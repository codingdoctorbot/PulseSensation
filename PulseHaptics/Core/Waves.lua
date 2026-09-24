-- Pulse — Core/Waves.lua
--
-- Signal-shaping for continuous cues. Three independent functions and nothing else: no
-- scheduler, no layer handling, no engine contact. Each takes numbers and returns 0..1, so
-- a cue author builds a texture without re-deriving wave maths and the engine keeps owning
-- blending, smoothing, routing and output.
--
-- Consumers: Modules/Movement.lua (waterTexture via Sine, swimTexture via Harmonic) and
-- Modules/PlayerState.lua (via Sine). taxiRide, glideThrust, castTexture and breathTexture
-- still carry their own hand-rolled sine calls — they were tuned by feel against that
-- maths, and rerouting them would change how they feel for no benefit.
--
-- None of the three calls the others. A caller composes them, or uses one alone:
--
--     local v = Pulse.Waves.Sine(baseline, 1.2, 0.15)
--     v = Pulse.Haptics.MicroFlutter(v)
--     Pulse:HoldIfEnabled("someTexture", v, 0)
--
-- The Waves/Haptics split is deliberate. A wave is PERCEIVED DESIGN — the author decided
-- this texture should breathe. MicroFlutter is an IMPLEMENTATION DETAIL, existing so a
-- steady signal keeps clearing the engine's change threshold, and meant to be
-- imperceptible. Keeping them apart stops the two becoming one "add some wobble" helper
-- doing two unrelated jobs.

local ADDON_NAME, Pulse = ...

Pulse.Waves = Pulse.Waves or {}
Pulse.Haptics = Pulse.Haptics or {}

-- Hand-rolled, not math.clamp — CONFIRMED absent on this client (Core/Engine.lua's header
-- notes math.lerp failing the same way). Local because no file here exports one.
local function clamp01(v)
	if v ~= v then
		return 0
	end -- NaN in, silence out
	if v < 0 then
		return 0
	end
	if v > 1 then
		return 1
	end
	return v
end

local TWO_PI = math.pi * 2

-- 1. Sine — a baseline that breathes
--
--     output = baseline * (1 + depth * sin(2*pi*f*t + phase))
--
-- The wave modulates AROUND the requested strength rather than replacing it: the cue
-- decides how strong it should be from game state, this decides how that strength moves
-- over time, and neither has to know about the other.
--
--   baseline   desired strength, 0..1 — the real amplitude of the cue.
--   frequency  cycles per second. HZ, NOT radians per second. The ad-hoc calls left in
--              Movement.lua and Combat.lua pass radians/sec straight to math.sin, so their
--              numbers are not transferable without dividing by 2*pi.
--   depth      swing either side of the baseline, as a fraction of it. 0.15 = ±15%.
--              0 = a flat hold, a legitimate use.
--   phase      optional radians offset. Two cues on one frequency otherwise move in
--              lockstep, which reads as one texture rather than two.
--   time       optional, defaults to GetTime(). Pass it to phase-lock several cues to one
--              clock reading, or to make a test deterministic.
--
-- Returns 0..1, clamped: baseline plus depth can mathematically exceed 1, and clamping here
-- rather than in every caller is the point of a shared helper.
function Pulse.Waves.Sine(baseline, frequency, depth, phase, time, thetaOverride)
	baseline = baseline or 0
	if baseline <= 0 then
		return 0
	end

	frequency = frequency or 1.0
	depth = depth or 0
	if depth == 0 then
		return clamp01(baseline)
	end

	local t = time or GetTime()
	local theta = thetaOverride or (TWO_PI * frequency * t + (phase or 0))
	return clamp01(baseline * (1.0 + depth * math.sin(theta)))
end

-- 2. Harmonic — a baseline that breathes with a shape
--
--     composite = ( sin(theta) + h * sin(2*theta + harmonicPhase) ) / (1 + |h|)
--     output    = baseline * (1 + depth * composite)
--
-- A second harmonic at twice the fundamental, which is what buys a different waveform
-- family. Same-frequency sine plus cosine does not: sin(x) + cos(x) reduces to
-- sqrt(2)*sin(x + pi/4), a phase-shifted sine and nothing new. A 2f component reshapes the
-- cycle — sharper peaks, softer troughs, or an asymmetric swell depending on harmonicPhase.
--
-- THE NORMALISATION MATTERS and is not in the original proposal. `sin(x) + h*sin(2x)` peaks
-- at up to 1 + |h|, so undivided, adding a harmonic silently widens the swing and `depth`
-- stops meaning its name — 0.15 with harmonic 0.5 would really be 0.225. Dividing keeps the
-- composite inside ±1, so harmonic changes the SHAPE, depth changes the SIZE, and neither
-- moves the other.
--
--   harmonic       amount of 2f content. 0 gives exactly Sine's output. Sensible range is
--                  roughly 0..0.5; negative inverts it, a different shape not a mistake.
--   harmonicPhase  optional radians offset of the harmonic against the fundamental — the
--                  knob deciding whether the cycle leans forward or back.
--
-- Every other parameter behaves exactly as in Sine above.
function Pulse.Waves.Harmonic(baseline, frequency, depth, harmonic, harmonicPhase, phase, time, thetaOverride)
	baseline = baseline or 0
	if baseline <= 0 then
		return 0
	end

	frequency = frequency or 1.0
	depth = depth or 0
	harmonic = harmonic or 0
	if depth == 0 then
		return clamp01(baseline)
	end

	local t = time or GetTime()
	local theta = thetaOverride or (TWO_PI * frequency * t + (phase or 0))

	if harmonic == 0 then
		-- Skip the second sine entirely: a continuous cue evaluates this every frame, and
		-- a caller leaving the harmonic at zero should pay exactly what Sine costs.
		return clamp01(baseline * (1.0 + depth * math.sin(theta)))
	end

	local composite = math.sin(theta) + harmonic * math.sin(2 * theta + (harmonicPhase or 0))
	composite = composite / (1.0 + math.abs(harmonic))

	return clamp01(baseline * (1.0 + depth * composite))
end

-- 3. MicroFlutter — keeping a steady signal alive
--
-- Not a texture. A technical nudge, and it should never be felt as anything.
--
-- The problem is real and was hit live: the engine only calls SetVibration when a channel
-- moves further than the change threshold (Core/Engine.lua's epsilon gate), so a perfectly
-- steady hold stops producing calls, and on some hardware that reads as the motor stopping
-- and restarting rather than holding. Combat.lua's channel hum already carries a
-- hand-rolled version of this fix.
--
-- AMPLITUDE IS DERIVED, NOT FIXED, correcting the micro-variance proposal's 0.0007 — a
-- peak-to-peak swing of 0.0014, smaller than the 0.0015 default threshold it exists to
-- defeat, so it would be gated out and do nothing. Combat.lua's demonstrably working value
-- is 0.01, roughly seven times the threshold.
--
--     amplitude = max(MIN_AMPLITUDE, epsilon * EPSILON_MULTIPLE)
--
-- which stays correct if the player moves the Change threshold slider on the calibration
-- page, and never drops below the value already known to work. The figure is
-- PRE-SMOOTHING: the engine's attack/release filter attenuates a 7Hz wobble considerably,
-- so the swing actually delivered to the motor is a good deal smaller.
local MICRO_FLUTTER_HZ = 7.0
local MICRO_FLUTTER_MIN = 0.01 -- the amplitude confirmed working in Combat.lua
local MICRO_FLUTTER_EPS_MULT = 4.0 -- headroom over the gate if the threshold is raised

-- Returns the flutter offset alone, unclamped and signed, for a caller that wants to
-- inspect or scale it. Most callers want MicroFlutter below.
function Pulse.Haptics.MicroFlutterOffset(amount, time)
	local amplitude = amount
	if not amplitude then
		local epsilon = Pulse.Database and Pulse.Database.GetChangeEpsilon and Pulse.Database:GetChangeEpsilon() or 0
		amplitude = math.max(MICRO_FLUTTER_MIN, epsilon * MICRO_FLUTTER_EPS_MULT)
	end
	local t = time or GetTime()
	return math.sin(TWO_PI * MICRO_FLUTTER_HZ * t) * amplitude
end

-- Apply the nudge to a value. Silence stays silence: a zero input must never come back
-- humming, for the same reason the breakaway floor must not (Core/Engine.lua).
--
--   value   the signal to keep alive, 0..1.
--   amount  optional explicit amplitude, overriding the derived one. For cooking.
--   time    optional, defaults to GetTime().
function Pulse.Haptics.MicroFlutter(value, amount, time)
	value = value or 0
	if value <= 0 then
		return 0
	end
	return clamp01(value + Pulse.Haptics.MicroFlutterOffset(amount, time))
end
