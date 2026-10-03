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
local issecretvalue = Pulse.issecret

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

-- Repair recognition (replaces the old `wasRepair` latch, which could swallow the next buy
-- or sell after a guild-funded repair, a durability update from equipping at a vendor, or
-- money arriving before durability). Every flag here expires; none can outlive its window.
local REPAIR_WINDOW = 2.0 -- [measure, §11] RepairAllItems() call -> server confirmation
local DEBIT_WINDOW = 1.0 -- [measure, §11] durability confirmation -> PLAYER_MONEY
local knownRepairCost = 0 -- GetRepairAllCost(), refreshed at open and on every durability update
local armedUntil = 0 -- set by the RepairAllItems post-hook
local armedGuild = false
local armedCost = 0
local debitCost = 0 -- copper a personal repair will take; -1 = unknown (cursor repair)
local debitUntil = 0
local repairFiredAt = -100
local cursorPaidAt = -100 -- a cursor repair's payment seen before its durability update

-- One-frame deferred close (window bus, Core/Arbiter.lua): a close is dropped when an
-- interaction SHOW arrives before the deferred close runs.
local showSerial = 0
local pendingCloseSerial = -1
local pendingBankClose = false

local function readRepairCost()
	if type(GetRepairAllCost) ~= "function" then
		return 0
	end
	local cost = GetRepairAllCost()
	if issecretvalue(cost) or type(cost) ~= "number" or cost < 0 then
		return 0
	end
	return cost
end

local function resetRepair()
	armedUntil, armedGuild, armedCost = 0, false, 0
	debitCost, debitUntil = 0, 0
	cursorPaidAt = -100
end

local function fireRepairOnce(now)
	if (now - repairFiredAt) < DEBIT_WINDOW then
		return
	end
	repairFiredAt = now
	Pulse:FireIfEnabled("merchantRepair")
end

-- hooksecurefunc post-hook: runs after RepairAllItems has sent its request, catches every
-- caller (Blizzard's button, auto-repair addons), taints nothing. `useGuildFunds` is the
-- argument Blizzard's guild-repair button passes (Vanilla/MerchantFrame.xml:318).
local function onRepairAllItems(useGuildFunds)
	if not inMerchant then
		return
	end
	local cost = knownRepairCost > 0 and knownRepairCost or readRepairCost()
	if cost <= 0 then
		return
	end
	armedUntil = GetTime() + REPAIR_WINDOW
	armedGuild = (useGuildFunds == true)
	armedCost = cost
end

local function flushDeferredClose()
	if pendingCloseSerial < 0 then
		return
	end
	local transition = (showSerial ~= pendingCloseSerial)
	local bank = pendingBankClose
	pendingCloseSerial, pendingBankClose = -1, false
	if transition then
		return -- a window opened before this frame ended: the close was part of a chain
	end
	if bank then
		Pulse:FireIfEnabled("bankClosed")
	end
	Pulse:FireIfEnabled(CLOSED_CUE)
end

local function deferClose(isBank)
	if pendingCloseSerial < 0 then
		pendingCloseSerial = showSerial
		C_Timer.After(0, flushDeferredClose) -- static function: no closure per close
	end
	if isBank then
		pendingBankClose = true
	end
end

local function openMerchant()
	inMerchant = true
	local money = (GetMoney and GetMoney()) or 0
	lastMerchantMoney = (not issecretvalue(money) and type(money) == "number") and money or 0
	knownRepairCost = readRepairCost()
	resetRepair()
end

local function onShow(interaction)
	if type(interaction) ~= "number" then
		return
	end

	showSerial = showSerial + 1
	if interaction == 5 or interaction == 12 then
		openMerchant()
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

	local isBank = false
	if type(interaction) == "number" then
		if interaction == 5 or interaction == 12 then
			inMerchant = false
			resetRepair()
		elseif BANK_INTERACTIONS[interaction] then
			inBank = false
			isBank = true
		end
	end

	deferClose(isBank)
end

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
		onShow(arg1)
	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
		onHide(arg1)
	elseif event == "MERCHANT_SHOW" then
		showSerial = showSerial + 1
		openMerchant()
	elseif event == "MERCHANT_CLOSED" then
		inMerchant = false
		resetRepair()
	elseif event == "UPDATE_INVENTORY_DURABILITY" then
		if inMerchant then
			local now = GetTime()
			local armed = now < armedUntil
			local cursor = (type(InRepairMode) == "function") and InRepairMode() and true or false
			if armed or cursor then
				-- Confirmed repair. Equipping gear at a vendor also sends this event, but
				-- without an armed RepairAllItems call or the repair cursor it is ignored:
				-- nothing fires and nothing latches.
				fireRepairOnce(now)
				if armed and not armedGuild then
					debitCost, debitUntil = armedCost, now + DEBIT_WINDOW
				elseif cursor and (now - cursorPaidAt) > DEBIT_WINDOW then
					debitCost, debitUntil = -1, now + DEBIT_WINDOW
				end
				armedUntil = 0
			end
			knownRepairCost = readRepairCost()
		end
	elseif event == "PLAYER_MONEY" then
		if inMerchant then
			local current = (GetMoney and GetMoney()) or 0
			if not issecretvalue(current) and type(current) == "number" then
				local delta = current - lastMerchantMoney
				lastMerchantMoney = current
				local now = GetTime()
				if delta < 0 and now < debitUntil and (debitCost < 0 or -delta == debitCost) then
					debitCost, debitUntil = 0, 0 -- the repair's own payment, already felt
				elseif delta < 0 and type(InRepairMode) == "function" and InRepairMode() then
					-- Repair cursor active: a debit now is a repair, never a purchase.
					fireRepairOnce(now)
					cursorPaidAt = now
				elseif delta < 0 and now < armedUntil and not armedGuild and -delta == armedCost then
					-- Money beat the durability update: this IS the repair.
					fireRepairOnce(now)
					armedUntil = 0
				elseif delta > 0 then
					Pulse:FireIfEnabled("merchantSell")
				elseif delta < 0 then
					Pulse.Arbiter:VendorOwnerSpoke()
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
		showSerial = showSerial + 1
		inBank = true
		local money = (GetMoney and GetMoney()) or 0
		lastBankMoney = (not issecretvalue(money) and type(money) == "number") and money or 0
	elseif event == "BANKFRAME_CLOSED" or event == "GUILDBANKFRAME_CLOSED" then
		inBank = false
		deferClose(true)
	elseif event == "GUILDBANK_UPDATE_MONEY" then
		Pulse:FireIfEnabled("bankGold")
	end
end)

local function sync()
	frame:UnregisterAllEvents()
	inMerchant = false
	inBank = false
	resetRepair()
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

	-- Reseed live open state if syncing while an interaction is already open
	if Pulse.Arbiter and Pulse.Arbiter.IsMerchantOpen and Pulse.Arbiter:IsMerchantOpen() then
		openMerchant()
	end
	if type(BankFrame) == "table" and BankFrame.IsShown and BankFrame:IsShown() then
		inBank = true
		local money = (GetMoney and GetMoney()) or 0
		lastBankMoney = (not issecretvalue(money) and type(money) == "number") and money or 0
	end
end

function M:OnEnable()
	Pulse:BindFrame(WATCHED, sync)
	if type(RepairAllItems) == "function" then
		hooksecurefunc("RepairAllItems", onRepairAllItems)
	end
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
		repairArmed = GetTime() < armedUntil,
		repairDebitPending = GetTime() < debitUntil,
		pendingClose = pendingCloseSerial >= 0,
	}
end
