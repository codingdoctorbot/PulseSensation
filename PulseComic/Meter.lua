-- PulseComic — Meter.lua (prototype)
--
-- An on-screen panel that answers questions chat cannot. A secret number prints as nothing
-- useful, but the client will still DRAW it, and a StatusBar given secret min/max/value
-- will still FILL. So the panel lets the engine do the maths and shows the result:
--
--   * Bar      SetMinMaxValues(0, health) + SetValue(damage): the fill is damage / health,
--              computed by the client, never seen by Lua. The numbers are drawn on top.
--   * Lamp     A tiny clipping window over the far right end of the same bar made ZOOM
--              times wider. Only the last 1/ZOOM of the bar is visible, so the lamp stays
--              dark until damage >= ~99.9% of health and is fully lit at >= 100% (the bar
--              clamps). That is a threshold, "damage >= health", decided by geometry.
--   * Slide    The OVERKILL art anchored to the RIGHT edge of a zoomed bar's fill texture,
--              inside a clipping window at the bar's end. It slides into view only on a
--              killing-size hit.
--
-- Which health reading is "health before the hit" is unknown: UNIT_HEALTH may arrive before
-- or after the combat-text event. So two candidates get a row each, and you read off which
-- one behaves. `/comic meter test <dmg> <hp>` drives it with plain numbers, to check the
-- geometry (huge bar widths, clipping, anchoring to a fill texture) out of combat first.

local _, ns = ...

local M = {}
ns.meter = M

local FONT = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ART = "Interface\\AddOns\\PulseComic\\Media\\overkill"
local ZOOM = 1000 -- lamp / slide threshold starts at 1 - 1/ZOOM of health (99.9%)

local BAR_W, BAR_H = 200, 14
local LAMP_W = 28
local SLIDE = 128

local interpolation = _G.Enum
	and _G.Enum.StatusBarInterpolation
	and _G.Enum.StatusBarInterpolation.ExponentialEaseOut

-- Health of the target from the last two UNIT_HEALTH events. May be secret; only ever
-- stored and handed to StatusBar.
local healthLast, healthBefore

local panel, rows, slideBar

-- ── Building ──────────────────────────────────────────────────────────────────────────
local function NewText(parent, size)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, size, "OUTLINE")
	return fs
end

local function NewBar(parent, width, height, r, g, b, a)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(width, height)
	bar:SetStatusBarTexture(WHITE)
	bar:SetStatusBarColor(r, g, b, a or 1)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

-- A clipping window showing only the right end of a bar ZOOM times its width.
local function NewZoomWindow(parent, width, height)
	local window = CreateFrame("Frame", nil, parent)
	window:SetSize(width, height)
	window:SetClipsChildren(true)
	local bg = window:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(window)
	bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
	return window
end

local function NewRow(index, label, withLamp)
	local y = -26 - (index - 1) * 22
	local row = {}

	row.label = NewText(panel, 11)
	row.label:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
	row.label:SetText(label)

	row.track = panel:CreateTexture(nil, "BACKGROUND")
	row.track:SetColorTexture(0.12, 0.12, 0.12, 0.9)
	row.track:SetSize(BAR_W, BAR_H)
	row.track:SetPoint("TOPLEFT", panel, "TOPLEFT", 120, y)

	row.bar = NewBar(panel, BAR_W, BAR_H, 1, 0.75, 0.1)
	row.bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 120, y)

	-- Anchored to the panel, not the bar: a bar holding a secret value can make anything
	-- anchored to it anchor-secret.
	row.text = NewText(panel, 10)
	row.text:SetPoint("CENTER", panel, "TOPLEFT", 120 + BAR_W / 2, y - BAR_H / 2)

	if withLamp then
		row.lampWindow = NewZoomWindow(panel, LAMP_W, BAR_H)
		row.lampWindow:SetPoint("TOPLEFT", panel, "TOPLEFT", 120 + BAR_W + 8, y)
		row.lamp = NewBar(row.lampWindow, LAMP_W * ZOOM, BAR_H, 1, 0.15, 0.1)
		row.lamp:SetPoint("RIGHT", row.lampWindow, "RIGHT")
	end
	return row
end

local function Build()
	panel = CreateFrame("Frame", "PulseComicMeter", UIParent)
	panel:SetSize(120 + BAR_W + LAMP_W + 18, 26 + 3 * 22 + SLIDE + 12)
	panel:SetPoint("CENTER", UIParent, "CENTER", -360, 0)
	panel:SetFrameStrata("MEDIUM")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

	local bg = panel:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(panel)
	bg:SetColorTexture(0, 0, 0, 0.65)

	local title = NewText(panel, 12)
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
	title:SetText("|cffffd60aPulseComic meter|r  damage / health, drawn by the client")

	rows = {
		max = NewRow(1, "of max health", false),
		hit = NewRow(2, "of health at hit", true),
		prev = NewRow(3, "of health, prior", true),
	}

	-- OVERKILL slide: the art rides the right edge of a zoomed bar's (invisible) fill.
	local window = NewZoomWindow(panel, SLIDE, SLIDE)
	window:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
	slideBar = NewBar(window, SLIDE * ZOOM, SLIDE, 0, 0, 0, 0)
	slideBar:SetPoint("RIGHT", window, "RIGHT")
	local art = slideBar:CreateTexture(nil, "OVERLAY")
	art:SetTexture(ART)
	art:SetSize(SLIDE, SLIDE)
	art:SetPoint("RIGHT", slideBar:GetStatusBarTexture(), "RIGHT")

	local slideLabel = NewText(panel, 10)
	slideLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
	slideLabel:SetText("slide:\n" .. "damage >= health")
	M.slideLabel = slideLabel
end

-- ── Driving ───────────────────────────────────────────────────────────────────────────
-- `value` and `max` may be secret numbers. Snap to 0, then ease to the target so every hit
-- visibly animates.
local function Fill(bar, value, max)
	bar:SetMinMaxValues(0, max)
	bar:SetValue(0)
	if interpolation then
		bar:SetValue(value, interpolation)
	else
		bar:SetValue(value)
	end
end

local function ShowRow(row, amount, health)
	if type(health) ~= "number" then
		row.text:SetText("no reading")
		Fill(row.bar, 0, 1)
		if row.lamp then
			Fill(row.lamp, 0, 1)
		end
		return
	end
	Fill(row.bar, amount, health)
	if row.lamp then
		Fill(row.lamp, amount, health)
	end
	row.text:SetFormattedText("%s / %s", ns.AmountText(amount), ns.AmountText(health))
end

-- One hit. All three readings are taken here, and handed on without being looked at.
function M:Show(amount, healthNow, healthPrior, healthMax)
	if not panel or type(amount) ~= "number" then
		return
	end
	ShowRow(rows.max, amount, healthMax)
	ShowRow(rows.hit, amount, healthNow)
	ShowRow(rows.prev, amount, healthPrior)

	local source = healthNow
	if ns.db.meterSource == "prev" then
		source = healthPrior
	end
	if type(source) == "number" then
		Fill(slideBar, amount, source)
	else
		Fill(slideBar, 0, 1)
	end
end

function M:OnHit(amount)
	if not ns.db.meter then
		return
	end
	self:Show(amount, UnitHealth("target"), healthBefore, UnitHealthMax("target"))
end

-- ── Health tracking ───────────────────────────────────────────────────────────────────
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event)
	if event == "UNIT_HEALTH" then
		healthBefore = healthLast
		healthLast = UnitHealth("target")
	else -- PLAYER_TARGET_CHANGED
		healthLast = UnitHealth("target")
		healthBefore = healthLast
	end
end)

local function Sync()
	watcher:UnregisterEvent("UNIT_HEALTH")
	watcher:UnregisterEvent("PLAYER_TARGET_CHANGED")
	if ns.db.meter then
		if not panel then
			Build()
		end
		watcher:RegisterUnitEvent("UNIT_HEALTH", "target")
		watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
		healthLast = UnitHealth("target")
		healthBefore = healthLast
		panel:Show()
	elseif panel then
		panel:Hide()
	end
end

function M:Init()
	Sync()
end

-- Re-applies ns.db.meter after it changed elsewhere (the settings window).
function M:Refresh()
	Sync()
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────
function M:Command(arg)
	local sub, rest = string.match(arg or "", "^%s*(%S*)%s*(.-)%s*$")
	sub = string.lower(sub or "")
	if sub == "" then
		ns.db.meter = not ns.db.meter
		Sync()
		ns.Say("meter " .. (ns.db.meter and "on: drag to move" or "off"))
	elseif sub == "test" then
		-- Plain numbers typed by the player, never secrets: safe to do arithmetic on.
		local dmgText, hpText, maxText = string.match(rest, "^(%d+)%s+(%d+)%s*(%d*)$")
		if not dmgText then
			ns.Say("usage: /comic meter test <damage> <health> [maxHealth]   e.g. 5000 4000 = overkill")
			return
		end
		if not ns.db.meter then
			ns.db.meter = true
			Sync()
		end
		local dmg, hp = tonumber(dmgText), tonumber(hpText)
		self:Show(dmg, hp, hp, tonumber(maxText) or hp * 2)
	elseif sub == "source" then
		if rest == "hit" or rest == "prev" then
			ns.db.meterSource = rest
			ns.Say("slide uses health " .. (rest == "hit" and "read at the hit" or "from the prior update"))
		else
			ns.Say("usage: /comic meter source hit | prev")
		end
	else
		ns.Say("/comic meter  ·  meter test <damage> <health> [max]  ·  meter source hit|prev")
	end
end
