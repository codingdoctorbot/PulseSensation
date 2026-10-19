-- PulseComic — UI/Minimap.lua
--
-- Minimap button, ported from PulseHaptics' UI/Minimap.lua (without its LibDataBroker feed
-- and SmartNavigation hooks). Left-click toggles the settings window, right-click turns
-- PulseComic on or off, drag moves the button around the minimap. Position and visibility
-- live in PulseComicDB.minimap.

local ADDON_NAME, ns = ...

local MinimapButton = {}
ns.minimap = MinimapButton

local ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\pow"
local TOGGLE_DEBOUNCE = 0.3

local button
local isDragging = false
local lastToggleTime = 0

-- ── Position ──────────────────────────────────────────────────────────────────────────

local function getRadius()
	local width = Minimap:GetWidth()
	if not width or width <= 0 then
		width = 140
	end
	return (width / 2) + 6
end

local function updatePosition(angle)
	local radius = getRadius()
	local rad = math.rad(angle or 225)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

-- ── Tooltip ───────────────────────────────────────────────────────────────────────────

local function onOff(value)
	return value and "|cff00ff00on|r" or "|cffff0000off|r"
end

local function showTooltip(owner)
	if isDragging then
		return
	end
	local db = ns.db
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("PulseComic", 1.00, 0.84, 0.04)
	GameTooltip:AddLine("Status: " .. (db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"), 1, 1, 1)
	GameTooltip:AddLine("Killing-blow event: " .. onOff(db.killEvent), 1, 1, 1)
	GameTooltip:AddLine("Target death check: " .. onOff(db.killUnitDead), 1, 1, 1)
	GameTooltip:AddLine("Pet kills: " .. onOff(db.killPet) .. "   Kill log: " .. onOff(db.killLog), 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("|cff00ff00Left-Click:|r Open Settings", 0.85, 0.85, 0.85)
	GameTooltip:AddLine("|cff00ff00Right-Click:|r Toggle On/Off", 0.85, 0.85, 0.85)
	GameTooltip:AddLine("|cff888888Drag:|r Move Icon", 0.70, 0.70, 0.70)
	GameTooltip:Show()
end

-- ── Button ────────────────────────────────────────────────────────────────────────────

local function toggleEnabled(owner)
	local now = GetTime()
	if now - lastToggleTime < TOGGLE_DEBOUNCE then
		return
	end
	lastToggleTime = now
	ns.Toggle("enabled")
	ns.Say(ns.db.enabled and "enabled" or "disabled")
	if owner and GameTooltip:GetOwner() == owner then
		showTooltip(owner)
	end
end

local function create()
	local btn = CreateFrame("Button", "PulseComicMinimapButton", Minimap)
	btn:SetSize(32, 32)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel((Minimap:GetFrameLevel() or 8) + 5)
	btn:RegisterForClicks("anyUp")
	btn:RegisterForDrag("LeftButton")

	-- Keep clicks and motion from reaching the minimap underneath (no accidental pings).
	if btn.SetPropagateMouseClicks then
		btn:SetPropagateMouseClicks(false)
	end
	if btn.SetPropagateMouseMotion then
		btn:SetPropagateMouseMotion(false)
	end
	btn:SetScript("OnMouseDown", function() end)
	btn:SetScript("OnMouseUp", function() end)

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetVertexColor(0, 0, 0, 0.85)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	icon:SetTexture(ICON)

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetSize(22, 22)
	highlight:SetPoint("CENTER", btn, "CENTER", 0, 0)
	highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	highlight:SetBlendMode("ADD")

	btn:SetScript("OnEnter", showTooltip)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	btn:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			toggleEnabled(self)
		else
			ns.ui.Toggle()
		end
	end)

	-- Drag around the minimap's edge; one write on drop.
	local currentAngle
	btn:SetScript("OnDragStart", function(self)
		isDragging = true
		GameTooltip:Hide()
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			if not mx then
				return
			end
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale() or 1
			currentAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
			updatePosition(currentAngle)
		end)
	end)
	btn:SetScript("OnDragStop", function(self)
		isDragging = false
		self:SetScript("OnUpdate", nil)
		if currentAngle then
			ns.account.minimap.pos = currentAngle
		end
	end)

	-- Follow the minimap's own visibility.
	Minimap:HookScript("OnShow", function()
		MinimapButton:Refresh()
	end)
	Minimap:HookScript("OnHide", function()
		btn:Hide()
	end)

	return btn
end

-- ── Public ────────────────────────────────────────────────────────────────────────────

function MinimapButton:Init()
	if not Minimap then
		return
	end
	button = button or create()
	self:Refresh()

	-- The minimap's size can settle after ADDON_LOADED; place the button again once in world.
	local settle = CreateFrame("Frame")
	settle:RegisterEvent("PLAYER_ENTERING_WORLD")
	settle:SetScript("OnEvent", function(f)
		f:UnregisterAllEvents()
		MinimapButton:Refresh()
	end)
end

function MinimapButton:Refresh()
	if not button then
		return
	end
	local cfg = ns.account.minimap
	if cfg.hide or not Minimap:IsShown() then
		button:Hide()
	else
		button:Show()
		updatePosition(cfg.pos)
	end
end

function MinimapButton:SetShown(shown)
	ns.account.minimap.hide = not shown
	self:Refresh()
	if ns.ui.Refresh then
		ns.ui.Refresh()
	end
end

function MinimapButton:Toggle()
	self:SetShown(ns.account.minimap.hide)
end
