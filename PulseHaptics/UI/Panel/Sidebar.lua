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
	cueIndex = "Interface\\Icons\\INV_Misc_Spyglass_02",
	profiles = "Interface\\Icons\\INV_Misc_Note_01",
	defaultProfiles = "Interface\\Icons\\INV_Misc_Folder_01",
	crafting = "Interface\\Icons\\Trade_BlackSmithing",
	COMBAT = "Interface\\Icons\\Ability_DualWield",
	CASTING = "Interface\\Icons\\Spell_Holy_MagicalSentry",
	MOVEMENT = "Interface\\Icons\\Ability_Rogue_Sprint",
	CHARACTER = "Interface\\Icons\\Spell_Holy_WordFortitude",
	CONTROL = "Interface\\Icons\\Spell_Frost_ChainsOfIce",
	TARGET = "Interface\\Icons\\Ability_Hunter_SniperShot",
	WORLD = "Interface\\Icons\\Spell_Nature_EarthBind",
	SOCIAL = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
	INTERFACE = "Interface\\Icons\\INV_Misc_Gear_01",
	CONTROLLER = "Interface\\Icons\\INV_Gizmo_02",
	CONTROLLER_UI = "Interface\\Icons\\INV_Gizmo_01",
	GAMEPAD_INTERACT = "Interface\\Icons\\INV_Gizmo_08",
	modeTuning = "Interface\\Icons\\Trade_Engineering",
	calibration = "Interface\\Icons\\INV_Misc_EngGizmos_17",
	continuous = "Interface\\Icons\\Spell_Arcane_PortalIronForge",
	guide = "Interface\\Icons\\INV_Misc_Book_09",
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
			if button.Label.SetTextColor and NORMAL_FONT_COLOR then
				button.Label:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
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
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
