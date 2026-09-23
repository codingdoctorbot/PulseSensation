-- Pulse — Modules/World.lua
--
-- G9 (durability/gear swap), G10 (own emotes/novelty), G17 (resting) and G18
-- (loot/economy). All simple single- or few-event triggers, so this module uses
-- Pulse:WatchTrigger (Core/Init.lua) rather than dedicated event frames.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("World", M)

function M:OnEnable()
	Pulse:WatchTrigger({ id = "resting", events = { "PLAYER_UPDATE_RESTING" } })
	Pulse:WatchTrigger({ id = "lootGold", events = { "CHAT_MSG_MONEY" } })
	Pulse:WatchTrigger({ id = "itemObtained", events = { "ITEM_PUSH" } })
	Pulse:WatchTrigger({ id = "harvestComplete", events = { "LOOT_READY" } })
	Pulse:WatchTrigger({ id = "durabilityLow", events = { "UPDATE_INVENTORY_ALERTS" } })
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

	frame:SetScript("OnEvent", function(_, event, message, sender)
		local playerName = UnitName("player")
		local senderName = (Ambiguate and sender) and Ambiguate(sender, "none") or sender
		if senderName == playerName then
			Pulse:FireIfEnabled("emote")
		elseif message and playerName and playerName ~= "" then
			-- Frontier pattern: match whole word only so "Ana" does not match "Anakin"
			local pattern = "%f[%a]" .. playerName .. "%f[%A]"
			if message:find(pattern) then
				Pulse:FireIfEnabled("emote")
			end
		end
	end)

	Pulse:BindFrame({ "emote" }, sync)
end
