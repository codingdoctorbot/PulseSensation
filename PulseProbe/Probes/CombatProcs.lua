-- PulseProbe — Probes/CombatProcs.lua
--
-- Intercepts high-impact combat procs and crowd control breaks via COMBAT_LOG_EVENT_UNFILTERED.
-- Tests: SPELL_EXTRA_ATTACKS (Windfury/Sword Spec), SPELL_AURA_BROKEN_SPELL (CC Shatter),
-- DAMAGE_SHIELD (Thorns/Retribution/Lightning Shield), and SPELL_DISPEL / SPELL_STOLEN.

local ADDON_NAME, Probe = ...

local CP = {}
Probe.CombatProcs = CP

local frame = CreateFrame("Frame")
local playerGUID = nil

local function onCombatLogEvent()
	local _, event, _, sourceGUID, _, _, _, destGUID, destName, _, _, _, spellName, _, extraArg1, extraArg2 =
		CombatLogGetCurrentEventInfo()

	if not playerGUID then
		playerGUID = UnitGUID("player")
	end

	-- 1. Multi-Hit Extra Attack Procs (Windfury, Sword Spec, Thrash Blade, Ironfoe, HoJ)
	if event == "SPELL_EXTRA_ATTACKS" then
		if sourceGUID == playerGUID then
			local amount = extraArg1 or 1
			local isSecret = issecretvalue and issecretvalue(amount)
			local cue = (amount >= 2) and "procExtraAttacksHeavy" or "procExtraAttacks"
			local payload = string.format("amount=%d (%s)", amount, spellName or "Extra Attack")
			Probe:AddLogEntry("Combat", "SPELL_EXTRA_ATTACKS", payload, isSecret, false, cue)
		end

	-- 2. Crowd Control Premature Breakage
	elseif event == "SPELL_AURA_BROKEN_SPELL" or event == "SPELL_AURA_BROKEN" then
		local isTargetVictim = (destGUID == UnitGUID("target"))
		local isPlayerSource = (sourceGUID == playerGUID)

		if isTargetVictim or isPlayerSource then
			local brokenSpell = spellName or "Crowd Control"
			local breakerSpell = extraArg2 or "Damage"
			local payload = string.format("%s broken by %s", brokenSpell, breakerSpell)
			Probe:AddLogEntry("Combat", event, payload, false, false, "crowdControlBroken")
		end

	-- 3. Damage Shields (Thorns, Retribution Aura, Lightning Shield)
	elseif event == "DAMAGE_SHIELD" then
		if destGUID == playerGUID or sourceGUID == playerGUID then
			local amount = extraArg1 or 0
			local payload = string.format("Shield hit: %s (%d dmg)", spellName or "Damage Shield", amount)
			Probe:AddLogEntry("Combat", "DAMAGE_SHIELD", payload, false, false, "damageShieldReciprocal")
		end

	-- 4. Dispels & Spellsteal
	elseif event == "SPELL_DISPEL" then
		if sourceGUID == playerGUID then
			local dispelledSpell = extraArg2 or "Buff"
			local payload = string.format("Dispelled: %s from %s", dispelledSpell, destName or "target")
			Probe:AddLogEntry("Combat", "SPELL_DISPEL", payload, false, false, "spellDispelSuccess")
		end
	elseif event == "SPELL_STOLEN" then
		if sourceGUID == playerGUID then
			local stolenSpell = extraArg2 or "Buff"
			local payload = string.format("Stole: %s from %s", stolenSpell, destName or "target")
			Probe:AddLogEntry("Combat", "SPELL_STOLEN", payload, false, false, "spellStolenSuccess")
		end
	end
end

function CP:OnInit(probeCore)
	frame:SetScript("OnEvent", onCombatLogEvent)
end

function CP:OnEnable()
	playerGUID = UnitGUID("player")
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

Probe:RegisterProbe("CombatProcs", CP)
