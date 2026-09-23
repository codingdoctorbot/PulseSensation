-- Pulse — Modules/AlertUnitWatch.lua
--
-- Accessibility cue, imported near-verbatim from Tremor/Modules/UnitWatch.lua. The most
-- constrained module in the import: every handler is occurrence-only, because the spellcast
-- payload for a non-player unit is secret up to and including arg1's unit token. One frame
-- per unit token, frame identity is the filter, never a branch on arg1.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertUnitWatch", M)

function M:OnEnable()
	self:_WatchUnit("target", "targetCastStart", "targetChannelStart")
	self:_WatchUnit("focus", "focusCastStart", "focusChannelStart")
	self:_WatchSwaps()
	self:_WatchTargetDeath()
	self:_WatchHostileRadar()
	self:_WatchDefensives()
end

function M:_WatchUnit(unit, startCue, channelCue)
	local frame = CreateFrame("Frame")

	local function sync()
		frame:UnregisterAllEvents()
		if not Pulse.Database:Get("masterEnabled") then
			return
		end
		if Pulse.Database:GetCue(startCue) then
			frame:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
		end
		if Pulse.Database:GetCue(channelCue) then
			frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
		end
	end

	frame:SetScript("OnEvent", function(_, event)
		if event == "UNIT_SPELLCAST_START" then
			Pulse:FireIfEnabled(startCue)
		else
			Pulse:FireIfEnabled(channelCue)
		end
	end)

	Pulse:BindFrame({ startCue, channelCue }, sync)
end

function M:_WatchSwaps()
	local frame = CreateFrame("Frame")

	local function sync()
		frame:UnregisterAllEvents()
		if not Pulse.Database:Get("masterEnabled") then
			return
		end
		if
			Pulse.Database:GetCue("targetChanged")
			or Pulse.Database:GetCue("targetCastStart")
			or Pulse.Database:GetCue("targetChannelStart")
		then
			frame:RegisterEvent("PLAYER_TARGET_CHANGED")
		end
		if
			Pulse.Database:GetCue("focusChanged")
			or Pulse.Database:GetCue("focusCastStart")
			or Pulse.Database:GetCue("focusChannelStart")
		then
			frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
		end
	end

	frame:SetScript("OnEvent", function(_, event)
		M:_OnSwap(event)
	end)

	Pulse:BindFrame({
		"targetChanged",
		"focusChanged",
		"targetCastStart",
		"focusCastStart",
		"targetChannelStart",
		"focusChannelStart",
	}, sync)
end

-- Legal truthiness test only: the first return of UnitCastingInfo/UnitChannelInfo is a name
-- string or nil, and truthiness on a non-boolean secret is permitted. Do not extend it to
-- any other return. Resolving the target/focus collision via UnitIsUnit is illegal — a
-- secret boolean with no legal inspection path — so a duplicate fire when focus == target
-- is left to the blended engine to collapse.
function M:_OnSwap(event)
	local isTarget = (event == "PLAYER_TARGET_CHANGED")
	local unit = isTarget and "target" or "focus"
	local castCue = isTarget and "targetCastStart" or "focusCastStart"
	local channelCue = isTarget and "targetChannelStart" or "focusChannelStart"
	local changedCue = isTarget and "targetChanged" or "focusChanged"

	if Pulse.Database:GetCue(castCue) and UnitCastingInfo(unit) then
		Pulse:FireIfEnabled(castCue)
		return
	end

	if Pulse.Database:GetCue(channelCue) and UnitChannelInfo(unit) then
		Pulse:FireIfEnabled(channelCue)
		return
	end

	Pulse:FireIfEnabled(changedCue)
end

function M:_WatchTargetDeath()
	local frame = CreateFrame("Frame")

	local function sync()
		frame:UnregisterAllEvents()
		if not Pulse.Database:Get("masterEnabled") then
			return
		end
		if Pulse.Database:GetCue("targetDied") then
			frame:RegisterEvent("PLAYER_TARGET_DIED")
		end
	end

	frame:SetScript("OnEvent", function()
		Pulse:FireIfEnabled("targetDied")
	end)

	Pulse:BindFrame({ "targetDied" }, sync)
end

local TOT_FOR_UNIT = {
	target = "targettarget",
	focus = "focustarget",
}

local wasTargeting = {
	target = false,
	focus = false,
}

local function checkUnitTargetingPlayer(unit)
	if not UnitExists(unit) then
		return false
	end
	local okAttack, canAttack = pcall(UnitCanAttack, unit, "player")
	if not okAttack or issecretvalue(canAttack) or not canAttack then
		return false
	end
	local tot = TOT_FOR_UNIT[unit]
	if not tot or not UnitExists(tot) then
		return false
	end
	local okUnit, isTargeting = pcall(UnitIsUnit, tot, "player")
	if okUnit and not issecretvalue(isTargeting) and isTargeting then
		return true
	end
	return false
end

function M:_WatchHostileRadar()
	local frame = CreateFrame("Frame")

	local function sync()
		frame:UnregisterAllEvents()
		wasTargeting.target = false
		wasTargeting.focus = false
		if not Pulse.Database:Get("masterEnabled") then
			return
		end
		if Pulse.Database:GetCue("targetedByEnemy") then
			frame:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
			frame:RegisterEvent("PLAYER_TARGET_CHANGED")
			frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
			wasTargeting.target = checkUnitTargetingPlayer("target")
			wasTargeting.focus = checkUnitTargetingPlayer("focus")
		end
	end

	frame:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_TARGET" then
			if unit == "target" or unit == "focus" then
				local isTargeting = checkUnitTargetingPlayer(unit)
				if isTargeting and not wasTargeting[unit] then
					Pulse:FireIfEnabled("targetedByEnemy")
				end
				wasTargeting[unit] = isTargeting
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			local isTargeting = checkUnitTargetingPlayer("target")
			if isTargeting then
				Pulse:FireIfEnabled("targetedByEnemy")
			end
			wasTargeting.target = isTargeting
		elseif event == "PLAYER_FOCUS_CHANGED" then
			local isTargeting = checkUnitTargetingPlayer("focus")
			if isTargeting then
				Pulse:FireIfEnabled("targetedByEnemy")
			end
			wasTargeting.focus = isTargeting
		end
	end)

	Pulse:BindFrame({ "targetedByEnemy" }, sync)
end

function M:_WatchDefensives()
	local frame = CreateFrame("Frame")

	local function sync()
		frame:UnregisterAllEvents()
		if not Pulse.Database:Get("masterEnabled") then
			return
		end
		if Pulse.Database:GetCue("targetBigDefensive") then
			frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "target")
			frame:RegisterUnitEvent("UNIT_AURA", "target")
		end
	end

	local function isBigDefensiveSpell(spellID)
		if not spellID or issecretvalue(spellID) then
			return false
		end
		if C_UnitAuras and type(C_UnitAuras.AuraIsBigDefensive) == "function" then
			local ok, isDef = pcall(C_UnitAuras.AuraIsBigDefensive, spellID)
			if ok and not issecretvalue(isDef) and isDef then
				return true
			end
		end
		return false
	end

	frame:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
		if unit ~= "target" then
			return
		end

		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local spellID = arg3
			if isBigDefensiveSpell(spellID) then
				Pulse:FireIfEnabled("targetBigDefensive")
			end
			return
		end

		if event == "UNIT_AURA" then
			local updateInfo = arg2
			if updateInfo and type(updateInfo) == "table" and updateInfo.addedAuras then
				for _, auraData in ipairs(updateInfo.addedAuras) do
					if auraData and auraData.spellId and isBigDefensiveSpell(auraData.spellId) then
						Pulse:FireIfEnabled("targetBigDefensive")
						return
					end
				end
			end
		end
	end)

	Pulse:BindFrame({ "targetBigDefensive" }, sync)
end
