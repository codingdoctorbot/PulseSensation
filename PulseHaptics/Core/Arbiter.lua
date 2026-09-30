-- Pulse — Core/Arbiter.lua
--
-- Cross-module cue arbitration: which cue speaks when one game action fires several.
--
-- Three mechanisms, all driven by data in Core/Registry.lua (Registry.EPISODES and the
-- per-trigger `bus` / `busPriority` fields), and none of them allocating per event:
--
--   1. Liveness. Is a cue actually audible right now — master switch, its own switch, its
--      gates, and a non-zero intensity? The owner rule below is only ever asked about a
--      cue that is live: a disabled owner must never silence the cue standing in for it.
--   2. Episodes. A vendor visit and a loot window. A yielder steps aside only while its
--      episode is open AND one of that episode's owners is live.
--   3. Buses. Cue families that chain inside a frame (one window closing as another opens)
--      share one engine layer. A lower-priority cue arriving inside the bus window after a
--      higher one is dropped; a higher one arriving after a lower one replaces it, because
--      Engine:PlayMode on the same layer name bumps that layer's token (Engine.lua:354-355).
--
-- Reads game state only. Calls no protected API, hooks nothing, writes no SavedVariables.

local ADDON_NAME, Pulse = ...

local Arbiter = {}
Pulse.Arbiter = Arbiter

-- ── Liveness ──────────────────────────────────────────────────────────────────

function Arbiter:IsLive(cueID)
	local db = Pulse.Database
	if not db:Get("masterEnabled") or not db:GetCue(cueID) then
		return false
	end
	if not Pulse:GatesOpen(cueID) then
		return false
	end
	local intensity = db:GetTriggerSetting(cueID, "intensity", 1.0)
	return type(intensity) == "number" and intensity > 0
end

local function anyLive(list)
	if not list then
		return false
	end
	for i = 1, #list do
		if Arbiter:IsLive(list[i]) then
			return true
		end
	end
	return false
end

local function firstLive(list)
	if not list then
		return false
	end
	for i = 1, #list do
		if Arbiter:IsLive(list[i]) then
			return list[i]
		end
	end
	return false
end

-- ── Vendor episode ────────────────────────────────────────────────────────────

-- Read through Enum where the client defines it, with the confirmed literal as fallback —
-- the same pattern as Modules/Interaction.lua:36-42.
local function interactionType(name, literal)
	local value = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType[name]
	if type(value) == "number" then
		return value
	end
	return literal
end
local PIM_MERCHANT = interactionType("Merchant", 5)
local PIM_VENDOR = interactionType("Vendor", 12)

local function interacting(kind)
	local pim = C_PlayerInteractionManager
	if not (pim and type(pim.IsInteractingWithNpcOfType) == "function") then
		return false
	end
	local value = pim.IsInteractingWithNpcOfType(kind)
	if issecretvalue(value) then
		return false
	end
	return value and true or false
end

-- The single source of truth for "a vendor is open". Interaction-manager state first:
-- bag and merchant replacement addons hide MerchantFrame, the interaction does not end.
function Arbiter:IsMerchantOpen()
	if interacting(PIM_MERCHANT) or interacting(PIM_VENDOR) then
		return true
	end
	return (MerchantFrame and MerchantFrame:IsShown()) and true or false
end

-- True while a vendor is open and something that speaks for a purchase is live.
function Arbiter:VendorOwnsIntake()
	local episode = Pulse.Registry.EPISODES.vendor
	return self:IsMerchantOpen() and anyLive(episode.owners)
end

-- ── Loot episode ──────────────────────────────────────────────────────────────

local LOOT_TAIL = 0.30 -- [measure, §11] last BAG_UPDATE_DELAYED may trail LOOT_CLOSED
local LOOT_STALE = 60 -- a missed LOOT_CLOSED can never pin the episode open
local COIN_CUE = "lootGold"

-- Quality -> intensity multiplier on the speaking cue. Starting values, tuned in game.
local QUALITY_GAIN = { [0] = 0.70, 0.85, 1.00, 1.15, 1.30, 1.45, 1.45, 1.30, 1.00 }
local QUEST_GAIN = 1.15

-- Scalars and three reused arrays: nothing allocated after the first episode.
local loot = {
	open = false,
	autoLoot = false,
	openedAt = 0,
	closedAt = -100,
	speaker = false,
	spoke = false,
	sawSlotCleared = false,
	best = -1,
	quest = false,
	items = 0,
	coins = 0,
}
local slotGain, slotIsCoin, slotLocked = {}, {}, {}

local function gainFor(quality, isQuest)
	local gain = QUALITY_GAIN[quality] or 1.0
	if isQuest and gain < QUEST_GAIN then
		gain = QUEST_GAIN
	end
	return gain
end

local function scan()
	wipe(slotGain)
	wipe(slotIsCoin)
	wipe(slotLocked)
	loot.best, loot.quest, loot.items, loot.coins = -1, false, 0, 0
	local n = GetNumLootItems and GetNumLootItems() or 0
	if issecretvalue(n) or type(n) ~= "number" then
		return
	end
	for slot = 1, n do
		local _, _, _, _, quality, locked, isQuestItem, _, _, isCoin = GetLootSlotInfo(slot)
		if issecretvalue(quality) or type(quality) ~= "number" then
			quality = 1
		end
		if issecretvalue(locked) then
			locked = true -- unknown ownership: treat as a roll item, never ours to announce
		end
		if issecretvalue(isQuestItem) then
			isQuestItem = false
		end
		if issecretvalue(isCoin) then
			isCoin = false
		end
		if isCoin == nil and GetLootSlotType then
			local kind = GetLootSlotType(slot)
			isCoin = (not issecretvalue(kind)) and kind == 2
		end
		slotLocked[slot] = locked and true or false
		slotIsCoin[slot] = isCoin and true or false
		slotGain[slot] = gainFor(quality, isQuestItem)
		if not locked then
			if isCoin then
				loot.coins = loot.coins + 1
			else
				loot.items = loot.items + 1
				if quality > loot.best then
					loot.best = quality
				end
				if isQuestItem then
					loot.quest = true
				end
			end
		end
	end
end

local function chooseSpeaker()
	if loot.items > 0 then
		local cue = firstLive(Pulse.Registry.EPISODES.loot.intake)
		if cue then
			return cue
		end
	end
	if loot.coins > 0 and Arbiter:IsLive(COIN_CUE) then
		return COIN_CUE
	end
	return false
end

local function lootLive()
	if loot.open then
		if (GetTime() - loot.openedAt) > LOOT_STALE then
			loot.open = false
			loot.closedAt = -100
			return false
		end
		return true
	end
	return (GetTime() - loot.closedAt) < LOOT_TAIL
end

-- LOOT_READY and LOOT_OPENED both land here; the first opens the episode, a second call
-- inside the same episode only rescans (autoloot can empty slots between the two).
function Arbiter:LootOpened(autoLoot)
	if not loot.open then
		loot.open = true
		loot.openedAt = GetTime()
		loot.spoke = false
		loot.sawSlotCleared = false
	end
	if not issecretvalue(autoLoot) then
		loot.autoLoot = autoLoot and true or false
	end
	scan()
	if loot.items + loot.coins > 0 or not loot.speaker then
		loot.speaker = chooseSpeaker()
	end
end

function Arbiter:LootClosed()
	if loot.open then
		loot.open = false
		loot.closedAt = GetTime()
	end
end

function Arbiter:LootReset()
	loot.open, loot.speaker, loot.spoke = false, false, false
	loot.closedAt = -100
end

-- Every intake handler (ITEM_PUSH, BAG_UPDATE_DELAYED gain, own CHAT_MSG_LOOT,
-- CHAT_MSG_MONEY) asks this first. true = "handled, do not fire your own cue".
function Arbiter:LootIntake()
	if not lootLive() or not loot.speaker then
		return false
	end
	if loot.autoLoot then
		if not loot.spoke then
			loot.spoke = true
			Pulse:FireIfEnabled(loot.speaker, gainFor(loot.best, loot.quest))
		end
		return true
	end
	-- Manual looting speaks per click from LootSlotCleared. Until the first click has been
	-- seen, intake falls through, so a client that never sends LOOT_SLOT_CLEARED is never
	-- silent.
	return loot.sawSlotCleared
end

-- LOOT_SLOT_CLEARED(slot). Manual looting: one cue per deliberate click, at that slot's
-- own quality. Autoloot: the first clear is simply the earliest intake.
function Arbiter:LootSlotCleared(slot)
	if not loot.open or not loot.speaker then
		return
	end
	if issecretvalue(slot) or type(slot) ~= "number" or slotLocked[slot] then
		return
	end
	if loot.autoLoot then
		self:LootIntake()
		return
	end
	loot.sawSlotCleared = true
	local cue = loot.speaker
	if slotIsCoin[slot] and self:IsLive(COIN_CUE) then
		cue = COIN_CUE
	end
	Pulse:FireIfEnabled(cue, slotGain[slot] or 1.0)
end

function Arbiter:_DebugLoot()
	return loot
end

-- ── Buses ─────────────────────────────────────────────────────────────────────

local DEFAULT_BUS_WINDOW = 0.15 -- [measure, §11]; covers ControllerUI's 20 Hz panel poll
local busTime, busPriority, busLayer = {}, {}, {}

-- Pre-seeded from the Registry once, so no key is ever created at event time.
function Arbiter:SeedBuses()
	for _, trigger in ipairs(Pulse.Triggers) do
		local bus = trigger.bus
		if bus and not busLayer[bus] then
			busTime[bus] = -100
			busPriority[bus] = -1
			busLayer[bus] = "bus:" .. bus
		end
	end
end

-- Returns ok, layerName. ok = false when a more important cue on the same bus spoke inside
-- the window. An unknown bus name degrades to "no bus" rather than erroring.
function Arbiter:ClaimBus(bus, priority, window, fallbackLayer)
	local layer = busLayer[bus]
	if not layer then
		return true, fallbackLayer
	end
	local now = GetTime()
	priority = priority or 0
	if (now - busTime[bus]) < (window or DEFAULT_BUS_WINDOW) and priority < busPriority[bus] then
		return false, nil
	end
	busTime[bus] = now
	busPriority[bus] = priority
	return true, layer
end

Arbiter:SeedBuses()
