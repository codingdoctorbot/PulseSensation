-- Pulse — UI/GameMenu.lua
--
-- Integration into Blizzard's Game Menu (Escape Menu).
-- Anchors a sleek Pulse Haptics button above GameMenuFrame (or stacked above ControllerApex crest).
-- Provides native controller SmartNavigation support in the Game Menu.
--
-- Architecture & Taint Shielding (ControllerApex pattern):
-- 1. Parented to UIParent (strata DIALOG), NEVER to GameMenuFrame. This guarantees 100% zero
--    execution taint on GameMenuFrame and avoids ADDON_ACTION_BLOCKED errors when pressing Escape.
-- 2. Native SmartNavigation integration: Injects jump navigation overrides chaining between
--    the top button (Options) and the bottom button (Exit Game), enabling seamless controller
--    D-pad/stick navigation and (A) button selection.
-- 3. Resilient initialization: Hooks immediately if GameMenuFrame exists, or awaits ADDON_LOADED/PLAYER_LOGIN.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local GameMenu = {}
Pulse.UI.GameMenu = GameMenu

local BANNER_H = 32
local DEFAULT_BANNER_W = 200
local ICON_PATH = "Interface\\AddOns\\PulseHaptics\\Media\\icon"

local banner = nil
local isHooked = false

local function onClick()
	if InCombatLockdown and InCombatLockdown() then
		print("|cff4cb8ffPulse:|r Cannot open settings during combat.")
		return
	end
	if HideUIPanel and GameMenuFrame then
		HideUIPanel(GameMenuFrame)
	elseif GameMenuFrame then
		GameMenuFrame:Hide()
	end
	if Pulse.UI and Pulse.UI.Panel and Pulse.UI.Panel.Toggle then
		Pulse.UI.Panel.Toggle()
	end
end

local function setFocused(btn, focused)
	if not btn then
		return
	end
	if focused then
		btn.bg:SetColorTexture(0.118, 0.145, 0.212, 0.98) -- Elevated Slate (#1E2536)
		btn.accent:SetColorTexture(0.40, 0.85, 1.00, 1.0) -- Bright Neon Cyan (#66D9FF)
		btn.sheen:SetColorTexture(0.40, 0.85, 1.00, 1.0)
		btn.title:SetTextColor(1.0, 1.0, 1.0)
		btn.badge:SetTextColor(0.40, 0.85, 1.00)
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end
	else
		btn.bg:SetColorTexture(0.043, 0.055, 0.078, 0.98) -- Deep Obsidian (#0B0E14)
		btn.accent:SetColorTexture(0.298, 0.722, 1.000, 1.0) -- #4CB8FF
		btn.sheen:SetColorTexture(0.298, 0.722, 1.000, 0.85)
		btn.title:SetTextColor(0.298, 0.722, 1.000)
		btn.badge:SetTextColor(0.220, 0.741, 0.973)
	end
end

local function updateBannerLayout()
	if not banner or not GameMenuFrame then
		return
	end

	-- Match width to the GameMenuFrame buttons (typically 200px)
	local buttonW = DEFAULT_BANNER_W
	if GameMenuFrame.buttons and GameMenuFrame.buttons[1] and GameMenuFrame.buttons[1].GetWidth then
		local w = GameMenuFrame.buttons[1]:GetWidth()
		if w and w > 100 then
			buttonW = w
		end
	end
	banner:SetWidth(buttonW)
	banner:SetHeight(BANNER_H)

	banner:ClearAllPoints()
	local apexCrest = _G.ControllerApexGameMenuCrest
	if apexCrest and apexCrest.IsShown and apexCrest:IsShown() then
		-- If ControllerApex is active and displaying its crest, stack cleanly above it
		banner:SetPoint("BOTTOM", apexCrest, "TOP", 0, 6)
	else
		-- Dock gracefully directly above GameMenuFrame
		banner:SetPoint("BOTTOM", GameMenuFrame, "TOP", 0, 8)
	end
end

local function setupSmartNavOverrides()
	if not banner or not GameMenuFrame or not GameMenuFrame.buttons then
		return
	end

	if not SmartNavigation_AddJumpNavigationOverride or not SMART_NAV_INPUT_DIRECTION then
		return
	end

	local topBtn = GameMenuFrame.buttons[1]
	local exitBtn = GameMenuFrame.buttons[#GameMenuFrame.buttons]

	if not topBtn or not exitBtn then
		return
	end

	-- When focused on top button (Options), pressing UP navigates to Pulse banner
	SmartNavigation_AddJumpNavigationOverride(topBtn, SMART_NAV_INPUT_DIRECTION.UP, banner)

	-- When focused on Pulse banner:
	-- DOWN navigates down to top button (Options)
	SmartNavigation_AddJumpNavigationOverride(banner, SMART_NAV_INPUT_DIRECTION.DOWN, topBtn)
	-- UP wraps around to bottom button (Exit Game)
	SmartNavigation_AddJumpNavigationOverride(banner, SMART_NAV_INPUT_DIRECTION.UP, exitBtn)

	-- When focused on lowermost button (Exit Game), pressing DOWN wraps around to Pulse banner
	SmartNavigation_AddJumpNavigationOverride(exitBtn, SMART_NAV_INPUT_DIRECTION.DOWN, banner)
end

local function clearSmartNavOverrides()
	if not banner then
		return
	end
	if SmartNavigation_ClearJumpNavigationOverrides then
		SmartNavigation_ClearJumpNavigationOverrides(banner)
	end
end

local function createBanner()
	if banner then
		return banner
	end

	-- Parent to UIParent to ensure GameMenuFrame remains 100% untainted
	local b = CreateFrame("Button", "PulseGameMenuButton", UIParent)
	b:SetSize(DEFAULT_BANNER_W, BANNER_H)
	b:SetFrameStrata("DIALOG")
	if GameMenuFrame and GameMenuFrame.GetFrameLevel then
		b:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 5)
	end
	b:EnableMouse(true)
	b:Hide()

	-- SmartNavigation custom cursor offset (positions yellow pointer cleanly at left accent)
	b.customSmartNavOffsetX = -4
	b.customSmartNavOffsetY = 0

	-- Deep Slate Obsidian Base Plate (#0B0E14)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0.043, 0.055, 0.078, 0.98)

	-- 1px Precision Hairline Boundaries
	local bTop = b:CreateTexture(nil, "BORDER")
	bTop:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	bTop:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	bTop:SetHeight(1)
	bTop:SetColorTexture(0.149, 0.184, 0.251, 0.60)

	local bBottom = b:CreateTexture(nil, "BORDER")
	bBottom:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	bBottom:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	bBottom:SetHeight(1)
	bBottom:SetColorTexture(0.149, 0.184, 0.251, 0.60)

	local bLeft = b:CreateTexture(nil, "BORDER")
	bLeft:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	bLeft:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	bLeft:SetWidth(1)
	bLeft:SetColorTexture(0.149, 0.184, 0.251, 0.60)

	local bRight = b:CreateTexture(nil, "BORDER")
	bRight:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	bRight:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	bRight:SetWidth(1)
	bRight:SetColorTexture(0.149, 0.184, 0.251, 0.60)

	-- Left Accent Docking Socket (Pulse Electric Cyan / Sky Blue)
	b.accent = b:CreateTexture(nil, "ARTWORK")
	b.accent:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.accent:SetWidth(4)
	b.accent:SetColorTexture(0.298, 0.722, 1.000, 1.0) -- #4CB8FF

	-- Top Electric Cyan Hairline Sheen
	b.sheen = b:CreateTexture(nil, "ARTWORK")
	b.sheen:SetPoint("TOPLEFT", 1, -1)
	b.sheen:SetPoint("TOPRIGHT", -1, -1)
	b.sheen:SetHeight(1)
	b.sheen:SetColorTexture(0.298, 0.722, 1.000, 0.85)

	-- Sleek Haptic Ripple Icon (20x20)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(20, 20)
	b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.icon:SetTexture(ICON_PATH)

	-- Title: 14pt Semi-Bold Sans-Serif (#4CB8FF)
	local fontName = "GameFontHighlightMedium"
	if _G.ApexFontCardTitle then
		fontName = "ApexFontCardTitle"
	elseif _G.GameFontNormalMed1 then
		fontName = "GameFontNormalMed1"
	end
	b.title = b:CreateFontString(nil, "OVERLAY", fontName)
	b.title:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
	b.title:SetText("|cff4cb8ffPulse Haptics|r")

	-- Right Badge: Semi-Bold Command Prompt (#38BDF8)
	local legendFont = "GameFontDisableSmall"
	if _G.ApexFontLegend then
		legendFont = "ApexFontLegend"
	end
	b.badge = b:CreateFontString(nil, "OVERLAY", legendFont)
	b.badge:SetPoint("RIGHT", b, "RIGHT", -10, 0)
	b.badge:SetText("|cff38BDF8/pulse|r")

	-- Interactive Feedback Scripts (Mouse + Controller SmartNavigation)
	b:SetScript("OnEnter", function(btn)
		setFocused(btn, true)
	end)

	b:SetScript("OnLeave", function(btn)
		setFocused(btn, false)
	end)

	b:SetScript("OnClick", onClick)

	-- SmartNavigation hooks for GamePad controller focus & activation
	b.OnSmartNavSelect = function(btn)
		setFocused(btn, true)
	end

	b.OnSmartNavDeselect = function(btn)
		setFocused(btn, false)
	end

	b.OnSmartNavClick = onClick

	banner = b
	_G.GameMenuButtonPulse = b
	return b
end

local function hookGameMenu()
	if isHooked or not GameMenuFrame then
		return
	end

	createBanner()
	updateBannerLayout()

	-- Visibility synchronization and SmartNavigation setup
	if GameMenuFrame.HookScript then
		GameMenuFrame:HookScript("OnShow", function()
			updateBannerLayout()
			banner:Show()
			setupSmartNavOverrides()
		end)
		GameMenuFrame:HookScript("OnHide", function()
			banner:Hide()
			clearSmartNavOverrides()
		end)
	end

	if hooksecurefunc then
		hooksecurefunc(GameMenuFrame, "Show", function()
			updateBannerLayout()
			banner:Show()
			setupSmartNavOverrides()
		end)
		hooksecurefunc(GameMenuFrame, "Hide", function()
			banner:Hide()
			clearSmartNavOverrides()
		end)

		-- Re-register jump navigation overrides after GameMenuFrame rebuilds gamepad buttons
		if GameMenuFrameMixin and GameMenuFrameMixin.SetupGamepadButtons then
			hooksecurefunc(GameMenuFrameMixin, "SetupGamepadButtons", function(menuFrame)
				if menuFrame == GameMenuFrame then
					setupSmartNavOverrides()
				end
			end)
		elseif GameMenuFrame.SetupGamepadButtons then
			hooksecurefunc(GameMenuFrame, "SetupGamepadButtons", function()
				setupSmartNavOverrides()
			end)
		end
	end

	if GameMenuFrame:IsShown() then
		updateBannerLayout()
		banner:Show()
		setupSmartNavOverrides()
	end

	isHooked = true
end

function GameMenu:Init()
	if GameMenuFrame then
		hookGameMenu()
	else
		-- If GameMenuFrame is not yet loaded, wait for it
		local loader = CreateFrame("Frame")
		loader:RegisterEvent("ADDON_LOADED")
		loader:RegisterEvent("PLAYER_LOGIN")
		loader:SetScript("OnEvent", function(frame)
			if GameMenuFrame then
				hookGameMenu()
				frame:UnregisterAllEvents()
			end
		end)
	end
end
