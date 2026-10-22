-- KAPOW — UI/GalleryPage.lua
--
-- The Gallery tab: every art sequence as a thumbnail, to look at before choosing it. Top, the
-- event the art is for (shared with the Events tab); left, the categories; middle, a page of
-- thumbnails (the peak frame); right, the clicked sequence playing its onset / peak /
-- aftershock on a loop, the three frames side by side, and buttons to keep it for the event,
-- use a random pick from its category, or play it on screen with the event's look.
--
-- Clicking a thumbnail only previews it; nothing changes until "Use for this event". The
-- window does not scroll, so long categories are paged.

local _, ns = ...

local Theme = ns.ui.Theme

local LIST_WIDTH = 150
local LIST_STEP = 26
local TOP = 40 -- below the event row
local THUMB = 80
local THUMB_STEP = 88
local GRID_COLUMNS, GRID_ROWS = 5, 4
local PER_PAGE = GRID_COLUMNS * GRID_ROWS
local GRID_LEFT = LIST_WIDTH + 14
local PANEL_LEFT = GRID_LEFT + GRID_COLUMNS * THUMB_STEP + 12
local BUTTON_WIDTH = 150
local BIG = 180
local SMALL = 60
local LOOP_HOLD = 0.9 -- seconds the aftershock stays before the loop starts again
local SPEEDS = { { 1, "Speed: 1x" }, { 0.5, "Speed: 0.5x" }, { 0.25, "Speed: 0.25x" } }

local filter = "all" -- category id, or "all"
local pageIndex = 1
local picked -- the art key being previewed

-- Every sequence in a category ("all": the whole catalog, each shared sequence once).
local function Entries(categoryId)
	local list, seen = {}, {}
	for _, category in ipairs(ns.art.CATEGORIES) do
		if categoryId == "all" or category.id == categoryId then
			for _, item in ipairs(category.items) do
				if not seen[item[1]] then
					seen[item[1]] = true
					list[#list + 1] = { key = item[1], word = item[2], category = category.id }
				end
			end
		end
	end
	return list
end

local function EventId()
	return ns.ui.SelectedEvent and ns.ui.SelectedEvent() or "crit"
end

local function CurrentArt()
	local cfg = ns.db.events[EventId()]
	return cfg and ns.art.Current(cfg.art)
end

local function Border(frame, inset)
	local edge = frame:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints(frame)
	local fill = frame:CreateTexture(nil, "BORDER")
	fill:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
	fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
	fill:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 0.95)
	return edge
end

local function SetEdge(edge, color, alpha)
	edge:SetColorTexture(color.r, color.g, color.b, alpha)
end

local function ActionButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	Theme.StyleActionButton(button, false)
	return button
end

local function EventMenu(root, isSelected, setSelected)
	for _, group in ipairs(ns.EVENT_GROUPS) do
		local sub
		for _, def in ipairs(ns.EVENTS) do
			if def.group == group.id then
				sub = sub or root:CreateButton(group.label)
				sub:CreateRadio(def.label, isSelected, setSelected, def.id)
			end
		end
	end
end

ns.ui.pages.gallery = {
	label = "Gallery",
	order = 2.5, -- after Events
	Build = function(parent)
		local page = {}

		-- Event row (a settings row, so controller navigation reaches it)
		local header = CreateFrame("Frame", nil, parent)
		header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		header:SetSize(Theme.COLUMN_WIDTH, 1)
		local rows = ns.ui.BuildColumns(header, {
			{
				type = "dropdown",
				label = "Choose art for",
				tooltip = "The event the gallery's art is for. The Events tab edits the same event.",
				get = EventId,
				set = function(id)
					ns.ui.SelectEvent(id)
					ns.ui.Refresh()
				end,
				text = function(id)
					local def = ns.EVENT_BY_ID[id]
					return def and def.label or tostring(id)
				end,
				build = EventMenu,
			},
		})
		local nowText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		nowText:SetPoint("LEFT", header, "TOPLEFT", Theme.CONTROL_LEFT + Theme.DROPDOWN_WIDTH + 16, -Theme.ROW_HEIGHT / 2)
		nowText:SetTextColor(Theme.COLOR_TEXT_MUTED.r, Theme.COLOR_TEXT_MUTED.g, Theme.COLOR_TEXT_MUTED.b)

		-- Categories
		local categoryButtons = {}
		local function CategoryButton(id, label, i)
			local button = ActionButton(parent, label, LIST_WIDTH)
			button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -TOP - (i - 1) * LIST_STEP)
			local text = button:GetFontString()
			if text then
				text:SetJustifyH("LEFT")
				text:ClearAllPoints()
				text:SetPoint("LEFT", button, "LEFT", 8, 0)
				text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
			end
			button:SetScript("OnClick", function()
				filter, pageIndex = id, 1
				page.Refresh()
			end)
			categoryButtons[id] = button
		end
		CategoryButton("all", "Everything (" .. #Entries("all") .. ")", 1)
		for i, category in ipairs(ns.art.CATEGORIES) do
			CategoryButton(category.id, category.label .. " (" .. #category.items .. ")", i + 1)
		end

		-- Thumbnails
		local thumbs = {}
		for i = 1, PER_PAGE do
			local col, row = (i - 1) % GRID_COLUMNS, math.floor((i - 1) / GRID_COLUMNS)
			local button = CreateFrame("Button", nil, parent)
			button:SetSize(THUMB, THUMB)
			button:SetPoint("TOPLEFT", parent, "TOPLEFT", GRID_LEFT + col * THUMB_STEP, -TOP - row * THUMB_STEP)
			button.Edge = Border(button, 2)
			button.Art = button:CreateTexture(nil, "ARTWORK")
			button.Art:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
			button.Art:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
			local hl = button:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints(button)
			hl:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.12)
			button.InUse = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			button.InUse:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
			button.InUse:SetText("|cff40ff40● in use|r")
			button:SetScript("OnClick", function(self)
				if self.entry then
					picked = self.entry.key
					page.Refresh()
				end
			end)
			button:SetScript("OnEnter", function(self)
				if self.entry then
					Theme.ShowTooltip(self, self.entry.word, ns.art.CategoryLabel(self.entry.category) .. "\nClick to preview it on the right.")
				end
			end)
			button:SetScript("OnLeave", Theme.HideTooltip)
			thumbs[i] = button
		end

		-- Pages
		local gridBottom = -TOP - GRID_ROWS * THUMB_STEP
		local prev = ActionButton(parent, "< Previous", 110)
		prev:SetPoint("TOPLEFT", parent, "TOPLEFT", GRID_LEFT, gridBottom - 4)
		local nextButton = ActionButton(parent, "Next >", 110)
		nextButton:SetPoint("TOPRIGHT", parent, "TOPLEFT", GRID_LEFT + GRID_COLUMNS * THUMB_STEP - (THUMB_STEP - THUMB), gridBottom - 4)
		local pageText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		pageText:SetPoint("LEFT", prev, "RIGHT", 0, 0)
		pageText:SetPoint("RIGHT", nextButton, "LEFT", 0, 0)
		prev:SetScript("OnClick", function()
			pageIndex = pageIndex - 1
			page.Refresh()
		end)
		nextButton:SetScript("OnClick", function()
			pageIndex = pageIndex + 1
			page.Refresh()
		end)

		-- Preview panel: the picked sequence on a loop, then its three frames.
		local panel = CreateFrame("Frame", nil, parent)
		panel:SetPoint("TOPLEFT", parent, "TOPLEFT", PANEL_LEFT, -TOP)
		panel:SetSize(BIG + 8 + 12 + BUTTON_WIDTH, 1)

		local stage = CreateFrame("Frame", nil, panel)
		stage:SetSize(BIG + 8, BIG + 8)
		stage:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
		SetEdge(Border(stage, 1), Theme.COLOR_BORDER, 0.8)
		local big = stage:CreateTexture(nil, "ARTWORK")
		big:SetSize(BIG, BIG)
		big:SetPoint("CENTER")

		local word = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		word:SetPoint("TOP", stage, "BOTTOM", 0, -6)
		local where = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		where:SetPoint("TOP", word, "BOTTOM", 0, -2)
		where:SetTextColor(Theme.COLOR_TEXT_MUTED.r, Theme.COLOR_TEXT_MUTED.g, Theme.COLOR_TEXT_MUTED.b)

		local small = {}
		for i, name in ipairs({ "onset", "peak", "aftershock" }) do
			local tex = panel:CreateTexture(nil, "ARTWORK")
			tex:SetSize(SMALL, SMALL)
			tex:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", (BIG + 8 - 3 * SMALL - 2 * 12) / 2 + (i - 1) * (SMALL + 12), -44)
			local label = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			label:SetPoint("TOP", tex, "BOTTOM", 0, -1)
			label:SetText(name)
			small[i] = tex
		end

		local speed = 1
		local speedButton = ActionButton(panel, SPEEDS[1][2], BUTTON_WIDTH)
		speedButton:SetPoint("TOPLEFT", stage, "TOPRIGHT", 12, 0)
		speedButton:SetScript("OnClick", function(self)
			local i = 1
			for n, entry in ipairs(SPEEDS) do
				if entry[1] == speed then
					i = n % #SPEEDS + 1
				end
			end
			speed = SPEEDS[i][1]
			self:SetText(SPEEDS[i][2])
		end)

		local useButton = ActionButton(panel, "Use for this event", BUTTON_WIDTH)
		useButton:SetPoint("TOPLEFT", speedButton, "BOTTOMLEFT", 0, -16)
		Theme.StyleActionButton(useButton, true)
		useButton:SetScript("OnClick", function()
			if picked then
				ns.SetEvent(EventId(), "art", picked)
			end
		end)
		local randomButton = ActionButton(panel, "Random from category", BUTTON_WIDTH)
		randomButton:SetPoint("TOPLEFT", useButton, "BOTTOMLEFT", 0, -6)
		randomButton:SetScript("OnClick", function()
			local entry = picked and ns.art.Get(picked)
			if entry then
				ns.SetEvent(EventId(), "art", "random:" .. entry.category)
			end
		end)
		local playButton = ActionButton(panel, "Play on screen", BUTTON_WIDTH)
		playButton:SetPoint("TOPLEFT", randomButton, "BOTTOMLEFT", 0, -16)
		playButton:SetScript("OnClick", function()
			if picked then
				ns.announcer:Preview(EventId(), picked)
			end
		end)
		local eventsButton = ActionButton(panel, "Back to Events", BUTTON_WIDTH)
		eventsButton:SetPoint("TOPLEFT", playButton, "BOTTOMLEFT", 0, -6)
		eventsButton:SetScript("OnClick", function()
			ns.ui.Open("events")
		end)
		local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		hint:SetPoint("TOPLEFT", eventsButton, "BOTTOMLEFT", 0, -10)
		hint:SetWidth(BUTTON_WIDTH)
		hint:SetJustifyH("LEFT")
		hint:SetText("Play on screen uses the event's animation, text and position with this art. Nothing is kept until you press Use.")

		-- The loop: onset, peak, aftershock at the art's frame times, a hold, again.
		local frames, step, elapsed = nil, 1, 0
		local times = ns.art.FRAME_TIMES
		stage:SetScript("OnUpdate", function(_, dt)
			if not frames then
				return
			end
			elapsed = elapsed + dt * speed
			local length = step == 3 and (times[3] + LOOP_HOLD) or times[step]
			if elapsed >= length then
				elapsed = elapsed - length
				step = step % 3 + 1
				big:SetTexture(frames[step])
			end
		end)

		local function ShowPicked()
			local entry = picked and ns.art.Get(picked)
			frames, step, elapsed = entry and entry.frames, 1, 0
			for i, tex in ipairs(small) do
				tex:SetTexture(entry and entry.frames[i] or nil)
				tex:SetShown(entry ~= nil)
			end
			big:SetShown(entry ~= nil)
			useButton:SetEnabled(entry ~= nil)
			randomButton:SetEnabled(entry ~= nil)
			playButton:SetEnabled(entry ~= nil)
			if entry then
				big:SetTexture(entry.frames[1])
				word:SetText(entry.word)
				where:SetText(ns.art.CategoryLabel(entry.category) .. "  ·  " .. picked)
			else
				word:SetText("Pick a thumbnail")
				where:SetText("")
			end
		end

		page.height = TOP + math.max((#ns.art.CATEGORIES + 1) * LIST_STEP, GRID_ROWS * THUMB_STEP + 30, BIG + 8 + 44 + SMALL + 16)

		local shownFor -- the event the picked art was last synced to
		function page.Refresh()
			for _, row in ipairs(rows) do
				row:RefreshValue()
			end
			local current = CurrentArt()
			nowText:SetText("Now: " .. ns.art.Describe(current))
			-- Opening the tab (or switching event) starts on the event's own art.
			if shownFor ~= EventId() then
				shownFor = EventId()
				local entry = current and ns.art.Get(current)
				if entry then
					picked = current
				end
			end

			for id, button in pairs(categoryButtons) do
				local c = id == filter and Theme.COLOR_ACCENT or Theme.COLOR_BORDER
				button.ComicBorder:SetColorTexture(c.r, c.g, c.b, id == filter and 0.9 or 0.8)
			end

			local list = Entries(filter)
			local pages = math.max(1, math.ceil(#list / PER_PAGE))
			pageIndex = math.max(1, math.min(pageIndex, pages))
			local first = (pageIndex - 1) * PER_PAGE
			for i, button in ipairs(thumbs) do
				local entry = list[first + i]
				button.entry = entry
				if entry then
					local art = ns.art.Get(entry.key)
					button.Art:SetTexture(art and art.frames[2] or nil)
					local selected = entry.key == picked
					SetEdge(button.Edge, selected and Theme.COLOR_ACCENT or Theme.COLOR_BORDER, selected and 1 or 0.8)
					button.InUse:SetShown(entry.key == current)
					button:Show()
				else
					button:Hide()
				end
			end
			pageText:SetText("Page " .. pageIndex .. " / " .. pages .. "   ·   " .. #list .. " sequences")
			prev:SetEnabled(pageIndex > 1)
			nextButton:SetEnabled(pageIndex < pages)
			ShowPicked()
		end

		return page
	end,
}
