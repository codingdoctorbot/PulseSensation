-- Pulse — Modules/Combat.lua
--
-- Combat and spell feedback: ability pulses, critical strikes, casting textures,
-- parry/dodge/block, combo points, and damage taken via COMBAT_TEXT_UPDATE.
--

-- Reads the player's own combat-text feed and cast state, so no restricted units and no
-- target/focus secrecy guards. heavyDamageTaken was removed because damage amounts can
-- return secret values in combat. Handlers take no varargs where the payload is unused.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Combat", M)

-- Forward-declared so the COMBAT_TEXT_UPDATE dispatch can reference it before the
-- weapon-swing-sync section assigns it.

local applyParryHaste

-- Ability pulse: spell 61304 is the universal GCD placeholder, tracked as a cooldown
-- object and used as a proxy for "an ability was pressed".

local abilityPulseFrame = CreateFrame("Frame")
local lastAbilityPulseStartTime = 0

local function syncAbilityPulse()
	abilityPulseFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("abilityPulse") then
		return
	end
	abilityPulseFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

abilityPulseFrame:SetScript("OnEvent", function()
	if not InCombatLockdown() then
		return
	end -- the whole point is a combat heartbeat
	local info = C_Spell.GetSpellCooldown(61304)
	if info and not issecretvalue(info) then
		local startTime, duration = info.startTime, info.duration
		if not issecretvalue(startTime) and not issecretvalue(duration) then
			if
				startTime
				and startTime > 0
				and duration
				and duration > 0
				and duration <= 1.5
				and startTime ~= lastAbilityPulseStartTime
			then
				lastAbilityPulseStartTime = startTime
				Pulse:FireIfEnabled("abilityPulse")
			end
		end
	end
end)

-- Cooldown Manager: tracks the built-in Essential category through C_Spell.GetSpellCooldown,
-- pcall-wrapped so a behaviour change degrades rather than errors.
-- NOT FUNCTIONING AT THE MOMENT — NEEDS WORK.

local cooldownFrame = CreateFrame("Frame")
local COOLDOWN_CATEGORY = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Essential
local trackedSpells = {} -- spellID -> was on cooldown last check
local cooldownSetResolved = false

local function resolveCooldownSet()
	wipe(trackedSpells)
	cooldownSetResolved = false
	if not COOLDOWN_CATEGORY then
		if Pulse.debug then
			print("Pulse: cooldownReady -> Enum.CooldownViewerCategory.Essential missing")
		end
		return
	end
	if not C_CooldownViewer or type(C_CooldownViewer.GetCooldownViewerCategorySet) ~= "function" then
		if Pulse.debug then
			print("Pulse: cooldownReady -> C_CooldownViewer.GetCooldownViewerCategorySet missing")
		end
		return
	end
	local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, COOLDOWN_CATEGORY)
	if not ok then
		if Pulse.debug then
			print("Pulse: cooldownReady -> GetCooldownViewerCategorySet threw ->", ids)
		end
		return
	end
	if type(ids) ~= "table" then
		if Pulse.debug then
			print("Pulse: cooldownReady -> GetCooldownViewerCategorySet returned", type(ids))
		end
		return
	end
	for _, spellID in ipairs(ids) do
		trackedSpells[spellID] = false
	end
	cooldownSetResolved = true
	if Pulse.debug then
		print(("Pulse: cooldownReady -> resolved %d tracked spell(s)"):format(#ids))
	end
end

local function checkCooldowns()
	if not cooldownSetResolved then
		if Pulse.debug then
			print("Pulse: cooldownReady -> checkCooldowns skipped, set never resolved")
		end
		return
	end
	local now = GetTime()
	for spellID, wasOnCD in pairs(trackedSpells) do
		local info = C_Spell.GetSpellCooldown(spellID)
		-- RULE-B habit: guard the struct before touching fields, even with no restricted
		-- unit involved.
		if info and not issecretvalue(info) then
			local startTime, duration = info.startTime, info.duration
			if not issecretvalue(startTime) and not issecretvalue(duration) then
				local onCD = startTime
					and startTime > 0
					and duration
					and duration > 1.5
					and (now < startTime + duration)
				if Pulse.debug then
					print(
						("Pulse: cooldownReady -> spell %d onCD=%s wasOnCD=%s startTime=%s duration=%s"):format(
							spellID,
							tostring(onCD),
							tostring(wasOnCD),
							tostring(startTime),
							tostring(duration)
						)
					)
				end
				if wasOnCD and not onCD then
					Pulse:FireIfEnabled("cooldownReady")
				end
				trackedSpells[spellID] = onCD and true or false
			elseif Pulse.debug then
				print(("Pulse: cooldownReady -> spell %d skipped, startTime/duration secret"):format(spellID))
			end
		elseif Pulse.debug then
			print(
				("Pulse: cooldownReady -> spell %d skipped, info %s"):format(
					spellID,
					(info == nil) and "nil" or "secret"
				)
			)
		end
	end
end

local function syncCooldownReady()
	cooldownFrame:UnregisterAllEvents()
	wipe(trackedSpells)
	cooldownSetResolved = false
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("cooldownReady") then
		return
	end
	resolveCooldownSet()
	cooldownFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	cooldownFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	checkCooldowns() -- seed real current state, not a stale default
end

cooldownFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_SPECIALIZATION_CHANGED" then
		resolveCooldownSet()
		return
	end
	checkCooldowns()
end)

-- COMBAT_TEXT_UPDATE family: crit, deflect (parry/dodge/block), combo points, damage taken.
-- Damage taken comes through here rather than the non-functional UNIT_COMBAT watcher, and
-- tracks occurrence only rather than amounts, which avoids the value-secrecy problem.

local textFrame = CreateFrame("Frame")

local DEFLECT_TYPES = {
	DODGE = true,
	PARRY = true,
	BLOCK = true,
	SPELL_DODGE = true,
	SPELL_PARRY = true,
	SPELL_BLOCK = true,
	SPELL_DEFLECT = true,
	SPELL_REFLECT = true,
}

local COMBAT_TEXT_CUES = {
	"critLanded",
	"deflect",
	"damageTaken",
	"honorGained",
	"factionGained",
	"healCrit",
	"healReceived",
	"debuffReceived",
}

local function syncCombatText()
	textFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	local any = false
	for _, cueID in ipairs(COMBAT_TEXT_CUES) do
		if Pulse.Database:GetCue(cueID) then
			any = true
			break
		end
	end
	if not any then
		return
	end
	textFrame:RegisterEvent("COMBAT_TEXT_UPDATE")
end

-- damageTaken uses the registry's per-cue intensity, default 0.3. honorGained and
-- factionGained ride the same event stream, occurrence only.

textFrame:SetScript("OnEvent", function(_, event, messageType)
	local ok, data = false, nil
	if C_CombatText and type(C_CombatText.GetCurrentEventInfo) == "function" then
		local arg3, arg4
		ok, data, arg3, arg4 = pcall(C_CombatText.GetCurrentEventInfo)
		if ok then
			-- When partial resists or absorbs occur, Blizzard's CombatText.lua translates them
			-- into damage or crit damage if arg3 (amount) is present:
			if messageType == "RESIST" or messageType == "ABSORB" then
				if arg3 and not issecretvalue(arg3) then
					messageType = arg4 and "DAMAGE_CRIT" or "DAMAGE"
				end
			elseif messageType == "SPELL_RESIST" or messageType == "SPELL_ABSORB" then
				if arg3 and not issecretvalue(arg3) then
					messageType = arg4 and "SPELL_DAMAGE_CRIT" or "SPELL_DAMAGE"
				end
			end
		end
	end

	-- Identified while ruling out EXTRA_ATTACKS
	-- (Pulse_Retail_Combat_Text_Windfury_Findings.md): it means the player picked up a
	-- harmful aura. Occurrence only — the amount on this feed is a secret value.
	if messageType == "SPELL_AURA_START_HARMFUL" then
		Pulse:FireIfEnabled("debuffReceived")
		return
	end
	if messageType == "DAMAGE_CRIT" or messageType == "SPELL_DAMAGE_CRIT" then
		Pulse:FireIfEnabled("critLanded")
		Pulse:FireIfEnabled("damageTaken")
	elseif messageType == "DAMAGE" or messageType == "SPELL_DAMAGE" or messageType == "DAMAGE_SHIELD" then
		Pulse:FireIfEnabled("damageTaken")
	elseif DEFLECT_TYPES[messageType] then
		Pulse:FireIfEnabled("deflect")
		-- Partial block: player blocked arg3 but took data damage
		if
			(messageType == "BLOCK" or messageType == "SPELL_BLOCK")
			and ok
			and data
			and not issecretvalue(data)
			and type(data) == "number"
			and data > 0
		then
			Pulse:FireIfEnabled("damageTaken")
		end
		-- Parry haste: PARRY only, not DODGE/BLOCK. Parrying speeds up your own next
		-- main-hand swing, a real mechanic, distinct from merely avoiding the hit.
		if messageType == "PARRY" and applyParryHaste then
			applyParryHaste()
		end
	elseif messageType == "HEAL_CRIT" then
		Pulse:FireIfEnabled("healCrit")
		Pulse:FireIfEnabled("healReceived")
	elseif messageType == "HEAL" or messageType == "PERIODIC_HEAL" then
		Pulse:FireIfEnabled("healReceived")
	elseif messageType == "HONOR_GAINED" then
		Pulse:FireIfEnabled("honorGained")
	elseif messageType == "FACTION" then
		Pulse:FireIfEnabled("factionGained")
	end
end)

-- Combo points: UNIT_POWER_UPDATE with powerType "COMBO_POINTS", filtered to an actual
-- increase so a reset to zero after a finisher is ignored.

local COMBO_POINTS_POWER_TYPE = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
local comboFrame = CreateFrame("Frame")
local lastComboPoints = 0

local function syncComboPoint()
	comboFrame:UnregisterAllEvents()
	lastComboPoints = 0
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("comboPoint") then
		return
	end
	comboFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	-- Seed from live state, not 0: enabling mid-combo should not treat the existing count
	-- as a fresh gain.
	local current = UnitPower("player", COMBO_POINTS_POWER_TYPE)
	lastComboPoints = (not issecretvalue(current) and type(current) == "number") and current or 0
end

comboFrame:SetScript("OnEvent", function(_, event, unit, powerType)
	if powerType ~= "COMBO_POINTS" then
		return
	end
	local current = UnitPower("player", COMBO_POINTS_POWER_TYPE)
	if issecretvalue(current) or type(current) ~= "number" then
		return
	end
	if current > lastComboPoints then
		Pulse:FireIfEnabled("comboPoint")
	end
	lastComboPoints = current
end)

-- Casting texture — held continuously between START and STOP/FAILED/INTERRUPTED.

local castFrame = CreateFrame("Frame")
local isCasting = false
local isChanneling = false

-- Hand-rolled fallback implementation since native math.clamp is unavailable on this client

local function clamp01(v)
	if v < 0 then
		return 0
	end
	if v > 1 then
		return 1
	end
	return v
end

-- A standard cast swells toward completion; a channel holds a steady hum. UnitCastingInfo
-- times are milliseconds, converted against GetTime()'s seconds via *1000. Payload reads
-- are issecretvalue-guarded.

local function castTick()
	-- A craft is its own sensation (Modules/Crafting.lua) and a craft IS a cast, so without
	-- this both textures run on one channel and the engine max-blends them into something
	-- neither was tuned for. Suppression rather than blending: one action, one feeling.
	if Pulse.IsCrafting and Pulse.IsCrafting() then
		return
	end

	-- After the craft guard, not before: this runs every frame and nothing below emits
	-- during a craft.
	local presence = Pulse.Database:GetTriggerSetting("castTexture", "castPresence", 0.1)

	if isCasting then
		local name, _, _, startTimeMs, endTimeMs = UnitCastingInfo("player")
		if not name then
			-- Cast has ended or was cancelled: prevent state desync and buzzing
			isCasting = false
			return
		end
		if
			not issecretvalue(startTimeMs)
			and not issecretvalue(endTimeMs)
			and startTimeMs
			and endTimeMs
			and endTimeMs > startTimeMs
		then
			local progress = clamp01((GetTime() * 1000 - startTimeMs) / (endTimeMs - startTimeMs))
			local peak = Pulse.Database:GetTriggerSetting("castTexture", "castSwellPeak", 0.7)
			Pulse:HoldIfEnabled("castTexture", presence, progress * peak)
		else
			-- Secret value / missing timestamp fallback: ensure the motor never goes silent
			Pulse:HoldIfEnabled("castTexture", presence, presence * 1.5)
		end
	elseif isChanneling then
		local name = UnitChannelInfo and UnitChannelInfo("player")
		if not name then
			isChanneling = false
			return
		end
		local hum = Pulse.Database:GetTriggerSetting("castTexture", "channelHum", 0.2)
		local value = Pulse.Haptics.MicroFlutter(hum)
		Pulse:HoldIfEnabled("castTexture", presence, value)
	end
end

local function syncCast()
	isCasting = false
	isChanneling = false
	castFrame:SetScript("OnUpdate", nil)
	if not Pulse.Database:Get("masterEnabled") or not Pulse.Database:GetCue("castTexture") then
		if Pulse.CastActivity and Pulse.CastActivity.SetActive then
			Pulse.CastActivity:SetActive("combat", false)
		end
		return
	end

	if Pulse.CastActivity and Pulse.CastActivity.SetActive then
		Pulse.CastActivity:SetActive("combat", true)
	end

	-- Seed from live state: if mid-cast or mid-channel, resume rather than dropping the sensation
	if type(UnitCastingInfo) == "function" and UnitCastingInfo("player") then
		isCasting = true
	elseif type(UnitChannelInfo) == "function" and UnitChannelInfo("player") then
		isChanneling = true
	end

	castFrame:SetScript("OnUpdate", castTick)
end

if Pulse.CastActivity and Pulse.CastActivity.OnActivity then
	Pulse.CastActivity:OnActivity(function(activity)
		local c = activity.classification
		if c == "CAST_START" or c == "CRAFT_CAST_START" then
			isCasting = true
			isChanneling = false
		elseif c == "CHANNEL_START" then
			isCasting = false
			isChanneling = true
		elseif
			c == "CAST_COMPLETE"
			or c == "CAST_STOPPED"
			or c == "INSTANT"
			or c == "CHANNEL_STOP"
			or c == "FAILED"
			or c == "INTERRUPTED"
			or c == "CRAFT_STOPPED"
		then
			isCasting = false
			isChanneling = false
		end
	end)
end

-- Ranged auto-repeat start/stop: class-agnostic (Auto Shot, Shoot, wands), kept separate
-- from the per-arrow trigger so the two tune independently.

local autoRepeatFrame = CreateFrame("Frame")

local function syncAutoRepeat()
	autoRepeatFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not (Pulse.Database:GetCue("autoRepeatStart") or Pulse.Database:GetCue("autoRepeatStop")) then
		return
	end
	autoRepeatFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
	autoRepeatFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
end

autoRepeatFrame:SetScript("OnEvent", function(_, event)
	if event == "START_AUTOREPEAT_SPELL" then
		Pulse:FireIfEnabled("autoRepeatStart")
	else
		Pulse:FireIfEnabled("autoRepeatStop")
	end
end)

-- Melee auto-attack start/stop: PLAYER_ENTER_COMBAT / PLAYER_LEAVE_COMBAT, which are
-- distinct from the general combat-state events. A separate cue pair from ranged, so the
-- two configure independently.

local meleeAttackFrame = CreateFrame("Frame")

local function syncMeleeAttack()
	meleeAttackFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not (Pulse.Database:GetCue("meleeAttackStart") or Pulse.Database:GetCue("meleeAttackStop")) then
		return
	end
	meleeAttackFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
	meleeAttackFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
end

meleeAttackFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTER_COMBAT" then
		Pulse:FireIfEnabled("meleeAttackStart")
	else
		Pulse:FireIfEnabled("meleeAttackStop")
	end
end)

-- Auto Shot per-arrow tap: UNIT_SPELLCAST_SUCCEEDED with spell 75. Melee is not tracked
-- this way — COMBAT_LOG_EVENT_UNFILTERED errors on registration on this client, and
-- speed-based estimation drifts.

local AUTO_SHOT_SPELL_ID = 75

local autoShotFrame = CreateFrame("Frame")

local function syncAutoShot()
	autoShotFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("autoShotFired") then
		return
	end
	autoShotFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

autoShotFrame:SetScript("OnEvent", function(_, event, ...)
	local _, _, spellID = ...
	if spellID == AUTO_SHOT_SPELL_ID then
		Pulse:FireIfEnabled("autoShotFired")
	end
end)

-- Weapon swing sync — an out-of-combat speed cache with a constant fallback, working
-- around combat restrictions by remembering speeds read while they were readable.

local swingFrame = CreateFrame("Frame")
local mainNextSwing, offNextSwing = nil, nil
local wasSwingActive = false

-- Current melee haste multiplier (1.0 = 0% haste).
--
-- GetMeleeHaste is reached through a type check and a pcall (2026-09-21). It sits on the
-- PLAYER_LOGIN path and swingTick reaches it from an OnUpdate, so an absent function would
-- throw once at login and then once per frame while attacking. RULE E: a missing read
-- degrades to "assume no haste", never to an error.
local function getHasteMultiplier()
	if type(GetMeleeHaste) ~= "function" then
		return 1.0
	end
	local ok, haste = pcall(GetMeleeHaste)
	if not ok then
		return 1.0
	end
	if issecretvalue(haste) or type(haste) ~= "number" or haste < -90 then
		return 1.0
	end
	return 1.0 + (haste / 100)
end

-- Out-of-combat unhasted base speed caches updated whenever UnitAttackSpeed is safely readable
local cachedMainBaseSpeed, cachedOffBaseSpeed = nil, nil

-- Lifecycle events keeping the out-of-combat cache fresh. Registered by syncSwing rather
-- than at file scope (2026-09-21), because registering unconditionally meant work at every
-- login and gear swap with both weapon-swing cues and the master switch off.
swingFrame:SetScript("OnEvent", function(self, event, ...)
	local success, main, off = pcall(UnitAttackSpeed, "player")
	local mult = getHasteMultiplier()
	if success and not issecretvalue(main) and type(main) == "number" and main > 0 then
		cachedMainBaseSpeed = main * mult
	end
	if success and not issecretvalue(off) and type(off) == "number" and off > 0 then
		cachedOffBaseSpeed = off * mult
	end
end)

local STUN_LOC_TYPES = { STUN = true, STUN_MECHANIC = true }

local function isPlayerStunned()
	local count = C_LossOfControl.GetActiveLossOfControlDataCount()
	if issecretvalue(count) or not count then
		return false
	end
	for index = 1, count do
		local data = C_LossOfControl.GetActiveLossOfControlData(index)
		if issecretvalue(data) then
			return false
		end
		if data then
			local locType = data.locType
			if issecretvalue(locType) then
				return false
			end
			if STUN_LOC_TYPES[locType] then
				return true
			end
		end
	end
	return false
end

-- Safely retrieves weapon speeds, utilizing base speed cache scaled by dynamic melee haste
local function GetActiveWeaponSpeeds()
	local success, main, off = pcall(UnitAttackSpeed, "player")
	local mult = getHasteMultiplier()

	-- Cache unhasted base speeds whenever live values are readable
	if success and not issecretvalue(main) and type(main) == "number" and main > 0 then
		cachedMainBaseSpeed = main * mult
	end
	if success and not issecretvalue(off) and type(off) == "number" and off > 0 then
		cachedOffBaseSpeed = off * mult
	end

	-- Determine main-hand speed: Live -> Cache (Haste Scaled) -> constant fallback.
	--
	-- fallbackMain is 2.6s, the standard unhasted base speed of one-handed weapons. It is
	-- scaled by dynamic melee haste (divided by mult) so hasted characters attack faster
	-- even when using the fallback estimate.
	local fallbackMain = 2.6
	local activeMain
	if success and not issecretvalue(main) and type(main) == "number" and main > 0 then
		activeMain = main
	else
		local base = cachedMainBaseSpeed or fallbackMain
		activeMain = base / mult
	end

	-- Determine off-hand speed: Live -> Cache (Haste Scaled) -> Nil
	local activeOff
	if success and not issecretvalue(off) and type(off) == "number" and off > 0 then
		activeOff = off
	elseif cachedOffBaseSpeed then
		activeOff = cachedOffBaseSpeed / mult
	end

	return activeMain, activeOff
end

applyParryHaste = function()
	if not mainNextSwing then
		return
	end
	if Pulse.Database:GetTriggerSetting("weaponSwingMain", "parryHasteEnabled", 1) ~= 1 then
		return
	end

	local mainSpeed = GetActiveWeaponSpeeds()
	if not mainSpeed or mainSpeed <= 0 then
		return
	end

	local now = GetTime()
	local remaining = mainNextSwing - now
	local reduced = math.max(remaining - mainSpeed * 0.4, mainSpeed * 0.2)
	mainNextSwing = now + reduced
end

local function swingTick()
	local attacking = C_Spell.IsCurrentSpell(6603)
	if issecretvalue(attacking) then
		attacking = false
	end
	local inRange = UnitExists("target") and CheckInteractDistance("target", 3)
	if issecretvalue(inRange) then
		inRange = false
	end
	local active = attacking and inRange and not isPlayerStunned()

	if active and not wasSwingActive then
		local mainSpeed, offSpeed = GetActiveWeaponSpeeds()
		local now = GetTime()

		if mainSpeed and mainSpeed > 0 then
			Pulse:FireIfEnabled("weaponSwingMain")
			mainNextSwing = now + mainSpeed
		end
		if offSpeed and offSpeed > 0 then
			Pulse:FireIfEnabled("weaponSwingOff")
			offNextSwing = now + offSpeed
		end
	elseif not active and wasSwingActive then
		mainNextSwing, offNextSwing = nil, nil
	elseif active then
		local now = GetTime()
		if mainNextSwing and now >= mainNextSwing then
			Pulse:FireIfEnabled("weaponSwingMain")
			local mainSpeed = GetActiveWeaponSpeeds()
			mainNextSwing = now + (mainSpeed or 2.6)
		end
		if offNextSwing and now >= offNextSwing then
			Pulse:FireIfEnabled("weaponSwingOff")
			local _, offSpeedDynamic = GetActiveWeaponSpeeds()
			offNextSwing = now + (offSpeedDynamic or 2.6)
		end
	end

	wasSwingActive = active
end

-- PLAYER_SWING — the real signal, and the primary source as of 2026-09-21
--
-- Forever exposes a swing-timer event carrying (swingDuration, swingType), swingType being
-- one of Enum.PlayerSwingType.MainHand / OffHand / Ranged, which Blizzard's own swing-timer
-- UI consumes. Both arguments CONFIRMED NON-SECRET by a diagnostic addon, and a proof of
-- concept drove C_GamePad.SetVibration from it on the live client ("Forever PLAYER_SWING
-- Discovery — Weapon Swing Haptic Cue Proposal.md").
--
-- This retires the reason the estimator below exists: it predicted swing times from
-- UnitAttackSpeed because melee had no per-swing event and the combat log is closed to
-- addons, needing a haste cache, a range check, a stun check and a parry-haste correction,
-- and still drifting with nothing to correct against.
--
-- SEMANTIC CAVEAT, UNRESOLVED: this is a SWING, not necessarily a connection. Whether it
-- also fires on a miss, dodge or parry is UNTESTED (§8 of the discovery doc). For a
-- weapon-swing cue that is arguably correct; a "successful hit" cue would need a different
-- source, and the combat log is still shut.
--
-- Ranged swings are deliberately not wired: autoShotFired already covers Auto Shot through
-- UNIT_SPELLCAST_SUCCEEDED, and firing both would double every shot. Enum.PlayerSwingType
-- .Ranged is available here if that cue is ever rebuilt on this event instead.
local swingEventFrame = CreateFrame("Frame")

local function swingTypeValue(name, fallback)
	local enum = Enum and Enum.PlayerSwingType
	local value = enum and enum[name]
	if type(value) == "number" then
		return value
	end
	return fallback
end

swingEventFrame:SetScript("OnEvent", function(_, _, swingDuration, swingType)
	if issecretvalue(swingType) then
		return
	end
	if swingType == swingTypeValue("MainHand", 0) then
		Pulse:FireIfEnabled("weaponSwingMain")
	elseif swingType == swingTypeValue("OffHand", 1) then
		Pulse:FireIfEnabled("weaponSwingOff")
	end
end)

-- Is the real event there? C_EventUtils.IsEventValid, used the same way in
-- Modules/ControllerUI.lua. Checked live rather than cached at load, so if a patch removes
-- PLAYER_SWING the estimator returns on the next settings change or reload rather than
-- waiting for someone to notice the silence.
local function swingEventAvailable()
	if not (C_EventUtils and type(C_EventUtils.IsEventValid) == "function") then
		return false
	end
	local ok, valid = pcall(C_EventUtils.IsEventValid, "PLAYER_SWING")
	return (ok and valid) and true or false
end

local function syncSwing()
	swingFrame:SetScript("OnUpdate", nil)
	swingFrame:UnregisterAllEvents()
	swingEventFrame:UnregisterAllEvents()
	mainNextSwing, offNextSwing = nil, nil
	wasSwingActive = false
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not (Pulse.Database:GetCue("weaponSwingMain") or Pulse.Database:GetCue("weaponSwingOff")) then
		return
	end

	-- Two ways to end up on the estimator: the event is gone (a patch), or the player
	-- chose it. Anything else uses the real signal.
	local forced = Pulse.Database:GetTriggerSetting("weaponSwingMain", "forceEstimator", 0) == 1
	if not forced and swingEventAvailable() then
		swingEventFrame:RegisterEvent("PLAYER_SWING")
		if Pulse.debug then
			print("Pulse: weapon swings using PLAYER_SWING (measured)")
		end
		return
	end

	if Pulse.debug then
		print(
			("Pulse: weapon swings using the estimator (%s)"):format(
				forced and "forced by setting" or "PLAYER_SWING unavailable"
			)
		)
	end
	swingFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	swingFrame:RegisterEvent("PLAYER_LOGIN")
	swingFrame:SetScript("OnUpdate", swingTick)
end

-- Proc Glow — SPELL_ACTIVATION_OVERLAY_GLOW_SHOW
-- Fires when a reactive spell or talent lights up on the action bar.
local procGlowFrame = CreateFrame("Frame")

local function syncProcGlow()
	procGlowFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("procGlow") then
		return
	end
	procGlowFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
end

procGlowFrame:SetScript("OnEvent", function()
	Pulse:FireIfEnabled("procGlow")
end)

-- Melee Swing Range — C_SwingTimer.EnableRangeCheck & PLAYER_SWING_RANGE_UPDATE
-- Informs the player when entering or leaving auto-attack melee range.
local meleeRangeFrame = CreateFrame("Frame")
local wasInRange = nil

local function syncMeleeRange()
	meleeRangeFrame:UnregisterAllEvents()
	wasInRange = nil
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	local wantRange = Pulse.Database:GetCue("meleeRangeIn") or Pulse.Database:GetCue("meleeRangeOut")
	if not wantRange then
		if C_SwingTimer and type(C_SwingTimer.EnableRangeCheck) == "function" then
			pcall(C_SwingTimer.EnableRangeCheck, 0, false)
		end
		return
	end

	if C_SwingTimer and type(C_SwingTimer.EnableRangeCheck) == "function" then
		pcall(C_SwingTimer.EnableRangeCheck, 0, true)
		meleeRangeFrame:RegisterEvent("PLAYER_SWING_RANGE_UPDATE")
		meleeRangeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	end
end

meleeRangeFrame:SetScript("OnEvent", function(_, event, swingType, isInRange, checksRange)
	if event == "PLAYER_TARGET_CHANGED" then
		wasInRange = nil
		return
	end
	if event == "PLAYER_SWING_RANGE_UPDATE" then
		if swingType ~= 0 or not checksRange then
			return
		end
		if wasInRange == nil then
			wasInRange = isInRange
			return
		end
		if isInRange and not wasInRange then
			wasInRange = true
			Pulse:FireIfEnabled("meleeRangeIn")
		elseif not isInRange and wasInRange then
			wasInRange = false
			Pulse:FireIfEnabled("meleeRangeOut")
		end
	end
end)

function M:OnEnable()
	Pulse:BindFrame({ "abilityPulse" }, syncAbilityPulse)
	Pulse:BindFrame({
		"critLanded",
		"deflect",
		"damageTaken",
		"honorGained",
		"factionGained",
		"healCrit",
		"healReceived",
		"debuffReceived",
	}, syncCombatText)
	Pulse:BindFrame({ "comboPoint" }, syncComboPoint)
	Pulse:BindFrame({ "castTexture" }, syncCast)
	Pulse:BindFrame({ "cooldownReady" }, syncCooldownReady)
	Pulse:BindFrame({ "autoRepeatStart", "autoRepeatStop" }, syncAutoRepeat)
	Pulse:BindFrame({ "meleeAttackStart", "meleeAttackStop" }, syncMeleeAttack)
	Pulse:BindFrame({ "autoShotFired" }, syncAutoShot)
	Pulse:BindFrame({ "weaponSwingMain", "weaponSwingOff" }, syncSwing)
	Pulse:BindFrame({ "procGlow" }, syncProcGlow)
	Pulse:BindFrame({ "meleeRangeIn", "meleeRangeOut" }, syncMeleeRange)
end

function M:_DebugCombat()
	return {
		inCombat = InCombatLockdown() and true or false,
		isCasting = isCasting,
		isChanneling = isChanneling,
		swingSource = swingEventAvailable() and "event" or "estimator",
		cooldownSetResolved = cooldownSetResolved,
		wasMeleeInRange = wasInRange,
	}
end
