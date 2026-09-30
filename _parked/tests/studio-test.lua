-- Offline test suite for PulseStudio (Waveform Sequencer companion)
-- Run from repo root: luajit PulseChecklist/tests/studio-test.lua

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
	function f:ClearAllPoints()
		self.points = {}
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
	function f:GetName()
		return self.name or "MockStudioFrame"
	end
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
	function f:RegisterEvent(event) end
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
_G.tinsert = table.insert
_G.tremove = table.remove
_G.wipe = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

_G.C_Timer = {
	After = function(dur, fn)
		fn()
	end,
}

-- Stub PulseHaptics
local lastSetLayer, lastSetLow, lastSetHigh, lastSetDur = nil, nil, nil, nil
local stoppedLayer = nil

_G.Pulse = {
	Engine = {
		Set = function(_, layer, low, high, dur, isTrans)
			lastSetLayer = layer
			lastSetLow = low
			lastSetHigh = high
			lastSetDur = dur
		end,
		Stop = function(_, layer)
			stoppedLayer = layer
		end,
	},
	Modes = {
		BURST = {
			baseDuration = 0.05,
			steps = {
				{ role = "high", relIntensity = 0.95, relDuration = 0.8 },
				{ gap = 0.055 },
				{ role = "both", relIntensity = 0.80, relDuration = 0.8 },
			},
		},
	},
	ModeOrder = { "BURST" },
}

local function fireEvent(event, arg1)
	for _, f in ipairs(allFrames) do
		if f.scripts and f.scripts["OnEvent"] then
			f.scripts["OnEvent"](f, event, arg1)
		end
	end
end

-- ── Load PulseStudio ────────────────────────────────────────────────────────
local coreChunk = assert(loadfile("PulseStudio/Core.lua"))
local Studio = {}
coreChunk("PulseStudio", Studio)

local seqChunk = assert(loadfile("PulseStudio/Sequencer.lua"))
seqChunk("PulseStudio", Studio)

local uiChunk = assert(loadfile("PulseStudio/UI.lua"))
uiChunk("PulseStudio", Studio)

-- Initialize DB
fireEvent("ADDON_LOADED", "PulseStudio")
check("Studio global created", type(_G.PulseStudio), "table")
check("Studio DB initialized", type(Studio.db), "table")
check("Studio customModes initialized", type(Studio.db.customModes), "table")

-- Test 1: Sequencer block management
Studio:Clear()
check("Sequencer starts empty", #Studio.Blocks, 0)

local b1 = Studio:AddBlock("low", 0.0, 0.12, 0.75)
check("Added block 1", #Studio.Blocks, 1)
check("Block 1 role is low", b1.role, "low")
check("Block 1 intensity", b1.intensity, 0.75)

local b2 = Studio:AddBlock("high", 0.15, 0.08, 0.90)
check("Added block 2", #Studio.Blocks, 2)
check("Selected block is block 2", Studio.SelectedBlockID, b2.id)

Studio:UpdateSelectedBlock("intensity", 0.60)
check("Updated selected block intensity", b2.intensity, 0.60)

-- Test 2: Audition playback
local okPlay = Studio:PlaySequence(Studio.Blocks)
check("Studio:PlaySequence returns true", okPlay, true)
check("Engine received audition layer", lastSetLayer, "Studio_Audition")

Studio:Stop()
check("Studio:Stop stopped audition layer", stoppedLayer, "Studio_Audition")

-- Test 3: Export to Lua
local luaCode = Studio:ExportToLua("TEST_SLAM", "A test slam", Studio.Blocks)
check("Export contains mode name", luaCode:find("TEST_SLAM") ~= nil, true)
check("Export contains role low", luaCode:find('role = "low"') ~= nil, true)
check("Export contains role high", luaCode:find('role = "high"') ~= nil, true)

-- Test 4: Remix built-in mode
Studio:LoadBuiltin("BURST")
check("Remix BURST loaded blocks", #Studio.Blocks, 2)
check("Remix block 1 role is high", Studio.Blocks[1].role, "high")
check("Remix block 2 role is both", Studio.Blocks[2].role, "both")

-- Test 5: Save Custom Mode & Dynamic Pulse Injection
Studio:SaveCustomMode("EPIC_SHOCK", "Epic custom shockwave", Studio.Blocks, 0.10)
check("Saved to DB", type(Studio.db.customModes["EPIC_SHOCK"]), "table")
check("Injected into Pulse.Modes", type(_G.Pulse.Modes["EPIC_SHOCK"]), "table")
local foundInOrder = false
for _, id in ipairs(_G.Pulse.ModeOrder) do
	if id == "EPIC_SHOCK" then
		foundInOrder = true
		break
	end
end
check("Injected into Pulse.ModeOrder", foundInOrder, true)

-- Test 6: UI toggle
Studio:ToggleUI()
local sf = _G.PulseStudioFrame
check("PulseStudioFrame instantiated", type(sf), "table")
check("PulseStudioFrame shown", sf:IsShown(), true)
Studio:ToggleUI()
check("PulseStudioFrame hidden", sf:IsShown(), false)

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
os.exit(failures == 0 and 0 or 1)
