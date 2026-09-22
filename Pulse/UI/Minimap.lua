-- Pulse — UI/Minimap.lua
--
-- Minimap icon launcher using LibDataBroker-1.1 and LibDBIcon-1.0.
-- Left-click toggles Pulse settings window, right-click toggles master haptics.
-- Position and visibility are persisted in PulseDB.minimap.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local Minimap = {}
Pulse.UI.Minimap = Minimap

local ldbObj = nil
local iconLib = nil

local function getIconLib()
	if not iconLib and _G.LibStub then
		iconLib = _G.LibStub("LibDBIcon-1.0", true)
	end
	return iconLib
end

local function getLDB()
	if _G.LibStub then
		return _G.LibStub("LibDataBroker-1.1", true)
	end
	return nil
end

function Minimap:Init()
	local ldb = getLDB()
	local icon = getIconLib()
	if not ldb or not icon then
		return
	end

	if not ldbObj then
		ldbObj = ldb:NewDataObject("Pulse", {
			type = "launcher",
			text = "Pulse",
			icon = "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
			OnClick = function(_, button)
				if button == "RightButton" then
					local current = Pulse.Database:Get("masterEnabled")
					Pulse.Database:Set("masterEnabled", not current)
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
	end

	local minimapConfig = Pulse.Database:Get("minimap")
	if not minimapConfig or type(minimapConfig) ~= "table" then
		minimapConfig = { hide = false }
		Pulse.Database:Set("minimap", minimapConfig)
	end

	if not icon:IsRegistered("Pulse") then
		icon:Register("Pulse", ldbObj, minimapConfig)
	end

	self:Refresh()

	Pulse.Database:OnGlobalChanged("minimap", function()
		Minimap:Refresh()
	end)
end

function Minimap:Refresh()
	local icon = getIconLib()
	if not icon or not icon:IsRegistered("Pulse") then
		return
	end
	local cfg = Pulse.Database:Get("minimap")
	if cfg and cfg.hide then
		icon:Hide("Pulse")
	else
		icon:Show("Pulse")
	end
end

function Minimap:Toggle()
	local cfg = Pulse.Database:Get("minimap") or {}
	cfg.hide = not cfg.hide
	Pulse.Database:Set("minimap", cfg)
	self:Refresh()
end
