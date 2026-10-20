-- KAPOW — UI/ExtrasPage.lua
--
-- The Extras tab: fighting-game extras (combo counter, impact flash), the two overlays drawn
-- from hidden health (low health, FINISH IT!), placing things on screen, calmer motion,
-- controller navigation for this window, personal records and party sync. Everything here
-- starts off; the new banners themselves (duels, countdowns, boss pull, assist, records,
-- achievements, loot, quests, honorable kills) are switched on in Events › Arcade and Moments.

local _, ns = ...

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

local function Checkbox(key, label, tooltip, extra)
	local spec = { type = "checkbox", label = label, tooltip = tooltip, get = Get(key), set = Set(key) }
	for k, v in pairs(extra or {}) do
		spec[k] = v
	end
	return spec
end

local function Percent(v)
	return math.floor(v * 100 + 0.5) .. "%"
end

local function PercentChoices(list)
	local choices = {}
	for i, v in ipairs(list) do
		choices[i] = { v, Percent(v) }
	end
	return choices
end

local function RecordLine()
	local r = ns.moments and ns.moments.Records() or {}
	return string.format(
		"Best: multi-kill %d  ·  spree %d  ·  combo %d",
		r.multi or 0,
		r.spree or 0,
		r.combo or 0
	)
end

local function TallyLine()
	local r = ns.moments and ns.moments.Records() or {}
	return string.format(
		"Kills %d  ·  multi-kills %d  ·  duels won %d, lost %d",
		r.total_kills or 0,
		r.total_multis or 0,
		r.total_duelwins or 0,
		r.total_duellosses or 0
	)
end

local function Specs()
	return {
		{ type = "header", label = "Arcade" },
		{ type = "note", label = "New banners: Events tab, Arcade and Moments groups (all off)." },
		Checkbox(
			"comboCounter",
			"Combo counter",
			"A fighting-game hit counter (\"12 HITS\") beside your character while your hits on one target keep coming less than 2 seconds apart. When the chain ends, the Combo banner (Events › Arcade) shows if it reached the minimum. Counts hits only, so hidden damage numbers do not matter."
		),
		{
			type = "choice",
			label = "Combo banner from",
			tooltip = "Hits in one chain needed for the Combo banner and for a combo record.",
			needs = "comboCounter",
			choices = { { 3, "3 hits" }, { 5, "5 hits" }, { 8, "8 hits" }, { 12, "12 hits" }, { 20, "20 hits" } },
			get = Get("comboMin"),
			set = Set("comboMin"),
		},
		{
			type = "choice",
			label = "Impact flash",
			tooltip = "A quick full-screen flash. The game may hide whether a hit crit or killed: the flash then sits behind the same two hidden gates as the comic frames, so the client still shows it only on the right hits.",
			choices = {
				{ "off", "Off" },
				{ "critkill", "Crit kills" },
				{ "kill", "Every kill" },
				{ "crit", "Every crit" },
			},
			get = Get("flash"),
			set = Set("flash"),
		},
		{
			type = "buttons",
			label = "Try",
			tooltip = "Plays the flash as if a crit kill landed (with a plain test hit).",
			buttons = {
				{
					"Flash",
					function()
						if ns.extras then
							local mode = ns.db.flash
							if mode == "off" then
								ns.db.flash = "critkill"
							end
							ns.extras.Flash(true, true)
							ns.db.flash = mode
						end
					end,
				},
			},
		},

		{ type = "header", label = "Hidden health (experimental)" },
		{ type = "note", label = "The client compares health; KAPOW never reads it." },
		Checkbox(
			"dangerLow",
			"Low health warning",
			"Pulsing red screen edges while your health is at or below the threshold. Health is hidden from addons in combat; the game's own health curve turns it into the edges' opacity inside the client, so this keeps working in combat."
		),
		{
			type = "choice",
			label = "Low health at",
			tooltip = "Your health share that turns the warning on.",
			needs = "dangerLow",
			choices = PercentChoices({ 0.15, 0.2, 0.25, 0.3, 0.35, 0.5 }),
			get = Get("dangerAt"),
			set = Set("dangerAt"),
		},
		Checkbox(
			"finishIt",
			"FINISH IT!",
			"A pulsing FINISH IT! while your hostile target's health is at or below the threshold (execute range). Drawn the same way as the low health warning, from hidden health."
		),
		{
			type = "choice",
			label = "Finish it at",
			tooltip = "Your target's health share that shows FINISH IT!.",
			needs = "finishIt",
			choices = PercentChoices({ 0.1, 0.15, 0.2, 0.25, 0.3, 0.35 }),
			get = Get("finishAt"),
			set = Set("finishAt"),
		},

		{ type = "header", label = "Comfort" },
		Checkbox(
			"reduceMotion",
			"Reduce motion",
			"Calmer shows: no slam, bounce or shake (art rises and fades or stays still), no random offset or tilt, no impact flash, no pulsing, and every show at most three quarters as long."
		),
		Checkbox(
			"gamepadNav",
			"Controller navigation",
			"Drive this window with a controller while it is open: D-pad up and down move between settings, left and right change them, A clicks, B closes, the shoulder buttons switch tabs. Off: the controller does nothing here.",
			{ master = true }
		),

		{ type = "column" },
		{ type = "header", label = "Placing" },
		{ type = "note", label = "Yellow boxes: drag each one, then lock." },
		{
			type = "buttons",
			label = "Move things",
			tooltip = "Shows a yellow box for the hit pops, banners, multi-kill bar, UwU word, combo counter and FINISH IT!. Drag them where you want; /kapow unlock and /kapow lock do the same.",
			master = true,
			buttons = {
				{
					"Unlock",
					function()
						ns.extras.SetUnlocked(true)
					end,
				},
				{
					"Lock",
					function()
						ns.extras.SetUnlocked(false)
					end,
				},
			},
		},
		{
			type = "buttons",
			label = "Reset places",
			tooltip = "Puts every movable thing back where it started.",
			master = true,
			buttons = {
				{
					"Reset",
					function()
						ns.extras.ResetPlaces()
					end,
				},
			},
		},

		{ type = "header", label = "Records" },
		{ type = "note", textFunc = RecordLine },
		{ type = "note", textFunc = TallyLine },
		{
			type = "buttons",
			label = "Records",
			tooltip = "This character's bests and tallies. The New personal record banner (Events › Moments) shows when a best of at least a double kill, a 5-kill spree or a 5-hit combo is beaten, once per run.",
			master = true,
			buttons = {
				{
					"Print",
					function()
						ns.moments.PrintRecords()
					end,
				},
				{
					"Reset",
					function()
						ns.moments.ResetRecords()
						ns.ui.Refresh()
					end,
				},
			},
		},

		{ type = "header", label = "Party sync" },
		Checkbox(
			"partySync",
			"Share big moments",
			"Tells groupmates who also run KAPOW (with this on) about your multi-kills, sprees, first blood, combos, records and duel wins; theirs show in your kill feed (\"Bob: Mega kill x5\"). Sends only the moment and a count through hidden addon messages, at most two a second. The game can block addon messages during boss fights."
		),
	}
end

ns.ui.pages.extras = {
	label = "Extras",
	order = 5,
	Build = function(parent)
		local rows, height = ns.ui.BuildColumns(parent, Specs())
		return {
			height = height,
			rows = rows,
			Refresh = function()
				local enabled = ns.db.enabled
				for _, row in ipairs(rows) do
					row:RefreshValue()
					local spec = row.spec
					if not spec.master then
						local on = enabled and (not spec.needs or ns.db[spec.needs])
						row:SetRowEnabled(on and true or false)
					end
				end
			end,
		}
	end,
}
