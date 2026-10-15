-- Pulse — UI/GameMenu.lua
--
-- Integration into Blizzard's Game Menu (Escape Menu).
-- Anchors a sleek Pulse Haptics button above GameMenuFrame (or stacked above ControllerApex crest).
--
-- Crash-Proof & Zero-Taint Architecture (ControllerForever / EasyController pattern):
-- 1. Parented to UIParent (strata DIALOG), NEVER to GameMenuFrame.
-- 2. ZERO SmartNavigation table injection: Never calls SmartNavigation_AddJumpNavigationOverride
--    on Blizzard's GameMenuFrame.buttons, which taints SmartNavigation and causes client freezes.
-- 3. Uses a standalone GamePad D-Pad / Button listener + OverrideBindingOwner while focused,
--    allowing seamless D-Pad UP/DOWN wrapping between Options, Pulse Banner, and Exit Game
--    without ever tainting Blizzard's SmartNavigation stack.
-- 4. Closes GameMenuFrame safely via deferred execution without tainting UIParent panels.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local GameMenu = {}
Pulse.UI.GameMenu = GameMenu

local BANNER_H = 32
local DEFAULT_BANNER_W = 200
local ICON_PATH = "Interface\\AddOns\\PulseHaptics\\Media\\icon"

local banner = nil
local bindOwner = nil
local navWatcher = nil
local isHooked = false
local isBannerFocused = false

-- Safely close GameMenuFrame and toggle Pulse Panel on the next frame tick
-- so we never taint the active Gamepad/SmartNavigation call stack.
local function onClick()
	if InCombatLockdown and InCombatLockdown() then
		print("|cff4cb8ffPulse:|r Cannot open settings during combat.")
		return
	end

	C_Timer.After(0, function()
		if InCombatLockdown and InCombatLockdown() then
			return
		end
		-- Use GameMenuFrame:Hide() directly instead of HideUIPanel(GameMenuFrame)
		-- because HideUIPanel taints UIParent attributes when called from addon code.
		if GameMenuFrame and GameMenuFrame:IsShown() then
			GameMenuFrame:Hide()
		end
		if Pulse.UI and Pulse.UI.Panel and Pulse.UI.Panel.Toggle then
			Pulse.UI.Panel.Toggle()
		end
	end)
end

local function setFocused(btn, focused)
	if not btn then
		return
	end
	isBannerFocused = focused and true or false

	if focused then
		btn.bg:SetColorTexture(0.118, 0.145, 0.212, 0.98) -- Elevated Slate (#1E2536)
		btn.accent:SetColorTexture(0.40, 0.85, 1.00, 1.0) -- Bright Neon Cyan (#66D9FF)
		btn.sheen:SetColorTexture(0.40, 0.85, 1.00, 1.0)
		btn.title:SetTextColor(1.0, 1.0, 1.0)
		btn.badge:SetTextColor(0.40, 0.85, 1.00)
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end

		-- Bind PAD1 (A / Cross) to click the Pulse banner while it holds virtual focus
		if bindOwner and not (InCombatLockdown and InCombatLockdown()) then
			ClearOverrideBindings(bindOwner)
			SetOverrideBindingClick(bindOwner, true, "PAD1", "PulseGameMenuButton", "LeftButton")
		end
	else
		btn.bg:SetColorTexture(0.043, 0.055, 0.078, 0.98) -- Deep Obsidian (#0B0E14)
		btn.accent:SetColorTexture(0.298, 0.722, 1.000, 1.0) -- #4CB8FF
		btn.sheen:SetColorTexture(0.298, 0.722, 1.000, 0.85)
		btn.title:SetTextColor(0.298, 0.722, 1.000)
		btn.badge:SetTextColor(0.220, 0.741, 0.973)

		if bindOwner and not (InCombatLockdown and InCombatLockdown()) then
			ClearOverrideBindings(bindOwner)
		end
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

-- Read-only check to see if a GameMenuFrame button currently has SmartNavigation / Mouse focus
local function isGameMenuButtonHighlighted(btn)
	if not btn then
		return false
	end
	if btn.IsMouseOver and btn:IsMouseOver() then
		return true
	end
	-- Check SmartNavigation's current target in a strictly read-only manner
	if _G.SmartNavigation and _G.SmartNavigation.currentTarget == btn then
		return true
	end
	if _G.SmartNavigation_GetFocusedFrame and _G.SmartNavigation_GetFocusedFrame() == btn then
		return true
	end
	return false
end

local function createNavWatcher()
	if navWatcher then
		return navWatcher
	end

	bindOwner = CreateFrame("Frame", "PulseGameMenuBindOwner", UIParent)

	-- Passive listener frame that watches GamePad D-Pad UP/DOWN while GameMenuFrame is shown
	local w = CreateFrame("Frame", "PulseGameMenuNavWatcher", UIParent)
	w:Hide()

	-- Always propagate input so we NEVER block Blizzard's secure GamePad stack
	if w.SetPropagateKeyboardInput then
		pcall(w.SetPropagateKeyboardInput, w, true)
	end

	w:SetScript("OnGamePadButtonDown", function(self, button)
		if not banner or not banner:IsShown() or not GameMenuFrame or not GameMenuFrame:IsShown() then
			return
		end

		if button == "PADDUP" or button == "PADDOWN" then
			local buttons = GameMenuFrame.buttons
			local topBtn = buttons and buttons[1]
			local exitBtn = buttons and buttons[#buttons]

			if isBannerFocused then
				-- Moving off the Pulse banner back onto GameMenuFrame buttons
				setFocused(banner, false)
			elseif (button == "PADDUP" and isGameMenuButtonHighlighted(topBtn))
				or (button == "PADDOWN" and isGameMenuButtonHighlighted(exitBtn)) then
				-- Stepped past the top or bottom button: highlight Pulse banner
				C_Timer.After(0, function()
					if banner and banner:IsShown() then
						setFocused(banner, true)
					end
				end)
			end
		elseif button == "PAD2" then
			-- B / Circle clears focus before closing
			if isBannerFocused then
				setFocused(banner, false)
			end
		end
	end)

	navWatcher = w
	return w
end

local function createBanner()
	if banner then
		return banner
	end

	createNavWatcher()

	-- Parent to UIParent to ensure GameMenuFrame remains 100% untainted
	local b = CreateFrame("Button", "PulseGameMenuButton", UIParent)
	b:SetSize(DEFAULT_BANNER_W, BANNER_H)
	b:SetFrameStrata("DIALOG")
	if GameMenuFrame and GameMenuFrame.GetFrameLevel then
		b:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 5)
	end
	b:EnableMouse(true)
	b:RegisterForClicks("AnyUp")
	b:Hide()

	-- Crucial: Tell Blizzard's native SmartNavigation NOT to walk or mutate this addon frame
	b.ignoreSmartNavigation = true

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

	-- Interactive Feedback Scripts (Mouse + Virtual Controller Focus)
	b:SetScript("OnEnter", function(btn)
		setFocused(btn, true)
	end)

	b:SetScript("OnLeave", function(btn)
		setFocused(btn, false)
	end)

	b:SetScript("OnClick", onClick)

	banner = b
	_G.GameMenuButtonPulse = b
	return b
end

local function onGameMenuShow()
	C_Timer.After(0, function()
		if not GameMenuFrame or not GameMenuFrame:IsShown() then
			return
		end
		updateBannerLayout()
		setFocused(banner, false)
		banner:Show()
		if navWatcher then
			navWatcher:Show()
		end
	end)
end

local function onGameMenuHide()
	if banner then
		setFocused(banner, false)
		banner:Hide()
	end
	if navWatcher then
		navWatcher:Hide()
	end
end

local function hookGameMenu()
	if isHooked or not GameMenuFrame then
		return
	end

	createBanner()
	updateBannerLayout()

	-- Use HookScript ONLY (not both HookScript and hooksecurefunc) to prevent double-firing
	if GameMenuFrame.HookScript then
		GameMenuFrame:HookScript("OnShow", onGameMenuShow)
		GameMenuFrame:HookScript("OnHide", onGameMenuHide)
	end

	-- Ensure we clean up overrides if combat starts while the menu is open
	local combatGuard = CreateFrame("Frame")
	combatGuard:RegisterEvent("PLAYER_REGEN_DISABLED")
	combatGuard:SetScript("OnEvent", function()
		if bindOwner then
			ClearOverrideBindings(bindOwner)
		end
		if banner then
			setFocused(banner, false)
		end
	end)

	if GameMenuFrame:IsShown() then
		onGameMenuShow()
	end

	isHooked = true
end

function GameMenu:Init()
	if GameMenuFrame then
		hookGameMenu()
	else
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
