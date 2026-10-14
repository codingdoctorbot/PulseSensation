-- Pulse — UI/QuickSetup.lua
--
-- Quick Setup: a short route into the same settings the full panel edits, running in
-- parallel with it. Nothing here has storage of its own — every control reads and writes the
-- live values through Pulse.Database, so the wizard and the panel can be used in either
-- order, any number of times, and always agree.
--
-- Tuning is reduced to a handful of knobs, each mapped onto the real settings underneath:
--
--   Strength       masterIntensity                                    (per profile)
--   Motor balance  Low/High channel gain, measured from the applied   (global calibration)
--                  controller preset's own values
--   Subtle cues    Low/High channel gamma, measured the same way      (global calibration)
--   Category       a settings page's switch (its page gate), plus      (per profile)
--                  every discrete cue on that page as a multiple of
--                  its authored defaultIntensity
--   Texture        a continuous cue's own switch and intensity        (per profile)
--
-- Categories and textures are read from Registry:GetPages() rather than listed here, so the
-- wizard can never name a cue the registry does not have. Every knob sits next to a Feel
-- button: tuning is move-then-feel, not guess-then-play.
--
-- Completely isolated from Blizzard's protected Settings managers to prevent taint.

local ADDON_NAME, Pulse = ...
local issecretvalue = Pulse.issecret

Pulse.UI = Pulse.UI or {}
local QuickSetup = {}
Pulse.UI.QuickSetup = QuickSetup

local FRAME_NAME = "PulseQuickSetupFrame"
local frame
local currentStep = 1

local WINDOW_W, WINDOW_H = 680, 580
local CONTENT_W = WINDOW_W - 32
local STEP_LABELS = { "Controller", "Feel", "Categories", "Immersion", "Finish" }
local STEP_COUNT = #STEP_LABELS

local THEME = {
	bg = { r = 0.035, g = 0.040, b = 0.055, a = 0.96 },
	surface = { r = 0.060, g = 0.068, b = 0.085, a = 0.90 },
	border = { r = 0.18, g = 0.22, b = 0.28, a = 0.85 },
	accent = { r = 0.30, g = 0.72, b = 1.00, a = 1.0 },
	textPrimary = { r = 0.90, g = 0.93, b = 0.96 },
	textMuted = { r = 0.53, g = 0.58, b = 0.68 },
	good = { r = 0.40, g = 0.85, b = 0.60 },
	bad = { r = 1.00, g = 0.40, b = 0.40 },
}

-- Modes the Feel buttons play. Each must exist in Pulse.Modes (quicksetup-test checks).
local FEEL = {
	select = { mode = "TAP", scale = 0.6 }, -- picking a controller card
	test = { mode = "HEAVY", scale = 1.0 }, -- Step 1's Test rumble
	strength = { mode = "THUD", scale = 1.0 }, -- full-scale hit, so only master strength shapes it
	balance = { mode = "IMPACT", scale = 1.0 }, -- drives both motors, so balance is audible
	subtle = { mode = "KNOCK", scale = 0.3 }, -- a deliberately quiet cue
	finish = { mode = "CHIME", scale = 0.75 },
}

-- ── Tuning: the knobs, mapped onto the real settings ─────────────────────────
--
-- Pure data-in, data-out over Pulse.Database; no frames. Exposed as QuickSetup.Tuning so the
-- offline tests can check the arithmetic without a client.

local Tuning = {}
QuickSetup.Tuning = Tuning

-- Balance ±1 moves each motor's gain by up to ±50% of the preset's; subtle ±1 bends each
-- motor's response curve (gamma) by up to ±35% of the preset's.
local BALANCE_SPAN = 0.5
local SUBTLE_SPAN = 0.35
-- Same ceiling as the per-cue intensity slider in UI/Panel/Spec.lua.
local CUE_INTENSITY_MAX = 1.5

local function db()
	return Pulse.Database
end

local function clamp(value, low, high)
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

-- A calibration knob's allowed range, read from the table that drives the calibration page
-- so the two can never disagree.
local function tunableRange(key, fallbackMin, fallbackMax)
	for _, tunable in ipairs(Pulse.CHANNEL_TUNABLES or {}) do
		if tunable.key == key then
			return tunable.min, tunable.max
		end
	end
	return fallbackMin, fallbackMax
end

-- The value the applied controller preset gives one channel's key: the zero point balance and
-- subtle are measured from, so "Even" and "Preset" always mean "as the preset ships".
local function presetValue(channel, key)
	local device = Pulse.Devices[db():GetAppliedDevicePreset()]
	local overrides = device and device.channels and device.channels[channel]
	local value = overrides and overrides[key]
	if type(value) ~= "number" then
		value = Pulse.CHANNEL_DEFAULTS[key]
	end
	return value
end

-- Live value as a multiple of the preset's (1.0 = untouched).
local function channelRatio(channel, key)
	local base = presetValue(channel, key)
	if type(base) ~= "number" or base <= 0 then
		return 1.0
	end
	local value = db():GetChannelTuning(channel, key, base)
	if type(value) ~= "number" then
		return 1.0
	end
	return value / base
end

local function setChannelRatio(channel, key, ratio)
	local low, high = tunableRange(key, 0, 2)
	local value = clamp(presetValue(channel, key) * ratio, low, high)
	db():SetChannelTuning(channel, key, value, low, high)
end

function Tuning.GetStrength()
	local value = db():Get("masterIntensity")
	return type(value) == "number" and value or 1.0
end

function Tuning.SetStrength(value)
	db():Set("masterIntensity", value)
end

-- -1 = heavier rumble (Low motor up, High down), 0 = the preset's balance, +1 = sharper buzz.
function Tuning.GetBalance()
	local lowRatio, highRatio = channelRatio("Low", "gain"), channelRatio("High", "gain")
	return clamp((highRatio - lowRatio) / (2 * BALANCE_SPAN), -1, 1)
end

function Tuning.SetBalance(value)
	value = clamp(value, -1, 1)
	setChannelRatio("Low", "gain", 1 - BALANCE_SPAN * value)
	setChannelRatio("High", "gain", 1 + BALANCE_SPAN * value)
end

-- -1 = quiet cues fainter, 0 = the preset's curve, +1 = quiet cues stronger. A gamma below
-- the preset's lifts small values (Core/Devices.lua, "Response curve").
function Tuning.GetSubtle()
	local sum = 0
	for _, channel in ipairs(Pulse.CHANNELS) do
		sum = sum + (1 - channelRatio(channel, "gamma")) / SUBTLE_SPAN
	end
	return clamp(sum / #Pulse.CHANNELS, -1, 1)
end

function Tuning.SetSubtle(value)
	value = clamp(value, -1, 1)
	for _, channel in ipairs(Pulse.CHANNELS) do
		setChannelRatio(channel, "gamma", 1 - SUBTLE_SPAN * value)
	end
end

-- Back to the applied preset's calibration: balance and subtle return to their zero points.
function Tuning.ResetCalibration()
	db():ApplyDevicePreset(db():GetAppliedDevicePreset())
end

local function pageByID(pageID)
	for _, page in ipairs(Pulse.Registry:GetPages()) do
		if page.id == pageID then
			return page
		end
	end
	return nil
end

-- A page's playable cues, either its discrete ones or its continuous textures. Gates play
-- nothing and are handled separately.
local function cuesOf(page, continuous)
	local list = {}
	if not page then
		return list
	end
	for _, section in ipairs(page.sections or {}) do
		for _, trigger in ipairs(section.triggers or {}) do
			local isTexture = trigger.continuous and true or false
			if not trigger.gate and (trigger.mode or isTexture) and isTexture == continuous then
				list[#list + 1] = trigger
			end
		end
	end
	return list
end

local function baseIntensity(trigger)
	local base = trigger.defaultIntensity
	if type(base) ~= "number" or base <= 0 then
		return 1.0
	end
	return base
end

local function cueRatio(trigger)
	local base = baseIntensity(trigger)
	local value = db():GetTriggerSetting(trigger.id, "intensity", base)
	if type(value) ~= "number" then
		return 1.0
	end
	return value / base
end

local function setCueRatio(trigger, ratio)
	local value = clamp(baseIntensity(trigger) * ratio, 0, CUE_INTENSITY_MAX)
	db():SetTriggerSetting(trigger.id, "intensity", value, 0, CUE_INTENSITY_MAX)
end

-- Every settings page that has a switch, in sidebar order: the wizard's categories.
function Tuning.Categories()
	local list = {}
	for _, page in ipairs(Pulse.Registry:GetPages()) do
		if Pulse.Registry:GetPageGate(page.id) and #cuesOf(page, false) > 0 then
			list[#list + 1] = page
		end
	end
	return list
end

function Tuning.IsCategoryOn(pageID)
	local gate = Pulse.Registry:GetPageGate(pageID)
	return gate and db():GetCue(gate) or false
end

function Tuning.SetCategoryOn(pageID, enabled)
	local gate = Pulse.Registry:GetPageGate(pageID)
	if gate then
		db():SetCue(gate, enabled and true or false)
	end
end

-- Mean of the page's discrete cues, each as a multiple of its designed level (1.0 = as
-- designed). Continuous textures are tuned in their own step and left out of this.
function Tuning.GetCategoryStrength(pageID)
	local sum, count = 0, 0
	for _, trigger in ipairs(cuesOf(pageByID(pageID), false)) do
		sum = sum + cueRatio(trigger)
		count = count + 1
	end
	return count > 0 and (sum / count) or 1.0
end

function Tuning.SetCategoryStrength(pageID, ratio)
	for _, trigger in ipairs(cuesOf(pageByID(pageID), false)) do
		setCueRatio(trigger, ratio)
	end
end

-- The cue a category's Feel button plays: the first one switched on, else the first at all.
function Tuning.SampleCue(pageID)
	local cues = cuesOf(pageByID(pageID), false)
	for _, trigger in ipairs(cues) do
		if db():GetCue(trigger.id) then
			return trigger.id
		end
	end
	return cues[1] and cues[1].id or nil
end

-- Every continuous texture, in sidebar order, with the page it lives on.
function Tuning.Textures()
	local list = {}
	for _, page in ipairs(Pulse.Registry:GetPages()) do
		for _, trigger in ipairs(cuesOf(page, true)) do
			list[#list + 1] = { trigger = trigger, page = page }
		end
	end
	return list
end

function Tuning.GetCueStrength(triggerID)
	local trigger = Pulse.Registry:GetTrigger(triggerID)
	return trigger and cueRatio(trigger) or 1.0
end

function Tuning.SetCueStrength(triggerID, ratio)
	local trigger = Pulse.Registry:GetTrigger(triggerID)
	if trigger then
		setCueRatio(trigger, ratio)
	end
end

-- ── Status reads ─────────────────────────────────────────────────────────────

-- true / false, or nil when the client cannot say.
local function controllerSupportOn()
	if C_GamePad and type(C_GamePad.IsEnabled) == "function" then
		local ok, enabled = pcall(C_GamePad.IsEnabled)
		if ok and not (issecretvalue and issecretvalue(enabled)) then
			return enabled and true or false
		end
	end
	return nil
end

-- deviceID, presetID, display name — any may be nil. Never applies anything.
local function detectController()
	if type(Pulse.DetectDevice) ~= "function" then
		return nil
	end
	local ok, deviceID, presetID, name = pcall(Pulse.DetectDevice)
	if not ok or not deviceID then
		return nil
	end
	local device = presetID and Pulse.Devices[presetID]
	return deviceID, device and presetID or nil, (device and device.label) or name or "a controller"
end

local function deviceLabel(id)
	local device = Pulse.Devices[id]
	return device and device.label or "Generic / unknown"
end

-- ── Small UI helpers ─────────────────────────────────────────────────────────

local function panelTheme()
	return Pulse.UI.Panel and Pulse.UI.Panel.Theme
end

local function setColor(fontString, color)
	fontString:SetTextColor(color.r, color.g, color.b)
end

local function showTip(owner, title, body)
	local theme = panelTheme()
	if theme and theme.ShowTooltip then
		theme.ShowTooltip(owner, title, body)
	end
end

local function hideTip()
	local theme = panelTheme()
	if theme and theme.HideTooltip then
		theme.HideTooltip()
	end
end

local function attachTip(region, title, bodyFn)
	region:SetScript("OnEnter", function(self)
		showTip(self, title, type(bodyFn) == "function" and bodyFn() or bodyFn)
	end)
	region:SetScript("OnLeave", hideTip)
end

local function playCheckSound(on)
	local theme = panelTheme()
	if theme and theme.PlayCheckSound then
		theme.PlayCheckSound(on)
	end
end

local function percent(value)
	return ("%d%%"):format(math.floor(value + 0.5))
end

local function balanceText(value)
	value = math.floor(value + 0.5)
	if value == 0 then
		return "Even"
	end
	return value < 0 and ("Heavy %d"):format(-value) or ("Sharp %d"):format(value)
end

local function subtleText(value)
	value = math.floor(value + 0.5)
	if value == 0 then
		return "Preset"
	end
	return value > 0 and ("+%d"):format(value) or ("-%d"):format(-value)
end

local function createCard(parent, width, height)
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(width, height)

	local border = card:CreateTexture(nil, "BORDER")
	border:SetAllPoints(card)
	border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, THEME.border.a)
	card.border = border

	local inner = card:CreateTexture(nil, "ARTWORK")
	inner:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
	inner:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.95)
	card.inner = inner

	return card
end

local function createButton(parent, text, width, height, isAccent)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 120, height or 26)
	btn:SetText(text)
	local theme = panelTheme()
	if theme and theme.StyleActionButton then
		theme.StyleActionButton(btn, isAccent)
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

-- The panel's own slider widget (MinimalSliderWithSteppersTemplate, as in UI/Panel/Rows.lua):
-- its stepper arrows step it from a controller too. `spec` = { min, max, step, get, set,
-- format }, all in the slider's own units. Refresh() pulls the live value without writing it
-- back — the same `applying` feedback-loop guard Rows.lua uses.
local function createSlider(parent, width, spec)
	local slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
	slider:SetWidth(width)

	local function current()
		local value = spec.get()
		if type(value) ~= "number" then
			return spec.min
		end
		return clamp(value, spec.min, spec.max)
	end

	local formatters = {}
	if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
		formatters[MinimalSliderWithSteppersMixin.Label.Right] = spec.format
	end
	local steps = math.max(1, math.floor((spec.max - spec.min) / spec.step + 0.5))
	slider:Init(current(), spec.min, spec.max, steps, formatters)

	local applying = false
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if applying then
			return
		end
		applying = true
		spec.set(value)
		applying = false
	end, slider)

	slider.Refresh = function()
		applying = true
		slider:SetValue(current())
		applying = false
	end
	return slider
end

-- Title plus one line of explanation at the top of a step. Content starts at -HEADER_H.
local HEADER_H = 50

local function addStepHeader(sf, titleText, descText)
	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 4, -4)
	title:SetText(titleText)
	setColor(title, THEME.accent)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
	desc:SetPoint("RIGHT", sf, "RIGHT", -4, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(descText)
	setColor(desc, THEME.textMuted)
end

-- ── Feel: preview playback with inline feedback ──────────────────────────────

local messageText -- bottom-bar status line, built in buildWindow

local function showMessage(text, color)
	if messageText then
		messageText:SetText(text or "")
		setColor(messageText, color or THEME.textMuted)
	end
end

local function report(ok, err)
	if ok then
		showMessage("")
	else
		showMessage(err and (tostring(err):gsub("^%l", string.upper) .. ".") or "Nothing played.", THEME.bad)
	end
	return ok
end

local function feelMode(feel)
	if not Pulse.TestMode then
		return false
	end
	return report(Pulse:TestMode(feel.mode, feel.scale))
end

local function feelCue(triggerID)
	if not (Pulse.TestCue and triggerID) then
		return false
	end
	return report(Pulse:TestCue(triggerID))
end

-- ── Step 1: Controller ───────────────────────────────────────────────────────

local function buildStep1(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	addStepHeader(
		sf,
		"Your controller",
		"Pick your controller to load its motor calibration. Every later step is tuned on top of it."
	)

	local status = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	status:SetPoint("TOPLEFT", sf, "TOPLEFT", 4, -HEADER_H)
	status:SetPoint("RIGHT", sf, "RIGHT", -4, 0)
	status:SetJustifyH("LEFT")

	local applied, detected = "default", nil
	local cards = {}
	local columns, gap = 2, 10
	local cardW = math.floor((CONTENT_W - gap) / columns)
	local cardH, pitch = 32, 37
	local gridTop = HEADER_H + 26

	for _, id in ipairs(Pulse.DEVICE_ORDER) do
		local device = Pulse.Devices[id]
		if device then
			local slot = #cards
			local card = CreateFrame("Button", nil, sf)
			card:SetSize(cardW, cardH)
			card:SetPoint(
				"TOPLEFT",
				sf,
				"TOPLEFT",
				(slot % columns) * (cardW + gap),
				-(gridTop + math.floor(slot / columns) * pitch)
			)

			local border = card:CreateTexture(nil, "BORDER")
			border:SetAllPoints(card)
			local inner = card:CreateTexture(nil, "ARTWORK")
			inner:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
			inner:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
			inner:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.95)

			local pip = card:CreateTexture(nil, "OVERLAY")
			pip:SetSize(3, cardH - 2)
			pip:SetPoint("LEFT", card, "LEFT", 1, 0)
			pip:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1)

			local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetPoint("LEFT", card, "LEFT", 12, 0)
			label:SetText(device.label)

			local tag = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			tag:SetPoint("RIGHT", card, "RIGHT", -10, 0)

			card.refresh = function()
				local inUse = applied == id
				if inUse then
					border:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 0.9)
					setColor(label, THEME.accent)
				else
					border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.7)
					setColor(label, THEME.textPrimary)
				end
				pip:SetShown(inUse)
				if inUse then
					tag:SetText("In use")
					setColor(tag, THEME.good)
				elseif detected == id then
					tag:SetText("Detected")
					setColor(tag, THEME.accent)
				else
					tag:SetText("")
				end
			end

			card:SetScript("OnClick", function()
				-- Re-picking the controller already in use keeps its trimming; only a change
				-- loads new starting values.
				if applied ~= id then
					db():ApplyDevicePreset(id)
				end
				applied = db():GetAppliedDevicePreset()
				for _, c in ipairs(cards) do
					c.refresh()
				end
				feelMode(FEEL.select)
			end)
			attachTip(card, device.label, device.note)

			cards[#cards + 1] = card
		end
	end

	local rows = math.ceil(#cards / columns)
	local note = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	note:SetPoint("TOPLEFT", sf, "TOPLEFT", 4, -(gridTop + rows * pitch + 2))
	note:SetPoint("RIGHT", sf, "RIGHT", -4, 0)
	note:SetJustifyH("LEFT")
	note:SetText(
		"Switching controller replaces motor trimming with its starting values. Not listed? Use Generic / unknown."
	)
	setColor(note, THEME.textMuted)

	local testCard = createCard(sf, CONTENT_W, 46)
	testCard:SetPoint("BOTTOMLEFT", sf, "BOTTOMLEFT", 0, 0)

	local testLabel = testCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	testLabel:SetPoint("LEFT", testCard, "LEFT", 14, 0)
	testLabel:SetText("Hold your controller and press Test. Felt nothing? Check the line above the list.")
	setColor(testLabel, THEME.textPrimary)

	local btnTest = createButton(testCard, "Test rumble", 120, 26, true)
	btnTest:SetPoint("RIGHT", testCard, "RIGHT", -10, 0)
	btnTest:SetScript("OnClick", function()
		feelMode(FEEL.test)
	end)

	sf.OnShowStep = function()
		applied = db():GetAppliedDevicePreset() or "default"
		local deviceID, presetID, name = detectController()
		detected = presetID

		local support = controllerSupportOn()
		if support == false then
			status:SetText(
				"Controller support is off. Type |cffffffff/console GamePadEnable 1|r and restart the game."
			)
			setColor(status, THEME.bad)
		elseif deviceID then
			status:SetText(("Detected: |cffffffff%s|r"):format(name))
			setColor(status, THEME.good)
		else
			status:SetText("No controller detected. Connect one, then press Test rumble.")
			setColor(status, THEME.textMuted)
		end

		for _, c in ipairs(cards) do
			c.refresh()
		end
	end

	return sf
end

-- ── Step 2: Feel (strength, motor balance, subtle cues) ──────────────────────

local function buildKnobCard(sf, top, spec)
	local card = createCard(sf, CONTENT_W, 92)
	card:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, -top)

	local title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
	title:SetText(spec.title)

	local desc = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
	desc:SetPoint("RIGHT", card, "RIGHT", -120, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(spec.desc)
	setColor(desc, THEME.textMuted)

	local slider = createSlider(card, 420, spec.slider)
	slider:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -50)

	local leftHint = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	leftHint:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
	leftHint:SetText(spec.leftHint or "")

	local rightHint = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	rightHint:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
	rightHint:SetText(spec.rightHint or "")

	local btnFeel = createButton(card, "Feel", 90, 26, true)
	btnFeel:SetPoint("RIGHT", card, "RIGHT", -14, 0)
	btnFeel:SetScript("OnClick", function()
		feelMode(spec.feel)
	end)

	return slider
end

local function buildStep2(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	addStepHeader(
		sf,
		"How it feels",
		"Three knobs cover most tuning. Move one, press Feel, repeat until it sits right in your hands."
	)

	local pitch = 102
	local sliders = {}

	sliders[1] = buildKnobCard(sf, HEADER_H, {
		title = "Strength",
		desc = "How hard everything vibrates. Saved in your active profile.",
		feel = FEEL.strength,
		leftHint = "Gentle",
		rightHint = "Full",
		slider = {
			min = 10,
			max = 100,
			step = 5,
			format = percent,
			get = function()
				return Tuning.GetStrength() * 100
			end,
			set = function(value)
				Tuning.SetStrength(value / 100)
			end,
		},
	})

	sliders[2] = buildKnobCard(sf, HEADER_H + pitch, {
		title = "Motor balance",
		desc = "Heavy rumble from the big motor or sharp buzz from the small one. Applies to every profile.",
		feel = FEEL.balance,
		leftHint = "Heavier rumble",
		rightHint = "Sharper buzz",
		slider = {
			min = -100,
			max = 100,
			step = 10,
			format = balanceText,
			get = function()
				return Tuning.GetBalance() * 100
			end,
			set = function(value)
				Tuning.SetBalance(value / 100)
			end,
		},
	})

	sliders[3] = buildKnobCard(sf, HEADER_H + pitch * 2, {
		title = "Subtle cues",
		desc = "Can't feel the small taps? Lift them. Too buzzy? Push them down. Applies to every profile.",
		feel = FEEL.subtle,
		leftHint = "Fainter",
		rightHint = "Stronger",
		slider = {
			min = -100,
			max = 100,
			step = 10,
			format = subtleText,
			get = function()
				return Tuning.GetSubtle() * 100
			end,
			set = function(value)
				Tuning.SetSubtle(value / 100)
			end,
		},
	})

	local footer = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	footer:SetPoint("BOTTOMLEFT", sf, "BOTTOMLEFT", 4, 12)
	footer:SetPoint("RIGHT", sf, "RIGHT", -190, 0)
	footer:SetJustifyH("LEFT")
	setColor(footer, THEME.textMuted)

	local btnReset = createButton(sf, "Reset balance & subtle", 176, 24, false)
	btnReset:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 6)
	btnReset:SetScript("OnClick", function()
		Tuning.ResetCalibration()
		for _, slider in ipairs(sliders) do
			slider.Refresh()
		end
	end)
	attachTip(btnReset, "Reset balance & subtle", function()
		return ("Reloads the %s starting calibration, which also undoes motor trimming made in the full settings."):format(
			deviceLabel(db():GetAppliedDevicePreset())
		)
	end)

	sf.OnShowStep = function()
		for _, slider in ipairs(sliders) do
			slider.Refresh()
		end
		footer:SetText(
			("Balance and subtle start from the %s calibration. Finer motor timing is under Controller calibration in the full settings."):format(
				deviceLabel(db():GetAppliedDevicePreset())
			)
		)
	end

	return sf
end

-- ── Steps 3 and 4: one tunable row per category / texture ────────────────────

local ROW_H = 26

-- spec = { label, tip(), isOn(), setOn(v), isAvailable()?, strength = slider spec, feel() }
local function buildTuneRow(sf, top, spec)
	local card = createCard(sf, CONTENT_W, ROW_H)
	card:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, -top)
	card:EnableMouse(true)
	attachTip(card, spec.label, spec.tip)

	local cb = createCheckbox(card, 20)
	cb:SetPoint("LEFT", card, "LEFT", 8, 0)

	local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", card, "LEFT", 36, 0)
	label:SetWidth(196)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	label:SetText(spec.label)

	local slider = createSlider(card, 270, spec.strength)
	slider:SetPoint("LEFT", card, "LEFT", 240, 0)

	local btnFeel = createButton(card, "Feel", 56, 20, false)
	btnFeel:SetPoint("RIGHT", card, "RIGHT", -6, 0)
	btnFeel:SetScript("OnClick", spec.feel)

	card.refresh = function()
		local on = spec.isOn() and true or false
		local available = (not spec.isAvailable) or spec.isAvailable()
		cb:SetChecked(on)
		slider.Refresh()
		slider:SetEnabled(on and available)
		label:SetAlpha((on and available) and 1 or 0.45)
	end

	cb:SetScript("OnClick", function(self)
		local value = self:GetChecked() and true or false
		playCheckSound(value)
		spec.setOn(value)
		card.refresh()
	end)

	return card
end

local function strengthSpec(get, set)
	return {
		min = 25,
		max = 150,
		step = 5,
		format = percent,
		get = function()
			return get() * 100
		end,
		set = function(value)
			set(value / 100)
		end,
	}
end

local function addBulkButtons(sf, onAll)
	local btnOff = createButton(sf, "All off", 70, 20, false)
	btnOff:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -6)
	btnOff:SetScript("OnClick", function()
		onAll(false)
	end)

	local btnOn = createButton(sf, "All on", 70, 20, false)
	btnOn:SetPoint("RIGHT", btnOff, "LEFT", -6, 0)
	btnOn:SetScript("OnClick", function()
		onAll(true)
	end)
end

local function sectionList(page)
	local names = {}
	for _, section in ipairs(page.sections or {}) do
		names[#names + 1] = section.label
	end
	return table.concat(names, ", ")
end

local function buildStep3(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	addStepHeader(
		sf,
		"What you feel",
		"Each row is a page of the full settings: its switch, and one strength for its cues. 100% is as designed."
	)

	local rows = {}
	local pitch = ROW_H + 5
	for index, page in ipairs(Tuning.Categories()) do
		local pageID = page.id
		rows[#rows + 1] = buildTuneRow(sf, HEADER_H + (index - 1) * pitch, {
			label = page.label,
			tip = function()
				return ("Covers: %s.\n\nThe checkbox is this page's switch in the full settings. Strength scales every cue on the page from its designed level; single cues can still be fine-tuned there."):format(
					sectionList(page)
				)
			end,
			isOn = function()
				return Tuning.IsCategoryOn(pageID)
			end,
			setOn = function(value)
				Tuning.SetCategoryOn(pageID, value)
			end,
			strength = strengthSpec(function()
				return Tuning.GetCategoryStrength(pageID)
			end, function(value)
				Tuning.SetCategoryStrength(pageID, value)
			end),
			feel = function()
				feelCue(Tuning.SampleCue(pageID))
			end,
		})
	end

	local function refreshAll()
		for _, row in ipairs(rows) do
			row.refresh()
		end
	end

	addBulkButtons(sf, function(enabled)
		for _, page in ipairs(Tuning.Categories()) do
			Tuning.SetCategoryOn(page.id, enabled)
		end
		refreshAll()
	end)

	sf.OnShowStep = refreshAll
	return sf
end

local function buildStep4(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	addStepHeader(
		sf,
		"Immersion textures",
		"Continuous vibration while something lasts: gliding, swimming, casting, weather. Pick and tune each one."
	)

	local rows = {}
	local textures = Tuning.Textures()
	local pitch = ROW_H + 3
	for index, entry in ipairs(textures) do
		local trigger, page = entry.trigger, entry.page
		local id = trigger.id
		rows[#rows + 1] = buildTuneRow(sf, HEADER_H + (index - 1) * pitch, {
			label = trigger.label or id,
			tip = function()
				local body = trigger.desc or ""
				if not Pulse:GatesOpen(id, trigger) then
					body = body .. ("\n\nSilent while %s is switched off in Categories."):format(page.label)
				end
				return body
			end,
			isOn = function()
				return db():GetCue(id)
			end,
			setOn = function(value)
				db():SetCue(id, value)
			end,
			isAvailable = function()
				return Pulse:GatesOpen(id, trigger)
			end,
			strength = strengthSpec(function()
				return Tuning.GetCueStrength(id)
			end, function(value)
				Tuning.SetCueStrength(id, value)
			end),
			feel = function()
				feelCue(id)
			end,
		})
	end

	local function refreshAll()
		for _, row in ipairs(rows) do
			row.refresh()
		end
	end

	addBulkButtons(sf, function(enabled)
		for _, entry in ipairs(textures) do
			db():SetCue(entry.trigger.id, enabled)
		end
		refreshAll()
	end)

	sf.OnShowStep = refreshAll
	return sf
end

-- ── Step 5: Finish ───────────────────────────────────────────────────────────

local function buildStep5(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	addStepHeader(sf, "All set", "Everything is already saved as you go. Closing this window keeps it.")

	local card = createCard(sf, CONTENT_W, 250)
	card:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, -HEADER_H)

	local summary = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	summary:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)
	summary:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	summary:SetJustifyH("LEFT")
	summary:SetSpacing(5)

	local hint = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hint:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 4, -12)
	hint:SetPoint("RIGHT", sf, "RIGHT", -4, 0)
	hint:SetJustifyH("LEFT")
	hint:SetSpacing(3)
	setColor(hint, THEME.textMuted)
	hint:SetText(
		"Come back any time with |cff4cb8ff/pulse setup|r: every step shows your current settings.\n"
			.. "Single cues, vibration shapes and motor timing live in the full settings (|cff4cb8ff/pulse|r)."
	)

	sf.OnShowStep = function()
		local categoriesOn, categories = 0, Tuning.Categories()
		for _, page in ipairs(categories) do
			if Tuning.IsCategoryOn(page.id) then
				categoriesOn = categoriesOn + 1
			end
		end
		local texturesOn, textures = 0, Tuning.Textures()
		for _, entry in ipairs(textures) do
			if db():GetCue(entry.trigger.id) then
				texturesOn = texturesOn + 1
			end
		end
		local profile = db():GetActiveProfileName() or "Default"

		summary:SetText(
			table.concat({
				("Controller:  |cffffffff%s|r"):format(deviceLabel(db():GetAppliedDevicePreset())),
				("Motor balance:  |cffffffff%s|r     Subtle cues:  |cffffffff%s|r"):format(
					balanceText(Tuning.GetBalance() * 100),
					subtleText(Tuning.GetSubtle() * 100)
				),
				"",
				("Profile:  |cffffffff%s|r"):format(profile),
				("Strength:  |cffffffff%s|r"):format(percent(Tuning.GetStrength() * 100)),
				("Categories on:  |cffffffff%d of %d|r     Textures on:  |cffffffff%d of %d|r"):format(
					categoriesOn,
					#categories,
					texturesOn,
					#textures
				),
				"",
				("Controller, balance and subtle cues apply to every profile. Strength, categories and textures belong to |cffffffff%s|r."):format(
					profile
				),
			}, "\n")
		)
	end

	return sf
end

-- ── Window ───────────────────────────────────────────────────────────────────

local stepFrames = {}
local stepTabs = {}
local btnBack, btnNext, btnDone

local function updateStepView()
	for i = 1, STEP_COUNT do
		if stepFrames[i] then
			stepFrames[i]:SetShown(i == currentStep)
		end
		local tab = stepTabs[i]
		if tab then
			if i == currentStep then
				setColor(tab.text, THEME.accent)
			elseif i < currentStep then
				setColor(tab.text, THEME.good)
			else
				setColor(tab.text, THEME.textMuted)
			end
			tab.underline:SetShown(i == currentStep)
		end
	end

	if btnBack then
		btnBack:SetShown(currentStep > 1)
	end
	if btnNext then
		btnNext:SetShown(currentStep < STEP_COUNT)
	end
	if btnDone then
		btnDone:SetShown(currentStep == STEP_COUNT)
	end
end

local function goToStep(step)
	currentStep = clamp(step, 1, STEP_COUNT)
	showMessage("")
	if Pulse.CancelContinuousPreview then
		Pulse:CancelContinuousPreview()
	end
	local sf = stepFrames[currentStep]
	if sf and sf.OnShowStep then
		sf.OnShowStep()
	end
	updateStepView()
end
QuickSetup.GoToStep = goToStep

local function buildWindow()
	if frame then
		return frame
	end

	local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
	f:SetSize(WINDOW_W, WINDOW_H)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)

	-- Register Escape to close
	tinsert(UISpecialFrames, FRAME_NAME)

	local border = f:CreateTexture(nil, "BORDER")
	border:SetAllPoints(f)
	border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, THEME.border.a)

	local inner = f:CreateTexture(nil, "ARTWORK")
	inner:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	inner:SetColorTexture(THEME.bg.r, THEME.bg.g, THEME.bg.b, THEME.bg.a)

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

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function()
		QuickSetup.Close()
	end)

	-- Step tabs: clickable, so any step can be revisited directly to re-tune it.
	local stepBar = CreateFrame("Frame", nil, f)
	stepBar:SetHeight(26)
	stepBar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 16, -6)
	stepBar:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", -16, -6)

	local tabGap = 6
	local tabW = math.floor((CONTENT_W - tabGap * (STEP_COUNT - 1)) / STEP_COUNT)
	for i = 1, STEP_COUNT do
		local tab = CreateFrame("Button", nil, stepBar)
		tab:SetSize(tabW, 26)
		tab:SetPoint("LEFT", stepBar, "LEFT", (i - 1) * (tabW + tabGap), 0)

		local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("LEFT", tab, "LEFT", 2, 1)
		text:SetText(("%d. %s"):format(i, STEP_LABELS[i]))
		tab.text = text

		local underline = tab:CreateTexture(nil, "OVERLAY")
		underline:SetHeight(2)
		underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
		underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
		underline:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 0.9)
		tab.underline = underline

		tab:SetScript("OnClick", function()
			goToStep(i)
		end)
		stepTabs[i] = tab
	end

	-- Content Container
	local container = CreateFrame("Frame", nil, f)
	container:SetPoint("TOPLEFT", stepBar, "BOTTOMLEFT", 0, -8)
	container:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 56)

	stepFrames[1] = buildStep1(container)
	stepFrames[2] = buildStep2(container)
	stepFrames[3] = buildStep3(container)
	stepFrames[4] = buildStep4(container)
	stepFrames[5] = buildStep5(container)

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

	local primaryW, gap = 130, 10

	btnBack = createButton(bottomBar, "< Back", 100, 28, false)
	btnBack:SetPoint("LEFT", bottomBar, "LEFT", 0, 0)
	btnBack:SetScript("OnClick", function()
		goToStep(currentStep - 1)
	end)

	btnNext = createButton(bottomBar, "Next >", primaryW, 28, true)
	btnNext:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
	btnNext:SetScript("OnClick", function()
		goToStep(currentStep + 1)
	end)

	btnDone = createButton(bottomBar, "Done", primaryW, 28, true)
	btnDone:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
	btnDone:SetScript("OnClick", function()
		db():SetQuickSetupCompleted(true)
		feelMode(FEEL.finish)
		QuickSetup.Close()
		print("|cff4cb8ffPulse:|r Quick setup saved. |cffffffff/pulse setup|r re-tunes it, |cffffffff/pulse|r opens every setting.")
	end)

	local btnAdvanced = createButton(bottomBar, "Full settings", primaryW, 28, false)
	btnAdvanced:SetPoint("RIGHT", bottomBar, "RIGHT", -(primaryW + gap), 0)
	btnAdvanced:SetScript("OnClick", function()
		db():SetQuickSetupCompleted(true)
		QuickSetup.Close()
		if Pulse.UI.Panel and Pulse.UI.Panel.Open then
			Pulse.UI.Panel.Open()
		end
	end)

	-- Feel feedback ("No controller detected.") between Back and Full settings.
	messageText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	messageText:SetPoint("LEFT", bottomBar, "LEFT", 110, 0)
	messageText:SetPoint("RIGHT", btnAdvanced, "LEFT", -gap, 0)
	messageText:SetJustifyH("CENTER")

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
	goToStep(initialStep or 1)
	frame:Show()
end

function QuickSetup.Close()
	if Pulse.CancelContinuousPreview then
		Pulse:CancelContinuousPreview()
	end
	hideTip()
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
