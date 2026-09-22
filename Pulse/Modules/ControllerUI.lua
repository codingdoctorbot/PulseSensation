-- Pulse — Modules/ControllerUI.lua
--
-- WoW Forever's native gamepad interface, observed rather than recreated. Nothing here
-- reads raw controller input, polls a stick or reimplements navigation — Blizzard maintains
-- that state and announces every transition this module cares about.
--
-- Three observation mechanisms, because Blizzard uses three:
--   CallbackRegistryMixin  — SmartNavigation's eight navigation/focus callbacks.
--                            Unregisterable, so they follow the usual BindFrame pattern and
--                            cost nothing while every cue in the group is off.
--   EventRegistry          — the radial's open/close. Also unregisterable.
--   hooksecurefunc         — the radial's selection lifecycle and the shared tab plumbing.
--                            These CANNOT be undone, so they install once and stay. Each
--                            hook body does nothing but call FireIfEnabled, which returns
--                            immediately when the cue or the addon is off.
--
-- Every name below was CHECKED against the Forever source rather than recalled:
--   SmartNavigation            Blizzard_GamepadSmartNavigation/SmartNavigation.xml:64
--   its eight callback events  .../SmartNavigation.lua:74-81
--   GetCurrentButton()         .../SmartNavigation.lua:1583
--   GamepadRadial              Blizzard_Gamepad/UI/Radials/GamepadRadial.xml:119
--   BeginSelection/EndSelection/CancelSelection/NextPage/PreviousPage
--                              .../GamepadRadial.lua:931/958/968/849/858
--   Gamepad.ShowMainMenu/HideMainMenu   .../GamepadRadial.lua:553/563
--   InputUtil.IsGamepadUIEnabled()      Blizzard_SharedXML/Mainline/InputUtil.lua:11
--
-- NONE of it is confirmed live. The source says these fire; nothing in this project has yet
-- felt one land. Every cue ships off by default and says so in its own caveat.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("ControllerUI", M)

-- Callback-registry owner token. Register and unregister both key off it, so it must be one
-- stable table for the addon's lifetime, not a fresh one per sync.
local OWNER = {}

local function anyEnabled(cueIDs)
    for _, cueID in ipairs(cueIDs) do
        if Pulse.Database:GetCue(cueID) then return true end
    end
    return false
end

-- Every cue here describes the CONTROLLER driving the interface, so none should fire on
-- mouse and keyboard. Blizzard's own answer is InputUtil.IsGamepadUIEnabled(), resolving to
-- C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad. Absent,
-- stay silent rather than guess (RULE E) — these cues are meaningless without a gamepad
-- interface anyway.
local function gamepadUIActive()
    if not InputUtil or type(InputUtil.IsGamepadUIEnabled) ~= "function" then return false end
    local ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
    return (ok and enabled) and true or false
end

-- SmartNavigation — focus movement, edges, focus in/out

local NAV_CUES = {
    "uiNavigate", "uiNavigateEdge", "uiSelectionDisabled", "uiFocusIn", "uiFocusOut",
}

local navRegistered = false
local lastNavButton = nil
local navSeeded = false

local function currentNavButton()
    if not SmartNavigation then return nil end
    if type(SmartNavigation.GetCurrentButton) == "function" then
        local ok, button = pcall(SmartNavigation.GetCurrentButton, SmartNavigation)
        if ok then return button end
    end
    return SmartNavigation.currentButton
end

local function onSelectionUpdated()
    if not gamepadUIActive() then return end
    local button = currentNavButton()
    -- Object identity, never the frame's name: UI elements share names or have none, and
    -- the callback can fire more than once for the same element.
    if button == lastNavButton then return end
    lastNavButton = button
    -- Discovering what's already focused when a panel opens is not a navigation step.
    if not navSeeded then
        navSeeded = true
        return
    end
    -- Losing the selection isn't a destination — uiFocusOut covers that transition.
    if not button then return end
    Pulse:FireIfEnabled("uiNavigate")
end

local function onEdge()
    if not gamepadUIActive() then return end
    Pulse:FireIfEnabled("uiNavigateEdge")
end

local function onSelectionDisabled()
    if not gamepadUIActive() then return end
    Pulse:FireIfEnabled("uiSelectionDisabled")
end

local function onFocusedFrame()
    if not gamepadUIActive() then return end
    Pulse:FireIfEnabled("uiFocusIn")
end

local function onUnfocusedFrame()
    if not gamepadUIActive() then return end
    Pulse:FireIfEnabled("uiFocusOut")
end

local NAV_CALLBACKS = {
    { "SelectedButtonUpdated",             onSelectionUpdated },
    { "SelectedButtonEnabledStateChanged", onSelectionDisabled },
    { "HitTopEdge",                        onEdge },
    { "HitBottomEdge",                     onEdge },
    { "HitLeftEdge",                       onEdge },
    { "HitRightEdge",                      onEdge },
    { "FocusedFrame",                      onFocusedFrame },
    { "UnfocusedFrame",                    onUnfocusedFrame },
}

local function syncNav()
    local wanted = Pulse.Database:Get("masterEnabled") and anyEnabled(NAV_CUES) or false
    if wanted == navRegistered then return end
    -- Blizzard_GamepadSmartNavigation may not have loaded yet. Leave navRegistered alone so
    -- the retry in OnEnable picks this up on a later ADDON_LOADED.
    if not SmartNavigation or type(SmartNavigation.RegisterCallback) ~= "function" then return end

    if wanted then
        -- Seed from live state: arriving with something already focused is not a step.
        lastNavButton = currentNavButton()
        navSeeded = true
        for _, callback in ipairs(NAV_CALLBACKS) do
            pcall(SmartNavigation.RegisterCallback, SmartNavigation, callback[1], callback[2], OWNER)
        end
    else
        for _, callback in ipairs(NAV_CALLBACKS) do
            pcall(SmartNavigation.UnregisterCallback, SmartNavigation, callback[1], OWNER)
        end
        lastNavButton, navSeeded = nil, false
    end
    navRegistered = wanted
end

-- Radial menu — open/close via EventRegistry

local RADIAL_EVENT_CUES = { "radialOpen", "radialClose" }
local radialEventsRegistered = false

-- Hoisted rather than built inside sync: UnregisterCallback keys on the owner, but keeping
-- one stable function per event avoids relying on that detail.
local function onRadialShown()  Pulse:FireIfEnabled("radialOpen")  end
local function onRadialHidden() Pulse:FireIfEnabled("radialClose") end

local function syncRadialEvents()
    local wanted = Pulse.Database:Get("masterEnabled") and anyEnabled(RADIAL_EVENT_CUES) or false
    if wanted == radialEventsRegistered then return end
    if not EventRegistry then return end

    if wanted then
        pcall(EventRegistry.RegisterCallback, EventRegistry, "Gamepad.ShowMainMenu", onRadialShown, OWNER)
        pcall(EventRegistry.RegisterCallback, EventRegistry, "Gamepad.HideMainMenu", onRadialHidden, OWNER)
    else
        pcall(EventRegistry.UnregisterCallback, EventRegistry, "Gamepad.ShowMainMenu", OWNER)
        pcall(EventRegistry.UnregisterCallback, EventRegistry, "Gamepad.HideMainMenu", OWNER)
    end
    radialEventsRegistered = wanted
end

-- Radial menu — selection lifecycle via hooksecurefunc

local radialHooked = false
-- Our own copy of the selected segment, not a read of GamepadRadial.currentIndex: a
-- hooksecurefunc body runs AFTER the original, by which point currentIndex has been updated
-- (BeginSelection) or zeroed (EndSelection), so it cannot say what changed.
local lastRadialIndex = 0
-- Same idea for the page: ActivateRadial fires on open as well as on a real page change,
-- so the previous page is tracked here and cleared on show (nil = "haven't seen one yet").
local lastRadialPage = nil

-- GamepadRadialSegmentMixin:IsEnabled() is `self.handler and self.handler:IsEnabled()`, so
-- an empty segment returns NIL rather than false. Empty and disabled differ to Blizzard but
-- not to a player — neither can be used — so both land on radialBlocked. On any doubt (no
-- segment, no method, a throw) assume usable and play the ordinary tick: a missing
-- blocked-cue is a smaller lie than a phantom one.
local function radialSegmentUsable(radial, segmentIndex)
    local list = radial and radial.SegmentList
    local segment = list and list[segmentIndex]
    if not segment or type(segment.IsEnabled) ~= "function" then return true end
    local ok, enabled = pcall(segment.IsEnabled, segment)
    if not ok then return true end
    return enabled and true or false
end

local function hookRadial()
    if radialHooked then return end
    local radial = GamepadRadial
    if not radial or type(radial.BeginSelection) ~= "function" then return end
    if type(radial.HookScript) ~= "function" then return end
    radialHooked = true

    hooksecurefunc(radial, "BeginSelection", function(self, segmentIndex)
        -- Blizzard change-gates this at the call site (ProcessInput:1007 only calls it when
        -- buttonIndex ~= currentIndex), so holding the stick on one segment does not repeat.
        -- The guard is for the OTHER caller: ActivateRadial re-selects the SAME index when
        -- the wheel rebuilds on a page change, which would double-tick.
        if segmentIndex == lastRadialIndex then return end
        lastRadialIndex = segmentIndex
        if segmentIndex == 0 then return end
        if radialSegmentUsable(self, segmentIndex) then
            Pulse:FireIfEnabled("radialTick")
        else
            Pulse:FireIfEnabled("radialBlocked")
        end
    end)

    -- Closing the radial without committing does NOT end the selection: EndSelection is
    -- reached from exactly two places (CancelSelection, and ProcessInput when the stick
    -- recentres) and the hide path is neither. Blizzard does not care — OnShow resets its
    -- own currentIndex — but lastRadialIndex would survive and suppress the next sweep onto
    -- that segment as a duplicate. Clearing on both edges keeps the two in step.
    --
    -- HookScript rather than hooksecurefunc on the method: the XML wires these as
    -- <OnShow method="OnShow"/>, and HookScript is correct regardless of how a script was
    -- wired. Installed unconditionally, being state bookkeeping rather than a cue — it must
    -- stay right while every radial cue is off.

    -- Both outcomes fire from this one hook, because cancelling cannot be hooked on its
    -- own: GamepadRadial binds it as
    -- `AddFunctionBinding(GAMEPAD_STICK_RIGHT_PRESS, GenerateClosure(self.CancelSelection, self))`
    -- at load, and GenerateClosure captures the function REFERENCE then, so replacing
    -- radial.CancelSelection afterwards is invisible to the binding. CONFIRMED LIVE
    -- 2026-09-21: hooking CancelSelection directly never fired. It does set isCancelled and
    -- call self:EndSelection(), which IS resolved by name at call time, so this hook sees
    -- the cancel with the flag already set.
    --
    -- EndSelection early-returns when nothing was selected and the hook still runs, so
    -- lastRadialIndex doubles as "there was a live selection to end".
    hooksecurefunc(radial, "EndSelection", function(self)
        local hadSelection = lastRadialIndex
        lastRadialIndex = 0
        if hadSelection == 0 then return end
        if self.isCancelled then
            Pulse:FireIfEnabled("radialCancel")
        else
            Pulse:FireIfEnabled("radialSelect")
        end
    end)

    -- Paging is NOT hooked. Same captured-closure problem (GAMEPAD_SHOULDER_LEFT/RIGHT bind
    -- GenerateClosure(self.PreviousPage/NextPage, self) at load), and the obvious workaround
    -- — hooking ActivateRadial, which both page functions call by name — TAINTS THE GAME.
    --
    -- CONFIRMED LIVE 2026-09-21: "Pulse has been blocked from an action only available to
    -- the Blizzard UI". OnShow calls self:ActivateRadial(DEFAULT_PAGE_INDEX) about a third
    -- of the way through its body, then calls HideUIPanel twice, SetUIFocusState,
    -- UnsuspendAllFrames and GroupTargeting:StopTargeting. hooksecurefunc keeps the hooked
    -- function's own execution clean, but the hook runs inside the CALLER's execution, so
    -- everything OnShow did afterwards ran tainted and the protected calls were refused.
    --
    -- THE RULE THIS BOUGHT: only hook a Blizzard function whose caller does nothing
    -- protected afterwards. BeginSelection and EndSelection qualify — each is the last
    -- statement in its branch of ProcessInput, and EndSelection is last in CancelSelection.
    -- ActivateRadial does not. Page changes are read instead, below: a poll costs a table
    -- lookup every 0.05s and cannot taint anything.
end

-- Tabs

local tabsHooked = false

-- Panels set their own tab as they open. Where Blizzard passes isUserAction it is trusted
-- and anything the player did not do stays silent; the legacy path has no such flag.
local function onTabChanged(isUserAction)
    if isUserAction == false then return end
    if not gamepadUIActive() then return end
    Pulse:FireIfEnabled("uiTabChanged")
end

local function hookTabs()
    if tabsHooked then return end

    -- The flag is set at the BOTTOM of this function, not here: setting it first records a
    -- total failure as a success, because the ADDON_LOADED/PLAYER_ENTERING_WORLD retry then
    -- returns on the flag instead of trying the hooks again, leaving uiTabChanged dead for
    -- the session.

    -- Hooking the MIXIN table, not individual frames. Mixin() copies function references
    -- onto a frame at creation, so this reaches only panels built AFTER it runs — most of
    -- them, since the big tabbed panels are load-on-demand, but not all. Hooking every frame
    -- would mean tracking frame creation, a much larger change for an unfelt cue.
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
    -- The legacy path is a plain global, so this one reaches every panel that uses it.
    if type(PanelTemplates_SetTab) == "function" then
        hooksecurefunc("PanelTemplates_SetTab", function()
            onTabChanged(nil)
        end)
        installed = true
    end

    -- Only now: nothing installed means nothing was hooked, and the next retry should get
    -- another go rather than being turned away at the top.
    tabsHooked = installed
end

-- Radial menu — page changes, and state reset, by reading rather than hooking
--
-- Deliberately a poll. Every hookable route into a page change runs inside a caller that
-- goes on to touch protected frames (see hookRadial), and this addon is not worth tainting
-- the game's menu for. Reading IsShown() and an integer every 0.05s taints nothing. It also
-- clears both trackers when the radial closes — Blizzard's hide path never calls
-- EndSelection, so without it the next sweep onto the same segment is swallowed.

local RADIAL_CUES = {
    "radialOpen", "radialClose", "radialTick", "radialBlocked",
    "radialSelect", "radialCancel", "radialPage",
}

local radialPollFrame = CreateFrame("Frame")
local radialPollElapsed = 0
local RADIAL_POLL_INTERVAL = 0.05

local function radialPollTick(_, elapsed)
    radialPollElapsed = radialPollElapsed + elapsed
    if radialPollElapsed < RADIAL_POLL_INTERVAL then return end
    radialPollElapsed = 0

    local radial = GamepadRadial
    if not radial or not radial:IsShown() then
        lastRadialIndex, lastRadialPage = 0, nil
        return
    end

    local page = radial.currentMainMenuPageIndex
    if page == lastRadialPage then return end
    local hadPage = lastRadialPage
    lastRadialPage = page
    -- First page seen after opening seeds the tracker; it isn't a change.
    if hadPage == nil or page == nil then return end
    Pulse:FireIfEnabled("radialPage")
end

local function syncRadialPoll()
    local wanted = Pulse.Database:Get("masterEnabled") and anyEnabled(RADIAL_CUES) or false
    radialPollFrame:SetScript("OnUpdate", wanted and radialPollTick or nil)
    if not wanted then
        lastRadialIndex, lastRadialPage = 0, nil
    end
end

-- Gamepad Controller Interactions — the controller acting on the world
--
-- Every signal here is a plain Lua event on our own frame, deliberately. The radial section
-- above needed hooksecurefunc and that cost a real taint bug. An event dispatched to our
-- own frame has nothing of Blizzard's running after it in the same stack and cannot taint
-- anything. Where a choice existed, the event won.

local INTERACT_EVENT_FOR_CUE = {
    softEnemyChanged    = "PLAYER_SOFT_ENEMY_CHANGED",
    softFriendChanged   = "PLAYER_SOFT_FRIEND_CHANGED",
    softInteractChanged = "PLAYER_SOFT_INTERACT_CHANGED",
    actionBarPage       = "ACTIONBAR_PAGE_CHANGED",
    inputModeChanged    = "INPUT_DEVICE_INTERFACE_TRANSITION",
}

local INTERACT_CUE_FOR_EVENT = {}
for cueID, event in pairs(INTERACT_EVENT_FOR_CUE) do
    INTERACT_CUE_FOR_EVENT[event] = cueID
end

-- cursorPickup/cursorDrop are two edges of one event, so they're handled separately.
local INTERACT_CUES = {
    "softEnemyChanged", "softFriendChanged", "softInteractChanged",
    "cursorPickup", "cursorDrop", "actionBarPage", "inputModeChanged",
}

local interactFrame = CreateFrame("Frame")
local hasCursorItem = false

-- Registering an event the client does not know throws, and
-- INPUT_DEVICE_INTERFACE_TRANSITION is Forever-only, absent from the retail archive.
-- C_EventUtils.IsEventValid is the portability tool for this; the pcall is the belt.
local function safeRegisterEvent(frame, event)
    if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
        local ok, valid = pcall(C_EventUtils.IsEventValid, event)
        if ok and not valid then return end
    end
    pcall(frame.RegisterEvent, frame, event)
end

-- Presence only. The item is never read, compared or stored: truthiness on a non-boolean
-- secret is the one inspection Secret Values permits, and all this needs.
local function cursorHasItem()
    if not C_Cursor or type(C_Cursor.GetCursorItem) ~= "function" then return false end
    local ok, item = pcall(C_Cursor.GetCursorItem)
    return (ok and item) and true or false
end

local function syncInteract()
    interactFrame:UnregisterAllEvents()
    if not Pulse.Database:Get("masterEnabled") then return end

    for cueID, event in pairs(INTERACT_EVENT_FOR_CUE) do
        if Pulse.Database:GetCue(cueID) then
            safeRegisterEvent(interactFrame, event)
        end
    end

    if Pulse.Database:GetCue("cursorPickup") or Pulse.Database:GetCue("cursorDrop") then
        safeRegisterEvent(interactFrame, "CURSOR_CHANGED")
        -- Seed from live state rather than false: enabling the cue mid-drag should not make
        -- the next event look like a pickup.
        hasCursorItem = cursorHasItem()
    end
end

-- No varargs read anywhere here. PLAYER_SOFT_INTERACT_CHANGED carries oldTarget/newTarget
-- GUIDs and is flagged SecretWhenUnitIdentityRestricted in Blizzard's documentation; every
-- cue in this group is occurrence-only, so touching a payload gains nothing and risks a
-- RULE B violation.
interactFrame:SetScript("OnEvent", function(_, event)
    if event == "CURSOR_CHANGED" then
        local has = cursorHasItem()
        if has == hasCursorItem then return end
        hasCursorItem = has
        Pulse:FireIfEnabled(has and "cursorPickup" or "cursorDrop")
        return
    end
    local cueID = INTERACT_CUE_FOR_EVENT[event]
    if cueID then Pulse:FireIfEnabled(cueID) end
end)

local function installHooks()
    hookRadial()
    hookTabs()
end

function M:OnEnable()
    Pulse:BindFrame(NAV_CUES, syncNav)
    Pulse:BindFrame(RADIAL_EVENT_CUES, syncRadialEvents)
    Pulse:BindFrame(RADIAL_CUES, syncRadialPoll)
    Pulse:BindFrame(INTERACT_CUES, syncInteract)
    installHooks()

    -- Blizzard_Gamepad, Blizzard_GamepadSmartNavigation and the tabbed panels can load
    -- after this addon, so anything absent at ADDON_LOADED gets another chance. Each
    -- install and sync is idempotent and returns immediately once it has succeeded.
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function()
        installHooks()
        syncNav()
        syncRadialEvents()
    end)
end
