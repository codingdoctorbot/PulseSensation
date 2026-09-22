-- Pulse — UI/Panel/Panel.lua
--
-- The window itself, and the glue that holds the other five files together.
--
-- Built lazily, the first time somebody opens it. Nothing in this tree runs at login beyond
-- registering a slash command, which is half the point: the old panel's cost was paid by
-- everyone at every login, opened or not, because Blizzard's Settings API wants every
-- control registered up front.
--
-- HOW IT IS SHOWN, AND WHY NOT ShowUIPanel. Blizzard's settings window goes through
-- ShowUIPanel, which hands it to UIParent's panel manager and, as a side effect, to the
-- gamepad frame-controls manager (FrameControlsManager.lua:200-208 listens on
-- UIParentPanelManager.ShowUIPanel). Pulse uses a plain Show plus UISpecialFrames for
-- Escape-to-close, and registers with no panel manager: this window never needs to push
-- other panels around, and that system has its own taint history.
--
-- Skipping ShowUIPanel was originally about avoiding the layout bookkeeping while still
-- getting gamepad integration from a direct FrameControlsManager:FrameShown call, the way
-- LootFrame.lua:213 and FloatingChatFrame.lua:139 do. Live, that direct call is what
-- produced "Pulse has been blocked from an action only available to the Blizzard UI", and
-- ShowUIPanel would have reached the identical protected call by the identical route with a
-- longer stack. Neither door was open. UI/Panel/Gamepad.lua's header has the trace.
--
-- REFRESHING. Every write anywhere — a row here, a slash command, a profile switch, a
-- module — lands in Pulse.Database, which notifies its listeners. The panel subscribes to
-- all of them and coalesces the result into one refresh on the next frame. A profile switch
-- fires several hundred notifications at once, and turning those into one pass is what lets
-- it show up here immediately where the old panel had to be closed and reopened.

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel
local Theme = Panel.Theme
local Content = Panel.Content
local Sidebar = Panel.Sidebar
local Gamepad = Panel.Gamepad
local Spec = Panel.Spec

local FRAME_NAME = "PulseSettingsFrame"

local frame -- the window, nil until first open
local dirty = false
local dirtyScheduled = false

-- ── Dirty handling ────────────────────────────────────────────────────────────

local function processDirty()
    dirtyScheduled = false
    if not dirty then
        return
    end
    dirty = false
    if not frame or not frame:IsShown() then
        return
    end
    frame.Content:RefreshRows()
    frame.Content:LayoutRows()
end

-- Called by every row after it writes, and by every database listener. Cheap enough to call
-- from anywhere: it sets a flag and, at most once per frame, does one pass over the page in
-- view. Pages out of view are refreshed when next shown.
function Panel.MarkDirty()
    dirty = true
    if dirtyScheduled then
        return
    end
    if not frame or not frame:IsShown() then
        return
    end
    dirtyScheduled = true
    C_Timer.After(0, processDirty)
end

-- ── Database subscriptions ────────────────────────────────────────────────────

-- Everything up front rather than per row, for one reason: Database's notifyAll visits only
-- keys that already have a listener, so a key nobody subscribed to is silent. Subscribing
-- the whole surface means a profile switch reaches this panel whichever pages have been
-- opened. The cost is a few hundred table entries created once.
local function subscribeToDatabase()
    local db = Pulse.Database
    local mark = Panel.MarkDirty

    for key in pairs(db.GLOBAL_DEFAULTS) do
        db:OnGlobalChanged(key, mark)
    end
    for key in pairs(db.PROFILE_DEFAULTS) do
        db:OnGlobalChanged(key, mark)
    end

    for _, trigger in ipairs(Pulse.Triggers) do
        db:OnCueChanged(trigger.id, mark)
        db:OnTriggerSettingChanged(trigger.id, "intensity", mark)
        if trigger.tunables then
            for _, tunable in ipairs(trigger.tunables) do
                db:OnTriggerSettingChanged(trigger.id, tunable.key, mark)
            end
        end
    end

    for _, modeID in ipairs(Pulse.ModeOrder) do
        db:OnModeTuningChanged(modeID, "lowMult", mark)
        db:OnModeTuningChanged(modeID, "highMult", mark)
        db:OnModeTuningChanged(modeID, "triggerMult", mark)
        db:OnModeTuningChanged(modeID, "durMult", mark)
    end

    if type(db.OnChannelTuningChanged) == "function" then
        for _, channel in ipairs(Pulse.CHANNELS) do
            for _, tunable in ipairs(Pulse.CHANNEL_TUNABLES) do
                db:OnChannelTuningChanged(channel, tunable.key, mark)
            end
        end
    end
end

-- ── Window construction ───────────────────────────────────────────────────────

-- SettingsFrameTemplate is the flat panel background plus the ButtonFrameTemplateNoPortrait
-- nine-slice border and the corner close button, the frame the real settings window is
-- built on (Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml:4). Falls
-- back rather than erroring: the window is worth having even as a generic panel.
local function createWindow()
    local created
    for _, template in ipairs({ "SettingsFrameTemplate", "ButtonFrameTemplate" }) do
        local ok, result = pcall(CreateFrame, "Frame", FRAME_NAME, UIParent, template)
        if ok and result then
            created = result
            break
        end
    end
    if not created then
        created = CreateFrame("Frame", FRAME_NAME, UIParent)
    end
    return created
end

local function buildWindow()
    local f = createWindow()
    f:SetSize(Theme.PANEL_WIDTH, Theme.PANEL_HEIGHT)
    f:SetPoint("CENTER")
    -- DIALOG, not HIGH. Blizzard's settings window is HIGH and both can be open at once,
    -- since the splash page has a button that opens this one. At equal strata the two
    -- interleave by frame level and one window's text shows through the other's.
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Title. SettingsFrameTemplate puts it on the nine-slice; a fallback frame may not, so
    -- make our own rather than assume.
    local titleText = f.NineSlice and f.NineSlice.Text
    if not titleText then
        titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOP", f, "TOP", 0, -5)
    end
    titleText:SetText("Pulse")
    if titleText.SetTextColor then
        titleText:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
    end

    -- An opaque fill of our own, before anything else is drawn.
    --
    -- SettingsFrameTemplate ships a Bg (FlatPanelBackgroundTemplate) that ought to do this
    -- and does not: its XML sets frameLevel="0", an ABSOLUTE level, so it renders below
    -- every other frame in the strata — including Blizzard's settings window when that is
    -- open. CONFIRMED FROM A SCREENSHOT: this window's border and rows on top, its
    -- background at the very bottom, and the splash page's wordmark legible in between.
    --
    -- A texture on the frame itself cannot do that, being drawn as part of its frame rather
    -- than as a frame of its own. The Bg is nudged up too, so the nine-slice art still
    -- reads where it shows past this fill.
    if f.Bg and f.Bg.SetFrameLevel then
        f.Bg:SetFrameLevel(f:GetFrameLevel())
    end

    local fill = f:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
    fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
    fill:SetColorTexture(Theme.COLOR_BG.r, Theme.COLOR_BG.g, Theme.COLOR_BG.b, 1)

    -- Atmospheric watermark of the ripple artwork in the background of the content pane
    local watermark = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    watermark:SetTexture("Interface\\AddOns\\Pulse\\Media\\SettingsBG")
    watermark:SetPoint("TOPLEFT", f, "TOPLEFT", 190, -60)
    watermark:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    watermark:SetAlpha(0.06)

    -- The inner recessed area behind the list. Blizzard_SettingsPanel.xml:10-16.
    local inner = f:CreateTexture(nil, "OVERLAY", nil, 2)
    local okAtlas = pcall(inner.SetAtlas, inner, "Options_InnerFrame", true)
    if okAtlas then
        inner:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -64)
    else
        inner:Hide()
    end

    -- Corner X. SettingsFrameTemplate supplies ClosePanelButton; make one if it did not.
    if not f.ClosePanelButton then
        local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
        if ok and close then
            f.ClosePanelButton = close
        end
    end
    if f.ClosePanelButton then
        f.ClosePanelButton:SetScript("OnClick", function()
            Panel.Close()
        end)
    end

    -- Bottom-right Close. Blizzard_SettingsPanel.xml:50-55.
    local closeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeButton:SetSize(96, 22)
    closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    closeButton:SetText(CLOSE or "Close")
    closeButton:SetScript("OnClick", function()
        Panel.Close()
    end)
    f.CloseButton = closeButton

    -- Sidebar.
    local sidebar = Sidebar.Create(f, function(page)
        -- Clearing the box on a category change matches Blizzard's panel
        -- (SettingsPanelMixin:SelectCategory calls ClearSearchBox) and matters more here,
        -- the filter being page-scoped: a stale term makes a fresh page look half empty.
        if f.SearchBox and f.SearchBox:GetText() ~= "" then
            f.SearchBox:SetText("")
        end
        f.Content:SetPage(page)
    end)
    sidebar:SetWidth(Theme.SIDEBAR_WIDTH)
    sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", Theme.SIDEBAR_INSET_X, Theme.SIDEBAR_INSET_Y)
    sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", Theme.SIDEBAR_INSET_X, Theme.SIDEBAR_BOTTOM)
    f.Sidebar = sidebar

    -- Content container. Three anchors, as Blizzard_SettingsPanel.xml:67-77 does, so it
    -- tracks the sidebar on the left and the window on the right.
    local container = CreateFrame("Frame", nil, f)
    container:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", Theme.CONTAINER_GAP, 0)
    container:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", Theme.CONTAINER_GAP, 1)
    container:SetPoint("RIGHT", f, "RIGHT", Theme.CONTAINER_RIGHT, 0)
    f.Container = container

    f.Content = Content.Create(container)

    -- Search box. Scoped to the page in view — Content.lua's SetFilter says why, and the
    -- instruction text says so on screen rather than leaving it to be discovered.
    local ok, search = pcall(CreateFrame, "EditBox", nil, f, "SearchBoxTemplate")
    if ok and search then
        search:SetSize(350, 22)
        search:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 4, 20)
        search:SetAutoFocus(false)
        search:SetMaxBytes(64)
        if search.Instructions then
            search.Instructions:SetText("Search this page")
        end
        search:HookScript("OnTextChanged", function(self)
            f.Content:SetFilter(self:GetText())
        end)
        search:HookScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                f.Content:SetFilter(nil)
            end
        end)
        f.SearchBox = search
    end

    f:SetScript("OnShow", function()
        f.Content:RefreshRows()
        f.Content:LayoutRows()
        Gamepad.OnShow()
    end)
    f:SetScript("OnHide", function()
        Theme.HideTooltip()
        -- The list and the dialogs are parented to UIParent, not to the window, so that
        -- they can sit above it. That means closing the window has to take them with it.
        Panel.Popup.CloseAll()
        Gamepad.OnHide()
    end)

    return f
end

-- ── Build ─────────────────────────────────────────────────────────────────────

function Panel.EnsureBuilt()
    if frame then
        return frame
    end

    -- Everything the spec reads has to exist. Database:Init and the module OnEnable pass
    -- both run from Core/Init.lua's ADDON_LOADED bootstrap, and building lazily on first
    -- open means this file assumes nothing about event ordering.
    if not Pulse.Database or not Pulse.Registry then
        return nil
    end

    local ok, result = pcall(buildWindow)
    if not ok then
        print("Pulse: could not build the settings window (" .. tostring(result) .. ")")
        return nil
    end
    frame = result

    local pages = Spec.BuildPages()
    frame.pageList = pages
    frame.Sidebar:CreateButtons(pages)

    -- After CreateButtons: Gamepad.Setup adds a "right enters this category" override to
    -- every sidebar button and then marks itself done, so it must run when there are
    -- buttons to walk. InputUtil may call it the moment it is registered.
    Gamepad.Init(frame)

    subscribeToDatabase()

    tinsert(UISpecialFrames, FRAME_NAME)

    frame.Sidebar:Select(pages[1])

    return frame
end

-- ── Open / close ──────────────────────────────────────────────────────────────

-- Switch the page in view by id. Public because the cue index needs it: an index entry's
-- whole job is to be a link.
function Panel.GoToPage(pageID)
    if not frame or not frame.pageList or not pageID then
        return false
    end
    for _, page in ipairs(frame.pageList) do
        if page.id == pageID then
            frame.Sidebar:Select(page)
            return true
        end
    end
    return false
end

function Panel.Open(pageID)
    local f = Panel.EnsureBuilt()
    if not f then
        return
    end

    Panel.GoToPage(pageID)

    f:Show()
    f:Raise()
end

function Panel.Close()
    if frame then
        frame:Hide()
    end
end

function Panel.Toggle(pageID)
    if frame and frame:IsShown() then
        Panel.Close()
    else
        Panel.Open(pageID)
    end
end

function Panel.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- Kept for symmetry with Pulse.UI.Settings:Build(), in case Core/Init.lua ever wants to
-- build this eagerly. Building is idempotent.
function Panel:Build()
    return Panel.EnsureBuilt()
end

-- ── Slash commands ────────────────────────────────────────────────────────────
--
-- Moved here from UI/Settings.lua on 2026-09-22, when that file became the splash page.
-- `debug` and `test` are ported verbatim, including both bespoke heartbeat previews. The
-- one change: a bare /pulse opens Pulse's own window rather than Settings.OpenToCategory,
-- the Blizzard category now being a welcome page with one button on it.

local function slashHandler(message)
    local command, rest = strsplit(" ", strtrim(message or ""), 2)
    command = string.lower(command or "")

    if command == "debug" then
        Pulse.debug = not Pulse.debug
        print("Pulse: debug " .. (Pulse.debug and "ON — option changes and cue firings will print here." or "OFF"))
        return
    end

    if command == "test" then
        local arg = strtrim(rest or "")
        if arg == "" then
            print(
                "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: "
                    .. table.concat(Pulse.ModeOrder, ", ")
                    .. ", heartbeat, warningbeat"
            )
            return
        end
        local lowerArg = string.lower(arg)
        if lowerArg == "heartbeat" or lowerArg == "warningbeat" then
            local method = (lowerArg == "heartbeat") and "TestHeartbeat" or "TestWarningBeat"
            local health = Pulse.modules and Pulse.modules.Health
            if not (health and health[method]) then
                print("Pulse: that preview is unavailable.")
                return
            end
            local ok, reason = health[method](health)
            if not ok then
                print("Pulse: " .. reason .. ", so there is nothing to test.")
            end
            return
        end
        local modeID = string.upper(arg)
        local ok, reason = Pulse:TestMode(modeID)
        if not ok then
            print(
                "Pulse: "
                    .. reason
                    .. (
                        reason == "no such mode"
                            and (' "' .. modeID .. '" — try one of: ' .. table.concat(Pulse.ModeOrder, ", "))
                        or ", so there is nothing to test."
                    )
            )
        end
        return
    end

    if command == "profile" then
        local target = strtrim(rest or "")
        local db = Pulse.Database
        if not db then
            return
        end

        local names = db:GetProfileNames()

        if target == "" then
            local _, activeName, why = db:GetProfileResolution()
            print(('Pulse: active profile is "%s" (%s)'):format(activeName or "Default", why or "in force"))
            return
        end

        local matchName = nil
        local lowerTarget = string.lower(target)
        for _, name in ipairs(names) do
            if string.lower(name) == lowerTarget then
                matchName = name
                break
            end
        end

        if not matchName then
            for _, name in ipairs(names) do
                if string.lower(name):find(lowerTarget, 1, true) then
                    matchName = name
                    break
                end
            end
        end

        if matchName then
            db:SetActiveProfileName(matchName)
            print(('Pulse: switched to profile "%s"'):format(matchName))
        else
            print(('Pulse: no profile matching "%s". Available: %s'):format(target, table.concat(names, ", ")))
        end
        return
    end

    -- Bare /pulse, and /pulse ui, both land on the window.
    Panel.Toggle()
end

SLASH_PULSE1 = "/pulse"
SlashCmdList["PULSE"] = slashHandler

SLASH_PULSEUI1 = "/pulseui"
SLASH_PULSEUI2 = "/pulsepanel"
SlashCmdList["PULSEUI"] = function()
    Panel.Toggle()
end
