-- PulseProbe — AudioHaptic.lua
--
-- Audible & tactile preview engine. Maps candidate cues to built-in Blizzard SOUNDKITs
-- and optional C_GamePad vibration pulses so the user can audit event rhythm in real time.

local ADDON_NAME, Probe = ...

local AH = {}
Probe.AudioHaptic = AH

local activeVibrationTimer = nil

-- SOUNDKIT mappings for candidate cues (safe numeric fallbacks included)
local SOUND_MAPPINGS = {
	-- Combat Procs
	procExtraAttacks = SOUNDKIT and SOUNDKIT.IG_BONUS_ROLL_START or 8959, -- Double rapid punch
	procExtraAttacksHeavy = SOUNDKIT and SOUNDKIT.IG_BONUS_ROLL_START or 8959,
	crowdControlBroken = SOUNDKIT and SOUNDKIT.UI_WARGAME_LOSE or 8456, -- Brittle glass snap
	damageShieldReciprocal = SOUNDKIT and SOUNDKIT.IG_CREATURE_AGGRO_SELECT or 1175,
	spellDispelSuccess = SOUNDKIT and SOUNDKIT.IG_SPELL_CAST_DIRECT or 823,
	spellStolenSuccess = SOUNDKIT and SOUNDKIT.UI_BONUS_ROLL_ENCOUNTER_START or 824,

	-- Minions & Pets
	petDead = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 3175, -- Hollow gong/alarm
	petHealthCritical = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959,
	petThreatAnchor = SOUNDKIT and SOUNDKIT.PUT_DOWN_SMALL_CHAIN or 1205,
	petHappinessIncreased = SOUNDKIT and SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT or 1176,

	-- World & Hazards
	screenShake = SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 11466, -- Heavy quake thud
	envDamageLava = SOUNDKIT and SOUNDKIT.LAVA_BURNING or 3290,
	envDamageSlime = SOUNDKIT and SOUNDKIT.SLIME_RUMBLE or 3291,
	envDamageFalling = SOUNDKIT and SOUNDKIT.FALL_DAMAGE or 3280,

	-- Navigation
	waypointGeigerTick = SOUNDKIT and SOUNDKIT.IG_INVENTORY_ROTATE or 1201, -- Metallic tick
	waypointArrival = SOUNDKIT and SOUNDKIT.UI_QUEST_COMPLETE or 878, -- Triumphant arrival

	-- Loot & Economy
	lootQualityCommon = SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN or 862,
	lootQualityUncommon = SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN or 876,
	lootQualityRare = SOUNDKIT and SOUNDKIT.UI_BONUS_LOOT_ROLL or 877,
	lootQualityEpic = SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 11466,
	lootQualityLegendary = SOUNDKIT and SOUNDKIT.UI_LEGENDARY_LOOT_TOAST or 63971,
	craftMulticraftProc = SOUNDKIT and SOUNDKIT.AUCTION_WINDOW_OPEN or 882,

	-- Errors & Ergonomics
	actionErrorNoResource = SOUNDKIT and SOUNDKIT.IG_ABILITY_DISABLED or 1202, -- Empty chamber dead-click
	actionErrorOutOfRange = SOUNDKIT and SOUNDKIT.UI_ERROR_SOUND or 1203,
	actionErrorOnCooldown = SOUNDKIT and SOUNDKIT.IG_SPELL_FAILED or 1204,
	durabilityWarningLow = SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST or 874,
	durabilityItemBroken = SOUNDKIT and SOUNDKIT.ITEM_BREAK_ARMOR or 1199,
}

-- Vibration profile definitions (lowMotor, highMotor, durationSeconds)
local HAPTIC_MAPPINGS = {
	procExtraAttacks = { low = 0.80, high = 0.65, dur = 0.12 },
	procExtraAttacksHeavy = { low = 1.00, high = 0.85, dur = 0.16 },
	crowdControlBroken = { low = 0.15, high = 0.90, dur = 0.08 },
	damageShieldReciprocal = { low = 0.00, high = 0.45, dur = 0.04 },
	spellDispelSuccess = { low = 0.35, high = 0.65, dur = 0.10 },
	spellStolenSuccess = { low = 0.60, high = 0.80, dur = 0.22 },

	petDead = { low = 0.90, high = 0.20, dur = 0.25 },
	petHealthCritical = { low = 0.30, high = 0.70, dur = 0.15 },
	petThreatAnchor = { low = 0.50, high = 0.40, dur = 0.07 },
	petHappinessIncreased = { low = 0.35, high = 0.40, dur = 0.40 },

	screenShake = { low = 0.85, high = 0.20, dur = 0.30 },
	envDamageLava = { low = 0.75, high = 0.45, dur = 0.16 },
	envDamageSlime = { low = 0.60, high = 0.35, dur = 0.18 },
	envDamageFalling = { low = 0.95, high = 0.30, dur = 0.22 },

	waypointGeigerTick = { low = 0.00, high = 0.30, dur = 0.03 },
	waypointArrival = { low = 0.50, high = 0.70, dur = 0.28 },

	lootQualityCommon = { low = 0.00, high = 0.25, dur = 0.04 },
	lootQualityUncommon = { low = 0.20, high = 0.40, dur = 0.08 },
	lootQualityRare = { low = 0.40, high = 0.60, dur = 0.16 },
	lootQualityEpic = { low = 0.80, high = 0.70, dur = 0.25 },
	lootQualityLegendary = { low = 1.00, high = 0.90, dur = 0.50 },
	craftMulticraftProc = { low = 0.35, high = 0.65, dur = 0.12 },

	actionErrorNoResource = { low = 0.20, high = 0.15, dur = 0.04 },
	actionErrorOutOfRange = { low = 0.10, high = 0.30, dur = 0.05 },
	actionErrorOnCooldown = { low = 0.00, high = 0.25, dur = 0.03 },
	durabilityWarningLow = { low = 0.50, high = 0.20, dur = 0.24 },
	durabilityItemBroken = { low = 0.85, high = 0.90, dur = 0.20 },
}

function AH:PlayMockSound(cueID)
	if not Probe.DB or not Probe.DB.soundEnabled then
		return
	end
	local soundKitID = SOUND_MAPPINGS[cueID]
	if soundKitID then
		pcall(PlaySound, soundKitID, "SFX", false)
	end
end

function AH:TriggerHapticVibration(cueID)
	if not Probe.DB or not Probe.DB.hapticsEnabled then
		return
	end
	if not C_GamePad or not C_GamePad.IsEnabled or not C_GamePad.IsEnabled() then
		return
	end

	local profile = HAPTIC_MAPPINGS[cueID]
	if not profile then
		return
	end

	-- Cancel existing timer if one is running
	if activeVibrationTimer then
		activeVibrationTimer:Cancel()
		activeVibrationTimer = nil
	end

	local deviceIndex = 0 -- Default primary gamepad device
	pcall(C_GamePad.SetVibration, deviceIndex, profile.low, profile.high)

	activeVibrationTimer = C_Timer.NewTimer(profile.dur, function()
		pcall(C_GamePad.SetVibration, deviceIndex, 0, 0)
		activeVibrationTimer = nil
	end)
end

function AH:OnProbeFired(category, eventName, mockCue)
	if not mockCue or mockCue == "" then
		return
	end
	self:PlayMockSound(mockCue)
	self:TriggerHapticVibration(mockCue)
end
