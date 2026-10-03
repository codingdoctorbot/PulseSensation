-- PulseDebug — Oscilloscope.lua
--
-- Real-time graphic waveform monitor for gamepad haptics in World of Warcraft.
-- Visualizes dynamic motor output (Low LF motor, High HF motor, triggers) over a rolling
-- time window with zero Lua garbage generation in the sampling and rendering loop.
--
-- Features:
-- 1. Dual-Trace Visualization:
--    - Split Dual-Beam mode: High motor on top, Low motor on bottom (lab scope style).
--    - Overlaid mode: Both motors share the full 0.0 to 1.0 vertical scale.
-- 2. Rolling Time Buffer:
--    - 60 discrete time columns, scrolling smoothly right-to-left.
--    - Configurable sweep window (1.5s fast, 3.0s normal, 6.0s wide).
-- 3. Cue Event Tagging:
--    - Transients (THUD, TICK) and continuous layers (CAST, SWIM, FOOTFALL) tag the timeline.
--    - Interactive column tooltips show precise timestamp, amplitudes, and cue name.
-- 4. Dual Form Factor:
--    - Embedded "Scope" tab inside the main PulseDebug window (/pdui).
--    - Standalone floating mini-HUD (/pdebug scope) for in-game combat/locomotion testing.
-- 5. Zero-GC & Secret-Value Safe:
--    - Pre-allocated 60-slice ring buffer and UI texture pool.
--    - All readings guarded against secret values (Rule B).

local ADDON_NAME = ...

-- File-local fallback for issecretvalue (native on WoW Forever / retail; never write the global).
local issecretvalue = _G.issecretvalue or function()
	return false
end

local function core()
	local P = _G.Pulse
	if not P or not P.Database or not P.Registry or not P.Engine then
		return nil
	end
	return P
end

---------------------------------------------------------------------------
-- Telemetry & Ring Buffer (Zero-GC)
---------------------------------------------------------------------------

local SAMPLE_COUNT = 60
local SWEEP_PRESETS = {
	{ rate = 0.025, label = "1.5s" },
	{ rate = 0.050, label = "3.0s" },
	{ rate = 0.100, label = "6.0s" },
}
local currentSweepIndex = 2 -- Default 3.0s
local sweepRate = SWEEP_PRESETS[currentSweepIndex].rate

local samples = {}
for i = 1, SAMPLE_COUNT do
	samples[i] = {
		time = 0,
		low = 0,
		high = 0,
		ltrig = 0,
		rtrig = 0,
		tag = nil,
		action = nil,
	}
end

local head = 0
local totalSamples = 0
local isFrozen = false
local displayMode = "split" -- "split" or "overlay"

-- Peak hold tracking
local peakLow = 0
local peakHigh = 0
local peakLowTime = 0
local peakHighTime = 0
local PEAK_HOLD_DURATION = 1.5

-- Pending cue tag to attach to the next sample slice
local pendingCueTag = nil
local pendingCueAction = nil

local function RecordCueEvent(action, triggerID)
	if isFrozen then
		return
	end
	pendingCueTag = tostring(triggerID or "")
	pendingCueAction = tostring(action or "CUE")
end

local function PushSample(now, low, high, ltrig, rtrig)
	head = (head % SAMPLE_COUNT) + 1
	local s = samples[head]
	s.time = now
	s.low = low or 0
	s.high = high or 0
	s.ltrig = ltrig or 0
	s.rtrig = rtrig or 0
	s.tag = pendingCueTag
	s.action = pendingCueAction
	pendingCueTag = nil
	pendingCueAction = nil

	if totalSamples < SAMPLE_COUNT then
		totalSamples = totalSamples + 1
	end

	-- Update 1.5s peak hold
	if s.low >= peakLow then
		peakLow = s.low
		peakLowTime = now
	elseif (now - peakLowTime) > PEAK_HOLD_DURATION then
		peakLow = s.low
		peakLowTime = now
	end

	if s.high >= peakHigh then
		peakHigh = s.high
		peakHighTime = now
	elseif (now - peakHighTime) > PEAK_HOLD_DURATION then
		peakHigh = s.high
		peakHighTime = now
	end
end

local function ClearScope()
	head = 0
	totalSamples = 0
	peakLow = 0
	peakHigh = 0
	peakLowTime = 0
	peakHighTime = 0
	pendingCueTag = nil
	pendingCueAction = nil
	for i = 1, SAMPLE_COUNT do
		local s = samples[i]
		s.time = 0
		s.low = 0
		s.high = 0
		s.ltrig = 0
		s.rtrig = 0
		s.tag = nil
		s.action = nil
	end
end

---------------------------------------------------------------------------
-- UI Color Palette & Styling
---------------------------------------------------------------------------

local COLOR_BG = { 0.04, 0.06, 0.09, 0.94 }
local COLOR_GRID = { 0.16, 0.22, 0.28, 0.40 }
local COLOR_GRID_SOFTFLOOR = { 0.40, 0.32, 0.12, 0.55 }
local COLOR_DIVIDER = { 0.25, 0.32, 0.42, 0.70 }

-- Motor colorways
local COLOR_LOW_FILL = { 1.00, 0.62, 0.05, 0.85 } -- Amber
local COLOR_LOW_CAP = { 1.00, 0.82, 0.35, 1.00 }
local COLOR_HIGH_FILL = { 0.00, 0.82, 1.00, 0.85 } -- Cyan
local COLOR_HIGH_CAP = { 0.55, 0.95, 1.00, 1.00 }
local COLOR_TAG_TICK = { 1.00, 0.85, 0.20, 1.00 }

---------------------------------------------------------------------------
-- Canvas & Visualizer Column Pool
---------------------------------------------------------------------------

local function CreateOscilloscopeCanvas(parent, width, height)
	local canvas = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	canvas:SetSize(width, height)
	canvas:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	canvas:SetBackdropColor(COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4])
	canvas:SetBackdropBorderColor(0.30, 0.38, 0.48, 0.80)

	-- Grid Lines
	local gridLines = {}
	local function makeGridLine(yRatio, r, g, b, a)
		local line = canvas:CreateTexture(nil, "BACKGROUND")
		line:SetColorTexture(r or COLOR_GRID[1], g or COLOR_GRID[2], b or COLOR_GRID[3], a or COLOR_GRID[4])
		line:SetHeight(1)
		line:SetPoint("LEFT", canvas, "LEFT", 4, 0)
		line:SetPoint("RIGHT", canvas, "RIGHT", -4, 0)
		line._yRatio = yRatio
		gridLines[#gridLines + 1] = line
		return line
	end

	-- Center beam divider in split mode
	local centerDivider = canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
	centerDivider:SetColorTexture(COLOR_DIVIDER[1], COLOR_DIVIDER[2], COLOR_DIVIDER[3], COLOR_DIVIDER[4])
	centerDivider:SetHeight(1.5)
	centerDivider:SetPoint("LEFT", canvas, "LEFT", 4, 0)
	centerDivider:SetPoint("RIGHT", canvas, "RIGHT", -4, 0)

	-- Secondary reference lines
	local gridSplitHighMid = makeGridLine(0.75)
	local gridSplitLowMid = makeGridLine(0.25)
	local gridFloorOverlay = makeGridLine(
		0.20,
		COLOR_GRID_SOFTFLOOR[1],
		COLOR_GRID_SOFTFLOOR[2],
		COLOR_GRID_SOFTFLOOR[3],
		COLOR_GRID_SOFTFLOOR[4]
	)

	-- Scale labels
	local lblHighCeiling = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	lblHighCeiling:SetPoint("TOPLEFT", canvas, "TOPLEFT", 8, -6)
	lblHighCeiling:SetText("|cff00d4ffHIGH 1.0|r")

	local lblMid = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	lblMid:SetPoint("LEFT", canvas, "LEFT", 8, 0)
	lblMid:SetText("|cff7788990.0 / SPLIT|r")

	local lblLowFloor = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	lblLowFloor:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 8, 6)
	lblLowFloor:SetText("|cffffaa00LOW 1.0|r")

	-- Pre-allocated column bar widgets
	local columns = {}
	local plotWidth = width - 16
	local colWidth = math.max(1, (plotWidth / SAMPLE_COUNT) - 1)

	for i = 1, SAMPLE_COUNT do
		local col = CreateFrame("Button", nil, canvas)
		col:SetSize(colWidth, height - 12)
		col:SetPoint("LEFT", canvas, "LEFT", 8 + (i - 1) * (colWidth + 1), 0)
		col:EnableMouse(true)

		-- High motor bar
		local highBar = col:CreateTexture(nil, "ARTWORK")
		highBar:SetColorTexture(COLOR_HIGH_FILL[1], COLOR_HIGH_FILL[2], COLOR_HIGH_FILL[3], COLOR_HIGH_FILL[4])

		-- High motor cap (bright peak cap)
		local highCap = col:CreateTexture(nil, "OVERLAY")
		highCap:SetColorTexture(COLOR_HIGH_CAP[1], COLOR_HIGH_CAP[2], COLOR_HIGH_CAP[3], COLOR_HIGH_CAP[4])
		highCap:SetHeight(2)

		-- Low motor bar
		local lowBar = col:CreateTexture(nil, "ARTWORK")
		lowBar:SetColorTexture(COLOR_LOW_FILL[1], COLOR_LOW_FILL[2], COLOR_LOW_FILL[3], COLOR_LOW_FILL[4])

		-- Low motor cap
		local lowCap = col:CreateTexture(nil, "OVERLAY")
		lowCap:SetColorTexture(COLOR_LOW_CAP[1], COLOR_LOW_CAP[2], COLOR_LOW_CAP[3], COLOR_LOW_CAP[4])
		lowCap:SetHeight(2)

		-- Tag marker (cue fired indicator at top of column)
		local tagMarker = col:CreateTexture(nil, "OVERLAY")
		tagMarker:SetColorTexture(COLOR_TAG_TICK[1], COLOR_TAG_TICK[2], COLOR_TAG_TICK[3], COLOR_TAG_TICK[4])
		tagMarker:SetSize(math.max(colWidth, 2), 4)
		tagMarker:SetPoint("TOP", col, "TOP", 0, 0)
		tagMarker:Hide()

		-- Column mouseover tooltip for detailed inspection
		col:SetScript("OnEnter", function(self)
			local sample = self._sample
			if not sample or sample.time == 0 then
				return
			end
			if _G.GameTooltip then
				_G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
				local sec = math.floor(sample.time)
				local ms = math.floor((sample.time - sec) * 1000)
				_G.GameTooltip:AddLine(string.format("Time: %02d.%03ds", sec % 60, ms), 1, 1, 1)
				_G.GameTooltip:AddDoubleLine(
					"Low Motor (LF):",
					string.format("%.3f (%d%%)", sample.low, math.floor(sample.low * 100)),
					1,
					0.7,
					0.1,
					1,
					1,
					1
				)
				_G.GameTooltip:AddDoubleLine(
					"High Motor (HF):",
					string.format("%.3f (%d%%)", sample.high, math.floor(sample.high * 100)),
					0.2,
					0.8,
					1,
					1,
					1,
					1
				)
				if sample.ltrig > 0 or sample.rtrig > 0 then
					_G.GameTooltip:AddDoubleLine(
						"Triggers (L/R):",
						string.format("%.2f / %.2f", sample.ltrig, sample.rtrig),
						0.6,
						0.9,
						0.6,
						1,
						1,
						1
					)
				end
				if sample.tag then
					_G.GameTooltip:AddLine(" ")
					_G.GameTooltip:AddDoubleLine("Cue Event:", sample.tag, 1, 0.85, 0.2, 1, 1, 0.6)
					if sample.action then
						_G.GameTooltip:AddDoubleLine("Action:", sample.action, 0.7, 0.7, 0.7, 1, 1, 1)
					end
				end
				_G.GameTooltip:Show()
			end
		end)
		col:SetScript("OnLeave", function()
			if _G.GameTooltip then
				_G.GameTooltip:Hide()
			end
		end)

		columns[i] = {
			frame = col,
			lowBar = lowBar,
			lowCap = lowCap,
			highBar = highBar,
			highCap = highCap,
			tagMarker = tagMarker,
		}
	end

	-- Render pass
	local function RenderCanvas()
		local rawH = nil
		if type(canvas.GetHeight) == "function" then
			rawH = canvas:GetHeight()
		end
		if not rawH or type(rawH) ~= "number" or rawH <= 0 then
			rawH = height or 200
		end
		local canvasH = math.max(20, rawH - 16)
		local halfH = canvasH * 0.5
		local centerY = rawH * 0.5

		-- Position grid lines
		centerDivider:SetPoint("CENTER", canvas, "BOTTOM", 0, centerY)
		gridSplitHighMid:SetPoint("CENTER", canvas, "BOTTOM", 0, centerY + halfH * 0.5)
		gridSplitLowMid:SetPoint("CENTER", canvas, "BOTTOM", 0, centerY - halfH * 0.5)
		gridFloorOverlay:SetPoint("CENTER", canvas, "BOTTOM", 0, 8 + canvasH * 0.20)

		if displayMode == "split" then
			centerDivider:Show()
			gridSplitHighMid:Show()
			gridSplitLowMid:Show()
			gridFloorOverlay:Hide()
			lblHighCeiling:SetText("|cff00d4ffHIGH 1.0|r")
			lblMid:SetText("|cff7788990.0 / SPLIT|r")
			lblLowFloor:SetText("|cffffaa00LOW 1.0|r")
		else
			centerDivider:Hide()
			gridSplitHighMid:Hide()
			gridSplitLowMid:Hide()
			gridFloorOverlay:Show()
			lblHighCeiling:SetText("|cffffffff1.0 CEIL|r")
			lblMid:SetText("|cff7788990.5 MID|r")
			lblLowFloor:SetText("|cffffaa000.2 FLOOR|r")
		end

		-- Populate columns from ring buffer (oldest on left, newest on right)
		for i = 1, SAMPLE_COUNT do
			local col = columns[i]
			local ringIndex = ((head - (SAMPLE_COUNT - i)) % SAMPLE_COUNT) + 1
			local sample = samples[ringIndex]
			col.frame._sample = sample

			local lowVal = sample.low or 0
			local highVal = sample.high or 0

			if sample.tag then
				col.tagMarker:Show()
			else
				col.tagMarker:Hide()
			end

			if displayMode == "split" then
				-- High Motor: grows UPWARD from center divider
				local hH = math.max(0, highVal * (halfH - 2))
				if hH > 0 then
					col.highBar:ClearAllPoints()
					col.highBar:SetPoint("BOTTOM", canvas, "BOTTOM", 0, centerY + 1)
					col.highBar:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.highBar:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.highBar:SetHeight(hH)
					col.highBar:Show()

					col.highCap:ClearAllPoints()
					col.highCap:SetPoint("BOTTOM", col.highBar, "TOP", 0, -1)
					col.highCap:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.highCap:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.highCap:Show()
				else
					col.highBar:Hide()
					col.highCap:Hide()
				end

				-- Low Motor: grows DOWNWARD from center divider
				local lH = math.max(0, lowVal * (halfH - 2))
				if lH > 0 then
					col.lowBar:ClearAllPoints()
					col.lowBar:SetPoint("TOP", canvas, "BOTTOM", 0, centerY - 1)
					col.lowBar:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.lowBar:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.lowBar:SetHeight(lH)
					col.lowBar:Show()

					col.lowCap:ClearAllPoints()
					col.lowCap:SetPoint("TOP", col.lowBar, "BOTTOM", 0, 1)
					col.lowCap:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.lowCap:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.lowCap:Show()
				else
					col.lowBar:Hide()
					col.lowCap:Hide()
				end
			else
				-- Overlaid Mode: both grow UPWARD from bottom base
				local lH = math.max(0, lowVal * (canvasH - 2))
				local hH = math.max(0, highVal * (canvasH - 2))

				if lH > 0 then
					col.lowBar:ClearAllPoints()
					col.lowBar:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 8)
					col.lowBar:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.lowBar:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.lowBar:SetHeight(lH)
					col.lowBar:Show()

					col.lowCap:ClearAllPoints()
					col.lowCap:SetPoint("BOTTOM", col.lowBar, "TOP", 0, -1)
					col.lowCap:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.lowCap:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.lowCap:Show()
				else
					col.lowBar:Hide()
					col.lowCap:Hide()
				end

				if hH > 0 then
					col.highBar:ClearAllPoints()
					col.highBar:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 8)
					col.highBar:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.highBar:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.highBar:SetHeight(hH)
					col.highBar:Show()

					col.highCap:ClearAllPoints()
					col.highCap:SetPoint("BOTTOM", col.highBar, "TOP", 0, -1)
					col.highCap:SetPoint("LEFT", col.frame, "LEFT", 0, 0)
					col.highCap:SetPoint("RIGHT", col.frame, "RIGHT", 0, 0)
					col.highCap:Show()
				else
					col.highBar:Hide()
					col.highCap:Hide()
				end
			end
		end
	end

	canvas.Render = RenderCanvas
	return canvas
end

---------------------------------------------------------------------------
-- Telemetry Header Widget
---------------------------------------------------------------------------

local function CreateTelemetryHeader(parent)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(28)

	local txtStatus = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	txtStatus:SetPoint("LEFT", header, "LEFT", 6, 0)
	txtStatus:SetText("|cff00ff00RUN|r  |cff888888[3.0s / 20Hz]|r")

	local txtLow = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	txtLow:SetPoint("LEFT", txtStatus, "RIGHT", 24, 0)
	txtLow:SetText("|cffffaa00LOW: 0.00|r |cff778899(peak 0.00)|r")

	local txtHigh = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	txtHigh:SetPoint("LEFT", txtLow, "RIGHT", 24, 0)
	txtHigh:SetText("|cff00d4ffHIGH: 0.00|r |cff778899(peak 0.00)|r")

	local txtLayers = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	txtLayers:SetPoint("RIGHT", header, "RIGHT", -6, 0)
	txtLayers:SetText("layers: 0")

	local function UpdateHeader(low, high, activeLayers)
		if isFrozen then
			txtStatus:SetText(
				"|cffff4444FROZEN|r  |cff888888["
					.. SWEEP_PRESETS[currentSweepIndex].label
					.. " / "
					.. string.format("%dHz", math.floor(1 / sweepRate))
					.. "]|r"
			)
		else
			txtStatus:SetText(
				"|cff00ff00RUN|r  |cff888888["
					.. SWEEP_PRESETS[currentSweepIndex].label
					.. " / "
					.. string.format("%dHz", math.floor(1 / sweepRate))
					.. "]|r"
			)
		end

		txtLow:SetText(string.format("|cffffaa00LOW: %.2f|r |cff778899(peak %.2f)|r", low or 0, peakLow or 0))
		txtHigh:SetText(string.format("|cff00d4ffHIGH: %.2f|r |cff778899(peak %.2f)|r", high or 0, peakHigh or 0))
		txtLayers:SetText(string.format("layers: %d", activeLayers or 0))
	end

	header.Update = UpdateHeader
	return header
end

---------------------------------------------------------------------------
-- Master Oscilloscope Panel (Embedded in PulseDebugUI)
---------------------------------------------------------------------------

local embeddedPanel = nil
local floatingHud = nil

local function BuildEmbeddedPanel(parent)
	local p = CreateFrame("Frame", "PulseDebugScopePanel", parent)
	p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

	local header = CreateTelemetryHeader(p)
	header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)

	local canvas = CreateOscilloscopeCanvas(p, 608, 270)
	canvas:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
	canvas:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)

	-- Controls Bar
	local controls = CreateFrame("Frame", nil, p)
	controls:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -6)
	controls:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
	controls:SetHeight(32)

	local btnFreeze = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
	btnFreeze:SetSize(72, 22)
	btnFreeze:SetPoint("LEFT", controls, "LEFT", 0, 0)
	btnFreeze:SetText("Freeze")
	btnFreeze:SetScript("OnClick", function(self)
		isFrozen = not isFrozen
		self:SetText(isFrozen and "Run" or "Freeze")
	end)

	local btnMode = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
	btnMode:SetSize(82, 22)
	btnMode:SetPoint("LEFT", btnFreeze, "RIGHT", 6, 0)
	btnMode:SetText(displayMode == "split" and "Split Beam" or "Overlaid")
	btnMode:SetScript("OnClick", function(self)
		displayMode = (displayMode == "split") and "overlay" or "split"
		self:SetText(displayMode == "split" and "Split Beam" or "Overlaid")
		canvas.Render()
	end)

	local btnSweep = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
	btnSweep:SetSize(72, 22)
	btnSweep:SetPoint("LEFT", btnMode, "RIGHT", 6, 0)
	btnSweep:SetText("Sweep " .. SWEEP_PRESETS[currentSweepIndex].label)
	btnSweep:SetScript("OnClick", function(self)
		currentSweepIndex = (currentSweepIndex % #SWEEP_PRESETS) + 1
		sweepRate = SWEEP_PRESETS[currentSweepIndex].rate
		self:SetText("Sweep " .. SWEEP_PRESETS[currentSweepIndex].label)
	end)

	local btnClear = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
	btnClear:SetSize(56, 22)
	btnClear:SetPoint("LEFT", btnSweep, "RIGHT", 6, 0)
	btnClear:SetText("Clear")
	btnClear:SetScript("OnClick", function()
		ClearScope()
		canvas.Render()
	end)

	local btnPopout = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
	btnPopout:SetSize(86, 22)
	btnPopout:SetPoint("RIGHT", controls, "RIGHT", 0, 0)
	btnPopout:SetText("Pop-out HUD")
	btnPopout:SetScript("OnClick", function()
		if _G.PulseDebugUI and _G.PulseDebugUI.ToggleScopeHUD then
			_G.PulseDebugUI.ToggleScopeHUD()
		end
	end)

	p.header = header
	p.canvas = canvas
	p.btnFreeze = btnFreeze
	return p
end

---------------------------------------------------------------------------
-- Standalone Floating Mini-HUD (for combat / locomotion gameplay testing)
---------------------------------------------------------------------------

local function BuildFloatingHUD()
	if floatingHud then
		return floatingHud
	end

	local hud = CreateFrame("Frame", "PulseOscilloscopeHUD", UIParent, "BackdropTemplate")
	hud:SetSize(360, 190)
	hud:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 140)
	hud:SetFrameStrata("DIALOG")
	hud:SetClampedToScreen(true)
	hud:SetMovable(true)
	hud:EnableMouse(true)
	hud:RegisterForDrag("LeftButton")
	hud:SetScript("OnDragStart", hud.StartMoving)
	hud:SetScript("OnDragStop", hud.StopMovingOrSizing)
	hud:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	hud:SetBackdropColor(0.03, 0.05, 0.08, 0.90)
	hud:SetBackdropBorderColor(0.20, 0.35, 0.50, 0.85)
	hud:Hide()

	if UISpecialFrames then
		tinsert(UISpecialFrames, "PulseOscilloscopeHUD")
	end

	local title = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	title:SetPoint("TOPLEFT", hud, "TOPLEFT", 8, -6)
	title:SetText("|cffb488ffPulse|r Haptic Oscilloscope")

	local btnClose = CreateFrame("Button", nil, hud, "UIPanelCloseButton")
	btnClose:SetSize(18, 18)
	btnClose:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -2, -2)

	local header = CreateTelemetryHeader(hud)
	header:SetPoint("TOPLEFT", hud, "TOPLEFT", 0, -18)
	header:SetPoint("TOPRIGHT", hud, "TOPRIGHT", 0, -18)

	local canvas = CreateOscilloscopeCanvas(hud, 344, 115)
	canvas:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	canvas:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)

	-- Mini controls bar
	local btnFreeze = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
	btnFreeze:SetSize(58, 18)
	btnFreeze:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 8, 6)
	btnFreeze:SetText("Freeze")
	btnFreeze:SetScript("OnClick", function(self)
		isFrozen = not isFrozen
		self:SetText(isFrozen and "Run" or "Freeze")
	end)

	local btnMode = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
	btnMode:SetSize(52, 18)
	btnMode:SetPoint("LEFT", btnFreeze, "RIGHT", 4, 0)
	btnMode:SetText(displayMode == "split" and "Split" or "Over")
	btnMode:SetScript("OnClick", function(self)
		displayMode = (displayMode == "split") and "overlay" or "split"
		self:SetText(displayMode == "split" and "Split" or "Over")
		canvas.Render()
	end)

	local btnClear = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
	btnClear:SetSize(46, 18)
	btnClear:SetPoint("LEFT", btnMode, "RIGHT", 4, 0)
	btnClear:SetText("Clear")
	btnClear:SetScript("OnClick", function()
		ClearScope()
		canvas.Render()
	end)

	hud.header = header
	hud.canvas = canvas
	hud.btnFreeze = btnFreeze
	floatingHud = hud
	return hud
end

---------------------------------------------------------------------------
-- Real-time Sampling & Drive Loop (Zero-GC)
---------------------------------------------------------------------------

-- Static telemetry buffer reused every tick to avoid table creation
local telemetryBuffer = {
	low = 0,
	high = 0,
	ltrig = 0,
	rtrig = 0,
	smoothedLow = 0,
	smoothedHigh = 0,
	anyActive = false,
}

local elapsedSinceSample = 0
local driveFrame = CreateFrame("Frame")

local function OnOscilloscopeTick(elapsed)
	elapsedSinceSample = elapsedSinceSample + elapsed
	if elapsedSinceSample < sweepRate then
		return
	end
	elapsedSinceSample = 0

	local P = core()
	if not P or not P.Engine then
		return
	end

	local now = (type(GetTime) == "function") and GetTime() or 0

	-- Read channel outputs using zero-allocation reach-in or fallback
	if type(P.Engine.GetChannelOutputs) == "function" then
		P.Engine:GetChannelOutputs(telemetryBuffer)
	else
		-- Fallback to _DebugChannels if older engine version
		local channels = P.Engine:_DebugChannels()
		local lowInfo = channels.Low or channels.low
		local highInfo = channels.High or channels.high
		local l = lowInfo and lowInfo.lastSet or 0
		local h = highInfo and highInfo.lastSet or 0
		telemetryBuffer.low = (not issecretvalue(l) and type(l) == "number") and l or 0
		telemetryBuffer.high = (not issecretvalue(h) and type(h) == "number") and h or 0
		telemetryBuffer.ltrig = 0
		telemetryBuffer.rtrig = 0
	end

	local activeLayers = 0
	if type(P.Engine.GetActiveLayerCount) == "function" then
		activeLayers = P.Engine:GetActiveLayerCount()
	elseif type(P.Engine._DebugLayers) == "function" then
		local layers = P.Engine:_DebugLayers()
		activeLayers = #layers
	end

	if not isFrozen then
		PushSample(now, telemetryBuffer.low, telemetryBuffer.high, telemetryBuffer.ltrig, telemetryBuffer.rtrig)
	end

	-- Update active views
	if embeddedPanel and embeddedPanel:IsShown() then
		embeddedPanel.header.Update(telemetryBuffer.low, telemetryBuffer.high, activeLayers)
		embeddedPanel.canvas.Render()
	end

	if floatingHud and floatingHud:IsShown() then
		floatingHud.header.Update(telemetryBuffer.low, telemetryBuffer.high, activeLayers)
		floatingHud.canvas.Render()
	end
end

driveFrame:SetScript("OnUpdate", function(_, elapsed)
	-- Only tick if either the embedded scope panel or the floating HUD is visible
	local embeddedVisible = (embeddedPanel and embeddedPanel:IsShown())
	local hudVisible = (floatingHud and floatingHud:IsShown())
	if embeddedVisible or hudVisible then
		OnOscilloscopeTick(elapsed)
	end
end)

---------------------------------------------------------------------------
-- Public Module Interface
---------------------------------------------------------------------------

local Oscilloscope = {
	RecordCue = RecordCueEvent,
	Clear = ClearScope,
	GetSamples = function()
		return samples
	end,
	IsFrozen = function()
		return isFrozen
	end,
	SetFrozen = function(frozen)
		isFrozen = frozen and true or false
		if embeddedPanel and embeddedPanel.btnFreeze then
			embeddedPanel.btnFreeze:SetText(isFrozen and "Run" or "Freeze")
		end
		if floatingHud and floatingHud.btnFreeze then
			floatingHud.btnFreeze:SetText(isFrozen and "Run" or "Freeze")
		end
	end,
	SetDisplayMode = function(mode)
		displayMode = (mode == "overlay") and "overlay" or "split"
		if embeddedPanel then
			embeddedPanel.canvas.Render()
		end
		if floatingHud then
			floatingHud.canvas.Render()
		end
	end,
	GetDisplayMode = function()
		return displayMode
	end,
	MountEmbedded = function(parent)
		if not embeddedPanel then
			embeddedPanel = BuildEmbeddedPanel(parent)
		end
		return embeddedPanel
	end,
	ToggleHUD = function()
		local hud = BuildFloatingHUD()
		if hud:IsShown() then
			hud:Hide()
		else
			hud:Show()
			hud.canvas.Render()
		end
		return hud:IsShown()
	end,
	ShowHUD = function()
		local hud = BuildFloatingHUD()
		hud:Show()
		hud.canvas.Render()
	end,
	HideHUD = function()
		if floatingHud then
			floatingHud:Hide()
		end
	end,
}

_G.PulseOscilloscope = Oscilloscope
return Oscilloscope
