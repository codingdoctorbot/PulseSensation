-- PulseProbe — UI.lua
--
-- Movable diagnostic dashboard, live telemetry feed, and one-click simulation lab.
-- Designed to make testing experimental cues as effortless as possible.

local ADDON_NAME, Probe = ...

local UI = {}
Probe.UI = UI

local C = Probe.Colors
local currentTab = 1
local activeFilter = "All"

---------------------------------------------------------------------------
-- Main Window Frame
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "PulseProbeUIFrame", UIParent, "BackdropTemplate")
frame:SetSize(720, 520)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 24,
	insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
frame:Hide()

if UISpecialFrames then
	table.insert(UISpecialFrames, "PulseProbeUIFrame")
end

-- Title Header
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
titleText:SetText(
	C.PRIMARY .. "PulseProbe" .. C.RESET .. " |cffffffffCue Laboratory|r " .. C.MUTED .. "v" .. Probe.Version .. C.RESET
)

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

---------------------------------------------------------------------------
-- Top Control Toolbar (Sound, Haptic, Pause, Clear)
---------------------------------------------------------------------------

local soundBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
soundBtn:SetSize(90, 22)
soundBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -8, -4)

local function updateSoundBtnText()
	local enabled = Probe.DB and Probe.DB.soundEnabled
	soundBtn:SetText(enabled and (C.SUCCESS .. "Sound: ON" .. C.RESET) or (C.DANGER .. "Sound: OFF" .. C.RESET))
end
soundBtn:SetScript("OnClick", function()
	Probe.DB.soundEnabled = not Probe.DB.soundEnabled
	updateSoundBtnText()
end)

local hapticBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
hapticBtn:SetSize(96, 22)
hapticBtn:SetPoint("RIGHT", soundBtn, "LEFT", -6, 0)

local function updateHapticBtnText()
	local enabled = Probe.DB and Probe.DB.hapticsEnabled
	hapticBtn:SetText(enabled and (C.SUCCESS .. "Rumble: ON" .. C.RESET) or (C.DANGER .. "Rumble: OFF" .. C.RESET))
end
hapticBtn:SetScript("OnClick", function()
	Probe.DB.hapticsEnabled = not Probe.DB.hapticsEnabled
	updateHapticBtnText()
end)

local pauseBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
pauseBtn:SetSize(80, 22)
pauseBtn:SetPoint("RIGHT", hapticBtn, "LEFT", -6, 0)

local function updatePauseBtnText()
	pauseBtn:SetText(Probe.IsPaused and (C.WARNING .. "Paused" .. C.RESET) or (C.SUCCESS .. "Live" .. C.RESET))
end
pauseBtn:SetScript("OnClick", function()
	Probe.IsPaused = not Probe.IsPaused
	updatePauseBtnText()
end)

local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
clearBtn:SetSize(60, 22)
clearBtn:SetPoint("RIGHT", pauseBtn, "LEFT", -6, 0)
clearBtn:SetText("Clear")
clearBtn:SetScript("OnClick", function()
	Probe:ClearLogs()
end)

---------------------------------------------------------------------------
-- Tab Navigation Buttons
---------------------------------------------------------------------------

local tabs = {}
local tabNames = { "Live Feed", "Simulation Lab", "Environment & Status" }
local tabFrames = {}

local function selectTab(tabIdx)
	currentTab = tabIdx
	for i = 1, #tabs do
		if i == tabIdx then
			tabs[i]:SetAlpha(1.0)
			tabs[i]:LockHighlight()
			tabFrames[i]:Show()
		else
			tabs[i]:SetAlpha(0.6)
			tabs[i]:UnlockHighlight()
			tabFrames[i]:Hide()
		end
	end
	if tabIdx == 1 then
		UI:RefreshLogView()
	end
end

for i, name in ipairs(tabNames) do
	local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	tab:SetSize(130, 24)
	tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + ((i - 1) * 134), -42)
	tab:SetText(name)
	tab:SetScript("OnClick", function()
		selectTab(i)
	end)
	tabs[i] = tab

	local tabFrame = CreateFrame("Frame", nil, frame)
	tabFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -72)
	tabFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
	tabFrames[i] = tabFrame
end

---------------------------------------------------------------------------
-- TAB 1: Live Feed View
---------------------------------------------------------------------------

local feedContainer = tabFrames[1]

-- Filter Sub-Bar
local filterCategories = { "All", "Combat", "Pets", "World", "Navigation", "Economy", "Errors" }
local filterButtons = {}

local logScrollFrame =
	CreateFrame("ScrollFrame", "PulseProbeLogScrollFrame", feedContainer, "UIPanelScrollFrameTemplate")
logScrollFrame:SetPoint("TOPLEFT", feedContainer, "TOPLEFT", 0, -32)
logScrollFrame:SetPoint("BOTTOMRIGHT", feedContainer, "BOTTOMRIGHT", -24, 8)

local logText = CreateFrame("EditBox", nil, logScrollFrame)
logText:SetMultiLine(true)
logText:SetAutoFocus(false)
logText:EnableMouse(true)
logText:SetFontObject(ChatFontNormal)
logText:SetWidth(650)
logText:SetScript("OnEscapePressed", function()
	frame:Hide()
end)
logScrollFrame:SetScrollChild(logText)

for i, cat in ipairs(filterCategories) do
	local fBtn = CreateFrame("Button", nil, feedContainer, "UIPanelButtonTemplate")
	fBtn:SetSize(82, 20)
	fBtn:SetPoint("TOPLEFT", feedContainer, "TOPLEFT", (i - 1) * 86, -4)
	fBtn:SetText(cat)
	fBtn:SetScript("OnClick", function()
		activeFilter = cat
		for _, b in ipairs(filterButtons) do
			b:UnlockHighlight()
		end
		fBtn:LockHighlight()
		UI:RefreshLogView()
	end)
	filterButtons[i] = fBtn
	if i == 1 then
		fBtn:LockHighlight()
	end
end

function UI:RefreshLogView()
	if not feedContainer:IsShown() then
		return
	end

	local lines = {}
	local count = Probe.LogCount
	local head = Probe.LogHead

	if count == 0 then
		logText:SetText(C.MUTED .. "No telemetry captured yet. Waiting for combat, pet, or world events..." .. C.RESET)
		return
	end

	for i = 0, count - 1 do
		local idx = ((head - 1 - i + 100) % 100) + 1
		local entry = Probe.LogEntries[idx]
		if entry and entry.timestamp > 0 then
			if activeFilter == "All" or entry.category == activeFilter then
				local taintBadge = entry.isTainted and (C.DANGER .. "[TAINTED]" .. C.RESET)
					or (C.SUCCESS .. "[Safe]" .. C.RESET)
				local secretBadge = entry.isSecret and (C.DANGER .. "[SECRET!]" .. C.RESET)
					or (C.MUTED .. "[Public]" .. C.RESET)
				local catBadge = C.PRIMARY .. "[" .. entry.category .. "]" .. C.RESET
				local timeStr = C.MUTED .. entry.timeStr .. C.RESET

				local line = string.format(
					"%s %s %s %s: %s | %s %s",
					timeStr,
					catBadge,
					taintBadge,
					entry.eventName,
					entry.payloadStr,
					entry.mockCue ~= "" and (C.WARNING .. "-> " .. entry.mockCue .. C.RESET) or "",
					secretBadge
				)
				table.insert(lines, line)
			end
		end
	end

	if #lines == 0 then
		logText:SetText(C.MUTED .. "No entries match filter: " .. activeFilter .. C.RESET)
	else
		logText:SetText(table.concat(lines, "\n\n"))
	end
end

function UI:OnNewLogEntry(_)
	if currentTab == 1 then
		self:RefreshLogView()
	end
end

---------------------------------------------------------------------------
-- TAB 2: Simulation Lab (One-Click Candidate Cue Testing)
---------------------------------------------------------------------------

local labContainer = tabFrames[2]

local labScrollFrame =
	CreateFrame("ScrollFrame", "PulseProbeLabScrollFrame", labContainer, "UIPanelScrollFrameTemplate")
labScrollFrame:SetPoint("TOPLEFT", labContainer, "TOPLEFT", 0, 0)
labScrollFrame:SetPoint("BOTTOMRIGHT", labContainer, "BOTTOMRIGHT", -24, 0)

local labContent = CreateFrame("Frame", nil, labScrollFrame)
labContent:SetSize(660, 680)
labScrollFrame:SetScrollChild(labContent)

local function createSectionHeader(parent, yOffset, title)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
	fs:SetText(C.PRIMARY .. "● " .. title .. C.RESET)
	return fs
end

local function createSimButton(parent, x, y, label, tooltip, category, eventName, payloadStr, mockCue)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(200, 24)
	btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	btn:SetText(label)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(label, 1, 1, 1)
		GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine("Simulates cue with audio & gamepad rumble.", 0.2, 0.9, 0.2)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	btn:SetScript("OnClick", function()
		Probe:AddLogEntry(category, "[SIM] " .. eventName, payloadStr, false, false, mockCue)
	end)

	return btn
end

-- Section: Combat Procs (y: -10)
createSectionHeader(labContent, -10, "Combat Procs (Classic Melee & CC Dynamics)")
createSimButton(
	labContent,
	12,
	-34,
	"Windfury (2 Extra Swings)",
	"SPELL_EXTRA_ATTACKS amount=2 (Rapid Double Punch)",
	"Combat",
	"SPELL_EXTRA_ATTACKS",
	"amount=2 (Windfury Weapon)",
	"procExtraAttacksHeavy"
)
createSimButton(
	labContent,
	224,
	-34,
	"Sword Spec (1 Extra Swing)",
	"SPELL_EXTRA_ATTACKS amount=1 (Instant Staccato Snap)",
	"Combat",
	"SPELL_EXTRA_ATTACKS",
	"amount=1 (Sword Specialization)",
	"procExtraAttacks"
)
createSimButton(
	labContent,
	436,
	-34,
	"CC Shatter (Sheep Broke)",
	"SPELL_AURA_BROKEN_SPELL (Polymorph broken by Moonfire)",
	"Combat",
	"SPELL_AURA_BROKEN_SPELL",
	"Polymorph broken by Moonfire",
	"crowdControlBroken"
)

createSimButton(
	labContent,
	12,
	-64,
	"Thorns Reciprocal Spark",
	"DAMAGE_SHIELD (Retaliation damage received on hit)",
	"Combat",
	"DAMAGE_SHIELD",
	"amount=38 Nature (Thorns)",
	"damageShieldReciprocal"
)
createSimButton(
	labContent,
	224,
	-64,
	"Dispel / Purge Cleanse",
	"SPELL_DISPEL (Removed Blessing of Protection)",
	"Combat",
	"SPELL_DISPEL",
	"Removed Blessing of Protection",
	"spellDispelSuccess"
)
createSimButton(
	labContent,
	436,
	-64,
	"Mage Spellsteal Siphon",
	"SPELL_STOLEN (Stole Ice Barrier from enemy Mage)",
	"Combat",
	"SPELL_STOLEN",
	"Stole Ice Barrier",
	"spellStolenSuccess"
)

-- Section: Minions & Pets (y: -106)
createSectionHeader(labContent, -106, "Minions & Pets (Hunter, Warlock & Mage Companions)")
createSimButton(
	labContent,
	12,
	-130,
	"Pet Death (petDead)",
	"UNIT_DIED destGUID=pet (Heavy hollow mourning thud)",
	"Pets",
	"UNIT_DIED",
	"destGUID=UnitGUID('pet')",
	"petDead"
)
createSimButton(
	labContent,
	224,
	-130,
	"Pet Threat Anchor (Growl)",
	"SPELL_CAST_SUCCESS (Pet secured aggro with Growl)",
	"Pets",
	"SPELL_CAST_SUCCESS",
	"Growl (Rank 7) secured threat",
	"petThreatAnchor"
)
createSimButton(
	labContent,
	436,
	-130,
	"Pet Health Low (<20%)",
	"UNIT_HEALTH on pet (Urgent dual-stutter alarm)",
	"Pets",
	"UNIT_HEALTH",
	"Pet health at 18% (Critical)",
	"petHealthCritical"
)

createSimButton(
	labContent,
	12,
	-160,
	"Pet Happiness Increased",
	"GetPetHappiness() transition (Unhappy -> Happy Purr)",
	"Pets",
	"UNIT_HAPPINESS",
	"Happiness climbed to Level 3 (Happy)",
	"petHappinessIncreased"
)

-- Section: World & Hazards (y: -202)
createSectionHeader(labContent, -202, "World & Hazards (Screen Shake & Environmental Trauma)")
createSimButton(
	labContent,
	12,
	-226,
	"Screen Shake (Boss Stomp)",
	"ScriptAnimationUtil.ShakeFrame (Quake rumble)",
	"World",
	"ShakeFrame",
	"region=UIParent duration=0.45 mag=2.0",
	"screenShake"
)
createSimButton(
	labContent,
	224,
	-226,
	"Lava Thermal Burn",
	"ENVIRONMENTAL_DAMAGE Lava (Deep boiling sizzle)",
	"World",
	"ENVIRONMENTAL_DAMAGE",
	"Lava: 450 Fire (Blackrock Depths)",
	"envDamageLava"
)
createSimButton(
	labContent,
	436,
	-226,
	"Slime Acid Burn",
	"ENVIRONMENTAL_DAMAGE Slime (Viscous bubbling churn)",
	"World",
	"ENVIRONMENTAL_DAMAGE",
	"Slime: 320 Nature (Naxxramas)",
	"envDamageSlime"
)

createSimButton(
	labContent,
	12,
	-256,
	"Fall Damage Impact",
	"ENVIRONMENTAL_DAMAGE Falling (Bone-crunching concussion)",
	"World",
	"ENVIRONMENTAL_DAMAGE",
	"Falling: 1200 Physical damage",
	"envDamageFalling"
)

-- Section: Navigation Radar (y: -298)
createSectionHeader(labContent, -298, "Navigation Radar (C_Navigation Waypoint Geiger)")
createSimButton(
	labContent,
	12,
	-322,
	"Geiger Click (30 yd)",
	"C_Navigation.GetDistance() == 30 (Cadence tick)",
	"Navigation",
	"C_Navigation",
	"Distance: 30.5 yards to quest objective",
	"waypointGeigerTick"
)
createSimButton(
	labContent,
	224,
	-322,
	"Geiger Rapid (8 yd)",
	"C_Navigation.GetDistance() == 8 (Rapid proximity tick)",
	"Navigation",
	"C_Navigation",
	"Distance: 8.2 yards to quest objective",
	"waypointGeigerTick"
)
createSimButton(
	labContent,
	436,
	-322,
	"Waypoint Arrival Chime",
	"C_Navigation.GetDistance() < 5 (Arrival resolution)",
	"Navigation",
	"C_Navigation",
	"Distance: 2.1 yards (ARRIVED)",
	"waypointArrival"
)

-- Section: Loot & Economy (y: -364)
createSectionHeader(labContent, -364, "Loot & Economy (Quality Fanfare & Crafting Procs)")
createSimButton(
	labContent,
	12,
	-388,
	"Common Loot (White)",
	"Enum.ItemQuality.Common (Clean inventory click)",
	"Economy",
	"LOOT_OPENED",
	"Quality: Common (Tough Jerky)",
	"lootQualityCommon"
)
createSimButton(
	labContent,
	224,
	-388,
	"Rare Loot (Blue)",
	"Enum.ItemQuality.Rare (Melodic double chime)",
	"Economy",
	"LOOT_OPENED",
	"Quality: Rare (Robes of Arugal)",
	"lootQualityRare"
)
createSimButton(
	labContent,
	436,
	-388,
	"Epic Loot (Purple)",
	"Enum.ItemQuality.Epic (Triumphant fanfare surge)",
	"Economy",
	"LOOT_OPENED",
	"Quality: Epic (Staff of Jordan)",
	"lootQualityEpic"
)

createSimButton(
	labContent,
	12,
	-418,
	"Legendary Loot (Orange)",
	"Enum.ItemQuality.Legendary (Sub-bass crescendo)",
	"Economy",
	"LOOT_OPENED",
	"Quality: Legendary (Thunderfury)",
	"lootQualityLegendary"
)
createSimButton(
	labContent,
	224,
	-418,
	"Multicraft Proc (x3)",
	"TRADE_SKILL_ITEM_CRAFTED_RESULT (Multicraft jackpot)",
	"Economy",
	"TRADE_SKILL_ITEM_CRAFTED_RESULT",
	"Multicraft bonus: +3 Elixirs",
	"craftMulticraftProc"
)

-- Section: Ergonomics & Errors (y: -460)
createSectionHeader(labContent, -460, "Gamepad Ergonomics & Errors (Dead Clicks & Durability)")
createSimButton(
	labContent,
	12,
	-484,
	"Out of Energy (Dead Click)",
	"LE_GAME_ERR_OUT_OF_ENERGY (Empty chamber tick)",
	"Errors",
	"UI_ERROR_MESSAGE",
	"ErrorCode: OUT_OF_ENERGY",
	"actionErrorNoResource"
)
createSimButton(
	labContent,
	224,
	-484,
	"Out of Range Deflect",
	"LE_GAME_ERR_OUT_OF_RANGE (Rubbery bounce bump)",
	"Errors",
	"UI_ERROR_MESSAGE",
	"ErrorCode: OUT_OF_RANGE",
	"actionErrorOutOfRange"
)
createSimButton(
	labContent,
	436,
	-484,
	"On Cooldown Spring",
	"LE_GAME_ERR_SPELL_COOLDOWN (Spring rebound tick)",
	"Errors",
	"UI_ERROR_MESSAGE",
	"ErrorCode: SPELL_COOLDOWN",
	"actionErrorOnCooldown"
)

createSimButton(
	labContent,
	12,
	-514,
	"Durability Warning (<20%)",
	"GetInventoryAlertStatus == 1 (Metallic creak groan)",
	"Errors",
	"UPDATE_INVENTORY_ALERTS",
	"Slot 9 (MainHand) durability < 20%",
	"durabilityWarningLow"
)
createSimButton(
	labContent,
	224,
	-514,
	"Armor Broken (0% Clang)",
	"GetInventoryAlertStatus == 2 (Resonant armor crack)",
	"Errors",
	"UPDATE_INVENTORY_ALERTS",
	"Slot 3 (Chest) shattered at 0%",
	"durabilityItemBroken"
)

---------------------------------------------------------------------------
-- TAB 3: Environment & Status View
---------------------------------------------------------------------------

local envContainer = tabFrames[3]

local envText = envContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
envText:SetPoint("TOPLEFT", envContainer, "TOPLEFT", 12, -12)
envText:SetJustifyH("LEFT")
envText:SetWidth(660)

local function updateEnvironmentStatus()
	if not envContainer:IsShown() then
		return
	end

	local clientVersion, clientBuild = GetBuildInfo()
	local isForever = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
	local gamepadEnabled = C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
	local deviceCount = C_GamePad and C_GamePad.GetDeviceCount and C_GamePad.GetDeviceCount() or 0
	local shakeHooked = Probe.WorldHazards and Probe.WorldHazards.isShakeHooked

	local memUsage = GetAddOnMemoryUsage and GetAddOnMemoryUsage(ADDON_NAME) or 0

	local lines = {
		C.HIGHLIGHT .. "== World of Warcraft Client Environment ==" .. C.RESET,
		"Target Client: " .. C.PRIMARY .. "World of Warcraft Forever (_classic_beta_)" .. C.RESET,
		"Client Version: " .. C.HIGHLIGHT .. clientVersion .. " (Build " .. clientBuild .. ")" .. C.RESET,
		"Classic Project Guard: "
			.. (isForever and (C.SUCCESS .. "TRUE (WOW_PROJECT_CLASSIC)") or (C.WARNING .. "Non-Classic Branch"))
			.. C.RESET,
		"",
		C.HIGHLIGHT .. "== Gamepad & Haptics Hardware ==" .. C.RESET,
		"C_GamePad Subsystem: " .. (C_GamePad and (C.SUCCESS .. "Available") or (C.DANGER .. "Missing")) .. C.RESET,
		"Gamepad API Enabled: "
			.. (gamepadEnabled and (C.SUCCESS .. "ENABLED") or (C.DANGER .. "DISABLED (Check /console GamePadEnable 1)"))
			.. C.RESET,
		"Connected Devices: " .. C.HIGHLIGHT .. tostring(deviceCount) .. C.RESET,
		"",
		C.HIGHLIGHT .. "== Active Hook & Probe Verification ==" .. C.RESET,
		"ScriptAnimationUtil.ShakeFrame Hook: "
			.. (shakeHooked and (C.SUCCESS .. "HOOKED (Untainted / hooksecurefunc)") or (C.WARNING .. "Pending / Not Hooked"))
			.. C.RESET,
		"C_Navigation Subsystem: "
			.. (C_Navigation and (C.SUCCESS .. "Available") or (C.DANGER .. "Unavailable"))
			.. C.RESET,
		"C_SuperTrack Subsystem: "
			.. (C_SuperTrack and (C.SUCCESS .. "Available") or (C.DANGER .. "Unavailable"))
			.. C.RESET,
		"",
		C.HIGHLIGHT .. "== Secrecy Sandbox Audit ==" .. C.RESET,
		"Player GUID Secrecy: "
			.. (issecretvalue and issecretvalue(UnitGUID("player")) and (C.DANGER .. "RESTRICTED") or (C.SUCCESS .. "Public / Accessible"))
			.. C.RESET,
		"Target Exists Secrecy: "
			.. (issecretvalue and issecretvalue(UnitExists("target")) and (C.DANGER .. "RESTRICTED") or (C.SUCCESS .. "Public / Accessible"))
			.. C.RESET,
		"",
		C.HIGHLIGHT .. "== Subaddon Diagnostics ==" .. C.RESET,
		"Logged Event History: " .. C.HIGHLIGHT .. tostring(Probe.LogCount) .. " / 100 entries" .. C.RESET,
		"Memory Footprint: " .. C.HIGHLIGHT .. string.format("%.1f kB", memUsage) .. C.RESET,
	}

	envText:SetText(table.concat(lines, "\n"))
end

envContainer:SetScript("OnShow", updateEnvironmentStatus)

---------------------------------------------------------------------------
-- Public UI Methods
---------------------------------------------------------------------------

function UI:Toggle()
	if frame:IsShown() then
		frame:Hide()
	else
		self:Show()
	end
end

function UI:Show()
	updateSoundBtnText()
	updateHapticBtnText()
	updatePauseBtnText()
	selectTab(currentTab)
	frame:Show()
end

function UI:Hide()
	frame:Hide()
end
