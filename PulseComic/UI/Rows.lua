-- PulseComic — UI/Rows.lua
--
-- One constructor per kind of settings row, ported from PulseHaptics' UI/Panel/Rows.lua and
-- cut down to what this window needs: header, checkbox, choice (a button that cycles its
-- values) and a row of buttons. Rows are built once and live for the session; no pooling.
--
-- Every row exposes:
--   row.rowHeight        vertical space it wants
--   row:RefreshValue()   re-read the setting and update the widget
--   row:SetRowEnabled(b) grey out / restore

local _, ns = ...

local Theme = ns.ui.Theme

local Rows = {}
ns.ui.Rows = Rows

-- ── Shared scaffolding ────────────────────────────────────────────────────────────────

local function showHover(row, owner)
	row.HoverBackground:Show()
	row.HoverPip:Show()
	Theme.ShowTooltip(owner or row, row.spec.label, row.spec.tooltip)
end

local function hideHover(row)
	row.HoverBackground:Hide()
	row.HoverPip:Hide()
	Theme.HideTooltip()
end

-- The label, the hover wash and pip, and an invisible hit area over the label column that
-- owns the tooltip.
local function createBaseRow(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(Theme.ROW_HEIGHT)
	row.rowHeight = Theme.ROW_HEIGHT
	row.spec = spec

	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Text:SetJustifyH("LEFT")
	row.Text:SetWordWrap(false)
	row.Text:SetPoint("LEFT", row, "LEFT", Theme.TEXT_LEFT, 0)
	row.Text:SetPoint("RIGHT", row, "LEFT", Theme.CONTROL_LEFT - 10, 0)
	row.Text:SetText(spec.label or "")
	row.Text:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)

	row.HoverBackground = Theme.CreateHoverBackground(row)

	local pip = row:CreateTexture(nil, "OVERLAY")
	pip:SetSize(2, 16)
	pip:SetPoint("LEFT", row, "LEFT", 14, 0)
	pip:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.9)
	pip:Hide()
	row.HoverPip = pip

	local hit = CreateFrame("Frame", nil, row)
	hit:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	hit:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", Theme.CONTROL_LEFT - 4, 0)
	hit:EnableMouse(true)
	hit:SetScript("OnEnter", function()
		showHover(row)
	end)
	hit:SetScript("OnLeave", function()
		hideHover(row)
	end)
	row.Hit = hit

	return row
end

local function attachControlTooltip(row, control)
	control:HookScript("OnEnter", function()
		showHover(row, control)
	end)
	control:HookScript("OnLeave", function()
		hideHover(row)
	end)
end

-- ── Section header ────────────────────────────────────────────────────────────────────

function Rows.CreateHeader(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(Theme.HEADER_ROW_H)
	row.rowHeight = Theme.HEADER_ROW_H
	row.spec = spec

	row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	row.Title:SetJustifyH("LEFT")
	row.Title:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -14)
	row.Title:SetText(spec.label or "")

	local rule = row:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
	rule:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	rule:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.25)

	row.RefreshValue = function()
		if spec.labelFunc then
			row.Title:SetText(spec.labelFunc())
		end
	end
	row.SetRowEnabled = function() end
	row:RefreshValue()
	return row
end

-- ── Checkbox ──────────────────────────────────────────────────────────────────────────
-- spec: label, tooltip, get() -> bool, set(bool)

function Rows.CreateCheckbox(parent, spec)
	local row = createBaseRow(parent, spec)

	local box = CreateFrame("CheckButton", nil, row)
	box:SetSize(Theme.CHECKBOX_SIZE_X, Theme.CHECKBOX_SIZE_Y)
	box:SetPoint("LEFT", row, "LEFT", Theme.CONTROL_LEFT, 0)
	box:SetMotionScriptsWhileDisabled(true)
	box:SetNormalAtlas("checkbox-minimal")
	box:SetPushedAtlas("checkbox-minimal")
	box:SetCheckedTexture("checkmark-minimal")
	box:SetDisabledCheckedTexture("checkmark-minimal-disabled")

	box:SetScript("OnClick", function(self)
		local value = self:GetChecked() and true or false
		Theme.PlayCheckSound(value)
		spec.set(value)
		-- Show whatever the setting actually holds now.
		row:RefreshValue()
	end)
	box:SetScript("OnEnter", function()
		showHover(row, box)
	end)
	box:SetScript("OnLeave", function()
		hideHover(row)
	end)

	-- Clicking the label toggles the box, as Blizzard's rows do.
	row.Hit:SetScript("OnMouseUp", function()
		if box:IsEnabled() then
			box:Click()
		end
	end)

	row.Control = box
	row.RefreshValue = function()
		if spec.labelFunc then
			row.Text:SetText(spec.labelFunc())
		end
		box:SetChecked(spec.get() and true or false)
	end
	row.SetRowEnabled = function(_, enabled)
		box:SetEnabled(enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	row:RefreshValue()
	return row
end

-- ── Choice ────────────────────────────────────────────────────────────────────────────
-- spec: label, tooltip, choices = { { value, text }, ... }, get() -> value, set(value)
-- A button showing the current choice; each click moves to the next one.

function Rows.CreateChoice(parent, spec)
	local row = createBaseRow(parent, spec)

	local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	button:SetSize(Theme.BUTTON_WIDTH, 22)
	button:SetPoint("LEFT", row, "LEFT", Theme.CONTROL_LEFT, 0)
	Theme.StyleActionButton(button, false)

	local function currentIndex()
		local value = spec.get()
		for i, choice in ipairs(spec.choices) do
			if choice[1] == value then
				return i
			end
		end
		return nil
	end

	button:SetScript("OnClick", function()
		local nextIndex = ((currentIndex() or 0) % #spec.choices) + 1
		Theme.PlayCheckSound(true)
		spec.set(spec.choices[nextIndex][1])
		row:RefreshValue()
	end)
	attachControlTooltip(row, button)

	row.Control = button
	row.RefreshValue = function()
		local i = currentIndex()
		button:SetText(i and spec.choices[i][2] or tostring(spec.get()))
	end
	row.SetRowEnabled = function(_, enabled)
		button:SetEnabled(enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	row:RefreshValue()
	return row
end

-- ── Buttons ───────────────────────────────────────────────────────────────────────────
-- spec: label, tooltip, buttons = { { text, onClick }, ... }

function Rows.CreateButtons(parent, spec)
	local row = createBaseRow(parent, spec)
	local width = math.floor((Theme.COLUMN_WIDTH - 20 - (Theme.CONTROL_LEFT - 100)) / #spec.buttons) - 6
	row.Text:SetPoint("RIGHT", row, "LEFT", Theme.CONTROL_LEFT - 110, 0)
	row.Hit:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", Theme.CONTROL_LEFT - 114, 0)

	local buttons = {}
	local previous
	for i, entry in ipairs(spec.buttons) do
		local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		button:SetSize(width, 22)
		if previous then
			button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
		else
			button:SetPoint("LEFT", row, "LEFT", Theme.CONTROL_LEFT - 100, 0)
		end
		button:SetText(entry[1])
		Theme.StyleActionButton(button, true)
		button:SetScript("OnClick", entry[2])
		attachControlTooltip(row, button)
		buttons[i] = button
		previous = button
	end

	row.Buttons = buttons
	row.RefreshValue = function() end
	row.SetRowEnabled = function(_, enabled)
		for _, button in ipairs(buttons) do
			button:SetEnabled(enabled)
		end
		Theme.DisplayEnabled(row, enabled)
	end
	return row
end

-- ── Dropdown ──────────────────────────────────────────────────────────────────────────
-- spec: label, tooltip, get() -> value, set(value), text(value) -> shown text,
--       build(rootDescription, isSelected, setSelected) fills the menu (Blizzard_Menu).

function Rows.CreateDropdown(parent, spec)
	local row = createBaseRow(parent, spec)

	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(spec.width or Theme.DROPDOWN_WIDTH)
	dropdown:SetPoint("LEFT", row, "LEFT", Theme.CONTROL_LEFT, 0)

	local function isSelected(value)
		return spec.get() == value
	end
	local function setSelected(value)
		spec.set(value)
		row:RefreshValue()
	end
	dropdown:SetupMenu(function(_, rootDescription)
		spec.build(rootDescription, isSelected, setSelected)
	end)
	attachControlTooltip(row, dropdown)

	row.Control = dropdown
	row.RefreshValue = function()
		if spec.labelFunc then
			row.Text:SetText(spec.labelFunc())
		end
		dropdown:OverrideText(spec.text(spec.get()))
	end
	row.SetRowEnabled = function(_, enabled)
		dropdown:SetEnabled(enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	row:RefreshValue()
	return row
end

-- ── Text entry ────────────────────────────────────────────────────────────────────────
-- spec: label, tooltip, get() -> text, set(text) on Enter or when focus leaves,
--       width, maxLetters (0: unlimited), noCommitOnBlur.

function Rows.CreateEdit(parent, spec)
	local row = createBaseRow(parent, spec)

	local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	box:SetSize(spec.width or Theme.EDIT_WIDTH, 20)
	box:SetPoint("LEFT", row, "LEFT", Theme.CONTROL_LEFT + 6, 0)
	box:SetAutoFocus(false)
	box:SetMaxLetters(spec.maxLetters or 120)

	local function commit()
		if spec.set then
			spec.set(box:GetText())
		end
	end
	box:SetScript("OnEnterPressed", function(self)
		commit()
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		row:RefreshValue()
	end)
	box:HookScript("OnEditFocusLost", function()
		if not spec.noCommitOnBlur then
			commit()
		end
	end)
	attachControlTooltip(row, box)

	row.Box = box
	row.RefreshValue = function()
		if spec.labelFunc then
			row.Text:SetText(spec.labelFunc())
		end
		if spec.get and not box:HasFocus() then
			box:SetText(spec.get() or "")
			box:SetCursorPosition(0)
		end
	end
	row.SetRowEnabled = function(_, enabled)
		box:SetEnabled(enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	row:RefreshValue()
	return row
end

-- ── Note ──────────────────────────────────────────────────────────────────────────────
-- spec: textFunc() -> text (or label for fixed text). A line of small print, no control.

function Rows.CreateNote(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(Theme.ROW_HEIGHT)
	row.rowHeight = Theme.ROW_HEIGHT
	row.spec = spec

	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.Text:SetJustifyH("LEFT")
	row.Text:SetPoint("LEFT", row, "LEFT", Theme.TEXT_LEFT, 0)
	row.Text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	row.Text:SetTextColor(Theme.COLOR_TEXT_MUTED.r, Theme.COLOR_TEXT_MUTED.g, Theme.COLOR_TEXT_MUTED.b)

	row.RefreshValue = function()
		row.Text:SetText(spec.textFunc and spec.textFunc() or spec.label or "")
	end
	row.SetRowEnabled = function() end
	row:RefreshValue()
	return row
end

-- ── Dispatcher ────────────────────────────────────────────────────────────────────────

local BUILDERS = {
	header = Rows.CreateHeader,
	checkbox = Rows.CreateCheckbox,
	choice = Rows.CreateChoice,
	buttons = Rows.CreateButtons,
	dropdown = Rows.CreateDropdown,
	edit = Rows.CreateEdit,
	note = Rows.CreateNote,
}

function Rows.Create(parent, spec)
	return BUILDERS[spec.type](parent, spec)
end
