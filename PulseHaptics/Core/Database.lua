-- Pulse — Core/Database.lua
--
-- SavedVariables load, defaults, change notification. RULE D discipline throughout: every
-- value here is a boolean, a number or an addon-authored string. Nothing Pulse reads is
-- ever a secret value, but the habit costs nothing and a future trigger might read one.
--
-- Profiles (2026-09-15): masterEnabled and defaultHapticSchema stay global — the addon's
-- on/off switch and which physical motors it drives are not playstyle choices. Everything a
-- cue-by-cue config is made of — masterIntensity, triggers, triggerSettings — lives per
-- profile, with each character choosing which one it uses.
--
-- The four built-in slots (BUILTIN_PROFILE_NAMES) seed from Pulse.Triggers[*].default. What
-- a "Raiding" or "PvP" cue set should contain is a feel judgment for whoever holds the
-- controller, not something to fabricate here. They can never be renamed or deleted
-- (Database:IsBuiltinProfile), so a known-safe fallback always exists.
--
-- Custom profiles (2026-09-16, DB.customProfiles): create/rename/delete on top of the four
-- built-ins, named freely. Naming one needs text input; UI/Panel/Popup.lua supplies the
-- dialog.

local ADDON_NAME, Pulse = ...

local Database = {}
Pulse.Database = Database

local DB
local DB_VERSION = 7

local GLOBAL_DEFAULTS = {
	masterEnabled = true,
	defaultHapticSchema = "standard",
	-- ON by default. The switch stays because a one-line-per-cue list is a legitimate
	-- thing to want, but it is not the default: if the panel ever needs to shrink, the
	-- honest ways are group toggles, lazy per-page construction or fewer cues, not hiding
	-- controls that work.
	showAdvancedCueControls = true,
	-- 2026-09-21, after seeing 140 stacked in a live screenshot. Each preview is a
	-- full-width button row, so every cue costs two rows and the brightest thing on the
	-- page is the optional control rather than the checkbox that does something. On by
	-- default because previews are useful while tuning; one click gets a clean list.
	showCueTestButtons = true,
	minimap = { hide = false },
}

-- The shape of one profile slot. These fields used to live flat on DB; DB_VERSION 2's
-- migration moves whatever an install already had into every slot rather than resetting to
-- Registry.lua's stock defaults, so no tuning is thrown away (see _MigrateToProfiles).
local PROFILE_DEFAULTS = {
	masterIntensity = 0.7,
	triggers = {}, -- triggerID -> bool, seeded from Pulse.Triggers[*].default
	triggerSettings = {}, -- triggerID -> { settingKey -> number }, seeded from tunables
}

local BUILTIN_PROFILE_NAMES = {
	"Default",
	"Dungeon: Tank",
	"Dungeon: Healer",
	"Dungeon: Melee",
	"Dungeon: Caster",
	"Dungeon: Hunter",
	"Immersion: Melee",
	"Immersion: Caster",
	"Immersion: Ranged",
	"PvP",
	"Raiding",
	"Questing",
}

Pulse.DEFAULT_PROFILE_METADATA = {
	{
		id = "Dungeon: Tank",
		name = "Dungeon: Tank",
		category = "dungeon",
		label = "Dungeon: Tank",
		summary = "Commanding protection. High threat alerts, mitigation tracking, crowd control, and kick windows. Silences non-combat clutter.",
		emphasizes = "Threat loss/warning, heavy hits taken, defensive cooldowns, crowd control, enemy kick windows",
		silences = "Weather, footsteps, loot popups, quest dialogs, merchant/mail",
		intensity = 0.80,
	},
	{
		id = "Dungeon: Healer",
		name = "Dungeon: Healer",
		category = "dungeon",
		label = "Dungeon: Healer",
		summary = "Attentive triage. Emergency low health warnings, dispel/CC alerts, kick warnings, and heal completion confirmation with subdued personal damage.",
		emphasizes = "Low health alarms, heal cast success, self/enemy interrupt warnings, dispellable CC",
		silences = "Personal damage clutter, footsteps, weather, world dialogs",
		intensity = 0.65,
	},
	{
		id = "Dungeon: Melee",
		name = "Dungeon: Melee",
		category = "dungeon",
		label = "Dungeon: Melee DPS",
		summary = "High-tempo physical execution. Snappy combo points and resource spenders, execute range alerts, boss telegraphs, and kick windows.",
		emphasizes = "Combo points, resource cap, execute range, kick alert, boss telegraphs, burst cooldowns",
		silences = "World dialogs, ambient weather, merchant/mail",
		intensity = 0.75,
	},
	{
		id = "Dungeon: Caster",
		name = "Dungeon: Caster",
		category = "dungeon",
		label = "Dungeon: Caster DPS",
		summary = "Fluid spellcasting pacing. Continuous channel bed during casts, crisp completion snap, lockout warnings, and proc notifications.",
		emphasizes = "Cast texture, cast finish confirmation, lockout/pushback warnings, proc glows, kick alerts",
		silences = "Locomotion clatter, weapon swings, loot popups, world dialogs",
		intensity = 0.70,
	},
	{
		id = "Dungeon: Hunter",
		name = "Dungeon: Hunter",
		category = "dungeon",
		label = "Dungeon: Hunter",
		summary = "Paced ranged rhythm with melee-weaving support. Auto-shot timing, weapon swings, pet status, trap triggers, and boss mechanics.",
		emphasizes = "Auto-shot cadence, weapon swings, pet status, trap triggers, execute range, boss mechanics",
		silences = "Ambient weather, world dialogs, merchant/mail",
		intensity = 0.70,
	},
	{
		id = "Immersion: Melee",
		name = "Immersion: Melee",
		category = "immersion",
		label = "Immersion: Melee",
		summary = "Visceral physical game-feel. Armor-weighted footstep gait, terrain landings, parry and block impacts, swimming drag, weather, and rich world looting.",
		emphasizes = "Locomotion & footsteps by armor weight, mount strides, weather, swimming drag, parry/blocks, full loot/quest haptics",
		silences = "None (full sensory richness)",
		intensity = 0.80,
	},
	{
		id = "Immersion: Caster",
		name = "Immersion: Caster",
		category = "immersion",
		label = "Immersion: Caster",
		summary = "Atmospheric and arcane. Flowing spellcast textures, elemental channeling, environmental wind and weather, flight gliding, and magical world interactions.",
		emphasizes = "Cast flow, flight & skyriding, swimming, weather changes, quest and item haptics",
		silences = "Jarring physical weapon clatter",
		intensity = 0.70,
	},
	{
		id = "Immersion: Ranged",
		name = "Immersion: Ranged",
		category = "immersion",
		label = "Immersion: Ranged",
		summary = "Naturalistic scout feel. Locomotion, flight gliding, wilderness weather, tracking/stealth cues, world exploration, and bow release.",
		emphasizes = "Footstep pacing, mount travel, gliding, weather, soft-target interaction, weapon draw/release",
		silences = "Discordant combat spam",
		intensity = 0.75,
	},
	{
		id = "PvP",
		name = "PvP",
		category = "pvp",
		label = "PvP (Tactical Radar)",
		summary = "Pure competitive reaction. Instant tactical alerts for stuns, silences, disarms, lockouts, panic health warnings, and combat transitions.",
		emphasizes = "Full loss-of-control suite, kick opportunities, lockouts, panic health warning, combat enter/leave",
		silences = "100% stripped of footsteps, weather, swimming, flight, loot, quest, and UI noise",
		intensity = 0.75,
	},
	{
		id = "Default",
		name = "Default",
		category = "general",
		label = "Default (Balanced Baseline)",
		summary = "The standard authored baseline. Balanced game-feel across combat, environment, movement, and alerts.",
		emphasizes = "Standard balance across all categories",
		silences = "None (stock defaults)",
		intensity = 0.70,
	},
}

-- Curated trigger overrides for built-in profiles. Profiles with `__exclusive = true` enable
-- only their explicitly listed cues and silence all other triggers; profiles without it inherit
-- the trigger's authored default for unmentioned cues.
local PROFILE_TRIGGER_OVERRIDES = {
	Raiding = {
		bossAbilityWarning = true,
		cooldownReady = true,
		lowHealthWarning = true,
		combatLeave = true,
		playerAlive = true,
		encounterStart = true,
		encounterEnd = true,
		focusCastStart = true,
		focusChannelStart = true,
		rolePoll = true,
		summonRequest = true,
		raidTarget = true,
		lootRoll = true,
		lootReceived = true,
		selfChannelInterrupted = true,
	},
	Questing = {
		damageTaken = true,
		castTexture = true,
		comboPoint = true,
		lowHealthWarning = true,
		breathTexture = true,
		weatherChanged = true,
		dismount = true,
		jumped = true,
		swimTexture = true,
		taxiRide = true,
		lootGold = true,
		itemObtained = true,
		bagItemAdded = true,
		bagFull = true,
		equipChanged = true,
		emote = true,
		combatLeave = true,
		partyInvite = true,
		whisper = true,
		duelRequest = true,
		lootOpened = true,
		lootRoll = true,
		lootConfirm = true,
		lootReceived = true,
		merchantShow = true,
		mailShow = true,
		taxiOpened = true,
		questDetail = true,
		questComplete = true,
		questTurnedIn = true,
		zoneChanged = true,
		enteringWorld = true,
		achievement = true,
		selfCastSucceeded = true,
	},
	["Dungeon: Tank"] = {
		__exclusive = true,
		threatLost = true,
		threatWarning = true,
		tauntSuccess = true,
		tauntFailed = true,
		damageTaken = true,
		deflect = true,
		bossAbilityWarning = true,
		bossChatWarning = true,
		cooldownReady = true,
		lossOfControlStart = true,
		ccMaster = true,
		ccStun = true,
		ccSilence = true,
		ccFear = true,
		ccDisarm = true,
		ccPacify = true,
		ccIncapacitate = true,
		focusCastStart = true,
		focusChannelStart = true,
		targetCastStopped = true,
		targetedByEnemy = true,
		combatEnter = true,
		combatLeave = true,
		playerAlive = true,
		lowHealthWarning = true,
		lowHealthTexture = true,
		raidTarget = true,
		rolePoll = true,
		summonRequest = true,
		durabilityLow = true,
		targetBigDefensive = true,
		controllerUIMaster = true,
		uiNavigate = true,
		groupTargetingStart = true,
		groupTargetingStop = true,
		uiTabChanged = true,
		panelOpen = true,
		panelClose = true,
		radialOpen = true,
		radialClose = true,
		radialTick = true,
		radialSelect = true,
		radialPage = true,
		popupShown = true,
		popupHidden = true,
	},
	["Dungeon: Healer"] = {
		__exclusive = true,
		lowHealthWarning = true,
		lowHealthTexture = true,
		healCrit = true,
		healReceived = true,
		selfCastSucceeded = true,
		selfCastFailed = true,
		selfChannelInterrupted = true,
		castTexture = true,
		cooldownReady = true,
		procGlow = true,
		bossAbilityWarning = true,
		bossChatWarning = true,
		focusCastStart = true,
		focusChannelStart = true,
		lossOfControlStart = true,
		ccMaster = true,
		ccSilence = true,
		ccStun = true,
		ccFear = true,
		ccIncapacitate = true,
		rolePoll = true,
		summonRequest = true,
		raidTarget = true,
		combatEnter = true,
		combatLeave = true,
		playerAlive = true,
		damageTaken = true,
		targetBigDefensive = true,
		controllerUIMaster = true,
		uiNavigate = true,
		groupTargetingStart = true,
		groupTargetingStop = true,
		uiTabChanged = true,
		panelOpen = true,
		panelClose = true,
		radialOpen = true,
		radialClose = true,
		radialTick = true,
		radialSelect = true,
		radialPage = true,
		popupShown = true,
		popupHidden = true,
	},
	["Dungeon: Melee"] = {
		__exclusive = true,
		comboPoint = true,
		resourceCapped = true,
		critLanded = true,
		deflect = true,
		weaponSwingMain = true,
		weaponSwingOff = true,
		targetDied = true,
		focusCastStart = true,
		focusChannelStart = true,
		targetCastStopped = true,
		bossAbilityWarning = true,
		bossChatWarning = true,
		cooldownReady = true,
		procGlow = true,
		lossOfControlStart = true,
		ccMaster = true,
		ccStun = true,
		ccDisarm = true,
		damageTaken = true,
		combatEnter = true,
		combatLeave = true,
		playerAlive = true,
		lowHealthWarning = true,
		raidTarget = true,
		targetBigDefensive = true,
		controllerUIMaster = true,
		uiNavigate = true,
		groupTargetingStart = true,
		groupTargetingStop = true,
		uiTabChanged = true,
		panelOpen = true,
		panelClose = true,
		radialOpen = true,
		radialClose = true,
		radialTick = true,
		radialSelect = true,
		radialPage = true,
		popupShown = true,
		popupHidden = true,
	},
	["Dungeon: Caster"] = {
		__exclusive = true,
		castTexture = true,
		selfCastSucceeded = true,
		selfCastFailed = true,
		selfChannelInterrupted = true,
		critLanded = true,
		procGlow = true,
		cooldownReady = true,
		resourceCapped = true,
		focusCastStart = true,
		focusChannelStart = true,
		targetCastStopped = true,
		bossAbilityWarning = true,
		bossChatWarning = true,
		lossOfControlStart = true,
		ccMaster = true,
		ccSilence = true,
		ccStun = true,
		damageTaken = true,
		lowHealthWarning = true,
		combatEnter = true,
		combatLeave = true,
		playerAlive = true,
		raidTarget = true,
		targetBigDefensive = true,
		controllerUIMaster = true,
		uiNavigate = true,
		groupTargetingStart = true,
		groupTargetingStop = true,
		uiTabChanged = true,
		panelOpen = true,
		panelClose = true,
		radialOpen = true,
		radialClose = true,
		radialTick = true,
		radialSelect = true,
		radialPage = true,
		popupShown = true,
		popupHidden = true,
	},
	["Dungeon: Hunter"] = {
		__exclusive = true,
		autoShotFired = true,
		autoRepeatStart = true,
		autoRepeatStop = true,
		weaponSwingMain = true,
		weaponSwingOff = true,
		procGlow = true,
		cooldownReady = true,
		critLanded = true,
		focusCastStart = true,
		focusChannelStart = true,
		targetCastStopped = true,
		bossAbilityWarning = true,
		bossChatWarning = true,
		lossOfControlStart = true,
		ccMaster = true,
		ccStun = true,
		ccSilence = true,
		threatWarning = true,
		damageTaken = true,
		lowHealthWarning = true,
		combatEnter = true,
		combatLeave = true,
		playerAlive = true,
		raidTarget = true,
		targetBigDefensive = true,
		controllerUIMaster = true,
		uiNavigate = true,
		groupTargetingStart = true,
		groupTargetingStop = true,
		uiTabChanged = true,
		panelOpen = true,
		panelClose = true,
		radialOpen = true,
		radialClose = true,
		radialTick = true,
		radialSelect = true,
		radialPage = true,
		popupShown = true,
		popupHidden = true,
	},
	["Immersion: Melee"] = {
		locomotion = true,
		landingSoft = true,
		landingHard = true,
		jumped = true,
		swimTexture = true,
		waterTexture = true,
		breathWarning = true,
		breathTexture = true,
		weatherChanged = true,
		weatherTexture = true,
		taxiRide = true,
		taxiTakeoff = true,
		taxiLanding = true,
		mountUp = true,
		dismount = true,
		glideThrust = true,
		lootGold = true,
		itemObtained = true,
		bagItemAdded = true,
		bagFull = true,
		harvestComplete = true,
		durabilityLow = true,
		equipChanged = true,
		emote = true,
		achievement = true,
		damageTaken = true,
		deflect = true,
		critLanded = true,
		weaponSwingMain = true,
		weaponSwingOff = true,
		comboPoint = true,
		cooldownReady = true,
		questDetail = true,
		questComplete = true,
		questTurnedIn = true,
		merchantShow = true,
		mailShow = true,
		taxiOpened = true,
		softTargetInteract = true,
		softTargetInteraction = true,
		craftTexture = true,
		combatEnter = true,
		combatLeave = true,
	},
	["Immersion: Caster"] = {
		castTexture = true,
		selfCastSucceeded = true,
		critLanded = true,
		procGlow = true,
		locomotion = true,
		landingSoft = true,
		landingHard = true,
		glideThrust = true,
		taxiRide = true,
		mountUp = true,
		dismount = true,
		swimTexture = true,
		waterTexture = true,
		breathTexture = true,
		weatherChanged = true,
		weatherTexture = true,
		lootGold = true,
		itemObtained = true,
		bagItemAdded = true,
		bagFull = true,
		equipChanged = true,
		achievement = true,
		questDetail = true,
		questComplete = true,
		questTurnedIn = true,
		merchantShow = true,
		mailShow = true,
		taxiOpened = true,
		softTargetInteract = true,
		craftTexture = true,
		combatEnter = true,
		combatLeave = true,
		weaponSwingMain = false,
		weaponSwingOff = false,
		autoShotFired = false,
	},
	["Immersion: Ranged"] = {
		autoShotFired = true,
		critLanded = true,
		procGlow = true,
		locomotion = true,
		landingSoft = true,
		landingHard = true,
		jumped = true,
		glideThrust = true,
		mountUp = true,
		dismount = true,
		taxiRide = true,
		swimTexture = true,
		waterTexture = true,
		weatherChanged = true,
		weatherTexture = true,
		lootGold = true,
		itemObtained = true,
		bagItemAdded = true,
		bagFull = true,
		harvestComplete = true,
		equipChanged = true,
		achievement = true,
		questDetail = true,
		questComplete = true,
		questTurnedIn = true,
		merchantShow = true,
		mailShow = true,
		taxiOpened = true,
		softTargetInteract = true,
		softTargetInteraction = true,
		craftTexture = true,
		combatEnter = true,
		combatLeave = true,
		weaponSwingMain = true,
		weaponSwingOff = true,
	},
	PvP = {
		__exclusive = true,
		lossOfControlStart = true,
		ccMaster = true,
		ccStun = true,
		ccSilence = true,
		ccFear = true,
		ccDisarm = true,
		ccPacify = true,
		ccIncapacitate = true,
		focusCastStart = true,
		focusChannelStart = true,
		targetCastStopped = true,
		targetedByEnemy = true,
		selfCastFailed = true,
		selfChannelInterrupted = true,
		damageTaken = true,
		cooldownReady = true,
		lowHealthWarning = true,
		lowHealthTexture = true,
		targetBigDefensive = true,
		targetDied = true,
		combatEnter = true,
		combatLeave = true,
		duelRequest = true,
		raidTarget = true,
	},
}

local function sanitizeBool(value)
	if issecretvalue(value) then
		return nil
	end
	return value and true or false
end

local function sanitizeProfileName(name)
	if issecretvalue(name) or type(name) ~= "string" then
		return nil
	end
	name = name:match("^%s*(.-)%s*$")
	if name == "" or #name > 24 then
		return nil
	end
	return name
end

local function sanitizeNumber(value, minValue, maxValue)
	if issecretvalue(value) then
		return nil
	end
	value = tonumber(value)
	if not value then
		return nil
	end
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

local function copyDefaults(src, dst)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dst[key]) ~= "table" then
				dst[key] = {}
			end
			copyDefaults(value, dst[key])
		elseif dst[key] == nil then
			dst[key] = value
		end
	end
	return dst
end

-- "Name - Realm", the standard per-character key inside one account-wide SavedVariables
-- table. RULE D-legal: UnitName("player")/GetRealmName() are the player's own identity,
-- never secret.
--
-- Cached (2026-09-21) because this is on the per-frame path: reached from GetCue,
-- GetTriggerSetting, GetTriggerMode and Get("masterIntensity"), so HoldIfEnabled builds it
-- twice per call and a continuous texture calls HoldIfEnabled every frame — several
-- concatenations and a pair of C calls per frame for a value that changes once per login.
--
-- Deliberately NOT computed at file load: UnitName("player") is not reliably populated at
-- ADDON_LOADED, and a key of "? - Realm" would silently strand this character on Default.
-- Computed lazily and recomputed once the player entity is up, so a key captured too early
-- is corrected rather than persisted.
local cachedCharacterKey = nil

-- Forward-declared because the PLAYER_ENTERING_WORLD handler below calls it, and the
-- definition sits far further down next to the resolution cache it clears. Without this
-- the call compiles as a GLOBAL lookup — a `local function` is only in scope from its own
-- declaration onwards — and fires "attempt to call a nil value" on every login
-- (Database.lua:166, reported 2026-09-22). Same forward-declaration pattern
-- Modules/Combat.lua already uses for applyParryHaste, and for the same reason.
local invalidateResolution

local function characterKey()
	if cachedCharacterKey then
		return cachedCharacterKey
	end
	local name = UnitName("player")
	local realm = GetRealmName()
	local key = (name or "?") .. " - " .. (realm or "?")
	-- Only cache a key that actually identifies somebody. A placeholder is recomputed next
	-- call rather than frozen in.
	if name and realm then
		cachedCharacterKey = key
	end
	return key
end

do
	local keyFrame = CreateFrame("Frame")
	keyFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	-- Changing specialization can change which profile resolves without any rule changing,
	-- which is the point of the spec scope. Harmless without specializations: the event
	-- never fires, or resolves to the same name for one string comparison.
	keyFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	-- A switch that arrived mid-fight was deferred rather than dropped; this is where it
	-- lands. See notifyProfileSwitch.
	keyFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

	keyFrame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			cachedCharacterKey = nil
			characterKey()
			-- The character key is half of every rule lookup, so a new one invalidates
			-- the resolution as surely as a rule change does.
			invalidateResolution()
		end
		-- Guarded: these can in principle arrive before Database:Init has run, and
		-- resolving a profile against a nil store is not worth an error.
		if not DB then
			return
		end
		if event == "PLAYER_REGEN_ENABLED" then
			Database:FlushPendingProfileSwitch()
		end
		Database:RefreshActiveProfile()
	end)
end

local cueListeners = {}
local globalListeners = {}
local triggerSettingListeners = {}
local modeTuningListeners = {}

local function notify(listeners, key)
	local list = listeners[key]
	if not list then
		return
	end
	for _, callback in ipairs(list) do
		callback()
	end
end

-- Switching the active profile can change any cue's enabled state, any tunable and
-- masterIntensity at once — there is no single key to notify, so every subscriber gets a
-- callback as if each key had changed individually. Modules rely on this to re-sync event
-- registration (Init.lua's BindFrame) against whichever profile just became active.
local function notifyAll(listeners)
	for key in pairs(listeners) do
		notify(listeners, key)
	end
end

local function subscribe(listeners, key, callback)
	local list = listeners[key]
	if not list then
		list = {}
		listeners[key] = list
	end
	list[#list + 1] = callback
end

function Database:OnCueChanged(triggerID, callback)
	subscribe(cueListeners, triggerID, callback)
end

function Database:OnGlobalChanged(key, callback)
	subscribe(globalListeners, key, callback)
end

function Database:OnTriggerSettingChanged(triggerID, settingKey, callback)
	subscribe(triggerSettingListeners, triggerID .. ":" .. settingKey, callback)
end

function Database:OnModeTuningChanged(modeID, key, callback)
	subscribe(modeTuningListeners, modeID .. ":" .. key, callback)
end

function Database:Init()
	PulseDB = PulseDB or {}
	DB = PulseDB
	-- Migrate before ApplyDefaults: migration moves a pre-profiles install's values into
	-- every slot verbatim, holes and all, then ApplyDefaults fills the holes.
	self:Migrate()
	self:ApplyDefaults()
end

function Database:ApplyDefaults()
	copyDefaults(GLOBAL_DEFAULTS, DB)
	DB.profiles = DB.profiles or {}
	DB.charProfile = DB.charProfile or {}
	DB.specProfile = DB.specProfile or {}
	DB.customProfiles = DB.customProfiles or {}
	for _, name in ipairs(self:_AllProfileNames()) do
		local isNew = (DB.profiles[name] == nil)
		DB.profiles[name] = DB.profiles[name] or {}
		copyDefaults(PROFILE_DEFAULTS, DB.profiles[name])
		self:_SeedProfileTriggerDefaults(DB.profiles[name], PROFILE_TRIGGER_OVERRIDES[name])
		if isNew then
			local meta = self:GetDefaultProfileMeta(name)
			if meta and meta.intensity then
				DB.profiles[name].masterIntensity = meta.intensity
			end
		end
	end
end

-- Built-ins first, then custom profiles in creation order — the order GetProfileNames
-- hands the settings dropdown.
function Database:_AllProfileNames()
	local names = {}
	for _, name in ipairs(BUILTIN_PROFILE_NAMES) do
		names[#names + 1] = name
	end
	for _, name in ipairs(DB.customProfiles or {}) do
		names[#names + 1] = name
	end
	return names
end

function Database:IsBuiltinProfile(name)
	for _, builtin in ipairs(BUILTIN_PROFILE_NAMES) do
		if builtin == name then
			return true
		end
	end
	return false
end

function Database:GetDefaultProfileMeta(name)
	if not Pulse.DEFAULT_PROFILE_METADATA then
		return nil
	end
	for _, meta in ipairs(Pulse.DEFAULT_PROFILE_METADATA) do
		if meta.id == name then
			return meta
		end
	end
	return nil
end

-- Per-trigger seeding, aimed at one profile table rather than DB — called once per slot in
-- ApplyDefaults. `overrides` wins over trigger.default on a first-time seed only, still
-- "fill holes, never stomp a real choice". A custom profile created later never gets one,
-- since PROFILE_TRIGGER_OVERRIDES names only the curated built-ins.
function Database:_SeedProfileTriggerDefaults(profile, overrides)
	for _, trigger in ipairs(Pulse.Triggers) do
		if profile.triggers[trigger.id] == nil then
			local default = overrides and overrides[trigger.id]
			if default == nil then
				if overrides and overrides.__exclusive then
					default = false
				else
					default = trigger.default
				end
			end
			profile.triggers[trigger.id] = default and true or false
		end
		-- Per-cue intensity for every trigger that produces vibration, mode-based or
		-- continuous. `defaultIntensity` is optional, set only where a cue starts quieter
		-- than the 1.0 norm (e.g. damageTaken, Core/Registry.lua).
		if trigger.mode or trigger.continuous then
			profile.triggerSettings[trigger.id] = profile.triggerSettings[trigger.id] or {}
			local settings = profile.triggerSettings[trigger.id]
			if settings.intensity == nil then
				settings.intensity = trigger.defaultIntensity or 1.0
			end
		end
		if trigger.tunables then
			profile.triggerSettings[trigger.id] = profile.triggerSettings[trigger.id] or {}
			local settings = profile.triggerSettings[trigger.id]
			for _, tunable in ipairs(trigger.tunables) do
				if settings[tunable.key] == nil then
					-- Boolean tunables are stored as 1/0, never as a Lua boolean. Every
					-- reader treats a triggerSetting as a number — the checkbox in
					-- UI/Panel/Spec.lua writes `value and 1 or 0`, modules test
					-- `setting(key, 1) == 1`. Seeding raw `true` meant a tunable declared
					-- `default = true` failed `== 1` and read as OFF until the player
					-- toggled the checkbox twice. CAUGHT 2026-09-21 by swimTexture's
					-- separateMotors; the same bug silently disabled Locomotion's
					-- mountedOnly and splitFeet.
					local value = tunable.default
					if tunable.boolean then
						value = value and 1 or 0
					end
					settings[tunable.key] = value
				end
			end
		end
	end
end

function Database:Migrate()
	DB.version = DB.version or 1
	if DB.version < 2 then
		self:_MigrateToProfiles()
	end
	if DB.version < 3 then
		self:_ApplyCuratedProfileContent()
	end
	if DB.version < 4 then
		self:_MigrateSwimSplit()
	end
	if DB.version < 5 then
		self:_ClearBadAdvancedDefault()
	end
	if DB.version < 6 then
		self:_MigrateToProfileRules()
	end
	if DB.version < 7 then
		self:_MigrateRoleAndImmersionProfiles()
	end
	DB.version = DB_VERSION
end

-- One-time, DB_VERSION 6 -> 7: seeds newly added Dungeon and Immersion role profiles into
-- DB.profiles without overwriting existing custom profiles or any profiles already modified.
function Database:_MigrateRoleAndImmersionProfiles()
	for _, name in ipairs(BUILTIN_PROFILE_NAMES) do
		local overrides = PROFILE_TRIGGER_OVERRIDES[name]
		if overrides and not (DB.profiles and DB.profiles[name]) then
			DB.profiles = DB.profiles or {}
			DB.profiles[name] = {}
			copyDefaults(PROFILE_DEFAULTS, DB.profiles[name])
			self:_SeedProfileTriggerDefaults(DB.profiles[name], overrides)
			local meta = self:GetDefaultProfileMeta(name)
			if meta and meta.intensity then
				DB.profiles[name].masterIntensity = meta.intensity
			end
		end
	end
end

-- One-time, DB_VERSION 2 -> 3: PROFILE_TRIGGER_OVERRIDES' curated content for Raiding/
-- Questing/PvP, forced rather than hole-filled, because on an already-migrated install
-- every trigger has a seeded value and _SeedProfileTriggerDefaults would find no holes.
-- Default is untouched — it is simply not a key in PROFILE_TRIGGER_OVERRIDES. Runs before
-- ApplyDefaults, so on a fresh install it is harmlessly redundant, not a conflict.
function Database:_ApplyCuratedProfileContent()
	for profileName, overrides in pairs(PROFILE_TRIGGER_OVERRIDES) do
		local profile = DB.profiles and DB.profiles[profileName]
		if profile then
			profile.triggers = profile.triggers or {}
			for triggerID, enabled in pairs(overrides) do
				profile.triggers[triggerID] = enabled
			end
		end
	end
end

-- One-time, DB_VERSION 4 -> 5: undo a bad default already written to disk.
-- showAdvancedCueControls shipped as `false` for one build. ApplyDefaults only fills holes
-- (copyDefaults' `dst[key] == nil` test), so correcting GLOBAL_DEFAULTS back to `true` does
-- nothing for anyone who logged in with that build — their sliders and mode pickers stay
-- gone with no indication why.
--
-- Deleting the stored key rather than setting it to true restores it to "unset", so
-- ApplyDefaults seeds the current default — what would have happened had the bad build
-- never existed. Anyone who deliberately turned it off turns it off once more, the lesser
-- harm.
function Database:_ClearBadAdvancedDefault()
	DB.showAdvancedCueControls = nil
end

-- One-time, DB_VERSION 3 -> 4: swimTexture split into effort (swimTexture) plus ambient
-- (waterTexture), 2026-09-21. Three things have to carry across or the split silently
-- takes away tuning and a texture the player already had:
--
--   swimHighPeak  -> swimTexture.peak         the pair was blended with max(), so the
--                                             larger of the two was the only one doing
--                                             anything. It is the honest survivor.
--   idleFloatAmplitude -> waterTexture.baseline   live-tuned to 0.04 over seven rounds;
--                                             throwing it away would be rude.
--   swimTexture enabled -> waterTexture enabled   somebody who had swim feedback on had
--                                             the float as part of it. Leaving the new
--                                             ambient cue off would read as the split
--                                             having removed something.
--
-- Runs per profile, since all three live in per-profile storage.
function Database:_MigrateSwimSplit()
	-- Normalise any boolean tunable already persisted as a Lua boolean into 1/0. See
	-- _SeedProfileTriggerDefaults for why they must be numbers.
	for _, profile in pairs(DB.profiles or {}) do
		for _, settings in pairs(profile.triggerSettings or {}) do
			for key, value in pairs(settings) do
				if type(value) == "boolean" then
					settings[key] = value and 1 or 0
				end
			end
		end
	end

	for _, profile in pairs(DB.profiles or {}) do
		local settings = profile.triggerSettings
		local old = settings and settings.swimTexture
		if old then
			-- max() is what the old code did with the pair, so take the same winner.
			local high = old.swimHighPeak
			local low = old.swimLowPeak
			local peak = math.max(high or 0, low or 0)
			if peak > 0 and old.peak == nil then
				old.peak = peak
			end
			old.swimLowPeak, old.swimHighPeak = nil, nil

			if old.idleFloatAmplitude ~= nil then
				settings.waterTexture = settings.waterTexture or {}
				if settings.waterTexture.baseline == nil then
					settings.waterTexture.baseline = old.idleFloatAmplitude
				end
				old.idleFloatAmplitude = nil
			end
		end
		if profile.triggers and profile.triggers.swimTexture and profile.triggers.waterTexture == nil then
			profile.triggers.waterTexture = true
		end
	end
end

-- One-time, DB_VERSION 1 -> 2: before profiles existed, masterIntensity/triggers/
-- triggerSettings sat flat on DB. Snapshot whatever's there (a fresh install has nothing,
-- so this snapshot is just empty defaults ApplyDefaults fills in next) into every one of
-- the four slots identically, then drop the old flat fields so there's exactly one source
-- of truth going forward. CopyTable (Blizzard_SharedXMLBase/TableUtil.lua, confirmed real
-- this session) deep-copies so the four slots are independent tables, not aliases of the
-- same one.
function Database:_MigrateToProfiles()
	local snapshot = {
		masterIntensity = DB.masterIntensity,
		triggers = DB.triggers or {},
		triggerSettings = DB.triggerSettings or {},
	}
	DB.profiles = {}
	for _, name in ipairs(BUILTIN_PROFILE_NAMES) do
		DB.profiles[name] = CopyTable(snapshot)
	end
	DB.charProfile = DB.charProfile or {}
	DB.customProfiles = DB.customProfiles or {}
	-- Only if the key actually identifies somebody. This runs during ADDON_LOADED, when
	-- UnitName("player") is not yet populated, so characterKey() can return the "? - ?"
	-- placeholder — and writing that persisted a junk rule forever. characterKey's own
	-- cache already refuses to hold a placeholder for exactly this reason; this write did
	-- not. Skipping it costs nothing: an unset character rule falls through to the account
	-- rule and then to Default, which is where this line was pointing anyway.
	local key = characterKey()
	if key and not key:find("?", 1, true) then
		DB.charProfile[key] = "Default"
	end
	DB.masterIntensity = nil
	DB.triggers = nil
	DB.triggerSettings = nil
end

function Database:GetProfileNames()
	return self:_AllProfileNames()
end

-- Which profile is active, and why
--
-- 2026-09-22. Resolving a profile automatically is a borrowed idea; what the scopes hold
-- is not. The obvious shape is for each scope to own its own copy of every setting, which
-- is simple and wrong here: every character ends up with a private configuration and two
-- of them can never share one. Pulse's named profiles exist precisely so five characters
-- can share one "Raiding".
--
-- So the scopes here hold a NAME, not a settings table. What is automatic is which profile
-- gets picked; what is shared stays shared.
--
--     specialization rule   this character, this spec   DB.specProfile[char .. "::" .. id]
--     character rule        this character              DB.charProfile[char]
--     account rule          everything else             DB.accountProfile
--     Default               nothing set at all
--
-- Most specific wins. An unset scope falls through rather than blocking, so the common case
-- — one rule, at the character level — behaves as it did before this existed.
--
-- SPECIALIZATIONS MAY NOT EXIST HERE. GetSpecialization is present in the Forever API
-- (SpecializationInfoDocumentation.lua:237), but Forever is a classic-shaped roster on a
-- retail client and whether a character actually HAS a spec is unverified. specInfo
-- returns nil when it does not, the spec scope then never resolves, and the UI hides the
-- row rather than offering a rule that can never match.

local SCOPE_SPEC = "spec"
local SCOPE_CHARACTER = "character"
local SCOPE_ACCOUNT = "account"

Database.SCOPE_SPEC = SCOPE_SPEC
Database.SCOPE_CHARACTER = SCOPE_CHARACTER
Database.SCOPE_ACCOUNT = SCOPE_ACCOUNT

-- id, name. Both nil on a client or character without specializations, which is a
-- supported state, not a failure.
function Database:GetSpecInfo()
	if type(GetSpecialization) ~= "function" then
		return nil
	end
	if type(GetSpecializationInfo) ~= "function" then
		return nil
	end
	local ok, index = pcall(GetSpecialization)
	if not ok or type(index) ~= "number" then
		return nil
	end
	local okInfo, id, name = pcall(GetSpecializationInfo, index)
	if not okInfo or type(id) ~= "number" then
		return nil
	end
	return id, name
end

local function specKey()
	local id = Database:GetSpecInfo()
	if not id then
		return nil
	end
	return characterKey() .. "::" .. tostring(id)
end

-- The name stored against a scope, or nil. A name pointing at a profile that no longer
-- exists reads as unset — same RULE E degrade the old single-scope lookup used, now
-- applied at every level so a stale rule cannot shadow a good one below it.
local function ruleFor(scope)
	local name
	if scope == SCOPE_SPEC then
		local key = specKey()
		name = key and DB.specProfile[key]
	elseif scope == SCOPE_CHARACTER then
		name = DB.charProfile[characterKey()]
	elseif scope == SCOPE_ACCOUNT then
		name = DB.accountProfile
	end
	if name and DB.profiles[name] then
		return name
	end
	return nil
end

-- Cached, because this is on the per-frame path and was not cheap. activeProfile() backs
-- Get("masterIntensity"), GetCue and GetTriggerSetting, and resolving from scratch costs
-- four pcalls — GetSpecInfo runs twice, directly and through ruleFor(SCOPE_SPEC) ->
-- specKey() — plus a tostring and a concat. Engine's OnUpdate does one per frame;
-- pollLandingAndSwim while swimming does about a dozen. Fifty-odd pcalls a frame on the
-- path cachedCharacterKey exists to keep cheap.
--
-- WHEN IT IS SAFE TO CACHE, which is not always. Everything that can change the answer
-- clears this: the three scope setters, the four operations adding or removing a profile
-- name, and the event frame for a login. A rule is a stored name, valid only while
-- DB.profiles has it, so nothing else can move the result — EXCEPT changing specialization,
-- which moves it without touching any stored value, warned only by
-- PLAYER_SPECIALIZATION_CHANGED. Whether that event fires on a classic-shaped Forever
-- roster is UNVERIFIED, and making an unverified event load-bearing for which profile is
-- active is not worth the pcalls it saves.
--
-- So: no spec rules anywhere means the spec scope cannot win, the branch is skipped and the
-- result is cached — the common case, and the one the hot path cares about. A spec rule set
-- anywhere means resolving live every call, correct whether or not the event arrives, paid
-- only by someone who asked for it.
local resolution -- { scope, name, why } or nil

local function anySpecRules()
	return next(DB.specProfile or {}) ~= nil
end

-- Assigns the upvalue forward-declared near characterKey above. NOT `local function`:
-- that would create a second, shadowing local and leave the early caller seeing nil again.
function invalidateResolution()
	resolution = nil
end

-- Which scope is actually in force, the profile it names, and a line fit to show someone.
function Database:GetProfileResolution()
	local cacheable = not anySpecRules()
	if cacheable and resolution then
		return resolution.scope, resolution.name, resolution.why
	end
	local scope, name, why
	local specID, specName

	-- Only asked when a spec rule could actually match. This is the expensive part: two
	-- pcalls here and two more inside ruleFor's specKey().
	local candidate
	if not cacheable then
		specID, specName = self:GetSpecInfo()
		candidate = ruleFor(SCOPE_SPEC)
	end

	if candidate then
		scope, name = SCOPE_SPEC, candidate
		why = ("this specialization (%s)"):format(specName or tostring(specID))
	else
		candidate = ruleFor(SCOPE_CHARACTER)
		if candidate then
			scope, name, why = SCOPE_CHARACTER, candidate, "this character"
		else
			candidate = ruleFor(SCOPE_ACCOUNT)
			if candidate then
				scope, name, why = SCOPE_ACCOUNT, candidate, "every character"
			else
				scope, name, why = nil, "Default", "nothing set — falling back to Default"
			end
		end
	end

	if cacheable then
		resolution = { scope = scope, name = name, why = why }
	end
	return scope, name, why
end

function Database:GetActiveProfileName()
	local _, name = self:GetProfileResolution()
	return name
end

function Database:GetProfileRule(scope)
	return ruleFor(scope)
end

-- Deferred in combat: this notification is what makes every module re-register its events
-- (Init.lua's BindFrame), and tearing that down and rebuilding it mid-pull is the kind of
-- thing that goes wrong once and never reproduces. The stored rule changes immediately;
-- only the re-sync waits.
local pendingProfileNotify = false

local function notifyProfileSwitch()
	if InCombatLockdown and InCombatLockdown() then
		pendingProfileNotify = true
		return
	end
	notifyAll(cueListeners)
	notify(globalListeners, "masterIntensity")
	notifyAll(triggerSettingListeners)
end

function Database:HasPendingProfileSwitch()
	return pendingProfileNotify
end

function Database:FlushPendingProfileSwitch()
	if not pendingProfileNotify then
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	pendingProfileNotify = false
	notifyAll(cueListeners)
	notify(globalListeners, "masterIntensity")
	notifyAll(triggerSettingListeners)
	return true
end

-- Re-resolve after something that could change the answer without changing any rule —
-- logging in, or changing specialization. Only notifies if the resolved profile actually
-- moved, so a spec change with no spec rule set costs one string comparison.
local lastResolved

function Database:RefreshActiveProfile()
	-- Before reading, not after: a specialization change moves the answer without any
	-- rule changing, which is the entire point of having a spec scope.
	invalidateResolution()
	local name = self:GetActiveProfileName()
	if name == lastResolved then
		return false
	end
	lastResolved = name
	if Pulse.debug then
		local _, _, why = self:GetProfileResolution()
		print(('Pulse: profile is now "%s" (%s)'):format(name, why))
	end
	notifyProfileSwitch()
	return true
end

function Database:SetProfileForScope(scope, name)
	if not DB.profiles[name] then
		return false, "no such profile"
	end

	if scope == SCOPE_SPEC then
		local key = specKey()
		if not key then
			return false, "this character has no specialization"
		end
		DB.specProfile[key] = name
	elseif scope == SCOPE_CHARACTER then
		DB.charProfile[characterKey()] = name
	elseif scope == SCOPE_ACCOUNT then
		DB.accountProfile = name
	else
		return false, "no such scope"
	end

	invalidateResolution()
	lastResolved = self:GetActiveProfileName()
	notifyProfileSwitch()
	return true
end

function Database:ClearProfileForScope(scope)
	if scope == SCOPE_SPEC then
		local key = specKey()
		if not key then
			return false, "this character has no specialization"
		end
		DB.specProfile[key] = nil
	elseif scope == SCOPE_CHARACTER then
		DB.charProfile[characterKey()] = nil
	elseif scope == SCOPE_ACCOUNT then
		DB.accountProfile = nil
	else
		return false, "no such scope"
	end

	invalidateResolution()
	lastResolved = self:GetActiveProfileName()
	notifyProfileSwitch()
	return true
end

-- Writes to the most specific scope currently in force, so choosing from the dropdown
-- changes what you are actually using rather than editing a rule something more specific
-- overrides — WITH ONE EXCEPTION: it never writes the account rule.
--
-- Changing what every character does is a deliberate act and belongs to the "Every
-- character" dropdown alone. When the account rule (or nothing) is in force this writes the
-- character rule instead, which wins over the account rule, so the switch still takes
-- effect and only affects whoever asked for it. Found by the offline harness: "Copy this
-- profile" was quietly repointing every character at the new copy.
function Database:SetActiveProfileName(name)
	if not DB.profiles[name] then
		return
	end
	if self:GetActiveProfileName() == name then
		return
	end
	local scope = self:GetProfileResolution()
	if scope ~= SCOPE_SPEC and scope ~= SCOPE_CHARACTER then
		scope = SCOPE_CHARACTER
	end
	self:SetProfileForScope(scope, name)
end

-- DB_VERSION 5 -> 6. Purely additive: the old DB.charProfile IS the character scope and
-- keeps its shape and its contents, so an existing install resolves to exactly the
-- profile it resolved to yesterday. The two new scopes start empty.
function Database:_MigrateToProfileRules()
	DB.specProfile = DB.specProfile or {}
	-- DB.accountProfile is deliberately left nil rather than seeded to "Default":
	-- an unset account rule falls through to Default anyway, and seeding it would turn
	-- "nothing set" into a rule the player never made and would have to find and clear.
end

-- Seeded from Registry.lua's stock defaults, same as every built-in, then switches this
-- character to it — creating a profile is also choosing to use it, not adding an empty
-- slot.
function Database:CreateProfile(name)
	name = sanitizeProfileName(name)
	if not name then
		return false, "enter a name (up to 24 characters)"
	end
	if DB.profiles[name] then
		return false, ('a profile named "%s" already exists'):format(name)
	end
	DB.profiles[name] = {}
	copyDefaults(PROFILE_DEFAULTS, DB.profiles[name])
	self:_SeedProfileTriggerDefaults(DB.profiles[name])
	invalidateResolution()
	DB.customProfiles[#DB.customProfiles + 1] = name
	if Pulse.debug then
		print(('Pulse: created profile "%s"'):format(name))
	end
	self:SetActiveProfileName(name)
	return true
end

-- Copy an existing profile rather than starting from stock defaults, and switch to it.
-- CreateProfile seeds from Registry.lua, so "Raiding but quieter" meant rebuilding 151 cues
-- by hand. Pulse's profiles are siblings rather than a hierarchy, so there is no scope
-- above to inherit from and duplication has to be offered explicitly.
function Database:DuplicateProfile(sourceName, newName)
	if not DB.profiles[sourceName] then
		return false, "no such profile"
	end
	newName = sanitizeProfileName(newName)
	if not newName then
		return false, "enter a name (up to 24 characters)"
	end
	if DB.profiles[newName] then
		return false, ('a profile named "%s" already exists'):format(newName)
	end

	-- A deep copy, so the two are independent from the first edit. Seeding afterwards
	-- fills anything the source was missing — a profile made before a cue existed has a
	-- hole where that cue's default belongs, and the copy should not inherit the hole.
	DB.profiles[newName] = CopyTable(DB.profiles[sourceName])
	copyDefaults(PROFILE_DEFAULTS, DB.profiles[newName])
	self:_SeedProfileTriggerDefaults(DB.profiles[newName])
	invalidateResolution()
	DB.customProfiles[#DB.customProfiles + 1] = newName

	if Pulse.debug then
		print(('Pulse: copied profile "%s" to "%s"'):format(sourceName, newName))
	end
	self:SetActiveProfileName(newName)
	return true
end

-- Built-ins are permanent by design: always a known-safe fallback, and Registry.lua's own
-- defaults are one Reset click away regardless (ResetProfileToDefaults below).
function Database:RenameProfile(oldName, newName)
	if self:IsBuiltinProfile(oldName) then
		return false, "built-in profiles can't be renamed"
	end
	if not DB.profiles[oldName] then
		return false, "no such profile"
	end
	newName = sanitizeProfileName(newName)
	if not newName then
		return false, "enter a name (up to 24 characters)"
	end
	if newName == oldName then
		return true
	end
	if DB.profiles[newName] then
		return false, ('a profile named "%s" already exists'):format(newName)
	end

	DB.profiles[newName] = DB.profiles[oldName]
	DB.profiles[oldName] = nil
	for i, name in ipairs(DB.customProfiles) do
		if name == oldName then
			DB.customProfiles[i] = newName
			break
		end
	end
	-- Every rule pointing at the old name follows it, so a rename strands nobody back on
	-- Default. All three scopes: fixing up only the character rules would break a spec one.
	for charKey, profileName in pairs(DB.charProfile) do
		if profileName == oldName then
			DB.charProfile[charKey] = newName
		end
	end
	for key, profileName in pairs(DB.specProfile) do
		if profileName == oldName then
			DB.specProfile[key] = newName
		end
	end
	if DB.accountProfile == oldName then
		DB.accountProfile = newName
	end
	invalidateResolution()
	if Pulse.debug then
		print(('Pulse: renamed profile "%s" to "%s"'):format(oldName, newName))
	end
	return true
end

-- Wipe-then-reseed, the same two steps CreateProfile uses. Passing
-- PROFILE_TRIGGER_OVERRIDES[name] — nil for Default and any custom profile, the curated
-- table for Raiding/Questing/PvP — means resetting a built-in restores ITS defaults rather
-- than blank Registry.lua ones with the curation stripped out. Wiping the whole
-- triggerSettings table also clears per-trigger __mode overrides and any future per-mode
-- tuning, not just the keys this function knows about.
function Database:ResetProfileToDefaults(name)
	name = name or self:GetActiveProfileName()
	if not DB.profiles[name] then
		return false, "no such profile"
	end

	DB.profiles[name] = {}
	copyDefaults(PROFILE_DEFAULTS, DB.profiles[name])
	self:_SeedProfileTriggerDefaults(DB.profiles[name], PROFILE_TRIGGER_OVERRIDES[name])
	local meta = self:GetDefaultProfileMeta(name)
	if meta and meta.intensity then
		DB.profiles[name].masterIntensity = meta.intensity
	end

	if Pulse.debug then
		print(('Pulse: reset profile "%s" to defaults'):format(name))
	end
	if self:GetActiveProfileName() == name then
		notifyProfileSwitch()
	end
	return true
end

function Database:DeleteProfile(name)
	if self:IsBuiltinProfile(name) then
		return false, "built-in profiles can't be deleted"
	end
	if not DB.profiles[name] then
		return false, "no such profile"
	end

	local wasActiveHere = (self:GetActiveProfileName() == name)

	DB.profiles[name] = nil
	for i, existing in ipairs(DB.customProfiles) do
		if existing == name then
			table.remove(DB.customProfiles, i)
			break
		end
	end
	-- Every rule naming the deleted profile is CLEARED rather than rewritten to "Default".
	-- Clearing is what the scope system already means by "no opinion": the rule falls
	-- through to the next scope down. Rewriting would invent an explicit rule the player
	-- never made. ruleFor already treats a dangling name as unset, so this is tidying.
	for charKey, profileName in pairs(DB.charProfile) do
		if profileName == name then
			DB.charProfile[charKey] = nil
		end
	end
	for key, profileName in pairs(DB.specProfile) do
		if profileName == name then
			DB.specProfile[key] = nil
		end
	end
	if DB.accountProfile == name then
		DB.accountProfile = nil
	end
	invalidateResolution()
	if Pulse.debug then
		print(('Pulse: deleted profile "%s"'):format(name))
	end
	if wasActiveHere then
		notifyProfileSwitch()
	end
	return true
end

local function activeProfile()
	local name = Database:GetActiveProfileName()
	local profile = DB and DB.profiles and DB.profiles[name]
	if not profile then
		profile = DB and DB.profiles and DB.profiles["Default"]
	end
	return profile or PROFILE_DEFAULTS
end

function Database:Get(key)
	if key == "masterIntensity" then
		return activeProfile().masterIntensity
	end
	return DB[key]
end

function Database:Set(key, value)
	if issecretvalue(value) then
		return
	end
	if key == "masterIntensity" then
		value = sanitizeNumber(value, 0.0, 1.0)
		if value == nil then
			return
		end
		activeProfile().masterIntensity = value
		if Pulse.debug then
			print(("Pulse: %s set to %s"):format(key, tostring(value)))
		end
		notify(globalListeners, key)
		return
	end
	local default = GLOBAL_DEFAULTS[key]
	if type(default) == "boolean" then
		value = sanitizeBool(value)
	elseif key == "defaultHapticSchema" then
		if not Pulse.HapticSchemas[value] then
			return
		end
	else
		return
	end
	if value == nil then
		return
	end
	DB[key] = value
	if Pulse.debug then
		print(("Pulse: %s set to %s"):format(key, tostring(value)))
	end
	notify(globalListeners, key)
end

function Database:GetCue(triggerID)
	return activeProfile().triggers[triggerID] and true or false
end

function Database:SetCue(triggerID, enabled)
	enabled = sanitizeBool(enabled)
	if enabled == nil then
		return
	end
	activeProfile().triggers[triggerID] = enabled
	if Pulse.debug then
		local trigger = Pulse.Registry:GetTrigger(triggerID)
		print(("Pulse: %s %s"):format(trigger and trigger.label or triggerID, enabled and "enabled" or "disabled"))
	end
	notify(cueListeners, triggerID)
end

-- Generic per-trigger numeric settings, for a trigger needing a dial beyond on/off — e.g.
-- lowHealthWarning's heartbeat interval. Declared via Pulse.Triggers[*].tunables
-- (Core/Registry.lua) and rendered generically by UI/Panel/Spec.lua, so a trigger gains a
-- slider with no UI file edit.
function Database:GetTriggerSetting(triggerID, settingKey, default)
	local settings = activeProfile().triggerSettings[triggerID]
	local value = settings and settings[settingKey]
	if value == nil then
		return default
	end
	return value
end

function Database:SetTriggerSetting(triggerID, settingKey, value, minValue, maxValue)
	value = sanitizeNumber(value, minValue, maxValue)
	if value == nil then
		return
	end
	local profile = activeProfile()
	profile.triggerSettings[triggerID] = profile.triggerSettings[triggerID] or {}
	profile.triggerSettings[triggerID][settingKey] = value
	if Pulse.debug then
		local trigger = Pulse.Registry:GetTrigger(triggerID)
		print(("Pulse: %s %s set to %.2f"):format(trigger and trigger.label or triggerID, settingKey, value))
	end
	notify(triggerSettingListeners, triggerID .. ":" .. settingKey)
end

-- Per-mode motor/duration tuning. Global, not per-profile: like masterEnabled and
-- defaultHapticSchema this is hardware calibration ("THUD hits too hard on my controller"),
-- not a playstyle choice. DB.modeTuning is lazily created like DB.customProfiles rather
-- than folded into GLOBAL_DEFAULTS' copyDefaults pass, being nested rather than a scalar.
function Database:GetModeTuning(modeID, key, default)
	local t = DB.modeTuning and DB.modeTuning[modeID]
	local value = t and t[key]
	if value == nil then
		return default
	end
	return value
end

function Database:SetModeTuning(modeID, key, value, minValue, maxValue)
	value = sanitizeNumber(value, minValue, maxValue)
	if value == nil then
		return
	end
	DB.modeTuning = DB.modeTuning or {}
	DB.modeTuning[modeID] = DB.modeTuning[modeID] or {}
	DB.modeTuning[modeID][key] = value
	if Pulse.debug then
		print(("Pulse: mode %s %s set to %.2f"):format(modeID, key, value))
	end
	notify(modeTuningListeners, modeID .. ":" .. key)
end

-- The Reset button on the Motor & Timing page: every mode's low/high/duration multiplier
-- back to 1.0 (GetModeTuning's own default), in one shot rather than per-mode.
function Database:ResetModeTuning()
	DB.modeTuning = {}
	if Pulse.debug then
		print("Pulse: mode tuning reset to defaults")
	end
	notifyAll(modeTuningListeners)
end

-- Per-channel hardware calibration (Core/Devices.lua). Global for the reason modeTuning is:
-- which motors a controller has and how hard they must be driven is a property of the
-- plastic in your hands, not of whether you are raiding. Stored and notified the same lazy
-- way, so nothing here touches the profile machinery.
local channelTuningListeners = {}

function Database:OnChannelTuningChanged(channel, key, callback)
	subscribe(channelTuningListeners, channel .. ":" .. key, callback)
end

function Database:GetChannelTuning(channel, key, default)
	local t = DB.channelTuning and DB.channelTuning[channel]
	local value = t and t[key]
	if value == nil then
		return default
	end
	return value
end

function Database:SetChannelTuning(channel, key, value, minValue, maxValue)
	value = sanitizeNumber(value, minValue, maxValue)
	if value == nil then
		return
	end
	DB.channelTuning = DB.channelTuning or {}
	DB.channelTuning[channel] = DB.channelTuning[channel] or {}
	DB.channelTuning[channel][key] = value
	if Pulse.debug then
		print(("Pulse: channel %s %s set to %.3f"):format(channel, key, value))
	end
	notify(channelTuningListeners, channel .. ":" .. key)
end

function Database:ResetChannelTuning()
	DB.channelTuning = {}
	-- The preset label goes with the values it stood for. Left behind, the page shows
	-- "Xbox (One / Series)" selected while every slider is back at CHANNEL_DEFAULTS — a
	-- dropdown claiming a preset that is not in force.
	DB.devicePreset = "default"
	if Pulse.debug then
		print("Pulse: controller calibration reset to defaults")
	end
	notifyAll(channelTuningListeners)
end

-- Which controller preset the player picked (Core/Devices.lua). Remembered only as a label:
-- selecting one does nothing until Apply writes its values into channelTuning, so the
-- sliders always show the real numbers in force rather than a preset name standing in for
-- values you cannot see. Global, like the rest of the calibration.
function Database:GetDevicePreset()
	local id = DB.devicePreset
	if not id or not Pulse.Devices[id] then
		return "default"
	end
	return id
end

function Database:SetDevicePreset(id)
	if not Pulse.Devices[id] then
		return
	end
	DB.devicePreset = id
end

-- Overwrites every channel's calibration with the preset's values, falling back to
-- CHANNEL_DEFAULTS for any channel or key it does not mention. Destructive on purpose and
-- confirmed at the call site: a preset is a fresh starting point, not a layer sitting under
-- numbers you already trimmed.
function Database:ApplyDevicePreset(id)
	local device = Pulse.Devices[id]
	if not device then
		return false, "no such controller preset"
	end

	DB.channelTuning = {}
	for _, channel in ipairs(Pulse.CHANNELS) do
		local overrides = device.channels and device.channels[channel]
		local target = {}
		for key, default in pairs(Pulse.CHANNEL_DEFAULTS) do
			target[key] = (overrides and overrides[key]) or default
		end
		DB.channelTuning[channel] = target
	end

	self:SetDevicePreset(id)
	if Pulse.debug then
		print(('Pulse: applied controller preset "%s"'):format(device.label or id))
	end
	notifyAll(channelTuningListeners)
	return true
end

-- Locomotion's resolved character facts (Modules/Locomotion.lua): race token, riding tier,
-- boot-armour weight. Persisted rather than cached in module state because they are looked
-- up once at login and treated as constant for the session — a login where UnitRace or the
-- item cache is not warm would otherwise use a generic gait for that whole session, and the
-- last known values are a better guess than "Human". Global: your race is not a playstyle.
function Database:GetLocomotionProfile()
	local t = DB.locomotionProfile
	if type(t) ~= "table" then
		return nil
	end
	return t
end

function Database:SetLocomotionProfile(race, ridingTier, armorMultiplier)
	if issecretvalue(race) or type(race) ~= "string" then
		return
	end
	DB.locomotionProfile = {
		race = race,
		ridingTier = sanitizeNumber(ridingTier, 0, 3) or 0,
		armorMultiplier = sanitizeNumber(armorMultiplier, 0.1, 2.0) or 1.0,
	}
end

-- The one non-per-channel calibration value — see Devices.lua's CHANGE_EPSILON_DEFAULT.
function Database:GetChangeEpsilon()
	local value = DB.changeEpsilon
	if value == nil then
		return Pulse.CHANGE_EPSILON_DEFAULT
	end
	return value
end

function Database:SetChangeEpsilon(value)
	value = sanitizeNumber(value, 0.0, 0.05)
	if value == nil then
		return
	end
	DB.changeEpsilon = value
	if Pulse.debug then
		print(("Pulse: change threshold set to %.4f"):format(value))
	end
end

-- Per-trigger mode override: lets a discrete trigger play a different Core/Modes.lua shape
-- than its Registry.lua default without touching the trigger's definition. Stored under the
-- reserved "__mode" key in the same triggerSettings table the numeric tunables use — the
-- leading double-underscore cannot collide with a real tunable key, which is always a plain
-- identifier like "beatInterval". Reuses OnTriggerSettingChanged/notify (subscribe on
-- settingKey "__mode") rather than a parallel listener table for one more setting shape.
function Database:GetTriggerMode(triggerID)
	local settings = activeProfile().triggerSettings[triggerID]
	return settings and settings.__mode or nil
end

function Database:SetTriggerMode(triggerID, modeID)
	-- nil is a legal value here — it means "clear the override, fall back to the
	-- trigger's own default mode" — so only a non-nil, unrecognised mode name is rejected.
	if modeID ~= nil and not Pulse.Modes[modeID] then
		return
	end
	local profile = activeProfile()
	profile.triggerSettings[triggerID] = profile.triggerSettings[triggerID] or {}
	profile.triggerSettings[triggerID].__mode = modeID
	if Pulse.debug then
		local trigger = Pulse.Registry:GetTrigger(triggerID)
		print(("Pulse: %s mode override -> %s"):format(trigger and trigger.label or triggerID, modeID or "(default)"))
	end
	notify(triggerSettingListeners, triggerID .. ":__mode")
end

Database.GLOBAL_DEFAULTS = GLOBAL_DEFAULTS
Database.PROFILE_DEFAULTS = PROFILE_DEFAULTS
