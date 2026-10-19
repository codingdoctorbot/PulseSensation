-- Offline test for PulseComic.
--
-- PulseComic decides which comic frame is visible without ever reading the crit flag or the
-- death state, because in 12.x either may be a secret boolean. This test loads the real
-- PulseComic.lua against a stub WoW API in which secret booleans are tables that throw on
-- comparison, and only SetAlphaFromBoolean may unwrap them. Effective alpha is computed as
-- the product down the parent chain, the same as the client.
--
-- It cannot tell you that the client really delivers target hits on the combat-text feed,
-- or that UnitIsDead settles inside killDelay; those are what `/comic debug` is for. It can
-- tell you that every (crit, dead) pair shows exactly the right frame through the secret
-- path, the plain path and the pre-12.0 fallback, and that nothing ever compares a secret.
--
-- Run from the repo root:  lua PulseChecklist/tests/pulsecomic-test.lua PulseComic

local ROOT = arg[1] or "PulseComic"
-- TOC order, minus the window and minimap button (UI/), which the smoke test covers.
local FILES = { "PulseComic.lua", "Meter.lua", "ArtCatalog.lua", "Art.lua", "Events.lua", "Display.lua", "Themes.lua", "Profiles.lua", "Announcer.lua" }
local unpack = table.unpack or unpack

local failures = 0
local function check(label, got, want)
	if got ~= want then
		failures = failures + 1
		io.write(("FAIL  %-58s got %s, wanted %s\n"):format(label, tostring(got), tostring(want)))
	else
		io.write(("ok    %s\n"):format(label))
	end
end

-- ── Secret stand-ins ──────────────────────────────────────────────────────────────────
local realtype = type
local SecretMT = {}
local function refuse()
	error("attempt to use a secret value", 2)
end
SecretMT.__eq, SecretMT.__lt, SecretMT.__le = refuse, refuse, refuse
SecretMT.__add, SecretMT.__sub, SecretMT.__concat, SecretMT.__len = refuse, refuse, refuse, refuse
SecretMT.__mul, SecretMT.__div, SecretMT.__mod, SecretMT.__pow, SecretMT.__unm = refuse, refuse, refuse, refuse, refuse
SecretMT.__index, SecretMT.__call = refuse, refuse
-- A marker the assertions can recognise, proving the secret travelled to SetText untouched.
SecretMT.__tostring = function(t)
	return "<S:" .. tostring(rawget(t, "__v")[1]) .. ">"
end
local function Secret(v)
	return setmetatable({ __v = { v } }, SecretMT)
end
local function isSecret(x)
	return realtype(x) == "table" and getmetatable(x) == SecretMT
end
local function unwrap(x)
	return rawget(x, "__v")[1]
end

-- ── Stub client ───────────────────────────────────────────────────────────────────────
local env -- per-load state, rebuilt by Load()

local function NewRegion(parent, modern)
	local r = { alpha = 1, parent = parent, shown = true }
	local noop = function() end
	for _, m in ipairs({
		"SetAllPoints", "SetFrameStrata", "EnableMouse", "ClearAllPoints",
		"SetScale", "SetRotation", "SetStatusBarTexture", "SetStatusBarColor",
		"SetClipsChildren", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
		"SetColorTexture", "SetJustifyH", "SetWidth", "SetHeight",
	}) do
		r[m] = noop
	end
	function r:SetSize(w, h)
		self.w, self.h = w, h
	end
	function r:SetTexture(path)
		self.texture = path
	end
	function r:SetPoint(point, rel)
		self.point, self.anchorTo = point, rel
	end
	-- StatusBar: record what the client would be asked to draw. Secrets pass straight through.
	function r:SetMinMaxValues(lo, hi)
		self.lo, self.hi = lo, hi
	end
	function r:SetValue(v, interp)
		self.value, self.interp = v, interp
	end
	function r:GetStatusBarTexture()
		self.fill = self.fill or NewRegion(self, modern)
		return self.fill
	end
	function r:Hide()
		self.shown = false
	end
	function r:Show()
		self.shown = true
	end
	function r:SetAlpha(a)
		if isSecret(a) then
			refuse()
		end
		self.alpha = a
	end
	if modern then
		function r:SetAlphaFromBoolean(v, ifTrue, ifFalse)
			local b = v
			if isSecret(v) then
				b = unwrap(v)
			end
			if b then
				self.alpha = ifTrue
			else
				self.alpha = ifFalse
			end
		end
	end
	function r:CreateTexture()
		local t = NewRegion(self, modern)
		env.regions[#env.regions + 1] = t
		return t
	end
	function r:CreateFontString()
		local fs = NewRegion(self, modern)
		fs.text = nil
		fs.SetTextColor, fs.SetShadowOffset = noop, noop
		-- Like the client: true when the font loaded. env.badFonts lists paths it refuses.
		function fs:SetFont(path)
			if env.badFonts and env.badFonts[path] then
				return false
			end
			self.fontPath = path
			return true
		end
		function fs:SetText(t)
			self.text = t
		end
		function fs:SetFormattedText(fmt, ...)
			-- The client takes secrets here; Lua 5.1's %s ignores __tostring, so render them first.
			local args = { ... }
			for i = 1, select("#", ...) do
				if isSecret(args[i]) then
					args[i] = tostring(args[i])
				end
			end
			self.text = string.format(fmt, unpack(args, 1, select("#", ...)))
		end
		function fs:GetStringWidth()
			return #tostring(self.text or "") * 10
		end
		env.labels[#env.labels + 1] = fs
		return fs
	end
	function r:CreateAnimationGroup()
		local g = { SetScript = noop, Play = noop, Stop = noop }
		function g:CreateAnimation()
			return setmetatable({}, { __index = function() return noop end })
		end
		return g
	end
	function r:Effective()
		local a, p = self.alpha, self.parent
		while p do
			a = a * p.alpha
			p = p.parent
		end
		return a
	end
	return r
end

-- saved / savedChar: what PulseComicDB / PulseComicCharDB hold before ADDON_LOADED.
local function Load(modern, saved, savedChar)
	env = { regions = {}, labels = {}, frames = {}, timers = {}, now = 1000, dead = false, info = {}, modern = modern }

	_G.type = function(x)
		if isSecret(x) then
			return realtype(unwrap(x))
		end
		return realtype(x)
	end
	_G.issecretvalue = modern and isSecret or nil
	_G.GetTime = function()
		return env.now
	end
	_G.C_Timer = {
		After = function(d, fn)
			env.timers[#env.timers + 1] = { at = env.now + d, fn = fn }
		end,
	}
	_G.UIParent = NewRegion(nil, modern)
	_G.CreateFrame = function(_, name, parent)
		local f = NewRegion(parent or _G.UIParent, modern)
		local scripts, events = {}, {}
		function f:RegisterEvent(e)
			events[e] = true
		end
		f.RegisterUnitEvent = f.RegisterEvent
		function f:UnregisterEvent(e)
			events[e] = nil
		end
		function f:UnregisterAllEvents()
			for e in pairs(events) do
				events[e] = nil
			end
		end
		function f:SetScript(n, fn)
			scripts[n] = fn
		end
		function f:Fire(e, ...)
			if events[e] and scripts.OnEvent then
				scripts.OnEvent(self, e, ...)
			end
		end
		f.events = events
		f.scripts = scripts
		env.frames[#env.frames + 1] = f
		if name then
			_G[name] = f
		end
		return f
	end
	_G.UnitIsDead = function()
		return env.dead
	end
	-- Group and identity. env.guids maps unit tokens to GUIDs (plain or Secret()).
	env.guids = { player = "Player-1", pet = "Pet-1", party1 = "Player-2", partypet1 = "Pet-2", target = "Creature-1" }
	env.names = { party1 = "Bob" }
	env.partySize = 1
	_G.UnitGUID = function(unit)
		return env.guids[unit]
	end
	_G.UnitName = function(unit)
		if isSecret(unit) then
			return env.names[unwrap(unit)]
		end
		return env.names[unit]
	end
	_G.GetNumSubgroupMembers = function()
		return env.partySize
	end
	_G.GetNumGroupMembers = function()
		return env.partySize + 1
	end
	_G.IsInRaid = function()
		return false
	end
	env.inGroup = false
	env.deadUnits = {}
	env.tokens = { ["Creature-1"] = "target", ["Creature-5"] = "nameplate5" }
	env.names.target = Secret("Hogger")
	env.names.nameplate5 = Secret("Defias Thug")
	_G.IsInGroup = function()
		return env.inGroup
	end
	env.falling, env.flying, env.swimming = false, false, false
	_G.IsFalling = function()
		return env.falling
	end
	_G.IsFlying = function()
		return env.flying
	end
	_G.IsSwimming = function()
		return env.swimming
	end
	_G.UnitOnTaxi = function()
		return false
	end
	_G.UnitIsUnit = function(a, b)
		return a == b
	end
	_G.UnitIsDeadOrGhost = function(unit)
		return env.deadUnits[unit] == true
	end
	-- Takes a secret GUID, as the client does, and answers with a secret token.
	_G.UnitTokenFromGUID = function(guid)
		local token = env.tokens[isSecret(guid) and unwrap(guid) or guid]
		if token and isSecret(guid) then
			return Secret(token)
		end
		return token
	end
	_G.GetPlayerInfoByGUID = function()
		return nil
	end
	env.sounds = 0
	_G.SOUNDKIT = { RAID_WARNING = 8959 }
	_G.PlaySound = function()
		env.sounds = env.sounds + 1
	end
	_G.UnitHealth = function()
		return env.health
	end
	_G.UnitHealthMax = function()
		return env.healthMax
	end
	_G.Enum = modern and { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 } } or nil
	local spellNames = { [1766] = "Kick", [1767] = "Kick", [6552] = "Pummel", [133] = "Fireball" }
	_G.C_Spell = {
		IsCurrentSpell = function() return false end,
		GetSpellName = function(id) return spellNames[id] end,
	}
	-- The client's abbreviator. It takes secrets from addon code and returns a secret string.
	_G.AbbreviateNumbers = modern
			and function(n)
				if isSecret(n) then
					return Secret(("%.1fK"):format(unwrap(n) / 1000))
				end
				return ("%.1fK"):format(n / 1000)
			end
		or nil
	local getInfo = function()
		return unpack(env.info, 1, 3)
	end
	if modern then
		_G.C_CombatText = { SetActiveUnit = function(u) env.activeUnit = u end, GetCurrentEventInfo = getInfo }
		_G.CombatTextSetActiveUnit, _G.GetCurrentCombatTextEventInfo = nil, nil
	else
		_G.C_CombatText = nil
		_G.CombatTextSetActiveUnit = function(u) env.activeUnit = u end
		_G.GetCurrentCombatTextEventInfo = getInfo
	end
	env.chat = {}
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) env.chat[#env.chat + 1] = m end }
	_G.SlashCmdList = {}
	_G.PulseComicDB = saved
	_G.PulseComicCharDB = savedChar

	-- TOC order, one shared addon namespace, as the client does it.
	env.ns = {}
	for _, file in ipairs(FILES) do
		assert(loadfile(ROOT .. "/" .. file))("PulseComic", env.ns)
	end
	for _, f in ipairs(env.frames) do
		if f.events.ADDON_LOADED then
			env.driver = f
		end
	end
	env.driver:Fire("ADDON_LOADED", "PulseComic")
	env.driver:Fire("PLAYER_ENTERING_WORLD")
end

local function Advance(dt)
	env.now = env.now + dt
	table.sort(env.timers, function(a, b) return a.at < b.at end)
	while env.timers[1] and env.timers[1].at <= env.now do
		table.remove(env.timers, 1).fn()
	end
end

-- Which comic frames are visible: texture effective alpha × root alpha, for shown roots.
local KEYS = { "pow", "ko", "overkill" }
local function Visible()
	local out = {}
	for _, key in ipairs(KEYS) do
		local root = _G["PulseComicFrame_" .. key]
		for _, tex in ipairs(env.regions) do
			local p = tex.parent
			while p and p ~= root do
				p = p.parent
			end
			if p == root and root.shown and tex:Effective() > 0.5 then
				out[#out + 1] = key
			end
		end
	end
	return #out == 0 and "none" or table.concat(out, "+")
end

-- Text of the damage label on a given frame.
local function LabelOf(key)
	local root = _G["PulseComicFrame_" .. key]
	for _, fs in ipairs(env.labels) do
		local p = fs.parent
		while p and p ~= root do
			p = p.parent
		end
		if p == root then
			return fs.text
		end
	end
end

local function Fade()
	for _, key in ipairs(KEYS) do
		_G["PulseComicFrame_" .. key].shown = false
	end
end

-- One hit on the target. mine=false means no cast of ours preceded it.
local function Hit(msgType, crit, dead, mine, amount)
	env.now = env.now + 5
	env.timers = {}
	env.dead = dead
	if amount == nil then
		amount = 1234
	elseif amount == "missing" then
		amount = nil
	end
	env.info = { amount, 0, crit } -- Blizzard_CombatText layout: data, arg3, arg4
	Fade()
	if mine ~= false then
		env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
	end
	env.driver:Fire("COMBAT_TEXT_UPDATE", msgType)
	Advance(0.2)
	return Visible()
end

local CASES = {
	{ "crit, alive", true, false, "pow" },
	{ "no crit, dead", false, true, "ko" },
	{ "crit, dead", true, true, "overkill" },
	{ "no crit, alive", false, false, "none" },
}

-- ── 12.x client ───────────────────────────────────────────────────────────────────────
Load(true)
check("12.x: active unit set to target", env.activeUnit, "target")

for _, c in ipairs(CASES) do
	local name, crit, dead, want = unpack(c)
	Fade()
	_G.SlashCmdList.PULSECOMIC("test " .. ({ pow = "pow", ko = "ko", overkill = "overkill", none = "hit" })[want])
	check("/comic test, " .. name, Visible(), want)
	local msg = crit and "DAMAGE_CRIT" or "DAMAGE"
	check("secret type + secret crit + secret dead, " .. name, Hit(Secret(msg), Secret(crit), Secret(dead)), want)
	check("plain type + plain dead, " .. name, Hit(msg, nil, dead), want)
end

-- Damage numbers
Fade()
_G.SlashCmdList.PULSECOMIC("test pow")
check("/comic test pow labels the burst through the abbreviator", LabelOf("pow"), "12.3K")
Hit("DAMAGE_CRIT", nil, false)
check("plain amount is abbreviated", LabelOf("pow"), "1.2K")
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false), nil, Secret(98765))
check("secret amount is abbreviated by the client and reaches SetText", tostring(LabelOf("pow")), "<S:98.8K>")
_G.AbbreviateNumbers = nil
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false), nil, Secret(98765))
check("without a formatter the secret amount goes to SetText as it is", tostring(LabelOf("pow")), "<S:98765>")
_G.AbbreviateNumbers = function(n)
	if isSecret(n) then
		return Secret(("%.1fK"):format(unwrap(n) / 1000))
	end
	return ("%.1fK"):format(n / 1000)
end
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false), nil, Secret("98765"))
check("secret string amount reaches SetText", tostring(LabelOf("pow")), "<S:98765>")
Hit("DAMAGE_CRIT", nil, false, nil, "missing")
check("missing amount gives an empty label", LabelOf("pow"), "")
_G.SlashCmdList.PULSECOMIC("numbers")
Hit("DAMAGE_CRIT", nil, false)
check("/comic numbers off clears the label", LabelOf("pow"), "")
_G.SlashCmdList.PULSECOMIC("numbers")
Hit("DAMAGE_CRIT", nil, false)
check("/comic numbers on restores it", LabelOf("pow"), "1.2K")

check("plain HEAL is ignored", Hit("HEAL", false, false), "none")

-- UNIT_COMBAT on the target: unit, action, flagText, amount, schoolMask
local function UnitCombat(action, flagText, amount)
	env.now = env.now + 5
	env.timers = {}
	env.dead = false
	Fade()
	env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
	env.driver:Fire("UNIT_COMBAT", "target", action, flagText, amount, 1)
	Advance(0.2)
	return Visible()
end
check("UNIT_COMBAT critical WOUND shows POW!", UnitCombat("WOUND", "CRITICAL", 4321), "pow")
check("UNIT_COMBAT WOUND amount reaches the label", LabelOf("pow"), "4.3K")
check("UNIT_COMBAT critical HEAL is ignored", UnitCombat("HEAL", "CRITICAL", 4321), "none")
check("UNIT_COMBAT secret action is ignored", UnitCombat(Secret("WOUND"), "CRITICAL", 4321), "none")

-- Killing blows via PARTY_KILL. `attacker` lands the kill just after the hit (or just
-- before it with before=true); msgType nil means no hit of ours at all.
local function KillHit(msgType, attacker, opts)
	opts = opts or {}
	env.now = env.now + 5
	env.timers = {}
	env.dead = opts.dead or false
	env.info = { 1234, 0, nil }
	Fade()
	env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
	if opts.before and attacker then
		env.driver:Fire("PARTY_KILL", attacker, opts.victim or "Creature-1")
	end
	if msgType then
		env.driver:Fire("COMBAT_TEXT_UPDATE", msgType)
	end
	if not opts.before and attacker then
		Advance(0.05)
		env.driver:Fire("PARTY_KILL", attacker, opts.victim or "Creature-1")
	end
	Advance(0.4)
	return Visible()
end

check("PARTY_KILL registered by default", env.driver.events.PARTY_KILL, true)
check("your killing blow on a plain hit shows K.O.!", KillHit("DAMAGE", "Player-1"), "ko")
check("your killing blow on a crit shows OVERKILL!", KillHit("DAMAGE_CRIT", "Player-1"), "overkill")
check("kill reported before the hit still counts", KillHit("DAMAGE_CRIT", "Player-1", { before = true }), "overkill")
check("kill counts while UnitIsDead reads alive", KillHit("DAMAGE", "Player-1", { dead = false }), "ko")
check("groupmate's kill is not yours", KillHit("DAMAGE_CRIT", "Player-2"), "pow")
check("groupmate's kill shows via UnitIsDead when that is on", KillHit("DAMAGE_CRIT", "Player-2", { dead = true }), "overkill")
check("pet's killing blow with no hit of yours shows K.O.!", KillHit(nil, "Pet-1"), "ko")
check("secret attacker is not counted", KillHit("DAMAGE_CRIT", Secret("Player-1")), "pow")

_G.SlashCmdList.PULSECOMIC("kill death")
check("/comic kill death turns UnitIsDead off", env.ns.db.killUnitDead, false)
check("with UnitIsDead off a groupmate's kill shows only POW!", KillHit("DAMAGE_CRIT", "Player-2", { dead = true }), "pow")
check("with UnitIsDead off your kill still shows OVERKILL!", KillHit("DAMAGE_CRIT", "Player-1", { dead = false }), "overkill")
_G.SlashCmdList.PULSECOMIC("kill pet")
check("/comic kill pet turns pet kills off", KillHit(nil, "Pet-1"), "none")
_G.SlashCmdList.PULSECOMIC("kill pet")
_G.SlashCmdList.PULSECOMIC("kill event")
check("/comic kill event unregisters PARTY_KILL", env.driver.events.PARTY_KILL, nil)
check("with both sources off a crit kill shows only POW!", KillHit("DAMAGE_CRIT", nil, { dead = true }), "pow")
_G.SlashCmdList.PULSECOMIC("kill log")
check("kill log keeps PARTY_KILL registered", env.driver.events.PARTY_KILL, true)
check("kill log alone counts nothing", KillHit("DAMAGE", "Player-1"), "none")
check("kill log says the event is off", (env.chat[#env.chat] or ""):find("killing-blow event is off", 1, true) ~= nil, true)
_G.SlashCmdList.PULSECOMIC("kill event")
_G.SlashCmdList.PULSECOMIC("kill death")

KillHit("DAMAGE", "Player-1")
check("kill log: you, your target, counted", (env.chat[#env.chat] or ""):find("kill: you, your target", 1, true) ~= nil, true)
KillHit("DAMAGE", "Player-2", { victim = "Creature-9" })
check("kill log names the groupmate", (env.chat[#env.chat] or ""):find("kill: Bob (group), not your target", 1, true) ~= nil, true)
KillHit(nil, "Pet-2")
check("kill log names a groupmate's pet", (env.chat[#env.chat] or ""):find("Bob", 1, true) == nil and (env.chat[#env.chat] or ""):find("(group pet)", 1, true) ~= nil, true)
KillHit("DAMAGE", Secret("Player-1"), { victim = Secret("Creature-1") })
check("kill log handles secret attacker and victim", (env.chat[#env.chat] or ""):find("a secret attacker, victim secret", 1, true) ~= nil, true)
KillHit("DAMAGE", "Creature-7")
check("kill log: someone outside your group", (env.chat[#env.chat] or ""):find("outside your group", 1, true) ~= nil, true)
_G.SlashCmdList.PULSECOMIC("kill log")
check("groupmate crit ignored under attribution=recent", Hit("DAMAGE_CRIT", true, false, false), "none")
_G.SlashCmdList.PULSECOMIC("attribution any")
check("groupmate crit shown under attribution=any", Hit("DAMAGE_CRIT", true, false, false), "pow")
_G.SlashCmdList.PULSECOMIC("attribution recent")

env.now = env.now + 5
env.timers = {}
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE_CRIT")
Advance(0.01)
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE_CRIT")
check("two hits 10 ms apart schedule one pop", #env.timers, 1)

_G.SlashCmdList.PULSECOMIC("off")
check("/comic off stops listening", env.driver.events.COMBAT_TEXT_UPDATE, nil)
_G.SlashCmdList.PULSECOMIC("on")
check("/comic on listens again", env.driver.events.COMBAT_TEXT_UPDATE, true)

-- ── Hit meter (Meter.lua) ─────────────────────────────────────────────────────────────
check("meter is off and unbuilt by default", _G.PulseComicMeter, nil)
_G.SlashCmdList.PULSECOMIC("meter test 5000 4000")
local meterPanel = _G.PulseComicMeter
check("meter test builds and shows the panel", meterPanel ~= nil and meterPanel.shown, true)

-- Find bars by role: rows sit in the panel, lamps and the slide sit in clipping windows.
local function Bars()
	local out = { rows = {}, zoomed = {} }
	for _, f in ipairs(env.frames) do
		if f.lo ~= nil then
			if f.w and f.w >= 1000 then
				out.zoomed[#out.zoomed + 1] = f
			else
				out.rows[#out.rows + 1] = f
			end
		end
	end
	return out
end
local bars = Bars()
check("three proportional rows", #bars.rows, 3)
check("two lamps + one slide, each 1000x its window", #bars.zoomed, 3)
check("lamp width is 28 x 1000", bars.zoomed[1].w, 28000)
check("slide width is 128 x 1000", bars.zoomed[3].w, 128000)
check("zoomed bars are pinned to their window's right edge", bars.zoomed[1].point, "RIGHT")
check("row 'at hit': max is the health given", bars.rows[2].hi, 4000)
check("row 'at hit': value is the damage", bars.rows[2].value, 5000)
check("row 'of max': max health used", bars.rows[1].hi, 8000)
check("fill eases in (ExponentialEaseOut)", bars.rows[2].interp, 1)
check("slide: damage vs health", bars.zoomed[3].hi .. ":" .. bars.zoomed[3].value, "4000:5000")
local slideArt
for _, t in ipairs(env.regions) do
	if t.anchorTo == bars.zoomed[3]:GetStatusBarTexture() then
		slideArt = t
	end
end
check("OVERKILL art rides the slide bar's fill edge", slideArt ~= nil and slideArt.point, "RIGHT")
local rowTexts = {}
for _, fs in ipairs(env.labels) do
	if fs.text and tostring(fs.text):match("^%S+ / %S+$") then
		rowTexts[#rowTexts + 1] = fs.text
	end
end
check("row text draws damage / health", rowTexts[2], "5.0K / 4.0K")

-- Live path: secret damage and secret health go to the bars untouched.
env.health, env.healthMax = Secret(2000), Secret(10000)
local watcherFrame
for _, f in ipairs(env.frames) do
	if f.events.UNIT_HEALTH then
		watcherFrame = f
	end
end
check("meter watches target health", watcherFrame ~= nil, true)
env.health = Secret(9000); watcherFrame:Fire("UNIT_HEALTH", "target")
env.health = Secret(6000); watcherFrame:Fire("UNIT_HEALTH", "target")
env.health = Secret(2500)
local okMeter, errMeter = pcall(Hit, Secret("DAMAGE"), Secret(false), Secret(false), nil, Secret(3000))
check("secret hit through the meter does not error", okMeter and "ok" or tostring(errMeter), "ok")
bars = Bars()
check("row 'at hit' max is the secret read at the hit", tostring(bars.rows[2].hi), "<S:2500>")
check("row 'prior' max is the update before the latest", tostring(bars.rows[3].hi), "<S:9000>")
check("row 'of max' max is the secret max health", tostring(bars.rows[1].hi), "<S:10000>")
check("bar value is the secret damage", tostring(bars.rows[2].value), "<S:3000>")
check("slide defaults to the 'at hit' reading", tostring(bars.zoomed[3].hi), "<S:2500>")
_G.SlashCmdList.PULSECOMIC("meter source prev")
Hit(Secret("DAMAGE"), Secret(false), Secret(false), nil, Secret(3000))
check("meter source prev moves the slide to the prior reading", tostring(Bars().zoomed[3].hi), "<S:9000>")
_G.SlashCmdList.PULSECOMIC("meter source hit")
env.health = nil
Hit("DAMAGE", nil, false)
check("no health reading: row says so", Bars().rows[2].hi, 1)
_G.SlashCmdList.PULSECOMIC("meter")
check("/comic meter toggles the panel off", meterPanel.shown, false)
check("and stops watching health", watcherFrame.events.UNIT_HEALTH, nil)
env.health, env.healthMax = nil, nil

_G.SlashCmdList.PULSECOMIC("debug")
env.info = { Secret("a"), Secret(1), Secret(true) }
env.dead = Secret(false)
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
local ok, err = pcall(env.driver.Fire, env.driver, "COMBAT_TEXT_UPDATE", Secret("DAMAGE_CRIT"))
check("debug output with every value secret does not error", ok and "ok" or tostring(err), "ok")
check("debug output marks secrets", (env.chat[#env.chat] or ""):find("<secret string>", 1, true) ~= nil, true)

-- ── Announcer ─────────────────────────────────────────────────────────────────────────
Load(true)
local ann = env.ns.announcer
local annFrame, targetCasts
for _, f in ipairs(env.frames) do
	if f.events.PLAYER_REGEN_DISABLED then
		annFrame = f
	end
end
for _, f in ipairs(env.frames) do
	if f.events.UNIT_SPELLCAST_INTERRUPTED and f ~= annFrame then
		targetCasts = f
	end
end
check("announcer registers PARTY_KILL", annFrame and annFrame.events.PARTY_KILL, true)
check("announcer watches the target's interrupts on its own frame", targetCasts ~= nil, true)

local function Flush()
	for _ = 1, 12 do
		Advance(1)
	end
end
-- Titles shown since a Mark(). The history is bounded, so count by shownTotal.
local function Since(mark)
	local out, count = {}, ann.shownTotal - mark
	for i = #ann.history - count + 1, #ann.history do
		out[#out + 1] = ann.history[i]
	end
	return table.concat(out, ",")
end
local function Mark()
	Flush()
	return ann.shownTotal
end
local function Sub()
	return tostring(ann.stage.sub.text)
end
local function Kill(attacker, victim)
	annFrame:Fire("PARTY_KILL", attacker, victim or "Creature-1")
end

-- FIRST BLOOD
local m = Mark()
annFrame:Fire("PLAYER_REGEN_DISABLED")
Kill("Player-1")
check("solo kill: no FIRST BLOOD by default", Since(m), "")
env.inGroup = true
annFrame:Fire("PLAYER_REGEN_DISABLED")
m = Mark()
Kill("Player-2")
check("group fight: groupmate's first kill is FIRST BLOOD", Since(m), "firstblood")
check("FIRST BLOOD names killer and secret victim", Sub(), "Bob drew first blood on <S:Hogger>")
check("FIRST BLOOD plays a sound", env.sounds, 1)
Flush()
m = Mark()
Kill("Player-2")
check("only the first kill of a fight", Since(m), "")
annFrame:Fire("PLAYER_REGEN_ENABLED")
annFrame:Fire("PLAYER_REGEN_DISABLED")
m = Mark()
Kill("Player-1")
check("a new fight has its own FIRST BLOOD", Since(m), "firstblood")
check("your FIRST BLOOD says you", Sub(), "You drew first blood on <S:Hogger>")

-- Multi-kills: Player-1 kills above were 5+ seconds apart from each other
env.now = env.now + 10
m = Mark()
Kill("Player-1")
Advance(1)
Kill("Player-1")
Advance(1)
Kill("Player-1")
Flush()
-- Your 5th kill of the session lands here too, hence the spree.
check("kills under 4 s apart: DOUBLE then TRIPLE KILL", Since(m), "double,triple,spree5")
env.now = env.now + 10
m = Mark()
Kill("Pet-1")
Advance(1)
Kill("Pet-1")
Flush()
check("pet kills count toward multi-kills", Since(m):find("double", 1, true) ~= nil, true)

-- Spree: kills so far this session: 1 (solo) + 1 + 3 + 2 = 7 of yours; dying resets it.
m = Mark()
annFrame:Fire("PLAYER_DEAD")
Flush()
check("PLAYER_DEAD: YOU DIED", Since(m), "youdied")
m = Mark()
for _ = 1, 5 do
	env.now = env.now + 10
	Kill("Player-1")
end
Flush()
check("5 kills without dying: KILLING SPREE", Since(m), "spree5")
for _ = 1, 5 do
	env.now = env.now + 10
	Kill("Player-1")
end
Flush()
check("10: RAMPAGE", ann.history[#ann.history], "spree10")

-- MVP (Flawless, which also ends a deathless group fight, is tested with the fight flow)
env.ns.SetEvent("flawless", "enabled", false)
annFrame:Fire("PLAYER_REGEN_DISABLED")
for _ = 1, 3 do
	env.now = env.now + 10
	Kill("Player-1")
end
Kill("Player-2")
m = Mark()
annFrame:Fire("PLAYER_REGEN_ENABLED")
Flush()
check("fight end in a group: MVP", Since(m), "mvp")
check("MVP names the top killer", Sub(), "You  ·  3 of 4 kills")
annFrame:Fire("PLAYER_REGEN_DISABLED")
env.now = env.now + 10
Kill("Player-1")
Kill("Player-1")
Kill("Player-2")
Kill("Pet-2") -- a groupmate's pet is its own entry
Kill("Player-2")
m = Mark()
annFrame:Fire("PLAYER_REGEN_ENABLED")
Flush()
check("tied fight: no MVP", Since(m):find("mvp", 1, true) == nil, true)

-- Kill feed
env.now = env.now + 10
Kill("Player-2", Secret("Creature-5"))
local feedText = tostring(_G.PulseComicKillFeed.lines[1].text)
check("feed line names the groupmate", feedText:find("Bob", 1, true) ~= nil, true)
check("feed line draws the secret victim name", feedText:find("<S:Defias Thug>", 1, true) ~= nil, true)
Kill("Player-1", Secret("Creature-404"))
check("unknown victim reads 'an enemy'", tostring(_G.PulseComicKillFeed.lines[1].text):find("an enemy", 1, true) ~= nil, true)
check("newest feed line on top, older below", tostring(_G.PulseComicKillFeed.lines[2].text):find("Bob", 1, true) ~= nil, true)
Advance(7)
check("feed lines expire", _G.PulseComicKillFeed.lines[1].shown, false)
local before = #ann.feedEntries
Kill("Creature-7")
check("kills outside the group stay out of the feed", #ann.feedEntries, before)

-- Deaths
m = Mark()
annFrame:Fire("UNIT_DIED", "Player-2")
Flush()
check("groupmate death: TEAMMATE DOWN", Since(m), "teammate")
check("TEAMMATE DOWN names them", Sub(), "Bob")
env.partySize = 2
env.guids.party2 = "Player-3"
env.deadUnits = { party1 = true, party2 = true }
m = Mark()
annFrame:Fire("UNIT_DIED", "Player-3")
Flush()
check("everyone else down: LAST ONE STANDING", Since(m), "teammate,laststanding")
env.deadUnits.player = true
m = Mark()
annFrame:Fire("PLAYER_DEAD")
Flush()
check("you too: WIPE", Since(m), "youdied,wipe")
env.deadUnits, env.partySize, env.guids.party2 = {}, 1, nil
m = Mark()
env.guids.pet = nil -- the pet is already gone when UNIT_DIED fires
annFrame:Fire("UNIT_DIED", "Pet-1")
Flush()
check("pet death: PET DOWN (from the cached GUID)", Since(m), "petdown")
env.guids.pet = "Pet-1"
m = Mark()
annFrame:Fire("UNIT_DIED", Secret("Creature-1"))
Flush()
check("secret GUID death: nothing", Since(m), "")

-- Interrupts
m = Mark()
annFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1767)
Advance(0.2)
targetCasts:Fire("UNIT_SPELLCAST_INTERRUPTED", Secret("target"), Secret("c"), Secret(9), Secret("Player-1"))
Flush()
check("your Kick then the target's interrupt: INTERRUPT!", Since(m), "interrupt")
check("INTERRUPT! draws the target's secret name", Sub(), "You shut <S:Hogger> up")
m = Mark()
annFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 133)
targetCasts:Fire("UNIT_SPELLCAST_INTERRUPTED")
Flush()
check("a non-interrupt spell does not claim it", Since(m), "")
annFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast-3", 6552)
Advance(0.7)
targetCasts:Fire("UNIT_SPELLCAST_INTERRUPTED")
Flush()
check("too late to be yours", Since(m), "")
m = Mark()
annFrame:Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-4", 133, "Creature-5", 1)
Flush()
check("someone interrupts you: INTERRUPTED", Since(m), "interrupted")
check("INTERRUPTED names the interrupter", Sub(), "by <S:Defias Thug>")
m = Mark()
annFrame:Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-5", 133, nil, 1)
Flush()
check("a cast you cancelled: nothing", Since(m), "")
annFrame:Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-6", 133, Secret("Creature-9"), 1)
Flush()
check("a secret interrupter still counts", Since(m), "interrupted")

-- Encounters, level up
m = Mark()
annFrame:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1)
annFrame:Fire("ENCOUNTER_END", 2, "Van Cleef", 1, 5, 0)
annFrame:Fire("PLAYER_LEVEL_UP", 42)
Flush()
check("BOSS DOWN, WIPE, LEVEL UP", Since(m), "bossdown,encwipe,levelup")

-- Avoidance (off by default)
check("dodges off by default", annFrame.events.UNIT_COMBAT, nil)
env.ns.SetEvent("avoid", "enabled", true)
check("annAvoid registers UNIT_COMBAT on you", annFrame.events.UNIT_COMBAT, true)
m = Mark()
annFrame:Fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
annFrame:Fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
Advance(2)
annFrame:Fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
annFrame:Fire("UNIT_COMBAT", "player", Secret("DODGE"), "", 0, 1)
Flush()
check("DODGED!, throttled, then PARRIED!", Since(m), "avoid,avoid")

-- Toggles and limits
env.ns.Set("annFeed", false)
before = #ann.feedEntries
Kill("Player-1")
check("feed off: no line", #ann.feedEntries, before)
m = Mark()
for _ = 1, 8 do
	ann:Fire("triple", { count = 3 })
end
Flush()
check("one banner on screen, at most 4 waiting", select(2, Since(m):gsub("triple", "")), 5)
env.ns.Set("enabled", false)
check("PulseComic off: announcer unregisters", next(annFrame.events), nil)
env.ns.Set("enabled", true)
check("back on: registers again", annFrame.events.PARTY_KILL, true)
m = Mark()
ann:Demo()
Flush()
check("demo plays four banners", Since(m), "firstblood,double,spree5,mvp")

-- ── Art, events, text ─────────────────────────────────────────────────────────────────
Load(true)
local ART = env.ns.art
check("art: a sequence resolves to three frames", #ART.Resolve("comic/pow").frames, 3)
check("art: frame paths follow Art/<theme>/<message>_<n>", ART.Resolve("anime/critical").frames[2], "Interface\\AddOns\\PulseComic\\Art\\anime\\critical_2")
check("art: originals play one file three times", ART.Resolve("original/pow").frames[3], "Interface\\AddOns\\PulseComic\\Media\\pow")
check("art: none is text only", ART.Resolve("none"), nil)
check("art: random from a category stays in it", ART.Resolve("random:failure").category, "failure")
check("art: random from everything resolves", ART.Resolve("random:all") ~= nil, true)
check("art: unknown choice resolves to nothing", ART.Resolve("comic/nope"), nil)
check("art: describe a random choice", ART.Describe("random:anime"), "Random: Anime")
local fs = { SetText = function(self, t) self.text = t end, SetFormattedText = function(self, f, ...)
	local a = { ... }
	for i = 1, select("#", ...) do
		if isSecret(a[i]) then
			a[i] = tostring(a[i])
		end
	end
	self.text = string.format(f, unpack(a, 1, select("#", ...)))
end }
env.ns.ComposeText(fs, "100% {amount}!", { amount = "1.2K" })
check("text: % in a template is kept, tokens fill", fs.text, "100% 1.2K!")
env.ns.ComposeText(fs, "{killer} vs {nobody}", { killer = "You" })
check("text: an unknown token draws empty", fs.text, "You vs ")
env.ns.ComposeText(fs, "{victim}", { victim = Secret("Hogger") })
check("text: secret values are drawn, not read", fs.text, "<S:Hogger>")
env.ns.ComposeText(fs, "plain words", nil)
check("text: a template without tokens is set as is", fs.text, "plain words")
env.ns.ComposeText(fs, "", nil)
check("text: empty template clears", fs.text, "")

-- Hit events take their look from the profile
local function TexOf(key)
	local root = _G["PulseComicFrame_" .. key]
	for _, tex in ipairs(env.regions) do
		local p = tex.parent
		while p and p ~= root do
			p = p.parent
		end
		if p == root and tex.texture then
			return tex.texture
		end
	end
end
env.ns.SetEvent("crit", "art", "anime/critical")
Hit("DAMAGE_CRIT", nil, false)
check("crit plays the chosen art, first frame", TexOf("pow"), "Interface\\AddOns\\PulseComic\\Art\\anime\\critical_1")
env.timers = {}
env.ns.Test("pow")
Advance(0.09)
check("flipbook: peak frame after 80 ms", TexOf("pow"), "Interface\\AddOns\\PulseComic\\Art\\anime\\critical_2")
Advance(0.13)
check("flipbook: aftershock frame after 200 ms", TexOf("pow"), "Interface\\AddOns\\PulseComic\\Art\\anime\\critical_3")
env.ns.SetEvent("crit", "anim", "slam")
env.timers = {}
env.ns.Test("pow")
check("slam shows the peak frame from the start", TexOf("pow"), "Interface\\AddOns\\PulseComic\\Art\\anime\\critical_2")
env.ns.SetEvent("crit", "enabled", false)
check("crit event off: a crit shows nothing", Hit("DAMAGE_CRIT", nil, false), "none")
check("crit event off: a crit kill still shows OVERKILL!", Hit("DAMAGE_CRIT", nil, true), "overkill")
env.ns.SetEvent("crit", "enabled", true)
env.ns.SetEvent("crit", "sub", "{amount} CRIT")
Hit("DAMAGE_CRIT", nil, false)
check("hit detail line is a template", LabelOf("pow"), "1.2K CRIT")

-- ── Profiles ──────────────────────────────────────────────────────────────────────────
Load(true)
local P = env.ns.profiles
check("fresh install: one Default profile", table.concat(P:Names(), ","), "Default")
check("ns.db is the active profile", env.ns.db == _G.PulseComicDB.profiles.Default, true)
check("character table created", type(_G.PulseComicCharDB), "table")
check("every event filled", env.ns.db.events.spree30.title, "WICKED SICK")
check("minimap lives account-wide", _G.PulseComicDB.minimap.pos, 225)

check("create from defaults", P:Create("PvP"), "PvP")
check("create refuses a duplicate", select(2, P:Create("PvP")), "a profile with that name exists")
check("create refuses an empty name", P:Create("   "), nil)
_G.PulseComicDB.profiles.PvP.events.firstblood.enabled = false
check("use a profile on this character", P:Use("PvP"), true)
check("switch moves ns.db", env.ns.db == _G.PulseComicDB.profiles.PvP, true)
check("character choice saved", _G.PulseComicCharDB.profile, "PvP")
check("announcer follows the switch", select(2, pcall(function()
	env.inGroup = true
	local annFrame2
	for _, f in ipairs(env.frames) do
		if f.events.PLAYER_REGEN_DISABLED then
			annFrame2 = f
		end
	end
	local before2 = env.ns.announcer.shownTotal
	annFrame2:Fire("PLAYER_REGEN_DISABLED")
	annFrame2:Fire("PARTY_KILL", "Player-2", "Creature-1")
	return env.ns.announcer.shownTotal - before2
end)), 0)
check("copy a profile", P:Create("PvP copy", "PvP"), "PvP copy")
check("copy is a deep copy", _G.PulseComicDB.profiles["PvP copy"].events ~= _G.PulseComicDB.profiles.PvP.events, true)
check("rename", P:Rename("PvP copy", "Raid"), "Raid")
check("Default keeps its name", P:Rename("Default", "X"), nil)
check("set account default", P:SetDefault("Raid"), true)
check("character keeps its own choice", P:ActiveName(), "PvP")
P:Use(nil)
check("following the default", P:ActiveName(), "Raid")
check("delete", P:Delete("Raid"), true)
check("deleting the default falls back to Default", P:ActiveName(), "Default")
check("Default cannot be deleted", P:Delete("Default"), false)
_G.PulseComicDB.profiles.PvP.scale = 2
P:Reset("PvP")
check("reset restores defaults", _G.PulseComicDB.profiles.PvP.scale, 1)

-- Export / import round trip
local pvp = _G.PulseComicDB.profiles.PvP
pvp.events.crit.art = "anime/critical"
pvp.events.crit.title = "BAM | {amount} 100%"
pvp.events.youdied.anim = "shake"
pvp.killPet = false
local text = P:Export("PvP")
check("export starts with the prefix", text:sub(1, 8), "PCOMIC1:")
check("export is one line without | (chat-safe)", text:find("[|\n]") == nil, true)
local added = P:Import(text)
check("import adds a copy beside the original", added and added[1], "PvP (2)")
local copy = _G.PulseComicDB.profiles["PvP (2)"]
check("round trip: art", copy.events.crit.art, "anime/critical")
check("round trip: text with | and %", copy.events.crit.title, "BAM | {amount} 100%")
check("round trip: animation", copy.events.youdied.anim, "shake")
check("round trip: flat setting", copy.killPet, false)
added = P:Import(text, "Mine")
check("import under a chosen name", added and added[1], "Mine")
added = P:Import(P:ExportAll())
check("import all: every profile added", added and #added, #P:Names() / 2)

check("import rejects other text", select(2, P:Import("hello")), "not a PulseComic export (it starts with PCOMIC1:)")
check("import rejects a cut-off string", P:Import(text:sub(1, 40)), nil)
check("import rejects deep nesting", P:Import("PCOMIC1:" .. string.rep("{S61;", 10) .. string.rep("}", 10)), nil)
check("import rejects trailing data", P:Import(text .. "T"), nil)
local hostile
local function Enc(v)
	local out = {}
	local function e(x)
		if type(x) == "table" then
			out[#out + 1] = "{"
			local keys = {}
			for k in pairs(x) do keys[#keys + 1] = k end
			table.sort(keys)
			for _, k in ipairs(keys) do e(k); e(x[k]) end
			out[#out + 1] = "}"
		elseif type(x) == "string" then
			out[#out + 1] = "S" .. x:gsub(".", function(c) return ("%02x"):format(c:byte()) end) .. ";"
		elseif type(x) == "number" then
			out[#out + 1] = "N" .. x .. ";"
		else
			out[#out + 1] = x and "T" or "F"
		end
	end
	e(v)
	return "PCOMIC1:" .. table.concat(out)
end
hostile = Enc({ kind = "profile", name = "Evil", profile = {
	scale = "big", foo = "bar", killPet = 1,
	events = { crit = { anim = "evil", size = 99, color = "rainbow", title = string.rep("x", 500) }, unknown = { a = 1 } },
} })
added = P:Import(hostile)
local evil = added and _G.PulseComicDB.profiles[added[1]]
check("hostile import still creates a profile", evil ~= nil, true)
check("hostile: wrong type falls back to default", evil.scale, 1)
check("hostile: unknown keys dropped", evil.foo, nil)
check("hostile: unknown animation falls back", evil.events.crit.anim, "flipbook")
check("hostile: size clamped", evil.events.crit.size, 3)
check("hostile: unknown color falls back", evil.events.crit.color, "gold")
check("hostile: long text cut", #evil.events.crit.title, 300)
check("hostile: unknown event dropped", evil.events.unknown, nil)

-- Migration: art saved under the old category id
Load(true, { version = 2, defaultProfile = "Default", profiles = { Default = { events = { critkill = { art = "counterstrike/headshot" } } } } })
check("migration: saved counterstrike art becomes tactical", _G.PulseComicDB.profiles.Default.events.critkill.art, "tactical/headshot")

-- Migration from flat settings of the previous build
Load(true, { scale = 1.5, annMultiKill = false, numbers = false, critPop = false, minimap = { hide = true, pos = 10 } }, { profile = "Gone" })
local d = _G.PulseComicDB.profiles.Default
check("migration: flat settings become Default", d.scale, 1.5)
check("migration: old toggles become event switches", d.events.double.enabled, false)
check("migration: old crit toggle", d.events.crit.enabled, false)
check("migration: numbers off becomes hit details off", d.events.kill.details, false)
check("migration: old keys removed", d.annMultiKill == nil and d.numbers == nil and d.critPop == nil, true)
check("migration: minimap moves account-wide", _G.PulseComicDB.minimap.hide, true)
check("a character pointing at a missing profile follows the default", env.ns.profiles:ActiveName(), "Default")

-- ── Falls, fight flow, themes, fonts ─────────────────────────────────────────────────
Load(true)
ann = env.ns.announcer
local fallFrame, annFrame3
for _, f in ipairs(env.frames) do
	if f.scripts and f.scripts.OnUpdate then
		fallFrame = f
	end
	if f.events.PLAYER_REGEN_DISABLED then
		annFrame3 = f
	end
end
check("fall events on by default: the fall poll runs", fallFrame ~= nil, true)
local function Air(seconds)
	local steps = math.floor(seconds / 0.1 + 0.5)
	for _ = 1, steps do
		env.now = env.now + 0.1
		fallFrame.scripts.OnUpdate(fallFrame, 0.1)
		Advance(0)
	end
end
local function Land()
	env.falling = false
	Air(0.1)
end
local function Ids(mark)
	Flush()
	local out, count = {}, ann.shownTotal - mark
	for i = #ann.history - count + 1, #ann.history do
		out[#out + 1] = ann.history[i]
	end
	return table.concat(out, ",")
end

m = Mark()
env.falling = true
Air(0.5)
Land()
check("short drop: nothing", Ids(m), "")

m = Mark()
env.falling = true
Air(1.4)
check("over 1.2 s in the air: falling", ann.history[#ann.history], "falling")
Air(1.6)
Land()
Advance(0.4)
check("survived a 3 s fall: falling, then hard landing", Ids(m), "falling,hardlanding")
check("hard landing tells the air time", Sub(), "3.0 s in the air")

m = Mark()
env.falling = true
Air(3)
Land()
env.deadUnits.player = true
annFrame3:Fire("PLAYER_DEAD")
Advance(0.4)
env.deadUnits.player = nil
check("death right after a long fall: fell to death, not YOU DIED, no hard landing", Ids(m), "falling,falldeath")
m = Mark()
env.falling = true
Air(2)
annFrame3:Fire("PLAYER_DEAD")
env.falling = false
Air(0.2)
Advance(0.4)
check("death while still falling: fell to death", Ids(m), "falling,falldeath")
m = Mark()
annFrame3:Fire("PLAYER_DEAD")
check("death on the ground: YOU DIED", Ids(m), "youdied")
env.ns.SetEvent("falldeath", "enabled", false)
m = Mark()
env.falling = true
Air(3)
Land()
annFrame3:Fire("PLAYER_DEAD")
check("fell to death off: YOU DIED instead", Ids(m), "falling,youdied")
env.ns.SetEvent("falldeath", "enabled", true)
m = Mark()
env.falling, env.flying = true, true
Air(3)
env.falling, env.flying = false, false
Air(0.1)
Advance(0.4)
check("flying is not falling", Ids(m), "")
env.ns.SetEvent("falling", "enabled", false)
env.ns.SetEvent("hardlanding", "enabled", false)
env.ns.SetEvent("falldeath", "enabled", false)
check("all fall events off: the poll stops", fallFrame.scripts.OnUpdate, nil)

-- Fight flow
check("fight start off by default", (function()
	m = Mark()
	annFrame3:Fire("PLAYER_REGEN_DISABLED")
	return Ids(m)
end)(), "")
env.ns.SetEvent("kickoff", "enabled", true)
env.ns.SetEvent("fulltime", "enabled", true)
env.inGroup = true
m = Mark()
annFrame3:Fire("PLAYER_REGEN_DISABLED")
env.now = env.now + 10
annFrame3:Fire("PARTY_KILL", "Player-2", "Creature-1")
annFrame3:Fire("PLAYER_REGEN_ENABLED")
check("group fight: start, first blood, end, flawless", Ids(m), "kickoff,firstblood,fulltime,flawless")
m = Mark()
annFrame3:Fire("PLAYER_REGEN_DISABLED")
annFrame3:Fire("PARTY_KILL", "Player-2", "Creature-1")
annFrame3:Fire("UNIT_DIED", "Player-2")
annFrame3:Fire("PLAYER_REGEN_ENABLED")
check("a teammate died: no flawless", Ids(m):find("flawless", 1, true) == nil, true)
m = Mark()
annFrame3:Fire("PLAYER_REGEN_DISABLED")
annFrame3:Fire("PLAYER_REGEN_ENABLED")
check("a fight with no kills has no end banner", Ids(m), "kickoff")

-- Fonts
P = env.ns.profiles
local FONT_DIR = "Interface\\AddOns\\PulseComic\\Art\\_fonts\\"
env.ns.Test("pow")
check("auto font: a comic pop gets the comic font", ann.stage and _G.PulseComicFrame_pow and (function()
	for _, fs in ipairs(env.labels) do
		local q = fs.parent
		while q and q ~= _G.PulseComicFrame_pow do
			q = q.parent
		end
		if q then
			return fs.fontPath
		end
	end
end)(), FONT_DIR .. "bangers\\Bangers-Regular.ttf")
env.ns.SetEvent("kickoff", "art", "none")
annFrame3:Fire("PLAYER_REGEN_DISABLED")
check("auto font without art: the stencil text font", ann.stage.title.fontPath, FONT_DIR .. "black-ops-one\\BlackOpsOne-Regular.ttf")
Flush()
env.ns.SetEvent("kickoff", "font", "graduate")
annFrame3:Fire("PLAYER_REGEN_DISABLED")
check("a chosen display font", ann.stage.title.fontPath, FONT_DIR .. "graduate\\Graduate-Regular.ttf")
Flush()
env.badFonts = { [FONT_DIR .. "knewave\\Knewave-Regular.ttf"] = true }
env.ns.SetEvent("kickoff", "font", "knewave")
annFrame3:Fire("PLAYER_REGEN_DISABLED")
check("a font the client refuses leaves the game font", ann.stage.title.fontPath, "Fonts\\FRIZQT__.TTF")
env.badFonts = nil
Flush()
env.ns.SetEvent("kickoff", "font", "arial")
annFrame3:Fire("PLAYER_REGEN_DISABLED")
check("event font reaches the title", ann.stage.title.fontPath, "Fonts\\ARIALN.TTF")
check("and the detail line", ann.stage.sub.fontPath, "Fonts\\ARIALN.TTF")
Flush()

-- Catalog and themes
check("categories carry the addon's own names", env.ns.art.CategoryLabel("tactical") .. "|" .. env.ns.art.CategoryLabel("arcade") .. "|" .. env.ns.art.CategoryLabel("football"), "Strike Squad|Roadfighter|Soccer League")
check("Strike Squad art resolves", env.ns.art.Resolve("tactical/headshot").frames[1], "Interface\\AddOns\\PulseComic\\Art\\tactical\\headshot_1")
check("an art key saved before the rename still resolves", env.ns.art.Resolve("counterstrike/headshot").frames[1], "Interface\\AddOns\\PulseComic\\Art\\tactical\\headshot_1")
check("old random category still resolves", env.ns.art.Resolve("random:counterstrike").category, "tactical")
check("football and falling art in the catalog", env.ns.art.Resolve("football/top-bins") ~= nil and env.ns.art.Resolve("falling/wheee") ~= nil, true)
check("nine display fonts listed", #env.ns.ART_FONTS, 9)
check("each category knows its font", env.ns.art.FontFor("comic") .. "|" .. env.ns.art.FontFor("tactical"), "bangers|black-ops-one")
P = env.ns.profiles
env.ns.SetEvent("crit", "enabled", false)
check("the old theme id still applies", P:ApplyTheme("Default", "counterstrike"), true)
check("apply Strike Squad", P:ApplyTheme("Default", "tactical"), true)
local ev = env.ns.db.events
check("CS: headshot art on crit kills", ev.critkill.art, "tactical/headshot")
check("CS: art carries the word, no title on top", ev.critkill.title, "")
check("CS: text where there is no art", ev.kill.title .. "|" .. ev.kill.art, "ENEMY DOWN|none")
check("CS: stencil font everywhere", ev.youdied.font, "black-ops-one")
check("CS: ACE art on 5 kills", ev.mega.art, "tactical/ace")
check("CS: turns round start on", ev.kickoff.enabled, true)
check("CS: keeps crit off as the player had it", ev.crit.enabled, false)
check("apply Football", P:ApplyTheme("Default", "football"), true)
check("Football: GOAL! art, its word in the art", ev.kill.art .. "|" .. ev.kill.title, "football/goal|")
check("Football: top bins on crit kills", ev.critkill.art, "football/top-bins")
check("Football: varsity font", ev.kill.font, "graduate")
check("Football: text where it has no art", ev.bossdown.art .. "|" .. ev.bossdown.title, "none|CHAMPIONS!")
env.ns.themes.Get("football").events.bossdown.art = "football/champions"
P:ApplyTheme("Default", "football")
check("art a theme names but the catalog lacks falls back to text", ev.bossdown.art .. "|" .. ev.bossdown.title, "none|CHAMPIONS!")
env.ns.themes.Get("football").events.bossdown.art = nil
check("apply Roadfighter", P:ApplyTheme("Default", "roadfighter") and ev.interrupt.art, "arcade/counter")
check("apply Shadow Clan", P:ApplyTheme("Default", "shadowclan") and ev.critkill.art, "ninja/executed")
check("apply Boomer Shooter", P:ApplyTheme("Default", "boomer") and ev.kill.art .. "|" .. ev.kill.font, "arena/fragged|metal-mania")
check("Football: hat-trick art", P:ApplyTheme("Default", "football") and ev.triple.art, "football/hat-trick")
check("Football: own goal on fall death", ev.falldeath.art, "football/own-goal")
check("apply Classic restores defaults", P:ApplyTheme("Default", "classic") and ev.kill.art, "comic/ko")
check("new profile from a theme", P:CreateFromTheme("", "tactical"), "Strike Squad")
check("named after the theme, dressed in it", _G.PulseComicDB.profiles["Strike Squad"].events.critkill.art, "tactical/headshot")
local cs = P:Export("Strike Squad")
local back = P:Import(cs)
check("theme survives export / import", _G.PulseComicDB.profiles[back[1]].events.kill.font, "black-ops-one")
check("unknown theme refused", P:ApplyTheme("Default", "chess"), false)
local chatBefore = #env.chat
_G.SlashCmdList.PULSECOMIC("credits")
check("/comic credits lists every font", #env.chat - chatBefore, 9 + 2)
check("credits name the designer and license", (table.concat(env.chat, "\n", chatBefore + 1)):find("Tyler Finck", 1, true) ~= nil
	and (table.concat(env.chat, "\n", chatBefore + 1)):find("SIL Open Font License 1.1", 1, true) ~= nil, true)

-- ── Pre-12.0 client: no SetAlphaFromBoolean, no secrets, legacy combat-text globals ────
Load(false)
check("pre-12.0: active unit set through legacy global", env.activeUnit, "target")
for _, c in ipairs(CASES) do
	local name, crit, dead, want = unpack(c)
	check("pre-12.0 plain path, " .. name, Hit(crit and "SPELL_DAMAGE_CRIT" or "SPELL_DAMAGE", nil, dead), want)
end

-- ── Source scan: no branching on a possibly-secret value ──────────────────────────────
-- The stand-ins above cannot catch `if isCrit then` or `isCrit == true`: Lua lets any table
-- be truthy and only runs __eq when both sides are tables. In the client both raise. So the
-- names that may carry a secret are checked in the source instead.
_G.type = realtype
local SECRET_NAMES = {
	"isCrit", "isDead", "ret1", "ret2", "ret3", "dead", "victimGUID", "attackerGUID", "value", "amount", "width",
	"health", "healthNow", "healthPrior", "healthMax", "healthLast", "healthBefore", "source", "max",
	"victim", "interruptedBy", "token", "encounterName", "level",
}
local offenders = {}
for _, file in ipairs(FILES) do
local source = assert(io.open(ROOT .. "/" .. file)):read("*a")
local lineNo = 0
for line in (source .. "\n"):gmatch("([^\n]*)\n") do
	lineNo = lineNo + 1
	-- Comments and string literals cannot branch on anything; drop them before matching.
	local code = line:gsub("%-%-.*$", ""):gsub('"[^"]*"', '""'):gsub("'[^']*'", "''")
	for _, name in ipairs(SECRET_NAMES) do
		local n = "%f[%w_]" .. name .. "%f[^%w_]"
		local keyword = code:match("%f[%w_]if%s+%(?" .. n)
			or code:match("%f[%w_]elseif%s+%(?" .. n)
			or code:match("%f[%w_]while%s+%(?" .. n)
			or code:match("%f[%w_]and%s+%(?" .. n)
			or code:match("%f[%w_]or%s+%(?" .. n)
			or code:match("%f[%w_]not%s+%(?" .. n)
			or code:match(n .. "%s*[=~<>]=")
			or code:match(n .. "%s*[<>]")
			or code:match("[=~<>]=%s*" .. n)
			or code:match(n .. "%s+and%f[^%w_]")
			or code:match(n .. "%s+or%f[^%w_]")
		-- The one sanctioned read: Gate() inspects `value` only after issecretvalue() said no.
		local sanctioned = name == "value" and code:match("^%s*if value then%s*$")
		if keyword and not sanctioned then
			offenders[#offenders + 1] = ("%s:%d: %s"):format(file, lineNo, (line:gsub("^%s+", "")))
		end
	end
end
end
check("source never branches on or compares a possibly-secret value", table.concat(offenders, " | "), "")

if failures == 0 then
	print("NO FAILURES")
else
	print(("FAILURES: %d"):format(failures))
	os.exit(1)
end
