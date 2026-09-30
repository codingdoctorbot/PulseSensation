-- Offline test suite for PulseCompass (Tactile Navigation Radar)
-- Run from repo root: luajit PulseChecklist/tests/compass-test.lua

local failures = 0
local function check(label, got, want)
	if got ~= want then
		failures = failures + 1
		io.write(("FAIL  %-50s got %s, wanted %s\n"):format(label, tostring(got), tostring(want)))
	else
		io.write(("ok    %s\n"):format(label))
	end
end

-- ── WoW Environment Stub ───────────────────────────────────────────────────
_G.DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, msg) end,
}
_G.UIParent = {}
_G.SlashCmdList = {}

local currentTime = 50.0
_G.GetTime = function()
	return currentTime
end

_G.InCombatLockdown = function()
	return false
end

_G.strtrim = function(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local allFrames = {}
_G.CreateFrame = function(frameType, name, parent, template)
	local f = {
		name = name,
		type = frameType,
		scripts = {},
		points = {},
		fontStrings = {},
		shown = false,
	}
	if name then
		_G[name] = f
	end
	table.insert(allFrames, f)
	function f:SetSize(w, h)
		self.w, self.h = w, h
	end
	function f:SetPoint(...)
		table.insert(self.points, { ... })
	end
	function f:SetBackdrop(...) end
	function f:SetBackdropColor(...) end
	function f:SetBackdropBorderColor(...) end
	function f:SetMovable(...) end
	function f:EnableMouse(...) end
	function f:RegisterForDrag(...) end
	function f:SetClampedToScreen(...) end
	function f:SetText(...) end
	function f:GetText()
		return ""
	end
	function f:SetChecked(val)
		self.checked = val
	end
	function f:GetChecked()
		return self.checked or false
	end
	function f:GetName()
		return self.name or "MockCompassFrame"
	end
	function f:CreateFontString(...)
		local fs = {
			SetPoint = function(...) end,
			SetText = function(...) end,
		}
		table.insert(self.fontStrings, fs)
		return fs
	end
	function f:RegisterEvent(event) end
	function f:SetScript(handler, fn)
		self.scripts[handler] = fn
	end
	function f:Show()
		self.shown = true
	end
	function f:Hide()
		self.shown = false
	end
	function f:IsShown()
		return self.shown
	end
	return f
end

-- Stub C_Map
local playerPos = { x = 0.50, y = 0.50 }
local waypointPos = { x = 0.60, y = 0.40 } -- North-East
local playerFacing = 0 -- Facing North

_G.GetPlayerFacing = function()
	return playerFacing
end

_G.UnitIsDeadOrGhost = function()
	return false
end

_G.UnitExists = function()
	return false
end

_G.C_Map = {
	GetBestMapForUnit = function()
		return 100
	end,
	GetPlayerMapPosition = function(_, unit)
		return {
			GetXY = function()
				return playerPos.x, playerPos.y
			end,
		}
	end,
	GetUserWaypoint = function()
		return {
			uiMapID = 100,
			position = {
				GetXY = function()
					return waypointPos.x, waypointPos.y
				end,
			},
		}
	end,
}

-- Stub Pulse
local lastLayerSet, lastLowSet, lastHighSet, lastDurSet = nil, nil, nil, nil
_G.Pulse = {
	PlayMode = function(_, mode) end,
	Engine = {
		Set = function(_, layer, low, high, dur, isTrans)
			lastLayerSet = layer
			lastLowSet = low
			lastHighSet = high
			lastDurSet = dur
		end,
		Stop = function(_, layer) end,
	},
}

-- ── Load Addon Files ────────────────────────────────────────────────────────
local Compass = {}
local addonEnv = { "PulseCompass", Compass }

local function loadFile(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error("Failed to load " .. path .. ": " .. tostring(err))
	end
	chunk(unpack(addonEnv))
end

loadFile("PulseCompass/Radar.lua")
loadFile("PulseCompass/Core.lua")
loadFile("PulseCompass/UI.lua")

-- ── Tests ───────────────────────────────────────────────────────────────────

-- Test 1: Bearing math
local r = Compass.Radar
-- North is 0. Target East (dx > 0, dy = 0) -> +90 deg
local bearingEast = r:CalculateBearing(0.5, 0.5, 0.6, 0.5, 0)
check("Bearing East is 90 deg", math.floor(bearingEast + 0.5), 90)

-- Target West (dx < 0, dy = 0) -> -90 deg
local bearingWest = r:CalculateBearing(0.5, 0.5, 0.4, 0.5, 0)
check("Bearing West is -90 deg", math.floor(bearingWest + 0.5), -90)

-- Target North (dx = 0, dy < 0) -> 0 deg (Ahead)
local bearingNorth = r:CalculateBearing(0.5, 0.5, 0.5, 0.4, 0)
check("Bearing North is 0 deg", math.floor(bearingNorth + 0.5), 0)

-- Test 2: Stereo motor calculation
local low, high, isAhead, isBehind = r:CalculateStereoMotors(0, 1.0)
check("Straight ahead isAhead flag", isAhead, true)
check("Straight ahead balanced stereo low", low, 0.45)
check("Straight ahead balanced stereo high", high, 0.45)

local lowL, highL = r:CalculateStereoMotors(-60, 1.0)
check("Target Left activates low motor predominantly", lowL > highL, true)

local lowR, highR = r:CalculateStereoMotors(60, 1.0)
check("Target Right activates high motor predominantly", highR > lowR, true)

-- Test 3: Ping intervals
local closeInterval = r:GetPingInterval(0.01)
local farInterval = r:GetPingInterval(0.50)
check("Close distance ping interval", closeInterval, 0.40)
check("Far distance ping interval", farInterval, 2.20)
check("Close interval is faster than far", closeInterval < farInterval, true)

-- Test 4: Radar State Update with mocked waypoint
local state = r:UpdateState("WAYPOINT", 1.0)
check("Radar detected waypoint", state.hasTarget, true)
check("Target type is WAYPOINT", state.targetType, "WAYPOINT")
check("Left and right motor calculated", state.leftMotor > 0 and state.rightMotor > 0, true)

-- Test 5: Real-time Navigation Update Tick
Compass.db = {
	enabled = true,
	trackingMode = "WAYPOINT",
	intensity = 0.85,
	pulseDuration = 0.12,
	muteInCombat = false,
}

currentTime = 100.0
lastLayerSet = nil
Compass:OnUpdateTick(0.1)
check("OnUpdateTick dispatched Compass_Radar layer", lastLayerSet, "Compass_Radar")
check("Duration passed to engine", lastDurSet, 0.12)
check("Low motor dispatched", type(lastLowSet), "number")
check("High motor dispatched", type(lastHighSet), "number")

-- Test 6: UI Toggle
Compass:ToggleUI()
local cf = _G.PulseCompassFrame
check("PulseCompassFrame created", type(cf), "table")
check("PulseCompassFrame shown", cf:IsShown(), true)
Compass:ToggleUI()
check("PulseCompassFrame hidden", cf:IsShown(), false)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
os.exit(failures == 0 and 0 or 1)
