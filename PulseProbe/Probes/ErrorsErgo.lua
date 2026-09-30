-- PulseProbe — Probes/ErrorsErgo.lua
--
-- Intercepts UI error codes for mechanical dead-clicks and monitors inventory durability transitions.
-- Tests: Resource starvation, out-of-range bounce, cooldown resistance, and yellow/red durability alerts.

local ADDON_NAME, Probe = ...

local EE = {}
Probe.ErrorsErgo = EE

local frame = CreateFrame("Frame")
local lastResourceErrorTime = 0
local lastRangeErrorTime = 0
local lastCooldownErrorTime = 0
local lastDurabilityAlertTime = 0

local SLOT_NAMES = {
	[1] = "Head",
	[2] = "Shoulders",
	[3] = "Chest",
	[4] = "Waist",
	[5] = "Legs",
	[6] = "Feet",
	[7] = "Wrists",
	[8] = "Hands",
	[9] = "MainHand",
	[10] = "Shield / OffHand",
	[11] = "Ranged",
}

local function onUIErrorMessage(messageType, message)
	if not messageType or issecretvalue(messageType) then
		return
	end

	local now = GetTime()

	-- 1. Resource Starvation (Out of Energy, Rage, Mana, Combo Points, Runes)
	if
		messageType == LE_GAME_ERR_OUT_OF_ENERGY
		or messageType == LE_GAME_ERR_OUT_OF_RAGE
		or messageType == LE_GAME_ERR_OUT_OF_MANA
		or messageType == LE_GAME_ERR_OUT_OF_COMBO_POINTS
		or messageType == LE_GAME_ERR_OUT_OF_RUNES
		or messageType == LE_GAME_ERR_OUT_OF_HOLY_POWER
	then
		if now - lastResourceErrorTime >= 0.400 then -- 400ms clamp
			lastResourceErrorTime = now
			local payload = string.format("Code: %d | '%s'", messageType, message or "Out of resource")
			Probe:AddLogEntry("Errors", "UI_ERROR (Starvation)", payload, false, false, "actionErrorNoResource")
		end

	-- 2. Out of Range Deflection
	elseif messageType == LE_GAME_ERR_OUT_OF_RANGE or messageType == LE_GAME_ERR_SPELL_OUT_OF_RANGE then
		if now - lastRangeErrorTime >= 0.400 then
			lastRangeErrorTime = now
			local payload = string.format("Code: %d | '%s'", messageType, message or "Out of range")
			Probe:AddLogEntry("Errors", "UI_ERROR (Out of Range)", payload, false, false, "actionErrorOutOfRange")
		end

	-- 3. On Cooldown Spring Tick
	elseif messageType == LE_GAME_ERR_ABILITY_COOLDOWN or messageType == LE_GAME_ERR_SPELL_COOLDOWN then
		if now - lastCooldownErrorTime >= 0.400 then
			lastCooldownErrorTime = now
			local payload = string.format("Code: %d | '%s'", messageType, message or "Ability on cooldown")
			Probe:AddLogEntry("Errors", "UI_ERROR (Cooldown)", payload, false, false, "actionErrorOnCooldown")
		end
	end
end

local function onInventoryAlerts()
	local now = GetTime()
	if now - lastDurabilityAlertTime < 2.0 then -- 2s throttle
		return
	end
	lastDurabilityAlertTime = now

	local anyBroken = false
	local anyWarning = false
	local affectedSlots = {}

	for slotIdx = 1, 11 do
		local status = GetInventoryAlertStatus and GetInventoryAlertStatus(slotIdx) or 0
		if status == 2 then
			anyBroken = true
			table.insert(affectedSlots, (SLOT_NAMES[slotIdx] or tostring(slotIdx)) .. " [BROKEN 0%]")
		elseif status == 1 then
			anyWarning = true
			table.insert(affectedSlots, (SLOT_NAMES[slotIdx] or tostring(slotIdx)) .. " [<20%]")
		end
	end

	if anyBroken then
		local payload = string.format("Rupture: %s", table.concat(affectedSlots, ", "))
		Probe:AddLogEntry("Errors", "UPDATE_INVENTORY_ALERTS (Broken)", payload, false, false, "durabilityItemBroken")
	elseif anyWarning then
		local payload = string.format("Warning: %s", table.concat(affectedSlots, ", "))
		Probe:AddLogEntry("Errors", "UPDATE_INVENTORY_ALERTS (Low)", payload, false, false, "durabilityWarningLow")
	end
end

local function onEvent(_, event, ...)
	if event == "UI_ERROR_MESSAGE" then
		local messageType, message = ...
		onUIErrorMessage(messageType, message)
	elseif event == "UPDATE_INVENTORY_ALERTS" then
		onInventoryAlerts()
	end
end

function EE:OnInit(probeCore)
	frame:SetScript("OnEvent", onEvent)
end

function EE:OnEnable()
	frame:RegisterEvent("UI_ERROR_MESSAGE")
	frame:RegisterEvent("UPDATE_INVENTORY_ALERTS")
end

Probe:RegisterProbe("ErrorsErgo", EE)
