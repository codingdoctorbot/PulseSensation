-- Targeted test for Core/Engine.lua's asynchronous cancellation boundary.
--
-- The claim under test: before the engine generation existed, StopAll cleared state but
-- left already-scheduled C_Timer callbacks alive, so a PlayMode step or a ramp step could
-- fire afterwards and put state straight back. These cases fail against the old code and
-- pass against the new.

local ROOT = arg[1] or "."

-- ── Stubs ─────────────────────────────────────────────────────────────────────

local now = 1000
function GetTime()
    return now
end

-- A controllable timer queue, so "later" is something the test decides.
local timers = {}
C_Timer = {
    After = function(delay, fn)
        timers[#timers + 1] = { at = now + delay, fn = fn }
    end,
}

local function pendingTimers()
    return #timers
end

-- Fires everything due up to `untilTime`, in order, exactly as the client would.
local function runTimersTo(untilTime)
    now = untilTime
    table.sort(timers, function(a, b)
        return a.at < b.at
    end)
    local due, rest = {}, {}
    for _, t in ipairs(timers) do
        if t.at <= untilTime then
            due[#due + 1] = t
        else
            rest[#rest + 1] = t
        end
    end
    timers = rest
    for _, t in ipairs(due) do
        t.fn()
    end
end

local vibrations = 0
C_GamePad = {
    IsEnabled = function()
        return true
    end,
    GetActiveDeviceID = function()
        return 1
    end,
    SetVibration = function()
        vibrations = vibrations + 1
    end,
    StopVibration = function() end,
}

local printed = 0
function print()
    printed = printed + 1
end
function issecretvalue()
    return false
end
function CreateFrame()
    return setmetatable({}, {
        __index = function()
            return function() end
        end,
    })
end
function wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end
unpack = unpack or table.unpack

local Pulse = { debug = false }
Pulse.Database = {
    Get = function(_, key)
        if key == "defaultHapticSchema" then
            return "standard"
        end
        return true
    end,
    GetChannelTuning = function(_, _, _, default)
        return default
    end,
    GetChangeEpsilon = function()
        return 0.0015
    end,
    GetModeTuning = function(_, _, _, default)
        return default
    end,
    OnChannelTuningChanged = function() end,
    OnGlobalChanged = function() end,
}

for _, file in ipairs({
    "Core/Modes.lua",
    "Core/Devices.lua",
    "Core/Schemas/Standard.lua",
    "Core/Engine.lua",
}) do
    assert(loadfile(ROOT .. "/" .. file))("Pulse", Pulse)
end

local Engine = Pulse.Engine
Engine:RefreshDevice()

-- Spy on the two entry points a stale callback would use to recreate state.
local recreated = 0
local realSet, realSetRoles = Engine.Set, Engine.SetRoles
Engine.Set = function(self, ...)
    recreated = recreated + 1
    return realSet(self, ...)
end
Engine.SetRoles = function(self, ...)
    recreated = recreated + 1
    return realSetRoles(self, ...)
end

local realRaw = Engine.RawChannel
local rawCalls = 0
Engine.RawChannel = function(self, ...)
    rawCalls = rawCalls + 1
    return realRaw(self, ...)
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local failures = 0
local function check(label, got, want)
    local ok = (got == want)
    if not ok then
        failures = failures + 1
    end
    io.write(("%-52s %-8s %s\n"):format(label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
end

-- ── A normal sequence still runs ──────────────────────────────────────────────

recreated = 0
Engine:PlayMode("test", "STUTTER", 1.0)
check("STUTTER schedules steps", pendingTimers() > 0, true)
runTimersTo(now + 5)
check("  and they run when nothing stops them", recreated > 0, true)

-- ── StopAll voids scheduled PlayMode steps ────────────────────────────────────

recreated = 0
Engine:PlayMode("test", "STUTTER", 1.0)
local scheduled = pendingTimers()
check("STUTTER scheduled again", scheduled > 0, true)
Engine:StopAll()
runTimersTo(now + 5)
check("StopAll voids every pending step", recreated, 0)
check("  and the queue drained anyway", pendingTimers(), 0)

-- Re-firing after a StopAll must still work: the generation only voids the past.
recreated = 0
Engine:RefreshDevice()
Engine:PlayMode("test", "STUTTER", 1.0)
runTimersTo(now + 5)
check("a cue fired AFTER StopAll still plays", recreated > 0, true)

-- ── StopAll voids a ramp in flight ────────────────────────────────────────────

rawCalls, printed = 0, 0
Engine:RampChannel("Low")
check("ramp schedules its sweep", pendingTimers() > 1, true)
runTimersTo(now + 1.0)
local partway = rawCalls
check("  and steps while it runs", partway > 0, true)

Engine:StopAll()
runTimersTo(now + 60)
check("StopAll voids the rest of the ramp", rawCalls, partway)
check("  and the whole queue is drained", pendingTimers(), 0)

-- ── A layer token still cancels one sequence without touching the rest ────────

recreated = 0
Engine:RefreshDevice()
Engine:PlayMode("alpha", "STUTTER", 1.0)
Engine:PlayMode("beta", "STUTTER", 1.0)
Engine:PlayMode("alpha", "STUTTER", 1.0) -- supersedes alpha's first sequence
runTimersTo(now + 5)
check("re-firing one cue does not silence the other", recreated > 0, true)

-- ── Trigger vibration modes & role fallback ──────────────────────────────────

assert(loadfile(ROOT .. "/Core/Schemas/RumbleAndTriggers.lua"))("Pulse", Pulse)

check("TRIGGER_CLICK is in Pulse.Modes", type(Pulse.Modes.TRIGGER_CLICK), "table")
check("TRIGGER_CLICK has hasTrigger", Pulse.ModeRoleInfo.TRIGGER_CLICK.hasTrigger, true)
check("TRIGGER_CLICK has no low motor", Pulse.ModeRoleInfo.TRIGGER_CLICK.hasLow, false)
check("TRIGGER_RECOIL has trigger", Pulse.ModeRoleInfo.TRIGGER_RECOIL.hasTrigger, true)
check("TRIGGER_RECOIL has low rumble", Pulse.ModeRoleInfo.TRIGGER_RECOIL.hasLow, true)

local lastRoles = nil
local spySetRoles = Engine.SetRoles
Engine.SetRoles = function(self, name, roles, duration)
    lastRoles = roles
    return spySetRoles(self, name, roles, duration)
end

Engine:RefreshDevice()
Engine:PlayMode("trigger_test", "TRIGGER_CLICK", 1.0)
runTimersTo(now + 1)
check("TRIGGER_CLICK emits rtrigger role", (lastRoles and lastRoles.rtrigger ~= nil), true)

Engine.SetRoles = spySetRoles

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
