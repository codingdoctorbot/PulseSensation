-- Pulse — Modules/AlertGeneric.lua
--
-- Accessibility cues ported from Tremor/Modules/SelfCast.lua and Tremor/Modules/State.lua.
-- Both used the same generic category-watch pattern for every row, so nothing beyond the
-- registration is needed here. Exception: selfCastFailed, see _WatchCastFailed below.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertGeneric", M)

-- BUG: UNIT_SPELLCAST_FAILED_QUIET false positives.
--
-- 1) Dead/ghost auto-attack retries:
--    WoW silently retries the last active Attack/Auto Shot/Shoot roughly every
--    weapon-swing interval. These failed attempts fire UNIT_SPELLCAST_FAILED_QUIET
--    while dead or ghosted, causing an unwanted ~2–3s haptic cadence.
--    Handle this separately from the generic WatchCategory pass.
--
-- 2) Touch of Death Notification:
--    SpellIDs 121125 and 1221044 are hidden, self-targeted server-side
--    "Touch of Death Notification" events, not player casts. They can fire
--    repeatedly in and out of combat. Filter these explicitly by spellID.
--
-- Both causes CONFIRMED from live testing. The spellID filter is reliable because
-- UNIT_SPELLCAST_FAILED/_QUIET carry the spellID, though no reason code.

local IGNORED_SPELL_IDS = { [121125] = true, [1221044] = true }

-- actionFailed is handled by _WatchActionFailed in AlertExperimental.lua, which filters
-- LE_GAME_ERR_ATTACK_DEAD. Excluded from this generic pass, which inspects no payloads —
-- including it would bypass that filter, double-register the watcher and reintroduce
-- dead-state spam.

local CUSTOM = { selfCastFailed = true, selfChannelInterrupted = true, actionFailed = true }

function M:OnEnable()
    Pulse:WatchCategory("ALERT_SELF_CAST", CUSTOM)
    Pulse:WatchCategory("ALERT_STATE")
    self:_WatchCastFailed()
    self:_WatchChannelInterrupted()
end

function M:_WatchCastFailed()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then return end
        if not Pulse.Database:GetCue("selfCastFailed") then return end
        frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
    end

    frame:SetScript("OnEvent", function(_, event, unitTarget, castGUID, spellID)
        if UnitIsDeadOrGhost("player") then return end
        if not issecretvalue(spellID) and IGNORED_SPELL_IDS[spellID] then return end
        Pulse:FireIfEnabled("selfCastFailed")
    end)

    Pulse:BindFrame({ "selfCastFailed" }, sync)
end

-- selfChannelInterrupted needs the event's 4th argument (interruptedBy) to tell "cut short"
-- from "ran to completion", so it cannot use the generic zero-inspection watcher.
function M:_WatchChannelInterrupted()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then return end
        if not Pulse.Database:GetCue("selfChannelInterrupted") then return end
        frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    end

    -- interruptedBy is nil when the channel ran to completion and a real GUID when it was
    -- cut short — CONFIRMED against Blizzard's CastingBarFrame.lua
    -- (`complete = interruptedBy == nil`). UNVERIFIED whether it comes back secret here;
    -- the RULE B guard below means it silently never fires rather than erroring if so.
    frame:SetScript("OnEvent", function(_, event, unitTarget, castGUID, spellID, interruptedBy)
        if issecretvalue(interruptedBy) then return end
        if interruptedBy == nil then return end
        Pulse:FireIfEnabled("selfChannelInterrupted")
    end)

    Pulse:BindFrame({ "selfChannelInterrupted" }, sync)
end
