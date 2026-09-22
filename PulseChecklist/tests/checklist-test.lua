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
        io.write(("FAIL  %-50s got %s, wanted %s\n")
            :format(label, tostring(got), tostring(want)))
    else
        io.write(("ok    %s\n"):format(label))
    end
end

-- ── Stub WoW API ──────────────────────────────────────────────────────────────

local METHOD_PREFIXES = {
    "Set", "Get", "Is", "Register", "Unregister", "Enable", "Disable",
    "Show", "Hide", "Start", "Stop", "Create", "Click", "Clear", "Add", "Highlight",
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
        if frameType == "Button" and f.__script_OnClick and f.__script_OnEnter then
            buttons[f] = true
        end
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
    AddLine  = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    Show     = function() end,
    Hide     = function() end,
}

-- ── Fake Pulse ────────────────────────────────────────────────────────────────

local TRIGGER = { id = "autoShotFired", label = "Auto Shot", category = "COMBAT" }

_G.Pulse = {
    Registry = {
        GetCategories         = function() return { "COMBAT" } end,
        GetCategoryLabel      = function() return "Combat texture" end,
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

-- Building a row calls ensureEntry, so the entry exists before anything is clicked. That
-- predates confirmedBy; what matters here is that it starts unstamped.
check("row build seeded the entry", type(PulseChecklistDB.autoShotFired), "table")
check("  starting untested", PulseChecklistDB.autoShotFired.status, "untested")
check("  and unstamped", PulseChecklistDB.autoShotFired.confirmedBy, nil)

statusButton.__script_OnClick(statusButton)   -- untested -> functioning
local entry = PulseChecklistDB.autoShotFired
check("click created the entry", type(entry), "table")
check("  status advanced", entry.status, "functioning")
check("  confirmedBy recorded", type(entry.confirmedBy), "table")
check("  with this character", entry.confirmedBy and entry.confirmedBy.name, "Testchar")
check("  and its realm", entry.confirmedBy and entry.confirmedBy.realm, "Testrealm")
check("  and its class", entry.confirmedBy and entry.confirmedBy.class, "HUNTER")

-- Cycle all the way back round to untested: the stamp must go with it.
statusButton.__script_OnClick(statusButton)   -- needswork
statusButton.__script_OnClick(statusButton)   -- nonfunctioning
check("cycled to nonfunctioning", entry.status, "nonfunctioning")
check("  still stamped", type(entry.confirmedBy), "table")
statusButton.__script_OnClick(statusButton)   -- untested
check("cycled back to untested", entry.status, "untested")
check("  stamp cleared", entry.confirmedBy, nil)

-- ── Confirmed elsewhere ───────────────────────────────────────────────────────

io.write("\n--- another character ---\n")

statusButton.__script_OnClick(statusButton)   -- functioning, as Testchar
local selfText = statusButton:GetText()
check("own confirmation is unmarked", selfText:find("\194\183", 1, true) == nil, true)

-- Same saved table, different character logged in.
who = { name = "Otherchar", realm = "Testrealm", class = "MAGE" }
statusButton.__script_OnEnter(statusButton)
local joined = table.concat(tooltipLines, "\n")
check("tooltip names the other character", joined:find("Testchar", 1, true) ~= nil, true)
check("  and warns it was not this one", joined:find("Not this character", 1, true) ~= nil, true)

-- The marker only appears once a refresh runs, which a click does.
statusButton.__script_OnClick(statusButton)   -- needswork, now as Otherchar
statusButton.__script_OnClick(statusButton)   -- nonfunctioning
check("re-stamped to the current character",
    PulseChecklistDB.autoShotFired.confirmedBy.name, "Otherchar")

-- ── Pre-confirmedBy saved data ────────────────────────────────────────────────

io.write("\n--- legacy entry ---\n")

-- What an existing saved table looks like: status and comment, no confirmedBy.
PulseChecklistDB.autoShotFired = { status = "functioning", comment = "worked on the hunter" }
local okEnter = pcall(statusButton.__script_OnEnter, statusButton)
check("tooltip copes with no stamp", okEnter, true)
check("  and says so plainly",
    table.concat(tooltipLines, "\n"):find("before this build recorded", 1, true) ~= nil, true)
check("comment survived untouched",
    PulseChecklistDB.autoShotFired.comment, "worked on the hunter")

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
