-- Pulse — UI/Panel/Theme.lua
--
-- Geometry, fonts and shared helpers for Pulse's own settings window.
--
-- WHY THIS TREE EXISTS. The settings panel used to drive Blizzard's Settings framework —
-- RegisterProxySetting, CreateCheckbox, a vertical layout per category, and a
-- WowScrollBoxList recycling a small pool of row frames across ~764 controls. That
-- framework's lifecycle is where this addon's crashes lived: pooled rows entering
-- SmartNavigation's node set and being recycled with the reference left dangling, and
-- RepairDisplay re-running a linear parent scan on every setting change.
--
-- This tree replaces the PRESENTATION only. Nothing here touches Core/ or Modules/, and
-- every read and write still goes through Pulse.Database with the same keys.
--
-- THE TWO RULES THAT MAKE IT STABLE
--
--   1. No pooling. A row is built once for the page it belongs to, the first time that page
--      is opened, and lives for the session. A frame that is never recycled cannot be
--      recycled out from under a navigation reference.
--
--   2. A plain ScrollFrame, not a ScrollBox. CONFIRMED in the Forever source
--      (Blizzard_GamepadSmartNavigation/SmartNavigation.lua:879) that
--      SmartNavigationMixin:HandleScroll branches on IsObjectType("ScrollFrame") and takes
--      a flat SetVerticalScroll path. The other branch — re-resolving a button through
--      FindFrame(elementData) because "the ScrollBox frames are in a pool and can change
--      when scrolling" — is the machinery being avoided, and a plain ScrollFrame never
--      reaches it.
--
-- Everything else here is fidelity: the numbers below are copied from the real thing, so a
-- Pulse page reads as native rather than as an approximation of native.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
Pulse.UI.Panel = Pulse.UI.Panel or {}
local Panel = Pulse.UI.Panel

local Theme = {}
Panel.Theme = Theme

-- ── Window ────────────────────────────────────────────────────────────────────
-- Blizzard_SettingsPanel.xml:4-8.
Theme.PANEL_WIDTH  = 920
Theme.PANEL_HEIGHT = 724

-- Blizzard_SettingsPanel.xml:60-66. The sidebar's own size plus where it sits.
Theme.SIDEBAR_WIDTH   = 199
Theme.SIDEBAR_INSET_X = 18
Theme.SIDEBAR_INSET_Y = -76
Theme.SIDEBAR_BOTTOM  = 46

-- Blizzard_SettingsPanel.xml:67-77.
Theme.CONTAINER_GAP   = 16   -- between sidebar right edge and the content container
Theme.CONTAINER_RIGHT = -22

-- Blizzard_SettingsList.xml:6-25. The page header band above the scrolling list.
Theme.HEADER_HEIGHT     = 50
Theme.HEADER_TITLE_X    = 7
Theme.HEADER_TITLE_Y    = -22
Theme.HEADER_TITLE_FONT = "GameFontHighlightHuge"

-- Blizzard_SettingsList.lua:53-82. verticalPad/padLeft/padRight/spacing for the list, and
-- where the scroll region sits relative to the header.
Theme.LIST_VERTICAL_PAD = 10
Theme.LIST_PAD_LEFT     = 25
Theme.LIST_PAD_RIGHT    = 0
Theme.LIST_SPACING      = 9
Theme.LIST_TOP_X        = -15
Theme.LIST_TOP_Y        = -2
Theme.LIST_BOTTOM_X     = -20
Theme.LIST_BOTTOM_Y     = -2

-- ── Rows ──────────────────────────────────────────────────────────────────────
-- Blizzard_SettingControls.xml:104-131 (26px rows) and :13 (45px section header).
Theme.ROW_HEIGHT    = 26
Theme.HEADER_ROW_H  = 45

-- Blizzard_SettingControls.lua:1 — indentSize, and :338-341 for where the label sits.
-- Text runs from (indent + 37) on the left to 85px short of the row's centre; the control
-- itself starts 80px short of that same centre. Reproduced rather than approximated so a
-- Pulse page and a Blizzard page line up if they are open side by side.
Theme.INDENT        = 15
Theme.TEXT_LEFT     = 37
Theme.TEXT_RIGHT    = -85
Theme.CONTROL_LEFT  = -80

-- Blizzard_SettingControls.lua:338 — a parented (child) row drops to the small font.
Theme.FONT_NORMAL   = "GameFontNormal"
Theme.FONT_CHILD    = "GameFontNormalSmall"

-- Blizzard_SettingControls.xml:82-90 / :693 / :802 / :922.
Theme.CHECKBOX_SIZE_X = 30
Theme.CHECKBOX_SIZE_Y = 29
Theme.SLIDER_WIDTH    = 250
Theme.SLIDER_OFFSET_Y = 3
Theme.DROPDOWN_LEFT   = -48   -- dropdown rows sit further right than sliders
Theme.DROPDOWN_WIDTH  = 220
Theme.BUTTON_WIDTH    = 200
Theme.BUTTON_LEFT     = -40

-- Blizzard_CategoryList.xml:47-49 and :63-68.
Theme.CATEGORY_HEIGHT   = 20
Theme.CATEGORY_LABEL_X  = 36
Theme.CATEGORY_INDENT   = 12

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Blizzard's rows show a faint white wash under the cursor
-- (HoverBackgroundTemplate, Blizzard_SettingControls.xml:5-12).
function Theme.CreateHoverBackground(frame, inset)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetColorTexture(1, 1, 1, 0.1)
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset or -10, 0)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 0)
    texture:Hide()
    return texture
end

-- One tooltip for the whole panel, styled like Blizzard's SettingsTooltip: control name as
-- title, description wrapped underneath. Deliberately NOT SettingsTooltip itself — that
-- frame belongs to the panel being replaced, and borrowing it would put the dependency
-- back.
local tooltip

local function getTooltip()
    if tooltip then return tooltip end
    -- SharedTooltipTemplate is Blizzard_SharedXML and always present; the fallback only
    -- degrades a missing template to no tooltip rather than to a broken panel.
    local ok, frame = pcall(CreateFrame, "GameTooltip", "PulsePanelTooltip", UIParent,
                            "SharedTooltipTemplate")
    if ok and frame then
        tooltip = frame
    else
        tooltip = GameTooltip
    end
    return tooltip
end

function Theme.ShowTooltip(owner, title, body)
    if not title and not body then return end
    local tip = getTooltip()
    if not tip then return end
    tip:SetOwner(owner, "ANCHOR_RIGHT", -10, 0)
    if title and title ~= "" then
        tip:SetText(title, 1, 1, 1, 1, true)
        if body and body ~= "" then
            tip:AddLine(" ")
            tip:AddLine(body, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        end
    else
        tip:SetText(body, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    end
    tip:Show()
end

function Theme.HideTooltip()
    local tip = getTooltip()
    if tip then tip:Hide() end
end

-- Every SmartNavigation call in this tree goes through these two. The globals come from
-- Blizzard_GamepadSmartNavigation, loaded only where gamepad UI exists, so a bare call
-- would error without it. Guarded once here rather than at forty call sites.
function Theme.MarkIgnored(frame)
    if frame and type(SmartNavigation_MarkFrameIgnored) == "function" then
        pcall(SmartNavigation_MarkFrameIgnored, frame)
    end
end

function Theme.MarkFocusable(frame)
    if frame and type(SmartNavigation_MarkFrameFocusable) == "function" then
        pcall(SmartNavigation_MarkFrameFocusable, frame)
    end
end

function Theme.ClearIgnored(frame)
    if frame and type(SmartNavigation_ClearIgnoreStatus) == "function" then
        pcall(SmartNavigation_ClearIgnoreStatus, frame)
    end
end

function Theme.PlayCheckSound(on)
    if not SOUNDKIT then return end
    local kit = on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                   or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
    if kit then PlaySound(kit) end
end

-- Greying out. Blizzard's SettingsListElementMixin:DisplayEnabled
-- (Blizzard_SettingControls.lua:282-292) does these same three things, including taking the
-- row out of gamepad navigation: a disabled row should be unreachable, not merely dimmed.
function Theme.DisplayEnabled(row, enabled)
    local color = enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
    if row.Text then row.Text:SetTextColor(color:GetRGB()) end
    if row.DesaturateHierarchy then row:DesaturateHierarchy(enabled and 0 or 1) end
    if enabled then
        Theme.ClearIgnored(row)
    else
        Theme.MarkIgnored(row)
    end
end
