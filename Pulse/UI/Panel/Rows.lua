-- Pulse — UI/Panel/Rows.lua
--
-- One constructor per kind of settings row, each returning a finished, permanent frame.
--
-- Deliberately plain: a row is created, wired to its get/set closures, and lives until
-- logout. No Init, no Release, no element data, no pool — the three pieces of Blizzard's
-- row contract that exist only because its rows are recycled. Nothing here can be handed a
-- different setting later, so nothing here can hold a stale one.
--
-- The widgets INSIDE a row are Blizzard's, which is what makes the result look native:
-- MinimalSliderWithSteppersTemplate, the settings dropdown with its stepper arrows,
-- UIPanelButtonTemplate, the checkbox atlases. Those are widget templates from
-- Blizzard_SharedXML — inert artwork and geometry, not the Settings framework's lifecycle.
-- Borrowing a slider is not borrowing the panel that kept recycling it.
--
-- WHICH FRAME TYPE A ROW IS, AND WHY IT MATTERS. SmartNavigation picks its target by
-- walking the panel and taking anything that is a Button or EditBox, has a mouse script, or
-- was explicitly marked focusable (Blizzard_GamepadSmartNavigation/Utility.lua:191-200),
-- then calls SetHighlightLocked on it (SmartNavigation.lua:506, :518).
--
--   * A checkbox row and a button row are plain Frames, and the widget inside them is the
--     navigation target — the same shape Blizzard uses, and the inner widget is a real
--     Button so SetHighlightLocked is always there.
--   * A slider row and a dropdown row are Buttons themselves, with the inner control
--     marked ignored, so the stick lands on the whole row rather than one of the three
--     sub-widgets a slider is made of. Blizzard marks a Frame focusable instead; a real
--     Button gets the same navigation with no question about whether SetHighlightLocked
--     exists on what is being highlighted.
--
-- Every row exposes the same four things to Content.lua:
--   row.rowHeight        how much vertical space it wants
--   row.searchText       lowercased label + tooltip, for the search box
--   row:RefreshValue()   re-read the database and update the widget
--   row:SetRowEnabled(b) grey out / restore, including gamepad reachability

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel
local Theme = Panel.Theme

local Rows = {}
Panel.Rows = Rows

-- ── Shared row scaffolding ────────────────────────────────────────────────────

-- Blizzard_SettingControls.lua:449-452 — the gamepad cursor sits off the row's left edge
-- rather than on top of the control it is pointing at.
local function setCursorAnchor(row, control)
    if type(SmartNavigation_SetCustomCursorAnchorPointForFrame) ~= "function" then
        return
    end
    if type(CreateAnchor) ~= "function" then
        return
    end
    local ok, anchor = pcall(CreateAnchor, "RIGHT", row, "LEFT", 30)
    if ok and anchor then
        pcall(SmartNavigation_SetCustomCursorAnchorPointForFrame, control, anchor)
    end
end

-- The label, the hover wash, and for Frame rows the invisible hit area owning the tooltip.
-- Copied from SettingsListElementTemplate (Blizzard_SettingControls.xml:45-79), including
-- the odd BOTTOMRIGHT-relative-to-BOTTOM anchor that makes the tooltip region cover the
-- label column but stop short of the control.
local function createBaseRow(parent, spec, frameType)
    local row = CreateFrame(frameType or "Frame", nil, parent)
    row:SetHeight(Theme.ROW_HEIGHT)
    row.rowHeight = Theme.ROW_HEIGHT
    row.spec = spec

    local indent = spec.child and Theme.INDENT or 0

    row.Text = row:CreateFontString(nil, "OVERLAY", spec.child and Theme.FONT_CHILD or Theme.FONT_NORMAL)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)
    row.Text:SetPoint("LEFT", row, "LEFT", indent + Theme.TEXT_LEFT, 0)
    row.Text:SetPoint("RIGHT", row, "CENTER", Theme.TEXT_RIGHT, 0)
    row.Text:SetText(spec.label or "")

    row.HoverBackground = Theme.CreateHoverBackground(row)

    row.ShowRowTooltip = function()
        row.HoverBackground:Show()
        Theme.ShowTooltip(row, spec.label, spec.tooltip)
    end
    row.HideRowTooltip = function()
        row.HoverBackground:Hide()
        Theme.HideTooltip()
    end

    if frameType == "Button" then
        -- The row IS the navigation target, so hover and tooltip belong on it directly; a
        -- second hit-area frame would only fight it for OnLeave.
        row:SetScript("OnEnter", row.ShowRowTooltip)
        row:SetScript("OnLeave", row.HideRowTooltip)
    else
        local hit = CreateFrame("Frame", nil, row)
        hit:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        hit:SetPoint("BOTTOMRIGHT", row, "BOTTOM", -80, 0)
        hit:EnableMouse(true)
        hit:SetScript("OnEnter", row.ShowRowTooltip)
        hit:SetScript("OnLeave", row.HideRowTooltip)
        -- Blizzard_SettingControls.lua:355: this frame has mouse scripts, so
        -- SmartNavigation_CanFocusFrame would treat it as a button. It is a label.
        Theme.MarkIgnored(hit)
        row.Hit = hit
    end

    row.searchText = string.lower((spec.label or "") .. " " .. (spec.tooltip or ""))

    return row
end

-- Attaches the tooltip to a control as well as to the label, so hovering the slider or the
-- dropdown says the same thing as hovering its name.
local function attachControlTooltip(row, control, spec)
    if not control or not control.HookScript then
        return
    end
    control:HookScript("OnEnter", function()
        Theme.ShowTooltip(control, spec.label, spec.tooltip)
    end)
    control:HookScript("OnLeave", Theme.HideTooltip)
end

-- ── Section header ────────────────────────────────────────────────────────────

-- 45px, GameFontHighlightLarge, TOPLEFT 7,-16 — SettingsListSectionHeaderTemplate
-- (Blizzard_SettingControls.xml:13-23) to the pixel. No NewFeature badge, no tooltip mixin,
-- no navigation presence: a heading is a line of text. The retired UI/SectionHeader.lua
-- existed to work around a Settings-framework bug in exactly this spot; here the frame is
-- never pooled and never has to clean up after itself, so no workaround is needed.
function Rows.CreateHeader(parent, spec)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(Theme.HEADER_ROW_H)
    row.rowHeight = Theme.HEADER_ROW_H
    row.spec = spec
    row.isHeader = true

    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    row.Title:SetJustifyH("LEFT")
    row.Title:SetJustifyV("TOP")
    row.Title:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -16)
    row.Title:SetText(spec.label or "")

    local rule = row:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
    rule:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    rule:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.25)

    row.searchText = string.lower(spec.label or "")
    Theme.MarkIgnored(row)

    row.RefreshValue = function() end
    row.SetRowEnabled = function() end

    return row
end

-- ── Free-text block (the Guide page) ──────────────────────────────────────────

-- The one row that is not a control. Height depends on the wrapped text, so Content.lua
-- calls MeasureHeight once the real width is known rather than fixing it here.
function Rows.CreateText(parent, spec)
    local row = CreateFrame("Frame", nil, parent)
    row.spec = spec
    row.isText = true
    row.rowHeight = 1

    row.Body = row:CreateFontString(nil, "OVERLAY", spec.font or "GameFontHighlight")
    row.Body:SetJustifyH("LEFT")
    row.Body:SetSpacing(2)
    -- One corner only, width set explicitly in MeasureHeight. A FontString deriving its
    -- width from two anchors has not necessarily resolved it by the time GetStringHeight is
    -- asked, which is how a wrapped paragraph comes out one line tall on the first pass.
    row.Body:SetPoint("TOPLEFT", row, "TOPLEFT", Theme.TEXT_LEFT, 0)

    -- `body` may be a function, for a paragraph that reports state rather than stating a
    -- fact — the profiles page's "which rule is in force" line is the reason this exists.
    local function currentBody()
        if type(spec.body) == "function" then
            return spec.body() or ""
        end
        return spec.body or ""
    end
    row.Body:SetText(currentBody())

    -- currentBody(), not spec.body: a live paragraph is a function and concatenating one
    -- errors. Search matches the text as it read when the page was built, which is all a
    -- search index can honestly promise about a string that changes.
    row.searchText = string.lower((spec.label or "") .. " " .. currentBody())
    Theme.MarkIgnored(row)

    row.MeasureHeight = function()
        local available = (row:GetWidth() or 0) - Theme.TEXT_LEFT - 20
        if available > 1 then
            row.Body:SetWidth(available)
        end
        local height = row.Body:GetStringHeight()
        if not height or height < 1 then
            height = 1
        end
        row.rowHeight = height + (spec.gap or 4)
        row:SetHeight(row.rowHeight)
        return row.rowHeight
    end

    row.RefreshValue = function()
        if type(spec.body) ~= "function" then
            return
        end
        local text = currentBody()
        -- No relayout needed: every caller of RefreshRows follows it with LayoutRows,
        -- which re-measures text rows itself. Setting the string is enough.
        if text ~= row.Body:GetText() then
            row.Body:SetText(text)
        end
    end
    row.SetRowEnabled = function() end

    return row
end

-- ── Checkbox ──────────────────────────────────────────────────────────────────

-- Hand-rolled from the same four atlases SettingsCheckboxTemplate uses
-- (Blizzard_SettingControls.xml:82-101) rather than inheriting it. Five lines either way,
-- and this way the row owes nothing to the Settings addon.
function Rows.CreateCheckbox(parent, spec)
    local row = createBaseRow(parent, spec, "Frame")

    local box = CreateFrame("CheckButton", nil, row)
    box:SetSize(Theme.CHECKBOX_SIZE_X, Theme.CHECKBOX_SIZE_Y)
    box:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT, 0)
    box:SetMotionScriptsWhileDisabled(true)
    box:SetNormalAtlas("checkbox-minimal")
    box:SetPushedAtlas("checkbox-minimal")
    box:SetCheckedTexture("checkmark-minimal")
    box:SetDisabledCheckedTexture("checkmark-minimal-disabled")

    box:SetScript("OnClick", function(self)
        local value = self:GetChecked() and true or false
        Theme.PlayCheckSound(value)
        spec.set(value)
        -- The store may refuse or clamp; show whatever it actually holds now.
        self:SetChecked(spec.get() and true or false)
    end)

    box:SetScript("OnEnter", function()
        row.HoverBackground:Show()
        Theme.ShowTooltip(box, spec.label, spec.tooltip)
    end)
    box:SetScript("OnLeave", function()
        row.HoverBackground:Hide()
        Theme.HideTooltip()
    end)

    -- Clicking the label toggles the box, exactly as Blizzard's rows do
    -- (Blizzard_SettingControls.lua:596-600).
    row.Hit:SetScript("OnMouseUp", function()
        if box:IsEnabled() then
            box:Click()
        end
    end)

    setCursorAnchor(row, box)
    if type(SmartNavigation_AddIgnoreInputNavigationOverride) == "function" and SMART_NAV_INPUT_DIRECTION then
        pcall(SmartNavigation_AddIgnoreInputNavigationOverride, box, SMART_NAV_INPUT_DIRECTION.RIGHT)
    end

    row.Control = box
    row.RefreshValue = function()
        box:SetChecked(spec.get() and true or false)
    end
    row.SetRowEnabled = function(_, enabled)
        box:SetEnabled(enabled)
        Theme.DisplayEnabled(row, enabled)
    end

    row:RefreshValue()
    return row
end

-- ── Slider ────────────────────────────────────────────────────────────────────

-- Formats the number under the slider handle. Blizzard's own sliders pass no formatter and
-- print the raw float, which on a 0.05 step is how "0.6500000001" reaches the screen. The
-- step already says how much precision is meaningful.
local function makeFormatter(step)
    local decimals, scale = 0, step or 0
    while scale > 0 and scale < 1 and decimals < 4 do
        scale = scale * 10
        decimals = decimals + 1
    end
    local pattern = "%." .. decimals .. "f"
    return function(value)
        return string.format(pattern, value or 0)
    end
end

function Rows.CreateSlider(parent, spec)
    local row = createBaseRow(parent, spec, "Button")

    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(Theme.SLIDER_WIDTH)
    slider:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT, Theme.SLIDER_OFFSET_Y)

    local step = spec.step or 0.05
    local range = (spec.max or 1) - (spec.min or 0)
    local steps = (step > 0) and (range / step) or 100
    if steps < 1 then
        steps = 1
    end

    local formatters = {}
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
        formatters[MinimalSliderWithSteppersMixin.Label.Right] = makeFormatter(step)
    end

    -- A missing value would reach Slider:SetValue as nil and error inside a Blizzard
    -- widget, a confusing place to read a Pulse bug from. Falls back to the bottom of the
    -- range; the next refresh corrects it if the store catches up.
    local function currentValue()
        local value = spec.get()
        if type(value) ~= "number" then
            return spec.min or 0
        end
        return value
    end

    slider:Init(currentValue(), spec.min or 0, spec.max or 1, steps, formatters)

    -- Feedback-loop guard: writing to the database notifies the panel, the panel refreshes
    -- this row, and the refresh would drive SetValue back into the slider mid-drag.
    -- `applying` makes the round trip a no-op instead of a fight.
    local applying = false
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if applying then
            return
        end
        applying = true
        spec.set(value)
        applying = false
    end, row)

    attachControlTooltip(row, slider.Slider, spec)

    -- Blizzard_SettingControls.lua:728-731: the inner widget is skipped and the ROW is the
    -- navigation target, so D-pad bindings act on a whole row.
    Theme.MarkIgnored(slider)
    Theme.MarkFocusable(row)
    setCursorAnchor(row, row)

    row.Control = slider
    row.RefreshValue = function()
        if applying then
            return
        end
        local value = currentValue()
        local current = slider.Slider and slider.Slider:GetValue()
        -- Only write when it actually differs, so a refresh never nudges a slider the
        -- player is holding.
        if current == nil or math.abs(current - value) > (step * 0.001) then
            applying = true
            slider:SetValue(value)
            applying = false
        end
    end
    row.SetRowEnabled = function(_, enabled)
        slider:SetEnabled(enabled)
        Theme.DisplayEnabled(row, enabled)
    end

    -- Called by SmartNavigation:SelectButton and its deselect half (SmartNavigation.lua:507,
    -- :525). Left and right step the slider while this row is selected, and the on-screen
    -- legend says so.
    row.OnSmartNavSelect = function()
        Panel.Gamepad.OnSliderSelected(slider)
    end
    row.OnSmartNavDeselect = function()
        Panel.Gamepad.OnSliderDeselected()
    end

    return row
end

-- ── Dropdown ──────────────────────────────────────────────────────────────────

-- SettingsDropdownWithButtonsTemplate is the dropdown-plus-stepper-arrows combination
-- Blizzard's own rows use; the arrows are what left and right map onto for gamepad. Falls
-- back to the bare dropdown if the template is absent, so the page still renders.
local function createDropdownControl(row)
    local ok, control = pcall(CreateFrame, "Frame", nil, row, "SettingsDropdownWithButtonsTemplate")
    if ok and control and control.Dropdown then
        control:SetPoint("LEFT", row, "CENTER", Theme.DROPDOWN_LEFT, 3)
        control.Dropdown:SetWidth(Theme.DROPDOWN_WIDTH)
        return control, control.Dropdown
    end

    local ok2, dropdown = pcall(CreateFrame, "DropdownButton", nil, row, "WowStyle2DropdownTemplate")
    if ok2 and dropdown then
        dropdown:SetWidth(Theme.DROPDOWN_WIDTH)
        dropdown:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT, 3)
        return dropdown, dropdown
    end

    return nil, nil
end

function Rows.CreateDropdown(parent, spec)
    local row = createBaseRow(parent, spec, "Button")

    local control, dropdown = createDropdownControl(row)
    if not dropdown then
        -- No dropdown widget on this client: degrade to a label rather than taking the
        -- whole page down.
        row.RefreshValue = function() end
        row.SetRowEnabled = function(_, enabled)
            Theme.DisplayEnabled(row, enabled)
        end
        return row
    end

    -- DELIBERATELY NO SetupMenu. That one call wires this widget to Blizzard's Menu
    -- system, and opening such a menu ends at a protected binding call an addon's stack
    -- may not reach — UI/Panel/Popup.lua's header has the trace. Without a generator,
    -- DropdownButtonMixin:GenerateMenu returns immediately, so the widget keeps all of its
    -- artwork and none of its behaviour, and Popup.OpenList supplies the behaviour.

    local function options()
        local ok, result = pcall(spec.options)
        if ok and type(result) == "table" then
            return result
        end
        return {}
    end

    local function labelFor(value)
        for _, option in ipairs(options()) do
            if option.value == value then
                return option.label
            end
        end
        return CUSTOM or "Custom"
    end

    local function setText(text)
        if dropdown.Text then
            dropdown.Text:SetText(text)
        elseif dropdown.SetText then
            dropdown:SetText(text)
        end
    end

    -- Step by one without opening anything. The template's stepper buttons normally drive
    -- the menu's own selection; with no menu they run off the options array directly.
    local function step(delta)
        local list = options()
        local current = spec.get()
        for index, option in ipairs(list) do
            if option.value == current then
                local target = list[index + delta]
                if target then
                    spec.set(target.value)
                end
                return
            end
        end
        if list[1] then
            spec.set(list[1].value)
        end
    end

    local function updateSteppers()
        if not control.SetSteppersEnabled then
            return
        end
        local list = options()
        local current = spec.get()
        local index
        for i, option in ipairs(list) do
            if option.value == current then
                index = i
                break
            end
        end
        control:SetSteppersEnabled(index ~= nil and index > 1, index ~= nil and index < #list)
    end

    dropdown:HookScript("OnMouseDown", function()
        if not dropdown:IsEnabled() then
            return
        end
        Panel.Popup.OpenList(dropdown, options(), spec.get(), function(value)
            spec.set(value)
        end)
    end)

    if control.IncrementButton then
        control.IncrementButton:SetScript("OnClick", function()
            step(1)
            if SOUNDKIT then
                Theme.PlayCheckSound(true)
            end
        end)
    end
    if control.DecrementButton then
        control.DecrementButton:SetScript("OnClick", function()
            step(-1)
            if SOUNDKIT then
                Theme.PlayCheckSound(true)
            end
        end)
    end
    if control.SetSteppersShown then
        control:SetSteppersShown(true)
    end

    attachControlTooltip(row, dropdown, spec)

    Theme.MarkIgnored(control)
    Theme.MarkFocusable(row)
    setCursorAnchor(row, row)

    row.Control = control
    row.Dropdown = dropdown

    row.RefreshValue = function()
        setText(labelFor(spec.get()))
        updateSteppers()
    end
    row.SetRowEnabled = function(_, enabled)
        if control.SetEnabled then
            control:SetEnabled(enabled)
        elseif dropdown.SetEnabled then
            dropdown:SetEnabled(enabled)
        end
        Theme.DisplayEnabled(row, enabled)
    end

    row.OnSmartNavSelect = function()
        Panel.Gamepad.OnDropdownSelected(control, dropdown)
    end
    row.OnSmartNavDeselect = function()
        Panel.Gamepad.OnDropdownDeselected()
    end

    row:RefreshValue()
    return row
end

-- ── Button ────────────────────────────────────────────────────────────────────

-- A named row with a button on the right — every Play/Test/Ramp/Apply row.
-- Blizzard_SettingControls.lua:920 sets the width to 200 and leaves height to the template.
function Rows.CreateButton(parent, spec)
    local row = createBaseRow(parent, spec, "Frame")

    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetWidth(Theme.BUTTON_WIDTH)
    button:SetPoint("LEFT", row, "CENTER", Theme.BUTTON_LEFT, 0)
    button:SetText(spec.buttonText or "")
    button:SetScript("OnClick", function()
        spec.onClick()
    end)

    attachControlTooltip(row, button, spec)

    setCursorAnchor(row, button)
    if type(SmartNavigation_AddIgnoreInputNavigationOverride) == "function" and SMART_NAV_INPUT_DIRECTION then
        pcall(SmartNavigation_AddIgnoreInputNavigationOverride, button, SMART_NAV_INPUT_DIRECTION.RIGHT)
    end

    row.Control = button
    row.RefreshValue = function()
        if spec.buttonTextFunc then
            button:SetText(spec.buttonTextFunc())
        end
        -- Same idea as a live `body`: a row whose NAME reports state, e.g. a rule row
        -- that reads "This character — Raiding" and has to follow the rule it names.
        if spec.labelFunc then
            row.Text:SetText(spec.labelFunc())
        end
    end
    row.SetRowEnabled = function(_, enabled)
        button:SetEnabled(enabled)
        Theme.DisplayEnabled(row, enabled)
    end

    return row
end

-- ── Index entry ───────────────────────────────────────────────────────────────

-- One line of the cue index: a state dot, the cue's name, and where it lives. The whole row
-- is the click target, so this is a Button, which also makes it a navigation target for
-- whenever the controller pass lands.
--
-- NOT a control. It changes nothing; it reports state and navigates. That distinction backs
-- the row counts quoted in UIguide.md, so the index reads as its own kind rather than a
-- button row with a "Go" on it.
local DOT_ON = { 0.25, 0.80, 0.35 }
local DOT_OFF = { 0.32, 0.32, 0.32 }

function Rows.CreateIndex(parent, spec)
    local row = createBaseRow(parent, spec, "Button")

    local dot = row:CreateTexture(nil, "OVERLAY")
    dot:SetSize(8, 8)
    dot:SetPoint("LEFT", row, "LEFT", 20, 0)
    dot:SetColorTexture(DOT_OFF[1], DOT_OFF[2], DOT_OFF[3], 1)

    -- Where the cue's own controls are, in the column other pages put their control in, so
    -- the index lines up rather than inventing a layout.
    local location = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    location:SetJustifyH("LEFT")
    location:SetWordWrap(false)
    location:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT, 0)
    location:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    location:SetText(spec.location or "")
    location:SetTextColor(0.62, 0.62, 0.62)

    row:SetScript("OnClick", function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end
        spec.onClick()
    end)

    setCursorAnchor(row, row)

    row.Control = nil
    row.RefreshValue = function()
        local on = spec.get and spec.get()
        local colour = on and DOT_ON or DOT_OFF
        dot:SetColorTexture(colour[1], colour[2], colour[3], 1)
    end
    row.SetRowEnabled = function(_, enabled)
        Theme.DisplayEnabled(row, enabled)
    end

    row:RefreshValue()
    return row
end

-- ── Dispatch ──────────────────────────────────────────────────────────────────

local builders = {
    header = Rows.CreateHeader,
    text = Rows.CreateText,
    checkbox = Rows.CreateCheckbox,
    slider = Rows.CreateSlider,
    dropdown = Rows.CreateDropdown,
    button = Rows.CreateButton,
    index = Rows.CreateIndex,
}

-- Every write from a row marks the panel dirty on top of whatever the database notifies.
-- Belt and braces on purpose: a handful of setters — the device preset, the change
-- threshold, the mode tester's selection, Pulse.debug — go through no listener list at all,
-- and a row writing one of those still has to see its own result.
local function wrapSet(spec)
    local set = spec.set
    if type(set) ~= "function" then
        return
    end
    spec.set = function(value)
        set(value)
        if Panel.MarkDirty then
            Panel.MarkDirty()
        end
    end
end

function Rows.Create(parent, spec)
    local builder = builders[spec.kind]
    if not builder then
        return nil
    end

    wrapSet(spec)
    -- A single malformed spec should cost its own row, not the page it is on.
    local ok, row = pcall(builder, parent, spec)
    if not ok then
        print(("Pulse: could not build settings row %q (%s)"):format(tostring(spec.label), tostring(row)))
        return nil
    end
    return row
end
