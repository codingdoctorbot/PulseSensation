-- Pulse — UI/QuickSetup.lua
--
-- Standalone Quick Setup wizard for first-time onboarding and rapid configuration.
-- Completely isolated from Blizzard's protected Settings managers to prevent taint.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local QuickSetup = {}
Pulse.UI.QuickSetup = QuickSetup

local FRAME_NAME = "PulseQuickSetupFrame"
local frame
local currentStep = 1

local THEME = {
	bg = { r = 0.035, g = 0.040, b = 0.055, a = 0.96 },
	surface = { r = 0.060, g = 0.068, b = 0.085, a = 0.90 },
	border = { r = 0.18, g = 0.22, b = 0.28, a = 0.85 },
	accent = { r = 0.30, g = 0.72, b = 1.00, a = 1.0 },
	accentDim = { r = 0.15, g = 0.40, b = 0.60, a = 0.8 },
	textPrimary = { r = 0.90, g = 0.93, b = 0.96 },
	textMuted = { r = 0.53, g = 0.58, b = 0.68 },
}

-- ── Data Definitions ─────────────────────────────────────────────────────────

local CONTROLLER_OPTIONS = {
	{
		id = "dualsense",
		label = "DualSense (PS5)",
		desc = "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response",
	},
	{ id = "ds4", label = "DualShock 4 (PS4)", desc = "Dual asymmetrical ERM motors, balanced 75ms spin-up" },
	{
		id = "xbox",
		label = "Xbox One / Series",
		desc = "Heavy left counterweight (85ms), light right counterweight (45ms)",
	},
	{
		id = "xbox_elite",
		label = "Xbox Elite Series 2",
		desc = "Tuned for heavy chassis damping (+10% Low motor gain)",
	},
	{ id = "switchpro", label = "Nintendo Switch Pro", desc = "Tuned for HD Rumble voice-coil actuators" },
	{ id = "8bitdo", label = "8BitDo / Other XInput", desc = "Calibrated for standard third-party ERM rumble curves" },
	{ id = "steamdeck", label = "Steam Deck / Controller", desc = "Tuned for trackpad & chassis LRA haptics" },
	{ id = "default", label = "Generic / Unknown", desc = "Engine defaults without device-specific calibration" },
}

local CATEGORY_OPTIONS = {
	{
		id = "offensive",
		label = "Offensive Combat",
		desc = "Weapon swings, ability execution, crits, and cast finish.",
		cues = {
			"abilityPulse",
			"meleeAttackStart",
			"meleeAttackStop",
			"meleeRangeIn",
			"meleeRangeOut",
			"autoRepeatStart",
			"autoRepeatStop",
			"autoShotFired",
			"weaponSwingMain",
			"weaponSwingOff",
			"selfCastSucceeded",
			"selfCastInstant",
		},
		testMode = "HEAVY_STRIKE",
	},
	{
		id = "defensive",
		label = "Defensive Combat & Threat",
		desc = "Damage taken, crits received, dodges, CC, and threat lost.",
		cues = {
			"critLanded",
			"damageTaken",
			"deflect",
			"healCrit",
			"healReceived",
			"debuffReceived",
			"threatWarning",
			"threatLost",
			"ccMaster",
		},
		testMode = "DOUBLE_THUD",
	},
	{
		id = "world",
		label = "World & Discovery",
		desc = "Loot drops, rare alerts, quest turn-ins, and leveling up.",
		gate = "gateWorld",
		cues = {
			"lootReceived",
			"questComplete",
			"questAccepted",
			"levelUp",
			"achievement",
			"xpGained",
		},
		testMode = "CHIME",
	},
	{
		id = "target",
		label = "Target & Crosshair",
		desc = "Target lock, friendly/enemy target changes, and reticle interaction.",
		gate = "gateTarget",
		extraGates = { "gateInteract" },
		cues = {
			"targetChange",
			"focusChange",
			"softTargetInteraction",
		},
		testMode = "DEFLECT",
	},
	{
		id = "interface",
		label = "Controller UI & Windows",
		desc = "Menu navigation, bag open/close, vendor windows, and dialogs.",
		gate = "controllerUIMaster",
		extraGates = { "gateInterface" },
		cues = {
			"uiInfoMessage",
			"merchantShow",
			"bankOpened",
		},
		testMode = "TAP",
	},
	{
		id = "social",
		label = "Social & Group Readiness",
		desc = "Direct whispers, party invites, dungeon queue pops, and ready checks.",
		gate = "gateSocial",
		cues = {
			"whisper",
			"partyInvite",
			"readyCheck",
			"queuePop",
		},
		testMode = "PULSE_BURST",
	},
}

local CONTINUOUS_OPTIONS = {
	{
		id = "glideThrust",
		label = "Skyriding / Gliding Thrust",
		desc = "Wind resistance & thrust build-up while gliding.",
		default = true,
	},
	{
		id = "locomotion",
		label = "Footfalls & Mount Gait",
		desc = "Rhythmic footsteps on foot and hoofbeats mounted.",
		default = false,
	},
	{
		id = "waterTexture",
		label = "In Water (Buoyancy)",
		desc = "Subtle hydrostatic buoyancy while swimming or floating.",
		default = false,
	},
	{
		id = "swimTexture",
		label = "Swimming Resistance",
		desc = "Hydrodynamic stroke resistance that scales with speed.",
		default = false,
	},
	{
		id = "oceanTexture",
		label = "Ocean Waves & Swell",
		desc = "Harmonic oceanic gravity swells and coastal surges.",
		default = false,
	},
	{
		id = "castTexture",
		label = "Spellcasting Hum",
		desc = "Continuous hum and channel vibration while casting spells.",
		default = false,
	},
	{
		id = "craftTexture",
		label = "Crafting Rhythms",
		desc = "Hammer blows, mining picks, and tailoring stitches.",
		default = false,
	},
	{
		id = "weatherTexture",
		label = "Weather Atmosphere",
		desc = "Rain patter, crystalline snow, and sandstorm rumbles.",
		default = false,
	},
	{
		id = "breathTexture",
		label = "Breath Depletion",
		desc = "Rising heartbeat vibration as lungs empty underwater.",
		default = false,
	},
	{
		id = "lowHealthWarning",
		label = "Low Health Alert",
		desc = "Urgent repeating heartbeat lub-dub below 20% health.",
		default = false,
	},
	{
		id = "taxiRide",
		label = "Flight Path Cruise",
		desc = "Gentle steady texture while riding a taxi flight.",
		default = false,
	},
	{
		id = "stealthTexture",
		label = "Stealth Breathing",
		desc = "Slow breathing wave while stealthed or invisible.",
		default = false,
	},
}

-- ── UI Helper Builders ───────────────────────────────────────────────────────

local function createCard(parent, width, height)
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(width, height)

	local bg = card:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(card)
	bg:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, THEME.surface.a)
	card.bg = bg

	local border = card:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	border:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
	border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, THEME.border.a)
	card.border = border

	local inner = card:CreateTexture(nil, "ARTWORK")
	inner:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
	inner:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, THEME.surface.a)
	card.inner = inner

	return card
end

local function createButton(parent, text, width, height, isAccent)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 120, height or 26)
	btn:SetText(text)

	if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.StyleActionButton then
		Pulse.UI.Panel.Theme.StyleActionButton(btn, isAccent)
	end

	return btn
end

local function createCheckbox(parent, size)
	local cb = CreateFrame("CheckButton", nil, parent)
	cb:SetSize(size or 24, size or 24)
	cb:SetNormalAtlas("checkbox-minimal")
	cb:SetPushedAtlas("checkbox-minimal")
	cb:SetCheckedTexture("checkmark-minimal")
	cb:SetDisabledCheckedTexture("checkmark-minimal-disabled")
	return cb
end

-- ── Window Construction ───────────────────────────────────────────────────────

local stepFrames = {}
local stepIndicators = {}
local btnBack, btnNext, btnFinish

local function updateStepView()
	for i = 1, 4 do
		if stepFrames[i] then
			stepFrames[i]:SetShown(i == currentStep)
		end
		if stepIndicators[i] then
			if i == currentStep then
				stepIndicators[i]:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)
			elseif i < currentStep then
				stepIndicators[i]:SetTextColor(0.40, 0.85, 0.60)
			else
				stepIndicators[i]:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)
			end
		end
	end

	if btnBack then
		btnBack:SetShown(currentStep > 1)
	end
	if btnNext then
		btnNext:SetShown(currentStep < 4)
	end
	if btnFinish then
		btnFinish:SetShown(currentStep == 4)
	end
end

local function buildStep1(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText("Step 1: Choose Your Controller Hardware")
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(
		"Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators."
	)
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local selectedDevice = Pulse.Database:GetAppliedDevicePreset() or "default"
	local devCards = {}

	local startY = -68
	local cardW = 310
	local cardH = 62

	for idx, opt in ipairs(CONTROLLER_OPTIONS) do
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local x = col * (cardW + 14) + 6
		local y = startY - row * (cardH + 8)

		local card = CreateFrame("Button", nil, sf)
		card:SetSize(cardW, cardH)
		card:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

		local bg = card:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(card)
		bg:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.85)
		card.bg = bg

		local border = card:CreateTexture(nil, "BORDER")
		border:SetAllPoints(card)
		border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.8)
		card.border = border

		local inner = card:CreateTexture(nil, "ARTWORK")
		inner:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
		inner:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
		inner:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.95)
		card.inner = inner

		local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
		label:SetText(opt.label)

		local sub = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		sub:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
		sub:SetPoint("RIGHT", card, "RIGHT", -10, 0)
		sub:SetJustifyH("LEFT")
		sub:SetText(opt.desc)
		sub:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

		local pip = card:CreateTexture(nil, "OVERLAY")
		pip:SetSize(3, cardH - 2)
		pip:SetPoint("LEFT", card, "LEFT", 1, 0)
		pip:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1)
		pip:Hide()
		card.pip = pip

		local function refreshCard()
			if selectedDevice == opt.id then
				border:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 0.9)
				label:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)
				pip:Show()
			else
				border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.7)
				label:SetTextColor(THEME.textPrimary.r, THEME.textPrimary.g, THEME.textPrimary.b)
				pip:Hide()
			end
		end

		card:SetScript("OnClick", function()
			selectedDevice = opt.id
			Pulse.Database:ApplyDevicePreset(opt.id)
			for _, c in ipairs(devCards) do
				c.refresh()
			end
			-- Play subtle confirmation feedback
			if Pulse.TestMode then
				Pulse:TestMode("TAP", 0.6)
			end
		end)

		card.refresh = refreshCard
		devCards[#devCards + 1] = card
		refreshCard()
	end

	-- Test button for Step 1
	local testCard = createCard(sf, 634, 46)
	testCard:SetPoint("BOTTOMLEFT", sf, "BOTTOMLEFT", 6, 6)

	local testLabel = testCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	testLabel:SetPoint("LEFT", testCard, "LEFT", 16, 0)
	testLabel:SetText("Verify controller connection and motor calibration:")
	testLabel:SetTextColor(THEME.textPrimary.r, THEME.textPrimary.g, THEME.textPrimary.b)

	local btnTest = createButton(testCard, "Test Rumble", 140, 26, true)
	btnTest:SetPoint("RIGHT", testCard, "RIGHT", -12, 0)
	btnTest:SetScript("OnClick", function()
		if Pulse.TestMode then
			local ok, err = Pulse:TestMode("HEAVY_STRIKE", 0.85)
			if not ok and err then
				print("|cffff5555Pulse:|r " .. tostring(err))
			end
		end
	end)

	sf.OnShowStep = function()
		selectedDevice = Pulse.Database:GetAppliedDevicePreset() or "default"
		for _, c in ipairs(devCards) do
			c.refresh()
		end
	end

	return sf
end

local function buildStep2(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText("Step 2: Choose Your Haptic Categories")
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText("Select which areas of gameplay produce tactile feedback through your controller.")
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local startY = -56
	local rowH = 46
	local catRows = {}

	for idx, opt in ipairs(CATEGORY_OPTIONS) do
		local y = startY - (idx - 1) * (rowH + 6)
		local card = createCard(sf, 634, rowH)
		card:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, y)

		local cb = createCheckbox(card, 22)
		cb:SetPoint("LEFT", card, "LEFT", 12, 0)

		local lbl = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		lbl:SetPoint("TOPLEFT", cb, "TOPRIGHT", 10, -2)
		lbl:SetText(opt.label)

		local sub = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		sub:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
		sub:SetPoint("RIGHT", card, "RIGHT", -100, 0)
		sub:SetJustifyH("LEFT")
		sub:SetText(opt.desc)
		sub:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

		local btnTest = createButton(card, "Test", 72, 22, false)
		btnTest:SetPoint("RIGHT", card, "RIGHT", -12, 0)
		btnTest:SetScript("OnClick", function()
			if Pulse.TestMode and opt.testMode then
				Pulse:TestMode(opt.testMode, 0.75)
			end
		end)

		local function isOptActive()
			if opt.gate then
				if not Pulse.Database:GetCue(opt.gate) then
					return false
				end
			end
			-- Check if at least half of the cues are active
			local activeCount = 0
			for _, cueID in ipairs(opt.cues) do
				if Pulse.Database:GetCue(cueID) then
					activeCount = activeCount + 1
				end
			end
			return activeCount > 0
		end

		local function setOptActive(enabled)
			if opt.gate then
				Pulse.Database:SetCue(opt.gate, enabled)
			end
			if opt.extraGates then
				for _, eg in ipairs(opt.extraGates) do
					Pulse.Database:SetCue(eg, enabled)
				end
			end
			for _, cueID in ipairs(opt.cues) do
				Pulse.Database:SetCue(cueID, enabled)
			end
			cb:SetChecked(enabled)
		end

		cb:SetScript("OnClick", function(self)
			local val = self:GetChecked() and true or false
			if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
				Pulse.UI.Panel.Theme.PlayCheckSound(val)
			end
			setOptActive(val)
		end)

		card.refresh = function()
			cb:SetChecked(isOptActive())
		end

		catRows[#catRows + 1] = card
		card.refresh()
	end

	-- Bulk enable / disable controls
	local bottomCard = CreateFrame("Frame", nil, sf)
	bottomCard:SetSize(634, 28)
	bottomCard:SetPoint("BOTTOMLEFT", sf, "BOTTOMLEFT", 6, 8)

	local btnEnableAll = createButton(bottomCard, "Enable All", 100, 24, false)
	btnEnableAll:SetPoint("LEFT", bottomCard, "LEFT", 0, 0)
	btnEnableAll:SetScript("OnClick", function()
		for _, card in ipairs(catRows) do
			card.setOptActive(true)
		end
	end)

	local btnDisableAll = createButton(bottomCard, "Disable All", 100, 24, false)
	btnDisableAll:SetPoint("LEFT", btnEnableAll, "RIGHT", 10, 0)
	btnDisableAll:SetScript("OnClick", function()
		for _, card in ipairs(catRows) do
			card.setOptActive(false)
		end
	end)

	sf.OnShowStep = function()
		for _, card in ipairs(catRows) do
			card.refresh()
		end
	end

	return sf
end

local function buildStep3(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText("Step 3: Immersion & Continuous Textures")
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(
		"Continuous textures provide constant atmospheric vibration (footfalls, water, glide speed, weather). Choose which you want active."
	)
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	-- Master continuous banner
	local masterCard = createCard(sf, 634, 38)
	masterCard:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -56)

	local cbMaster = createCheckbox(masterCard, 22)
	cbMaster:SetPoint("LEFT", masterCard, "LEFT", 12, 0)

	local lblMaster = masterCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblMaster:SetPoint("LEFT", cbMaster, "RIGHT", 10, 0)
	lblMaster:SetText("Enable Continuous Immersion Haptics (Master)")

	local itemCards = {}

	local startY = -102
	local cardW = 310
	local cardH = 46

	for idx, opt in ipairs(CONTINUOUS_OPTIONS) do
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local x = col * (cardW + 14) + 6
		local y = startY - row * (cardH + 6)

		local card = createCard(sf, cardW, cardH)
		card:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

		local cb = createCheckbox(card, 20)
		cb:SetPoint("LEFT", card, "LEFT", 8, 0)

		local lbl = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		lbl:SetPoint("TOPLEFT", cb, "TOPRIGHT", 8, -2)
		lbl:SetPoint("RIGHT", card, "RIGHT", -60, 0)
		lbl:SetJustifyH("LEFT")
		lbl:SetText(opt.label)

		local sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		sub:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
		sub:SetPoint("RIGHT", card, "RIGHT", -60, 0)
		sub:SetJustifyH("LEFT")
		sub:SetText(opt.desc)
		sub:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

		local btnPreview = createButton(card, "Feel", 48, 20, false)
		btnPreview:SetPoint("RIGHT", card, "RIGHT", -6, 0)
		btnPreview:SetScript("OnClick", function()
			if Pulse.TestCue then
				Pulse:TestCue(opt.id)
			end
		end)

		cb:SetScript("OnClick", function(self)
			local val = self:GetChecked() and true or false
			if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
				Pulse.UI.Panel.Theme.PlayCheckSound(val)
			end
			Pulse.Database:SetCue(opt.id, val)
		end)

		card.refresh = function()
			cb:SetChecked(Pulse.Database:GetCue(opt.id))
		end

		itemCards[#itemCards + 1] = card
		card.refresh()
	end

	cbMaster:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
		for _, opt in ipairs(CONTINUOUS_OPTIONS) do
			if val then
				Pulse.Database:SetCue(opt.id, opt.default)
			else
				Pulse.Database:SetCue(opt.id, false)
			end
		end
		for _, card in ipairs(itemCards) do
			card.refresh()
		end
	end)

	sf.OnShowStep = function()
		local anyOn = false
		for _, opt in ipairs(CONTINUOUS_OPTIONS) do
			if Pulse.Database:GetCue(opt.id) then
				anyOn = true
				break
			end
		end
		cbMaster:SetChecked(anyOn)
		for _, card in ipairs(itemCards) do
			card.refresh()
		end
	end

	return sf
end

local function buildStep4(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText("Step 4: Overall Strength & Completion")
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText("Set your global master intensity. You can fine-tune individual cues anytime in settings.")
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	-- Master Intensity Slider Card
	local sliderCard = createCard(sf, 634, 90)
	sliderCard:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -60)

	local sliderLabel = sliderCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	sliderLabel:SetPoint("TOPLEFT", sliderCard, "TOPLEFT", 16, -14)
	sliderLabel:SetText("Master Vibration Strength")

	local valLabel = sliderCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	valLabel:SetPoint("TOPRIGHT", sliderCard, "TOPRIGHT", -16, -14)
	valLabel:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local slider = CreateFrame("Slider", nil, sliderCard, "OptionsSliderTemplate")
	slider:SetWidth(460)
	slider:SetHeight(18)
	slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -18)
	slider:SetMinMaxValues(10, 100)
	slider:SetValueStep(5)
	slider:SetObeyStepOnDrag(true)

	if slider.Low then
		slider.Low:SetText("10%")
	end
	if slider.High then
		slider.High:SetText("100%")
	end
	if slider.Text then
		slider.Text:SetText("")
	end

	local btnFeel = createButton(sliderCard, "Feel Strength", 120, 26, false)
	btnFeel:SetPoint("LEFT", slider, "RIGHT", 20, 0)
	btnFeel:SetScript("OnClick", function()
		if Pulse.TestMode then
			Pulse:TestMode("HEAVY_STRIKE", slider:GetValue() / 100)
		end
	end)

	local function updateSliderVal(val)
		valLabel:SetText(("%d%%"):format(math.floor(val + 0.5)))
		Pulse.Database:Set("masterIntensity", val / 100)
	end

	slider:SetScript("OnValueChanged", function(self, value)
		updateSliderVal(value)
	end)

	-- Info Summary Card
	local summaryCard = createCard(sf, 634, 180)
	summaryCard:SetPoint("TOPLEFT", sliderCard, "BOTTOMLEFT", 0, -14)

	local summaryTitle = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	summaryTitle:SetPoint("TOPLEFT", summaryCard, "TOPLEFT", 16, -16)
	summaryTitle:SetText("Setup Summary")
	summaryTitle:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local summaryText = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	summaryText:SetPoint("TOPLEFT", summaryTitle, "BOTTOMLEFT", 0, -10)
	summaryText:SetPoint("RIGHT", summaryCard, "RIGHT", -16, 0)
	summaryText:SetJustifyH("LEFT")
	summaryText:SetSpacing(4)
	summaryCard.summaryText = summaryText

	local function refreshSummary()
		local presetID = Pulse.Database:GetAppliedDevicePreset() or "default"
		local devName = "Generic / Unknown"
		for _, opt in ipairs(CONTROLLER_OPTIONS) do
			if opt.id == presetID then
				devName = opt.label
				break
			end
		end
		local activeProf = Pulse.Database:GetActiveProfileName() or "Default"
		local curInt = math.floor((Pulse.Database:Get("masterIntensity") or 0.70) * 100 + 0.5)

		summaryText:SetText(
			(
				"- Selected Controller: |cffffffff%s|r\n"
				.. "- Active Profile: |cffffffff%s|r\n"
				.. "- Master Intensity: |cffffffff%d%%|r\n\n"
				.. "All preferences have been written directly to your active profile.\nYou can re-run this setup at any time by typing |cff4cb8ff/pulse setup|r."
			):format(devName, activeProf, curInt)
		)
	end

	sf.OnShowStep = function()
		local curInt = math.floor((Pulse.Database:Get("masterIntensity") or 0.70) * 100 + 0.5)
		slider:SetValue(curInt)
		updateSliderVal(curInt)
		refreshSummary()
	end

	return sf
end

local function buildWindow()
	if frame then
		return frame
	end

	local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
	f:SetSize(660, 520)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)

	-- Register Escape to close
	tinsert(UISpecialFrames, FRAME_NAME)

	-- Window background & borders
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetColorTexture(THEME.bg.r, THEME.bg.g, THEME.bg.b, THEME.bg.a)
	f.bg = bg

	local border = f:CreateTexture(nil, "BORDER")
	border:SetAllPoints(f)
	border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, THEME.border.a)
	f.border = border

	local inner = f:CreateTexture(nil, "ARTWORK")
	inner:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	inner:SetColorTexture(THEME.bg.r, THEME.bg.g, THEME.bg.b, THEME.bg.a)
	f.inner = inner

	-- Header Bar
	local headerBar = CreateFrame("Frame", nil, f)
	headerBar:SetHeight(48)
	headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	headerBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

	local title = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	title:SetPoint("LEFT", headerBar, "LEFT", 18, 2)
	title:SetText("PULSE |cff4cb8ffQUICK SETUP|r")

	local accentLine = headerBar:CreateTexture(nil, "OVERLAY")
	accentLine:SetHeight(2)
	accentLine:SetPoint("BOTTOMLEFT", headerBar, "BOTTOMLEFT", 16, 0)
	accentLine:SetPoint("BOTTOMRIGHT", headerBar, "BOTTOMRIGHT", -16, 0)
	accentLine:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 0.8)

	-- Close Button (X)
	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function()
		QuickSetup.Close()
	end)

	-- Step breadcrumb tabs
	local stepBar = CreateFrame("Frame", nil, f)
	stepBar:SetHeight(26)
	stepBar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 16, -6)
	stepBar:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", -16, -6)

	local stepLabels = { "1. Controller", "2. Categories", "3. Immersion", "4. Finish" }
	local tabW = 150
	for i = 1, 4 do
		local tab = stepBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		tab:SetPoint("LEFT", stepBar, "LEFT", (i - 1) * (tabW + 8), 0)
		tab:SetText(stepLabels[i])
		stepIndicators[i] = tab
	end

	-- Content Container
	local container = CreateFrame("Frame", nil, f)
	container:SetPoint("TOPLEFT", stepBar, "BOTTOMLEFT", 0, -8)
	container:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 56)

	stepFrames[1] = buildStep1(container)
	stepFrames[2] = buildStep2(container)
	stepFrames[3] = buildStep3(container)
	stepFrames[4] = buildStep4(container)

	-- Bottom Action Bar
	local bottomBar = CreateFrame("Frame", nil, f)
	bottomBar:SetHeight(50)
	bottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 0)
	bottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 0)

	local bottomRule = bottomBar:CreateTexture(nil, "ARTWORK")
	bottomRule:SetHeight(1)
	bottomRule:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 0, 0)
	bottomRule:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", 0, 0)
	bottomRule:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.6)

	btnBack = createButton(bottomBar, "< Back", 100, 28, false)
	btnBack:SetPoint("LEFT", bottomBar, "LEFT", 0, 0)
	btnBack:SetScript("OnClick", function()
		if currentStep > 1 then
			currentStep = currentStep - 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end
	end)

	btnNext = createButton(bottomBar, "Next >", 110, 28, true)
	btnNext:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
	btnNext:SetScript("OnClick", function()
		if currentStep < 4 then
			currentStep = currentStep + 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end
	end)

	btnFinish = createButton(bottomBar, "Save & Start Playing", 160, 28, true)
	btnFinish:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
	btnFinish:SetScript("OnClick", function()
		Pulse.Database:SetQuickSetupCompleted(true)
		if Pulse.TestMode then
			Pulse:TestMode("LEVEL_UP", 0.75)
		end
		QuickSetup.Close()
		print("|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.")
	end)

	local btnAdvanced = createButton(bottomBar, "Advanced Settings", 140, 28, false)
	btnAdvanced:SetPoint("RIGHT", btnFinish, "LEFT", -10, 0)
	btnAdvanced:SetScript("OnClick", function()
		Pulse.Database:SetQuickSetupCompleted(true)
		QuickSetup.Close()
		if Pulse.UI.Panel and Pulse.UI.Panel.Open then
			Pulse.UI.Panel.Open()
		end
	end)

	-- Close on combat start to avoid taint
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_REGEN_DISABLED" then
			QuickSetup.Close()
		end
	end)

	frame = f
	return f
end

-- ── Public API ────────────────────────────────────────────────────────────────

function QuickSetup.Open(initialStep)
	if InCombatLockdown and InCombatLockdown() then
		print("|cffff5555Pulse:|r Cannot open Quick Setup during combat.")
		return
	end

	buildWindow()
	currentStep = initialStep or 1
	if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
		stepFrames[currentStep].OnShowStep()
	end
	updateStepView()
	frame:Show()
end

function QuickSetup.Close()
	if Pulse.CancelContinuousPreview then
		Pulse:CancelContinuousPreview()
	end
	if frame then
		frame:Hide()
	end
end

function QuickSetup.Toggle()
	if frame and frame:IsShown() then
		QuickSetup.Close()
	else
		QuickSetup.Open()
	end
end
