-- Pulse — Core/Init.lua
--
-- Namespace, module registry, the shared "fire this trigger" helper, frame-binding, and
-- the load bootstrap. Structure ported from Tremor's Core/Init.lua.

local ADDON_NAME, Pulse = ...

_G.Pulse = Pulse -- for /run poking while tuning, same reason as Tremor's Core/Init.lua:12

-- Safe global fallback for issecretvalue. Older client builds, test harnesses, or
-- isolated environments that lack the 11.0+ Secret Values C-API will not error.
if type(_G.issecretvalue) ~= "function" then
    _G.issecretvalue = function()
        return false
    end
end

Pulse.ADDON_NAME = ADDON_NAME
Pulse.modules = {}
Pulse.moduleOrder = {}

-- Real-time monitoring for testing unverified cues without a second window or a log file.
-- Session-only, not Database-backed: a testing aid for one play session, and persisting it
-- risks it being left on and spamming chat next login. Toggle with `/pulse debug`.
-- Database.lua prints option changes; FireIfEnabled/HoldIfEnabled below print firings.
Pulse.debug = false

function Pulse:RegisterModule(name, moduleTable)
    self.modules[name] = moduleTable
    self.moduleOrder[#self.moduleOrder + 1] = name
    return moduleTable
end

-- Per-trigger throttle. The accessibility cues (Modules/Alert*.lua) rely on it; Pulse's own
-- native triggers mostly self-throttle by transition-tracking and set no `throttle` field
-- at all, which is treated as no throttle.
local lastFireTime = {}

-- Reach-in for PulseDebug /pdebug why
function Pulse:_DebugLastFireTime(triggerID)
    return lastFireTime[triggerID]
end

-- Debug-only: last GetTime() a continuous trigger's Hold was reached. Stays empty while
-- Pulse.debug is false, so a normal play session pays nothing.
local lastHoldLogTime = {}
-- Larger than every continuous caller's poll cadence, which is effectively every frame
-- while active — a gap this size means the hold stopped and restarted, not that it landed
-- between two ticks.
local HOLD_LOG_GAP = 0.5

-- The shared path from "a trigger's condition happened" to "play its mode". Every
-- discrete (non-continuous) trigger ends here.
function Pulse:FireIfEnabled(triggerID, intensityOverride)
    if not self.Database:Get("masterEnabled") then
        return
    end
    if not self.Database:GetCue(triggerID) then
        return
    end
    local trigger = self.Registry:GetTrigger(triggerID)
    if not trigger or not trigger.mode then
        return
    end

    if trigger.throttle and trigger.throttle > 0 then
        local now = GetTime()
        local last = lastFireTime[triggerID]
        if last and (now - last) < trigger.throttle then
            return
        end
        lastFireTime[triggerID] = now
    end

    -- Per-cue intensity (2026-09-15), replacing the old per-category scale. Seeded by
    -- Database:ApplyDefaults, so it is an ordinary GetTriggerSetting read.
    local scale = self.Database:GetTriggerSetting(triggerID, "intensity", 1.0)
    -- A user-chosen mode override wins over the trigger's own Registry.lua default: same
    -- trigger, same everything else, a different shape.
    local modeID = self.Database:GetTriggerMode(triggerID) or trigger.mode
    if self.debug then
        print(("Pulse: %s fired -> %s (intensity %.2f)"):format(trigger.label or triggerID, modeID, scale))
    end
    self.Engine:PlayMode(triggerID, modeID, scale, intensityOverride)
end

-- Continuous triggers skip the mode-shape scheduler and go straight to the engine's
-- role-space target, still scaled by per-cue intensity and gated by the same
-- masterEnabled/per-trigger checks, so no module duplicates them.
--
-- `duration` is optional, passed through to Engine:Hold.
function Pulse:HoldIfEnabled(triggerID, low, high, duration)
    if not self.Database:Get("masterEnabled") then
        return
    end
    if not self.Database:GetCue(triggerID) then
        return
    end
    local trigger = self.Registry:GetTrigger(triggerID)
    if not trigger then
        return
    end
    local scale = self.Database:GetTriggerSetting(triggerID, "intensity", 1.0)
    if self.debug then
        -- Rising edge only: a continuous trigger holds every OnUpdate tick while active,
        -- so logging every call would flood chat with the same line at frame rate.
        local now = GetTime()
        local last = lastHoldLogTime[triggerID]
        if not last or (now - last) > HOLD_LOG_GAP then
            print(
                ("Pulse: %s holding -> low %.2f high %.2f"):format(
                    trigger.label or triggerID,
                    (low or 0) * scale,
                    (high or 0) * scale
                )
            )
        end
        lastHoldLogTime[triggerID] = now
    end
    self.Engine:Hold(triggerID, (low or 0) * scale, (high or 0) * scale, duration)
end

local staticScaled = {}

-- Role-space sibling of HoldIfEnabled, for a continuous cue driving more than the two rumble
-- roles — Modules/Locomotion.lua's left/right footfalls are the first caller. Same gates,
-- same intensity scaling; the caller names its roles instead of passing (low, high). Without
-- it, a module wanting four roles would reach Engine:SetRoles directly and silently skip
-- masterEnabled, the cue's own switch and its intensity slider.
function Pulse:HoldRolesIfEnabled(triggerID, roles, duration)
    if not self.Database:Get("masterEnabled") then
        return
    end
    if not self.Database:GetCue(triggerID) then
        return
    end
    local trigger = self.Registry:GetTrigger(triggerID)
    if not trigger then
        return
    end
    local scale = self.Database:GetTriggerSetting(triggerID, "intensity", 1.0)
    wipe(staticScaled)
    for role, value in pairs(roles) do
        staticScaled[role] = (value or 0) * scale
    end
    if self.debug then
        -- Rising edge only, as HoldIfEnabled does. Missing until 2026-09-21, which made
        -- locomotion invisible to /pulse debug: it drives ltrigger/rtrigger through here
        -- rather than low/high through HoldIfEnabled, so the cue looked like it was never
        -- firing when it was.
        local now = GetTime()
        local last = lastHoldLogTime[triggerID]
        if not last or (now - last) > HOLD_LOG_GAP then
            local parts = {}
            for _, role in ipairs({ "low", "high", "ltrigger", "rtrigger" }) do
                if staticScaled[role] then
                    parts[#parts + 1] = ("%s %.2f"):format(role, staticScaled[role])
                end
            end
            print(
                ("Pulse: %s holding -> %s"):format(
                    trigger.label or triggerID,
                    #parts > 0 and table.concat(parts, "  ") or "(nothing)"
                )
            )
        end
        lastHoldLogTime[triggerID] = now
    end
    -- HoldRoles, not SetRoles: an omitted duration must mean one refresh window, as in
    -- HoldIfEnabled. SetRoles' own 0.1 default is short enough to stutter against.
    self.Engine:HoldRoles(triggerID, staticScaled, duration)
end

-- The one calibration entry point — the panel's "Test the selected mode" button and
-- /pulse test both call it, so one place knows what testing a mode means: bypass
-- masterEnabled and every trigger's enabled/throttle check, but still require a live pad.
-- Returns true, or false plus a reason, so each caller reports failure in its own voice.
function Pulse:TestMode(modeID)
    if not Pulse.Modes[modeID] then
        return false, "no such mode"
    end
    self.Engine:RefreshDevice()
    if not self.Engine:IsDeviceReady() then
        return false, "no controller detected"
    end
    self.Engine:PlayMode("preview", modeID, 1.0)
    return true
end

-- Per-cue preview, behind the Play button on every cue's row. Same stance as TestMode:
-- bypass masterEnabled and the cue's own checks but still require a live pad — you should
-- not have to switch a cue on, or wait for the situation that fires it, to find out what it
-- feels like. Unlike TestMode it plays the cue AS CONFIGURED, with its per-cue intensity
-- and its mode override, so it answers "what will this cue feel like" rather than "what
-- does this mode feel like in the abstract".
local PREVIEW_LAYER = "preview"

-- How long a continuous cue's preview holds. Such a texture has no natural length — its
-- real duration is however long you swim, glide or cast — so this is long enough to read as
-- sustained rather than a blip, and short enough not to outlast the button press by much.
local PREVIEW_HOLD_SECONDS = 3.5

-- What level a continuous preview holds at. A flat value rather than each texture's live
-- curve, which its own module computes from speed, depletion or cast progress — none of
-- which exist while standing in a settings panel. An honest sample, not a simulation, and
-- each cue's tooltip says so.
local PREVIEW_CONTINUOUS_LEVEL = 0.45

-- The two heartbeat cues own purpose-built previews reproducing their real lub-dub shape
-- (Modules/Health.lua, also reached by /pulse test heartbeat|warningbeat). Routed to those
-- rather than approximated with a flat hold.
local BESPOKE_PREVIEW = {
    lowHealthWarning = "TestWarningBeat",
    lowHealthTexture = "TestHeartbeat",
}

-- Does this cue have anything to preview? A gate-only trigger that plays nothing itself
-- (padDisconnected) has no button. Next to TestCue so the panel never re-derives the rule.
function Pulse:CanTestCue(triggerID)
    if BESPOKE_PREVIEW[triggerID] then
        return true
    end
    local trigger = self.Registry:GetTrigger(triggerID)
    return (trigger and (trigger.mode or trigger.continuous)) and true or false
end

-- Returns true, or false plus a reason, exactly like TestMode — callers report it in their
-- own voice.
function Pulse:TestCue(triggerID)
    local trigger = self.Registry:GetTrigger(triggerID)
    if not trigger then
        return false, "no such cue"
    end

    local method = BESPOKE_PREVIEW[triggerID]
    if method then
        local health = self.modules.Health
        if health and health[method] then
            return health[method](health)
        end
    end

    self.Engine:RefreshDevice()
    if not self.Engine:IsDeviceReady() then
        return false, "no controller detected"
    end

    local scale = self.Database:GetTriggerSetting(triggerID, "intensity", trigger.defaultIntensity or 1.0)

    if trigger.mode then
        local modeID = self.Database:GetTriggerMode(triggerID) or trigger.mode
        if not Pulse.Modes[modeID] then
            return false, "no such mode"
        end
        self.Engine:PlayMode(PREVIEW_LAYER, modeID, scale)
        return true
    end

    if trigger.continuous then
        -- Cancel rather than Stop: a discrete preview played a moment ago may still have
        -- steps in flight that would otherwise land on top of this hold (Engine.lua).
        self.Engine:CancelLayer(PREVIEW_LAYER)
        local level = PREVIEW_CONTINUOUS_LEVEL * scale
        self.Engine:Set(PREVIEW_LAYER, level, level, PREVIEW_HOLD_SECONDS)
        return true
    end

    return false, "this cue plays nothing on its own"
end

-- cueIDs: array of trigger ids whose enabled-state affects this frame's registration.
-- sync:   function that registers or unregisters events based on current settings.
function Pulse:BindFrame(cueIDs, sync)
    for _, cueID in ipairs(cueIDs) do
        self.Database:OnCueChanged(cueID, sync)
    end
    self.Database:OnGlobalChanged("masterEnabled", sync)
    sync()
end

-- The generic single-trigger watcher, for triggers needing nothing but "these events fire
-- it". No varargs read: RULE-A caution kept even though nothing here reads a restricted
-- unit, because the habit costs nothing.
function Pulse:WatchTrigger(trigger)
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then
            return
        end
        if not Pulse.Database:GetCue(trigger.id) then
            return
        end
        for _, event in ipairs(trigger.events) do
            if trigger.unit then
                frame:RegisterUnitEvent(event, trigger.unit)
            else
                frame:RegisterEvent(event)
            end
        end
    end

    frame:SetScript("OnEvent", function()
        Pulse:FireIfEnabled(trigger.id)
    end)

    self:BindFrame({ trigger.id }, sync)
    return frame
end

-- A whole category of purely generic triggers watched in one call. `custom` names trigger
-- ids a module handles itself, skipped here so a trigger with its own logic never also gets
-- a generic watcher behind its author's back.
function Pulse:WatchCategory(category, custom)
    for _, trigger in ipairs(self.Registry:GetTriggersByCategory(category)) do
        if trigger.events and #trigger.events > 0 and not (custom and custom[trigger.id]) then
            self:WatchTrigger(trigger)
        end
    end
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then
        return
    end

    Pulse.Database:Init()
    Pulse.Engine:Init()

    for _, name in ipairs(Pulse.moduleOrder) do
        local module = Pulse.modules[name]
        if module.OnEnable then
            module:OnEnable()
        end
    end

    -- The welcome page in Blizzard's AddOns list. Every cue, dial, dropdown and button
    -- that used to be registered here lives in Pulse's own window (UI/Panel/), built the
    -- first time somebody opens it rather than at login. The guide is a page in that
    -- window, built from the same Core/Guide.lua content.
    Pulse.UI.Settings:Build()

    self:UnregisterEvent("ADDON_LOADED")
end)
