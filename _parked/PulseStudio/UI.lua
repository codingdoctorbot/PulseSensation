-- PulseStudio — UI.lua
--
-- Visual multi-track timeline and haptic waveform composer interface.
-- Features live block editing, instant tactile audition, and Lua export.

local _, Studio = ...

local studioUI = nil
local CANVAS_WIDTH = 460
local CANVAS_HEIGHT = 120
local MAX_TIME = 1.0 -- 1.0s viewport

local function timeToX(t)
	return math.min(CANVAS_WIDTH, math.max(0, (t / MAX_TIME) * CANVAS_WIDTH))
end

local function createStudioUI()
	if studioUI then
		return studioUI
	end

	local f = CreateFrame("Frame", "PulseStudioFrame", UIParent, "BackdropTemplate")
	f:SetSize(520, 480)
	f:SetPoint("CENTER", UIParent, "CENTER", 50, 20)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)

	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	f:SetBackdropColor(0.06, 0.06, 0.08, 0.98)

	-- Header
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 22, -18)
	title:SetText("|cffffaa00PulseStudio|r  |cffffffffWaveform Sequencer|r")

	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sub:SetPoint("TOPLEFT", 22, -40)
	sub:SetText("Compose tactile waveforms on dual Low/High motor tracks.")

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -8, -8)

	-- Timeline Canvas Box
	local canvas = CreateFrame("Frame", nil, f, "BackdropTemplate")
	canvas:SetSize(CANVAS_WIDTH, CANVAS_HEIGHT)
	canvas:SetPoint("TOPLEFT", 26, -70)
	canvas:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	canvas:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
	canvas:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)

	-- Track Dividers & Labels
	local trackLowLabel = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	trackLowLabel:SetPoint("TOPLEFT", 6, -6)
	trackLowLabel:SetText("|cffffaa00Low (Bass)|r")

	local trackHighLabel = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	trackHighLabel:SetPoint("TOPLEFT", 6, -66)
	trackHighLabel:SetText("|cff00ffccHigh (Treble)|r")

	local divider = canvas:CreateLine(nil, "BACKGROUND")
	divider:SetColorTexture(0.2, 0.2, 0.25, 0.6)
	divider:SetStartPoint("TOPLEFT", 0, -60)
	divider:SetEndPoint("TOPRIGHT", 0, -60)
	divider:SetThickness(1)

	-- Time Grid Lines (0.2s, 0.4s, 0.6s, 0.8s, 1.0s)
	for i = 1, 4 do
		local tX = (i / 5) * CANVAS_WIDTH
		local line = canvas:CreateLine(nil, "BACKGROUND")
		line:SetColorTexture(0.15, 0.15, 0.20, 0.4)
		line:SetStartPoint("TOPLEFT", tX, 0)
		line:SetEndPoint("BOTTOMLEFT", tX, 0)
		line:SetThickness(1)

		local tLabel = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		tLabel:SetPoint("BOTTOMLEFT", tX + 2, 2)
		tLabel:SetText(string.format("%.1fs", i * 0.2))
	end

	-- Block Pool for Canvas Rendering
	local blockFrames = {}
	local function clearRenderedBlocks()
		for _, bf in ipairs(blockFrames) do
			bf:Hide()
		end
	end

	local inspectorFrame = nil

	local function refreshCanvas()
		clearRenderedBlocks()
		local blocks = Studio.Blocks
		local bfIdx = 1

		for _, b in ipairs(blocks) do
			local bf = blockFrames[bfIdx]
			if not bf then
				bf = CreateFrame("Button", nil, canvas, "BackdropTemplate")
				bf:SetBackdrop({
					bgFile = "Interface\\Buttons\\WHITE8X8",
					edgeFile = "Interface\\Buttons\\WHITE8X8",
					edgeSize = 1,
				})
				blockFrames[bfIdx] = bf
			end

			local x = timeToX(b.start)
			local w = math.max(6, timeToX(b.duration))
			local isSelected = (Studio.SelectedBlockID == b.id)

			-- Render in Low or High track
			local function placeBlock(parentBf, yOffset, r, g, bl)
				local h = 50 * b.intensity
				parentBf:SetSize(w, math.max(8, h))
				parentBf:ClearAllPoints()
				parentBf:SetPoint("BOTTOMLEFT", canvas, "TOPLEFT", x, yOffset)
				parentBf:SetBackdropColor(r, g, bl, isSelected and 0.95 or 0.70)
				parentBf:SetBackdropBorderColor(
					isSelected and 1.0 or 0.5,
					isSelected and 1.0 or 0.5,
					isSelected and 1.0 or 0.5,
					1.0
				)
				parentBf:SetScript("OnClick", function()
					Studio.SelectedBlockID = b.id
					refreshCanvas()
					if inspectorFrame and inspectorFrame.Sync then
						inspectorFrame.Sync()
					end
				end)
				parentBf:Show()
			end

			if b.role == "low" then
				placeBlock(bf, -58, 1.0, 0.65, 0.0)
				bfIdx = bfIdx + 1
			elseif b.role == "high" then
				placeBlock(bf, -118, 0.0, 0.9, 0.8)
				bfIdx = bfIdx + 1
			else
				-- Both motors: render Low track, and make another frame for High track
				placeBlock(bf, -58, 1.0, 0.65, 0.0)
				bfIdx = bfIdx + 1

				local bf2 = blockFrames[bfIdx]
				if not bf2 then
					bf2 = CreateFrame("Button", nil, canvas, "BackdropTemplate")
					bf2:SetBackdrop({
						bgFile = "Interface\\Buttons\\WHITE8X8",
						edgeFile = "Interface\\Buttons\\WHITE8X8",
						edgeSize = 1,
					})
					blockFrames[bfIdx] = bf2
				end
				placeBlock(bf2, -118, 0.0, 0.9, 0.8)
				bfIdx = bfIdx + 1
			end
		end
	end

	-- Transport Controls Bar
	local playBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	playBtn:SetSize(90, 26)
	playBtn:SetPoint("TOPLEFT", 26, -200)
	playBtn:SetText("|cff44ff44▶ Audition|r")
	playBtn:SetScript("OnClick", function()
		Studio:PlaySequence(Studio.Blocks)
	end)

	local stopBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	stopBtn:SetSize(75, 26)
	stopBtn:SetPoint("LEFT", playBtn, "RIGHT", 8, 0)
	stopBtn:SetText("⏹ Stop")
	stopBtn:SetScript("OnClick", function()
		Studio:Stop()
	end)

	local addLowBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	addLowBtn:SetSize(95, 26)
	addLowBtn:SetPoint("LEFT", stopBtn, "RIGHT", 14, 0)
	addLowBtn:SetText("+ Low Step")
	addLowBtn:SetScript("OnClick", function()
		Studio:AddBlock("low", 0.0, 0.10, 0.8)
		refreshCanvas()
		if inspectorFrame and inspectorFrame.Sync then
			inspectorFrame.Sync()
		end
	end)

	local addHighBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	addHighBtn:SetSize(95, 26)
	addHighBtn:SetPoint("LEFT", addLowBtn, "RIGHT", 8, 0)
	addHighBtn:SetText("+ High Step")
	addHighBtn:SetScript("OnClick", function()
		Studio:AddBlock("high", 0.0, 0.05, 0.8)
		refreshCanvas()
		if inspectorFrame and inspectorFrame.Sync then
			inspectorFrame.Sync()
		end
	end)

	local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	clearBtn:SetSize(65, 26)
	clearBtn:SetPoint("LEFT", addHighBtn, "RIGHT", 8, 0)
	clearBtn:SetText("Clear")
	clearBtn:SetScript("OnClick", function()
		Studio:Clear()
		refreshCanvas()
		if inspectorFrame and inspectorFrame.Sync then
			inspectorFrame.Sync()
		end
	end)

	-- Selected Step Inspector
	local insp = CreateFrame("Frame", nil, f, "BackdropTemplate")
	insp:SetSize(CANVAS_WIDTH, 140)
	insp:SetPoint("TOPLEFT", 26, -235)
	insp:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	insp:SetBackdropColor(0.04, 0.04, 0.05, 0.8)
	insp:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.6)

	local inspTitle = insp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	inspTitle:SetPoint("TOPLEFT", 12, -10)
	inspTitle:SetText("Step Inspector")

	-- Delete Step Button
	local delBtn = CreateFrame("Button", nil, insp, "UIPanelButtonTemplate")
	delBtn:SetSize(90, 20)
	delBtn:SetPoint("TOPRIGHT", -12, -8)
	delBtn:SetText("|cffff5555Delete Step|r")

	-- Start Time Slider
	local startSlider = CreateFrame("Slider", "PulseStudioStartSlider", insp, "OptionsSliderTemplate")
	startSlider:SetPoint("TOPLEFT", 20, -45)
	startSlider:SetSize(180, 16)
	startSlider:SetMinMaxValues(0.0, 1.0)
	startSlider:SetValueStep(0.01)
	startSlider:SetObeyStepOnDrag(true)
	if _G[startSlider:GetName() .. "Low"] then
		_G[startSlider:GetName() .. "Low"]:SetText("0s")
	end
	if _G[startSlider:GetName() .. "High"] then
		_G[startSlider:GetName() .. "High"]:SetText("1s")
	end

	-- Duration Slider
	local durSlider = CreateFrame("Slider", "PulseStudioDurSlider", insp, "OptionsSliderTemplate")
	durSlider:SetPoint("TOPLEFT", 240, -45)
	durSlider:SetSize(180, 16)
	durSlider:SetMinMaxValues(0.02, 0.50)
	durSlider:SetValueStep(0.01)
	durSlider:SetObeyStepOnDrag(true)
	if _G[durSlider:GetName() .. "Low"] then
		_G[durSlider:GetName() .. "Low"]:SetText("0.02s")
	end
	if _G[durSlider:GetName() .. "High"] then
		_G[durSlider:GetName() .. "High"]:SetText("0.5s")
	end

	-- Intensity Slider
	local intSlider = CreateFrame("Slider", "PulseStudioIntSlider", insp, "OptionsSliderTemplate")
	intSlider:SetPoint("TOPLEFT", 20, -95)
	intSlider:SetSize(180, 16)
	intSlider:SetMinMaxValues(0.05, 1.0)
	intSlider:SetValueStep(0.05)
	intSlider:SetObeyStepOnDrag(true)
	if _G[intSlider:GetName() .. "Low"] then
		_G[intSlider:GetName() .. "Low"]:SetText("5%")
	end
	if _G[intSlider:GetName() .. "High"] then
		_G[intSlider:GetName() .. "High"]:SetText("100%")
	end

	-- Role Selector (Low / High / Both)
	local roleLow = CreateFrame("Button", nil, insp, "UIPanelButtonTemplate")
	roleLow:SetSize(60, 22)
	roleLow:SetPoint("TOPLEFT", 240, -90)
	roleLow:SetText("Low")

	local roleHigh = CreateFrame("Button", nil, insp, "UIPanelButtonTemplate")
	roleHigh:SetSize(60, 22)
	roleHigh:SetPoint("LEFT", roleLow, "RIGHT", 6, 0)
	roleHigh:SetText("High")

	local roleBoth = CreateFrame("Button", nil, insp, "UIPanelButtonTemplate")
	roleBoth:SetSize(60, 22)
	roleBoth:SetPoint("LEFT", roleHigh, "RIGHT", 6, 0)
	roleBoth:SetText("Both")

	local function syncInspector()
		local b = Studio:GetSelectedBlock()
		if not b then
			inspTitle:SetText("|cff888888No step selected. Click a block above or add one.|r")
			startSlider:Hide()
			durSlider:Hide()
			intSlider:Hide()
			roleLow:Hide()
			roleHigh:Hide()
			roleBoth:Hide()
			delBtn:Hide()
			return
		end

		inspTitle:SetText(string.format("Selected Step #%d (%s motor)", b.id, string.upper(b.role)))
		startSlider:Show()
		durSlider:Show()
		intSlider:Show()
		roleLow:Show()
		roleHigh:Show()
		roleBoth:Show()
		delBtn:Show()

		startSlider:SetValue(b.start)
		if _G[startSlider:GetName() .. "Text"] then
			_G[startSlider:GetName() .. "Text"]:SetText(string.format("Start: %.3fs", b.start))
		end

		durSlider:SetValue(b.duration)
		if _G[durSlider:GetName() .. "Text"] then
			_G[durSlider:GetName() .. "Text"]:SetText(string.format("Duration: %.3fs", b.duration))
		end

		intSlider:SetValue(b.intensity)
		if _G[intSlider:GetName() .. "Text"] then
			_G[intSlider:GetName() .. "Text"]:SetText(
				string.format("Intensity: %d%%", math.floor(b.intensity * 100 + 0.5))
			)
		end
	end
	insp.Sync = syncInspector
	inspectorFrame = insp

	startSlider:SetScript("OnValueChanged", function(self, val)
		Studio:UpdateSelectedBlock("start", val)
		if _G[self:GetName() .. "Text"] then
			_G[self:GetName() .. "Text"]:SetText(string.format("Start: %.3fs", val))
		end
		refreshCanvas()
	end)

	durSlider:SetScript("OnValueChanged", function(self, val)
		Studio:UpdateSelectedBlock("duration", val)
		if _G[self:GetName() .. "Text"] then
			_G[self:GetName() .. "Text"]:SetText(string.format("Duration: %.3fs", val))
		end
		refreshCanvas()
	end)

	intSlider:SetScript("OnValueChanged", function(self, val)
		Studio:UpdateSelectedBlock("intensity", val)
		if _G[self:GetName() .. "Text"] then
			_G[self:GetName() .. "Text"]:SetText(string.format("Intensity: %d%%", math.floor(val * 100 + 0.5)))
		end
		refreshCanvas()
	end)

	roleLow:SetScript("OnClick", function()
		Studio:UpdateSelectedBlock("role", "low")
		syncInspector()
		refreshCanvas()
	end)
	roleHigh:SetScript("OnClick", function()
		Studio:UpdateSelectedBlock("role", "high")
		syncInspector()
		refreshCanvas()
	end)
	roleBoth:SetScript("OnClick", function()
		Studio:UpdateSelectedBlock("role", "both")
		syncInspector()
		refreshCanvas()
	end)

	delBtn:SetScript("OnClick", function()
		local b = Studio:GetSelectedBlock()
		if b then
			Studio:RemoveBlock(b.id)
			syncInspector()
			refreshCanvas()
		end
	end)

	-- Bottom Action Bar: Preset Loader & Lua Export
	local exportBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	exportBox:SetSize(460, 24)
	exportBox:SetPoint("BOTTOMLEFT", 30, 20)
	exportBox:SetAutoFocus(false)
	exportBox:SetText("/pb play BURST")
	exportBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)

	local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	exportBtn:SetSize(130, 24)
	exportBtn:SetPoint("BOTTOMLEFT", 26, 50)
	exportBtn:SetText("Export Lua String")
	exportBtn:SetScript("OnClick", function()
		local lua = Studio:ExportToLua("MY_PULSE", "Created in PulseStudio", Studio.Blocks)
		exportBox:SetText(lua)
		exportBox:HighlightText()
		exportBox:SetFocus()
	end)

	local remixBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	remixBtn:SetSize(110, 24)
	remixBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
	remixBtn:SetText("Remix BURST")
	remixBtn:SetScript("OnClick", function()
		Studio:LoadBuiltin("BURST")
		syncInspector()
		refreshCanvas()
	end)

	local remixHeartBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	remixHeartBtn:SetSize(130, 24)
	remixHeartBtn:SetPoint("LEFT", remixBtn, "RIGHT", 10, 0)
	remixHeartBtn:SetText("Remix PULSE_BEAT")
	remixHeartBtn:SetScript("OnClick", function()
		Studio:LoadBuiltin("PULSE_BEAT")
		syncInspector()
		refreshCanvas()
	end)

	f:SetScript("OnShow", function()
		if #Studio.Blocks == 0 then
			Studio:LoadBuiltin("BURST")
		end
		syncInspector()
		refreshCanvas()
	end)

	studioUI = f
	return f
end

function Studio:ToggleUI()
	local ui = createStudioUI()
	if ui:IsShown() then
		ui:Hide()
	else
		ui:Show()
	end
end
