# 2. Actuator models: ERM and LRA

The engine only decides a **command** between 0 and 1. What the hand feels depends on the
hardware turning that command into motion. The two actuator classes respond very differently,
so each needs its own model. Both are implemented in `model.py` (`class ERM`, `class LRAAct`).

> **Status of the numbers.** No controller has been measured for this analysis. The parameters
> below are class-typical estimates, chosen to be physically plausible. Sections 4–6 therefore
> report conclusions together with how they change when these parameters change (sensitivity
> sweeps). A finding that only appears for one parameter value is marked as such.

## 2.1 ERM: eccentric rotating mass

A DC motor spins an off-centre weight. The weight's centripetal force shakes the controller.

### Model

State: normalised speed `w`, where 1 = full speed.

```
running target speed   w_ss(u) = (u − u_c) / (1 − u_c)         (negative below u_c)
speeding up            dw/dt = (w_ss − w) / τ_up
slowing down           dw/dt = (w_ss − w) / τ_down             (coasting: no active brake)
stopping               w reaches 0 → motor stops
starting from rest     only when u > u_b                        (breakaway)
felt strength          E = w²                                  (force ∝ m·r·ω²)
vibration frequency    f = f_max · w
```

Why each part is there:

- **Breakaway `u_b` higher than running friction `u_c`.** Static friction is higher than
  sliding friction, so a stopped motor needs more to start than a turning one needs to keep
  turning. This hysteresis is why a quiet texture hovering near the threshold can stutter:
  it starts, slows below `u_c`, stops, and only restarts once the command goes above `u_b`.
- **`τ_down` longer than `τ_up`.** Controller rumble drivers are one-directional PWM switches:
  they can push the motor, but not brake it. When the command drops, the motor coasts down on
  friction alone.
- **E = w².** The force from a spinning eccentric mass grows with speed squared, so a motor at
  half speed shakes at a quarter of full strength. This is the most important difference from
  an LRA: **ERM strength is roughly quadratic in command, LRA strength is linear.**

### Parameters

| Parameter | Low (heavy) motor | High (light) motor | Plausible range | Source of estimate |
|---|---|---|---|---|
| τ_up (spin-up) | 60 ms | 30 ms | 40–100 / 20–50 ms | Typical coin/cylinder ERM datasheets list 30–100 ms rise times |
| τ_down (coast-down) | 90 ms | 45 ms | 60–150 / 30–80 ms | Coasting on friction, 1.5× spin-up |
| u_b (breakaway) | 0.060 | 0.050 | **0.03–0.15** | Unknown for these controllers. Presets assume 0.025–0.040 |
| u_c (running friction) | 0.040 | 0.035 | ≈ 0.7 × u_b | |
| f_max | 70 Hz | 150 Hz | 50–100 / 100–250 Hz | Used only when discussing perception |

Breakaway is the least certain value and the most important one for quiet modes, so §4 sweeps it
from 0.03 to 0.15.

### What these values produce (step response, command held for 600 ms)

| | Low motor | High motor |
|---|---|---|
| Time to 50% strength | 74 ms | 37 ms |
| Time to 90% strength | 178 ms | 89 ms |
| After release: strength halves in | ~28 ms | ~14 ms |
| After release from 0.7: below detection in | 147 ms | 75 ms |

And how much of its eventual strength a short pulse reaches, at command 0.45:

| Pulse length | Low motor | High motor | Modes of this length |
|---|---|---|---|
| 30 ms | 15% | 40% | CLICK |
| 40 ms | 24% | 54% | TICK, STUTTER pulses |
| 55 ms | 36% | 71% | TAP |
| 120 ms | 75% | 96% | DOUBLE_TAP pulses |

**Short pulses never reach full strength on an ERM.** CLICK, TICK and TAP are all high-motor
modes, which is the right choice: on the low motor they would reach even less.

### What the ERM model ignores

- **The hand and controller.** The controller's mass and the hand's damping shape the felt
  response, mostly by attenuating very low frequencies. Leaving this out makes slow-spinning
  (quiet) states look slightly *more* felt than they are, so conclusions about quiet modes
  being weak are conservative.
- **Frequency-dependent skin sensitivity.** The hand is most sensitive around 150–300 Hz and
  much less so around 30–70 Hz. A low motor at low speed is therefore felt even less than
  E = w² suggests. Same conservative direction.
- **Battery voltage, motor heating, wear.** These shift u_b and full speed from pad to pad,
  which is why the Ramp calibration exists.

## 2.2 LRA: linear resonant actuator / voice coil

A magnet on a spring, driven by a coil at (or near) the spring's resonant frequency. On PC,
a pad like the DualSense, Switch Pro or Steam Deck turns the two rumble values into a vibration
waveform. The model assumes the rumble value sets the waveform's amplitude.

### Model

```
drive at resonance f0 with amplitude u
envelope a(t):   da/dt = (u − a) / τ_env,   τ_env = Q / (π · f0)
felt strength    E = a                    (acceleration at a fixed frequency ∝ amplitude)
no breakaway: any non-zero command moves the mass
```

A resonator's amplitude builds up and dies away over roughly Q cycles. That lag is `τ_env`.

| Parameter | Low channel | High channel | Plausible range |
|---|---|---|---|
| τ_env | 12 ms | 10 ms | 5–25 ms (f0 150–250 Hz, Q 4–15) |
| Active braking | none | none | Some driver chips brake, which shortens release |

| | Low channel | High channel |
|---|---|---|
| Time to 50% strength | 8 ms | 7 ms |
| Time to 90% strength | 28 ms | 23 ms |
| After release from 0.7: below detection in | 50 ms | 42 ms |

Compared with an ERM, an LRA is about **5–8× faster** at the same command, and its strength is
**linear** rather than quadratic.

### What the LRA model ignores, and why it matters

- **How the OS or driver maps rumble onto the actuator.** This is unknown for WoW's path
  (WoW → OS or SDL → driver → pad). The Low and High values may become different
  frequencies, or pass through a curve in firmware. If the mapping is non-linear, the gamma
  conclusions in §5 shift. The timing conclusions do not.
- **Rattle and buzz of the housing.** This is what the Steam Controller and Steam Deck presets'
  slower attack is meant to prevent. It is a mechanical effect outside this model, so those
  presets' slower attack is kept as it is and not judged here.

## 2.3 From strength to "feel"

| Quantity | Definition | Used for |
|---|---|---|
| **E** | Normalised strength (acceleration), summed over both channels (0–2) | Peak, timing |
| **Detection** | E ≥ 0.01, i.e. −40 dB below full scale | "First felt", "felt for", tail |
| **ψ** (perceived magnitude) | E^0.6 (Stevens' power law; vibration exponents are reported between 0.5 and 0.95) | Comparing how strong modes feel |
| **Dip** | Drop in dB from the weaker neighbouring peak to the deepest point between two pulses | Whether pulses in a rhythm stay separate |
| **Tail** | Time from the mode's authored end until E stops being detectable | Blur and overlap with the next cue |

**Reading dips** (an assumption based on tactile amplitude-modulation studies; treat the
boundaries as approximate):

| Dip | Reading |
|---|---|
| ≥ 12 dB | **Crisp**: clearly separate pulses |
| 6–12 dB | **Soft**: separate, but smeared together |
| < 6 dB | **Fused**: feels like one wobbling pulse |

## 2.4 Simulation conditions

| Setting | Baseline | Swept in §4–5 |
|---|---|---|
| Frame rate | 60 fps | 30, 144 fps |
| masterIntensity | 0.7 (default) | 0.65–1.0 |
| Cue intensity | 1.0 | 0.5 |
| Actuator integration | 2 kHz | |
| Trigger timing | on a frame boundary | |
| Transport latency (USB/Bluetooth) | omitted: the same for every profile, so it shifts all timings equally | |
