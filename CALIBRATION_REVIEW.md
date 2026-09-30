# Calibration Review

## 1. Breakaway-floor Ramp probe

**Scope:** the Ramp probe on the controller-calibration page, which is how a person measures a motor's
breakaway floor, and the Set Floor button that records the result.

**Files involved**

| File | What it holds |
|---|---|
| `PulseHaptics/Core/Devices.lua:148-163` | Ramp shape: `RAMP_PEAK`, `RAMP_STEP`, `RAMP_STEP_SECONDS` |
| `PulseHaptics/Core/Engine.lua:929-996` | `Engine:RampChannel`: schedules and prints the steps |
| `PulseHaptics/UI/Panel/Spec.lua:1780-1815` | Ramp button tooltip and the **Set Floor** button |
| `PulseChecklist/tests/harness.lua:1651-1663` | CR-025 checks on ramp duration and tooltip |
| `PulseChecklist/tests/engine-test.lua:413-421` | Active-ramp tracking test |

**Current settings**

```lua
Pulse.RAMP_PEAK = 0.40
Pulse.RAMP_STEP = 0.01
Pulse.RAMP_STEP_SECONDS = 0.4   -- 40 steps, ~16 s
```

The floor slider runs from 0 to 0.40 in steps of 0.005. Since commit `72950f5`, every preset floor is
between **0.025 and 0.065**.

---

### Problem statements

#### P1: The ramp is too coarse for where floors now are

A 0.01 step can only report the floor to ±0.005. On a floor of 0.025–0.065, that is an error of
**±8–20%** of the value being measured.

The comment above the constants (`Devices.lua:150-154`) rejected the first design because 0.025 steps
meant ±8% error on a floor of "about 0.15". Floors have since moved down by about 3×, so the same
problem is back, and it is worse than before. The ramp's step is also twice the slider's step (0.005),
so every other slider value can never be read off the ramp.

#### P2: Most of the sweep is spent above any plausible answer

The ramp climbs to 0.40, but the highest preset floor is 0.065. About **85% of the 16 seconds**
happens above the range the reading will land in. That time would be better spent on finer steps where
the answer actually is.

#### P3: 0.4 s per step is shorter than the time from feeling to reading

Several delays add up within each step:

- **Motor spin-up near the threshold.** An ERM motor at barely-above-breakaway drive has almost no
  spare torque, so it accelerates slowly. The first felt movement can arrive well into the step.
- **Human detection.** Reaction time to a touch stimulus is typically 200–400 ms.
- **Reading the chat.** The printed line changes at the start of each step.

When these add up past 0.4 s, the person feels step *N* while step *N+1* is already on screen, and the
reading comes out one step too high.

#### P4: Set Floor records the step showing when the button is clicked, not the step that was felt

`Spec.lua` stores `ramp.magnitude`, the current step at the moment of the click:

```lua
local floorVal = ramp.magnitude
store:SetChannelTuning(channel, "floor", floorVal, 0.0, 0.40)
```

Clicking takes longer than reading a number: the person has to notice, move the pointer or controller
focus, then click. That delay adds to P3, so the saved floor is **consistently too high**, by one step
or more. The button exists to make calibration easy, but it gives a less accurate result than reading
the chat.

#### P5 (minor): Stale fallbacks and comments

- `Spec.lua:1788-1790` falls back to `or 0.40`, `or 0.01` and `or 0.4`. These copy today's values and
  will quietly disagree once the constants change.
- `Engine.lua:1014` says *"Nothing currently calls StopRamp"*, but Set Floor does
  (`Spec.lua`, `Pulse.Engine:StopRamp(channel)`).
- `harness.lua:1652-1659` hardcodes "16 seconds" and "40%". These checks must change along with the
  constants.

---

### Proposed fixes

#### F1: Change the ramp shape (fixes P1, P2, P3)

| | Peak | Step | Interval | Steps | Duration | Reading error |
|---|---|---|---|---|---|---|
| Current | 0.40 | 0.01 | 0.4 s | 40 | 16 s | ±0.005 (±8–20%) |
| **Proposed** | **0.20** | **0.005** | **0.5 s** | **40** | **20 s** | **±0.0025 (±4–10%)** |

- **Step 0.005** matches the slider, so every reading can be entered exactly. Going finer is probably
  not useful: many rumble drivers appear to round intensity to 8 bits (about 0.004 per level).
- **Peak 0.20** is about 3× the highest preset floor, which leaves headroom for worn or unusual motors.
  A motor that is still silent at 0.20 is broken, and the Test button shows that faster.
- **0.5 s** gives slow spin-up and human reaction time room to finish within the same step.

The slider's 0.40 maximum stays as it is, so a higher floor can still be set by hand.

`PulseHaptics/Core/Devices.lua`, replacing lines 148-163:

```lua
-- Shape of the Ramp probe on the calibration page (Core/Engine.lua drives it).
--
-- Proportioned against where the answer plausibly lives rather than across the whole range.
-- Preset floors sit at 0.025-0.065, so the first two shapes both measured in the wrong place:
-- peak 0.5 / step 0.025, then peak 0.40 / step 0.01, the latter still reporting a 0.03 floor
-- only to ±0.005, about ±17% of the figure being measured.
--
-- The step matches the Breakaway floor slider (0.005), so every reading can be entered
-- exactly. Finer is not worth it: rumble drivers commonly quantise intensity to 8 bits.
--
-- No measurement backs the 0.20 ceiling; it is an instrument-design choice, roughly three
-- times the highest preset floor. Anything still silent at 20% is a dead motor rather than a
-- high floor, which the Test button answers faster. The slider still reaches 0.40.
--
-- 0.5s per step, because near breakaway an ERM has almost no spare torque and spins up
-- slowly, and the person then has to notice it. At 0.4s the felt step and the printed step
-- came apart often enough to read one step high.
--
-- 40 steps at 0.5s is twenty seconds. Long for a button, trivial for something pressed once
-- per controller.
Pulse.RAMP_PEAK = 0.20
Pulse.RAMP_STEP = 0.005
Pulse.RAMP_STEP_SECONDS = 0.5

-- How long after first feeling the motor a person typically clicks Set Floor. Set Floor
-- credits the step that was running this long before the click, not the one running at it.
-- An estimate, not a measurement: touch reaction time plus a click. Too high and the reading
-- comes out one step (0.005) low, which is the cheaper error: a floor slightly under
-- breakaway still lets the next step up start the motor.
Pulse.RAMP_REACTION_SECONDS = 0.35
```

#### F2: Correct Set Floor for reaction time (fixes P4)

Keep the ramp's start time, and look up which step was running `RAMP_REACTION_SECONDS` before the click.
The result can never be higher than the current step. Because every step lasts the same time, this is
a single calculation and needs no history.

`PulseHaptics/Core/Engine.lua`, in `Engine:RampChannel`:

```lua
	rampToken = (rampToken or 0) + 1
	local token = rampToken
	local generation = engineGeneration
	local startedAt = GetTime()
```

and in the per-step timer:

```lua
			self.activeRamp = {
				channel = channel,
				magnitude = magnitude,
				step = step,
				steps = steps,
				token = token,
				startedAt = startedAt,
				increment = increment,
				interval = interval,
			}
```

A new function next to `GetActiveRamp`:

```lua
-- The step the person FELT, not the one showing when they clicked. Set Floor lands a
-- reaction time after the sensation, and every step of that lag used to be written into the
-- floor. Steps are evenly spaced, so the step at any earlier moment is arithmetic rather
-- than history. Never later than the step running now.
function Engine:GetRampReading()
	local ramp = self.activeRamp
	if not ramp then
		return nil
	end
	local felt = GetTime() - ramp.startedAt - (Pulse.RAMP_REACTION_SECONDS or 0)
	local step = math.floor(felt / ramp.interval) + 1
	step = math.max(1, math.min(ramp.step, step))
	return ramp.increment * step, ramp
end
```

`PulseHaptics/UI/Panel/Spec.lua`, in the Set Floor handler:

```lua
			function()
				local floorVal, ramp = Pulse.Engine:GetRampReading()
				if ramp and ramp.channel == channel then
					store:SetChannelTuning(channel, "floor", floorVal, 0.0, 0.40)
					Pulse.Engine:StopRamp(channel)
					print(
						("Pulse: captured %s breakaway floor at %.3f (ramp was at %.3f when clicked)"):format(
							channel,
							floorVal,
							ramp.magnitude
						)
					)
					return true
				elseif ramp then
```

The rest of the handler stays the same. Printing both numbers lets the person see the correction and
override it with the slider if they disagree.

#### F3: Remove stale fallbacks and comments (fixes P5)

`Spec.lua:1786-1791`: the `.toc` loads `Core/Devices.lua` (line 38) before `UI/Panel/Spec.lua`
(line 128), so the fallbacks can never be used and can go. That leaves one source of truth:

```lua
			string.format(
				"Climbs this motor slowly from silence to %d%% power over %d seconds, ",
				math.floor(Pulse.RAMP_PEAK * 100 + 0.5),
				math.floor((Pulse.RAMP_PEAK / Pulse.RAMP_STEP) * Pulse.RAMP_STEP_SECONDS + 0.5)
			)
```

`Engine.lua:1014-1017`:

```lua
-- StopRamp is the explicit "stop and go quiet": Set Floor calls it once it has taken its
-- reading. The Test button does not — it interrupts a ramp through ProbeChannel, which
-- bumps rampToken so the remaining timers no-op and then drives the channel itself.
```

#### F4: Update and add tests

`PulseChecklist/tests/harness.lua:1652-1659`, replacing the hardcoded values:

```lua
		check("Ramp calibration duration is 20 seconds (CR-025)", expectedDuration, 20)
		...
					check("Ramp tooltip mentions 20 seconds (CR-025)", row.tooltip:find("20 seconds") ~= nil, true)
					check("Ramp tooltip mentions 20% power (CR-025)", row.tooltip:find("20%%") ~= nil, true)
```

`PulseChecklist/tests/engine-test.lua`, after the "Active Ramp Tracking" block. It uses the file's
existing fake clock (`now`, `runTimersTo`):

```lua
-- ── Set Floor credits the felt step, not the clicked one ─────────────────────

Engine:RampChannel("Low")
local t0 = now
local dt, inc = Pulse.RAMP_STEP_SECONDS, Pulse.RAMP_STEP
local function near(a, b)
	return a ~= nil and math.abs(a - b) < 1e-9
end

-- 0.1s into step 3: within the reaction window, so step 2 is credited.
runTimersTo(t0 + 2 * dt + 0.1)
check("reading steps back inside the reaction window", near(Engine:GetRampReading(), 2 * inc), true)
check("  while the ramp itself is on step 3", Engine:GetActiveRamp().step, 3)

-- Past the reaction window into step 3: step 3 is credited.
runTimersTo(t0 + 2 * dt + Pulse.RAMP_REACTION_SECONDS + 0.01)
check("reading holds once the window has passed", near(Engine:GetRampReading(), 3 * inc), true)

-- Very early click on step 1 never goes below step 1.
Engine:StopRamp("Low")
Engine:RampChannel("Low")
runTimersTo(now + 0.01)
check("reading never drops below the first step", near(Engine:GetRampReading(), inc), true)
Engine:StopRamp("Low")
check("no reading without a ramp", Engine:GetRampReading(), nil)
```

---

### Effect on installed copies

- Floors that are already saved are **not changed**. These fixes only affect new measurements.
- Anyone who calibrated with **Set Floor** under the old settings probably has a floor one step (0.01)
  or more too high. It may be worth re-running Ramp on each controller once.

### Verification plan

1. `scripts/test.sh`: all suites pass, including the updated CR-025 checks and the new
   `GetRampReading` tests.
2. In game, on each controller: press Ramp and confirm the chat says 20 s / 20% and prints steps
   in 0.005 increments. Click Set Floor when the motor first moves, and check that the printed
   "captured" value is at or one step below the "ramp was at" value.
3. Compare the captured floor against the preset value for that controller (0.025–0.065).
