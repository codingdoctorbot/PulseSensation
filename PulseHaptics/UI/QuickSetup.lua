-- Pulse — UI/QuickSetup.lua
--
-- Standalone Quick Setup wizard for first-time onboarding and rapid configuration.
-- Completely isolated from Blizzard's protected Settings managers to prevent taint.
--
-- 6-Step Guided Flow:
--   1. Controller Hardware (8 device presets + rumble calibration test)
--   2. Combat Haptics (Offensive & Defensive + Class & Planned Role)
--   3. World & Target Interactions (World & Discovery + Target & Crosshair)
--   4. Interface & Social (Controller UI & Windows + Social & Group Readiness)
--   5. Immersion & Continuous Textures (12 effects; casting, crafting, low-health and breath enabled for new setups)
--   6. Master Strength & Finish (Master intensity slider, live summary, save & play)

local ADDON_NAME, Pulse = ...
local L = Pulse.L or function(text) return text end

Pulse.UI = Pulse.UI or {}
local QuickSetup = {}
Pulse.UI.QuickSetup = QuickSetup

local FRAME_NAME = "PulseQuickSetupFrame"
local frame
local currentStep = 1
local fitButton

local THEME = {
	bg = { r = 0.035, g = 0.040, b = 0.055, a = 1.0 },
	surface = { r = 0.060, g = 0.068, b = 0.085, a = 0.95 },
	border = { r = 0.18, g = 0.22, b = 0.28, a = 0.75 },
	accent = { r = 0.30, g = 0.72, b = 1.00, a = 1.0 },
	accentDim = { r = 0.15, g = 0.40, b = 0.60, a = 0.8 },
	textPrimary = { r = 0.90, g = 0.93, b = 0.96 },
	textMuted = { r = 0.53, g = 0.58, b = 0.68 },
	live = { r = 0.18, g = 0.83, b = 0.75 },
}

-- ── Data Definitions ─────────────────────────────────────────────────────────

local CONTROLLER_OPTIONS = {
	{
		id = "dualsense",
		label = L("DualSense (PS5)"),
		desc = L("Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response"),
	},
	{ id = "ds4", label = L("DualShock 4 (PS4)"), desc = L("Dual asymmetrical ERM motors, balanced 75ms spin-up") },
	{
		id = "xbox",
		label = L("Xbox One / Series"),
		desc = L("Heavy left counterweight (85ms), light right counterweight (45ms)"),
	},
	{
		id = "xbox_elite",
		label = L("Xbox Elite Series 2"),
		desc = L("Tuned for heavy chassis damping (+10% Low motor gain)"),
	},
	{ id = "switchpro", label = L("Nintendo Switch Pro"), desc = L("Tuned for HD Rumble voice-coil actuators") },
	{ id = "8bitdo", label = L("8BitDo / Other XInput"), desc = L("Calibrated for standard third-party ERM rumble curves") },
	{ id = "steamdeck", label = L("Steam Deck / Controller"), desc = L("Tuned for trackpad & chassis LRA haptics") },
	{ id = "default", label = L("Generic / Unknown"), desc = L("Engine defaults without device-specific calibration") },
}

local CLASS_LIST = {
	{ id = "WARRIOR", label = L("Warrior"), color = { r = 0.78, g = 0.61, b = 0.43 } },
	{ id = "PALADIN", label = L("Paladin"), color = { r = 0.96, g = 0.55, b = 0.73 } },
	{ id = "HUNTER", label = L("Hunter"), color = { r = 0.67, g = 0.83, b = 0.45 } },
	{ id = "ROGUE", label = L("Rogue"), color = { r = 1.00, g = 0.96, b = 0.41 } },
	{ id = "PRIEST", label = L("Priest"), color = { r = 1.00, g = 1.00, b = 1.00 } },
	{ id = "SHAMAN", label = L("Shaman"), color = { r = 0.00, g = 0.44, b = 0.87 } },
	{ id = "MAGE", label = L("Mage"), color = { r = 0.25, g = 0.78, b = 0.92 } },
	{ id = "WARLOCK", label = L("Warlock"), color = { r = 0.53, g = 0.53, b = 0.93 } },
	{ id = "DRUID", label = L("Druid"), color = { r = 1.00, g = 0.49, b = 0.04 } },
	{ id = "DEATHKNIGHT", label = L("Death Knight"), color = { r = 0.77, g = 0.12, b = 0.23 } },
}

local ROLE_LIST = {
	{ id = "tank", label = L("🛡️ Tank"), desc = L("Threat, mitigations, and CC") },
	{ id = "healer", label = L("💚 Healer"), desc = L("Heal casts and low-health triage") },
	{ id = "melee", label = L("⚔️ Melee DPS"), desc = L("Weapon swings, ability cadence, and auto-attack stops") },
	{ id = "ranged", label = L("🏹 Ranged DPS"), desc = L("Spell flow, instant casts, and interrupts") },
}

-- Cues each role / class switches on. Mind the direction: critLanded, healCrit and
-- healReceived fire when YOU are crit or healed (see their Registry caveats), so they are
-- survival cues for a tank, not output cues for a DPS or healer.
local ROLE_CUES = {
	tank = { "threatLost", "deflect", "damageTaken", "critLanded", "debuffReceived" },
	healer = { "selfCastSucceeded", "selfCastInterrupted", "threatAggro" },
	melee = { "weaponSwingMain", "weaponSwingOff", "abilityPulse", "meleeAttackStop" },
	ranged = { "selfCastSucceeded", "selfCastInstant", "selfCastInterrupted" },
}

-- Only classes with a cue that is theirs alone. autoShotFired is Hunter-specific (spell 75).
local CLASS_CUES = {
	HUNTER = { "autoShotFired", "autoRepeatStop" },
	ROGUE = { "comboPoint" },
	DRUID = { "comboPoint", "formChanged" },
}

local selectedClass = nil
-- nil until the player picks one: a highlighted role must mean its cues were applied.
local selectedRole = nil

-- Switch a cue on or off, and when switching it on also open the page gate and category
-- master in front of it — otherwise a cue enabled here stays silent if that page was
-- switched off in the settings window.
local function setCue(id, enabled)
	Pulse.Database:SetCue(id, enabled)
	if not enabled then
		return
	end
	local registry = Pulse.Registry
	local trigger = registry:GetTrigger(id)
	local master = trigger and registry.ALERT_CATEGORY_MASTER[trigger.category]
	if master and master ~= id then
		Pulse.Database:SetCue(master, true)
	end
	local gate = registry.CUE_GATE[id]
	if gate and gate ~= id then
		Pulse.Database:SetCue(gate, true)
	end
end

-- Apply the selected class and role. Cues owned by a role or class that is NOT selected go
-- back to their registry default rather than off, so clicking through all four roles does
-- not leave all four applied, and default-on cues (deflect, critLanded, threat warnings)
-- are not silenced just because another role listed them.
local function applyClassAndRole()
	local wanted, managed = {}, {}
	for _, sets in ipairs({ ROLE_CUES, CLASS_CUES }) do
		for _, ids in pairs(sets) do
			for _, id in ipairs(ids) do
				managed[id] = true
			end
		end
	end
	for _, id in ipairs(ROLE_CUES[selectedRole] or {}) do
		wanted[id] = true
	end
	for _, id in ipairs(CLASS_CUES[selectedClass] or {}) do
		wanted[id] = true
	end
	for id in pairs(managed) do
		local trigger = Pulse.Registry:GetTrigger(id)
		if wanted[id] then
			setCue(id, true)
		elseif trigger then
			setCue(id, trigger.default and true or false)
		end
	end
end

-- Every test button goes through here so a failure ("no controller detected") is reported
-- instead of swallowed. `quiet` is for the incidental feedback taps on selection clicks.
local function reportTest(ok, reason, quiet)
	if not ok and reason and not quiet then
		print("|cffff5555Pulse:|r " .. tostring(reason))
	end
end

local function testMode(modeID, scale, quiet)
	if Pulse.TestMode then
		local ok, reason = Pulse:TestMode(modeID, scale)
		reportTest(ok, reason, quiet)
	end
end

local CONTINUOUS_OPTIONS = {
	{
		id = "glideThrust",
		label = L("Skyriding / Gliding Thrust"),
		desc = L("Wind resistance & thrust surge while flying. Scales dynamically with your flight speed."),
		default = false,
	},
	{
		id = "locomotion",
		label = L("Footfalls & Mount Gait"),
		desc = L("Rhythmic footsteps on foot and hoofbeat cadence while mounted, weighted by armor class."),
		default = false,
	},
	{
		id = "waterTexture",
		label = L("In Water (Buoyancy)"),
		desc = L("Subtle hydrostatic floating texture when swimming or bobbing in bodies of water."),
		default = false,
	},
	{
		id = "swimTexture",
		label = L("Swimming Resistance"),
		desc = L("Hydrodynamic water drag that scales as you swim forward through rivers and seas."),
		default = false,
	},
	{
		id = "oceanTexture",
		label = L("Ocean Waves & Swell"),
		desc = L("Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans."),
		default = false,
	},
	{
		id = "castTexture",
		label = L("Spellcasting Channel Hum"),
		desc = L("Continuous magical hum that builds during casts and channels steadily through your hands."),
		default = true,
	},
	{
		id = "craftTexture",
		label = L("Crafting Rhythms"),
		desc = L("Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches."),
		default = true,
	},
	{
		id = "weatherTexture",
		label = L("Weather Atmosphere"),
		desc = L("Light rain patter, crisp snow rustle, and deep desert sandstorm rumbles."),
		default = false,
	},
	{
		id = "breathTexture",
		label = L("Breath Depletion"),
		desc = L("Rising heartbeat pulse that quickens and intensifies as your breath meter runs low underwater."),
		default = true,
	},
	{
		id = "lowHealthWarning",
		label = L("Low Health Heartbeat"),
		desc = L("Urgent repeating cardiac 'lub-dub' rhythm in sync with screen warnings below 20% health."),
		default = true,
	},
	{
		id = "taxiRide",
		label = L("Flight Path Cruise"),
		desc = L("Gentle steady engine-like cruise vibration while riding flight master gryphons, bats, or wyverns."),
		default = false,
	},
	{
		id = "stealthTexture",
		label = L("Stealth Breathing Wave"),
		desc = L("Slow, rhythmic breathing expansion wave keeping you aware of your stealth state."),
		default = false,
	},
}

-- Seed only genuinely new installs. Existing profiles and a partially completed wizard
-- keep the player's saved choices when this window is opened again.
local function applyInitialContinuousDefaults()
	local database = Pulse.Database
	if not database:Get("quickSetupDefaultsPending") then
		return
	end
	for _, option in ipairs(CONTINUOUS_OPTIONS) do
		setCue(option.id, option.default)
	end
	database:Set("quickSetupDefaultsPending", false)
end

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

-- Translations run longer than English: buttons grow to their text instead of spilling out.
fitButton = function(btn)
	local label = btn.GetFontString and btn:GetFontString()
	if label and label.GetStringWidth then
		btn:SetWidth(math.max(btn.minWidth or 0, math.ceil(label:GetStringWidth() or 0) + 24))
	end
end

-- Shrinks a one-line string slightly, then truncates, so it never runs under its neighbours.
local function fitLine(fs, available)
	fs:SetWidth(available)
	if fs.SetWordWrap then
		fs:SetWordWrap(false)
	end
	if fs.SetTextScale then
		fs:SetTextScale(1)
		local natural = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
		if natural and natural > available then
			fs:SetTextScale(math.max(0.85, available / natural))
		end
	end
end

local function createButton(parent, text, width, height, isAccent)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 120, height or 26)
	btn:SetText(text)

	if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.StyleActionButton then
		Pulse.UI.Panel.Theme.StyleActionButton(btn, isAccent)
	end
	btn.minWidth = width or 120
	fitButton(btn)

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

-- ── Window Construction & Controller Navigation ─────────────────────────────

local TOTAL_STEPS = 6
local stepFrames = {}
local stepIndicators = {}
local btnBack, btnNext, btnFinish, btnAdvanced
local tabIndicatorL1, tabIndicatorR1, navLegend

local quickNavFocus = nil
local quickFocusBox = nil
local pendingCaptureCleanup

local function getQuickFocusBox(parent)
	if quickFocusBox then
		return quickFocusBox
	end

	local fb = CreateFrame("Frame", nil, parent)
	fb:SetFrameStrata("DIALOG")
	fb:SetFrameLevel((parent:GetFrameLevel() or 10) + 30)

	-- Hollow 2px Electric Cyan Border (never washes out the card surface)
	local bTop = fb:CreateTexture(nil, "OVERLAY")
	bTop:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	bTop:SetPoint("TOPRIGHT", fb, "TOPRIGHT", 0, 0)
	bTop:SetHeight(2)
	bTop:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
	fb.bTop = bTop

	local bBottom = fb:CreateTexture(nil, "OVERLAY")
	bBottom:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	bBottom:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", 0, 0)
	bBottom:SetHeight(2)
	bBottom:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
	fb.bBottom = bBottom

	local bLeft = fb:CreateTexture(nil, "OVERLAY")
	bLeft:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	bLeft:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	bLeft:SetWidth(2)
	bLeft:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
	fb.bLeft = bLeft

	local bRight = fb:CreateTexture(nil, "OVERLAY")
	bRight:SetPoint("TOPRIGHT", fb, "TOPRIGHT", 0, 0)
	bRight:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", 0, 0)
	bRight:SetWidth(2)
	bRight:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
	fb.bRight = bRight

	-- Glowing Left Accent Docking Socket (4px wide, vibrant neon cyan)
	local accent = fb:CreateTexture(nil, "OVERLAY")
	accent:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	accent:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	accent:SetWidth(4)
	accent:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
	fb.accent = accent

	-- Subtle translucent interior tint (only 0.05 alpha for crystal-clear readability)
	local inner = fb:CreateTexture(nil, "BACKGROUND")
	inner:SetPoint("TOPLEFT", fb, "TOPLEFT", 2, -2)
	inner:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", -2, 2)
	inner:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 0.05)
	fb.inner = inner

	fb:Hide()
	quickFocusBox = fb
	return fb
end

local function setQuickFocus(target)
	if quickNavFocus and quickNavFocus.isSlider and quickNavFocus.SetAdjusting and target ~= quickNavFocus then
		quickNavFocus.SetAdjusting(false)
	end
	quickNavFocus = target
	if not target or not target.widget or not target.widget:IsShown() then
		if quickFocusBox then
			quickFocusBox:Hide()
		end
		return
	end
	if not frame then
		return
	end
	local fb = getQuickFocusBox(frame)
	fb:ClearAllPoints()
	fb:SetPoint("TOPLEFT", target.widget, "TOPLEFT", -2, 2)
	fb:SetPoint("BOTTOMRIGHT", target.widget, "BOTTOMRIGHT", 2, -2)
	if fb.bTop then
		fb.bTop:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
		fb.bBottom:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
		fb.bLeft:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
		fb.bRight:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
		fb.accent:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
	end
	fb:Show()
	if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
	end
end

local function navigateQuickStep(direction)
	local targets = stepFrames[currentStep] and stepFrames[currentStep].navTargets or {}
	if #targets == 0 then
		return
	end

	if not quickNavFocus or not quickNavFocus.widget or not quickNavFocus.widget:IsShown() then
		setQuickFocus(targets[1])
		return
	end

	local cx, cy = quickNavFocus.widget:GetCenter()
	if not cx or not cy then
		setQuickFocus(targets[1])
		return
	end

	local bestTarget = nil
	local lowestScore = math.huge

	for _, target in ipairs(targets) do
		local cand = target.widget
		if cand ~= quickNavFocus.widget and cand:IsShown() then
			local tx, ty = cand:GetCenter()
			if tx and ty then
				local dx = tx - cx
				local dy = ty - cy
				local valid = false

				if direction == "UP" and dy > 6 then
					valid = true
				elseif direction == "DOWN" and dy < -6 then
					valid = true
				elseif direction == "RIGHT" and dx > 6 then
					valid = true
				elseif direction == "LEFT" and dx < -6 then
					valid = true
				end

				if valid then
					local euclidean = math.sqrt(dx * dx + dy * dy)
					local perp = (direction == "UP" or direction == "DOWN") and math.abs(dx) or math.abs(dy)
					local parallel = (direction == "UP" or direction == "DOWN") and math.abs(dy) or math.abs(dx)
					local score = euclidean * (1.0 + (perp / (parallel + 1.0)) * 2.5)

					if score < lowestScore then
						lowestScore = score
						bestTarget = target
					end
				end
			end
		end
	end

	if bestTarget then
		setQuickFocus(bestTarget)
	end
end

local function onQuickGamepadInput(key)
	if InCombatLockdown and InCombatLockdown() then
		QuickSetup.Close()
		return
	end

	-- Bumper navigation
	if key == "PADLSHOULDER" then
		if currentStep > 1 then
			currentStep = currentStep - 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end
		return
	elseif key == "PADRSHOULDER" then
		if currentStep < TOTAL_STEPS then
			currentStep = currentStep + 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end
		return
	end

	-- B button: if adjusting slider, cancel adjustment mode; otherwise step back or close
	if key == "PAD2" then
		if quickNavFocus and quickNavFocus.isSlider and quickNavFocus.IsAdjusting and quickNavFocus.IsAdjusting() then
			quickNavFocus.SetAdjusting(false)
			return
		end
		if currentStep > 1 then
			currentStep = currentStep - 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		else
			QuickSetup.Close()
		end
		return
	end

	-- Start button: finish if on step 6, otherwise advance
	if key == "PADFORWARD" then
		if currentStep == TOTAL_STEPS then
			if btnFinish then
				btnFinish:Click()
			end
		else
			if btnNext then
				btnNext:Click()
			end
		end
		return
	end

	-- D-Pad directional navigation
	if key == "PADDUP" then
		navigateQuickStep("UP")
	elseif key == "PADDDOWN" then
		navigateQuickStep("DOWN")
	elseif key == "PADDLEFT" then
		if quickNavFocus and quickNavFocus.isSlider and quickNavFocus.IsAdjusting and quickNavFocus.IsAdjusting() then
			quickNavFocus.OnStep(-1)
		elseif quickNavFocus and not quickNavFocus.isSlider and quickNavFocus.OnStep then
			quickNavFocus.OnStep(-1)
		else
			navigateQuickStep("LEFT")
		end
	elseif key == "PADDRIGHT" then
		if quickNavFocus and quickNavFocus.isSlider and quickNavFocus.IsAdjusting and quickNavFocus.IsAdjusting() then
			quickNavFocus.OnStep(1)
		elseif quickNavFocus and not quickNavFocus.isSlider and quickNavFocus.OnStep then
			quickNavFocus.OnStep(1)
		else
			navigateQuickStep("RIGHT")
		end
	elseif key == "PAD1" then
		-- A button: activate focused target
		if quickNavFocus and quickNavFocus.OnActivate then
			quickNavFocus.OnActivate()
		end
	end
end

-- Native OnGamePadButtonDown handles navigation; never redirect gameplay keys to
-- an invisible click target. Clean up only our own stale overrides, after combat if needed.
local function releaseQuickCaptureKeys(owner)
	if not owner or not ClearOverrideBindings then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		pendingCaptureCleanup = owner
		return
	end
	ClearOverrideBindings(owner)
	if pendingCaptureCleanup == owner then
		pendingCaptureCleanup = nil
	end
end

function updateStepView()
	for i = 1, TOTAL_STEPS do
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

	if tabIndicatorL1 then
		if currentStep > 1 then
			tabIndicatorL1:SetText(L("|cff38BDF8[L1 / LB]|r"))
		else
			tabIndicatorL1:SetText(L("|cff444444[L1 / LB]|r"))
		end
	end
	if tabIndicatorR1 then
		if currentStep < TOTAL_STEPS then
			tabIndicatorR1:SetText(L("|cff38BDF8[R1 / RB]|r"))
		else
			tabIndicatorR1:SetText(L("|cff444444[R1 / RB]|r"))
		end
	end

	if btnBack then
		btnBack:SetShown(currentStep > 1)
	end
	if btnNext then
		btnNext:SetShown(currentStep < TOTAL_STEPS)
	end
	if btnFinish then
		btnFinish:SetShown(currentStep == TOTAL_STEPS)
	end
	if btnAdvanced then
		btnAdvanced:SetShown(currentStep == TOTAL_STEPS)
	end

	if navLegend then
		if currentStep == TOTAL_STEPS then
			navLegend:SetText(L("|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select"))
		else
			navLegend:SetText(
				L("|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[D-Pad]|r Navigate  •  |cff38BDF8[A]|r Select")
			)
		end
		-- The legend gets whatever the visible buttons leave free.
		local used = 112 + 10
		for _, btn in ipairs({ btnNext, btnFinish, btnAdvanced }) do
			if btn and btn:IsShown() then
				used = used + btn:GetWidth() + 10
			end
		end
		fitLine(navLegend, math.max(80, 640 - used)) -- bottom bar: 676 window - 2 × 18 inset
	end

	local targets = stepFrames[currentStep] and stepFrames[currentStep].navTargets or {}
	if #targets > 0 then
		setQuickFocus(targets[1])
	else
		if quickFocusBox then
			quickFocusBox:Hide()
		end
	end
end

-- ── Step 1: Controller Hardware Selection ────────────────────────────────────

local function buildStep1(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText(L("Step 1: Choose Your Controller Hardware"))
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	-- Language cycles in place so gamepad players never need a dropdown.
	local btnLanguage = createButton(sf, "", 200, 22, false)
	btnLanguage:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -10, -8)
	title:SetPoint("RIGHT", btnLanguage, "LEFT", -8, 0)
	title:SetJustifyH("LEFT")

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(
		L("Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.")
	)
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local selectedDevice = Pulse.Database:GetAppliedDevicePreset() or "default"
	local devCards = {}

	local startY = -68
	local cardW = 308
	local cardH = 72 -- room for two-line translated descriptions

	for idx, opt in ipairs(CONTROLLER_OPTIONS) do
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local x = col * (cardW + 12) + 6
		local y = startY - row * (cardH + 6)

		local card = CreateFrame("Button", nil, sf)
		card:SetSize(cardW, cardH)
		card:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

		local bg = card:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(card)
		bg:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.90)
		card.bg = bg

		local border = card:CreateTexture(nil, "BORDER")
		border:SetAllPoints(card)
		border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.7)
		card.border = border

		local inner = card:CreateTexture(nil, "ARTWORK")
		inner:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
		inner:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
		inner:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.95)
		card.inner = inner

		local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
		label:SetText(opt.label)

		local activeBadge = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		activeBadge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
		activeBadge:SetText("|cff2dd4bf[" .. L("ACTIVE") .. "]|r")
		activeBadge:Hide()
		card.activeBadge = activeBadge

		local sub = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		sub:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
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
				inner:SetColorTexture(0.06, 0.10, 0.16, 0.96)
				border:SetColorTexture(THEME.accentDim.r, THEME.accentDim.g, THEME.accentDim.b, 0.8)
				label:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)
				pip:Show()
				activeBadge:Show()
			else
				inner:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.95)
				border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.6)
				label:SetTextColor(THEME.textPrimary.r, THEME.textPrimary.g, THEME.textPrimary.b)
				pip:Hide()
				activeBadge:Hide()
			end
		end

		card:SetScript("OnEnter", function()
			if selectedDevice ~= opt.id then
				inner:SetColorTexture(THEME.surface.r + 0.02, THEME.surface.g + 0.02, THEME.surface.b + 0.03, 0.95)
			end
		end)
		card:SetScript("OnLeave", function()
			if selectedDevice ~= opt.id then
				inner:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.95)
			end
		end)

		card:SetScript("OnClick", function()
			selectedDevice = opt.id
			Pulse.Database:ApplyDevicePreset(opt.id)
			for _, c in ipairs(devCards) do
				c.refresh()
			end
			testMode("TAP", 0.6, true)
		end)

		card.refresh = refreshCard
		devCards[#devCards + 1] = card
		refreshCard()
	end

	local testCard = createCard(sf, 634, 46)
	testCard:SetPoint("BOTTOMLEFT", sf, "BOTTOMLEFT", 6, 6)

	local testLabel = testCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	testLabel:SetPoint("LEFT", testCard, "LEFT", 16, 0)
	testLabel:SetText(L("Verify controller connection and motor calibration:"))
	testLabel:SetTextColor(THEME.textPrimary.r, THEME.textPrimary.g, THEME.textPrimary.b)

	local btnTest = createButton(testCard, L("Test Rumble"), 140, 26, true)
	btnTest:SetPoint("RIGHT", testCard, "RIGHT", -12, 0)
	btnTest:SetScript("OnClick", function()
		testMode("HEAVY", 0.85)
	end)

	local btnReload = createButton(testCard, L("Reload & continue"), 150, 26, true)
	btnReload:SetPoint("RIGHT", btnTest, "LEFT", -10, 0)
	btnReload:SetScript("OnClick", function()
		Pulse.Database:Set("quickSetupResumePending", true)
		ReloadUI()
	end)
	testLabel:SetPoint("RIGHT", btnReload, "LEFT", -10, 0)
	testLabel:SetJustifyH("LEFT")

	local function languageValue()
		local value = Pulse.Database:Get("language")
		return Pulse.Locale:IsSupported(value) and value or "auto"
	end
	local function refreshLanguage()
		local options = Pulse.Locale:GetOptions()
		local value = languageValue()
		for _, opt in ipairs(options) do
			if opt.value == value then
				btnLanguage:SetText("|cff2dd4bf" .. L("Language:") .. "|r " .. opt.label)
				fitButton(btnLanguage)
			end
		end
		local pending = Pulse.Locale:NeedsReload()
		btnReload:SetShown(pending)
		testLabel:SetText(pending and L("Reload UI to apply the language change.")
			or L("Verify controller connection and motor calibration:"))
	end
	btnLanguage:SetScript("OnClick", function()
		local options = Pulse.Locale:GetOptions()
		local value, nextIndex = languageValue(), 1
		for i, opt in ipairs(options) do
			if opt.value == value then
				nextIndex = i % #options + 1
			end
		end
		Pulse.Database:Set("language", options[nextIndex].value)
		refreshLanguage()
	end)
	refreshLanguage()

	local navTargets = {}
	for _, c in ipairs(devCards) do
		navTargets[#navTargets + 1] = {
			widget = c,
			OnActivate = function()
				c:Click()
			end,
		}
	end
	navTargets[#navTargets + 1] = {
		widget = btnTest,
		OnActivate = function()
			btnTest:Click()
		end,
	}
	navTargets[#navTargets + 1] = {
		widget = btnLanguage,
		OnActivate = function()
			btnLanguage:Click()
		end,
	}
	navTargets[#navTargets + 1] = {
		widget = btnReload,
		OnActivate = function()
			if btnReload:IsShown() then
				btnReload:Click()
			end
		end,
	}
	sf.navTargets = navTargets

	sf.OnShowStep = function()
		selectedDevice = Pulse.Database:GetAppliedDevicePreset() or "default"
		for _, c in ipairs(devCards) do
			c.refresh()
		end
		refreshLanguage()
	end

	return sf
end

-- ── Step 2: Combat Haptics (Offensive + Defensive) & Class / Role ───────────

local function buildStep2(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -8)
	title:SetText(L("Step 2: Combat Haptics & Class Role"))
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(L("Choose your planned class & role, and configure offensive and defensive combat feedback."))
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	-- 1. Class & Role Selector Card
	local roleCard = createCard(sf, 634, 108)
	roleCard:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -50)

	local roleTitle = roleCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	roleTitle:SetPoint("TOPLEFT", roleCard, "TOPLEFT", 12, -8)
	roleTitle:SetText(L("1. Planned Class & Combat Role"))
	roleTitle:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	-- Assigned once the Offensive/Defensive cards below exist; class and role clicks change
	-- cues those two checkboxes summarise.
	local refreshCombatChecks = function() end

	-- Class selection buttons (2 rows of 5)
	local classButtons = {}
	local classW = 118
	local classH = 20

	for idx, cInfo in ipairs(CLASS_LIST) do
		local col = (idx - 1) % 5
		local row = math.floor((idx - 1) / 5)
		local x = 12 + col * (classW + 6)
		local y = -30 - row * (classH + 4)

		local btn = CreateFrame("Button", nil, roleCard)
		btn:SetSize(classW, classH)
		btn:SetPoint("TOPLEFT", roleCard, "TOPLEFT", x, y)

		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(btn)
		bg:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.9)
		btn.bg = bg

		local border = btn:CreateTexture(nil, "BORDER")
		border:SetAllPoints(btn)
		border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.8)
		btn.border = border

		local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("CENTER", btn, "CENTER", 0, 0)
		text:SetText(cInfo.label)
		btn.text = text

		local function refreshClassBtn()
			if selectedClass == cInfo.id then
				border:SetColorTexture(cInfo.color.r, cInfo.color.g, cInfo.color.b, 1)
				text:SetTextColor(cInfo.color.r, cInfo.color.g, cInfo.color.b)
			else
				border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.6)
				text:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)
			end
		end

		btn:SetScript("OnClick", function()
			selectedClass = cInfo.id
			for _, b in ipairs(classButtons) do
				b.refresh()
			end
			applyClassAndRole()
			refreshCombatChecks()
			testMode("TICK", 0.6, true)
		end)

		btn.refresh = refreshClassBtn
		classButtons[#classButtons + 1] = btn
		refreshClassBtn()
	end

	-- Role selection buttons (1 row of 4)
	local roleButtons = {}
	local roleW = 149
	local roleH = 24
	local roleY = -78

	for idx, rInfo in ipairs(ROLE_LIST) do
		local x = 12 + (idx - 1) * (roleW + 8)
		local btn = CreateFrame("Button", nil, roleCard)
		btn:SetSize(roleW, roleH)
		btn:SetPoint("TOPLEFT", roleCard, "TOPLEFT", x, roleY)

		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(btn)
		bg:SetColorTexture(THEME.surface.r, THEME.surface.g, THEME.surface.b, 0.9)
		btn.bg = bg

		local border = btn:CreateTexture(nil, "BORDER")
		border:SetAllPoints(btn)
		border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.8)
		btn.border = border

		local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("CENTER", btn, "CENTER", 0, 0)
		text:SetText(rInfo.label)
		btn.text = text

		local function refreshRoleBtn()
			if selectedRole == rInfo.id then
				border:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1)
				text:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)
			else
				border:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.6)
				text:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)
			end
		end

		btn:SetScript("OnClick", function()
			selectedRole = rInfo.id
			applyClassAndRole()
			refreshCombatChecks()
			for _, b in ipairs(roleButtons) do
				b.refresh()
			end
			testMode("TAP", 0.7, true)
		end)

		btn.refresh = refreshRoleBtn
		roleButtons[#roleButtons + 1] = btn
		refreshRoleBtn()
	end

	-- 2. Offensive Combat Card
	local offCard = createCard(sf, 634, 94)
	offCard:SetPoint("TOPLEFT", roleCard, "BOTTOMLEFT", 0, -8)

	local cbOff = createCheckbox(offCard, 22)
	cbOff:SetPoint("TOPLEFT", offCard, "TOPLEFT", 12, -12)

	local lblOff = offCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblOff:SetPoint("LEFT", cbOff, "RIGHT", 10, 0)
	lblOff:SetText(L("Offensive Combat Haptics"))

	local descOff = offCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	descOff:SetPoint("TOPLEFT", cbOff, "BOTTOMLEFT", 4, -6)
	descOff:SetPoint("RIGHT", offCard, "RIGHT", -110, 0)
	descOff:SetJustifyH("LEFT")
	descOff:SetText(
		L("Physical strikes for weapon swings (main & off hand), auto-shot arrows, ability execution cadence, and completed and instant spellcasts.")
	)
	descOff:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local btnTestOff = createButton(offCard, L("Test Strike"), 90, 24, false)
	btnTestOff:SetPoint("TOPRIGHT", offCard, "TOPRIGHT", -12, -12)
	btnTestOff:SetScript("OnClick", function()
		testMode("IMPACT", 0.75)
	end)

	local OFF_CUES = {
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
	}

	local function isOffActive()
		for _, id in ipairs(OFF_CUES) do
			if Pulse.Database:GetCue(id) then
				return true
			end
		end
		return false
	end

	cbOff:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		for _, id in ipairs(OFF_CUES) do
			setCue(id, val)
		end
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
	end)

	-- 3. Defensive Combat Card
	local defCard = createCard(sf, 634, 94)
	defCard:SetPoint("TOPLEFT", offCard, "BOTTOMLEFT", 0, -8)

	local cbDef = createCheckbox(defCard, 22)
	cbDef:SetPoint("TOPLEFT", defCard, "TOPLEFT", 12, -12)

	local lblDef = defCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblDef:SetPoint("LEFT", cbDef, "RIGHT", 10, 0)
	lblDef:SetText(L("Defensive Combat & Threat Feedback"))

	local descDef = defCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	descDef:SetPoint("TOPLEFT", cbDef, "BOTTOMLEFT", 4, -6)
	descDef:SetPoint("RIGHT", defCard, "RIGHT", -110, 0)
	descDef:SetJustifyH("LEFT")
	descDef:SetText(
		L("Sensory radar for survival: immediate physical warnings when taking damage, getting critically hit, deflecting attacks, being healed, receiving debuffs, threat changes, or losing control.")
	)
	descDef:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local btnTestDef = createButton(defCard, L("Test Impact"), 90, 24, false)
	btnTestDef:SetPoint("TOPRIGHT", defCard, "TOPRIGHT", -12, -12)
	btnTestDef:SetScript("OnClick", function()
		-- THUD is critLanded's own mode: the hit this card is about.
		testMode("THUD", 0.75)
	end)

	local DEF_CUES = {
		"critLanded",
		"damageTaken",
		"deflect",
		"healCrit",
		"healReceived",
		"debuffReceived",
		"threatRising",
		"threatAggro",
		"threatLost",
		"ccMaster",
	}

	local function isDefActive()
		for _, id in ipairs(DEF_CUES) do
			if Pulse.Database:GetCue(id) then
				return true
			end
		end
		return false
	end

	cbDef:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		for _, id in ipairs(DEF_CUES) do
			setCue(id, val)
		end
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
	end)

	refreshCombatChecks = function()
		cbOff:SetChecked(isOffActive())
		cbDef:SetChecked(isDefActive())
	end

	sf.OnShowStep = function()
		if not selectedClass then
			local pClass
			if type(UnitClass) == "function" then
				local _, cls = UnitClass("player")
				pClass = cls
			end
			selectedClass = pClass or "WARRIOR"
		end
		for _, b in ipairs(classButtons) do
			b.refresh()
		end
		for _, b in ipairs(roleButtons) do
			b.refresh()
		end
		refreshCombatChecks()
	end

	local navTargets = {}
	for _, b in ipairs(classButtons) do
		navTargets[#navTargets + 1] = {
			widget = b,
			OnActivate = function()
				b:Click()
			end,
		}
	end
	for _, b in ipairs(roleButtons) do
		navTargets[#navTargets + 1] = {
			widget = b,
			OnActivate = function()
				b:Click()
			end,
		}
	end
	navTargets[#navTargets + 1] = {
		widget = cbOff,
		OnActivate = function()
			cbOff:Click()
		end,
	}
	navTargets[#navTargets + 1] = {
		widget = btnTestOff,
		OnActivate = function()
			btnTestOff:Click()
		end,
	}
	navTargets[#navTargets + 1] = {
		widget = cbDef,
		OnActivate = function()
			cbDef:Click()
		end,
	}
	navTargets[#navTargets + 1] = {
		widget = btnTestDef,
		OnActivate = function()
			btnTestDef:Click()
		end,
	}
	sf.navTargets = navTargets

	return sf
end

-- ── Step 3: World & Discovery + Target & Crosshair ───────────────────────────

local function buildStep3(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText(L("Step 3: World & Target Interactions"))
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(L("Configure tactile rewards for exploring Azeroth and sensory spatial awareness for targeting."))
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	-- 1. World & Discovery Card
	local worldCard = createCard(sf, 634, 142)
	worldCard:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -56)

	local cbWorld = createCheckbox(worldCard, 22)
	cbWorld:SetPoint("TOPLEFT", worldCard, "TOPLEFT", 12, -12)

	local lblWorld = worldCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblWorld:SetPoint("LEFT", cbWorld, "RIGHT", 10, 0)
	lblWorld:SetText(L("World & Discovery Haptics"))

	local descWorld = worldCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	descWorld:SetPoint("TOPLEFT", cbWorld, "BOTTOMLEFT", 4, -8)
	descWorld:SetPoint("RIGHT", worldCard, "RIGHT", -110, 0)
	descWorld:SetJustifyH("LEFT")
	descWorld:SetSpacing(3)
	descWorld:SetText(
		L("Tactile sensations for living in the world of Azeroth:\n• |cffffffffLoot Drops & Currency:|r Feel items and gold collected into your bags.\n• |cffffffffQuests & Turn-ins:|r Physical confirmation upon accepting and completing objectives.\n• |cffffffffProgression:|r Rewarding celebration pulses for leveling up, achievements, and XP gains.")
	)
	descWorld:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local btnTestWorld = createButton(worldCard, L("Test Reward"), 90, 24, false)
	btnTestWorld:SetPoint("TOPRIGHT", worldCard, "TOPRIGHT", -12, -12)
	btnTestWorld:SetScript("OnClick", function()
		testMode("CHIME", 0.75)
	end)

	local WORLD_CUES = { "lootReceived", "questComplete", "questAccepted", "levelUp", "achievement", "xpGained" }

	local function isWorldActive()
		if not Pulse.Database:GetCue("gateWorld") then
			return false
		end
		for _, id in ipairs(WORLD_CUES) do
			if Pulse.Database:GetCue(id) then
				return true
			end
		end
		return false
	end

	cbWorld:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		setCue("gateWorld", val)
		for _, id in ipairs(WORLD_CUES) do
			setCue(id, val)
		end
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
	end)

	-- 2. Target & Crosshair Card
	local targetCard = createCard(sf, 634, 142)
	targetCard:SetPoint("TOPLEFT", worldCard, "BOTTOMLEFT", 0, -10)

	local cbTarget = createCheckbox(targetCard, 22)
	cbTarget:SetPoint("TOPLEFT", targetCard, "TOPLEFT", 12, -12)

	local lblTarget = targetCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblTarget:SetPoint("LEFT", cbTarget, "RIGHT", 10, 0)
	lblTarget:SetText(L("Target & Crosshair Feedback"))

	local descTarget = targetCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	descTarget:SetPoint("TOPLEFT", cbTarget, "BOTTOMLEFT", 4, -8)
	descTarget:SetPoint("RIGHT", targetCard, "RIGHT", -110, 0)
	descTarget:SetJustifyH("LEFT")
	descTarget:SetSpacing(3)
	descTarget:SetText(
		L("Sensory spatial awareness when aiming and selecting units:\n• |cffffffffTarget Lock & Switch:|r Distinct click when acquiring a new target or cycling units.\n• |cffffffffFocus Target:|r Physical confirmation when assigning or swapping your focus target.\n• |cffffffffSoft Interaction:|r Tactile blip when your controller reticle aligns with an interactable NPC.")
	)
	descTarget:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local btnTestTarget = createButton(targetCard, L("Test Lock"), 90, 24, false)
	btnTestTarget:SetPoint("TOPRIGHT", targetCard, "TOPRIGHT", -12, -12)
	btnTestTarget:SetScript("OnClick", function()
		testMode("DEFLECT", 0.75)
	end)

	local TARGET_CUES = { "targetChanged", "focusChanged", "softTargetInteraction" }

	local function isTargetActive()
		if not Pulse.Database:GetCue("gateTarget") then
			return false
		end
		for _, id in ipairs(TARGET_CUES) do
			if Pulse.Database:GetCue(id) then
				return true
			end
		end
		return false
	end

	cbTarget:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		setCue("gateTarget", val)
		setCue("gateInteract", val)
		for _, id in ipairs(TARGET_CUES) do
			setCue(id, val)
		end
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
	end)

	local navTargets = {
		{
			widget = cbWorld,
			OnActivate = function()
				cbWorld:Click()
			end,
		},
		{
			widget = btnTestWorld,
			OnActivate = function()
				btnTestWorld:Click()
			end,
		},
		{
			widget = cbTarget,
			OnActivate = function()
				cbTarget:Click()
			end,
		},
		{
			widget = btnTestTarget,
			OnActivate = function()
				btnTestTarget:Click()
			end,
		},
	}
	sf.navTargets = navTargets

	sf.OnShowStep = function()
		cbWorld:SetChecked(isWorldActive())
		cbTarget:SetChecked(isTargetActive())
	end

	return sf
end

-- ── Step 4: Controller UI & Windows + Social & Group Readiness ──────────────

local function buildStep4(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText(L("Step 4: Interface & Social Alerts"))
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(L("Choose whether gamepad menu navigation and group communication produce controller vibration."))
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	-- 1. Controller UI Card
	local uiCard = createCard(sf, 634, 142)
	uiCard:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -56)

	local cbUI = createCheckbox(uiCard, 22)
	cbUI:SetPoint("TOPLEFT", uiCard, "TOPLEFT", 12, -12)

	local lblUI = uiCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblUI:SetPoint("LEFT", cbUI, "RIGHT", 10, 0)
	lblUI:SetText(L("Controller UI & Window Feedback"))

	local descUI = uiCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	descUI:SetPoint("TOPLEFT", cbUI, "BOTTOMLEFT", 4, -8)
	descUI:SetPoint("RIGHT", uiCard, "RIGHT", -110, 0)
	descUI:SetJustifyH("LEFT")
	descUI:SetSpacing(3)
	descUI:SetText(
		L("Brings Blizzard's native gamepad interface alive under your thumbs:\n• |cffffffffRadial & Menus:|r Soft tactile micro-taps as your stick moves across buttons and tabs.\n• |cffffffffWindows:|r Physical confirmation when opening bags, merchant shops, banks, and mail.\n• |cffffffffDialogs & Prompts:|r Tactile prompt when NPC interaction windows or quest frames appear.")
	)
	descUI:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local btnTestUI = createButton(uiCard, L("Test UI"), 90, 24, false)
	btnTestUI:SetPoint("TOPRIGHT", uiCard, "TOPRIGHT", -12, -12)
	btnTestUI:SetScript("OnClick", function()
		testMode("TAP", 0.75)
	end)

	local UI_CUES = { "uiInfoMessage", "merchantShow", "bankOpened" }

	local function isUIActive()
		if not Pulse.Database:GetCue("controllerUIMaster") then
			return false
		end
		for _, id in ipairs(UI_CUES) do
			if Pulse.Database:GetCue(id) then
				return true
			end
		end
		return false
	end

	cbUI:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		setCue("controllerUIMaster", val)
		setCue("gateInterface", val)
		for _, id in ipairs(UI_CUES) do
			setCue(id, val)
		end
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
	end)

	-- 2. Social & Group Card
	local socialCard = createCard(sf, 634, 142)
	socialCard:SetPoint("TOPLEFT", uiCard, "BOTTOMLEFT", 0, -10)

	local cbSocial = createCheckbox(socialCard, 22)
	cbSocial:SetPoint("TOPLEFT", socialCard, "TOPLEFT", 12, -12)

	local lblSocial = socialCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblSocial:SetPoint("LEFT", cbSocial, "RIGHT", 10, 0)
	lblSocial:SetText(L("Social & Group Communication"))

	local descSocial = socialCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	descSocial:SetPoint("TOPLEFT", cbSocial, "BOTTOMLEFT", 4, -8)
	descSocial:SetPoint("RIGHT", socialCard, "RIGHT", -110, 0)
	descSocial:SetJustifyH("LEFT")
	descSocial:SetSpacing(3)
	descSocial:SetText(
		L("Never miss an important group alert, even while looking away:\n• |cffffffffDirect Whispers:|r Distinct personal communication blip on incoming whispers.\n• |cffffffffParty & Raid Invites:|r Dual-pulse notification when receiving group invitations.\n• |cffffffffQueue Pops & Ready Checks:|r High-priority attention-grabbing pulse when instances are ready.")
	)
	descSocial:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	local btnTestSocial = createButton(socialCard, L("Test Alert"), 90, 24, false)
	btnTestSocial:SetPoint("TOPRIGHT", socialCard, "TOPRIGHT", -12, -12)
	btnTestSocial:SetScript("OnClick", function()
		-- DOUBLE_TAP is readyCheck's own mode.
		testMode("DOUBLE_TAP", 0.75)
	end)

	local SOCIAL_CUES = { "whisper", "partyInvite", "readyCheck", "queuePop" }

	local function isSocialActive()
		if not Pulse.Database:GetCue("gateSocial") then
			return false
		end
		for _, id in ipairs(SOCIAL_CUES) do
			if Pulse.Database:GetCue(id) then
				return true
			end
		end
		return false
	end

	cbSocial:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		setCue("gateSocial", val)
		for _, id in ipairs(SOCIAL_CUES) do
			setCue(id, val)
		end
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
	end)

	local navTargets = {
		{
			widget = cbUI,
			OnActivate = function()
				cbUI:Click()
			end,
		},
		{
			widget = btnTestUI,
			OnActivate = function()
				btnTestUI:Click()
			end,
		},
		{
			widget = cbSocial,
			OnActivate = function()
				cbSocial:Click()
			end,
		},
		{
			widget = btnTestSocial,
			OnActivate = function()
				btnTestSocial:Click()
			end,
		},
	}
	sf.navTargets = navTargets

	sf.OnShowStep = function()
		cbUI:SetChecked(isUIActive())
		cbSocial:SetChecked(isSocialActive())
	end

	return sf
end

-- ── Step 5: Immersion & Continuous Textures ────────

local function buildStep5(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -8)
	title:SetText(L("Step 5: Immersion & Continuous Textures"))
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(
		L("New setups enable casting, crafting, low-health and breath effects. Other effects start off; your saved choices are kept.")
	)
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	-- Master continuous banner
	local masterCard = createCard(sf, 634, 34)
	masterCard:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -64) -- room for a two-line translated intro

	local cbMaster = createCheckbox(masterCard, 20)
	cbMaster:SetPoint("LEFT", masterCard, "LEFT", 10, 0)

	local lblMaster = masterCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lblMaster:SetPoint("LEFT", cbMaster, "RIGHT", 8, 0)
	lblMaster:SetText(L("Enable Continuous Immersion Haptics (Master)"))

	local subMaster = masterCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	subMaster:SetPoint("LEFT", lblMaster, "RIGHT", 12, 0)
	subMaster:SetText(L("(Toggles all continuous sensations)"))
	subMaster:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)
	-- 634 card - 10 inset - 20 checkbox - 8 gap - label - 12 gap - 10 inset
	fitLine(subMaster, math.max(60, 572 - math.ceil(lblMaster:GetStringWidth() or 0)))

	local itemCards = {}
	local startY = -104
	local cardW = 310
	local cardH = 51 -- name plus two description lines; longer text moves to the tooltip

	for idx, opt in ipairs(CONTINUOUS_OPTIONS) do
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local x = col * (cardW + 14) + 6
		local y = startY - row * (cardH + 4)

		local card = createCard(sf, cardW, cardH)
		card:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

		local cb = createCheckbox(card, 20)
		cb:SetPoint("LEFT", card, "LEFT", 8, 0)

		local lbl = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		lbl:SetPoint("TOPLEFT", cb, "TOPRIGHT", 8, -2)
		lbl:SetPoint("RIGHT", card, "RIGHT", -66, 0)
		lbl:SetJustifyH("LEFT")
		lbl:SetText(opt.label)

		local sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		sub:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
		sub:SetPoint("RIGHT", card, "RIGHT", -66, 0)
		sub:SetJustifyH("LEFT")
		sub:SetText(opt.desc)
		sub:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)
		if sub.SetMaxLines then
			sub:SetMaxLines(2)
		end
		card:EnableMouse(true)
		card:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(opt.label)
			GameTooltip:AddLine(opt.desc, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		card:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		local btnPreview = createButton(card, L("Feel"), 56, 20, false)
		btnPreview:SetPoint("RIGHT", card, "RIGHT", -6, 0)
		-- Text ends at the button, whatever width its translated label needs.
		lbl:SetPoint("RIGHT", btnPreview, "LEFT", -6, 0)
		sub:SetPoint("RIGHT", btnPreview, "LEFT", -6, 0)
		btnPreview:SetScript("OnClick", function()
			if Pulse.TestCue then
				reportTest(Pulse:TestCue(opt.id))
			end
		end)

		cb:SetScript("OnClick", function(self)
			local val = self:GetChecked() and true or false
			if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
				Pulse.UI.Panel.Theme.PlayCheckSound(val)
			end
			setCue(opt.id, val)
		end)

		card.refresh = function()
			cb:SetChecked(Pulse.Database:GetCue(opt.id))
		end

		card.cb = cb
		card.btnPreview = btnPreview
		itemCards[#itemCards + 1] = card
		card.refresh()
	end

	cbMaster:SetScript("OnClick", function(self)
		local val = self:GetChecked() and true or false
		if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.PlayCheckSound then
			Pulse.UI.Panel.Theme.PlayCheckSound(val)
		end
		for _, opt in ipairs(CONTINUOUS_OPTIONS) do
			setCue(opt.id, val)
		end
		for _, card in ipairs(itemCards) do
			card.refresh()
		end
	end)

	local navTargets = {}
	navTargets[#navTargets + 1] = {
		widget = cbMaster,
		OnActivate = function()
			cbMaster:Click()
		end,
	}
	for _, card in ipairs(itemCards) do
		navTargets[#navTargets + 1] = {
			widget = card.cb,
			OnActivate = function()
				card.cb:Click()
			end,
		}
		navTargets[#navTargets + 1] = {
			widget = card.btnPreview,
			OnActivate = function()
				card.btnPreview:Click()
			end,
		}
	end
	sf.navTargets = navTargets

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

-- ── Step 6: Master Strength & Completion ─────────────────────────────────────

local function buildStep6(container)
	local sf = CreateFrame("Frame", nil, container)
	sf:SetAllPoints(container)

	local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, -10)
	title:SetText(L("Step 6: Master Strength & Completion"))
	title:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local desc = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("RIGHT", sf, "RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(L("Adjust your global master vibration strength. Individual cues can always be fine-tuned in settings."))
	desc:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)

	-- Master Intensity Slider Card
	local sliderCard = createCard(sf, 634, 100)
	sliderCard:SetPoint("TOPLEFT", sf, "TOPLEFT", 6, -56)

	local sliderLabel = sliderCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	sliderLabel:SetPoint("TOPLEFT", sliderCard, "TOPLEFT", 16, -14)
	sliderLabel:SetText(L("Master Vibration Strength"))

	local valLabel = sliderCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	valLabel:SetPoint("TOPRIGHT", sliderCard, "TOPRIGHT", -16, -14)
	valLabel:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local slider = CreateFrame("Slider", nil, sliderCard, "OptionsSliderTemplate")
	slider:SetWidth(450)
	slider:SetHeight(18)
	slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -14)
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

	local btnFeel = createButton(sliderCard, L("Feel Strength"), 130, 26, false)
	btnFeel:SetPoint("LEFT", slider, "RIGHT", 16, 0)
	btnFeel:SetScript("OnClick", function()
		-- Scale 1.0: the slider already wrote masterIntensity, which the engine applies.
		testMode("HEAVY", 1.0)
	end)

	local sliderHint = sliderCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sliderHint:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -12)
	sliderHint:SetText(L("|cff38BDF8[A] Adjust Value|r  •  |cffffffff[>] Jump to Feel Button|r"))

	local isSliderAdjusting = false
	local function updateSliderHint()
		if isSliderAdjusting then
			sliderHint:SetText(
				(L("|cff00ff00[Adjusting %d%%]|r Use |cffffffff[< / >]|r to Change, |cff38BDF8[A]|r Confirm & Feel")):format(
					slider:GetValue() or 70
				)
			)
			if quickFocusBox and quickFocusBox.bTop then
				quickFocusBox.bTop:SetColorTexture(1.0, 0.85, 0.2, 1.0)
				quickFocusBox.bBottom:SetColorTexture(1.0, 0.85, 0.2, 1.0)
				quickFocusBox.bLeft:SetColorTexture(1.0, 0.85, 0.2, 1.0)
				quickFocusBox.bRight:SetColorTexture(1.0, 0.85, 0.2, 1.0)
				quickFocusBox.accent:SetColorTexture(1.0, 0.85, 0.2, 1.0)
			end
		else
			sliderHint:SetText(L("|cff38BDF8[A] Adjust Value|r  •  |cffffffff[>] Jump to Feel Button|r"))
			if quickFocusBox and quickFocusBox.bTop then
				quickFocusBox.bTop:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
				quickFocusBox.bBottom:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
				quickFocusBox.bLeft:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
				quickFocusBox.bRight:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
				quickFocusBox.accent:SetColorTexture(THEME.accent.r, THEME.accent.g, THEME.accent.b, 1.0)
			end
		end
	end

	local function updateSliderVal(val)
		valLabel:SetText(("%d%%"):format(math.floor(val + 0.5)))
		Pulse.Database:Set("masterIntensity", val / 100)
		if isSliderAdjusting then
			updateSliderHint()
		end
	end

	slider:SetScript("OnValueChanged", function(self, value)
		updateSliderVal(value)
	end)

	-- Info Summary Card
	local summaryCard = createCard(sf, 634, 190)
	summaryCard:SetPoint("TOPLEFT", sliderCard, "BOTTOMLEFT", 0, -12)

	local summaryTitle = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	summaryTitle:SetPoint("TOPLEFT", summaryCard, "TOPLEFT", 16, -16)
	summaryTitle:SetText(L("Setup Summary"))
	summaryTitle:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)

	local summaryText = summaryCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	summaryText:SetPoint("TOPLEFT", summaryTitle, "BOTTOMLEFT", 0, -8)
	summaryText:SetPoint("RIGHT", summaryCard, "RIGHT", -16, 0)
	summaryText:SetJustifyH("LEFT")
	summaryText:SetSpacing(4)
	summaryCard.summaryText = summaryText

	local function refreshSummary()
		local presetID = Pulse.Database:GetAppliedDevicePreset() or "default"
		local devName = L("Generic / Unknown")
		for _, opt in ipairs(CONTROLLER_OPTIONS) do
			if opt.id == presetID then
				devName = opt.label
				break
			end
		end

		local className = selectedClass or "Default"
		for _, c in ipairs(CLASS_LIST) do
			if c.id == selectedClass then
				className = c.label
				break
			end
		end

		local roleName = L("no role chosen")
		for _, r in ipairs(ROLE_LIST) do
			if r.id == selectedRole then
				roleName = r.label
				break
			end
		end

		local curInt = math.floor((Pulse.Database:Get("masterIntensity") or 0.70) * 100 + 0.5)

		local contCount = 0
		for _, opt in ipairs(CONTINUOUS_OPTIONS) do
			if Pulse.Database:GetCue(opt.id) then
				contCount = contCount + 1
			end
		end

		summaryText:SetText(
			(
				L("• Selected Controller Hardware: |cffffffff%s|r\n• Character Class & Planned Role: |cffffffff%s (%s)|r\n• Active Continuous Textures: |cffffffff%d active|r\n• Master Haptic Strength: |cffffffff%d%%|r\n\nAll preferences are saved directly to your active profile.\nYou can re-run this setup anytime by typing |cff4cb8ff/pulse setup|r.")
			):format(devName, className, roleName, contCount, curInt)
		)
	end

	sf.OnShowStep = function()
		local curInt = math.floor((Pulse.Database:Get("masterIntensity") or 0.70) * 100 + 0.5)
		slider:SetValue(curInt)
		updateSliderVal(curInt)
		isSliderAdjusting = false
		updateSliderHint()
		refreshSummary()
	end

	local navTargets = {
		{
			widget = slider,
			isSlider = true,
			IsAdjusting = function()
				return isSliderAdjusting
			end,
			SetAdjusting = function(adj)
				isSliderAdjusting = adj
				updateSliderHint()
			end,
			OnStep = function(delta)
				local cur = slider:GetValue() or 70
				local nextVal = math.max(10, math.min(100, cur + delta * 5))
				slider:SetValue(nextVal)
				testMode("TAP", 1.0, true)
			end,
			OnActivate = function()
				isSliderAdjusting = not isSliderAdjusting
				updateSliderHint()
				if not isSliderAdjusting then
					testMode("HEAVY", 1.0)
				end
			end,
		},
		{
			widget = btnFeel,
			OnActivate = function()
				btnFeel:Click()
			end,
		},
	}
	sf.navTargets = navTargets

	return sf
end

-- ── Window Frame & Navigation ────────────────────────────────────────────────

local function createWindow()
	local created
	for _, template in ipairs({ "SettingsFrameTemplate", "ButtonFrameTemplate" }) do
		local ok, result = pcall(CreateFrame, "Frame", FRAME_NAME, UIParent, template)
		if ok and result then
			created = result
			break
		end
	end
	if not created then
		created = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
	end
	return created
end

local function buildWindow()
	if frame then
		return frame
	end

	local f = createWindow()
	f:Hide() -- install lifecycle hooks before its first Show
	f:SetSize(676, 550)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)

	tinsert(UISpecialFrames, FRAME_NAME)

	-- Title on Blizzard nine-slice frame
	local titleText = f.NineSlice and f.NineSlice.Text
	if not titleText then
		titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		titleText:SetPoint("TOP", f, "TOP", 0, -5)
	end
	titleText:SetText(L("PULSE QUICK SETUP"))
	if titleText.SetTextColor then
		titleText:SetTextColor(THEME.accent.r, THEME.accent.g, THEME.accent.b)
	end

	local titleIcon = f:CreateTexture(nil, "OVERLAY")
	titleIcon:SetSize(18, 18)
	titleIcon:SetTexture("Interface\\AddOns\\PulseHaptics\\Media\\icon")
	titleIcon:SetPoint("RIGHT", titleText, "LEFT", -6, 0)
	f.TitleIcon = titleIcon

	-- Fix frame level of template background
	if f.Bg and f.Bg.SetFrameLevel then
		f.Bg:SetFrameLevel(f:GetFrameLevel())
	end

	-- Opaque dark fill behind content
	local fill = f:CreateTexture(nil, "BACKGROUND")
	fill:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
	fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
	fill:SetColorTexture(THEME.bg.r, THEME.bg.g, THEME.bg.b, 1)

	-- Atmospheric watermark of the ripple artwork
	local watermark = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	watermark:SetTexture("Interface\\AddOns\\PulseHaptics\\Media\\SettingsBG")
	watermark:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -40)
	watermark:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
	watermark:SetAlpha(0.06)

	-- Inner recessed frame behind content
	local inner = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	local okAtlas = pcall(inner.SetAtlas, inner, "Options_InnerFrame", true)
	if okAtlas then
		inner:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -54)
		inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 46)
	end

	-- Close button from SettingsFrameTemplate, or create if absent
	if not f.ClosePanelButton then
		local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
		if ok and close then
			f.ClosePanelButton = close
		end
	end
	if f.ClosePanelButton then
		f.ClosePanelButton:SetScript("OnClick", function()
			QuickSetup.Close()
		end)
	end

	-- Step breadcrumb tabs (6 tabs across 640px)
	local stepBar = CreateFrame("Frame", nil, f)
	stepBar:SetHeight(24)
	stepBar:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -28)
	stepBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -28)

	local l1Btn = CreateFrame("Button", nil, stepBar)
	l1Btn:SetSize(62, 22)
	l1Btn:SetPoint("LEFT", stepBar, "LEFT", 0, 0)
	tabIndicatorL1 = l1Btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tabIndicatorL1:SetAllPoints(l1Btn)
	tabIndicatorL1:SetJustifyH("LEFT")
	tabIndicatorL1:SetText(L("|cff38BDF8[L1 / LB]|r"))
	l1Btn:SetScript("OnClick", function()
		if currentStep > 1 then
			currentStep = currentStep - 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end
	end)

	local r1Btn = CreateFrame("Button", nil, stepBar)
	r1Btn:SetSize(62, 22)
	r1Btn:SetPoint("RIGHT", stepBar, "RIGHT", 0, 0)
	tabIndicatorR1 = r1Btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tabIndicatorR1:SetAllPoints(r1Btn)
	tabIndicatorR1:SetJustifyH("RIGHT")
	tabIndicatorR1:SetText(L("|cff38BDF8[R1 / RB]|r"))
	r1Btn:SetScript("OnClick", function()
		if currentStep < TOTAL_STEPS then
			currentStep = currentStep + 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end
	end)

	local stepLabels = {
		L("1. Controller"),
		L("2. Combat"),
		L("3. World"),
		L("4. Interface"),
		L("5. Immersion"),
		L("6. Finish"),
	}
	local tabW = 80
	local startX = 70
	for i = 1, TOTAL_STEPS do
		local tabBtn = CreateFrame("Button", nil, stepBar)
		tabBtn:SetSize(tabW, 22)
		tabBtn:SetPoint("LEFT", stepBar, "LEFT", startX + (i - 1) * (tabW + 4), 0)
		local tab = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		tab:SetAllPoints(tabBtn)
		tab:SetJustifyH("CENTER")
		tab:SetText(stepLabels[i])
		tabBtn:SetScript("OnClick", function()
			currentStep = i
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end)
		stepIndicators[i] = tab
	end

	-- Content Container
	local container = CreateFrame("Frame", nil, f)
	container:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -58)
	container:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 48)

	stepFrames[1] = buildStep1(container)
	stepFrames[2] = buildStep2(container)
	stepFrames[3] = buildStep3(container)
	stepFrames[4] = buildStep4(container)
	stepFrames[5] = buildStep5(container)
	stepFrames[6] = buildStep6(container)

	-- Bottom Action Bar
	local bottomBar = CreateFrame("Frame", nil, f)
	bottomBar:SetHeight(40)
	bottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 8)
	bottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 8)

	local bottomRule = bottomBar:CreateTexture(nil, "ARTWORK")
	bottomRule:SetHeight(1)
	bottomRule:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 0, 0)
	bottomRule:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", 0, 0)
	bottomRule:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.4)

	btnBack = createButton(bottomBar, L("< Back"), 100, 26, false)
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

	navLegend = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	navLegend:SetPoint("LEFT", bottomBar, "LEFT", 112, 0)
	navLegend:SetTextColor(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b)
	navLegend:SetText(L("|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[D-Pad]|r Navigate  •  |cff38BDF8[A]|r Select"))

	btnNext = createButton(bottomBar, L("Next >"), 110, 26, true)
	btnNext:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
	btnNext:SetScript("OnClick", function()
		if currentStep < TOTAL_STEPS then
			currentStep = currentStep + 1
			if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
				stepFrames[currentStep].OnShowStep()
			end
			updateStepView()
		end
	end)

	btnFinish = createButton(bottomBar, L("Save & Start Playing"), 160, 26, true)
	btnFinish:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
	btnFinish:SetScript("OnClick", function()
		Pulse.Database:SetQuickSetupCompleted(true)
		-- SURGE is levelUp's own mode.
		testMode("SURGE", 0.75, true)
		QuickSetup.Close()
		print(L("|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings."))
	end)

	btnAdvanced = createButton(bottomBar, L("Advanced Settings"), 140, 26, false)
	btnAdvanced:SetPoint("RIGHT", btnFinish, "LEFT", -10, 0)
	btnAdvanced:SetScript("OnClick", function()
		Pulse.Database:SetQuickSetupCompleted(true)
		QuickSetup.Close()
		if Pulse.UI.Panel and Pulse.UI.Panel.Open then
			Pulse.UI.Panel.Open()
		end
	end)

	if stepFrames[6] and stepFrames[6].navTargets then
		table.insert(stepFrames[6].navTargets, {
			widget = btnAdvanced,
			OnActivate = function()
				btnAdvanced:Click()
			end,
		})
		table.insert(stepFrames[6].navTargets, {
			widget = btnFinish,
			OnActivate = function()
				btnFinish:Click()
			end,
		})
	end

	if f.EnableGamePadButton then
		pcall(f.EnableGamePadButton, f, true)
	end
	f:SetScript("OnGamePadButtonDown", function(_, key)
		onQuickGamepadInput(key)
	end)

	f:HookScript("OnShow", function()
		releaseQuickCaptureKeys(f)
		if f.EnableGamePadButton then
			f:EnableGamePadButton(true)
		end
		local targets = stepFrames[currentStep] and stepFrames[currentStep].navTargets or {}
		if #targets > 0 then
			setQuickFocus(targets[1])
		end
	end)

	f:HookScript("OnHide", function()
		releaseQuickCaptureKeys(f)
		if f.EnableGamePadButton then
			f:EnableGamePadButton(false)
		end
		if Pulse.CancelContinuousPreview then
			Pulse:CancelContinuousPreview()
		end
		if quickFocusBox then
			quickFocusBox:Hide()
		end
	end)

	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			QuickSetup.Close()
		elseif event == "PLAYER_REGEN_ENABLED" and pendingCaptureCleanup then
			releaseQuickCaptureKeys(pendingCaptureCleanup)
		end
	end)

	frame = f
	return f
end

-- ── Public API ────────────────────────────────────────────────────────────────

function QuickSetup.Open(initialStep)
	if InCombatLockdown and InCombatLockdown() then
		print(L("|cffff5555Pulse:|r Cannot open Quick Setup during combat."))
		return
	end

	if Pulse.UI and Pulse.UI.Panel and Pulse.UI.Panel.Close then
		Pulse.UI.Panel.Close()
	end

	applyInitialContinuousDefaults()
	buildWindow()
	currentStep = initialStep or 1
	if stepFrames[currentStep] and stepFrames[currentStep].OnShowStep then
		stepFrames[currentStep].OnShowStep()
	end
	updateStepView()
	frame:Show()
end

function QuickSetup.Close()
	if frame then
		frame:Hide() -- OnHide owns all exit-path cleanup, including Escape.
	end
end

function QuickSetup.Toggle()
	if frame and frame:IsShown() then
		QuickSetup.Close()
	else
		QuickSetup.Open()
	end
end

-- A language change reloads the UI; reopen the wizard on its language step afterwards.
function QuickSetup.ResumeAfterReload()
	if not Pulse.Database:Get("quickSetupResumePending") then
		return false
	end
	Pulse.Database:Set("quickSetupResumePending", false)
	QuickSetup.Open(1)
	return true
end

local resumeWatcher = CreateFrame("Frame")
resumeWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
resumeWatcher:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	C_Timer.After(1, QuickSetup.ResumeAfterReload)
end)

-- Keep authored IDs and saved values unchanged; translate display metadata at login.
if Pulse.Locale then
	Pulse.Locale:RegisterTable(CONTROLLER_OPTIONS)
	Pulse.Locale:RegisterTable(CLASS_LIST)
	Pulse.Locale:RegisterTable(ROLE_LIST)
	Pulse.Locale:RegisterTable(CONTINUOUS_OPTIONS)
end
