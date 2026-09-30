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

## Documents

| # | File | Contents | Status |
|---|---|---|---|
| 1 | [01-pipeline.md](01-pipeline.md) | The engine's signal chain exactly as the code implements it, with line references | ✅ done |
| 2 | [02-actuator-models.md](02-actuator-models.md) | ERM and LRA physical models, parameters and assumptions | ✅ done |
| 3 | [03-static-transfer.md](03-static-transfer.md) | Each profile's input→command curve: floor, gamma, gain, clipping, dead zones | ✅ done |
| 4 | [04-erm-dynamics.md](04-erm-dynamics.md) | Selected modes simulated on ERM hardware, per profile | ⏳ next |
| 5 | [05-lra-dynamics.md](05-lra-dynamics.md) | Selected modes simulated on LRA hardware, per profile | ⏳ |
| 6 | [06-findings.md](06-findings.md) | Negative effects, ranked, with suggested tuning directions | ⏳ |
| — | [model.py](model.py) | The simulator that produces every table (plain Python 3, no dependencies) | ✅ engine + actuators |

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
