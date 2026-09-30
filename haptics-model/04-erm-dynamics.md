# 4. ERM hardware: the selected modes over time

Each selected mode is run through the engine and the ERM model from §2.1, for every ERM profile.
Conditions: nominal hardware, 60 fps, master 0.7, cue intensity 1.0.

Reproduce: `python3 haptics-model/model.py erm`

## 4.1 Baseline results

**Peak strength** (dB re full scale, both motors summed):

| Profile | TAP | DOUBLE_TAP | TICK | CHIME | THUD | STUTTER | CLICK | HEAVY |
|---|---|---|---|---|---|---|---|---|
| default | −20 | −18 | −32 | −17 | −8 | −11 | **not felt** | 0 |
| xbox | −16 | −15 | −25 | −14 | −6 | −8 | −38 | 0 |
| xbox_elite | −15 | −13 | −23 | −12 | −5 | −7 | −35 | +2 |
| ds4 | −16 | −15 | −25 | −14 | −6 | −8 | −37 | 0 |
| 8bitdo | −16 | −15 | −24 | −13 | −6 | −8 | −36 | +1 |

**First felt** (ms after the cue fires):

| Profile | TAP | DOUBLE_TAP | TICK | CHIME | THUD | STUTTER | CLICK | HEAVY |
|---|---|---|---|---|---|---|---|---|
| default | 14 | 23 | 25 | 29 | 7 | 7 | — | 6 |
| xbox | 9 | 20 | 15 | 23 | 5 | 5 | 28 | 5 |
| xbox_elite | 8 | 18 | 13 | 21 | 5 | 5 | 23 | 4 |
| ds4 | 9 | 20 | 15 | 23 | 5 | 5 | 27 | 5 |
| 8bitdo | 9 | 20 | 14 | 23 | 5 | 5 | 25 | 5 |

**Tail** (ms still felt after the mode's authored end):

| Profile | TAP | DOUBLE_TAP | TICK | CHIME | THUD | STUTTER | CLICK | HEAVY |
|---|---|---|---|---|---|---|---|---|
| default | 81 | 139 | 48 | 79 | 152 | 103 | — | 170 |
| xbox | 85 | 182 | 62 | 81 | 192 | 103 | 21 | 205 |
| xbox_elite | 91 | 203 | 71 | 87 | 209 | 110 | 33 | 221 |
| ds4 | 85 | 175 | 63 | 81 | 184 | 103 | 22 | 198 |
| 8bitdo | 86 | 182 | 64 | 82 | 191 | 103 | 25 | 201 |

**Dip between pulses** (dB; ≥ 12 crisp, 6–12 soft, < 6 fused):

| Profile | DOUBLE_TAP | CHIME | STUTTER |
|---|---|---|---|
| default | 22 | 14 | 10, 11, 11 |
| xbox | 15 | **8** | 12, 12, 12 |
| xbox_elite | 13 | **8** | 11, 12, 12 |
| ds4 | 16 | **9** | 12, 12, 12 |
| 8bitdo | 15 | **9** | 12, 12, 12 |

### What the presets do well

- **They make modes stronger and faster to start.** Peaks are up to 9 dB higher than
  `default`, most of all for light modes (TICK +7 to +9 dB), and the first sensation comes
  2–12 ms sooner. The floor, gamma below 1 and the overdrive kick all help here.
- **They rescue CLICK from silence, just about.** Under `default` it is not felt at all, and
  under the presets it peaks at −35 to −38 dB, barely above detection (§3.4).

### What the presets make worse

- **Rhythms blur.** The presets' release times (45–55 ms on the low motor, compared with 28 ms
  in `default`) lengthen the tails of low-motor modes by 30–65 ms (DOUBLE_TAP, THUD, HEAVY)
  and fill in the gaps:
  - DOUBLE_TAP's dip falls from 22 dB to 13–16 dB. It is still crisp, but only just.
  - **CHIME falls from 14 dB (crisp) to 8–9 dB (soft).** The low motor is still running out
    its release when the high note starts, so the two notes merge into a single rising buzz.
    CHIME is the fourth most-used mode (19 cues).
  - STUTTER is the exception: its High channel release (24 ms) is slightly *shorter* than
    `default`'s, so its dips improve a little.

The envelopes show this. Each character is 10 ms, and the bar height is strength from
−40 dB (blank) to 0 dB (█).

```
DOUBLE_TAP authored  ████████████············████████████··························
           default     ▁▂▃▃▄▄▄▄▅▅▅▅▅▅▄▄▄▃▃▂▂▁▁▁▂▃▃▄▄▄▄▅▅▅▅▅▅▅▅▄▄▄▃▃▃▂▂▁
           xbox        ▂▃▄▄▄▅▅▅▅▅▅▅▅▅▅▅▅▄▄▄▃▃▃▃▃▄▄▅▅▅▅▅▅▅▅▆▆▅▅▅▅▅▅▄▄▄▃▃▃▂▂▁▁
           xbox rel12  ▂▃▄▄▄▅▅▅▅▅▅▅▅▅▄▄▄▃▃▂▂▁▁▁▂▃▄▄▄▅▅▅▅▅▅▅▅▅▅▅▄▄▃▃▂▂▁▁

CHIME      authored  ██████████········██████████··························
           default     ▁▂▂▃▃▃▄▄▄▄▃▃▃▂▂▂▁▂▃▄▄▅▅▅▅▅▅▅▅▄▃▃▂▁
           xbox        ▁▂▃▃▄▄▄▄▄▄▄▄▄▄▃▃▃▄▄▅▅▅▆▆▆▆▆▅▅▅▄▃▂▂▁
           xbox rel12  ▁▂▃▃▄▄▄▄▄▄▄▃▃▂▂▁▁▃▄▅▅▅▅▆▆▆▆▅▅▄▃▂▁

STUTTER    authored  ████······████······████······████··························
           default   ▁▃▅▅▆▆▆▅▅▄▅▅▆▆▆▆▆▆▅▅▅▅▆▆▆▆▆▆▅▅▅▅▆▆▆▆▆▆▅▅▄▃▃▂▁
           xbox      ▂▄▆▆▆▆▆▆▅▅▅▆▆▇▇▇▆▆▆▅▅▆▆▇▇▇▆▆▆▅▅▆▆▇▇▇▆▆▆▅▄▄▃▂▁
           xbox rel12▂▄▆▆▆▆▆▅▄▄▄▅▆▆▇▇▆▅▅▄▅▅▆▆▇▇▆▅▅▄▅▅▆▆▇▇▆▅▅▄▃▂▁
```

`xbox rel12` is the Xbox preset with only the release time changed to 12 ms (§4.2).

## 4.2 Why: the software smoothing duplicates the motor's own inertia

The ERM presets' time constants are described as motor properties. The Xbox note says
"heavy counterweight on left (85 ms spin-up …)". But the engine applies them **in software, in
front of a motor that already has that inertia**. The motor then adds its own spin-up and
coast-down on top. The result is two filters in series, so the lag is counted twice.

What-ifs on the Xbox preset (nothing else changed):

| Variant | DOUBLE_TAP dip | CHIME dip | STUTTER dip | DOUBLE_TAP first felt | CHIME first felt | THUD tail | Peaks |
|---|---|---|---|---|---|---|---|
| xbox as shipped | 15 dB | 8 dB | 12 dB | 20 ms | 23 ms | 192 ms | — |
| release τ 12 ms (both channels) | 26 dB | 18 dB | 18 dB | 20 ms | 23 ms | 143 ms | within 1 dB |
| no software smoothing at all | 28 dB | 20 dB | 22 dB | 12 ms | 14 ms | 138 ms | within 1 dB |
| no overdrive | 14 dB | 8 dB | 12 dB | 24 ms | 28 ms | 191 ms | −1 to −2 dB |

- **Release time is what blurs rhythms.** Cutting it to 12 ms turns CHIME back into two
  notes (18 dB) and takes about 50 ms off every tail, with no loss of strength.
- **Transient attack time costs 8–9 ms of onset on low-motor modes**, and continuous attack
  time doubles how long HUM takes to fade in (355 ms → 178 ms without it). With a real ERM
  there is nothing to gain from either: the motor cannot follow faster than its own inertia
  anyway, so software attack only adds delay.
- **Overdrive is doing its job.** It gives 4–5 ms faster onset and +1–2 dB peak on short hits,
  and it doesn't affect tails.

Where software ERM-style smoothing *does* belong is `lra_classic`: that preset deliberately
imitates ERM inertia on a voice coil, which has none of its own (§5).

## 4.3 Sensitivity

### Motor speed (nominal τ × 0.6 and × 1.6)

| Hardware | Profile | DOUBLE_TAP dip | CHIME dip | STUTTER dip | TICK peak |
|---|---|---|---|---|---|
| fast motors | default | 42 | 24 | 17–18 | −29 dB |
| | xbox | 24 | 14 | 20 | −22 dB |
| nominal | default | 22 | 14 | 10–11 | −32 dB |
| | xbox | 15 | 8 | 12 | −25 dB |
| slow motors | default | 13 | 9 | 6–7 | −36 dB |
| | xbox | **9** | **5 (fused)** | 7–8 | −29 dB |

The preset's rhythm penalty holds for all three motor speeds, and it gets worse with slow
motors. On a pad with heavy weights, which is what the Elite preset assumes, **CHIME fuses into
one pulse**. On fast motors the preset is harmless for rhythms.

### Frame rate

| fps | Profile | DOUBLE_TAP dip | STUTTER dip | DOUBLE_TAP first felt | STUTTER peak |
|---|---|---|---|---|---|
| 30 | default | 29 | 8 | 19 ms | −9 dB |
| | xbox | 20 | 9 | 14 ms | −7 dB |
| 60 | default | 22 | 10–11 | 23 ms | −11 dB |
| | xbox | 15 | 12 | 20 ms | −8 dB |
| 144 | default | 20 | 9–11 | 30 ms | −14 dB |
| | xbox | 13 | 11–13 | 28 ms | −11 dB |

Frame rate affects every profile the same way, so it doesn't change the comparison. Two
effects are engine-wide rather than profile-related:

- **At 30 fps STUTTER goes soft (8–9 dB)** for every profile. Its 40 ms on / 60 ms off pattern
  is quantized to 33 ms frames, so the pulses stretch and the gaps shrink.
- **Onset gets faster at lower frame rates.** On the first tick after a cue, the smoother
  applies the full frame time, including time that passed before the layer existed. At 30 fps
  a 33 ms step is "credited" immediately. So the smoothing is not fully frame-rate independent
  at onset: DOUBLE_TAP is first felt anywhere from 14 to 30 ms depending on fps.

## 4.4 Continuous textures

HUM (0.25) and DRIFT (0.08) held for 1 s:

| Profile | HUM steady | HUM 90% rise | HUM felt after the state ends | DRIFT |
|---|---|---|---|---|
| default | −34 dB | 336 ms | 372 ms | not felt |
| xbox | −28 dB | 355 ms | 423 ms | not felt |
| xbox_elite | −24 dB | 367 ms | 447 ms | not felt |
| ds4 | −27 dB | 328 ms | 421 ms | not felt |
| 8bitdo | −27 dB | 341 ms | 427 ms | not felt |

- DRIFT is silent on an ERM under every profile (§3.5).
- HUM lingers for about 0.4 s after its state ends. Most of that is the engine's 350 ms
  `REFRESH_WINDOW`, which applies to all profiles; the presets add 50–75 ms. This is a
  design choice ("decays within one refresh window"), not a profile problem.

## 4.5 Section summary

| # | Effect | Profiles | Severity | Holds across sensitivity? |
|---|---|---|---|---|
| E1 | Software release (45–55 ms, Low) stacks on the motor's coast-down. CHIME goes soft (8–9 dB), DOUBLE_TAP loses 6–9 dB, low-motor tails grow 30–65 ms. | xbox, xbox_elite, ds4, 8bitdo | **Medium–high**: CHIME is used by 19 cues, and fuses on slow motors | Yes. Worse on slow motors, harmless on fast ones |
| E2 | Software attack delays onset by 8–9 ms on low-motor modes and halves HUM's fade-in speed | same | Low–medium | Yes |
| E3 | CLICK and TICK stay near or below detection (see S1) | all ERM | High, already listed as S1 | Yes |
| E4 | STUTTER goes soft at 30 fps | all profiles (engine-wide) | Low | Frame-rate specific |
| E5 | Overdrive helps a little (+1–2 dB, −4 ms) | ERM presets | Positive | Yes |
