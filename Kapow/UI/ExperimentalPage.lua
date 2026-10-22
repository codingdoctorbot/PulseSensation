-- KAPOW — UI/ExperimentalPage.lua
--
-- The Experimental tab: features that work but behave in ways worth knowing about first
-- (hit sounds, interrupt streaks, the damage meter, the combat text unit, a kill statistic).
--
-- Hit sounds. The three hit frames are always played together and the wrong two are hidden
-- by the client from secret crit/death flags (Kapow.lua). A sound cannot be hidden that way,
-- so a hit event's sound plays only when the game tells the hit type plainly; with hidden
-- flags it stays silent unless "Also when the game hides the hit type" is on, which plays
-- every hit event's sound on every hit (the behaviour before this tab existed).

local _, ns = ...

local D = ns.display

local function Get(key)
	return function()
		return ns.db[key]
	end
end

local function Set(key)
	return function(value)
		ns.Set(key, value)
	end
end

local function SoundDropdown(eventId, label)
	local function text(key)
		local entry = D.SOUNDS[key]
		return entry and entry[1] or tostring(key)
	end
	return {
		type = "dropdown",
		label = label,
		tooltip = "The sound this hit event plays (Event sounds and Play sounds on hit events must be on).",
		needs = "hitSounds",
		get = function()
			return ns.db.events[eventId].sound
		end,
		set = function(value)
			ns.SetEvent(eventId, "sound", value)
		end,
		text = text,
		build = function(root, isSelected, setSelected)
			for _, key in ipairs(D.SOUND_ORDER) do
				root:CreateRadio(text(key), isSelected, setSelected, key)
			end
		end,
	}
end

local function Specs()
	return {
		{ type = "header", label = "Experimental" },
		{ type = "note", label = "Working, but with quirks. Each one says what to expect." },

		{ type = "header", label = "Art frames" },
		{
			type = "choice",
			label = "Three-frame timing",
			tooltip = "For animations that play the art's three frames.\n\nArt's timing: onset and peak flash by (80 ms, 120 ms) and the aftershock stays until it fades, as the art was drawn.\n\nHold the peak: the peak stays on screen and the aftershock arrives as it fades.",
			choices = { { "aftershock", "Art's timing" }, { "peak", "Hold the peak" } },
			get = Get("frameHold"),
			set = Set("frameHold"),
		},

		{ type = "header", label = "Hit sounds" },
		{
			type = "checkbox",
			label = "Play sounds on hit events",
			tooltip = "Lets Critical hit, Killing blow and Critical killing blow play their sound. When the game says plainly what kind of hit it was, only the matching sound plays. In combat the game can hide that; then hits stay silent unless the next option is on.",
			get = Get("hitSounds"),
			set = Set("hitSounds"),
		},
		{
			type = "checkbox",
			label = "Also when the game hides the hit type",
			tooltip = "When the game hides whether a hit was a crit or a kill, KAPOW cannot tell which sound fits. With this on, every hit then plays the sound of each hit event that has one (up to three at once), as before this tab existed.",
			needs = "hitSounds",
			get = Get("hitSoundsSecret"),
			set = Set("hitSoundsSecret"),
		},
		SoundDropdown("crit", "Critical hit sound"),
		SoundDropdown("kill", "Killing blow sound"),
		SoundDropdown("critkill", "Crit kill sound"),
		{ type = "note", label = "Needs Event sounds on (General tab)." },

		{ type = "header", label = "UwU mode" },
		{
			type = "checkbox",
			label = "UwU on crits",
			tooltip = "A cute word (uwu~, owo~, ara ara~, nya~...) floats up over your character on every crit, as the Forever UwU addon does. It follows the game's crit flag even when that is hidden, like the comic frames.",
			get = Get("uwu"),
			set = Set("uwu"),
		},
		{
			type = "dropdown",
			label = "UwU sound",
			tooltip = "Plays with it, only when the game says plainly that the hit was a crit (Event sounds must be on).",
			needs = "uwu",
			get = function()
				return ns.db.uwuSound
			end,
			set = function(value)
				ns.Set("uwuSound", value)
			end,
			text = function(key)
				local entry = D.SOUNDS[key]
				return entry and entry[1] or tostring(key)
			end,
			build = function(root, isSelected, setSelected)
				for _, key in ipairs(D.SOUND_ORDER) do
					local entry = D.SOUNDS[key]
					root:CreateRadio(entry and entry[1] or key, isSelected, setSelected, key)
				end
			end,
		},
		{
			type = "buttons",
			label = "Try it",
			tooltip = "Shows one UwU with a plain crit.",
			needs = "uwu",
			buttons = {
				{
					"UwU!",
					function()
						if ns.UwuPop then
							ns.UwuPop(true)
						end
					end,
				},
			},
		},

		{ type = "header", label = "Interrupts" },
		{
			type = "checkbox",
			label = "Streaks grow",
			tooltip = "Each interrupt in a row (yours, or one on you) pops a little bigger, up to double size, until the fight ends. Also fills the {count} token of both interrupt events.",
			get = Get("interruptGrow"),
			set = Set("interruptGrow"),
		},

		{ type = "column" },
		{ type = "header", label = "Damage meter" },
		{ type = "note", label = "Uses Blizzard's damage meter; switch it on in the game's options." },
		{
			type = "checkbox",
			label = "Overkill numbers on OVERKILL!",
			tooltip = "Adds the overkill of your killing hit to the Critical killing blow frame (+1,234 overkill) and fills the {overkill} token. To get one kill's overkill, the meter is read and CLEARED after every hit, so Blizzard's damage meter window stays empty while this is on (MidnightBattleText works the same way).",
			get = Get("meterOverkill"),
			set = Set("meterOverkill"),
		},
		{
			type = "checkbox",
			label = "Confirm interrupts with the damage meter",
			tooltip = "Counts your interrupt when the meter's interrupt count changes right after one of your interrupt spells, on any enemy, not only your target. Does not clear the meter.",
			get = Get("meterInterrupts"),
			set = Set("meterInterrupts"),
		},

		{ type = "header", label = "Combat text feed" },
		{
			type = "choice",
			label = "Combat text unit",
			tooltip = "The game's combat text follows one unit for every addon. Switch to target (as before): KAPOW points it at your target, which can make PulseHaptics' damage-taken cues fire on damage you deal, and MidnightFCT switches it back. Leave it alone: KAPOW never touches it and reads your target's hits from its own combat events, as MikScrollingBattleText and MidnightFCT do.",
			choices = { { "target", "Switch to target" }, { "leave", "Leave it alone" } },
			get = Get("feedUnit"),
			set = Set("feedUnit"),
		},

		{ type = "header", label = "Kill statistic" },
		{
			type = "checkbox",
			label = "A kill statistic confirms your kills",
			tooltip = "The server counts your kills in statistics. When the chosen one goes up, KAPOW shows a kill of yours (WarCult confirms PvP killing blows this way). Pick the statistic's number below.",
			get = Get("killStatistic"),
			set = Set("killStatistic"),
		},
		{
			type = "edit",
			label = "Statistic number",
			tooltip = "Its ID, from the list button.",
			needs = "killStatistic",
			width = 90,
			maxLetters = 9,
			get = function()
				return tostring(ns.db.killStatId or 0)
			end,
			set = function(text)
				local id = tonumber(text)
				if id and id >= 0 then
					ns.Set("killStatId", math.floor(id))
				end
			end,
		},
		{
			type = "buttons",
			label = "Find it",
			tooltip = "Prints every statistic with \"kill\" in its name, with its number, to chat.",
			buttons = {
				{
					"List kill statistics",
					function()
						if ns.detect then
							ns.detect.ListKillStatistics()
						end
					end,
				},
			},
		},
	}
end

ns.ui.pages.experimental = {
	label = "Experimental",
	order = 4,
	Build = function(parent)
		local rows, height = ns.ui.BuildColumns(parent, Specs())
		return {
			height = height,
			Refresh = function()
				for _, row in ipairs(rows) do
					row:RefreshValue()
					local needs = row.spec.needs
					if needs then
						row:SetRowEnabled((ns.db.enabled and ns.db[needs]) and true or false)
					end
				end
			end,
		}
	end,
}
