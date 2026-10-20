-- KAPOW — Moments.lua
--
-- Banners for moments outside the hit-and-kill path, each an event that starts switched off
-- (Events › Arcade and Moments), plus personal records and party sync:
--
--   DUELS        "Duel starting: 3" system lines feed the countdown, then ROUND 1 ... FIGHT!;
--                the "has defeated" / "has fled" lines decide YOU WIN or YOU LOSE.
--   COUNTDOWN    START_TIMER (arena and battleground gates, /countdown pull timers): 3, 2, 1,
--                FIGHT! in step with the game's own timer.
--   BOSS PULL    ENCOUNTER_START.
--   ACHIEVEMENT, EPIC LOOT, QUEST, HONORABLE KILL   their plain game events.
--   RECORDS      best multi-kill, spree and combo per character (KapowCharDB.records), and
--                lifetime tallies; "New personal record" fires when a best is beaten.
--   PARTY SYNC   addon messages ("KAPOW" prefix) tell groupmates who also run KAPOW about your
--                big moments; theirs arrive as kill-feed lines. Only event ids and plain
--                counts are sent; nothing secret can reach SendAddonMessage.
--
-- System and loot chat may be secret during chat lockdown (encounters, Mythic+): such lines
-- are skipped, never parsed.

local _, ns = ...

local issecretvalue = _G.issecretvalue or function()
	return false
end

local M = {}
ns.moments = M

local PREFIX = "KAPOW"
local SYNC_VERSION = "1"

local function Db()
	return ns.db
end

local function On(id)
	local db = Db()
	local cfg = db and db.events and db.events[id]
	return cfg and cfg.enabled and db.enabled
end

local function Fire(id, values)
	if ns.announcer and On(id) then
		ns.announcer:Fire(id, values)
	end
end

local function Plain(v)
	if issecretvalue(v) then
		return nil
	end
	return v
end

-- "Name-Realm" and "Name" compare equal.
local function ShortName(name)
	name = Plain(name)
	if type(name) ~= "string" then
		return nil
	end
	return (string.match(name, "^[^%-]+")) or name
end

local function MyName()
	return ShortName(UnitName("player"))
end

-- ── Format strings to patterns ────────────────────────────────────────────────────────
-- "%1$s has defeated %2$s in a duel" -> a Lua pattern and the argument number of each
-- capture, so the game's translated strings work in every language.

function M.Pattern(fmt)
	if type(fmt) ~= "string" then
		return nil
	end
	local out, order, auto, pos = {}, {}, 0, 1
	while pos <= #fmt do
		local n, kind, stop = string.match(fmt, "^%%(%d)%$([sd])()", pos)
		if not n then
			kind, stop = string.match(fmt, "^%%([sd])()", pos)
		end
		if kind then
			if not n then
				auto = auto + 1
				n = auto
			end
			order[#order + 1] = tonumber(n)
			out[#out + 1] = kind == "d" and "(%d+)" or "(.+)"
			pos = stop
		else
			local c = string.sub(fmt, pos, pos)
			if string.find(c, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
				c = "%" .. c
			end
			out[#out + 1] = c
			pos = pos + 1
		end
	end
	return "^" .. table.concat(out) .. "$", order
end

-- The arguments of `text` in format order, or nil when it does not match.
function M.Match(text, compiled)
	if not compiled or not compiled[1] then
		return nil
	end
	local caps = { string.match(text, compiled[1]) }
	if not caps[1] then
		return nil
	end
	local args = {}
	for i, argIndex in ipairs(compiled[2]) do
		args[argIndex] = caps[i]
	end
	return args
end

local compiled = {}
local function Compiled(globalName)
	local fmt = _G[globalName]
	local entry = compiled[globalName]
	if not entry or entry.fmt ~= fmt then
		local pattern, order = M.Pattern(fmt)
		entry = { pattern, order, fmt = fmt }
		compiled[globalName] = entry
	end
	return entry
end

-- ── Records ───────────────────────────────────────────────────────────────────────────

M.RECORD_LABELS = { multi = "multi-kill", spree = "spree", combo = "combo" }

local function Records()
	local char = ns.char
	if not char then
		return nil
	end
	if type(char.records) ~= "table" then
		char.records = {}
	end
	return char.records
end
M.Records = Records

-- Smallest earlier best worth beating out loud (a 2-kill spree record is not news).
M.RECORD_MIN = { multi = 2, spree = 5, combo = 5 }
local celebrated = {} -- kind -> true once this run has had its banner

-- A best for `kind` (multi, spree, combo) reached `value`: saved, and celebrated once per run
-- when it beats an earlier best of at least RECORD_MIN (the first best is just remembered).
function M.CheckRecord(kind, reached)
	local records = Records()
	if not records or type(reached) ~= "number" then
		return
	end
	local best = records[kind] or 0
	if reached > best then
		records[kind] = reached
		if best >= (M.RECORD_MIN[kind] or 1) and not celebrated[kind] then
			celebrated[kind] = true
			Fire("record", { name = M.RECORD_LABELS[kind] or kind, count = reached })
			M.Share("record", reached)
		end
	end
end

-- A run (multi-kill chain, spree, combo) ended: the next record may be celebrated again.
function M.EndRun(kind)
	celebrated[kind] = nil
end

function M.Count(kind, by)
	local records = Records()
	if records then
		local key = "total_" .. kind
		records[key] = (records[key] or 0) + (by or 1)
	end
end

function M.PrintRecords()
	local r = Records() or {}
	ns.Say(
		string.format(
			"records: best multi-kill %d, best spree %d, best combo %d  ·  kills %d, multi-kills %d, duels won %d, lost %d",
			r.multi or 0,
			r.spree or 0,
			r.combo or 0,
			r.total_kills or 0,
			r.total_multis or 0,
			r.total_duelwins or 0,
			r.total_duellosses or 0
		)
	)
end

function M.ResetRecords()
	if ns.char then
		ns.char.records = {}
	end
end

-- ── Party sync ────────────────────────────────────────────────────────────────────────

-- The events that travel; anything else in a message is ignored.
M.SHAREABLE = {
	double = true, triple = true, multi = true, mega = true, ultra = true, monster = true, ludicrous = true,
	spree5 = true, spree10 = true, spree15 = true, spree20 = true, spree25 = true, spree30 = true,
	firstblood = true, combo = true, record = true, duelwin = true,
}

local SHARE_GAP = 0.5
local lastShareAt = -100
local prefixRegistered = false

local function GroupChannel()
	if IsInGroup and _G.LE_PARTY_CATEGORY_INSTANCE and IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	elseif IsInRaid and IsInRaid() then
		return "RAID"
	elseif IsInGroup and IsInGroup() then
		return "PARTY"
	end
	return nil
end

local function SendFunc()
	local chat = _G.C_ChatInfo
	return chat and chat.SendAddonMessage or _G.SendAddonMessage
end

-- Tells the group about one of your moments. id: an event id; count: a plain number.
function M.Share(id, count)
	local db = Db()
	if not (db and db.enabled and db.partySync and M.SHAREABLE[id]) then
		return false
	end
	local channel = GroupChannel()
	local send = SendFunc()
	local now = GetTime()
	if not channel or not send or now - lastShareAt < SHARE_GAP then
		return false
	end
	if issecretvalue(count) or type(count) ~= "number" then
		count = 0
	end
	lastShareAt = now
	local ok = pcall(send, PREFIX, SYNC_VERSION .. "|" .. id .. "|" .. math.floor(count), channel)
	return ok
end

local function FeedLabel(id)
	local def = ns.EVENT_BY_ID and ns.EVENT_BY_ID[id]
	local label = def and def.label or id
	return (string.gsub(label, "%s*%b()$", ""))
end

-- A message from a groupmate's KAPOW.
function M.OnAddonMessage(prefix, text, sender)
	local db = Db()
	if not (db and db.enabled and db.partySync) then
		return
	end
	prefix, text = Plain(prefix), Plain(text)
	if prefix ~= PREFIX or type(text) ~= "string" then
		return
	end
	local who = ShortName(sender)
	if not who or who == MyName() then
		return
	end
	local version, id, count = string.match(text, "^(%d+)|([%w]+)|(%d+)$")
	if version ~= SYNC_VERSION or not M.SHAREABLE[id] then
		return
	end
	count = math.min(999, tonumber(count) or 0)
	if ns.announcer then
		local label = FeedLabel(id)
		if count > 1 then
			ns.announcer:FeedLine("|cff66ccff%s|r: %s x%d", who, label, count)
		else
			ns.announcer:FeedLine("|cff66ccff%s|r: %s", who, label)
		end
	end
end

-- ── Countdowns ────────────────────────────────────────────────────────────────────────

local countdownGen = 0

local function Countdown(seconds, goId, goValues)
	countdownGen = countdownGen + 1
	local gen = countdownGen
	for n = 3, 1, -1 do
		local at = seconds - n
		if at >= 0 then
			C_Timer.After(at, function()
				if gen == countdownGen then
					Fire("countdown", { count = n })
				end
			end)
		end
	end
	C_Timer.After(math.max(0, seconds), function()
		if gen == countdownGen then
			Fire(goId, goValues)
		end
	end)
end
M.Countdown = Countdown

local function OnStartTimer(timerType, timeRemaining)
	timeRemaining = Plain(timeRemaining)
	if type(timeRemaining) ~= "number" or timeRemaining <= 0 or timeRemaining > 120 then
		return
	end
	Countdown(timeRemaining, "countgo", {})
end

-- ── Duels ─────────────────────────────────────────────────────────────────────────────

local duelWith

local function OnSystemLine(text)
	text = Plain(text)
	if type(text) ~= "string" then
		return
	end
	local args = M.Match(text, Compiled("DUEL_COUNTDOWN"))
	if args then
		local n = tonumber(args[1])
		if not duelWith then
			duelWith = ShortName(UnitName("target"))
		end
		if n then
			Fire("countdown", { count = n })
			if n == 1 then
				local rival = duelWith or "your rival"
				C_Timer.After(1, function()
					Fire("duelstart", { name = rival })
				end)
			end
		end
		return
	end
	local winner, loser
	args = M.Match(text, Compiled("DUEL_WINNER_KNOCKOUT"))
	if args then
		winner, loser = args[1], args[2]
	else
		args = M.Match(text, Compiled("DUEL_WINNER_RETREAT"))
		if args then
			winner, loser = args[1], args[2]
		end
	end
	if not winner then
		return
	end
	local me = MyName()
	if ShortName(winner) == me then
		M.Count("duelwins")
		Fire("duelwin", { name = ShortName(loser) or loser })
		M.Share("duelwin", 1)
	elseif ShortName(loser) == me then
		M.Count("duellosses")
		Fire("duellose", { name = ShortName(winner) or winner })
	end
	duelWith = nil
end

-- ── Loot, achievements, quests, honorable kills ───────────────────────────────────────

local EPIC_COLORS = { a335ee = true, ff8000 = true, e6cc80 = true, ["00ccff"] = true }
local LOOT_STRINGS = { "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }

local function ItemQuality(link)
	local item = _G.C_Item
	if item and item.GetItemQualityByID then
		local ok, quality = pcall(item.GetItemQualityByID, link)
		if ok and type(quality) == "number" then
			return quality
		end
	end
	if _G.GetItemInfo then
		local ok, _, _, quality = pcall(_G.GetItemInfo, link)
		if ok and type(quality) == "number" then
			return quality
		end
	end
	local hex = string.match(link, "|c%x%x(%x%x%x%x%x%x)")
	if hex and EPIC_COLORS[string.lower(hex)] then
		return 4
	end
	return nil
end
M.ItemQuality = ItemQuality

local function OnLoot(text)
	text = Plain(text)
	if type(text) ~= "string" then
		return
	end
	for _, name in ipairs(LOOT_STRINGS) do
		local args = M.Match(text, Compiled(name))
		if args and args[1] then
			local quality = ItemQuality(args[1])
			if quality and quality >= 4 then
				Fire("epicloot", { name = args[1] })
			end
			return
		end
	end
end

local lastHonorKills

local function HonorKills()
	if not _G.GetPVPLifetimeStats then
		return nil
	end
	local ok, kills = pcall(_G.GetPVPLifetimeStats)
	kills = ok and Plain(kills) or nil
	return type(kills) == "number" and kills or nil
end

local function OnHonorKills()
	local kills = HonorKills()
	if kills and lastHonorKills and kills > lastHonorKills then
		Fire("honorkill", { count = kills })
	end
	lastHonorKills = kills or lastHonorKills
end

local function OnAchievement(achievementID, alreadyEarned)
	if Plain(alreadyEarned) == true or not _G.GetAchievementInfo then
		return
	end
	local ok, _, name = pcall(_G.GetAchievementInfo, achievementID)
	Fire("achievement", { name = (ok and name) or "" })
end

local function OnQuest(questID)
	local log = _G.C_QuestLog
	local title
	if log and log.GetTitleForQuestID then
		local ok, found = pcall(log.GetTitleForQuestID, questID)
		title = ok and found or nil
	end
	Fire("quest", { name = title or "" })
end

-- ── Wiring ────────────────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_SYSTEM" then
		OnSystemLine((...))
	elseif event == "DUEL_REQUESTED" then
		duelWith = ShortName((...))
	elseif event == "START_TIMER" then
		OnStartTimer(...)
	elseif event == "STOP_TIMER_OF_TYPE" then
		countdownGen = countdownGen + 1
	elseif event == "ENCOUNTER_START" then
		local _, name = ...
		Fire("bosspull", { name = name or "" })
	elseif event == "ACHIEVEMENT_EARNED" then
		OnAchievement(...)
	elseif event == "CHAT_MSG_LOOT" then
		OnLoot((...))
	elseif event == "QUEST_TURNED_IN" then
		OnQuest((...))
	elseif event == "PLAYER_PVP_KILLS_CHANGED" then
		if (...) == "player" then
			OnHonorKills()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		lastHonorKills = HonorKills()
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, text, _, sender = ...
		M.OnAddonMessage(prefix, text, sender)
	end
end)

local function Want(event, wanted)
	if wanted then
		pcall(frame.RegisterEvent, frame, event)
	end
end

function M.Sync()
	local db = Db()
	if not db then
		return
	end
	frame:UnregisterAllEvents()
	if not db.enabled then
		return
	end
	local duels = On("duelstart") or On("duelwin") or On("duellose")
	Want("CHAT_MSG_SYSTEM", duels or On("countdown"))
	Want("DUEL_REQUESTED", duels)
	Want("START_TIMER", On("countdown") or On("countgo"))
	Want("STOP_TIMER_OF_TYPE", On("countdown") or On("countgo"))
	Want("ENCOUNTER_START", On("bosspull"))
	Want("ACHIEVEMENT_EARNED", On("achievement"))
	Want("CHAT_MSG_LOOT", On("epicloot"))
	Want("QUEST_TURNED_IN", On("quest"))
	Want("PLAYER_PVP_KILLS_CHANGED", On("honorkill"))
	Want("PLAYER_ENTERING_WORLD", On("honorkill"))
	if On("honorkill") and not lastHonorKills then
		lastHonorKills = HonorKills()
	end
	if db.partySync then
		local chat = _G.C_ChatInfo
		if not prefixRegistered and chat and chat.RegisterAddonMessagePrefix then
			prefixRegistered = pcall(chat.RegisterAddonMessagePrefix, PREFIX)
		end
		Want("CHAT_MSG_ADDON", true)
	end
end

-- For tests: feed one event as the client would.
M.OnEvent = function(event, ...)
	frame:GetScript("OnEvent")(frame, event, ...)
end
