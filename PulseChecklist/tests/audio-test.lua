-- Offline test suite for PulseAudio (Earcon & Speaker Synthesizer)
-- Run from repo root: luajit PulseChecklist/tests/audio-test.lua

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
_G.SOUNDKIT = {
	IG_MAINMENU_OPTION_CHECKBOX_ON = 856,
	GLUE_CHARACTER_SELECT_ENTER_WORLD = 1115,
	RAID_WARNING = 8959,
}

local currentTime = 100.0
_G.GetTime = function()
	return currentTime
end

local inCombat = false
_G.InCombatLockdown = function()
	return inCombat
end

local lastPlayedSound = nil
local lastPlayedChannel = nil
_G.PlaySound = function(soundID, channel)
	lastPlayedSound = soundID
	lastPlayedChannel = channel
	return true
end

_G.CreateFrame = function(frameType, name, parent, template)
	local f = {
		name = name,
		type = frameType,
		scripts = {},
		points = {},
		fontStrings = {},
		buttons = {},
		shown = false,
	}
	if name then
		_G[name] = f
	end
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
	function f:SetChecked(val)
		self.checked = val
	end
	function f:GetChecked()
		return self.checked or false
	end
	function f:GetName()
		return self.name or "MockAudioFrame"
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

_G.hooksecurefunc = function(tbl, method, hookFn)
	local orig = tbl[method]
	tbl[method] = function(...)
		if orig then
			orig(...)
		end
		hookFn(...)
	end
end

_G.strtrim = function(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Stub Pulse
local pulseEngineCallbacks = {}
_G.Pulse = {
	PlayMode = function(self, modeName, scale) end,
	Engine = {
		Set = function(self, layer, low, high, dur, isTrans) end,
	},
}

-- ── Load Addon Files ────────────────────────────────────────────────────────
local Audio = {}
local addonEnv = { "PulseAudio", Audio }

local function loadFile(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error("Failed to load " .. path .. ": " .. tostring(err))
	end
	chunk(unpack(addonEnv))
end

loadFile("PulseAudio/SoundBank.lua")
loadFile("PulseAudio/Core.lua")
loadFile("PulseAudio/UI.lua")

-- ── Tests ───────────────────────────────────────────────────────────────────

-- Test 1: SoundBank lookup
local sb = Audio.SoundBank
check("SoundBank exists", type(sb), "table")
local clickSound = sb:GetSoundID("mechanical", "CLICK", "both")
check("Mechanical CLICK returns valid sound ID", type(clickSound), "number")

local subtleSound = sb:GetSoundID("subtle", "CLICK", "both")
check("Subtle CLICK returns sound ID", type(subtleSound), "number")

-- Test 2: Database and Initialization
Audio.db = {
	enabled = true,
	theme = "mechanical",
	channel = "Master",
	muteInCombat = false,
	throttle = 0.035,
}

-- Test 3: PlayTest
lastPlayedSound, lastPlayedChannel = nil, nil
local testOk = Audio:PlayTest("BURST")
check("PlayTest returned true", testOk, true)
check("PlaySound called", type(lastPlayedSound), "number")
check("Played on Master channel", lastPlayedChannel, "Master")

-- Test 4: Engine Hooking & Throttling
Audio:HookPulse()
currentTime = 200.0
lastPlayedSound = nil
_G.Pulse:PlayMode("KNOCK", 1.0)
check("Pulse:PlayMode triggered earcon", type(lastPlayedSound), "number")

-- Rapid fire within throttle interval should be dropped
lastPlayedSound = nil
currentTime = 200.010 -- 10ms later
_G.Pulse:PlayMode("KNOCK", 1.0)
check("Rapid fire earcon was throttled", lastPlayedSound, nil)

-- After throttle window, should play
currentTime = 200.050 -- 50ms later
_G.Pulse:PlayMode("KNOCK", 1.0)
check("Earcon played after throttle", type(lastPlayedSound), "number")

-- Test 5: Combat Lockdown Muting
Audio.db.muteInCombat = true
inCombat = true
lastPlayedSound = nil
currentTime = 300.0
_G.Pulse:PlayMode("BURST", 1.0)
check("Muted during combat lockdown", lastPlayedSound, nil)
inCombat = false

-- Test 6: UI Toggle
Audio:ToggleUI()
local af = _G.PulseAudioFrame
check("PulseAudioFrame created", type(af), "table")
check("PulseAudioFrame shown", af:IsShown(), true)
Audio:ToggleUI()
check("PulseAudioFrame hidden", af:IsShown(), false)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
os.exit(failures == 0 and 0 or 1)
