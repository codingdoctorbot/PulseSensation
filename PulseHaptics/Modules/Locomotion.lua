-- Pulse — Modules/Locomotion.lua
--
-- Footfall and gait texture: walking, running, mounted, shapeshifted. Built from the WoW
-- Forever proof of concept in Locomotion:Running/.
--
-- RACE DETERMINES THE MOUNT ON THIS CLIENT. The roster is the eight classic races plus
-- Skyborne, every race rides its own racial mount, and there are no flying or aquatic
-- mounts — so RACE_GAITS' `mount` field is a lookup rather than a guess. On retail it would
-- be wrong.
--
-- Cadence and intensity are feel judgments, not measurements, but they describe something
-- real (a Tauren's run animation is slower and heavier than a Gnome's) and every one is
-- reachable from a slider.
--
-- Three design rules:
--
--   resolve on movement start, not per frame — race, mount, armour, form and speed are read
--       when PLAYER_STARTED_MOVING fires, and again on mounting, shapeshifting or entering
--       combat. The per-frame path advances a phase and evaluates a waveform, nothing else.
--
--   speed is read OUT OF COMBAT ONLY — GetUnitSpeed can return a secret value in combat,
--       which caused a 766-repeat error in swimTexture. The last out-of-combat reading is
--       held and reused, so snares and boosts go untracked in combat: a deliberate trade
--       for never erroring and never going silent.
--
--   constants are cached and persisted — race, riding tier and boot weight go to
--       SavedVariables (Database's locomotionProfile), so a login where UnitRace or the item
--       cache is not warm still gets the right gait rather than a generic one all session.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Locomotion", M)

local CUE = "locomotion"
local INVSLOT_FEET = 8

-- Blizzard's nominal speeds, used only to turn an absolute speed into a ratio.
local BASE_RUN_SPEED = 7.0
local BASE_WALK_SPEED = 2.5
local WALK_RUN_BOUNDARY = 4.5

-- Character tables

-- The Forever roster. `mount` is the racial mount, which on this client is the only mount
-- that race will be on. Skyborne is the Forever-exclusive tenth.
local RACE_GAITS = {
	Human = { cadence = 1.00, intensity = 1.00, mount = "HORSE" },
	Dwarf = { cadence = 1.15, intensity = 1.15, mount = "RAM" },
	NightElf = { cadence = 0.90, intensity = 0.90, mount = "SABER" },
	Gnome = { cadence = 1.50, intensity = 0.60, mount = "MECHANOSTRIDER" },
	Orc = { cadence = 0.95, intensity = 1.15, mount = "WOLF" },
	Scourge = { cadence = 1.00, intensity = 0.90, mount = "UNDEAD_HORSE" },
	Tauren = { cadence = 0.75, intensity = 1.40, mount = "KODO" },
	Troll = { cadence = 0.90, intensity = 0.95, mount = "RAPTOR" },
	Skyborne = { cadence = 0.95, intensity = 0.85, mount = "HAWKSTRIDER" },
}

-- An unrecognised race token falls back to the elf profile rather than to nothing, per the
-- proof of concept. A light quadruped-rider is the least wrong guess for an unknown race.
local FALLBACK_RACE = { cadence = 0.90, intensity = 0.90, mount = "SABER" }

-- Note which gait each mount gets: raptors and hawkstriders are BIPEDAL, so they get
-- FOOTSTEP's clean alternation rather than GALLOP's offset hoof pair, and the
-- mechanostrider is a machine, so it gets the sawtooth.
local MOUNT_GAITS = {
	HORSE = { cadence = 1.8, intensity = 1.20, mode = "GALLOP", sharpness = 4 },
	UNDEAD_HORSE = { cadence = 1.7, intensity = 1.00, mode = "GALLOP", sharpness = 3 },
	WOLF = { cadence = 2.0, intensity = 1.10, mode = "GALLOP", sharpness = 4 },
	SABER = { cadence = 2.1, intensity = 1.00, mode = "GALLOP", sharpness = 3 },
	RAM = { cadence = 1.9, intensity = 1.25, mode = "GALLOP", sharpness = 4 },
	KODO = { cadence = 1.3, intensity = 1.60, mode = "GALLOP", sharpness = 5 },
	RAPTOR = { cadence = 2.2, intensity = 1.10, mode = "FOOTSTEP", sharpness = 4 },
	HAWKSTRIDER = { cadence = 2.4, intensity = 0.90, mode = "FOOTSTEP", sharpness = 3 },
	MECHANOSTRIDER = { cadence = 2.5, intensity = 1.00, mode = "MECHANICAL", sharpness = 5 },
}

-- Shapeshift form IDs, CONFIRMED against Blizzard's own Blizzard_FrameXMLBase/Constants.lua
-- rather than inherited unverified, and the Classic set, which is what Forever uses. Read
-- through the named globals with the confirmed literal as fallback, so a renamed constant
-- costs nothing.
local function formID(name, literal)
	local value = _G[name]
	if type(value) == "number" then
		return value
	end
	return literal
end

local CAT = formID("DRUID_CAT_FORM", 1)
local TREE = formID("DRUID_TREE_FORM", 2)
local TRAVEL = formID("DRUID_TRAVEL_FORM", 3)
local AQUATIC = formID("DRUID_ACQUATIC_FORM", 4)
local BEAR = formID("DRUID_BEAR_FORM", 5)
local DIRE_BEAR = 8 -- Classic-only; absent from the retail constants file, harmless if it never fires
local GHOST_WOLF = formID("SHAMAN_GHOST_WOLF_FORM", 16)
local FLIGHT = formID("DRUID_FLIGHT_FORM", 27)
local STEALTH = formID("ROGUE_STEALTH", 30)
local MOONKIN_1 = formID("DRUID_MOONKIN_FORM_1", 31)
local MOONKIN_2 = formID("DRUID_MOONKIN_FORM_2", 35)

-- Forms with no footfalls. Without this, aquatic and flight forms fall through to the
-- bipedal branch and produce footsteps while swimming or flying. Swimming has waterTexture
-- and swimTexture, flight has glideThrust; a gait adds nothing to either.
local FORM_SILENT = {
	[AQUATIC] = true,
	[FLIGHT] = true,
}

-- Quadrupeds get GALLOP's offset hoof pair; bipeds get FOOTSTEP's clean alternation. That
-- distinction is the point of having a form table at all — a moonkin does not move like a
-- cat.
local FORM_GAITS = {
	[CAT] = { cadence = 1.30, intensity = 0.40, mode = "GALLOP", sharpness = 2 },
	[BEAR] = { cadence = 0.80, intensity = 1.50, mode = "GALLOP", sharpness = 6 },
	[DIRE_BEAR] = { cadence = 0.80, intensity = 1.60, mode = "GALLOP", sharpness = 6 },
	[TRAVEL] = { cadence = 1.40, intensity = 0.70, mode = "GALLOP", sharpness = 3 },
	[GHOST_WOLF] = { cadence = 1.35, intensity = 0.60, mode = "GALLOP", sharpness = 3 },
	-- Bipedal forms. Moonkin is a heavy two-legged caster, tree a slow one, rogue stealth
	-- an ordinary biped moving deliberately — soft and low, so creeping does not announce
	-- itself through the controller.
	[MOONKIN_1] = { cadence = 0.95, intensity = 1.10, mode = "FOOTSTEP", sharpness = 4 },
	[MOONKIN_2] = { cadence = 0.95, intensity = 1.10, mode = "FOOTSTEP", sharpness = 4 },
	[TREE] = { cadence = 0.85, intensity = 0.80, mode = "FOOTSTEP", sharpness = 3 },
	[STEALTH] = { cadence = 0.90, intensity = 0.35, mode = "FOOTSTEP", sharpness = 2 },
}

-- DELIBERATELY ABSENT, do not add them: PRIEST_SHADOWFORM (28) and the three warrior
-- stances (17/18/19) are returned by GetShapeshiftFormID but change nothing about how the
-- character moves. Listing them would override the racial gait with a generic one. Falling
-- through to the bipedal branch is correct, not an oversight.

-- Boot weight — the one character factor that is not a feel judgment: item subclass is a
-- fact about the item, read through Enum.ItemClass.Armor rather than a hardcoded 4. Cached
-- on equipment change, so it costs nothing per frame.
local ARMOR_WEIGHT = { [1] = 0.7, [2] = 0.9, [3] = 1.1, [4] = 1.3 } -- cloth/leather/mail/plate
local BAREFOOT_WEIGHT = 0.6

-- Riding tiers. Apprentice and Journeyman are the two on a classic-shaped client; the ids
-- are inherited from the proof of concept and UNCONFIRMED.
--
-- DELIBERATELY NOT a speed multiplier. An epic mount moves faster and GetUnitSpeed already
-- reports it, in speedRatio. Multiplying cadence by the tier too would double-count and
-- give a 100% mount a comically fast stride. The tier is only a confidence nudge to how the
-- mount carries itself.
local RIDING_SPELLS = { [33388] = 1, [33391] = 2 }
local RIDING_CONFIDENCE = { [0] = 0.90, [1] = 1.00, [2] = 1.10 }

-- Cached character facts

local character = { race = "Human", ridingTier = 0, armorMultiplier = 1.0 }

local function loadPersisted()
	local saved = Pulse.Database:GetLocomotionProfile()
	if saved then
		character.race = saved.race or character.race
		character.ridingTier = saved.ridingTier or 0
		character.armorMultiplier = saved.armorMultiplier or 1.0
	end
end

local function refreshRace()
	if type(UnitRace) ~= "function" then
		return
	end
	local ok, _, raceToken = pcall(UnitRace, "player")
	if not ok or issecretvalue(raceToken) or type(raceToken) ~= "string" then
		return
	end
	character.race = raceToken
end

local function refreshRidingTier()
	local tier = 0
	if C_Spell and type(C_Spell.IsSpellKnownOrOverridesKnown) == "function" then
		for spellID, spellTier in pairs(RIDING_SPELLS) do
			local ok, known = pcall(C_Spell.IsSpellKnownOrOverridesKnown, spellID)
			if ok and known and spellTier > tier then
				tier = spellTier
			end
		end
	elseif type(IsSpellKnown) == "function" then
		for spellID, spellTier in pairs(RIDING_SPELLS) do
			local ok, known = pcall(IsSpellKnown, spellID)
			if ok and known and spellTier > tier then
				tier = spellTier
			end
		end
	end
	character.ridingTier = tier
end

local function refreshArmorWeight()
	if type(GetInventoryItemID) ~= "function" then
		return
	end
	local ok, itemID = pcall(GetInventoryItemID, "player", INVSLOT_FEET)
	if not ok then
		return
	end
	if not itemID then
		character.armorMultiplier = BAREFOOT_WEIGHT
		return
	end
	if not (C_Item and type(C_Item.GetItemInfoInstant) == "function") then
		return
	end
	local okInfo, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemID)
	if not okInfo then
		return
	end
	local armorClass = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
	if classID == armorClass then
		character.armorMultiplier = ARMOR_WEIGHT[subclassID] or 1.0
	else
		character.armorMultiplier = 1.0
	end
end

local function persist()
	Pulse.Database:SetLocomotionProfile(character.race, character.ridingTier, character.armorMultiplier)
end

-- Gait waveforms. Each returns two values that alternate: left, right.

local function gaitWaveform(mode, phase, intensity, sharpness)
	local peak = intensity
	if peak < 0 then
		peak = 0
	elseif peak > 1 then
		peak = 1
	end

	if mode == "GALLOP" then
		-- Two hooves, the trailing one offset, so the pair lands as a rolling double.
		local lead = math.abs(math.sin(phase))
		local trail = math.abs(math.sin(phase - 0.6))
		return (lead ^ sharpness) * peak, (trail ^ sharpness) * peak
	elseif mode == "MECHANICAL" then
		-- A sawtooth per half cycle: rises and resets rather than swelling and fading.
		-- Reachable again now that Gnome resolves to MECHANOSTRIDER.
		local norm = (phase / (math.pi * 2)) % 1.0
		local left = (norm < 0.5) and (((norm * 2) ^ sharpness) * peak) or 0
		local right = (norm >= 0.5) and ((((norm - 0.5) * 2) ^ sharpness) * peak) or 0
		return left, right
	end

	-- FOOTSTEP: one foot at a time, clean alternation. Bipeds, on foot or mounted.
	local left = math.max(0, math.sin(phase))
	local right = math.max(0, -math.sin(phase))
	return (left ^ sharpness) * peak, (right ^ sharpness) * peak
end

-- Gait resolution — runs on movement start, not per frame

local gait = { mode = "FOOTSTEP", cadence = 2.8, intensity = 0.35, sharpness = 4, valid = false }
local inCombat = false
local lastGoodSpeed = BASE_RUN_SPEED

local function setting(key, default)
	return Pulse.Database:GetTriggerSetting(CUE, key, default)
end

-- Out of combat, read it. In combat, reuse the last out-of-combat reading: GetUnitSpeed can
-- come back secret there, and comparing a secret throws rather than reading nil.
local function resolveSpeed()
	if inCombat then
		return lastGoodSpeed
	end
	if type(GetUnitSpeed) ~= "function" then
		return lastGoodSpeed
	end
	local ok, speed = pcall(GetUnitSpeed, "player")
	if not ok or issecretvalue(speed) or type(speed) ~= "number" then
		return lastGoodSpeed
	end
	if speed > 0.05 then
		lastGoodSpeed = speed
	end
	return speed
end

local function resolveGait()
	local speed = resolveSpeed()
	if speed <= 0.05 then
		gait.valid = false
		return
	end

	local speedRatio = speed / BASE_RUN_SPEED
	local isWalking = speed < WALK_RUN_BOUNDARY
	local race = RACE_GAITS[character.race] or FALLBACK_RACE

	local runCadence = setting("runCadence", 2.8)
	local walkCadence = setting("walkCadence", 1.8)
	local baseIntensity = setting("gaitIntensity", 0.35)

	local currentForm = (type(GetShapeshiftFormID) == "function") and GetShapeshiftFormID() or nil

	-- Checked before anything else: a druid in aquatic form is also "moving" and would
	-- otherwise get footsteps underwater.
	if currentForm and FORM_SILENT[currentForm] then
		gait.valid = false
		return
	end

	local form = currentForm and FORM_GAITS[currentForm]

	if form then
		gait.mode = form.mode
		-- Walking in form softens the strike as well as slowing it.
		gait.sharpness = isWalking and math.max(2, form.sharpness - 1) or form.sharpness
		gait.cadence = isWalking and (walkCadence * (speed / BASE_WALK_SPEED))
			or (runCadence * form.cadence * speedRatio)
		gait.intensity = baseIntensity * form.intensity
	elseif IsMounted and IsMounted() then
		local mount = MOUNT_GAITS[race.mount] or MOUNT_GAITS.SABER
		local confidence = RIDING_CONFIDENCE[character.ridingTier] or 1.0
		gait.mode = mount.mode
		gait.sharpness = isWalking and math.max(2, mount.sharpness - 1) or mount.sharpness
		gait.cadence = isWalking and (walkCadence * 1.1 * (speed / BASE_WALK_SPEED))
			or (runCadence * mount.cadence * speedRatio * confidence)
		gait.intensity = baseIntensity * mount.intensity * setting("mountIntensity", 1.2)
	else
		gait.mode = "FOOTSTEP"
		if isWalking then
			gait.cadence = walkCadence * (speed / BASE_WALK_SPEED)
			gait.sharpness = 3
			gait.intensity = baseIntensity * race.intensity * character.armorMultiplier * 0.6
		else
			gait.cadence = runCadence * race.cadence * speedRatio
			gait.sharpness = 4
			-- Faster hits harder, with diminishing return rather than proportionally.
			local force = math.min(1.5, 0.4 + (speedRatio * 0.6))
			gait.intensity = baseIntensity * race.intensity * character.armorMultiplier * force
		end
	end

	if gait.cadence > 8.0 then
		gait.cadence = 8.0
	elseif gait.cadence <= 0 then
		gait.cadence = 1.0
	end
	gait.valid = true
end

-- Per-frame: advance the phase, evaluate, emit. Nothing else.

local runPhase = 0
local isMoving = false
local pollFrame = CreateFrame("Frame")

-- How often the gait is re-resolved while moving OUT of combat. Twice a second, not sixty:
-- "resolve on movement start, not per frame" still holds. Two reasons it exists at all —
-- PLAYER_STARTED_MOVING fires the instant movement begins, when GetUnitSpeed still reads 0
-- and the resolve therefore fails (the "works in combat only" silence, 2026-09-21); and
-- out-of-combat speed changes such as sprint effects would otherwise leave a stale cadence.
-- In combat nothing re-resolves: speed is deliberately held (see resolveSpeed).
local RESOLVE_INTERVAL = 0.5
local resolveElapsed = 0

-- Split the stride across two actuators only when the controller HAS two suitable ones:
-- asked for by the setting, vetoed by the hardware.
--
-- WHY THE VETO MATTERS. Split sends left to ltrigger and right to rtrigger. On a pad
-- without trigger motors — DualShock 4, Switch Pro, Steam Deck, anything unidentified —
-- Engine.lua's ROLE_FALLBACK sends those to Low and High, and under Standard High is the
-- physically stronger motor, so every right footfall hits harder than every left. A limp
-- rather than a gait, worse than not splitting.
--
-- Defaults to not splitting, because "Generic / unknown" declares no trigger actuators;
-- naming your controller on the calibration page turns it on if the hardware supports it.
local function shouldSplitFeet()
	if setting("splitFeet", 1) ~= 1 then
		return false
	end
	local preset = Pulse.Devices and Pulse.Devices[Pulse.Database:GetDevicePreset()]
	if preset and preset.triggers ~= true then
		return false
	end
	return true
end

-- Ground contact

-- How long after a jump input the ascent is assumed still in progress.
--
-- Needed because IsFalling() is FALSE WHILE RISING — not a guess, Movement.lua's landing
-- poll relies on the same fact. Without this window the first half of every jump would
-- still produce footfalls and the second half would not.
--
-- The number IS a guess: a jump arc is roughly a second, the rise roughly half. Erring long
-- on purpose, because a missing footfall is less wrong than one in mid-air.
local JUMP_ASCENT_GRACE = 0.45
local lastJumpAt = -1000

-- Unconditional, like Movement.lua's hook on the same function: one timestamp write is
-- cheaper than bookkeeping to attach and detach it with the cue. hooksecurefunc chains, so
-- Movement's hook is unaffected.
if type(hooksecurefunc) == "function" and type(_G.JumpOrAscendStart) == "function" then
	hooksecurefunc("JumpOrAscendStart", function()
		if IsSwimming and IsSwimming() then
			return
		end
		if _G.HasFullControl and not _G.HasFullControl() then
			return
		end
		if not IsFalling() and not IsFlying() then
			lastJumpAt = GetTime()
		end
	end)
end

-- States in which the character has no ground contact and therefore no footfalls.
--
-- Polled per frame rather than resolved on an event, because none of these HAS a reliable
-- event: you can enter water, take off or jump while already moving, and
-- PLAYER_STARTED_MOVING does not fire again for any of them.
--
-- Deliberately NOT folded into resolveGait. Whether a gait applies now is a physical fact
-- changing many times a second; what the gait IS changes rarely. Separating them also keeps
-- the cost at four boolean calls a frame rather than a full resolve a frame — an invalid
-- gait makes tick() retry until it succeeds, and while swimming it never would.
local function hasGroundContact()
	-- Swimming has waterTexture for buoyancy and swimTexture for effort; a gait adds
	-- nothing. Same reasoning as FORM_SILENT above, which covers only a druid.
	if type(IsSwimming) == "function" and IsSwimming() then
		return false
	end

	-- Flight and Skyriding's glide. GetGlidingInfo is the confirmed-live check glideThrust
	-- already uses (Modules/Flight.lua), so the two agree about what gliding means. IsFlying
	-- covers ordinary flight and a taxi ride, which taxiRide already textures.
	if type(IsFlying) == "function" and IsFlying() then
		return false
	end
	if C_PlayerInfo and type(C_PlayerInfo.GetGlidingInfo) == "function" then
		local ok, gliding = pcall(C_PlayerInfo.GetGlidingInfo)
		if ok and gliding == true then
			return false
		end
	end

	-- Falling covers the descent; the jump hook above covers the rise.
	if type(IsFalling) == "function" and IsFalling() then
		return false
	end
	if (GetTime() - lastJumpAt) < JUMP_ASCENT_GRACE then
		return false
	end

	return true
end

local wasGrounded = true
local splitRoles = { ltrigger = 0, rtrigger = 0 }

local function tick(_, elapsed)
	if not isMoving then
		pollFrame:SetScript("OnUpdate", nil)
		return
	end

	-- Checked before the resolve: with no ground contact there is nothing to resolve and
	-- nothing to emit. Not emitting IS the mechanism — the layer decays within one refresh
	-- window (Core/Engine.lua's Hold model) and the cue owning that state takes over.
	--
	-- The phase is left where it is rather than reset: resuming mid-stride is what a jump
	-- feels like, and resetting to zero would put the first footfall exactly on the
	-- landing, where landingSoft/landingHard already fires.
	if not hasGroundContact() then
		wasGrounded = false
		return
	end

	if not wasGrounded then
		wasGrounded = true
		-- Whatever was resolved before the water or the glide is stale — you can enter
		-- running and come out walking. Re-resolve rather than wait out the interval.
		resolveElapsed = 0
		if not inCombat then
			resolveGait()
		end
	end

	-- Keep trying until speed is readable: an invalid gait right after movement starts is
	-- the normal case, not an error.
	if not gait.valid then
		if inCombat then
			return
		end -- combat holds whatever was last resolved
		resolveGait()
		if not gait.valid then
			return
		end
		runPhase = 0 -- begin the stride on a footfall
	else
		resolveElapsed = resolveElapsed + (elapsed or 0)
		if resolveElapsed >= RESOLVE_INTERVAL then
			resolveElapsed = 0
			if not inCombat then
				resolveGait()
			end
		end
	end

	if setting("mountedOnly", 1) == 1 and not (IsMounted and IsMounted()) then
		return
	end

	-- Cadence is real steps per second, and the phase accumulates elapsed time rather than
	-- counting ticks, so the stride holds its rate at any frame rate.
	runPhase = (runPhase + (elapsed or 0) * gait.cadence * math.pi * 2) % (math.pi * 2)

	local left, right = gaitWaveform(gait.mode, runPhase, gait.intensity, gait.sharpness)

	if shouldSplitFeet() then
		-- Left and right to separate roles, so the gait walks across the pad.
		-- Reused table to prevent GC allocation in high-frequency tick loop (Rule 4).
		splitRoles.ltrigger = left
		splitRoles.rtrigger = right
		Pulse:HoldRolesIfEnabled(CUE, splitRoles, 0.2)
	else
		-- Both feet through ONE role, which is what "do not split" has to mean.
		--
		-- max() rather than left+right: the two waveforms are opposite halves of one cycle
		-- and never overlap, so max is "whichever foot is currently down" and keeps every
		-- footfall the same strength.
		--
		-- The LOW role on purpose. A sustained texture runs for as long as you are moving,
		-- and under Standard the high motor is the physically stronger one — driving it at
		-- ~3 footfalls a second for a whole journey would be exhausting. The large slow
		-- mass is the right home for a background gait, and its Strength slider can trim
		-- it.
		Pulse:HoldIfEnabled(CUE, math.max(left, right), 0, 0.2)
	end
end

-- Events

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_ENTERING_WORLD" then
		refreshRace()
		refreshRidingTier()
		refreshArmorWeight()
		persist()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if arg1 == INVSLOT_FEET then
			refreshArmorWeight()
			persist()
			if isMoving then
				resolveGait()
			end
		end
	elseif event == "LEARNED_SPELL_IN_TAB" or event == "SPELLS_CHANGED" then
		refreshRidingTier()
		persist()
	elseif event == "PLAYER_STARTED_MOVING" then
		isMoving = true
		runPhase = 0 -- always begin a stride on a footfall, never mid-air
		resolveElapsed = 0
		-- May well fail: GetUnitSpeed still reads 0 at this instant. tick() retries.
		resolveGait()
		if Pulse.Database:Get("masterEnabled") and Pulse.Database:GetCue(CUE) then
			pollFrame:SetScript("OnUpdate", tick)
		end
	elseif event == "PLAYER_STOPPED_MOVING" then
		isMoving = false
		pollFrame:SetScript("OnUpdate", nil)
		runPhase = 0
		gait.valid = false
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Take one last honest speed reading on the way in, then hold it for the fight.
		resolveSpeed()
		inCombat = true
		if isMoving then
			resolveGait()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		if isMoving then
			resolveGait()
		end
	else
		-- PLAYER_MOUNT_DISPLAY_CHANGED / UPDATE_SHAPESHIFT_FORM. Neither
		-- PLAYER_STARTED_MOVING nor STOPPED fires when you mount or shift mid-stride, so
		-- without these the gait goes stale and you keep feeling footsteps while riding.
		if isMoving then
			resolveGait()
		end
	end
end)

local EVENTS = {
	"PLAYER_ENTERING_WORLD",
	"PLAYER_EQUIPMENT_CHANGED",
	"PLAYER_STARTED_MOVING",
	"PLAYER_STOPPED_MOVING",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_MOUNT_DISPLAY_CHANGED",
	"UPDATE_SHAPESHIFT_FORM",
	"SPELLS_CHANGED",
}

local function sync()
	eventFrame:UnregisterAllEvents()
	pollFrame:SetScript("OnUpdate", nil)
	isMoving, runPhase = false, 0
	gait.valid = false
	wasGrounded = true

	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue(CUE) then
		return
	end

	loadPersisted()
	for _, event in ipairs(EVENTS) do
		pcall(eventFrame.RegisterEvent, eventFrame, event)
	end
	-- Seed from live state: enabling the cue while already running should not wait for the
	-- next PLAYER_STARTED_MOVING.
	refreshRace()
	refreshRidingTier()
	refreshArmorWeight()
	persist()
	local speed = resolveSpeed()
	if speed > 0.05 then
		isMoving = true
		resolveGait()
		pollFrame:SetScript("OnUpdate", tick)
	end
end

function M:OnEnable()
	loadPersisted()
	Pulse:BindFrame({ CUE }, sync)
end

-- Reach-in for PulseDebug, read-only: the only way to see what the gait resolved to
-- without instrumenting the tick loop.
function M:_DebugGait()
	return {
		race = character.race,
		ridingTier = character.ridingTier,
		armorMultiplier = character.armorMultiplier,
		mount = (RACE_GAITS[character.race] or FALLBACK_RACE).mount,
		mode = gait.mode,
		cadence = gait.cadence,
		intensity = gait.intensity,
		sharpness = gait.sharpness,
		valid = gait.valid,
		inCombat = inCombat,
		lastGoodSpeed = lastGoodSpeed,
		-- Live, not cached: "the gait is valid but you are hearing nothing" is the one
		-- state that needs explaining, and this is the field that explains it.
		grounded = hasGroundContact(),
	}
end
