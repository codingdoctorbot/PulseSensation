-- PulseProbe — Probes/PetsMinions.lua
--
-- Intercepts pet lifelines, companion threat landing, critical pet health, and happiness.
-- Tests: petDead (UNIT_DIED on pet), petThreatAnchor (Growl/Torment), petHealthCritical, petHappinessIncreased.

local ADDON_NAME, Probe = ...

local PM = {}
Probe.PetsMinions = PM

local frame = CreateFrame("Frame")
local lastHealthWarnTime = 0
local lastHappinessLevel = nil

-- Known pet taunt spell IDs (Hunter Growl, Warlock Voidwalker Torment / Suffering)
local PET_TAUNT_SPELLS = {
	[2649] = true, -- Growl (Hunter)
	[14916] = true,
	[14917] = true,
	[14918] = true,
	[14919] = true,
	[14920] = true,
	[14921] = true,
	[17735] = true, -- Torment (Voidwalker)
	[17736] = true,
	[17737] = true,
	[17738] = true,
	[36213] = true, -- Anguish (Felguard)
	[17751] = true, -- Suffering (Voidwalker Taunt AoE)
}

local function onCombatLogEvent()
	local _, event, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellId, spellName =
		CombatLogGetCurrentEventInfo()

	local petGUID = UnitGUID("pet")
	if not petGUID then
		return
	end

	-- 1. Pet Death Alert
	if event == "UNIT_DIED" and destGUID == petGUID then
		if UnitIsDead("pet") or UnitHealth("pet") <= 0 then
			local payload = string.format("Pet '%s' died in combat!", UnitName("pet") or "Companion")
			Probe:AddLogEntry("Pets", "UNIT_DIED (Pet)", payload, false, false, "petDead")
		end

	-- 2. Pet Threat Anchor (Growl / Torment landing)
	elseif event == "SPELL_CAST_SUCCESS" and sourceGUID == petGUID then
		if spellId and PET_TAUNT_SPELLS[spellId] then
			local payload = string.format("Pet landed taunt: %s on %s", spellName or "Growl", destName or "Target")
			Probe:AddLogEntry("Pets", "SPELL_CAST_SUCCESS (Pet)", payload, false, false, "petThreatAnchor")
		end
	end
end

local function onFrameEvent(_, event, unit)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		onCombatLogEvent()
	elseif event == "UNIT_HEALTH" and unit == "pet" then
		if not UnitExists("pet") or UnitIsDead("pet") then
			return
		end
		local maxHP = UnitHealthMax("pet")
		local curHP = UnitHealth("pet")
		if maxHP > 0 and (curHP / maxHP) < 0.20 then
			local now = GetTime()
			if now - lastHealthWarnTime > 5.0 then -- 5s throttle
				lastHealthWarnTime = now
				local pct = math.floor((curHP / maxHP) * 100)
				local payload = string.format("Pet health critical: %d%% (%d / %d)", pct, curHP, maxHP)
				Probe:AddLogEntry("Pets", "UNIT_HEALTH (Pet Low)", payload, false, false, "petHealthCritical")
			end
		end
	elseif event == "UNIT_HAPPINESS" and unit == "pet" then
		if GetPetHappiness then
			local level = GetPetHappiness()
			if level and not issecretvalue(level) and type(level) == "number" then
				if lastHappinessLevel and level > lastHappinessLevel then
					local payload = string.format("Happiness climbed: Level %d -> Level %d", lastHappinessLevel, level)
					Probe:AddLogEntry("Pets", "UNIT_HAPPINESS", payload, false, false, "petHappinessIncreased")
				end
				lastHappinessLevel = level
			end
		end
	end
end

function PM:OnInit(probeCore)
	frame:SetScript("OnEvent", onFrameEvent)
end

function PM:OnEnable()
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterUnitEvent("UNIT_HEALTH", "pet")
	frame:RegisterUnitEvent("UNIT_HAPPINESS", "pet")
	if GetPetHappiness then
		lastHappinessLevel = GetPetHappiness()
	end
end

Probe:RegisterProbe("PetsMinions", PM)
