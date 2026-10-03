-- Pulse — Modules/World.lua
--
-- G9 (durability/gear swap), G10 (own emotes/novelty), G17 (resting) and G18
-- (loot/economy). All simple single- or few-event triggers, so this module uses
-- Pulse:WatchTrigger (Core/Init.lua) rather than dedicated event frames.

local ADDON_NAME, Pulse = ...
local issecretvalue = Pulse.issecret

local M = {}
Pulse:RegisterModule("World", M)

function M:OnEnable()
	Pulse:WatchTrigger({ id = "resting", events = { "PLAYER_UPDATE_RESTING" } })
	-- lootGold, itemObtained, harvestComplete and lootReceived: one loot-episode frame
	-- (Core/Arbiter.lua) instead of four independent watchers. durabilityLow: worsening
	-- edge only.
	self:_WatchLoot()
	self:_WatchDurability()
	Pulse:WatchTrigger({ id = "equipChanged", events = { "PLAYER_EQUIPMENT_CHANGED" } })
	-- Sibling to the player's own emote below. Unlike CHAT_MSG_TEXT_EMOTE these three
	-- carry no player name to match against, so no filtering is needed and the generic
	-- WatchTrigger path fits.
	Pulse:WatchTrigger({
		id = "npcEmote",
		events = {
			"CHAT_MSG_MONSTER_EMOTE",
			"CHAT_MSG_MONSTER_YELL",
			"CHAT_MSG_MONSTER_WHISPER",
		},
	})
	self:_WatchEmote()
end

-- CHAT_MSG_TEXT_EMOTE fires for everyone's emotes, so react only to the player's own or a
-- crowded area buzzes continuously.

function M:_WatchEmote()
	local frame = CreateFrame("Frame")

	local function sync()
		frame:UnregisterAllEvents()
		if not Pulse.Database:Get("masterEnabled") then
			return
		end
		if not Pulse.Database:GetCue("emote") then
			return
		end
		frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
	end

	frame:SetScript("OnEvent", function(_, _, message, sender)
		if issecretvalue(message) or issecretvalue(sender) then
			return
		end
		if not message or not sender then
			return
		end
		local playerName = UnitName("player")
		if not playerName or issecretvalue(playerName) or playerName == "" then
			return
		end
		local senderName = (Ambiguate and sender) and Ambiguate(sender, "none") or sender
		if senderName == playerName then
			Pulse:FireIfEnabled("emote")
		else
			-- Frontier pattern: match whole word only so "Ana" does not match "Anakin"
			-- Escape magic characters in playerName to handle realm suffixes or punctuation
			local escapedName = playerName:gsub("%p", "%%%0")
			local pattern = "%f[%a]" .. escapedName .. "%f[%A]"
			local ok, found = pcall(string.find, message, pattern)
			if ok and found then
				Pulse:FireIfEnabled("emote")
			elseif not ok then
				-- Fallback plain substring match if pattern matching fails (e.g. non-ASCII)
				if message:find(playerName, 1, true) then
					Pulse:FireIfEnabled("emote")
				end
			end
		end
	end)

	Pulse:BindFrame({ "emote" }, sync)
end

-- ── Loot episode (Core/Arbiter.lua) ───────────────────────────────────────────
--
-- LOOT_READY .. LOOT_CLOSED is one episode. Every intake event asks the Arbiter first; the
-- episode's speaker plays once (autoloot) or once per click (manual), everything else in
-- the episode stands down. Outside an episode each cue behaves exactly as before.

local LOOT_WATCHED = { "lootOpened", "harvestComplete", "itemObtained", "lootReceived", "lootGold", "bagItemAdded" }

function M:_WatchLoot()
	local frame = CreateFrame("Frame")
	local Arbiter = Pulse.Arbiter
	local playerGUID = nil

	local function sync()
		frame:UnregisterAllEvents()
		Arbiter:LootReset()
		if not Pulse.Database:Get("masterEnabled") then
			return
		end
		local any = false
		for _, cueID in ipairs(LOOT_WATCHED) do
			if Pulse.Database:GetCue(cueID) then
				any = true
				break
			end
		end
		if not any then
			return
		end
		frame:RegisterEvent("LOOT_READY")
		frame:RegisterEvent("LOOT_OPENED")
		frame:RegisterEvent("LOOT_SLOT_CLEARED")
		frame:RegisterEvent("LOOT_CLOSED")
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		if Pulse.Database:GetCue("itemObtained") then
			frame:RegisterEvent("ITEM_PUSH")
		end
		if Pulse.Database:GetCue("lootReceived") then
			frame:RegisterEvent("CHAT_MSG_LOOT")
		end
		if Pulse.Database:GetCue("lootGold") then
			frame:RegisterEvent("CHAT_MSG_MONEY")
		end
	end

	-- CHAT_MSG_LOOT fires for every group member's loot and roll. Own loot only: the 12th
	-- payload field is the looter's GUID (ChatInfoDocumentation.lua, CHAT_MSG_LOOT).
	local function isOwnLoot(guid)
		if issecretvalue(guid) or type(guid) ~= "string" then
			return false
		end
		if not playerGUID then
			local mine = UnitGUID("player")
			if issecretvalue(mine) then
				return false
			end
			playerGUID = mine
		end
		return guid == playerGUID
	end

	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "LOOT_READY" then
			Arbiter:LootOpened((...))
			if not Arbiter:IsLive("lootOpened") then
				Pulse:FireIfEnabled("harvestComplete")
			end
		elseif event == "LOOT_OPENED" then
			Arbiter:LootOpened((...))
		elseif event == "LOOT_SLOT_CLEARED" then
			Arbiter:LootSlotCleared((...))
		elseif event == "LOOT_CLOSED" then
			Arbiter:LootClosed()
		elseif event == "ITEM_PUSH" then
			if not Arbiter:VendorOwnsIntake("itemObtained") and not Arbiter:LootIntake() then
				Pulse:FireIfEnabled("itemObtained")
			end
		elseif event == "CHAT_MSG_LOOT" then
			local guid = select(12, ...)
			if isOwnLoot(guid) and not Arbiter:LootIntake() then
				Pulse:FireIfEnabled("lootReceived")
			end
		elseif event == "CHAT_MSG_MONEY" then
			if not Arbiter:LootIntake() then
				Pulse:FireIfEnabled("lootGold")
			end
		elseif event == "PLAYER_ENTERING_WORLD" then
			playerGUID = nil
			Arbiter:LootReset()
		end
	end)

	Pulse:BindFrame(LOOT_WATCHED, sync)
end

-- ── Durability: worsening edge only ───────────────────────────────────────────
--
-- UPDATE_INVENTORY_ALERTS also fires when a repair CLEARS an alert, and on zoning. The cue
-- means "your gear got worse", so it fires only when the worst slot status rises
-- (0 none -> 1 yellow -> 2 red), read the way Blizzard's own DurabilityFrame reads it.

local ALERT_SLOT_FALLBACK = 11 -- INVENTORY_ALERT_STATUS_SLOTS, DurabilityFrame.lua:1-12
local BROKEN_GAIN = 1.25

function M:_WatchDurability()
	local frame = CreateFrame("Frame")
	local lastWorst = -1 -- unseeded: the first reading is a baseline, never a cue

	local function worstAlert()
		if type(GetInventoryAlertStatus) ~= "function" then
			return 0
		end
		local slots = (type(INVENTORY_ALERT_STATUS_SLOTS) == "table" and #INVENTORY_ALERT_STATUS_SLOTS)
			or ALERT_SLOT_FALLBACK
		if slots <= 0 then
			slots = ALERT_SLOT_FALLBACK
		end
		local worst = 0
		for index = 1, slots do
			local status = GetInventoryAlertStatus(index)
			if not issecretvalue(status) and type(status) == "number" and status > worst then
				worst = status
			end
		end
		return worst
	end

	local function sync()
		frame:UnregisterAllEvents()
		lastWorst = -1
		if not Pulse.Database:Get("masterEnabled") or not Pulse.Database:GetCue("durabilityLow") then
			return
		end
		frame:RegisterEvent("UPDATE_INVENTORY_ALERTS")
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		lastWorst = worstAlert()
	end

	frame:SetScript("OnEvent", function(_, event)
		local worst = worstAlert()
		if event == "UPDATE_INVENTORY_ALERTS" and lastWorst >= 0 and worst > lastWorst then
			Pulse:FireIfEnabled("durabilityLow", worst >= 2 and BROKEN_GAIN or 1.0)
		end
		lastWorst = worst
	end)

	Pulse:BindFrame({ "durabilityLow" }, sync)
end
