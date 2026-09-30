-- PulseProbe — Probes/Sequencer.lua
--
-- Phase 0 event-order capture for PulseHaptics' arbitration constants. Records every event
-- the Phase 1 design depends on, with one or two state samples taken at arrival, into the
-- trace ring (Core.lua, Probe:Record). Start with /probe trace start <scenario>, act, then
-- /probe trace stop and /probe trace dump.
--
-- Read-only: registers events, reads state, post-hooks two Blizzard functions with
-- hooksecurefunc. Never calls a protected function, never calls debugprofilestart.

local ADDON_NAME, Probe = ...

local SQ = {}
Probe.Sequencer = SQ

local frame = CreateFrame("Frame")

local EVENTS = {
	-- vendor & repair
	"MERCHANT_SHOW",
	"MERCHANT_CLOSED",
	"PLAYER_MONEY",
	"UPDATE_INVENTORY_DURABILITY",
	"UPDATE_INVENTORY_ALERTS",
	-- bags & intake
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",
	"ITEM_PUSH",
	"CHAT_MSG_LOOT",
	"CHAT_MSG_MONEY",
	-- loot window
	"LOOT_READY",
	"LOOT_OPENED",
	"LOOT_SLOT_CLEARED",
	"LOOT_CLOSED",
	"START_LOOT_ROLL",
	-- windows
	"PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
	"PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
	"GOSSIP_SHOW",
	"GOSSIP_CLOSED",
	"MAIL_SHOW",
	"MAIL_CLOSED",
	"MAIL_INBOX_UPDATE",
	"BANKFRAME_OPENED",
	"BANKFRAME_CLOSED",
	-- pull & swing
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"UNIT_THREAT_SITUATION_UPDATE",
	"PLAYER_ENTER_COMBAT",
	"PLAYER_SWING",
	-- equipment
	"PLAYER_EQUIPMENT_CHANGED",
}

local function freeSlots()
	if C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots then
		return C_Container.CalculateTotalNumberOfFreeBagSlots()
	end
	return nil
end

-- One or two state samples per event, chosen to answer a specific §11 question.
frame:SetScript("OnEvent", function(_, event, a1, a2, ...)
	if event == "PLAYER_MONEY" then
		Probe:Record(event, GetMoney and GetMoney())
	elseif event == "BAG_UPDATE_DELAYED" then
		Probe:Record(event, freeSlots())
	elseif event == "UPDATE_INVENTORY_DURABILITY" then
		Probe:Record(event, GetRepairAllCost and GetRepairAllCost(), InRepairMode and InRepairMode())
	elseif event == "UPDATE_INVENTORY_ALERTS" then
		local worst = 0
		for i = 1, 11 do
			local s = GetInventoryAlertStatus and GetInventoryAlertStatus(i)
			if type(s) == "number" and not issecretvalue(s) and s > worst then
				worst = s
			end
		end
		Probe:Record(event, worst)
	elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
		-- Is the loot list already readable at LOOT_READY? (Arbiter scans at both.)
		Probe:Record(event, a1, GetNumLootItems and GetNumLootItems())
	elseif event == "CHAT_MSG_LOOT" then
		Probe:Record(event, select(10, ...)) -- 12th payload field: looter GUID
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		Probe:Record(event, InCombatLockdown(), UnitAffectingCombat("player"))
	else
		Probe:Record(event, a1, a2)
	end
end)

-- Next-frame timer probe: when an interaction window hides, schedule a C_Timer.After(0)
-- and record when it runs relative to a following SHOW — the deferred-close assumption.
local function onTimer0()
	Probe:Record("TIMER0")
end

local hooked = false
local function hookOnce()
	if hooked then
		return
	end
	hooked = true
	if type(RepairAllItems) == "function" then
		hooksecurefunc("RepairAllItems", function(useGuild)
			Probe:Record("HOOK_RepairAllItems", useGuild, GetRepairAllCost and GetRepairAllCost())
		end)
	end
end

local mailHooked = false
local function hookMail()
	if mailHooked or type(OpenAllMail) ~= "table" then
		return
	end
	mailHooked = true
	if type(OpenAllMail.StartOpening) == "function" then
		hooksecurefunc(OpenAllMail, "StartOpening", function()
			Probe:Record("HOOK_OpenAllMail_Start")
		end)
	end
	if type(OpenAllMail.StopOpening) == "function" then
		hooksecurefunc(OpenAllMail, "StopOpening", function()
			Probe:Record("HOOK_OpenAllMail_Stop")
		end)
	end
end

-- UI panel poll at frame rate (ControllerUI polls at 20 Hz): records when the left panel
-- changes, to measure panelOpen's lag against the interaction events.
local lastLeft = false
local pollFrame = CreateFrame("Frame")
pollFrame:SetScript("OnUpdate", function()
	if not Probe.TraceState.running or type(GetUIPanel) ~= "function" then
		return
	end
	local left = GetUIPanel("left") or false
	if left ~= lastLeft then
		lastLeft = left
		Probe:Record("UIPANEL_LEFT", left and left.GetName and left:GetName() or false)
	end
end)

local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnEvent", function()
	C_Timer.After(0, onTimer0)
end)

function SQ:OnInit() end

function SQ:OnEnable()
	for _, event in ipairs(EVENTS) do
		pcall(frame.RegisterEvent, frame, event)
	end
	pcall(timerFrame.RegisterEvent, timerFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
	hookOnce()
	hookMail()
	-- Blizzard_MailFrame may load on demand; try again when it does.
	frame:RegisterEvent("ADDON_LOADED")
end

frame:HookScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == "Blizzard_MailFrame" then
		hookMail()
	end
end)

Probe:RegisterProbe("Sequencer", SQ)
