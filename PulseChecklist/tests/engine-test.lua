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

Engine:PlayMode("test", "STUTTER", 1.0)
local scheduled = pendingTimers()
check("STUTTER scheduled again", scheduled > 0, true)
recreated = 0
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

-- ── Inverted Schema & Presets ────────────────────────────────────────────────

assert(loadfile(ROOT .. "/Core/Schemas/Inverted.lua"))("Pulse", Pulse)

local inv = Pulse.HapticSchemas.inverted
check("inverted schema registered", type(inv), "table")
local invLow = inv.roles and inv.roles.low
local invHigh = inv.roles and inv.roles.high
check("inverted schema maps low to High channel", invLow and invLow.channel, "High")
check("inverted schema maps high to Low channel", invHigh and invHigh.channel, "Low")

check("8bitdo preset registered", type(Pulse.Devices["8bitdo"]), "table")
check("xbox_elite preset registered", type(Pulse.Devices.xbox_elite), "table")
check("steamdeck preset registered", type(Pulse.Devices.steamdeck), "table")
check("steamcontroller2 preset registered", type(Pulse.Devices.steamcontroller2), "table")
check("steamcontroller preset registered", type(Pulse.Devices.steamcontroller), "table")

check("steamdeck low gain", Pulse.Devices.steamdeck.channels.Low.gain, 1.20)
check("steamdeck low floor", Pulse.Devices.steamdeck.channels.Low.floor, 0.050)
check("steamcontroller2 low floor", Pulse.Devices.steamcontroller2.channels.Low.floor, 0.035)
check("steamcontroller low floor", Pulse.Devices.steamcontroller.channels.Low.floor, 0.060)

check("dualsense triggers disabled", Pulse.Devices.dualsense.triggers, false)
check("dualsense low gain", Pulse.Devices.dualsense.channels.Low.gain, 1.15)
check("dualsense low floor", Pulse.Devices.dualsense.channels.Low.floor, 0.030)
check("ds4 triggers disabled", Pulse.Devices.ds4.triggers, false)
check("ds4 low floor", Pulse.Devices.ds4.channels.Low.floor, 0.120)
check("xbox triggers enabled", Pulse.Devices.xbox.triggers, true)
check("xbox_elite triggers enabled", Pulse.Devices.xbox_elite.triggers, true)

local mockRawState = {}
C_GamePad.GetDeviceRawState = function(_)
	return mockRawState
end

mockRawState = { name = "8BitDo Ultimate Wireless Controller" }
local _, d1 = Pulse.DetectDevice()
check("detect 8bitdo controller", d1, "8bitdo")

mockRawState = { name = "Xbox Elite Wireless Controller" }
local _, d2 = Pulse.DetectDevice()
check("detect xbox elite controller", d2, "xbox_elite")

mockRawState = { name = "Wireless Controller" }
local _, d3 = Pulse.DetectDevice()
check("detect wireless controller fallback", d3, "dualsense")

mockRawState = { name = "Steam Deck Controller" }
local _, dDeck = Pulse.DetectDevice()
check("detect steam deck name", dDeck, "steamdeck")

mockRawState = { name = "Steam Virtual Gamepad" }
local _, dVirt = Pulse.DetectDevice()
check("detect steam virtual gamepad name", dVirt, "steamdeck")

mockRawState = { name = "Steam Controller 2" }
local _, dSC2 = Pulse.DetectDevice()
check("detect steam controller 2 name", dSC2, "steamcontroller2")

mockRawState = { name = "Steam Controller" }
local _, dSC1 = Pulse.DetectDevice()
check("detect steam controller v1 name", dSC1, "steamcontroller")

mockRawState = { name = "Joy-Con (L/R)" }
local _, dJoy = Pulse.DetectDevice()
check("detect joy-con name", dJoy, "switchpro")

-- macOS Bluetooth DualShock 4 vs DualSense disambiguation (both name themselves "Wireless Controller")
mockRawState = { name = "Wireless Controller", vendorID = 0x054C, productID = 0x09CC }
local _, dMacDS4 = Pulse.DetectDevice()
check("macOS bluetooth DS4 matches ds4 not dualsense", dMacDS4, "ds4")

mockRawState = { name = "Wireless Controller", vendorID = 0x054C, productID = 0x0CE6 }
local _, dMacDS5 = Pulse.DetectDevice()
check("macOS bluetooth DualSense matches dualsense", dMacDS5, "dualsense")

mockRawState = { vendorID = 0x054C, productID = 0x0BA0 }
local _, dDS4Dongle = Pulse.DetectDevice()
check("detect DS4 USB wireless adaptor PID", dDS4Dongle, "ds4")

-- Xbox PID priority over generic "Xbox Wireless Controller" name
mockRawState = { name = "Xbox Wireless Controller", vendorID = 0x045E, productID = 0x0B00 }
local _, dPID_EliteUSB = Pulse.DetectDevice()
check("detect xbox elite series 2 USB PID", dPID_EliteUSB, "xbox_elite")

mockRawState = { name = "Xbox Wireless Controller", vendorID = 0x045E, productID = 0x0B05 }
local _, dPID_EliteBT = Pulse.DetectDevice()
check("detect xbox elite series 2 BT PID", dPID_EliteBT, "xbox_elite")

mockRawState = { vendorID = 0x045E, productID = 0x0B12 }
local _, dPID_SeriesX = Pulse.DetectDevice()
check("detect xbox series X PID", dPID_SeriesX, "xbox")

-- Switch Pro & Joy-Con PIDs
mockRawState = { vendorID = 0x057E, productID = 0x2006 }
local _, dPID_JoyConL = Pulse.DetectDevice()
check("detect joy-con L PID", dPID_JoyConL, "switchpro")

-- 8BitDo PIDs and Vendor fallback
mockRawState = { vendorID = 0x2DC8, productID = 0x310B }
local _, dPID_8BitDo = Pulse.DetectDevice()
check("detect 8bitdo ultimate PID", dPID_8BitDo, "8bitdo")

mockRawState = { vendorID = 0x2DC8, productID = 0x9999 }
local _, dPID_8BitDoFallback = Pulse.DetectDevice()
check("detect 8bitdo vendor fallback", dPID_8BitDoFallback, "8bitdo")

-- Valve PID detection tests
mockRawState = { vendorID = 0x28DE, productID = 0x1102 }
local _, dPID_SC1 = Pulse.DetectDevice()
check("detect steam controller v1 wired PID", dPID_SC1, "steamcontroller")

mockRawState = { vendorID = 0x28DE, productID = 0x1142 }
local _, dPID_SC1_Dongle = Pulse.DetectDevice()
check("detect steam controller v1 dongle PID", dPID_SC1_Dongle, "steamcontroller")

mockRawState = { vendorID = 0x28DE, productID = 0x11FF }
local _, dPID_Virt = Pulse.DetectDevice()
check("detect steam virtual gamepad PID", dPID_Virt, "steamdeck")

mockRawState = { vendorID = 0x28DE, productID = 0x1201 }
local _, dPID_SC2 = Pulse.DetectDevice()
check("detect steam controller 2 wired PID", dPID_SC2, "steamcontroller2")

mockRawState = { vendorID = 0x28DE, productID = 0x1205 }
local _, dPID_Deck = Pulse.DetectDevice()
check("detect steam deck internal PID", dPID_Deck, "steamdeck")

mockRawState = { vendorID = 0x28DE, productID = 0x9999 }
local _, dPID_Fallback = Pulse.DetectDevice()
check("detect unknown valve vendor fallback", dPID_Fallback, "steamdeck")

-- ── Active Ramp Tracking & Set Floor capture ─────────────────────────────────

Engine:RampChannel("Low")
runTimersTo(now + 0.1)
local activeRamp = Engine:GetActiveRamp()
check("active ramp tracked", type(activeRamp), "table")
check("active ramp channel is Low", activeRamp and activeRamp.channel, "Low")
Engine:StopRamp("Low")
check("active ramp cleared by StopRamp", Engine:GetActiveRamp(), nil)

-- ── Defensive C_GamePad guards on RefreshDevice ──────────────────────────────
local savedGamePad = C_GamePad
C_GamePad = nil
local okNilGP = pcall(function()
	Engine:RefreshDevice()
end)
check("RefreshDevice safe when C_GamePad is nil", okNilGP, true)
check("deviceReady false when C_GamePad is nil", Engine:IsDeviceReady(), false)
C_GamePad = savedGamePad
Engine:RefreshDevice()
check("deviceReady restored when C_GamePad present", Engine:IsDeviceReady(), true)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
