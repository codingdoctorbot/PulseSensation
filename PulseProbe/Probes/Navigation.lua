-- PulseProbe — Probes/Navigation.lua
--
-- Monitors native C_Navigation and C_SuperTrack distance vectors for couch/gamepad guidance.
-- Tests: Waypoint proximity Geiger cadence and arrival resolution chime.

local ADDON_NAME, Probe = ...

local Nav = {}
Probe.Navigation = Nav

local arrivalFired = false
local lastGeigerTickTime = 0

local function checkNavigationDistance()
	if not C_SuperTrack or not C_SuperTrack.IsSuperTrackingAnything or not C_SuperTrack.IsSuperTrackingAnything() then
		arrivalFired = false
		return
	end

	if not C_Navigation or not C_Navigation.GetDistance then
		return
	end

	local distance = C_Navigation.GetDistance()
	if not distance or issecretvalue(distance) or type(distance) ~= "number" then
		return
	end

	local now = GetTime()

	-- Arrival (< 5 yards)
	if distance < 5.0 and not arrivalFired then
		arrivalFired = true
		local payload = string.format("Arrived at Waypoint! (distance: %.1f yd)", distance)
		Probe:AddLogEntry("Navigation", "C_Navigation (Arrival)", payload, false, false, "waypointArrival")

	-- In proximity range (5 to 50 yards) -> Geiger cadence
	elseif distance >= 5.0 and distance <= 50.0 then
		arrivalFired = false

		-- Scale tick interval inversely with distance: 50yd -> 1.0s, 5yd -> 0.20s
		local interval = 0.20 + (distance / 50.0) * 0.80
		if now - lastGeigerTickTime >= interval then
			lastGeigerTickTime = now
			local payload = string.format("Distance: %.1f yd (Cadence: %.2fs)", distance, interval)
			Probe:AddLogEntry("Navigation", "C_Navigation (Geiger)", payload, false, false, "waypointGeigerTick")
		end
	elseif distance > 50.0 then
		arrivalFired = false
	end
end

function Nav:OnInit(_)
	-- Ticker runs at 10Hz (0.10s) to evaluate distance gates with zero GC garbage
	self.ticker = C_Timer.NewTicker(0.10, checkNavigationDistance)
end

function Nav:OnEnable()
	arrivalFired = false
end

Probe:RegisterProbe("Navigation", Nav)
