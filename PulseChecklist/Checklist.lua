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

local FRAME_WIDTH  = 620
local FRAME_HEIGHT = 480
local ROW_HEIGHT   = 24
local HEADER_HEIGHT = 22

-- Cycle order: untested is the honest default for anything nobody's touched yet, distinct
-- from actually confirming it works — a fresh install shouldn't silently read as "all
-- functioning" just because that happened to be first in the list.
local STATUS_ORDER = { "untested", "functioning", "needswork", "nonfunctioning" }
local STATUS_INFO = {
    untested       = { label = "Untested",        r = 0.6,  g = 0.6,  b = 0.6  },
    functioning    = { label = "Functioning",     r = 0.25, g = 0.85, b = 0.25 },
    needswork      = { label = "Needs work",      r = 0.95, g = 0.8,  b = 0.15 },
    nonfunctioning = { label = "Non-functioning", r = 0.95, g = 0.3,  b = 0.3  },
}

local function nextStatus(current)
    for i, status in ipairs(STATUS_ORDER) do
        if status == current then
            return STATUS_ORDER[(i % #STATUS_ORDER) + 1]
        end
    end
    return STATUS_ORDER[1]
end

local function ensureEntry(triggerID)
    PulseChecklistDB[triggerID] = PulseChecklistDB[triggerID] or { status = "untested", comment = "" }
    local entry = PulseChecklistDB[triggerID]
    if not STATUS_INFO[entry.status] then entry.status = "untested" end -- guard against a stale/renamed status
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
        name  = name,
        realm = realm,
        class = class,
        when  = date("%Y-%m-%d"),
    }
end

local function isSameCharacter(stamp)
    if not stamp then return true end -- nothing recorded, so nothing to disagree with
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
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("Pulse Checklist")

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

local filterBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
filterBox:SetSize(240, 20)
filterBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -40)
filterBox:SetAutoFocus(false)
filterBox:SetScript("OnEscapePressed", filterBox.ClearFocus)

local filterHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
filterHint:SetPoint("LEFT", filterBox, "RIGHT", 8, 0)
filterHint:SetText("filter by id/label/category")

local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -44)

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

    local statusButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    statusButton:SetSize(96, ROW_HEIGHT - 4)
    statusButton:SetPoint("LEFT", row, "LEFT", 0, 0)

    local idLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    idLabel:SetPoint("LEFT", statusButton, "RIGHT", 8, 0)
    idLabel:SetWidth(190)
    idLabel:SetJustifyH("LEFT")
    idLabel:SetText(trigger.id .. (trigger.label and ("  |cff888888(" .. trigger.label .. ")|r") or ""))

    local commentBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    commentBox:SetSize(row:GetWidth() - 96 - 8 - 190 - 16, ROW_HEIGHT - 6)
    commentBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)
    commentBox:SetAutoFocus(false)
    commentBox:SetMaxLetters(120)

    local function refreshStatus()
        local entry = ensureEntry(trigger.id)
        local info = STATUS_INFO[entry.status]
        -- A trailing dot rather than a second column: the row is already three controls
        -- wide and the comment box is the one that wants the space. Only the surprising
        -- case is marked — a status this character could not have set itself.
        local elsewhere = entry.status ~= "untested" and not isSameCharacter(entry.confirmedBy)
        statusButton:SetText(info.label .. (elsewhere and " |cff888888\194\183|r" or ""))
        statusButton:GetFontString():SetTextColor(info.r, info.g, info.b)
    end

    statusButton:SetScript("OnClick", function()
        local entry = ensureEntry(trigger.id)
        entry.status = nextStatus(entry.status)
        stampEntry(entry)
        refreshStatus()
    end)

    -- The full attribution lives in the tooltip, so it costs no row width.
    statusButton:SetScript("OnEnter", function(self)
        local entry = ensureEntry(trigger.id)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(trigger.id, 1, 1, 1)
        local stamp = entry.confirmedBy
        if entry.status == "untested" then
            GameTooltip:AddLine("Not tested yet.", 0.6, 0.6, 0.6)
        elseif not stamp then
            GameTooltip:AddLine("Set before this build recorded who did it.", 0.6, 0.6, 0.6)
        else
            GameTooltip:AddLine(("%s set this on %s-%s (%s) on %s."):format(
                STATUS_INFO[entry.status].label, tostring(stamp.name), tostring(stamp.realm),
                tostring(stamp.class), tostring(stamp.when)), 0.6, 0.6, 0.6)
            if not isSameCharacter(stamp) then
                GameTooltip:AddLine("Not this character — some cues only fire for the right class or spec.",
                    0.95, 0.8, 0.15, true)
            end
        end
        GameTooltip:Show()
    end)
    statusButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function commitComment()
        ensureEntry(trigger.id).comment = commentBox:GetText()
    end
    commentBox:SetScript("OnEnterPressed", function(self)
        commitComment()
        self:ClearFocus()
    end)
    commentBox:SetScript("OnEditFocusLost", commitComment)
    commentBox:SetScript("OnEscapePressed", commentBox.ClearFocus)

    local entry = ensureEntry(trigger.id)
    commentBox:SetText(entry.comment or "")
    refreshStatus()

    local searchText = string.lower(trigger.id .. " " .. (trigger.label or ""))
    return { kind = "row", frame = row, triggerID = trigger.id, searchText = searchText,
             refreshStatus = refreshStatus }
end

local function buildEntries()
    for _, entry in ipairs(entries) do entry.frame:Hide() end
    entries = {}

    local P = _G.Pulse
    if not P or not P.Registry then return end

    for _, category in ipairs(P.Registry:GetCategories()) do
        local triggers = P.Registry:GetTriggersByCategory(category)
        if #triggers > 0 then
            entries[#entries + 1] = createHeader(P.Registry:GetCategoryLabel(category))
            for _, trigger in ipairs(triggers) do
                entries[#entries + 1] = createRow(trigger)
            end
        end
    end
end

-- Re-lays out every entry top to bottom, skipping (and hiding) anything the current
-- filter excludes. Three passes, deliberately not combined into one: a row is visible if
-- EITHER its own id/label matches OR its enclosing category's own label matches (the
-- "filter by id/label/category" the UI hint promises), and a header is visible if it
-- matches itself OR at least one of its own rows will show — both of those need every
-- row's match state decided first, which a single top-to-bottom pass can't do since a
-- header appears before the rows whose visibility could make IT visible.
local function relayout()
    local query = string.lower(filterBox:GetText() or "")

    local currentCategoryMatches = true
    for _, entry in ipairs(entries) do
        if entry.kind == "header" then
            entry.selfMatches = (query == "") or entry.searchText:find(query, 1, true) ~= nil
            currentCategoryMatches = entry.selfMatches
            entry.anyChildVisible = false
        else
            entry.visible = currentCategoryMatches
                or entry.searchText:find(query, 1, true) ~= nil
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
-- Load / slash command
---------------------------------------------------------------------------

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then return end
    PulseChecklistDB = PulseChecklistDB or {}
    -- Built lazily on first open (SLASH handler below), not here — Pulse's own
    -- ADDON_LOADED handler (Core/Init.lua) hasn't necessarily populated Pulse.Registry by
    -- the moment this addon's ADDON_LOADED fires, since load order between two separate
    -- addons isn't guaranteed just because one names the other in Dependencies.
    self:UnregisterEvent("ADDON_LOADED")
end)

local builtOnce = false

SLASH_PULSECHECKLIST1 = "/pulsecheck"
SLASH_PULSECHECKLIST2 = "/pcheck"
SlashCmdList["PULSECHECKLIST"] = function()
    if frame:IsShown() then
        frame:Hide()
        return
    end
    if not builtOnce then
        if not (_G.Pulse and _G.Pulse.Registry) then
            print("PulseChecklist: Pulse is not loaded. Check the AddOns list at character select.")
            return
        end
        buildEntries()
        relayout()
        builtOnce = true
    end
    frame:Show()
end
