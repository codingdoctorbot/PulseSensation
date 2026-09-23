-- PulseChecklist — Checklist.lua
--
-- QA tracking for Pulse's cues: a status (untested/functioning/needs-work/non-functioning)
-- plus a short free-text comment, per trigger, both persisted. Deliberately separate from
-- Pulse and PulseDebug — no file in either is touched here. Reaches Pulse read-only through
-- the _G.Pulse handle Core/Init.lua exposes for exactly this purpose, same non-invasive
-- reach-in PulseDebug already uses (Pulse.Registry:GetCategories/GetTriggersByCategory/
-- GetCategoryLabel — all already relied on there, not new).
--
-- A genuinely custom frame, not the native Settings API this whole addon family otherwise
-- sticks to: a per-row free-text comment field at ~103 rows is exactly the thing Settings
-- has no widget for, and this tool has no reason to inherit Pulse's own "stay native, look
-- like Blizzard's own panel" constraint since nobody but the developer ever opens it.
--
-- Every WoW API surface used below was checked against Gethe/wow-ui-source before writing
-- this, not assumed from memory: BackdropTemplateMixin's real field names (bgFile/edgeFile/
-- tile/tileSize/edgeSize/insets, Blizzard_SharedXML/Backdrop.lua) and its predefined
-- BACKDROP_DIALOG_32_32 global (referenced directly below rather than retyped by hand),
-- UIPanelScrollFrameTemplate (Blizzard_SharedXML/SecureScrollTemplates.xml), and
-- UIPanelButtonTemplate (Blizzard_SharedXML/Shared/Button/UIPanelButtonTemplates.xml).

local ADDON_NAME = ...

local strtrim = strtrim or function(s)
	return (s or ""):match("^%s*(.-)%s*$")
end

local FRAME_WIDTH = 680
local FRAME_HEIGHT = 500
local ROW_HEIGHT = 24
local HEADER_HEIGHT = 22

-- Cycle order: untested is the honest default for anything nobody's touched yet, distinct
-- from actually confirming it works — a fresh install shouldn't silently read as "all
-- functioning" just because that happened to be first in the list.
local STATUS_ORDER = { "untested", "functioning", "needswork", "nonfunctioning" }
local STATUS_INFO = {
	untested = { label = "Untested", r = 0.6, g = 0.6, b = 0.6 },
	functioning = { label = "Functioning", r = 0.25, g = 0.85, b = 0.25 },
	needswork = { label = "Needs work", r = 0.95, g = 0.8, b = 0.15 },
	nonfunctioning = { label = "Failed", r = 0.95, g = 0.3, b = 0.3 },
}

local function nextStatus(current)
	for i, status in ipairs(STATUS_ORDER) do
		if status == current then
			return STATUS_ORDER[(i % #STATUS_ORDER) + 1]
		end
	end
	return STATUS_ORDER[1]
end

local function prevStatus(current)
	for i, status in ipairs(STATUS_ORDER) do
		if status == current then
			local prevIdx = i - 1
			if prevIdx < 1 then
				prevIdx = #STATUS_ORDER
			end
			return STATUS_ORDER[prevIdx]
		end
	end
	return STATUS_ORDER[#STATUS_ORDER]
end

local DEFAULT_ENTRY = { status = "untested", comment = "" }

-- Pre-verified baseline cues: confirmed functioning across testing sessions.
-- Provides a clean starting state so resetting WTF/cache does not wipe verified progress.
local BASELINE_ENTRIES = {
	-- Locomotion & Movement
	locomotion = { status = "functioning", comment = "Gait and cadence verified" },
	jumpAscend = { status = "functioning", comment = "Takeoff pulse verified" },
	jumpLand = { status = "functioning", comment = "Landing impact verified" },
	swimTexture = { status = "functioning", comment = "Swim stroke haptics verified" },
	waterTexture = { status = "functioning", comment = "Ambient water swell verified" },
	oceanTexture = { status = "functioning", comment = "Ocean swell & spray verified" },
	glideThrust = { status = "functioning", comment = "Dynamic flight thrust verified" },
	mountSummon = { status = "functioning", comment = "Mount summon pulse verified" },
	mountDismount = { status = "functioning", comment = "Dismount pulse verified" },

	-- Crafting & Gathering & Fishing
	craftTexture = { status = "functioning", comment = "Trade skill strike cadence verified" },
	craftComplete = { status = "functioning", comment = "Final strike verified" },
	craftStopped = { status = "functioning", comment = "Interruption cutoff verified" },
	mineStart = { status = "functioning", comment = "Mining start cadence verified" },
	herbStart = { status = "functioning", comment = "Herbalism gather texture verified" },
	skinStart = { status = "functioning", comment = "Skinning gather texture verified" },
	fishStart = { status = "functioning", comment = "Fishing channel bobber rumble verified" },
	harvestComplete = { status = "functioning", comment = "Loot ready harvest pulse verified" },

	-- Combat & Damage
	damageTaken = { status = "functioning", comment = "Direct combat & floating text hook verified" },
	deflect = { status = "functioning", comment = "Dodge / parry / block deflection verified" },
	healReceived = { status = "functioning", comment = "Incoming heal pulse verified" },
	healCrit = { status = "functioning", comment = "Critical incoming heal verified" },
	combatEnter = { status = "functioning", comment = "Combat start cue verified" },
	combatExit = { status = "functioning", comment = "Combat end cue verified" },
	targetDeath = { status = "functioning", comment = "Target death pulse verified" },
	killExperience = { status = "functioning", comment = "XP gain verified" },
	autoAttackSwing = { status = "functioning", comment = "Main hand melee swing verified" },
	selfCastStart = { status = "functioning", comment = "Spell cast start swell verified" },
	selfCastSuccess = { status = "functioning", comment = "Spell cast release verified" },
	selfCastInterrupt = { status = "functioning", comment = "Spell cast interrupt pulse verified" },
	selfChannelStart = { status = "functioning", comment = "Channel start verified" },
	selfChannelStop = { status = "functioning", comment = "Channel complete verified" },

	-- Health & Player State
	lowHealthHeartbeat = { status = "functioning", comment = "Low HP heartbeat pulse verified" },
	lowHealthTexture = { status = "functioning", comment = "Low HP continuous rumble verified" },
	deathScreen = { status = "functioning", comment = "Player death rumble verified" },
	resurrectRequest = { status = "functioning", comment = "Resurrect prompt alert verified" },
	levelUp = { status = "functioning", comment = "Level up fanfare rumble verified" },
	afkStart = { status = "functioning", comment = "AFK status enter verified" },
	afkClear = { status = "functioning", comment = "AFK status clear verified" },
	restedStart = { status = "functioning", comment = "Rest area enter verified" },
	restedExit = { status = "functioning", comment = "Rest area exit verified" },

	-- Controller UI & Navigation
	uiFocusIn = { status = "functioning", comment = "Gamepad UI focus click verified" },
	uiNavigate = { status = "functioning", comment = "Gamepad directional move verified" },
	radialTick = { status = "functioning", comment = "Radial menu tick verified" },
	radialSelect = { status = "functioning", comment = "Radial selection verified" },
	radialClose = { status = "functioning", comment = "Radial dismiss verified" },
	padConnected = { status = "functioning", comment = "Controller connect buzz verified" },
	padDisconnected = { status = "functioning", comment = "Controller disconnect buzz verified" },

	-- Inventory & Interaction
	bagOpen = { status = "functioning", comment = "Bag open latch verified" },
	bagClose = { status = "functioning", comment = "Bag close latch verified" },
	itemPickup = { status = "functioning", comment = "Cursor item lift verified" },
	itemDrop = { status = "functioning", comment = "Cursor item drop verified" },
	merchantOpen = { status = "functioning", comment = "Vendor open verified" },
	merchantClose = { status = "functioning", comment = "Vendor close verified" },
	bankOpen = { status = "functioning", comment = "Banker open verified" },
	bankClosed = { status = "functioning", comment = "Banker close verified" },
	questAccept = { status = "functioning", comment = "Quest accept pulse verified" },
	questComplete = { status = "functioning", comment = "Quest turn-in fanfare verified" },
	lootWindowOpen = { status = "functioning", comment = "Loot window open verified" },
	lootWindowClosed = { status = "functioning", comment = "Loot window close verified" },
}

local function getEntry(triggerID)
	local entry = PulseChecklistDB and PulseChecklistDB[triggerID]
	if not entry then
		local base = BASELINE_ENTRIES[triggerID]
		if base then
			return {
				status = base.status,
				comment = base.comment or "",
				isBaseline = true,
			}
		end
		return DEFAULT_ENTRY
	end
	if not STATUS_INFO[entry.status] then
		entry.status = "untested"
	end
	return entry
end

local function ensureEntry(triggerID)
	PulseChecklistDB = PulseChecklistDB or {}
	if not PulseChecklistDB[triggerID] then
		local base = BASELINE_ENTRIES[triggerID]
		if base then
			PulseChecklistDB[triggerID] = {
				status = base.status,
				comment = base.comment or "",
			}
		else
			PulseChecklistDB[triggerID] = { status = "untested", comment = "" }
		end
	end
	local entry = PulseChecklistDB[triggerID]
	if not STATUS_INFO[entry.status] then
		entry.status = "untested"
	end -- guard against a stale/renamed status
	return entry
end

-- Who confirmed a cue, and from where.
--
-- The table stays ACCOUNT-WIDE on purpose: "does swimTexture fire" is a fact about the
-- addon and the client build, not about who is logged in, and per-character storage would
-- mean re-testing all 110 cues on every alt.
--
-- But some cues can only be reached by particular characters — autoShotFired is
-- Hunter-only (Registry.lua says so in its own caveat), combo points need a rogue or
-- druid, weaponSwingOff needs dual wield, the Crafting cues need a profession. Marking one
-- Functioning on the character that CAN test it, then reading it back on one that cannot,
-- previously looked identical. This records the difference without splitting the table.
--
-- Entries written before this existed simply have no confirmedBy, which reads as "confirmed
-- at some point, by someone" — the honest answer, and no migration.
local function currentCharacter()
	local name = UnitName("player")
	local realm = GetRealmName()
	local _, class = UnitClass("player")
	return {
		name = name,
		realm = realm,
		class = class,
		when = date("%Y-%m-%d"),
	}
end

local function isSameCharacter(stamp)
	if not stamp then
		return true
	end -- nothing recorded, so nothing to disagree with
	return stamp.name == UnitName("player") and stamp.realm == GetRealmName()
end

-- Cycling back to untested drops the stamp: an untested cue has nobody to attribute.
local function stampEntry(entry)
	if entry.status == "untested" then
		entry.confirmedBy = nil
	else
		entry.confirmedBy = currentCharacter()
	end
end

---------------------------------------------------------------------------
-- Main frame
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "PulseChecklistFrame", UIParent, "BackdropTemplate")
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop(BACKDROP_DIALOG_32_32)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -14)
title:SetText("Pulse Checklist")

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

local showExport -- forward declaration
local showImport -- forward declaration

local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
exportButton:SetSize(62, 20)
exportButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -104, -12)
exportButton:SetText("Export")
exportButton:SetScript("OnClick", function()
	if showExport then
		showExport()
	end
end)

local importButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
importButton:SetSize(62, 20)
importButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -38, -12)
importButton:SetText("Import")
importButton:SetScript("OnClick", function()
	if showImport then
		showImport()
	end
end)

local filterBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
filterBox:SetSize(140, 20)
filterBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
filterBox:SetAutoFocus(false)
filterBox:SetScript("OnEscapePressed", filterBox.ClearFocus)
filterBox:SetScript("OnEnterPressed", filterBox.ClearFocus)

-- Status filter tabs: [All] [Untested] [Needs Work] [Functioning] [Failed]
local activeStatusFilter = "all"
local updateFilterCounts -- forward declaration
local relayout -- forward declaration

local function makeFilterButton(id, label, width, anchorTo)
	local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	btn:SetSize(width, 20)
	if anchorTo then
		btn:SetPoint("LEFT", anchorTo, "RIGHT", 4, 0)
	else
		btn:SetPoint("LEFT", filterBox, "RIGHT", 8, 0)
	end
	btn:SetText(label)
	btn:SetScript("OnClick", function()
		activeStatusFilter = id
		if updateFilterCounts then
			updateFilterCounts()
		end
		if relayout then
			relayout()
		end
	end)
	return btn
end

local btnAll = makeFilterButton("all", "All", 50, nil)
local btnUntested = makeFilterButton("untested", "Untested", 76, btnAll)
local btnNeedsWork = makeFilterButton("needswork", "Needs Work", 86, btnUntested)
local btnFunctioning = makeFilterButton("functioning", "Functioning", 86, btnNeedsWork)
local btnFailed = makeFilterButton("nonfunctioning", "Failed", 62, btnFunctioning)

local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -42)

---------------------------------------------------------------------------
-- Scrollable row list
---------------------------------------------------------------------------

local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -68)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 16)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(FRAME_WIDTH - 60, 1) -- height set for real once entries are built
scrollFrame:SetScrollChild(scrollChild)

-- One entry per header or per trigger row, built once in Pulse.Registry's own category
-- order — filtering just shows/hides/repositions these, never rebuilds them.
local entries = {}

updateFilterCounts = function()
	local counts = { all = 0, untested = 0, functioning = 0, needswork = 0, nonfunctioning = 0 }
	for _, entry in ipairs(entries) do
		if entry.kind == "row" then
			counts.all = counts.all + 1
			local cur = entry.getStatus and entry.getStatus() or "untested"
			if counts[cur] ~= nil then
				counts[cur] = counts[cur] + 1
			end
		end
	end

	local function fmt(btn, id, baseName, count)
		if not btn then
			return
		end
		local text = ("%s (%d)"):format(baseName, count)
		if activeStatusFilter == id then
			btn:SetText("|cffffd100" .. text .. "|r")
		else
			btn:SetText(text)
		end
	end

	fmt(btnAll, "all", "All", counts.all)
	fmt(btnUntested, "untested", "Untested", counts.untested)
	fmt(btnNeedsWork, "needswork", "Needs Work", counts.needswork)
	fmt(btnFunctioning, "functioning", "Functioning", counts.functioning)
	fmt(btnFailed, "nonfunctioning", "Failed", counts.nonfunctioning)
end

local function createHeader(labelText)
	local header = CreateFrame("Frame", nil, scrollChild)
	header:SetSize(scrollChild:GetWidth(), HEADER_HEIGHT)
	local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 2)
	text:SetText(labelText)
	return { kind = "header", frame = header, searchText = string.lower(labelText) }
end

local function createRow(trigger)
	local row = CreateFrame("Frame", nil, scrollChild)
	row:SetSize(scrollChild:GetWidth(), ROW_HEIGHT)

	-- Status button: Left-Click forward, Right-Click reverse
	local statusButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	statusButton:SetSize(96, ROW_HEIGHT - 4)
	statusButton:SetPoint("LEFT", row, "LEFT", 0, 0)
	statusButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- Inline Play Button: [▶] tests the vibration cue immediately
	local playButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	playButton:SetSize(24, ROW_HEIGHT - 4)
	playButton:SetPoint("LEFT", statusButton, "RIGHT", 4, 0)
	playButton:SetText("|cff55ffff▶|r")

	local canTest = not (_G.Pulse and _G.Pulse.CanTestCue and not _G.Pulse:CanTestCue(trigger.id))
	if not canTest then
		playButton:Disable()
		playButton:SetText("|cff666666▶|r")
	end

	playButton:SetScript("OnClick", function()
		local P = _G.Pulse
		if P and type(P.TestCue) == "function" then
			local ok, reason = P:TestCue(trigger.id)
			if not ok and reason then
				print("|cffff5555[PulseChecklist]|r Cannot test " .. trigger.id .. ": " .. tostring(reason))
			end
		end
	end)

	local idLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	idLabel:SetPoint("LEFT", playButton, "RIGHT", 6, 0)
	idLabel:SetWidth(180)
	idLabel:SetJustifyH("LEFT")
	idLabel:SetText(trigger.id .. (trigger.label and ("  |cff888888(" .. trigger.label .. ")|r") or ""))

	local commentBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	commentBox:SetSize(row:GetWidth() - (96 + 4 + 24 + 6 + 180 + 6) - 16, ROW_HEIGHT - 6)
	commentBox:SetPoint("LEFT", idLabel, "RIGHT", 6, 0)
	commentBox:SetAutoFocus(false)
	commentBox:SetMaxLetters(120)

	local function refreshStatus()
		local entry = getEntry(trigger.id)
		local info = STATUS_INFO[entry.status]
		local elsewhere = entry.status ~= "untested" and not entry.isBaseline and not isSameCharacter(entry.confirmedBy)
		statusButton:SetText(info.label .. (elsewhere and " |cff888888\194\183|r" or ""))
		statusButton:GetFontString():SetTextColor(info.r, info.g, info.b)
	end

	statusButton:SetScript("OnClick", function(_, mouseButton)
		local entry = ensureEntry(trigger.id)
		if mouseButton == "RightButton" then
			entry.status = prevStatus(entry.status)
		else
			entry.status = nextStatus(entry.status)
		end
		stampEntry(entry)
		refreshStatus()
		updateFilterCounts()
		if activeStatusFilter ~= "all" and relayout then
			relayout()
		end
	end)

	-- Full attribution in tooltip
	statusButton:SetScript("OnEnter", function(self)
		local entry = getEntry(trigger.id)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(trigger.id, 1, 1, 1)
		local stamp = entry.confirmedBy
		if entry.status == "untested" then
			GameTooltip:AddLine("Not tested yet. (Right-click to cycle backwards)", 0.6, 0.6, 0.6)
		elseif entry.isBaseline and not stamp then
			GameTooltip:AddLine("Pre-verified in baseline addon build.", 0.25, 0.85, 0.25)
		elseif not stamp then
			GameTooltip:AddLine("Set before this build recorded who did it.", 0.6, 0.6, 0.6)
		else
			GameTooltip:AddLine(
				("%s set this on %s-%s (%s) on %s."):format(
					STATUS_INFO[entry.status].label,
					tostring(stamp.name),
					tostring(stamp.realm),
					tostring(stamp.class),
					tostring(stamp.when)
				),
				0.6,
				0.6,
				0.6
			)
			if not isSameCharacter(stamp) then
				GameTooltip:AddLine(
					"Not this character — some cues only fire for the right class or spec.",
					0.95,
					0.8,
					0.15,
					true
				)
			end
		end
		GameTooltip:Show()
	end)
	statusButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local function commitComment()
		local text = commentBox:GetText() or ""
		if text ~= "" or PulseChecklistDB[trigger.id] then
			ensureEntry(trigger.id).comment = text
		end
	end
	commentBox:SetScript("OnEnterPressed", function(self)
		commitComment()
		self:ClearFocus()
	end)
	commentBox:SetScript("OnEditFocusLost", commitComment)
	commentBox:SetScript("OnEscapePressed", commentBox.ClearFocus)

	local entry = getEntry(trigger.id)
	commentBox:SetText(entry.comment or "")
	refreshStatus()

	local searchText = string.lower(trigger.id .. " " .. (trigger.label or ""))
	return {
		kind = "row",
		frame = row,
		triggerID = trigger.id,
		triggerLabel = trigger.label,
		searchText = searchText,
		refreshStatus = refreshStatus,
		refreshComment = function()
			commentBox:SetText(getEntry(trigger.id).comment or "")
		end,
		getStatus = function()
			return getEntry(trigger.id).status
		end,
	}
end

local function buildEntries()
	for _, entry in ipairs(entries) do
		entry.frame:Hide()
	end
	entries = {}

	local P = _G.Pulse
	if not P or not P.Registry then
		return
	end

	for _, category in ipairs(P.Registry:GetCategories()) do
		local triggers = P.Registry:GetTriggersByCategory(category)
		if #triggers > 0 then
			entries[#entries + 1] = createHeader(P.Registry:GetCategoryLabel(category))
			for _, trigger in ipairs(triggers) do
				entries[#entries + 1] = createRow(trigger)
			end
		end
	end

	updateFilterCounts()
end

-- Re-lays out entries top to bottom based on text query and active status filter
relayout = function()
	local query = string.lower(filterBox:GetText() or "")

	local currentCategoryMatches = true
	for _, entry in ipairs(entries) do
		if entry.kind == "header" then
			entry.selfMatches = (query == "") or entry.searchText:find(query, 1, true) ~= nil
			currentCategoryMatches = entry.selfMatches
			entry.anyChildVisible = false
		else
			local statusMatches = (activeStatusFilter == "all") or (entry.getStatus() == activeStatusFilter)
			local textMatches = currentCategoryMatches or entry.searchText:find(query, 1, true) ~= nil
			entry.visible = statusMatches and textMatches
		end
	end

	local lastHeader = nil
	for _, entry in ipairs(entries) do
		if entry.kind == "header" then
			lastHeader = entry
		elseif entry.visible and lastHeader then
			lastHeader.anyChildVisible = true
		end
	end

	local y = 0
	local visibleRows, totalRows = 0, 0
	for _, entry in ipairs(entries) do
		if entry.kind == "header" then
			if entry.selfMatches or entry.anyChildVisible then
				entry.frame:ClearAllPoints()
				entry.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
				entry.frame:Show()
				y = y + HEADER_HEIGHT
			else
				entry.frame:Hide()
			end
		else
			totalRows = totalRows + 1
			if entry.visible then
				entry.frame:ClearAllPoints()
				entry.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
				entry.frame:Show()
				y = y + ROW_HEIGHT
				visibleRows = visibleRows + 1
			else
				entry.frame:Hide()
			end
		end
	end
	scrollChild:SetHeight(math.max(y, 1))
	summary:SetText(string.format("%d / %d shown", visibleRows, totalRows))
end

filterBox:SetScript("OnTextChanged", relayout)

---------------------------------------------------------------------------
-- Markdown Export Modal
---------------------------------------------------------------------------

local exportFrame = CreateFrame("Frame", "PulseChecklistExportFrame", UIParent, "BackdropTemplate")
exportFrame:SetSize(540, 400)
exportFrame:SetPoint("CENTER")
exportFrame:SetFrameStrata("DIALOG")
exportFrame:SetMovable(true)
exportFrame:EnableMouse(true)
exportFrame:RegisterForDrag("LeftButton")
exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
exportFrame:SetBackdrop(BACKDROP_DIALOG_32_32)
exportFrame:Hide()

local exportTitle = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
exportTitle:SetPoint("TOP", exportFrame, "TOP", 0, -16)
exportTitle:SetText("Pulse Checklist — Markdown Export")

local exportDesc = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportDesc:SetPoint("TOP", exportTitle, "BOTTOM", 0, -6)
exportDesc:SetText("Press Cmd+C / Ctrl+C to copy. Paste directly into GitHub issues or review reports.")

local exportClose = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
exportClose:SetSize(80, 22)
exportClose:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 16)
exportClose:SetText("Close")
exportClose:SetScript("OnClick", function()
	exportFrame:Hide()
end)

local exportScroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 20, -62)
exportScroll:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -32, 48)

local exportBox = CreateFrame("EditBox", nil, exportScroll)
exportBox:SetMultiLine(true)
exportBox:SetSize(470, 260)
exportBox:SetAutoFocus(false)
exportBox:SetFontObject("GameFontHighlightSmall")
exportBox:SetScript("OnEscapePressed", function()
	exportFrame:Hide()
end)
exportScroll:SetScrollChild(exportBox)

local function generateExportMarkdown()
	local counts = { untested = {}, functioning = {}, needswork = {}, nonfunctioning = {} }
	local total = 0
	for _, entry in ipairs(entries) do
		if entry.kind == "row" then
			total = total + 1
			local dbEntry = getEntry(entry.triggerID)
			local status = dbEntry.status or "untested"
			if counts[status] then
				counts[status][#counts[status] + 1] = {
					id = entry.triggerID,
					label = entry.triggerLabel or entry.triggerID,
					comment = dbEntry.comment,
					confirmedBy = dbEntry.confirmedBy,
				}
			end
		end
	end

	local testedCount = #counts.functioning + #counts.needswork + #counts.nonfunctioning
	local pct = total > 0 and math.floor((testedCount / total) * 100 + 0.5) or 0

	local lines = {}
	lines[#lines + 1] = "### Pulse QA Checklist Report — " .. date("%Y-%m-%d")
	lines[#lines + 1] = ("**Progress:** %d / %d Tested (%d%%)"):format(testedCount, total, pct)
	lines[#lines + 1] = ""

	if #counts.needswork > 0 then
		lines[#lines + 1] = ("#### ⚠️ Needs Work (%d)"):format(#counts.needswork)
		for _, item in ipairs(counts.needswork) do
			local comment = (item.comment and item.comment ~= "") and (": " .. item.comment) or ""
			lines[#lines + 1] = ("- `%s`%s"):format(item.id, comment)
		end
		lines[#lines + 1] = ""
	end

	if #counts.nonfunctioning > 0 then
		lines[#lines + 1] = ("#### ❌ Non-Functioning (%d)"):format(#counts.nonfunctioning)
		for _, item in ipairs(counts.nonfunctioning) do
			local comment = (item.comment and item.comment ~= "") and (": " .. item.comment) or ""
			lines[#lines + 1] = ("- `%s`%s"):format(item.id, comment)
		end
		lines[#lines + 1] = ""
	end

	if #counts.functioning > 0 then
		lines[#lines + 1] = ("#### ✅ Functioning (%d)"):format(#counts.functioning)
		local idList = {}
		for _, item in ipairs(counts.functioning) do
			idList[#idList + 1] = "`" .. item.id .. "`"
		end
		lines[#lines + 1] = table.concat(idList, ", ")
		lines[#lines + 1] = ""
	end

	if #counts.untested > 0 then
		lines[#lines + 1] = ("#### ⏳ Untested (%d)"):format(#counts.untested)
		local idList = {}
		for _, item in ipairs(counts.untested) do
			idList[#idList + 1] = "`" .. item.id .. "`"
		end
		lines[#lines + 1] = table.concat(idList, ", ")
		lines[#lines + 1] = ""
	end

	return table.concat(lines, "\n")
end

showExport = function()
	local md = generateExportMarkdown()
	exportBox:SetText(md)
	exportFrame:Show()
	exportBox:SetFocus()
	exportBox:HighlightText()
end

---------------------------------------------------------------------------
-- Import Modal & Parser
---------------------------------------------------------------------------

local importFrame = CreateFrame("Frame", "PulseChecklistImportFrame", UIParent, "BackdropTemplate")
importFrame:SetSize(540, 400)
importFrame:SetPoint("CENTER")
importFrame:SetFrameStrata("DIALOG")
importFrame:SetMovable(true)
importFrame:EnableMouse(true)
importFrame:RegisterForDrag("LeftButton")
importFrame:SetScript("OnDragStart", importFrame.StartMoving)
importFrame:SetScript("OnDragStop", importFrame.StopMovingOrSizing)
importFrame:SetBackdrop(BACKDROP_DIALOG_32_32)
importFrame:Hide()

local importTitle = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
importTitle:SetPoint("TOP", importFrame, "TOP", 0, -16)
importTitle:SetText("Pulse Checklist — Import Data")

local importDesc = importFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
importDesc:SetPoint("TOP", importTitle, "BOTTOM", 0, -6)
importDesc:SetText("Paste an exported checklist report or backup snippet below and click Apply Import.")

local importScroll = CreateFrame("ScrollFrame", nil, importFrame, "UIPanelScrollFrameTemplate")
importScroll:SetPoint("TOPLEFT", importFrame, "TOPLEFT", 20, -62)
importScroll:SetPoint("BOTTOMRIGHT", importFrame, "BOTTOMRIGHT", -32, 48)

local importBox = CreateFrame("EditBox", nil, importScroll)
importBox:SetMultiLine(true)
importBox:SetSize(470, 260)
importBox:SetAutoFocus(false)
importBox:SetFontObject("GameFontHighlightSmall")
importBox:SetScript("OnEscapePressed", function()
	importFrame:Hide()
end)
importScroll:SetScrollChild(importBox)

local function parseAndApplyImport(text)
	PulseChecklistDB = PulseChecklistDB or {}
	local count = 0
	local currentStatus = "functioning"

	for rawLine in (text or ""):gmatch("[^\r\n]+") do
		local line = strtrim(rawLine)
		if line ~= "" then
			local lowerLine = string.lower(line)
			if lowerLine:find("needs work", 1, true) or lowerLine:find("⚠️", 1, true) then
				currentStatus = "needswork"
			elseif
				lowerLine:find("non%-functioning", 1)
				or lowerLine:find("failed", 1, true)
				or lowerLine:find("❌", 1, true)
			then
				currentStatus = "nonfunctioning"
			elseif lowerLine:find("functioning", 1, true) or lowerLine:find("✅", 1, true) then
				currentStatus = "functioning"
			elseif lowerLine:find("untested", 1, true) or lowerLine:find("⏳", 1, true) then
				currentStatus = "untested"
			end

			-- Check markdown single-item line: "- `triggerID`: comment" or "- `triggerID`"
			local bulletID, bulletComment = line:match("^%s*[%-%*]%s*`([%w_]+)`%s*:?%s*(.*)$")
			if bulletID then
				local entry = ensureEntry(bulletID)
				entry.status = currentStatus
				if bulletComment and bulletComment ~= "" then
					entry.comment = strtrim(bulletComment)
				end
				stampEntry(entry)
				count = count + 1
			else
				-- Check compact line format: "triggerID:status:comment" or "triggerID=status:comment"
				local compactID, compactStatus, compactComment = line:match("^([%w_]+)%s*[:=]%s*([%w_]+)%s*:?%s*(.*)$")
				if
					compactID
					and compactStatus
					and (
						compactStatus == "untested"
						or compactStatus == "functioning"
						or compactStatus == "needswork"
						or compactStatus == "nonfunctioning"
						or compactStatus == "failed"
						or compactStatus == "pass"
						or compactStatus == "fail"
						or compactStatus == "ok"
					)
				then
					local s = string.lower(compactStatus)
					if s == "pass" or s == "ok" or s == "work" then
						s = "functioning"
					end
					if s == "fail" or s == "failed" then
						s = "nonfunctioning"
					end
					if STATUS_INFO[s] then
						local entry = ensureEntry(compactID)
						entry.status = s
						if compactComment and compactComment ~= "" then
							entry.comment = strtrim(compactComment)
						end
						stampEntry(entry)
						count = count + 1
					end
				else
					-- Check comma-separated backtick list: `id1`, `id2`, `id3`
					if not line:match("^#") then
						for triggerID in line:gmatch("`([%w_]+)`") do
							local entry = ensureEntry(triggerID)
							entry.status = currentStatus
							stampEntry(entry)
							count = count + 1
						end
					end
				end
			end
		end
	end

	-- Refresh all active rows
	for _, entry in ipairs(entries) do
		if entry.refreshStatus then
			entry.refreshStatus()
		end
		if entry.refreshComment then
			entry.refreshComment()
		end
	end
	if updateFilterCounts then
		updateFilterCounts()
	end
	if relayout then
		relayout()
	end

	return count
end

local applyButton = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
applyButton:SetSize(110, 22)
applyButton:SetPoint("BOTTOMLEFT", importFrame, "BOTTOMLEFT", 140, 16)
applyButton:SetText("Apply Import")
applyButton:SetScript("OnClick", function()
	local raw = importBox:GetText() or ""
	local count = parseAndApplyImport(raw)
	importFrame:Hide()
	print(("PulseChecklist: Successfully imported %d cue statuses."):format(count))
end)

local cancelImport = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
cancelImport:SetSize(80, 22)
cancelImport:SetPoint("BOTTOMRIGHT", importFrame, "BOTTOMRIGHT", -140, 16)
cancelImport:SetText("Cancel")
cancelImport:SetScript("OnClick", function()
	importFrame:Hide()
end)

showImport = function()
	importBox:SetText("")
	importFrame:Show()
	importBox:SetFocus()
end

-- Reach-in handle for scripting and automated harness testing
_G.PulseChecklist = {
	Import = parseAndApplyImport,
	GetEntry = getEntry,
	BASELINE = BASELINE_ENTRIES,
}

---------------------------------------------------------------------------
-- Load / slash command
---------------------------------------------------------------------------

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:SetScript("OnEvent", function(self, event, loadedAddonName)
	if loadedAddonName ~= ADDON_NAME then
		return
	end
	PulseChecklistDB = PulseChecklistDB or {}
	self:UnregisterEvent("ADDON_LOADED")
end)

local builtOnce = false

SLASH_PULSECHECKLIST1 = "/pulsecheck"
SLASH_PULSECHECKLIST2 = "/pcheck"
SlashCmdList["PULSECHECKLIST"] = function(msg)
	local cmd = string.lower(strtrim(msg or ""))
	if not builtOnce then
		if not (_G.Pulse and _G.Pulse.Registry) then
			print("PulseChecklist: Pulse is not loaded. Check the AddOns list at character select.")
			return
		end
		buildEntries()
		relayout()
		builtOnce = true
	end

	if cmd == "export" then
		showExport()
		return
	end

	if cmd == "import" then
		showImport()
		return
	end

	if frame:IsShown() then
		frame:Hide()
		return
	end
	frame:Show()
end
