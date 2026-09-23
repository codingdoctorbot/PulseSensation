-- Targeted test for Modules/Crafting.lua.
--
-- Drives real CRAFT_START / CRAFT_COMPLETE through Core/CastActivity.lua and inspects the
-- module through _DebugCraft, counting engine strikes rather than trusting the maths.

local ROOT = arg[1] or "."

-- ── Stubs ─────────────────────────────────────────────────────────────────────

local now = 1000
function GetTime() return now end

local FrameMT = { __index = function(_, key)
    if type(key) == "string" and key:match("^%u") then return function() end end
    return nil
end }

local scripts = {}
local function newFrame()
    local f = setmetatable({}, FrameMT)
    f.SetScript = function(_, name, fn) scripts[name] = fn end
    f.RegisterEvent = function() end
    f.UnregisterAllEvents = function() end
    f.RegisterUnitEvent = function() end
    return f
end
function CreateFrame() return newFrame() end
function hooksecurefunc() end
function issecretvalue() return false end
function print(...) io.write("[print] ", tostring((...)), "\n") end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function CopyTable(src) local o = {} for k, v in pairs(src) do
    o[k] = type(v) == "table" and CopyTable(v) or v end return o end
function strsplit(sep, str) local o = {} for p in tostring(str):gmatch("[^"..sep.."]+") do o[#o+1] = p end return unpack(o) end
function strtrim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
unpack = unpack or table.unpack

Enum = { Profession = {
    FirstAid = 0, Blacksmithing = 1, Leatherworking = 2, Alchemy = 3, Herbalism = 4,
    Cooking = 5, Mining = 6, Tailoring = 7, Engineering = 8, Enchanting = 9,
    Fishing = 10, Skinning = 11, Jewelcrafting = 12, Inscription = 13,
} }

recipeProfession = Enum.Profession.Blacksmithing
C_TradeSkillUI = { GetProfessionInfoByRecipeID = function()
    if recipeProfession == false then return nil end
    return { profession = recipeProfession }
end }

castStartMs, castEndMs = nil, nil
function UnitCastingInfo() return nil, nil, nil, castStartMs, castEndMs end

-- ── Load ──────────────────────────────────────────────────────────────────────

local Pulse = { modules = {}, moduleOrder = {}, debug = false }
function Pulse:RegisterModule(name, module)
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = name
end
function Pulse:BindFrame(_, sync) Pulse.__sync = sync end
function Pulse:HoldRolesIfEnabled(_, roles) Pulse.__bed = roles and roles.low end

local cues, settings = { craftTexture = true }, {}
Pulse.Database = {
    Get = function(_, key) return key == "masterEnabled" end,
    GetCue = function(_, id) return cues[id] end,
    GetTriggerSetting = function(_, _, key, default)
        local v = settings[key]
        if v == nil then return default end
        return v
    end,
}

local strikes = 0
Pulse.Engine = { PlayMode = function() strikes = strikes + 1 end }

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
    if not ok then failures = failures + 1 end
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
runCraftTo(3.0, 0.5, 10)   -- half way: beat 1 played, beats 2 and 3 not
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

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
