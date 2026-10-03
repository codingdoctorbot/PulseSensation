-- PulseBridge — Core.lua
--
-- Direct haptic dispatcher connecting WeakAuras, BigWigs, DBM, and custom macros to PulseHaptics.
-- Built for World of Warcraft Forever (_classic_beta_, Interface 120100/110200).
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC in tight loops), and Rule 5 (Taint Immunity).

local ADDON_NAME, Bridge = ...
_G.PulseBridge = Bridge

Bridge.Name = ADDON_NAME
Bridge.Version = "0.3.2-beta"

local PREFIX = "|cff00ffccPulseBridge|r  "
local SUCCESS = "|cff44ff44"
local DANGER = "|cffff4444"
local WARN = "|cffffcc00"
local RESET = "|r"

-- Default settings schema
local DB_DEFAULTS = {
	enabled = true,
	globalScale = 1.0,
	weakaurasEnabled = true,
	bigwigsEnabled = true,
	dbmEnabled = true,
	macroPrefix = "PB_",
}

local function printMsg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. (msg or ""))
end

---------------------------------------------------------------------------
-- Lifecycle & SavedVariables
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		if not _G.PulseBridgeDB then
			_G.PulseBridgeDB = {}
		end
		for k, v in pairs(DB_DEFAULTS) do
			if _G.PulseBridgeDB[k] == nil then
				_G.PulseBridgeDB[k] = v
			end
		end
		Bridge.db = _G.PulseBridgeDB

		-- Announce presence cleanly
		if Bridge:IsConnected() then
			printMsg(SUCCESS .. "Connected to PulseHaptics engine." .. RESET .. " Type |cffffff00/pb|r for settings.")
		else
			printMsg(WARN .. "PulseHaptics not yet detected. Waiting for engine..." .. RESET)
		end
	end
end)

---------------------------------------------------------------------------
-- Engine Detection & Status
---------------------------------------------------------------------------

function Bridge:IsConnected()
	return _G.Pulse and _G.Pulse.Engine and true or false
end

function Bridge:GetEngine()
	if _G.Pulse and _G.Pulse.Engine then
		return _G.Pulse.Engine
	end
	return nil
end

---------------------------------------------------------------------------
-- Public Dispatcher API (Zero Taint)
---------------------------------------------------------------------------

--- Plays a named vibration mode through Pulse's engine.
-- @param modeID string Mode identifier (e.g. "BURST", "HEAVY", "PULSE_BEAT", "CLICK")
-- @param scale number Optional intensity multiplier (default 1.0)
-- @param layerName string Optional unique layer identifier (default "PB_Custom")
-- @return boolean true on successful dispatch, false otherwise
function Bridge:Play(modeID, scale, layerName)
	if not self.db or not self.db.enabled then
		return false
	end

	local engine = self:GetEngine()
	if not engine or not engine.PlayMode then
		return false
	end

	modeID = modeID or "BURST"
	local mult = (scale or 1.0) * (self.db.globalScale or 1.0)
	local layer = layerName or "PB_Alert"

	-- Route through Pulse arbitration bus if active
	if _G.Pulse and _G.Pulse.Arbiter and _G.Pulse.Arbiter.RecordEvent then
		_G.Pulse.Arbiter:RecordEvent("Bridge", modeID)
	end

	engine:PlayMode(layer, modeID, mult)
	return true
end

--- Direct low-level dual-motor vibration trigger.
-- @param low number Low motor magnitude (0.0 to 1.0)
-- @param high number High motor magnitude (0.0 to 1.0)
-- @param duration number Duration in seconds
-- @param isTransient boolean Whether to treat as sharp impact (fast attack)
-- @param layerName string Optional unique layer name
function Bridge:Vibrate(low, high, duration, isTransient, layerName)
	if not self.db or not self.db.enabled then
		return false
	end

	local engine = self:GetEngine()
	if not engine or not engine.Set then
		return false
	end

	local mult = self.db.globalScale or 1.0
	local layer = layerName or "PB_Direct"
	engine:Set(layer, (low or 0) * mult, (high or 0) * mult, duration or 0.1, isTransient == true)
	return true
end

--- Stops a currently playing bridge layer.
-- @param layerName string The layer name passed to Play or Vibrate
function Bridge:Stop(layerName)
	local engine = self:GetEngine()
	if engine and engine.Stop then
		engine:Stop(layerName or "PB_Alert")
		engine:Stop(layerName or "PB_Direct")
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Slash Command Interface (/pb, /pulsebridge)
---------------------------------------------------------------------------

local function handleSlash(input)
	local arg1, arg2, arg3 = strsplit(" ", strtrim(input or ""))
	arg1 = arg1 and string.lower(arg1) or ""

	if arg1 == "play" and arg2 and arg2 ~= "" then
		local mode = string.upper(arg2)
		local scale = tonumber(arg3) or 1.0
		local ok = Bridge:Play(mode, scale, "PB_Macro")
		if ok then
			printMsg("Playing mode: |cffffff00" .. mode .. "|r (scale: " .. scale .. ")")
		else
			printMsg(DANGER .. "Failed to play mode: " .. mode .. RESET)
		end
	elseif arg1 == "stop" then
		Bridge:Stop("PB_Macro")
		Bridge:Stop("PB_Alert")
		Bridge:Stop("PB_Direct")
		printMsg("Stopped bridge vibrations.")
	elseif arg1 == "scale" and arg2 and arg2 ~= "" then
		local s = tonumber(arg2)
		if s and s >= 0 and s <= 2.0 then
			Bridge.db.globalScale = s
			printMsg("Global Bridge Scale set to |cffffff00" .. string.format("%.2f", s) .. "|r")
		else
			printMsg(WARN .. "Usage: /pb scale [0.0 - 2.0]" .. RESET)
		end
	elseif arg1 == "status" then
		printMsg("=== Status Report ===")
		printMsg(
			"  Engine: "
				.. (Bridge:IsConnected() and (SUCCESS .. "Connected" .. RESET) or (DANGER .. "Disconnected" .. RESET))
		)
		printMsg(
			"  WeakAuras Hook: "
				.. (Bridge.HasWeakAuras and (SUCCESS .. "Active" .. RESET) or (WARN .. "Inactive" .. RESET))
		)
		printMsg(
			"  BigWigs Hook: "
				.. (Bridge.HasBigWigs and (SUCCESS .. "Active" .. RESET) or (WARN .. "Inactive" .. RESET))
		)
		printMsg("  DBM Hook: " .. (Bridge.HasDBM and (SUCCESS .. "Active" .. RESET) or (WARN .. "Inactive" .. RESET)))
		printMsg("  Global Scale: " .. string.format("%.2f", Bridge.db and Bridge.db.globalScale or 1.0))
	else
		-- Toggle UI window
		if Bridge.ToggleUI then
			Bridge:ToggleUI()
		else
			printMsg(
				"Commands: |cffffff00/pb play <MODE> [scale]|r | |cffffff00/pb stop|r | |cffffff00/pb scale <num>|r | |cffffff00/pb status|r"
			)
		end
	end
end

_G.SLASH_PULSEBRIDGE1 = "/pulsebridge"
_G.SLASH_PULSEBRIDGE2 = "/pb"
SlashCmdList["PULSEBRIDGE"] = handleSlash
