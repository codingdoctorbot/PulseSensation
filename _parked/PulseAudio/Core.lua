-- PulseAudio — Core.lua
--
-- Acoustic earcon synthesizer translating tactile haptic impulses into audible feedback.
-- Hooks into Pulse's mode and engine execution paths without taint.
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC), and Rule 5 (Taint Immunity).

local ADDON_NAME, Audio = ...
_G.PulseAudio = Audio

Audio.Name = ADDON_NAME
Audio.Version = "0.3.1-beta"

local PREFIX = "|cff33ccffPulseAudio|r  "
local SUCCESS = "|cff44ff44"
local DANGER = "|cffff4444"
local RESET = "|r"

local function printMsg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. (msg or ""))
end

local DEFAULTS = {
	enabled = true,
	theme = "mechanical",
	channel = "Master",
	muteInCombat = false,
	throttle = 0.035, -- 35ms cooldown between audio earcons to prevent sound clutter
}

---------------------------------------------------------------------------
-- Initialization & SavedVariables
---------------------------------------------------------------------------

local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		if not _G.PulseAudioDB then
			_G.PulseAudioDB = {}
		end
		for k, v in pairs(DEFAULTS) do
			if _G.PulseAudioDB[k] == nil then
				_G.PulseAudioDB[k] = v
			end
		end
		Audio.db = _G.PulseAudioDB

		Audio:HookPulse()
		printMsg(SUCCESS .. "Earcon synthesizer active." .. RESET .. " Type |cffffff00/paudio|r for settings.")
	end
end)

---------------------------------------------------------------------------
-- Pulse Engine Hooking (Zero Taint)
---------------------------------------------------------------------------

local isHooked = false
local lastSoundTime = 0

function Audio:HookPulse()
	if isHooked then
		return
	end
	if not _G.Pulse then
		return
	end

	-- Hook PlayMode (high-level tactile modes)
	if type(_G.Pulse.PlayMode) == "function" then
		hooksecurefunc(_G.Pulse, "PlayMode", function(_, modeName, scale)
			Audio:OnModePlayed(modeName, scale)
		end)
		isHooked = true
	end

	-- Hook Engine:Set (low-level motor events, for direct haptics / footsteps)
	if _G.Pulse.Engine and type(_G.Pulse.Engine.Set) == "function" then
		hooksecurefunc(_G.Pulse.Engine, "Set", function(_, layerName, low, high, duration, isTransient)
			Audio:OnEngineSet(layerName, low, high, duration, isTransient)
		end)
		isHooked = true
	end
end

function Audio:OnModePlayed(modeName, scale)
	if not self.db or not self.db.enabled then
		return
	end
	if self.db.muteInCombat and InCombatLockdown() then
		return
	end

	local now = GetTime()
	if (now - lastSoundTime) < (self.db.throttle or 0.035) then
		return
	end

	local soundID = self.SoundBank:GetSoundID(self.db.theme, modeName, "both")
	if soundID then
		pcall(PlaySound, soundID, self.db.channel or "Master")
		lastSoundTime = now
	end
end

function Audio:OnEngineSet(layerName, low, high, _, isTransient)
	if not self.db or not self.db.enabled then
		return
	end
	if not isTransient then
		return -- Ignore continuous hums/textures to prevent constant sound spam
	end
	if self.db.muteInCombat and InCombatLockdown() then
		return
	end

	local now = GetTime()
	if (now - lastSoundTime) < (self.db.throttle or 0.035) then
		return
	end

	local role = ((low or 0) > (high or 0)) and "low" or "high"
	local soundID = self.SoundBank:GetSoundID(self.db.theme, nil, role)
	if soundID then
		pcall(PlaySound, soundID, self.db.channel or "Master")
		lastSoundTime = now
	end
end

function Audio:PlayTest(modeName)
	local soundID = self.SoundBank:GetSoundID(self.db.theme, modeName or "BURST", "both")
	if soundID then
		pcall(PlaySound, soundID, self.db.channel or "Master")
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Slash Commands
---------------------------------------------------------------------------

local function handleSlash(msg)
	local cmd = string.lower(strtrim(msg or ""))
	if cmd == "test" then
		Audio:PlayTest("BURST")
		printMsg("Played test earcon.")
	elseif cmd == "toggle" then
		Audio.db.enabled = not Audio.db.enabled
		printMsg(
			"Synthesizer " .. (Audio.db.enabled and (SUCCESS .. "enabled" .. RESET) or (DANGER .. "disabled" .. RESET))
		)
	else
		Audio:ToggleUI()
	end
end

SLASH_PULSEAUDIO1 = "/pulseaudio"
SLASH_PULSEAUDIO2 = "/paudio"
SlashCmdList["PULSEAUDIO"] = handleSlash
