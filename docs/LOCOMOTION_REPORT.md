# Locomotion Motor Trace Report

**Date:** 2026-09-29 · **Code baseline:** HEAD `ac3d02f` plus the uncommitted working tree · **Shareable copy:** [Claude Doc](https://claude.ai/code/artifact/4ecacca3-cf9f-4e68-b0a9-36733377c980) (private until shared) · **Interactive trace:** [Locomotion Motor Trace](https://claude.ai/artifact/3KKjjCNjcPapxp1cbBb7WE)

**Labels:** [Fact] = measured from the real addon code or read from a file; [Inference] = reasoned from facts, not measured; [Recommendation] = proposed change.

## Summary

A footfall never reaches the hands as a tap. It is a 188 ms block at breakaway level, and the two motors pass it back and forth, so running never goes quiet. These results are simulated on the saved settings; nothing has been felt on hardware.

Causes of the muddy running cue, biggest first (Xbox tuning, Standard schema, Skyborne running at 7.0):

1. **The floor stretches each footfall to the whole half-stride.** With split feet the blocks meet end to end. New.
2. **At cue intensity 0.15, each footfall is almost all floor.** New.
3. **Continuous smoothing blurs what is left.** Known from CR-005 and CR-012; the numbers are new.
4. **The feet are uneven:** in timing (new), and slightly in strength (CR-030).
5. **Steps come twice as fast as labelled** (CR-005). Fixing only the rate would make each block longer.

Fix direction: short 30–60 ms taps at real step times (CR-005), plus a dead-zone curve instead of the floor lift (CR-008 b). Switching footfalls to the impact attack alone is not enough.

## Scope and method

The numbers come from the addon's own Lua, run offline, and match the page's simulator frame for frame.

- **What ran [Fact].** `PulseChecklist/tests/locomotion-sim/locosim.lua` loads the real `Core/Init`, `Devices`, `Schemas/*`, `Registry`, `Engine` and `Modules/Locomotion` under stubbed WoW APIs. It records every `C_GamePad.SetVibration` value.
- **Check [Fact].** `compare.py` runs 26 configurations through the Lua and through the page's JavaScript port. Every frame matches to 6 decimals.
- **Saved settings [Fact].** From `WTF/Account/<account>/SavedVariables/PulseHaptics.lua`, written on 2026-09-29 at 08:38 and read without changes:
  - Xbox tuning applied, `standard` schema, Skyborne, riding tier 0, barefoot.
  - Caster: Overall 1.0, cue intensity 0.15, gait strength 1.0.
  - Ranged actual: Overall 0.65, cue intensity 0.15, gait strength 0.2.
- **Assumptions.** Fixed 60 fps. Speed reads 0 on the first frame of movement. Locomotion updates before Engine each frame. Flat ground, with no jumps or combat.
- **Not covered.** Walking, mounted on these profiles, the Default profile (its cue is off), and feel on hardware.

## Why running feels muddy on your settings

The breakaway floor removes the gaps between steps more than the smoothing does. Running at 7.0 gives 2.66 cycles a second, so each foot's half-stride lasts 188 ms. The left foot goes to Low and the right foot to High.

The Claude Doc version has a trace chart of this. On the Caster profile from 4.0 to 4.75 s, the two motors hand over with no quiet gap, and the quietest moment is 0.042. Reproduce it with the "Your Caster profile, running" example on the interactive page.

Caster profile, with one part of the motor path switched off at a time (what-ifs are experiments, not addon behaviour):

| What if | Quiet time | Low keeps step | High keeps step | Step spacing L→R / R→L (ms) |
| --- | --- | --- | --- | --- |
| As saved | 0% | 10% | 52% | 170 / 206 |
| No smoothing | 0% | 100% | 100% | 189 / 187 |
| Impact attack | 0% | 81% | 95% | 180 / 196 |
| No floor | 50% | 46% | 65% | 181 / 194 |

Quiet time is the share of 2–9 s with both motors under 0.02. "Keeps step" is the share of the step's rise above the floor that reaches the motor. Source: `analyse.py`.

- **Floor block [Fact, new].** `sin⁴` is above zero across the whole half-cycle (`Modules/Locomotion.lua:249-251`). The engine lifts any value above zero to the floor (`Core/Engine.lua:435-437`): 0.12 on Low, 0.10 on High (`Core/Devices.lua:186-187`). So each footfall opens at the floor at the zero crossing and holds for 188 ms. With split feet the stronger motor never drops below 0.042. Sharpness cannot shorten the block.
- **Mostly floor [Fact, new].** Caster's target peaks at 0.186, and 0.120 of that is floor. Ranged actual peaks at 0.129, so the step adds 0.009.
- **Smoothing [Fact, extends CR-005].** Low's 90 ms attack needs about 200 ms to reach 90%, longer than a 188 ms footfall (`Core/Engine.lua:97-107, :449-453`). On Ranged actual neither motor reaches its floor: Low peaks at 0.108 against 0.120, High at 0.099 against 0.100.
- **Timing [Fact, new].** Low's slower attack delays the left foot. Peak lag is 41 ms against 24 ms on Caster, and 86 against 35 ms on Ranged actual. On Ranged actual, felt steps come 137 then 239 ms apart instead of 188.
- **Impact attack alone [Fact, new].** CR-012's fix restores most of the strength and timing, but quiet time stays at 0%.
- **Low motor may barely spin [Inference].** On Ranged actual, Low never reaches the floor, which is meant to be where the motor starts turning. The floors are unmeasured starting points (`Core/Devices.lua:160-162`).

## Findings across all setups

Three of these are new; the rest confirm CODE_REVIEW entries with measured numbers. All are [Fact] from the Lua runs unless marked.

| Finding | Evidence | Status |
| --- | --- | --- |
| Generic preset: High never moves; both feet go to Low (Low peak 0.327 mounted) | `Locomotion.lua:373-381, :535`; `Devices.lua:219-222` | CR-005 |
| Stock settings: nothing plays on foot (`mountedOnly` on) | `Registry.lua:2636`; `Locomotion.lua:507-509` | CR-005 |
| Xbox + Standard splits feet onto Low/High; stock plate run, right foot 22% stronger | `Locomotion.lua:365-381`; `Engine.lua:127-141` | CR-030 |
| Footfall rate is 2× the "steps/s" label (2.8 gives about 5.6 a second) | `Locomotion.lua:249-251, :511-513` | CR-005 |
| Mounted cadence hits the 8.0 ceiling; mount speed and riding skill change nothing | `Locomotion.lua:321-322, :339-343` | New |
| Mechanostrider: target peaks at 0.29, motor reaches 0.056 | `Locomotion.lua:239-245` | New |
| Last footfall holds 0.2 s after stopping (Low on until 0.28 s after) | `Locomotion.lua:522, :535, :569-573` | New |
| [Inference] Mounted gait feels like a hum, not hoofbeats | Mounted trace, Low 0.095–0.185 | Agrees with CR-005 |

If the riding spell IDs are not detected (marked unconfirmed at `Locomotion.lua:139-146`), mounted cadence is 7.26 instead of 8.0.

## Corrections

Three earlier statements were wrong or overstated, and are corrected here and in DOCS_COMPILATION §12.

- **Strength gap on your settings.** In chat I said the right foot is about 20% stronger. That figure is from stock settings (CR-030). On your profiles the gap is small and points both ways. On Caster the right foot is about 7% stronger (High 0.136 against Low 0.127). On Ranged actual the left foot is about 9% stronger (Low 0.108 against High 0.099).
- **CODE_REVIEW §13.1, "more on/off".** Each motor on its own does drop to near 0 (Caster: Low 0.006, High 0.000). The hands never feel a gap, because the other motor is in its floor block at that moment.
- **What was new.** The first chat summary of this trace presented CR-005 and CR-030 findings as new. The page and DOCS §12 now mark which are already known.

## Fix plan

Footfalls need to become short discrete taps. Only switching the attack or correcting the rate leaves the floor block in place.

| Change | Effect | Basis | CR |
| --- | --- | --- | --- |
| Short 30–60 ms taps at real step times | Floor lift lasts one tap, not a half-stride | Not simulated | CR-005 fix 1 |
| Dead-zone curve instead of linear floor lift | Small values no longer raised to breakaway strength | Not simulated | CR-008 b |
| Split only when the schema routes trigger roles to trigger motors | Removes uneven feet on Xbox + Standard | Code reading | CR-030 |
| Footfalls on the impact attack only | Strength and timing mostly restored; quiet time stays 0% | Simulated | CR-012 |
| Correct the cadence to real steps/s only | Blocks lengthen to about 376 ms, since a block is always half a cycle | [Inference] from `1 / (2 × cadence)` | CR-005 fix 2 |

The last two rows do not fix the muddiness on their own; the first two do the main work. Nothing here has been felt on a controller.

## Evidence and files

Everything here can be rerun from the repo; nothing is committed yet.

- **Interactive trace:** [Locomotion Motor Trace](https://claude.ai/artifact/3KKjjCNjcPapxp1cbBb7WE). Low and High over 10 s, your two profiles as examples, and what-if switches.
- **Simulation:** `PulseChecklist/tests/locomotion-sim/`, with `README.md` explaining how to run it. The folder is left out of the release zip (`scripts/package.sh:37`).
- **Compilation:** `docs/DOCS_COMPILATION.md` §12 (findings 1–9), §12.1 (findings 10–16) and §12.2 (ranked summary).
- **Related review entries:** `docs/CODE_REVIEW.md` CR-005, CR-008, CR-012, CR-030 and §13.1.

Rerun from the repo root:

```sh
python3 PulseChecklist/tests/locomotion-sim/compare.py   # Lua vs page, 26 configs
python3 PulseChecklist/tests/locomotion-sim/analyse.py   # per-footfall what-ifs
```
