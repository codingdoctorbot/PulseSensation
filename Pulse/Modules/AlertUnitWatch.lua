-- Pulse — Modules/AlertUnitWatch.lua
--
-- Accessibility cue, imported near-verbatim from Tremor/Modules/UnitWatch.lua. The most
-- constrained module in the import: every handler is occurrence-only, because the spellcast
-- payload for a non-player unit is secret up to and including arg1's unit token. One frame
-- per unit token, frame identity is the filter, never a branch on arg1.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertUnitWatch", M)

function M:OnEnable()
    self:_WatchUnit("target", "targetCastStart", "targetChannelStart")
    self:_WatchUnit("focus",  "focusCastStart",  "focusChannelStart")
    self:_WatchSwaps()
end

function M:_WatchUnit(unit, startCue, channelCue)
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then return end
        if Pulse.Database:GetCue(startCue) then
            frame:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
        end
        if Pulse.Database:GetCue(channelCue) then
            frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
        end
    end

    frame:SetScript("OnEvent", function(_, event)
        if event == "UNIT_SPELLCAST_START" then
            Pulse:FireIfEnabled(startCue)
        else
            Pulse:FireIfEnabled(channelCue)
        end
    end)

    Pulse:BindFrame({ startCue, channelCue }, sync)
end

function M:_WatchSwaps()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then return end
        if Pulse.Database:GetCue("targetChanged")
            or Pulse.Database:GetCue("targetCastStart")
            or Pulse.Database:GetCue("targetChannelStart") then
            frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        end
        if Pulse.Database:GetCue("focusChanged")
            or Pulse.Database:GetCue("focusCastStart")
            or Pulse.Database:GetCue("focusChannelStart") then
            frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        end
    end

    frame:SetScript("OnEvent", function(_, event)
        M:_OnSwap(event)
    end)

    Pulse:BindFrame({ "targetChanged", "focusChanged",
                      "targetCastStart", "focusCastStart",
                      "targetChannelStart", "focusChannelStart" }, sync)
end

-- Legal truthiness test only: the first return of UnitCastingInfo/UnitChannelInfo is a name
-- string or nil, and truthiness on a non-boolean secret is permitted. Do not extend it to
-- any other return. Resolving the target/focus collision via UnitIsUnit is illegal — a
-- secret boolean with no legal inspection path — so a duplicate fire when focus == target
-- is left to the blended engine to collapse.
function M:_OnSwap(event)
    local isTarget   = (event == "PLAYER_TARGET_CHANGED")
    local unit       = isTarget and "target" or "focus"
    local castCue    = isTarget and "targetCastStart"    or "focusCastStart"
    local channelCue = isTarget and "targetChannelStart" or "focusChannelStart"
    local changedCue = isTarget and "targetChanged"      or "focusChanged"

    if Pulse.Database:GetCue(castCue) and UnitCastingInfo(unit) then
        Pulse:FireIfEnabled(castCue)
        return
    end

    if Pulse.Database:GetCue(channelCue) and UnitChannelInfo(unit) then
        Pulse:FireIfEnabled(channelCue)
        return
    end

    Pulse:FireIfEnabled(changedCue)
end
