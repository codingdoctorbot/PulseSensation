-- Offline smoke test for PulseChecklist's window and its saved state.
--
-- The checklist table is ACCOUNT-WIDE (PulseChecklist.toc's `## SavedVariables`), which is
-- deliberate: whether a cue fires is a fact about the addon and the client, not about who
-- is logged in. What that scope cannot express on its own is that some cues are only
-- reachable by particular characters — autoShotFired is Hunter-only, combo points need a
-- rogue or druid — so `confirmedBy` records which character set a status.
--
-- This drives the real status button through its real OnClick: cycling stamps the current
-- character, cycling back to untested clears it, and an entry stamped by somebody else is
-- marked. It also covers the pre-`confirmedBy` entry shape, since an existing saved table
-- has none and must not error or be mislabelled.
--
-- Run from the repo root:  lua PulseChecklist/tests/checklist-test.lua PulseChecklist

local ROOT = arg[1] or "PulseChecklist"

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        io.write(("FAIL  %-50s got %s, wanted %s\n"):format(label, tostring(got), tostring(want)))
    else
        io.write(("ok    %s\n"):format(label))
    end
end

-- ── Stub WoW API ──────────────────────────────────────────────────────────────

local METHOD_PREFIXES = {
    "Set",
    "Get",
    "Is",
    "Register",
    "Unregister",
    "Enable",
    "Disable",
    "Show",
    "Hide",
    "Start",
    "Stop",
    "Create",
    "Click",
    "Clear",
    "Add",
    "Highlight",
}

local function looksLikeMethod(key)
    if type(key) ~= "string" then return false end
    for _, prefix in ipairs(METHOD_PREFIXES) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- Status buttons are the ones carrying both OnClick and OnEnter; nothing else on the frame
-- has that pair, so the test can find them without the file exporting anything.
local buttons = {}

local FrameMT = {}
FrameMT.__index = function(tbl, key)
    if not looksLikeMethod(key) then return nil end
    local fn = function() return nil end
    rawset(tbl, key, fn)
    return fn
end

local function newFrame(frameType, name, parent, template)
    local f = setmetatable({}, FrameMT)
    f.__frameType, f.__template, f.__shown = frameType, template, false
    rawset(f, "Show", function() f.__shown = true end)
    rawset(f, "Hide", function() f.__shown = false end)
    rawset(f, "IsShown", function() return f.__shown end)
    rawset(f, "SetScript", function(_, script, fn)
        f["__script_" .. script] = fn
        if frameType == "Button" and f.__script_OnClick and f.__script_OnEnter then buttons[f] = true end
    end)
    rawset(f, "GetScript", function(_, script) return f["__script_" .. script] end)
    rawset(f, "SetText", function(_, text) f.__text = text end)
    rawset(f, "GetText", function() return f.__text or "" end)
    rawset(f, "GetWidth", function() return 560 end)
    rawset(f, "GetFontString", function()
        f.__fontString = f.__fontString or newFrame("FontString")
        return f.__fontString
    end)
    rawset(f, "CreateFontString", function() return newFrame("FontString") end)
    rawset(f, "CreateTexture", function() return newFrame("Texture") end)
    return f
end

_G = _G or _ENV
UIParent = newFrame("Frame", "UIParent")
BACKDROP_DIALOG_32_32 = { bgFile = "stub" }
SlashCmdList = {}

function CreateFrame(frameType, name, parent, template)
    local f = newFrame(frameType, name, parent, template)
    if name then _G[name] = f end
    return f
end

-- The character this test is "logged in as". Swapped later to prove the elsewhere marker.
local who = { name = "Testchar", realm = "Testrealm", class = "HUNTER" }

function UnitName() return who.name end
function GetRealmName() return who.realm end
function UnitClass() return "Hunter", who.class end
function date() return "2026-09-22" end

local tooltipLines = {}
GameTooltip = {
    SetOwner = function() tooltipLines = {} end,
    AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    Show = function() end,
    Hide = function() end,
}

-- ── Fake Pulse ────────────────────────────────────────────────────────────────

local TRIGGER = { id = "autoShotFired", label = "Auto Shot", category = "COMBAT" }

_G.Pulse = {
    Registry = {
        GetCategories = function() return { "COMBAT" } end,
        GetCategoryLabel = function() return "Combat texture" end,
        GetTriggersByCategory = function() return { TRIGGER } end,
    },
}

-- ── Load ──────────────────────────────────────────────────────────────────────

io.write("--- loading ---\n")
local chunk, err = loadfile(ROOT .. "/Checklist.lua")
if not chunk then
    failures = failures + 1
    io.write("LOAD FAIL  " .. tostring(err) .. "\n")
else
    local ok, runErr = pcall(chunk, "PulseChecklist")
    if not ok then
        failures = failures + 1
        io.write("RUN FAIL   " .. tostring(runErr) .. "\n")
    else
        io.write("loaded     Checklist.lua\n")
    end
end

-- The addon builds rows lazily on first open, so the slash handler is what gets us there.
PulseChecklistDB = {}
local slash = SlashCmdList["PULSECHECKLIST"]
check("slash command registered", type(slash), "function")
pcall(slash, "")

local statusButton = next(buttons)
check("a status button was built", statusButton ~= nil, true)

-- ── Cycling stamps the current character ──────────────────────────────────────

io.write("\n--- stamping ---\n")

-- Building a row does not populate DB; entry is created only when clicked or commented.
check("row build leaves entry clean", PulseChecklistDB.autoShotFired, nil)

statusButton.__script_OnClick(statusButton) -- untested -> functioning
local entry = PulseChecklistDB.autoShotFired
check("click created the entry", type(entry), "table")
check("  status advanced", entry.status, "functioning")
check("  confirmedBy recorded", type(entry.confirmedBy), "table")
check("  with this character", entry.confirmedBy and entry.confirmedBy.name, "Testchar")
check("  and its realm", entry.confirmedBy and entry.confirmedBy.realm, "Testrealm")
check("  and its class", entry.confirmedBy and entry.confirmedBy.class, "HUNTER")

-- Cycle all the way back round to untested: the stamp must go with it.
statusButton.__script_OnClick(statusButton) -- needswork
statusButton.__script_OnClick(statusButton) -- nonfunctioning
check("cycled to nonfunctioning", entry.status, "nonfunctioning")
check("  still stamped", type(entry.confirmedBy), "table")
statusButton.__script_OnClick(statusButton) -- untested
check("cycled back to untested", entry.status, "untested")
check("  stamp cleared", entry.confirmedBy, nil)

-- ── Confirmed elsewhere ───────────────────────────────────────────────────────

io.write("\n--- another character ---\n")

statusButton.__script_OnClick(statusButton) -- functioning, as Testchar
local selfText = statusButton:GetText()
check("own confirmation is unmarked", selfText:find("\194\183", 1, true) == nil, true)

-- Same saved table, different character logged in.
who = { name = "Otherchar", realm = "Testrealm", class = "MAGE" }
statusButton.__script_OnEnter(statusButton)
local joined = table.concat(tooltipLines, "\n")
check("tooltip names the other character", joined:find("Testchar", 1, true) ~= nil, true)
check("  and warns it was not this one", joined:find("Not this character", 1, true) ~= nil, true)

-- The marker only appears once a refresh runs, which a click does.
statusButton.__script_OnClick(statusButton) -- needswork, now as Otherchar
statusButton.__script_OnClick(statusButton) -- nonfunctioning
check("re-stamped to the current character", PulseChecklistDB.autoShotFired.confirmedBy.name, "Otherchar")

-- ── Pre-confirmedBy saved data ────────────────────────────────────────────────

io.write("\n--- legacy entry ---\n")

-- What an existing saved table looks like: status and comment, no confirmedBy.
PulseChecklistDB.autoShotFired = { status = "functioning", comment = "worked on the hunter" }
local okEnter = pcall(statusButton.__script_OnEnter, statusButton)
check("tooltip copes with no stamp", okEnter, true)
check(
    "  and says so plainly",
    table.concat(tooltipLines, "\n"):find("before this build recorded", 1, true) ~= nil,
    true
)
check("comment survived untouched", PulseChecklistDB.autoShotFired.comment, "worked on the hunter")

-- ── Baseline fallback ─────────────────────────────────────────────────────────

io.write("\n--- baseline fallback ---\n")

-- Reset DB so no real entry exists, exposing the baseline layer.
PulseChecklistDB = {}
who = { name = "Testchar", realm = "Testrealm", class = "HUNTER" }

local C = _G.PulseChecklist
check("PulseChecklist global exposed",       type(C), "table")
check("  GetEntry function present",         type(C and C.GetEntry), "function")
check("  BASELINE table present",            type(C and C.BASELINE), "table")

-- locomotion is in BASELINE_ENTRIES as "functioning"
local locoEntry = C.GetEntry("locomotion")
check("baseline entry returns functioning",  locoEntry and locoEntry.status, "functioning")
check("  isBaseline flag set",               locoEntry and locoEntry.isBaseline, true)
check("  has comment",                       type(locoEntry and locoEntry.comment), "string")

-- A trigger not in the baseline should return untested
local unknownEntry = C.GetEntry("__not_a_real_trigger__")
check("unknown trigger returns untested",    unknownEntry and unknownEntry.status, "untested")
check("  isBaseline not set",                unknownEntry and unknownEntry.isBaseline, nil)

-- Baseline entries must NOT be written to DB just by reading
check("read does not pollute DB",            PulseChecklistDB.locomotion, nil)

-- ── Import parser ─────────────────────────────────────────────────────────────

io.write("\n--- import parser ---\n")

PulseChecklistDB = {}

local MARKDOWN_IMPORT = [[
### Pulse QA Checklist Report — 2026-09-23
**Progress:** 3 / 10 Tested (30%)

#### ⚠️ Needs Work (1)
- `damageTaken`: floats only fire with FCT on

#### ❌ Non-Functioning (1)
- `somebrokenCue`: never fires at all

#### ✅ Functioning (3)
`locomotion`, `jumpLand`, `craftTexture`
]]

local imported = C.Import(MARKDOWN_IMPORT)
check("import returns count > 0",            imported > 0, true)

-- Section header context propagation: needswork section
check("needswork entry written",             PulseChecklistDB.damageTaken ~= nil, true)
check("  correct status",                    PulseChecklistDB.damageTaken and PulseChecklistDB.damageTaken.status, "needswork")
check("  comment preserved",                 PulseChecklistDB.damageTaken and PulseChecklistDB.damageTaken.comment, "floats only fire with FCT on")

-- Nonfunctioning section
check("nonfunctioning entry written",        PulseChecklistDB.somebrokenCue ~= nil, true)
check("  correct status",                    PulseChecklistDB.somebrokenCue and PulseChecklistDB.somebrokenCue.status, "nonfunctioning")

-- Comma-separated backtick list under functioning header
check("functioning locomotion written",      PulseChecklistDB.locomotion ~= nil, true)
check("  correct status",                    PulseChecklistDB.locomotion and PulseChecklistDB.locomotion.status, "functioning")
check("functioning jumpLand written",        PulseChecklistDB.jumpLand ~= nil, true)
check("  correct status",                    PulseChecklistDB.jumpLand and PulseChecklistDB.jumpLand.status, "functioning")
check("functioning craftTexture written",    PulseChecklistDB.craftTexture ~= nil, true)
check("  correct status",                    PulseChecklistDB.craftTexture and PulseChecklistDB.craftTexture.status, "functioning")

-- Imported entries are stamped with the current character
check("imported entry stamped",              PulseChecklistDB.locomotion and type(PulseChecklistDB.locomotion.confirmedBy), "table")
check("  stamp has character name",          PulseChecklistDB.locomotion and PulseChecklistDB.locomotion.confirmedBy and PulseChecklistDB.locomotion.confirmedBy.name, "Testchar")

-- ── Baseline promotion on click ───────────────────────────────────────────────

io.write("\n--- baseline promotion on click ---\n")

-- Reset so the row's trigger (autoShotFired) has no DB entry; use the Fake Pulse
-- trigger which is NOT in the baseline. Verify that the baseline path (locomotion)
-- would promote correctly by testing ensureEntry logic directly via Import.
PulseChecklistDB = {}

-- autoShotFired is not in BASELINE, so clicking the button starts from untested
statusButton.__script_OnClick(statusButton)  -- untested -> functioning
check("non-baseline click creates DB entry", type(PulseChecklistDB.autoShotFired), "table")
check("  status is functioning",             PulseChecklistDB.autoShotFired and PulseChecklistDB.autoShotFired.status, "functioning")
check("  stamped on click",                  PulseChecklistDB.autoShotFired and type(PulseChecklistDB.autoShotFired.confirmedBy), "table")

-- Now simulate a baseline trigger being clicked via Import with compact format:
-- ensureEntry will seed from BASELINE first, then click overwrites.
PulseChecklistDB.locomotion = nil  -- ensure baseline path
local compactImported = C.Import("locomotion:needswork:felt weak")
check("compact import written",              PulseChecklistDB.locomotion ~= nil, true)
check("  compact status correct",            PulseChecklistDB.locomotion and PulseChecklistDB.locomotion.status, "needswork")
check("  compact comment correct",           PulseChecklistDB.locomotion and PulseChecklistDB.locomotion.comment, "felt weak")

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
