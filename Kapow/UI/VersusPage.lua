-- KAPOW — UI/VersusPage.lua
--
-- The VS intro tab (Versus.lua): on/off, when it plays, how long, how big and how see-through,
-- and a Test button that plays it over this window with your target (or yourself twice).

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

local function Slider(key, label, tooltip, min, max, step, format)
	return {
		type = "slider",
		label = label,
		tooltip = tooltip,
		needs = "versus",
		min = min,
		max = max,
		step = step,
		format = format,
		get = Get(key),
		set = Set(key),
	}
end

local function Percent(v)
	return math.floor(v * 100 + 0.5) .. "%"
end

local function Seconds(v)
	return string.format("%.2f s", v)
end

local function Pixels(v)
	return math.floor(v + 0.5) .. " px"
end

local function Specs()
	return {
		{ type = "header", label = "VS intro" },
		Checkbox(
			"versus",
			"Show the VS intro",
			"You on the left and your opponent on the right as large, see-through 3D models, with the VS art slamming in between, before a fight you chose below. Gone again in a few seconds.",
			{ master = true }
		),
		{ type = "header", label = "When" },
		Checkbox("versusDuel", "Duel starts", "When a duel's countdown reaches zero.", { needs = "versus" }),
		Checkbox("versusBoss", "Boss pull", "When a boss encounter starts. The boss is the opponent when the game lets its model be drawn, else your target.", { needs = "versus" }),
		Checkbox("versusCountdown", "Countdown FIGHT!", "At the end of an arena, battleground or pull-timer countdown.", { needs = "versus" }),
		Checkbox("versusCombat", "Every fight", "Whenever you enter combat with an attackable target. Frequent; at most once every 10 seconds.", { needs = "versus" }),
		{
			type = "choice",
			label = "No opponent model",
			tooltip = "No target, or its model cannot be drawn: show you and the VS, the VS alone, or skip the intro.",
			needs = "versus",
			choices = { { "you", "You and VS" }, { "vs", "VS alone" }, { "skip", "Skip it" } },
			get = Get("versusFallback"),
			set = Set("versusFallback"),
		},
		Checkbox(
			"versusStrictIdentity",
			"Cautious opponent check",
			"The first version: no opponent model while the game keeps its identity hidden (often in dungeons, raids and PvP matches). Off: the model is always tried, as unit frame addons do with their 3D portraits, and the choice above applies only if it fails.",
			{ needs = "versus" }
		),
		{
			type = "buttons",
			label = "Try it",
			tooltip = "Plays the intro now, over this window. Without a target you face yourself.",
			master = true,
			buttons = {
				{
					"Test",
					function()
						ns.versus.Test()
					end,
				},
			},
		},
		{ type = "column" },
		{ type = "header", label = "Look" },
		Slider("versusDuration", "Duration", "From the slide-in to the end of the fade, in seconds.", 2, 4, 0.25, Seconds),
		Slider("versusSize", "Size", "The whole intro: both models and the VS.", 0.5, 1.5, 0.05, Percent),
		Slider("versusVsSize", "VS size", "The VS art, on top of Size.", 0.5, 1.5, 0.05, Percent),
		Slider("versusPortraitAlpha", "Model opacity", "How solid the two models are. Low keeps the fight visible through them.", 0.1, 1, 0.05, Percent),
		Slider("versusVsAlpha", "VS opacity", "How solid the VS art is.", 0.1, 1, 0.05, Percent),
		Slider("versusY", "Height", "Up or down from the middle of the screen.", -300, 300, 10, Pixels),
		Checkbox(
			"versusBehind",
			"Behind the interface",
			"Draw it under your action bars, unit frames and KAPOW's banners (over the game world). Off: on top of everything.",
			{ needs = "versus" }
		),
		{
			type = "buttons",
			label = "Defaults",
			tooltip = "Puts the look back: 3 s, 100% size, models 35%, VS 70%, 40 px up, behind the interface.",
			needs = "versus",
			buttons = {
				{
					"Reset look",
					function()
						for _, key in ipairs({ "versusDuration", "versusSize", "versusVsSize", "versusPortraitAlpha", "versusVsAlpha", "versusY", "versusBehind" }) do
							ns.Set(key, ns.DEFAULTS[key])
						end
					end,
				},
			},
		},
	}
end

ns.ui.pages.versus = {
	label = "VS intro",
	order = 5.5, -- after Extras
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
