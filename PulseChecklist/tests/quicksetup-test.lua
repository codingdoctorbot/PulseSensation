-- Wizard behavior tests against the real database, registry and UI constructors.
-- Frame/security behavior is mocked; live gamepad and combat verification is still needed.
local output = io.write
local baseline = {}
io.write = function(...)
	baseline[#baseline + 1] = table.concat({ ... })
end
dofile((arg[1] or "PulseHaptics") .. "/../PulseChecklist/tests/harness.lua")
io.write = output
assert(not table.concat(baseline):find("FAILURES:"), "base settings harness failed")

local P = _G.Pulse
local Q = P.UI.QuickSetup
local failures, checks = 0, 0
local function check(label, got, want)
	checks = checks + 1
	if got ~= want then
		failures = failures + 1
		io.write("FAIL " .. label .. ": got " .. tostring(got) .. ", expected " .. tostring(want) .. "\n")
	end
end
local function upvalue(fn, wanted)
	for i = 1, 100 do
		local name, value = debug.getupvalue(fn, i)
		if not name then
			break
		end
		if name == wanted then
			return value
		end
	end
	error("missing wizard state " .. wanted)
end
local combat, bindingCalls, deniedCalls = false, 0, 0
local bindings = {}
function InCombatLockdown()
	return combat
end
function SetOverrideBindingClick(owner, _, key, button)
	bindingCalls = bindingCalls + 1
	bindings[key] = { owner = owner, button = button }
end
function ClearOverrideBindings(owner)
	if combat then
		deniedCalls = deniedCalls + 1
		error("binding changes are blocked during combat")
	end
	for key, binding in pairs(bindings) do
		if binding.owner == owner then
			bindings[key] = nil
		end
	end
end
local function bindingCount()
	local count = 0
	for _ in pairs(bindings) do
		count = count + 1
	end
	return count
end
local ids = {
	"glideThrust",
	"locomotion",
	"waterTexture",
	"swimTexture",
	"oceanTexture",
	"castTexture",
	"craftTexture",
	"weatherTexture",
	"breathTexture",
	"lowHealthWarning",
	"taxiRide",
	"stealthTexture",
}
local defaults = { castTexture = true, craftTexture = true, breathTexture = true, lowHealthWarning = true }
local function clickChecked(widget, checked)
	widget:SetChecked(checked)
	widget:GetScript("OnClick")(widget)
end

-- Only genuinely new saved data receives onboarding defaults, once the wizard opens.
Q.Close()
_G.PulseDB = nil
P.Database:Init()
check("fresh install queues wizard defaults", P.Database:Get("quickSetupDefaultsPending"), true)
Q.Open(5)
local frame = _G.PulseQuickSetupFrame
local steps = upvalue(Q.Open, "stepFrames")
for _, id in ipairs(ids) do
	check("new wizard default " .. id, P.Database:GetCue(id), defaults[id] or false)
	if defaults[id] then
		check("default parent enabled " .. id, P:GatesOpen(id), true)
	end
end
check("defaults consumed once", P.Database:Get("quickSetupDefaultsPending"), false)
P.Database:SetCue("castTexture", false)
P.Database:SetCue("weatherTexture", true)
Q.Close()
P.Database:Init() -- reload equivalent: keep the persisted marker and choices
Q.Open(5)
check("reopen keeps casting choice", P.Database:GetCue("castTexture"), false)
check("reopen keeps weather choice", P.Database:GetCue("weatherTexture"), true)
Q.Close()
-- Upgrading an existing configuration never resets its preferences.
_G.PulseDB.quickSetupDefaultsPending = nil
P.Database:Init()
Q.Open(5)
check("existing install has no pending reset", P.Database:Get("quickSetupDefaultsPending"), false)
check("upgrade keeps casting choice", P.Database:GetCue("castTexture"), false)
check("upgrade keeps weather choice", P.Database:GetCue("weatherTexture"), true)

-- Every individual texture and the group master must open the actual registry gates.
for i, id in ipairs(ids) do
	local gate = P.Registry.CUE_GATE[id]
	if gate then
		P.Database:SetCue(gate, false)
	end
	P.Database:SetCue(id, false)
	clickChecked(steps[5].navTargets[2 * i].widget, true)
	check("texture enabled " .. id, P.Database:GetCue(id), true)
	check("texture parent enabled " .. id, P:GatesOpen(id), true)
end
for _, id in ipairs(ids) do
	local gate = P.Registry.CUE_GATE[id]
	if gate then
		P.Database:SetCue(gate, false)
	end
end
clickChecked(steps[5].navTargets[1].widget, true)
for _, id in ipairs(ids) do
	check("master enables parent " .. id, P:GatesOpen(id), true)
end
clickChecked(steps[5].navTargets[1].widget, false)
for _, id in ipairs(ids) do
	check("master disables texture " .. id, P.Database:GetCue(id), false)
end

local groups = {
	{ 3, 1, { "lootReceived", "questComplete", "questAccepted", "levelUp", "achievement", "xpGained" } },
	{ 3, 3, { "targetChanged", "focusChanged", "softTargetInteraction" } },
	{ 4, 1, { "uiInfoMessage", "merchantShow", "bankOpened" } },
	{ 4, 3, { "whisper", "partyInvite", "readyCheck", "queuePop" } },
}
for _, group in ipairs(groups) do
	for _, id in ipairs(group[3]) do
		local gate = P.Registry.CUE_GATE[id]
		if gate then
			P.Database:SetCue(gate, false)
		end
	end
	clickChecked(steps[group[1]].navTargets[group[2]].widget, true)
	for _, id in ipairs(group[3]) do
		check("group cue enabled " .. id, P.Database:GetCue(id), true)
		check("group parent enabled " .. id, P:GatesOpen(id), true)
	end
end

-- Native controller input remains live, without a second hidden capture path.
Q.Close()
Q.Open(1)
check("no capture bindings installed", bindingCalls, 0)
check("no owned overrides left open", bindingCount(), 0)
P.Database:ApplyDevicePreset("default")
frame:GetScript("OnGamePadButtonDown")(frame, "PAD1")
check("native confirm activates selected controller", P.Database:GetAppliedDevicePreset(), "dualsense")
frame:GetScript("OnGamePadButtonDown")(frame, "PADRSHOULDER")
frame:GetScript("OnGamePadButtonDown")(frame, "PADLSHOULDER")
check("native bumpers return to first page", upvalue(Q.Open, "currentStep"), 1)

-- Defensive cleanup queues owned stale bindings if combat prevents clearing them.
bindings.PAD1 = { owner = frame, button = "old capture" }
combat = true
frame:GetScript("OnEvent")(frame, "PLAYER_REGEN_DISABLED")
check("wizard closes on combat", frame:IsShown(), false)
check("no protected cleanup attempted in combat", deniedCalls, 0)
combat = false
frame:GetScript("OnEvent")(frame, "PLAYER_REGEN_ENABLED")
check("deferred cleanup releases stale bindings", bindingCount(), 0)
Q.Open(1)
Q.Close()
check("repeated open/close never installs captures", bindingCalls, 0)

-- Advanced Settings uses the same native input and deferred owner cleanup policy.
P.UI.Panel.Open()
local settingsFrame = _G.PulseSettingsFrame
check("settings never installs capture bindings", bindingCalls, 0)
settingsFrame:GetScript("OnGamePadButtonDown")(settingsFrame, "PAD2")
check("settings native back closes window", settingsFrame:IsShown(), false)
P.UI.Panel.Open()
bindings.PAD1 = { owner = settingsFrame, button = "old settings capture" }
combat = true
P.UI.Panel.Close()
check("settings avoids protected cleanup in combat", deniedCalls, 0)
combat = false
assert(rawget(settingsFrame, "__hook_OnEvent"))(settingsFrame, "PLAYER_REGEN_ENABLED")
check("settings retries its own pending cleanup", bindingCount(), 0)

-- Escape/template Hide must stop a preview just like the explicit Close button.
Q.Open(5)
local cancelCount = 0
local originalCancel = P.CancelContinuousPreview
P.CancelContinuousPreview = function()
	cancelCount = cancelCount + 1
end
frame:Hide()
check("Escape cancels continuous preview", cancelCount, 1)
P.CancelContinuousPreview = originalCancel

-- Entering the wizard during combat defers first-run defaults rather than consuming them.
_G.PulseDB = {}
P.Database:Init()
combat = true
Q.Open(1)
check("combat preserves pending defaults", P.Database:Get("quickSetupDefaultsPending"), true)
combat = false
Q.Open(1)
for _, id in ipairs(ids) do
	check("delayed default " .. id, P.Database:GetCue(id), defaults[id] or false)
end
Q.Close()

io.write((failures == 0 and "PASS" or "FAIL") .. ": " .. checks .. " wizard checks; " .. failures .. " failures\n")
if failures > 0 then
	os.exit(1)
end
