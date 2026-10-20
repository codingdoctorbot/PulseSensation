-- KAPOW — UI/EventsPage.lua
--
-- The Events tab: what each moment shows. Left, the event groups; middle, the events of the
-- selected group (a dot shows which are on); right, the editor for the selected event: art
-- (by category, or random from one), animation, title and detail-line text templates,
-- color, size, position and sound, with a preview of the art and Preview / Reset buttons.

local _, ns = ...

local Theme = ns.ui.Theme

local GROUP_WIDTH = 140
local EVENT_WIDTH = 250
local EDITOR_LEFT = GROUP_WIDTH + 10 + EVENT_WIDTH + 20
local LIST_STEP = 26
local EVENT_SLOTS = 8 -- the largest group has 7

local selectedGroup, selectedEvent = "hits", "crit"

local function Def()
	return ns.EVENT_BY_ID[selectedEvent]
end

local function Cfg()
	return ns.db.events[selectedEvent]
end

local function EventGet(field)
	return function()
		return Cfg()[field]
	end
end

local function EventSet(field)
	return function(value)
		ns.SetEvent(selectedEvent, field, value)
	end
end

-- A dropdown of fixed options: order = list of keys, labels = key -> label (or { label }).
local function OptionsDropdown(label, tooltip, field, order, labels)
	local function text(key)
		local entry = labels[key]
		if type(entry) == "table" then
			return entry.label or entry[1]
		end
		return entry or tostring(key)
	end
	return {
		type = "dropdown",
		label = label,
		tooltip = tooltip,
		get = EventGet(field),
		set = EventSet(field),
		text = text,
		build = function(root, isSelected, setSelected)
			for _, key in ipairs(order) do
				root:CreateRadio(text(key), isSelected, setSelected, key)
			end
		end,
	}
end

local COLOR_LABELS = { gold = "Gold", orange = "Orange", red = "Red", green = "Green", blue = "Blue", purple = "Purple", white = "White" }

local function EditorSpecs()
	local D = ns.display
	return {
		{
			type = "header",
			labelFunc = function()
				return Def().label
			end,
		},
		{
			type = "checkbox",
			label = "Show this event",
			get = EventGet("enabled"),
			set = EventSet("enabled"),
		},
		{
			type = "dropdown",
			label = "Art",
			tooltip = "A three-frame sequence with its word in the art, a random one from a category on every show, or none for text only.",
			get = EventGet("art"),
			set = EventSet("art"),
			text = ns.art.Describe,
			build = function(root, isSelected, setSelected)
				root:CreateRadio("None (text only)", isSelected, setSelected, "none")
				root:CreateRadio("Random: everything", isSelected, setSelected, "random:all")
				for _, category in ipairs(ns.art.CATEGORIES) do
					local sub = root:CreateButton(category.label)
					sub:CreateRadio("Random " .. category.label, isSelected, setSelected, "random:" .. category.id)
					for _, item in ipairs(category.items) do
						sub:CreateRadio(item[2], isSelected, setSelected, item[1])
					end
				end
			end,
		},
		OptionsDropdown("Animation", "How it enters, moves and leaves. Flipbook, Bounce, Rise and Shake play the art's three frames.", "anim", D.ANIM_ORDER, D.ANIMS),
		{
			type = "edit",
			label = "Title text",
			tooltip = "Drawn in big letters: over nothing when there is no art, under the art when there is. Leave empty for none. Tokens fill in, e.g. {killer}.",
			get = EventGet("title"),
			set = EventSet("title"),
		},
		{
			type = "edit",
			label = "Detail line",
			tooltip = "The smaller line. Tokens fill in, e.g. {victim} or {amount}.",
			get = EventGet("sub"),
			set = EventSet("sub"),
		},
		{
			type = "checkbox",
			labelFunc = function()
				return Def().hit and "Show the damage number" or "Show the detail line"
			end,
			get = EventGet("details"),
			set = EventSet("details"),
		},
		OptionsDropdown("Title color", nil, "color", D.COLOR_ORDER, COLOR_LABELS),
		OptionsDropdown("Font", "For the title and the detail line.", "font", D.FONT_ORDER, D.FONTS),
		{
			type = "choice",
			label = "Size",
			choices = { { 0.5, "50%" }, { 0.75, "75%" }, { 1, "100%" }, { 1.25, "125%" }, { 1.5, "150%" }, { 2, "200%" } },
			get = EventGet("size"),
			set = EventSet("size"),
		},
		{
			type = "choice",
			label = "Duration",
			tooltip = "How long it stays, as a multiple of its normal length. The art's three frames slow down or speed up with it.",
			choices = { { 0.5, "0.5x" }, { 0.75, "0.75x" }, { 1, "1x" }, { 1.5, "1.5x" }, { 2, "2x" }, { 3, "3x" } },
			get = EventGet("duration"),
			set = EventSet("duration"),
		},
		OptionsDropdown("Position", "Comic spot follows /kapow pos; the others are fixed places on screen.", "pos", D.POSITION_ORDER, D.POSITIONS),
		(function()
			-- Hit events' sounds live on the Experimental tab (they cannot follow the secret gates).
			local spec = OptionsDropdown("Sound", "Needs Event sounds on (General tab).", "sound", D.SOUND_ORDER, D.SOUNDS)
			spec.hitLocked = true
			spec.labelFunc = function()
				return Def().hit and "Sound: see Experimental" or "Sound"
			end
			return spec
		end)(),
		{
			type = "note",
			textFunc = function()
				local tokens = Def().tokens
				return "Text tokens: " .. ((tokens and tokens ~= "") and tokens or "none for this event")
			end,
		},
		{
			type = "buttons",
			label = "",
			buttons = {
				{
					"Preview",
					function()
						ns.announcer:Preview(selectedEvent)
					end,
				},
				{
					"Reset event",
					function()
						local defaults = ns.EventDefaults(selectedEvent)
						for field, value in pairs(defaults) do
							ns.db.events[selectedEvent][field] = value
						end
						ns.SetEvent(selectedEvent, "enabled", defaults.enabled)
					end,
				},
			},
		},
	}
end

local function StyleSelected(button, selected)
	local c = selected and Theme.COLOR_ACCENT or Theme.COLOR_BORDER
	button.ComicBorder:SetColorTexture(c.r, c.g, c.b, selected and 0.9 or 0.8)
end

local function ListButton(parent, x, y, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	Theme.StyleActionButton(button, false)
	local text = button:GetFontString()
	if text then
		text:SetJustifyH("LEFT")
		text:ClearAllPoints()
		text:SetPoint("LEFT", button, "LEFT", 8, 0)
		text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	end
	return button
end

local function EventsInGroup(group)
	local list = {}
	for _, def in ipairs(ns.EVENTS) do
		if def.group == group then
			list[#list + 1] = def
		end
	end
	return list
end

ns.ui.pages.events = {
	label = "Events",
	order = 2,
	Build = function(parent)
		local page = {}

		-- Groups
		local groupButtons = {}
		for i, group in ipairs(ns.EVENT_GROUPS) do
			local button = ListButton(parent, 0, -(i - 1) * LIST_STEP, GROUP_WIDTH)
			button:SetText(group.label)
			button:SetScript("OnClick", function()
				selectedGroup = group.id
				selectedEvent = EventsInGroup(group.id)[1].id
				page.Refresh()
			end)
			groupButtons[group.id] = button
		end

		-- Events of the selected group
		local eventButtons = {}
		for i = 1, EVENT_SLOTS do
			local button = ListButton(parent, GROUP_WIDTH + 10, -(i - 1) * LIST_STEP, EVENT_WIDTH)
			button:SetScript("OnClick", function(self)
				if self.eventId then
					selectedEvent = self.eventId
					page.Refresh()
				end
			end)
			eventButtons[i] = button
		end

		-- Editor
		local editor = CreateFrame("Frame", nil, parent)
		editor:SetPoint("TOPLEFT", parent, "TOPLEFT", EDITOR_LEFT, 0)
		editor:SetSize(Theme.COLUMN_WIDTH, 1)
		local rows, height = ns.ui.BuildColumns(editor, EditorSpecs())

		-- Art preview: the peak frame of the current choice (a random pick for random ones).
		local preview = parent:CreateTexture(nil, "ARTWORK")
		preview:SetSize(150, 150)
		preview:SetPoint("TOPRIGHT", parent, "TOPLEFT", EDITOR_LEFT - 20, -(EVENT_SLOTS * LIST_STEP + 10))
		local previewLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		previewLabel:SetPoint("TOP", preview, "BOTTOM", 0, -4)

		page.height = math.max(height, EVENT_SLOTS * LIST_STEP + 190)

		function page.Refresh()
			for id, button in pairs(groupButtons) do
				StyleSelected(button, id == selectedGroup)
			end
			local list = EventsInGroup(selectedGroup)
			for i, button in ipairs(eventButtons) do
				local def = list[i]
				if def then
					local on = ns.db.events[def.id].enabled
					button.eventId = def.id
					button:SetText((on and "|cff40ff40●|r  " or "|cff777777○|r  ") .. def.label)
					StyleSelected(button, def.id == selectedEvent)
					button:Show()
				else
					button.eventId = nil
					button:Hide()
				end
			end
			for _, row in ipairs(rows) do
				row:RefreshValue()
				if row.spec.hitLocked then
					row:SetRowEnabled(not Def().hit)
				end
			end
			local entry = ns.art.Resolve(Cfg().art)
			if entry then
				preview:SetTexture(entry.frames[2])
				preview:Show()
				previewLabel:SetText(ns.art.Describe(Cfg().art))
			else
				preview:Hide()
				previewLabel:SetText("Text only")
			end
		end

		return page
	end,
}
