-- Pulse — Modules/AlertThreat.lua
--
-- Accessibility cue, imported near-verbatim from Tremor/Modules/Threat.lua. Transition-
-- tracking state machine over UnitThreatSituation's 0-3 status, guarded per RULE B even
-- though the player/target query form is exempt from the threat-state predicate.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertThreat", M)

local WATCHED = { "threatRising", "threatAggro", "threatLost" }

-- -1 means "no reading yet", distinct from 0, so the first event of a pull cannot fire
-- threatLost.
local lastStatus = -1

function M:OnEnable()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        lastStatus = -1
        if not Pulse.Database:Get("masterEnabled") then return end
        local anyEnabled = false
        for _, triggerID in ipairs(WATCHED) do
            if Pulse.Database:GetCue(triggerID) then anyEnabled = true end
        end
        if not anyEnabled then return end
        frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end

    frame:SetScript("OnEvent", function(_, event)
        M:_OnEvent(event)
    end)

    Pulse:BindFrame(WATCHED, sync)
end

function M:_OnEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then
        lastStatus = -1
        return
    end

    local raw = UnitThreatSituation("player", "target")
    if issecretvalue(raw) then return end

    local status = raw or 0
    if status == lastStatus then return end

    if raw == nil then
        lastStatus = status
        return
    end

    if status == 1 and lastStatus < 1 then
        Pulse:FireIfEnabled("threatRising")
    elseif status >= 2 and lastStatus < 2 then
        Pulse:FireIfEnabled("threatAggro")
    elseif status < 2 and lastStatus >= 2 then
        Pulse:FireIfEnabled("threatLost")
    end

    lastStatus = status
end
