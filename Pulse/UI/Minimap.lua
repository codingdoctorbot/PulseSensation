-- Pulse — UI/Minimap.lua
--
-- Dedicated, taint-free minimap button launcher and LibDataBroker-1.1 provider.
-- Left-click toggles Pulse settings, right-click toggles master vibration.
-- Drag with LeftButton moves the icon smoothly around the minimap perimeter.
-- Position and visibility are persisted in PulseDB.minimap.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local MinimapButton = {}
Pulse.UI.Minimap = MinimapButton

local ldbObj = nil
local buttonFrame = nil
local isDragging = false
local lastToggleTime = 0
local TOGGLE_DEBOUNCE = 0.3

-- ── Math & Position helpers ───────────────────────────────────────────────────

local function getRadius()
	if not Minimap then
		return 80
	end
	local width = Minimap:GetWidth() or 140
	if not width or width <= 0 then
		width = 140
	end
	return (width / 2) + 6
end

local function updateButtonPosition(angle)
	if not buttonFrame or not Minimap then
		return
	end
	local radius = getRadius()
	local rad = math.rad(angle or 225)
	local cos, sin = math.cos(rad), math.sin(rad)
	local x = cos * radius
	local y = sin * radius
	buttonFrame:ClearAllPoints()
	buttonFrame:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- ── Tooltip ───────────────────────────────────────────────────────────────────

local function showTooltip(owner)
	if isDragging then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Pulse Haptics", 0.30, 0.72, 1.00)

	local master = Pulse.Database:Get("masterEnabled")
	local statusText = master and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
	GameTooltip:AddLine(("Status: %s"):format(statusText), 1, 1, 1)

	local profileName = Pulse.Database:GetActiveProfileName() or "Default"
	if Pulse.Database.HasPendingProfileSwitch and Pulse.Database:HasPendingProfileSwitch() then
		GameTooltip:AddLine(
			("Active Profile: |cffffd100%s|r |cffff8800(Pending exit from combat)|r"):format(profileName),
			1,
			1,
			1
		)
	else
		GameTooltip:AddLine(("Active Profile: |cffffd100%s|r"):format(profileName), 1, 1, 1)
	end

	local schema = Pulse.Database:Get("defaultHapticSchema") or "standard"
	GameTooltip:AddLine(("Vibration Schema: |cffffd100%s|r"):format(schema), 1, 1, 1)

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("|cff00ff00Left-Click:|r Open Settings", 0.85, 0.85, 0.85)
	GameTooltip:AddLine("|cff00ff00Right-Click:|r Toggle Master On/Off", 0.85, 0.85, 0.85)
	GameTooltip:AddLine("|cff888888Drag:|r Move Icon", 0.70, 0.70, 0.70)
	GameTooltip:Show()
end

-- ── Action Handlers ───────────────────────────────────────────────────────────

local function toggleMasterEnabled(owner)
	local now = GetTime()
	if (now - lastToggleTime) < TOGGLE_DEBOUNCE then
		return
	end
	lastToggleTime = now

	-- In-combat protection: changing master state unregisters/registers events across 22 modules
	if InCombatLockdown and InCombatLockdown() then
		if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cff00bfff[Pulse]|r Cannot toggle master haptics while in combat.",
				1,
				0.3,
				0.3
			)
		end
		return
	end

	local current = Pulse.Database:Get("masterEnabled")
	Pulse.Database:Set("masterEnabled", not current)

	if owner and GameTooltip:GetOwner() == owner then
		showTooltip(owner)
	end
end

-- ── Frame Construction ────────────────────────────────────────────────────────

local function createMinimapButton()
	if buttonFrame then
		return buttonFrame
	end
	if not Minimap then
		return nil
	end

	-- Parent to Minimap matching standard Classic addon minimap buttons
	local btn = CreateFrame("Button", "PulseMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel((Minimap:GetFrameLevel() or 8) + 5)
	btn:RegisterForClicks("anyUp")
	btn:RegisterForDrag("LeftButton")

	-- Prevent click-through and motion propagation to Minimap underneath (PingLocation protection)
	if btn.SetPropagateMouseClicks then
		btn:SetPropagateMouseClicks(false)
	end
	if btn.SetPropagateMouseMotion then
		btn:SetPropagateMouseMotion(false)
	end
	btn:SetScript("OnMouseDown", function() end)
	btn:SetScript("OnMouseUp", function() end)

	-- Out of SmartNavigation: gamepad stick navigation must not try to target the minimap icon
	if Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.MarkIgnored then
		Pulse.UI.Panel.Theme.MarkIgnored(btn)
	end

	-- 1. Dark circular backing (authentic Classic offset)
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetVertexColor(0, 0, 0, 0.85)
	btn.Background = bg

	-- 2. Icon artwork (Spell_Nature_WispSplode) with coordinate crop
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
	icon:SetTexture("Interface\\Icons\\Spell_Nature_WispSplode")
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	btn.Icon = icon

	-- 3. Classic golden minimap tracking border
	-- The circular aperture in MiniMap-TrackingBorder naturally clips and frames the square icon
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	btn.Border = border

	-- 4. Hover highlight
	local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetSize(24, 24)
	highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 5, -4)
	highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	highlight:SetBlendMode("ADD")
	btn.Highlight = highlight

	-- Scripts
	btn:SetScript("OnEnter", function(self)
		showTooltip(self)
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	btn:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			toggleMasterEnabled(self)
		else
			if Pulse.UI.Panel and Pulse.UI.Panel.Toggle then
				Pulse.UI.Panel.Toggle()
			elseif Pulse.UI.Panel and Pulse.UI.Panel.Open then
				Pulse.UI.Panel.Open()
			end
		end
	end)

	-- Dragging around Minimap circumference (zero DB writes during drag, persists once on drop)
	local getCursor = _G.GetCursorPosition
	local currentAngle = nil

	btn:SetScript("OnDragStart", function(self)
		isDragging = true
		GameTooltip:Hide()
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			if not mx or not my or not getCursor then
				return
			end
			local cx, cy = getCursor()
			local scale = Minimap:GetEffectiveScale() or 1
			cx, cy = cx / scale, cy / scale
			currentAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
			updateButtonPosition(currentAngle)
		end)
	end)

	btn:SetScript("OnDragStop", function(self)
		isDragging = false
		self:SetScript("OnUpdate", nil)
		if currentAngle then
			local cfg = Pulse.Database:Get("minimap") or {}
			cfg.minimapPos = currentAngle
			Pulse.Database:Set("minimap", cfg)
		end
	end)

	-- Synchronize button visibility with Minimap shown/hidden state
	if Minimap.HookScript then
		Minimap:HookScript("OnShow", function()
			local cfg = Pulse.Database:Get("minimap") or {}
			if not cfg.hide and buttonFrame then
				buttonFrame:Show()
			end
		end)
		Minimap:HookScript("OnHide", function()
			if buttonFrame then
				buttonFrame:Hide()
			end
		end)
	end

	buttonFrame = btn
	return btn
end

-- ── LibDataBroker Integration ─────────────────────────────────────────────────

local function initLDB()
	if ldbObj then
		return ldbObj
	end
	local libStub = _G.LibStub
	local ldb = libStub and libStub("LibDataBroker-1.1", true)
	if not ldb then
		return nil
	end

	ldbObj = ldb:NewDataObject("Pulse", {
		type = "launcher",
		text = "Pulse",
		icon = "Interface\\Icons\\Spell_Nature_WispSplode",
		OnClick = function(_, button)
			if button == "RightButton" then
				toggleMasterEnabled(nil)
			else
				if Pulse.UI.Panel and Pulse.UI.Panel.Toggle then
					Pulse.UI.Panel.Toggle()
				elseif Pulse.UI.Panel and Pulse.UI.Panel.Open then
					Pulse.UI.Panel.Open()
				end
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then
				return
			end
			tooltip:AddLine("Pulse Haptics", 0.30, 0.72, 1.00)
			local master = Pulse.Database:Get("masterEnabled")
			local statusText = master and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
			tooltip:AddLine(("Status: %s"):format(statusText), 1, 1, 1)

			local profileName = Pulse.Database:GetActiveProfileName() or "Default"
			if Pulse.Database.HasPendingProfileSwitch and Pulse.Database:HasPendingProfileSwitch() then
				tooltip:AddLine(
					("Active Profile: |cffffd100%s|r |cffff8800(Pending exit from combat)|r"):format(profileName),
					1,
					1,
					1
				)
			else
				tooltip:AddLine(("Active Profile: |cffffd100%s|r"):format(profileName), 1, 1, 1)
			end

			local schema = Pulse.Database:Get("defaultHapticSchema") or "standard"
			tooltip:AddLine(("Vibration Schema: |cffffd100%s|r"):format(schema), 1, 1, 1)

			tooltip:AddLine(" ")
			tooltip:AddLine("|cff00ff00Left-Click:|r Open Settings", 0.85, 0.85, 0.85)
			tooltip:AddLine("|cff00ff00Right-Click:|r Toggle Master On/Off", 0.85, 0.85, 0.85)
		end,
	})
	return ldbObj
end

-- ── Public API ────────────────────────────────────────────────────────────────

function MinimapButton:Init()
	initLDB()

	local minimapConfig = Pulse.Database:Get("minimap")
	if not minimapConfig or type(minimapConfig) ~= "table" then
		minimapConfig = { hide = false, minimapPos = 225 }
		Pulse.Database:Set("minimap", minimapConfig)
	end

	createMinimapButton()
	self:Refresh()

	Pulse.Database:OnGlobalChanged("minimap", function()
		MinimapButton:Refresh()
	end)

	-- Settling listener: update position once world layout is finalized
	local loginFrame = CreateFrame("Frame")
	loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	loginFrame:SetScript("OnEvent", function(frame)
		frame:UnregisterAllEvents()
		MinimapButton:Refresh()
	end)
end

function MinimapButton:Refresh()
	local btn = createMinimapButton()
	if not btn then
		return
	end

	local cfg = Pulse.Database:Get("minimap") or {}
	if cfg.hide or (Minimap and not Minimap:IsShown()) then
		btn:Hide()
	else
		btn:Show()
		updateButtonPosition(cfg.minimapPos or 225)
	end
end

function MinimapButton:Toggle()
	local cfg = Pulse.Database:Get("minimap") or {}
	cfg.hide = not cfg.hide
	Pulse.Database:Set("minimap", cfg)
	self:Refresh()
end
