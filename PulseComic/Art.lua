-- PulseComic — Art.lua
--
-- The art catalog. Every entry is a message with its word baked into the artwork and three
-- animation frames (Art/<theme>/<message>_1..3.tga: onset, peak, aftershock; 256x256 RGBA).
-- The originals in Media/ are one frame each and play as all three.
--
-- An art choice stored in a profile is one of:
--   "<theme>/<message>"   one sequence, e.g. "comic/pow"
--   "random:<category>"   a random sequence from that category on every show
--   "random:all"          a random sequence from the whole catalog
--   "none"                text only
--
-- WoW addons cannot list a folder, so the catalog is spelled out in ArtCatalog.lua, which
-- scripts/make-art-catalog.py generates from Art/_metadata/manifest.json.

local ADDON_NAME, ns = ...

local ART = {}
ns.art = ART

local ROOT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"

-- Suggested frame timing from the manifest, in seconds.
ART.FRAME_TIMES = { 0.08, 0.12, 0.18 }

-- Display order of categories, each with its sequences (key, word): the generated catalog
-- (ArtCatalog.lua, from the manifest) plus the one-frame originals in Media/.
ART.CATEGORIES = {}
for _, category in ipairs(ns.ART_CATALOG or {}) do
	ART.CATEGORIES[#ART.CATEGORIES + 1] = category
end
ART.CATEGORIES[#ART.CATEGORIES + 1] = {
	id = "original",
	label = "Original",
	font = "bangers",
	items = {
		{ "original/pow", "POW! (original)" },
		{ "original/ko", "K.O.! (original)" },
		{ "original/overkill", "OVERKILL! (original)" },
	},
}

-- key -> { word, category, frames = { path1, path2, path3 } }
local BY_KEY = {}
-- category id -> font key (Display.FONTS), for the "Match the art" font
local CATEGORY_FONT = {}
-- category id -> list of keys, and every key once for random:all
local KEYS_BY_CATEGORY, ALL_KEYS = {}, {}

for _, category in ipairs(ART.CATEGORIES) do
	local keys = {}
	KEYS_BY_CATEGORY[category.id] = keys
	CATEGORY_FONT[category.id] = category.font
	for _, item in ipairs(category.items) do
		local key, word = item[1], item[2]
		keys[#keys + 1] = key
		if not BY_KEY[key] then
			local frames
			local theme, message = string.match(key, "^([^/]+)/(.+)$")
			if theme == "original" then
				local path = ROOT .. "Media\\" .. message
				frames = { path, path, path }
			else
				local base = ROOT .. "Art\\" .. theme .. "\\" .. message .. "_"
				frames = { base .. "1", base .. "2", base .. "3" }
			end
			BY_KEY[key] = { word = word, category = category.id, frames = frames }
			ALL_KEYS[#ALL_KEYS + 1] = key
		end
	end
end

-- Category ids renamed since profiles were first saved. A stored choice with an old id
-- still resolves, and Profiles.lua rewrites it on load.
local LEGACY = { counterstrike = "tactical" }

function ART.Current(choice)
	if type(choice) ~= "string" then
		return choice
	end
	local category, rest = string.match(choice, "^([%w%-]+)/(.+)$")
	if category and LEGACY[category] then
		return LEGACY[category] .. "/" .. rest
	end
	category = string.match(choice, "^random:(.+)$")
	if category and LEGACY[category] then
		return "random:" .. LEGACY[category]
	end
	return choice
end

function ART.Get(key)
	return BY_KEY[ART.Current(key)]
end

-- The font key that belongs with a category's art, or nil.
function ART.FontFor(categoryId)
	return CATEGORY_FONT[categoryId]
end

function ART.CategoryLabel(id)
	if id == "all" then
		return "Everything"
	end
	for _, category in ipairs(ART.CATEGORIES) do
		if category.id == id then
			return category.label
		end
	end
	return id
end

-- Resolves a stored choice to one entry for this show (nil for "none" or unknown).
function ART.Resolve(choice)
	if type(choice) ~= "string" or choice == "none" then
		return nil
	end
	choice = ART.Current(choice)
	local category = string.match(choice, "^random:(.+)$")
	if category then
		local keys = (category == "all") and ALL_KEYS or KEYS_BY_CATEGORY[category]
		if not keys or #keys == 0 then
			return nil
		end
		return BY_KEY[keys[math.random(1, #keys)]]
	end
	return BY_KEY[choice]
end

-- What a choice reads as in the window.
function ART.Describe(choice)
	if choice == "none" or choice == nil then
		return "None (text only)"
	end
	choice = ART.Current(choice)
	local category = string.match(choice, "^random:(.+)$")
	if category then
		return "Random: " .. ART.CategoryLabel(category)
	end
	local entry = BY_KEY[choice]
	return entry and entry.word or choice
end
