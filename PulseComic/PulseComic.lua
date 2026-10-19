-- PulseComic
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
-- `/comic debug` also probes whether GetStringWidth() of that text stays readable, which
-- would be a crude size signal (wider number, bigger hit). Expected to be secret too.
--
-- OLDER CLIENTS (16001 / 110x)
-- SetAlphaFromBoolean is 12.0+. Clients without it have no secret values either, so the gate
-- falls back to a plain SetAlpha. Same for C_CombatText vs. the legacy combat-text globals.
--
-- WHAT IS GUESSED (see /comic debug, which exists to settle each of these in the live client)
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

local DEFAULTS = {
	enabled = true,
	scale = 1.0,
	x = 0,
	y = 140,
	attribution = "recent", -- "recent": only hits shortly after your own cast/auto-attack; "any": every hit on target
	minInterval = 0.12, -- seconds between pops
	killDelay = 0.15, -- seconds to wait for the target's death state to settle after a hit
	jitter = true, -- small random offset and tilt per pop
	numbers = true, -- print the hit's damage inside the burst
	meter = false, -- the hit-meter prototype panel (Meter.lua)
	meterSource = "hit", -- which health reading drives the OVERKILL slide: "hit" or "prev"
	debug = false,
}

local db

-- ── Client compatibility ──────────────────────────────────────────────────────────────
local CombatText = _G.C_CombatText
local SetActiveUnit = (CombatText and CombatText.SetActiveUnit) or _G.CombatTextSetActiveUnit
local GetEventInfo = (CombatText and CombatText.GetCurrentEventInfo) or _G.GetCurrentCombatTextEventInfo
local IsCurrentSpellFn = (_G.C_Spell and _G.C_Spell.IsCurrentSpell) or _G.IsCurrentSpell

local FONT = "Fonts\\FRIZQT__.TTF"

-- Damage amount -> label text. `amount` may be a secret number or string: no comparisons,
-- no arithmetic, only type() and calls documented to pass secrets through. The client's
-- abbreviator is tried first ("12.3K"); if it refuses a secret, plain formatting is used.
local function AmountText(amount)
	local kind = type(amount)
	if kind ~= "number" and kind ~= "string" then
		return ""
	end
	local abbreviate = _G.AbbreviateNumbers
	if abbreviate and kind == "number" then
		local ok, text = pcall(abbreviate, amount)
		if ok and type(text) == "string" then
			return text
		end
	end
	return string.format("%s", amount)
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

-- ── Styles ────────────────────────────────────────────────────────────────────────────
-- wantCrit / wantDead: the (crit, dead) pair for which this frame is visible.
local STYLES = {
	{ key = "pow", wantCrit = true, wantDead = false },
	{ key = "ko", wantCrit = false, wantDead = true },
	{ key = "overkill", wantCrit = true, wantDead = true },
}

local FRAME_SIZE = 256
local TEXTURE_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local frames = {} -- key -> { root, critGate, deadGate, tex, anim }

local function BuildFrame(style)
	local root = CreateFrame("Frame", "PulseComicFrame_" .. style.key, UIParent)
	root:SetSize(FRAME_SIZE, FRAME_SIZE)
	root:SetFrameStrata("HIGH")
	root:EnableMouse(false)
	root:Hide()

	local critGate = CreateFrame("Frame", nil, root)
	critGate:SetAllPoints(root)
	local deadGate = CreateFrame("Frame", nil, critGate)
	deadGate:SetAllPoints(critGate)

	local tex = deadGate:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(deadGate)
	tex:SetTexture(TEXTURE_PATH .. style.key)

	-- Damage number, inside deadGate so it shares the frame's visibility.
	local label = deadGate:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, 30, "THICKOUTLINE")
	label:SetPoint("CENTER", deadGate, "CENTER", 0, -62)
	label:SetTextColor(1, 1, 1)
	label:SetShadowOffset(2, -2)

	-- Pop in, hold, fade. All on root, with plain (non-secret) values.
	local anim = root:CreateAnimationGroup()
	local pop = anim:CreateAnimation("Scale")
	pop:SetOrder(1)
	pop:SetDuration(0.12)
	if pop.SetScaleFrom then
		pop:SetScaleFrom(0.35, 0.35)
		pop:SetScaleTo(1.0, 1.0)
	else
		pop:SetFromScale(0.35, 0.35)
		pop:SetToScale(1.0, 1.0)
	end
	pop:SetSmoothing("OUT")
	local fade = anim:CreateAnimation("Alpha")
	fade:SetOrder(2)
	fade:SetStartDelay(0.5)
	fade:SetDuration(0.3)
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	anim:SetScript("OnFinished", function()
		root:Hide()
	end)

	frames[style.key] = { root = root, critGate = critGate, deadGate = deadGate, tex = tex, label = label, anim = anim }
end

for _, style in ipairs(STYLES) do
	BuildFrame(style)
end

-- ── Showing a pop ─────────────────────────────────────────────────────────────────────
-- isCrit / isDead may be secret booleans, amount a secret number, or plain values from
-- /comic test. Never read them.
local function Pop(isCrit, isDead, amount)
	local text = db.numbers and AmountText(amount) or ""
	local dx, dy, tilt = 0, 0, 0
	if db.jitter then
		dx, dy, tilt = math.random(-40, 40), math.random(-20, 20), math.rad(math.random(-8, 8))
	end
	for _, style in ipairs(STYLES) do
		local f = frames[style.key]
		Gate(f.critGate, isCrit, style.wantCrit and 1 or 0, style.wantCrit and 0 or 1)
		Gate(f.deadGate, isDead, style.wantDead and 1 or 0, style.wantDead and 0 or 1)
		f.tex:SetRotation(tilt)
		f.label:SetText(text)
		f.root:SetScale(db.scale)
		f.root:ClearAllPoints()
		f.root:SetPoint("CENTER", UIParent, "CENTER", db.x + dx, db.y + dy)
		f.root:SetAlpha(1)
		f.anim:Stop()
		f.root:Show()
		f.anim:Play()
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

-- ── Resolving a hit ───────────────────────────────────────────────────────────────────
local lastPopAt = 0

-- Called with the crit flag of one hit. The target's death state is sampled a moment later,
-- because it is not updated at the instant the hit is reported.
local function OnHit(isCrit, amount)
	if not db.enabled then
		return
	end
	local now = GetTime()
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
		-- UnitIsDead is not wrapped in `and`/`or`: its result may be a secret boolean.
		Pop(isCrit, UnitIsDead("target"), amount)
	end)
end

-- ── Debug ─────────────────────────────────────────────────────────────────────────────
local function Say(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd60aPulseComic|r " .. msg)
end
ns.Say = Say

local function Describe(v)
	if issecretvalue(v) then
		return "<secret " .. type(v) .. ">"
	end
	return type(v) .. ":" .. tostring(v)
end

-- Width probe for /comic debug: does GetStringWidth() of a secret number stay readable?
-- Its own hidden FontString, because SetText with a secret marks the string's text secret
-- until it is reset, and that must not leak into the visible labels.
local probe
local function ProbeWidth(amount)
	if not probe then
		local holder = CreateFrame("Frame", nil, UIParent)
		holder:SetSize(1, 1)
		holder:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100) -- off-screen
		probe = holder:CreateFontString(nil, "OVERLAY")
		probe:SetFont(FONT, 30, "THICKOUTLINE")
	end
	local ok = pcall(probe.SetText, probe, AmountText(amount))
	if not ok then
		return "SetText refused"
	end
	local okWidth, width = pcall(probe.GetStringWidth, probe)
	if not okWidth then
		return "GetStringWidth errored"
	end
	return Describe(width)
end

-- ── Event sources ─────────────────────────────────────────────────────────────────────
local CRIT_TYPES = { DAMAGE_CRIT = true, SPELL_DAMAGE_CRIT = true }
local HIT_TYPES = { DAMAGE = true, SPELL_DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE_CRIT = true }

local function OnCombatText(messageType)
	local ok, ret1, ret2, ret3
	if GetEventInfo then
		ok, ret1, ret2, ret3 = pcall(GetEventInfo)
	end

	if db.debug then
		Say(
			"CTU type="
				.. Describe(messageType)
				.. " info1="
				.. Describe(ret1)
				.. " info2(amount?)="
				.. Describe(ret2)
				.. " info3(crit?)="
				.. Describe(ret3)
				.. " dead="
				.. Describe(UnitIsDead("target"))
				.. " width="
				.. ProbeWidth(ret2)
		)
	end

	if not issecretvalue(messageType) and type(messageType) == "string" then
		-- Readable message type: filter to damage, and derive the crit flag as a plain boolean.
		if not HIT_TYPES[messageType] then
			return
		end
		OnHit(CRIT_TYPES[messageType] == true, ret2)
	elseif ok then
		-- Secret message type: cannot be filtered. Use the feed's crit flag (PulseHaptics reads
		-- it as the third value after pcall on RESIST/ABSORB entries) and let the engine
		-- decide visibility. Unconfirmed; compare with `/comic debug`.
		-- type() reports the real type even for a secret, so this test is safe.
		if type(ret3) == "boolean" then
			OnHit(ret3, ret2)
		end
	end
end

local function OnUnitCombat(unit, _, flagText, amount)
	if unit ~= "target" then
		return
	end
	if db.debug then
		Say("UNIT_COMBAT flag=" .. Describe(flagText) .. " dead=" .. Describe(UnitIsDead("target")))
	end
	if issecretvalue(flagText) then
		return -- a secret string cannot be turned into a boolean; COMBAT_TEXT_UPDATE is the path for that
	end
	OnHit(flagText == "CRITICAL", amount)
end

local driver = CreateFrame("Frame")
local function SyncSources()
	driver:UnregisterEvent("COMBAT_TEXT_UPDATE")
	driver:UnregisterEvent("UNIT_COMBAT")
	driver:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	if not db.enabled then
		return
	end
	driver:RegisterEvent("COMBAT_TEXT_UPDATE")
	driver:RegisterUnitEvent("UNIT_COMBAT", "target")
	driver:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
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
		PulseComicDB = PulseComicDB or {}
		db = PulseComicDB
		for k, v in pairs(DEFAULTS) do
			if db[k] == nil then
				db[k] = v
			end
		end
		ns.db = db
		if ns.meter then
			ns.meter:Init()
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
	end
end)

-- ── Slash commands ────────────────────────────────────────────────────────────────────
local TESTS = {
	pow = { true, false, 12345 },
	ko = { false, true, 4321 },
	overkill = { true, true, 987654 },
	hit = { false, false, 100 },
}

SLASH_PULSECOMIC1 = "/comic"
SLASH_PULSECOMIC2 = "/pulsecomic"
SlashCmdList["PULSECOMIC"] = function(input)
	local cmd, arg = string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	if cmd == "test" then
		local t = TESTS[string.lower(arg)]
		if not t then
			Say("usage: /comic test pow | ko | overkill | hit  (plain booleans, no secrets)")
			return
		end
		Pop(t[1], t[2], t[3])
	elseif cmd == "on" or cmd == "off" then
		db.enabled = (cmd == "on")
		SyncSources()
		Say(db.enabled and "enabled" or "disabled")
	elseif cmd == "scale" then
		local n = tonumber(arg)
		if n and n >= 0.3 and n <= 3 then
			db.scale = n
			Say("scale " .. n)
		else
			Say("usage: /comic scale 0.3 - 3")
		end
	elseif cmd == "pos" then
		local x, y = string.match(arg, "^(-?%d+)%s+(-?%d+)$")
		if x then
			db.x, db.y = tonumber(x), tonumber(y)
			Say("offset " .. x .. ", " .. y)
		else
			Say("usage: /comic pos <x> <y>  (pixels from screen centre)")
		end
	elseif cmd == "attribution" then
		if arg == "any" or arg == "recent" then
			db.attribution = arg
			Say("attribution " .. arg)
		else
			Say("usage: /comic attribution recent | any")
		end
	elseif cmd == "meter" then
		if ns.meter then
			ns.meter:Command(arg)
		end
	elseif cmd == "numbers" then
		db.numbers = not db.numbers
		Say("damage numbers " .. (db.numbers and "on" or "off"))
	elseif cmd == "jitter" then
		db.jitter = not db.jitter
		Say("jitter " .. (db.jitter and "on" or "off"))
	elseif cmd == "debug" then
		db.debug = not db.debug
		Say(
			"debug "
				.. (db.debug and "on: every hit on your target prints its raw feed values (secret ones as <secret>) and whether its text width is readable" or "off")
		)
	else
		Say("/comic test pow|ko|overkill|hit  ·  on|off  ·  scale <n>  ·  pos <x> <y>  ·  attribution recent|any  ·  numbers  ·  meter  ·  jitter  ·  debug")
	end
end
