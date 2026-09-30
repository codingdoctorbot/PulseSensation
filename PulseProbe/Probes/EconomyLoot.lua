-- PulseProbe — Probes/EconomyLoot.lua
--
-- Scans loot windows for item rarity tiers (Common -> Legendary) and monitors modern profession procs.
-- Tests: Enum.ItemQuality fanfare scaling and TRADE_SKILL_ITEM_CRAFTED_RESULT procs.

local ADDON_NAME, Probe = ...

local EL = {}
Probe.EconomyLoot = EL

local frame = CreateFrame("Frame")

local QUALITY_NAMES = {
	[0] = "Poor (Grey)",
	[1] = "Common (White)",
	[2] = "Uncommon (Green)",
	[3] = "Rare (Blue)",
	[4] = "Epic (Purple)",
	[5] = "Legendary (Orange)",
	[6] = "Artifact (Gold)",
	[7] = "Heirloom (Cyan)",
}

local QUALITY_CUES = {
	[0] = "lootQualityCommon",
	[1] = "lootQualityCommon",
	[2] = "lootQualityUncommon",
	[3] = "lootQualityRare",
	[4] = "lootQualityEpic",
	[5] = "lootQualityLegendary",
	[6] = "lootQualityLegendary",
	[7] = "lootQualityEpic",
}

local function onLootOpened()
	local numItems = GetNumLootItems and GetNumLootItems() or 0
	if numItems == 0 then
		return
	end

	local highestQuality = -1
	local highestItemName = ""

	for slot = 1, numItems do
		local slotType = GetLootSlotType(slot)
		if slotType == 1 then -- 1 = LOOT_SLOT_ITEM
			local itemLink = GetLootSlotLink(slot)
			if itemLink and not issecretvalue(itemLink) then
				local name, _, quality = C_Item.GetItemInfo(itemLink)
				if quality and quality > highestQuality then
					highestQuality = quality
					highestItemName = name or "Item"
				end
			end
		end
	end

	if highestQuality >= 0 then
		local cue = QUALITY_CUES[highestQuality] or "lootQualityCommon"
		local qualityLabel = QUALITY_NAMES[highestQuality] or tostring(highestQuality)
		local payload = string.format("Rarity: %s | Top Item: %s", qualityLabel, highestItemName)
		Probe:AddLogEntry("Economy", "LOOT_OPENED (Quality Scan)", payload, false, false, cue)
	end
end

local function onTradeSkillResult(_, event, resultData)
	if not resultData or issecretvalue(resultData) or type(resultData) ~= "table" then
		return
	end

	-- Multicraft bonus items
	if resultData.multicraft and resultData.multicraft > 0 then
		local payload = string.format("Multicraft Proc! Extra items: +%d", resultData.multicraft)
		Probe:AddLogEntry("Economy", "TRADE_SKILL_RESULT (Multicraft)", payload, false, false, "craftMulticraftProc")
	end

	-- Ingenuity / Inspiration refund
	if resultData.hasIngenuityProc and resultData.ingenuityRefund and resultData.ingenuityRefund > 0 then
		local payload = string.format("Ingenuity Proc! Concentration refunded: %d", resultData.ingenuityRefund)
		Probe:AddLogEntry("Economy", "TRADE_SKILL_RESULT (Ingenuity)", payload, false, false, "craftMulticraftProc")
	end
end

local function onEvent(_, event, ...)
	if event == "LOOT_OPENED" then
		onLootOpened()
	elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
		onTradeSkillResult(_, event, ...)
	end
end

function EL:OnInit(probeCore)
	frame:SetScript("OnEvent", onEvent)
end

function EL:OnEnable()
	frame:RegisterEvent("LOOT_OPENED")
	if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("TRADE_SKILL_ITEM_CRAFTED_RESULT") then
		frame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
	end
end

Probe:RegisterProbe("EconomyLoot", EL)
