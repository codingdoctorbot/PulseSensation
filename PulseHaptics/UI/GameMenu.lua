-- Pulse — UI/GameMenu.lua
--
-- Integration into Blizzard's Game Menu (Escape Menu).
-- Anchors a sleek Pulse Haptics banner above GameMenuFrame (or stacked above ControllerApex crest).
--
-- Architecture & Crash Prevention (ControllerForever / EasyController pattern):
-- 1. Parented to UIParent (strata DIALOG), NEVER to GameMenuFrame.
-- 2. ZERO SmartNavigation table mutation: Never calls SmartNavigation_AddJumpNavigationOverride
--    on Blizzard's GameMenuFrame.buttons (Options / Exit Game). Modifying Blizzard's internal
--    menu buttons taints them, causing ADDON_ACTION_FORBIDDEN and freezing the client in
--    FrameControlsManager / ActionBarStyles.
-- 3. Controller Shortcut Binding: While GameMenuFrame is up and out of combat, binds PAD3 ([X])
--    to the banner via SetOverrideBindingClick. PAD3 is completely unused by Blizzard's menu
--    (which uses A for Select and B for Return) and unused by ControllerForever (which uses Y).
-- 4. Safe Dismissal: Uses deferred GameMenuFrame:Hide() on the next frame tick rather than
--    HideUIPanel(), completely avoiding SetPreferredGamepadInteractTarget execution taint.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local GameMenu = {}
Pulse.UI.GameMenu = GameMenu

local PAD_KEY = "PAD3"
local PAD_LABEL = "X"
local BUTTON_NAME = "PulseGameMenuButton"
local BANNER_H = 32
local DEFAULT_BANNER_W = 200
local ICON_PATH = "Interface\\AddOns\\PulseHaptics\\Media\\icon"

local banner = nil
local bound = false
local isHooked = false

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

local function panelShown()
	local panel = Pulse.UI and Pulse.UI.Panel
	return panel and panel.IsShown and panel.IsShown() or false
end

local function openPanel()
	local panel = Pulse.UI and Pulse.UI.Panel
	if panel and panel.Open then
		panel.Open()
	elseif panel and panel.Toggle then
		panel.Toggle()
	end
end

local function refreshPrompt()
	if not banner or not banner.badge then
		return
	end
	if bound then
		banner.badge:SetText(("|cff38BDF8[%s]|r |cffffffffSettings|r"):format(PAD_LABEL))
	else
		banner.badge:SetText("|cff38BDF8/pulse|r")
	end
end

local function unbind()
	if bound and banner and not inCombat() then
		ClearOverrideBindings(banner)
		bound = false
	end
	refreshPrompt()
end

local function ensureBound()
	if not banner or inCombat() or panelShown() then
		return
	end
	local want = ("CLICK %s:LeftButton"):format(BUTTON_NAME)
	if bound and GetBindingAction and GetBindingAction(PAD_KEY, true) == want then
		return
	end
	ClearOverrideBindings(banner)
	SetOverrideBindingClick(banner, true, PAD_KEY, BUTTON_NAME, "LeftButton")
	bound = true
	refreshPrompt()
end

local function onClick()
	if inCombat() then
		print("|cff4cb8ffPulse:|r Cannot open settings during combat.")
		return
	end

	unbind()

	-- Defer dismissal to next frame tick: avoids SetPreferredGamepadInteractTarget taint
	C_Timer.After(0, function()
		if inCombat() then
			return
		end
		if GameMenuFrame and GameMenuFrame:IsShown() then
			GameMenuFrame:Hide()
		end
		openPanel()
	end)
end

local function setHover(btn, on)
	if not btn then
		return
	end
	if on then
		btn.bg:SetColorTexture(0.118, 0.145, 0.212, 0.98) -- Elevated Slate (#1E2536)
		btn.accent:SetColorTexture(0.40, 0.85, 1.00, 1.0) -- Bright Neon Cyan (#66D9FF)
		btn.title:SetTextColor(1.0, 1.0, 1.0)
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end
	else
		btn.bg:SetColorTexture(0.043, 0.055, 0.078, 0.98) -- Deep Obsidian (#0B0E14)
		btn.accent:SetColorTexture(0.298, 0.722, 1.000, 1.0) -- #4CB8FF
		btn.title:SetTextColor(0.298, 0.722, 1.000)
	end
end

local function updateBannerLayout()
	if not banner or not GameMenuFrame then
		return
	end

	local buttonW = DEFAULT_BANNER_W
	local first = GameMenuFrame.buttons and GameMenuFrame.buttons[1]
	if first and first.GetWidth then
		local bw = first:GetWidth()
		if bw and bw > 100 then
			buttonW = bw
		end
	end
	banner:SetWidth(buttonW)
	banner:SetHeight(BANNER_H)
	if GameMenuFrame.GetFrameLevel then
		banner:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 5)
	end

	banner:ClearAllPoints()
	local apexCrest = _G.ControllerApexGameMenuCrest
	if apexCrest and apexCrest.IsShown and apexCrest:IsShown() then
		banner:SetPoint("BOTTOM", apexCrest, "TOP", 0, 6)
	else
		banner:SetPoint("BOTTOM", GameMenuFrame, "TOP", 0, 8)
	end
end

local function createBanner()
	if banner then
		return banner
	end

	local b = CreateFrame("Button", BUTTON_NAME, UIParent)
	b:SetSize(DEFAULT_BANNER_W, BANNER_H)
	b:SetFrameStrata("DIALOG")
	b:EnableMouse(true)
	b:RegisterForClicks("AnyUp")
	b:Hide()

	-- Explicitly tell Blizzard SmartNavigation to ignore this frame
	b.ignoreSmartNavigation = true

	-- 1px hairline border
	local edge = b:CreateTexture(nil, "BACKGROUND", nil, 0)
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	edge:SetColorTexture(0.149, 0.184, 0.251, 0.60)

	-- Slate Obsidian Base Plate
	b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.bg:SetAllPoints()

	-- Left Electric Cyan Accent
	b.accent = b:CreateTexture(nil, "ARTWORK")
	b.accent:SetPoint("TOPLEFT")
	b.accent:SetPoint("BOTTOMLEFT")
	b.accent:SetWidth(4)

	-- Icon
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(20, 20)
	b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.icon:SetTexture(ICON_PATH)

	-- Title
	local fontName = _G.ApexFontCardTitle or (_G.GameFontNormalMed1 and "GameFontNormalMed1" or "GameFontHighlight")
	b.title = b:CreateFontString(nil, "OVERLAY", fontName)
	b.title:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
	b.title:SetText("Pulse Haptics")

	-- Badge: Controller [X] prompt or /pulse command
	local legendFont = _G.ApexFontLegend or "GameFontHighlightSmall"
	b.badge = b:CreateFontString(nil, "OVERLAY", legendFont)
	b.badge:SetPoint("RIGHT", b, "RIGHT", -10, 0)

	b:SetScript("OnEnter", function(btn)
		setHover(btn, true)
	end)
	b:SetScript("OnLeave", function(btn)
		setHover(btn, false)
	end)
	b:SetScript("OnClick", onClick)

	setHover(b, false)
	banner = b
	_G.GameMenuButtonPulse = b
	refreshPrompt()
	return b
end

local function onMenuShow()
	C_Timer.After(0, function()
		if not (GameMenuFrame and GameMenuFrame:IsShown()) then
			return
		end
		updateBannerLayout()
		banner:Show()
		ensureBound()
	end)
end

local function onMenuHide()
	if banner then
		banner:Hide()
	end
	unbind()
end

local function hookGameMenu()
	if isHooked or not GameMenuFrame then
		return
	end
	isHooked = true
	createBanner()

	-- Combat safety: clear bindings the instant combat begins
	local combatWatcher = CreateFrame("Frame")
	combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
	combatWatcher:SetScript("OnEvent", function()
		if bound and banner then
			ClearOverrideBindings(banner)
			bound = false
		end
		refreshPrompt()
	end)

	-- Re-bind check when focus refreshes
	if EventRegistry and EventRegistry.RegisterCallback then
		EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", function()
			C_Timer.After(0, function()
				if GameMenuFrame and GameMenuFrame:IsShown() then
					ensureBound()
				end
			end)
		end, GameMenu)
	end

	GameMenuFrame:HookScript("OnShow", onMenuShow)
	GameMenuFrame:HookScript("OnHide", onMenuHide)
	if GameMenuFrame:IsShown() then
		onMenuShow()
	end
end

function GameMenu:Init()
	if GameMenuFrame then
		hookGameMenu()
	else
		local loader = CreateFrame("Frame")
		loader:RegisterEvent("ADDON_LOADED")
		loader:RegisterEvent("PLAYER_LOGIN")
		loader:SetScript("OnEvent", function(f)
			if GameMenuFrame then
				hookGameMenu()
				f:UnregisterAllEvents()
			end
		end)
	end
end
