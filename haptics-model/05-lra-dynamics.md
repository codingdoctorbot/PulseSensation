# 5. LRA hardware: the selected modes over time

The same modes are run through the engine and the LRA model from §2.2, for every LRA profile.
Conditions: nominal hardware (τ_env 10–12 ms), 60 fps, master 0.7, cue intensity 1.0.

Reproduce: `python3 haptics-model/model.py lra`

On an LRA, every mode is detectable within a millisecond, because the model leaves out transport
latency (§2.4). The onset table therefore shows **time to 50% of peak** instead.

## 5.1 Baseline results

**Peak strength** (dB re full scale, both channels summed; above 0 means both channels are
contributing):

| Profile | TAP | DOUBLE_TAP | TICK | CHIME | THUD | STUTTER | CLICK | HEAVY |
|---|---|---|---|---|---|---|---|---|
| default | −8 | −8 | −13 | −8 | +1 | −4 | −18 | +3 |
| dualsense | −8 | −6 | −11 | −7 | +2 | −4 | −16 | +4 |
| switchpro | −6 | −5 | −9 | −5 | +4 | −2 | −13 | +5 |
| steamdeck | −7 | −5 | −11 | −6 | +3 | −4 | −15 | +4 |
| steamcontroller2 | −7 | −6 | −11 | −7 | +2 | −4 | −15 | +4 |
| steamcontroller | −8 | −6 | −11 | −7 | +2 | −4 | −16 | +3 |
| lra_classic | −6 | −5 | −9 | −5 | +3 | −2 | −13 | +4 |

**Time to 50% of peak** (ms):

| Profile | TAP | DOUBLE_TAP | TICK | CHIME | THUD | STUTTER | CLICK | HEAVY |
|---|---|---|---|---|---|---|---|---|
| default | 11 | 13 | 10 | 18 | 12 | 10 | 9 | 12 |
| dualsense, switchpro, steamdeck, steamcontroller2, steamcontroller | 7 | 9 | 7 | 9–11 | 8 | 7 | 7 | 8 |
| lra_classic | 9 | 19 | 9 | 21 | 13 | 9 | 9 | 14 |

**Tail** (ms felt after the authored end):

| Profile | TAP | DOUBLE_TAP | TICK | CHIME | THUD | STUTTER | CLICK | HEAVY |
|---|---|---|---|---|---|---|---|---|
| default | 93 | 109 | 76 | 85 | 109 | 107 | 52 | 107 |
| dualsense | 55 | 81 | 49 | 47 | 71 | 58 | 37 | 66 |
| switchpro | 67 | 95 | 61 | 59 | 85 | 76 | 43 | 80 |
| steamdeck | 65 | 98 | 59 | 57 | 87 | 68 | 40 | 87 |
| steamcontroller2 | 61 | 84 | 50 | 54 | 74 | 64 | 39 | 73 |
| steamcontroller | 77 | 123 | 63 | 69 | 113 | 80 | 51 | 115 |
| lra_classic | 106 | 171 | 90 | 99 | 161 | 109 | 69 | 165 |

**Dip between pulses** (dB; ≥ 12 crisp, 6–12 soft, < 6 fused; ≥ 40 means true silence in the gap):

| Profile | DOUBLE_TAP | CHIME | STUTTER |
|---|---|---|---|
| default | ≥ 40 | 30 | 14 |
| dualsense | ≥ 40 | ≥ 40 | 38 |
| switchpro | ≥ 40 | ≥ 40 | 24 |
| steamdeck | ≥ 40 | ≥ 40 | 29 |
| steamcontroller2 | ≥ 40 | ≥ 40 | 32 |
| steamcontroller | ≥ 40 | 22 | 19 |
| lra_classic | 21 | 15 | 14 |

### Timing: the LRA presets work well

- **Every rhythm is crisp on every LRA preset.** The native presets (dualsense, switchpro,
  steamdeck, steamcontroller2) leave the gaps between pulses nearly or fully silent. Their short
  software times (5 ms transient attack, 10–20 ms release) suit an actuator that responds
  within about 10 ms.
- **They are clearly better than `default` on the same hardware.** Tails are 10–50 ms shorter,
  STUTTER's dips are 10–24 dB deeper, and onsets are 4–9 ms faster.
- **`steamcontroller`** is slower on purpose (40 ms Low attack, 30 ms release) to avoid housing
  rattle. It stays crisp everywhere (STUTTER 19 dB, CHIME 22 dB), so that trade-off costs
  nothing noticeable.
- **`lra_classic`** puts ERM inertia on a voice coil on purpose. Its tails are the longest
  (up to 171 ms) and its dips the shallowest (14–21 dB), but everything is still crisp at the
  nominal actuator speed. This is where software ERM-style smoothing belongs, unlike on a
  real ERM (§4.2).

`default` is not an LRA preset, but on an LRA it behaves reasonably, like a slightly soft
native preset.

### Envelopes

10 ms per character, −40 dB (blank) to 0 dB (█):

```
CLICK      authored    ███··························
           default     ▄▄▅▅▄▄▃▃▁
           dualsense   ▅▅▅▅▄▃▂
           steamcontro ▅▅▅▅▅▄▃▂▁
           lra_classic ▅▆▆▆▆▅▅▄▃▂

STUTTER    authored    ████······████······████······████··························
           default     ▆▇▇███▇▇▆▅▇▇▇███▇▇▆▅▇▇▇███▇▇▆▅▇▇▇███▇▇▆▅▅▄▄▃▂
           dualsense   ▇█████▆▅▄▂▇█████▆▅▄▂▇█████▆▅▄▂▇█████▆▅▄▂
           steamcontro ▇▇████▇▆▆▅▇▇████▇▆▆▅▇▇████▇▆▆▅▇▇████▇▆▆▅▄▂
           lra_classic ▇█████▇▇▆▆▇█████▇▇▆▆▇█████▇▇▆▆▇█████▇▇▆▆▅▅▄▃▂

CHIME      authored    ██████████········██████████··························
           default     ▅▆▆▆▇▇▇▇▇▇▇▆▆▅▅▄▃▃▅▆▇▇▇▇▇▇▇▇▇▇▆▅▅▄▄▃▁
           dualsense   ▆▇▇▇▇▇▇▇▇▇▇▆▅▄▃▁  ▆▇▇▇▇▇▇▇▇▇▇▆▅▃▂
           steamcontro ▆▇▇▇▇▇▇▇▇▇▇▇▆▆▅▅▄▃▆▇▇▇▇▇▇▇▇▇▇▇▆▅▄▃▂
           lra_classic ▅▆▇▇▇▇▇▇▇▇▇▇▇▆▆▆▅▅▆▇▇███▇▇▇▇▇▇▇▆▅▅▄▄▃▂
```

On an LRA, even a 30 ms CLICK is felt for 60–100 ms (to −40 dB). That is frame rounding
(30 → 33 ms), plus the software release, plus the coil ringing down. It is short enough to
still read as a click.

## 5.2 Strength: where the LRA presets fall short

Timing is fine. The problems are in level, and they come from §3.

### L1: The intensity ladder is flattened, and gamma 1.0 leaves it that way

An LRA's strength is linear in the command, while an ERM's is roughly quadratic. With gamma 1.0,
the whole vocabulary on an LRA spans about 13 dB, against about 25 dB on an Xbox pad (§3.2). The
**absolute** difference is even larger: TICK peaks at −11 dB on a DualSense and −25 dB on an
Xbox pad, and CLICK at −16 dB against −38 dB. A cue written to stay in the background, such as
damageTaken (TICK 0.3), sits at −20 dB on a DualSense, only 5 dB below an ERM pad's DOUBLE_TAP
(−15 dB). On an ERM pad the same cue is not felt at all (§3.4).

What-if: gamma on the DualSense preset (High channel, steady strength relative to HEAVY):

| Variant | CLICK | TICK | TAP | THUMP | HEAVY | Range | Weakest cue | Cues below −30 dB |
|---|---|---|---|---|---|---|---|---|
| dualsense (gamma 1.0) | −12.9 | −8.6 | −5.0 | −1.4 | 0 | 12.9 dB | −21 dB | 0 |
| gamma 1.4 | −17.1 | −11.7 | −6.8 | −1.9 | 0 | 17.1 dB | −27 dB | 0 |
| gamma 1.8 | −20.4 | −14.5 | −8.7 | −2.4 | 0 | 20.4 dB | −30 dB | 4 |
| *xbox on ERM, for reference* | −25.4 | −16.4 | −9.3 | −2.5 | 0 | 25.4 dB | *not felt* | — |

**Gamma around 1.4–1.6 on LRA channels** brings the ladder most of the way to an ERM's while
keeping every shipped cue at −30 dB or stronger, well above the −40 dB detection threshold.

> **Caveat.** This assumes the OS/driver passes the rumble value to the actuator linearly
> (§2.2). If a driver already applies its own curve, raising gamma would go too far. A quick
> check on a real pad would settle it: fire CLICK and HEAVY and compare how different they feel
> with an Xbox pad and with a DualSense.

### L2: Gain collapses the top of the range at high master

From §3.3: the Switch Pro (gain 1.30) sends identical THUMP and HEAVY commands from master 0.90,
and the Steam Deck Low channel (1.25) from master 0.94. The time behaviour doesn't change this.

### L3: Textures are far stronger on LRA pads than on ERM pads

| Hardware | HUM steady | DRIFT steady |
|---|---|---|
| ERM presets (§4.4) | −24 to −28 dB | **not felt** |
| LRA presets | −10 to −13 dB | −16 to −21 dB |

DRIFT is described as "a barely-there fade, for the quietest ambient onset". On an LRA it is as
strong as a background cue like damageTaken (−20 dB). Only the preview button uses it today, but
the real textures (swim, glide, cast, stealth, low health) follow the same rule: **an LRA pad
plays a mid-level texture like HUM 11–18 dB stronger than an ERM pad does, and a quiet one goes
from silent to clearly felt.** The gamma change in L1 narrows this, because quiet continuous
inputs fall further (and pass through the soft-floor knee).

### Continuous attack times

| Profile | HUM 90% rise | HUM felt after the state ends |
|---|---|---|
| default | 177 ms | 399 ms |
| dualsense | 45 ms | 376 ms |
| switchpro | 55 ms | 389 ms |
| steamdeck | 87 ms | 391 ms |
| steamcontroller2 | 55 ms | 378 ms |
| steamcontroller | 100 ms | 414 ms |
| lra_classic | 177 ms | 449 ms |

These all follow each preset's stated intent: fast fade-ins on native voice coils, slower ones
where rattle or ERM imitation is the goal. The ~0.4 s linger after the state ends is the
engine's 350 ms `REFRESH_WINDOW`, which is the same for every profile (§4.4).

## 5.3 Sensitivity

### Actuator speed (τ_env 5 ms and 25 ms)

| Actuator | Profile | DOUBLE_TAP dip | CHIME dip | STUTTER dip | CLICK peak |
|---|---|---|---|---|---|
| fast (5 ms) | default | ≥ 40 | ≥ 40 | 15 | −18 dB |
| | dualsense | ≥ 40 | ≥ 40 | ≥ 40 | −16 dB |
| | steamcontroller | ≥ 40 | 24 | 21 | −15 dB |
| | lra_classic | 22 | 16 | 15 | −12 dB |
| slow (25 ms) | default | 30 | 18 | **8** | −21 dB |
| | dualsense | 38 | 26 | 16 | −18 dB |
| | steamcontroller | 27 | 16 | **10–11** | −18 dB |
| | lra_classic | 17 | 11 | **8** | −16 dB |

On a slow actuator, STUTTER goes soft under `default`, `steamcontroller` and `lra_classic`. The
native presets stay crisp across the whole range.

### Frame rate

| fps | Profile | STUTTER dip | CLICK tail | Time to 50% (TAP) |
|---|---|---|---|---|
| 30 | default | **10** | 51 ms | 8 ms |
| | dualsense | 29 | 31 ms | 7 ms |
| | lra_classic | **10** | 57 ms | 7 ms |
| 60 | default | 14 | 52 ms | 11 ms |
| | dualsense | 38 | 37 ms | 7 ms |
| | lra_classic | 14 | 69 ms | 9 ms |
| 144 | default | 12–15 | 61 ms | 18 ms |
| | dualsense | 36–≥ 40 | 42 ms | 11 ms |
| | lra_classic | 13–15 | 76 ms | 16 ms |

At 30 fps, STUTTER goes soft on the slower presets, the same engine-wide quantization effect as
on ERM (§4.3). Onset also slows as the frame rate rises, for the reason given in §4.3 (the
first tick credits a whole frame). On an LRA that difference is visible: TAP reaches 50% in 7 ms
at 60 fps on a DualSense, but 11 ms at 144 fps.

## 5.4 Section summary

| # | Effect | Profiles | Severity | Holds across sensitivity? |
|---|---|---|---|---|
| L1 | Intensity ladder flattened to ~13 dB (ERM: ~25 dB). Background cues are prominent, and light and heavy modes feel closer together. | All LRA presets (gamma 1.0) | **Medium** | Depends on the driver mapping being linear (unverified) |
| L2 | Gain clips THUMP into HEAVY at high master | switchpro ≥ 0.90, steamdeck Low ≥ 0.94 | Low–medium | Yes (static) |
| L3 | Textures play 11–18 dB stronger than on ERM, and "barely there" DRIFT is clearly felt | All LRA presets | Medium: cross-pad inconsistency | Same caveat as L1 |
| L4 | Rhythms: all crisp. Native presets beat `default` by 10–24 dB of STUTTER dip and 10–50 ms of tail. | Native LRA presets | **Positive** | Yes |
| L5 | STUTTER goes soft on slow actuators or at 30 fps | default, steamcontroller, lra_classic | Low | Condition-specific |
