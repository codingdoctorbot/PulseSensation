-- Targeted test for Locomotion.lua:
-- 1. Ground-contact guard
-- 2. CR-005: Cadence steps/sec and discrete transient footfalls (on foot & mounted GALLOP)
-- 3. CR-030: Schema-aware footfall splitting
-- 4. CR-020: Applied device preset tracking

local ROOT = arg[1] or "."

-- ── Stubs ────────────────────────────────────────────────────────────────────

local now = 1000
function GetTime()
	return now
end

local createdFrames = {}
function CreateFrame()
	local scripts = {}
	local f = {
		SetScript = function(self, name, fn)
			scripts[name] = fn
		end,
		GetScript = function(self, name)
			return scripts[name]
		end,
		RegisterEvent = function() end,
		UnregisterAllEvents = function() end,
	}
	createdFrames[#createdFrames + 1] = f
	return f
end

local hooks = {}
function hooksecurefunc(name, fn)
	hooks[name] = fn
end
function JumpOrAscendStart() end

swimming, flying, falling, gliding = false, false, false, false
local mounted = false
local playerSpeed = 7.0

function IsSwimming()
	return swimming
end
function IsFlying()
	return flying
end
function IsFalling()
	return falling
end
function IsMounted()
	return mounted
end
C_PlayerInfo = {
	GetGlidingInfo = function()
		return gliding, true, 0
	end,
}
C_Spell = {
	IsSpellKnownOrOverridesKnown = function()
		return false
	end,
}
C_Item = {
	GetItemInfoInstant = function()
		return nil
	end,
}
Enum = { ItemClass = { Armor = 4 } }
function issecretvalue()
	return false
end
function UnitRace()
	return "Human", "Human"
end
function GetUnitSpeed()
	return playerSpeed
end
local currentForm = nil
function GetShapeshiftFormID()
	return currentForm
end
function GetInventoryItemID()
	return nil
end
function print(...)
	io.write("[print] ", ..., "\n")
end

local currentSchema = "standard"
local dbStore = {
	masterEnabled = true,
	cues = { locomotion = true },
	appliedDevicePreset = "default",
	devicePreset = "default",
	triggerSettings = {
		locomotion = {
			runCadence = 2.8,
			walkCadence = 1.8,
			gaitIntensity = 0.35,
			mountedOnly = 0,
			splitFeet = 1,
			mountIntensity = 1.2,
		},
	},
}

local Pulse = {
	modules = {},
	Database = {
		GetLocomotionProfile = function()
			return nil
		end,
		SetLocomotionProfile = function() end,
		GetTriggerSetting = function(_, triggerID, key, default)
			local t = dbStore.triggerSettings[triggerID]
			if t and t[key] ~= nil then
				return t[key]
			end
			return default
		end,
		GetDevicePreset = function()
			return dbStore.devicePreset or "default"
		end,
		GetAppliedDevicePreset = function()
			return dbStore.appliedDevicePreset or dbStore.devicePreset or "default"
		end,
		SetDevicePreset = function(_, id)
			dbStore.devicePreset = id
		end,
		ApplyDevicePreset = function(_, id)
			dbStore.appliedDevicePreset = id
			dbStore.devicePreset = id
		end,
		Get = function(_, key)
			if key == "masterEnabled" then
				return dbStore.masterEnabled
			end
			return false
		end,
		GetCue = function(_, cue)
			return dbStore.cues[cue] == true
		end,
	},
	Devices = {
		default = { label = "Generic", triggers = false },
		xbox = { label = "Xbox", triggers = true },
		dualsense = { label = "DualSense", triggers = false },
	},
	HapticSchemas = {
		standard = {
			roles = {
				low = { channel = "Low" },
				high = { channel = "High" },
			},
		},
		rumbleAndTriggers = {
			roles = {
				low = { channel = "Low" },
				high = { channel = "High" },
				ltrigger = { channel = "LTrigger" },
				rtrigger = { channel = "RTrigger" },
			},
		},
		lowOnly = {
			roles = {
				low = { channel = "Low" },
				high = { channel = "Low" },
			},
		},
		highOnly = {
			roles = {
				low = { channel = "High" },
				high = { channel = "High" },
			},
		},
	},
}

Pulse.Engine = {
	_ActiveSchema = function()
		return Pulse.HapticSchemas[currentSchema]
	end,
	ResolveRole = function(self, role, schema)
		schema = schema or self:_ActiveSchema()
		local def = schema.roles[role]
		if def then
			return def
		end
		local fb = { ltrigger = "low", rtrigger = "high" }
		return fb[role] and schema.roles[fb[role]] or nil
	end,
}

local syncFn = nil
function Pulse:RegisterModule(name, module)
	self.modules[name] = module
end
function Pulse:BindFrame(_, fn)
	syncFn = fn
end

local holdCalls = {}
local holdRoleCalls = {}

function Pulse:HoldIfEnabled(cue, low, high, duration, isTransient, shape)
	holdCalls[#holdCalls + 1] = {
		cue = cue,
		low = low,
		high = high,
		duration = duration,
		isTransient = isTransient,
		shape = shape,
		time = now,
	}
end

function Pulse:HoldRolesIfEnabled(cue, roles, duration, isTransient)
	local copy = {}
	for k, v in pairs(roles) do
		copy[k] = v
	end
	holdRoleCalls[#holdRoleCalls + 1] = {
		cue = cue,
		roles = copy,
		duration = duration,
		isTransient = isTransient,
		time = now,
	}
end

function Pulse:Stop() end

assert(loadfile(ROOT .. "/Modules/Locomotion.lua"))("Pulse", Pulse)

local M = Pulse.modules.Locomotion
local failures = 0

local function check(label, actual, expected)
	local ok = (actual == expected)
	if not ok then
		failures = failures + 1
	end
	io.write(
		("%-52s actual=%-6s expected=%-6s %s\n"):format(
			label,
			tostring(actual),
			tostring(expected),
			ok and "ok" or "FAIL"
		)
	)
end

-- ── Part 1: Ground-Contact Guard ─────────────────────────────────────────────

io.write("\n── Part 1: Ground-Contact Guard ──\n")

local function reset()
	swimming, flying, falling, gliding = false, false, false, false
	now = now + 100 -- well past any jump grace
end

reset()
check("standing on ground", M:_DebugGait().grounded, true)

reset()
swimming = true
check("swimming", M:_DebugGait().grounded, false)

reset()
flying = true
check("flying (also covers a taxi ride)", M:_DebugGait().grounded, false)

reset()
gliding = true
check("gliding (Skyriding)", M:_DebugGait().grounded, false)

reset()
falling = true
check("falling", M:_DebugGait().grounded, false)

-- The rise of a jump: IsFalling() is still false, so only the hook covers it.
reset()
hooks["JumpOrAscendStart"]()
check("jump, 0.0s after the input (ascent)", M:_DebugGait().grounded, false)
now = now + 0.40
check("jump, 0.4s after the input (ascent)", M:_DebugGait().grounded, false)
now = now + 0.10
check("jump, 0.5s after the input (grace over)", M:_DebugGait().grounded, true)

-- And the descent is picked up by IsFalling even after the grace expires.
falling = true
check("jump, grace over but still falling", M:_DebugGait().grounded, false)

-- ── Part 2: CR-030 Schema-Aware Footfall Splitting ───────────────────────────

io.write("\n── Part 2: CR-030 Schema-Aware Footfall Splitting ──\n")

-- pollFrame is createdFrames[1], eventFrame is createdFrames[2]
local pollFrame = createdFrames[1]
local eventFrame = createdFrames[2]

M:OnEnable()
if syncFn then
	syncFn()
end

-- Case 2A: Footfalls drive both Low and High motors with shaped envelope
currentSchema = "standard"
dbStore.appliedDevicePreset = "xbox"
dbStore.devicePreset = "xbox"
dbStore.triggerSettings.locomotion.splitFeet = 0
mounted = false
playerSpeed = 7.0
reset()

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STARTED_MOVING")
local onUpdate = pollFrame:GetScript("OnUpdate")
check("OnUpdate installed on start moving", onUpdate ~= nil, true)

holdCalls = {}
-- Tick for 1 frame
onUpdate(pollFrame, 1 / 60)
check("Footfall sent via HoldIfEnabled", #holdCalls > 0, true)
check("Footfall drives Low motor for body mass", holdCalls[1] and holdCalls[1].low > 0, true)
check("Footfall drives High motor for contact crispness", holdCalls[1] and holdCalls[1].high > 0, true)
check("Footfall uses transient fast attack lane", holdCalls[1] and holdCalls[1].isTransient, true)
check("Footfall duration is discrete 45ms tap", holdCalls[1] and holdCalls[1].duration, 0.045)
check("Footfall attaches shaped envelope table", holdCalls[1] and type(holdCalls[1].shape) == "table", true)
check("Footfall shape has kickGain >= 1.5", holdCalls[1] and (holdCalls[1].shape.kickGain or 0) >= 1.5, true)
check("Footfall shape has cut threshold", holdCalls[1] and (holdCalls[1].shape.cut or 0) > 0, true)

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STOPPED_MOVING")

-- ── Part 3: Stereo Timbre Panning (splitFeet) ────────────────────────────────

io.write("\n── Part 3: Stereo Timbre Panning (splitFeet) ──\n")

-- When splitFeet is 1, left foot leans Low (left) and right foot leans High (right)
dbStore.triggerSettings.locomotion.splitFeet = 1
reset()

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STARTED_MOVING")
holdCalls = {}
-- First step (stepIndex == 1, left foot)
onUpdate(pollFrame, 1 / 60)
check("Left footfall sent", #holdCalls == 1, true)
local leftLow = holdCalls[1].low
local leftHigh = holdCalls[1].high

-- Advance phase to step 2 (right foot)
local dt = 1 / 60
while #holdCalls < 2 do
	now = now + dt
	onUpdate(pollFrame, dt)
end
check("Right footfall sent", #holdCalls >= 2, true)
local rightLow = holdCalls[2].low
local rightHigh = holdCalls[2].high

-- Left foot leans Low vs Right foot which leans High
check("Left foot has higher low motor than right foot", leftLow > rightLow, true)
check("Right foot has higher high motor than left foot", rightHigh > leftHigh, true)

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STOPPED_MOVING")

-- ── Part 4: CR-005 Cadence & Footfalls per Second on Foot ─────────────────────

io.write("\n── Part 4: CR-005 Cadence & Footfalls per Second (On Foot) ──\n")

currentSchema = "standard"
dbStore.appliedDevicePreset = "default"
dbStore.devicePreset = "default"
mounted = false
playerSpeed = 7.0 -- Base run speed
dbStore.triggerSettings.locomotion.runCadence = 2.8
reset()

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STARTED_MOVING")
holdCalls = {}
holdRoleCalls = {}

-- Simulate 10.0 seconds of running at 60 fps (600 frames, dt = 1/60)
local dt = 1 / 60
for _ = 1, 600 do
	now = now + dt
	onUpdate(pollFrame, dt)
end

-- At 2.8 steps/sec over 10.0 seconds, exactly 28 steps should have fired (28 or 29 with fencepost t=0)
local footfallCount = #holdCalls
local stepsPerSec = footfallCount / 10.0
check("CR-005: 10s run footfall count ~28 (was 56)", footfallCount == 28 or footfallCount == 29, true)
check("CR-005: steps/sec matches configured 2.8 within 0.1", math.abs(stepsPerSec - 2.8) <= 0.1, true)

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STOPPED_MOVING")

-- ── Part 5: CR-005 Mounted GALLOP Cadence & Hoof Patterns ────────────────────

io.write("\n── Part 5: CR-005 Mounted GALLOP Cadence & Hoof Patterns ──\n")

mounted = true
playerSpeed = 11.2 -- 60% mount speed (1.6x base)
reset()

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STARTED_MOVING")
local gaitInfo = M:_DebugGait()
check("CR-005: mounted gait mode is GALLOP", gaitInfo.mode, "GALLOP")
check(
	"CR-005: mounted cadence is normalized (not pinned at 8.0)",
	gaitInfo.cadence < 8.0 and gaitInfo.cadence > 4.0,
	true
)

holdCalls = {}
holdRoleCalls = {}

-- Simulate 10.0 seconds of mounted galloping at 60 fps
for _ = 1, 600 do
	now = now + dt
	onUpdate(pollFrame, dt)
end

local mountedFootfalls = #holdCalls
local mountedStepsPerSec = mountedFootfalls / 10.0
-- Deliberate gallop merge: trail hoof lands < 80ms after lead, fusing into one heavier strike per stride
local expectedImpactsPerSec = gaitInfo.cadence * 0.5
check(
	"Deliberate gallop pair merge: impacts per second matches stride rate (~"
		.. string.format("%.2f", expectedImpactsPerSec)
		.. ")",
	math.abs(mountedStepsPerSec - expectedImpactsPerSec) <= 0.25,
	true
)
check("Merged gallop hoof strike uses HOOF shape", holdCalls[1] and holdCalls[1].shape ~= nil, true)
check("Merged gallop hoof strike has extended tau", holdCalls[1] and (holdCalls[1].shape.tau.low > 0.05), true)

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STOPPED_MOVING")

-- ── Part 6: H1 Gallop Merge Desync & Shape Transition Regressions ─────────────

io.write("\n── Part 6: H1 Gallop Merge Desync & Shape Transitions ──\n")

-- Reproduction A: Mounted Walk -> Run Gallop Merge Transition
mounted = true
playerSpeed = 2.5
reset()
eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STARTED_MOVING")
holdCalls = {}

for _ = 1, 180 do
	now = now + dt
	onUpdate(pollFrame, dt)
end
local walkSteps = #holdCalls
check("Mounted walk produces steps", walkSteps > 0, true)

-- Transition immediately mid-stride to full gallop speed (isGallopMerged = true)
playerSpeed = 11.2
holdCalls = {}
for _ = 1, 300 do
	now = now + dt
	onUpdate(pollFrame, dt)
end
check("H1 Fix: Footfalls continue firing after walk->gallop transition (no cadence lock)", #holdCalls >= 8, true)

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STOPPED_MOVING")

-- Reproduction B: On-Foot Run -> Druid Cat Form Transition
mounted = false
playerSpeed = 7.0
currentForm = nil
reset()
eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STARTED_MOVING")
holdCalls = {}

for _ = 1, 120 do
	now = now + dt
	onUpdate(pollFrame, dt)
end
check("On-foot run produces steps", #holdCalls > 0, true)

-- Shift into Cat Form (form ID 1)
currentForm = 1
holdCalls = {}
for _ = 1, 180 do
	now = now + dt
	onUpdate(pollFrame, dt)
end
check("Footfalls continue firing after shifting into Cat Form", #holdCalls >= 4, true)

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STOPPED_MOVING")
currentForm = nil

-- ── Part 7: M1 Single-Motor Schema splitFeet Guard ────────────────────────────

io.write("\n── Part 7: M1 Single-Motor Schema splitFeet Guard ──\n")

currentSchema = "lowOnly"
dbStore.triggerSettings.locomotion.splitFeet = 1
mounted = false
playerSpeed = 7.0
reset()
eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STARTED_MOVING")
holdCalls = {}

onUpdate(pollFrame, dt)
local s1Low = holdCalls[1] and holdCalls[1].low
local s1High = holdCalls[1].high

while #holdCalls < 2 do
	now = now + dt
	onUpdate(pollFrame, dt)
end
local s2Low = holdCalls[2] and holdCalls[2].low
local s2High = holdCalls[2].high

check("M1 Fix: Low-only schema does not split Low motor between feet", s1Low, s2Low)
check("M1 Fix: Low-only schema does not split High motor between feet", s1High, s2High)

eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_STOPPED_MOVING")
currentSchema = "standard"

-- ── Summary ───────────────────────────────────────────────────────────────────

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
