-- KAPOW — Announcer.lua
--
-- Arena-shooter moments (old-school arena and tactical shooters) and a kill feed. Each moment is an event in
-- Events.lua whose look (art, animation, text, color, size, place, sound) the player picks:
--
--   firstblood            the first kill of a fight by anyone in your group
--   double ... ludicrous  your kills less than MULTI_WINDOW apart
--   spree5 ... spree30    your kills since you last died
--   mvp                   most killing blows in your group when the fight ends
--   youdied, teammate, laststanding, wipe, petdown
--   interrupt (yours, on your target), interrupted (you)
--   bossdown, encwipe, levelup
--   kickoff, fulltime, flawless  a fight starting, ending, ending with nobody in the group dead
--   falling, hardlanding, falldeath  your own falls, from IsFalling() (plain for the player)
--   avoid                 dodge / parry / block / miss on you (frequent, for testing)
--   kill feed             "Bob [skull] Defias Thug" for every killing blow in your group
--
-- SECRETS. Decisions are made only on plain facts: who landed a kill (your group's GUIDs are
-- plain), your own and your pet's casts (plain by SecretWhenUnitSpellCastRestricted), which
-- event fired and when. Values that may be secret — a victim's name, an interrupter, an
-- enemy's cast — are never compared or concatenated; they go into the event's text values
-- and are drawn by FontString:SetFormattedText (SecretArguments = "AllowedWhenTainted").
--
-- "You interrupted your target" is read by timing, not from the event: an interrupt spell of
-- yours (or your pet's) succeeds, then your target's UNIT_SPELLCAST_INTERRUPTED fires within
-- INTERRUPT_WINDOW. The target's own payload, interruptedBy included, stays unread.

local _, ns = ...

local issecretvalue = _G.issecretvalue or function()
	return false
end

local A = {}
ns.announcer = A

local FONT = "Fonts\\FRIZQT__.TTF"
local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:16|t"

local MULTI_WINDOW = 4 -- seconds between kills for a multi-kill (the classic arena-shooter window)
local INTERRUPT_WINDOW = 0.5 -- seconds from your interrupt spell to the target's interrupt
local BANNER_LIFE = 1.8 -- seconds one banner holds the screen
local QUEUE_MAX = 4
local FEED_LINES = 5
local FEED_TIME = 6 -- seconds a kill-feed line stays
local AVOID_THROTTLE = 1.5
local FALL_POLL = 0.05 -- seconds between IsFalling() reads while a fall event is on
local FALL_LONG = 1.2 -- seconds in the air before "falling"
local HARD_LANDING = 2.5 -- seconds in the air for a hard landing (PulseHaptics' threshold)
local FALL_DEATH_WINDOW = 1.0 -- a death this soon after landing was the fall
local FALL_DEATH_MIN_AIR = 0.8 -- shorter drops do not kill; a death after one is something else

local MULTI = { [2] = "double", [3] = "triple", [4] = "multi", [5] = "mega", [6] = "ultra", [7] = "monster" }
local MULTI_MAX = "ludicrous"
local SPREE = { [5] = "spree5", [10] = "spree10", [15] = "spree15", [20] = "spree20", [25] = "spree25" }
local SPREE_MAX = "spree30" -- 30, then every 5 kills

local AVOID = { DODGE = "Dodged", PARRY = "Parried", BLOCK = "Blocked", MISS = "Missed" }

-- Interrupt spells, by name so every rank matches. Built lazily from one ID each; an ID this
-- client does not know is skipped.
local INTERRUPT_IDS = {
	1766, -- Kick
	6552, -- Pummel
	72, -- Shield Bash
	2139, -- Counterspell
	8042, -- Earth Shock
	19244, -- Spell Lock (Felhunter)
	15487, -- Silence
	16979, -- Feral Charge
	57994, -- Wind Shear
	47528, -- Mind Freeze
	96231, -- Rebuke
	147362, -- Counter Shot
	106839, -- Skull Bash
	183752, -- Disrupt
	116705, -- Spear Hand Strike
	187707, -- Muzzle
	351338, -- Quell
}

local db

local function On(id)
	local cfg = db.events[id]
	return cfg and cfg.enabled
end

local function AnyOn(...)
	for i = 1, select("#", ...) do
		if On((select(i, ...))) then
			return true
		end
	end
	return false
end

local function SpellName(spellID)
	local get = (C_Spell and C_Spell.GetSpellName) or _G.GetSpellInfo
	if not get then
		return nil
	end
	local ok, name = pcall(get, spellID)
	if ok and type(name) == "string" and not issecretvalue(name) then
		return name
	end
	return nil
end

local interruptNames
local function IsInterruptSpell(spellID)
	if not interruptNames then
		interruptNames = {}
		for _, id in ipairs(INTERRUPT_IDS) do
			local name = SpellName(id)
			if name then
				interruptNames[name] = true
			end
		end
	end
	local name = SpellName(spellID)
	return name ~= nil and interruptNames[name] == true
end

-- ── Banner ────────────────────────────────────────────────────────────────────────────
local stage
local queue = {}
local showing = false
A.history = {} -- event ids shown, newest last (bounded); read by tests and /kapow announce
A.shownTotal = 0 -- banners shown this session

local function EnsureStage()
	if stage then
		return
	end
	local root = CreateFrame("Frame", "KapowBanner", UIParent)
	root:SetSize(256, 256)
	root:SetFrameStrata("HIGH")
	root:EnableMouse(false)
	root:Hide()
	stage = ns.display.NewStage(root, root, BANNER_LIFE)
	A.stage = stage
end

local ShowNext

local function Done()
	showing = false
	ShowNext()
end

ShowNext = function()
	local entry = table.remove(queue, 1)
	if not entry then
		return
	end
	EnsureStage()
	showing = true
	A.shownTotal = A.shownTotal + 1
	local history = A.history
	history[#history + 1] = entry.id
	if #history > 30 then
		table.remove(history, 1)
	end
	ns.display.Play(stage, db.events[entry.id], entry.values, nil, Done)
end

-- Queues event `id` with its text values (which may hold secrets).
function A:Fire(id, values)
	if not db or not On(id) or #queue >= QUEUE_MAX then
		return
	end
	queue[#queue + 1] = { id = id, values = values or {} }
	if not showing then
		ShowNext()
	end
end

-- Shows one event at once with sample values, for the window's Preview button.
local SAMPLE = { killer = "You", victim = "Hogger", count = 3, total = 5, name = "Bob", level = 42, amount = "12.3K" }
function A:Preview(id)
	local def = ns.EVENT_BY_ID[id]
	if def and def.hit then
		ns.Test(id == "crit" and "pow" or (id == "kill" and "ko" or "overkill"))
		return
	end
	EnsureStage()
	showing = true
	ns.display.Play(stage, db.events[id], SAMPLE, nil, Done)
end

-- ── Kill feed ─────────────────────────────────────────────────────────────────────────
local feed
local feedEntries = {} -- { at, format, args, n }, newest first

local function BuildFeed()
	feed = CreateFrame("Frame", "KapowKillFeed", UIParent)
	feed:SetSize(360, FEED_LINES * 22)
	feed:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -230, -210)
	feed:EnableMouse(false)
	feed.lines = {}
	for i = 1, FEED_LINES do
		local line = feed:CreateFontString(nil, "OVERLAY")
		line:SetFont(FONT, 15, "OUTLINE")
		line:SetJustifyH("RIGHT")
		line:SetPoint("TOPRIGHT", feed, "TOPRIGHT", 0, -(i - 1) * 22)
		line:SetWidth(360)
		feed.lines[i] = line
	end
end

local function RenderFeed()
	local now = GetTime()
	for i = #feedEntries, 1, -1 do
		if now - feedEntries[i].at >= FEED_TIME then
			table.remove(feedEntries, i)
		end
	end
	for i = 1, FEED_LINES do
		local line, entry = feed.lines[i], feedEntries[i]
		if entry then
			line:SetFormattedText(entry.format, unpack(entry.args, 1, entry.n))
			line:Show()
		else
			line:SetText("")
			line:Hide()
		end
	end
end

function A:FeedLine(format, ...)
	if not feed then
		BuildFeed()
	end
	table.insert(feedEntries, 1, { at = GetTime(), format = format, args = { ... }, n = select("#", ...) })
	if #feedEntries > FEED_LINES then
		table.remove(feedEntries)
	end
	RenderFeed()
	C_Timer.After(FEED_TIME + 0.05, RenderFeed)
end
A.feedEntries = feedEntries

-- ── Names ─────────────────────────────────────────────────────────────────────────────

-- Text for a unit by GUID, which may be secret. Returns a string that may itself be secret
-- (draw it, never read it), or `fallback`.
local function NameFromGUID(guid, fallback)
	if not issecretvalue(guid) and guid == nil then
		return fallback
	end
	if UnitTokenFromGUID then
		local ok, token = pcall(UnitTokenFromGUID, guid)
		if ok and type(token) == "string" then
			local okName, name = pcall(UnitName, token)
			if okName and type(name) == "string" then
				return name
			end
		end
	end
	if GetPlayerInfoByGUID then
		local ok, _, _, _, _, _, name = pcall(GetPlayerInfoByGUID, guid)
		if ok and type(name) == "string" then
			return name
		end
	end
	return fallback
end

local function KillerText(who, unit)
	if who == "you" then
		return "|cffffd60aYou|r"
	elseif who == "pet" then
		return "|cffffd60aYour pet|r"
	elseif who == "group" or who == "grouppet" then
		return ns.UnitLabel(unit)
	end
	return "Someone"
end

-- ── Group helpers ─────────────────────────────────────────────────────────────────────

local function InGroup()
	return IsInGroup and IsInGroup() or false
end

-- Unit tokens of everyone in the group but you.
local groupUnits = {}
local function GroupUnits()
	for i = #groupUnits, 1, -1 do
		groupUnits[i] = nil
	end
	if IsInRaid and IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local unit = "raid" .. i
			if not UnitIsUnit(unit, "player") then
				groupUnits[#groupUnits + 1] = unit
			end
		end
	else
		for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
			groupUnits[#groupUnits + 1] = "party" .. i
		end
	end
	return groupUnits
end

local function GroupUnitByGUID(guid)
	if not ns.Plain(guid) then
		return nil
	end
	local plainGUID = guid
	for _, unit in ipairs(GroupUnits()) do
		local unitGUID = UnitGUID(unit)
		if ns.Plain(unitGUID) and unitGUID == plainGUID then
			return unit
		end
	end
	return nil
end

-- ── Fight state ───────────────────────────────────────────────────────────────────────
local fightKills = {} -- killer key -> { count, label }
local fightTotal = 0
local fightDeaths = false -- anyone in the group died this fight
local firstBloodDone = false
local myKillTimes = 0 -- kills in the current multi-kill chain
local lastMyKillAt = -100
local spree = 0
local lastAvoidAt = -100
local lastMyInterruptAt = -100
local petGUID -- cached on UNIT_PET: the pet's GUID may be gone by the time UNIT_DIED fires

local function CachePet()
	local guid = UnitGUID("pet")
	if ns.Plain(guid) then
		petGUID = guid
	end
end

local function ResetFight()
	for k in pairs(fightKills) do
		fightKills[k] = nil
	end
	fightTotal = 0
	fightDeaths = false
	firstBloodDone = false
end

local function SpreeEvent(n)
	if SPREE[n] then
		return SPREE[n]
	end
	if n >= 30 and n % 5 == 0 then
		return SPREE_MAX
	end
	return nil
end

-- ── Events ────────────────────────────────────────────────────────────────────────────

local function OnPartyKill(attackerGUID, victimGUID)
	local who, unit = ns.WhoKilled(attackerGUID)
	local inGroup = who == "you" or who == "pet" or who == "group" or who == "grouppet"
	local mine = who == "you" or (who == "pet" and db.killPet)
	local victim = NameFromGUID(victimGUID, "an enemy")

	if db.annFeed and inGroup then
		A:FeedLine("%s  " .. SKULL .. "  %s", KillerText(who, unit), victim)
	end

	if not inGroup then
		return
	end

	-- FIRST BLOOD and the MVP tally: everyone in the group.
	local key = (who == "you" or who == "pet") and "you" or unit
	local entry = fightKills[key]
	if not entry then
		entry = { count = 0, label = (key == "you") and "You" or ns.UnitLabel(unit) }
		fightKills[key] = entry
	end
	entry.count = entry.count + 1
	fightTotal = fightTotal + 1

	if not firstBloodDone and (InGroup() or db.annFirstBloodSolo) then
		A:Fire("firstblood", { killer = entry.label, victim = victim })
	end
	firstBloodDone = true

	if not mine then
		return
	end

	local now = GetTime()
	if now - lastMyKillAt <= MULTI_WINDOW then
		myKillTimes = myKillTimes + 1
	else
		myKillTimes = 1
	end
	lastMyKillAt = now
	if myKillTimes >= 2 then
		A:Fire(MULTI[myKillTimes] or MULTI_MAX, { count = myKillTimes, victim = victim })
	end

	spree = spree + 1
	local spreeEvent = SpreeEvent(spree)
	if spreeEvent then
		A:Fire(spreeEvent, { count = spree, victim = victim })
	end
end

local function OnFightEnd()
	if fightTotal > 0 then
		A:Fire("fulltime", { count = fightTotal })
	end
	if InGroup() and fightTotal >= 3 then
		local best, bestCount, tie = nil, 0, false
		for _, entry in pairs(fightKills) do
			if entry.count > bestCount then
				best, bestCount, tie = entry, entry.count, false
			elseif entry.count == bestCount then
				tie = true
			end
		end
		if best and not tie then
			A:Fire("mvp", { name = best.label, count = best.count, total = fightTotal })
		end
	end
	if InGroup() and fightTotal > 0 and not fightDeaths then
		A:Fire("flawless", { count = fightTotal })
	end
	ResetFight()
end

-- After a death in the group: LAST ONE STANDING when only you are up, WIPE when nobody is.
local function CheckGroupStanding()
	if not InGroup() then
		return
	end
	local units = GroupUnits()
	if #units < 2 then
		return
	end
	for _, unit in ipairs(units) do
		if not UnitIsDeadOrGhost(unit) then
			return -- someone else is still up
		end
	end
	if UnitIsDeadOrGhost("player") then
		A:Fire("wipe")
	else
		A:Fire("laststanding")
	end
end

local function OnUnitDied(guid)
	if not ns.Plain(guid) then
		return -- an enemy or a stranger: secret, and not ours to announce
	end
	local plainGUID = guid
	CachePet()
	if petGUID and plainGUID == petGUID then
		petGUID = nil
		A:Fire("petdown")
		return
	end
	local unit = GroupUnitByGUID(plainGUID)
	if unit then
		fightDeaths = true
		A:Fire("teammate", { name = ns.UnitLabel(unit) })
		CheckGroupStanding()
	end
end

-- ── Falls ─────────────────────────────────────────────────────────────────────────────
-- Polled only while a fall event is on. Flying mounts and taxis do not count as falling.
local fallFrame = CreateFrame("Frame")
local fallStart -- GetTime() the current fall began, nil on the ground
local fallAnnounced = false
local lastLandAt, lastLandAir = -100, 0
local fallElapsed = 0

local function Seconds(t)
	return string.format("%.1f", t)
end

local function Airborne()
	if not IsFalling() then
		return false
	end
	if IsFlying and IsFlying() then
		return false
	end
	if UnitOnTaxi and UnitOnTaxi("player") then
		return false
	end
	return true
end

local function PollFalls(_, elapsed)
	fallElapsed = fallElapsed + elapsed
	if fallElapsed < FALL_POLL then
		return
	end
	fallElapsed = 0
	local now = GetTime()
	local falling = Airborne()
	if falling then
		if not fallStart then
			fallStart, fallAnnounced = now, false
		elseif not fallAnnounced and now - fallStart >= FALL_LONG then
			fallAnnounced = true
			A:Fire("falling", { time = Seconds(now - fallStart) })
		end
	elseif fallStart then
		local air = now - fallStart
		fallStart = nil
		lastLandAt, lastLandAir = now, air
		if air >= HARD_LANDING and not (IsSwimming and IsSwimming()) then
			-- Wait a moment: if PLAYER_DEAD follows, the landing killed and falldeath shows.
			local landedAt = now
			C_Timer.After(0.3, function()
				if lastLandAt == landedAt and not UnitIsDeadOrGhost("player") then
					A:Fire("hardlanding", { time = Seconds(air) })
				end
			end)
		end
	end
end

-- How long the fall that just killed you lasted, or nil when the death was not a fall.
local function FallThatKilled()
	local now = GetTime()
	if fallStart and now - fallStart >= FALL_DEATH_MIN_AIR then
		return now - fallStart
	end
	if now - lastLandAt <= FALL_DEATH_WINDOW and lastLandAir >= FALL_DEATH_MIN_AIR then
		return lastLandAir
	end
	return nil
end

local function OnPlayerDead()
	spree, myKillTimes = 0, 0
	fightDeaths = true
	local air = FallThatKilled()
	fallStart, lastLandAt = nil, -100 -- the fall is spent; no hard landing on top
	if air and On("falldeath") then
		A:Fire("falldeath", { time = Seconds(air) })
	else
		A:Fire("youdied")
	end
	CheckGroupStanding()
end

-- Your own (or your pet's) cast: remember interrupt spells for the timing match.
local function OnOwnCast(spellID)
	if ns.Plain(spellID) and IsInterruptSpell(spellID) then
		lastMyInterruptAt = GetTime()
	end
end

-- Your target's cast was interrupted. Nothing in the payload is read.
local function OnTargetInterrupted()
	if GetTime() - lastMyInterruptAt <= INTERRUPT_WINDOW then
		lastMyInterruptAt = -100
		A:Fire("interrupt", { name = UnitName("target") or "them" })
	end
end

-- Whether a value is there at all. Secret first: a secret may not be compared with nil.
local function Present(v)
	return issecretvalue(v) or v ~= nil
end

-- Your own cast was interrupted. Payload plain (it is your cast); an interrupt by someone
-- carries interruptedBy, a cast you cancelled or moved out of does not.
local function OnPlayerInterrupted(interruptedBy)
	if Present(interruptedBy) then
		A:Fire("interrupted", { name = NameFromGUID(interruptedBy, "an enemy") })
	end
end

local function OnPlayerCombat(action)
	if issecretvalue(action) then
		return
	end
	local text = AVOID[action]
	local now = GetTime()
	if text and now - lastAvoidAt >= AVOID_THROTTLE then
		lastAvoidAt = now
		A:Fire("avoid", { name = text })
	end
end

-- ── Wiring ────────────────────────────────────────────────────────────────────────────
local driver = CreateFrame("Frame")
local targetCasts = CreateFrame("Frame") -- fires only for "target"; its payload is never read

local function Register(frame, event, ...)
	-- pcall: a client without the event refuses to register it.
	if select("#", ...) > 0 then
		pcall(frame.RegisterUnitEvent, frame, event, ...)
	else
		pcall(frame.RegisterEvent, frame, event)
	end
end

local KILL_EVENTS = {
	"firstblood", "mvp", "double", "triple", "multi", "mega", "ultra", "monster", "ludicrous",
	"spree5", "spree10", "spree15", "spree20", "spree25", "spree30",
}

function A:Sync()
	if not db then
		return
	end
	driver:UnregisterAllEvents()
	targetCasts:UnregisterAllEvents()
	if not db.enabled then
		fallFrame:SetScript("OnUpdate", nil)
		fallStart = nil
		return
	end
	Register(driver, "PLAYER_REGEN_DISABLED")
	Register(driver, "PLAYER_REGEN_ENABLED")
	local falls = AnyOn("falling", "hardlanding", "falldeath")
	fallFrame:SetScript("OnUpdate", falls and PollFalls or nil)
	if not falls then
		fallStart = nil
	end
	if db.annFeed or AnyOn(unpack(KILL_EVENTS)) then
		Register(driver, "PARTY_KILL")
	end
	-- Death resets sprees and multi-kills, so it is watched whenever those are on.
	if AnyOn("youdied", "laststanding", "wipe", "falldeath", "flawless", unpack(KILL_EVENTS)) then
		Register(driver, "PLAYER_DEAD")
	end
	if AnyOn("teammate", "laststanding", "wipe", "petdown", "flawless") then
		Register(driver, "UNIT_DIED")
	end
	if On("petdown") then
		Register(driver, "UNIT_PET", "player")
		CachePet()
	end
	if On("interrupt") then
		Register(driver, "UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
		Register(targetCasts, "UNIT_SPELLCAST_INTERRUPTED", "target")
	end
	if On("interrupted") then
		Register(driver, "UNIT_SPELLCAST_INTERRUPTED", "player")
	end
	if AnyOn("bossdown", "encwipe") then
		Register(driver, "ENCOUNTER_END")
	end
	if On("levelup") then
		Register(driver, "PLAYER_LEVEL_UP")
	end
	if On("avoid") then
		Register(driver, "UNIT_COMBAT", "player")
	end
end

driver:SetScript("OnEvent", function(_, event, ...)
	if event == "PARTY_KILL" then
		OnPartyKill(...)
	elseif event == "PLAYER_REGEN_DISABLED" then
		ResetFight()
		A:Fire("kickoff")
	elseif event == "PLAYER_REGEN_ENABLED" then
		OnFightEnd()
	elseif event == "PLAYER_DEAD" then
		OnPlayerDead()
	elseif event == "UNIT_DIED" then
		OnUnitDied(...)
	elseif event == "UNIT_PET" then
		CachePet()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, _, spellID = ...
		OnOwnCast(spellID)
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		local _, _, _, interruptedBy = ...
		OnPlayerInterrupted(interruptedBy)
	elseif event == "ENCOUNTER_END" then
		local _, encounterName, _, _, success = ...
		A:Fire(success == 1 and "bossdown" or "encwipe", { name = encounterName })
	elseif event == "PLAYER_LEVEL_UP" then
		local level = ...
		A:Fire("levelup", { level = level })
	elseif event == "UNIT_COMBAT" then
		local _, action = ...
		OnPlayerCombat(action)
	end
end)

targetCasts:SetScript("OnEvent", function()
	OnTargetInterrupted()
end)

-- Also called when the profile changes.
function A:Init()
	db = ns.db
	self:Sync()
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────

-- A run through four banners and a feed line, with plain test values.
function A:Demo()
	A:FeedLine("%s  " .. SKULL .. "  %s", "|cffffd60aYou|r", "Hogger")
	A:Fire("firstblood", { killer = "You", victim = "Hogger" })
	A:Fire("double", { count = 2 })
	A:Fire("spree5", { count = 5 })
	A:Fire("mvp", { name = "You", count = 4, total = 6 })
end

function A:Command(arg)
	local sub = string.lower(string.match(arg or "", "^%s*(%S*)") or "")
	if sub == "test" then
		A:Demo()
	elseif sub == "last" then
		ns.Say("recent banners: " .. (#A.history > 0 and table.concat(A.history, ", ") or "none"))
	else
		ns.Say("/kapow announce test (demo banners and a feed line)  ·  announce last (recent banners)")
	end
end
