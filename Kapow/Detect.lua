-- KAPOW — Detect.lua
--
-- Extra detection sources, each optional and off by default. Every one was taken from a
-- reference addon or from Blizzard's own UI and checked against both the Forever (1.60.1) and
-- the retail Midnight UI source:
--
--   COMBAT LOG COLOURS (MikScrollingBattleText's Forever build, Combat/Reader.lua)
--     COMBAT_LOG_MESSAGE has no restriction. Its text is wrapped and unreadable, but its colour
--     is plain, and it only fires while C_CombatLog.SetFilteredEventsEnabled is on (Blizzard
--     turns that off when its combat log tab hides, so this keeps it on). With Blizzard's
--     "My actions" filter your lines are grey 0.7, and a killing blow is a highlighted event
--     (colour x1.5, capped at 1: CombatLogUtil.lua), so YOUR KILLING BLOW IS A WHITE LINE.
--     Nothing here reads a line: only when it came and its colour.
--
--   TARGET DEATH EVENT (Blizzard_CombatAudioAlerts)
--     PLAYER_TARGET_DIED: no payload, never secret. The exact moment your target died.
--
--   DAMAGE METER (MidnightBattleText, src/data/OnDamageMeterCombatSessionUpdate.lua)
--     C_DamageMeter reports your own damage per spell, with overkillAmount. In combat the values
--     are secret: they cannot be subtracted, so to get "this kill's overkill" the meter is read
--     and then cleared on every update, as MidnightBattleText does. THAT CLEARS BLIZZARD'S
--     DAMAGE METER WINDOW, which the option says. The Interrupts meter type confirms interrupts.
--
--   KILL STATISTIC (WarCult's achievement-counter check)
--     A server counter of your kills (a statistic) goes up by one when a kill is credited to
--     you. CRITERIA_UPDATE announces changes. Which statistic is the user's choice: /kapow stats
--     lists the ones with "kill" in their name.

local _, ns = ...

local issecretvalue = _G.issecretvalue or function()
	return false
end

local DT = {}
ns.detect = DT

local frame = CreateFrame("Frame")
local db

local function Say(msg)
	if ns.Say then
		ns.Say(msg)
	end
end

local function PlainNumber(v)
	return not issecretvalue(v) and type(v) == "number"
end

-- ── Combat log colours ────────────────────────────────────────────────────────────────

local KEEP_ALIVE = 2 -- seconds between checks that the filtered log is still on
local logEnabledByUs = false
local keepElapsed = 0
DT.sawGreyLine = false -- grey lines of yours have arrived, so the colours are Blizzard's defaults
DT.lastMineLineAt = -100 -- the latest line of yours (read by Attribution.lua)

local function Near(value, target)
	return math.abs(value - target) <= 0.02
end

-- Blizzard's combat log filter, from its own saved table (read only): true when it sends your
-- own damage (its "My actions" quick button, or a filter with your melee, spell and DoT damage).
local DAMAGE_EVENTS = { "SWING_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE" }
function DT.MyActionsFilter()
	local saved = _G.Blizzard_CombatLog_Filters
	if type(saved) ~= "table" or type(saved.filters) ~= "table" then
		return false
	end
	local filter = PlainNumber(saved.currentFilter) and saved.filters[saved.currentFilter]
	if type(filter) ~= "table" then
		return false
	end
	local myActions = _G.QUICKBUTTON_NAME_MY_ACTIONS
	if type(filter.name) == "string" and type(myActions) == "string" and filter.name == myActions then
		return true
	end
	local mine = _G.COMBATLOG_FILTER_MINE
	if mine == nil or type(filter.filters) ~= "table" then
		return false
	end
	for _, part in ipairs(filter.filters) do
		local sources = type(part) == "table" and part.sourceFlags
		local events = type(part) == "table" and part.eventList
		if type(sources) == "table" and sources[mine] == true and type(events) == "table" then
			local all = true
			for _, event in ipairs(DAMAGE_EVENTS) do
				if events[event] ~= true then
					all = false
					break
				end
			end
			if all then
				return true
			end
		end
	end
	return false
end

local function KeepLog()
	local log = _G.C_CombatLog
	if not (log and log.SetFilteredEventsEnabled and log.AreFilteredEventsEnabled) then
		return
	end
	local ok, enabled = pcall(log.AreFilteredEventsEnabled)
	if ok and not issecretvalue(enabled) and enabled == false then
		pcall(log.SetFilteredEventsEnabled, true)
		logEnabledByUs = true
	end
end

local function ReleaseLog()
	local log = _G.C_CombatLog
	local window = _G.COMBATLOG
	local shown = window and window.IsShown and window:IsShown()
	if logEnabledByUs and not (not issecretvalue(shown) and shown) and log and log.SetFilteredEventsEnabled then
		pcall(log.SetFilteredEventsEnabled, false)
	end
	logEnabledByUs = false
end

-- "mine" (grey), "kill" (white), "other", or nil when the colour is not plain.
function DT.LineKind(r, g, b)
	if not (PlainNumber(r) and PlainNumber(g) and PlainNumber(b)) then
		return nil
	end
	if Near(r, 0.7) and Near(g, 0.7) and Near(b, 0.7) then
		return "mine"
	end
	if r >= 0.99 and g >= 0.99 and b >= 0.99 then
		return "kill"
	end
	return "other"
end

local function OnLogMessage(_, r, g, b, order)
	local oldest = _G.Enum and _G.Enum.CombatLogMessageOrder and _G.Enum.CombatLogMessageOrder.Oldest
	if oldest ~= nil and not issecretvalue(order) and order == oldest then
		return -- lines refilled into Blizzard's window, not new events
	end
	local kind = DT.LineKind(r, g, b)
	if kind == "mine" then
		DT.sawGreyLine = true
		DT.lastMineLineAt = GetTime()
	elseif kind == "kill" and db.killLogLine and DT.sawGreyLine and DT.MyActionsFilter() then
		if ns.OnLogKill then
			ns.OnLogKill()
		end
	end
end

-- ── Damage meter ──────────────────────────────────────────────────────────────────────

local METER_DAMAGE = 0 -- Enum.DamageMeterType.DamageDone
local METER_INTERRUPTS = 5 -- Enum.DamageMeterType.Interrupts
local METER_OVERALL = 0 -- Enum.DamageMeterSessionType.Overall
DT.overkill, DT.overkillAt = nil, -100 -- the latest overkill amount (maybe secret) and when
local meterBusy = false

function DT.MeterAvailable()
	local meter = _G.C_DamageMeter
	if not (meter and meter.IsDamageMeterAvailable) then
		return false
	end
	local ok, available = pcall(meter.IsDamageMeterAvailable)
	return ok and not issecretvalue(available) and available == true
end

local function ReadOverkill()
	local meter = _G.C_DamageMeter
	local me = UnitGUID("player")
	if not (meter and meter.GetCombatSessionSourceFromType) or issecretvalue(me) or type(me) ~= "string" then
		return
	end
	local enum = _G.Enum
	local damageType = enum and enum.DamageMeterType and enum.DamageMeterType.DamageDone or METER_DAMAGE
	local overall = enum and enum.DamageMeterSessionType and enum.DamageMeterSessionType.Overall or METER_OVERALL
	local ok, mine = pcall(meter.GetCombatSessionSourceFromType, overall, damageType, me)
	if not ok or type(mine) ~= "table" or type(mine.combatSpells) ~= "table" then
		return
	end
	local count = #mine.combatSpells
	if count > 0 then
		-- After a clear the meter holds only what landed since: usually one spell. The newest is
		-- taken; the value may be secret and is only ever drawn.
		local spell = mine.combatSpells[count]
		if type(spell) == "table" then
			DT.overkill, DT.overkillAt = spell.overkillAmount, GetTime()
		end
		if meter.ResetAllCombatSessions then
			pcall(meter.ResetAllCombatSessions)
		end
	end
end

local function OnMeterUpdate(meterType)
	if meterBusy or issecretvalue(meterType) then
		return
	end
	meterBusy = true
	local enum = _G.Enum and _G.Enum.DamageMeterType
	local interrupts = enum and enum.Interrupts or METER_INTERRUPTS
	local damage = enum and enum.DamageDone or METER_DAMAGE
	if meterType == interrupts and db.meterInterrupts and ns.announcer then
		ns.announcer:OnMeterInterrupt()
	elseif meterType == damage and db.meterOverkill then
		ReadOverkill()
	end
	meterBusy = false
end

-- The overkill of a kill that just happened, or nil.
function DT.FreshOverkill(window)
	if db and db.meterOverkill and GetTime() - DT.overkillAt <= (window or 1.0) then
		return DT.overkill
	end
	return nil
end

-- ── Kill statistic ────────────────────────────────────────────────────────────────────

local statWhere = {} -- statID -> { category, index } (Forever's GetStatistic takes those)
local statLast

-- Forever: GetStatistic(category, index) -> quantity, skip, statID. Retail: GetStatistic(id).
local function EachStatistic(fn)
	local list = _G.GetStatisticsCategoryList and _G.GetStatisticsCategoryList()
	if type(list) ~= "table" or not _G.GetCategoryNumAchievements then
		return
	end
	for _, category in ipairs(list) do
		local count = _G.GetCategoryNumAchievements(category) or 0
		for index = 1, count do
			local quantity, skip, statID = _G.GetStatistic(category, index)
			if not skip and statID then
				fn(category, index, statID, quantity)
			end
		end
	end
end

local function ReadStatistic(statID)
	if not PlainNumber(statID) or statID <= 0 or not _G.GetStatistic then
		return nil
	end
	local where = statWhere[statID]
	if not where then
		EachStatistic(function(category, index, id)
			if id == statID then
				statWhere[statID] = { category, index }
			end
		end)
		where = statWhere[statID]
	end
	if not where then
		return nil
	end
	local quantity = _G.GetStatistic(where[1], where[2])
	if issecretvalue(quantity) then
		return nil
	end
	return tonumber(quantity) or 0
end

local function OnCriteriaUpdate()
	if not db.killStatistic then
		return
	end
	local kills = ReadStatistic(db.killStatId)
	if kills and statLast and kills > statLast and ns.OnStatKill then
		ns.OnStatKill()
	end
	statLast = kills or statLast
end

-- /kapow stats: the statistics with "kill" in their name, with IDs, for the Experimental tab.
function DT.ListKillStatistics()
	local found = 0
	EachStatistic(function(_, _, statID, quantity)
		local name = _G.GetAchievementInfo and select(2, _G.GetAchievementInfo(statID))
		if type(name) == "string" and not issecretvalue(name) and string.find(string.lower(name), "kill", 1, true) then
			found = found + 1
			Say(("stat |cffffd60a%d|r  %s = %s"):format(statID, name, tostring(quantity)))
		end
	end)
	if found == 0 then
		Say("no statistics with \"kill\" in their name on this client")
	end
	return found
end

-- ── Wiring ────────────────────────────────────────────────────────────────────────────

local function KeepAlive(_, elapsed)
	keepElapsed = keepElapsed + elapsed
	if keepElapsed >= KEEP_ALIVE then
		keepElapsed = 0
		KeepLog()
	end
end

-- Whether combat-log lines are wanted at all: for killing blows or for Accurate attribution.
local function WantLog()
	return db.enabled and (db.killLogLine or db.attribution == "accurate")
end

function DT.Sync()
	db = ns.db
	if not db then
		return
	end
	frame:UnregisterAllEvents()
	if WantLog() then
		pcall(frame.RegisterEvent, frame, "COMBAT_LOG_MESSAGE")
		KeepLog()
		frame:SetScript("OnUpdate", KeepAlive)
	else
		frame:SetScript("OnUpdate", nil)
		ReleaseLog()
	end
	if not db.enabled then
		return
	end
	if db.killTargetDied or (db.killPet and db.killPetBackup) then
		pcall(frame.RegisterEvent, frame, "PLAYER_TARGET_DIED")
	end
	if db.meterOverkill or db.meterInterrupts then
		pcall(frame.RegisterEvent, frame, "DAMAGE_METER_COMBAT_SESSION_UPDATED")
	end
	if db.killStatistic then
		pcall(frame.RegisterEvent, frame, "CRITERIA_UPDATE")
		statLast = ReadStatistic(db.killStatId)
	end
end

DT.targetDiedAt, DT.targetDiedSerial = -100, -1

frame:SetScript("OnEvent", function(_, event, ...)
	if not db then
		return
	end
	if event == "COMBAT_LOG_MESSAGE" then
		OnLogMessage(...)
	elseif event == "PLAYER_TARGET_DIED" then
		DT.targetDiedAt, DT.targetDiedSerial = GetTime(), ns.TargetSerial and ns.TargetSerial() or -1
		if ns.OnTargetDied then
			ns.OnTargetDied()
		end
	elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
		OnMeterUpdate(...)
	elseif event == "CRITERIA_UPDATE" then
		OnCriteriaUpdate()
	end
end)

-- Whether the target selected as `serial` died at or after `since` (PLAYER_TARGET_DIED).
function DT.TargetDiedSince(since, serial)
	return db and db.killTargetDied and DT.targetDiedSerial == serial and DT.targetDiedAt >= since
end
