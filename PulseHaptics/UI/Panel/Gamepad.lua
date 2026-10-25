-- Pulse — UI/Panel/Gamepad.lua
--
-- Safe, native controller navigation for Pulse's main settings panel.
--
-- Architecture:
--   - Two main focus contexts: "SIDEBAR" (category list) and "CONTENT" (settings rows).
--   - Horizontal Sub-Focus in Cue Rows:
--       [Checkbox] <-> [Mode Dropdown] <-> [Intensity Slider] <-> [Play Button (>)]
--   - D-Pad UP/DOWN moves vertically across rows while retaining column alignment.
--   - D-Pad LEFT/RIGHT moves horizontally between widgets on the active row.
--   - Pressing D-Pad LEFT on the first control returns cleanly to the Sidebar.
--   - Dedicated "Try Texture" hotkey on PAD3 ([X] / [Square]) anytime anywhere on a Cue Row.
--   - Interactive Slider Adjustment: Pressing A on a slider enters "Adjust Mode" (golden glow)
--     allowing D-Pad LEFT/RIGHT to slide values smoothly with live haptic feedback.
--     Triggers (LT/RT) also step sliders directly.
--   - Integrated Dropdown Navigation: D-Pad and A/B directly browse and pick from Popup menus.
--   - Dynamic Lowermost Bar: Displays contextual button prompts with native Blizzard controller glyphs.
--   - Native button events handle navigation. No hidden click target captures gameplay keys.
--     Any stale window-owned overrides are cleared out of combat.

local ADDON_NAME, Pulse = ...
local L = Pulse.L or function(text) return text end

local Panel = Pulse.UI.Panel
local Theme = Panel.Theme

local Gamepad = {}
Panel.Gamepad = Gamepad

local panel -- reference to PulsePanel
local pendingCaptureCleanup
local focusBox -- visual focus reticle
local mode = "SIDEBAR" -- "SIDEBAR" or "CONTENT"
local currentSidebarIndex = 1
local currentContentIndex = 1
local currentSubTargetIndex = 1
local isAdjustingSlider = false
local focusedRow = nil

function Gamepad.IsEnabled()
	if type(InputUtil) == "table" and type(InputUtil.IsGamepadUIEnabled) == "function" then
		if InputUtil.IsGamepadUIEnabled() then
			return true
		end
	end
	if type(GetCVarBool) == "function" then
		local ok, val = pcall(GetCVarBool, "GamePadEnable")
		if ok and val then
			return true
		end
	end
	return true
end

-- ── Visual Focus Reticle ─────────────────────────────────────────────────────

local function getFocusBox(parent)
	if focusBox then
		return focusBox
	end

	local fb = CreateFrame("Frame", nil, parent)
	fb:SetFrameStrata("DIALOG")
	fb:SetFrameLevel((parent:GetFrameLevel() or 10) + 15)

	-- Hollow 2px Radiant Border
	local bTop = fb:CreateTexture(nil, "OVERLAY")
	bTop:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	bTop:SetPoint("TOPRIGHT", fb, "TOPRIGHT", 0, 0)
	bTop:SetHeight(2)
	bTop:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1.0)
	fb.bTop = bTop

	local bBottom = fb:CreateTexture(nil, "OVERLAY")
	bBottom:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	bBottom:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", 0, 0)
	bBottom:SetHeight(2)
	bBottom:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1.0)
	fb.bBottom = bBottom

	local bLeft = fb:CreateTexture(nil, "OVERLAY")
	bLeft:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	bLeft:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	bLeft:SetWidth(2)
	bLeft:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1.0)
	fb.bLeft = bLeft

	local bRight = fb:CreateTexture(nil, "OVERLAY")
	bRight:SetPoint("TOPRIGHT", fb, "TOPRIGHT", 0, 0)
	bRight:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", 0, 0)
	bRight:SetWidth(2)
	bRight:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1.0)
	fb.bRight = bRight

	-- Left Accent Docking Socket (4px wide)
	local accent = fb:CreateTexture(nil, "OVERLAY")
	accent:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	accent:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	accent:SetWidth(4)
	accent:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1.0)
	fb.accent = accent

	-- Translucent interior tint (0.05 alpha for crystal-clear readability)
	local inner = fb:CreateTexture(nil, "BACKGROUND")
	inner:SetPoint("TOPLEFT", fb, "TOPLEFT", 2, -2)
	inner:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", -2, 2)
	inner:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.05)
	fb.inner = inner

	fb:Hide()
	focusBox = fb
	return fb
end

local function setFocusBoxColor(r, g, b)
	local fb = getFocusBox(panel)
	fb.bTop:SetColorTexture(r, g, b, 1.0)
	fb.bBottom:SetColorTexture(r, g, b, 1.0)
	fb.bLeft:SetColorTexture(r, g, b, 1.0)
	fb.bRight:SetColorTexture(r, g, b, 1.0)
	fb.accent:SetColorTexture(r, g, b, 1.0)
	fb.inner:SetColorTexture(r, g, b, 0.08)
end

local function highlightWidget(widget, insetX, insetY)
	if not widget or not widget:IsShown() then
		if focusBox then
			focusBox:Hide()
		end
		return
	end

	local fb = getFocusBox(panel)
	fb:ClearAllPoints()
	fb:SetPoint("TOPLEFT", widget, "TOPLEFT", -(insetX or 2), insetY or 2)
	fb:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", insetX or 2, -(insetY or 2))
	fb:Show()
end

-- ── Hardware Controller Detection & Glyphs ────────────────────────────────────

local function detectPadStyle()
	if _G.InputDeviceIconSetManager and _G.InputDeviceIconSetManager.GetActiveInputDeviceIconSet then
		local set = _G.InputDeviceIconSetManager:GetActiveInputDeviceIconSet()
		if set == "Shapes" or set == "Letters" or set == "Reverse" then
			return set
		end
	end

	if C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetDeviceMappedState then
		local id = C_GamePad.GetActiveDeviceID()
		if id then
			local state = C_GamePad.GetDeviceMappedState(id)
			if state then
				if state.labelStyle and state.labelStyle ~= "" and state.labelStyle ~= "Generic" then
					return state.labelStyle
				end
				local name = (state.name or ""):lower()
				if
					name:find("dualsense")
					or name:find("dualshock")
					or name:find("playstation")
					or name:find("sony")
					or name:find("ps5")
					or name:find("ps4")
				then
					return "Shapes"
				elseif
					name:find("switch")
					or name:find("nintendo")
					or name:find("joy%-?con")
					or name:find("pro controller")
				then
					return "Reverse"
				elseif name:find("xbox") or name:find("xinput") or name:find("microsoft") then
					return "Letters"
				end
			end
		end
	end

	if _G.ControllerForever and _G.ControllerForever.RuleBar and _G.ControllerForever.RuleBar.padStyle then
		local s = _G.ControllerForever.RuleBar.padStyle()
		if s == "ps" then
			return "Shapes"
		elseif s == "nintendo" then
			return "Reverse"
		elseif s == "xbox" then
			return "Letters"
		end
	end

	return "Letters"
end

local function getGlyphs()
	local style = detectPadStyle()
	if style == "Shapes" then
		return {
			A = "|A:Gamepad_Shp_Cross_32:14:14:0:-1|a",
			B = "|A:Gamepad_Shp_Circle_32:14:14:0:-1|a",
			X = "|A:Gamepad_Shp_Square_32:14:14:0:-1|a",
			Y = "|A:Gamepad_Shp_Triangle_32:14:14:0:-1|a",
			SHOULDERS = "|A:Gamepad_Shp_LShoulder_32:14:14:0:-1|a/|A:Gamepad_Shp_RShoulder_32:14:14:0:-1|a",
			TRIGGERS = "|A:Gamepad_Shp_LTrigger_32:14:14:0:-1|a/|A:Gamepad_Shp_RTrigger_32:14:14:0:-1|a",
			DPAD = "|A:Gamepad_Gen_Dpad_32:14:14:0:-1|a",
			NAME_X = "Square",
			NAME_A = "Cross",
			NAME_B = "Circle",
		}
	elseif style == "Reverse" then
		return {
			A = "|A:Gamepad_Rev_A_32:14:14:0:-1|a",
			B = "|A:Gamepad_Rev_B_32:14:14:0:-1|a",
			X = "|A:Gamepad_Rev_X_32:14:14:0:-1|a",
			Y = "|A:Gamepad_Rev_Y_32:14:14:0:-1|a",
			SHOULDERS = "|A:Gamepad_Rev_LShoulder_32:14:14:0:-1|a/|A:Gamepad_Rev_RShoulder_32:14:14:0:-1|a",
			TRIGGERS = "|A:Gamepad_Rev_LTrigger_32:14:14:0:-1|a/|A:Gamepad_Rev_RTrigger_32:14:14:0:-1|a",
			DPAD = "|A:Gamepad_Gen_Dpad_32:14:14:0:-1|a",
			NAME_X = "Y",
			NAME_A = "A",
			NAME_B = "B",
		}
	else
		return {
			A = "|A:Gamepad_Ltr_A_32:14:14:0:-1|a",
			B = "|A:Gamepad_Ltr_B_32:14:14:0:-1|a",
			X = "|A:Gamepad_Ltr_X_32:14:14:0:-1|a",
			Y = "|A:Gamepad_Ltr_Y_32:14:14:0:-1|a",
			SHOULDERS = "|A:Gamepad_Ltr_LShoulder_32:14:14:0:-1|a/|A:Gamepad_Ltr_RShoulder_32:14:14:0:-1|a",
			TRIGGERS = "|A:Gamepad_Ltr_LTrigger_32:14:14:0:-1|a/|A:Gamepad_Ltr_RTrigger_32:14:14:0:-1|a",
			DPAD = "|A:Gamepad_Gen_Dpad_32:14:14:0:-1|a",
			NAME_X = "X",
			NAME_A = "A",
			NAME_B = "B",
		}
	end
end

-- ── Content Row & Sub-Target Navigation ───────────────────────────────────────

local function getVisibleRows()
	local rows = {}
	if not panel or not panel.Content or not panel.Content.page then
		return rows
	end
	local pageRows = panel.Content.page.rows
	if not pageRows then
		return rows
	end

	for _, row in ipairs(pageRows) do
		if row:IsShown() and not row.isHeader and not row.isText then
			rows[#rows + 1] = row
		end
	end
	return rows
end

local function getRowSubTargets(row)
	local targets = {}
	if not row then
		return targets
	end

	local hasSub = (type(row.Slider) == "table")
		or (type(row.Dropdown) == "table")
		or (type(row.Play) == "table" and type(row.Play.IsShown) == "function")

	if hasSub then
		-- Cue row with multiple interactive elements on the same horizontal line.
		-- Ordered strictly by visual left-to-right coordinate on screen:
		-- 1. Checkbox / Toggle   (Theme.CUE_CHECK_LEFT = 4)
		-- 2. Intensity Slider     (Theme.CUE_SLIDER_LEFT = 232)
		-- 3. Vibration Mode       (Theme.CUE_DROPDOWN_LEFT = 392)
		-- 4. Try Texture (Play >) (Theme.CUE_PLAY_LEFT = 550)
		if type(row.Control) == "table" and row.Control.IsShown and row.Control:IsShown() then
			targets[#targets + 1] = { kind = "CHECK", widget = row.Control, label = L("Enable Cue") }
		end
		if type(row.Slider) == "table" and row.Slider.IsShown and row.Slider:IsShown() then
			targets[#targets + 1] = { kind = "SLIDER", widget = row.Slider, label = L("Intensity Slider") }
		end
		if type(row.Dropdown) == "table" and row.Dropdown.IsShown and row.Dropdown:IsShown() then
			targets[#targets + 1] = { kind = "DROPDOWN", widget = row.Dropdown, label = L("Vibration Mode") }
		end
		if type(row.Play) == "table" and row.Play.IsShown and row.Play:IsShown() then
			targets[#targets + 1] = { kind = "PLAY", widget = row.Play, label = L("Try Texture") }
		end
	else
		-- Single-control row (e.g. Master Intensity slider, Checkbox, Button)
		local widget = (type(row.Slider) == "table" and row.Slider)
			or (type(row.Dropdown) == "table" and row.Dropdown)
			or (type(row.Button) == "table" and row.Button)
			or (type(row.Control) == "table" and row.Control)
			or row
		local kind = "GENERIC"
		if type(row.Slider) == "table" or (type(row.Control) == "table" and row.Control.OnStepperClicked) then
			kind = "SLIDER"
		elseif type(row.Dropdown) == "table" then
			kind = "DROPDOWN"
		elseif
			type(row.Control) == "table"
			and row.Control.IsObjectType
			and row.Control:IsObjectType("CheckButton")
		then
			kind = "CHECK"
		elseif type(widget) == "table" and widget.IsObjectType and widget:IsObjectType("Button") then
			kind = "BUTTON"
		end
		targets[#targets + 1] = { kind = kind, widget = widget }
	end

	return targets
end

local function ensureRowVisible(row)
	if not row or not panel or not panel.Content or not panel.Content.Scroll then
		return
	end

	local scroll = panel.Content.Scroll
	local scrollChild = panel.Content.Child
	if not scrollChild then
		return
	end

	local rowTop = row:GetTop()
	local rowBottom = row:GetBottom()
	local scrollTop = scroll:GetTop()
	local scrollBottom = scroll:GetBottom()

	if not rowTop or not rowBottom or not scrollTop or not scrollBottom then
		return
	end

	local curScroll = scroll:GetVerticalScroll() or 0
	local maxScroll = scroll:GetVerticalScrollRange() or 0

	if rowTop > scrollTop then
		local diff = rowTop - scrollTop + 10
		local target = math.max(0, curScroll - diff)
		scroll:SetVerticalScroll(target)
	elseif rowBottom < scrollBottom then
		local diff = scrollBottom - rowBottom + 10
		local target = math.min(maxScroll, curScroll + diff)
		scroll:SetVerticalScroll(target)
	end
end

-- ── Lowermost Bar Footer Legend ───────────────────────────────────────────────

local function updateGamepadFooter()
	if not panel or not panel.UpdateGamepadLegend then
		return
	end

	local glyphs = getGlyphs()

	if Panel.Popup and Panel.Popup.IsListOpen and Panel.Popup.IsListOpen() then
		panel.UpdateGamepadLegend(
			string.format(L("%s Browse Modes   •   %s Select   •   %s Cancel"), glyphs.DPAD, glyphs.A, glyphs.B)
		)
		return
	end

	if mode == "SIDEBAR" then
		panel.UpdateGamepadLegend(
			string.format(
				L("%s Switch Category   •   %s Navigate   •   %s Select   •   %s Close"),
				glyphs.SHOULDERS,
				glyphs.DPAD,
				glyphs.A,
				glyphs.B
			)
		)
	elseif mode == "CONTENT" then
		local rows = getVisibleRows()
		local row = rows[currentContentIndex]
		local targets = getRowSubTargets(row)
		local currentTarget = targets[currentSubTargetIndex] or { kind = "GENERIC" }

		if isAdjustingSlider then
			panel.UpdateGamepadLegend(
				string.format(
					L("|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture"),
					glyphs.A,
					glyphs.B,
					glyphs.X
				)
			)
		elseif currentTarget.kind == "CHECK" then
			panel.UpdateGamepadLegend(
				string.format(
					L("%s Toggle   •   |cff38BDF8▶|r Next Control   •   %s Try Texture   •   %s Categories"),
					glyphs.A,
					glyphs.X,
					glyphs.B
				)
			)
		elseif currentTarget.kind == "DROPDOWN" then
			panel.UpdateGamepadLegend(
				string.format(
					L("%s Select Mode   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories"),
					glyphs.A,
					glyphs.X,
					glyphs.B
				)
			)
		elseif currentTarget.kind == "SLIDER" then
			panel.UpdateGamepadLegend(
				string.format(
					L("%s Adjust Intensity   •   %s Quick Step   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories"),
					glyphs.A,
					glyphs.TRIGGERS,
					glyphs.X,
					glyphs.B
				)
			)
		elseif currentTarget.kind == "PLAY" then
			panel.UpdateGamepadLegend(
				string.format(
					L("%s/%s Try Texture   •   |cff38BDF8◀|r Controls   •   %s Categories"),
					glyphs.A,
					glyphs.X,
					glyphs.B
				)
			)
		else
			panel.UpdateGamepadLegend(
				string.format(L("%s Activate   •   %s Try Texture   •   %s Categories"), glyphs.A, glyphs.X, glyphs.B)
			)
		end
	end
end

local function setContentFocus(rowIndex, subIndex)
	local rows = getVisibleRows()
	if #rows == 0 then
		focusedRow = nil
		if focusBox then
			focusBox:Hide()
		end
		updateGamepadFooter()
		return
	end

	if rowIndex < 1 then
		rowIndex = 1
	elseif rowIndex > #rows then
		rowIndex = #rows
	end

	currentContentIndex = rowIndex
	local row = rows[rowIndex]
	focusedRow = row

	local targets = getRowSubTargets(row)
	if #targets == 0 then
		currentSubTargetIndex = 1
		highlightWidget(row, 2, 2)
		ensureRowVisible(row)
		updateGamepadFooter()
		return
	end

	subIndex = subIndex or currentSubTargetIndex or 1
	if subIndex < 1 then
		subIndex = 1
	elseif subIndex > #targets then
		subIndex = #targets
	end
	currentSubTargetIndex = subIndex

	local target = targets[subIndex]
	if isAdjustingSlider and target.kind ~= "SLIDER" then
		isAdjustingSlider = false
		setFocusBoxColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
	end

	if row.ShowRowTooltip then
		row:ShowRowTooltip()
	end

	local widget = target.widget or row
	if target.kind == "CHECK" then
		highlightWidget(widget, 4, 4)
	elseif target.kind == "DROPDOWN" then
		highlightWidget(widget, 4, 4)
	elseif target.kind == "SLIDER" then
		highlightWidget(widget, 4, 4)
		if isAdjustingSlider then
			setFocusBoxColor(1.0, 0.82, 0.20) -- Glowing Gold
		else
			setFocusBoxColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
		end
	elseif target.kind == "PLAY" then
		highlightWidget(widget, 4, 4)
	else
		highlightWidget(widget, 2, 2)
	end

	ensureRowVisible(row)
	if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
	end
	updateGamepadFooter()
end

-- ── Slider Stepping & Haptic Feedback ────────────────────────────────────────

local function stepSlider(row, delta)
	if not row then
		return
	end
	local slider = row.Slider or (row.Control and row.Control.OnStepperClicked and row.Control)
	if not slider then
		return
	end

	if slider.OnStepperClicked then
		pcall(slider.OnStepperClicked, slider, delta > 0)
	end

	local realSlider = slider.Slider or (slider.GetValue and slider)
	if realSlider and realSlider.GetValue and realSlider.SetValue then
		local cur = realSlider:GetValue() or 1.0
		local minVal, maxVal = realSlider:GetMinMaxValues()
		minVal = minVal or 0
		maxVal = maxVal or 1.5
		local step = 0.05
		if row.spec and row.spec.intensity and row.spec.intensity.step then
			step = row.spec.intensity.step
		elseif row.spec and row.spec.step then
			step = row.spec.step
		end
		local nextVal = math.max(minVal, math.min(maxVal, cur + delta * step))
		if slider.SetValue then
			slider:SetValue(nextVal)
		else
			realSlider:SetValue(nextVal)
		end
	end

	-- Live tactile pulse when adjusting so the player feels the new intensity immediately
	if Pulse.TestMode then
		pcall(Pulse.TestMode, Pulse, "TAP", 0.7)
	end
end

-- ── Try Texture Hotkey Execution ─────────────────────────────────────────────

local function tryTexture(row)
	if not row then
		return
	end
	if type(row.Play) == "table" and type(row.Play.Click) == "function" then
		row.Play:Click()
	elseif row.spec and row.spec.test and type(row.spec.test.onClick) == "function" then
		row.spec.test.onClick()
	elseif row.spec and row.spec.testMode and Pulse.TestMode then
		Pulse:TestMode(row.spec.testMode, 0.75)
	elseif type(row.Button) == "table" and type(row.Button.Click) == "function" then
		row.Button:Click()
	end
end

-- ── Sidebar Navigation ───────────────────────────────────────────────────────

local function getSidebarButtons()
	if not panel or not panel.Sidebar or not panel.Sidebar.buttons then
		return {}
	end
	local btns = {}
	for _, b in ipairs(panel.Sidebar.buttons) do
		if b:IsShown() then
			btns[#btns + 1] = b
		end
	end
	return btns
end

local function selectSidebarIndex(index, enterContent)
	local buttons = getSidebarButtons()
	if #buttons == 0 then
		return
	end

	if index < 1 then
		index = #buttons
	elseif index > #buttons then
		index = 1
	end

	currentSidebarIndex = index
	local btn = buttons[index]

	if btn and btn.page then
		panel.Sidebar:Select(btn.page)
		if enterContent then
			mode = "CONTENT"
			setContentFocus(1, 1)
		else
			mode = "SIDEBAR"
			isAdjustingSlider = false
			if focusedRow and focusedRow.HideRowTooltip then
				focusedRow:HideRowTooltip()
				focusedRow = nil
			end
			setFocusBoxColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
			highlightWidget(btn, 0, 0)
			updateGamepadFooter()
		end
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
	end
end

-- ── Input Dispatcher ─────────────────────────────────────────────────────────

local function scrollContent(delta)
	if not panel or not panel.Content or not panel.Content.Scroll then
		return
	end
	local scroll = panel.Content.Scroll
	local cur = scroll:GetVerticalScroll() or 0
	local maxRange = scroll:GetVerticalScrollRange() or 0
	local target = math.max(0, math.min(maxRange, cur + delta))
	scroll:SetVerticalScroll(target)
end

local function handleInput(key)
	if InCombatLockdown and InCombatLockdown() then
		Panel.Close()
		return
	end

	-- 0. Check if Dropdown Popup is open
	if Panel.Popup and Panel.Popup.IsListOpen and Panel.Popup.IsListOpen() then
		if key == "PADDUP" then
			Panel.Popup.NavigateList(-1)
			return
		elseif key == "PADDDOWN" then
			Panel.Popup.NavigateList(1)
			return
		elseif key == "PAD1" then
			Panel.Popup.ConfirmList()
			updateGamepadFooter()
			return
		elseif key == "PAD2" then
			Panel.Popup.CloseList()
			updateGamepadFooter()
			return
		end
	end

	-- 1. Global Bumpers: Tab categories forward/backward
	if key == "PADLSHOULDER" then
		selectSidebarIndex(currentSidebarIndex - 1, mode == "CONTENT")
		return
	elseif key == "PADRSHOULDER" then
		selectSidebarIndex(currentSidebarIndex + 1, mode == "CONTENT")
		return
	end

	-- 2. Quick Setup Shortcut: PADBACK (View / Select)
	if key == "PADBACK" then
		Panel.Close()
		if Pulse.UI and Pulse.UI.QuickSetup and Pulse.UI.QuickSetup.Open then
			Pulse.UI.QuickSetup.Open()
		end
		return
	end

	-- 3. Sidebar Mode
	if mode == "SIDEBAR" then
		if key == "PADDUP" then
			selectSidebarIndex(currentSidebarIndex - 1, false)
		elseif key == "PADDDOWN" then
			selectSidebarIndex(currentSidebarIndex + 1, false)
		elseif key == "PADDRIGHT" or key == "PAD1" then
			mode = "CONTENT"
			setContentFocus(1, 1)
		elseif key == "PAD2" or key == "PADFORWARD" then
			Panel.Close()
		end

	-- 4. Content Mode
	elseif mode == "CONTENT" then
		local rows = getVisibleRows()
		local row = rows[currentContentIndex]
		local targets = getRowSubTargets(row)
		local currentTarget = targets[currentSubTargetIndex] or { kind = "GENERIC", widget = row }

		-- Global Row Hotkey: PAD3 (Square / X) Instant Try Texture
		if key == "PAD3" then
			tryTexture(row)
			return
		end

		-- Global Trigger adjustments for Sliders:
		if (key == "PADLTRIGGER" or key == "PADRTRIGGER") and (currentTarget.kind == "SLIDER" or isAdjustingSlider) then
			stepSlider(row, key == "PADRTRIGGER" and 1 or -1)
			return
		elseif key == "PADLTRIGGER" then
			scrollContent(-120)
			return
		elseif key == "PADRTRIGGER" then
			scrollContent(120)
			return
		end

		-- Vertical Navigation
		if key == "PADDUP" then
			if isAdjustingSlider then
				isAdjustingSlider = false
			end
			setContentFocus(currentContentIndex - 1, currentSubTargetIndex)
			return
		elseif key == "PADDDOWN" then
			if isAdjustingSlider then
				isAdjustingSlider = false
			end
			setContentFocus(currentContentIndex + 1, currentSubTargetIndex)
			return
		end

		-- Horizontal Navigation / Slider Stepping
		if key == "PADDLEFT" then
			if isAdjustingSlider then
				stepSlider(row, -1)
				return
			elseif currentSubTargetIndex > 1 then
				setContentFocus(currentContentIndex, currentSubTargetIndex - 1)
				return
			else
				-- On leftmost target: return to sidebar
				mode = "SIDEBAR"
				selectSidebarIndex(currentSidebarIndex, false)
				return
			end
		elseif key == "PADDRIGHT" then
			if isAdjustingSlider then
				stepSlider(row, 1)
				return
			elseif currentSubTargetIndex < #targets then
				setContentFocus(currentContentIndex, currentSubTargetIndex + 1)
				return
			end
		end

		-- Activation (A / PAD1)
		if key == "PAD1" then
			if currentTarget.kind == "CHECK" then
				if type(row.Control) == "table" and row.Control.Click then
					row.Control:Click()
				end
			elseif currentTarget.kind == "DROPDOWN" then
				if
					type(currentTarget.widget) == "table"
					and currentTarget.widget.GetScript
					and currentTarget.widget:GetScript("OnMouseDown")
				then
					currentTarget.widget:GetScript("OnMouseDown")(currentTarget.widget)
				elseif type(currentTarget.widget) == "table" and currentTarget.widget.Click then
					currentTarget.widget:Click()
				end
				updateGamepadFooter()
			elseif currentTarget.kind == "SLIDER" then
				isAdjustingSlider = not isAdjustingSlider
				if isAdjustingSlider then
					setFocusBoxColor(1.0, 0.82, 0.20) -- Glowing Gold
					if Pulse.TestMode then
						Pulse:TestMode("TAP", 0.7)
					end
				else
					setFocusBoxColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
					if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
						PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
					end
				end
				updateGamepadFooter()
			elseif currentTarget.kind == "PLAY" then
				tryTexture(row)
			elseif currentTarget.kind == "BUTTON" then
				if type(currentTarget.widget) == "table" and currentTarget.widget.Click then
					currentTarget.widget:Click()
				end
			end
			return
		end

		-- Return (B / PAD2)
		if key == "PAD2" then
			if isAdjustingSlider then
				isAdjustingSlider = false
				setFocusBoxColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
				updateGamepadFooter()
				return
			else
				mode = "SIDEBAR"
				selectSidebarIndex(currentSidebarIndex, false)
				return
			end
		end

		-- Start/Menu button closes panel
		if key == "PADFORWARD" then
			Panel.Close()
			return
		end
	end
end

-- ── Bindings & Lifecycle ─────────────────────────────────────────────────────

local function releaseCaptureKeys(owner)
	if not owner or not ClearOverrideBindings then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		pendingCaptureCleanup = owner
		return
	end
	ClearOverrideBindings(owner)
	if pendingCaptureCleanup == owner then
		pendingCaptureCleanup = nil
	end
end

function Gamepad.OnShow()
	if not panel or not panel:IsShown() then
		return
	end

	mode = "SIDEBAR"
	currentSidebarIndex = 1
	currentContentIndex = 1
	currentSubTargetIndex = 1
	isAdjustingSlider = false
	focusedRow = nil

	if panel.EnableGamePadButton then
		pcall(panel.EnableGamePadButton, panel, true)
	end

	panel:SetScript("OnGamePadButtonDown", function(_, key)
		handleInput(key)
	end)

	releaseCaptureKeys(panel)
	selectSidebarIndex(1, false)
end

function Gamepad.OnHide()
	isAdjustingSlider = false
	if focusBox then
		focusBox:Hide()
	end
	if focusedRow and focusedRow.HideRowTooltip then
		focusedRow:HideRowTooltip()
		focusedRow = nil
	end
	if panel then
		releaseCaptureKeys(panel)
		if panel.EnableGamePadButton then
			panel:EnableGamePadButton(false)
		end
		if panel.UpdateGamepadLegend then
			panel.UpdateGamepadLegend("")
		end
	end
	if Panel.Popup and Panel.Popup.IsListOpen and Panel.Popup.IsListOpen() then
		Panel.Popup.CloseList()
	end
end

function Gamepad.RefreshNavigation()
	if mode == "CONTENT" then
		setContentFocus(currentContentIndex, currentSubTargetIndex)
	end
end

function Gamepad.Setup() end

function Gamepad.Init(owner)
	panel = owner
	owner:RegisterEvent("PLAYER_REGEN_ENABLED")
	owner:HookScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" and pendingCaptureCleanup then
			releaseCaptureKeys(pendingCaptureCleanup)
		end
	end)
end
