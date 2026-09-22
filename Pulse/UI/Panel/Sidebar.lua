-- Pulse — UI/Panel/Sidebar.lua
--
-- The left-hand category list: one button per page, the parent row unindented and its
-- pages indented under it, exactly like the real settings sidebar.
--
-- Styling is SettingsCategoryListButtonTemplate to the pixel (Blizzard_CategoryList.xml:
-- 47-90) and its selection behaviour is SettingsCategoryListButtonMixin:UpdateStateInternal
-- (Blizzard_CategoryList.lua:44-67): Options_List_Active under the selected row,
-- Options_List_Hover under the cursor, GameFontHighlight for a child row and for the
-- selection, GameFontNormal otherwise.
--
-- Not a ScrollBox, and not even a ScrollFrame. The list is a fixed known length — one root
-- page, the cue pages from Registry's PAGE_LAYOUT, three tuning pages and the guide, about
-- seventeen rows at 20px — which fits the 569px sidebar with room to spare. A scroll region
-- would guard against a case that cannot arise and would add a second scrollable group for
-- gamepad navigation to reason about. If the page count ever outgrows the height,
-- CreateButtons is where the scroll region goes.

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel
local Theme = Panel.Theme

local Sidebar = {}
Panel.Sidebar = Sidebar

local SidebarMixin = {}

local function updateButtonState(button)
    local selected = button.selected
    if selected then
        button.Label:SetFontObject("GameFontHighlight")
        button.Texture:SetAtlas("Options_List_Active", true)
        button.Texture:Show()
    else
        button.Label:SetFontObject(button.isChild and "GameFontHighlight" or "GameFontNormal")
        if button.over then
            button.Texture:SetAtlas("Options_List_Hover", true)
            button.Texture:Show()
        else
            button.Texture:Hide()
        end
    end
end

function Sidebar.Create(parent, onSelect)
    local frame = CreateFrame("Frame", nil, parent)
    Mixin(frame, SidebarMixin)
    frame.buttons = {}
    frame.onSelect = onSelect
    return frame
end

function SidebarMixin:CreateButtons(pages)
    local previous = nil
    for _, page in ipairs(pages) do
        local button = CreateFrame("Button", nil, self)
        button:SetHeight(Theme.CATEGORY_HEIGHT)
        button:SetPoint("LEFT", self, "LEFT", 0, 0)
        button:SetPoint("RIGHT", self, "RIGHT", 0, 0)
        if previous then
            button:SetPoint("TOP", previous, "BOTTOM", 0, 0)
        else
            button:SetPoint("TOP", self, "TOP", 0, 0)
        end

        button.Texture = button:CreateTexture(nil, "BACKGROUND")
        button.Texture:SetPoint("CENTER")
        button.Texture:Hide()

        button.Label = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        button.Label:SetJustifyH("LEFT")
        button.Label:SetPoint("TOPLEFT", button, "TOPLEFT",
            Theme.CATEGORY_LABEL_X + (page.indent or 0) * Theme.CATEGORY_INDENT, 1)
        button.Label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
        button.Label:SetText(page.label)

        button.page = page
        button.isChild = (page.indent or 0) > 0

        button:SetScript("OnEnter", function(self)
            self.over = true
            updateButtonState(self)
        end)
        button:SetScript("OnLeave", function(self)
            self.over = false
            updateButtonState(self)
        end)
        button:SetScript("OnClick", function(self)
            if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            end
            self:GetParent():Select(self.page)
        end)

        updateButtonState(button)

        self.buttons[#self.buttons + 1] = button
        previous = button
    end
end

function SidebarMixin:Select(page)
    for _, button in ipairs(self.buttons) do
        button.selected = (button.page == page)
        updateButtonState(button)
    end
    self.selectedPage = page
    if self.onSelect then self.onSelect(page) end
end

function SidebarMixin:GetSelectedButton()
    for _, button in ipairs(self.buttons) do
        if button.selected then return button end
    end
    return self.buttons[1]
end

function SidebarMixin:GetFirstButton()
    return self.buttons[1]
end
