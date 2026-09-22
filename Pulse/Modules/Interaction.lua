-- Pulse — Modules/Interaction.lua
--
-- Every NPC and world interaction window, through one event pair.
--
-- PLAYER_INTERACTION_MANAGER_FRAME_SHOW and _HIDE both carry a `type`, an
-- Enum.PlayerInteractionType with 81 values
-- (PlayerInteractionManagerConstantsDocumentation.lua:6-9). That one pair covers every
-- window an NPC or world object can open — guild bank, auctioneer, spirit healer, stable
-- master and seventy more — where Pulse previously had six, each on its own legacy event.
--
-- BOTH PATHS, ON PURPOSE. The six that already existed keep their declarative
-- `events = {...}` watchers in Core/Registry.lua, and this module ALSO maps their
-- interaction types to the same cue ids. Not a double-fire: Pulse:FireIfEnabled throttles
-- per cue id and every one of these carries throttle = 1.0, so whichever path arrives first
-- fires and the other is dropped milliseconds later.
--
-- So "does Forever route MERCHANT_SHOW, or the manager event, or both" never has to be
-- answered — it answers itself at runtime, the same either way. An exclusion list would
-- have needed the answer up front and been wrong half the time.
--
-- The cost, stated rather than buried: closing and reopening the same window inside a
-- second gives one pulse, not two. That was already true before this module existed.
--
-- NOT MAPPED: most of the 81. Garrisons, covenants, azerite, Chromie time, housing — retail
-- systems a classic-shaped roster never opens. They are neither listed nor excluded; they
-- fall through to `interactionWindow`, so anything unmapped still produces something and a
-- window type added to the client later is covered without an edit here.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Interaction", M)

local GENERIC_CUE = "interactionWindow"
local CLOSED_CUE  = "interactionWindowClosed"

-- Read through Enum where the client defines it, with the confirmed literal as fallback —
-- the pattern Modules/Crafting.lua and Modules/Locomotion.lua use. Values CONFIRMED against
-- PlayerInteractionManagerConstantsDocumentation.lua.
local function interactionType(name, literal)
    local value = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType[name]
    if type(value) == "number" then return value end
    return literal
end

-- interaction type -> cue id. Several types share a cue: a vendor is a merchant, and three
-- kinds of banker are all "a bank opened" as far as the hand is concerned.
local TYPE_CUE = {}

local function map(cueID, ...)
    for _, pair in ipairs({ ... }) do
        TYPE_CUE[interactionType(pair[1], pair[2])] = cueID
    end
end

-- Already had cues, already had legacy watchers. Mapped here so they fire on whichever
-- path this client actually uses.
map("merchantShow",   { "Merchant", 5 }, { "Vendor", 12 })
map("bankOpened",     { "Banker", 8 }, { "CharacterBanker", 67 }, { "AccountBanker", 68 })
map("mailShow",       { "MailInfo", 17 })
map("trainerShow",    { "Trainer", 7 })
map("taxiOpened",     { "TaxiNode", 6 })
map("tradeSkillShow", { "Professions", 59 },
                      { "ProfessionsCraftingOrder", 58 },
                      { "ProfessionsCustomerOrder", 60 })
map("questDetail",    { "QuestGiver", 4 })
map("tradeRequest",   { "TradePartner", 1 })

-- New. The gaps.
map("guildBankOpened",  { "GuildBanker", 10 }, { "VoidStorageBanker", 26 })
map("auctionHouseShow", { "Auctioneer", 21 }, { "BlackMarketAuctioneer", 27 })
map("gossipShow",       { "Gossip", 3 })
map("spiritHealerShow", { "SpiritHealer", 18 }, { "AreaSpiritHealer", 19 })
map("stableShow",       { "StableMaster", 22 }, { "PetUntrainer", 80 })
map("binderShow",       { "Binder", 20 })

-- Every cue this module can fire, so sync knows whether to register at all.
local WATCHED = { GENERIC_CUE, CLOSED_CUE }
do
    local seen = {}
    for _, cueID in pairs(TYPE_CUE) do
        if not seen[cueID] then
            seen[cueID] = true
            WATCHED[#WATCHED + 1] = cueID
        end
    end
end

-- Events

local frame = CreateFrame("Frame")

-- The debug line prints the RAW type for every interaction, mapped or not, which is the
-- point: the enum has 81 values and which of them actually fire on this client is an
-- observation nobody has made. One trip past a guild bank and an auctioneer with
-- /pulse debug on settles it, and the table above can then be corrected from evidence.
local function onShow(interaction)
    if type(interaction) ~= "number" then return end

    local cueID = TYPE_CUE[interaction] or GENERIC_CUE

    if Pulse.debug then
        print(("Pulse: interaction window %d -> %s%s"):format(
            interaction, cueID, TYPE_CUE[interaction] and "" or " (unmapped, generic)"))
    end

    Pulse:FireIfEnabled(cueID)
end

local function onHide(interaction)
    if Pulse.debug and type(interaction) == "number" then
        print(("Pulse: interaction window %d closed"):format(interaction))
    end
    Pulse:FireIfEnabled(CLOSED_CUE)
end

frame:SetScript("OnEvent", function(_, event, interaction)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        onShow(interaction)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        onHide(interaction)
    end
end)

local function sync()
    frame:UnregisterAllEvents()
    if not Pulse.Database:Get("masterEnabled") then return end

    local any = false
    for _, cueID in ipairs(WATCHED) do
        if Pulse.Database:GetCue(cueID) then any = true break end
    end
    if not any then return end

    -- Registered as a pair: splitting would cost more bookkeeping than it saves events.
    pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
end

function M:OnEnable()
    Pulse:BindFrame(WATCHED, sync)
end

-- Reach-in for PulseDebug, read-only.
function M:_DebugInteraction()
    local mapped = 0
    for _ in pairs(TYPE_CUE) do mapped = mapped + 1 end
    return { mappedTypes = mapped, watchedCues = #WATCHED }
end
