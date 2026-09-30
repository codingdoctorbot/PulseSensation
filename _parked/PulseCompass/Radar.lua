-- PulseCompass — Radar.lua
--
-- Directional spatial calculation engine and stereo motor panning synthesizer.
-- Converts relative navigation angles and distances into intuitive dual-motor pulses.
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC), and Rule 5 (Taint Immunity).

local _, Compass = ...

Compass.Radar = {}
local Radar = Compass.Radar

local PI = math.pi
local TWO_PI = math.pi * 2
local RAD_TO_DEG = 180 / math.pi

-- Pre-allocated state table for zero-GC calculation loop (Rule 4)
local radarState = {
	hasTarget = false,
	targetType = "NONE",
	distance = 0,
	relAngleDeg = 0,
	leftMotor = 0,
	rightMotor = 0,
	pingInterval = 1.0,
	isAhead = false,
	isArrived = false,
}

---------------------------------------------------------------------------
-- Angle & Spatial Math
---------------------------------------------------------------------------

--- Normalizes an angle into [-PI, PI] range.
local function normalizeRad(rad)
	while rad > PI do
		rad = rad - TWO_PI
	end
	while rad < -PI do
		rad = rad + TWO_PI
	end
	return rad
end

--- Calculates relative angle in degrees between player heading and target.
-- Negative degrees: Target is to the LEFT.
-- Positive degrees: Target is to the RIGHT.
-- Near 0: Target is STRAIGHT AHEAD.
function Radar:CalculateBearing(px, py, tx, ty, playerFacing)
	local dx = tx - px
	local dy = ty - py

	-- In WoW 2D map space: +X is East, +Y is South.
	-- Angle from player to target (0 rad is North, PI/2 is East, PI is South, 3PI/2 is West)
	-- math.atan2(dx, -dy) gives 0 at North, PI/2 at East, -PI/2 at West.
	local targetAngle = math.atan2(dx, -dy)
	if targetAngle < 0 then
		targetAngle = targetAngle + TWO_PI
	end

	-- WoW GetPlayerFacing returns radians: 0 at North, increasing counter-clockwise or clockwise
	local facing = playerFacing or 0

	local delta = normalizeRad(targetAngle - facing)
	return delta * RAD_TO_DEG
end

--- Maps relative angle [-180, 180] to stereo motor intensities.
-- Left motor (Low frequency) activates when target is on left.
-- Right motor (High frequency) activates when target is on right.
-- Straight ahead triggers balanced harmonious stereo feedback.
function Radar:CalculateStereoMotors(relAngleDeg, masterIntensity)
	local intensity = masterIntensity or 1.0
	local absAngle = math.abs(relAngleDeg)

	if absAngle <= 18 then
		-- Straight ahead: Balanced stereo lock-on
		return 0.45 * intensity, 0.45 * intensity, true, false
	elseif absAngle >= 150 then
		-- Directly behind: Urgent alert thud
		return 0.70 * intensity, 0.70 * intensity, false, true
	end

	local norm = math.min(1.0, absAngle / 80.0) * intensity
	if relAngleDeg < 0 then
		-- Target to Left -> Left motor dominant
		local low = norm
		local high = norm * 0.15
		return low, high, false, false
	else
		-- Target to Right -> Right motor dominant
		local low = norm * 0.15
		local high = norm
		return low, high, false, false
	end
end

--- Calculates dynamic ping rhythm based on distance to waypoint.
function Radar:GetPingInterval(dist)
	if dist <= 0.005 then
		return 0.25 -- Arrived
	elseif dist < 0.03 then
		return 0.40 -- Very close (< 50 yd)
	elseif dist < 0.08 then
		return 0.80 -- Medium range (< 150 yd)
	elseif dist < 0.20 then
		return 1.40 -- Long range (< 300 yd)
	else
		return 2.20 -- Distant (> 500 yd)
	end
end

---------------------------------------------------------------------------
-- Target Coordinate Provider
---------------------------------------------------------------------------

function Radar:UpdateState(trackingMode, masterIntensity)
	radarState.hasTarget = false
	radarState.distance = 0
	radarState.leftMotor = 0
	radarState.rightMotor = 0
	radarState.isAhead = false
	radarState.isArrived = false

	if not C_Map then
		return radarState
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then
		return radarState
	end

	local pPos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pPos then
		return radarState
	end

	local px, py = pPos:GetXY()
	if not px or not py then
		return radarState
	end

	local tx, ty = nil, nil
	local targetFound = false

	-- Mode 1: Corpse navigation
	if trackingMode == "CORPSE" or (trackingMode == "AUTO" and UnitIsDeadOrGhost("player")) then
		local cPos = (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition) and C_DeathInfo.GetCorpseMapPosition()
		if cPos then
			tx, ty = cPos:GetXY()
			targetFound = true
			radarState.targetType = "CORPSE"
		end
	end

	-- Mode 2: User map waypoint
	if not targetFound and (trackingMode == "WAYPOINT" or trackingMode == "AUTO") then
		local wp = C_Map.GetUserWaypoint()
		if wp and wp.uiMapID == mapID and wp.position then
			tx, ty = wp.position:GetXY()
			targetFound = true
			radarState.targetType = "WAYPOINT"
		end
	end

	-- Mode 3: Target unit (if on same map)
	if not targetFound and (trackingMode == "TARGET" or trackingMode == "AUTO") and UnitExists("target") then
		local tPos = C_Map.GetPlayerMapPosition(mapID, "target")
		if tPos then
			tx, ty = tPos:GetXY()
			targetFound = true
			radarState.targetType = "TARGET"
		end
	end

	if not targetFound or not tx or not ty then
		return radarState
	end

	local dx = tx - px
	local dy = ty - py
	local dist = math.sqrt(dx * dx + dy * dy)
	local facing = GetPlayerFacing() or 0

	local relAngle = self:CalculateBearing(px, py, tx, ty, facing)
	local low, high, isAhead, isBehind = self:CalculateStereoMotors(relAngle, masterIntensity)

	radarState.hasTarget = true
	radarState.distance = dist
	radarState.relAngleDeg = relAngle
	radarState.leftMotor = low
	radarState.rightMotor = high
	radarState.isAhead = isAhead
	radarState.isBehind = isBehind
	radarState.isArrived = (dist <= 0.005)
	radarState.pingInterval = self:GetPingInterval(dist)

	return radarState
end
