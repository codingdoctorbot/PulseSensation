-- IMPLEMENTATION_PLAN_PHASE0_1_2/tools/floor-model.lua
--
-- Pure-maths model of Core/Engine.lua mapValue's breakaway floor, three ways:
--   regressed  f623a8a..441f4f3: soft floor nested in the discrete branch, no else
--   fixed      0c74dc3 / plan P0.1: hard floor for discrete, soft floor for continuous
--   doc9.4     brainstormingcuepolish.md Thought 9.4: "1-12% clamped to 15%"
-- Presets as Core/Devices.lua: Xbox = ERM_LOW (floor 0.125, gamma 0.88) / ERM_HIGH (0.095, 0.88).
-- Run: luajit IMPLEMENTATION_PLAN_PHASE0_1_2/tools/floor-model.lua
local function c(v)
	if v < 0 then
		return 0
	elseif v > 1 then
		return 1
	end
	return v
end
local function soft(v, floor)
	local knee = math.max(0.02, floor * 0.5)
	local t = c(v / knee)
	return floor * t * t * (3 - 2 * t) + (1 - floor) * v
end
local function regressed(v, floor, gamma, discrete)
	if v <= 0 then
		return 0
	end
	v = v ^ gamma
	if discrete then
		v = floor + (1 - floor) * v
		v = soft(v, floor)
	end
	return c(v)
end
local function fixed(v, floor, gamma, discrete)
	if v <= 0 then
		return 0
	end
	v = v ^ gamma
	if discrete then
		v = floor + (1 - floor) * v
	else
		v = soft(v, floor)
	end
	return c(v)
end
local function doc(v)
	if v <= 0 then
		return 0
	elseif v <= 0.12 then
		return 0.15
	end
	return v
end
print("Discrete cue, Xbox HIGH motor (floor 0.095, gamma 0.88)")
print("  input   regressed   fixed")
for _, v in ipairs({ 0.02, 0.05, 0.0735, 0.10, 0.196, 0.30, 0.50, 0.80 }) do
	print(("  %.4f   %.3f       %.3f"):format(v, regressed(v, 0.095, 0.88, true), fixed(v, 0.095, 0.88, true)))
end
print("\nContinuous texture, Xbox LOW motor (floor 0.125, gamma 0.88)")
print("  input   regressed   fixed    (regressed < 0.125 = below breakaway)")
for _, v in ipairs({ 0.02, 0.05, 0.08, 0.10, 0.15, 0.30 }) do
	print(("  %.3f    %.3f       %.3f"):format(v, regressed(v, 0.125, 0.88, false), fixed(v, 0.125, 0.88, false)))
end
print("\nThought 9.4 clamp (not monotonic between 0.12 and 0.13)")
for _, v in ipairs({ 0.11, 0.12, 0.13, 0.14, 0.15 }) do
	print(("  in %.2f -> out %.2f"):format(v, doc(v)))
end
print("\nGain stacking example: TICK relIntensity 0.28 x master 0.7 x group 0.75 x cue 0.5 =", 0.28 * 0.7 * 0.75 * 0.5)
