-- Targeted test for Modules/Crafting.lua.
--
-- Drives real CRAFT_START / CRAFT_COMPLETE through Core/CastActivity.lua and inspects the
-- module through _DebugCraft, counting engine strikes rather than trusting the maths.

local ROOT = arg[1] or "."

-- ── Stubs ─────────────────────────────────────────────────────────────────────

local now = 1000
function GetTime()
	return now
end

local FrameMT = {
	__index = function(_, key)
		if type(key) == "string" and key:match("^%u") then
			return function() end
		end
		return nil
	end,
}

local scripts = {}
local function newFrame()
	local f = setmetatable({}, FrameMT)
	f.SetScript = function(_, name, fn)
		scripts[name] = fn
	end
	f.RegisterEvent = function() end
	f.UnregisterAllEvents = function() end
	f.RegisterUnitEvent = function() end
	return f
end
function CreateFrame()
	return newFrame()
end
function hooksecurefunc() end
function issecretvalue()
	return false
end
function print(...)
	io.write("[print] ", tostring((...)), "\n")
end
function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end
function CopyTable(src)
	local o = {}
	for k, v in pairs(src) do
		o[k] = type(v) == "table" and CopyTable(v) or v
	end
	return o
end
function strsplit(sep, str)
	local o = {}
	for p in tostring(str):gmatch("[^" .. sep .. "]+") do
		o[#o + 1] = p
	end
	return unpack(o)
end
function strtrim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
function UnitName()
	return "Tester"
end
function GetRealmName()
	return "Realm"
end
unpack = unpack or table.unpack

Enum = {
	Profession = {
		FirstAid = 0,
		Blacksmithing = 1,
		Leatherworking = 2,
		Alchemy = 3,
		Herbalism = 4,
		Cooking = 5,
		Mining = 6,
		Tailoring = 7,
		Engineering = 8,
		Enchanting = 9,
		Fishing = 10,
		Skinning = 11,
		Jewelcrafting = 12,
		Inscription = 13,
	},
}

recipeProfession = Enum.Profession.Blacksmithing
C_TradeSkillUI = {
	GetProfessionInfoByRecipeID = function()
		if recipeProfession == false then
			return nil
		end
		return { profession = recipeProfession }
	end,
}

castStartMs, castEndMs = nil, nil
channelStartMs, channelEndMs = nil, nil
function UnitCastingInfo()
	return nil, nil, nil, castStartMs, castEndMs
end
function UnitChannelInfo()
	return nil, nil, nil, channelStartMs, channelEndMs
end
function GetSpellInfo()
	return nil
end
function GetSpellTexture()
	return nil
end

-- ── Load ──────────────────────────────────────────────────────────────────────

local Pulse = { modules = {}, moduleOrder = {}, debug = false }
function Pulse:RegisterModule(name, module)
	self.modules[name] = module
	self.moduleOrder[#self.moduleOrder + 1] = name
end
function Pulse:BindFrame(_, sync)
	Pulse.__sync = sync
end
function Pulse:HoldRolesIfEnabled(_, roles)
	Pulse.__bed = roles and roles.low
end

local cues, settings = { craftTexture = true }, {}
Pulse.Database = {
	Get = function(_, key)
		return key == "masterEnabled"
	end,
	GetCue = function(_, id)
		return cues[id]
	end,
	GetTriggerSetting = function(_, _, key, default)
		local v = settings[key]
		if v == nil then
			return default
		end
		return v
	end,
}

local strikes = 0
Pulse.Engine = {
	PlayMode = function()
		strikes = strikes + 1
	end,
}

for _, file in ipairs({ "Core/CastActivity.lua", "Modules/Crafting.lua" }) do
	assert(loadfile(ROOT .. "/" .. file))("Pulse", Pulse)
end

local M = Pulse.modules.Crafting
M:OnEnable()
Pulse.__sync()

-- ── Helpers ───────────────────────────────────────────────────────────────────

local failures = 0
local function check(label, got, want)
	local ok = (got == want)
	if not ok then
		failures = failures + 1
	end
	io.write(("%-46s %-16s %s\n"):format(label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
end

local function startCraft(recipeID, durationSeconds)
	strikes = 0
	now = now + 100
	castStartMs = now * 1000
	castEndMs = (now + durationSeconds) * 1000
	Pulse.CastActivity:_OnCraftBegin(recipeID or 1234)
end

-- Runs the craft to completion in small steps, as the OnUpdate loop would.
local function runCraftTo(durationSeconds, fraction, steps)
	for i = 1, steps do
		now = castStartMs / 1000 + (durationSeconds * fraction * i / steps)
		if scripts.OnUpdate then
			scripts.OnUpdate()
		end
	end
end

local function runCraft(durationSeconds, steps)
	runCraftTo(durationSeconds, 1.0, steps)
end

-- ── Cases ─────────────────────────────────────────────────────────────────────

recipeProfession = Enum.Profession.Blacksmithing
startCraft(1234, 3.0)
check("blacksmithing resolves", M:_DebugCraft().profession, "Blacksmithing")
check("  and is active", M:_DebugCraft().active, true)
check("  Pulse.IsCrafting agrees", Pulse.IsCrafting(), true)
check("  strike shape", M:_DebugCraft().mode, "THUD")

runCraft(3.0, 60)
-- cadence 1.1 over 3s -> floor(3.3+0.5) = 3 strikes.
check("3s blacksmith craft plans 3 strikes", M:_DebugCraft().strikesTotal, 3)
check("  and played them", strikes, 3)
check("  bed emitted on the low role", Pulse.__bed ~= nil, true)

Pulse.CastActivity:_OnSucceeded("player", nil, 1234)
check("completing ends the craft", M:_DebugCraft().active, false)
check("  and castTexture is free again", Pulse.IsCrafting(), false)

-- The final blow must land on completion even when the ticks stopped short of the last
-- beat, which is the normal case: the cast ends the instant progress reaches 1 and the
-- tick that would have played it never runs.
recipeProfession = Enum.Profession.Blacksmithing
startCraft(1234, 3.0)
runCraftTo(3.0, 0.5, 10) -- half way: beat 1 played, beats 2 and 3 not
local before = strikes
check("stopped short, mid-craft", before, 1)
Pulse.CastActivity:_OnSucceeded("player", nil, 1234)
check("last blow lands on completion", strikes, before + 1)
check("  exactly one, not the backlog", strikes, 2)

-- A craft that is abandoned does not get the courtesy strike.
startCraft(1234, 3.0)
runCraftTo(3.0, 0.5, 10)
before = strikes
Pulse.CastActivity:_OnStop("player", nil, 1234)
check("abandoned craft plays no final blow", strikes, before)
check("  and is inactive", M:_DebugCraft().active, false)

-- Mining is a different rhythm.
recipeProfession = Enum.Profession.Mining
startCraft(555, 3.0)
check("mining resolves", M:_DebugCraft().profession, "Mining")
runCraft(3.0, 60)
check("  faster cadence, more strikes", M:_DebugCraft().strikesTotal, 5)

-- A profession with no rhythm gets the bed and nothing else.
recipeProfession = Enum.Profession.Enchanting
startCraft(777, 3.0)
check("enchanting resolves", M:_DebugCraft().profession, "Enchanting")
runCraft(3.0, 60)
check("  and strikes nothing", strikes, 0)
Pulse.CastActivity:_OnSucceeded("player", nil, 777)

-- Unresolvable recipe falls back rather than going quiet.
recipeProfession = false
startCraft(999, 3.0)
check("unresolved falls back", M:_DebugCraft().profession, "Other crafting")
check("  and still runs", M:_DebugCraft().active, true)
Pulse.CastActivity:_OnSucceeded("player", nil, 999)

-- A profession switched off produces nothing at all.
settings["p1_on"] = 0
recipeProfession = Enum.Profession.Blacksmithing
startCraft(1234, 3.0)
check("disabled profession stays inactive", M:_DebugCraft().active, false)
check("  and castTexture is not suppressed", Pulse.IsCrafting(), false)
runCraft(3.0, 20)
check("  and plays nothing", strikes, 0)
settings["p1_on"] = nil

-- Per-profession strength of zero silences the strikes but keeps the craft live.
settings["p1_gain"] = 0
startCraft(1234, 3.0)
runCraft(3.0, 60)
check("zero strength plays no strikes", strikes, 0)
check("  but the craft is still active", M:_DebugCraft().active, true)
Pulse.CastActivity:_OnSucceeded("player", nil, 1234)
check("  and completed cleanly", M:_DebugCraft().active, false)
settings["p1_gain"] = nil

-- ── Gathering & Fishing ────────────────────────────────────────────────────────

local function startGather(spellID, durationSeconds)
	strikes = 0
	now = now + 100
	castStartMs = now * 1000
	castEndMs = (now + durationSeconds) * 1000
	Pulse.CastActivity:_OnStart("player", "guid-gather", spellID)
end

local function startChannel(spellID, durationSeconds)
	strikes = 0
	now = now + 100
	castStartMs = nil
	castEndMs = nil
	channelStartMs = now * 1000
	channelEndMs = (now + durationSeconds) * 1000
	Pulse.CastActivity:_OnChannelStart("player", "guid-channel", spellID)
end

-- Mining gathering (spellID 2575)
startGather(2575, 3.0)
check("mining gathering resolves", M:_DebugCraft().profession, "Mining")
check("  and is active", M:_DebugCraft().active, true)
check("  Pulse.IsCrafting agrees", Pulse.IsCrafting(), true)
check("  strike shape is TAP", M:_DebugCraft().mode, "TAP")
runCraft(3.0, 60)
check("  strikes planned for 3s mining", M:_DebugCraft().strikesTotal, 5)
check("  and strikes played", strikes, 5)
Pulse.CastActivity:_OnSucceeded("player", "guid-gather", 2575)
check("completing gathering ends craft", M:_DebugCraft().active, false)
check("  and castTexture is freed", Pulse.IsCrafting(), false)

-- Abandoned gathering (moving / canceling)
startGather(2575, 3.0)
runCraftTo(3.0, 0.5, 10)
before = strikes
check("gathering stopped short", before >= 1, true)
Pulse.CastActivity:_OnStop("player", "guid-gather", 2575)
check("abandoned gathering plays no courtesy strike", strikes, before)
check("  and is inactive", M:_DebugCraft().active, false)
check("  and castTexture is freed", Pulse.IsCrafting(), false)

-- Fishing channel (spellID 7620)
Pulse.__bed = nil
startChannel(7620, 20.0)
check("fishing channel resolves", M:_DebugCraft().profession, "Fishing")
check("  and is active", M:_DebugCraft().active, true)
check("  Pulse.IsCrafting agrees", Pulse.IsCrafting(), true)
if scripts.OnUpdate then
	scripts.OnUpdate()
end
check("  fishing bed emitted on low role", Pulse.__bed ~= nil, true)
check("  and fishing has no strikes", strikes, 0)
Pulse.CastActivity:_OnChannelStop("player", "guid-channel", 7620)
check("channel stop ends fishing", M:_DebugCraft().active, false)
check("  and castTexture is freed", Pulse.IsCrafting(), false)

-- Disabled gathering profession falls back
settings["p6_on"] = 0
startGather(2575, 3.0)
check("disabled mining stays inactive in crafting", M:_DebugCraft().active, false)
check("  leaving castTexture unsuppressed for fallback", Pulse.IsCrafting(), false)
settings["p6_on"] = nil
-- Disparate spell IDs: TRADE_SKILL_CRAFT_BEGIN has recipeSpellID (e.g. 2662 "Rough Sharpening Stone")
-- while UNIT_SPELLCAST_START and UNIT_SPELLCAST_SUCCEEDED have profession spellID (e.g. 2018 "Blacksmithing")
recipeProfession = Enum.Profession.Blacksmithing
startCraft(2662, 3.0)
Pulse.CastActivity:_OnStart("player", "guid-smith-1", 2018)
check("disparate spell ID craft starts active", M:_DebugCraft().active, true)
check("  and Pulse.IsCrafting agrees", Pulse.IsCrafting(), true)
runCraftTo(3.0, 0.5, 10)
before = strikes
Pulse.CastActivity:_OnSucceeded("player", "guid-smith-1", 2018)
check("disparate spell ID completes craft cleanly", M:_DebugCraft().active, false)
check("  and plays final strike", strikes, before + 1)
check("  and frees castTexture", Pulse.IsCrafting(), false)

-- Disparate spell ID interrupted/stopped
startCraft(2662, 3.0)
Pulse.CastActivity:_OnStart("player", "guid-smith-2", 2018)
runCraftTo(3.0, 0.5, 10)
before = strikes
Pulse.CastActivity:_OnStop("player", "guid-smith-2", 2018)
check("disparate spell ID stop terminates craft", M:_DebugCraft().active, false)
check("  without courtesy strike", strikes, before)
check("  and frees castTexture", Pulse.IsCrafting(), false)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
