# 1. The signal chain, as implemented

This describes what the code does, in order, from a cue firing to the value sent to
`C_GamePad.SetVibration`. The model in `model.py` copies these steps exactly. Line numbers refer
to the files at the commit this folder was written on.

## 1.1 Stage map

```
 Cue fires ── Pulse:FireIfEnabled                          Core/Init.lua:75
   │   scale = trigger "intensity" (default 1.0; 39 cues ship at 0.3–0.8)
   ▼
 Engine:PlayMode(name, mode, scale)                       Core/Engine.lua:347
   │   each step: magnitude = relIntensity × scale × lowMult/highMult
   │   duration = max(20 ms, relDuration × baseDuration × durMult)
   │   gap      = max(25 ms, gap × durMult)
   │   step 1 runs synchronously; later steps go through C_Timer.After (next frame)
   │   every step overwrites the SAME layer, marked isTransient = true
   ▼
 OnUpdate tick (every frame)                               Core/Engine.lua:635
   │   expire layers whose endTime has passed
   │   per role: continuous layers → saturating sum 1-(1-a)(1-b)
   │             transient layers  → max
   │             both present      → continuous + transient (clamped)
   │   × masterIntensity (default 0.7)                     Core/Database.lua:53
   │   × schema intensity (Standard: 1.0), roles → channel via max
   ▼
 driveChannel(channel, …)                                  Core/Engine.lua:544
   │ ① Overdrive: on a transient onset, value × overdriveBoost for overdriveDuration
   │ ② mapValue:                                          Core/Engine.lua:506
   │      v = clamp(v × gain)
   │      v = v^gamma            (or smoothstep if useSCurve)
   │      transient:  v = floor + (1 − floor) × v                     (hard floor)
   │      continuous: v = floor × smoothstep(v / knee) + (1 − floor) × v (soft floor,
   │                  knee = max(0.02, floor/2))
   │ ③ Smoothing, first-order, frame-rate independent:    Core/Engine.lua:116
   │      rising:  τ = transientAttackTau if the channel has a transient layer, else attackTau
   │      falling: τ = releaseTau
   │ ④ Shut-off: target 0 and smoothed < 0.025 → snap to 0 (SHUTOFF_DEADBAND)
   │ ⑤ Rate limit: send if onset / jump > 0.20 / shut-off, or if Δ > 0.0015
   │      and ≥ 12.5 ms since the last send; always resend every 250 ms (watchdog)
   ▼
 C_GamePad.SetVibration(channel, value)  ── the command the model hands to the actuator
```

## 1.2 Stage details that matter for feel

### PlayMode scheduling

- One mode is **one layer**. Every step replaces that layer's roles. A step that uses only
  `high` therefore sets the low target to zero, and the low channel starts releasing from that
  moment.
- Step and gap lengths are exact in the schedule. However, the engine only acts on frame
  boundaries: `C_Timer.After` fires on a frame, and a layer expires on the first frame where
  `now ≥ endTime`. At 60 fps every edge can be up to 16.7 ms late, and at 30 fps up to 33 ms.
  Short modes feel this the most: CLICK is 30 ms long, and STUTTER is 40 ms on, 60 ms off.

### Overdrive (ERM presets only)

`Core/Engine.lua:559-574`. This is a boost applied before `mapValue`. It starts when:

- the channel is transient, **and**
- either the previous wanted value was 0 and nothing has been sent for ≥ 70 ms,
  or the wanted value jumped by more than 0.40 in one tick.

Two consequences, both visible from the code alone:

1. **Whether a later pulse gets the kick depends on its intensity.** Between the pulses of a
   rhythm (DOUBLE_TAP, STUTTER), the release keeps sending updates, so the 70 ms silence
   condition fails. Later pulses only get overdrive if they jump by more than 0.40.
   DOUBLE_TAP at the default master (0.6 × 0.7 = **0.42**) passes. With master 0.65
   (**0.39**), or any cue set below 1.0, it fails. In that case the first tap is kicked and
   the second is not.
2. The boost is multiplied in **before** gain and gamma. So its real size is
   `boost^gamma` (1.25^0.88 ≈ 1.22 on the Xbox low motor), and it clips at
   `1 / (gain × boost)` of the input.

### mapValue order: gain → gamma → floor

- Gain is applied first and clipped to 1. With a gain above 1, any input over `1/gain`
  gives the same command, so the top of the range collapses:

  | Profile | Channel gain | Inputs that all clip to 1.0 |
  |---|---|---|
  | switchpro | 1.30 / 1.30 | ≥ 0.77 |
  | steamdeck | 1.25 / 1.05 | ≥ 0.80 / ≥ 0.95 |
  | lra_classic | 1.20 / 1.10 | ≥ 0.83 / ≥ 0.91 |
  | dualsense | 1.15 / 1.05 | ≥ 0.87 / ≥ 0.95 |
  | xbox_elite | 1.10 / 1.05 | ≥ 0.91 / ≥ 0.95 |

  At the default master of 0.7, no mode's peak goes above 0.7, so this matters when master or
  a cue's intensity is raised. Overdrive also lowers the clip point: see section 3.
- The floor remaps `[0, 1] → [floor, 1]`. Transients get the full floor as soon as they are
  non-zero. Continuous textures get it gradually below the knee (0.02 for every current
  preset floor ≤ 0.04), so a very quiet texture can end up **below** the floor. On an ERM,
  that means below breakaway, where the motor stalls. See section 3.

### Smoothing sits after the floor

The low-pass filter acts on the post-floor command. That has two effects:

- **Onset:** the command climbs from 0 through the sub-floor region, taking a few ms with the
  transient taus (5–25 ms).
- **Release:** after a pulse ends, the command decays exponentially from its peak and snaps to
  0 only below 0.025. A command of 0.6 takes `releaseTau × ln(0.6/0.025) ≈ 3.2 × releaseTau`
  to go quiet. That is **160 ms** for the Xbox low motor (τ = 50 ms). During that time the
  command sits above the motor's stall level, so the software keeps the motor turning **on
  top of** its own mechanical coast-down. Section 4 measures what this does to DOUBLE_TAP's
  120 ms gap.

### Rate limiting

Onsets, jumps over 0.20 and shut-offs are sent at once. Smaller changes are held for up to
12.5 ms. That is below one 60 fps frame, so at 60 fps or lower it effectively never delays
anything. At 144 fps it thins out release updates.

## 1.3 What the profiles actually change

Only the per-channel values in stage ② and ③, plus overdrive in ①. Schema, master and mode
shape are the same for every profile. The profile values:

| Profile | Ch | gain | gamma | floor | attack τ | trans. attack τ | release τ | overdrive |
|---|---|---|---|---|---|---|---|---|
| default | both | 1.00 | 1.00 | 0.000 | 75 ms | 12 ms | 28 ms | off |
| xbox | Low | 1.00 | 0.88 | 0.025 | 85 | 18 | 50 | ×1.25, 25 ms |
| | High | 1.00 | 0.88 | 0.025 | 45 | 10 | 24 | ×1.15, 20 ms |
| xbox_elite | Low | 1.10 | 0.85 | 0.040 | 90 | 18 | 55 | ×1.25, 25 ms |
| | High | 1.05 | 0.85 | 0.040 | 50 | 10 | 26 | ×1.15, 20 ms |
| ds4 | Low | 1.00 | 0.90 | 0.040 | 75 | 18 | 45 | ×1.25, 25 ms |
| | High | 1.00 | 0.90 | 0.040 | 40 | 10 | 24 | ×1.15, 20 ms |
| 8bitdo | Low | 1.00 | 0.88 | 0.040 | 80 | 18 | 48 | ×1.25, 25 ms |
| | High | 1.00 | 0.88 | 0.040 | 45 | 10 | 24 | ×1.15, 20 ms |
| dualsense | Low | 1.15 | 1.00 | 0.025 | 15 | 5 | 12 | off |
| | High | 1.05 | 1.00 | 0.025 | 12 | 5 | 10 | off |
| switchpro | Low | 1.30 | 1.00 | 0.055 | 20 | 5 | 18 | off |
| | High | 1.30 | 1.00 | 0.055 | 15 | 5 | 15 | off |
| steamdeck | Low | 1.25 | 0.90 | 0.045 | 35 | 5 | 20 | off |
| | High | 1.05 | 1.00 | 0.035 | 15 | 5 | 15 | off |
| steamcontroller2 | Low | 1.10 | 1.00 | 0.035 | 20 | 5 | 15 | off |
| | High | 1.05 | 1.00 | 0.035 | 15 | 5 | 12 | off |
| steamcontroller | Low | 1.10 | 1.00 | 0.060 | 40 | 5 | 30 | off |
| | High | 1.00 | 1.00 | 0.040 | 20 | 5 | 20 | off |
| lra_classic | Low | 1.20 | 0.88 | 0.065 | 75 | 25 | 45 | ×1.25, 25 ms |
| | High | 1.10 | 0.88 | 0.050 | 40 | 12 | 28 | ×1.15, 20 ms |

`useSCurve` is off in every preset.

## 1.4 Observations from reading the code

These come from the code alone. Sections 3–5 check each one with the model.

| # | Observation | Checked in |
|---|---|---|
| O1 | Release smoothing keeps an ERM driven above stall for ~3 × releaseTau after each pulse, adding to its mechanical coast-down. This may blur rhythms. | §4 |
| O2 | Overdrive on the 2nd and later pulses of a rhythm depends on intensity (the > 0.40 jump rule), so taps in one mode can start differently. | §4 |
| O3 | Frame quantization lengthens short steps and gaps by up to one frame. | §4, §5 |
| O4 | Gains above 1 clip the top of the range. Modes that differ only in peak (THUMP 0.85 vs HEAVY 1.0) can become identical. | §3 |
| O5 | The soft floor lets quiet continuous textures sit below the floor, which on an ERM means below breakaway (stall or stutter). | §3, §4 |
| O6 | The floor, gamma and gain values are class estimates. If a real controller's breakaway is higher than its preset floor (Xbox is now 0.025), light modes may not start the motor at all. | §3, §4 |
