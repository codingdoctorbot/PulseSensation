-- PulseComic — Profiles.lua
--
-- Saved settings live in profiles, shared across the account; each character picks one or
-- follows the account default.
--
--   PulseComicDB (account)        { version = 2, profiles = { [name] = profile },
--                                   defaultProfile = name, minimap = { hide, pos } }
--   PulseComicCharDB (character)  { profile = name }   -- nil: follow the account default
--
-- A profile is the flat settings (ns.DEFAULTS) plus profile.events (Events.lua).
-- ns.db is always the active profile.
--
-- EXPORT / IMPORT. A profile (or all of them) becomes one line of text, "PCOMIC1:" plus a
-- small typed encoding with strings in hex, safe to paste into chat or a forum. Import
-- parses it with the reader below, never with loadstring, and keeps only known keys of the
-- expected types, so a pasted string can set settings and nothing else.

local _, ns = ...

local P = {}
ns.profiles = P

local PREFIX = "PCOMIC1:"
local MAX_IMPORT = 200000 -- characters
local MAX_DEPTH = 6
local MAX_STRING = 300 -- longest text a setting may hold

local account, char

-- ── Defaults and migration ────────────────────────────────────────────────────────────

local function CopyValue(v)
	if type(v) ~= "table" then
		return v
	end
	local copy = {}
	for k, inner in pairs(v) do
		copy[k] = CopyValue(inner)
	end
	return copy
end

-- Settings of builds before events existed, mapped onto the events they became.
local OLD_TOGGLES = {
	annFirstBlood = { "firstblood" },
	annMultiKill = { "double", "triple", "multi", "mega", "ultra", "monster", "ludicrous" },
	annSpree = { "spree5", "spree10", "spree15", "spree20", "spree25", "spree30" },
	annMVP = { "mvp" },
	annDeaths = { "youdied", "teammate", "laststanding", "wipe" },
	annPetDeath = { "petdown" },
	annInterrupts = { "interrupt", "interrupted" },
	annEncounter = { "bossdown", "encwipe" },
	annLevelUp = { "levelup" },
	annAvoid = { "avoid" },
	critPop = { "crit" },
}

local function Fill(profile)
	local fresh = type(profile.events) ~= "table"
	for k, v in pairs(ns.DEFAULTS) do
		if profile[k] == nil then
			profile[k] = CopyValue(v)
		end
	end
	profile.events = fresh and {} or profile.events
	ns.FillEventDefaults(profile.events)
	for _, cfg in pairs(profile.events) do
		cfg.art = ns.art.Current(cfg.art) -- art ids renamed since this profile was saved
	end
	if fresh then
		for key, ids in pairs(OLD_TOGGLES) do
			if profile[key] == false then
				for _, id in ipairs(ids) do
					profile.events[id].enabled = false
				end
			end
		end
		if profile.numbers == false then
			for _, id in ipairs({ "crit", "kill", "critkill" }) do
				profile.events[id].details = false
			end
		end
	end
	for key in pairs(OLD_TOGGLES) do
		profile[key] = nil
	end
	profile.numbers = nil
	profile.minimap = nil -- account-wide now
	return profile
end
P.Fill = Fill

-- ── Loading ───────────────────────────────────────────────────────────────────────────

-- Called at ADDON_LOADED. Returns the active profile.
function P:Load()
	local saved = _G.PulseComicDB
	if type(saved) ~= "table" then
		saved = {}
	end
	if type(saved.profiles) ~= "table" then
		-- Fresh install, or the flat settings of an earlier build: those become "Default".
		local migrated = {}
		for k, v in pairs(saved) do
			if k ~= "minimap" then
				migrated[k] = v
			end
		end
		saved = { version = 2, profiles = { Default = migrated }, defaultProfile = "Default", minimap = saved.minimap }
	end
	account = saved
	_G.PulseComicDB = account
	if type(account.minimap) ~= "table" then
		account.minimap = { hide = false, pos = 225 }
	end
	if type(account.profiles.Default) ~= "table" then
		account.profiles.Default = {}
	end
	for _, profile in pairs(account.profiles) do
		Fill(profile)
	end
	if type(account.defaultProfile) ~= "string" or not account.profiles[account.defaultProfile] then
		account.defaultProfile = "Default"
	end

	char = _G.PulseComicCharDB
	if type(char) ~= "table" then
		char = {}
		_G.PulseComicCharDB = char
	end
	ns.account, ns.char = account, char
	return self:Active()
end

-- ── Queries ───────────────────────────────────────────────────────────────────────────

function P:ActiveName()
	local name = char.profile
	if name and account.profiles[name] then
		return name
	end
	return account.defaultProfile
end

function P:Active()
	return account.profiles[self:ActiveName()]
end

-- Whether this character has its own choice (false: it follows the account default).
function P:HasCharacterChoice()
	return char.profile ~= nil and account.profiles[char.profile] ~= nil
end

function P:DefaultName()
	return account.defaultProfile
end

-- "Raid (2)" before "Raid (10)": numbers compare by value, letters without case.
local function NaturalKey(name)
	return (string.gsub(string.lower(name), "%d+", function(digits)
		return string.format("%08d", tonumber(digits))
	end))
end

function P:Names()
	local names = {}
	for name in pairs(account.profiles) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		if a == "Default" or b == "Default" then
			return a == "Default"
		end
		return NaturalKey(a) < NaturalKey(b)
	end)
	return names
end

function P:Exists(name)
	return account.profiles[name] ~= nil
end

-- ── Changes ───────────────────────────────────────────────────────────────────────────

local function Apply()
	ns.ApplyProfile(P:Active())
end

local function ValidName(name)
	if type(name) ~= "string" then
		return nil
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" or #name > 40 then
		return nil
	end
	return name
end

local function FreeName(name)
	if not account.profiles[name] then
		return name
	end
	local base = string.gsub(name, " %(%d+%)$", "")
	for i = 2, 99 do
		local candidate = base .. " (" .. i .. ")"
		if not account.profiles[candidate] then
			return candidate
		end
	end
	return nil
end

-- This character uses `name`; nil follows the account default.
function P:Use(name)
	if name ~= nil and not account.profiles[name] then
		return false
	end
	char.profile = name
	Apply()
	return true
end

function P:SetDefault(name)
	if not account.profiles[name] then
		return false
	end
	account.defaultProfile = name
	Apply()
	return true
end

-- A new profile from defaults, or a copy of `fromName`. Returns its name.
function P:Create(name, fromName)
	name = ValidName(name)
	if not name then
		return nil, "give the profile a name (up to 40 characters)"
	end
	if account.profiles[name] then
		return nil, "a profile with that name exists"
	end
	local profile = fromName and CopyValue(account.profiles[fromName]) or {}
	account.profiles[name] = Fill(profile)
	return name
end

function P:Rename(old, new)
	new = ValidName(new)
	if not account.profiles[old] or old == "Default" then
		return nil, "the Default profile keeps its name"
	end
	if not new then
		return nil, "give the profile a name (up to 40 characters)"
	end
	if account.profiles[new] then
		return nil, "a profile with that name exists"
	end
	account.profiles[new], account.profiles[old] = account.profiles[old], nil
	if account.defaultProfile == old then
		account.defaultProfile = new
	end
	if char.profile == old then
		char.profile = new
	end
	Apply()
	return new
end

-- Other characters that used a deleted profile fall back to the account default when they
-- next log in.
function P:Delete(name)
	if name == "Default" or not account.profiles[name] then
		return false, "the Default profile cannot be deleted"
	end
	account.profiles[name] = nil
	if account.defaultProfile == name then
		account.defaultProfile = "Default"
	end
	if char.profile == name then
		char.profile = nil
	end
	Apply()
	return true
end

function P:Reset(name)
	if not account.profiles[name] then
		return false
	end
	account.profiles[name] = Fill({})
	Apply()
	return true
end

-- Rewrites the event looks of profile `name` with a theme (Themes.lua).
function P:ApplyTheme(name, themeId)
	local profile = account.profiles[name]
	if not profile or not ns.themes.Apply(profile, themeId) then
		return false
	end
	Apply()
	return true
end

-- A new profile from defaults dressed in a theme. Returns its name.
function P:CreateFromTheme(name, themeId)
	local theme = ns.themes.Get(themeId)
	if not theme then
		return nil, "no such theme"
	end
	local created, err = self:Create(ValidName(name) and name or FreeName(theme.label))
	if not created then
		return nil, err
	end
	ns.themes.Apply(account.profiles[created], themeId)
	return created
end

-- ── Encoding ──────────────────────────────────────────────────────────────────────────

local function Hex(s)
	return (string.gsub(s, ".", function(c)
		return string.format("%02x", string.byte(c))
	end))
end

local function Encode(v, out)
	local kind = type(v)
	if kind == "number" then
		out[#out + 1] = "N" .. tostring(v) .. ";"
	elseif kind == "boolean" then
		out[#out + 1] = v and "T" or "F"
	elseif kind == "string" then
		out[#out + 1] = "S" .. Hex(v) .. ";"
	elseif kind == "table" then
		out[#out + 1] = "{"
		local keys = {}
		for k in pairs(v) do
			if type(k) == "string" or type(k) == "number" then
				keys[#keys + 1] = k
			end
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in ipairs(keys) do
			Encode(k, out)
			Encode(v[k], out)
		end
		out[#out + 1] = "}"
	end
end

local function Serialize(v)
	local out = {}
	Encode(v, out)
	return PREFIX .. table.concat(out)
end

-- Reader: returns value, next position; or nil, error.
local Decode
function Decode(s, i, depth)
	local tag = string.sub(s, i, i)
	if tag == "T" then
		return true, i + 1
	elseif tag == "F" then
		return false, i + 1
	elseif tag == "N" then
		local stop = string.find(s, ";", i + 1, true)
		local n = stop and tonumber(string.sub(s, i + 1, stop - 1))
		if not n then
			return nil, "bad number"
		end
		return n, stop + 1
	elseif tag == "S" then
		local stop = string.find(s, ";", i + 1, true)
		local hex = stop and string.sub(s, i + 1, stop - 1)
		if not hex or #hex % 2 == 1 or string.find(hex, "[^0-9a-fA-F]") then
			return nil, "bad text"
		end
		local text = string.gsub(hex, "..", function(pair)
			return string.char(tonumber(pair, 16))
		end)
		return text, stop + 1
	elseif tag == "{" then
		if depth >= MAX_DEPTH then
			return nil, "nested too deep"
		end
		local t, pos = {}, i + 1
		while string.sub(s, pos, pos) ~= "}" do
			if pos > #s then
				return nil, "cut short"
			end
			local k, v
			k, pos = Decode(s, pos, depth + 1)
			if k == nil then
				return nil, pos
			end
			if type(k) ~= "string" and type(k) ~= "number" then
				return nil, "bad key"
			end
			v, pos = Decode(s, pos, depth + 1)
			if v == nil then
				return nil, pos
			end
			t[k] = v
		end
		return t, pos + 1
	end
	return nil, "unexpected data"
end

local function Deserialize(text)
	if type(text) ~= "string" then
		return nil, "nothing to import"
	end
	text = string.gsub(text, "%s+", "")
	if #text > MAX_IMPORT then
		return nil, "too long"
	end
	if string.sub(text, 1, #PREFIX) ~= PREFIX then
		return nil, "not a PulseComic export (it starts with " .. PREFIX .. ")"
	end
	local decoded, pos = Decode(text, #PREFIX + 1, 0)
	if decoded == nil then
		return nil, pos
	end
	if pos <= #text then
		return nil, "extra data after the end"
	end
	return decoded
end

-- ── Cleaning imported data ────────────────────────────────────────────────────────────

local ENUMS = {
	anim = ns.display.ANIMS,
	color = ns.display.COLORS,
	pos = ns.display.POSITIONS,
	sound = ns.display.SOUNDS,
	font = ns.display.FONTS,
}

local function CleanValue(incoming, default)
	if type(incoming) ~= type(default) then
		return CopyValue(default)
	end
	if type(incoming) == "string" and #incoming > MAX_STRING then
		return string.sub(incoming, 1, MAX_STRING)
	end
	if type(incoming) == "table" then
		local clean = {}
		for k, v in pairs(default) do
			clean[k] = CleanValue(incoming[k], v)
		end
		return clean
	end
	return incoming
end

-- A profile from untrusted data: known keys of the right type only, the rest default.
local function CleanProfile(data)
	local profile = Fill({})
	if type(data) ~= "table" then
		return profile
	end
	for k, default in pairs(ns.DEFAULTS) do
		if data[k] ~= nil then
			profile[k] = CleanValue(data[k], default)
		end
	end
	if type(data.events) == "table" then
		for id, cfg in pairs(profile.events) do
			local incoming = data.events[id]
			if type(incoming) == "table" then
				for field, default in pairs(cfg) do
					local clean = CleanValue(incoming[field], default)
					local enum = ENUMS[field]
					if enum and not enum[clean] then
						clean = default
					end
					if field == "size" then
						clean = math.min(3, math.max(0.3, clean))
					end
					cfg[field] = clean
				end
			end
		end
	end
	return profile
end

-- ── Export / import ───────────────────────────────────────────────────────────────────

function P:Export(name)
	local profile = account.profiles[name]
	if not profile then
		return nil
	end
	return Serialize({ kind = "profile", name = name, profile = profile })
end

function P:ExportAll()
	return Serialize({ kind = "all", profiles = account.profiles, defaultProfile = account.defaultProfile })
end

-- Imports a string from Export or ExportAll. A single profile is added as `name` (or its
-- own name), never over an existing one. Returns the list of profile names added.
function P:Import(text, name)
	local data, err = Deserialize(text)
	if not data then
		return nil, err
	end
	local incoming = {}
	if data.kind == "profile" and type(data.profile) == "table" then
		incoming[#incoming + 1] = { ValidName(name) or ValidName(data.name) or "Imported", data.profile }
	elseif data.kind == "all" and type(data.profiles) == "table" then
		for profileName, profile in pairs(data.profiles) do
			if type(profile) == "table" then
				incoming[#incoming + 1] = { ValidName(profileName) or "Imported", profile }
			end
		end
		table.sort(incoming, function(a, b)
			return a[1] < b[1]
		end)
	else
		return nil, "not a PulseComic profile"
	end
	local added = {}
	for _, item in ipairs(incoming) do
		local free = FreeName(item[1])
		if free then
			account.profiles[free] = CleanProfile(item[2])
			added[#added + 1] = free
		end
	end
	if #added == 0 then
		return nil, "no free profile names left"
	end
	return added
end
