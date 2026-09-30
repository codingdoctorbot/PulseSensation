# 3. Static transfer: what each profile does to a level

This section ignores time. It asks what command, and what steady strength, a given mode level
produces under each profile. Section 4 adds timing.

Reproduce: `python3 haptics-model/model.py transfer`

## 3.1 Command sent for each authored level

Transient path, master 0.7, cue intensity 1.0, no overdrive. The column header is the mode's
peak relIntensity.

| Profile | Ch | CLICK 0.20 | TICK 0.35 | TAP 0.55 | DOUBLE_TAP 0.60 | THUMP 0.85 | HEAVY 1.00 |
|---|---|---|---|---|---|---|---|
| default | both | 0.140 | 0.245 | 0.385 | 0.420 | 0.595 | 0.700 |
| xbox | both | 0.198 | 0.308 | 0.446 | 0.479 | 0.642 | 0.737 |
| xbox_elite | Low | 0.236 | 0.355 | 0.502 | 0.538 | 0.710 | 0.809 |
| ds4 | both | 0.204 | 0.311 | 0.447 | 0.480 | 0.642 | 0.736 |
| 8bitdo | both | 0.210 | 0.318 | 0.454 | 0.487 | 0.648 | 0.741 |
| dualsense | Low | 0.182 | 0.300 | 0.457 | 0.496 | 0.692 | 0.810 |
| switchpro | both | 0.227 | 0.356 | 0.528 | 0.571 | 0.786 | 0.915 |
| steamdeck | Low | 0.244 | 0.374 | 0.539 | 0.580 | 0.777 | 0.892 |
| steamcontroller2 | Low | 0.184 | 0.295 | 0.444 | 0.481 | 0.667 | 0.778 |
| steamcontroller | Low | 0.205 | 0.313 | 0.458 | 0.494 | 0.675 | 0.784 |
| lra_classic | Low | 0.260 | 0.383 | 0.539 | 0.577 | 0.760 | 0.867 |

Every preset raises quiet levels, through floor and gamma below 1, and most raise loud levels
too, through gain. `model.py` prints the High-channel rows as well.

## 3.2 The intensity ladder: how far apart light and heavy modes feel

Steady strength on the High channel, in dB relative to HEAVY. An ERM's strength is roughly
quadratic in command and an LRA's is linear (§2), so the same commands give very different
ladders:

| Hardware | Profile | CLICK | TICK | TAP | THUMP | HEAVY | CLICK→HEAVY | THUMP vs HEAVY |
|---|---|---|---|---|---|---|---|---|
| ERM | default | −32.1 | −20.0 | −11.2 | −3.0 | 0 | 32.1 dB | 3.0 dB |
| ERM | xbox | −25.4 | −16.4 | −9.3 | −2.5 | 0 | 25.4 dB | 2.5 dB |
| ERM | xbox_elite | −23.4 | −15.3 | −8.8 | −2.4 | 0 | 23.4 dB | 2.4 dB |
| ERM | ds4 | −24.8 | −16.2 | −9.3 | −2.5 | 0 | 24.8 dB | 2.5 dB |
| ERM | 8bitdo | −24.2 | −15.9 | −9.1 | −2.5 | 0 | 24.2 dB | 2.5 dB |
| LRA | default | −14.0 | −9.1 | −5.2 | −1.4 | 0 | 14.0 dB | 1.4 dB |
| LRA | dualsense | −12.9 | −8.6 | −5.0 | −1.4 | 0 | 12.9 dB | 1.4 dB |
| LRA | switchpro | −12.1 | −8.2 | −4.8 | −1.3 | 0 | 12.1 dB | 1.3 dB |
| LRA | steamdeck | −12.5 | −8.4 | −4.9 | −1.3 | 0 | 12.5 dB | 1.3 dB |
| LRA | steamcontroller2 | −12.5 | −8.4 | −4.9 | −1.3 | 0 | 12.5 dB | 1.3 dB |
| LRA | steamcontroller | −12.2 | −8.3 | −4.8 | −1.3 | 0 | 12.2 dB | 1.3 dB |
| LRA | lra_classic | −10.8 | −7.2 | −4.2 | −1.2 | 0 | 10.8 dB | 1.2 dB |

**What this shows**

- **An LRA pad gets about half the dB range of an ERM pad from the same cues.** On an LRA,
  CLICK is only 12–14 dB below HEAVY. On an ERM it is 24–32 dB below. Cues written to "stay in
  the background", such as damageTaken (TICK at 0.3), are therefore relatively much more
  prominent on a DualSense, Switch Pro or Steam Deck than on an Xbox pad.
- **The LRA presets all keep gamma at 1.0** (Steam Deck Low: 0.90), so none of them corrects
  for this. A gamma around 1.6–2.0 on LRA channels would roughly match an ERM's quadratic
  ladder. This depends on the OS/driver passing the rumble value through linearly, which is
  not verified (§2.2).
- **THUMP vs HEAVY differ by only 1.2–1.4 dB on LRA pads.** That is about one just-noticeable
  difference for vibration intensity, so the two modes are told apart by duration (140 ms vs
  450 ms), not by strength. That still works, but only because the durations differ.
- On ERM pads, the presets compress the ladder by 7–9 dB compared with `default`. That is the
  intended cost of lifting quiet cues, and it is not a problem in itself. §3.4 shows the
  problem is that they now don't lift quiet cues *enough*.

## 3.3 Gain clipping at the top of the range

Gain is applied before clipping, so a channel with gain > 1 sends 1.0 for every input above
`1/gain`. THUMP (0.85) and HEAVY (1.0) then become the same command.

**Sustained part** of a pulse (no overdrive): THUMP equals HEAVY once master reaches

| Profile | Channel | Gain | Master at which THUMP = HEAVY |
|---|---|---|---|
| switchpro | Low and High | 1.30 | **0.90** |
| steamdeck | Low | 1.25 | 0.94 |
| lra_classic | Low | 1.20 | 0.98 |
| all others | | ≤ 1.15 | never (needs master > 1.0) |

**Onset**, during the ERM overdrive kick: the kick multiplies by 1.25 before gain, so the first
25 ms clip much earlier.

| Profile | master 0.7 | master 0.85 | master 1.0 |
|---|---|---|---|
| default | 0.59 vs 0.70 | 0.72 vs 0.85 | 0.85 vs 1.00 |
| xbox, ds4, 8bitdo | 0.78 vs 0.89 | 0.92 vs 1.00 | **same** |
| xbox_elite | 0.85 vs 0.97 | 0.99 vs 1.00 | **same** |
| switchpro, steamdeck | 0.79 vs 0.91 | 0.94 vs 1.00 | **same** |
| lra_classic | 0.91 vs 1.00 | **same** | **same** |

At the default master of 0.7 nothing collapses. The problem appears for players who turn master
intensity up, which is also when they are asking for *more* contrast. The worst cases are
**Switch Pro** (sustained collapse from master 0.90) and **lra_classic** (its onset collapses
from master 0.85).

## 3.4 Light cues on ERM pads: where the floor stops being enough

The census runs every one of the 175 cues in `Core/Registry.lua` through the engine and the ERM
model, at its shipped intensity and master 0.7, and counts the cues that produce **no
detectable vibration** (peak E below −40 dB). Because the true breakaway is unknown, it is swept
from 0.03 to 0.15. Each cell shows imperceptible cues out of 175, with the number of those that
are on by default (out of 50) in brackets.

| Profile | u_b 0.03 | u_b 0.06 | u_b 0.10 | u_b 0.15 |
|---|---|---|---|---|
| default | 15 (6) | 15 (6) | 16 (6) | 19 (6) |
| **xbox, current** | **11 (4)** | **11 (4)** | 15 (6) | 15 (6) |
| xbox, floors before 72950f5 | 0 (0) | 4 (2) | 9 (3) | 11 (4) |
| **ds4, current** | **10 (3)** | **11 (4)** | 11 (4) | 15 (6) |
| ds4, floors before 72950f5 | 1 (0) | 4 (2) | 9 (3) | 11 (4) |
| **8bitdo, current** | **9 (3)** | **11 (4)** | 11 (4) | 15 (6) |
| 8bitdo, floors before 72950f5 | 0 (0) | 1 (0) | 4 (2) | 11 (4) |
| **xbox_elite, current** | **4 (2)** | **9 (3)** | 11 (4) | 15 (6) |
| xbox_elite, floors before 72950f5 | 0 (0) | 0 (0) | 4 (2) | 9 (3) |

The cues lost on the Xbox preset at u_b = 0.06, compared with the same cue on a DualSense:

| Cue | Mode | Intensity | On by default | Xbox command | Xbox strength | DualSense strength |
|---|---|---|---|---|---|---|
| uiNavigate | TICK | 0.35 | **yes** | 0.147 | −43 dB | −19 dB |
| radialTick | TICK | 0.30 | **yes** | 0.131 | −46 dB | −20 dB |
| popupHidden | CLICK | 0.50 | **yes** | 0.127 | −51 dB | −21 dB |
| panelClose | CLICK | 0.50 | **yes** | 0.127 | −51 dB | −21 dB |
| damageTaken | TICK | 0.30 | no | 0.131 | −46 dB | −20 dB |
| healReceived | TICK | 0.30 | no | 0.131 | −46 dB | −20 dB |
| softEnemyChanged | TICK | 0.30 | no | 0.131 | −46 dB | −20 dB |
| softFriendChanged | TICK | 0.30 | no | 0.131 | −46 dB | −20 dB |
| softTargetInteraction | CLICK | 0.45 | no | 0.117 | −53 dB | −21 dB |
| selfCastInstant | CLICK | 0.50 | no | 0.127 | −51 dB | −21 dB |
| xpGained | BLIP | 0.40 | no | 0.192 | −43 dB | −15 dB |

**Why a floor above breakaway still isn't felt.** The floor is described as "the smallest
value that makes this motor actually spin". But a motor that is only just spinning is almost
still: at a command of 0.13, the High motor settles at about 10% speed, which is about 1% of
full-scale force at roughly 15 Hz. On top of that, TICK and CLICK last 30–40 ms, so the motor
reaches only 40–55% of even that speed (§2.1). The floor has to cover **perception** of a short
pulse, not only **breakaway**. Those are different thresholds, and the perception threshold is
higher.

This also applies to the Ramp calibration (see `CALIBRATION_REVIEW.md`). The ramp holds each
step for 0.4 s, and the person reports the first level they feel. A held 0.4 s vibration is
felt at a lower level than a 30 ms click, so even an accurately measured ramp floor will be
too low for CLICK and TICK on an ERM.

**Robustness.** The result depends on the ERM strength law E ≈ w² (§2.1), which is basic
physics for an eccentric mass, and on the −40 dB detection threshold. Using −46 dB instead
would restore TICK at 0.3–0.35, but not the CLICK cues at −51 to −53 dB.

## 3.5 Continuous textures and the soft floor

Command for quiet texture inputs (after master) on the Low channel:

| Profile | floor | knee | 0.005 | 0.010 | 0.020 | 0.030 | 0.050 | 0.080 |
|---|---|---|---|---|---|---|---|---|
| xbox | 0.025 | 0.020 | 0.021 | 0.041 | 0.056 | 0.070 | 0.095 | 0.131 |
| xbox_elite | 0.040 | 0.020 | 0.037 | 0.061 | 0.077 | 0.093 | 0.122 | 0.162 |
| ds4 | 0.040 | 0.020 | 0.024 | 0.051 | 0.068 | 0.081 | 0.105 | 0.139 |
| 8bitdo | 0.040 | 0.020 | 0.027 | 0.055 | 0.071 | 0.084 | 0.109 | 0.144 |
| lra_classic | 0.065 | 0.033 | 0.028 | 0.064 | 0.100 | 0.115 | 0.144 | 0.184 |

- DRIFT (0.08 × master 0.7 = 0.056) sends 0.10–0.13 on ERM presets. That can start the motor
  if breakaway is below about 0.10, but the steady strength is only **−41 to −48 dB**, at or
  below the detection threshold. At half intensity it drops to −51 to −62 dB. **On an ERM,
  DRIFT is effectively silent.** Today this only affects the mode-preview button, because no
  real trigger uses DRIFT (`Core/Modes.lua`). Any future texture authored at DRIFT's level
  would be silent on ERM pads.
- On an ERM, the soft floor does not produce the "whisper-quiet" fade its comment describes
  (`Core/Engine.lua:529-533`). A command between 0 and breakaway produces **no motion at all**.
  On an ERM, the knee only decides where a fading texture cuts out, and because of hysteresis
  the motor keeps turning down to its running-friction level and then stops abruptly. This is
  harmless, but "fade to whisper" only happens on an LRA.

## 3.6 Section summary

| # | Effect | Who is affected | Severity |
|---|---|---|---|
| S1 | Light cues (TICK 0.3–0.35, CLICK 0.45–0.5, BLIP 0.4) are imperceptible on ERM pads. 4 of them are on by default. This is a regression from `72950f5`, which lowered the ERM floors. | Xbox, DS4, 8BitDo, Elite | **High**: cues silently disappear |
| S2 | LRA pads get about half an ERM's dB range. Background cues become relatively prominent, and the gap between heavy modes is ~1 JND. | All LRA presets | Medium: hierarchy flattens |
| S3 | Gain > 1 collapses THUMP and HEAVY when master is turned up | Switch Pro (≥ 0.90), Steam Deck Low (≥ 0.94), lra_classic (onset ≥ 0.85) | Low–medium: only at high master |
| S4 | The soft-floor fade does not exist on ERM hardware; the texture cuts out instead | ERM presets | Low: cosmetic |
