-- PulseComic — Events.lua
--
-- Every moment PulseComic can show, and what it shows by default. A profile stores one
-- config per event (profile.events[id]); anything missing falls back to the defaults here.
--
-- Per event:
--   enabled   show it at all
--   art       an Art.lua choice: a sequence, "random:<category>", "random:all" or "none"
--   anim      animation preset (Display.lua): flipbook, slam, bounce, rise, shake, static
--   title     text template drawn over / instead of the art ("" for none)
--   sub       detail-line template under it
--   details   whether the detail line shows (for hit events: the damage number)
--   color     title color key (Display.COLORS)
--   size      scale multiplier
--   pos       where it shows: comic, banner, low, left, right
--   sound     sound key (Display.SOUNDS)
--   font      font key for the title and detail line (Display.FONTS); "auto" matches the art
--
-- TEXT TEMPLATES. {token} fills from the event's values: {killer} {victim} {count} {amount}
-- {name} {level} {total} {time}. Values may be secret (an enemy's name, a damage amount), so a
-- template is turned into a plain format string plus an argument list and handed to
-- FontString:SetFormattedText, which draws secrets. Nothing here reads a value.

local _, ns = ...

-- Hit events are the three secret-gated comic frames in PulseComic.lua; every other event
-- is a banner from Announcer.lua.
ns.EVENTS = {
	-- Hits
	{ id = "crit", group = "hits", label = "Critical hit", hit = true, tokens = "{amount}",
		art = "comic/pow", anim = "flipbook", title = "", sub = "{amount}", pos = "comic", sound = "none" },
	{ id = "kill", group = "hits", label = "Killing blow", hit = true, tokens = "{amount}",
		art = "comic/ko", anim = "flipbook", title = "", sub = "{amount}", pos = "comic", sound = "none" },
	{ id = "critkill", group = "hits", label = "Critical killing blow", hit = true, tokens = "{amount}",
		art = "comic/overkill", anim = "flipbook", title = "", sub = "{amount}", pos = "comic", sound = "none" },

	-- Kills
	{ id = "firstblood", group = "kills", label = "First blood", tokens = "{killer} {victim}",
		art = "none", title = "FIRST BLOOD", sub = "{killer} drew first blood on {victim}", color = "red" },

	-- Multi-kills: your kills less than 4 s apart
	{ id = "double", group = "multi", label = "Double kill (2)", tokens = "{count}",
		art = "escalation/double-kill", title = "", sub = "{count} kills" },
	{ id = "triple", group = "multi", label = "Triple kill (3)", tokens = "{count}",
		art = "none", title = "TRIPLE KILL", sub = "{count} kills" },
	{ id = "multi", group = "multi", label = "Multi kill (4)", tokens = "{count}",
		art = "escalation/multikill", title = "", sub = "{count} kills" },
	{ id = "mega", group = "multi", label = "Mega kill (5)", tokens = "{count}",
		art = "none", title = "MEGA KILL", sub = "{count} kills" },
	{ id = "ultra", group = "multi", label = "Ultra kill (6)", tokens = "{count}",
		art = "none", title = "ULTRA KILL", sub = "{count} kills" },
	{ id = "monster", group = "multi", label = "Monster kill (7)", tokens = "{count}",
		art = "none", title = "MONSTER KILL", sub = "{count} kills" },
	{ id = "ludicrous", group = "multi", label = "Ludicrous kill (8+)", tokens = "{count}",
		art = "none", title = "LUDICROUS KILL", sub = "{count} kills" },

	-- Sprees: your kills since you last died
	{ id = "spree5", group = "spree", label = "Killing spree (5)", tokens = "{count}",
		art = "none", title = "KILLING SPREE", sub = "{count} kills without dying" },
	{ id = "spree10", group = "spree", label = "Rampage (10)", tokens = "{count}",
		art = "escalation/rampage", title = "", sub = "{count} kills without dying" },
	{ id = "spree15", group = "spree", label = "Dominating (15)", tokens = "{count}",
		art = "none", title = "DOMINATING", sub = "{count} kills without dying" },
	{ id = "spree20", group = "spree", label = "Unstoppable (20)", tokens = "{count}",
		art = "none", title = "UNSTOPPABLE", sub = "{count} kills without dying" },
	{ id = "spree25", group = "spree", label = "Godlike (25)", tokens = "{count}",
		art = "none", title = "GODLIKE", sub = "{count} kills without dying" },
	{ id = "spree30", group = "spree", label = "Wicked sick (30, every 5 after)", tokens = "{count}",
		art = "none", title = "WICKED SICK", sub = "{count} kills without dying" },

	-- Fight flow: from entering combat to leaving it
	{ id = "kickoff", group = "fight", label = "Fight start", tokens = "",
		art = "none", title = "FIGHT!", sub = "", sound = "none", off = true },
	{ id = "fulltime", group = "fight", label = "Fight end", tokens = "{count}",
		art = "none", title = "FIGHT OVER", sub = "{count} kills", sound = "none", off = true },
	{ id = "mvp", group = "fight", label = "MVP (group fight end)", tokens = "{name} {count} {total}",
		art = "none", title = "MVP", sub = "{name}  ·  {count} of {total} kills" },
	{ id = "flawless", group = "fight", label = "Flawless (group, nobody died)", tokens = "{count}",
		art = "none", title = "FLAWLESS", sub = "{count} kills, nobody fell", color = "green" },

	-- Deaths
	{ id = "youdied", group = "deaths", label = "You died", tokens = "",
		art = "none", title = "YOU DIED", sub = "", color = "red" },
	{ id = "teammate", group = "deaths", label = "Teammate down", tokens = "{name}",
		art = "none", title = "TEAMMATE DOWN", sub = "{name}", color = "red", sound = "none" },
	{ id = "laststanding", group = "deaths", label = "Last one standing", tokens = "",
		art = "none", title = "LAST ONE STANDING", sub = "It's all on you", color = "red" },
	{ id = "wipe", group = "deaths", label = "Group wipe", tokens = "",
		art = "failure/bonk", title = "", sub = "Everyone is down", color = "red" },
	{ id = "petdown", group = "deaths", label = "Pet down", tokens = "",
		art = "none", title = "PET DOWN", sub = "", color = "red", sound = "none" },

	-- Interrupts
	{ id = "interrupt", group = "interrupts", label = "You interrupted", tokens = "{name}",
		art = "arcade/counter", title = "", sub = "You shut {name} up", color = "blue" },
	{ id = "interrupted", group = "interrupts", label = "You were interrupted", tokens = "{name}",
		art = "failure/nope", title = "", sub = "by {name}", color = "red", sound = "none" },

	-- Encounters and progress
	{ id = "bossdown", group = "encounters", label = "Boss down", tokens = "{name}",
		art = "arcade/perfect", title = "", sub = "{name}", color = "green" },
	{ id = "encwipe", group = "encounters", label = "Encounter wipe", tokens = "{name}",
		art = "failure/bonk", title = "", sub = "{name}", color = "red" },
	{ id = "levelup", group = "encounters", label = "Level up", tokens = "{level}",
		art = "anime/limit-break", title = "", sub = "Level {level}", color = "green" },

	-- Falls
	{ id = "falling", group = "falls", label = "Falling (over 1.2 s)", tokens = "",
		art = "falling/wheee", title = "", sub = "", anim = "shake", color = "white", sound = "none" },
	{ id = "hardlanding", group = "falls", label = "Hard landing (over 2.5 s, survived)", tokens = "{time}",
		art = "falling/faceplant", title = "", sub = "{time} s in the air", sound = "none" },
	{ id = "falldeath", group = "falls", label = "Fell to death", tokens = "{time}",
		art = "falling/gravity-wins", title = "", sub = "Fell for {time} s", color = "red" },

	-- Testing
	{ id = "avoid", group = "testing", label = "Dodge / parry / block / miss", tokens = "{name}",
		art = "failure/whiff", title = "", sub = "{name}", color = "white", sound = "none", off = true },
}

ns.EVENT_GROUPS = {
	{ id = "hits", label = "Hits" },
	{ id = "kills", label = "Kills" },
	{ id = "fight", label = "Fight" },
	{ id = "multi", label = "Multi-kills" },
	{ id = "spree", label = "Sprees" },
	{ id = "deaths", label = "Deaths" },
	{ id = "interrupts", label = "Interrupts" },
	{ id = "encounters", label = "Encounters" },
	{ id = "falls", label = "Falls" },
	{ id = "testing", label = "Testing" },
}

local BY_ID = {}
for _, def in ipairs(ns.EVENTS) do
	BY_ID[def.id] = def
end
ns.EVENT_BY_ID = BY_ID

-- The default config of one event, as a fresh table.
function ns.EventDefaults(id)
	local def = BY_ID[id]
	return {
		enabled = not def.off,
		art = def.art,
		anim = def.anim or "slam",
		title = def.title,
		sub = def.sub,
		details = true,
		color = def.color or "gold",
		size = 1,
		pos = def.pos or "banner",
		sound = def.sound or "raidwarning",
		font = def.font or "auto",
	}
end

-- Fills a profile's event table: every event present, every field present.
function ns.FillEventDefaults(events)
	for _, def in ipairs(ns.EVENTS) do
		local cfg = events[def.id]
		if type(cfg) ~= "table" then
			cfg = {}
			events[def.id] = cfg
		end
		for k, v in pairs(ns.EventDefaults(def.id)) do
			if cfg[k] == nil then
				cfg[k] = v
			end
		end
	end
	return events
end

-- The active profile's config of one event.
function ns.EventConfig(id)
	return ns.db.events[id]
end

-- ── Text templates ────────────────────────────────────────────────────────────────────
-- template -> { format, token1, token2, ... }, built once per distinct template.
local compiled = {}

local function Compile(template)
	local entry = compiled[template]
	if entry then
		return entry
	end
	entry = {}
	-- Escape the user's own % first, then turn every {token} into %s.
	local format = string.gsub(template, "%%", "%%%%")
	format = string.gsub(format, "{(%w+)}", function(token)
		entry[#entry + 1] = token
		return "%s"
	end)
	entry.format = format
	compiled[template] = entry
	return entry
end

local args = {}

-- Draws `template` on `fontString` with values that may be secret. Missing values draw as "".
function ns.ComposeText(fontString, template, values)
	if type(template) ~= "string" or template == "" then
		fontString:SetText("")
		return false
	end
	local entry = Compile(template)
	local n = #entry
	if n == 0 then
		fontString:SetText(template)
		return true
	end
	for i = 1, n do
		local v = values and values[entry[i]]
		if not ns.IsSecret(v) and v == nil then
			v = ""
		end
		args[i] = v
	end
	fontString:SetFormattedText(entry.format, unpack(args, 1, n))
	for i = 1, n do
		args[i] = nil
	end
	return true
end
