-- PulseChecklist/tests/arbitration-test.lua
--
-- Phase 1 arbitration: owner-aware vendor guard, loot episode, repair recognition,
-- durability worsening edge, window bus and deferred close. Drives the REAL Core/Init.lua
-- FireIfEnabled, Core/Registry.lua, Core/Arbiter.lua and the three modules through stubbed
-- events; only the Database and the Engine are fakes.

local ROOT = arg[1] or "PulseHaptics"

-- ── Stubs ─────────────────────────────────────────────────────────────────────

local now = 1000
function GetTime()
	return now
end

local timers = {}
C_Timer = {
	After = function(delay, fn)
		timers[#timers + 1] = { at = now + delay, fn = fn }
	end,
}
local function nextFrame(dt)
	now = now + (dt or 0.016)
	local due = timers
	timers = {}
	for _, t in ipairs(due) do
		if t.at <= now then
			t.fn()
		else
			timers[#timers + 1] = t
		end
	end
end

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end
function print() end

local frames = {}
function CreateFrame()
	local f = { events = {}, scripts = {} }
	function f:RegisterEvent(e)
		self.events[e] = true
	end
	function f:RegisterUnitEvent(e)
		self.events[e] = true
	end
	function f:UnregisterAllEvents()
		wipe(self.events)
	end
	function f:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function f:GetScript(name)
		return self.scripts[name]
	end
	frames[#frames + 1] = f
	return f
end
local function fire(event, ...)
	for _, f in ipairs(frames) do
		if f.events[event] and f.scripts.OnEvent then
			f.scripts.OnEvent(f, event, ...)
		end
	end
end

function hooksecurefunc(a, b, c)
	if type(a) == "string" then
		local orig = _G[a]
		_G[a] = function(...)
			orig(...)
			b(...)
		end
	else
		local orig = a[b]
		a[b] = function(...)
			orig(...)
			c(...)
		end
	end
end

-- Game state the tests move.
local freeSlots, merchantOpen, money, repairCost, repairMode = 20, false, 100000, 0, false
local alertStatus = {}
local lootSlots = {} -- { quality, locked, isQuest, isCoin }
C_Container = {
	CalculateTotalNumberOfFreeBagSlots = function()
		return freeSlots
	end,
}
C_PlayerInteractionManager = {
	IsInteractingWithNpcOfType = function(kind)
		return merchantOpen and (kind == 5 or kind == 12)
	end,
}
function GetMoney()
	return money
end
function GetRepairAllCost()
	return repairCost, repairCost > 0
end
function InRepairMode()
	return repairMode
end
function RepairAllItems() end
function GetInventoryAlertStatus(i)
	return alertStatus[i] or 0
end
function GetNumLootItems()
	return #lootSlots
end
function GetLootSlotInfo(slot)
	local s = lootSlots[slot]
	return nil, nil, 1, nil, s.quality, s.locked, s.isQuest, nil, nil, s.isCoin
end
function UnitGUID()
	return "Player-1"
end
function UnitName()
	return "Tester"
end

-- ── Fakes: Database and Engine ────────────────────────────────────────────────

local cues = {}
local syncs = {} -- every BindFrame sync, called on a profile change like the real notifier
local Pulse = { debug = false }
Pulse.Database = {
	Get = function(_, key)
		if key == "masterEnabled" then
			return true
		end
		return nil
	end,
	GetCue = function(_, id)
		return cues[id] and true or false
	end,
	GetTriggerSetting = function(_, _, _, default)
		return default
	end,
	GetTriggerMode = function()
		return nil
	end,
	OnCueChanged = function(_, _, cb)
		syncs[cb] = true
	end,
	OnGlobalChanged = function(_, _, cb)
		syncs[cb] = true
	end,
}
local plays = {}
Pulse.Engine = {
	PlayMode = function(_, layer, modeID, scale, override)
		plays[#plays + 1] = { layer = layer, mode = modeID, override = override }
	end,
}

for _, file in ipairs({ "Core/Init.lua", "Core/Registry.lua", "Core/Modes.lua", "Core/Arbiter.lua" }) do
	assert(loadfile(ROOT .. "/" .. file))("Pulse", Pulse)
end

-- Record what actually played, through the real FireIfEnabled.
local fired = {}
local realFire = Pulse.FireIfEnabled
Pulse.FireIfEnabled = function(self, id, override)
	local played = realFire(self, id, override)
	if played then
		fired[#fired + 1] = { id = id, override = override }
	end
	return played
end

for _, file in ipairs({ "Modules/Inventory.lua", "Modules/World.lua", "Modules/Interaction.lua" }) do
	assert(loadfile(ROOT .. "/" .. file))("Pulse", Pulse)
end

for _, name in ipairs({ "Inventory", "World", "Interaction" }) do
	Pulse.modules[name]:OnEnable()
end

local function setProfile(list)
	wipe(cues)
	-- Page switches default ON in every profile (Database:_SeedProfileTriggerDefaults).
	for _, trigger in ipairs(Pulse.Triggers) do
		if trigger.gate then
			cues[trigger.id] = true
		end
	end
	for _, id in ipairs(list) do
		cues[id] = true
	end
	for cb in pairs(syncs) do
		cb()
	end
end

local function count(id)
	local n = 0
	for _, f in ipairs(fired) do
		if f.id == id then
			n = n + 1
		end
	end
	return n
end
local function reset()
	wipe(fired)
	wipe(plays)
	now = now + 5 -- clear every throttle and bus window
end

local failures = 0
local function check(label, got, want)
	local ok = (got == want)
	if not ok then
		failures = failures + 1
	end
	io.write(("%-68s %-6s %s\n"):format(label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
end

-- Every scenario starts from 20 free slots, baselined by the modules' own sync.
local function fresh(list)
	merchantOpen, repairMode, freeSlots = false, false, 20
	setProfile(list)
	reset()
end

-- ── Vendor ────────────────────────────────────────────────────────────────────

fresh({ "bagItemAdded" }) -- Default profile shape: merchantBuy OFF
merchantOpen = true
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
freeSlots = 19
fire("BAG_UPDATE_DELAYED")
check("V1 Default: purchase still felt through bagItemAdded", count("bagItemAdded"), 1)

fresh({ "bagItemAdded", "merchantBuy" }) -- Immersion shape
merchantOpen = true
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
fire("MERCHANT_SHOW")
freeSlots = 19
fire("BAG_UPDATE_DELAYED") -- bag BEFORE money: order must not matter
money = money - 100
fire("PLAYER_MONEY")
check("V2 owner live: bagItemAdded yields", count("bagItemAdded"), 0)
check("V2 owner live: merchantBuy plays once", count("merchantBuy"), 1)

reset()
merchantOpen = false
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 5)
freeSlots = 18
fire("BAG_UPDATE_DELAYED")
check("V3 no vendor (bank withdrawal): bagItemAdded plays", count("bagItemAdded"), 1)

fresh({ "bagItemAdded", "itemObtained", "merchantBuy" })
merchantOpen = true
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
fire("MERCHANT_SHOW")
fire("ITEM_PUSH", 1, 0)
freeSlots = 19
fire("BAG_UPDATE_DELAYED")
-- Non-gold currency purchase: no PLAYER_MONEY
nextFrame(0.35)
check("V4 currency purchase felt through deferred intake", #fired, 1)

fresh({ "bagItemAdded", "itemObtained", "merchantBuy" })
merchantOpen = true
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
fire("MERCHANT_SHOW")
fire("ITEM_PUSH", 1, 0)
freeSlots = 19
fire("BAG_UPDATE_DELAYED")
money = money - 100
fire("PLAYER_MONEY")
nextFrame(0.35)
check("V5 gold purchase: exactly one cue (merchantBuy)", #fired, 1)
check("V5   merchantBuy was the speaker", fired[1] and fired[1].id, "merchantBuy")

-- ── Loot ──────────────────────────────────────────────────────────────────────

fresh({ "itemObtained", "bagItemAdded", "lootReceived", "lootGold", "lootOpened" })
lootSlots = { { quality = 2 }, { quality = 1 } }
fire("LOOT_READY", true)
fire("LOOT_OPENED", true, false)
fire("LOOT_SLOT_CLEARED", 1)
fire("ITEM_PUSH", 1, 0)
fire("CHAT_MSG_LOOT", "You receive loot", "Tester", "", "", "", "", 0, 0, "", 0, 1, "Player-1")
fire("LOOT_SLOT_CLEARED", 2)
fire("ITEM_PUSH", 1, 0)
freeSlots = 18
fire("BAG_UPDATE_DELAYED")
fire("LOOT_CLOSED")
check("L1 autoloot: itemObtained speaks exactly once", count("itemObtained"), 1)
check("L1   at the best quality's gain (Uncommon 1.00)", fired[1] and fired[1].override, 1.0)
check("L1   bagItemAdded stands down", count("bagItemAdded"), 0)
check("L1   lootReceived stands down", count("lootReceived"), 0)
nextFrame(0.1)
freeSlots = 17
fire("BAG_UPDATE_DELAYED")
check("L1   a bag settle inside the tail still stands down", count("bagItemAdded"), 0)
nextFrame(0.5)
freeSlots = 16
fire("BAG_UPDATE_DELAYED")
check("L1   after the tail, bag cues are back to normal", count("bagItemAdded"), 1)

fresh({ "bagItemAdded" }) -- Default: the only intake cue becomes the speaker
lootSlots = { { quality = 3 }, { quality = 1 } }
fire("LOOT_READY", true)
fire("LOOT_OPENED", true, false)
freeSlots = 19
fire("BAG_UPDATE_DELAYED")
now = now + 0.25 -- past bagItemAdded's own 0.2 s throttle, so only the episode can merge these
freeSlots = 18
fire("BAG_UPDATE_DELAYED")
fire("LOOT_CLOSED")
check("L2 Default autoloot: one bagItemAdded per corpse", count("bagItemAdded"), 1)

fresh({ "itemObtained", "lootGold" })
lootSlots = { { quality = 0, isCoin = true }, { quality = 2 }, { quality = 1, isQuest = true } }
fire("LOOT_READY", false)
fire("LOOT_OPENED", false, false)
fire("LOOT_SLOT_CLEARED", 1)
fire("CHAT_MSG_MONEY", "You loot 5 Copper")
fire("LOOT_SLOT_CLEARED", 2)
fire("ITEM_PUSH", 1, 0)
now = now + 0.4
fire("LOOT_SLOT_CLEARED", 3)
fire("ITEM_PUSH", 1, 0)
fire("LOOT_CLOSED")
check("L3 manual: coin click -> lootGold once", count("lootGold"), 1)
check("L3 manual: one itemObtained per item click", count("itemObtained"), 2)
check("L3   quest item gets the quest gain (1.15)", fired[#fired] and fired[#fired].override, 1.15)

fresh({ "itemObtained" })
lootSlots = { { quality = 2 }, { quality = 2 } }
fire("LOOT_OPENED", false, false) -- a client that never sends LOOT_SLOT_CLEARED
fire("ITEM_PUSH", 1, 0)
now = now + 0.4
fire("ITEM_PUSH", 1, 0)
fire("LOOT_CLOSED")
check("L4 manual without LOOT_SLOT_CLEARED: never silent", count("itemObtained"), 2)

fresh({ "lootReceived" })
fire("CHAT_MSG_LOOT", "Someone receives loot", "Other", "", "", "", "", 0, 0, "", 0, 1, "Player-2")
check("L5 another player's loot: silent", count("lootReceived"), 0)
fire("CHAT_MSG_LOOT", "You receive loot", "Tester", "", "", "", "", 0, 0, "", 0, 2, "Player-1")
check("L5 own loot outside a loot window: plays", count("lootReceived"), 1)

fresh({ "itemObtained" })
lootSlots = { { quality = 4, locked = true }, { quality = 1 } }
fire("LOOT_OPENED", false, false)
fire("LOOT_SLOT_CLEARED", 1)
check("L6 roll (locked) slot cleared: silent", count("itemObtained"), 0)
fire("LOOT_CLOSED")

fresh({ "itemObtained" })
lootSlots = { { quality = 4 } } -- Epic -> gain 1.30
fire("LOOT_READY", true)
lootSlots = {} -- autoloot emptied window before LOOT_OPENED
fire("LOOT_OPENED", true, false)
fire("ITEM_PUSH", 1, 0)
check("L7 autoloot emptied before LOOT_OPENED keeps Epic gain (1.30)", fired[1] and fired[1].override, 1.3)

-- ── Repair ────────────────────────────────────────────────────────────────────

local function openVendor()
	merchantOpen = true
	fire("MERCHANT_SHOW")
end

fresh({ "merchantBuy", "merchantSell", "merchantRepair" })
repairCost = 500
openVendor()
RepairAllItems()
fire("UPDATE_INVENTORY_DURABILITY")
repairCost = 0
money = money - 500
fire("PLAYER_MONEY")
check("R1 personal repair: merchantRepair once", count("merchantRepair"), 1)
check("R1   its payment is not a purchase", count("merchantBuy"), 0)
now = now + 0.3
money = money - 100
fire("PLAYER_MONEY")
check("R1   the next real purchase is felt", count("merchantBuy"), 1)

fresh({ "merchantBuy", "merchantSell", "merchantRepair" })
repairCost = 500
openVendor()
RepairAllItems()
money = money - 500
fire("PLAYER_MONEY") -- money before durability
fire("UPDATE_INVENTORY_DURABILITY")
check("R2 money first: merchantRepair once, not twice", count("merchantRepair"), 1)
check("R2   and not a purchase", count("merchantBuy"), 0)
now = now + 0.3
money = money - 100
fire("PLAYER_MONEY")
check("R2   next purchase felt", count("merchantBuy"), 1)

fresh({ "merchantBuy", "merchantSell", "merchantRepair" })
repairCost = 500
openVendor()
RepairAllItems(true) -- guild funds: personal money never moves
fire("UPDATE_INVENTORY_DURABILITY")
check("R3 guild repair: merchantRepair once", count("merchantRepair"), 1)
now = now + 0.3
money = money + 50
fire("PLAYER_MONEY")
check("R3   the next sale is NOT swallowed", count("merchantSell"), 1)

fresh({ "merchantBuy", "merchantSell", "merchantRepair" })
repairCost = 500
openVendor()
fire("UPDATE_INVENTORY_DURABILITY") -- equipping gear at the vendor
check("R4 durability update without a repair: silent", count("merchantRepair"), 0)
money = money - 100
fire("PLAYER_MONEY")
check("R4   next purchase felt", count("merchantBuy"), 1)

fresh({ "merchantBuy", "merchantSell", "merchantRepair" })
repairCost = 500
openVendor()
RepairAllItems() -- request never confirmed (not enough money)
now = now + 3
money = money - 500 -- same amount, long after the window
fire("PLAYER_MONEY")
check("R5 expired arm cannot swallow a later purchase", count("merchantBuy"), 1)

fresh({ "merchantBuy", "merchantSell", "merchantRepair" })
repairCost = 500
openVendor()
repairMode = true -- single-item repair cursor
fire("UPDATE_INVENTORY_DURABILITY")
money = money - 120
fire("PLAYER_MONEY")
repairMode = false
check(
	"R6 cursor repair: merchantRepair once, payment absorbed",
	count("merchantRepair") == 1 and count("merchantBuy") == 0,
	true
)

fresh({ "merchantBuy", "merchantRepair" })
repairCost = 500
openVendor()
repairMode = true
money = money - 500
fire("PLAYER_MONEY") -- repair money arrives before durability
check("R7 repair payment not misread as merchantBuy", count("merchantBuy"), 0)
fire("UPDATE_INVENTORY_DURABILITY")
now = now + 0.4
repairMode = false
money = money - 100
fire("PLAYER_MONEY") -- real purchase after repair
check("R7 cursor repair felt once", count("merchantRepair"), 1)
check("R7 purchase after repair felt as merchantBuy", fired[#fired] and fired[#fired].id, "merchantBuy")

-- ── Durability ────────────────────────────────────────────────────────────────

fresh({ "durabilityLow" })
wipe(alertStatus)
fire("PLAYER_ENTERING_WORLD")
alertStatus[5] = 1
fire("UPDATE_INVENTORY_ALERTS")
check("D1 none -> yellow fires", count("durabilityLow"), 1)
fire("UPDATE_INVENTORY_ALERTS")
check("D1 yellow -> yellow is silent", count("durabilityLow"), 1)
alertStatus[5] = 0
fire("UPDATE_INVENTORY_ALERTS")
check("D1 repair (yellow -> none) is silent", count("durabilityLow"), 1)
alertStatus[9] = 2
fire("UPDATE_INVENTORY_ALERTS")
check("D1 none -> red fires again", count("durabilityLow"), 2)
check("D1   with the broken gain", fired[#fired].override, 1.25)

-- ── Window bus and deferred close ─────────────────────────────────────────────

fresh({ "interactionWindowClosed", "merchantShow", "mailShow" })
merchantOpen = false
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 17) -- mail
reset()
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 17) -- click a vendor while the mailbox is open
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
nextFrame()
check("B1 chained mail -> vendor: close dropped", count("interactionWindowClosed"), 0)
check("B1   vendor arrival felt", count("merchantShow"), 1)

reset()
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 5)
nextFrame()
check("B2 a plain close still plays", count("interactionWindowClosed"), 1)

fresh({ "interactionWindowClosed", "bankClosed" })
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
reset()
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
fire("BANKFRAME_CLOSED")
nextFrame()
check("B3 bank close: bankClosed plays once", count("bankClosed"), 1)
check("B3   generic close yields to it on the bus", count("interactionWindowClosed"), 0)

fresh({ "interactionWindowClosed", "merchantShow", "gossipShow" })
reset()
Pulse:FireIfEnabled("interactionWindowClosed")
Pulse:FireIfEnabled("merchantShow")
check(
	"B4 higher priority replaces on the same layer",
	plays[1].layer == plays[2].layer and plays[2].layer == "bus:window",
	true
)
Pulse:FireIfEnabled("gossipShow")
check("B4 lower priority inside the window is dropped", #plays, 2)
now = now + 0.2
check("B4 dropped cue's throttle was not consumed", Pulse:FireIfEnabled("gossipShow"), true)

fresh({ "guildBankOpened", "interactionWindowClosed" })
Pulse:FireIfEnabled("guildBankOpened") -- window bus prio 3, DOUBLE_TAP ~0.36 s
now = now + 0.2
Pulse:FireIfEnabled("interactionWindowClosed") -- window bus prio 1
check("B5 lower-prio cue does not cut off DOUBLE_TAP while playing", #plays, 1)

-- ── Intake outside any episode (mail, quest reward) ───────────────────────────

fresh({ "itemObtained", "bagItemAdded" })
fire("ITEM_PUSH", 1, 0) -- a mail attachment arrives
freeSlots = 19
fire("BAG_UPDATE_DELAYED")
check("I1 mail item: itemObtained plays", count("itemObtained"), 1)
check("I1   bagItemAdded yields to it on the intake bus", count("bagItemAdded"), 0)
reset()
freeSlots = 18
fire("BAG_UPDATE_DELAYED") -- bag first this time
fire("ITEM_PUSH", 1, 0)
check(
	"I2 order reversed: both played, same layer (item replaced bag)",
	plays[1] and plays[2] and plays[1].layer == plays[2].layer,
	true
)

io.write(failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n"))
os.exit(failures == 0 and 0 or 1)
