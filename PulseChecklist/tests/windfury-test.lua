-- PulseChecklist/tests/windfury-test.lua
-- Unit tests for PulseHaptics/Modules/Windfury.lua and experimental Windfury tracking.

local scriptDir = arg[0]:match("^(.-)[^/\\]*$")
if scriptDir == "" then
	scriptDir = "./"
end
dofile(scriptDir .. "harness.lua")

io.write("\n================== WINDFURY MODULE TESTS ==================\n")

local failures = 0
local function check(label, got, want)
	local ok = (got == want)
	if not ok then
		failures = failures + 1
	end
	io.write(string.format("%-66s %-8s %s\n", label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
end

local P = _G.Pulse
local DB = P.Database
local R = P.Registry

-- 1. Registry & Cues
local swingCue = R:GetTrigger("windfurySwing")
local spellCue = R:GetTrigger("windfurySpell")

check("windfurySwing cue exists in Registry", swingCue ~= nil, true)
check("windfurySwing category is EXPERIMENTAL", swingCue and swingCue.category, "EXPERIMENTAL")
check("windfurySwing mode is BURST", swingCue and swingCue.mode, "BURST")
check("windfurySwing default is false", swingCue and swingCue.default, false)

check("windfurySpell cue exists in Registry", spellCue ~= nil, true)
check("windfurySpell category is EXPERIMENTAL", spellCue and spellCue.category, "EXPERIMENTAL")
check("windfurySpell mode is BURST", spellCue and spellCue.mode, "BURST")
check("windfurySpell default is false", spellCue and spellCue.default, false)

-- 2. PAGE_LAYOUT
local expPage = nil
for _, page in ipairs(R:GetPages()) do
	if page.id == "EXPERIMENTAL" then
		expPage = page
		break
	end
end
check("EXPERIMENTAL page exists in PAGE_LAYOUT", expPage ~= nil, true)
check("EXPERIMENTAL page label is 'Experimental'", expPage and expPage.label, "Experimental")

local hasSwingInPage = false
local hasSpellInPage = false
if expPage then
	for _, sec in ipairs(expPage.sections) do
		for _, trig in ipairs(sec.triggers) do
			if trig.id == "windfurySwing" then
				hasSwingInPage = true
			end
			if trig.id == "windfurySpell" then
				hasSpellInPage = true
			end
		end
	end
end
check("windfurySwing rendered in Experimental page", hasSwingInPage, true)
check("windfurySpell rendered in Experimental page", hasSpellInPage, true)

-- 3. Module Registration & Frame Interception
local ROOT = arg[1] or "PulseHaptics"
local registeredEvents = {}
local registeredScripts = {}
local origCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...)
	local f = origCreateFrame(...)
	local origSetScript = f.SetScript
	rawset(f, "SetScript", function(self, name, fn)
		registeredScripts[name] = fn
		if origSetScript then
			origSetScript(self, name, fn)
		end
	end)
	rawset(f, "RegisterEvent", function(self, ev)
		registeredEvents[ev] = true
	end)
	rawset(f, "RegisterUnitEvent", function(self, ev)
		registeredEvents[ev] = true
	end)
	return f
end

local wfChunk = loadfile(ROOT .. "/Modules/Windfury.lua")
check("Modules/Windfury.lua compiles cleanly", type(wfChunk), "function")
if wfChunk then
	wfChunk("Pulse", P)
end

_G.CreateFrame = origCreateFrame

local Windfury = P.modules and P.modules["Windfury"]
check("Windfury module registered in Pulse", Windfury ~= nil, true)

-- 4. Behavior & Mock Tests
DB:Set("masterEnabled", true)
DB:SetCue("windfurySwing", true)
DB:SetCue("windfurySpell", true)

-- Capture fired cues
local firedCues = {}
local origFire = P.FireIfEnabled
P.FireIfEnabled = function(self, id)
	firedCues[#firedCues + 1] = id
	return origFire(self, id)
end

-- Re-enable module to hook frames
Windfury:OnEnable()

check("Windfury frame registered PLAYER_SWING", registeredEvents["PLAYER_SWING"] == true, true)
check("Windfury frame registered UNIT_SPELLCAST_SUCCEEDED", registeredEvents["UNIT_SPELLCAST_SUCCEEDED"] == true, true)

-- Mock time
local mockTime = 100.0
_G.GetTime = function()
	return mockTime
end

local onEvent = registeredScripts["OnEvent"]
if onEvent then
	-- Swing 1: Normal auto-attack at t = 100.0s (weapon speed = 2.6s)
	mockTime = 100.0
	wipe(firedCues)
	onEvent(nil, "PLAYER_SWING", 2.6, 0)
	check("Normal swing at t=100.0 does NOT trigger windfurySwing", #firedCues, 0)

	-- Swing 2: Windfury bonus swing at t = 100.06s (dt = 0.06s < 2.6 * 0.5)
	mockTime = 100.06
	wipe(firedCues)
	onEvent(nil, "PLAYER_SWING", 2.6, 0)
	check("Extra attack at t=100.06 TRIGGERS windfurySwing", #firedCues == 1 and firedCues[1], "windfurySwing")

	-- Swing 3: Second Windfury bonus swing at t = 100.10s (dt = 0.04s) - should debounce
	mockTime = 100.10
	wipe(firedCues)
	onEvent(nil, "PLAYER_SWING", 2.6, 0)
	check("Second extra attack within 400ms is debounced", #firedCues, 0)

	-- Swing 4: Secret value safety test
	mockTime = 101.0
	_G.__secrets = _G.__secrets or {}
	_G.__secrets[9999] = true
	wipe(firedCues)
	onEvent(nil, "PLAYER_SWING", 2.6, 9999)
	check("Secret swingType safely ignored", #firedCues, 0)

	-- Off-hand swing (type 1) ignored
	mockTime = 101.5
	wipe(firedCues)
	onEvent(nil, "PLAYER_SWING", 2.0, 1)
	check("Off-hand swing ignored", #firedCues, 0)

	-- Test Vector 2: Spellcast Succeeded Detection
	-- Unrelated spell (e.g. 133 Fireball)
	mockTime = 105.0
	wipe(firedCues)
	onEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 133)
	check("Unrelated spell (133) does not trigger windfurySpell", #firedCues, 0)

	-- Windfury Attack (Spell ID 25504)
	mockTime = 106.0
	wipe(firedCues)
	onEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 25504)
	check("Windfury Attack (25504) TRIGGERS windfurySpell", #firedCues == 1 and firedCues[1], "windfurySpell")

	-- Second spellcast within debounce cooldown
	mockTime = 106.1
	wipe(firedCues)
	onEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 25504)
	check("Rapid duplicate spellcast is debounced", #firedCues, 0)

	-- Secret spellID
	mockTime = 108.0
	_G.__secrets[8888] = true
	wipe(firedCues)
	onEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 8888)
	check("Secret spellID safely ignored", #firedCues, 0)
end

-- Restore
P.FireIfEnabled = origFire

io.write(
	"─────────────────────────────────────────────────────────────────\n"
)
if failures == 0 then
	io.write("✓ ALL WINDFURY TESTS PASSED\n")
	os.exit(0)
else
	io.write(string.format("✗ %d FAILURE(S) IN WINDFURY TESTS\n", failures))
	os.exit(1)
end
