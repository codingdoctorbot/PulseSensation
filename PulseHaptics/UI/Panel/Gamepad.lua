-- Pulse — UI/Panel/Gamepad.lua
--
-- Controller navigation for Pulse's own settings window.
--
-- READ THE BLOCK BELOW FIRST. As of 2026-09-22 this file is mostly inert: the approach it
-- was built on — hand the window to Forever's frame-controls manager and let
-- SmartNavigation drive it, as Blizzard_SettingsPanel.lua:1162-1213 does — is unavailable
-- to an addon, because every route into it ends at a protected binding call.
-- DRIVE_BLIZZARD_NAVIGATION is off and the window is mouse-only until Pulse owns the input.
--
-- The shape it was built to, kept because the replacement wants the same one: the sidebar
-- is the main navigation group and the content container a named SUB-SECTION, so the two
-- are separate focus contexts. Right on a category enters the settings, B or the left edge
-- returns to the list; inside the content the D-pad moves between rows, the right stick
-- scrolls, and a selected slider or dropdown claims left and right.
--
-- Everything is guarded. Blizzard_GamepadSmartNavigation and Blizzard_GamepadSharedUtility
-- exist only on a client with gamepad UI; without them every function here is a no-op and
-- the panel is simply a mouse panel. Nothing here may be the reason a page fails to open.

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel

local Gamepad = {}
Panel.Gamepad = Gamepad

local FOCUS_KEY = "PulsePanelContent"

-- Driving Blizzard's navigation — OFF, 2026-09-22
--
-- CONFIRMED LIVE: "Pulse has been blocked from an action only available to the Blizzard
-- UI." The panel opened, settings changed, nothing crashed — the call was refused, not
-- fatal — but it fires on every open and means Blizzard's navigation never actually took
-- the window anyway.
--
-- THE PATH, traced in the Forever source rather than guessed:
--
--     Gamepad.OnShow
--       -> GamepadMode.FrameControlsManager:FrameShown(panel)
--            FrameControlsManager.lua:449  CheckForInputBinding(self)
--            FrameControlsManager.lua:111  GamepadMode.ActivateBindingGroup(...)
--            InputButtonBinding.lua:28     SetOverrideBindingClick(UIParent, ...)
--
-- SetOverrideBindingClick is protected. Everything on a call stack that started in Pulse is
-- tainted, so the client refuses it at the bottom. FocusFrame reaches the same place a
-- second way through EnableNavigation -> SmartNavigation:ActivateBinding, and the prompted
-- binding footers below end identically: CreatePromptedBindingFooter ->
-- Finalize/ShowAndActivateBindings -> the same protected call.
--
-- Modules/ControllerUI.lua records the same message from hooking ActivateRadial on
-- 2026-09-21, and the rule it bought applies here: where a choice exists, take the one that
-- does not call into Blizzard's machinery. Taint follows the stack and an addon cannot hand
-- the binding system a clean one, so Pulse does not call into it.
--
-- WHAT IS STILL ON, none of it able to taint anything: every SmartNavigation_Mark* call,
-- the jump-navigation overrides and the custom cursor anchors. Each writes one field on a
-- frame and returns, costs nothing while the flag is off, and is exactly what a Pulse-owned
-- navigation pass will want.
--
-- WHAT IS LOST until Pulse owns the input: the controller cannot move through this window
-- at all. A headline feature, off, stated plainly rather than left to be discovered. The
-- replacement is a frame's own OnGamePadButtonDown with EnableGamePadButton — both
-- CONFIRMED present in this client's generated API documentation
-- (SimpleFrameAPIDocumentation.lua:225 and :1424), both ordinary frame methods, neither
-- protected. That is a separate piece of work, not a flag flip.
--
-- Setting this back to true restores the old behaviour and the error with it.
local DRIVE_BLIZZARD_NAVIGATION = false

local panel -- the window, set by Gamepad.Init
local refreshPending = false

local function smartNav()
	return (type(SmartNavigation) == "table") and SmartNavigation or nil
end

function Gamepad.IsEnabled()
	return type(InputUtil) == "table"
		and type(InputUtil.IsGamepadUIEnabled) == "function"
		and InputUtil.IsGamepadUIEnabled()
end

-- ── Navigation targets inside the current page ────────────────────────────────

-- A checkbox or button row is a plain Frame whose inner widget is the target; a slider or
-- dropdown row is itself the target. Rows.lua explains the split.
local function navTargetOf(row)
	if not row or not row:IsShown() then
		return nil
	end
	if row.isHeader or row.isText then
		return nil
	end
	if row:IsObjectType("Button") then
		return row
	end
	return row.Control
end

local function firstNavTarget()
	local content = panel and panel.Content
	local page = content and content.page
	if not page or not page.rows then
		return nil
	end
	for _, row in ipairs(page.rows) do
		local target = navTargetOf(row)
		if target then
			return target
		end
	end
	return nil
end

local function lastNavTarget()
	local content = panel and panel.Content
	local page = content and content.page
	if not page or not page.rows then
		return nil
	end
	for index = #page.rows, 1, -1 do
		local target = navTargetOf(page.rows[index])
		if target then
			return target
		end
	end
	return nil
end

-- ── Focus group: sidebar ⇄ content ────────────────────────────────────────────

function Gamepad.FocusContent(button)
	if not DRIVE_BLIZZARD_NAVIGATION then
		return
	end
	local nav = smartNav()
	if not nav or not nav.IsInFocusGroup then
		return
	end
	if nav:IsInFocusGroup() then
		return
	end

	nav:EnterFocusGroup(FOCUS_KEY)
	if nav.activeInfo then
		button = button or panel.lastContentButton or firstNavTarget()
		panel.lastContentButton = nil
		if button then
			nav:SelectButton(button)
		end
	end
end

function Gamepad.UnfocusContent(button)
	if not DRIVE_BLIZZARD_NAVIGATION then
		return
	end
	local nav = smartNav()
	if not nav or not nav.IsInFocusGroup then
		return
	end
	if not nav:IsInFocusGroup() then
		return
	end

	if not button then
		button = panel.Sidebar and panel.Sidebar:GetSelectedButton()
	end
	panel.lastContentButton = nav:GetCurrentButton()
	nav:LeaveFocusGroup(button)
	return true
end

-- ── Prompted binding footers ──────────────────────────────────────────────────
--
-- Blizzard builds these once at file scope (Blizzard_SettingControls.lua:669-685). Lazy
-- here instead, because this addon loads before the gamepad addons are certain to be
-- present, and a player on mouse and keyboard should never pay for them.

local function createFooter(debugName, bindings)
	-- The reason this whole section is inert: Finalize and ShowAndActivateBindings both
	-- end at SetOverrideBindingClick. See the header.
	if not DRIVE_BLIZZARD_NAVIGATION then
		return false
	end
	if
		type(GamepadSharedUtility) ~= "table"
		or type(GamepadSharedUtility.CreatePromptedBindingFooter) ~= "function"
	then
		return false
	end
	local parent = UIParent or GlueParent
	if not parent then
		return false
	end

	local ok, footer = pcall(GamepadSharedUtility.CreatePromptedBindingFooter, parent, debugName)
	if not ok or not footer then
		return false
	end

	for _, binding in ipairs(bindings) do
		if binding.key then
			pcall(footer.AddFunctionBinding, footer, binding.key, binding.func)
		end
	end
	pcall(footer.Finalize, footer)
	return footer
end

local function currentRow()
	local nav = smartNav()
	return nav and nav.GetCurrentButton and nav:GetCurrentButton() or nil
end

-- Sliders: left and right step by the slider's own step size, through the same
-- OnStepperClicked the visible arrows use, so keyboard, mouse and stick all move by the
-- same amount.
local sliderFooter

local function stepSlider(forward)
	local row = currentRow()
	local slider = row and row.Control
	if slider and slider.OnStepperClicked then
		slider:OnStepperClicked(forward)
	end
end

local function getSliderFooter()
	if sliderFooter ~= nil then
		return sliderFooter
	end
	sliderFooter = createFooter("PulsePanelSlider", {
		{
			key = GAMEPAD_DPAD_LEFT,
			func = function()
				stepSlider(false)
			end,
		},
		{
			key = GAMEPAD_DPAD_RIGHT,
			func = function()
				stepSlider(true)
			end,
		},
	})
	return sliderFooter
end

function Gamepad.OnSliderSelected()
	local footer = getSliderFooter()
	if footer then
		pcall(footer.ShowAndActivateBindings, footer)
	end
end

function Gamepad.OnSliderDeselected()
	local footer = getSliderFooter()
	if footer then
		pcall(footer.HideAndDeactivateBindings, footer)
	end
end

-- Dropdowns: left and right step through the options without opening the list, and the
-- face buttons open it. Same mapping as Blizzard_SettingControls.lua:772-795.
local dropdownFooter

local function stepDropdown(increment)
	local row = currentRow()
	local control = row and row.Control
	if not control then
		return
	end
	if increment then
		if control.IncrementButton then
			control.IncrementButton:Click()
		elseif control.Increment then
			control:Increment()
		end
	else
		if control.DecrementButton then
			control.DecrementButton:Click()
		elseif control.Decrement then
			control:Decrement()
		end
	end
end

local function openDropdown()
	local row = currentRow()
	local dropdown = row and row.Dropdown
	if not dropdown then
		return
	end
	if dropdown.MouseDown then
		dropdown:MouseDown()
	end
	if dropdown.MouseUp then
		dropdown:MouseUp()
	end
end

local function getDropdownFooter()
	if dropdownFooter ~= nil then
		return dropdownFooter
	end
	dropdownFooter = createFooter("PulsePanelDropdown", {
		{
			key = GAMEPAD_DPAD_LEFT,
			func = function()
				stepDropdown(false)
			end,
		},
		{
			key = GAMEPAD_DPAD_RIGHT,
			func = function()
				stepDropdown(true)
			end,
		},
		{ key = GAMEPAD_FACE_TOP, func = openDropdown },
		{ key = GAMEPAD_FACE_BOTTOM, func = openDropdown },
	})
	return dropdownFooter
end

function Gamepad.OnDropdownSelected()
	local footer = getDropdownFooter()
	if footer then
		pcall(footer.ShowAndActivateBindings, footer)
	end
end

function Gamepad.OnDropdownDeselected()
	local footer = getDropdownFooter()
	if footer then
		pcall(footer.HideAndDeactivateBindings, footer)
	end
end

-- ── Refreshing the navigable set ──────────────────────────────────────────────

-- SmartNavigation caches the buttons it found when the panel opened
-- (SmartNavigation.lua:1523). Switching pages, filtering and greying a row all change that
-- set. Coalesced to one rebuild per frame, because a page switch fires this once for the
-- switch and again for the refresh pass that follows, and walking the frame tree twice for
-- one visible change is waste.
local function doRefresh()
	refreshPending = false
	if not DRIVE_BLIZZARD_NAVIGATION then
		return
	end
	if not panel or not panel:IsShown() then
		return
	end
	if not Gamepad.IsEnabled() then
		return
	end

	local nav = smartNav()
	if not nav then
		return
	end

	if nav.RefreshButtonGroups then
		pcall(nav.RefreshButtonGroups, nav, panel)
	end
	-- Which frame to scroll when the selection moves off screen, and right-stick
	-- scrolling. A plain ScrollFrame takes HandleScroll's simple SetVerticalScroll path —
	-- see Content.lua's header.
	if nav.SetScrollFrameForFrame and panel.Content then
		pcall(nav.SetScrollFrameForFrame, nav, panel, panel.Content.Scroll)
	end
end

function Gamepad.RefreshNavigation()
	if not DRIVE_BLIZZARD_NAVIGATION then
		return
	end
	if refreshPending then
		return
	end
	if not panel or not panel:IsShown() then
		return
	end
	if not Gamepad.IsEnabled() then
		return
	end
	refreshPending = true
	C_Timer.After(0, doRefresh)
end

-- ── Setup and lifecycle ───────────────────────────────────────────────────────

-- Static wiring, done once. Mirrors SettingsPanelMixin:SetupGamepad.
function Gamepad.Setup()
	if not panel then
		return
	end
	if panel.gamepadSetupDone then
		return
	end
	panel.gamepadSetupDone = true

	local Theme = Panel.Theme
	Theme.MarkIgnored(panel.CloseButton)
	Theme.MarkIgnored(panel.ClosePanelButton)
	-- The search box is deliberately out of the gamepad's reach. Blizzard's panel lets a
	-- stick land on it, but typing into an EditBox with a controller means the on-screen
	-- keyboard and a focus state handed back cleanly, and a filter box is not worth that
	-- surface. Mouse users keep it.
	if panel.SearchBox then
		Theme.MarkIgnored(panel.SearchBox)
	end

	if type(SmartNavigation_MarkFrameSubSection) == "function" then
		pcall(SmartNavigation_MarkFrameSubSection, panel.Container, FOCUS_KEY)
	end

	-- Right from a category enters its settings, and it is the only way in: a sub-section
	-- is not reachable by ordinary directional navigation.
	-- Blizzard_SettingsPanel.lua:1090-1095.
	if
		type(SmartNavigation_AddJumpNavigationOverride) == "function"
		and SMART_NAV_INPUT_DIRECTION
		and panel.Sidebar
	then
		for _, button in ipairs(panel.Sidebar.buttons) do
			pcall(SmartNavigation_AddJumpNavigationOverride, button, SMART_NAV_INPUT_DIRECTION.RIGHT, function()
				Gamepad.FocusContent()
				return true
			end)
		end
	end

	-- Down from the bottom of the list reaches the Close button; up from it comes back.
	if
		type(SmartNavigation_AddJumpNavigationOverride) == "function"
		and SMART_NAV_INPUT_DIRECTION
		and panel.CloseButton
	then
		pcall(SmartNavigation_AddJumpNavigationOverride, panel.CloseButton, SMART_NAV_INPUT_DIRECTION.UP, function()
			Gamepad.FocusContent(lastNavTarget())
			return true
		end)
	end

	-- B, or walking off the left edge of the settings, returns to the category list
	-- rather than closing the window.
	panel.SmartNavigationCloseHandler = function()
		return Gamepad.UnfocusContent()
	end
end

function Gamepad.OnShow()
	if not panel then
		return
	end
	if not Gamepad.IsEnabled() then
		return
	end

	-- Marking only. Cheap, taint-free, and what a Pulse-owned navigation pass will read.
	Gamepad.Setup()

	if not DRIVE_BLIZZARD_NAVIGATION then
		return
	end

	if type(GamepadMode) == "table" and GamepadMode.FrameControlsManager then
		pcall(function()
			GamepadMode.FrameControlsManager:FrameShown(panel)
		end)
	end

	local nav = smartNav()
	if nav and nav.RegisterCallback then
		-- Wrapped, not passed directly: a CallbackRegistry hands the owner to the callback
		-- as its first argument, and UnfocusContent's first argument is the button to select
		-- afterwards — passing it raw would ask it to select the window.
		pcall(nav.RegisterCallback, nav, "HitLeftEdge", function()
			Gamepad.UnfocusContent()
		end, panel)
		-- Point SmartNavigation at the selected category rather than whatever is top-left.
		if nav.SetSmartNavPanelInfoAddedCallback then
			pcall(nav.SetSmartNavPanelInfoAddedCallback, nav, panel, function()
				local button = panel.Sidebar and panel.Sidebar:GetSelectedButton()
				if button and nav.SetTargetButtonForFrame then
					pcall(nav.SetTargetButtonForFrame, nav, panel, button)
				end
			end)
		end
	end

	Gamepad.RefreshNavigation()
end

function Gamepad.OnHide()
	if not panel then
		return
	end
	if not DRIVE_BLIZZARD_NAVIGATION then
		return
	end

	local nav = smartNav()
	if nav and nav.UnregisterCallback then
		pcall(nav.UnregisterCallback, nav, "HitLeftEdge", panel)
	end

	-- Any legend still on screen belongs to a row that is no longer selectable.
	Gamepad.OnSliderDeselected()
	Gamepad.OnDropdownDeselected()

	if type(GamepadMode) == "table" and GamepadMode.FrameControlsManager then
		pcall(function()
			GamepadMode.FrameControlsManager:FrameHidden(panel)
		end)
	end
end

function Gamepad.Init(owner)
	panel = owner

	if not DRIVE_BLIZZARD_NAVIGATION then
		return
	end

	-- The client can switch between mouse and gamepad at runtime and InputUtil is how a
	-- frame asks to be told. Optional: without it, Setup still runs from OnShow.
	if type(InputUtil) == "table" then
		if type(InputUtil.RegisterForInterfaceTransitions) == "function" then
			pcall(InputUtil.RegisterForInterfaceTransitions, panel)
		end
		if type(InputUtil.RegisterGamepadSetup) == "function" then
			pcall(InputUtil.RegisterGamepadSetup, panel, Gamepad.Setup)
		end
		if type(InputUtil.RegisterGamepadInit) == "function" then
			pcall(InputUtil.RegisterGamepadInit, panel, function()
				if panel:IsShown() then
					Gamepad.OnShow()
				end
			end)
		end
	end
end
