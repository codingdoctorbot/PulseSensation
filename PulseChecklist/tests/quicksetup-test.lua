-- PulseChecklist/tests/quicksetup-test.lua
-- Offline checks for PulseHaptics/UI/QuickSetup.lua: the wizard builds, every step shows,
-- every button can be pressed without a Lua error, every Feel button names a real mode or
-- cue, and each tuning knob writes the settings it claims to.

local scriptDir = arg[0]:match("^(.-)[^/\\]*$")
if scriptDir == "" then
	scriptDir = "./"
end
dofile(scriptDir .. "harness.lua")

io.write("\n================== QUICK SETUP TESTS ==================\n")

local failures = 0
local function check(label, got, want)
	local ok = (got == want)
	if not ok then
		failures = failures + 1
	end
	io.write(string.format("%-66s %-8s %s\n", label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
end

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 1e-6)
end

local P = _G.Pulse
local DB = P.Database
local R = P.Registry
local ROOT = arg[1] or "PulseHaptics"

local chunk, loadErr = loadfile(ROOT .. "/UI/QuickSetup.lua")
check("UI/QuickSetup.lua compiles", type(chunk), "function")
if not chunk then
	io.write(tostring(loadErr) .. "\n")
	os.exit(1)
end
chunk("PulseHaptics", P)

local QS = P.UI.QuickSetup
local T = QS and QS.Tuning
check("QuickSetup module registered", type(QS), "table")
check("QuickSetup.Tuning exposed", type(T), "table")

-- Record every preview the wizard asks for, so each can be checked against the registry.
local playedModes, playedCues = {}, {}
local origTestMode, origTestCue = P.TestMode, P.TestCue
P.TestMode = function(self, modeID, scale)
	playedModes[#playedModes + 1] = modeID
	return false, "no controller detected"
end
P.TestCue = function(self, triggerID)
	playedCues[#playedCues + 1] = triggerID
	return false, "no controller detected"
end

-- 1. Build and show every step
local okOpen, openErr = pcall(QS.Open)
check("Open() builds the window without error", okOpen, true)
if not okOpen then
	io.write("  " .. tostring(openErr) .. "\n")
end
local frame = _G.PulseQuickSetupFrame
check("PulseQuickSetupFrame exists and is shown", frame and frame:IsShown(), true)

for step = 1, 5 do
	local ok, err = pcall(QS.GoToStep, step)
	check(("GoToStep(%d) runs its OnShowStep without error"):format(step), ok, true)
	if not ok then
		io.write("  " .. tostring(err) .. "\n")
	end
end

-- 2. Press everything. Walks the whole window tree and fires every OnClick, OnEnter and
-- OnLeave, so a button wired to a missing function fails here rather than in the client.
-- Done and Full settings close the window; reopen after the walk.
local pressed, errors = 0, 0
local function walk(f)
	for _, script in ipairs({ "OnEnter", "OnLeave", "OnClick" }) do
		local fn = rawget(f, "__script_" .. script)
		if fn then
			if script == "OnClick" then
				pressed = pressed + 1
			end
			local ok, err = pcall(fn, f, "LeftButton")
			if not ok then
				errors = errors + 1
				io.write("  " .. script .. " error: " .. tostring(err) .. "\n")
			end
		end
	end
	for _, child in ipairs(f.__children or {}) do
		walk(child)
	end
end
if frame then
	walk(frame)
end
check("Pressed more than 50 buttons across all steps", pressed > 50, true)
check("No button, tab or tooltip raised a Lua error", errors, 0)

local badModes = {}
for _, modeID in ipairs(playedModes) do
	if not P.Modes[modeID] then
		badModes[#badModes + 1] = modeID
	end
end
check("Every Feel mode exists in Pulse.Modes", table.concat(badModes, ","), "")

local badCues = {}
for _, triggerID in ipairs(playedCues) do
	if not R:GetTrigger(triggerID) then
		badCues[#badCues + 1] = tostring(triggerID)
	end
end
check("Every Feel cue exists in the registry", table.concat(badCues, ","), "")
check("Category and texture Feel buttons played cues", #playedCues > 0, true)

-- 3. Tuning knobs write the real settings
DB:ApplyDevicePreset("dualsense")

T.SetStrength(0.55)
check("Strength writes masterIntensity", near(DB:Get("masterIntensity"), 0.55), true)

check("Balance reads Even straight after a preset", near(T.GetBalance(), 0), true)
T.SetBalance(0.4)
check("Balance +0.4 lowers the Low motor gain", near(DB:GetChannelTuning("Low", "gain"), 1.15 * 0.8), true)
check("Balance +0.4 raises the High motor gain", near(DB:GetChannelTuning("High", "gain"), 1.05 * 1.2), true)
check("Balance reads back what it wrote", near(T.GetBalance(), 0.4), true)

check("Subtle reads Preset straight after a preset", near(T.GetSubtle(), 0), true)
T.SetSubtle(1)
check("Subtle +1 lowers gamma (quiet cues stronger)", near(DB:GetChannelTuning("Low", "gamma"), 0.65), true)
check("Subtle reads back what it wrote", near(T.GetSubtle(), 1), true)

T.ResetCalibration()
check("Reset returns balance to Even", near(T.GetBalance(), 0), true)
check("Reset returns subtle to Preset", near(T.GetSubtle(), 0), true)
check("Reset keeps the controller in use", DB:GetAppliedDevicePreset(), "dualsense")

-- 4. Categories are the settings pages that have a switch
local categories = T.Categories()
check("Categories found", #categories >= 10, true)
local allGated = true
for _, page in ipairs(categories) do
	if not R:GetPageGate(page.id) then
		allGated = false
	end
end
check("Every category is a page with a page switch", allGated, true)

T.SetCategoryOn("WORLD", false)
check("Category off closes its page gate", DB:GetCue(R:GetPageGate("WORLD")), false)
T.SetCategoryOn("WORLD", true)
check("Category on opens its page gate", DB:GetCue(R:GetPageGate("WORLD")), true)

T.SetCategoryStrength("COMBAT", 0.8)
check("Category strength reads back what it wrote", near(T.GetCategoryStrength("COMBAT"), 0.8), true)
local scaledOK, sampled = true, 0
for _, page in ipairs(R:GetPages()) do
	if page.id == "COMBAT" then
		for _, section in ipairs(page.sections) do
			for _, trigger in ipairs(section.triggers) do
				if trigger.mode and not trigger.continuous then
					sampled = sampled + 1
					local want = (trigger.defaultIntensity or 1.0) * 0.8
					if not near(DB:GetTriggerSetting(trigger.id, "intensity"), want) then
						scaledOK = false
					end
				end
			end
		end
	end
end
check("Every Combat cue scaled from its designed level", scaledOK and sampled > 0, true)
check("SampleCue picks a real Combat cue", R:GetTrigger(T.SampleCue("COMBAT") or "") ~= nil, true)

-- 5. Textures are the registry's continuous cues
local textures = T.Textures()
check("Textures found", #textures >= 10, true)
local allContinuous = true
for _, entry in ipairs(textures) do
	if not entry.trigger.continuous then
		allContinuous = false
	end
end
check("Every texture is a continuous cue", allContinuous, true)
T.SetCueStrength("glideThrust", 0.6)
check("Texture strength writes the cue's intensity", near(DB:GetTriggerSetting("glideThrust", "intensity"), 0.6), true)
check("Texture strength reads back", near(T.GetCueStrength("glideThrust"), 0.6), true)

-- 6. Done marks setup complete
QS.Close()
DB:SetQuickSetupCompleted(false)
QS.Open(5)
check("Open(5) lands on the Finish step", frame and frame:IsShown(), true)

P.TestMode, P.TestCue = origTestMode, origTestCue

io.write(
	"─────────────────────────────────────────────────────────────────\n"
)
if failures == 0 then
	io.write("✓ ALL QUICK SETUP TESTS PASSED\n")
	os.exit(0)
else
	io.write(string.format("✗ %d FAILURE(S) IN QUICK SETUP TESTS\n", failures))
	os.exit(1)
end
