-- Pulse — Modules/ControllerUI.lua
--
-- WoW Forever's native gamepad interface, observed rather than recreated. Nothing here
-- reads raw controller input, polls a stick or reimplements navigation — Blizzard maintains
-- that state and announces or exposes every transition this module cares about.
--
-- ZERO-TAINT OBSERVATION ARCHITECTURE:
-- Blizzard's controller interface heavily intertwines with protected engine actions:
--   - SmartNavigationMixin:UninitializeGamepad() calls SelectButton(nil), then immediately
--     executes GamepadMode.DeactivateBindingGroup().
--   - GroupTargeting:StopTargeting() cleans up targeting, then calls SmartNavigation:Hide().
--   - UIParentPanelManager.HideUIPanel() dispatches to FramePositionDelegate:SetAttribute().
--
-- If an addon registers callbacks with SmartNavigation's CallbackRegistryMixin, GroupTargeting,
-- or EventRegistry for these events, the addon executes inside Blizzard's stack frame, tainting
-- the execution context and causing ADDON_ACTION_BLOCKED ("action only available to the Blizzard UI").
--
-- Therefore, this module observes all UI, panel, radial, and group targeting states via:
--   1. Passive Polling (uiPollFrame) — a lightweight 20Hz (0.05s) OnUpdate timer that inspects
--      read-only properties (SmartNavigation.currentButton, GamepadRadial:IsShown(),
--      GroupTargeting.isTargetingActive, and GetUIPanel). Zero callbacks, zero hooks inside
--      Blizzard managers, and ZERO garbage table allocations in the tick.
--   2. hooksecurefunc — strictly limited to terminal user interactions that execute no protected
--      operations afterwards:
--        - GamepadRadial.BeginSelection & EndSelection (last statements in ProcessInput/CancelSelection)
--        - TabSystemMixin / PanelTemplates_SetTab (interactive tab switches)
--   3. Plain Lua events on our own frame (interactFrame) — for soft targeting, cursor items, and action bar paging.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("ControllerUI", M)

local function anyEnabled(cueIDs)
	if not Pulse.Database:GetCue("controllerUIMaster") then
		return false
	end
	for _, cueID in ipairs(cueIDs) do
		if Pulse.Database:GetCue(cueID) then
			return true
		end
	end
	return false
end

-- Every cue here describes the CONTROLLER driving the interface, so none should fire on
-- mouse and keyboard. Blizzard's primary answer is InputUtil.IsGamepadUIEnabled(), resolving to
-- C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad.
-- Fallbacks check C_GamePad.IsEnabled() and whether Pulse detects an active controller.
local function gamepadUIActive()
	if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
		local ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
		if ok and enabled then
			return true
		end
	end
	if C_GamePad and type(C_GamePad.IsEnabled) == "function" then
		local ok, enabled = pcall(C_GamePad.IsEnabled)
		if ok and enabled then
			return true
		end
	end
	if Pulse.Engine and Pulse.Engine:IsDeviceReady() then
		return true
	end
	return false
end

-- ── SmartNavigation Focus & Navigation Inspection ─────────────────────────────

local function currentNavButton()
	if not SmartNavigation then
		return nil
	end
	if type(SmartNavigation.GetCurrentButton) == "function" then
		local ok, button = pcall(SmartNavigation.GetCurrentButton, SmartNavigation)
		if ok then
			return button
		end
	end
	return SmartNavigation.currentButton
end

local function navButtonEnabled(button)
	if not button then
		return false
	end
	if type(button.IsEnabled) == "function" then
		local ok, enabled = pcall(button.IsEnabled, button)
		if ok then
			return enabled and true or false
		end
	end
	return true
end

-- ── SmartNavigation Edge Detection (Commented Out / Pending Engine Fix) ──────
--
-- SmartNavigation:RegisterCallback invokes AttributeDelegate:SetAttribute on a SecureFrame,
-- which Blizzard UI strictly blocks third-party addons from doing (triggers ADDON_ACTION_FORBIDDEN).
-- The original implementation is preserved commented out below so it can be quickly re-enabled
-- if Blizzard ever unprotects CallbackRegistryMixin or decouples SmartNavigation from SecureFrame attributes.
--
--[[
local EDGE_EVENTS = {
	"HitTopEdge",
	"HitBottomEdge",
	"HitLeftEdge",
	"HitRightEdge",
}
local EDGE_OWNER = {}
local edgeRegistered = false

local function onEdge()
	if not gamepadUIActive() then
		return
	end
	Pulse:FireIfEnabled("uiNavigateEdge")
end

local function syncEdge()
	local wanted = Pulse.Database:Get("masterEnabled")
			and Pulse.Database:GetCue("controllerUIMaster")
			and Pulse.Database:GetCue("uiNavigateEdge")
		or false

	if wanted == edgeRegistered then
		return
	end
	if not SmartNavigation or type(SmartNavigation.RegisterCallback) ~= "function" then
		return
	end

	if wanted then
		for _, event in ipairs(EDGE_EVENTS) do
			pcall(SmartNavigation.RegisterCallback, SmartNavigation, event, onEdge, EDGE_OWNER)
		end
	else
		for _, event in ipairs(EDGE_EVENTS) do
			pcall(SmartNavigation.UnregisterCallback, SmartNavigation, event, EDGE_OWNER)
		end
	end
	edgeRegistered = wanted
end
--]]

local function syncEdge()
	-- Inert no-op while implementation is commented out above
end

-- ── Major UI Panels Inspection ────────────────────────────────────────────────

local PANEL_AREAS = { "left", "center", "right", "doublewide", "fullscreen" }

local function getUIPanelsState()
	if type(GetUIPanel) ~= "function" then
		return 0, nil
	end
	local count = 0
	local primary = nil
	for _, area in ipairs(PANEL_AREAS) do
		local ok, panel = pcall(GetUIPanel, area)
		if ok and panel then
			count = count + 1
			if not primary then
				primary = panel
			end
		end
	end
	return count, primary
end

-- ── Radial Menu Hooks (Selection Lifecycle) ───────────────────────────────────

local radialHooked = false
-- Our own copy of the selected segment, not a read of GamepadRadial.currentIndex: a
-- hooksecurefunc body runs AFTER the original, by which point currentIndex has been updated
-- (BeginSelection) or zeroed (EndSelection), so it cannot say what changed.
local lastRadialIndex = 0

-- GamepadRadialSegmentMixin:IsEnabled() is `self.handler and self.handler:IsEnabled()`, so
-- an empty segment returns NIL rather than false. Empty and disabled differ to Blizzard but
-- not to a player — neither can be used — so both land on radialBlocked. On any doubt (no
-- segment, no method, a throw) assume usable and play the ordinary tick: a missing
-- blocked-cue is a smaller lie than a phantom one.
local function radialSegmentUsable(radial, segmentIndex)
	local list = radial and radial.SegmentList
	local segment = list and list[segmentIndex]
	if not segment or type(segment.IsEnabled) ~= "function" then
		return true
	end
	local ok, enabled = pcall(segment.IsEnabled, segment)
	if not ok then
		return true
	end
	return enabled and true or false
end

local function hookRadial()
	if radialHooked then
		return
	end
	local radial = GamepadRadial
	if not radial or type(radial.BeginSelection) ~= "function" then
		return
	end
	if type(radial.HookScript) ~= "function" then
		return
	end
	radialHooked = true

	hooksecurefunc(radial, "BeginSelection", function(self, segmentIndex)
		-- Blizzard change-gates this at the call site (ProcessInput:1007 only calls it when
		-- buttonIndex ~= currentIndex), so holding the stick on one segment does not repeat.
		-- The guard is for the OTHER caller: ActivateRadial re-selects the SAME index when
		-- the wheel rebuilds on a page change, which would double-tick.
		if segmentIndex == lastRadialIndex then
			return
		end
		lastRadialIndex = segmentIndex
		if segmentIndex == 0 then
			return
		end
		if radialSegmentUsable(self, segmentIndex) then
			Pulse:FireIfEnabled("radialTick")
		else
			Pulse:FireIfEnabled("radialBlocked")
		end
	end)

	-- Both outcomes fire from this one hook, because cancelling cannot be hooked on its
	-- own: GamepadRadial binds it as
	-- `AddFunctionBinding(GAMEPAD_STICK_RIGHT_PRESS, GenerateClosure(self.CancelSelection, self))`
	-- at load, and GenerateClosure captures the function REFERENCE then, so replacing
	-- radial.CancelSelection afterwards is invisible to the binding.
	-- It does set isCancelled and call self:EndSelection(), which IS resolved by name at
	-- call time, so this hook sees the cancel with the flag already set.
	hooksecurefunc(radial, "EndSelection", function(self)
		local hadSelection = lastRadialIndex
		lastRadialIndex = 0
		if hadSelection == 0 then
			return
		end
		if self.isCancelled then
			Pulse:FireIfEnabled("radialCancel")
		else
			Pulse:FireIfEnabled("radialSelect")
		end
	end)
end

-- ── Tab Hooks ─────────────────────────────────────────────────────────────────

local tabsHooked = false

-- Panels set their own tab as they open. Where Blizzard passes isUserAction it is trusted
-- and anything the player did not do stays silent; the legacy path has no such flag.
local function onTabChanged(isUserAction)
	if isUserAction == false then
		return
	end
	if not gamepadUIActive() then
		return
	end
	Pulse:FireIfEnabled("uiTabChanged")
end

local function hookTabs()
	if tabsHooked then
		return
	end

	local installed = false

	if TabSystemMixin and type(TabSystemMixin.SetTab) == "function" then
		hooksecurefunc(TabSystemMixin, "SetTab", function(_, _, isUserAction)
			onTabChanged(isUserAction)
		end)
		installed = true
	end
	if TabSystemOwnerMixin and type(TabSystemOwnerMixin.SetTab) == "function" then
		hooksecurefunc(TabSystemOwnerMixin, "SetTab", function(_, _, isUserAction)
			onTabChanged(isUserAction)
		end)
		installed = true
	end
	if type(PanelTemplates_SetTab) == "function" then
		hooksecurefunc("PanelTemplates_SetTab", function()
			onTabChanged(nil)
		end)
		installed = true
	end

	tabsHooked = installed
end

-- ── Unified Controller UI Passive Poller ──────────────────────────────────────
--
-- Polls at 20Hz (0.05s). Reading IsShown(), currentButton, isTargetingActive, and GetUIPanel
-- runs entirely in our own frame's execution stack and can NEVER taint Blizzard's call chain.
-- When GamePad mode is toggled off, no Pulse callbacks run inside Blizzard's
-- UninitializeGamepad(), guaranteeing clean execution of DeactivateBindingGroup().

local UI_POLL_CUES = {
	"uiNavigate",
	"uiSelectionDisabled",
	"uiFocusIn",
	"uiFocusOut",
	"radialOpen",
	"radialClose",
	"radialTick",
	"radialBlocked",
	"radialSelect",
	"radialCancel",
	"radialPage",
	"panelOpen",
	"panelClose",
	"groupTargetingStart",
	"groupTargetingStop",
}

local uiPollFrame = CreateFrame("Frame")
local uiPollElapsed = 0
local UI_POLL_INTERVAL = 0.05
local uiPollSeeded = false

local lastNavButton = nil
local lastNavButtonEnabled = true
local lastRadialShown = false
local lastRadialPage = nil
local lastPanelCount = 0
local lastPrimaryPanel = nil
local lastGroupTargetingActive = false

local function resetPollState()
	lastNavButton = nil
	lastNavButtonEnabled = true
	lastRadialShown = false
	lastRadialIndex = 0
	lastRadialPage = nil
	lastPanelCount = 0
	lastPrimaryPanel = nil
	lastGroupTargetingActive = false
	uiPollSeeded = false
end

local function uiPollTick(_, elapsed)
	uiPollElapsed = uiPollElapsed + elapsed
	if uiPollElapsed < UI_POLL_INTERVAL then
		return
	end
	uiPollElapsed = 0

	if not gamepadUIActive() then
		if uiPollSeeded then
			resetPollState()
		end
		return
	end

	local navBtn = currentNavButton()
	local navEnabled = navButtonEnabled(navBtn)

	local radial = GamepadRadial
	local radialShown = (radial and radial:IsShown()) and true or false
	local radialPage = radialShown and radial.currentMainMenuPageIndex or nil

	local panelCount, primaryPanel = getUIPanelsState()

	local gtActive = (GroupTargeting and GroupTargeting.isTargetingActive) and true or false

	-- First tick seeds state so opening UI or logging in with focus/panels does not misfire
	if not uiPollSeeded then
		uiPollSeeded = true
		lastNavButton = navBtn
		lastNavButtonEnabled = navEnabled
		lastRadialShown = radialShown
		lastRadialPage = radialPage
		lastPanelCount = panelCount
		lastPrimaryPanel = primaryPanel
		lastGroupTargetingActive = gtActive
		return
	end

	-- SmartNavigation focus & element navigation
	if navBtn ~= lastNavButton then
		if lastNavButton == nil and navBtn ~= nil then
			Pulse:FireIfEnabled("uiFocusIn")
		elseif lastNavButton ~= nil and navBtn == nil then
			Pulse:FireIfEnabled("uiFocusOut")
		elseif lastNavButton ~= nil and navBtn ~= nil then
			Pulse:FireIfEnabled("uiNavigate")
		end
		lastNavButton = navBtn
		lastNavButtonEnabled = navEnabled
	elseif navBtn ~= nil and lastNavButtonEnabled and not navEnabled then
		Pulse:FireIfEnabled("uiSelectionDisabled")
		lastNavButtonEnabled = navEnabled
	else
		lastNavButtonEnabled = navEnabled
	end

	-- Radial open / close / page transitions
	if radialShown ~= lastRadialShown then
		if radialShown then
			Pulse:FireIfEnabled("radialOpen")
		else
			Pulse:FireIfEnabled("radialClose")
			lastRadialIndex = 0
			lastRadialPage = nil
		end
		lastRadialShown = radialShown
	end

	if radialShown and radialPage ~= nil then
		if lastRadialPage ~= nil and radialPage ~= lastRadialPage then
			Pulse:FireIfEnabled("radialPage")
		end
		lastRadialPage = radialPage
	end

	-- Major UI panels open / close transitions
	if panelCount ~= lastPanelCount or primaryPanel ~= lastPrimaryPanel then
		if
			panelCount > lastPanelCount
			or (panelCount == lastPanelCount and primaryPanel ~= lastPrimaryPanel and primaryPanel ~= nil)
		then
			Pulse:FireIfEnabled("panelOpen")
		elseif panelCount < lastPanelCount then
			Pulse:FireIfEnabled("panelClose")
		end
		lastPanelCount = panelCount
		lastPrimaryPanel = primaryPanel
	end

	-- Group Targeting modifier transitions
	if gtActive ~= lastGroupTargetingActive then
		if gtActive then
			Pulse:FireIfEnabled("groupTargetingStart")
		else
			Pulse:FireIfEnabled("groupTargetingStop")
		end
		lastGroupTargetingActive = gtActive
	end
end

local function syncUIPoll()
	local wanted = Pulse.Database:Get("masterEnabled") and anyEnabled(UI_POLL_CUES) or false
	uiPollFrame:SetScript("OnUpdate", wanted and uiPollTick or nil)
	if not wanted then
		resetPollState()
	end
end

-- ── Gamepad Controller Interactions (World Events) ───────────────────────────

local INTERACT_EVENT_FOR_CUE = {
	softEnemyChanged = "PLAYER_SOFT_ENEMY_CHANGED",
	softFriendChanged = "PLAYER_SOFT_FRIEND_CHANGED",
	softInteractChanged = "PLAYER_SOFT_INTERACT_CHANGED",
	softTargetInteraction = "PLAYER_SOFT_TARGET_INTERACTION",
	actionBarPage = "ACTIONBAR_PAGE_CHANGED",
	inputModeChanged = "INPUT_DEVICE_INTERFACE_TRANSITION",
}

local INTERACT_CUE_FOR_EVENT = {}
for cueID, event in pairs(INTERACT_EVENT_FOR_CUE) do
	INTERACT_CUE_FOR_EVENT[event] = cueID
end

local INTERACT_CUES = {
	"softEnemyChanged",
	"softFriendChanged",
	"softInteractChanged",
	"softTargetInteraction",
	"cursorPickup",
	"cursorDrop",
	"actionBarPage",
	"inputModeChanged",
}

local interactFrame = CreateFrame("Frame")
local hasCursorItem = false

local function safeRegisterEvent(frame, event)
	if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
		local ok, valid = pcall(C_EventUtils.IsEventValid, event)
		if ok and not valid then
			return
		end
	end
	pcall(frame.RegisterEvent, frame, event)
end

local function cursorHasItem()
	if not C_Cursor or type(C_Cursor.GetCursorItem) ~= "function" then
		return false
	end
	local ok, item = pcall(C_Cursor.GetCursorItem)
	return (ok and item) and true or false
end

local function syncInteract()
	interactFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end

	for cueID, event in pairs(INTERACT_EVENT_FOR_CUE) do
		if Pulse.Database:GetCue(cueID) then
			safeRegisterEvent(interactFrame, event)
		end
	end

	if Pulse.Database:GetCue("cursorPickup") or Pulse.Database:GetCue("cursorDrop") then
		safeRegisterEvent(interactFrame, "CURSOR_CHANGED")
		hasCursorItem = cursorHasItem()
	end
end

interactFrame:SetScript("OnEvent", function(_, event)
	if event == "CURSOR_CHANGED" then
		local has = cursorHasItem()
		if has == hasCursorItem then
			return
		end
		hasCursorItem = has
		Pulse:FireIfEnabled(has and "cursorPickup" or "cursorDrop")
		return
	end
	local cueID = INTERACT_CUE_FOR_EVENT[event]
	if cueID then
		Pulse:FireIfEnabled(cueID)
	end
end)

local function installHooks()
	hookRadial()
	hookTabs()
end

function M:OnEnable()
	local pollBinds = { "controllerUIMaster" }
	for _, id in ipairs(UI_POLL_CUES) do
		pollBinds[#pollBinds + 1] = id
	end
	Pulse:BindFrame(pollBinds, syncUIPoll)
	Pulse:BindFrame({ "controllerUIMaster", "uiNavigateEdge" }, syncEdge)

	Pulse:BindFrame(INTERACT_CUES, syncInteract)
	installHooks()

	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:RegisterEvent("PLAYER_ENTERING_WORLD")
	loader:SetScript("OnEvent", function()
		installHooks()
		syncUIPoll()
		syncEdge()
	end)
end
