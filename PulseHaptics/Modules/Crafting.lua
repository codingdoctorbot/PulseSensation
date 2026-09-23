-- Pulse — Modules/Crafting.lua
--
-- The craft texture: a bed you feel for the length of a craft, with the profession's own
-- work rhythm struck on top of it. A hammer for blacksmithing, a pick for mining, nothing
-- at all for tailoring.
--
-- WHY THIS IS NOT castTexture WITH A DIFFERENT NUMBER. castTexture (Modules/Combat.lua) is
-- one shape for every cast, a hum swelling toward completion, which is right for a spell —
-- one continuous effort. A craft is a sequence of blows with a known end, and the
-- interesting part is the rhythm rather than the swell. Two sensations, two cues, and
-- castTexture suppresses itself while this runs (Combat.lua's castTick) rather than both
-- layering into mush.
--
-- IDENTIFYING THE PROFESSION, by id and never by name. TRADE_SKILL_CRAFT_BEGIN hands
-- Core/CastActivity.lua the recipe's spell id, and C_TradeSkillUI.GetProfessionInfoByRecipeID
-- turns it into a ProfessionInfo whose `profession` field is an Enum.Profession
-- (TradeSkillUITypesDocumentation.lua:361-376). No string matching, no localisation problem.
-- That field is documented Nilable, so a recipe that does not resolve is normal, not an
-- error: it falls back to GENERIC_WORK rather than going silent.
--
-- GATHERING & FISHING: Unlike bench crafting, gathering (Mining, Herbalism, Skinning) and
-- Fishing fire standard CAST_START and CHANNEL_START events rather than TRADE_SKILL_CRAFT_BEGIN.
-- They are resolved via known spell IDs, spell textures (locale-independent), and spell names,
-- mapping directly to their authored profession sensations (e.g. pickaxe TAP strikes for Mining,
-- calm water bed hum for Fishing). If a gathering profession is disabled on the Crafting page,
-- castTexture in Modules/Combat.lua takes over as fallback.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Crafting", M)

local CUE = "craftTexture"
local STRIKE_LAYER = "craftStrike"

-- Professions

-- Read through Enum where the client defines it, with the confirmed literal as fallback, so
-- a renamed or absent constant costs nothing — the pattern Modules/Locomotion.lua uses for
-- form ids. Values CONFIRMED against ProfessionConstantsDocumentation.lua:232-254.
local function professionID(name, literal)
	local value = Enum and Enum.Profession and Enum.Profession[name]
	if type(value) == "number" then
		return value
	end
	return literal
end

local BLACKSMITHING = professionID("Blacksmithing", 1)
local LEATHERWORKING = professionID("Leatherworking", 2)
local ALCHEMY = professionID("Alchemy", 3)
local HERBALISM = professionID("Herbalism", 4)
local COOKING = professionID("Cooking", 5)
local MINING = professionID("Mining", 6)
local TAILORING = professionID("Tailoring", 7)
local ENGINEERING = professionID("Engineering", 8)
local ENCHANTING = professionID("Enchanting", 9)
local FISHING = professionID("Fishing", 10)
local SKINNING = professionID("Skinning", 11)
local JEWELCRAFTING = professionID("Jewelcrafting", 12)
local INSCRIPTION = professionID("Inscription", 13)
local FIRSTAID = professionID("FirstAid", 0)

-- One row per profession. The numbers are feel judgments, not measurements, and every one
-- is reachable from a slider.
--
--   bed       how present the continuous layer is, 0 for professions with no bulk to them
--   cadence   strikes per second of craft. A three-second craft at 1.1 gets three blows.
--   mode      which authored shape the strike plays (Core/Modes.lua)
--   strike    how hard, before the player's own per-profession slider
--
-- A profession with cadence 0 has no impacts at all. Tailoring and enchanting are not
-- percussive and pretending otherwise would be inventing a sensation that is not there.
local PROFESSION_WORK = {
	[BLACKSMITHING] = { label = "Blacksmithing", bed = 0.10, cadence = 1.1, mode = "THUD", strike = 0.85 },
	[MINING] = { label = "Mining", bed = 0.08, cadence = 1.6, mode = "TAP", strike = 0.70 },
	[ENGINEERING] = { label = "Engineering", bed = 0.09, cadence = 2.2, mode = "TICK", strike = 0.45 },
	[JEWELCRAFTING] = { label = "Jewelcrafting", bed = 0.06, cadence = 2.6, mode = "TICK", strike = 0.30 },
	[LEATHERWORKING] = { label = "Leatherworking", bed = 0.10, cadence = 1.4, mode = "TAP", strike = 0.45 },
	[SKINNING] = { label = "Skinning", bed = 0.08, cadence = 1.8, mode = "TICK", strike = 0.35 },
	[COOKING] = { label = "Cooking", bed = 0.12, cadence = 0.9, mode = "TICK", strike = 0.30 },
	[ALCHEMY] = { label = "Alchemy", bed = 0.14, cadence = 0.0, mode = nil, strike = 0.0 },
	[ENCHANTING] = { label = "Enchanting", bed = 0.16, cadence = 0.0, mode = nil, strike = 0.0 },
	[TAILORING] = { label = "Tailoring", bed = 0.09, cadence = 0.0, mode = nil, strike = 0.0 },
	[INSCRIPTION] = { label = "Inscription", bed = 0.08, cadence = 0.0, mode = nil, strike = 0.0 },
	[HERBALISM] = { label = "Herbalism", bed = 0.07, cadence = 0.0, mode = nil, strike = 0.0 },
	[FISHING] = { label = "Fishing", bed = 0.07, cadence = 0.0, mode = nil, strike = 0.0 },
	[FIRSTAID] = { label = "First Aid", bed = 0.08, cadence = 0.0, mode = nil, strike = 0.0 },
}

-- Anything that does not resolve. Mid-weight and rhythmic on purpose: it should read as
-- "you are making something" without claiming to know what.
local GENERIC_WORK = { label = "Other crafting", bed = 0.10, cadence = 1.2, mode = "TAP", strike = 0.45 }

-- Sidebar order for the settings page: crafting professions first, the ones a craft can
-- actually resolve to today.
local PROFESSION_ORDER = {
	BLACKSMITHING,
	MINING,
	ENGINEERING,
	JEWELCRAFTING,
	LEATHERWORKING,
	TAILORING,
	ALCHEMY,
	ENCHANTING,
	INSCRIPTION,
	COOKING,
	FIRSTAID,
	SKINNING,
	HERBALISM,
	FISHING,
}

-- Read by UI/Panel/Spec.lua to build the Crafting page. Exposed as data rather than as a
-- function so the page stays a plain transformation of it.
Pulse.Professions = {
	order = PROFESSION_ORDER,
	work = PROFESSION_WORK,
	generic = GENERIC_WORK,
}

-- Per-profession settings live on the craftTexture trigger, keyed by enum value, so they
-- ride the existing profile/SavedVariables machinery with no new storage.
function Pulse.Professions.EnabledKey(professionID)
	return "p" .. tostring(professionID) .. "_on"
end

function Pulse.Professions.GainKey(professionID)
	return "p" .. tostring(professionID) .. "_gain"
end

-- Which professions this character has, so the page can lead with those. Returns nil rather
-- than an empty table when the API is unavailable, so the caller can tell "none known" from
-- "cannot tell" and show everything in the second case.
function Pulse.Professions.GetKnown()
	if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
		return nil
	end
	local known = {}
	local indices = { GetProfessions() }
	for _, index in ipairs(indices) do
		if type(index) == "number" then
			local ok, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, index)
			if ok and name then
				known[#known + 1] = { name = name, skillLine = skillLine }
			end
		end
	end
	return known
end

-- State

local active = false -- a craft is in progress AND this cue is on
local work = GENERIC_WORK
local gain = 1.0
local strikesTotal = 0
local nextStrike = 1
local pollFrame = CreateFrame("Frame")

local function clamp01(v)
	if v < 0 then
		return 0
	end
	if v > 1 then
		return 1
	end
	return v
end

local function setting(key, default)
	return Pulse.Database:GetTriggerSetting(CUE, key, default)
end

-- Gathering detection
--
-- Known spell IDs for Gathering and Fishing across Classic and modern client ranks.
local GATHER_SPELL_IDS = {
	-- Mining
	[2575] = MINING,
	[2576] = MINING,
	[3564] = MINING,
	[10248] = MINING,
	[10249] = MINING,
	[29354] = MINING,
	[50310] = MINING,
	-- Herbalism
	[2366] = HERBALISM,
	[2368] = HERBALISM,
	[3570] = HERBALISM,
	[11993] = HERBALISM,
	[28695] = HERBALISM,
	[50300] = HERBALISM,
	-- Skinning
	[8613] = SKINNING,
	[8617] = SKINNING,
	[8618] = SKINNING,
	[10768] = SKINNING,
	[32678] = SKINNING,
	[50305] = SKINNING,
	-- Fishing
	[7620] = FISHING,
	[7731] = FISHING,
	[7732] = FISHING,
	[18248] = FISHING,
	[33095] = FISHING,
	[51294] = FISHING,
	[131474] = FISHING,
	[131476] = FISHING,
}

local GATHER_NAMES = {
	["mining"] = MINING,
	["fishing"] = FISHING,
	["herb gathering"] = HERBALISM,
	["herbalism"] = HERBALISM,
	["skinning"] = SKINNING,
}

local function matchTexture(tex)
	if type(tex) ~= "string" then
		return nil
	end
	local lower = tex:lower()
	if lower:find("trade_mining", 1, true) or lower:find("inv_pick_", 1, true) then
		return MINING
	elseif lower:find("trade_fishing", 1, true) then
		return FISHING
	elseif lower:find("trade_herbalism", 1, true) or lower:find("spell_nature_naturetouchgrow", 1, true) then
		return HERBALISM
	elseif lower:find("trade_skinning", 1, true) or lower:find("inv_misc_pelt_", 1, true) then
		return SKINNING
	end
	return nil
end

local function resolveGatherOrFishing(spellID)
	if type(spellID) == "number" then
		local prof = GATHER_SPELL_IDS[spellID]
		if prof then
			return prof
		end
	end

	local tex, name
	if type(spellID) == "number" then
		if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
			local ok, t = pcall(C_Spell.GetSpellTexture, spellID)
			if ok then
				tex = t
			end
		end
		if not tex and type(GetSpellTexture) == "function" then
			local ok, t = pcall(GetSpellTexture, spellID)
			if ok then
				tex = t
			end
		end

		if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
			local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
			if ok and type(info) == "table" and type(info.name) == "string" then
				name = info.name
			end
		end
		if not name and type(GetSpellInfo) == "function" then
			local ok, n = pcall(GetSpellInfo, spellID)
			if ok and type(n) == "string" then
				name = n
			end
		end
	end

	if not tex or not name then
		if type(UnitCastingInfo) == "function" then
			local cName, _, cTex = UnitCastingInfo("player")
			name = name or cName
			tex = tex or cTex
		end
		if (not tex or not name) and type(UnitChannelInfo) == "function" then
			local chName, _, chTex = UnitChannelInfo("player")
			name = name or chName
			tex = tex or chTex
		end
	end

	if tex then
		local prof = matchTexture(tex)
		if prof then
			return prof
		end
	end

	if name and type(name) == "string" then
		local prof = GATHER_NAMES[name:lower()]
		if prof then
			return prof
		end
	end

	return nil
end

-- Suppression hook. Modules/Combat.lua asks this before emitting castTexture, so a craft is
-- one sensation rather than two competing. A function rather than a shared flag, so
-- Combat.lua need not know how this module stores state and a missing module reads as "not
-- crafting" rather than erroring.
local lastCraftSeen = 0

function M:IsCrafting()
	if active then
		-- Failsafe: if no cast or channel is active, craft suppression auto-clears after 0.5s
		local hasCast = false
		if type(UnitCastingInfo) == "function" then
			local _, _, _, startTimeMs = UnitCastingInfo("player")
			if startTimeMs then
				hasCast = true
			end
		end
		if not hasCast and type(UnitChannelInfo) == "function" then
			local _, _, _, startTimeMs = UnitChannelInfo("player")
			if startTimeMs then
				hasCast = true
			end
		end

		if not hasCast then
			if GetTime() - lastCraftSeen > 0.5 then
				active = false
			end
		else
			lastCraftSeen = GetTime()
		end
	end
	return active
end

function Pulse.IsCrafting()
	local module = Pulse.modules and Pulse.modules.Crafting
	return module and module:IsCrafting() or false
end

-- Resolving a craft to a rhythm

local function resolveProfession(recipeSpellID)
	if type(recipeSpellID) ~= "number" then
		return nil
	end
	if not (C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoByRecipeID) == "function") then
		return nil
	end
	local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeSpellID)
	if not ok or type(info) ~= "table" then
		return nil
	end
	-- Documented Nilable. A recipe with no profession is a fallback, not a failure.
	if type(info.profession) ~= "number" then
		return nil
	end
	return info.profession
end

local tick

local function beginCraft(recipeSpellID, explicitProfessionID)
	local professionID = explicitProfessionID or resolveProfession(recipeSpellID)
	local resolved = professionID and PROFESSION_WORK[professionID] or nil

	-- A profession switched off on the Crafting page produces nothing at all, which is
	-- the point of having a per-profession toggle.
	if professionID and setting(Pulse.Professions.EnabledKey(professionID), 1) ~= 1 then
		active = false
		return
	end

	work = resolved or GENERIC_WORK
	gain = professionID and setting(Pulse.Professions.GainKey(professionID), 1.0) or 1.0
	strikesTotal = 0
	nextStrike = 1
	active = true
	lastCraftSeen = GetTime()

	if Pulse.Database:Get("masterEnabled") and Pulse.Database:GetCue(CUE) then
		pollFrame:SetScript("OnUpdate", tick)
	end

	if Pulse.debug then
		print(("Pulse: craft started — %s (recipe %s)"):format(work.label, tostring(recipeSpellID)))
	end
end

local function endCraft(completed)
	if not active then
		return
	end
	-- The last blow lands ON completion, not just before. Without this the final strike is
	-- usually lost: the cast ends the moment progress reaches 1 and the tick that would
	-- have played it never runs, so the craft feels unfinished.
	if completed and work.mode and strikesTotal > 0 and nextStrike <= strikesTotal then
		M:_PlayStrike()
	end
	active = false
	pollFrame:SetScript("OnUpdate", nil)
	strikesTotal = 0
	nextStrike = 1
end

function M:_PlayStrike()
	if not work.mode then
		return
	end
	local strength = clamp01(work.strike * gain * setting("strikeGain", 1.0))
	if strength <= 0 then
		return
	end
	-- Straight to the engine: the cue and master checks already happened in sync() and the
	-- tick's own guard, and PlayMode is the only way to reach an authored shape with a
	-- per-call scale.
	Pulse.Engine:PlayMode(STRIKE_LAYER, work.mode, strength)
end

-- Per frame: bed, and strikes on the beat
local bedRoles = { low = 0 }

function tick()
	if not active then
		return
	end

	local startTimeMs, endTimeMs
	if type(UnitCastingInfo) == "function" then
		local _, _, _, s, e = UnitCastingInfo("player")
		startTimeMs, endTimeMs = s, e
	end
	if not startTimeMs and type(UnitChannelInfo) == "function" then
		local _, _, _, s, e = UnitChannelInfo("player")
		startTimeMs, endTimeMs = s, e
	end
	-- RULE B, the same guard Combat.lua's castTick carries: comparing a secret value
	-- throws rather than reading as nil.
	if issecretvalue(startTimeMs) or issecretvalue(endTimeMs) then
		return
	end
	if not startTimeMs or not endTimeMs or endTimeMs <= startTimeMs then
		return
	end

	local duration = (endTimeMs - startTimeMs) / 1000
	local progress = clamp01((GetTime() * 1000 - startTimeMs) / (endTimeMs - startTimeMs))

	-- The bed, on the low role: it is the bulk of the work, and the strikes want the fast
	-- motor to themselves so the two read as separate sensations.
	-- Reused table to prevent GC allocation in high-frequency tick loop (Rule 4).
	local bed = work.bed * gain * setting("bedGain", 1.0)
	if bed > 0 then
		bedRoles.low = clamp01(bed)
		Pulse:HoldRolesIfEnabled(CUE, bedRoles)
	end

	if not work.mode or work.cadence <= 0 then
		return
	end

	-- Strike count is fixed once from the craft's real duration, so the rhythm divides the
	-- craft evenly and the last beat coincides with the end. Recomputing per frame would
	-- make the cadence wander as the duration estimate settled.
	if strikesTotal == 0 then
		strikesTotal = math.max(1, math.floor(duration * work.cadence + 0.5))
	end

	local beat = progress * strikesTotal
	while nextStrike <= strikesTotal and beat >= nextStrike do
		M:_PlayStrike()
		nextStrike = nextStrike + 1
	end
end

-- Wiring

local isGathering = false

local function onActivity(result)
	local classification = result.classification
	if classification == "CRAFT_START" then
		isGathering = false
		beginCraft(result.spellID)
	elseif classification == "CAST_START" then
		if not active or isGathering then
			local prof = resolveGatherOrFishing(result.spellID)
			if prof and (prof == MINING or prof == HERBALISM or prof == SKINNING) then
				isGathering = true
				beginCraft(result.spellID, prof)
			end
		end
	elseif classification == "CHANNEL_START" then
		if not active or isGathering then
			local prof = resolveGatherOrFishing(result.spellID)
			if prof and prof == FISHING then
				isGathering = true
				beginCraft(result.spellID, prof)
			end
		end
	elseif classification == "CRAFT_COMPLETE" then
		endCraft(true)
		isGathering = false
	elseif classification == "CAST_COMPLETE" or classification == "CHANNEL_COMPLETE" then
		if isGathering then
			endCraft(true)
			isGathering = false
		end
	elseif classification == "CRAFT_STOPPED" then
		endCraft(false)
		isGathering = false
	elseif
		classification == "CAST_STOPPED"
		or classification == "CHANNEL_STOP"
		or classification == "INTERRUPTED"
		or classification == "FAILED"
	then
		if isGathering then
			endCraft(false)
			isGathering = false
		end
	end
end

local function sync()
	local wanted = (Pulse.Database:Get("masterEnabled") and Pulse.Database:GetCue(CUE)) or false

	-- CastActivity only registers its events while something wants them; keyed by consumer
	-- so toggling casting cues does not unregister crafting, and disabling crafting clears its hold.
	Pulse.CastActivity:SetActive("crafting", wanted)

	if not wanted then
		active = false
		isGathering = false
		pollFrame:SetScript("OnUpdate", nil)
		return
	end

	-- Reseed live state if a tradeskill cast or channel is actively underway mid-profile switch or cue toggle
	local isTradeskill = false
	local currentSpellID = nil
	if type(UnitCastingInfo) == "function" then
		local name, _, _, _, _, isTrade, _, _, spellId = UnitCastingInfo("player")
		if name and isTrade then
			isTradeskill = true
			currentSpellID = spellId
		end
	end
	if not isTradeskill and type(UnitChannelInfo) == "function" then
		local name, _, _, _, _, isTrade, _, spellId = UnitChannelInfo("player")
		if name and isTrade then
			isTradeskill = true
			currentSpellID = spellId
		end
	end

	if isTradeskill then
		local prof = resolveGatherOrFishing(currentSpellID)
		if prof then
			work = PROFESSION_WORK[prof] or GENERIC_WORK
			gain = setting(Pulse.Professions.GainKey(prof), 1.0)
			isGathering = true
		end
		active = true
		pollFrame:SetScript("OnUpdate", tick)
	else
		active = false
		isGathering = false
		pollFrame:SetScript("OnUpdate", nil)
	end
end

function M:OnEnable()
	Pulse.CastActivity:OnActivity(onActivity)
	Pulse:BindFrame({ CUE }, sync)
end

-- Reach-in for PulseDebug, read-only, same stance as Locomotion's _DebugGait.
function M:_DebugCraft()
	return {
		active = active,
		profession = work.label,
		bed = work.bed,
		cadence = work.cadence,
		mode = work.mode,
		strike = work.strike,
		gain = gain,
		strikesTotal = strikesTotal,
		nextStrike = nextStrike,
	}
end
