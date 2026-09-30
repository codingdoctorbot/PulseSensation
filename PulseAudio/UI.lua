-- PulseAudio — UI.lua
--
-- Configuration and acoustic audition frame for PulseAudio.
-- Clean, modern dark styling matching the PulseHaptics design language.

local _, Audio = ...

local uiFrame = nil

local function createAudioUI()
	if uiFrame then
		return uiFrame
	end

	local f = CreateFrame("Frame", "PulseAudioFrame", UIParent, "BackdropTemplate")
	f:SetSize(440, 360)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
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
	f:SetBackdropColor(0.06, 0.08, 0.10, 0.96)

	-- Header
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 22, -18)
	title:SetText("|cff33ccffPulseAudio|r  |cffffffffEarcon Synthesizer|r")

	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sub:SetPoint("TOPLEFT", 22, -40)
	sub:SetText("Generates mechanical earcons and audible feedback from haptic cues.")

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -8, -8)

	-- Checkbox 1: Enable Synthesizer
	local cbEnable = CreateFrame("CheckButton", "PulseAudioEnableCB", f, "UICheckButtonTemplate")
	cbEnable:SetPoint("TOPLEFT", 22, -70)
	local cbEnableText = cbEnable.text or _G[cbEnable:GetName() .. "Text"]
	if cbEnableText then
		cbEnableText:SetText("Enable Earcon Synthesizer")
		cbEnableText:SetFontObject("GameFontHighlight")
	end
	cbEnable:SetChecked(Audio.db.enabled)
	cbEnable:SetScript("OnClick", function(self)
		Audio.db.enabled = self:GetChecked()
	end)

	-- Checkbox 2: Mute in Combat
	local cbCombat = CreateFrame("CheckButton", "PulseAudioCombatCB", f, "UICheckButtonTemplate")
	cbCombat:SetPoint("TOPLEFT", 22, -100)
	local cbCombatText = cbCombat.text or _G[cbCombat:GetName() .. "Text"]
	if cbCombatText then
		cbCombatText:SetText("Mute Earcons During Combat Lockdown")
		cbCombatText:SetFontObject("GameFontHighlight")
	end
	cbCombat:SetChecked(Audio.db.muteInCombat)
	cbCombat:SetScript("OnClick", function(self)
		Audio.db.muteInCombat = self:GetChecked()
	end)

	-- Theme Selection Group
	local themeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	themeLabel:SetPoint("TOPLEFT", 24, -145)
	themeLabel:SetText("|cff00ccffAcoustic Theme:|r")

	local themeDesc = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	themeDesc:SetPoint("TOPLEFT", 24, -165)
	themeDesc:SetText(Audio.SoundBank.THEME_PROFILES[Audio.db.theme or "mechanical"].desc)

	local function updateThemeDesc()
		local prof = Audio.SoundBank.THEME_PROFILES[Audio.db.theme or "mechanical"]
		themeDesc:SetText(prof and prof.desc or "")
	end

	local themes = {
		{ id = "mechanical", label = "Mechanical" },
		{ id = "subtle", label = "Subtle" },
		{ id = "tactical", label = "Tactical" },
	}

	for i, t in ipairs(themes) do
		local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		btn:SetSize(110, 24)
		btn:SetPoint("TOPLEFT", 24 + (i - 1) * 125, -190)
		btn:SetText(t.label)
		btn:SetScript("OnClick", function()
			Audio.db.theme = t.id
			updateThemeDesc()
			Audio:PlayTest("CLICK")
		end)
	end

	-- Audition Section
	local testLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	testLabel:SetPoint("TOPLEFT", 24, -235)
	testLabel:SetText("|cffffff00Audition Earcon Presets:|r")

	local testModes = {
		{ mode = "CLICK", label = "Click" },
		{ mode = "THUD", label = "Thud" },
		{ mode = "BURST", label = "Burst" },
		{ mode = "SURGE", label = "Alert" },
	}

	for i, m in ipairs(testModes) do
		local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		btn:SetSize(85, 24)
		btn:SetPoint("TOPLEFT", 24 + (i - 1) * 95, -260)
		btn:SetText(m.label)
		btn:SetScript("OnClick", function()
			Audio:PlayTest(m.mode)
		end)
	end

	-- Status line
	local status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	status:SetPoint("BOTTOMLEFT", 24, 20)
	status:SetText("Plays via Blizzard Master Audio channel. Fully compatible with DualSense speaker.")

	uiFrame = f
	return f
end

function Audio:ToggleUI()
	local f = createAudioUI()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end
