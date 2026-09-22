-- PulseDebug — Debug.lua
--
-- Troubleshooting companion for Pulse, same relationship TremorDebug has to Tremor: no
-- cue logic of its own, reaches Pulse through the `_G.Pulse` handle Core/Init.lua already
-- exposes for exactly this purpose. Installing this requires no change to Pulse.
--
-- Pulse's engine needs a different set of questions answered than Tremor's did. Tremor
-- plays one cue at a time, so "why didn't it fire" was the hard question and TremorDebug's
-- `why` command answers it. Pulse blends any number of named layers continuously, so the
-- hard question is closer to "what's actually contributing to the channel right now" —
-- `layers` and `channels` below exist because nothing else can answer that from outside
-- Core/Engine.lua's upvalues.

local ADDON_NAME = ...

local PREFIX = "|cffb488ff PulseDebug|r  "
local GOOD   = "|cff44ff44"
local BAD    = "|cffff5555"
local WARN   = "|cffffcc00"
local DIM    = "|cff999999"
local HEAD   = "|cffffffff"
local R      = "|r"

local function out(text)
    print(PREFIX .. (text or ""))
end

local function row(label, value)
    out(string.format("%-26s %s", label, value or ""))
end

local function flag(value)
    return value and (GOOD .. "yes" .. R) or (BAD .. "no" .. R)
end

local function readBool(value)
    if issecretvalue(value) then return nil end
    return value and true or false
end

local function boolCell(value)
    if value == nil then return WARN .. "secret" .. R end
    return flag(value)
end

local function core()
    local P = _G.Pulse
    if not P or not P.Database or not P.Registry or not P.Engine then
        out(BAD .. "Pulse is not loaded." .. R .. " Check the AddOns list at character select.")
        return nil
    end
    return P
end

local function findTrigger(P, triggerID)
    if triggerID == "" then
        out(BAD .. "which trigger?" .. R .. DIM .. "  /pdebug cues" .. R)
        return nil
    end
    local trigger = P.Registry:GetTrigger(triggerID)
    if not trigger then
        out(BAD .. "no such trigger: " .. R .. triggerID .. DIM .. "  /pdebug cues" .. R)
        return nil
    end
    return trigger
end

local commands = {}

function commands.help()
    out("Pulse's own state, read live. Not a second copy of the addon.")
    row("/pdebug state", "client CVars, the pad, and Pulse's gates")
    row("/pdebug layers", "every named layer currently blending into the channel")
    row("/pdebug channels", "smoothed vs. last-set value per physical channel")
    row("/pdebug cues [CATEGORY]", "every trigger, enabled or not")
    row("/pdebug why <triggerID>", "which gate is dropping this trigger")
    row("/pdebug fire <triggerID>", "play it through the real path, all gates apply")
    row("/pdebug hold <triggerID>", "hold a continuous trigger at 0.5/0.5 for 2s, real path")
    row("/pdebug raw <modeID>", "play a mode directly, past every trigger check")
    row("/pdebug watch <triggerID>", "log the trigger's registered events as they arrive")
    row("/pdebug watch off", "stop logging")
    row("/pdebug modes", "every mode id, discrete or continuous")
    row("/pdebug schema", "the active schema's role-to-channel map")
    row("/pdebug ui", "open the window: same readouts, with a live 10Hz refresh")
end

function commands.state(P)
    out(HEAD .. "— client —" .. R)
    row("GamePadEnable", string.format("%s%s", tostring(C_CVar.GetCVar("GamePadEnable")),
        DIM .. "   must be 1; default is 0" .. R))
    row("GamePadVibrationStrength", tostring(C_CVar.GetCVar("GamePadVibrationStrength")))

    out(HEAD .. "— device —" .. R)
    row("C_GamePad.IsEnabled()", boolCell(readBool(C_GamePad.IsEnabled())))
    local deviceID = C_GamePad.GetActiveDeviceID()
    row("active device id", issecretvalue(deviceID) and (WARN .. "secret" .. R) or tostring(deviceID))
    local level = C_GamePad.GetPowerLevel()
    row("power level", issecretvalue(level) and (WARN .. "secret" .. R) or tostring(level))
    row("Pulse sees a pad", flag(P.Engine:IsDeviceReady()))

    out(HEAD .. "— pulse —" .. R)
    row("masterEnabled", flag(P.Database:Get("masterEnabled")))
    row("profile", tostring(P.Database:GetActiveProfileName())
        .. DIM .. "  (masterIntensity/triggers/triggerSettings are per-profile)" .. R)
    row("masterIntensity", tostring(P.Database:Get("masterIntensity")))
    row("schema", tostring(P.Database:Get("defaultHapticSchema")))

    local total, enabled = 0, 0
    for _, category in ipairs(P.Registry:GetCategories()) do
        for _, trigger in ipairs(P.Registry:GetTriggersByCategory(category)) do
            total = total + 1
            if P.Database:GetCue(trigger.id) then enabled = enabled + 1 end
        end
    end
    row("triggers enabled", string.format("%d of %d", enabled, total))
    row("active layers right now", tostring(#P.Engine:_DebugLayers()))
end

function commands.layers(P)
    local layers = P.Engine:_DebugLayers()
    if #layers == 0 then
        out(DIM .. "nothing blending into the channel right now." .. R)
        return
    end
    -- Four roles since 2026-09-21, not two. A layer may drive ltrigger/rtrigger and
    -- nothing else (Modules/Locomotion.lua's split footfalls do exactly that), which the
    -- old two-column view could not show — and printing a nil through %.2f would have
    -- errored rather than displaying blank.
    local function cell(value)
        if value == nil then return DIM .. "  -  " .. R end
        return string.format("%-5.2f", value)
    end
    out(HEAD .. string.format("%-22s %-6s %-6s %-6s %-6s %s",
        "layer", "low", "high", "ltrig", "rtrig", "remaining") .. R)
    for _, layer in ipairs(layers) do
        out(string.format("  %-20s %s %s %s %s %.2fs",
            layer.name, cell(layer.low), cell(layer.high),
            cell(layer.ltrigger), cell(layer.rtrigger),
            math.max(layer.remaining, 0)))
    end
end

function commands.channels(P)
    local channels = P.Engine:_DebugChannels()
    if not next(channels) then
        out(DIM .. "no channel has been driven yet this session." .. R)
        return
    end
    out(HEAD .. string.format("%-14s %-10s %s", "channel", "smoothed", "last set") .. R)
    for channel, info in pairs(channels) do
        out(string.format("  %-12s %-10.2f %s",
            channel, info.smoothed or 0, tostring(info.lastSet)))
    end
end

function commands.cues(P, arg)
    local filter = (arg ~= "") and string.upper(arg) or nil
    local shown = false
    for _, category in ipairs(P.Registry:GetCategories()) do
        if not filter or category == filter or category:find(filter, 1, true) then
            shown = true
            out(HEAD .. P.Registry:GetCategoryLabel(category) .. R)
            for _, trigger in ipairs(P.Registry:GetTriggersByCategory(category)) do
                local shape = trigger.continuous and "continuous" or tostring(trigger.mode)
                out(string.format("  %s %-22s %-12s %s",
                    P.Database:GetCue(trigger.id) and (GOOD .. "on " .. R) or (DIM .. "off" .. R),
                    trigger.id, shape,
                    DIM .. "throttle " .. tostring(trigger.throttle or 0) .. R))
                -- Live tunable values (Registry.lua's `tunables`, e.g. continuous.md's
                -- devTuning sliders or lowHealthWarning's pre-existing heartRate) — was a
                -- gap before tonight, /pdebug had no way to see these without opening the
                -- settings panel.
                if trigger.tunables then
                    for _, tunable in ipairs(trigger.tunables) do
                        local value = P.Database:GetTriggerSetting(trigger.id, tunable.key, tunable.default)
                        out(string.format("      %s%-22s%s %.2f",
                            DIM, tunable.key, R, value))
                    end
                end
            end
        end
    end
    if not shown then
        out(BAD .. "no such category: " .. R .. arg .. DIM .. "  try a partial match, e.g. \"alert\"" .. R)
    end
end

-- Three gates, same shape as TremorDebug's why but shorter: Pulse has no arbitration or
-- combat/instance suppression to check, since layers blend instead of competing.
function commands.why(P, arg)
    local trigger = findTrigger(P, arg)
    if not trigger then return end

    out(string.format("%s%s%s  %s", HEAD, trigger.id, R, trigger.label or ""))

    local blocked = false
    local function gate(passed, label)
        if passed then
            row(GOOD .. "pass " .. R .. label, "")
        else
            blocked = true
            row(BAD .. "BLOCK" .. R .. " " .. label, "")
        end
    end

    gate(P.Database:Get("masterEnabled") and true or false, "masterEnabled")
    gate(P.Database:GetCue(trigger.id) and true or false, "cue enabled")
    -- ALERT_CC triggers (the only category with one, since ALERT_EXPERIMENTAL's
    -- experimentalMaster was removed the same day this check was added) have a second
    -- gate above their own cue toggle — a category master (Registry.ALERT_CATEGORY_MASTER)
    -- the underlying module checks before ever registering an event. This was a real blind
    -- spot until 2026-09-16: every gate above could pass while this one silently blocked
    -- it, and this command had no way to say so.
    local masterTriggerID = P.Registry.ALERT_CATEGORY_MASTER and P.Registry.ALERT_CATEGORY_MASTER[trigger.category]
    if masterTriggerID and masterTriggerID ~= trigger.id then
        gate(P.Database:GetCue(masterTriggerID) and true or false,
            masterTriggerID .. " (category master)")
    end
    gate(P.Engine:IsDeviceReady(), "device ready")
    if trigger.continuous then
        row(DIM .. "n/a  " .. R .. " mode", DIM .. "continuous — driven by Hold(), not a single PlayMode call" .. R)
    else
        gate(trigger.mode ~= nil, "has a mode")
    end

    row(DIM .. "?    " .. R .. " throttle",
        string.format("%ss min gap%s", tostring(trigger.throttle or 0),
            DIM .. " — last-fire time is private" .. R))

    if blocked then
        out(BAD .. "would be dropped." .. R .. " Clear the BLOCK rows above.")
    else
        out(GOOD .. "no visible gate blocks it." .. R .. DIM ..
            "  Still nothing felt? Check /pdebug layers right after firing it." .. R)
    end
end

function commands.fire(P, arg)
    local trigger = findTrigger(P, arg)
    if not trigger then return end
    if trigger.continuous then
        out(WARN .. trigger.id .. " is continuous." .. R .. DIM .. "  Use /pdebug hold instead." .. R)
        return
    end
    out(string.format("FireIfEnabled(%s)%s", trigger.id, DIM .. "  — the real path, every gate applies" .. R))
    P:FireIfEnabled(trigger.id)
end

function commands.hold(P, arg)
    local trigger = findTrigger(P, arg)
    if not trigger then return end
    if not trigger.continuous then
        out(WARN .. trigger.id .. " is discrete, not continuous." .. R .. DIM .. "  Use /pdebug fire instead." .. R)
        return
    end
    out(string.format("HoldIfEnabled(%s, 0.5, 0.5)%s", trigger.id,
        DIM .. "  — one 2s hold, real path, every gate applies" .. R))
    local ticks = 0
    local ticker
    ticker = C_Timer.NewTicker(0.3, function()
        ticks = ticks + 1
        P:HoldIfEnabled(trigger.id, 0.5, 0.5)
        if ticks >= 7 then ticker:Cancel() end
    end)
end

-- Straight to Pulse:TestMode — the same entry point the panel's button and /pulse test
-- use, bypassing masterEnabled and every trigger's own enabled/throttle check, but still
-- needing a live pad.
function commands.raw(P, arg)
    if arg == "" then
        out(BAD .. "which mode?" .. R .. DIM .. "  /pdebug modes" .. R)
        return
    end
    local modeID = string.upper(arg)
    local ok, reason = P:TestMode(modeID)
    if not ok then
        out(BAD .. reason .. R .. DIM .. "  /pdebug modes" .. R)
        return
    end
    out(string.format("%s%s", modeID, DIM .. "  — arbitration and throttle bypassed" .. R))
end

function commands.modes(P)
    for _, modeID in ipairs(P.ModeOrder) do
        local mode = P.Modes[modeID]
        row("  " .. modeID, (mode.continuous and (WARN .. "continuous" .. R) or "discrete")
            .. "  " .. (mode.label or ""))
    end
end

function commands.schema(P)
    if type(P.Engine._ActiveSchema) ~= "function" then
        out(BAD .. "Engine._ActiveSchema not found." .. R)
        return
    end
    local schema = P.Engine:_ActiveSchema()
    if not schema then
        out(BAD .. "no active schema." .. R)
        return
    end
    out(string.format("%s%s%s  %s", HEAD, tostring(schema.id), R, schema.label or ""))
    for role, def in pairs(schema.roles or {}) do
        row("  " .. role, string.format("%s @ %.2f",
            def.channel or (DIM .. "silent" .. R), def.intensity or 1.0))
    end
end

-- The window lives in UI.lua. Resolved through _G at call time rather than at load, so
-- this works whichever order the two files end up in.
function commands.ui()
    local ui = _G.PulseDebugUI
    if not ui then
        out(BAD .. "UI.lua is not loaded." .. R .. DIM .. "  Check PulseDebug.toc lists it." .. R)
        return
    end
    ui.Toggle()
end

local watchFrame = CreateFrame("Frame")
local watching

watchFrame:SetScript("OnEvent", function(_, event)
    out(string.format("%s%.1f%s  %s  %s", DIM, GetTime(), R, event,
        DIM .. "(" .. tostring(watching) .. ")" .. R))
end)

function commands.watch(P, arg)
    if arg == "" or string.lower(arg) == "off" then
        watchFrame:UnregisterAllEvents()
        watching = nil
        out("watch cleared.")
        return
    end
    local trigger = findTrigger(P, arg)
    if not trigger then return end
    if not trigger.events or #trigger.events == 0 then
        out(WARN .. trigger.id .. " has no registered-events entry in the registry." .. R
            .. DIM .. "  Native triggers (Movement/Flight/Combat/Environment/Health) mostly " ..
               "poll or hook rather than register plain events, so this only works for " ..
               "Accessibility triggers and this addon's own World-category ones." .. R)
        return
    end
    watchFrame:UnregisterAllEvents()
    watching = trigger.id
    for _, event in ipairs(trigger.events) do
        if trigger.unit then
            watchFrame:RegisterUnitEvent(event, trigger.unit)
        else
            watchFrame:RegisterEvent(event)
        end
    end
    out(string.format("watching %s%s%s  %s", HEAD, trigger.id, R,
        DIM .. table.concat(trigger.events, ", ") .. R))
end

SLASH_PULSEDEBUG1 = "/pdebug"
SLASH_PULSEDEBUG2 = "/pd"
SlashCmdList["PULSEDEBUG"] = function(message)
    local input = strtrim(message or "")
    local command, rest = string.match(input, "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    rest = strtrim(rest or "")

    if command == "" or command == "help" then
        commands.help()
        return
    end

    local handler = commands[command]
    if not handler then
        out(BAD .. "unknown command: " .. R .. command)
        commands.help()
        return
    end

    local P = core()
    if not P then return end
    handler(P, rest)
end
