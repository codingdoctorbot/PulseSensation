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
	meter = false, -- the hit-meter prototype panel (Meter.lua)
	meterSource = "hit", -- which health reading drives the OVERKILL slide: "hit" or "prev"
	-- Kill detection. Either source, both, or neither (then only crits pop).
	killEvent = true, -- PARTY_KILL: the client names the killing blow's attacker
	killUnitDead = true, -- UnitIsDead("target") read killDelay after your hit
	killPet = true, -- your pet's killing blows count as yours (PARTY_KILL only)
	killLog = false, -- print who landed every PARTY_KILL, to check group and pet behaviour
	-- Announcer (Announcer.lua). Which banners show is per event.
	annFirstBloodSolo = false, -- FIRST BLOOD also when you are not in a group
	annFeed = true, -- kill feed: who killed what
	annSound = true, -- master switch for event sounds
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

-- ── Showing a pop ─────────────────────────────────────────────────────────────────────
-- isCrit / isDead may be secret booleans, amount a secret number, or plain values from
-- /kapow test. Never read them.
local popValues = {}
local popOpts = {}

local function Pop(isCrit, isDead, amount)
	EnsureFrames()
	popValues.amount = AmountText(amount)
	local dx, dy, tilt = 0, 0, 0
	if db.jitter then
		dx, dy, tilt = math.random(-40, 40), math.random(-20, 20), math.rad(math.random(-8, 8))
	end
	popOpts.dx, popOpts.dy, popOpts.tilt = dx, dy, tilt
	for _, style in ipairs(STYLES) do
		local f = frames[style.key]
		local cfg = ns.EventConfig(style.event)
		if cfg.enabled then
			Gate(f.critGate, isCrit, style.wantCrit and 1 or 0, style.wantCrit and 0 or 1)
			Gate(f.deadGate, isDead, style.wantDead and 1 or 0, style.wantDead and 0 or 1)
			ns.display.Play(f.stage, cfg, popValues, popOpts)
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
local function ResolveDead(hitAt)
	if db.killEvent and lastKillAt >= hitAt - KILL_WINDOW then
		killConsumed = true
		return true
	end
	if db.killUnitDead then
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
	local counted = db.killEvent and (who == "you" or (who == "pet" and db.killPet))
	if db.killLog then
		LogKill(who, unit, victimGUID, counted)
	end
	if not counted then
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

-- ── Resolving a hit ───────────────────────────────────────────────────────────────────
local lastPopAt = 0

-- Called with the crit flag of one hit. Whether it killed is decided a moment later,
-- because neither the death state nor PARTY_KILL is in place at the instant of the hit.
local function OnHit(isCrit, amount)
	if not db.enabled then
		return
	end
	local now = GetTime()
	lastHitAt, lastHitCrit, lastHitAmount = now, isCrit, amount
	if not IsMine() then
		return
	end
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
		Pop(isCrit, ResolveDead(now), amount)
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

local function OnUnitCombat(unit, action, flagText, amount)
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
	OnHit(flagText == "CRITICAL", amount)
end

local driver = CreateFrame("Frame")
local function SyncSources()
	driver:UnregisterEvent("COMBAT_TEXT_UPDATE")
	driver:UnregisterEvent("UNIT_COMBAT")
	driver:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	pcall(driver.UnregisterEvent, driver, "PARTY_KILL")
	if not db.enabled then
		return
	end
	driver:RegisterEvent("COMBAT_TEXT_UPDATE")
	driver:RegisterUnitEvent("UNIT_COMBAT", "target")
	driver:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	if db.killEvent or db.killLog then
		-- pcall: a client without the event refuses to register it.
		pcall(driver.RegisterEvent, driver, "PARTY_KILL")
	end
	-- NOTE: the active unit is global. PulseHaptics sets it to "player" for its own damage-taken
	-- cues; whichever addon sets it last wins. See the README.
	if SetActiveUnit then
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
		SyncSources()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		lastCastAt = GetTime()
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
function ns.Set(key, value)
	db[key] = value
	if key == "enabled" or key == "killEvent" or key == "killLog" then
		SyncSources()
	elseif key == "meter" and ns.meter then
		ns.meter:Refresh()
	end
	if ns.announcer and (key == "enabled" or string.sub(key, 1, 3) == "ann") then
		ns.announcer:Sync()
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
}

local HELP = "/kapow opens settings  ·  test pow|ko|overkill|hit  ·  on|off  ·  kill event|death|pet|log  ·  announce test  ·  profile [name]  ·  credits  ·  scale <n>  ·  pos <x> <y>  ·  attribution recent|any  ·  numbers  ·  meter  ·  jitter  ·  minimap  ·  debug"

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
			Say("usage: /kapow kill event | death | pet | log")
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
		if arg == "any" or arg == "recent" then
			ns.Set("attribution", arg)
			Say("attribution " .. arg)
		else
			Say("usage: /kapow attribution recent | any")
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
