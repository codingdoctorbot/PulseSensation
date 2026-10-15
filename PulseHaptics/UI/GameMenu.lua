-- Pulse — UI/GameMenu.lua
--
-- Integration into Blizzard's Game Menu (Escape Menu).
-- Anchors a sleek, docked Pulse Haptics bar directly at the lowermost position of GameMenuFrame.
--
-- Architecture & Taint Shielding (ControllerApex pattern):
-- 1. Parented to UIParent (strata DIALOG), NEVER to GameMenuFrame. This guarantees 100% zero
--    execution taint on GameMenuFrame and avoids ADDON_ACTION_BLOCKED errors when pressing Escape.
-- 2. Dynamically tracks GameMenuFrame's visibility and width without modifying Blizzard's button pool.
-- 3. Resilient initialization: Hooks immediately if GameMenuFrame exists, or awaits ADDON_LOADED/PLAYER_LOGIN.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local GameMenu = {}
Pulse.UI.GameMenu = GameMenu

local BANNER_H = 38
local DEFAULT_BANNER_W = 204
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

local function updateBannerLayout()
	if not banner or not GameMenuFrame then
		return
	end
	local menuW = GameMenuFrame:GetWidth()
	if menuW and menuW > 120 then
		-- In modern Dragonflight/Classic VerticalLayoutFrame, padding is ~28px each side
		banner:SetWidth(math.max(DEFAULT_BANNER_W, menuW - 16))
	else
		banner:SetWidth(DEFAULT_BANNER_W)
	end
	banner:ClearAllPoints()
	-- Anchored directly to the lowermost edge of GameMenuFrame (or below gamepad footer if active)
	local footer = GameMenuFrame.gamepadFooter
	if footer and footer.IsShown and footer:IsShown() then
		banner:SetPoint("TOP", footer, "BOTTOM", 0, -6)
	else
		banner:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -8)
	end
end

local function createBanner()
	if banner then
		return banner
	end

	-- Parent to UIParent to ensure GameMenuFrame remains 100% untainted
	local b = CreateFrame("Button", "PulseGameMenuButton", UIParent)
	b:SetSize(DEFAULT_BANNER_W, BANNER_H)
	b:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -8)
	b:SetFrameStrata("DIALOG")
	if GameMenuFrame and GameMenuFrame.GetFrameLevel then
		b:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 5)
	end
	b:EnableMouse(true)
	b:Hide()

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

	-- Sleek Haptic Ripple Icon (22x22)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(22, 22)
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
	b.title:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
	b.title:SetText("|cff4cb8ffPulse Haptics|r")

	-- Right Badge: Semi-Bold Command Prompt (#38BDF8)
	local legendFont = "GameFontDisableSmall"
	if _G.ApexFontLegend then
		legendFont = "ApexFontLegend"
	end
	b.badge = b:CreateFontString(nil, "OVERLAY", legendFont)
	b.badge:SetPoint("RIGHT", b, "RIGHT", -12, 0)
	b.badge:SetText("|cff38BDF8/pulse|r")

	-- Interactive Feedback Scripts
	b:SetScript("OnEnter", function(btn)
		btn.bg:SetColorTexture(0.118, 0.145, 0.212, 0.98) -- Elevated Slate (#1E2536)
		btn.accent:SetColorTexture(0.40, 0.85, 1.00, 1.0) -- Bright Neon Cyan
		btn.sheen:SetColorTexture(0.40, 0.85, 1.00, 1.0)
		btn.title:SetTextColor(1.0, 1.0, 1.0)
		btn.badge:SetTextColor(0.40, 0.85, 1.00)
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end
	end)

	b:SetScript("OnLeave", function(btn)
		btn.bg:SetColorTexture(0.043, 0.055, 0.078, 0.98) -- Deep Obsidian (#0B0E14)
		btn.accent:SetColorTexture(0.298, 0.722, 1.000, 1.0)
		btn.sheen:SetColorTexture(0.298, 0.722, 1.000, 0.85)
		btn.title:SetTextColor(0.298, 0.722, 1.000)
		btn.badge:SetTextColor(0.220, 0.741, 0.973)
	end)

	b:SetScript("OnClick", onClick)

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

	-- Safe visibility synchronization without modifying Blizzard secure methods
	if GameMenuFrame.HookScript then
		GameMenuFrame:HookScript("OnShow", function()
			updateBannerLayout()
			banner:Show()
		end)
		GameMenuFrame:HookScript("OnHide", function()
			banner:Hide()
		end)
	end

	if hooksecurefunc then
		hooksecurefunc(GameMenuFrame, "Show", function()
			updateBannerLayout()
			banner:Show()
		end)
		hooksecurefunc(GameMenuFrame, "Hide", function()
			banner:Hide()
		end)
	end

	banner:SetShown(GameMenuFrame:IsShown())
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
