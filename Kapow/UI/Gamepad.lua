-- KAPOW — UI/Gamepad.lua
--
-- Controller navigation for the settings window (Extras › Controller navigation, off by
-- default). While the window is open and the option is on, the window takes the controller's
-- buttons through OnGamePadButtonDown (no bindings are overridden):
--
--   D-pad up / down      previous / next setting (top to bottom, then the next column)
--   D-pad left / right   change a choice or dropdown, move between a row's buttons; elsewhere
--                        jump to the nearest setting in the column beside
--   A (PAD1)             click: toggle a checkbox, next choice, press a button, type in a box
--   B (PAD2)             close the window
--   LB / RB              previous / next tab
--
-- The focused setting gets a gold frame and its explanation as a tooltip. In combat the
-- window lets go of the controller until combat ends.

local _, ns = ...

local Theme = ns.ui.Theme

local G = {}
ns.ui.gamepad = G

local window -- the settings window while it is open
local inCombat = false -- the window lets go of the controller in combat
local targets, index = {}, 1
local focus

-- ── Targets ───────────────────────────────────────────────────────────────────────────
-- A target is one widget: { widget = w, row = row or nil, sub = i (button rows) }.

local function Visible(widget)
	return widget and widget.IsVisible and widget:IsVisible()
end

local function AddRow(list, row)
	if not Visible(row) then
		return
	end
	if row.Buttons then
		for i, button in ipairs(row.Buttons) do
			if Visible(button) then
				list[#list + 1] = { widget = button, row = row, sub = i }
			end
		end
	elseif row.Control or row.Box then
		list[#list + 1] = { widget = row.Control or row.Box, row = row }
	end
end

local function Collect(list, frame)
	if frame.kapowRows then
		for _, row in ipairs(frame.kapowRows) do
			AddRow(list, row)
		end
		return
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if Visible(child) then
			local kind = child.GetObjectType and child:GetObjectType()
			if (kind == "Button" or kind == "CheckButton") and not child.kapowRows then
				list[#list + 1] = { widget = child }
			else
				Collect(list, child)
			end
		end
	end
end

local COLUMN_SNAP = 60 -- widgets whose left edges are this close share a column

local function SortTargets(list)
	for _, t in ipairs(list) do
		t.x, t.y = t.widget:GetLeft() or 0, t.widget:GetTop() or 0
	end
	-- Column of each target: the row's own left edge (so a row's buttons stay one column).
	for _, t in ipairs(list) do
		local anchor = t.row or t.widget
		t.column = math.floor(((anchor:GetLeft() or 0) + COLUMN_SNAP / 2) / COLUMN_SNAP)
	end
	table.sort(list, function(a, b)
		if a.column ~= b.column then
			return a.column < b.column
		end
		if math.abs(a.y - b.y) > 4 then
			return a.y > b.y
		end
		return a.x < b.x
	end)
end

local function Rebuild()
	local list = {}
	local page = window and window.pages and window.pages[window.current]
	if page and page.frame then
		Collect(list, page.frame)
	end
	SortTargets(list)
	targets = list
	index = math.max(1, math.min(index, #targets))
end

-- ── Focus ─────────────────────────────────────────────────────────────────────────────

local function EnsureFocus()
	if focus then
		return focus
	end
	focus = CreateFrame("Frame", nil, window)
	focus:SetFrameStrata("TOOLTIP")
	focus:EnableMouse(false)
	local c = Theme.COLOR_ACCENT
	local function Edge()
		local t = focus:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(c.r, c.g, c.b, 1)
		return t
	end
	local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(2)
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(2)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(2)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(2)
	return focus
end

local function Show()
	local t = targets[index]
	local f = EnsureFocus()
	if not t then
		f:Hide()
		Theme.HideTooltip()
		return
	end
	f:SetParent(window)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", t.widget, "TOPLEFT", -3, 3)
	f:SetPoint("BOTTOMRIGHT", t.widget, "BOTTOMRIGHT", 3, -3)
	f:Show()
	if t.row and t.row.spec then
		Theme.ShowTooltip(t.widget, t.row.spec.label, t.row.spec.tooltip)
	else
		Theme.HideTooltip()
	end
end

-- ── Actions ───────────────────────────────────────────────────────────────────────────

local function Enabled(widget)
	return not widget.IsEnabled or widget:IsEnabled()
end

-- The values a dropdown row offers, read by running its menu builder against a stand-in.
local function DropdownValues(spec)
	local values = {}
	local dummy = setmetatable({}, {
		__index = function()
			return function(self)
				return self
			end
		end,
	})
	local root = setmetatable({
		CreateRadio = function(self, _, _, _, value)
			values[#values + 1] = value
			return dummy
		end,
	}, getmetatable(dummy))
	pcall(spec.build, root, function()
		return false
	end, function() end)
	return values
end

local function Cycle(row, dir)
	local spec = row.spec
	local values = {}
	if spec.type == "choice" then
		for i, choice in ipairs(spec.choices) do
			values[i] = choice[1]
		end
	elseif spec.type == "dropdown" then
		values = DropdownValues(spec)
	end
	if #values == 0 then
		return false
	end
	local current = spec.get()
	local at = 0
	for i, v in ipairs(values) do
		if v == current then
			at = i
			break
		end
	end
	local nextAt = ((at - 1 + dir) % #values) + 1
	if at == 0 then
		nextAt = dir > 0 and 1 or #values
	end
	Theme.PlayCheckSound(true)
	spec.set(values[nextAt])
	row:RefreshValue()
	return true
end

-- The nearest target in the column to the left (dir -1) or right (+1).
local function Beside(dir)
	local here = targets[index]
	if not here then
		return nil
	end
	local best, bestDist
	for i, t in ipairs(targets) do
		local ahead = (dir > 0 and t.column > here.column) or (dir < 0 and t.column < here.column)
		if ahead then
			local dist = math.abs(t.column - here.column) * 1000 + math.abs(t.y - here.y)
			if not bestDist or dist < bestDist then
				best, bestDist = i, dist
			end
		end
	end
	return best
end

local function Horizontal(dir)
	local t = targets[index]
	if not t then
		return
	end
	local row = t.row
	if row and Enabled(t.widget) and (row.spec.type == "choice" or row.spec.type == "dropdown") then
		Cycle(row, dir)
		return
	end
	if row and row.Buttons then
		local nextIndex = index + dir
		local n = targets[nextIndex]
		if n and n.row == row then
			index = nextIndex
			Show()
			return
		end
	end
	local beside = Beside(dir)
	if beside then
		index = beside
		Show()
	end
end

local function Activate()
	local t = targets[index]
	if not t or not Enabled(t.widget) then
		return
	end
	local row = t.row
	if row and (row.spec.type == "choice" or row.spec.type == "dropdown") then
		Cycle(row, 1)
	elseif row and row.Box then
		row.Box:SetFocus()
	elseif t.widget.Click then
		t.widget:Click()
	end
	-- A click may have changed the page (tabs, the Events lists): find the widgets again.
	Rebuild()
	Show()
end

local function SwitchTab(dir)
	local order = window.tabOrder
	if not order or #order == 0 then
		return
	end
	local at = 1
	for i, id in ipairs(order) do
		if id == window.current then
			at = i
		end
	end
	local id = order[((at - 1 + dir) % #order) + 1]
	ns.ui.Open(id)
	index = 1
	Rebuild()
	Show()
end

local function OnButton(_, key)
	if inCombat then
		return
	end
	if key == "PADDUP" or key == "PADDDOWN" then
		Rebuild()
		if #targets > 0 then
			index = ((index - 1 + (key == "PADDDOWN" and 1 or -1)) % #targets) + 1
		end
		Show()
	elseif key == "PADDLEFT" then
		Horizontal(-1)
	elseif key == "PADDRIGHT" then
		Horizontal(1)
	elseif key == "PAD1" then
		Activate()
	elseif key == "PAD2" then
		ns.ui.Close()
	elseif key == "PADLSHOULDER" then
		SwitchTab(-1)
	elseif key == "PADRSHOULDER" then
		SwitchTab(1)
	end
end

-- ── Capture ───────────────────────────────────────────────────────────────────────────

local capturing = false

local function Capture(on)
	capturing = on and true or false
	if not window or not window.EnableGamePadButton then
		return
	end
	pcall(window.EnableGamePadButton, window, capturing)
	window:SetScript("OnGamePadButtonDown", on and OnButton or nil)
	if not on and focus then
		focus:Hide()
	end
end

local function Wanted()
	return window and window:IsShown() and ns.db and ns.db.gamepadNav and not inCombat
end

function G.Sync()
	if Wanted() then
		Capture(true)
		Rebuild()
		Show()
	else
		Capture(false)
	end
end

function G.OnShow(f)
	window = f
	index = 1
	G.Sync()
end

function G.OnHide()
	Capture(false)
end

-- After a page refresh the widgets may have moved or appeared (or the option changed).
function G.Refresh()
	if Wanted() then
		if not capturing then
			Capture(true)
		end
		Rebuild()
		Show()
	elseif capturing then
		Capture(false)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	inCombat = event == "PLAYER_REGEN_DISABLED"
	G.Sync()
end)
