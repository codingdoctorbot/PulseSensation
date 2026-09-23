-- Pulse — Modules/PlayerState.lua
--
-- Three small unrelated cues, none justifying a file: experience gained, a stealth texture,
-- and feedback when a confirmation popup appears. Grouped as "cheap things about the
-- player's own state" rather than pretending they share a mechanism. From
-- Cooking/Pulse_Ideas_for_Improvements.md §4 and §7 and the Integration doc's Group 7. All
-- three read only the player's own state: no restricted unit, no payload, no combat log.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("PlayerState", M)

-- Experience gained
--
-- Occurrence only. PLAYER_XP_UPDATE carries a unit token and nothing else worth reading;
-- the amount would need UnitXP diffing, and scaling by size is not worth the bookkeeping
-- for a near-subliminal cue. levelUp already exists and is much louder, so this stays quiet
-- enough not to compete with it.

local xpFrame = CreateFrame("Frame")

local function syncXP()
	xpFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("xpGained") then
		return
	end
	xpFrame:RegisterUnitEvent("PLAYER_XP_UPDATE", "player")
end

xpFrame:SetScript("OnEvent", function()
	Pulse:FireIfEnabled("xpGained")
end)

-- Stealth texture
--
-- A near-silent breathing wave while stealthed or invisible. Reads IsStealthed(), a plain
-- boolean about the player's own state — deliberately NOT an aura scan, which would be both
-- expensive and liable to return secret values.
--
-- The whole cue is: decide a baseline, hand it to Core/Waves.lua's Sine, keep the output
-- alive with MicroFlutter. That is the shape every new continuous cue should have.

local STEALTH_POLL = 0.1
local stealthFrame = CreateFrame("Frame")
local stealthElapsed = 0

local function isPlayerStealthed()
	if type(IsStealthed) ~= "function" then
		return false
	end
	local ok, stealthed = pcall(IsStealthed)
	return ok and stealthed or false
end

local function stealthTick(_, elapsed)
	stealthElapsed = stealthElapsed + elapsed
	if stealthElapsed < STEALTH_POLL then
		return
	end
	stealthElapsed = 0

	if not isPlayerStealthed() then
		stealthFrame:SetScript("OnUpdate", nil)
		return
	end

	local baseline = Pulse.Database:GetTriggerSetting("stealthTexture", "baseline", 0.06)
	local rate = Pulse.Database:GetTriggerSetting("stealthTexture", "breathRate", 0.30)
	local depth = Pulse.Database:GetTriggerSetting("stealthTexture", "breathDepth", 0.35)

	local value = Pulse.Waves.Sine(baseline, rate, depth)
	value = Pulse.Haptics.MicroFlutter(value)
	Pulse:HoldIfEnabled("stealthTexture", value, 0)
end

local function updateStealthState()
	if not Pulse.Database:Get("masterEnabled") or not Pulse.Database:GetCue("stealthTexture") then
		stealthFrame:SetScript("OnUpdate", nil)
		return
	end
	if isPlayerStealthed() then
		stealthElapsed = 0
		stealthFrame:SetScript("OnUpdate", stealthTick)
	else
		stealthFrame:SetScript("OnUpdate", nil)
	end
end

stealthFrame:SetScript("OnEvent", function()
	updateStealthState()
end)

local function syncStealth()
	stealthFrame:UnregisterAllEvents()
	stealthFrame:SetScript("OnUpdate", nil)
	stealthElapsed = 0
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("stealthTexture") then
		return
	end
	stealthFrame:RegisterEvent("UPDATE_STEALTH")
	stealthFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	updateStealthState()
end

-- Confirmation popups
--
-- A modal appearing is exactly what a controller player misses, their eyes not being on
-- the corner of the screen where it lands.
--
-- POLLED, NOT HOOKED, and that is the important decision. hooksecurefunc("StaticPopup_Show")
-- is the obvious implementation and the wrong one: it is a plain global called from all
-- over Blizzard's UI, often from code that goes on to touch protected frames, and this
-- addon already has one documented taint incident from that shape (Modules/ControllerUI.lua
-- on ActivateRadial). The rule that incident bought — only hook a Blizzard function whose
-- caller does nothing protected afterwards — rules it out. Reading IsShown() four times a
-- second taints nothing.

local POPUP_POLL = 0.25
local POPUP_FRAMES = 4 -- StaticPopup1..4, Blizzard's own pool size
local popupFrame = CreateFrame("Frame")
local popupElapsed = 0
local popupWasShown = false
local staticPopups = nil

local function getStaticPopups()
	if not staticPopups then
		staticPopups = {}
		for index = 1, POPUP_FRAMES do
			staticPopups[index] = _G["StaticPopup" .. index]
		end
	end
	return staticPopups
end

local function anyPopupShown()
	local popups = getStaticPopups()
	for index = 1, POPUP_FRAMES do
		local dialog = popups[index] or _G["StaticPopup" .. index]
		if dialog and dialog.IsShown then
			local ok, shown = pcall(dialog.IsShown, dialog)
			if ok and shown then
				return true
			end
		end
	end
	return false
end

local function popupTick(_, elapsed)
	popupElapsed = popupElapsed + elapsed
	if popupElapsed < POPUP_POLL then
		return
	end
	popupElapsed = 0

	local shown = anyPopupShown()
	if shown == popupWasShown then
		return
	end
	popupWasShown = shown
	Pulse:FireIfEnabled(shown and "popupShown" or "popupHidden")
end

local function syncPopup()
	popupFrame:SetScript("OnUpdate", nil)
	popupElapsed = 0
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("controllerUIMaster") then
		return
	end
	if not (Pulse.Database:GetCue("popupShown") or Pulse.Database:GetCue("popupHidden")) then
		return
	end
	-- Seed from live state, so arriving with a popup already open is not reported as one
	-- opening.
	popupWasShown = anyPopupShown()
	popupFrame:SetScript("OnUpdate", popupTick)
end

function M:OnEnable()
	Pulse:BindFrame({ "xpGained" }, syncXP)
	Pulse:BindFrame({ "stealthTexture" }, syncStealth)
	Pulse:BindFrame({ "controllerUIMaster", "popupShown", "popupHidden" }, syncPopup)
end
