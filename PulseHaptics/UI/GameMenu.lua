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
-- 3. Dynamic Controller Glyph & Shortcut Binding: While GameMenuFrame is up and out of combat,
--    binds PAD3 to the banner via SetOverrideBindingClick.
--    Detects active controller hardware (PlayStation: Square, Xbox: X, Nintendo: Y) and dynamically
--    displays the corresponding Blizzard button glyph (|A:Gamepad_...|a) and clear prompt:
--    "Press [Square / X glyph] to open settings".
-- 4. Dismissal: Uses the public HideUIPanel path out of combat on the next frame tick.
--    Direct Frame:Hide() skips FrameControlsManager cleanup and leaves its UI binding
--    groups active after the settings window closes.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local GameMenu = {}
Pulse.UI.GameMenu = GameMenu

local PAD_KEY = "PAD3"
local BUTTON_NAME = "PulseGameMenuButton"
local BANNER_H = 40
local BANNER_GAP = 52
local DEFAULT_BANNER_W = 260
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

-- Detect whether the active controller uses PlayStation (Shapes), Xbox (Letters), or Nintendo (Reverse) glyphs
local function detectPadStyle()
	-- 1. Check Blizzard's built-in InputDeviceIconSetManager
	if _G.InputDeviceIconSetManager and _G.InputDeviceIconSetManager.GetActiveInputDeviceIconSet then
		local set = _G.InputDeviceIconSetManager:GetActiveInputDeviceIconSet()
		if set == "Shapes" or set == "Letters" or set == "Reverse" then
			return set
		end
	end

	-- 2. Check C_GamePad device mapped state
	if C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetDeviceMappedState then
		local id = C_GamePad.GetActiveDeviceID()
		if id then
			local state = C_GamePad.GetDeviceMappedState(id)
			if state then
				if state.labelStyle and state.labelStyle ~= "" and state.labelStyle ~= "Generic" then
					return state.labelStyle
				end
				local name = (state.name or ""):lower()
				if
					name:find("dualsense")
					or name:find("dualshock")
					or name:find("playstation")
					or name:find("sony")
					or name:find("ps5")
					or name:find("ps4")
				then
					return "Shapes"
				elseif
					name:find("switch")
					or name:find("nintendo")
					or name:find("joy%-?con")
					or name:find("pro controller")
				then
					return "Reverse"
				elseif name:find("xbox") or name:find("xinput") or name:find("microsoft") then
					return "Letters"
				end
			end
		end
	end

	-- 3. Check ControllerForever setting if present
	if _G.ControllerForever and _G.ControllerForever.RuleBar and _G.ControllerForever.RuleBar.padStyle then
		local s = _G.ControllerForever.RuleBar.padStyle()
		if s == "ps" then
			return "Shapes"
		elseif s == "nintendo" then
			return "Reverse"
		elseif s == "xbox" then
			return "Letters"
		end
	end

	return "Auto"
end

-- Keep a single, compact prompt within the button's second line.
local function getGamepadPrompt()
	local style = detectPadStyle()
	if style == "Shapes" then
		return "|A:gamepad-ps-buttonsquare-normal:12:12|a Square: open settings"
	elseif style == "Letters" then
		return "|A:gamepad-xbox1-buttonx-normal:12:12|a X: open settings"
	elseif style == "Reverse" then
		return "|A:gamepad-switch-128x-face-y-normal:12:12|a Y: open settings"
	end
	return "Square / X: open settings"
end

local function refreshPrompt()
	if not banner or not banner.subtitle then
		return
	end
	banner.subtitle:SetText(bound and getGamepadPrompt() or "Click to open settings")
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

	-- Finish the current press before closing the managed native panel.
	C_Timer.After(0, function()
		if inCombat() then
			return
		end
		if GameMenuFrame and GameMenuFrame:IsShown() then
			-- Also releases native controller focus and its fallthrough key catcher.
			HideUIPanel(GameMenuFrame)
			if GameMenuFrame:IsShown() then
				return
			end
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
		if btn.subtitle then
			btn.subtitle:SetTextColor(1.0, 1.0, 1.0)
		end
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end
	else
		btn.bg:SetColorTexture(0.043, 0.055, 0.078, 0.98) -- Deep Obsidian (#0B0E14)
		btn.accent:SetColorTexture(0.298, 0.722, 1.000, 1.0) -- #4CB8FF
		btn.title:SetTextColor(0.298, 0.722, 1.000)
		if btn.subtitle then
			btn.subtitle:SetTextColor(0.88, 0.92, 0.96)
		end
	end
end

local function updateBannerLayout()
	if not banner or not GameMenuFrame then
		return
	end

	local width = DEFAULT_BANNER_W
	if GameMenuFrame.GetWidth then
		local gw = GameMenuFrame:GetWidth()
		if gw and gw > 150 then
			width = gw
		end
	end
	banner:SetWidth(width)
	banner:SetHeight(BANNER_H)
	banner.title:SetWidth(width - 56)
	banner.subtitle:SetWidth(width - 56)
	if GameMenuFrame.GetFrameLevel then
		banner:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 5)
	end

	banner:ClearAllPoints()
	local apexCrest = _G.ControllerApexGameMenuCrest
	if apexCrest and apexCrest.IsShown and apexCrest:IsShown() then
		banner:SetPoint("BOTTOM", apexCrest, "TOP", 0, 8)
	else
		-- Leave room above Blizzard's Game Menu title ribbon.
		banner:SetPoint("BOTTOM", GameMenuFrame, "TOP", 0, BANNER_GAP)
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
	b.icon:SetSize(24, 24)
	b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.icon:SetTexture(ICON_PATH)

	-- Title (Top Line)
	local fontName = _G.GameFontNormalMed1 and "GameFontNormalMed1" or "GameFontNormal"
	b.title = b:CreateFontString(nil, "OVERLAY", fontName)
	b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 44, -5)
	b.title:SetHeight(14)
	b.title:SetJustifyH("LEFT")
	b.title:SetWordWrap(false)
	b.title:SetText("Pulse Haptics")
	b.title:SetTextColor(0.298, 0.722, 1.000)

	-- Subtitle: controller shortcut, or a mouse prompt when unbound.
	local subFont = "GameFontHighlightSmall"
	b.subtitle = b:CreateFontString(nil, "OVERLAY", subFont)
	b.subtitle:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 44, 5)
	b.subtitle:SetHeight(14)
	b.subtitle:SetJustifyH("LEFT")
	b.subtitle:SetWordWrap(false)
	b.subtitle:SetTextColor(0.88, 0.92, 0.96)

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
	createBanner()
	isHooked = true

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

	-- Refresh button glyphs when active controller changes
	if
		_G.InputDeviceIconSetManager and _G.InputDeviceIconSetManager.RegisterActiveInputDeviceIconSetUpdatedCallback
	then
		_G.InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(function()
			refreshPrompt()
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
