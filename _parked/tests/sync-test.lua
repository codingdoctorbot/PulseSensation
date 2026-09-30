-- Offline test suite for PulseSync (Profile Hub & Exporter)
-- Run from repo root: luajit PulseChecklist/tests/sync-test.lua

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
_G.bit = require("bit")

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
	function f:SetMovable(...) end
	function f:EnableMouse(...) end
	function f:RegisterForDrag(...) end
	function f:SetClampedToScreen(...) end
	function f:SetText(...) end
	function f:GetText()
		return ""
	end
	function f:HighlightText(...) end
	function f:SetFocus(...) end
	function f:SetAutoFocus(...) end
	function f:SetMultiLine(...) end
	function f:SetFontObject(...) end
	function f:SetScrollChild(...) end
	function f:CreateFontString(...)
		local fs = {
			SetPoint = function(...) end,
			SetText = function(...) end,
			SetWidth = function(...) end,
			SetJustifyH = function(...) end,
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

-- Stub Pulse & PulseDB
_G.PulseDB = {
	profiles = {
		["Default"] = {
			masterIntensity = 1.0,
			gates = { Combat = true, Locomotion = true },
			cues = { jump = { enabled = true, mode = "SNAP" } },
		},
	},
}

_G.PulseStudioDB = {
	customModes = {
		MY_BASS = { label = "Heavy Bass", baseDuration = 0.2 },
	},
}

_G.Pulse = {
	Database = {
		GetActiveProfileName = function()
			return "Default"
		end,
		SetActiveProfile = function(_, name)
			_G.PulseDB.activeProfile = name
		end,
		OnProfilesChanged = function() end,
	},
	Modes = {},
}

-- ── Load Addon Files ────────────────────────────────────────────────────────
local Sync = {}
local addonEnv = { "PulseSync", Sync }

local function loadFile(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error("Failed to load " .. path .. ": " .. tostring(err))
	end
	chunk(unpack(addonEnv))
end

loadFile("PulseSync/Serializer.lua")
loadFile("PulseSync/Core.lua")
loadFile("PulseSync/UI.lua")

-- ── Tests ───────────────────────────────────────────────────────────────────

-- Test 1: Base64 Encoding & Decoding
local s = Sync.Serializer
local rawText = "Hello World! World of Warcraft Forever Classic Beta"
local encoded = s:Base64Encode(rawText)
local decoded = s:Base64Decode(encoded)
check("Base64 encode/decode round trip", decoded, rawText)

-- Test 2: Checksum
local cs1 = s:Checksum("Alpha")
local cs2 = s:Checksum("Alpha")
local cs3 = s:Checksum("Beta")
check("Checksum deterministic", cs1, cs2)
check("Checksum sensitive to content", cs1 ~= cs3, true)

-- Test 3: Table Serialization & Deserialization
local sampleTable = {
	str = "Test String",
	num = 42.5,
	boolTrue = true,
	boolFalse = false,
	sub = { foo = "bar", count = 3 },
}

local syncString = s:Serialize(sampleTable)
check("Serialized string starts with !Pulse:1:", syncString:sub(1, 9), "!Pulse:1:")

local restored, err = s:Deserialize(syncString)
check("Deserialized without error", err, nil)
check("Restored string", restored.str, "Test String")
check("Restored number", restored.num, 42.5)
check("Restored boolean true", restored.boolTrue, true)
check("Restored boolean false", restored.boolFalse, false)
check("Restored nested table", restored.sub.foo, "bar")

-- Test 4: Corruption Check
local corrupted = syncString:sub(1, #syncString - 3) .. "fff"
local _, corErr = s:Deserialize(corrupted)
check("Checksum mismatch detected on corrupt string", type(corErr), "string")

-- Test 5: Profile Export
local expStr, expErr = Sync:ExportProfile("Default")
check("Export active profile succeeds", type(expStr), "string")
check("Export string contains header", expStr:sub(1, 9), "!Pulse:1:")

-- Test 6: Profile Import
local impOk, impName = Sync:ImportProfile(expStr, "ImportedTestProfile")
check("Import succeeds", impOk, true)
check("Imported profile stored in PulseDB", type(_G.PulseDB.profiles["ImportedTestProfile"]), "table")
check("Imported profile has masterIntensity", _G.PulseDB.profiles["ImportedTestProfile"].masterIntensity, 1.0)
check("Imported custom modes into Pulse.Modes", type(_G.Pulse.Modes["MY_BASS"]), "table")

-- Test 7: Curated Presets
local presOk, presName = Sync:InstallCuratedPreset("STEAM_DECK_ECO")
check("Install Steam Deck Eco preset", presOk, true)
check("Preset active profile set", _G.PulseDB.activeProfile, presName)

-- Test 8: UI Toggle
Sync:ToggleUI()
local sf = _G.PulseSyncFrame
check("PulseSyncFrame created", type(sf), "table")
check("PulseSyncFrame shown", sf:IsShown(), true)
Sync:ToggleUI()
check("PulseSyncFrame hidden", sf:IsShown(), false)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
os.exit(failures == 0 and 0 or 1)
