-- PulseCompass — UI.lua
--
-- Tactile navigation radar HUD and configuration interface.
-- Provides a visual bearing compass and motor power meters matching the Pulse design theme.

local _, Compass = ...

local compassUI = nil

local function createCompassUI()
	if compassUI then
		return compassUI
	end

	local f = CreateFrame("Frame", "PulseCompassFrame", UIParent, "BackdropTemplate")
	f:SetSize(420, 420)
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
	f:SetBackdropColor(0.08, 0.06, 0.05, 0.98)

	-- Header
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 22, -18)
	title:SetText("|cffff6600PulseCompass|r  |cffffffffTactile Radar HUD|r")

	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sub:SetPoint("TOPLEFT", 22, -40)
	sub:SetText("Spatial haptics guiding your heading via stereo gamepad motors.")

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -8, -8)

	-- Checkbox 1: Enable Compass
	local cbEnable = CreateFrame("CheckButton", "PulseCompassEnableCB", f, "UICheckButtonTemplate")
	cbEnable:SetPoint("TOPLEFT", 22, -70)
	local cbEnableText = cbEnable.text or _G[cbEnable:GetName() .. "Text"]
	if cbEnableText then
		cbEnableText:SetText("Enable Directional Haptics")
		cbEnableText:SetFontObject("GameFontHighlight")
	end
	cbEnable:SetChecked(Compass.db.enabled)
	cbEnable:SetScript("OnClick", function(self)
		Compass.db.enabled = self:GetChecked()
	end)

	-- Checkbox 2: Mute in Combat
	local cbCombat = CreateFrame("CheckButton", "PulseCompassCombatCB", f, "UICheckButtonTemplate")
	cbCombat:SetPoint("TOPLEFT", 22, -98)
	local cbCombatText = cbCombat.text or _G[cbCombat:GetName() .. "Text"]
	if cbCombatText then
		cbCombatText:SetText("Mute During Combat Lockdown")
		cbCombatText:SetFontObject("GameFontHighlight")
	end
	cbCombat:SetChecked(Compass.db.muteInCombat)
	cbCombat:SetScript("OnClick", function(self)
		Compass.db.muteInCombat = self:GetChecked()
	end)

	-- Tracking Mode Selector
	local modeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	modeLabel:SetPoint("TOPLEFT", 24, -135)
	modeLabel:SetText("|cffffff00Tracking Mode:|r")

	local modes = { "AUTO", "WAYPOINT", "CORPSE", "TARGET" }
	for i, m in ipairs(modes) do
		local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		btn:SetSize(82, 22)
		btn:SetPoint("TOPLEFT", 24 + (i - 1) * 90, -155)
		btn:SetText(m)
		btn:SetScript("OnClick", function()
			Compass.db.trackingMode = m
			print("PulseCompass: Tracking mode set to " .. m)
		end)
	end

	-- Radar Display Box
	local radarBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
	radarBox:SetSize(370, 160)
	radarBox:SetPoint("TOPLEFT", 24, -195)
	radarBox:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	radarBox:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
	radarBox:SetBackdropBorderColor(0.3, 0.25, 0.2, 0.8)

	local radarInfo = radarBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	radarInfo:SetPoint("TOPLEFT", 16, -14)
	radarInfo:SetText("Target: None detected")

	local bearingInfo = radarBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	bearingInfo:SetPoint("CENTER", radarBox, "CENTER", 0, 15)
	bearingInfo:SetText("---°")

	local motorInfo = radarBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	motorInfo:SetPoint("BOTTOM", radarBox, "BOTTOM", 0, 15)
	motorInfo:SetText("Left (Low Motor): 0%   |   Right (High Motor): 0%")

	-- Live telemetry refresh in UI
	f:SetScript("OnUpdate", function(_, elapsed)
		if not f:IsShown() then
			return
		end
		f.timer = (f.timer or 0) + elapsed
		if f.timer < 0.1 then
			return
		end
		f.timer = 0

		local state = Compass.Radar:UpdateState(Compass.db.trackingMode or "AUTO", Compass.db.intensity or 0.8)
		if state.hasTarget then
			local sign = state.relAngleDeg > 0 and "+" or ""
			local dir = state.isAhead and "|cff44ff44LOCKED ON|r" or (state.relAngleDeg < 0 and "LEFT" or "RIGHT")
			bearingInfo:SetText(string.format("%s%.0f° (%s)", sign, state.relAngleDeg, dir))
			radarInfo:SetText(
				string.format(
					"Target: |cffffaa00%s|r   Cadence: |cffffffff%.1fs|r",
					state.targetType,
					state.pingInterval
				)
			)
			motorInfo:SetText(
				string.format(
					"Left Motor: |cff00ffcc%.0f%%|r   |   Right Motor: |cffffaa00%.0f%%|r",
					state.leftMotor * 100,
					state.rightMotor * 100
				)
			)
		else
			bearingInfo:SetText("|cff666666---° (Searching)|r")
			radarInfo:SetText("Target: No waypoint, corpse, or unit target")
			motorInfo:SetText("Left Motor: 0%   |   Right Motor: 0%")
		end
	end)

	compassUI = f
	return f
end

function Compass:ToggleUI()
	local f = createCompassUI()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end
