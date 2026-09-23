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

local CATEGORY_ICONS = {
	root = "Interface\\AddOns\\PulseHaptics\\Media\\icon",
	cueIndex = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\cueIndex",
	profiles = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\profiles",
	defaultProfiles = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\defaultProfiles",
	crafting = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\crafting",
	COMBAT = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\COMBAT",
	CASTING = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\CASTING",
	MOVEMENT = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\MOVEMENT",
	CHARACTER = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\CHARACTER",
	CONTROL = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\CONTROL",
	TARGET = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\TARGET",
	WORLD = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\WORLD",
	SOCIAL = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\SOCIAL",
	INTERFACE = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\INTERFACE",
	CONTROLLER = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\CONTROLLER",
	CONTROLLER_UI = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\CONTROLLER_UI",
	GAMEPAD_INTERACT = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\GAMEPAD_INTERACT",
	modeTuning = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\modeTuning",
	calibration = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\calibration",
	continuous = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\continuous",
	guide = "Interface\\AddOns\\PulseHaptics\\Media\\Icons\\guide",
}

local function setHorizontalGradient(texture, r1, g1, b1, a1, r2, g2, b2, a2)
	local ok = false
	if type(CreateColor) == "function" then
		ok = pcall(texture.SetGradient, texture, "HORIZONTAL", CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
	end
	if not ok then
		ok = pcall(texture.SetGradient, texture, "HORIZONTAL", r1, g1, b1, a1, r2, g2, b2, a2)
	end
	if not ok then
		pcall(texture.SetColorTexture, texture, r1, g1, b1, a1 * 0.5)
	end
end

local function updateButtonState(button)
	local selected = button.selected
	if selected then
		button.Label:SetFontObject("GameFontHighlight")
		if button.Label.SetTextColor then
			button.Label:SetTextColor(1, 1, 1)
		end
		button.Texture:SetAtlas("Options_List_Active", true)
		button.Texture:Show()
		if button.Indicator then
			button.Indicator:Show()
		end
		if button.ActiveWash then
			button.ActiveWash:Show()
		end
		if button.Icon then
			button.Icon:SetVertexColor(1, 1, 1, 1)
		end
	else
		button.Label:SetFontObject(button.isChild and "GameFontHighlight" or "GameFontNormal")
		if button.Indicator then
			button.Indicator:Hide()
		end
		if button.ActiveWash then
			button.ActiveWash:Hide()
		end
		if button.over then
			button.Texture:SetAtlas("Options_List_Hover", true)
			button.Texture:Show()
			if button.Label.SetTextColor then
				button.Label:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
			end
			if button.Icon then
				button.Icon:SetVertexColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1)
			end
		else
			button.Texture:Hide()
			if button.Label.SetTextColor then
				button.Label:SetTextColor(Theme.COLOR_TEXT_MUTED.r, Theme.COLOR_TEXT_MUTED.g, Theme.COLOR_TEXT_MUTED.b)
			end
			if button.Icon then
				button.Icon:SetVertexColor(0.70, 0.78, 0.85, 0.75)
			end
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

		-- Horizontal luminous wash on active category button
		button.ActiveWash = button:CreateTexture(nil, "BACKGROUND", nil, 1)
		button.ActiveWash:SetPoint("TOPLEFT", button, "TOPLEFT", 1, 0)
		button.ActiveWash:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		setHorizontalGradient(
			button.ActiveWash,
			Theme.COLOR_ACCENT.r,
			Theme.COLOR_ACCENT.g,
			Theme.COLOR_ACCENT.b,
			0.18,
			Theme.COLOR_ACCENT.r,
			Theme.COLOR_ACCENT.g,
			Theme.COLOR_ACCENT.b,
			0.0
		)
		button.ActiveWash:Hide()

		-- Left-edge active indicator pill
		button.Indicator = button:CreateTexture(nil, "OVERLAY")
		button.Indicator:SetWidth(3)
		button.Indicator:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -2)
		button.Indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 2)
		button.Indicator:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1)
		button.Indicator:Hide()

		-- Category icon
		local iconTexture = CATEGORY_ICONS[page.id]
		local iconX = (Theme.CATEGORY_LABEL_X - 18) + (page.indent or 0) * Theme.CATEGORY_INDENT
		if iconTexture then
			local icon = button:CreateTexture(nil, "ARTWORK")
			icon:SetSize(14, 14)
			icon:SetPoint("LEFT", button, "LEFT", iconX, 0)
			icon:SetTexture(iconTexture)
			button.Icon = icon
		end

		button.Label = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		button.Label:SetJustifyH("LEFT")
		button.Label:SetPoint(
			"TOPLEFT",
			button,
			"TOPLEFT",
			Theme.CATEGORY_LABEL_X + (page.indent or 0) * Theme.CATEGORY_INDENT,
			1
		)
		button.Label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
		button.Label:SetText(page.label)

		button.page = page
		button.isChild = (page.indent or 0) > 0

		button:SetScript("OnEnter", function(btn)
			btn.over = true
			updateButtonState(btn)
		end)
		button:SetScript("OnLeave", function(btn)
			btn.over = false
			updateButtonState(btn)
		end)
		button:SetScript("OnClick", function(btn)
			if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
			end
			btn:GetParent():Select(btn.page)
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
	if self.onSelect then
		self.onSelect(page)
	end
end

function SidebarMixin:GetSelectedButton()
	for _, button in ipairs(self.buttons) do
		if button.selected then
			return button
		end
	end
	return self.buttons[1]
end

function SidebarMixin:GetFirstButton()
	return self.buttons[1]
end
