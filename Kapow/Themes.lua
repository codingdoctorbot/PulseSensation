-- KAPOW — Themes.lua
--
-- A theme is a ready-made look for every event: titles, detail lines, art, animation,
-- color, font and sound. Applying one to a profile rewrites its event looks (a player's
-- customisations on that profile are replaced) and keeps which events are on, apart from
-- the events a theme turns on itself. "New from theme" in the Profiles tab starts a fresh
-- profile instead.
--
-- Themes are homages to genres, under names of their own: Roadfighter (arcade fighters),
-- Shadow Clan (ninja action), Boomer Shooter (old-school arena shooters), Strike Squad
-- (round-based tactical shooters), Soccer League (football broadcasts).
--
-- ART. An event uses a theme's art when the catalog has it (the word is in the art, so the
-- title is then artTitle, default none) and the theme's title text when not. Art added
-- later (manifest + scripts/make-art-catalog.py) is picked up by applying the theme again.

local _, ns = ...

local T = {}
ns.themes = T

-- Shorthand for the event tables below.
local function Text(title, sub, extra)
	local look = { title = title, sub = sub }
	for k, v in pairs(extra or {}) do
		look[k] = v
	end
	return look
end

local KILLS = "{count} kills"

T.LIST = {
	{
		id = "classic",
		label = "Classic",
		description = "KAPOW's own defaults: comic hits, arena announcer, art fonts.",
		events = {},
	},
	{
		id = "comic",
		label = "Comic chaos",
		description = "A random comic burst for every kill and streak, in comic lettering.",
		all = { anim = "flipbook", font = "bangers" },
		events = {
			kill = { art = "random:comic" },
			firstblood = { art = "comic/krakoom" },
			double = { art = "random:comic" },
			triple = { art = "random:comic" },
			multi = { art = "random:comic" },
			mega = { art = "comic/krakoom" },
			spree5 = { art = "random:comic" },
			spree10 = { art = "comic/boom" },
			interrupt = { art = "comic/zap" },
			hardlanding = { art = "comic/splat" },
			falldeath = { art = "comic/crash" },
		},
	},
	{
		id = "roadfighter",
		label = "Roadfighter",
		description = "Arcade fighting game: combos, counters, perfects and insert coin.",
		all = { font = "russo-one", anim = "slam", color = "gold" },
		enable = { kickoff = true, fulltime = true },
		events = {
			crit = Text("COMBO!", "{amount}", { color = "orange" }),
			kill = Text("K.O.!", "{amount}", { art = "comic/ko" }),
			critkill = Text("SUPER COMBO!", "{amount}", { art = "arcade/super-combo" }),
			firstblood = Text("FIRST ATTACK", "{killer} lands the first hit on {victim}"),
			double = Text("2 HIT COMBO", KILLS),
			triple = Text("3 HIT COMBO", KILLS),
			multi = Text("4 HIT COMBO", KILLS),
			mega = Text("5 HIT COMBO", KILLS),
			ultra = Text("6 HIT COMBO", KILLS),
			monster = Text("7 HIT COMBO", KILLS),
			ludicrous = Text("ULTRA COMBO", KILLS, { color = "red" }),
			spree5 = Text("WINNING STREAK", "{count} without a loss"),
			spree10 = Text("UNBEATABLE", "{count} without a loss"),
			spree15 = Text("CHAMPION", "{count} without a loss"),
			spree20 = Text("GRAND MASTER", "{count} without a loss"),
			spree25 = Text("LEGENDARY", "{count} without a loss"),
			spree30 = Text("FINAL BOSS", "{count} without a loss", { color = "red" }),
			kickoff = Text("ROUND 1 ... FIGHT!", "", { sound = "random:fightstart" }),
			fulltime = Text("YOU WIN!", "{count} K.O.s", { sound = "random:victory" }),
			mvp = Text("BEST FIGHTER", "{name}  ·  {count} of {total} K.O.s"),
			flawless = Text("PERFECT!", "Not a scratch", { art = "arcade/perfect" }),
			youdied = Text("GAME OVER", "Insert coin", { color = "red" }),
			teammate = Text("PARTNER DOWN", "{name}", { color = "red" }),
			laststanding = Text("LAST FIGHTER", "It's all on you", { color = "red" }),
			wipe = Text("CONTINUE?", "10 ... 9 ... 8 ...", { color = "red" }),
			petdown = Text("SIDEKICK DOWN", "", { color = "red" }),
			interrupt = Text("COUNTER!", "You countered {name}", { art = "arcade/counter", color = "blue" }),
			interrupted = Text("GUARD BREAK", "by {name}", { color = "red" }),
			bossdown = Text("YOU WIN!", "{name}", { color = "green" }),
			encwipe = Text("CONTINUE?", "{name}", { color = "red" }),
			levelup = Text("LEVEL UP!", "Level {level}", { color = "green" }),
			falling = Text("RING OUT?", "", { anim = "shake" }),
			hardlanding = Text("TECH LANDING", "{time} s in the air"),
			falldeath = Text("RING OUT!", "Fell for {time} s", { color = "red" }),
			avoid = Text("BLOCKED!", "{name}", { color = "white" }),
		},
	},
	{
		id = "shadowclan",
		label = "Shadow Clan",
		description = "Ninja action: shadow strikes, executions and silent cuts.",
		all = { font = "shojumaru", anim = "slam", color = "red" },
		events = {
			crit = Text("SHADOW STRIKE!", "{amount}", { art = "ninja/shadow-strike" }),
			kill = Text("SLAIN", "{amount}", { color = "white" }),
			critkill = Text("EXECUTED!", "{amount}", { art = "ninja/executed" }),
			firstblood = Text("FIRST CUT", "{killer} draws first blood on {victim}"),
			double = Text("TWIN BLADES", KILLS),
			triple = Text("THREE SHADOWS", KILLS),
			multi = Text("BLADE STORM", KILLS),
			mega = Text("OBLITERATED!", KILLS, { art = "ninja/obliterated" }),
			ultra = Text("THOUSAND CUTS", KILLS),
			monster = Text("NIGHT TERROR", KILLS),
			ludicrous = Text("DEMON BLADE", KILLS),
			spree5 = Text("SILENT DEATH", "{count} unseen"),
			spree10 = Text("SHADOW WALKER", "{count} unseen"),
			spree15 = Text("MASTER ASSASSIN", "{count} unseen"),
			spree20 = Text("GHOST", "{count} unseen"),
			spree25 = Text("LIVING LEGEND", "{count} unseen"),
			spree30 = Text("GRANDMASTER", "{count} unseen"),
			mvp = Text("CLAN CHAMPION", "{name}  ·  {count} of {total} kills"),
			flawless = Text("UNSEEN", "Nobody fell", { color = "white" }),
			youdied = Text("DEFEATED", "", { color = "red" }),
			teammate = Text("CLANSMAN DOWN", "{name}", { color = "red" }),
			laststanding = Text("LONE BLADE", "It's all on you"),
			wipe = Text("CLAN FALLEN", ""),
			petdown = Text("COMPANION DOWN", ""),
			interrupt = Text("SEVERED", "You silenced {name}", { color = "white" }),
			interrupted = Text("BROKEN STANCE", "by {name}"),
			bossdown = Text("VANQUISHED", "{name}", { color = "white" }),
			encwipe = Text("DISHONOURED", "{name}"),
			levelup = Text("NEW TECHNIQUE", "Level {level}", { color = "white" }),
			falling = Text("SHADOW DROP", "", { anim = "shake", color = "white" }),
			hardlanding = Text("NOT SO SILENT", "{time} s in the air"),
			falldeath = Text("MISSED THE ROOF", "Fell for {time} s"),
			avoid = Text("EVADED!", "{name}", { color = "white" }),
		},
	},
	{
		id = "boomer",
		label = "Boomer Shooter",
		description = "Old-school arena shooter: frags, gibs, rampages, heavy metal lettering.",
		all = { font = "metal-mania", anim = "shake", color = "red" },
		events = {
			crit = Text("BOOM!", "{amount}", { color = "orange" }),
			kill = Text("FRAGGED!", "{amount}", { art = "arena/fragged" }),
			critkill = Text("GIBBED!", "{amount}", { art = "arena/gibbed" }),
			firstblood = Text("FIRST FRAG", "{killer} fragged {victim} first"),
			double = Text("DOUBLE KILL", KILLS, { art = "escalation/double-kill" }),
			triple = Text("TRIPLE KILL", KILLS),
			multi = Text("MULTIKILL!", KILLS, { art = "escalation/multikill" }),
			mega = Text("MEGA KILL", KILLS),
			ultra = Text("ULTRA KILL", KILLS),
			monster = Text("MONSTER KILL", KILLS),
			ludicrous = Text("LUDICROUS KILL", KILLS),
			spree5 = Text("KILLING SPREE", "{count} frags without dying"),
			spree10 = Text("RAMPAGE!", "{count} frags without dying", { art = "escalation/rampage" }),
			spree15 = Text("DOMINATING", "{count} frags without dying"),
			spree20 = Text("UNSTOPPABLE", "{count} frags without dying"),
			spree25 = Text("GODLIKE", "{count} frags without dying"),
			spree30 = Text("WICKED SICK", "{count} frags without dying"),
			mvp = Text("TOP FRAGGER", "{name}  ·  {count} of {total} frags"),
			flawless = Text("FLAWLESS", "Nobody respawned", { color = "green" }),
			youdied = Text("YOU DIED", "Press jump to respawn"),
			teammate = Text("TEAMMATE FRAGGED", "{name}"),
			laststanding = Text("LAST MAN STANDING", "It's all on you"),
			wipe = Text("TEAM WIPED", ""),
			petdown = Text("PET GIBBED", ""),
			interrupt = Text("SHUT UP!", "You silenced {name}", { color = "orange" }),
			interrupted = Text("TELEFRAGGED", "by {name}"),
			bossdown = Text("LEVEL COMPLETE", "{name}", { color = "green" }),
			encwipe = Text("TRY AGAIN", "{name}"),
			levelup = Text("SECRET FOUND", "Level {level}", { color = "green" }),
			falling = Text("AAAAAAH!", "", { color = "white" }),
			hardlanding = Text("OOF!", "{time} s in the air", { color = "orange" }),
			falldeath = Text("GIBBED BY GRAVITY", "Fell for {time} s", { art = "arena/gibbed" }),
			avoid = Text("MISSED!", "{name}", { color = "white" }),
		},
	},
	{
		id = "tactical",
		label = "Strike Squad",
		description = "Round-based tactical shooter: headshots, 2K to ACE, clutches, bombs and team wins.",
		all = { font = "black-ops-one", anim = "slam", color = "orange" },
		enable = { kickoff = true, fulltime = true },
		events = {
			crit = Text("NICE SHOT", "{amount}", { color = "white" }),
			kill = Text("ENEMY DOWN", "{amount}"),
			critkill = Text("HEADSHOT", "{amount}", { art = "tactical/headshot" }),
			firstblood = Text("ENTRY FRAG", "{killer} opened the round on {victim}"),
			double = Text("2K", KILLS),
			triple = Text("3K", KILLS),
			multi = Text("4K", KILLS),
			mega = Text("ACE", "5 kills", { art = "tactical/ace" }),
			ultra = Text("ACE +1", KILLS),
			monster = Text("ACE +2", KILLS),
			ludicrous = Text("ANTI-CHEAT ALERT", KILLS, { color = "red" }),
			spree5 = Text("ON FIRE", "{count} without dying"),
			spree10 = Text("UNSTOPPABLE", "{count} without dying"),
			spree15 = Text("RAMPAGE", "{count} without dying"),
			spree20 = Text("TOP FRAGGER", "{count} without dying"),
			spree25 = Text("GRAND CHAMPION", "{count} without dying"),
			spree30 = Text("LEGEND", "{count} without dying"),
			kickoff = Text("GO GO GO!", "", { sound = "random:fightstart" }),
			fulltime = Text("ROUND OVER", KILLS, { color = "white" }),
			mvp = Text("ROUND MVP", "{name}  ·  {count} of {total} kills"),
			flawless = Text("FLAWLESS ROUND", "Nobody died", { color = "green" }),
			youdied = Text("YOU ARE DEAD", "Spectating...", { color = "red" }),
			teammate = Text("TEAMMATE DOWN", "{name}", { color = "red" }),
			laststanding = Text("CLUTCH", "1vX: it's on you", { art = "tactical/clutch" }),
			wipe = Text("TERRORISTS WIN", "", { art = "tactical/terrorists-win", color = "red" }),
			petdown = Text("K9 DOWN", "", { color = "red" }),
			interrupt = Text("BOMB DEFUSED", "You stopped {name}", { art = "tactical/bomb-defused", color = "blue" }),
			interrupted = Text("BOMB PLANTED", "by {name}", { art = "tactical/bomb-planted", color = "red" }),
			bossdown = Text("COUNTER-TERRORISTS WIN", "{name}", { art = "tactical/counter-terrorists-win", color = "blue" }),
			encwipe = Text("TERRORISTS WIN", "{name}", { art = "tactical/terrorists-win", color = "red" }),
			levelup = Text("RANK UP", "Level {level}", { color = "green" }),
			falling = Text("FIRE IN THE HOLE!", "", { anim = "shake" }),
			hardlanding = Text("FALL DAMAGE", "{time} s in the air"),
			falldeath = Text("SELF-ELIMINATED", "Fall damage, {time} s", { color = "red" }),
			avoid = Text("WHIFFED", "{name}", { color = "white" }),
		},
	},
	{
		id = "football",
		label = "Soccer League",
		description = "Football broadcast: goals, top bins, hat-tricks, red cards, VAR and clean sheets.",
		all = { font = "graduate", anim = "bounce", color = "white" },
		enable = { kickoff = true, fulltime = true },
		events = {
			crit = Text("WHAT A STRIKE!", "{amount}"),
			kill = Text("GOAL!", "{amount}", { art = "football/goal", color = "green" }),
			critkill = Text("TOP BINS!", "{amount}", { art = "football/top-bins", color = "green" }),
			firstblood = Text("OPENING GOAL", "{killer} scores first against {victim}", { color = "green" }),
			double = Text("BRACE!", "{count} goals"),
			triple = Text("HAT-TRICK!", "{count} goals", { art = "football/hat-trick", color = "gold" }),
			multi = Text("POKER!", "{count} goals"),
			mega = Text("MANITA!", "{count} goals", { color = "gold" }),
			ultra = Text("DOUBLE HAT-TRICK!", "{count} goals", { color = "gold" }),
			monster = Text("SEVEN UP!", "{count} goals", { color = "gold" }),
			ludicrous = Text("THRASHING!", "{count} goals", { color = "gold" }),
			spree5 = Text("IN FORM", "{count} goals unbeaten"),
			spree10 = Text("UNBEATEN RUN", "{count} goals unbeaten"),
			spree15 = Text("TITLE CHARGE", "{count} goals unbeaten"),
			spree20 = Text("INVINCIBLES", "{count} goals unbeaten", { color = "gold" }),
			spree25 = Text("LEGEND", "{count} goals unbeaten", { color = "gold" }),
			spree30 = Text("G.O.A.T.", "{count} goals unbeaten", { color = "gold" }),
			kickoff = Text("KICK-OFF", "", { sound = "countdown" }),
			fulltime = Text("FULL TIME", "{count} goals"),
			mvp = Text("PLAYER OF THE MATCH", "{name}  ·  {count} goals", { color = "gold" }),
			flawless = Text("CLEAN SHEET", "Nobody went down", { color = "green" }),
			youdied = Text("RED CARD", "Off you go", { art = "football/red-card", color = "red" }),
			teammate = Text("INJURY", "{name} is down", { color = "red" }),
			laststanding = Text("LAST DEFENDER", "It's all on you", { color = "red" }),
			wipe = Text("RELEGATED", "", { color = "red" }),
			petdown = Text("MASCOT DOWN", "", { color = "red" }),
			interrupt = Text("TACKLE!", "You stopped {name}", { color = "green" }),
			interrupted = Text("OFFSIDE!", "by {name}", { art = "football/offside", color = "gold" }),
			bossdown = Text("CHAMPIONS!", "{name}", { color = "gold" }),
			encwipe = Text("VAR CHECK", "{name}: what went wrong?", { art = "football/var-check", color = "purple" }),
			levelup = Text("PROMOTED", "Level {level}", { color = "green" }),
			falling = Text("DIVE!", "", { anim = "shake" }),
			hardlanding = Text("SIMULATION!", "{time} s in the air", { color = "gold" }),
			falldeath = Text("OWN GOAL", "Gravity scores", { art = "football/own-goal", color = "red" }),
			avoid = Text("WHAT A SAVE!", "{name}", { art = "football/what-a-save" }),
		},
	},
}

local BY_ID = {}
for _, theme in ipairs(T.LIST) do
	BY_ID[theme.id] = theme
end
BY_ID.counterstrike = BY_ID.tactical -- the theme's id before it was renamed

function T.Get(id)
	return BY_ID[id]
end

-- Rewrites every event look of `profile` to `themeId`. Which events are on is kept, except
-- those the theme turns on.
function T.Apply(profile, themeId)
	local theme = BY_ID[themeId]
	if not theme then
		return false
	end
	for _, def in ipairs(ns.EVENTS) do
		local cfg = profile.events[def.id]
		local enabled = cfg.enabled
		for field, value in pairs(ns.EventDefaults(def.id)) do
			cfg[field] = value
		end
		cfg.enabled = enabled
		if theme.enable and theme.enable[def.id] then
			cfg.enabled = true
		end
		for field, value in pairs(theme.all or {}) do
			cfg[field] = value
		end
		local look = theme.events[def.id]
		if look then
			for field, value in pairs(look) do
				if field ~= "art" and field ~= "artTitle" then
					cfg[field] = value
				end
			end
			if look.art and ns.art.Resolve(look.art) then
				cfg.art = look.art
				-- The word is in the art; a title of its own would say it twice.
				if look.title then
					cfg.title = look.artTitle or ""
				end
			elseif look.title then
				cfg.art = "none"
			end
		end
	end
	return true
end
