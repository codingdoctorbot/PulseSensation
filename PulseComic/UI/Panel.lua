-- PulseComic — UI/Panel.lua
--
-- PulseComic's own settings window, kept apart from Blizzard's settings panel. Based on
-- PulseHaptics' UI/Panel/Panel.lua: the same SettingsFrameTemplate shell, opaque fill and
-- close buttons, shown with a plain Show plus UISpecialFrames for Escape, never ShowUIPanel
-- (that route reaches the gamepad frame-controls manager and its protected calls).
--
-- Three pages behind tabs: General (this file), Events (EventsPage.lua: what each moment
-- shows) and Profiles (ProfilesPage.lua). Built lazily on first open; no scrolling, no
-- gamepad support yet. Every write goes through ns.Set / ns.SetEvent / ns.profiles, so
-- slash commands and this window stay in step.

local ADDON_NAME, ns = ...

local Theme = ns.ui.Theme
local Rows = ns.ui.Rows

local FRAME_NAME = "PulseComicSettingsFrame"
local PAGE_TOP = -62 -- below the tabs
local HIT_EVENTS = { "crit", "kill", "critkill" }

local frame -- nil until first open

ns.ui.pages = ns.ui.pages or {} -- id -> { label, order, Build(parent) -> page }

local function Get(key)
	return function()
		return ns.db[key]
	end
end

local function Set(key)
	return function(value)
		ns.Set(key, value)
	end
end

-- extra: master = true (never greyed out), needs = key (greyed out while that key is off)
local function Checkbox(key, label, tooltip, extra)
	local spec = { type = "checkbox", label = label, tooltip = tooltip, get = Get(key), set = Set(key) }
	for k, v in pairs(extra or {}) do
		spec[k] = v
	end
	return spec
end

-- Lays out specs top to bottom; a { type = "column" } entry starts the next column.
-- Returns the rows and the tallest column's height.
function ns.ui.BuildColumns(parent, specs)
	local function NewColumn(index)
		local column = CreateFrame("Frame", nil, parent)
		column:SetPoint("TOPLEFT", parent, "TOPLEFT", (index - 1) * (Theme.COLUMN_WIDTH + Theme.COLUMN_GAP), 0)
		column:SetWidth(Theme.COLUMN_WIDTH)
		return column
	end
	local rows = {}
	local columns, column, y, tallest = 1, NewColumn(1), 0, 0
	for _, spec in ipairs(specs) do
		if spec.type == "column" then
			columns = columns + 1
			column, y = NewColumn(columns), 0
		else
			local row = Rows.Create(column, spec)
			row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -y)
			row:SetPoint("RIGHT", column, "RIGHT", 0, 0)
			y = y + row.rowHeight + Theme.ROW_SPACING
			tallest = math.max(tallest, y)
			rows[#rows + 1] = row
		end
		column:SetHeight(math.max(y, 1))
	end
	return rows, tallest
end

-- ── General page ──────────────────────────────────────────────────────────────────────

local function GeneralSpecs()
	return {
		{ type = "header", label = "General" },
		Checkbox("enabled", "Enable PulseComic", "Shows comic, arena and announcer moments for your hits, kills and more. What each one looks like is on the Events tab.", { master = true }),
		Checkbox("jitter", "Random tilt and offset", "Give every hit pop a small random offset and tilt."),
		{
			type = "choice",
			label = "Overall size",
			tooltip = "Scale of everything PulseComic shows; each event has its own size on top.",
			choices = { { 0.75, "75%" }, { 1.0, "100%" }, { 1.25, "125%" }, { 1.5, "150%" } },
			get = Get("scale"),
			set = Set("scale"),
		},
		{
			type = "choice",
			label = "Hits that count",
			tooltip = "Mine only: hits shortly after your own cast, or while your auto-attack runs.\n\nEvery hit: anyone's hits on your target.",
			choices = { { "recent", "Mine only" }, { "any", "Every hit" } },
			get = Get("attribution"),
			set = Set("attribution"),
		},

		{ type = "header", label = "Kill detection" },
		Checkbox(
			"killEvent",
			"Killing-blow event (PARTY_KILL)",
			"The client reports who landed each killing blow in your group. Only your own (and, if enabled, your pet's) count, and they count even when you swapped targets."
		),
		Checkbox(
			"killUnitDead",
			"Target death check (UnitIsDead)",
			"The previous method: checks whether your target is dead a moment after your hit. Cannot tell whose blow it was, so a groupmate's kill also shows."
		),
		Checkbox("killPet", "Count pet killing blows", "Your pet's killing blows count as yours. Needs the killing-blow event.", { needs = "killEvent" }),
		Checkbox(
			"killLog",
			"Kill log in chat",
			"Prints who landed every killing blow the client reports (you, your pet, a groupmate or someone else) and whether PulseComic counted it. Use it to check group and pet behaviour."
		),

		{ type = "header", label = "Critical hits" },
		{
			type = "checkbox",
			label = "Show critical hits",
			tooltip = "The Critical hit event. Off: crits no longer pop on their own; a crit that kills still shows the Critical killing blow event.",
			get = function()
				return ns.db.events.crit.enabled
			end,
			set = function(value)
				ns.SetEvent("crit", "enabled", value)
			end,
		},
		{
			type = "checkbox",
			label = "Damage numbers",
			tooltip = "The detail line of the three hit events: the hit's damage, drawn by the client and never read by the addon.",
			get = function()
				return ns.db.events.crit.details
			end,
			set = function(value)
				for _, id in ipairs(HIT_EVENTS) do
					ns.SetEvent(id, "details", value)
				end
			end,
		},
		{
			type = "buttons",
			label = "Show a frame",
			tooltip = "Plays a hit frame with plain test values, no fight needed.",
			buttons = {
				{
					"Crit",
					function()
						ns.Test("pow")
					end,
				},
				{
					"Kill",
					function()
						ns.Test("ko")
					end,
				},
				{
					"Crit kill",
					function()
						ns.Test("overkill")
					end,
				},
			},
		},

		{ type = "header", label = "Extras" },
		Checkbox("meter", "Hit meter (prototype)", "On-screen bars of damage against health, drawn by the client from secret values."),
		{
			type = "checkbox",
			label = "Minimap button",
			tooltip = "Left-click opens this window, right-click turns PulseComic on or off, drag to move. Account-wide.",
			get = function()
				return not ns.account.minimap.hide
			end,
			set = function(value)
				if ns.minimap then
					ns.minimap:SetShown(value)
				end
			end,
			master = true,
		},
		Checkbox("debug", "Debug feed in chat", "Prints the raw feed values for every hit on your target; secret ones show as <secret>."),
		{
			type = "buttons",
			label = "Credits",
			tooltip = "Prints the font attributions (designers, copyright, SIL Open Font License 1.1) to chat.",
			master = true,
			buttons = {
				{
					"Font credits",
					function()
						ns.PrintCredits()
					end,
				},
			},
		},

		{ type = "column" },
		{ type = "header", label = "Announcer" },
		{ type = "note", label = "Which moments show, and how, is on the Events tab." },
		Checkbox("annSound", "Event sounds", "Master switch for the sound each event can play."),
		Checkbox("annFirstBloodSolo", "First blood when solo", "Also show First blood when you are not in a group."),
		Checkbox("annFeed", "Kill feed", "Top right: who in your group killed what. Enemy names are drawn by the client; when it has no name, \"an enemy\"."),
		{
			type = "buttons",
			label = "Test",
			tooltip = "Demo: First blood, Double kill, Killing spree and MVP plus a kill-feed line.",
			buttons = {
				{
					"Demo",
					function()
						ns.announcer:Demo()
					end,
				},
			},
		},
	}
end

ns.ui.pages.general = {
	label = "General",
	order = 1,
	Build = function(parent)
		local rows, height = ns.ui.BuildColumns(parent, GeneralSpecs())
		return {
			height = height,
			Refresh = function()
				local enabled = ns.db.enabled
				for _, row in ipairs(rows) do
					row:RefreshValue()
					-- Everything but the master switches greys out while PulseComic is off.
					local spec = row.spec
					if not spec.master then
						local on = enabled and (not spec.needs or ns.db[spec.needs])
						row:SetRowEnabled(on and true or false)
					end
				end
			end,
		}
	end,
}

-- ── Window ────────────────────────────────────────────────────────────────────────────

local function addonVersion()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if type(get) == "function" then
		local ok, version = pcall(get, ADDON_NAME, "Version")
		if ok and type(version) == "string" and version ~= "" then
			return "v" .. version
		end
	end
	return ""
end

local function createWindow()
	for _, template in ipairs({ "SettingsFrameTemplate", "ButtonFrameTemplate" }) do
		local ok, created = pcall(CreateFrame, "Frame", FRAME_NAME, UIParent, template)
		if ok and created then
			return created
		end
	end
	return CreateFrame("Frame", FRAME_NAME, UIParent)
end

local function SelectPage(f, id)
	f.current = id
	for pageId, page in pairs(f.pages) do
		page.frame:SetShown(pageId == id)
		local tab = f.tabs[pageId]
		local c = pageId == id and Theme.COLOR_ACCENT or Theme.COLOR_BORDER
		tab.ComicBorder:SetColorTexture(c.r, c.g, c.b, pageId == id and 0.9 or 0.8)
	end
	ns.ui.Refresh()
end

local function buildWindow()
	local f = createWindow()
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()

	local titleText = f.NineSlice and f.NineSlice.Text
	if not titleText then
		titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		titleText:SetPoint("TOP", f, "TOP", 0, -5)
	end
	titleText:SetText("PULSECOMIC")
	titleText:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)

	local titleIcon = f:CreateTexture(nil, "OVERLAY")
	titleIcon:SetSize(18, 18)
	titleIcon:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\pow")
	titleIcon:SetPoint("RIGHT", titleText, "LEFT", -6, 0)

	-- SettingsFrameTemplate's Bg sits at an absolute frame level 0, below everything else in
	-- the strata (see PulseHaptics' Panel.lua). Our own fill on the frame avoids that.
	if f.Bg and f.Bg.SetFrameLevel then
		f.Bg:SetFrameLevel(f:GetFrameLevel())
	end
	local fill = f:CreateTexture(nil, "BACKGROUND")
	fill:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
	fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
	fill:SetColorTexture(Theme.COLOR_BG.r, Theme.COLOR_BG.g, Theme.COLOR_BG.b, 1)

	if not f.ClosePanelButton then
		local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
		if ok and close then
			f.ClosePanelButton = close
		end
	end
	if f.ClosePanelButton then
		f.ClosePanelButton:SetScript("OnClick", function()
			f:Hide()
		end)
	end

	local closeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	closeButton:SetSize(96, 22)
	closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
	closeButton:SetText(CLOSE or "Close")
	Theme.StyleActionButton(closeButton, false)
	closeButton:SetScript("OnClick", function()
		f:Hide()
	end)

	local stamp = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	stamp:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 20)
	f.Stamp = stamp

	-- Pages, in tab order.
	local order = {}
	for id, def in pairs(ns.ui.pages) do
		order[#order + 1] = { id = id, def = def }
	end
	table.sort(order, function(a, b)
		return a.def.order < b.def.order
	end)

	f.pages, f.tabs = {}, {}
	local tallest, previousTab = 0, nil
	for _, item in ipairs(order) do
		local pageFrame = CreateFrame("Frame", nil, f)
		pageFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, PAGE_TOP)
		pageFrame:SetPoint("RIGHT", f, "RIGHT", -20, 0)
		local page = item.def.Build(pageFrame)
		page.frame = pageFrame
		pageFrame:SetHeight(math.max(page.height, 1))
		tallest = math.max(tallest, page.height)
		f.pages[item.id] = page

		local tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		tab:SetSize(110, 24)
		if previousTab then
			tab:SetPoint("LEFT", previousTab, "RIGHT", 6, 0)
		else
			tab:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -28)
		end
		tab:SetText(item.def.label)
		Theme.StyleActionButton(tab, false)
		tab:SetScript("OnClick", function()
			SelectPage(f, item.id)
		end)
		f.tabs[item.id] = tab
		previousTab = tab
	end

	f:SetSize(40 + 2 * Theme.COLUMN_WIDTH + Theme.COLUMN_GAP, -PAGE_TOP + tallest + 56)

	f:SetScript("OnShow", function()
		ns.ui.Refresh()
	end)
	f:SetScript("OnHide", function()
		Theme.HideTooltip()
	end)

	tinsert(UISpecialFrames, FRAME_NAME)
	return f
end

-- ── Public ────────────────────────────────────────────────────────────────────────────

function ns.ui.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	frame.Stamp:SetText(addonVersion() .. "   ·   profile: " .. ns.profiles:ActiveName() .. "   ·   /comic opens this window")
	local page = frame.pages[frame.current]
	if page then
		page.Refresh()
	end
end

function ns.ui.Open(pageId)
	if not ns.db then
		return
	end
	if not frame then
		local ok, result = pcall(buildWindow)
		if not ok then
			ns.Say("could not build the settings window (" .. tostring(result) .. ")")
			return
		end
		frame = result
		frame:Show()
		SelectPage(frame, pageId or "general")
	else
		frame:Show()
		if pageId then
			SelectPage(frame, pageId)
		end
	end
	frame:Raise()
end

function ns.ui.Close()
	if frame then
		frame:Hide()
	end
end

function ns.ui.Toggle()
	if frame and frame:IsShown() then
		ns.ui.Close()
	else
		ns.ui.Open()
	end
end
