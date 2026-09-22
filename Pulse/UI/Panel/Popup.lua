-- Pulse — UI/Panel/Popup.lua
--
-- Pulse's own dropdown list and its own dialogs, replacing Blizzard's Menu system and
-- StaticPopup inside this panel.
--
-- WHY THESE EXIST. CONFIRMED LIVE 2026-09-22: opening any dropdown in the panel produced
-- "Pulse has been blocked from an action only available to the Blizzard UI", first on the
-- controller-preset picker and then on the mode selector — the tell that it was never about
-- a particular dropdown.
--
--     click dropdown
--       -> MenuProxyMixin:OnShow                      Menu.lua:1805
--       -> EventRegistry:TriggerEvent("MenuProxy.OnShow")
--       -> FrameControlsManager's subscriber          FrameControlsManager.lua:256
--       -> self:FrameShown(menu)
--       -> CheckForInputBinding(self)                 FrameControlsManager.lua:449
--       -> GamepadMode.ActivateBindingGroup(...)      FrameControlsManager.lua:111
--       -> SetOverrideBindingClick(UIParent, ...)     InputButtonBinding.lua:28
--
-- That last call is protected. Blizzard's own settings panel runs identical code and is
-- fine, because taint is about who STARTED the stack. Nothing Pulse can set opts a menu
-- out, and no flag in UI/Panel/Gamepad.lua helps: Pulse is not making the call, Blizzard's
-- own subscriber is, inside Pulse's stack.
--
-- StaticPopup has the same shape — StaticPopupGamepad.lua:222 calls HandlePopupShown, which
-- is FrameShown again — so every confirmation dialog did it too.
--
-- Not cosmetic: the message is not throttled, so it fired on every open, and
-- StaticPopupDialogs["ADDON_ACTION_FORBIDDEN"]'s first button is Disable, which calls
-- C_AddOns.DisableAddOn and reloads. An addon that repeatedly invites the player to
-- uninstall it is not shippable.
--
-- WHAT IS KEPT. The dropdown ROW still uses SettingsDropdownWithButtonsTemplate, so the
-- closed state, label, arrow, stepper buttons and every atlas are Blizzard's and the page
-- looks unchanged. One call is dropped: SetupMenu. Without a generator,
-- DropdownButtonMixin:GenerateMenu returns immediately (DropdownButton.lua:255-259), so
-- clicking the widget creates no menu, fires no MenuProxy event and reaches nothing
-- protected. The list below opens instead.
--
-- Dialogs are the same trade: same fonts, same buttons, the backdrop template Blizzard's
-- own tooltips use. Only the machinery underneath is Pulse's.

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel
local Theme = Panel.Theme

local Popup = {}
Panel.Popup = Popup

-- 22 rather than Blizzard's 20: at 20 with GameFontHighlight the rows read as a wall of
-- text with no air in them.
local ENTRY_HEIGHT = 22
local LIST_PADDING = 12
local ENTRY_INSET = 5 -- entries stop short of the border on both sides
local TEXT_INSET = 12
local LIST_MAX_ROWS = 12 -- a whole number of rows, so nothing is ever half-cut
local LIST_MIN_WIDTH = 140
local LIST_MAX_WIDTH = 340
local DIALOG_WIDTH = 400

-- Above the settings window, which is DIALOG — and that in turn is above Blizzard's own
-- settings window at HIGH, since the splash page can open ours while theirs is still up.
local OVERLAY_STRATA = "FULLSCREEN_DIALOG"

-- An opaque panel with a real border. The fill is our own texture rather than the
-- template's: it guarantees opacity, which matters for a list opening over a page full of
-- text, and it leaves the border template doing the one job it is reliably good at.
--
-- DialogBorderOpaqueTemplate is the nine-slice Blizzard uses for solid floating panels. It
-- inherits DialogBorderNoCenterTemplate, a NineSlicePanelTemplate that does NOT anchor
-- itself (DialogTemplates.xml:63-67) — it must be told to fill its parent or it renders at
-- zero size and leaves a borderless box. TooltipBackdropTemplate is the fallback, being the
-- one every client has.
local function backdropFrame(parent, name)
    local frame = CreateFrame("Frame", name, parent)

    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    fill:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 1)

    local ok, border = pcall(CreateFrame, "Frame", nil, frame, "DialogBorderOpaqueTemplate")
    if not ok or not border then
        ok, border = pcall(CreateFrame, "Frame", nil, frame, "TooltipBackdropTemplate")
    end
    if ok and border then
        border:SetAllPoints(frame)
        frame.Border = border
    end
    return frame
end

-- Dropdown list

local list -- the popup itself
local listCatcher -- full-screen click-away catcher behind it
local entries = {} -- reused entry buttons, index-keyed
local listState = {}

local function closeList()
    if listCatcher then
        listCatcher:Hide()
    end
    listState.onSelect = nil
    listState.owner = nil
end

function Popup.CloseList()
    closeList()
end

function Popup.IsListOpen()
    return listCatcher ~= nil and listCatcher:IsShown()
end

local function ensureList()
    if list then
        return
    end

    -- The catcher IS the parent, so anything outside the list closes it. A sibling frame
    -- would leave gaps wherever the strata overlapped.
    listCatcher = CreateFrame("Button", nil, UIParent)
    listCatcher:SetAllPoints(UIParent)
    listCatcher:SetFrameStrata(OVERLAY_STRATA)
    listCatcher:Hide()
    listCatcher:SetScript("OnClick", closeList)
    Theme.MarkIgnored(listCatcher)

    list = backdropFrame(listCatcher, nil)
    list:SetFrameLevel(listCatcher:GetFrameLevel() + 10)
    list:EnableMouse(true)

    local scroll = CreateFrame("ScrollFrame", nil, list)
    scroll:SetPoint("TOPLEFT", list, "TOPLEFT", ENTRY_INSET, -LIST_PADDING)
    scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -ENTRY_INSET, LIST_PADDING)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local value = self:GetVerticalScroll() - (delta * ENTRY_HEIGHT * 2)
        if value < 0 then
            value = 0
        elseif value > range then
            value = range
        end
        self:SetVerticalScroll(value)
    end)
    list.Scroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    list.Child = child

    -- The same plain-ScrollFrame plumbing Content.lua uses, unprotected for the same
    -- reason. Without it a list longer than the cap just stopped, with no sign of more.
    local okBar, bar = pcall(CreateFrame, "EventFrame", nil, list, "MinimalScrollBar")
    if okBar and bar then
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2, 0)
        if ScrollUtil and type(ScrollUtil.InitScrollFrameWithScrollBar) == "function" then
            pcall(ScrollUtil.InitScrollFrameWithScrollBar, scroll, bar)
        end
        Theme.MarkIgnored(bar)
        list.ScrollBar = bar
    end
end

-- Entry buttons are reused across opens — safe here in a way row frames are not: nothing
-- outside this file holds one, they are marked out of gamepad navigation, and their click
-- closure is replaced on every open rather than left pointing at the last menu.
local function acquireEntry(index)
    local entry = entries[index]
    if entry then
        return entry
    end

    entry = CreateFrame("Button", nil, list.Child)
    entry:SetHeight(ENTRY_HEIGHT)

    -- A filled bar behind the selected row with subtle cyan accent tint
    entry.Selected = entry:CreateTexture(nil, "ARTWORK")
    entry.Selected:SetAllPoints(entry)
    entry.Selected:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.20)
    entry.Selected:Hide()

    entry.Highlight = entry:CreateTexture(nil, "HIGHLIGHT")
    entry.Highlight:SetAllPoints(entry)
    entry.Highlight:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.10)

    entry.Text = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    entry.Text:SetJustifyH("LEFT")
    entry.Text:SetWordWrap(false)
    entry.Text:SetPoint("LEFT", entry, "LEFT", TEXT_INSET, 0)
    entry.Text:SetPoint("RIGHT", entry, "RIGHT", -8, 0)

    entry:SetScript("OnEnter", function(self)
        if self.tooltip then
            Theme.ShowTooltip(self, self.label, self.tooltip)
        end
    end)
    entry:SetScript("OnLeave", Theme.HideTooltip)
    entry:SetScript("OnClick", function(self)
        local handler = listState.onSelect
        closeList()
        if handler then
            handler(self.value)
        end
    end)

    Theme.MarkIgnored(entry)
    entries[index] = entry
    return entry
end

-- options: array of { value, label, tooltip }. Anchored under the control, which is what
-- makes it read as that control's list rather than as a window.
function Popup.OpenList(owner, options, selectedValue, onSelect)
    ensureList()

    if listState.owner == owner and listCatcher:IsShown() then
        closeList()
        return
    end

    listState.owner = owner
    listState.onSelect = onSelect

    local shown = 0
    local widest = 0

    for index, option in ipairs(options) do
        local entry = acquireEntry(index)
        entry.value = option.value
        entry.label = option.label
        entry.tooltip = option.tooltip
        entry.Text:SetText(option.label or tostring(option.value))

        local selected = (option.value == selectedValue)
        entry.Selected:SetShown(selected)
        if selected then
            entry.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        else
            entry.Text:SetTextColor(0.86, 0.86, 0.86)
        end

        local textWidth = entry.Text:GetStringWidth() or 0
        if textWidth > widest then
            widest = textWidth
        end

        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", list.Child, "TOPLEFT", 0, -(index - 1) * ENTRY_HEIGHT)
        entry:SetPoint("RIGHT", list.Child, "RIGHT", 0, 0)
        entry:SetHeight(ENTRY_HEIGHT)
        entry:Show()
        shown = index
    end
    for index = shown + 1, #entries do
        entries[index]:Hide()
    end

    -- At least as wide as the control it drops from, and never narrow enough to clip a
    -- label. "Gamepad Controller Interactions" and the longer mode names are what push this
    -- past the control's own width.
    local width = math.max(owner:GetWidth() or 0, LIST_MIN_WIDTH, widest + TEXT_INSET + 20)
    if width > LIST_MAX_WIDTH then
        width = LIST_MAX_WIDTH
    end

    -- A whole number of rows: a list ending in a half-visible row reads as broken rather
    -- than scrollable.
    local visibleRows = math.min(shown, LIST_MAX_ROWS)
    local contentHeight = shown * ENTRY_HEIGHT
    local viewHeight = visibleRows * ENTRY_HEIGHT

    list.Child:SetSize(width - (ENTRY_INSET * 2), math.max(contentHeight, 1))
    list:SetSize(width, viewHeight + (LIST_PADDING * 2))
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    list.Scroll:SetVerticalScroll(0)

    -- The bar only exists while there is something to scroll to, so a short list is not
    -- decorated with a dead track.
    if list.ScrollBar then
        list.ScrollBar:SetShown(contentHeight > viewHeight)
    end

    listCatcher:Show()
    list:Show()
end

-- Dialogs

local dialog

local function closeDialog()
    if dialog then
        dialog:Hide()
    end
end

function Popup.CloseDialog()
    closeDialog()
end

local function ensureDialog()
    if dialog then
        return
    end

    dialog = backdropFrame(UIParent, "PulsePanelDialog")
    dialog:SetFrameStrata(OVERLAY_STRATA)
    dialog:SetFrameLevel(200)
    dialog:SetWidth(DIALOG_WIDTH)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    dialog:EnableMouse(true)
    dialog:Hide()
    Theme.MarkIgnored(dialog)

    dialog.Message = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.Message:SetJustifyH("CENTER")
    dialog.Message:SetSpacing(3)
    dialog.Message:SetWidth(DIALOG_WIDTH - 40)
    dialog.Message:SetPoint("TOP", dialog, "TOP", 0, -18)

    local edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    edit:SetSize(DIALOG_WIDTH - 80, 20)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(24)
    edit:SetPoint("TOP", dialog.Message, "BOTTOM", 0, -14)
    dialog.Edit = edit

    local accept = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    accept:SetSize(110, 22)
    dialog.Accept = accept

    local cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancel:SetSize(110, 22)
    cancel:SetText(CANCEL or "Cancel")
    cancel:SetScript("OnClick", closeDialog)
    dialog.Cancel = cancel

    local function accepted()
        local handler = dialog.onAccept
        local value = dialog.Edit:IsShown() and dialog.Edit:GetText() or nil
        closeDialog()
        if handler then
            handler(value)
        end
    end
    dialog.accepted = accepted

    accept:SetScript("OnClick", accepted)
    edit:SetScript("OnEnterPressed", accepted)
    edit:SetScript("OnEscapePressed", closeDialog)

    -- Escape closes it when no edit box catches the key. Propagation stays on except for
    -- the one key actually handled, so the dialog never eats anything else.
    dialog:EnableKeyboard(true)
    if dialog.SetPropagateKeyboardInput then
        dialog:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                closeDialog()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end

    dialog:SetScript("OnHide", function(self)
        self.onAccept = nil
        self.Edit:ClearFocus()
    end)
end

local function layoutDialog(withEdit)
    local height = 18 + dialog.Message:GetStringHeight() + 14
    if withEdit then
        dialog.Edit:Show()
        height = height + 20 + 14
        dialog.Accept:SetPoint("TOPRIGHT", dialog, "TOP", -6, -height)
        dialog.Cancel:SetPoint("TOPLEFT", dialog, "TOP", 6, -height)
    else
        dialog.Edit:Hide()
        dialog.Accept:SetPoint("TOPRIGHT", dialog, "TOP", -6, -height)
        dialog.Cancel:SetPoint("TOPLEFT", dialog, "TOP", 6, -height)
    end
    dialog:SetHeight(height + 22 + 18)
end

-- A yes/no confirmation. `acceptText` names the action rather than saying "Okay": a button
-- that says what it does is the difference between reading the dialog and not.
function Popup.Confirm(text, acceptText, onAccept)
    ensureDialog()
    dialog.Message:SetText(text)
    dialog.Accept:SetText(acceptText or OKAY or "Okay")
    dialog.Accept:ClearAllPoints()
    dialog.Cancel:ClearAllPoints()
    dialog.onAccept = onAccept
    layoutDialog(false)
    dialog:Show()
end

-- A confirmation that also wants a line of text.
function Popup.Prompt(text, defaultValue, acceptText, onAccept)
    ensureDialog()
    dialog.Message:SetText(text)
    dialog.Accept:SetText(acceptText or ACCEPT or "Accept")
    dialog.Accept:ClearAllPoints()
    dialog.Cancel:ClearAllPoints()
    dialog.onAccept = onAccept
    layoutDialog(true)
    dialog.Edit:SetText(defaultValue or "")
    dialog:Show()
    dialog.Edit:SetFocus()
    dialog.Edit:HighlightText()
end

-- Both overlays belong to the panel and should not outlive it on screen.
function Popup.CloseAll()
    closeList()
    closeDialog()
end
