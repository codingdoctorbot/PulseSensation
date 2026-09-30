-- PulseAudio — SoundBank.lua
--
-- Curated sound kits and earcon definitions mapped from tactile haptic modes.
-- Uses Blizzard built-in SOUNDKIT constants to avoid missing sound assets.
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC), and Rule 5 (Taint Immunity).

local _, Audio = ...

Audio.SoundBank = {}
local SB = Audio.SoundBank

-- Sound themes
SB.THEMES = {
	MECHANICAL = "mechanical",
	SUBTLE = "subtle",
	TACTICAL = "tactical",
}

-- Default SOUNDKIT fallback IDs (verified across Classic & Modern clients)
-- If a SOUNDKIT variable is missing in a client build, numeric fallback IDs are used.
local SK = _G.SOUNDKIT or {}

local SAMPLES = {
	CLICK_LIGHT = SK.IG_MAINMENU_OPTION_CHECKBOX_ON or 856,
	CLICK_HEAVY = SK.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857,
	THUD = SK.GLUE_CHARACTER_SELECT_ENTER_WORLD or 1115,
	KNOCK = SK.IG_QUEST_LOG_OPEN or 875,
	BURST = SK.UI_BAG_SORTING_01 or 138144,
	HEARTBEAT = SK.ALARM_CLOCK_WARNING_3 or 14389,
	SURGE = SK.SPELL_FAILED_DEFAULT or 5424,
	ALERT = SK.RAID_WARNING or 8959,
	SWOOSH = SK.LOOT_WINDOW_COIN_SOUND or 120,
	SUBTLE_TICK = SK.IG_MINIMAP_ZOOM_IN or 899,
	SUBTLE_THUMP = SK.IG_MINIMAP_ZOOM_OUT or 900,
}

SB.THEME_PROFILES = {
	[SB.THEMES.MECHANICAL] = {
		label = "Mechanical Switch / Relay",
		desc = "Crisp, tactile micro-switches and mechanical relay strikes.",
		modes = {
			CLICK = SAMPLES.CLICK_LIGHT,
			TICK = SAMPLES.SUBTLE_TICK,
			TAP = SAMPLES.CLICK_LIGHT,
			MICRO_TAP = SAMPLES.SUBTLE_TICK,
			THUD = SAMPLES.THUD,
			KNOCK = SAMPLES.KNOCK,
			BURST = SAMPLES.BURST,
			HEAVY_IMPACT = SAMPLES.THUD,
			HEARTBEAT = SAMPLES.HEARTBEAT,
			WARNINGBEAT = SAMPLES.ALERT,
			SURGE = SAMPLES.SURGE,
		},
		defaultLow = SAMPLES.THUD,
		defaultHigh = SAMPLES.CLICK_LIGHT,
	},
	[SB.THEMES.SUBTLE] = {
		label = "Subtle Acoustic Ticks",
		desc = "Minimal, non-intrusive soft clicks and gentle thumps.",
		modes = {
			CLICK = SAMPLES.SUBTLE_TICK,
			TICK = SAMPLES.SUBTLE_TICK,
			TAP = SAMPLES.SUBTLE_TICK,
			MICRO_TAP = SAMPLES.SUBTLE_TICK,
			THUD = SAMPLES.SUBTLE_THUMP,
			KNOCK = SAMPLES.SUBTLE_THUMP,
			BURST = SAMPLES.SWOOSH,
			HEAVY_IMPACT = SAMPLES.SUBTLE_THUMP,
			HEARTBEAT = SAMPLES.SUBTLE_THUMP,
			WARNINGBEAT = SAMPLES.CLICK_HEAVY,
			SURGE = SAMPLES.SWOOSH,
		},
		defaultLow = SAMPLES.SUBTLE_THUMP,
		defaultHigh = SAMPLES.SUBTLE_TICK,
	},
	[SB.THEMES.TACTICAL] = {
		label = "Tactical Radar (Alerts)",
		desc = "High-contrast alarms for raid mechanics, procs, and interrupts.",
		modes = {
			CLICK = SAMPLES.CLICK_LIGHT,
			TICK = SAMPLES.SUBTLE_TICK,
			TAP = SAMPLES.CLICK_LIGHT,
			MICRO_TAP = SAMPLES.SUBTLE_TICK,
			THUD = SAMPLES.THUD,
			KNOCK = SAMPLES.KNOCK,
			BURST = SAMPLES.ALERT,
			HEAVY_IMPACT = SAMPLES.ALERT,
			HEARTBEAT = SAMPLES.HEARTBEAT,
			WARNINGBEAT = SAMPLES.ALERT,
			SURGE = SAMPLES.ALERT,
		},
		defaultLow = SAMPLES.THUD,
		defaultHigh = SAMPLES.ALERT,
	},
}

function SB:GetSoundID(themeName, modeName, role)
	local profile = self.THEME_PROFILES[themeName] or self.THEME_PROFILES[self.THEMES.MECHANICAL]
	if modeName and profile.modes[modeName] then
		return profile.modes[modeName]
	end

	if role == "low" then
		return profile.defaultLow
	elseif role == "high" then
		return profile.defaultHigh
	end
	return profile.defaultLow
end
