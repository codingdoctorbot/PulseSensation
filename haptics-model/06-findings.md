# 6. Findings: where the current tunings hurt the feel

## Bottom line

- **LRA presets** (DualSense, Switch Pro, Steam Deck, Steam Controllers): **timing is good**.
  Every rhythm stays crisp and they clearly beat `default`. Their weakness is **level**: gamma
  1.0 flattens the intensity ladder to about half an ERM's, so light and heavy cues feel closer
  together than intended, and textures play much stronger than on ERM pads.
- **ERM presets** (Xbox, Elite, DS4, 8BitDo) have **two real problems**:
  1. After today's floor reduction (`72950f5`), **11 of 175 cues are no longer felt at all**,
     including 4 that are on by default.
  2. Their attack and release times are applied in software on top of a motor that already has
     that inertia. That **blurs rhythms**: CHIME's two notes merge, and on slow motors they fuse.
- Every problem found can be fixed with **values the calibration page already exposes**. None
  of them needs a code change.

## Ranked findings

| Rank | Finding | Affected | Evidence | Confidence | Tuning direction |
|---|---|---|---|---|---|
| **1** | Light cues are imperceptible on ERM pads. TICK 0.3–0.35, CLICK 0.45–0.5 and BLIP 0.4 peak at −43 to −53 dB. **11/175 cues, 4 on by default** (uiNavigate, radialTick, popupHidden, panelClose). Introduced by `72950f5`; the previous floors lost 0–4 cues. | xbox, ds4, 8bitdo (elite: 4–9) | §3.4, §4.1 | Medium–high | ERM floors around **0.10** on both channels |
| **2** | ERM software smoothing duplicates the motor's inertia. **CHIME drops from 14 dB to 8–9 dB (soft), and to 5 dB (fused) on slow motors.** DOUBLE_TAP loses 6–9 dB, low-motor tails grow 30–65 ms, and onset is 8–9 ms later. | xbox, xbox_elite, ds4, 8bitdo | §4.1, §4.2, §4.3 | Medium–high | releaseTau **~0.012**, transientAttackTau **~0.003**, attackTau **~0.030** |
| **3** | LRA intensity ladder flattened: CLICK→HEAVY spans ~13 dB against ~25 dB on ERM. Background cues are prominent, and textures are 11–18 dB stronger than on ERM pads. | all LRA presets | §3.2, §5.2 | Medium (assumes a linear driver) | gamma **~1.5** on LRA channels |
| **4** | Gain > 1 clips THUMP into HEAVY when master is raised | switchpro (master ≥ 0.90), steamdeck Low (≥ 0.94), lra_classic (onset ≥ 0.85) | §3.3 | High (arithmetic) | switchpro gain **~1.15** together with gamma 1.5 |
| 5 | Soft-floor "fade to whisper" doesn't exist on an ERM; DRIFT is silent there | ERM presets | §3.5, §4.4 | High | None needed today (no real trigger uses DRIFT) |
| 6 | Overdrive on a rhythm's later pulses depends on intensity (> 0.40 jump rule) | ERM presets | §1.2, step 2 | High | None: the felt effect is ≤ 1 dB |

### Not profile problems (engine-wide, out of scope here)

- STUTTER goes soft at 30 fps (quantized to 33 ms frames), on every profile (§4.3, §5.3).
- Onset speed depends on frame rate: the first smoothing tick credits a whole frame, so onset
  is faster at low fps (§4.3).
- Textures linger ~0.35 s after their state ends, because of `REFRESH_WINDOW` (§4.4).

## What the suggested directions do (model, nominal hardware)

These are **directions to try on a real pad with the calibration sliders**, not verified
values.

### ERM: Xbox preset

| | Xbox as shipped | Xbox with floor 0.10, release 12 ms, attack 3 / 30 ms |
|---|---|---|
| Cues not felt, u_b 0.03 / 0.06 / 0.10 / 0.15 | 11 / 11 / 15 / 15 | **0 / 0 / 4 / 10** |
| … of those on by default | 4 / 4 / 6 / 6 | **0 / 0 / 2 / 4** |
| CLICK / TICK / TAP peak | −38 / −25 / −16 dB | −31 / −21 / −14 dB |
| CLICK→HEAVY range | 25.4 dB | 20.3 dB (LRA today: ~13 dB) |
| DOUBLE_TAP / CHIME / STUTTER dip | 15 / **8** / 12 dB | **26 / 18 / 18 dB** |
| … on slow motors | 9 / **5** / 7–8 dB | 15 / 11 / 11 dB |
| First felt: DOUBLE_TAP / CHIME | 20 / 23 ms | 11 / 13 ms |
| THUD / HEAVY tail | 192 / 205 ms | 149 / 159 ms |
| HUM strength / 90% rise | −28 dB / 355 ms | −23 dB / 218 ms |

Everything improves except the width of the intensity ladder, which narrows by about 5 dB.
That narrowing is the unavoidable cost of lifting quiet cues back into perception, and the
result is still much wider than on an LRA. The other ERM presets follow the same pattern (§4).

### LRA: DualSense and Switch Pro

| | dualsense | dualsense, gamma 1.5 | switchpro | switchpro, gamma 1.5, gain 1.15 |
|---|---|---|---|---|
| CLICK→HEAVY range | 12.9 dB | **18.1 dB** | 12.1 dB | **16.1 dB** |
| CLICK / TICK / TAP peak | −16 / −11 / −8 dB | −22 / −16 / −11 dB | −13 / −9 / −6 dB | −19 / −14 / −10 dB |
| Weakest shipped cue | −21 dB | −28 dB | −18 dB | −23 dB |
| HUM / DRIFT steady | −13 / −21 dB | −19 / −28 dB | −11 / −18 dB | −17 / −26 dB |
| THUMP = HEAVY from master | never | never | **0.90** | never |
| STUTTER dip | 38 dB | 38 dB | 24 dB | 29 dB |

Every cue stays at least 12 dB above detection, timing is unchanged, and the gap in texture
strength between ERM and LRA pads narrows from about 15 dB to about 4 dB.

## What is fine and should stay

- **LRA preset timing.** The short attack and release times suit the hardware (§5.1).
- **ERM overdrive.** 4–5 ms faster onset and +1–2 dB on short hits, with no side effects (§4.2).
- **Steam Controller's slower attack** (to avoid rattle) and **lra_classic's ERM imitation**.
  Both stay crisp at nominal actuator speed and do what their notes say (§5.1).
- **Gamma below 1 on ERM presets.** It compresses the ladder a little, which is fine given
  ERM's wide native range.

## How to check these on a real pad (no code needed)

Each check uses the existing Controller calibration sliders and the mode test button:

1. **Finding 1, Xbox/DS4/8BitDo.** Move around the UI and close a panel (uiNavigate and
   panelClose are on by default). Then set both channels' **Breakaway floor to 0.10** and
   repeat. If the cues go from nothing to a faint
   tick, the finding holds.
2. **Finding 2, same pads.** Test **CHIME** and count the notes. Set both channels' **Release
   time to 0.012** and test again: it should become two distinct notes. Do the same with
   DOUBLE_TAP.
3. **Finding 3, DualSense or Switch Pro.** Test CLICK, then HEAVY, and compare the gap with the
   same test on an Xbox pad. Set **Response curve to 1.5** and repeat. The LRA gap should widen
   towards the Xbox one. If it overshoots (CLICK becomes hard to feel), the driver already
   applies a curve and gamma should stay nearer 1.2.
4. **Finding 4, Switch Pro.** Set master intensity to 1.0 and test THUMP, then HEAVY, noting
   whether they differ in strength or only in length. Then set **Strength to 1.15** and
   compare.

## Limits of this model

- **Nothing here is measured.** Actuator parameters are class estimates (§2). The conclusions
  were kept only where they held across the sensitivity sweeps: breakaway 0.03–0.15, motor
  speed ×0.6–×1.6, LRA τ 5–25 ms, and 30–144 fps. The one exception is finding 3, which depends
  on the driver's mapping (flagged above).
- **Detection is a single threshold** (−40 dB). A lower real threshold would bring back some
  TICK cues on ERM, but not the CLICK cues (−51 to −53 dB).
- **Perception is simplified.** There is no frequency weighting, and an ERM's low speed means
  low frequency, where skin is less sensitive. Both simplifications make ERM light cues look
  *stronger* than they are, so finding 1 is if anything understated.
- **Transport latency** (USB/Bluetooth) is left out. It is the same for every profile, so it
  shifts all timings equally.
- **Housing rattle and buzz** is outside the model, so presets tuned against it (Steam
  Controller, Steam Deck) are not judged on that point.
