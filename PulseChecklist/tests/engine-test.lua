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
local frameScripts = {}
function CreateFrame()
	local f = {}
	function f:SetScript(name, fn)
		frameScripts[name] = fn
	end
	return setmetatable(f, {
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

local mockDurMult = nil
local mockEpsilon = nil
local mockGain = nil
local mockFloor = nil

local Pulse = { debug = false }
Pulse.Database = {
	Get = function(_, key)
		if key == "defaultHapticSchema" then
			return "standard"
		end
		return true
	end,
	GetChannelTuning = function(_, _, key, default)
		if key == "gain" and mockGain ~= nil then
			return mockGain
		end
		if key == "floor" and mockFloor ~= nil then
			return mockFloor
		end
		return default
	end,
	GetChangeEpsilon = function()
		return mockEpsilon or 0.0015
	end,
	GetModeTuning = function(_, _, key, default)
		if key == "durMult" and mockDurMult then
			return mockDurMult
		end
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

-- ── Renamed vibration modes & backward compatibility aliases ─────────────────

check("SNAP is in Pulse.Modes", type(Pulse.Modes.SNAP), "table")
check("TRIGGER_CLICK aliases to SNAP", Pulse.Modes.TRIGGER_CLICK, Pulse.Modes.SNAP)
check("SNAP has high motor", Pulse.ModeRoleInfo.SNAP.hasHigh, true)
check("SNAP has no low motor", Pulse.ModeRoleInfo.SNAP.hasLow, false)
check("RECOIL is in Pulse.Modes", type(Pulse.Modes.RECOIL), "table")
check("TRIGGER_RECOIL aliases to RECOIL", Pulse.Modes.TRIGGER_RECOIL, Pulse.Modes.RECOIL)
check("RECOIL has low rumble", Pulse.ModeRoleInfo.RECOIL.hasLow, true)
check("RECOIL has high motor", Pulse.ModeRoleInfo.RECOIL.hasHigh, true)

local lastRoles = nil
local spySetRoles = Engine.SetRoles
Engine.SetRoles = function(self, name, roles, duration, isTransient, shape)
	lastRoles = roles
	return spySetRoles(self, name, roles, duration, isTransient, shape)
end

Engine:RefreshDevice()
Engine:PlayMode("trigger_test", "SNAP", 1.0)
runTimersTo(now + 1)
check("SNAP emits high role", (lastRoles and lastRoles.high ~= nil), true)

Engine.SetRoles = spySetRoles

-- ── Shaped layers (kick, decay, cut) ──────────────────────────────────────────

local testShape = {
	kickTime = 0.022,
	kickGain = 1.6,
	cut = 0.06,
	tau = { low = 0.040, high = 0.018, default = 0.030 },
}
Engine:SetRoles("test_shaped", { low = 0.5, high = 0.3 }, 0.045, true, testShape)
local debugLayers = Engine:_DebugLayers()
local foundShaped = false
for _, layer in ipairs(debugLayers) do
	if layer.name == "test_shaped" then
		foundShaped = layer.shape
	end
end
check("shaped layer registers shape flag in debug view", foundShaped, true)

Engine:StopAll()
check("StopAll clears shaped layers", #Engine:_DebugLayers(), 0)

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
check("xbox triggers disabled", Pulse.Devices.xbox.triggers, false)
check("xbox_elite triggers disabled", Pulse.Devices.xbox_elite.triggers, false)

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

-- ── OnUpdate Error Recovery (Pcall Death Loop Prevention) ─────────────────────
Engine:Set("test_layer", 0.5, 0.5, 1.0)
check("test_layer is present before tick", #Engine:_DebugLayers() > 0, true)

-- Force onEngineTick to throw by corrupting an internal resolver
local origActiveSchema = Engine._ActiveSchema
Engine._ActiveSchema = function()
	error("simulated schema explosion")
end

check("OnUpdate script is wired", type(frameScripts.OnUpdate), "function")
frameScripts.OnUpdate(nil, 0.016)
check("OnUpdate trapped the error in pcall", (Engine.errorCount or 0) > 0, true)
check(
	"  and recorded error message",
	Engine.lastError and Engine.lastError:find("simulated schema explosion") ~= nil,
	true
)
check("  and purged corrupted layers via StopAll", #Engine:_DebugLayers(), 0)

-- Restore healthy function and verify next tick executes cleanly without error
Engine._ActiveSchema = origActiveSchema
local preErrorCount = Engine.errorCount
Engine:Set("healthy_layer", 0.3, 0.3, 1.0)
frameScripts.OnUpdate(nil, 0.016)
check("next frame runs cleanly without repeating error", Engine.errorCount, preErrorCount)
check("  and healthy layer is active", #Engine:_DebugLayers(), 1)
Engine:StopAll()

-- ── Anti-Collapse Step Floor in PlayMode (Time-Dilation) ──────────────────────
mockDurMult = 0.001 -- extreme 1000x speedup
local prevTimerCount = #timers
Engine:PlayMode("test_anti_collapse", "TRIPLE_TAP")
-- TRIPLE_TAP has 3 steps separated by 2 gaps.
-- Step 1 runs synchronously at t=0.
-- Steps 2 and 3 must be scheduled via C_Timer.After with delay >= 20ms and separated by >= 20ms.
check("TRIPLE_TAP with 0.001 durMult schedules subsequent steps", #timers - prevTimerCount >= 2, true)
local timer1 = timers[prevTimerCount + 1]
local timer2 = timers[prevTimerCount + 2]
local delay1 = timer1.at - now
local delay2 = timer2.at - now
check("first delayed step scheduled at >= 20ms floor", delay1 >= 0.020, true)
check("second delayed step scheduled with at least 20ms separation", delay2 - delay1 >= 0.020, true)
mockDurMult = nil
Engine:StopAll()

-- ── Watchdog Input-Drop Prevention on Onset ──────────────────────────────────
-- When a channel flips from idle/decay (wanted == 0) to active hold (wanted > 0),
-- it must force a dispatch even if delta <= epsilon.
Engine:StopAll()
mockEpsilon = 0.10 -- large deadband: delta of 0.05 would normally be ignored
vibrations = 0
Engine:Set("onset_test", 0.05, 0.05, 1.0)
frameScripts.OnUpdate(nil, 0.016)
check("onset forces SetVibration dispatch despite delta <= epsilon", vibrations > 0, true)

-- On the subsequent steady frame (delta == 0, within 250ms), watchdog does NOT re-send
local vibAfterOnset = vibrations
frameScripts.OnUpdate(nil, 0.016)
check("subsequent steady tick within 250ms does not re-send", vibrations, vibAfterOnset)

mockEpsilon = nil
Engine:StopAll()

-- ── CR-013: Role-Pool Aliasing in PlayMode Delayed Steps (ENG-01) ───────────
Engine:StopAll()
-- RISING: step 1 (t=0) is Low 0.5; step 2 (t=0.16) is High 1.0.
Engine:PlayMode("target_rising", "RISING", 1.0)
-- Immediately flood the pool with >16 immediate steps from other layers in the same tick
for i = 1, 20 do
	Engine:PlayMode("flood_" .. i, "TAP", 0.1)
end
-- Advance timers to trigger step 2 of RISING
runTimersTo(now + 0.20)
local foundTarget = nil
for _, l in ipairs(Engine:_DebugLayers()) do
	if l.name == "target_rising" then
		foundTarget = l
		break
	end
end
check("target_rising layer survived delayed step", foundTarget ~= nil, true)
check("  and captured High magnitude is preserved at 1.0", foundTarget and foundTarget.high, 1.0)
check("  and role Low was not polluted by flood steps", foundTarget and foundTarget.low, nil)
Engine:StopAll()

-- ── CR-029: Gain 0 Silences Motor Even with Breakaway Floor > 0 ───────────────
Engine:StopAll()
mockGain = 0
mockFloor = 0.12
vibrations = 0
Engine:Set("gain_zero_test", 0.8, 0.8, 1.0)
frameScripts.OnUpdate(nil, 0.016)
local chanDebug = Engine:_DebugChannels()
check("gain 0 with floor 0.12 produces 0 on Low channel", chanDebug["Low"] and chanDebug["Low"].smoothed or 0, 0)
check("gain 0 with floor 0.12 produces 0 on High channel", chanDebug["High"] and chanDebug["High"].smoothed or 0, 0)
mockGain = nil
mockFloor = nil
Engine:StopAll()

-- ── CR-012: isTransient Support in Engine:Hold and Fast Attack ─────────────────
Engine:StopAll()
Engine:Hold("transient_hold", 1.0, 0, 0.05, true)
local layers = Engine:_DebugLayers()
local foundTransient = false
for _, l in ipairs(layers) do
	if l.name == "transient_hold" then
		foundTransient = l.isTransient
	end
end
check("Engine:Hold passes isTransient=true to layer", foundTransient, true)

Engine:Hold("sustained_hold", 1.0, 0, 0.05, false)
layers = Engine:_DebugLayers()
local foundSustained = true
for _, l in ipairs(layers) do
	if l.name == "sustained_hold" then
		foundSustained = l.isTransient
	end
end
check("Engine:Hold default/false sets isTransient=false", foundSustained, false)
Engine:StopAll()

-- ── ENG-03: Raw Calibration Error Trapping via pcall ─────────────────────────
Engine:StopAll()
local origSetVib = C_GamePad.SetVibration
C_GamePad.SetVibration = function(channel, mag)
	if channel == "Low" and mag == 0.75 then
		error("Hardware calibration failure on Low")
	end
	origSetVib(channel, mag)
end

Engine:RawChannel("Low", 0.75, 0.5)
check("raw hold was scheduled with clear error state", Engine:GetCalibrationError(), nil)

-- Next tick attempts to send Low to C_GamePad.SetVibration
local preErrCount = Engine.errorCount or 0
frameScripts.OnUpdate(nil, 0.016)
check("pcall trapped calibration error safely without crash", Engine:GetCalibrationError() ~= nil, true)
check(
	"  and captured error detail",
	Engine:GetCalibrationError() and Engine:GetCalibrationError():find("Hardware calibration failure on Low") ~= nil,
	true
)
check("  and engine.errorCount did not increment", Engine.errorCount or 0, preErrCount)

-- Normal layers continue working without interruption
Engine:Set("continue_layer", 0.5, 0.5, 0.5)
frameScripts.OnUpdate(nil, 0.016)
check("engine continues operating normally after calibration error", #Engine:_DebugLayers(), 1)

C_GamePad.SetVibration = origSetVib
Engine:StopAll()

-- ── Shutoff deadband: decay snaps to 0 below 0.025 on shutoff ───────────────
Engine:StopAll()
local lastLowVib = nil
local origSetVibSnap = C_GamePad.SetVibration
C_GamePad.SetVibration = function(channel, mag)
	if channel == "Low" then
		lastLowVib = mag
	end
	origSetVibSnap(channel, mag)
end

Engine:Set("shutoff_test", 0.3, 0, 1.0)
frameScripts.OnUpdate(nil, 0.050)
check("shutoff_test initial rumble sent", (lastLowVib or 0) > 0, true)

-- Stop layer so wanted becomes 0, then let release decay run
Engine:StopLayer("shutoff_test")
for _ = 1, 20 do
	frameScripts.OnUpdate(nil, 0.020)
end
check("shutoff_test snapped cleanly to zero", lastLowVib, 0)
C_GamePad.SetVibration = origSetVibSnap
Engine:StopAll()

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
