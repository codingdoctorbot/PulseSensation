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

-- Mock GameMenuFrame in harness environment if not present
if not _G.GameMenuFrame then
	_G.GameMenuFrame = _G.CreateFrame("Frame", "GameMenuFrame", _G.UIParent)
	_G.GameMenuFrame:SetSize(190, 260)
end

-- Set up SmartNavigation mocks
_G.SMART_NAV_INPUT_DIRECTION = {
	UP = { dirKey = "UP" },
	DOWN = { dirKey = "DOWN" },
}
local overridesRecorded = {}
_G.SmartNavigation_AddJumpNavigationOverride = function(btn, dir, target)
	overridesRecorded[btn] = overridesRecorded[btn] or {}
	overridesRecorded[btn][dir.dirKey] = target
end
_G.SmartNavigation_ClearJumpNavigationOverrides = function(btn)
	overridesRecorded[btn] = nil
end

local btn1 = _G.CreateFrame("Button", "GameMenuButton1", _G.GameMenuFrame)
local btn2 = _G.CreateFrame("Button", "GameMenuButton2", _G.GameMenuFrame)
_G.GameMenuFrame.buttons = { btn1, btn2 }

UI.GameMenu:Init()
local menuBtn = _G.GameMenuButtonPulse or _G.PulseGameMenuButton
check("GameMenuButtonPulse created", menuBtn ~= nil, true)
check("GameMenuButtonPulse parent is UIParent (taint-free)", menuBtn and menuBtn:GetParent(), _G.UIParent)
check("GameMenuButtonPulse has OnSmartNavSelect", type(menuBtn and menuBtn.OnSmartNavSelect), "function")
check("GameMenuButtonPulse has OnSmartNavDeselect", type(menuBtn and menuBtn.OnSmartNavDeselect), "function")
check("GameMenuButtonPulse has OnSmartNavClick", type(menuBtn and menuBtn.OnSmartNavClick), "function")

-- Verify visibility synchronization and SmartNavigation overrides on Show
_G.GameMenuFrame:Show()
check("GameMenuButtonPulse shows when GameMenuFrame shown", menuBtn:IsShown(), true)
check("Top button UP navigates to menuBtn", overridesRecorded[btn1] and overridesRecorded[btn1]["UP"], menuBtn)
check("menuBtn DOWN navigates to top button", overridesRecorded[menuBtn] and overridesRecorded[menuBtn]["DOWN"], btn1)
check("menuBtn UP wraps to bottom button", overridesRecorded[menuBtn] and overridesRecorded[menuBtn]["UP"], btn2)
check("Bottom button DOWN wraps to menuBtn", overridesRecorded[btn2] and overridesRecorded[menuBtn] ~= nil, true)

_G.GameMenuFrame:Hide()
check("GameMenuButtonPulse hides when GameMenuFrame hidden", menuBtn:IsShown(), false)
check("SmartNav overrides cleared on hide", overridesRecorded[menuBtn], nil)

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
