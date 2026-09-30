-- PulseCompass — Core.lua
--
-- Directional spatial haptics engine guiding players toward targets, corpses, or waypoints.
-- Feeds real-time stereo motor pulses into Pulse.Engine with zero Lua GC allocations.
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC), and Rule 5 (Taint Immunity).

local ADDON_NAME, Compass = ...
_G.PulseCompass = Compass

Compass.Name = ADDON_NAME
Compass.Version = "0.3.0-beta"

local PREFIX = "|cffff6600PulseCompass|r  "
local SUCCESS = "|cff44ff44"
local DANGER = "|cffff4444"
local RESET = "|r"

local function printMsg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. (msg or ""))
end

local DEFAULTS = {
	enabled = true,
	trackingMode = "AUTO", -- AUTO, WAYPOINT, CORPSE, TARGET
	intensity = 0.80,
	pulseDuration = 0.12,
	muteInCombat = true,
}

---------------------------------------------------------------------------
-- Initialization & SavedVariables
---------------------------------------------------------------------------

local compassFrame = CreateFrame("Frame")
compassFrame:RegisterEvent("ADDON_LOADED")
compassFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		if not _G.PulseCompassDB then
			_G.PulseCompassDB = {}
		end
		for k, v in pairs(DEFAULTS) do
			if _G.PulseCompassDB[k] == nil then
				_G.PulseCompassDB[k] = v
			end
		end
		Compass.db = _G.PulseCompassDB

		Compass:StartLoop()
		printMsg(SUCCESS .. "Tactile compass active." .. RESET .. " Type |cffffff00/pcompass|r for radar HUD.")
	end
end)

---------------------------------------------------------------------------
-- Real-Time Navigation Loop
---------------------------------------------------------------------------

local nextPingTime = 0
local lastArrived = false

local loopFrame = CreateFrame("Frame")

function Compass:StartLoop()
	loopFrame:SetScript("OnUpdate", function(_, elapsed)
		Compass:OnUpdateTick(elapsed)
	end)
end

function Compass:StopLoop()
	loopFrame:SetScript("OnUpdate", nil)
	if _G.Pulse and _G.Pulse.Engine then
		_G.Pulse.Engine:Stop("Compass_Radar")
	end
end

function Compass:OnUpdateTick(_)
	if not self.db or not self.db.enabled then
		return
	end
	if self.db.muteInCombat and InCombatLockdown() then
		return
	end

	local now = GetTime()
	if now < nextPingTime then
		return
	end

	local state = self.Radar:UpdateState(self.db.trackingMode or "AUTO", self.db.intensity or 0.8)
	if not state.hasTarget then
		nextPingTime = now + 1.0
		lastArrived = false
		return
	end

	if state.isArrived then
		if not lastArrived then
			-- Play celebratory destination reached transient
			if _G.Pulse and _G.Pulse.PlayMode then
				_G.Pulse:PlayMode("BURST", 1.0)
			end
			lastArrived = true
		end
		nextPingTime = now + 1.5
		return
	end

	lastArrived = false

	-- Dispatch tactile stereo ping
	if _G.Pulse and _G.Pulse.Engine then
		local dur = self.db.pulseDuration or 0.12
		_G.Pulse.Engine:Set("Compass_Radar", state.leftMotor, state.rightMotor, dur, true)
	end

	nextPingTime = now + state.pingInterval
end

---------------------------------------------------------------------------
-- Slash Commands
---------------------------------------------------------------------------

local function handleSlash(msg)
	local cmd = string.lower(strtrim(msg or ""))
	if cmd == "toggle" then
		Compass.db.enabled = not Compass.db.enabled
		printMsg(
			"Compass " .. (Compass.db.enabled and (SUCCESS .. "enabled" .. RESET) or (DANGER .. "disabled" .. RESET))
		)
	elseif cmd == "corpse" then
		Compass.db.trackingMode = "CORPSE"
		printMsg("Tracking mode set to |cffffff00CORPSE|r.")
	elseif cmd == "waypoint" then
		Compass.db.trackingMode = "WAYPOINT"
		printMsg("Tracking mode set to |cffffff00WAYPOINT|r.")
	elseif cmd == "target" then
		Compass.db.trackingMode = "TARGET"
		printMsg("Tracking mode set to |cffffff00TARGET|r.")
	elseif cmd == "auto" then
		Compass.db.trackingMode = "AUTO"
		printMsg("Tracking mode set to |cffffff00AUTO|r.")
	else
		Compass:ToggleUI()
	end
end

SLASH_PULSECOMPASS1 = "/pulsecompass"
SLASH_PULSECOMPASS2 = "/pcompass"
SlashCmdList["PULSECOMPASS"] = handleSlash
