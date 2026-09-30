-- Offline test suite for PulseBridge (WeakAuras & BossMod Hook companion)
-- Run from repo root: luajit PulseChecklist/tests/bridge-test.lua

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

local frameScripts = {}
local registeredEvents = {}
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
	function f:SetBackdropBorderColor(...) end
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
	function f:SetMinMaxValues(...) end
	function f:SetValueStep(...) end
	function f:SetObeyStepOnDrag(...) end
	function f:SetValue(...) end
	function f:SetChecked(val)
		self.checked = val
	end
	function f:GetChecked()
		return self.checked or false
	end
	function f:GetName()
		return self.name or "MockFrame"
	end
	allFrames = allFrames or {}
	table.insert(allFrames, f)
	function f:CreateFontString(...)
		local fs = {
			SetPoint = function(...) end,
			SetText = function(...) end,
		}
		table.insert(self.fontStrings, fs)
		return fs
	end
	function f:CreateLine(...)
		return {
			SetColorTexture = function(...) end,
			SetStartPoint = function(...) end,
			SetEndPoint = function(...) end,
			SetThickness = function(...) end,
		}
	end
	function f:RegisterEvent(event)
		registeredEvents[event] = true
	end
	function f:SetScript(handler, fn)
		self.scripts[handler] = fn
	end
	function f:Show()
		self.shown = true
		if self.scripts["OnShow"] then
			self.scripts["OnShow"](self)
		end
	end
	function f:Hide()
		self.shown = false
	end
	function f:IsShown()
		return self.shown
	end
	return f
end

_G.strtrim = function(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end
_G.strsplit = function(delim, str)
	local pos = 1
	local res = {}
	while true do
		local first, last = string.find(str, delim, pos, true)
		if not first then
			table.insert(res, string.sub(str, pos))
			break
		end
		table.insert(res, string.sub(str, pos, first - 1))
		pos = last + 1
	end
	return unpack(res)
end

-- Stub PulseHaptics
local lastModePlayed, lastScalePlayed, lastLayerPlayed = nil, nil, nil
local lastLow, lastHigh, lastDur = nil, nil, nil
local stoppedLayer = nil

_G.Pulse = {
	Engine = {
		PlayMode = function(_, layer, modeID, scale)
			lastLayerPlayed = layer
			lastModePlayed = modeID
			lastScalePlayed = scale
		end,
		Set = function(_, layer, low, high, dur, isTrans)
			lastLayerPlayed = layer
			lastLow = low
			lastHigh = high
			lastDur = dur
		end,
		Stop = function(_, layer)
			stoppedLayer = layer
		end,
	},
	Arbiter = {
		RecordEvent = function(_, category, event) end,
	},
}

-- ── Load PulseBridge ────────────────────────────────────────────────────────
local bridgeChunk = assert(loadfile("PulseBridge/Core.lua"))
local Bridge = {}
bridgeChunk("PulseBridge", Bridge)

local waChunk = assert(loadfile("PulseBridge/WeakAuras.lua"))
waChunk("PulseBridge", Bridge)

local bossChunk = assert(loadfile("PulseBridge/BossMods.lua"))
bossChunk("PulseBridge", Bridge)

local uiChunk = assert(loadfile("PulseBridge/UI.lua"))
uiChunk("PulseBridge", Bridge)

local function fireEvent(event, arg1, arg2)
	for _, f in ipairs(allFrames or {}) do
		if f.scripts and f.scripts["OnEvent"] then
			f.scripts["OnEvent"](f, event, arg1, arg2)
		end
	end
end

-- ── Run Unit Verification ───────────────────────────────────────────────────
check("Bridge global created", type(_G.PulseBridge), "table")
check("Bridge reports connected", Bridge:IsConnected(), true)

-- Trigger ADDON_LOADED to initialize DB
fireEvent("ADDON_LOADED", "PulseBridge")
check("Bridge DB initialized", type(Bridge.db), "table")
check("Bridge default enabled", Bridge.db.enabled, true)

-- Test 1: Play mode through Bridge
local ok = Bridge:Play("BURST", 1.2)
check("Bridge:Play returns true", ok, true)
check("Engine received BURST", lastModePlayed, "BURST")
check("Engine received scale 1.2", math.abs(lastScalePlayed - 1.2) < 0.001, true)

-- Test 2: Vibrate direct
Bridge:Vibrate(0.4, 0.8, 0.15, true)
check("Direct Low set", lastLow, 0.4)
check("Direct High set", lastHigh, 0.8)
check("Direct Dur set", lastDur, 0.15)

-- Test 3: Stop
Bridge:Stop("CustomLayer")
check("Layer stopped", stoppedLayer, "CustomLayer")

-- Test 4: WeakAuras Bridge
_G.WeakAuras = {}
fireEvent("PLAYER_LOGIN")
check("WeakAuras helper injected", type(_G.WeakAurasPulse), "function")

_G.WeakAurasPulse("HEAVY", 1.5)
check("WeakAurasPulse triggers HEAVY", lastModePlayed, "HEAVY")
check("WeakAuras layer is PB_WA", lastLayerPlayed, "PB_WA")

-- Test 5: Slash Command /pb play
SlashCmdList["PULSEBRIDGE"]("play DEFLECT 0.9")
check("Slash command played DEFLECT", lastModePlayed, "DEFLECT")

-- Test 6: UI toggle
Bridge:ToggleUI()
local ui = _G.PulseBridgeFrame
check("PulseBridgeFrame instantiated", type(ui), "table")
check("PulseBridgeFrame shown", ui:IsShown(), true)
Bridge:ToggleUI()
check("PulseBridgeFrame hidden", ui:IsShown(), false)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
os.exit(failures == 0 and 0 or 1)
