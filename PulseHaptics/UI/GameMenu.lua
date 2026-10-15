-- Pulse — UI/GameMenu.lua
--
-- Integration into Blizzard's Game Menu (Escape Menu).
-- Injects a dedicated Pulse Haptics button at the lowermost position of GameMenuFrame,
-- accompanied by a direct controller shortcut (PADBACK / PAD4) while the menu is open.
--
-- Taint-free execution: Uses HookScript, operates strictly out of combat, and preserves
-- Blizzard button chain integrity.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local GameMenu = {}
Pulse.UI.GameMenu = GameMenu

local menuBtn
local heightAdjusted = false
local injectedThisShow = false

local function onClick()
	if InCombatLockdown and InCombatLockdown() then
		print("|cffff5555Pulse:|r Cannot open settings during combat.")
		return
	end
	if HideUIPanel and GameMenuFrame then
		HideUIPanel(GameMenuFrame)
	elseif GameMenuFrame then
		GameMenuFrame:Hide()
	end
	if Pulse.UI and Pulse.UI.Panel and Pulse.UI.Panel.Toggle then
		Pulse.UI.Panel.Toggle()
	end
end

local function onGameMenuShow(frame)
	if (InCombatLockdown and InCombatLockdown()) or injectedThisShow then
		return
	end
	if not menuBtn then
		return
	end

	-- Identify the lowermost anchor: prefer GameMenuButtonQuit (with Continue pushed down)
	-- or GameMenuButtonContinue / GameMenuButtonLogout / GameMenuButtonAddons
	local quitBtn = _G.GameMenuButtonQuit
	local continueBtn = _G.GameMenuButtonContinue
	local anchor = quitBtn
		or continueBtn
		or _G.GameMenuButtonLogout
		or _G.GameMenuButtonAddons
		or _G.GameMenuButtonOptions

	if not anchor then
		return
	end

	menuBtn:SetWidth(anchor:GetWidth() or 144)
	menuBtn:ClearAllPoints()

	if quitBtn and continueBtn and continueBtn:GetParent() == frame then
		-- Position between Quit and Continue (lowermost option in the menu list)
		menuBtn:SetPoint("TOP", quitBtn, "BOTTOM", 0, -1)
		menuBtn:Show()

		continueBtn:ClearAllPoints()
		continueBtn:SetPoint("TOP", menuBtn, "BOTTOM", 0, -16)
	elseif continueBtn and continueBtn:GetParent() == frame then
		-- Lowermost at the absolute bottom below Continue
		menuBtn:SetPoint("TOP", continueBtn, "BOTTOM", 0, -1)
		menuBtn:Show()
	else
		menuBtn:SetPoint("TOP", anchor, "BOTTOM", 0, -1)
		menuBtn:Show()
	end

	if not heightAdjusted and frame.GetHeight and frame.SetHeight then
		frame:SetHeight(frame:GetHeight() + 24)
		heightAdjusted = true
	end

	injectedThisShow = true
end

local function onGameMenuHide()
	injectedThisShow = false
end

local function hookGamepadListener()
	if not GameMenuFrame then
		return
	end

	if GameMenuFrame.EnableGamePadButton then
		pcall(GameMenuFrame.EnableGamePadButton, GameMenuFrame, true)
	end

	if GameMenuFrame.HookScript then
		GameMenuFrame:HookScript("OnGamePadButtonDown", function(_, button)
			if InCombatLockdown and InCombatLockdown() then
				return
			end
			-- PADBACK (View/Select) or PAD4 (Y/Triangle) opens Pulse Haptics settings
			if button == "PADBACK" or button == "PAD4" then
				if HideUIPanel then
					HideUIPanel(GameMenuFrame)
				else
					GameMenuFrame:Hide()
				end
				if Pulse.UI and Pulse.UI.Panel and Pulse.UI.Panel.Toggle then
					Pulse.UI.Panel.Toggle()
				end
			end
		end)
	end
end

function GameMenu:Init()
	if not GameMenuFrame or menuBtn then
		return
	end

	-- Create the injected button inside GameMenuFrame
	local btn = CreateFrame("Button", "GameMenuButtonPulse", GameMenuFrame, "UIPanelButtonTemplate")
	btn:SetSize(144, 21)
	btn:SetText("|cff4cb8ffPulse Haptics|r")

	if Pulse.UI and Pulse.UI.Panel and Pulse.UI.Panel.Theme and Pulse.UI.Panel.Theme.StyleActionButton then
		Pulse.UI.Panel.Theme.StyleActionButton(btn, false)
	end

	btn:SetScript("OnClick", onClick)
	menuBtn = btn

	if GameMenuFrame.HookScript then
		GameMenuFrame:HookScript("OnShow", onGameMenuShow)
		GameMenuFrame:HookScript("OnHide", onGameMenuHide)
	end

	hookGamepadListener()

	if GameMenuFrame:IsShown() then
		onGameMenuShow(GameMenuFrame)
	end
end
