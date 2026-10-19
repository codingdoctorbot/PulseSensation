-- PulseComic — UI/Theme.lua
--
-- Palette and shared helpers for PulseComic's settings window. A trimmed port of
-- PulseHaptics' UI/Panel/Theme.lua: same surfaces and button styling, a comic-yellow accent,
-- and no SmartNavigation hooks (no gamepad support in this window yet).

local _, ns = ...

ns.ui = ns.ui or {}
local Theme = {}
ns.ui.Theme = Theme

-- ── Geometry ──────────────────────────────────────────────────────────────────────────
Theme.COLUMN_WIDTH = 480 -- the window holds two columns of rows
Theme.COLUMN_GAP = 20
Theme.ROW_HEIGHT = 26
Theme.HEADER_ROW_H = 40
Theme.ROW_SPACING = 2
Theme.TEXT_LEFT = 37
Theme.CONTROL_LEFT = 300 -- where a row's control starts, from the row's left edge
Theme.CHECKBOX_SIZE_X = 30
Theme.CHECKBOX_SIZE_Y = 29
Theme.BUTTON_WIDTH = 150
Theme.DROPDOWN_WIDTH = 220
Theme.EDIT_WIDTH = 220

-- ── Colors ────────────────────────────────────────────────────────────────────────────
Theme.COLOR_ACCENT = { r = 1.00, g = 0.84, b = 0.04 } -- the |cffffd60a chat prefix
Theme.COLOR_BG = { r = 0.035, g = 0.040, b = 0.055 }
Theme.COLOR_SURFACE = { r = 0.060, g = 0.068, b = 0.085 }
Theme.COLOR_BORDER = { r = 0.18, g = 0.22, b = 0.28 }
Theme.COLOR_TEXT_PRIMARY = { r = 0.90, g = 0.93, b = 0.96 }
Theme.COLOR_TEXT_MUTED = { r = 0.53, g = 0.58, b = 0.68 }

-- ── Helpers ───────────────────────────────────────────────────────────────────────────

function Theme.CreateHoverBackground(frame)
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.08)
	texture:SetPoint("TOPLEFT", frame, "TOPLEFT", -10, 0)
	texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 0)
	texture:Hide()
	return texture
end

-- One tooltip for the window: control name as title, description wrapped underneath.
local tooltip

local function getTooltip()
	if tooltip then
		return tooltip
	end
	local ok, frame = pcall(CreateFrame, "GameTooltip", "PulseComicTooltip", UIParent, "SharedTooltipTemplate")
	if ok and frame then
		tooltip = frame
	else
		tooltip = GameTooltip
	end
	return tooltip
end

function Theme.ShowTooltip(owner, title, body)
	if not title and not body then
		return
	end
	local tip = getTooltip()
	if not tip then
		return
	end
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
	if tip then
		tip:Hide()
	end
end

function Theme.PlayCheckSound(on)
	if not SOUNDKIT then
		return
	end
	local kit = on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
	if kit then
		PlaySound(kit)
	end
end

-- Flat surface, thin border and accent highlight over a UIPanelButtonTemplate button.
function Theme.StyleActionButton(button, isAccent)
	if not button then
		return
	end
	for _, piece in ipairs({ button.Left, button.Middle, button.Right }) do
		piece:SetAlpha(0)
	end
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
		texture:SetAlpha(0)
	end

	if not button.ComicBg then
		local bg = button:CreateTexture(nil, "BACKGROUND")
		bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		bg:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 0.95)
		button.ComicBg = bg

		local border = button:CreateTexture(nil, "BORDER")
		border:SetAllPoints(button)
		local c = isAccent and Theme.COLOR_ACCENT or Theme.COLOR_BORDER
		border:SetColorTexture(c.r, c.g, c.b, isAccent and 0.7 or 0.8)
		button.ComicBorder = border

		local hl = button:CreateTexture(nil, "HIGHLIGHT")
		hl:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		hl:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		hl:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.18)
		button:SetHighlightTexture(hl)
	end

	local fs = button:GetFontString()
	if fs then
		fs:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)
	end
end

-- Greys a row's label and desaturates its widgets.
function Theme.DisplayEnabled(row, enabled)
	local color = enabled and Theme.COLOR_TEXT_PRIMARY or Theme.COLOR_TEXT_MUTED
	if row.Text then
		row.Text:SetTextColor(color.r, color.g, color.b)
	end
	if row.DesaturateHierarchy then
		row:DesaturateHierarchy(enabled and 0 or 1)
	end
end
