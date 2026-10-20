-- KAPOW
--
-- Comic-book frames for critical hits and killing blows: POW! (crit), K.O.! (kill),
-- OVERKILL! (crit that kills).
--
-- THE SECRET-VALUE PROBLEM
-- In 12.x the combat log is closed to addons, and the crit flag / death state of a hit can
-- arrive as a secret boolean: tainted code may hold it and pass it to certain APIs, but any
-- `if isCrit then` raises a Lua error. So this addon never branches on either value. It
-- hands them to Region:SetAlphaFromBoolean(), and the engine does the branching.
--
-- THE GATE TRICK
-- A region's effective alpha is the product of its own alpha and every parent's. Each comic
-- frame is therefore two nested "gate" frames around one texture:
--
--     root (animated: pop, hold, fade; plain alpha)
--       └─ critGate  alpha = isCrit ? a : b      <- SetAlphaFromBoolean(isCrit, ...)
--            └─ deadGate  alpha = isDead ? a : b <- SetAlphaFromBoolean(isDead, ...)
--                 └─ texture
--
-- 1 × 1 = visible, anything × 0 = invisible, which is a logical AND of two secret booleans
-- without ever reading either. Flipping each gate's (true, false) alphas gives NOT, so:
--
--     POW!      critGate = isCrit      deadGate = NOT isDead
--     K.O.!     critGate = NOT isCrit  deadGate = isDead
--     OVERKILL! critGate = isCrit      deadGate = isDead
--
-- Exactly one of the three is visible for any (crit, dead) pair, or none for a plain hit.
-- The animation runs on `root`, never on a gate, so it cannot fight the secret alpha aspect.
--
-- DAMAGE NUMBERS
-- The hit's amount is secret in combat too. It cannot be compared, so it cannot decide
-- anything, but FontString:SetText() accepts secrets: the client draws the number and the
-- addon never sees it. The label sits inside deadGate, so it is gated with its frame.
--
-- OLDER CLIENTS (16001 / 110x)
-- SetAlphaFromBoolean is 12.0+. Clients without it have no secret values either, so the gate
-- falls back to a plain SetAlpha. Same for C_CombatText vs. the legacy combat-text globals.
--
-- WHAT IS GUESSED (see /kapow debug, which exists to settle each of these in the live client)
--   * The combat-text feed with its active unit set to "target" delivers hits on the target
--     and exposes a crit flag, either in the message type or in the event info.
--   * UnitIsDead("target") is readable (plain or secret) shortly after the killing hit.
--   * SetAlphaFromBoolean takes alpha on a 0-1 scale.
--   * "OVERKILL" means a critical killing blow. Real overkill damage (damage minus remaining
--     health) is arithmetic on secrets, which is not allowed.

local ADDON_NAME, ns = ...

local issecretvalue = _G.issecretvalue or function()
	return false
end

-- Flat settings of a profile (Profiles.lua). Per-event looks live in profile.events
-- (Events.lua); the minimap button's place is account-wide.
local DEFAULTS = {
	enabled = true,
	scale = 1.0,
	x = 0,
	y = 140,
	attribution = "recent", -- "recent": only hits shortly after your own cast/auto-attack; "any": every hit on target
	minInterval = 0.12, -- seconds between pops
	killDelay = 0.15, -- seconds to wait for the target's death state to settle after a hit
	jitter = true, -- small random offset and tilt per pop
	jitterX = 40, -- pixels each way, left and right
	jitterY = 20, -- pixels each way, up and down
	jitterTilt = 8, -- degrees each way
	jitterBanners = false, -- the same random offset and tilt on Announcer banners
	meter = false, -- the hit-meter prototype panel (Meter.lua)
	meterSource = "hit", -- which health reading drives the OVERKILL slide: "hit" or "prev"
	-- Kill detection. Either source, both, or neither (then only crits pop).
	killEvent = true, -- PARTY_KILL: the client names the killing blow's attacker
	killUnitDead = true, -- UnitIsDead("target") read killDelay after your hit
	killPet = true, -- count your pet's kills from PARTY_KILL or the optional backup
	killPetBackup = false, -- estimate pet kills from a watched target's death when PARTY_KILL is missing
	killLog = false, -- print who landed every PARTY_KILL, to check group and pet behaviour
	-- Experimental tab: sounds of the three hit events. Off: hit events stay silent.
	hitSounds = false, -- play the matching hit event's sound when the game tells the hit type plainly
	hitSoundsSecret = false, -- also when it hides crit/kill: then every hit event with a sound plays it
	-- More kill sources (Detect.lua), each optional.
	killTargetDied = false, -- PLAYER_TARGET_DIED: the exact moment your target died (not whose blow)
	killLogLine = false, -- your killing blow's white line in Blizzard's combat log (colour only)
	killStatistic = false, -- a kill statistic (killStatId) going up confirms your kill
	killStatId = 0,
	-- Damage meter (Experimental tab). Overkill reading clears Blizzard's damage meter window.
	meterOverkill = false, -- overkill of your killing hit on OVERKILL! and in {overkill}
	meterInterrupts = false, -- the meter's Interrupts count confirms your interrupts on any enemy
	interruptGrow = true, -- each interrupt in a row shows bigger (and fills {count})
	feedUnit = "target", -- combat-text unit: "target" (switch it, as before) or "leave" (never touch it)
	-- Announcer (Announcer.lua). Which banners show is per event.
	annFirstBloodSolo = false, -- FIRST BLOOD also when you are not in a group
	annFeed = true, -- kill feed: who killed what
	annSound = true, -- master switch for event sounds
	annStack = false, -- several banners at once (stacked) instead of one after another
	annStreakBar = false, -- a draining bar: time left to chain your next kill into a multi-kill
	uwu = false, -- UwU mode: a cute word floats up over your character on crits
	uwuSound = "none", -- its sound, played only when the game tells the crit plainly
	-- Extras.lua, all off by default.
	comboCounter = false, -- "12 HITS" while you keep hitting your target; Combo banner when it ends
	comboMin = 5, -- hits for the Combo banner
	flash = "off", -- impact flash: "off", "critkill", "kill" or "crit"
	dangerLow = false, -- red screen edges while your health is low (works on hidden health)
	dangerAt = 0.25,
	finishIt = false, -- "FINISH IT!" while your target is in execute range (works on hidden health)
	finishAt = 0.20,
	reduceMotion = false, -- calmer: no movement, tilt or flash, shorter shows
	partySync = false, -- tell groupmates who run KAPOW about your big moments (their kill feed)
	gamepadNav = false, -- drive the settings window with a controller
	-- Places (Extras.lua's unlock mode drags these; offsets from screen centre).
	bannerX = 0,
	bannerY = 260,
	barX = 0,
	barY = 190,
	uwuX = 0,
	uwuY = 40,
	comboX = -300,
	comboY = 80,
	finishX = 0,
	finishY = 230,
	debug = false,
}
ns.DEFAULTS = DEFAULTS

local db

ns.IsSecret = issecretvalue

-- ── Client compatibility ──────────────────────────────────────────────────────────────
local CombatText = _G.C_CombatText
local SetActiveUnit = (CombatText and CombatText.SetActiveUnit) or _G.CombatTextSetActiveUnit
local GetEventInfo = (CombatText and CombatText.GetCurrentEventInfo) or _G.GetCurrentCombatTextEventInfo
local IsCurrentSpellFn = (_G.C_Spell and _G.C_Spell.IsCurrentSpell) or _G.IsCurrentSpell

-- Damage amount -> label text. `amount` may be a secret number or string: no comparisons,
-- no arithmetic, no conversion, only type() and calls documented to take secrets. The
-- client's formatters accept secrets from addon code (SecretArguments = "AllowedWhenTainted"):
-- AbbreviateNumbers ("12.3K") first, then BreakUpLargeNumbers ("12,345"). Without either,
-- the value goes to SetText as it is.
local function AmountText(amount)
	local kind = type(amount)
	if kind ~= "number" and kind ~= "string" then
		return ""
	end
	local format = _G.AbbreviateNumbers or _G.BreakUpLargeNumbers
	if format and kind == "number" then
		local ok, text = pcall(format, amount)
		if ok and type(text) == "string" then
			return text
		end
	end
	return amount
end
ns.AmountText = AmountText

-- Sets a gate's alpha from a boolean that may be secret. Never reads `value` itself when
-- the engine can do it.
local function Gate(region, value, ifTrue, ifFalse)
	if region.SetAlphaFromBoolean then
		region:SetAlphaFromBoolean(value, ifTrue, ifFalse)
	elseif not issecretvalue(value) then
		if value then
			region:SetAlpha(ifTrue)
		else
			region:SetAlpha(ifFalse)
		end
	end
end

ns.Gate = Gate

-- ── Hit frames ────────────────────────────────────────────────────────────────────────
-- wantCrit / wantDead: the (crit, dead) pair for which this frame is visible; event: whose
-- look (art, animation, text, ...) it shows.
local STYLES = {
	{ key = "pow", event = "crit", wantCrit = true, wantDead = false },
	{ key = "ko", event = "kill", wantCrit = false, wantDead = true },
	{ key = "overkill", event = "critkill", wantCrit = true, wantDead = true },
}

local FRAME_SIZE = 256
local HIT_LIFE = 1.0 -- seconds a hit frame stays

local frames -- key -> { root, critGate, deadGate, stage }, built once Display.lua has loaded

local function EnsureFrames()
	if frames then
		return
	end
	frames = {}
	for _, style in ipairs(STYLES) do
		local root = CreateFrame("Frame", "KapowFrame_" .. style.key, UIParent)
		root:SetSize(FRAME_SIZE, FRAME_SIZE)
		root:SetFrameStrata("HIGH")
		root:EnableMouse(false)
		root:Hide()

		local critGate = CreateFrame("Frame", nil, root)
		critGate:SetAllPoints(root)
		local deadGate = CreateFrame("Frame", nil, critGate)
		deadGate:SetAllPoints(critGate)

		-- Art, title and damage number all inside deadGate; animation on root only.
		local stage = ns.display.NewStage(root, deadGate, HIT_LIFE)
		frames[style.key] = { root = root, critGate = critGate, deadGate = deadGate, stage = stage }
	end
end

-- ── UwU mode ──────────────────────────────────────────────────────────────────────────
-- An idea from the Forever UwU addon, built KAPOW's way: a cute word rises over your character
-- on crits. The crit flag may be secret, so the word sits under its own crit gate (the same
-- trick as the comic frames) and the client decides whether it shows. Its sound cannot be
-- gated, so it plays only when the crit flag is plain.
local UWU_WORDS = { "uwu~", "owo~", "ara ara~", "nya~", "kawaii~", "rawr x3", "senpai~", "baka~" }
local uwu -- { root, gate, text, anim }, built on first use

local function EnsureUwu()
	if uwu then
		return uwu
	end
	local root = CreateFrame("Frame", "KapowUwU", UIParent)
	root:SetSize(240, 60)
	root:SetPoint("CENTER", UIParent, "CENTER", db.uwuX or 0, db.uwuY or 40)
	root:SetFrameStrata("HIGH")
	root:EnableMouse(false)
	root:Hide()
	local gate = CreateFrame("Frame", nil, root)
	gate:SetAllPoints(root)
	local text = gate:CreateFontString(nil, "OVERLAY")
	local font = ns.display.FONTS["bubblegum-sans"] or ns.display.FONTS.friz
	if not text:SetFont(font[2], 30, "THICKOUTLINE") then
		text:SetFont(ns.display.FONTS.friz[2], 30, "THICKOUTLINE")
	end
	text:SetTextColor(1, 0.55, 0.85)
	text:SetPoint("CENTER", gate, "CENTER", 0, 0)
	local anim = root:CreateAnimationGroup()
	local rise = anim:CreateAnimation("Translation")
	rise:SetOffset(0, 50)
	rise:SetDuration(1.2)
	rise:SetSmoothing("OUT")
	local fade = anim:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	fade:SetStartDelay(0.6)
	fade:SetDuration(0.6)
	anim:SetScript("OnFinished", function()
		root:Hide()
	end)
	uwu = { root = root, gate = gate, text = text, anim = anim }
	if ns.extras then
		ns.extras.Register("uwu", root)
	end
	return uwu
end

-- isCrit may be secret: it only ever reaches the gate (and PlainBool for the sound).
local function UwuPop(isCrit)
	local u = EnsureUwu()
	Gate(u.gate, isCrit, 1, 0)
	u.text:SetText(UWU_WORDS[math.random(1, #UWU_WORDS)])
	u.anim:Stop()
	u.root:SetAlpha(1)
	u.root:Show()
	u.anim:Play()
	return u
end
ns.UwuPop = UwuPop

-- ── Showing a pop ─────────────────────────────────────────────────────────────────────
-- isCrit / isDead may be secret booleans, amount a secret number, or plain values from
-- /kapow test. Never read them.
local popValues = {}
local popOpts = {}

-- A random offset and tilt within the jitter settings (0, 0, 0 with jitter off).
local function Spread(limit)
	local n = math.floor(math.max(0, tonumber(limit) or 0))
	return n > 0 and math.random(-n, n) or 0
end

function ns.Jitter()
	if not db.jitter or db.reduceMotion then
		return 0, 0, 0
	end
	return Spread(db.jitterX), Spread(db.jitterY), math.rad(Spread(db.jitterTilt))
end
-- The Crit kill look with its detail line swapped for one that adds the overkill (meterOverkill).
local overkillMeta = {}
local overkillCfg = setmetatable({ sub = "{amount}  +{overkill} overkill" }, overkillMeta)

-- A plain copy of a possibly-secret boolean, or nil when the game hid it.
local function PlainBool(v)
	if issecretvalue(v) then
		return nil
	end
	return v == true
end

local function Pop(isCrit, isDead, amount)
	EnsureFrames()
	if db.flash ~= "off" and ns.extras then
		ns.extras.Flash(isCrit, isDead)
	end
	if db.uwu then
		UwuPop(isCrit)
		if PlainBool(isCrit) == true and db.uwuSound ~= "none" then
			ns.display.PlaySound(db.uwuSound)
		end
	end
	-- Sound cannot be gated by the secret alpha, so it plays only where the hit type is known:
	-- with plain flags exactly the visible frame's sound, with hidden ones none (or, with the
	-- experimental hitSoundsSecret, every hit event's sound as before).
	local knownCrit, knownDead = PlainBool(isCrit), PlainBool(isDead)
	local known = knownCrit ~= nil and knownDead ~= nil
	-- The damage meter's overkill of this kill (maybe secret, only ever drawn), or nil.
	local overkill = ns.detect and ns.detect.FreshOverkill()
	local hasOverkill = issecretvalue(overkill) or overkill ~= nil
	popValues.overkill = hasOverkill and AmountText(overkill) or nil
	popValues.amount = AmountText(amount)
	popOpts.dx, popOpts.dy, popOpts.tilt = ns.Jitter()
	for _, style in ipairs(STYLES) do
		local f = frames[style.key]
		local cfg = ns.EventConfig(style.event)
		if cfg.enabled then
			Gate(f.critGate, isCrit, style.wantCrit and 1 or 0, style.wantCrit and 0 or 1)
			Gate(f.deadGate, isDead, style.wantDead and 1 or 0, style.wantDead and 0 or 1)
			local audible
			if known then
				audible = knownCrit == style.wantCrit and knownDead == style.wantDead
			else
				audible = db.hitSoundsSecret
			end
			popOpts.silent = not (db.hitSounds and audible)
			local look = cfg
			if hasOverkill and style.event == "critkill" and cfg.details then
				overkillMeta.__index = cfg
				look = overkillCfg
			end
			ns.display.Play(f.stage, look, popValues, popOpts)
		else
			ns.display.Stop(f.stage)
		end
	end
end

-- ── Attribution ───────────────────────────────────────────────────────────────────────
-- The target feed reports every hit on the target, yours or a groupmate's. "recent" keeps
-- only hits that follow one of your own casts (player spellcasts are non-secret) or that
-- land while auto-attack is running. DoTs ticking after the window are not counted.
local lastCastAt = 0

local function IsMine()
	if db.attribution == "any" then
		return true
	end
	if GetTime() - lastCastAt <= 0.7 then
		return true
	end
	if IsCurrentSpellFn then
		local ok, auto = pcall(IsCurrentSpellFn, 6603) -- Auto Attack
		if ok and not issecretvalue(auto) and auto then
			return true
		end
	end
	return false
end

-- ── Debug ─────────────────────────────────────────────────────────────────────────────
local function Say(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd60aKAPOW|r " .. msg)
end
ns.Say = Say

local function Describe(v)
	if issecretvalue(v) then
		return "<secret " .. type(v) .. ">"
	end
	return type(v) .. ":" .. tostring(v)
end

-- ── Killing blows ─────────────────────────────────────────────────────────────────────
-- Two sources, each a separate option:
--
--   PARTY_KILL (killEvent). The client names the attacker of every killing blow in your
--   group. Its payload is SecretWhenUnitIdentityRestricted, which makes values secret for
--   units that are not player-controlled or in your party/raid. You and your pet are
--   neither, so attackerGUID should be plain for your own kills; the victim's GUID is
--   probably secret and is not needed. A secret attacker is simply not counted.
--
--   UnitIsDead (killUnitDead). The target's death state, read killDelay after your hit.
--   May be secret; it goes to the death gate unread. It cannot tell whose blow it was.
--
-- PARTY_KILL can arrive just before or just after the hit that caused it, so a kill counts
-- for any hit within KILL_WINDOW of it.
local KILL_WINDOW = 0.3

local lastKillAt = -100 -- GetTime() of the latest killing blow by you (or your pet)
local killConsumed = true -- whether a pop has already shown that kill

-- The latest hit on the target, attributed or not. A pet's killing blow pops with it.
local lastHitAt, lastHitCrit, lastHitAmount = -100, false, nil
local lastHitKey -- TargetKey() of the target that hit landed on
local targetSerial = 0

-- Secret first: a secret may not even be compared with nil.
local function Plain(v)
	return not issecretvalue(v) and v ~= nil
end

-- Who landed a killing blow: "you", "pet", "group", "grouppet", "other" or "secret", plus
-- the group unit token when there is one.
local function WhoKilled(attackerGUID)
	if issecretvalue(attackerGUID) then
		return "secret"
	end
	if type(attackerGUID) ~= "string" then
		return "other"
	end
	local attacker = attackerGUID -- checked plain above
	local me = UnitGUID("player")
	if Plain(me) and attacker == me then
		return "you"
	end
	local pet = UnitGUID("pet")
	if Plain(pet) and attacker == pet then
		return "pet"
	end
	local prefix, count = "party", GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
	if IsInRaid and IsInRaid() then
		prefix, count = "raid", GetNumGroupMembers()
	end
	for i = 1, count do
		local unit = prefix .. i
		local guid = UnitGUID(unit)
		if Plain(guid) and attacker == guid then
			return "group", unit
		end
		local petUnit = prefix .. "pet" .. i
		local petGUID = UnitGUID(petUnit)
		if Plain(petGUID) and attacker == petGUID then
			return "grouppet", petUnit
		end
	end
	return "other"
end

local function UnitLabel(unit)
	local name = UnitName(unit)
	if Plain(name) and type(name) == "string" then
		return name
	end
	return unit
end

ns.Plain, ns.WhoKilled, ns.UnitLabel = Plain, WhoKilled, UnitLabel

-- ── Pet kill backup (optional, off by default) ────────────────────────────────────────
-- Only deduplicates collisions with the optional backup; ordinary PARTY_KILL handling stays
-- unchanged. A kill is matched by its victim GUID when that is plain. When the client hides
-- it (unit-identity restrictions make GUIDs secret), timing decides instead: a killing-blow
-- report and an estimate less than DUP_WINDOW apart are taken to be the same kill.
local DUP_WINDOW = 1.0
local OWN_DUP = 0.5 -- a log line, a statistic and a PARTY_KILL of yours this close are one kill
local recentKills = {}
local lastOwnKillAt, lastOwnSource = -100, nil -- the latest kill of yours shown, and from where
local lastReportAt, lastReportGUID, lastReportPet = -100, nil, false
local lastBackupAt, lastBackupGUID, lastBackupKey = -100, nil, nil

local function PlainGUID(guid)
	if Plain(guid) and type(guid) == "string" then
		return guid
	end
end

local function FindKill(guid)
	local plain = PlainGUID(guid)
	if not plain then
		return nil
	end
	for _, entry in ipairs(recentKills) do
		if entry.guid == plain and GetTime() - entry.at < 10 then
			return entry
		end
	end
end

local function RememberKill(guid, backup)
	if #recentKills >= 32 then
		table.remove(recentKills, 1)
	end
	recentKills[#recentKills + 1] = { guid = guid, at = GetTime(), backup = backup }
end

-- Whether a kill is new. backup = true: the estimate asks. Otherwise a PARTY_KILL asks, with
-- `who` from WhoKilled. Kapow.lua and Announcer.lua both ask about the same PARTY_KILL and
-- get the same answer.
function ns.TrackKill(guid, backup, who)
	local now = GetTime()
	local plain = PlainGUID(guid)
	if backup then
		if plain and FindKill(plain) then
			return false
		end
		if now - lastOwnKillAt <= DUP_WINDOW then
			return false -- a log line, statistic or report of yours already showed this kill
		end
		-- A report around this death that cannot be told apart from it wins: one with a hidden
		-- victim, or the pet's own report when either GUID is hidden.
		if now - lastReportAt <= DUP_WINDOW
			and (lastReportGUID == nil or (lastReportPet and (plain == nil or lastReportGUID == plain))) then
			return false
		end
		lastBackupAt, lastBackupGUID = now, plain
		if plain then
			RememberKill(plain, true)
		end
		return true
	end
	local entry = FindKill(plain)
	local fresh
	local own = who == "you" or who == "pet"
	if own and lastOwnSource ~= "report" and now - lastOwnKillAt <= OWN_DUP then
		fresh = false -- the combat-log line or the statistic already showed this kill
	elseif entry then
		fresh = not entry.backup
	elseif who == "pet" and now - lastBackupAt <= DUP_WINDOW and (lastBackupGUID == nil or plain == nil) then
		fresh = false -- the pet kill the estimate already showed, reported with a hidden GUID
	else
		fresh = true
		if plain then
			RememberKill(plain, false)
		end
	end
	lastReportAt, lastReportGUID, lastReportPet = now, plain, who == "pet"
	if own and fresh then
		lastOwnKillAt, lastOwnSource = now, "report"
	end
	return fresh
end

-- The selected target as something comparable: its GUID when plain, otherwise the selection
-- itself (PLAYER_TARGET_CHANGED bumps targetSerial), so a hidden identity still works.
local serialKey, serialKeyFor
local function TargetKey()
	local guid = PlainGUID(UnitGUID("target"))
	if guid then
		return guid, guid
	end
	local exists = UnitExists("target")
	if issecretvalue(exists) or not exists then
		return nil
	end
	if serialKeyFor ~= targetSerial then
		serialKey, serialKeyFor = "target#" .. targetSerial, targetSerial
	end
	return serialKey, nil
end

-- Watch an alive target while the pet is actually fighting it. The short grace window
-- covers pettarget disappearing on death; it does not credit an idle pet's selected target.
-- This confirms death, not the killer: the UI labels the attribution as an estimate.
local petWatch = CreateFrame("Frame", "KapowPetKillWatcher")
local petKey, petAlive, petPending
local petSeenAt, petElapsed, petGeneration = -100, 0, 0

local function ResetPetWatch()
	petGeneration = petGeneration + 1
	petKey, petAlive, petPending = nil, false, false
	petSeenAt, petElapsed = -100, 0
end

local function PetBackupOn()
	return db and db.enabled and db.killPet and db.killPetBackup
end

local function ReadPetDead()
	local state = UnitIsDead("target")
	if not issecretvalue(state) and type(state) == "boolean" then
		return state
	end
end

local function PollPetKill()
	if not PetBackupOn() then
		return
	end
	local key, guid = TargetKey()
	if not key then
		ResetPetWatch()
		return
	end
	if key ~= petKey then
		ResetPetWatch()
		petKey = key
	end
	local state = ReadPetDead()
	if state == nil then
		ResetPetWatch()
		return
	end
	if not state then
		petAlive = true
		local exists = UnitExists("pet")
		if not issecretvalue(exists) and exists then
			local ok, same = pcall(UnitIsUnit, "pettarget", "target")
			local fighting = UnitAffectingCombat("pet")
			if ok and not issecretvalue(same) and not issecretvalue(fighting) and same and fighting then
				petSeenAt = GetTime()
			end
		end
		return
	end
	if not petAlive or petPending or GetTime() - petSeenAt > 0.7 or FindKill(guid) then
		return
	end
	petPending = true
	local serial, generation = targetSerial, petGeneration
	-- The victim's GUID as the client gives it (maybe secret): only for drawing its name.
	local rawGUID = UnitGUID("target")
	-- Give a real killing-blow event priority over the estimate.
	C_Timer.After(db.killDelay, function()
		if not PetBackupOn() or serial ~= targetSerial or generation ~= petGeneration or key ~= petKey then
			return
		end
		petPending = false
		if ReadPetDead() ~= true or not ns.TrackKill(guid, true) then
			return
		end
		lastBackupKey = key
		local crit, damage = false, nil
		if lastHitKey == key and GetTime() - lastHitAt <= KILL_WINDOW + db.killDelay then
			crit, damage = lastHitCrit, lastHitAmount
		end
		Pop(crit, true, damage)
		if ns.announcer then
			ns.announcer:PetKill(rawGUID)
		end
		if db.killLog then
			Say("kill: your pet, your target — backup estimate (no PARTY_KILL)")
		end
	end)
end

-- Whether the backup has taken (or is taking) the kill on the target a hit landed on.
local function PetBackupHandles(key)
	if not PetBackupOn() or not key then
		return false
	end
	if petPending and key == petKey then
		return true
	end
	if lastBackupKey == key and GetTime() - lastBackupAt <= DUP_WINDOW then
		return true
	end
	local entry = FindKill(key) -- the key is the GUID when that is plain
	return entry ~= nil and entry.backup
end

local function PollPetUpdate(_, elapsed)
	petElapsed = petElapsed + elapsed
	if petElapsed >= 0.05 then
		petElapsed = 0
		PollPetKill()
	end
end

local WHO_TEXT = {
	you = "you",
	pet = "your pet",
	other = "someone outside your group",
	secret = "a secret attacker",
}

local function LogKill(who, unit, victimGUID, counted)
	local whoText = WHO_TEXT[who]
	if who == "group" then
		whoText = UnitLabel(unit) .. " (group)"
	elseif who == "grouppet" then
		whoText = UnitLabel(unit) .. " (group pet)"
	end
	local victim
	if not Plain(victimGUID) then
		victim = "victim secret"
	else
		local victimPlain = victimGUID -- checked plain above
		local target = UnitGUID("target")
		if Plain(target) and victimPlain == target then
			victim = "your target"
		else
			victim = "not your target"
		end
	end
	local verdict
	if counted then
		verdict = "|cff40ff40counted|r"
	elseif who == "pet" then
		verdict = "ignored: pet kills are off"
	elseif not db.killEvent then
		verdict = "ignored: killing-blow event is off"
	else
		verdict = "not yours"
	end
	Say("kill: " .. whoText .. ", " .. victim .. " — " .. verdict)
end

-- Whether a hit at `hitAt` killed. Plain true for a counted killing blow; otherwise the
-- UnitIsDead reading (possibly secret), or plain false.
-- skipTargetRead: the target changed since the hit, so UnitIsDead would describe another unit.
-- serial: targetSerial when the hit landed (PLAYER_TARGET_DIED is tied to that selection).
local function ResolveDead(hitAt, skipTargetRead, serial)
	if (db.killEvent or db.killLogLine or db.killStatistic) and lastKillAt >= hitAt - KILL_WINDOW then
		killConsumed = true
		return true
	end
	if ns.detect and ns.detect.TargetDiedSince(hitAt - KILL_WINDOW, serial) then
		return true
	end
	if db.killUnitDead and not skipTargetRead then
		local dead = UnitIsDead("target")
		if type(dead) == "boolean" then
			return dead
		end
	end
	return false
end

local function OnPartyKill(attackerGUID, victimGUID)
	if not db.enabled then
		return
	end
	local who, unit = WhoKilled(attackerGUID)
	local fresh = ns.TrackKill(victimGUID, false, who)
	local counted = db.killEvent and (who == "you" or (who == "pet" and db.killPet))
	if db.killLog then
		LogKill(who, unit, victimGUID, counted)
	end
	if not counted or not fresh then
		return
	end
	local killAt = GetTime()
	lastKillAt, killConsumed = killAt, false
	-- A pending hit claims the kill when its timer fires. If none does (a pet's blow, a hit
	-- the attribution filter dropped), show the kill with the latest hit's crit and amount.
	C_Timer.After(db.killDelay + 0.05, function()
		if killConsumed or lastKillAt ~= killAt or not db.enabled then
			return
		end
		killConsumed = true
		local isCrit, amount = false, nil
		if killAt - lastHitAt <= KILL_WINDOW then
			isCrit, amount = lastHitCrit, lastHitAmount
		end
		Pop(isCrit, true, amount)
	end)
end

-- A kill of yours from a source that names no victim: the white combat-log line or the kill
-- statistic. Shown like a counted PARTY_KILL, once (TrackKill deduplicates the report).
local OWN_SOURCES = { log = "the combat log's white line", statistic = "the kill statistic" }
local function OwnKill(source)
	if not db.enabled then
		return
	end
	local killAt = GetTime()
	if killAt - lastOwnKillAt <= OWN_DUP then
		return
	end
	lastOwnKillAt, lastOwnSource = killAt, source
	lastKillAt, killConsumed = killAt, false
	C_Timer.After(db.killDelay + 0.05, function()
		if killConsumed or lastKillAt ~= killAt or not db.enabled then
			return
		end
		killConsumed = true
		local isCrit, amount = false, nil
		if killAt - lastHitAt <= KILL_WINDOW then
			isCrit, amount = lastHitCrit, lastHitAmount
		end
		Pop(isCrit, true, amount)
	end)
	if ns.announcer then
		-- The victim is most likely your dead target; its GUID (maybe secret) only names it.
		local targetDead = PlainBool(UnitIsDead("target"))
		ns.announcer:OwnKill(targetDead and UnitGUID("target") or nil)
	end
	if db.killLog then
		Say("kill: you — from " .. OWN_SOURCES[source])
	end
end

function ns.OnLogKill()
	OwnKill("log")
end

function ns.OnStatKill()
	OwnKill("statistic")
end

function ns.TargetSerial()
	return targetSerial
end

-- PLAYER_TARGET_DIED (Detect.lua): lets the pet backup see the death at once.
function ns.OnTargetDied()
	if PetBackupOn() then
		PollPetKill()
	end
end

-- ── Resolving a hit ───────────────────────────────────────────────────────────────────
local lastPopAt = 0

-- Called with the crit flag of one hit. Whether it killed is decided a moment later,
-- because neither the death state nor PARTY_KILL is in place at the instant of the hit.
local accurateHit -- the hit Accurate attribution is about to decide (both feeds may report it)
local lastMyHitAt, lastMyHitKey = -100, nil -- the latest hit judged yours, and on what

-- A hit was judged yours (any attribution mode): feeds the combo counter and assists.
local function MyHit(now, key)
	lastMyHitAt, lastMyHitKey = now, key
	if ns.extras then
		ns.extras.OnMyHit(key, now)
	end
end

-- Whether you hit the victim of a kill in the last few seconds (Announcer's Assist). The victim's
-- GUID may be hidden: then your current target counts if it is the one you hit and is dead.
function ns.MyHitOn(victimGUID)
	if GetTime() - lastMyHitAt > 6 or not lastMyHitKey then
		return false
	end
	local plain = PlainGUID(victimGUID)
	if plain then
		return plain == lastMyHitKey
	end
	return TargetKey() == lastMyHitKey and PlainBool(UnitIsDead("target")) == true
end

-- The pop of a hit already judged yours, killDelay after it landed.
local function Resolve(isCrit, amount, now, hitKey, serial)
	-- With the pet backup on, a target change during the delay still shows the hit; only a
	-- reported killing blow can then make it a kill, not the new target's death state.
	local stale = PetBackupOn() and serial ~= targetSerial
	if not stale then
		PollPetKill()
		if PetBackupHandles(hitKey) then
			return
		end
	end
	Pop(isCrit, ResolveDead(now, stale, serial), amount)
end

-- Accurate attribution (Attribution.lua) decides after the delay, when a swing or a combat-log
-- line reported just after the hit is known too; the throttle applies to hits judged yours.
local function OnAccurateHit(isCrit, amount, school, now, hitKey, serial)
	if accurateHit and now - accurateHit.at < 0.05 then
		-- The same hit from the other feed: keep the school if this one has it.
		if accurateHit.school == nil then
			accurateHit.school = school
		end
		return
	end
	local hit = { at = now, school = school }
	accurateHit = hit
	C_Timer.After(db.killDelay, function()
		if not db.enabled or not ns.attribution then
			return
		end
		local who = ns.attribution.Match(hit.school, hit.at)
		if not who or (who == "pet" and not db.killPet) then
			return
		end
		MyHit(now, hitKey)
		if ns.meter then
			ns.meter:OnHit(amount)
		end
		local t = GetTime()
		if t - lastPopAt < db.minInterval then
			return
		end
		lastPopAt = t
		Resolve(isCrit, amount, now, hitKey, serial)
	end)
end

local function OnHit(isCrit, amount, school)
	if not db.enabled then
		return
	end
	local now = GetTime()
	lastHitAt, lastHitCrit, lastHitAmount = now, isCrit, amount
	lastHitKey = TargetKey()
	local hitKey, serial = lastHitKey, targetSerial
	if db.attribution == "accurate" then
		OnAccurateHit(isCrit, amount, school, now, hitKey, serial)
		return
	end
	if not IsMine() then
		return
	end
	MyHit(now, hitKey)
	-- The meter sees every attributed hit, before the pop throttle.
	if ns.meter then
		ns.meter:OnHit(amount)
	end
	if now - lastPopAt < db.minInterval then
		return
	end
	lastPopAt = now
	C_Timer.After(db.killDelay, function()
		if not db.enabled then
			return
		end
		Resolve(isCrit, amount, now, hitKey, serial)
	end)
end

-- ── Event sources ─────────────────────────────────────────────────────────────────────
local CRIT_TYPES = { DAMAGE_CRIT = true, SPELL_DAMAGE_CRIT = true }
local HIT_TYPES = { DAMAGE = true, SPELL_DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE_CRIT = true }

local function OnCombatText(messageType)
	-- Same layout as Blizzard_CombatText: `data, arg3, arg4 = GetCurrentEventInfo()`. For
	-- damage types the amount is the first value; the third is the crit flag on partials.
	local ok, ret1, ret2, ret3
	if GetEventInfo then
		ok, ret1, ret2, ret3 = pcall(GetEventInfo)
	end

	if db.debug then
		Say(
			"CTU type="
				.. Describe(messageType)
				.. " info1(amount)="
				.. Describe(ret1)
				.. " info2="
				.. Describe(ret2)
				.. " info3(crit?)="
				.. Describe(ret3)
				.. " dead="
				.. Describe(UnitIsDead("target"))
		)
	end

	if not issecretvalue(messageType) and type(messageType) == "string" then
		-- Readable message type: filter to damage, and derive the crit flag as a plain boolean.
		if not HIT_TYPES[messageType] then
			return
		end
		OnHit(CRIT_TYPES[messageType] == true, ret1)
	elseif ok then
		-- Secret message type: cannot be filtered. Use the feed's crit flag (PulseHaptics reads
		-- it as the third value after pcall on RESIST/ABSORB entries) and let the engine
		-- decide visibility. Unconfirmed; compare with `/kapow debug`.
		-- type() reports the real type even for a secret, so this test is safe.
		if type(ret3) == "boolean" then
			OnHit(ret3, ret1)
		end
	end
end

local function OnUnitCombat(unit, action, flagText, amount, schoolMask)
	if unit ~= "target" then
		return
	end
	if db.debug then
		Say(
			"UNIT_COMBAT action="
				.. Describe(action)
				.. " flag="
				.. Describe(flagText)
				.. " amount="
				.. Describe(amount)
				.. " dead="
				.. Describe(UnitIsDead("target"))
		)
	end
	if issecretvalue(action) or issecretvalue(flagText) then
		return -- a secret string cannot be turned into a boolean; COMBAT_TEXT_UPDATE is the path for that
	end
	if action ~= "WOUND" then
		return -- heals, energizes, misses, dodges and the like
	end
	OnHit(flagText == "CRITICAL", amount, schoolMask)
end

local driver = CreateFrame("Frame")
local function SyncSources()
	ResetPetWatch()
	petWatch:SetScript("OnUpdate", PetBackupOn() and PollPetUpdate or nil)
	driver:UnregisterEvent("COMBAT_TEXT_UPDATE")
	driver:UnregisterEvent("UNIT_COMBAT")
	driver:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	pcall(driver.UnregisterEvent, driver, "PARTY_KILL")
	pcall(driver.UnregisterEvent, driver, "PLAYER_SWING")
	if ns.detect then
		ns.detect.Sync()
	end
	if ns.extras then
		ns.extras.Sync()
	end
	if ns.moments then
		ns.moments.Sync()
	end
	if not db.enabled then
		return
	end
	local switchFeed = db.feedUnit ~= "leave"
	if switchFeed then
		driver:RegisterEvent("COMBAT_TEXT_UPDATE")
	end
	driver:RegisterUnitEvent("UNIT_COMBAT", "target")
	driver:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	if db.attribution == "accurate" then
		pcall(driver.RegisterEvent, driver, "PLAYER_SWING") -- Forever only
	end
	if db.killEvent or db.killLog or PetBackupOn() or db.killLogLine or db.killStatistic then
		-- pcall: a client without the event refuses to register it. The log line and statistic
		-- sources listen too, so a report of the same kill is recognised as one.
		pcall(driver.RegisterEvent, driver, "PARTY_KILL")
	end
	-- NOTE: the active unit is global. PulseHaptics sets it to "player" for its own damage-taken
	-- cues and MidnightFCT sets it back to "player" whenever it changes; whichever addon sets it
	-- last wins. feedUnit = "leave" never touches it (hits then come from UNIT_COMBAT only, as
	-- MikScrollingBattleText and MidnightFCT do). See the README.
	if switchFeed and SetActiveUnit then
		pcall(SetActiveUnit, "target")
	end
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if (...) ~= ADDON_NAME then
			return
		end
		db = ns.profiles:Load()
		ns.db = db
		EnsureFrames()
		if ns.meter then
			ns.meter:Init()
		end
		if ns.announcer then
			ns.announcer:Init()
		end
		if ns.minimap then
			ns.minimap:Init()
		end
		return
	end
	if not db then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" then
		targetSerial = targetSerial + 1
		SyncSources()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		lastCastAt = GetTime()
		if ns.attribution then
			local unit, _, spellID = ...
			ns.attribution.OnCast(unit, spellID)
		end
	elseif event == "PLAYER_SWING" then
		if ns.attribution then
			local _, swingType = ...
			ns.attribution.OnSwing(swingType)
		end
	elseif event == "COMBAT_TEXT_UPDATE" then
		OnCombatText(...)
	elseif event == "UNIT_COMBAT" then
		OnUnitCombat(...)
	elseif event == "PARTY_KILL" then
		OnPartyKill(...)
	end
end)

-- ── Settings API (slash commands and the settings window) ─────────────────────────────
-- Every change goes through here, so a toggle has the same effect wherever it is made.
local SYNC_KEYS = {
	enabled = true, killEvent = true, killLog = true, killPet = true, killPetBackup = true,
	killTargetDied = true, killLogLine = true, killStatistic = true, killStatId = true,
	meterOverkill = true, meterInterrupts = true, feedUnit = true, attribution = true,
	comboCounter = true, flash = true, dangerLow = true, dangerAt = true, finishIt = true, finishAt = true,
	reduceMotion = true, partySync = true, gamepadNav = true,
}
function ns.Set(key, value)
	db[key] = value
	if SYNC_KEYS[key] then
		SyncSources()
	elseif key == "meter" and ns.meter then
		ns.meter:Refresh()
	end
	if ns.announcer and (key == "enabled" or string.sub(key, 1, 3) == "ann") then
		ns.announcer:Sync()
	end
	if ns.extras and ns.extras.IsPlaceKey(key) then
		ns.extras.PlaceAll()
	end
	if ns.ui and ns.ui.Refresh then
		ns.ui.Refresh()
	end
end

function ns.Toggle(key)
	ns.Set(key, not db[key])
	return db[key]
end

-- One field of one event's look.
function ns.SetEvent(id, field, value)
	db.events[id][field] = value
	if field == "enabled" and ns.announcer then
		ns.announcer:Sync()
	end
	if field == "enabled" and ns.moments then
		ns.moments.Sync()
	end
	if ns.ui and ns.ui.Refresh then
		ns.ui.Refresh()
	end
end

-- Switches every module to `profile` (Profiles.lua calls this after a change).
function ns.ApplyProfile(profile)
	db = profile
	ns.db = profile
	SyncSources()
	if ns.meter then
		ns.meter:Refresh()
	end
	if ns.announcer then
		ns.announcer:Init()
	end
	if ns.ui and ns.ui.Refresh then
		ns.ui.Refresh()
	end
end

local HIT_EVENTS = { "crit", "kill", "critkill" }

ns.TESTS = {
	pow = { true, false, 12345 },
	ko = { false, true, 4321 },
	overkill = { true, true, 987654 },
	hit = { false, false, 100 },
}

-- Plain booleans, no secrets: what /kapow test and the window's test buttons show.
function ns.Test(key)
	local t = ns.TESTS[key]
	if t then
		Pop(t[1], t[2], t[3])
	end
	return t ~= nil
end

-- Font attributions (ArtCatalog.lua, generated from Art/_fonts). Full licenses: Art/_fonts/*/OFL.txt.
function ns.PrintCredits()
	Say("art: generated for KAPOW (Art/). Display fonts, unmodified, under their own licenses:")
	for _, credit in ipairs(ns.FONT_CREDITS or {}) do
		Say("|cffffd60a" .. credit[1] .. "|r  " .. credit[2] .. "  (" .. credit[3] .. ")")
	end
	Say("full licenses beside each font in Art/_fonts; list in Kapow/FONT-CREDITS.md")
end

-- ── Slash commands ────────────────────────────────────────────────────────────────────
local KILL_KEYS = {
	event = { "killEvent", "killing-blow event (PARTY_KILL)" },
	death = { "killUnitDead", "target death check (UnitIsDead)" },
	pet = { "killPet", "pet killing blows" },
	log = { "killLog", "kill log in chat" },
	died = { "killTargetDied", "target death event (PLAYER_TARGET_DIED)" },
	line = { "killLogLine", "combat log colour (your white kill line)" },
	stat = { "killStatistic", "kill statistic" },
}

local HELP = "/kapow opens settings  ·  test pow|ko|overkill|hit  ·  on|off  ·  kill event|death|died|line|stat|pet|log  ·  stats  ·  announce test  ·  profile [name]  ·  credits  ·  scale <n>  ·  pos <x> <y>  ·  unlock|lock  ·  records [reset]  ·  attribution recent|any|accurate  ·  numbers  ·  meter  ·  jitter  ·  minimap  ·  debug"

SLASH_KAPOW1 = "/kapow"
SLASH_KAPOW2 = "/comic" -- the name before KAPOW
SlashCmdList["KAPOW"] = function(input)
	local cmd, arg = string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	if cmd == "" or cmd == "config" or cmd == "options" then
		if ns.ui then
			ns.ui.Toggle()
		else
			Say(HELP)
		end
	elseif cmd == "test" then
		if not ns.Test(string.lower(arg)) then
			Say("usage: /kapow test pow | ko | overkill | hit  (plain booleans, no secrets)")
		end
	elseif cmd == "on" or cmd == "off" then
		ns.Set("enabled", cmd == "on")
		Say(db.enabled and "enabled" or "disabled")
	elseif cmd == "kill" then
		local entry = KILL_KEYS[string.lower(arg)]
		if entry then
			Say(entry[2] .. " " .. (ns.Toggle(entry[1]) and "on" or "off"))
		else
			Say("usage: /kapow kill event | death | died | line | stat | pet | log")
		end
	elseif cmd == "scale" then
		local n = tonumber(arg)
		if n and n >= 0.3 and n <= 3 then
			ns.Set("scale", n)
			Say("scale " .. n)
		else
			Say("usage: /kapow scale 0.3 - 3")
		end
	elseif cmd == "pos" then
		local x, y = string.match(arg, "^(-?%d+)%s+(-?%d+)$")
		if x then
			db.x, db.y = tonumber(x), tonumber(y)
			Say("offset " .. x .. ", " .. y)
		else
			Say("usage: /kapow pos <x> <y>  (pixels from screen centre)")
		end
	elseif cmd == "attribution" then
		if arg == "any" or arg == "recent" or arg == "accurate" then
			ns.Set("attribution", arg)
			Say("attribution " .. arg)
		else
			Say("usage: /kapow attribution recent | any | accurate")
		end
	elseif cmd == "meter" then
		if ns.meter then
			ns.meter:Command(arg)
		end
	elseif cmd == "numbers" then
		local on = not db.events.crit.details
		for _, id in ipairs(HIT_EVENTS) do
			ns.SetEvent(id, "details", on)
		end
		Say("damage numbers " .. (on and "on" or "off"))
	elseif cmd == "profile" then
		local P = ns.profiles
		if arg == "" then
			Say("profile: " .. P:ActiveName() .. (P:HasCharacterChoice() and " (this character)" or " (account default)") .. "  ·  all: " .. table.concat(P:Names(), ", "))
		elseif P:Exists(arg) then
			P:Use(arg)
			Say("this character now uses profile " .. arg)
		else
			Say("no profile named " .. arg .. "  ·  all: " .. table.concat(P:Names(), ", "))
		end
	elseif cmd == "jitter" then
		Say("jitter " .. (ns.Toggle("jitter") and "on" or "off"))
	elseif cmd == "announce" or cmd == "ann" then
		if ns.announcer then
			ns.announcer:Command(arg)
		end
	elseif cmd == "unlock" or cmd == "lock" then
		if ns.extras then
			ns.extras.SetUnlocked(cmd == "unlock")
		end
	elseif cmd == "records" then
		if ns.moments then
			if string.lower(arg) == "reset" then
				ns.moments.ResetRecords()
				Say("records reset for this character")
			else
				ns.moments.PrintRecords()
			end
		end
	elseif cmd == "stats" then
		if ns.detect then
			ns.detect.ListKillStatistics()
		end
	elseif cmd == "credits" then
		ns.PrintCredits()
	elseif cmd == "minimap" then
		if ns.minimap then
			ns.minimap:Toggle()
			Say("minimap button " .. (ns.account.minimap.hide and "hidden" or "shown"))
		end
	elseif cmd == "debug" then
		ns.Toggle("debug")
		Say(
			"debug "
				.. (db.debug and "on: every hit on your target prints its raw feed values (secret ones as <secret>)" or "off")
		)
	else
		Say(HELP)
	end
end
