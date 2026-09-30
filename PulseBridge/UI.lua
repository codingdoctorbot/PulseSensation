-- PulseBridge — UI.lua
--
-- Compact configuration and testing panel for PulseBridge.
-- Clean, modern UI styling matching PulseHaptics theme.

local _, Bridge = ...

local uiFrame = nil

local function createBridgeUI()
	if uiFrame then
		return uiFrame
	end

	local f = CreateFrame("Frame", "PulseBridgeFrame", UIParent, "BackdropTemplate")
	f:SetSize(420, 360)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
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
	f:SetBackdropColor(0.08, 0.08, 0.10, 0.95)

	-- Title Header
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 20, -18)
	title:SetText("|cff00ffccPulseBridge|r  |cffffffffHooks & Dispatcher|r")

	local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	subtitle:SetPoint("TOPLEFT", 20, -40)
	subtitle:SetText("Dispatches haptics for WeakAuras, BigWigs, DBM, and macros.")

	-- Close Button
	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -8, -8)

	-- Status Section
	local statusBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
	statusBox:SetSize(380, 50)
	statusBox:SetPoint("TOPLEFT", 20, -65)
	statusBox:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	statusBox:SetBackdropColor(0.03, 0.03, 0.05, 0.8)
	statusBox:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.8)

	local statusText = statusBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusText:SetPoint("TOPLEFT", 12, -8)

	local function refreshStatus()
		local eng = Bridge:IsConnected() and "|cff44ff44● Connected|r" or "|cffff4444● Disconnected|r"
		local wa = Bridge.HasWeakAuras and "|cff44ff44Active|r" or "|cff888888None|r"
		local bw = Bridge.HasBigWigs and "|cff44ff44Active|r" or "|cff888888None|r"
		local dbm = Bridge.HasDBM and "|cff44ff44Active|r" or "|cff888888None|r"
		statusText:SetText(string.format("Engine: %s\nWeakAuras: %s   BigWigs: %s   DBM: %s", eng, wa, bw, dbm))
	end

	-- Master Enable Checkbox
	local masterCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	masterCheck:SetPoint("TOPLEFT", 20, -125)
	masterCheck.text = masterCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	masterCheck.text:SetPoint("LEFT", masterCheck, "RIGHT", 4, 1)
	masterCheck.text:SetText("Enable Haptic Bridge")
	masterCheck:SetChecked(Bridge.db and Bridge.db.enabled)
	masterCheck:SetScript("OnClick", function(self)
		Bridge.db.enabled = self:GetChecked()
	end)

	-- Sub-Hooks Checkboxes
	local waCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	waCheck:SetPoint("TOPLEFT", 20, -155)
	waCheck.text = waCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	waCheck.text:SetPoint("LEFT", waCheck, "RIGHT", 4, 1)
	waCheck.text:SetText("WeakAuras Hook")
	waCheck:SetChecked(Bridge.db and Bridge.db.weakaurasEnabled)
	waCheck:SetScript("OnClick", function(self)
		Bridge.db.weakaurasEnabled = self:GetChecked()
	end)

	local bwCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	bwCheck:SetPoint("TOPLEFT", 150, -155)
	bwCheck.text = bwCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	bwCheck.text:SetPoint("LEFT", bwCheck, "RIGHT", 4, 1)
	bwCheck.text:SetText("BigWigs Hook")
	bwCheck:SetChecked(Bridge.db and Bridge.db.bigwigsEnabled)
	bwCheck:SetScript("OnClick", function(self)
		Bridge.db.bigwigsEnabled = self:GetChecked()
	end)

	local dbmCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	dbmCheck:SetPoint("TOPLEFT", 270, -155)
	dbmCheck.text = dbmCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	dbmCheck.text:SetPoint("LEFT", dbmCheck, "RIGHT", 4, 1)
	dbmCheck.text:SetText("DBM Hook")
	dbmCheck:SetChecked(Bridge.db and Bridge.db.dbmEnabled)
	dbmCheck:SetScript("OnClick", function(self)
		Bridge.db.dbmEnabled = self:GetChecked()
	end)

	-- Global Scale Slider
	local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	scaleLabel:SetPoint("TOPLEFT", 24, -195)
	scaleLabel:SetText("Global Scale:")

	local slider = CreateFrame("Slider", "PulseBridgeScaleSlider", f, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 110, -195)
	slider:SetSize(250, 16)
	slider:SetMinMaxValues(0.2, 2.0)
	slider:SetValueStep(0.05)
	slider:SetObeyStepOnDrag(true)
	local curScale = Bridge.db and Bridge.db.globalScale or 1.0
	slider:SetValue(curScale)
	local sName = slider:GetName()
	if _G[sName .. "Low"] then
		_G[sName .. "Low"]:SetText("0.2x")
	end
	if _G[sName .. "High"] then
		_G[sName .. "High"]:SetText("2.0x")
	end
	if _G[sName .. "Text"] then
		_G[sName .. "Text"]:SetText(string.format("%.2fx", curScale))
	end
	slider:SetScript("OnValueChanged", function(self, value)
		Bridge.db.globalScale = value
		if _G[self:GetName() .. "Text"] then
			_G[self:GetName() .. "Text"]:SetText(string.format("%.2fx", value))
		end
	end)

	-- Test Audition Buttons
	local testHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	testHeader:SetPoint("TOPLEFT", 20, -230)
	testHeader:SetText("Test Modes:")

	local testModes = { "BURST", "HEAVY", "DEFLECT", "KNOCK", "CLICK" }
	for idx, mName in ipairs(testModes) do
		local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		btn:SetSize(70, 22)
		btn:SetPoint("TOPLEFT", 20 + (idx - 1) * 75, -250)
		btn:SetText(mName)
		btn:SetScript("OnClick", function()
			Bridge:Play(mName, 1.0, "PB_Test")
		end)
	end

	-- WeakAuras Helper Copy Box
	local waLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	waLabel:SetPoint("TOPLEFT", 20, -285)
	waLabel:SetText("WeakAuras Custom Action Snippet (Copy & Paste):")

	local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	editBox:SetSize(370, 22)
	editBox:SetPoint("TOPLEFT", 25, -305)
	editBox:SetAutoFocus(false)
	editBox:SetText('WeakAurasPulse("BURST", 1.0)')
	editBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)

	f:SetScript("OnShow", function()
		refreshStatus()
		masterCheck:SetChecked(Bridge.db and Bridge.db.enabled)
		waCheck:SetChecked(Bridge.db and Bridge.db.weakaurasEnabled)
		bwCheck:SetChecked(Bridge.db and Bridge.db.bigwigsEnabled)
		dbmCheck:SetChecked(Bridge.db and Bridge.db.dbmEnabled)
	end)

	uiFrame = f
	return f
end

function Bridge:ToggleUI()
	local ui = createBridgeUI()
	if ui:IsShown() then
		ui:Hide()
	else
		ui:Show()
	end
end
