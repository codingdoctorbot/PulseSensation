-- Pulse — UI/Panel/Content.lua
--
-- The right-hand side: a page title, a horizontal rule, and a scrolling column of rows.
--
-- This is where the crash class gets designed out, so the two decisions are stated plainly
-- rather than left as style.
--
-- LAZY, ONCE, FOREVER. A page's rows are built the first time it is opened and then kept.
-- Switching pages hides one set and shows another; nothing is destroyed or reused. The cost
-- is memory for frames the player has actually looked at — twenty to a hundred rows per
-- page, not 764 — and the benefit is that no frame here is ever bound to a second setting,
-- so no reference can go stale.
--
-- A PLAIN ScrollFrame, not WowScrollBoxList. The scroll child is one tall frame holding
-- every row for the current page, and scrolling moves it. SmartNavigation handles that
-- shape through the branch at SmartNavigation.lua:879 that calls SetVerticalScroll; the
-- pooled branch below it, re-finding a button by element data because "the ScrollBox frames
-- are in a pool and can change when scrolling", is never entered.
--
-- Layout numbers come from SettingsListMixin:OnLoad (Blizzard_SettingsList.lua:53-82):
-- 10px top and bottom padding, 25px left inset, 9px between rows.

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel
local Theme = Panel.Theme
local Rows  = Panel.Rows

local Content = {}
Panel.Content = Content

local ContentMixin = {}

-- ── Construction ──────────────────────────────────────────────────────────────

function Content.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    Mixin(frame, ContentMixin)
    frame:SetAllPoints(parent)

    -- Header band: title on the left, divider underneath. Blizzard_SettingsList.xml:6-25.
    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(Theme.HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    header.Title = header:CreateFontString(nil, "ARTWORK", Theme.HEADER_TITLE_FONT)
    header.Title:SetJustifyH("LEFT")
    header.Title:SetPoint("TOPLEFT", header, "TOPLEFT", Theme.HEADER_TITLE_X, Theme.HEADER_TITLE_Y)

    local divider = header:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", header, "TOP", 0, -Theme.HEADER_HEIGHT)
    header.Divider = divider

    frame.Header = header

    -- Scroll region.
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", Theme.LIST_TOP_X, Theme.LIST_TOP_Y)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Theme.LIST_BOTTOM_X, Theme.LIST_BOTTOM_Y)
    -- InitScrollFrameWithScrollBar installs an OnMouseWheel handler but does not enable
    -- the wheel; ScrollFrameTemplate normally does that in XML and this frame has no
    -- template.
    scroll:EnableMouseWheel(true)
    frame.Scroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    frame.Child = child

    -- MinimalScrollBar is the thin modern bar the real panel uses, and
    -- ScrollUtil.InitScrollFrameWithScrollBar (ScrollUtil.lua:215) is the supported way to
    -- drive one from a plain ScrollFrame rather than a ScrollBox.
    local ok, bar = pcall(CreateFrame, "EventFrame", nil, frame, "MinimalScrollBar")
    if ok and bar then
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, -4)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -1, 7)
        if ScrollUtil and type(ScrollUtil.InitScrollFrameWithScrollBar) == "function" then
            pcall(ScrollUtil.InitScrollFrameWithScrollBar, scroll, bar)
        end
        -- A page shorter than the window should not show a dead scroll bar. Blizzard gets
        -- this from AddManagedScrollBarVisibilityBehavior, which is ScrollBox-only; the
        -- bar's own flag does the same job for a plain ScrollFrame.
        if bar.SetHideIfUnscrollable then bar:SetHideIfUnscrollable(true) end
        frame.ScrollBar = bar
        Theme.MarkIgnored(bar)
    else
        -- No MinimalScrollBar: the mouse wheel still has to work.
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            local value = self:GetVerticalScroll() - (delta * 40)
            if value < 0 then value = 0 elseif value > range then value = range end
            self:SetVerticalScroll(value)
        end)
    end

    scroll:SetScript("OnSizeChanged", function()
        frame:LayoutRows()
    end)

    frame.pages = {}
    frame.filter = nil

    return frame
end

-- ── Page building ─────────────────────────────────────────────────────────────

-- Builds one page's rows, once. `page.build` (UI/Panel/Spec.lua) returns a flat array of
-- row specs in render order, headers included.
function ContentMixin:EnsurePage(page)
    if page.rows then return page.rows end

    local rows = {}
    local skipped = 0
    local specs = page.build and page.build() or {}
    for _, spec in ipairs(specs) do
        local row = Rows.Create(self.Child, spec)
        if row then
            row:Hide()
            rows[#rows + 1] = row
        else
            skipped = skipped + 1
        end
    end
    page.rows = rows
    -- Recorded, not only printed. Rows.Create swallows a bad spec so one broken row cannot
    -- take its page down, which is right at runtime and wrong under test — a silently
    -- missing control looks exactly like a clean build. The offline harness asserts zero.
    page.skippedRows = skipped
    return rows
end

-- ── Showing a page ────────────────────────────────────────────────────────────

function ContentMixin:SetPage(page)
    if self.page == page then return end

    if self.page and self.page.rows then
        for _, row in ipairs(self.page.rows) do row:Hide() end
    end

    self.page = page
    self.Header.Title:SetText(page and page.label or "")

    if page then
        self:EnsurePage(page)
        self:RefreshRows()
    end

    self.Scroll:SetVerticalScroll(0)
    self:LayoutRows()

    -- The set of navigable buttons just changed wholesale.
    Panel.Gamepad.RefreshNavigation()
end

-- ── Filtering ─────────────────────────────────────────────────────────────────

-- Search is scoped to the page in view, not the whole addon. A real difference from
-- Blizzard's panel and a deliberate one: searching everything means building all 764
-- controls at once, the "build the world at login" cost this rewrite exists to stop paying.
-- The box says so in its placeholder text.
function ContentMixin:SetFilter(text)
    text = text and string.lower(strtrim(text)) or ""
    if text == "" then text = nil end
    if self.filter == text then return end
    self.filter = text
    self:LayoutRows()
    Panel.Gamepad.RefreshNavigation()
end

-- A row can be hidden for two unrelated reasons and they compose. `visibleWhen` is the
-- player's own display choice — "Show per-cue detail controls", "Show a Play button on
-- every cue" — which needed a /reload when the old panel decided at registration time
-- whether a control existed. Here the row is always built and simply left out of the
-- layout, so both toggles are instant.
local function rowVisible(row, filter)
    local spec = row.spec
    if spec and spec.visibleWhen and not spec.visibleWhen() then return false end
    if not filter then return true end
    if row.isHeader then return false end   -- decided by its section, below
    return row.searchText and string.find(row.searchText, filter, 1, true) ~= nil
end

-- ── Layout ────────────────────────────────────────────────────────────────────

function ContentMixin:LayoutRows()
    local page = self.page
    if not page or not page.rows then return end

    local width = self.Scroll:GetWidth()
    if not width or width <= 0 then return end
    self.Child:SetWidth(width)

    local filter = self.filter

    -- First pass: visibility. A section header shows only if something under it survived
    -- the filter, so a filtered page never shows a heading over nothing.
    local shown = {}
    local lastHeaderIndex = nil
    local headerHasContent = false
    for index, row in ipairs(page.rows) do
        if row.isHeader then
            if lastHeaderIndex and not headerHasContent then
                shown[lastHeaderIndex] = false
            end
            lastHeaderIndex = index
            headerHasContent = false
            shown[index] = true
        else
            local visible = rowVisible(row, filter)
            shown[index] = visible
            if visible then headerHasContent = true end
        end
    end
    if lastHeaderIndex and not headerHasContent then
        shown[lastHeaderIndex] = false
    end

    -- Second pass: place what is left.
    local y = Theme.LIST_VERTICAL_PAD
    local first = true
    for index, row in ipairs(page.rows) do
        if shown[index] then
            if not first then y = y + Theme.LIST_SPACING end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.Child, "TOPLEFT", Theme.LIST_PAD_LEFT, -y)
            if row.MeasureHeight then
                -- Width from SetWidth rather than from a second anchor, so the wrapped
                -- text has a resolved width to be measured against in this same pass.
                row:SetWidth(width - Theme.LIST_PAD_LEFT)
                row:MeasureHeight()
            else
                row:SetPoint("RIGHT", self.Child, "RIGHT", Theme.LIST_PAD_RIGHT, 0)
            end
            row:Show()
            y = y + (row.rowHeight or Theme.ROW_HEIGHT)
            first = false
        else
            row:Hide()
        end
    end

    self.Child:SetHeight(math.max(y + Theme.LIST_VERTICAL_PAD, 1))
end

-- ── Refresh ───────────────────────────────────────────────────────────────────

-- Re-reads every row on the page in view and re-evaluates its dependency. Driven by a dirty
-- flag rather than per change, so a profile switch — which notifies every cue and every
-- tunable listener at once — costs one pass, not several hundred.
function ContentMixin:RefreshRows()
    local page = self.page
    if not page or not page.rows then return end

    local navigationChanged = false
    for _, row in ipairs(page.rows) do
        if row.RefreshValue then row:RefreshValue() end

        local spec = row.spec
        if spec and spec.enabledWhen and row.SetRowEnabled then
            local enabled = spec.enabledWhen() and true or false
            if row.lastEnabled ~= enabled then
                row.lastEnabled = enabled
                row:SetRowEnabled(enabled)
                navigationChanged = true
            end
        end
    end

    if navigationChanged then
        -- A greyed row is marked ignored by SmartNavigation, so the set of things the
        -- stick can reach just changed and has to be rebuilt.
        Panel.Gamepad.RefreshNavigation()
    end
end
