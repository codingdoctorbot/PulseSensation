-- PulseStudio — Core.lua
--
-- Core haptic synthesizer, sequencer manager, and dynamic mode registration bridge.
-- Built for World of Warcraft Forever (_classic_beta_, Interface 120100/110200).
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC in tight loops), and Rule 5 (Taint Immunity).

local ADDON_NAME, Studio = ...
_G.PulseStudio = Studio

Studio.Name = ADDON_NAME
Studio.Version = "0.3.2-beta"

local PREFIX = "|cffffaa00PulseStudio|r  "
local SUCCESS = "|cff44ff44"
local DANGER = "|cffff4444"
local RESET = "|r"

local function printMsg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. (msg or ""))
end

---------------------------------------------------------------------------
-- SavedVariables & Dynamic Injection
---------------------------------------------------------------------------

local studioFrame = CreateFrame("Frame")
studioFrame:RegisterEvent("ADDON_LOADED")
studioFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		if not _G.PulseStudioDB then
			_G.PulseStudioDB = {}
		end
		if not _G.PulseStudioDB.customModes then
			_G.PulseStudioDB.customModes = {}
		end
		Studio.db = _G.PulseStudioDB

		-- Inject saved custom modes into Pulse.Modes so PulseHaptics can use them anywhere
		Studio:RegisterSavedModesIntoPulse()
		printMsg(SUCCESS .. "Studio engine ready." .. RESET .. " Type |cffffff00/studio|r to compose waveforms.")
	end
end)

---------------------------------------------------------------------------
-- Dynamic Mode Registration
---------------------------------------------------------------------------

function Studio:RegisterSavedModesIntoPulse()
	if not _G.Pulse or not _G.Pulse.Modes or not self.db then
		return
	end

	for modeID, modeDef in pairs(self.db.customModes) do
		if modeDef and modeDef.steps then
			_G.Pulse.Modes[modeID] = modeDef
			local found = false
			for _, id in ipairs(_G.Pulse.ModeOrder) do
				if id == modeID then
					found = true
					break
				end
			end
			if not found then
				tinsert(_G.Pulse.ModeOrder, modeID)
			end
		end
	end
end

function Studio:SaveCustomMode(modeID, label, steps, baseDuration)
	if not modeID or modeID == "" then
		return false, "Mode ID cannot be empty"
	end
	modeID = string.upper(modeID)

	local def = {
		label = label or ("Custom mode: " .. modeID),
		baseDuration = baseDuration or 0.10,
		steps = steps,
		isStudioCustom = true,
	}

	self.db.customModes[modeID] = def
	if _G.Pulse and _G.Pulse.Modes then
		_G.Pulse.Modes[modeID] = def
		local found = false
		for _, id in ipairs(_G.Pulse.ModeOrder) do
			if id == modeID then
				found = true
				break
			end
		end
		if not found then
			tinsert(_G.Pulse.ModeOrder, modeID)
		end
	end
	return true
end

---------------------------------------------------------------------------
-- Real-Time Audition & Playback Scheduling
---------------------------------------------------------------------------

local playbackToken = 0

function Studio:PlaySequence(blocks)
	if not _G.Pulse or not _G.Pulse.Engine then
		printMsg(DANGER .. "Cannot audition: PulseHaptics engine not found." .. RESET)
		return false
	end

	playbackToken = playbackToken + 1
	local token = playbackToken
	local engine = _G.Pulse.Engine

	if not blocks or #blocks == 0 then
		return false
	end

	for _, block in ipairs(blocks) do
		local at = block.start or 0.0
		local dur = block.duration or 0.1
		local mag = block.intensity or 1.0
		local role = block.role or "both"

		local low, high = 0, 0
		if role == "low" then
			low = mag
		elseif role == "high" then
			high = mag
		else
			low = mag
			high = mag
		end

		if at <= 0.001 then
			engine:Set("Studio_Audition", low, high, dur, true)
		else
			C_Timer.After(at, function()
				if token ~= playbackToken then
					return
				end
				engine:Set("Studio_Audition", low, high, dur, true)
			end)
		end
	end
	return true
end

function Studio:Stop()
	playbackToken = playbackToken + 1
	if _G.Pulse and _G.Pulse.Engine then
		_G.Pulse.Engine:Stop("Studio_Audition")
	end
end

---------------------------------------------------------------------------
-- Lua Code Serialization
---------------------------------------------------------------------------

function Studio:ExportToLua(modeID, label, blocks)
	modeID = (modeID and modeID ~= "") and string.upper(modeID) or "CUSTOM_PULSE"
	label = label or "Authored in PulseStudio."

	-- Sort blocks by start time
	local sorted = {}
	for _, b in ipairs(blocks) do
		tinsert(sorted, { start = b.start, duration = b.duration, intensity = b.intensity, role = b.role })
	end
	table.sort(sorted, function(a, b)
		return a.start < b.start
	end)

	local lua = string.format('Pulse.Modes["%s"] = {\n', modeID)
	lua = lua .. string.format('    label = "%s",\n', label)
	lua = lua .. "    baseDuration = 0.10,\n"
	lua = lua .. "    steps = {\n"

	local curTime = 0.0
	for _, b in ipairs(sorted) do
		local gap = b.start - curTime
		if gap > 0.005 then
			lua = lua .. string.format("        { gap = %.3f },\n", gap)
		end
		local relDur = b.duration / 0.10
		lua = lua
			.. string.format(
				'        { role = "%s", relIntensity = %.2f, relDuration = %.2f },\n',
				b.role,
				b.intensity,
				relDur
			)
		curTime = b.start + b.duration
	end

	lua = lua .. "    },\n}"
	return lua
end

---------------------------------------------------------------------------
-- Slash Commands
---------------------------------------------------------------------------

local function handleSlash(input)
	local cmd = input and strtrim(string.lower(input)) or ""
	if cmd == "stop" then
		Studio:Stop()
		printMsg("Audition stopped.")
	else
		if Studio.ToggleUI then
			Studio:ToggleUI()
		else
			printMsg("Type |cffffff00/studio|r to open the haptic waveform composer.")
		end
	end
end

_G.SLASH_PULSESTUDIO1 = "/pulsestudio"
_G.SLASH_PULSESTUDIO2 = "/studio"
SlashCmdList["PULSESTUDIO"] = handleSlash
