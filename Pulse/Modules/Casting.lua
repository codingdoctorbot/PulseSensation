-- Pulse — Modules/Casting.lua
--
-- Thin consumer of Core/CastActivity.lua. Everything it does is turn a classification
-- string into a cue id; the classification work itself lives in the core service, and the
-- decision about what a cue feels like lives in Core/Registry.lua.
--
-- Only NEW cues are wired here. The existing cast cues — selfCastStart, selfCastSucceeded,
-- selfChannelStart and the rest — still come from their watchers in
-- Modules/AlertGeneric.lua and Modules/Combat.lua, untouched, so nothing double-fires. This
-- adds the two things those watchers cannot express:
--
--   the crafting arc    a craft is a small ritual with a beginning, a duration and an
--                       outcome, which is the shape haptics are good at.
--   instant vs. cast    UNIT_SPELLCAST_SUCCEEDED fires identically for an instant ability
--                       and a three-second cast finishing, which is why selfCastSucceeded
--                       reads as indiscriminate. CastActivity tells them apart, and
--                       selfCastInstant is the previously unreachable half.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Casting", M)

local CUES = { "craftStart", "craftComplete", "craftStopped", "selfCastInstant" }

-- One classification -> one cue. Anything CastActivity emits that is not in here is
-- ignored rather than guessed at — the other classifications are already covered by the
-- original watchers, and firing them from two places would double every pulse.
local CUE_FOR_CLASSIFICATION = {
    CRAFT_START    = "craftStart",
    CRAFT_COMPLETE = "craftComplete",
    CRAFT_STOPPED  = "craftStopped",
    INSTANT        = "selfCastInstant",
}

local function onActivity(result)
    local cueID = CUE_FOR_CLASSIFICATION[result.classification]
    if not cueID then return end
    Pulse:FireIfEnabled(cueID)
end

local function sync()
    local wanted = Pulse.Database:Get("masterEnabled") or false
    if wanted then
        local any = false
        for _, cueID in ipairs(CUES) do
            if Pulse.Database:GetCue(cueID) then any = true end
        end
        wanted = any
    end
    -- CastActivity registers nothing while no cue here wants it, so a player with all four
    -- switched off pays nothing for this module existing.
    Pulse.CastActivity:SetActive(wanted)
end

function M:OnEnable()
    Pulse.CastActivity:OnActivity(onActivity)
    Pulse:BindFrame(CUES, sync)
end
