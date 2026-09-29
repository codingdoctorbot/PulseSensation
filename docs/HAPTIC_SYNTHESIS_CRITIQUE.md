# Haptic Signal Synthesis Critique — Overdrive, Coast-Down, Ducking, Band Split

**Date:** 2026-09-30
**Tree reviewed:** HEAD `db2ffa5` plus the uncommitted working tree (WP1–WP5 edits in `PulseHaptics/Core/Engine.lua` and `PulseHaptics/Core/Devices.lua`).
**Scope:** the three physical models in the synthesis pipeline and the Low/High band split:
1. Overdrive kick and coast-down compensation for the ERM motors on the Xbox preset.
2. The tactile sidechain ducking (`duckingFactor = math.max(0.30, 1.0 - trans * 0.65)`) and its stated mechanoreceptor rationale.
3. The dual-motor split between Low (body rumble) and High (transient clicks): frequency masking, phase cancellation and motor-clatter risks in overlapping combat.

**Mode:** read-only. No code was changed. This file is the only repository file written.

**Labels:**
- **[Fact]** verified from code, algebra, or a simulation of the real engine files.
- **[Inference]** reasoned from code or physics, not run.
- **[Rec]** recommendation.
- **[Unverified]** needs hardware, the live client, or a literature check.

---

## 0. Summary

**Verdict:** the engine plumbing is sound, but all three physical models are unsound as physics, and the ducking is also unsound as mathematics.

- `./scripts/test.sh`: luacheck 0 warnings / 0 errors in 51 files; all 7 suites pass. [Fact]
- **Live install:** overdrive and coast trim are currently **inactive**; only the ducking reaches the player. [Fact]
  - The SavedVariables file (`WTF/Account/120143960#1/SavedVariables/PulseHaptics.lua`, mtime 2026-09-29 10:44) holds the old Xbox values (Low floor 0.12, attack 0.09, release 0.06, gamma 1).
  - It has no `overdriveBoost`, `overdriveDuration`, `coastCoeff` or `useSCurve` keys, so the engine falls back to `CHANNEL_DEFAULTS` (1.0 / 0 / 0 / false). Those turn on only after the Xbox preset is re-applied.
  - Ducking is hardcoded, so it is active on every device.

**Overlap with earlier work.** The session recorded in `docs/claudehandoff.md` §3.3 already flagged:
- overdrive not gated on `isTransient`;
- coast trim shortening the layer rather than cutting voltage;
- coast trim using the Low coefficient for every layer;
- ducking reversing the documented "never duck" policy.

Those points are repeated here only where new measurements extend them. Everything else in this file is new.

### Ranked findings

| # | Severity | Finding | Section |
|---|---|---|---|
| 1 | High | Coast trim opens holes in contiguous multi-step modes, turning smooth envelopes into kicked pulse trains (SURGE 1→4 segments, peak 0.76→0.90) | §2.2 |
| 2 | High | Coast-trimmed taps (15 ms) can be silently dropped. Whether they are depends on frame rate and on whether cue code runs before or after the engine's OnUpdate | §2.2 |
| 3 | High | On one actuator, ducking can only reduce output and the felt step. It removes 31–59% of small cues' step, and a weak transient on a strong bed produces a dip | §1 |
| 4 | Medium | Overdrive length is frame-quantized: 30 ms configured becomes 33–57 ms | §2.1 |
| 5 | Medium | Overdrive fires on command history, not rotor state: 104 of 107 kicks in a combat mix hit an already-spinning motor | §2.1 |
| 6 | Medium | Overdrive's "3× faster" claim: modelled speed-up is 1.1–1.4× | §2.1 |
| 7 | Medium | In combat both motors are above floor 99.8% of the time. Ducking is per-role, so the cross-motor masking case gets no relief | §3 |
| 8 | Low | `max(0.30, …)` floor is dead code | §1 |
| 9 | Low | Stale comment at `Engine.lua:690-691` contradicts the ducking at `:764` | §1 |
| 10 | Low | The tests for WP1–WP4 do not discriminate the behaviour they name | §4 |
| 11 | Low | Preset notes contain unsourced or implausible hardware claims | §5 |

---

## Method

**Probe:** `synth-probe.lua` in the repo root, saved as supporting evidence. Run it from the repo root with `luajit synth-probe.lua PulseHaptics`; it prints sections A–H, which map to the tables in this report (H feeds §7). It is read-only: it loads the engine files and writes nothing. Re-run on 2026-09-30 from the root and reproduced the figures quoted here. Its output reflects whatever working tree it is run against, so the numbers will move once the engine changes.

**What it loads:** the real working-tree files, by `loadfile`:
- `Core/Devices.lua`
- `Core/Schemas/Standard.lua`
- `Core/Modes.lua`
- `Core/Engine.lua`

For A/B variants, `Engine.lua` is patched **in memory only**:
- no ducking;
- `clamp01(c + t)` headroom mix;
- an instrumentation line that exposes the overdrive state.

**Stubs:** `GetTime`, `C_Timer.After` (a real scheduler), `CreateFrame`, `C_GamePad` (records `SetVibration`), and `Pulse.Database`, which returns the working-tree Xbox preset values plus any per-test overrides.

**Run settings:**
- Frames advance at a chosen fps.
- Callback order is selectable: cue code before the engine's OnUpdate in a frame ("T") or after it ("U").
- Unless stated otherwise: Xbox preset, master intensity 0.7 (the user's usual profile value), Standard schema, cue intensity 1.0.

**Signal chain as implemented**, per frame in `onEngineTick`:

1. Layers are blended per role:
   - continuous layers by saturating sum (`:755`);
   - transient layers by max (`:749-751`);
   - shaped layers by max (`:731-733`).
2. Ducking and combination per role (`:766-780`).
3. × master × schema intensity, then max per channel (`:791-799`).
4. Overdrive detection and boost on the channel target (`:558-574`).
5. `mapValue`: gain → gamma or smoothstep → floor lift (`:521-544`).
6. Attack/release smoothing, with a transient or continuous attack lane (`:581-585`).
7. Shutoff deadband and silence gate (`:586-603`).
8. Shaped merge: `base + shaped·(1−base)` (`:606`).
9. Send gating: onset, jump over 0.20, watchdog, or ε plus the 80 Hz cap (`:617-627`).
10. `SetVibration`.

---

## 1. Tactile sidechain ducking (`Engine.lua:766-780`)

```lua
local duckingFactor = math.max(0.30, 1.0 - (trans * 0.65))
local duckedCont = cont * duckingFactor
frameRoleTotals[role] = clamp01(duckedCont + trans * (1.0 - duckedCont))
```

### 1.1 The 0.30 floor never engages [Fact, algebra]

Role values are clamped to [0, 1] when stored (`SetRoles`, `:286`), and the transient total is a max of those values (`:749-751`). So `trans ≤ 1` and `1 − 0.65·trans ≥ 0.35`. The floor would need `trans > 1.077`. The strongest duck is therefore to 35%, not 30%.

The brainstorm specification used a 0.70 coefficient (`docs/brainstorm.md:150`), which would reach 0.30 at `trans = 1`.

### 1.2 On one actuator, ducking can only lower the output [Fact, algebra]

Ducking is computed per **role**, and every role resolves to exactly one physical channel (`resolveRole`, `:153-164`). So the bed and the transient being mixed are always destined for the same motor.

With `d = 1 − 0.65t`:

```
out_duck  = d·c + t·(1 − d·c)
out_plain =   c + t·(1 −   c)
out_duck − out_plain = −0.65 · t · c · (1 − t)   ≤ 0
```

Consequences:
- The ducked output is never above the unducked output.
- The felt step above the bed (`out − c`) is reduced by exactly the same amount.
- The largest loss is at `t = 0.5`: `−0.1625·c`.

Audio sidechain works because the masker and the target are separate signals (different tracks and spectra) sharing a speaker. Here both collapse into one scalar driving one rotor, so there is nothing to separate. Ducking cannot improve transient clarity on the same motor.

### 1.3 A weak transient on a strong bed makes a dip [Fact, algebra]

`out_duck < c` whenever `c > 1 / (1 + 0.65·(1 − t))`, which is `c > 0.606` as `t → 0`.

Closed form, role space. Each cell is the ducked value, with the unducked value in brackets; ▼ marks a dip below the bed:

| c \ t | 0.10 | 0.28 | 0.55 | 0.70 | 0.95 |
|---|---|---|---|---|---|
| 0.10 | 0.184 [0.190] | 0.339 [0.352] | 0.579 [0.595] | 0.716 [0.730] | 0.952 [0.955] |
| 0.30 | 0.352 [0.370] | 0.457 [0.496] | 0.637 [0.685] | 0.749 [0.790] | 0.956 [0.965] |
| 0.50 | 0.521 [0.550] | 0.574 [0.640] | 0.695 [0.775] | 0.782 [0.850] | 0.960 [0.975] |
| 0.70 | 0.689 [0.730] ▼ | 0.692 [0.784] ▼ | 0.752 [0.865] | 0.814 [0.910] | 0.963 [0.985] |
| 0.90 | 0.857 [0.910] ▼ | 0.810 [0.928] ▼ | 0.810 [0.955] ▼ | 0.847 [0.970] ▼ | 0.967 [0.995] |

**Exposure** [Inference]: the stock beds rarely reach this region. The cast swell is at most 0.70 on High, with 0.10 presence on Low. The dip becomes real only with stacked beds or raised per-cue intensity.

### 1.4 Measured in the engine [Fact, simulation]

Setup:
- `castTexture` is held every frame (Low 0.10, High 0.70 × progress).
- The cue fires at 90% progress, on the High role.
- Xbox preset, master 0.7, 60 fps.

The values are the felt step: the peak SetVibration value within 120 ms, minus the pre-cue level (0.524).

| Cue | Ducking (tree) | No ducking | `clamp01(c + t)` |
|---|---|---|---|
| TICK | 0.030 | 0.074 | 0.176 |
| TAP | 0.072 | 0.131 | 0.224 |
| Heartbeat lub (0.7, both roles) | 0.094 | 0.136 | 0.188 |
| SNAP | 0.170 | 0.180 | 0.188 |

Ducking removes 59% (TICK), 45% (TAP), 31% (heartbeat) and 6% (SNAP) of the felt step. That is the opposite of the comment's "preserving transient clarity".

### 1.5 The mechanoreceptor rationale does not hold

These are textbook values, recalled rather than looked up this session. Verify against sources (e.g. Bolanowski et al. 1988; Verrillo; Gescheider) before relying on the numbers. [Unverified]
- **Two receptor types.** Pacinian corpuscles (FA-II) are most sensitive around 200–300 Hz. Meissner corpuscles (FA-I) cover flutter at about 10–50 Hz.
- **"Rapidly adapting" is a different thing.** The term describes their response to *sustained indentation*: they fire at the onset and offset of pressure. It does not describe fatigue under vibration. Pacinian afferents keep phase-locking to ongoing vibration.
- **Real vibrotactile adaptation is slow and channel-specific.** It is a threshold elevation that builds over seconds to minutes of exposure.

Mismatch with the code [Inference]:
- **Timescale.** The code's ducks last as long as a transient layer, roughly 17–150 ms. That is two to three orders of magnitude too short to affect adaptation.
- **Duty cycle.** The brainstorm's claim of "~40% lower duty cycle" (`brainstorm.md:296`) cannot come from a duck that is active only while a transient is present.
- **Masking.** The mechanism that plausibly matters on these timescales is simultaneous masking. Masking relief needs the masker and target to be separable, and §1.2 shows they are not on one motor.

### 1.6 What a duck does to an ERM physically [Inference, DC-motor model]

- For an eccentric-rotating-mass motor, the vibration frequency equals the rotor speed, and the force amplitude is `m·r·ω²`.
- Above the breakaway floor, speed is roughly linear in drive. With the preset's gamma 0.88, ducking a bed to 0.35 of its command gives:
  - speed ×0.35^0.88 ≈ ×0.40;
  - force ≈ ×0.16;
  - frequency −60%.
- So the duck shifts timbre toward the flutter band as well as cutting level.
- If the rotor's mechanical time constant is tens of ms (unmeasured), it is about as long as the duck itself. The rotor would then only partly follow, and the net effect is a shaved peak.

### 1.7 Code and specification inconsistencies [Fact]

- **Stale comment.** `Engine.lua:690-691` still says transients are layered "without ducking or killing immersion". `:764-765` now ducks.
- **The heartbeat is a transient.** `Health.lua:116-118` and `:146-148` pass `isTransient = true`. So the low-health heartbeat ducks the cast texture on both roles, and is never ducked itself.
- **The implementation drifted from its specification.**
  - The brainstorm specifies **priority-gated** ducking: Priority 3/2 events duck Priority 1 layers (`brainstorm.md:143-151`).
  - The implementation ducks on **any** `isTransient` layer, including UI ticks, with 0.65 instead of 0.70.
- **Correction to earlier advice.** `docs/CODE_REVIEW.md:248` item (d) suggested "ducking continuous under transients instead of `(1−cont)` compression". What that item was after, a full felt step regardless of the bed, is delivered by headroom addition, `clamp01(c + t)`, not by ducking. See the last column of §1.4.

---

## 2. Overdrive and coast-down compensation

### 2.1 Overdrive (`Engine.lua:555-574`)

**Where the boost is applied** [Fact]
- The boost multiplies the channel **target** before `mapValue` (`:576`) and before attack smoothing (`:585`).
- **The floor and gamma compress it.** Above the floor, ×1.45 becomes ×1.387 (= 1.45^0.88) until the boosted value clamps at 1.0, which happens for wanted ≥ 0.69. The ratio of total drive is smaller still at low targets:

  | wanted | mapped | boosted | total ratio | above-floor ratio |
  |---|---|---|---|---|
  | 0.05 | 0.188 | 0.212 | 1.129 | 1.387 |
  | 0.10 | 0.240 | 0.285 | 1.186 | 1.387 |
  | 0.20 | 0.337 | 0.419 | 1.243 | 1.387 |
  | 0.50 | 0.600 | 0.784 | 1.306 | 1.387 |
  | 0.69 | 0.756 | 1.000 | 1.322 | 1.386 |
  | 0.80 | 0.844 | 1.000 | 1.185 | 1.217 |

- **The attack filter blunts it.** The kick then passes the transient attack filter (Xbox Low `transientAttackTau` 18 ms) instead of reaching the motor directly.
- **The design that was cited is not the one implemented.**
  - The brainstorm formula was `min(1, wanted × 1.45 + 0.15)` (Innovation 1). The DRV2605-style overdrive it cites drives at 100%.
  - The implementation has neither the +0.15 offset nor full drive. At wanted 0.05 the kick adds only +0.024 of drive, precisely where static friction needs the most help.

**Kick length is frame-quantized** [Fact, simulation]
- The boosted value set on the last boosted frame persists until the next frame, so the effective kick is `frameTime × ceil(duration / frameTime)`.
- Measured with BLIP on the Low motor, coast trim off to isolate:

  | fps | 30 | 35 | 40 | 45 | 50 | 60 | 90 | 144 |
  |---|---|---|---|---|---|---|---|---|
  | Low kick held, ms (set to 30) | 33 | **57** | 50 | 44 | 40 | 33 | 33 | 35 |

- High (set to 15 ms, SNAP): 33 ms at 30 fps, 17 ms at 60 fps, 21 ms at 144 fps.
- So a player at 35 fps gets nearly twice the configured kick.
- This diff removed the same class of problem from the shaped lane (L1, the `dt*1.2` kick clamp), and it reappears here.

**The "3× faster" claim (`Engine.lua:557`) is not supported** [Inference, model]
- Model: a first-order rotor above breakaway, `speed' = (drive_above_floor − speed) / τm`.
- Input: the actual `SetVibration` sends for LONG (Low 0.70 × 450 ms, master 0.7), 60 fps, zero-order hold.
- τm is unmeasured, so three values are shown. t90 is the time for rotor speed to reach 90% of its final value:

  | τm (assumed) | t90 without overdrive | t90 with 1.45×/30 ms | Ideal full-drive kick |
  |---|---|---|---|
  | 40 ms | 116.7 ms | 83.3 ms | 26.2 ms |
  | 85 ms | 216.7 ms | 183.3 ms | 55.7 ms |
  | 120 ms | 300.0 ms | 266.7 ms | 78.7 ms |

- The implemented kick speeds spin-up by about 1.1–1.4×. A true bang-bang kick would give about 4×: full drive until the rotor reaches its target, which takes `τm·ln(1/(1 − x))`.

**The trigger reads command history, not rotor state** [Fact, simulation]
- The trigger is `prevWanted == 0 or rawWanted − prevWanted > 0.30` (`:564`).
- A target that was 0 for one 16 ms frame does not mean the rotor stopped: the code's own comment says heavy ERMs coast 40–70 ms.
- In the 20-second combat mix (§3.1), **104 of 107** overdrive onsets fired while the previous frame was already driving that motor at or above its floor. Kicking a spinning rotor overshoots.

**Not gated on transients** [Fact; overlap: handoff §3.3]
- The trigger condition has no `isTransient` check, so continuous textures are kicked at onset too.
- The 85 ms continuous attack filter then absorbs most of that kick.

### 2.2 Coast-down compensation (`Engine.lua:290-302`)

```lua
if isTransient and dur > 0.030 and not shape then
    local coastCoeff = channelConfig("Low", "coastCoeff") or 0.0
    ...
    local coastTime = coastCoeff * math.sqrt(maxMag)
    dur = math.max(0.015, dur - coastTime)
```

**No voltage is cut** [Fact; overlap: handoff §3.3]
- Only the layer's `endTime` moves. When the target drops to 0, release smoothing (`:585`) keeps driving the motor down exponentially.
- From 0.6 on Xbox Low (`releaseTau` 50 ms), the time to the 0.025 shutoff snap is `50·ln(0.6/0.025) ≈ 159 ms` of decaying drive, against a trim of at most 40 ms.
- The slider description at `Devices.lua:146` ("Cuts electrical drive early so rotor momentum completes the tap cleanly") is false for this implementation.

**Wrong channel, wrong magnitude** [Fact]
- The Low coefficient is used for every layer, including High-only ones (overlap). The High coefficient, 0.020 (`Devices.lua:220`), is shown as a slider but never read.
- The magnitude is the role value before master intensity (`:296`). At a low master the motor spins slower, but the trim stays the same, so it over-trims.

**New: holes in contiguous modes** [Fact, simulation]
- `PlayMode` schedules each step at the **untrimmed** offset (`offset = offset + duration`, `:510`). So every trimmed step now ends before the next one starts.
- In each hole the target drops to 0, and the next step re-fires overdrive (prevWanted == 0).
- Results at 60 fps, cue code before OnUpdate:

  | Mode | On-segments (trim off → on) | Overdrive onsets (off → on) | Note |
  |---|---|---|---|
  | SURGE | 1 → 4 | 2 → 4 | Low peak 0.76 → 0.90 |
  | WOBBLE | 1 → 4 | 4 → 4 | |
  | BRAKE | 1 → 3 | 2 → 4 | |
  | DRAW | 2 → 3 | 2 → 3 | |
  | THUD | 1 → 2 | 2 → 3 | |
  | CRACK, RISING, FALLING | 1 → 2 | 2 → 2 | |

- Envelopes designed as smooth builds or fades become pulse trains with a kick at each pulse. On an ERM this is the literal "clatter" risk.

**New: short taps silently dropped** [Fact, simulation]
- Trimmed steps can fall to the 15 ms minimum, which is shorter than one frame at 60 fps (16.7 ms).
- If the cue code runs after the engine's OnUpdate in the same frame, the layer expires before it is ever sampled, and nothing is sent.
- Counts below are on-segments / frames sampled / overdrive onsets, then peak Low, High. A row of 0 means silent.

  | Mode | 60 fps, T, trim off | 60 fps, U, trim off | 60 fps, U, trim on | 30 fps, U, trim off | 30 fps, U, trim on |
  |---|---|---|---|---|---|
  | TAP | 1/4/1 · 0.00, 0.49 | 1/3/1 · 0.00, 0.48 | 1/1/1 · 0.00, 0.48 | 1/1/1 · 0.00, 0.57 | **0** |
  | SNAP | 1/3/1 · 0.00, 0.73 | 1/2/1 · 0.00, 0.73 | **0** | 1/1/1 · 0.00, 0.86 | **0** |
  | MICRO_TAP | 1/3/1 · 0.00, 0.55 | 1/2/1 · 0.00, 0.55 | **0** | 1/1/1 · 0.00, 0.64 | **0** |
  | STUTTER | 4/12/4 · 0.00, 0.72 | 4/8/4 · 0.00, 0.71 | **0** | 4/4/4 · 0.00, 0.83 | **0** |
  | STACCATO | 3/9/3 · 0.00, 0.80 | 3/6/3 · 0.00, 0.78 | **0** | 3/3/3 · 0.00, 0.90 | **0** |
  | BURST | 3/9/4 · 0.72, 0.78 | 3/6/4 · 0.72, 0.77 | **0** | 3/3/4 · 0.72, 0.90 | **0** |
  | IMPACT | 1/5/2 · 0.84, 0.76 | 1/4/2 · 0.84, 0.76 | 1/1/2 · 0.60, 0.75 | 1/2/2 · 0.84, 0.89 | **0** |

- At 30 fps with the trim on, **every** single-step tap in the probe list vanished: TAP, SNAP, MICRO_TAP, CLICK, TICK, BLIP, IMPACT and DEFLECT. CLICK (30 ms) also vanishes at 30 fps U without the trim, because 30 ms is shorter than a 33 ms frame.
- With the cue code before OnUpdate ("T"), the taps survive but are cut to a single frame. For example, SNAP goes from 3 frames sampled to 1.
- [Unverified] The order in which WoW runs `C_Timer` callbacks and game events relative to frame `OnUpdate` scripts is not known. This whole row depends on it. The 2026-09-29 audit also listed it as unverified.

**The `sqrt` law is not derived** [Inference]
- Viscous friction alone gives a coast time `∝ ln(ω₀/ω_threshold)`. Coulomb friction alone gives `∝ ω₀`.
- `coastCoeff·sqrt(magnitude)` corresponds to neither. It could only be justified as a fit to measurements, and none exist.

---

## 3. Low/High band split: masking, phase, clatter

### 3.1 Combat mix used for exposure figures [Fact, simulation]

- **Duration and setup:** 20 s at 60 fps, Xbox preset, master 0.7, cue code before OnUpdate.
- **Layers:**
  - 2.0 s cast swells back to back (Low 0.10, High 0.70 × progress);
  - a heartbeat lub-dub (0.7 then 0.2 on both roles, 50 ms each, 0.36 s apart) every 0.9 s;
  - THUD every 2.6 s;
  - SNAP every 1.7 s;
  - TICK every 0.45 s;
  - a BOOT footfall (shaped) every 0.5 s.

| Variant | Overdrive onsets Low / High (per s) | SetVibration calls/s | Both motors above floor | Low ≥ 0.6 while High ≤ 0.3 |
|---|---|---|---|---|
| Working tree (overdrive + coast + duck) | 72 / 35 (3.6 / 1.8) | 97 | 99.8% | 0.3% |
| Coast trim off | 63 / 31 (3.1 / 1.6) | 100 | 99.8% | 0.2% |
| Overdrive and coast off (duck only) | 0 / 0 | 98 | 99.8% | 0.2% |

### 3.2 Phase cancellation

- **In software: impossible** [Fact]. Low and High are computed independently, and every blend is non-negative: saturating sum (`:755`), max (`:749-751`, `:797-799`), shaped merge (`:606`). Nothing subtracts anywhere in the chain.
- **Mechanically it shows up as beating, not nulls** [Inference, physics]. `SetVibration(channel, intensity)` controls drive only; each rotor's phase and speed run free.
  - Two unlocked rotors at different speeds sum to a force that beats at |f_Low − f_High|. The beat is slowest and most noticeable when the two speeds converge. That is most likely when Low is driven hard while High sits near its floor.
  - A true null cannot form: the motors sit at opposite grips, so opposed forces form a couple. The shell rocks rather than going still.
- **Exposure is small in the combat mix:** Low ≥ 0.6 while High ≤ 0.3 in 0.2–0.3% of frames (table above).

### 3.3 Frequency masking

- **The split mostly doesn't happen in combat** [Fact, simulation]. Both motors are above their floors in 99.8% of frames. The cast texture's 0.10 Low presence, lifted by the floor remap, keeps the Low motor spinning, and the swell keeps High on.
- **Ducking misses the one place it could help** [Fact]. Ducking works per role, so a High click over a Low bed gets no relief. That is the only configuration where masking relief could work, because masker and target are on different actuators, and WP3 does not act there.
- **Which motor masks which is unknown** [Unverified].
  - The brainstorm maps Low → Meissner and High → Pacinian (`brainstorm.md:53-54`). That mapping rests on rotor speeds that have never been measured (see also `docs/DOCS_COMPILATION.md` finding #34).
  - If the High rotor runs near 150–300 Hz, it is the *more* detectable motor per unit displacement. The "heavy" Low bed would then be a weaker masker than its name suggests.
  - Both hands grip one rigid shell, and the Pacinian channel has large receptive fields and spatial summation. So each motor's vibration reaches both hands, and left/right separation gives only limited masking release.

### 3.4 Clatter sources, ranked

1. **Coast-trim holes plus overdrive re-kicks** in contiguous modes. [Fact, §2.2]
2. **Overdrive on an already-spinning rotor:** 104 of 107 onsets in the combat mix. [Fact, §2.1]
3. **Frame-dependent kick length:** 33–57 ms for a 30 ms setting. [Fact, §2.1]
4. **SHAPED_YIELD truncating footfalls** (pre-existing since `8a67a43`, `Engine.lua:86`, `:808-812`). [Fact, simulation]
   - Any same-role transient, even a 0.12 tick, multiplies the shaped footfall by 0.35.
   - BOOT footfall, Low per frame, alone: `0.657 0.657 0.323 0.262 0.220 0.191 0.000`.
   - With a 0.12 Low tick on frame 2: `0.657 0.441 0.361 0.367 0.299 0.250 0.052 0.037 0.027 0.000`.
   - The second kick frame drops 33%, and there is a small rebound when the tick expires.
5. **Sub-floor release crawl:** the release passes from the floor (0.125) down to the 0.025 snap while the rotor is below breakaway. This is already known: `docs/Claudereview.md` §3.2.

**The 80 Hz send cap (`:614-621`) is harmless** [Fact / Inference]. It binds only above 80 fps. The combat mix produced 97–100 SetVibration calls per second across both channels.

---

## 4. Test coverage of WP1–WP4

All 7 suites pass, but the new tests do not discriminate the behaviour they name. [Fact from reading the asserts; not mutation-run]
- **Ducking test** (`PulseChecklist/tests/engine-test.lua:680-681`): asserts output > the steady hum. It would pass with or without ducking: role-space 0.848 ducked vs 0.9 unducked, both above 0.5.
- **S-curve tests** (`:687-689`): check a local `smoothstep` copy, never the engine's `mapValue`.
- **Coast test** (`:650-653`): checks the layer's remaining time. That confirms the trim, not what the motor receives.
- **Overdrive test** (`:627`): checks only that output exceeds 0.40.

---

## 5. Device preset notes (`Devices.lua`)

These are the notes the Xbox and other presets display. [Unverified / Inference]
- **Xbox** ("Asymmetrical Mabuchi ERM motors: 24mm heavy counterweight…"): unsourced; nothing in the repository supports the brand or dimensions.
- **DS4** ("~22g vs 30g" counterweights): implausible [Inference]. That is roughly an order of magnitude heavier than a gamepad rotor weight is likely to be, and the whole DS4 weighs about 210 g.
- **Xbox Elite** ("elevated 0.135 floor to overcome chassis mass and damping"): this gets the physics wrong [Inference].
  - Breakaway is internal to the motor (static friction, cogging), so chassis mass does not change it.
  - More chassis mass lowers the felt amplitude, which is a **gain** adjustment, not a floor adjustment.
- Every preset value remains a starting guess, not a measurement. The header at `Devices.lua:180-183` says exactly that.

---

## 6. Recommendations (nothing implemented)

1. **Ducking.** This needs a user decision; the policy reversal is still unrecorded. [Rec]
   - If the goal is a full felt step, replace same-role ducking with headroom addition, `clamp01(c + t)`.
   - If masking relief is wanted, duck **across roles**: a High transient ducks the Low bed. Give it its own release time, gate it by priority as the brainstorm specified, and exempt information-carrying textures.
2. **Overdrive.** [Rec]
   - Apply it to transients only.
   - Apply it after the attack filter, or bypass the filter during the kick.
   - Drive at full level, or at `max(boost·x, kickLevel)`.
   - Express the duration in whole frames so it is stable across frame rates.
   - Trigger on an estimated rotor state (a per-channel first-order model with a coast time constant), not on the previous frame's command.
3. **Coast trim.** Park it. [Rec]
   - The real smear is the software release tail. Address it with per-mode envelopes or a separate transient release time constant, as `docs/DOCS_COMPILATION.md` §14.1 already recommends.
   - If the trim is kept:
     - use the resolved channel's coefficient;
     - use the post-master magnitude;
     - trim only when the next state is silence;
     - never trim a step that has a contiguous successor;
     - never go below one frame.
4. **Measure before tuning.** [Rec] Tape a phone to each grip, run an accelerometer spectrum app, and run the calibration Ramp on Low and then High. Record frequency and amplitude against command for each motor. That single measurement settles:
   - the masking direction;
   - the beat risk;
   - the real breakaway floors;
   - the rotor time constants that overdrive and coast compensation depend on.
5. **Tests that discriminate.** [Rec]
   - ducking on vs off must give different results;
   - kick length at 30, 35 and 60 fps;
   - SURGE on-segment count;
   - SNAP surviving both callback orders;
   - `mapValue` with `useSCurve` through the engine.
6. **Housekeeping.** [Rec]
   - Fix the stale comment at `Engine.lua:690-691`.
   - Correct the slider description at `Devices.lua:146`.
   - Mark the preset notes as unmeasured.

---

## 7. Advantages of the changes (added 2026-09-30 on request)

Question: *are there any advantages to the changes?* Yes, but most of them sit outside the three physical models. Figures are from `synth-probe.lua` section H.

### 7.1 Clear advantages

**WP5 send cap** (`Engine.lua:614-627`) [Fact, simulation]
- In the combat mix, SetVibration calls per second:
  - 60 fps: 90 with the cap, 90 without (the cap never binds at or below 80 fps);
  - 144 fps: 109 with, 182 without (−40%);
  - 240 fps: 95 with, 247 without (−62%).
- Onsets, jumps over 0.20 and shutoffs bypass the cap, so onset latency is unchanged.
- The battery claim is unmeasured.

**Layer pool** (`Engine.lua:65-75`, `:270-278`) [Fact, from diff]
- Expired layers are recycled instead of reallocated. This fixes L2 in `docs/Claudereview.md`: two table allocations per footfall.
- Delayed `PlayMode` steps still allocate one table per step (`:502-507`), which is minor.

**Shaped kick** (`Engine.lua:713`) [Fact, from diff]
- The `dt*1.2` clamp was removed and a `kickTime` default of 0.025 added. This fixes L1 (kick length depending on frame rate) and L4 (a missing `kickTime` erroring and triggering `StopAll`).

**Boolean calibration values can now be stored** (`Database.lua:2908`) [Fact]
- `SetChannelTuning` now accepts booleans, so `useSCurve` persists. The handoff's storage objection is resolved.
- The S-curve itself is off in every preset. It works as a "quieter background textures" option. "Perceptual linearization" is the wrong label, because it compresses the low end.

**Other fixes in the same uncommitted tree** [Fact from grep only; not reviewed in this critique]
- H2: `Panel.Refresh()` calls in `Spec.lua` are now 0.
- H1: gallop guard at `Locomotion.lua:619`.
- M3: `InCombatLockdown` gates at `Database.lua:2388` and `:2405`.
- M5: `DB_VERSION = 9`.
- All 7 suites pass. These are probably the most valuable part of the diff but need their own review.

### 7.2 Mixed

**Overdrive on its own**
- Isolated taps from silence, model with τm assumed at 40/85 ms. Peak rotor speed gain:

  | Mode | Gain |
  |---|---|
  | BLIP | +29% |
  | IMPACT | +13% / +15% |
  | THUMP | +4% / +7% |

- A real but modest gain for quiet scenes such as questing and menus.
- In busy combat, 104 of 107 kicks land on an already-spinning rotor, so there the gain turns into overshoot (§2.1). [Inference, model]

**Xbox preset retune** [Inference]
- Low transient attack 25→18 ms and Low release 60→50 ms should make Xbox taps crisper.
- It applies only after the preset is re-applied, and `ApplyDevicePreset` overwrites the player's Ramp calibration (`Database.lua:2974-2997`).

### 7.3 Little or no advantage

**Overdrive plus coast trim** [Inference, model]
- The trim cancels the overdrive gain:
  - IMPACT: −23% / −29% peak rotor speed, *worse* than with neither;
  - BLIP: +5% / +0%;
  - THUMP: +2% / −3%.

**Coast trim**
- Its only upside is shorter single taps at about the same peak (SNAP: 3 frames sampled → 1 at 60 fps).
- Footfalls, the brainstorm's motivating case ("footsteps blur", Innovation 2), are excluded by `not shape` (`Engine.lua:293`).

**Ducking**
- Its only upside is slightly less total drive during overlaps: at most `0.1625·c` below the unducked mix.
- The transient clarity loss is shown in §1.

### 7.4 Possible regression

**DS4 preset release shortened** [Fact / Inference]
- The DS4 preset release changed from 60/35 ms (HEAD `ERM_LOW`/`ERM_HIGH`) to 45/28 ms.
- `docs/DOCS_COMPILATION.md` §14.1 found that the DS4's weighty impacts come from that slow release, and the user rated the DS4 as feeling best. Shorter tails may remove that weight.

### 7.5 Keep / rework / park

| Keep | Rework | Park or decide |
|---|---|---|
| WP5 cap, layer pool, shaped-kick fix, boolean storage, H1/H2/M3/M5 (after review) | Overdrive: transient-only, after the attack filter, framed in whole frames, or leave it off | Coast trim; ducking (policy decision); the DS4 release change |

---

## 7.6 Live report: "vibrations increased" (2026-09-30)

**Question:** why did vibrations increase? Answered read-only by comparing the game's current SavedVariables (`PulseHaptics.lua`, saved 2026-09-30 00:59) with WoW's automatic backup (`PulseHaptics.lua.bak`, 2026-09-29 10:44).
- **Last character played:** Eri (Eri-Dairy). Its `config-cache.wtf` and per-character SavedVariables were written at 00:59.
- **Answer:** the increase comes from **settings**, plus part of the mode retune. It does **not** come from the new physics code.

### 7.6.1 The new physics code is not the cause [Fact]

- **Overdrive and coast trim are inactive.** `channelTuning` still holds the old Xbox values and none of the new keys, so the engine uses `CHANNEL_DEFAULTS` (boost 1.0, duration 0, `coastCoeff` 0).
- **Ducking can only lower output** (§1.2).
- The migration ran (`version` 7 → 9). The only other `channelTuning` changes were:
  - LTrigger/RTrigger rows removed;
  - `useSCurve = false` added.

### 7.6.2 Setting changes between the two saves [Fact]

These could only have been made through the UI: the migrations do not touch them. Whether they were deliberate is for the user to confirm.

**1. Motor schema: Standard → Inverted** (global)
- Every "high" role now drives the **heavy Low motor**, and every "low" role drives the light High motor.
- That moves the light, sharp content onto the heavy motor:
  - TAP (about 50 cues after the retune);
  - TICK (24);
  - CHIME's bright step;
  - DEFLECT;
  - the cast swell;
  - footfall contact clicks.
- That content now also uses the Low channel's slower tuning (release 60 ms, transient attack 25 ms), so it lasts longer.
- The only writers of `defaultHapticSchema` are the settings dropdowns (`Spec.lua:522` and `:1557`). The v8 migration only maps retired trigger schemas to `standard` (`Database.lua` `_MigrateRetiredSchemas`).

**2. Eri's profile: Immersion: Caster → Immersion: Ranged** (`charProfile`)

| | Old (Caster) | New (Ranged) |
|---|---|---|
| Master | 0.50 | 1.00 |
| Cues on in both profiles | 65 | 65, **all 2.00× stronger** |
| Cues switched | — | 35 newly on, 19 now off |
| Footfalls (`locomotion`), effective scale | 0.075 | 1.000 (13×) |
| Cast texture (`castTexture`), effective scale | 0.025 | 0.450 (18×) |
| Heartbeat (`lowHealthTexture`), effective scale | 0.50 | 1.15 |

**3. The Immersion: Ranged profile itself changed**
- Master 0.70 → 1.00.
- Footfall intensity 0.15 → 1.0.
- Cast texture intensity 1 → 0.45.
- Master 1.00 is not the curated default (0.75, `Database.lua` profile metadata), so the migration did not set it.
- The migration's curation step only stamped `__curatedVersion = 1`; no profile's cue on/off set changed.

### 7.6.3 The mode retune (uncommitted `Modes.lua`) [Fact]

Peak relIntensity, before → after:

| Mode | Change | Effect |
|---|---|---|
| HEAVY (6 cues: stun, aggro, death, resource capped) | High only 1.0 → both motors 1.0 | adds the heavy motor at full strength for 450 ms |
| DEFLECT | 0.50 → 0.95 | stronger |
| TICK | 0.20 → 0.28 | stronger |
| BLIP | 0.22 → 0.48 | stronger |
| CLICK | 0.30 → 0.38 | stronger |
| BURST | 0.65 → 1.00 | stronger |
| TAP | Low 0.60 × 120 ms → High 0.55 × 55 ms | lighter |
| STUTTER | shorter | lighter |
| THUD | High step shortened | lighter |

Summed over the modes in use, total drive is about unchanged. The per-mode changes are large.

### 7.6.4 To restore the previous feel [Rec]

In the Pulse settings:
- set the vibration schema back to **Standard**;
- give Eri **Immersion: Caster** again, or lower Immersion: Ranged's master and footfall intensity.

The mode retune can only be undone in code (a revert of `Modes.lua`), which was not touched here.

## 7.7 Swim texture "electric buzz": check of three proposed remedies (2026-09-30)

**Source:** three remedies pasted from another session, each checked against `Modules/Movement.lua:288-356`, `Core/Waves.lua:107-133`, the `Core/Registry.lua` swimTexture tunables and the live SavedVariables.

**Simulation setup:** full swim speed, stroke 0.95 Hz, live Xbox channel tuning (old values), Eri's profile (Immersion: Ranged, master 1.00, swimTexture stock). Values are what the motor is told:
- **swing** = (max − min) / (max + min);
- **off** = the share of frames sent exactly 0.

The simulation script is in the session scratchpad (`swim.lua`), not in the repo.

### 7.7.1 Facts

- **The stroke is on the "high" role by default** (`separateMotors` = 1, `Movement.lua:347-349`).
- **Your current Inverted schema already puts it on the heavy Low motor.** The remedies assume Standard.
- **"In water" (`waterTexture`) is off** in both Immersion: Ranged and Immersion: Ranged actual. There is currently no buoyancy layer to combine the stroke with.
- **The floor pins the stroke above zero.** The cue itself swings 49% (0.045 to 0.134), but the floor lift shrinks that to 21% on the High motor and 17% on the Low motor, and the motor is never off.
- **The `strokeDepth` slider cannot reach zero.** Its maximum is 1.0. The waveform's composite minimum is −0.993, so at depth 1.0 the trough is still 0.007 × peak, and the floor lifts it to 0.104.

### 7.7.2 Remedy by remedy

| Remedy | Standard schema | Inverted schema (current) |
|---|---|---|
| Stock | High 0.143–0.218, swing 21%, never off | Low 0.164–0.232, swing 17%, never off |
| 1. `separateMotors = 0` (route to low) | moves to Low: 0.164–0.232, swing 17% | moves to the **light High** motor (the opposite of the intent): 0.143–0.218 |
| 2. depth 1.0 (slider maximum) | High 0.104–0.242, swing 40%, never off | — |
| 2. depth 1.0 + asymmetry 0 (sliders only) | High 0.065–0.276, swing 62%, never off | — |
| 2. depth 1.6 (needs a code change) | High 0–0.273, swing 100%, off 13% | — |
| 3. High floor 0.10 → 0.05 | High 0.096–0.175, swing 29% | no effect on the stroke, which is on Low |

For comparison, Eri's old profile (Immersion: Caster, master 0.50) gave High 0.122–0.159 with a 13% swing.

### 7.7.3 Verdict [Inference / Rec]

**Remedy 2 is the only one that attacks the cause** (the floor pinning the trough).
- Within the sliders: depth 1.0 with asymmetry 0 gives a 62% swing.
- A real coast between strokes needs depth > 1 (a code change to the Registry maximum) or the dead-zone curve that replaces the linear floor lift (DOCS #29 H7).
- Expect a small restart kick at each stroke when the motor re-crosses its breakaway point.

**Remedy 1 depends on the schema.** It works as described only under Standard. Even then, it lands on a heavier floor (17% swing), and with "In water" off there is nothing to merge with.

**Remedy 3 is risky.**
- A floor below the true breakaway lets the trough stall the motor, which risks stall-and-restart chatter.
- It changes every continuous cue on the High motor.
- Under the Inverted schema it does not touch the stroke at all.

**Decide the schema first**, because it swaps which motor remedies 1 and 3 act on. [Unverified] Which schema was active when the "electric buzz" was felt.

## 7.8 Cast texture: "very strong despite lowering sliders" (2026-09-30)

**Save used:** the SavedVariables from 01:31, which show the user's newest changes:
- schema back to **Standard**;
- Eri's profile (Immersion: Ranged, overall intensity 1.00) with castTexture intensity 0.05, presence 0.03, swell peak 0.15 and channel hum 0.05.

**Simulation:** one 2.0 s cast on the live channel tuning (Low floor 0.12, High floor 0.10). The script is in the session scratchpad (`cast.lua`).

| Slider state | Low motor told | High motor told | Motors on until |
|---|---|---|---|
| Now (0.05 / 0.03 / 0.15) | 0.110–0.121 | 0.098–0.106 | 2.43 s |
| At 00:59 (0.45 / 0.06 / 0.45) | 0.131–0.144 | 0.115–0.278 | 2.45 s |
| Stock (1 / 0.10 / 0.70), overall intensity 1.0 | 0.189–0.208 | 0.154–0.717 | 2.47 s |

### 7.8.1 Cause [Fact]

**The floor lift is the cause.** It is already known as CR-008 and DOCS §4.1 "Floor linear lift → dead-zone curve" (OPEN).
- `mapValue` (`Engine.lua:539-542`) remaps every non-zero request to `floor + (1 − floor)·v`.
- At the current sliders the cast asks for 0.0015 (Low) and at most 0.0075 (High). The motors are nonetheless held at about their floors (0.12 and 0.10) for the whole cast.
- Cutting the sliders by about 95% lowered the Low drive by only about 40%. The remaining level is the floor, and no slider above 0 can remove it.

**The cast texture runs for the whole cast, plus about 0.43 s afterward.** That is `REFRESH_WINDOW` 0.35 s plus the release. Back-to-back casting is therefore close to continuous vibration.

**Channels behave the same way.** `MicroFlutter(channelHum)` (`Waves.lua:178-184`) keeps any non-zero hum alive, and the floor then lifts it to about 0.10.

### 7.8.2 Contributing factors

- **The floors were never measured.** 0.12 and 0.10 are exactly the old Xbox preset values, so the Ramp was never run. If the real breakaway is lower, a 0.12 drive spins the heavy motor at a clearly felt speed. [Inference / Unverified]
- **Overall intensity is 1.00** in this profile (it was 0.70 before 2026-09-30).
- **When cast timestamps are secret, the swell slider is ignored.** In that case the code holds `presence × 1.5` on High instead (`Combat.lua:478`). [Unverified] Whether player cast timestamps are ever secret.

### 7.8.3 What the user can do without code [Rec]

- Set **Cast presence** and **Cast swell peak** to exactly **0**, and **Channel hum** to 0 for channels. Exactly 0 is the only value that escapes the floor. Or turn the cue off.
- Or run **Ramp** on both motors and enter the measured floors. That lowers the minimum level of every cue.
- The real fix is the dead-zone curve (CR-008 (b)), which is a code change.

---

## 8. Coverage ledger

**Read in full:**
- `PulseHaptics/Core/Engine.lua` (1106 lines) and its uncommitted diff
- `PulseHaptics/Core/Devices.lua` (538 lines) and its uncommitted diff
- `docs/claudehandoff.md`
- `docs/Claudereview.md`

**Read in part:**
- `PulseHaptics/Core/Modes.lua`: 1-120 read; 120-340 grepped for steps
- `PulseHaptics/Core/Database.lua`: 2890-3030 (channel tuning, `ApplyDevicePreset`, epsilon)
- `PulseHaptics/Modules/Health.lua`: 42-45, 105-148, 255-290
- `PulseHaptics/Modules/Combat.lua`: cast texture, 440-505 by grep
- `PulseHaptics/Modules/Locomotion.lua`: shape table, 460-511
- `PulseChecklist/tests/engine-test.lua`: 600-700
- `docs/brainstorm.md`: 40-160 and 286-300, plus grep
- `docs/CODE_REVIEW.md` and `docs/DOCS_COMPILATION.md`: grep for ducking, overdrive, coast and masking, to check overlap
- Live SavedVariables: the `channelTuning` block and master intensities

**Run:**
- `./scripts/test.sh`: 7/7 pass, luacheck 0/0.
- `synth-probe.lua` (repo root), sections A–H.

**Not read:**
- `docs/implementationplan.md`
- the rest of `docs/brainstorm.md`
- `PulseHaptics/Core/Waves.lua`
- the other modules
- the calibration UI page
- `Core/Schemas/` other than `Standard.lua`

**Not verified:**
- All physiology figures (textbook recall, no citation lookup this session).
- All rotor speeds, time constants and frequencies (no hardware measurement).
- WoW's ordering of `C_Timer` callbacks and events relative to `OnUpdate`.
