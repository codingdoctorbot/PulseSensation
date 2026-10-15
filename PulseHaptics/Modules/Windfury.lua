-- Pulse — Modules/Windfury.lua
--
-- Dedicated detection for Windfury Weapon and extra-attack procs.
-- Two independent detection vectors exposed as separate experimental cues:
--
--   1. windfurySwing: PLAYER_SWING timing burst (< 50% of weapon speed).
--      Proven on WoW Forever by HanharEnhancementHUD. Extra attacks arrive well
--      before the natural swing timer. Does not reset baseline swing timing.
--
--   2. windfurySpell: UNIT_SPELLCAST_SUCCEEDED for Windfury Attack (Spell ID 25504).
--      Direct spellcast event hook. Dependent on server emitting the cast event for
--      item enchantment procs.

local ADDON_NAME, Pulse = ...
local issecretvalue = Pulse.issecret

local M = {}
Pulse:RegisterModule("Windfury", M)

local SWING_MAIN = 0
local EXTRA_ATTACK_WINDOW = 0.5 -- fraction of weapon speed (<50% = extra attack)
local PROC_COOLDOWN = 0.400 -- seconds: debounces multi-hit cluster

-- Static lookup table allocated once at load (never in OnEvent loop)
local WINDFURY_SPELL_IDS = {
	[25504] = true, -- Windfury Attack (Classic / Forever)
	[33757] = true, -- Windfury Attack (TBC / Wrath)
	[262895] = true, -- Windfury Attack (Modern Retail)
	[383290] = true, -- Windfury extra attack talent
}

-- Module-scoped primitive numbers (Zero GC allocations during combat)
local lastMainSwingStart = 0
local currentWeaponSpeed = 2.6
local lastSwingProcTime = 0
local lastSpellProcTime = 0

local frame = CreateFrame("Frame")

local function swingTypeValue(name, fallback)
	local enum = Enum and Enum.PlayerSwingType
	local value = enum and enum[name]
	if type(value) == "number" then
		return value
	end
	return fallback
end

local function getFallbackSpeed()
	if UnitAttackSpeed then
		local ok, mh = pcall(UnitAttackSpeed, "player")
		if ok and type(mh) == "number" and not (issecretvalue and issecretvalue(mh)) and mh > 0 then
			return mh
		end
	end
	return currentWeaponSpeed
end

local function onPlayerSwing(duration, swingType)
	if not Pulse:IsCueActive("windfurySwing") then
		return
	end
	if issecretvalue and (issecretvalue(swingType) or issecretvalue(duration)) then
		return
	end
	if swingType ~= swingTypeValue("MainHand", SWING_MAIN) then
		return
	end

	local speed
	if type(duration) == "number" and not (issecretvalue and issecretvalue(duration)) and duration > 0 then
		speed = duration
		currentWeaponSpeed = speed
	else
		speed = getFallbackSpeed()
	end

	local now = GetTime()
	local dt = now - lastMainSwingStart

	-- If main-hand swing lands well before the timer is due (<50% of weapon speed),
	-- it is an extra attack!
	if lastMainSwingStart > 0 and dt > 0 and dt < (speed * EXTRA_ATTACK_WINDOW) then
		if (now - lastSwingProcTime) > PROC_COOLDOWN then
			lastSwingProcTime = now
			Pulse:FireIfEnabled("windfurySwing")
		end
		-- Crucial: do not reset lastMainSwingStart on bonus extra attacks,
		-- so regular auto-attack swing cadence remains preserved!
		return
	end

	lastMainSwingStart = now
end

local function onSpellcastSucceeded(unitTarget, castGUID, spellID)
	if not Pulse:IsCueActive("windfurySpell") then
		return
	end
	if issecretvalue and issecretvalue(spellID) then
		return
	end
	if type(spellID) == "number" and WINDFURY_SPELL_IDS[spellID] then
		local now = GetTime()
		if (now - lastSpellProcTime) > PROC_COOLDOWN then
			lastSpellProcTime = now
			Pulse:FireIfEnabled("windfurySpell")
		end
	end
end

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
	if event == "PLAYER_SWING" then
		onPlayerSwing(arg1, arg2)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		onSpellcastSucceeded(arg1, arg2, arg3)
	end
end)

local function swingEventAvailable()
	if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
		local ok, valid = pcall(C_EventUtils.IsEventValid, "PLAYER_SWING")
		return (ok and valid) and true or false
	end
	return true
end

local function sync()
	frame:UnregisterAllEvents()
	lastMainSwingStart = 0

	if not Pulse.Database:Get("masterEnabled") then
		return
	end

	local swingActive = Pulse:IsCueActive("windfurySwing")
	local spellActive = Pulse:IsCueActive("windfurySpell")

	if not (swingActive or spellActive) then
		return
	end

	if swingActive and swingEventAvailable() then
		pcall(frame.RegisterEvent, frame, "PLAYER_SWING")
	end

	if spellActive then
		pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
	end
end

function M:OnEnable()
	Pulse:BindFrame({ "windfurySwing", "windfurySpell" }, sync)
end
