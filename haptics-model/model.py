#!/usr/bin/env python3
"""PulseHaptics feel model: engine pipeline + actuator physics.

Plain Python 3, no dependencies. Reproduces every table in this folder:

    python3 haptics-model/model.py            # all report sections
    python3 haptics-model/model.py transfer   # one section: transfer | erm | lra | sweep

The engine half mirrors PulseHaptics/Core/Engine.lua (PlayMode scheduling, layer blending,
overdrive, mapValue, smoothing, shut-off, rate limit). The actuator half is a model with
stated assumptions (see 02-actuator-models.md); its parameters are estimates, not
measurements.
"""

import math
import os
import re
import sys

# ── Presets: copied from PulseHaptics/Core/Devices.lua ─────────────────────────────────────

CHANNEL_DEFAULTS = dict(gain=1.0, gamma=1.0, floor=0.0, attackTau=0.075, transientAttackTau=0.012,
                        releaseTau=0.028, overdriveBoost=1.0, overdriveDuration=0.0, useSCurve=False)
ERM_LOW = dict(floor=0.025, attackTau=0.085, transientAttackTau=0.018, releaseTau=0.050,
               overdriveBoost=1.25, overdriveDuration=0.025, gamma=0.88, useSCurve=False)
ERM_HIGH = dict(floor=0.025, attackTau=0.045, transientAttackTau=0.010, releaseTau=0.024,
                overdriveBoost=1.15, overdriveDuration=0.020, gamma=0.88, useSCurve=False)
LRA = dict(floor=0.025, attackTau=0.015, transientAttackTau=0.005, releaseTau=0.012,
           overdriveBoost=1.00, overdriveDuration=0.000, gamma=1.00, useSCurve=False)


def cp(src, **extra):
    d = dict(CHANNEL_DEFAULTS)
    d.update(src)
    d.update(extra)
    return d


PRESETS = {
    "default": dict(Low=cp({}), High=cp({})),
    "ds4": dict(Low=cp(ERM_LOW, floor=0.040, attackTau=0.075, releaseTau=0.045, gamma=0.90),
                High=cp(ERM_HIGH, floor=0.040, attackTau=0.040, releaseTau=0.024, gamma=0.90)),
    "dualsense": dict(Low=cp(LRA, floor=0.025, gain=1.15, attackTau=0.015, releaseTau=0.012),
                      High=cp(LRA, floor=0.025, gain=1.05, attackTau=0.012, releaseTau=0.010)),
    "xbox": dict(Low=cp(ERM_LOW), High=cp(ERM_HIGH)),
    "xbox_elite": dict(Low=cp(ERM_LOW, floor=0.040, gain=1.10, attackTau=0.090, releaseTau=0.055, gamma=0.85),
                       High=cp(ERM_HIGH, floor=0.040, gain=1.05, attackTau=0.050, releaseTau=0.026, gamma=0.85)),
    "switchpro": dict(Low=cp(LRA, floor=0.055, gain=1.30, attackTau=0.020, releaseTau=0.018),
                      High=cp(LRA, floor=0.055, gain=1.30, attackTau=0.015, releaseTau=0.015)),
    "8bitdo": dict(Low=cp(ERM_LOW, floor=0.040, attackTau=0.080, releaseTau=0.048),
                   High=cp(ERM_HIGH, floor=0.040, attackTau=0.045, releaseTau=0.024)),
    "steamdeck": dict(Low=cp(LRA, floor=0.045, gain=1.25, attackTau=0.035, releaseTau=0.020, gamma=0.90),
                      High=cp(LRA, floor=0.035, gain=1.05, attackTau=0.015, releaseTau=0.015)),
    "steamcontroller2": dict(Low=cp(LRA, floor=0.035, gain=1.10, attackTau=0.020, releaseTau=0.015),
                             High=cp(LRA, floor=0.035, gain=1.05, attackTau=0.015, releaseTau=0.012)),
    "steamcontroller": dict(Low=cp(LRA, floor=0.060, gain=1.10, attackTau=0.040, releaseTau=0.030),
                            High=cp(LRA, floor=0.040, gain=1.00, attackTau=0.020, releaseTau=0.020)),
    "lra_classic": dict(Low=cp(ERM_LOW, floor=0.065, gain=1.20, attackTau=0.075, transientAttackTau=0.025,
                               releaseTau=0.045, gamma=0.88),
                        High=cp(ERM_HIGH, floor=0.050, gain=1.10, attackTau=0.040, transientAttackTau=0.012,
                                releaseTau=0.028, gamma=0.88)),
}

# Counterfactual: the ERM floors as they were before commit 72950f5 (same day as this model).
# Not presets in the addon; used only to compare "then vs now".
PREV_FLOORS = {"xbox": (0.125, 0.095), "xbox_elite": (0.135, 0.105), "ds4": (0.115, 0.090), "8bitdo": (0.145, 0.115)}
for _p, (_fl, _fh) in PREV_FLOORS.items():
    PRESETS[_p + "@prev"] = dict(Low=dict(PRESETS[_p]["Low"], floor=_fl), High=dict(PRESETS[_p]["High"], floor=_fh))

ERM_PROFILES = ["default", "xbox", "xbox_elite", "ds4", "8bitdo"]
LRA_PROFILES = ["default", "dualsense", "switchpro", "steamdeck", "steamcontroller2", "steamcontroller",
                "lra_classic"]

# ── Modes and cues: parsed from the addon source so the model cannot drift from it ─────────

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "PulseHaptics", "Core")


def _num(block, key):
    m = re.search(r"\b" + key + r"\s*=\s*([0-9.]+)", block)
    return float(m.group(1)) if m else None


def load_modes():
    """Core/Modes.lua -> {id: dict(base, steps=[(role, relI, relD) | ("gap", secs)])}."""
    src = open(os.path.join(ROOT, "Modes.lua")).read()
    body = src[src.index("Pulse.Modes = {"):src.index("Pulse.Modes.TRIGGER_CLICK")]
    modes, cont = {}, {}
    for m in re.finditer(r"\n\t([A-Z_]+) = \{(.*?)\n\t\},", body, re.S):
        mid, blk = m.group(1), m.group(2)
        if "continuous = true" in blk:
            cont[mid] = dict(low=_num(blk, "low") or 0.0, high=_num(blk, "high") or 0.0)
            continue
        steps = []
        for s in re.finditer(r"\{([^{}]*)\}", blk[blk.index("steps"):]):
            st = s.group(1)
            if "gap" in st:
                steps.append(("gap", _num(st, "gap")))
            else:
                role = re.search(r'role\s*=\s*"(\w+)"', st).group(1)
                steps.append((role, _num(st, "relIntensity") or 1.0, _num(st, "relDuration") or 1.0))
        modes[mid] = dict(base=_num(blk, "baseDuration") or 0.25, steps=steps)
    return modes, cont


def load_cues():
    """Core/Registry.lua -> [dict(id, mode, intensity, on)] for every trigger with a mode."""
    src = open(os.path.join(ROOT, "Registry.lua")).read()
    cues = []
    for blk in re.split(r"\n\t\{\n", src):
        i = re.search(r'^\t\tid = "([^"]+)"', blk, re.M)
        mo = re.search(r'^\t\tmode = "([A-Z_]+)"', blk, re.M)
        if not (i and mo):
            continue
        di = re.search(r"^\t\tdefaultIntensity = ([0-9.]+)", blk, re.M)
        de = re.search(r"^\t\tdefault = (true|false)", blk, re.M)
        cues.append(dict(id=i.group(1), mode=mo.group(1), intensity=float(di.group(1)) if di else 1.0,
                         on=bool(de and de.group(1) == "true")))
    return cues


MODES, CONTINUOUS = load_modes()
SELECTED = ["TAP", "DOUBLE_TAP", "TICK", "CHIME", "THUD", "STUTTER", "CLICK", "HEAVY"]

# ── Engine constants: PulseHaptics/Core/Engine.lua ────────────────────────────────────────

SILENCE_GATE = 0.004
SHUTOFF_DEADBAND = 0.025
WATCHDOG_INTERVAL = 0.250
MIN_TELEMETRY_INTERVAL = 0.0125
REFRESH_WINDOW = 0.35
CHANGE_EPSILON = 0.0015
MIN_STEP_DURATION = 0.020
MIN_GAP_DURATION = 0.025
T0 = 1000.0  # GetTime() is large in game; keeps "time since last send" honest at t=0


def clamp01(v):
    return 0.0 if v < 0 else (1.0 if v > 1 else v)


def map_value(cfg, v, transient):
    """Engine.lua mapValue."""
    if v <= 0:
        return 0.0
    v = clamp01(v * cfg["gain"])
    if v <= 0:
        return 0.0
    if cfg["useSCurve"]:
        v = v * v * (3.0 - 2.0 * v)
    elif cfg["gamma"] != 1.0:
        v = v ** cfg["gamma"]
    fl = cfg["floor"]
    if fl > 0:
        if transient:
            v = fl + (1.0 - fl) * v
        else:
            knee = cfg.get("floorKnee") or max(0.02, fl * 0.5)
            t = clamp01(v / knee)
            v = fl * t * t * (3.0 - 2.0 * t) + (1.0 - fl) * v
    return clamp01(v)


def smooth_towards(cur, wanted, dt, attack, release):
    tau = release if wanted < cur else attack
    if not tau or tau <= 0 or dt <= 0:
        return wanted
    a = 1.0 - math.exp(-dt / tau)
    return wanted if a >= 1 else cur + (wanted - cur) * a


def schedule(mode, scale):
    """Engine:PlayMode discrete branch -> list of (at, duration, {role: magnitude})."""
    out, offset, last_at = [], 0.0, -1.0
    for st in mode["steps"]:
        if st[0] == "gap":
            offset += max(MIN_GAP_DURATION, st[1])
            continue
        role, rel_i, rel_d = st
        dur = max(MIN_STEP_DURATION, rel_d * mode["base"])
        mag = clamp01(rel_i * scale)
        at = offset
        if last_at >= 0 and at <= last_at + MIN_STEP_DURATION:
            at = last_at + MIN_STEP_DURATION
            offset = at
        last_at = at
        roles = {"low": mag, "high": mag} if role == "both" else {role: mag}
        out.append((at, dur, roles))
        offset += dur
    return out


def authored_end(mode):
    ev = schedule(mode, 1.0)
    return max(at + d for at, d, _ in ev)


class Engine:
    """Faithful single-layer model of the OnUpdate pipeline (no shaped layers)."""

    def __init__(self, preset, master=0.7):
        self.cfg = PRESETS[preset]
        self.master = master
        self.layers = {}  # name -> dict(roles, end, transient)
        self.smoothed = {}
        self.last_set = {}
        self.last_sent_time = {}
        self.last_wanted = {}
        self.od_until = {"Low": 0.0, "High": 0.0}
        self.last_wanted_raw = {"Low": 0.0, "High": 0.0}
        self.cmd = {"Low": 0.0, "High": 0.0}  # what the controller currently holds

    def set_roles(self, name, roles, dur, transient, now):
        self.layers[name] = dict(roles=dict(roles), end=now + (dur if dur > 0 else 0.1), transient=transient)

    def _send(self, ch, v):
        self.cmd[ch] = v

    def drive(self, ch, wanted, last, dt, now, transient):
        cfg = self.cfg[ch]
        boost, oddur = cfg["overdriveBoost"], cfg["overdriveDuration"]
        raw = wanted
        prev = self.last_wanted_raw.get(ch, 0.0)
        self.last_wanted_raw[ch] = raw
        since = now - self.last_sent_time.get(ch, 0.0)
        if transient and oddur > 0 and raw > 0 and ((prev == 0 and since >= 0.070) or (raw - prev) > 0.40):
            self.od_until[ch] = now + oddur
        if now < self.od_until.get(ch, 0.0) and boost > 1.0:
            wanted = clamp01(wanted * boost)
        wanted = map_value(cfg, wanted, transient)
        attack = cfg["transientAttackTau"] if transient else cfg["attackTau"]
        sm = smooth_towards(self.smoothed.get(ch, 0.0), wanted, dt, attack, cfg["releaseTau"])
        if wanted == 0 and sm < SHUTOFF_DEADBAND:
            sm = 0.0
        self.smoothed[ch] = sm
        if wanted == 0 and sm <= SILENCE_GATE:
            if (last or 0) > 0:
                self._send(ch, 0.0)
                self.last_set[ch] = 0.0
            self.smoothed[ch] = 0.0
            return False
        out = clamp01(sm if sm > SILENCE_GATE else 0.0)
        is_on = out > SILENCE_GATE
        delta = abs(out - (last if last is not None else -1))
        since_last = now - self.last_sent_time.get(ch, 0.0)
        onset = wanted > 0 and self.last_wanted.get(ch, 0.0) == 0
        self.last_wanted[ch] = wanted
        critical = onset or delta > 0.20 or (not is_on and (last or 0) > 0)
        watchdog = is_on and since_last >= WATCHDOG_INTERVAL
        if critical or watchdog or (delta > CHANGE_EPSILON and since_last >= MIN_TELEMETRY_INTERVAL):
            self._send(ch, out)
            self.last_set[ch] = out
            self.last_sent_time[ch] = now
        return is_on

    def tick(self, now, dt):
        for name in [n for n, l in self.layers.items() if now >= l["end"]]:
            del self.layers[name]
        cont, trans = {}, {}
        for l in self.layers.values():
            for role, v in l["roles"].items():
                if v <= 0:
                    continue
                if l["transient"]:
                    trans[role] = max(trans.get(role, 0.0), v)
                else:
                    cont[role] = 1.0 - (1.0 - cont.get(role, 0.0)) * (1.0 - v)
        target, ch_trans = {}, {}
        for role in ("low", "high"):
            c, t = cont.get(role, 0.0), trans.get(role, 0.0)
            tot = clamp01(c + t)
            if tot <= 0:
                continue
            ch = "Low" if role == "low" else "High"
            m = clamp01(tot * self.master)
            if m > 0:
                target[ch] = max(target.get(ch, 0.0), m)
                if t > 0:
                    ch_trans[ch] = True
        any_on = False
        for ch, w in target.items():
            if self.drive(ch, w, self.last_set.get(ch), dt, now, ch_trans.get(ch, False)):
                any_on = True
        for ch, last in list(self.last_set.items()):
            if ch not in target and last > 0:
                if self.drive(ch, 0.0, last, dt, now, False):
                    any_on = True
        if not any_on and self.last_set:
            self.cmd["Low"] = self.cmd["High"] = 0.0
            self.smoothed.clear()
            self.last_set.clear()
            self.last_sent_time.clear()
            self.last_wanted.clear()


def run_engine(preset, mode_id=None, scale=1.0, master=0.7, fps=60.0, T=0.9, hold=None):
    """Simulate the engine. Returns a list of (t, cmdLow, cmdHigh), one row per frame.

    mode_id: a discrete mode (PlayMode) fired at t=0.
    hold:    (low, high, seconds) for a continuous Hold() re-armed every frame.
    """
    eng = Engine(preset, master)
    dt = 1.0 / fps
    timers = []
    if mode_id:
        for i, (at, dur, roles) in enumerate(schedule(MODES[mode_id], scale)):
            if at <= 0:
                eng.set_roles("cue", roles, dur, True, T0)
            else:
                timers.append((at, dur, roles))
    rows, k = [], 0
    while True:
        t = k * dt
        if t > T:
            break
        now = T0 + t
        for tm in [x for x in timers if x[0] <= t + 1e-9]:
            timers.remove(tm)
            eng.set_roles("cue", tm[2], tm[1], True, now)
        if hold and t < hold[2]:
            eng.set_roles("hold", {"low": hold[0] * scale, "high": hold[1] * scale}, REFRESH_WINDOW, False, now)
        eng.tick(now, dt)
        rows.append((t, eng.cmd["Low"], eng.cmd["High"]))
        k += 1
    return rows


# ── Actuator models (see 02-actuator-models.md) ───────────────────────────────────────────

class ERM:
    """Eccentric rotating mass on a unidirectional PWM driver.

    w = normalised speed (1.0 = full speed). Running target speed for command u is
    (u - uc) / (1 - uc); below uc the target is negative, i.e. friction decelerates it.
    Speeds up with tau_up, slows (coasts, no active braking) with tau_down, stops at w = 0.
    From rest it only starts once u > ub (static friction > running friction).
    Strength (vibration acceleration) is proportional to w^2 (centripetal force m r w^2).
    """

    def __init__(self, tau_up, tau_down, ub, uc, fmax):
        self.tau_up, self.tau_down, self.ub, self.uc, self.fmax = tau_up, tau_down, ub, uc, fmax
        self.w, self.running = 0.0, False

    def step(self, u, dt):
        if not self.running and u > self.ub:
            self.running = True
        if self.running:
            wss = (u - self.uc) / (1.0 - self.uc)
            tau = self.tau_up if wss > self.w else self.tau_down
            self.w += (wss - self.w) * (1.0 - math.exp(-dt / tau))
            if self.w <= 0:
                self.w, self.running = 0.0, False
        return self.w * self.w


class LRAAct:
    """Linear resonant actuator driven at resonance with amplitude = command.

    Envelope of a 2nd-order resonator driven at f0 behaves as 1st order with
    tau = Q / (pi f0). Strength (acceleration at a fixed frequency) is linear in amplitude.
    `brake` < 1 models a driver that actively brakes (faster decay than rise).
    """

    def __init__(self, tau, brake=1.0):
        self.tau, self.brake, self.a = tau, brake, 0.0

    def step(self, u, dt):
        tau = self.tau if u >= self.a else self.tau * self.brake
        self.a += (u - self.a) * (1.0 - math.exp(-dt / tau))
        return self.a


# Nominal hardware (class estimates, see 02-actuator-models.md)
ERM_HW = {"Low": dict(tau_up=0.060, tau_down=0.090, ub=0.060, uc=0.040, fmax=70.0),
          "High": dict(tau_up=0.030, tau_down=0.045, ub=0.050, uc=0.035, fmax=150.0)}
LRA_HW = {"Low": dict(tau=0.012, brake=1.0), "High": dict(tau=0.010, brake=1.0)}

PHYS_DT = 0.0005  # 2 kHz actuator integration
LATENCY = 0.0     # transport latency is identical for every profile; left out


def actuate(rows, kind, hw=None, T=None):
    """Drive actuator models with the engine's zero-order-held commands.

    Returns list of (t, E_low, E_high) at PHYS_DT resolution; E is normalised strength.
    """
    hw = hw or (ERM_HW if kind == "erm" else LRA_HW)
    mk = (lambda h: ERM(**h)) if kind == "erm" else (lambda h: LRAAct(**h))
    act = {ch: mk(hw[ch]) for ch in ("Low", "High")}
    T = T if T is not None else rows[-1][0]
    out, i, t = [], 0, 0.0
    while t <= T + 1e-12:
        while i + 1 < len(rows) and rows[i + 1][0] <= t - LATENCY + 1e-12:
            i += 1
        uL, uH = (rows[i][1], rows[i][2]) if rows[i][0] <= t - LATENCY + 1e-12 else (0.0, 0.0)
        out.append((t, act["Low"].step(uL, PHYS_DT), act["High"].step(uH, PHYS_DT)))
        t += PHYS_DT
    return out


# ── Metrics ───────────────────────────────────────────────────────────────────────────────

E_TH = 0.01   # detection threshold on normalised strength: -40 dB re full-scale acceleration
BETA = 0.6    # Stevens exponent: perceived magnitude = E ** BETA


def db(x):
    return 20.0 * math.log10(max(x, 1e-6))


def metrics(sim, end_nominal, pulses=None):
    """Summarise felt strength E = E_low + E_high."""
    E = [(t, l + h, l, h) for t, l, h in sim]
    peak = max(e for _, e, _, _ in E)
    on = [t for t, e, _, _ in E if e >= E_TH]
    t_det = on[0] if on else None
    t50 = next((t for t, e, _, _ in E if e >= 0.5 * peak), None) if peak >= E_TH else None
    last = on[-1] if on else None
    res = dict(peak=peak, psi=peak ** BETA if peak > 0 else 0.0, t_det=t_det, t50=t50,
               tail=(last - end_nominal) if last is not None else None,
               felt=len(on) * PHYS_DT, peakL=max(l for *_, l, _ in E), peakH=max(h for *_, h in E))
    if pulses:
        dips = []
        for (a0, a1), (b0, b1) in zip(pulses, pulses[1:]):
            pa = max(e for t, e, _, _ in E if a0 <= t < a1 + 0.03)
            pb = max(e for t, e, _, _ in E if b0 <= t < b1 + 0.03)
            gap = [e for t, e, _, _ in E if a1 <= t <= b0 + 0.03]
            # the dip is the deepest point between the two pulse peaks
            ta = max((t for t, e, _, _ in E if a0 <= t < a1 + 0.03 and e == pa))
            tb = min((t for t, e, _, _ in E if b0 <= t < b1 + 0.03 and e == pb))
            between = [e for t, e, _, _ in E if ta <= t <= tb]
            m = min(between) if between else min(gap)
            dips.append(db(min(pa, pb)) - db(max(m, 1e-6)))
        res["dips"] = dips
    return res


def pulse_windows(mode_id):
    return [(at, at + d) for at, d, _ in schedule(MODES[mode_id], 1.0)]


def fmt(x, unit="", nd=0, none="—"):
    if x is None:
        return none
    return f"{x * 1000:.{nd}f}{unit}" if unit == "ms" else f"{x:.{nd}f}{unit}"


# ── Report sections ───────────────────────────────────────────────────────────────────────

def section_transfer():
    print("## Transient command for authored inputs (master 0.7, trigger 1.0)\n")
    levels = [("CLICK", 0.20), ("TICK", 0.35), ("TAP", 0.55), ("DOUBLE_TAP", 0.60), ("THUMP", 0.85),
              ("HEAVY", 1.00)]
    print("| Profile | Ch | " + " | ".join(f"{m} {v:.2f}" for m, v in levels) + " |")
    print("|---|---|" + "---|" * len(levels))
    for p in PRESETS:
        for ch in ("Low", "High"):
            cfg = PRESETS[p][ch]
            cells = [f"{map_value(cfg, v * 0.7, True):.3f}" for _, v in levels]
            print(f"| {p} | {ch} | " + " | ".join(cells) + " |")


def steady_E(kind, ch, u, hw=None):
    """Steady-state strength for a held command u (no dynamics)."""
    if kind == "lra":
        return u
    h = (hw or ERM_HW)[ch]
    if u <= h["ub"]:
        return 0.0
    w = (u - h["uc"]) / (1.0 - h["uc"])
    return w * w


LADDER = [("CLICK", 0.20), ("TICK", 0.35), ("TAP", 0.55), ("THUMP", 0.85), ("HEAVY", 1.00)]


def section_contrast(master=0.7):
    print(f"\n## Steady strength on the High channel, dB relative to HEAVY (master {master})\n")
    print("| Hardware | Profile | " + " | ".join(m for m, _ in LADDER) + " | CLICK→HEAVY range | THUMP vs HEAVY |")
    print("|---|---|" + "---|" * (len(LADDER) + 2))
    for kind, profs in (("erm", ERM_PROFILES), ("lra", LRA_PROFILES)):
        for p in profs:
            cfg = PRESETS[p]["High"]
            E = [steady_E(kind, "High", map_value(cfg, v * master, True)) for _, v in LADDER]
            ref = E[-1]
            cells = [("silent" if e <= 0 else f"{db(e) - db(ref):+.1f}") for e in E]
            rng = (db(ref) - db(E[0])) if E[0] > 0 else float("inf")
            print(f"| {kind.upper()} | {p} | " + " | ".join(cells) + f" | {rng:.1f} dB | {db(E[-1]) - db(E[-2]):.1f} dB |")


def section_clip():
    print("\n## Top-of-range collapse: THUMP (0.85) vs HEAVY (1.0) command, Low channel, with overdrive\n")
    print("| Profile | master 0.7 | master 0.85 | master 1.0 |")
    print("|---|---|---|---|")
    for p in PRESETS:
        cfg = PRESETS[p]["Low"]
        cells = []
        for master in (0.7, 0.85, 1.0):
            b = cfg["overdriveBoost"] if cfg["overdriveDuration"] > 0 else 1.0
            a = map_value(cfg, clamp01(0.85 * master * b), True)
            h = map_value(cfg, clamp01(1.0 * master * b), True)
            tag = " **same**" if abs(h - a) < 1e-9 else ""
            cells.append(f"{a:.2f} vs {h:.2f}{tag}")
        print(f"| {p} | " + " | ".join(cells) + " |")


def section_continuous():
    print("\n## Continuous (soft-floor) command for quiet texture inputs (after master)\n")
    ins = [0.005, 0.01, 0.02, 0.03, 0.05, 0.08]
    print("| Profile | Ch | floor | knee | " + " | ".join(f"in {v:.3f}" for v in ins) + " |")
    print("|---|---|---|---|" + "---|" * len(ins))
    for p in ERM_PROFILES[1:] + ["lra_classic"]:
        cfg = PRESETS[p]["Low"]
        knee = cfg.get("floorKnee") or max(0.02, cfg["floor"] * 0.5)
        cells = [f"{map_value(cfg, v, False):.3f}" for v in ins]
        print(f"| {p} | Low | {cfg['floor']:.3f} | {knee:.3f} | " + " | ".join(cells) + " |")


_ROWS = {}


def cue_rows(p, mode, scale, master=0.7):
    key = (p, mode, round(scale, 3), master)
    if key not in _ROWS:
        _ROWS[key] = run_engine(p, mode, scale=scale, master=master, T=authored_end(MODES[mode]) + 0.4)
    return _ROWS[key]


def cue_census(kind, profile, hw, master=0.7, only_on=False):
    """Count cues that never start a motor, or are never detectable."""
    dead, faint, total = [], [], 0
    for c in load_cues():
        if c["mode"] not in MODES or (only_on and not c["on"]):
            continue
        total += 1
        rows = cue_rows(profile, c["mode"], c["intensity"], master)
        sim = actuate(rows, kind, hw)
        peak = max(l + h for _, l, h in sim)
        if peak <= 0:
            dead.append(c)
        elif peak < E_TH:
            faint.append(c)
    return total, dead, faint


def erm_hw_with(ub_low, ub_high):
    hw = {ch: dict(v) for ch, v in ERM_HW.items()}
    hw["Low"].update(ub=ub_low, uc=0.7 * ub_low)
    hw["High"].update(ub=ub_high, uc=0.7 * ub_high)
    return hw


def section_census():
    print("\n## Cue census on ERM hardware: cues with no felt output (master 0.7, shipped intensities)\n")
    ubs = [0.03, 0.06, 0.10, 0.15]
    print("| Profile | " + " | ".join(f"breakaway {u:.2f}" for u in ubs) + " |")
    print("|---|" + "---|" * len(ubs))
    detail = {}
    for p in ERM_PROFILES:
        cells = []
        for u in ubs:
            tot, dead, faint = cue_census("erm", p, erm_hw_with(u, u))
            ton, deadon, fainton = cue_census("erm", p, erm_hw_with(u, u), only_on=True)
            cells.append(f"{len(dead)} dead + {len(faint)} faint / {tot} (on by default: {len(deadon) + len(fainton)} / {ton})")
            detail[(p, u)] = dead + faint
        print(f"| {p} | " + " | ".join(cells) + " |")
    return detail


def section_dynamics(kind, profiles, scale=1.0, master=0.7, fps=60.0, hw=None, modes=SELECTED):
    for m in modes:
        end = authored_end(MODES[m])
        pw = pulse_windows(m) if len(MODES[m]["steps"]) > 1 and any(s[0] == "gap" for s in MODES[m]["steps"]) else None
        print(f"\n### {m} (authored length {end * 1000:.0f} ms)\n")
        hdr = "| Profile | peak cmd L/H | peak E | ψ | first felt | 50% | felt for | tail past end |"
        if pw:
            hdr += " dips (dB) |"
        print(hdr)
        print("|---" * (hdr.count("|") - 1) + "|")
        for p in profiles:
            rows = run_engine(p, m, scale=scale, master=master, fps=fps, T=end + 0.5)
            pcL = max(r[1] for r in rows)
            pcH = max(r[2] for r in rows)
            sim = actuate(rows, kind, hw)
            r = metrics(sim, end, pw)
            line = (f"| {p} | {pcL:.2f} / {pcH:.2f} | {r['peak']:.2f} | {r['psi']:.2f} | {fmt(r['t_det'], 'ms')} | "
                    f"{fmt(r['t50'], 'ms')} | {fmt(r['felt'], 'ms')} | {fmt(r['tail'], 'ms')} |")
            if pw:
                line += " " + ", ".join(f"{d:.0f}" for d in r["dips"]) + " |"
            print(line)


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "transfer"):
        section_transfer()
        section_contrast()
        section_clip()
        section_continuous()
        section_census()
    if which in ("all", "erm"):
        print("\n## ERM hardware\n")
        section_dynamics("erm", ERM_PROFILES)
    if which in ("all", "lra"):
        print("\n## LRA hardware\n")
        section_dynamics("lra", LRA_PROFILES)
