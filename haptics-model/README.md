# Haptics Model: how controller profiles affect the vibration modes

**Question:** do the current controller profiles (the device presets in `Core/Devices.lua`) make any
vibration mode feel worse than it was designed to feel, on either motor type?

**Approach:** simulate the whole chain from a cue firing to the vibration a hand feels:

```
mode shape ─► Engine (scale, master, overdrive, gain, gamma, floor, smoothing, rate limit)
           ─► SetVibration command ─► actuator physics (ERM motor / LRA voice coil)
           ─► felt vibration strength over time
```

Then compare selected modes across every profile, for both actuator types.

This folder contains only analysis. **No addon code has been changed.** Every number here comes
from a model, not from a measurement on real hardware. Each document says what it assumes, and which
conclusions still hold when those assumptions change.

**Start with [06-findings.md](06-findings.md)** for the ranked results. Sections 1–5 are the
evidence behind them.

## Documents

| # | File | Contents | Status |
|---|---|---|---|
| 1 | [01-pipeline.md](01-pipeline.md) | The engine's signal chain exactly as the code implements it, with line references | ✅ done |
| 2 | [02-actuator-models.md](02-actuator-models.md) | ERM and LRA physical models, parameters and assumptions | ✅ done |
| 3 | [03-static-transfer.md](03-static-transfer.md) | Each profile's input→command curve: floor, gamma, gain, clipping, dead zones | ✅ done |
| 4 | [04-erm-dynamics.md](04-erm-dynamics.md) | Selected modes simulated on ERM hardware, per profile | ✅ done |
| 5 | [05-lra-dynamics.md](05-lra-dynamics.md) | Selected modes simulated on LRA hardware, per profile | ✅ done |
| 6 | [06-findings.md](06-findings.md) | Negative effects, ranked, with suggested tuning directions | ✅ done |
| — | [model.py](model.py) | The simulator that produces every table (plain Python 3, no dependencies) | ✅ done |

## Reproducing the numbers

```
python3 haptics-model/model.py            # everything (~6 s)
python3 haptics-model/model.py transfer   # §3   (also: erm, lra, suggest)
```

The model reads the modes and cues directly from `Core/Modes.lua` and `Core/Registry.lua`, so
it keeps up with changes to either. The device presets are copied into `model.py`, and have to
be updated there if `Core/Devices.lua` changes.

## Modes selected

These were chosen by how often cues use them in `Core/Registry.lua`, plus the extremes of the
vocabulary (lightest, heaviest, fastest rhythm, continuous):

| Mode | Uses | Why it's included |
|---|---|---|
| TAP | 50 | Most-used mode; short, high motor, mid intensity |
| DOUBLE_TAP | 32 | Most-used rhythm; low motor; two taps must stay distinct |
| TICK | 24 | Light, short, high motor |
| CHIME | 19 | Low then high, with a gap: tests the handover between motors |
| THUD | 8 | Both motors, then low only: an impact with a tail |
| STUTTER | 5 | Fastest rhythm (40 ms on, 60 ms off): the hardest test of pulse separation |
| CLICK | 4 | Lightest discrete mode: the hardest test of the breakaway floor |
| HEAVY | 6 | Strongest mode: tests gain clipping and the top of the dynamic range |
| HUM | continuous | Steady low texture: tests the continuous (soft-floor) path |
| DRIFT | continuous | Quietest texture (0.08): tests the soft-floor knee near breakaway |

## Profiles covered

| Actuator | Profiles |
|---|---|
| **ERM** (spinning weight) | `default`, `xbox`, `xbox_elite`, `ds4`, `8bitdo` |
| **LRA / voice coil** | `default`, `dualsense`, `switchpro`, `steamdeck`, `steamcontroller2`, `steamcontroller`, `lra_classic` |

## Progress log

- **Step 1:** folder, plan and signal-chain document (`01-pipeline.md`).
- **Step 2:** simulator (`model.py`) and actuator models (`02-actuator-models.md`). First run:
  observation O2 (overdrive on a rhythm's later pulses depends on intensity) is real but small.
  The second tap comes out 0.3–0.9 dB stronger, mostly because the motor is still spinning from
  the first.
- **Step 3:** static transfer (`03-static-transfer.md`). Two main results:
  - **Light cues are imperceptible on ERM pads** with the floors lowered in `72950f5`: 9–11 of
    175 cues, including 4 of the 50 on by default (uiNavigate, radialTick, popupHidden,
    panelClose). With the previous floors, 0–4 were.
  - **LRA pads get about half an ERM's dB range**, because an LRA's strength is linear in the
    command while an ERM's is quadratic, and every LRA preset keeps gamma at 1.0.
- **Step 4:** ERM dynamics (`04-erm-dynamics.md`). The ERM presets' attack and release times
  are applied in software **in front of** a motor that already has that inertia, so the lag is
  counted twice. CHIME goes from crisp to soft (14 → 8–9 dB), and fuses completely on slow
  motors. DOUBLE_TAP loses 6–9 dB of separation, and tails grow 30–65 ms. Setting release
  to 12 ms fixes the rhythms with no loss of strength. Overdrive helps a little.
- **Step 5:** LRA dynamics (`05-lra-dynamics.md`). The native LRA presets are good for timing:
  every rhythm stays crisp, and they beat `default` clearly. Their problems are in level: gamma
  1.0 leaves an LRA's intensity ladder at about half an ERM's, and textures play 11–18 dB
  stronger than on ERM pads. A gamma of about 1.4–1.6 would restore most of the ladder without
  losing any cue (assuming the driver's mapping is linear).
- **Step 6:** findings (`06-findings.md`). Four problems are ranked, each with a tuning
  direction and a way to check it on a real pad using only the existing calibration sliders.
  The suggested directions were checked together in the model (`model.py suggest`).
