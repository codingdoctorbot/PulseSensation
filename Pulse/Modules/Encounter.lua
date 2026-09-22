-- Pulse — Modules/Encounter.lua
--
-- Boss ability warnings via Blizzard's built-in Boss Warnings timeline (C_EncounterEvents):
-- pre-scripted encounter metadata rather than real-time combat data, which is why Secret
-- Values does not block it. This is boss-timer functionality in plain terms, kept
-- experimental and off by default rather than treated as a settled accessibility cue.
--
-- NOT LIVE-VERIFIED: the exact field names on a returned EncounterEventInfo entry, and
-- whether GetEventsForEncounter behaves as documented. pcall-wrapped throughout, so a wrong
-- assumption degrades to "warns about nothing" (RULE E) rather than erroring.
--
-- bossChatWarning is the sister cue: a text-channel fallback (CHAT_MSG_RAID_WARNING /
-- MONSTER_YELL / MONSTER_EMOTE / MONSTER_WHISPER) depending on no C_EncounterEvents at all,
-- so it works anywhere bossAbilityWarning's native-HUD data might not exist. Deliberately
-- occurrence-only rather than pattern-matched against ability text: identifying which
-- mechanic a line refers to means maintaining a wording database per boss, per tier, per
-- locale — DBM and BigWigs's day-to-day maintenance load. This says "a boss said something
-- during this fight", the same honest scope bossAbilityWarning already accepts.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Encounter", M)

local bossTimers = {}   -- live C_Timer handles, cancelled wholesale on ENCOUNTER_END
local inEncounter = false

local function clearBossTimers()
    for _, timer in ipairs(bossTimers) do
        timer:Cancel()
    end
    wipe(bossTimers)
end

local function scheduleEncounter(encounterID)
    clearBossTimers()
    if not C_EncounterEvents or type(C_EncounterEvents.HasEventsForEncounter) ~= "function" then return end
    local ok, has = pcall(C_EncounterEvents.HasEventsForEncounter, encounterID)
    if not ok or not has then return end
    local ok2, events = pcall(C_EncounterEvents.GetEventsForEncounter, encounterID)
    if not ok2 or type(events) ~= "table" then return end

    local warningLead = Pulse.Database:GetTriggerSetting("bossAbilityWarning", "warningLead", 2.0)
    local minSeverity = Pulse.Database:GetTriggerSetting("bossAbilityWarning", "minSeverity", 2)

    for _, evt in ipairs(events) do
        -- Guard the whole entry before touching fields, even though nothing here is
        -- expected to be secret — pre-computed metadata is the premise this cue rests on.
        if not issecretvalue(evt) then
            local severity, timeOffset = evt.severityLevel, evt.timeOffset
            if not issecretvalue(severity) and not issecretvalue(timeOffset)
               and severity and timeOffset and severity >= minSeverity then
                local fireAt = timeOffset - warningLead
                if fireAt > 0 then
                    bossTimers[#bossTimers + 1] = C_Timer.NewTimer(fireAt, function()
                        Pulse:FireIfEnabled("bossAbilityWarning")
                    end)
                end
            end
        end
    end
end

local frame = CreateFrame("Frame")

-- Tracks inEncounter for bossChatWarning below too, so ENCOUNTER_START/END stay registered
-- whenever EITHER cue needs them, not just bossAbilityWarning.
local function sync()
    local enabled = Pulse.Database:Get("masterEnabled") and
        (Pulse.Database:GetCue("bossAbilityWarning") or Pulse.Database:GetCue("bossChatWarning"))

    if not enabled then
        frame:UnregisterAllEvents()
        clearBossTimers()
        inEncounter = false
        return
    end

    -- Reseed or preserve live inEncounter state if an encounter is already in progress,
    -- rather than blind-wiping on mid-fight cue toggles or profile switches.
    if IsEncounterInProgress and IsEncounterInProgress() then
        inEncounter = true
    end

    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
end

-- Not RULE-A-shaped the way target/focus watching is: ENCOUNTER_START/END describe the
-- encounter, not a restricted unit, and encounterID is CONFIRMED readable.
frame:SetScript("OnEvent", function(_, event, encounterID)
    if event == "ENCOUNTER_START" then
        inEncounter = true
        scheduleEncounter(encounterID)
    else
        inEncounter = false
        clearBossTimers()
    end
end)

-- bossChatWarning — see the file header. Occurrence-only: any of these four messages
-- arriving while inEncounter is true fires the cue, with no text parsing. KNOWN FALSE
-- POSITIVE: CHAT_MSG_RAID_WARNING can be a player using the raid-warning channel ("Pulling
-- in 5") rather than the boss. Documented rather than filtered, because telling a boss-sent
-- one from a player-sent one is not reliable.

local chatFrame = CreateFrame("Frame")

local function syncChatWarning()
    chatFrame:UnregisterAllEvents()
    if not Pulse.Database:Get("masterEnabled") then return end
    if not Pulse.Database:GetCue("bossChatWarning") then return end
    chatFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
    chatFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
    chatFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
    chatFrame:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
end

-- RULE A habit kept though these carry no restricted payload: no varargs read. The gate is
-- the shared inEncounter flag above, not anything off the event.
chatFrame:SetScript("OnEvent", function()
    if inEncounter then
        Pulse:FireIfEnabled("bossChatWarning")
    end
end)

function M:OnEnable()
    Pulse:BindFrame({ "bossAbilityWarning", "bossChatWarning" }, sync)
    Pulse:BindFrame({ "bossChatWarning" }, syncChatWarning)
end

-- Reach-in for PulseDebug, read-only
function M:_DebugEncounter()
    return {
        inEncounter = inEncounter,
        activeTimers = #bossTimers,
    }
end
