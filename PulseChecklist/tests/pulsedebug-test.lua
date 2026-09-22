-- Offline smoke test for PulseDebug's window.
--
-- UI.lua is the one file in this family written entirely blind — a frame nobody can look at
-- without a client. `luac -p` proves it parses, which is the weakest thing worth proving.
-- This loads both PulseDebug files against a stub WoW API and a fake Pulse, then actually
-- drives the window: clicks every button, toggles Live, runs the OnUpdate tick, and reads
-- back what each view rendered.
--
-- It cannot tell you the frame looks right. It can tell you that no view errors, that every
-- closure resolves, that the module reach-in scan finds what it should, and that the
-- Pulse-not-loaded path says so instead of throwing.
--
-- Run from the repo root:  lua PulseChecklist/tests/pulsedebug-test.lua PulseDebug

local ROOT = arg[1] or "PulseDebug"

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        io.write(("FAIL  %-46s got %s, wanted %s\n")
            :format(label, tostring(got), tostring(want)))
    else
        io.write(("ok    %s\n"):format(label))
    end
end

-- ── Stub WoW API ──────────────────────────────────────────────────────────────

-- Same auto-stub idea as harness.lua, narrowed to what these two files touch. Anything that
-- looks like a widget method returns nil; a real frame does the same for an unset data
-- field, and UI.lua branches on exactly that (`if not ui then`, `views[view]`).
local METHOD_PREFIXES = {
    "Set", "Get", "Is", "Register", "Unregister", "Enable", "Disable",
    "Show", "Hide", "Start", "Stop", "Create", "Click", "Raise", "Lower",
}

local function looksLikeMethod(key)
    if type(key) ~= "string" then return false end
    for _, prefix in ipairs(METHOD_PREFIXES) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- Every FontString ever created, so a render can be read back instead of merely not
-- throwing. Without this the view assertions below would only prove pcall succeeded.
local fontStrings = {}

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
    rawset(f, "SetScript", function(_, script, fn) f["__script_" .. script] = fn end)
    rawset(f, "GetScript", function(_, script) return f["__script_" .. script] end)
    -- Text is stored rather than dropped: the whole point is reading back what a view put
    -- on the frame.
    rawset(f, "SetText", function(_, text) f.__text = text end)
    rawset(f, "GetText", function() return f.__text end)
    rawset(f, "SetEnabled", function(_, v) f.__enabled = v and true or false end)
    rawset(f, "IsEnabled", function() return f.__enabled ~= false end)
    rawset(f, "SetChecked", function(_, v) f.__checked = v and true or false end)
    rawset(f, "GetChecked", function() return f.__checked end)
    rawset(f, "GetStringHeight", function() return 120 end)
    rawset(f, "CreateFontString", function() return newFrame("FontString") end)
    if frameType == "FontString" then fontStrings[#fontStrings + 1] = f end
    rawset(f, "CreateTexture", function() return newFrame("Texture") end)
    return f
end

-- Concatenated because the body is not the only FontString on the frame; the assertions
-- below all look for tokens distinctive enough that a title or a label cannot supply them.
local function renderedText()
    local parts = {}
    for _, fs in ipairs(fontStrings) do
        if fs.__text then parts[#parts + 1] = fs.__text end
    end
    return table.concat(parts, "\n")
end

local function clearText()
    for _, fs in ipairs(fontStrings) do fs.__text = nil end
end

local function contains(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil
end

_G = _G or _ENV
UIParent = newFrame("Frame", "UIParent")
BACKDROP_DIALOG_32_32 = { bgFile = "stub", edgeFile = "stub" }
SlashCmdList = {}

function CreateFrame(frameType, name, parent, template)
    local f = newFrame(frameType, name, parent, template)
    if name then _G[name] = f end
    return f
end

C_CVar = { GetCVar = function() return "1" end }
C_GamePad = {
    IsEnabled = function() return true end,
    GetActiveDeviceID = function() return 1 end,
    GetPowerLevel = function() return 3 end,
}
C_Timer = { NewTicker = function() return { Cancel = function() end } end }
function issecretvalue() return false end
function strtrim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- ── Fake Pulse ────────────────────────────────────────────────────────────────

-- Only the surface UI.lua reads. Deliberately not the real Core files: this suite is about
-- whether the window copes with what Pulse hands it, and harness.lua already covers whether
-- Pulse itself loads.
local TRIGGER = { id = "swimTexture", label = "Swimming resistance", continuous = true,
                  mode = nil, throttle = 0, category = "MOVEMENT" }

local fakePulse = {
    moduleOrder = { "Locomotion", "Silent" },
    modules = {
        -- One module with a reach-in, one without: the view must list the first and skip
        -- the second rather than printing an empty heading for it.
        Locomotion = { _DebugGait = function() return { cadence = 0.43, strike = 2, moving = true } end },
        Silent     = { OnEnable = function() end },
    },
    Database = {
        Get = function(_, key)
            if key == "masterEnabled" then return true end
            if key == "masterIntensity" then return 0.8 end
            return "standard"
        end,
        GetActiveProfileName = function() return "Raiding" end,
        GetCue = function() return true end,
    },
    Registry = {
        GetCategories = function() return { "MOVEMENT" } end,
        GetTriggersByCategory = function() return { TRIGGER } end,
    },
    Engine = {
        IsDeviceReady = function() return true end,
        _DebugLayers = function()
            return { { name = "swimTexture", low = 0.4, high = nil,
                       ltrigger = nil, rtrigger = 0.2, remaining = 1.5 } }
        end,
        _DebugChannels = function()
            return { Low = { smoothed = 0.31, lastSet = 0.30 } }
        end,
        _ActiveSchema = function()
            return { id = "standard", label = "Standard",
                     roles = { low = { channel = "Low", intensity = 1.0 } } }
        end,
    },
}

-- ── Load ──────────────────────────────────────────────────────────────────────

io.write("--- loading ---\n")
for _, relative in ipairs({ "Debug.lua", "UI.lua" }) do
    local chunk, err = loadfile(ROOT .. "/" .. relative)
    if not chunk then
        failures = failures + 1
        io.write("LOAD FAIL  " .. relative .. ": " .. tostring(err) .. "\n")
    else
        local ok, runErr = pcall(chunk, "PulseDebug")
        if not ok then
            failures = failures + 1
            io.write("RUN FAIL   " .. relative .. ": " .. tostring(runErr) .. "\n")
        else
            io.write("loaded     " .. relative .. "\n")
        end
    end
end

io.write("\n--- window ---\n")

check("UI.lua exported PulseDebugUI", type(_G.PulseDebugUI), "table")
check("both slash commands registered",
    SlashCmdList["PULSEDEBUG"] ~= nil and SlashCmdList["PULSEDEBUGUI"] ~= nil, true)

local frame = _G["PulseDebugUIFrame"]
check("named frame exists", type(frame), "table")

-- Pulse absent: the window must say so rather than throw, because the most likely time
-- someone opens this is when Pulse did not load.
_G.Pulse = nil
clearText()
local okHidden = pcall(_G.PulseDebugUI.Toggle)
check("opens with Pulse absent", okHidden, true)
check("  and says so on the frame", contains(renderedText(), "Pulse is not loaded"), true)
_G.PulseDebugUI.Toggle() -- close again

-- ── Every view, with Pulse present ────────────────────────────────────────────

_G.Pulse = fakePulse

io.write("\n--- views ---\n")

-- Each view is checked for a token only that view can produce, so a silently empty render
-- fails instead of passing.
local EXPECTED = {
    { "state",    "masterEnabled" },
    { "layers",   "swimTexture"   },
    { "channels", "Low"           },
    { "modules",  "cadence"       },
    { "schema",   "standard"      },
}

for _, case in ipairs(EXPECTED) do
    local view, token = case[1], case[2]
    clearText()
    local ok = pcall(_G.PulseDebugUI.Show, view)
    check("view renders: " .. view, ok, true)
    check("  and shows " .. token, contains(renderedText(), token), true)
end

-- The reach-in scan must skip a module that has none rather than print a bare heading.
clearText()
_G.PulseDebugUI.Show("modules")
check("modules lists one with a reach-in", contains(renderedText(), "Locomotion"), true)
check("  and skips one without", contains(renderedText(), "Silent"), false)

-- ── Live tick ─────────────────────────────────────────────────────────────────

io.write("\n--- live ---\n")

local onUpdate = frame:GetScript("OnUpdate")
check("OnUpdate is wired", type(onUpdate), "function")

-- Off by default, so a tick must be a no-op rather than a render.
local okIdle = pcall(onUpdate, frame, 1.0)
check("tick is safe while Live is off", okIdle, true)

-- Drive several ticks past the 0.1s threshold with Live on. Any view erroring under repeat
-- render shows up here rather than in a client.
_G.PulseDebugUI.Show("layers")
local okLive = true
for _ = 1, 5 do
    local ok = pcall(onUpdate, frame, 0.2)
    okLive = okLive and ok
end
check("ticks safely under repeat render", okLive, true)

-- ── Module introspection ──────────────────────────────────────────────────────

io.write("\n--- modules ---\n")

-- A module whose reach-in throws must not take the window down with it.
fakePulse.modules.Angry = { _DebugBoom = function() error("deliberate") end }
fakePulse.moduleOrder[#fakePulse.moduleOrder + 1] = "Angry"
clearText()
check("survives a reach-in that errors", pcall(_G.PulseDebugUI.Show, "modules"), true)
check("  and reports it inline", contains(renderedText(), "errored"), true)
check("  while still showing the healthy one", contains(renderedText(), "cadence"), true)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
