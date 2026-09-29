-- Pulse Profile Review — standalone auditing tool.
-- Reads Pulse's registry and PulseDB profile values. It only writes PulseProfileReviewDB.

local ADDON_NAME = ...
local ROW_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT = 27, 760, 570
local trim = strtrim or function(s)
	return (s or ""):match("^%s*(.-)%s*$")
end

local function hideTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local db
local selectedProfile = 1
local profiles, rows = {}, {}
local built = false

local function pulse()
	return _G.Pulse
end

local function profileNames()
	local p = pulse()
	if not p or not p.Database or not p.Registry then
		return nil
	end
	return p.Database:GetProfileNames()
end

local function savedProfile(name)
	return PulseDB and PulseDB.profiles and PulseDB.profiles[name]
end

local function reviewEntry(profileName, cueID)
	db.reviews[profileName] = db.reviews[profileName] or {}
	local entry = db.reviews[profileName][cueID]
	if not entry then
		entry = { decision = "unreviewed" }
		db.reviews[profileName][cueID] = entry
	end
	return entry
end

local function activeProfileName()
	local p = pulse()
	return p and p.Database and p.Database:GetActiveProfileName() or "Unknown"
end

local frame = CreateFrame("Frame", "PulseProfileReviewFrame", UIParent, "BackdropTemplate")
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
title:SetPoint("TOP", frame, "TOP", 0, -13)
title:SetText("Pulse Profile Review")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

local profileLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
profileLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -48)
profileLabel:SetWidth(310)
profileLabel:SetJustifyH("LEFT")

local activeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
activeLabel:SetPoint("TOPLEFT", profileLabel, "BOTTOMLEFT", 0, -5)
activeLabel:SetWidth(450)
activeLabel:SetJustifyH("LEFT")

local function makeButton(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, height)
	b:SetText(text)
	return b
end

local prevButton = makeButton(frame, "< Profile", 82, 22)
prevButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -188, -43)
local nextButton = makeButton(frame, "Profile >", 82, 22)
nextButton:SetPoint("LEFT", prevButton, "RIGHT", 5, 0)
local exportButton = makeButton(frame, "Export", 70, 22)
exportButton:SetPoint("LEFT", nextButton, "RIGHT", 5, 0)

local allYesButton = makeButton(frame, "All Yes", 70, 22)
allYesButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 14)
local allNoButton = makeButton(frame, "All No", 70, 22)
allNoButton:SetPoint("LEFT", allYesButton, "RIGHT", 6, 0)

local enableAllButton = makeButton(frame, "Enable All Cues", 120, 22)
enableAllButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -150, 14)
local disableAllButton = makeButton(frame, "Disable All Cues", 120, 22)
disableAllButton:SetPoint("LEFT", enableAllButton, "RIGHT", 6, 0)

local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
summary:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", 0, -9)
summary:SetWidth(450)
summary:SetJustifyH("LEFT")

local columnHeader = CreateFrame("Frame", nil, frame)
columnHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -111)
columnHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -111)
columnHeader:SetHeight(22)
local cueHeader = columnHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cueHeader:SetPoint("LEFT", columnHeader, "LEFT", 4, 0)
cueHeader:SetText("CUE")
local currentHeader = columnHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
currentHeader:SetPoint("RIGHT", columnHeader, "RIGHT", -157, 0)
currentHeader:SetText("CURRENT SETTING")
local decisionHeader = columnHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
decisionHeader:SetPoint("RIGHT", columnHeader, "RIGHT", -5, 0)
decisionHeader:SetText("BELONGS?")

local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -137)
scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 48)
local child = CreateFrame("Frame", nil, scroll)
child:SetWidth(FRAME_WIDTH - 58)
child:SetHeight(1)
scroll:SetScrollChild(child)

local exportFrame = CreateFrame("Frame", "PulseProfileReviewExportFrame", UIParent, "BackdropTemplate")
exportFrame:SetSize(620, 440)
exportFrame:SetPoint("CENTER")
exportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
exportFrame:SetBackdrop(BACKDROP_DIALOG_32_32)
exportFrame:Hide()
local exportTitle = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
exportTitle:SetPoint("TOP", exportFrame, "TOP", 0, -15)
exportTitle:SetText("Profile review export")
local exportHelp = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportHelp:SetPoint("TOP", exportTitle, "BOTTOM", 0, -7)
exportHelp:SetText("Select the text and copy it. Paste into a .md file or coding-agent prompt.")
local exportClose = makeButton(exportFrame, "Close", 80, 22)
exportClose:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 13)
exportClose:SetScript("OnClick", function()
	exportFrame:Hide()
end)
local exportScroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 18, -62)
exportScroll:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -32, 46)
local exportBox = CreateFrame("EditBox", nil, exportScroll)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetFontObject("GameFontHighlightSmall")
exportBox:SetWidth(555)
exportBox:SetScript("OnEscapePressed", function()
	exportFrame:Hide()
end)
exportScroll:SetScrollChild(exportBox)

local function decisionCount(profileName, triggers)
	local yes, no, pending = 0, 0, 0
	for _, trigger in ipairs(triggers) do
		local decision = reviewEntry(profileName, trigger.id).decision
		if decision == "yes" then
			yes = yes + 1
		elseif decision == "no" then
			no = no + 1
		else
			pending = pending + 1
		end
	end
	return yes, no, pending
end

local function refresh()
	local p = pulse()
	if not p or not p.Registry then
		return
	end
	local profileName = profiles[selectedProfile]
	if not profileName then
		return
	end
	local liveName = activeProfileName()
	profileLabel:SetText(("Reviewing: %s"):format(profileName))
	activeLabel:SetText(("Active in-game profile: %s"):format(liveName))
	local triggers = {}
	for _, category in ipairs(p.Registry:GetCategories()) do
		for _, trigger in ipairs(p.Registry:GetTriggersByCategory(category)) do
			triggers[#triggers + 1] = trigger
		end
	end
	local yes, no, pending = decisionCount(profileName, triggers)
	summary:SetText(
		("Review decisions: %d Yes · %d No · %d not reviewed | Current setting below is read-only."):format(
			yes,
			no,
			pending
		)
	)

	for _, row in ipairs(rows) do
		row:Hide()
	end
	wipe(rows)
	-- Category headings are regions on the scroll child; hide old ones before rebuilding.
	for _, region in ipairs({ child:GetRegions() }) do
		region:Hide()
	end
	local y = 0
	local function addHeader(category)
		local h = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h:SetPoint("TOPLEFT", child, "TOPLEFT", 5, -y)
		h:SetText(p.Registry:GetCategoryLabel(category))
		h:SetHeight(22)
		y = y + 23
	end
	local function addRow(trigger)
		local row = CreateFrame("Frame", nil, child)
		row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		row:SetSize(FRAME_WIDTH - 60, ROW_HEIGHT)
		row:EnableMouse(true)
		if #rows % 2 == 1 then
			local bg = row:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(1, 1, 1, 0.035)
		end
		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", row, "LEFT", 6, 0)
		label:SetWidth(350)
		label:SetJustifyH("LEFT")
		label:SetText((trigger.label or trigger.id) .. "  |cff777777(" .. trigger.id .. ")|r")
		if trigger.desc then
			row:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(trigger.label or trigger.id, 1, 1, 1)
				GameTooltip:AddLine(trigger.desc, nil, nil, nil, true)
				if trigger.caveat then
					GameTooltip:AddLine(trigger.caveat, 1, 0.75, 0.25, true)
				end
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", hideTooltip)
		end

		local prof = savedProfile(profileName)
		local currentOn = prof and prof.triggers and prof.triggers[trigger.id] == true
		local current = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		current:SetPoint("RIGHT", row, "RIGHT", -170, 0)
		current:SetWidth(93)
		current:SetJustifyH("CENTER")
		current:SetText(currentOn and "|cff44dd66On|r" or "|cffff6666Off|r")

		local entry = reviewEntry(profileName, trigger.id)
		local yesButton = makeButton(row, "Yes", 46, 19)
		yesButton:SetPoint("RIGHT", row, "RIGHT", -61, 0)
		local noButton = makeButton(row, "No", 46, 19)
		noButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		if entry.decision == "yes" then
			yesButton:SetText("✓ Yes")
		elseif entry.decision == "no" then
			noButton:SetText("✓ No")
		end
		local function setDecision(decision)
			entry.decision = decision
			entry.reviewedAt = date("%Y-%m-%d %H:%M")
			refresh()
		end
		yesButton:SetScript("OnClick", function()
			setDecision("yes")
		end)
		noButton:SetScript("OnClick", function()
			setDecision("no")
		end)
		rows[#rows + 1] = row
		row:Show()
		y = y + ROW_HEIGHT
	end
	for _, category in ipairs(p.Registry:GetCategories()) do
		local categoryTriggers = p.Registry:GetTriggersByCategory(category)
		if #categoryTriggers > 0 then
			addHeader(category)
			for _, trigger in ipairs(categoryTriggers) do
				addRow(trigger)
			end
		end
	end
	child:SetHeight(math.max(y, 1))
end

local function buildProfileList()
	local names = profileNames()
	if not names or #names == 0 then
		return false
	end
	profiles = names
	selectedProfile = math.min(selectedProfile, #profiles)
	if not built then
		local active = activeProfileName()
		for i, name in ipairs(profiles) do
			if name == active then
				selectedProfile = i
				break
			end
		end
	end
	return true
end

prevButton:SetScript("OnClick", function()
	selectedProfile = selectedProfile - 1
	if selectedProfile < 1 then
		selectedProfile = #profiles
	end
	refresh()
end)
nextButton:SetScript("OnClick", function()
	selectedProfile = selectedProfile + 1
	if selectedProfile > #profiles then
		selectedProfile = 1
	end
	refresh()
end)

allYesButton:SetScript("OnClick", function()
	local p = pulse()
	local profileName = profiles[selectedProfile]
	if not p or not p.Registry or not profileName then
		return
	end
	local nowStr = date("%Y-%m-%d %H:%M")
	for _, category in ipairs(p.Registry:GetCategories()) do
		for _, trigger in ipairs(p.Registry:GetTriggersByCategory(category)) do
			local entry = reviewEntry(profileName, trigger.id)
			entry.decision = "yes"
			entry.reviewedAt = nowStr
		end
	end
	refresh()
end)
allYesButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Mark All as Yes", 1, 1, 1)
	GameTooltip:AddLine("Set all cue review decisions for this profile to Yes.", nil, nil, nil, true)
	GameTooltip:Show()
end)
allYesButton:SetScript("OnLeave", hideTooltip)

allNoButton:SetScript("OnClick", function()
	local p = pulse()
	local profileName = profiles[selectedProfile]
	if not p or not p.Registry or not profileName then
		return
	end
	local nowStr = date("%Y-%m-%d %H:%M")
	for _, category in ipairs(p.Registry:GetCategories()) do
		for _, trigger in ipairs(p.Registry:GetTriggersByCategory(category)) do
			local entry = reviewEntry(profileName, trigger.id)
			entry.decision = "no"
			entry.reviewedAt = nowStr
		end
	end
	refresh()
end)
allNoButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Mark All as No", 1, 1, 1)
	GameTooltip:AddLine("Set all cue review decisions for this profile to No.", nil, nil, nil, true)
	GameTooltip:Show()
end)
allNoButton:SetScript("OnLeave", hideTooltip)

enableAllButton:SetScript("OnClick", function()
	local p = pulse()
	local profileName = profiles[selectedProfile]
	if not profileName then
		return
	end
	if p and p.Database and p.Database.SetAllCues then
		p.Database:SetAllCues(true, profileName)
	elseif PulseDB and PulseDB.profiles and PulseDB.profiles[profileName] then
		local prof = PulseDB.profiles[profileName]
		prof.triggers = prof.triggers or {}
		if p and p.Registry then
			for _, cat in ipairs(p.Registry:GetCategories()) do
				for _, tr in ipairs(p.Registry:GetTriggersByCategory(cat)) do
					prof.triggers[tr.id] = true
				end
			end
		end
	end
	print(("PulseProfileReview: enabled all cues in profile %s"):format(profileName))
	refresh()
end)
enableAllButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Enable All Cues (Debug)", 1, 1, 1)
	GameTooltip:AddLine("Directly turns ON all cues in this profile in PulseDB in one sweep.", nil, nil, nil, true)
	GameTooltip:Show()
end)
enableAllButton:SetScript("OnLeave", hideTooltip)

disableAllButton:SetScript("OnClick", function()
	local p = pulse()
	local profileName = profiles[selectedProfile]
	if not profileName then
		return
	end
	if p and p.Database and p.Database.SetAllCues then
		p.Database:SetAllCues(false, profileName)
	elseif PulseDB and PulseDB.profiles and PulseDB.profiles[profileName] then
		local prof = PulseDB.profiles[profileName]
		prof.triggers = prof.triggers or {}
		if p and p.Registry then
			for _, cat in ipairs(p.Registry:GetCategories()) do
				for _, tr in ipairs(p.Registry:GetTriggersByCategory(cat)) do
					prof.triggers[tr.id] = false
				end
			end
		end
	end
	print(("PulseProfileReview: disabled all cues in profile %s"):format(profileName))
	refresh()
end)
disableAllButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Disable All Cues (Debug)", 1, 1, 1)
	GameTooltip:AddLine(
		"Directly turns OFF all cues in this profile in PulseDB in one sweep (good for isolated testing).",
		nil,
		nil,
		nil,
		true
	)
	GameTooltip:Show()
end)
disableAllButton:SetScript("OnLeave", hideTooltip)

local function markdownEscape(s)
	return tostring(s or ""):gsub("|", "\\|"):gsub("\n", " ")
end

local function generateMarkdown()
	local p = pulse()
	local out = {
		"# Pulse profile cue review",
		"",
		"Generated: " .. date("%Y-%m-%d %H:%M"),
		"Active profile at export: " .. activeProfileName(),
		"Decisions are reviewer judgments and do not change Pulse settings.",
		"",
	}
	for _, profileName in ipairs(profiles) do
		local prof = savedProfile(profileName)
		out[#out + 1] = "## " .. profileName
		out[#out + 1] = ""
		out[#out + 1] = "| Cue ID | Cue | Current setting | Belongs? | Last reviewed |"
		out[#out + 1] = "|---|---|---:|---|---|"
		for _, category in ipairs(p.Registry:GetCategories()) do
			for _, trigger in ipairs(p.Registry:GetTriggersByCategory(category)) do
				local entry = reviewEntry(profileName, trigger.id)
				local enabled = prof and prof.triggers and prof.triggers[trigger.id] == true
				local decision = entry.decision == "yes" and "Yes" or entry.decision == "no" and "No" or "Not reviewed"
				out[#out + 1] = table.concat({
					"| " .. markdownEscape(trigger.id),
					markdownEscape(trigger.label or trigger.id),
					enabled and "On" or "Off",
					decision,
					markdownEscape(entry.reviewedAt or "—") .. " |",
				}, " | ")
			end
		end
		out[#out + 1] = ""
	end
	return table.concat(out, "\n")
end

local function showExport()
	exportBox:SetText(generateMarkdown())
	exportBox:SetHeight(math.max(350, exportBox:GetStringHeight() + 12))
	exportFrame:Show()
	exportBox:SetFocus()
	exportBox:HighlightText()
end
exportButton:SetScript("OnClick", showExport)

local function initialize()
	if not (_G.Pulse and _G.Pulse.Registry and _G.Pulse.Database) then
		print("PulseProfileReview: PulseHaptics is not loaded. Enable it in the AddOns list.")
		return false
	end
	if not buildProfileList() then
		print("PulseProfileReview: Pulse has not finished loading its profiles yet.")
		return false
	end
	refresh()
	built = true
	return true
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:SetScript("OnEvent", function(_, _, loadedName)
	if loadedName ~= ADDON_NAME then
		return
	end
	_G.PulseProfileReviewDB = _G.PulseProfileReviewDB or { version = 1, reviews = {} }
	db = _G.PulseProfileReviewDB
	db.reviews = db.reviews or {}
end)

SLASH_PULSEPROFILEREVIEW1 = "/pulsereview"
SLASH_PULSEPROFILEREVIEW2 = "/prreview"
SlashCmdList.PULSEPROFILEREVIEW = function(message)
	if not db then
		print("PulseProfileReview: waiting for addon initialization.")
		return
	end
	if not built and not initialize() then
		return
	end
	local command = string.lower(trim(message))
	if command == "export" then
		showExport()
		return
	end
	if frame:IsShown() then
		frame:Hide()
	else
		-- Keep the selected review profile, but refresh the live setting and active-profile label.
		buildProfileList()
		refresh()
		frame:Show()
	end
end
