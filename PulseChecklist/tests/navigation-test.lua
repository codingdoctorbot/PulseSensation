-- PulseChecklist/tests/navigation-test.lua
-- Unit tests for Game Menu integration, Quick Setup closing behavior, and Controller Navigation.

local scriptDir = arg[0]:match("^(.-)[^/\\]*$")
if scriptDir == "" then
	scriptDir = "./"
end
dofile(scriptDir .. "harness.lua")

io.write("\n================== CONTROLLER NAVIGATION & GAME MENU TESTS ==================\n")

local failures = 0
local function check(label, got, want)
	local ok = (got == want)
	if not ok then
		failures = failures + 1
	end
	io.write(string.format("%-66s %-8s %s\n", label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
end

local P = _G.Pulse
local UI = P.UI

-- 1. Game Menu Integration
check("Pulse.UI.GameMenu module exists", type(UI.GameMenu), "table")
check("Pulse.UI.GameMenu:Init function exists", type(UI.GameMenu.Init), "function")

-- Mock C_Timer.After to execute synchronously in offline test harness
_G.C_Timer = _G.C_Timer or {}
_G.C_Timer.After = function(_, fn)
	if fn then
		fn()
	end
end

if not _G.GameMenuFrame then
	_G.GameMenuFrame = _G.CreateFrame("Frame", "GameMenuFrame", _G.UIParent)
	_G.GameMenuFrame:SetSize(190, 260)
end

local bindingsRecorded = {}
_G.SetOverrideBindingClick = function(owner, priority, key, buttonName, mouseButton)
	bindingsRecorded[owner] = bindingsRecorded[owner] or {}
	bindingsRecorded[owner][key] = { button = buttonName, mouse = mouseButton }
end
_G.ClearOverrideBindings = function(owner)
	bindingsRecorded[owner] = nil
end

local btn1 = _G.CreateFrame("Button", "GameMenuButton1", _G.GameMenuFrame)
local btn2 = _G.CreateFrame("Button", "GameMenuButton2", _G.GameMenuFrame)
_G.GameMenuFrame.buttons = { btn1, btn2 }

UI.GameMenu:Init()
local menuBtn = _G.GameMenuButtonPulse or _G.PulseGameMenuButton
check("GameMenuButtonPulse created", menuBtn ~= nil, true)
check("GameMenuButtonPulse parent is UIParent (taint-free)", menuBtn and menuBtn:GetParent(), _G.UIParent)

-- Verify visibility synchronization and override binding on Show
_G.GameMenuFrame:Show()
check("GameMenuButtonPulse shows when GameMenuFrame shown", menuBtn:IsShown(), true)
check(
	"PAD3 override bound to PulseGameMenuButton",
	bindingsRecorded[menuBtn] and bindingsRecorded[menuBtn]["PAD3"] ~= nil,
	true
)

_G.GameMenuFrame:Hide()
check("GameMenuButtonPulse hides when GameMenuFrame hidden", menuBtn:IsShown(), false)
check("Override bindings cleared on hide", bindingsRecorded[menuBtn], nil)

-- 2. Quick Setup closes Main Panel
if UI.Panel and UI.Panel.EnsureBuilt then
	UI.Panel.EnsureBuilt()
end
if UI.Panel and UI.Panel.Open then
	UI.Panel.Open()
	check("Panel is open before QuickSetup.Open", UI.Panel.IsOpen(), true)

	if UI.QuickSetup and UI.QuickSetup.Open then
		UI.QuickSetup.Open()
		check("Panel is closed after QuickSetup.Open", UI.Panel.IsOpen(), false)
		UI.QuickSetup.Close()
	end
end

-- 3. Controller Navigation - Quick Setup
check("Pulse.UI.QuickSetup exists", type(UI.QuickSetup), "table")
UI.QuickSetup.Open(1)

local qsFrame = _G.PulseQuickSetupFrame
check("PulseQuickSetupFrame created", qsFrame ~= nil, true)

-- Test Step Navigation via Gamepad
local padHandler = qsFrame and qsFrame:GetScript("OnGamePadButtonDown")
check("QuickSetup has OnGamePadButtonDown script", type(padHandler), "function")

-- RB advances step from 1 to 2
if padHandler then
	padHandler(qsFrame, "PADRSHOULDER")
end
-- LB returns from 2 to 1
if padHandler then
	padHandler(qsFrame, "PADLSHOULDER")
end

UI.QuickSetup.Close()

-- 4. Controller Navigation - Main Panel Gamepad
local GP = UI.Panel and UI.Panel.Gamepad
check("Pulse.UI.Panel.Gamepad module exists", type(GP), "table")
check("Gamepad.IsEnabled returns true", GP and GP.IsEnabled(), true)

if UI.Panel and UI.Panel.Open then
	UI.Panel.Open()
	local panelFrame = _G.PulseSettingsFrame
	if panelFrame and panelFrame:GetScript("OnShow") and not panelFrame:GetScript("OnGamePadButtonDown") then
		panelFrame:GetScript("OnShow")(panelFrame)
	end
	check(
		"PulseSettingsFrame has OnGamePadButtonDown script",
		type(panelFrame and panelFrame:GetScript("OnGamePadButtonDown")),
		"function"
	)

	local panelPadHandler = panelFrame and panelFrame:GetScript("OnGamePadButtonDown")
	if panelPadHandler then
		-- RB switches category
		panelPadHandler(panelFrame, "PADRSHOULDER")
		-- D-Pad Right enters content
		panelPadHandler(panelFrame, "PADDRIGHT")
		-- D-Pad Left returns to sidebar
		panelPadHandler(panelFrame, "PADDLEFT")
		-- B closes panel
		panelPadHandler(panelFrame, "PAD2")
	end
	check("PulseSettingsFrame closed cleanly via controller PAD2", UI.Panel.IsOpen(), false)
end

io.write("\n")
if failures == 0 then
	io.write("✓ ALL CONTROLLER NAVIGATION & GAME MENU TESTS PASSED\n")
else
	io.write(string.format("✗ %d TEST(S) FAILED\n", failures))
	os.exit(1)
end
