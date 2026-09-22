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
-- Merchant buy, sell, and repair tactile feedback:
-- - merchantBuy: spending money while in a merchant window.
-- - merchantSell: earning money while in a merchant window.
-- - merchantRepair: durability update while in a merchant window.
--
-- Vault closing latch:
-- - bankClosed: heavy latch thud when closing a bank, guild bank, or void storage vault.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Interaction", M)

local GENERIC_CUE = "interactionWindow"
local CLOSED_CUE = "interactionWindowClosed"

-- Read through Enum where the client defines it, with the confirmed literal as fallback —
-- the pattern Modules/Crafting.lua and Modules/Locomotion.lua use. Values CONFIRMED against
-- PlayerInteractionManagerConstantsDocumentation.lua.
local function interactionType(name, literal)
    local value = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType[name]
    if type(value) == "number" then
        return value
    end
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
map("merchantShow", { "Merchant", 5 }, { "Vendor", 12 })
map("bankOpened", { "Banker", 8 }, { "CharacterBanker", 67 }, { "AccountBanker", 68 })
map("mailShow", { "MailInfo", 17 })
map("trainerShow", { "Trainer", 7 })
map("taxiOpened", { "TaxiNode", 6 })
map("tradeSkillShow", { "Professions", 59 }, { "ProfessionsCraftingOrder", 58 }, { "ProfessionsCustomerOrder", 60 })
map("questDetail", { "QuestGiver", 4 })
map("tradeRequest", { "TradePartner", 1 })

-- New. The gaps.
map("guildBankOpened", { "GuildBanker", 10 }, { "VoidStorageBanker", 26 })
map("auctionHouseShow", { "Auctioneer", 21 }, { "BlackMarketAuctioneer", 27 })
map("gossipShow", { "Gossip", 3 })
map("spiritHealerShow", { "SpiritHealer", 18 }, { "AreaSpiritHealer", 19 })
map("stableShow", { "StableMaster", 22 }, { "PetUntrainer", 80 })
map("binderShow", { "Binder", 20 })

local BANK_INTERACTIONS = {
    [8] = true,
    [67] = true,
    [68] = true,
    [10] = true,
    [26] = true,
}

-- Every cue this module can fire, so sync knows whether to register at all.
local WATCHED = {
    GENERIC_CUE,
    CLOSED_CUE,
    "merchantBuy",
    "merchantSell",
    "merchantRepair",
    "bankClosed",
    "bankGold",
    "stackSplit",
}
do
    local seen = {}
    for _, cueID in ipairs(WATCHED) do
        seen[cueID] = true
    end
    for _, cueID in pairs(TYPE_CUE) do
        if not seen[cueID] then
            seen[cueID] = true
            WATCHED[#WATCHED + 1] = cueID
        end
    end
end

-- Events & State

local frame = CreateFrame("Frame")
local inMerchant = false
local inBank = false
local lastMerchantMoney = 0
local lastBankMoney = 0
local wasRepair = false

local function onShow(interaction)
    if type(interaction) ~= "number" then
        return
    end

    if interaction == 5 or interaction == 12 then
        inMerchant = true
        local money = (GetMoney and GetMoney()) or 0
        lastMerchantMoney = (not issecretvalue(money) and type(money) == "number") and money or 0
        wasRepair = false
    elseif BANK_INTERACTIONS[interaction] then
        inBank = true
        local money = (GetMoney and GetMoney()) or 0
        lastBankMoney = (not issecretvalue(money) and type(money) == "number") and money or 0
    end

    local cueID = TYPE_CUE[interaction] or GENERIC_CUE

    if Pulse.debug then
        print(
            ("Pulse: interaction window %d -> %s%s"):format(
                interaction,
                cueID,
                TYPE_CUE[interaction] and "" or " (unmapped, generic)"
            )
        )
    end

    Pulse:FireIfEnabled(cueID)
end

local function onHide(interaction)
    if Pulse.debug and type(interaction) == "number" then
        print(("Pulse: interaction window %d closed"):format(interaction))
    end

    if type(interaction) == "number" then
        if interaction == 5 or interaction == 12 then
            inMerchant = false
            wasRepair = false
        elseif BANK_INTERACTIONS[interaction] then
            inBank = false
            Pulse:FireIfEnabled("bankClosed")
        end
    end

    Pulse:FireIfEnabled(CLOSED_CUE)
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        onShow(arg1)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        onHide(arg1)
    elseif event == "MERCHANT_SHOW" then
        inMerchant = true
        lastMerchantMoney = (GetMoney and GetMoney()) or 0
        wasRepair = false
    elseif event == "MERCHANT_CLOSED" then
        inMerchant = false
        wasRepair = false
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        if inMerchant then
            wasRepair = true
            Pulse:FireIfEnabled("merchantRepair")
        end
    elseif event == "PLAYER_MONEY" then
        if inMerchant then
            local current = (GetMoney and GetMoney()) or 0
            if not issecretvalue(current) and type(current) == "number" then
                local delta = current - lastMerchantMoney
                lastMerchantMoney = current
                if wasRepair then
                    wasRepair = false
                elseif delta > 0 then
                    Pulse:FireIfEnabled("merchantSell")
                elseif delta < 0 then
                    Pulse:FireIfEnabled("merchantBuy")
                end
            end
        elseif inBank then
            local current = (GetMoney and GetMoney()) or 0
            if not issecretvalue(current) and type(current) == "number" then
                local delta = current - lastBankMoney
                lastBankMoney = current
                if delta ~= 0 then
                    Pulse:FireIfEnabled("bankGold")
                end
            end
        end
    elseif event == "BANKFRAME_OPENED" or event == "GUILDBANKFRAME_OPENED" then
        inBank = true
        local money = (GetMoney and GetMoney()) or 0
        lastBankMoney = (not issecretvalue(money) and type(money) == "number") and money or 0
    elseif event == "BANKFRAME_CLOSED" or event == "GUILDBANKFRAME_CLOSED" then
        inBank = false
        Pulse:FireIfEnabled("bankClosed")
    elseif event == "GUILDBANK_UPDATE_MONEY" then
        Pulse:FireIfEnabled("bankGold")
    end
end)

local function sync()
    frame:UnregisterAllEvents()
    inMerchant = false
    inBank = false
    wasRepair = false
    if not Pulse.Database:Get("masterEnabled") then
        return
    end

    local any = false
    for _, cueID in ipairs(WATCHED) do
        if Pulse.Database:GetCue(cueID) then
            any = true
            break
        end
    end
    if not any then
        return
    end

    -- Interaction manager events
    pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

    -- Merchant physics
    local wantMerchantPhysics = Pulse.Database:GetCue("merchantBuy")
        or Pulse.Database:GetCue("merchantSell")
        or Pulse.Database:GetCue("merchantRepair")
    if wantMerchantPhysics then
        pcall(frame.RegisterEvent, frame, "MERCHANT_SHOW")
        pcall(frame.RegisterEvent, frame, "MERCHANT_CLOSED")
        pcall(frame.RegisterEvent, frame, "PLAYER_MONEY")
        pcall(frame.RegisterEvent, frame, "UPDATE_INVENTORY_DURABILITY")
    end

    -- Bank close latch & gold transfers
    local wantBank = Pulse.Database:GetCue("bankClosed") or Pulse.Database:GetCue("bankGold")
    if wantBank then
        pcall(frame.RegisterEvent, frame, "BANKFRAME_OPENED")
        pcall(frame.RegisterEvent, frame, "BANKFRAME_CLOSED")
        pcall(frame.RegisterEvent, frame, "GUILDBANKFRAME_OPENED")
        pcall(frame.RegisterEvent, frame, "GUILDBANKFRAME_CLOSED")
    end
    if Pulse.Database:GetCue("bankGold") then
        pcall(frame.RegisterEvent, frame, "PLAYER_MONEY")
        pcall(frame.RegisterEvent, frame, "GUILDBANK_UPDATE_MONEY")
    end
end

function M:OnEnable()
    Pulse:BindFrame(WATCHED, sync)
    if StackSplitFrame and type(StackSplitFrame.UpdateStackText) == "function" then
        hooksecurefunc(StackSplitFrame, "UpdateStackText", function()
            Pulse:FireIfEnabled("stackSplit")
        end)
    end
end

-- Reach-in for PulseDebug, read-only.
function M:_DebugInteraction()
    local mapped = 0
    for _ in pairs(TYPE_CUE) do
        mapped = mapped + 1
    end
    return {
        mappedTypes = mapped,
        watchedCues = #WATCHED,
        inMerchant = inMerchant,
        inBank = inBank,
        wasRepair = wasRepair,
    }
end
