-- Pulse — UI/Panel/Gamepad.lua
--
-- Safe, native controller navigation for Pulse's main settings panel.
--
-- Architecture:
--   - Two focus contexts: "SIDEBAR" (category list) and "CONTENT" (settings rows).
--   - D-Pad UP/DOWN moves focus; D-Pad RIGHT or A enters content; D-Pad LEFT or B returns to sidebar.
--   - Bumpers (LB/RB) switch categories smoothly from anywhere.
--   - Triggers (LT/RT) scroll the content frame.
--   - Sliders claim D-Pad LEFT/RIGHT to step values by their own precision.
--   - Auto-scrolling: Ensures the focused row is always cleanly visible in the ScrollFrame.
--   - Taint-free execution: Uses EnableGamePadButton and window-owned override bindings out of combat.
--     Clears cleanly on OnHide and closes instantly on combat start (PLAYER_REGEN_DISABLED).

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel
local Theme = Panel.Theme

local Gamepad = {}
Panel.Gamepad = Gamepad

local panel -- reference to PulsePanel
local captureButton -- invisible button owned by panel for override binding capture
local focusBox -- visual focus reticle
local mode = "SIDEBAR" -- "SIDEBAR" or "CONTENT"
local currentSidebarIndex = 1
local currentContentIndex = 1
local focusedRow = nil

local GAMEPAD_KEYS = {
	"PAD1",
	"PAD2",
	"PAD3",
	"PAD4",
	"PADLSHOULDER",
	"PADRSHOULDER",
	"PADLTRIGGER",
	"PADRTRIGGER",
	"PADDUP",
	"PADDDOWN",
	"PADDLEFT",
	"PADDRIGHT",
	"PADFORWARD",
	"PADBACK",
}

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

	-- 2px Radiant Cyan Border
	local border = fb:CreateTexture(nil, "BORDER")
	border:SetAllPoints(fb)
	border:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.85)
	fb.border = border

	-- Inner cut-out
	local inner = fb:CreateTexture(nil, "ARTWORK")
	inner:SetPoint("TOPLEFT", fb, "TOPLEFT", 1.5, -1.5)
	inner:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", -1.5, 1.5)
	inner:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.08)
	fb.inner = inner

	fb:Hide()
	focusBox = fb
	return fb
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

-- ── Content Row Navigation ───────────────────────────────────────────────────

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
		-- Row is above visible view: scroll up
		local diff = rowTop - scrollTop + 10
		local target = math.max(0, curScroll - diff)
		scroll:SetVerticalScroll(target)
	elseif rowBottom < scrollBottom then
		-- Row is below visible view: scroll down
		local diff = scrollBottom - rowBottom + 10
		local target = math.min(maxScroll, curScroll + diff)
		scroll:SetVerticalScroll(target)
	end
end

local function setContentFocus(index)
	local rows = getVisibleRows()
	if #rows == 0 then
		focusedRow = nil
		if focusBox then
			focusBox:Hide()
		end
		return
	end

	if index < 1 then
		index = 1
	elseif index > #rows then
		index = #rows
	end

	currentContentIndex = index

	if focusedRow and focusedRow.HideRowTooltip then
		focusedRow:HideRowTooltip()
	end

	local row = rows[index]
	focusedRow = row

	if row then
		if row.ShowRowTooltip then
			row:ShowRowTooltip()
		end
		highlightWidget(row, 2, 2)
		ensureRowVisible(row)
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end
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
			setContentFocus(1)
		else
			mode = "SIDEBAR"
			if focusedRow and focusedRow.HideRowTooltip then
				focusedRow:HideRowTooltip()
				focusedRow = nil
			end
			highlightWidget(btn, 0, 0)
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

	-- Global Bumpers: Tab categories forward/backward
	if key == "PADLSHOULDER" then
		selectSidebarIndex(currentSidebarIndex - 1, mode == "CONTENT")
		return
	elseif key == "PADRSHOULDER" then
		selectSidebarIndex(currentSidebarIndex + 1, mode == "CONTENT")
		return
	end

	-- Global Triggers: Scroll content
	if key == "PADLTRIGGER" then
		scrollContent(-120)
		return
	elseif key == "PADRTRIGGER" then
		scrollContent(120)
		return
	end

	-- Quick Setup Shortcut: PADBACK (Select / View)
	if key == "PADBACK" then
		Panel.Close()
		if Pulse.UI and Pulse.UI.QuickSetup and Pulse.UI.QuickSetup.Open then
			Pulse.UI.QuickSetup.Open()
		end
		return
	end

	if mode == "SIDEBAR" then
		if key == "PADDUP" then
			selectSidebarIndex(currentSidebarIndex - 1, false)
		elseif key == "PADDDOWN" then
			selectSidebarIndex(currentSidebarIndex + 1, false)
		elseif key == "PADDRIGHT" or key == "PAD1" then
			-- Enter content area
			mode = "CONTENT"
			setContentFocus(1)
		elseif key == "PAD2" or key == "PADFORWARD" then
			Panel.Close()
		end
	elseif mode == "CONTENT" then
		local rows = getVisibleRows()
		local row = rows[currentContentIndex]

		if key == "PADDUP" then
			setContentFocus(currentContentIndex - 1)
		elseif key == "PADDDOWN" then
			setContentFocus(currentContentIndex + 1)
		elseif key == "PADDLEFT" then
			-- If on a slider, step the slider down; otherwise return to sidebar
			if row and row.Control and row.Control.OnStepperClicked then
				row.Control:OnStepperClicked(false)
			elseif row and row.Control and (row.Control.DecrementButton or row.Control.Decrement) then
				if row.Control.DecrementButton then
					row.Control.DecrementButton:Click()
				else
					row.Control:Decrement()
				end
			else
				mode = "SIDEBAR"
				selectSidebarIndex(currentSidebarIndex, false)
			end
		elseif key == "PADDRIGHT" then
			-- If on a slider or dropdown, step up
			if row and row.Control and row.Control.OnStepperClicked then
				row.Control:OnStepperClicked(true)
			elseif row and row.Control and (row.Control.IncrementButton or row.Control.Increment) then
				if row.Control.IncrementButton then
					row.Control.IncrementButton:Click()
				else
					row.Control:Increment()
				end
			end
		elseif key == "PAD1" then
			-- A button: Activate the control
			if row then
				if row.Control and row.Control:IsObjectType("CheckButton") then
					row.Control:Click()
				elseif row.Button and row.Button:IsObjectType("Button") then
					row.Button:Click()
				elseif row.Control and row.Control:IsObjectType("Button") then
					row.Control:Click()
				elseif row.spec and row.spec.testMode and Pulse.TestMode then
					Pulse:TestMode(row.spec.testMode, 0.75)
				end
			end
		elseif key == "PAD2" then
			-- B button: Return to sidebar
			mode = "SIDEBAR"
			selectSidebarIndex(currentSidebarIndex, false)
		elseif key == "PADFORWARD" then
			Panel.Close()
		end
	end
end

-- ── Bindings & Lifecycle ─────────────────────────────────────────────────────

local function bindCaptureKeys(owner)
	if InCombatLockdown and InCombatLockdown() then
		return
	end
	if not captureButton then
		captureButton = CreateFrame("Button", "PulsePanelCaptureButton", UIParent)
		captureButton:SetSize(1, 1)
		captureButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
		captureButton:RegisterForClicks("AnyDown")
		captureButton:SetScript("OnClick", function(_, _, down)
			if down and captureButton.currentKey then
				handleInput(captureButton.currentKey)
			end
		end)
	end

	if ClearOverrideBindings then
		ClearOverrideBindings(owner)
	end

	for _, key in ipairs(GAMEPAD_KEYS) do
		if SetOverrideBindingClick then
			SetOverrideBindingClick(owner, true, key, captureButton:GetName(), "LeftButton")
		end
	end
end

local function releaseCaptureKeys(owner)
	if ClearOverrideBindings then
		pcall(ClearOverrideBindings, owner)
	end
end

function Gamepad.OnShow()
	if not panel or not panel:IsShown() then
		return
	end

	mode = "SIDEBAR"
	currentSidebarIndex = 1
	currentContentIndex = 1
	focusedRow = nil

	-- Hook native gamepad button events on the frame
	if panel.EnableGamePadButton then
		pcall(panel.EnableGamePadButton, panel, true)
	end

	panel:SetScript("OnGamePadButtonDown", function(_, key)
		handleInput(key)
	end)

	bindCaptureKeys(panel)
	selectSidebarIndex(1, false)
end

function Gamepad.OnHide()
	if focusBox then
		focusBox:Hide()
	end
	if focusedRow and focusedRow.HideRowTooltip then
		focusedRow:HideRowTooltip()
		focusedRow = nil
	end
	if panel then
		releaseCaptureKeys(panel)
	end
end

function Gamepad.RefreshNavigation()
	if mode == "CONTENT" then
		setContentFocus(currentContentIndex)
	end
end

function Gamepad.Setup() end

function Gamepad.Init(owner)
	panel = owner
end
