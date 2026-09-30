-- PulseSync — UI.lua
--
-- Visual interface for profile sharing, string export, import validation, and preset installation.
-- Styled with clean dark panels matching PulseHaptics theme.

local _, Sync = ...

local syncUI = nil

local function createSyncUI()
	if syncUI then
		return syncUI
	end

	local f = CreateFrame("Frame", "PulseSyncFrame", UIParent, "BackdropTemplate")
	f:SetSize(520, 500)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)

	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	f:SetBackdropColor(0.06, 0.08, 0.08, 0.98)

	-- Header
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 22, -18)
	title:SetText("|cff00ffaaPulseSync|r  |cffffffffProfile Hub & Exporter|r")

	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sub:SetPoint("TOPLEFT", 22, -40)
	sub:SetText("Export your tactile gamepad tunings to share, or import community strings.")

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -8, -8)

	-- ── SECTION 1: Export Active Profile ───────────────────────────────────────
	local exportTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	exportTitle:SetPoint("TOPLEFT", 24, -70)
	exportTitle:SetText("|cffffff00Export Profile String|r")

	local exportScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	exportScroll:SetSize(450, 70)
	exportScroll:SetPoint("TOPLEFT", 24, -92)

	local exportBox = CreateFrame("EditBox", nil, exportScroll)
	exportBox:SetMultiLine(true)
	exportBox:SetSize(430, 70)
	exportBox:SetFontObject("GameFontHighlightSmall")
	exportBox:SetAutoFocus(false)
	exportScroll:SetScrollChild(exportBox)

	local btnGenExport = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	btnGenExport:SetSize(150, 22)
	btnGenExport:SetPoint("TOPLEFT", 24, -170)
	btnGenExport:SetText("Generate String")

	local exportStatus = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	exportStatus:SetPoint("LEFT", btnGenExport, "RIGHT", 12, 0)

	btnGenExport:SetScript("OnClick", function()
		local str, err = Sync:ExportProfile()
		if str then
			exportBox:SetText(str)
			exportBox:HighlightText()
			exportBox:SetFocus()
			exportStatus:SetText("|cff44ff44Ready to copy (Ctrl+C)|r")
		else
			exportStatus:SetText("|cffff4444" .. tostring(err) .. "|r")
		end
	end)

	-- ── SECTION 2: Import Profile String ───────────────────────────────────────
	local importTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	importTitle:SetPoint("TOPLEFT", 24, -205)
	importTitle:SetText("|cffffff00Import Profile String|r")

	local importScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	importScroll:SetSize(450, 70)
	importScroll:SetPoint("TOPLEFT", 24, -227)

	local importBox = CreateFrame("EditBox", nil, importScroll)
	importBox:SetMultiLine(true)
	importBox:SetSize(430, 70)
	importBox:SetFontObject("GameFontHighlightSmall")
	importBox:SetAutoFocus(false)
	importScroll:SetScrollChild(importBox)

	local btnDoImport = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	btnDoImport:SetSize(150, 22)
	btnDoImport:SetPoint("TOPLEFT", 24, -305)
	btnDoImport:SetText("Import Profile")

	local importStatus = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	importStatus:SetPoint("LEFT", btnDoImport, "RIGHT", 12, 0)

	btnDoImport:SetScript("OnClick", function()
		local text = strtrim(importBox:GetText() or "")
		if text == "" then
			importStatus:SetText("|cffffcc00Paste string first|r")
			return
		end
		local ok, res = Sync:ImportProfile(text)
		if ok then
			importStatus:SetText("|cff44ff44Imported: " .. tostring(res) .. "|r")
		else
			importStatus:SetText("|cffff4444" .. tostring(res) .. "|r")
		end
	end)

	-- ── SECTION 3: Curated Presets ─────────────────────────────────────────────
	local presetTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	presetTitle:SetPoint("TOPLEFT", 24, -340)
	presetTitle:SetText("|cff00ccffCurated Community Presets|r")

	local curY = -365
	for _, preset in ipairs(Sync.CURATED_PRESETS) do
		local pBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		pBtn:SetSize(160, 22)
		pBtn:SetPoint("TOPLEFT", 24, curY)
		pBtn:SetText(preset.title)

		local pDesc = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		pDesc:SetPoint("LEFT", pBtn, "RIGHT", 10, 0)
		pDesc:SetText(preset.desc)
		pDesc:SetWidth(290)
		pDesc:SetJustifyH("LEFT")

		local pId = preset.id
		pBtn:SetScript("OnClick", function()
			local ok, name = Sync:InstallCuratedPreset(pId)
			if ok then
				importStatus:SetText("|cff44ff44Installed: " .. name .. "|r")
			else
				importStatus:SetText("|cffff4444" .. tostring(name) .. "|r")
			end
		end)

		curY = curY - 32
	end

	syncUI = f
	return f
end

function Sync:ToggleUI()
	local f = createSyncUI()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end
