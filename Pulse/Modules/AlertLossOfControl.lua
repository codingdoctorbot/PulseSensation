-- Pulse — Modules/AlertLossOfControl.lua
--
-- Accessibility cue, imported near-verbatim from Tremor/Modules/LossOfControl.lua.
-- SecretWhenLossOfControlInfoRestricted produces secrets only when the subject unit is not
-- the active player, so loss of control on YOU is fully readable, locType included. Still
-- RULE B guarded: the predicate is narrowly worded and a patch could widen it.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertLossOfControl", M)

-- VERIFY IN-GAME: check this key set against `/dump Enum.LossOfControlType` on the live
-- client — never run, there or in Tremor. An unrecognised type falls back to ccMaster's
-- generic cue rather than being dropped, so an incomplete list degrades quietly.
local TYPE_TO_CUE = {
    STUN = "ccStun", STUN_MECHANIC = "ccStun",
    FEAR = "ccFear", FEAR_MECHANIC = "ccFear", CHARM = "ccFear",
    SILENCE = "ccSilence",
    ROOT = "ccRoot",
    DISARM = "ccDisarm",
    PACIFY = "ccPacify", PACIFYSILENCE = "ccPacify", SCHOOL_INTERRUPT = "ccPacify",
    CONFUSE = "ccConfuse", POSSESS = "ccConfuse",
}

-- The set of locTypes active as of the previous event, so a still-active effect is not
-- re-announced every time something else about the loss-of-control state changes.
local announced = {}

function M:OnEnable()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        announced = {}
        if not Pulse.Database:Get("masterEnabled") then return end
        if not Pulse.Database:GetCue("ccMaster") then return end
        frame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
        frame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
    end

    frame:SetScript("OnEvent", function()
        M:_OnLossOfControl()
    end)

    Pulse:BindFrame({ "ccMaster" }, sync)
end

function M:_OnLossOfControl()
    local count = C_LossOfControl.GetActiveLossOfControlDataCount()
    if issecretvalue(count) then return end
    if not count then return end

    local active = {}
    for index = 1, count do
        local data = C_LossOfControl.GetActiveLossOfControlData(index)
        if issecretvalue(data) then return end
        if data then
            local locType = data.locType
            if issecretvalue(locType) then return end

            active[locType] = true
            if not announced[locType] then
                Pulse:FireIfEnabled(TYPE_TO_CUE[locType] or "ccMaster")
            end
        end
    end

    announced = active
end
