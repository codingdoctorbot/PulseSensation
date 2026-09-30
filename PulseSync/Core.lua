-- PulseSync — Core.lua
--
-- Profile import, export, and community sharing engine for PulseHaptics.
-- Supports 1-click sharing of tactile tuning, category gates, and custom studio modes.
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC), and Rule 5 (Taint Immunity).

local ADDON_NAME, Sync = ...
_G.PulseSync = Sync

Sync.Name = ADDON_NAME
Sync.Version = "0.3.0-beta"

local PREFIX = "|cff00ffaaPulseSync|r  "
local SUCCESS = "|cff44ff44"
local DANGER = "|cffff4444"
local RESET = "|r"

local function printMsg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. (msg or ""))
end

---------------------------------------------------------------------------
-- Initialization & SavedVariables
---------------------------------------------------------------------------

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("ADDON_LOADED")
syncFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		if not _G.PulseSyncDB then
			_G.PulseSyncDB = {
				history = {},
			}
		end
		Sync.db = _G.PulseSyncDB
		printMsg(SUCCESS .. "Profile sync hub ready." .. RESET .. " Type |cffffff00/psync|r to share or import.")
	end
end)

---------------------------------------------------------------------------
-- Profile Export & Import
---------------------------------------------------------------------------

function Sync:ExportProfile(profileName)
	if not _G.Pulse or not _G.Pulse.Database then
		return nil, "PulseHaptics not loaded"
	end

	local db = _G.PulseDB
	if not db or not db.profiles then
		return nil, "No profiles found in PulseDB"
	end

	local targetName = profileName or _G.Pulse.Database:GetActiveProfileName()
	local profData = db.profiles[targetName]
	if not profData then
		return nil, "Profile '" .. tostring(targetName) .. "' does not exist"
	end

	-- Package export payload
	local payload = {
		name = targetName,
		version = Sync.Version,
		exportedAt = date and date("%Y-%m-%d %H:%M:%S") or "Unknown",
		profile = profData,
		customModes = {},
	}

	-- Include any custom studio modes associated with this profile
	if _G.PulseStudioDB and _G.PulseStudioDB.customModes then
		for modeID, modeDef in pairs(_G.PulseStudioDB.customModes) do
			payload.customModes[modeID] = modeDef
		end
	end

	return self.Serializer:Serialize(payload)
end

function Sync:ImportProfile(exportStr, customName)
	local payload, err = self.Serializer:Deserialize(exportStr)
	if not payload then
		return false, err or "Invalid sync string"
	end

	if not payload.profile then
		return false, "Missing profile data in payload"
	end

	if not _G.Pulse or not _G.PulseDB then
		return false, "PulseHaptics not loaded"
	end

	local targetName = customName or payload.name or "Imported Profile"
	-- Ensure unique name if collision
	if _G.PulseDB.profiles[targetName] and not customName then
		targetName = targetName .. " (Imported)"
	end

	_G.PulseDB.profiles[targetName] = payload.profile

	-- Import custom studio modes if present
	if payload.customModes and type(payload.customModes) == "table" then
		if not _G.PulseStudioDB then
			_G.PulseStudioDB = { customModes = {} }
		end
		_G.PulseStudioDB.customModes = _G.PulseStudioDB.customModes or {}
		for modeID, modeDef in pairs(payload.customModes) do
			_G.PulseStudioDB.customModes[modeID] = modeDef
			if _G.Pulse and _G.Pulse.Modes then
				_G.Pulse.Modes[modeID] = modeDef
			end
		end
	end

	-- Notify Pulse database of new profile
	if _G.Pulse.Database and _G.Pulse.Database.OnProfilesChanged then
		_G.Pulse.Database:OnProfilesChanged()
	end

	return true, targetName
end

---------------------------------------------------------------------------
-- Curated Community Presets
---------------------------------------------------------------------------

Sync.CURATED_PRESETS = {
	{
		id = "STEAM_DECK_ECO",
		title = "Steam Deck Battery Saver",
		desc = "Lowers continuous immersion draw while maintaining sharp tactile weapon & combat snaps. Adds ~40m battery.",
		author = "Pulse Team",
		profile = {
			masterIntensity = 0.85,
			gates = { Environment = false, Locomotion = true, Combat = true, Encounter = true },
		},
	},
	{
		id = "TACTICAL_RADAR",
		title = "Mythic+ Tactical Radar",
		desc = "Stripped of all ambient world noise. High-contrast alerts for crowd control, kicks, and incoming telegraphs.",
		author = "Pulse Team",
		profile = {
			masterIntensity = 1.0,
			gates = {
				Environment = false,
				World = false,
				Locomotion = false,
				Inventory = false,
				Combat = true,
				Encounter = true,
			},
		},
	},
	{
		id = "COZY_EXPLORATION",
		title = "Cozy World Immersion",
		desc = "Rich organic textures for footsteps, weather, harvesting, dialogue, and gentle mount gallop.",
		author = "Pulse Team",
		profile = {
			masterIntensity = 0.90,
			gates = {
				Environment = true,
				World = true,
				Locomotion = true,
				Inventory = true,
				Crafting = true,
				Combat = true,
			},
		},
	},
}

function Sync:InstallCuratedPreset(presetID)
	for _, p in ipairs(self.CURATED_PRESETS) do
		if p.id == presetID then
			if not _G.PulseDB or not _G.PulseDB.profiles then
				return false, "PulseHaptics not loaded"
			end
			local name = p.title
			_G.PulseDB.profiles[name] = p.profile
			if _G.Pulse and _G.Pulse.Database and _G.Pulse.Database.SetActiveProfile then
				_G.Pulse.Database:SetActiveProfile(name)
			end
			return true, name
		end
	end
	return false, "Preset not found"
end

---------------------------------------------------------------------------
-- Slash Commands
---------------------------------------------------------------------------

local function handleSlash(msg)
	local cmd = string.lower(strtrim(msg or ""))
	if cmd == "export" then
		local str, err = Sync:ExportProfile()
		if str then
			printMsg("Active profile exported:")
			printMsg(str)
		else
			printMsg(DANGER .. "Export failed: " .. tostring(err) .. RESET)
		end
	else
		Sync:ToggleUI()
	end
end

SLASH_PULSESYNC1 = "/pulsesync"
SLASH_PULSESYNC2 = "/psync"
SlashCmdList["PULSESYNC"] = handleSlash
