-- Offline test for KAPOW.
--
-- KAPOW decides which comic frame is visible without ever reading the crit flag or the
-- death state, because in 12.x either may be a secret boolean. This test loads the real
-- Kapow.lua against a stub WoW API in which secret booleans are tables that throw on
-- comparison, and only SetAlphaFromBoolean may unwrap them. Effective alpha is computed as
-- the product down the parent chain, the same as the client.
--
-- It cannot tell you that the client really delivers target hits on the combat-text feed,
-- or that UnitIsDead settles inside killDelay; those are what `/kapow debug` is for. It can
-- tell you that every (crit, dead) pair shows exactly the right frame through the secret
-- path, the plain path and the pre-12.0 fallback, and that nothing ever compares a secret.
--
-- Run from the repo root:  lua PulseChecklist/tests/kapow-test.lua KAPOW

local ROOT = arg[1] or "Kapow"
-- TOC order, minus the window and minimap button (UI/), which the smoke test covers.
local FILES = { "Kapow.lua", "Meter.lua", "ArtCatalog.lua", "SoundCatalog.lua", "Art.lua", "Events.lua", "Display.lua", "Themes.lua", "Profiles.lua", "Announcer.lua", "Detect.lua", "Attribution.lua", "Extras.lua", "Moments.lua", "Versus.lua" }
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
		"SetVertexColor", "SetBlendMode", "SetParent",
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
	function r:IsShown()
		return self.shown
	end
	function r:GetCenter()
		return self.cx or 0, self.cy or 0
	end
	function r:Show()
		self.shown = true
	end
	function r:SetAlpha(a)
		if isSecret(a) and not env.secretAlphaOK then
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

-- saved / savedChar: what KapowDB / KapowCharDB hold before ADDON_LOADED.
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
	_G.UnitExists = function(unit)
		return env.guids[unit] ~= nil
	end
	_G.UnitAffectingCombat = function(unit)
		return unit == "pet" and env.petCombat or false
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
		if a == "pettarget" and b == "target" then
			return env.petTarget or false
		end
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
	_G.KapowDB = saved
	_G.KapowCharDB = savedChar

	-- TOC order, one shared addon namespace, as the client does it.
	env.ns = {}
	for _, file in ipairs(FILES) do
		assert(loadfile(ROOT .. "/" .. file))("Kapow", env.ns)
	end
	for _, f in ipairs(env.frames) do
		if f.events.ADDON_LOADED then
			env.driver = f
		end
	end
	env.driver:Fire("ADDON_LOADED", "Kapow")
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
		local root = _G["KapowFrame_" .. key]
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
	local root = _G["KapowFrame_" .. key]
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
		_G["KapowFrame_" .. key].shown = false
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
	_G.SlashCmdList.KAPOW("test " .. ({ pow = "pow", ko = "ko", overkill = "overkill", none = "hit" })[want])
	check("/kapow test, " .. name, Visible(), want)
	local msg = crit and "DAMAGE_CRIT" or "DAMAGE"
	check("secret type + secret crit + secret dead, " .. name, Hit(Secret(msg), Secret(crit), Secret(dead)), want)
	check("plain type + plain dead, " .. name, Hit(msg, nil, dead), want)
end

-- Damage numbers
Fade()
_G.SlashCmdList.KAPOW("test pow")
check("/kapow test pow labels the burst through the abbreviator", LabelOf("pow"), "12.3K")
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
_G.SlashCmdList.KAPOW("numbers")
Hit("DAMAGE_CRIT", nil, false)
check("/kapow numbers off clears the label", LabelOf("pow"), "")
_G.SlashCmdList.KAPOW("numbers")
Hit("DAMAGE_CRIT", nil, false)
check("/kapow numbers on restores it", LabelOf("pow"), "1.2K")

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

_G.SlashCmdList.KAPOW("kill death")
check("/kapow kill death turns UnitIsDead off", env.ns.db.killUnitDead, false)
check("with UnitIsDead off a groupmate's kill shows only POW!", KillHit("DAMAGE_CRIT", "Player-2", { dead = true }), "pow")
check("with UnitIsDead off your kill still shows OVERKILL!", KillHit("DAMAGE_CRIT", "Player-1", { dead = false }), "overkill")
_G.SlashCmdList.KAPOW("kill pet")
check("/kapow kill pet turns pet kills off", KillHit(nil, "Pet-1"), "none")
_G.SlashCmdList.KAPOW("kill pet")
_G.SlashCmdList.KAPOW("kill event")
check("/kapow kill event unregisters PARTY_KILL", env.driver.events.PARTY_KILL, nil)
check("with both sources off a crit kill shows only POW!", KillHit("DAMAGE_CRIT", nil, { dead = true }), "pow")
_G.SlashCmdList.KAPOW("kill log")
check("kill log keeps PARTY_KILL registered", env.driver.events.PARTY_KILL, true)
check("kill log alone counts nothing", KillHit("DAMAGE", "Player-1"), "none")
check("kill log says the event is off", (env.chat[#env.chat] or ""):find("killing-blow event is off", 1, true) ~= nil, true)
_G.SlashCmdList.KAPOW("kill event")
_G.SlashCmdList.KAPOW("kill death")

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
_G.SlashCmdList.KAPOW("kill log")
check("groupmate crit ignored under attribution=recent", Hit("DAMAGE_CRIT", true, false, false), "none")
_G.SlashCmdList.KAPOW("attribution any")
check("groupmate crit shown under attribution=any", Hit("DAMAGE_CRIT", true, false, false), "pow")
_G.SlashCmdList.KAPOW("attribution recent")

env.now = env.now + 5
env.timers = {}
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE_CRIT")
Advance(0.01)
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE_CRIT")
check("two hits 10 ms apart schedule one pop", #env.timers, 1)

_G.SlashCmdList.KAPOW("off")
check("/kapow off stops listening", env.driver.events.COMBAT_TEXT_UPDATE, nil)
_G.SlashCmdList.KAPOW("on")
check("/kapow on listens again", env.driver.events.COMBAT_TEXT_UPDATE, true)

-- ── Hit meter (Meter.lua) ─────────────────────────────────────────────────────────────
check("meter is off and unbuilt by default", _G.KAPOWMeter, nil)
_G.SlashCmdList.KAPOW("meter test 5000 4000")
local meterPanel = _G.KAPOWMeter
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
_G.SlashCmdList.KAPOW("meter source prev")
Hit(Secret("DAMAGE"), Secret(false), Secret(false), nil, Secret(3000))
check("meter source prev moves the slide to the prior reading", tostring(Bars().zoomed[3].hi), "<S:9000>")
_G.SlashCmdList.KAPOW("meter source hit")
env.health = nil
Hit("DAMAGE", nil, false)
check("no health reading: row says so", Bars().rows[2].hi, 1)
_G.SlashCmdList.KAPOW("meter")
check("/kapow meter toggles the panel off", meterPanel.shown, false)
check("and stops watching health", watcherFrame.events.UNIT_HEALTH, nil)
env.health, env.healthMax = nil, nil

_G.SlashCmdList.KAPOW("debug")
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
local feedText = tostring(_G.KapowKillFeed.lines[1].text)
check("feed line names the groupmate", feedText:find("Bob", 1, true) ~= nil, true)
check("feed line draws the secret victim name", feedText:find("<S:Defias Thug>", 1, true) ~= nil, true)
Kill("Player-1", Secret("Creature-404"))
check("unknown victim reads 'an enemy'", tostring(_G.KapowKillFeed.lines[1].text):find("an enemy", 1, true) ~= nil, true)
check("newest feed line on top, older below", tostring(_G.KapowKillFeed.lines[2].text):find("Bob", 1, true) ~= nil, true)
Advance(7)
check("feed lines expire", _G.KapowKillFeed.lines[1].shown, false)
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
check("KAPOW off: announcer unregisters", next(annFrame.events), nil)
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
check("art: frame paths follow Art/<theme>/<message>_<n>", ART.Resolve("anime/critical").frames[2], "Interface\\AddOns\\Kapow\\Art\\anime\\critical_2")
check("art: originals play one file three times", ART.Resolve("original/pow").frames[3], "Interface\\AddOns\\Kapow\\Media\\pow")
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
	local root = _G["KapowFrame_" .. key]
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
check("crit plays the chosen art, first frame", TexOf("pow"), "Interface\\AddOns\\Kapow\\Art\\anime\\critical_1")
env.timers = {}
env.ns.Test("pow")
Advance(0.09)
check("flipbook: peak frame after 80 ms", TexOf("pow"), "Interface\\AddOns\\Kapow\\Art\\anime\\critical_2")
Advance(0.13)
check("flipbook: aftershock frame after 200 ms", TexOf("pow"), "Interface\\AddOns\\Kapow\\Art\\anime\\critical_3")
env.ns.SetEvent("crit", "anim", "slam")
env.timers = {}
env.ns.Test("pow")
check("slam shows the peak frame from the start", TexOf("pow"), "Interface\\AddOns\\Kapow\\Art\\anime\\critical_2")
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
check("ns.db is the active profile", env.ns.db == _G.KapowDB.profiles.Default, true)
check("character table created", type(_G.KapowCharDB), "table")
check("every event filled", env.ns.db.events.spree30.title, "WICKED SICK")
check("minimap lives account-wide", _G.KapowDB.minimap.pos, 225)

check("create from defaults", P:Create("PvP"), "PvP")
check("create refuses a duplicate", select(2, P:Create("PvP")), "a profile with that name exists")
check("create refuses an empty name", P:Create("   "), nil)
_G.KapowDB.profiles.PvP.events.firstblood.enabled = false
check("use a profile on this character", P:Use("PvP"), true)
check("switch moves ns.db", env.ns.db == _G.KapowDB.profiles.PvP, true)
check("character choice saved", _G.KapowCharDB.profile, "PvP")
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
check("copy is a deep copy", _G.KapowDB.profiles["PvP copy"].events ~= _G.KapowDB.profiles.PvP.events, true)
check("rename", P:Rename("PvP copy", "Raid"), "Raid")
check("Default keeps its name", P:Rename("Default", "X"), nil)
check("set account default", P:SetDefault("Raid"), true)
check("character keeps its own choice", P:ActiveName(), "PvP")
P:Use(nil)
check("following the default", P:ActiveName(), "Raid")
check("delete", P:Delete("Raid"), true)
check("deleting the default falls back to Default", P:ActiveName(), "Default")
check("Default cannot be deleted", P:Delete("Default"), false)
_G.KapowDB.profiles.PvP.scale = 2
P:Reset("PvP")
check("reset restores defaults", _G.KapowDB.profiles.PvP.scale, 1)

-- Export / import round trip
local pvp = _G.KapowDB.profiles.PvP
pvp.events.crit.art = "anime/critical"
pvp.events.crit.title = "BAM | {amount} 100%"
pvp.events.youdied.anim = "shake"
pvp.killPet = false
pvp.killPetBackup = true
local text = P:Export("PvP")
check("export starts with the prefix", text:sub(1, 7), "KAPOW1:")
check("export is one line without | (chat-safe)", text:find("[|\n]") == nil, true)
local added = P:Import(text)
check("import adds a copy beside the original", added and added[1], "PvP (2)")
local copy = _G.KapowDB.profiles["PvP (2)"]
check("round trip: art", copy.events.crit.art, "anime/critical")
check("round trip: text with | and %", copy.events.crit.title, "BAM | {amount} 100%")
check("round trip: animation", copy.events.youdied.anim, "shake")
check("round trip: flat setting", copy.killPet, false)
check("round trip: separate pet backup setting", copy.killPetBackup, true)
added = P:Import(text, "Mine")
check("import under a chosen name", added and added[1], "Mine")
check("an export from before the rename still imports", (P:Import("PCOMIC1:" .. text:sub(8))) ~= nil, true)
added = P:Import(P:ExportAll())
check("import all: every profile added", added and #added, #P:Names() / 2)

check("import rejects other text", select(2, P:Import("hello")), "not a KAPOW export (it starts with KAPOW1:)")
check("import rejects a cut-off string", P:Import(text:sub(1, 40)), nil)
check("import rejects deep nesting", P:Import("KAPOW1:" .. string.rep("{S61;", 10) .. string.rep("}", 10)), nil)
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
	return "KAPOW1:" .. table.concat(out)
end
hostile = Enc({ kind = "profile", name = "Evil", profile = {
	scale = "big", foo = "bar", killPet = 1,
	events = { crit = { anim = "evil", size = 99, color = "rainbow", title = string.rep("x", 500) }, unknown = { a = 1 } },
} })
added = P:Import(hostile)
local evil = added and _G.KapowDB.profiles[added[1]]
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
check("migration: saved counterstrike art becomes tactical", _G.KapowDB.profiles.Default.events.critkill.art, "tactical/headshot")

-- Migration from flat settings of the previous build
Load(true, { scale = 1.5, annMultiKill = false, numbers = false, critPop = false, minimap = { hide = true, pos = 10 } }, { profile = "Gone" })
local d = _G.KapowDB.profiles.Default
check("migration: flat settings become Default", d.scale, 1.5)
check("migration: old toggles become event switches", d.events.double.enabled, false)
check("migration: old crit toggle", d.events.crit.enabled, false)
check("migration: numbers off becomes hit details off", d.events.kill.details, false)
check("migration: old keys removed", d.annMultiKill == nil and d.numbers == nil and d.critPop == nil, true)
check("migration: minimap moves account-wide", _G.KapowDB.minimap.hide, true)
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
local FONT_DIR = "Interface\\AddOns\\Kapow\\Art\\_fonts\\"
env.ns.Test("pow")
check("auto font: a comic pop gets the comic font", ann.stage and _G.KapowFrame_pow and (function()
	for _, fs in ipairs(env.labels) do
		local q = fs.parent
		while q and q ~= _G.KapowFrame_pow do
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
check("Strike Squad art resolves", env.ns.art.Resolve("tactical/headshot").frames[1], "Interface\\AddOns\\Kapow\\Art\\tactical\\headshot_1")
check("an art key saved before the rename still resolves", env.ns.art.Resolve("counterstrike/headshot").frames[1], "Interface\\AddOns\\Kapow\\Art\\tactical\\headshot_1")
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
check("named after the theme, dressed in it", _G.KapowDB.profiles["Strike Squad"].events.critkill.art, "tactical/headshot")
local cs = P:Export("Strike Squad")
local back = P:Import(cs)
check("theme survives export / import", _G.KapowDB.profiles[back[1]].events.kill.font, "black-ops-one")
check("unknown theme refused", P:ApplyTheme("Default", "chess"), false)
local chatBefore = #env.chat
_G.SlashCmdList.KAPOW("credits")
check("/kapow credits lists every font", #env.chat - chatBefore, 9 + 2)
check("credits name the designer and license", (table.concat(env.chat, "\n", chatBefore + 1)):find("Tyler Finck", 1, true) ~= nil
	and (table.concat(env.chat, "\n", chatBefore + 1)):find("SIL Open Font License 1.1", 1, true) ~= nil, true)

-- ── Optional pet target-death backup (no PARTY_KILL or player hit required) ──────────
local function PetTick()
	local watch = _G.KapowPetKillWatcher
	if watch.scripts.OnUpdate then
		watch.scripts.OnUpdate(watch, 0.05)
	end
end

local function PetSetup(modern)
	Load(modern ~= false)
	env.ns.Set("killUnitDead", false)
	env.ns.Set("annFirstBloodSolo", true)
	env.ns.Set("killPetBackup", true)
	env.petTarget, env.petCombat = true, true
	PetTick() -- observe the pet fighting a living target
end

local function PetDeath()
	env.dead = true
	PetTick()
	Advance(0.2)
end

local function PartyKillBoth(attacker)
	for _, frame in ipairs(env.frames) do
		frame:Fire("PARTY_KILL", attacker, "Creature-1")
	end
end

Load(true)
check("pet backup defaults off", env.ns.db.killPetBackup, false)
check("pet backup off does not poll", _G.KapowPetKillWatcher.scripts.OnUpdate, nil)
env.ns.Set("killPetBackup", true)
local petSaved = _G.KapowDB
Load(true, petSaved)
check("pet backup persists across reload", env.ns.db.killPetBackup, true)
check("pet backup resumes polling after reload", _G.KapowPetKillWatcher.scripts.OnUpdate ~= nil, true)

PetSetup()
PetDeath()
check("pet backup: pet-only target death shows K.O. without PARTY_KILL", Visible(), "ko")
check("pet backup leaves existing death-check setting alone", env.ns.db.killUnitDead, false)
check("pet backup: solo First Blood uses shared kill processing", env.ns.announcer.history[1], "firstblood")
check("pet backup: kill feed names your pet", env.ns.announcer.feedEntries[1].args[1]:find("Your pet", 1, true) ~= nil, true)
local feedCount = #env.ns.announcer.feedEntries
local popRoot = _G.KapowFrame_ko -- a duplicate pop would extend this frame's life
Advance(0.3)
PetTick()
check("pet backup: dead target is counted only once", #env.ns.announcer.feedEntries, feedCount)
PartyKillBoth("Pet-1")
Advance(0.2)
check("pet backup: late PARTY_KILL does not double count feed", #env.ns.announcer.feedEntries, feedCount)
check("pet backup: late PARTY_KILL does not award Double Kill", env.ns.announcer.history[2], nil)
Advance(0.6)
check("pet backup: late PARTY_KILL does not restart the pop", popRoot.shown, false)

-- Five independent pet deaths count toward multi-kills and a spree.
PetSetup()
for i = 1, 5 do
	if i > 1 then
		env.guids.target = "Creature-" .. i
		env.driver:Fire("PLAYER_TARGET_CHANGED")
		env.dead = false
		PetTick()
	end
	PetDeath()
	Advance(0.3)
end
for _ = 1, 12 do Advance(1) end
local history = table.concat(env.ns.announcer.history, ",")
check("pet backup contributes to multi-kills", history:find("double", 1, true) ~= nil, true)
check("pet backup contributes to killing sprees", history:find("spree5", 1, true) ~= nil, true)

PetSetup()
env.dead = true
PetTick() -- backup is pending; the real kill arrives before the confirmation timer
PartyKillBoth("Pet-1")
Advance(0.3)
check("pet backup: real pet PARTY_KILL wins", #env.ns.announcer.feedEntries, 1)
check("pet backup: real pet PARTY_KILL still pops", Visible(), "ko")

PetSetup()
env.dead = true
PetTick()
PartyKillBoth("Player-2")
Advance(0.3)
check("pet backup: reported groupmate kill suppresses pet estimate", Visible(), "none")
check("pet backup: groupmate remains the feed killer", env.ns.announcer.feedEntries[1].args[1], "Bob")

PetSetup()
env.ns.Set("killEvent", false)
PetTick()
PetDeath()
check("pet backup works with both original detection switches off", Visible(), "ko")

PetSetup()
env.dead = true
PetTick()
env.ns.Set("killPetBackup", false)
Advance(0.3)
check("pet backup: toggle off cancels pending death", Visible(), "none")
check("pet backup: toggle off stops polling", _G.KapowPetKillWatcher.scripts.OnUpdate, nil)

PetSetup()
env.ns.Set("killPet", false)
PetDeath()
check("pet backup respects pet kills disabled", Visible(), "none")

PetSetup()
env.ns.Set("enabled", false)
PetDeath()
check("pet backup respects addon disabled", Visible(), "none")
check("pet backup: addon disabled stops polling", _G.KapowPetKillWatcher.scripts.OnUpdate, nil)

PetSetup()
env.dead = true
PetTick()
env.guids.target = "Creature-9"
env.driver:Fire("PLAYER_TARGET_CHANGED")
Advance(0.3)
check("pet backup: changing target cancels pending kill", Visible(), "none")

PetSetup()
env.guids.target = "Creature-9"
env.dead = true
PetTick()
Advance(0.3)
check("pet backup: selecting an already dead target does not count", Visible(), "none")

PetSetup()
env.petTarget = false
Advance(0.8)
PetDeath()
check("pet backup: stale pet activity does not count", Visible(), "none")

PetSetup()
env.petTarget = false -- pettarget often clears at the instant of death
PetDeath()
check("pet backup: recently lost pettarget still counts", Visible(), "ko")

PetSetup()
env.ns.Set("killPetBackup", true) -- reset the observation
env.petCombat = false
PetTick()
PetDeath()
check("pet backup: idle pet target does not count", Visible(), "none")

PetSetup()
env.ns.Set("killPetBackup", true)
env.guids.pet = nil
PetTick()
PetDeath()
check("pet backup: no pet does not count", Visible(), "none")

PetSetup()
env.ns.Set("killPetBackup", true)
env.petTarget = Secret(true)
PetTick()
PetDeath()
check("pet backup: secret pettarget comparison is not read", Visible(), "none")

PetSetup()
env.ns.Set("killPetBackup", true)
_G.UnitIsUnit = function() error("unit comparison restricted") end
PetTick()
PetDeath()
check("pet backup: restricted unit comparison does not error or count", Visible(), "none")

PetSetup()
env.ns.Set("killPetBackup", true)
env.petCombat = Secret(true)
PetTick()
PetDeath()
check("pet backup: secret pet combat state does not count", Visible(), "none")

PetSetup()
env.dead = Secret(true)
PetTick()
Advance(0.3)
check("pet backup: secret death state does not award a kill", Visible(), "none")

-- Hidden target identity: the selection itself identifies the target, timing deduplicates.
PetSetup()
env.guids.target = Secret("Creature-1")
PetTick()
PetDeath()
check("pet backup: works when the target's GUID is hidden", Visible(), "ko")
check("pet backup: hidden-GUID kill reaches the feed", #env.ns.announcer.feedEntries, 1)
for _, frame in ipairs(env.frames) do
	frame:Fire("PARTY_KILL", "Pet-1", Secret("Creature-1"))
end
Advance(0.6)
check("pet backup: late pet report with a hidden victim does not double the feed", #env.ns.announcer.feedEntries, 1)

PetSetup()
env.dead = true
for _, frame in ipairs(env.frames) do
	frame:Fire("PARTY_KILL", "Pet-1", Secret("Creature-1"))
end
local popsBefore = #env.ns.announcer.feedEntries
PetTick()
Advance(0.3)
check("pet backup: a hidden-victim pet report just before the death wins (one feed line)", #env.ns.announcer.feedEntries, popsBefore)

PetSetup()
env.dead = true
for _, frame in ipairs(env.frames) do
	frame:Fire("PARTY_KILL", "Player-2", Secret("Creature-1"))
end
PetTick()
Advance(0.3)
check("pet backup: a hidden-victim groupmate report near the death suppresses the estimate", Visible(), "none")

-- Changing target right after a crit keeps the crit pop (the backup used to drop it).
PetSetup()
Fade()
env.info = { 1234, 0, true }
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE_CRIT")
env.guids.target = "Creature-9"
env.driver:Fire("PLAYER_TARGET_CHANGED")
Advance(0.2)
check("pet backup: a crit still pops when you change target right after it", Visible(), "pow")

-- A player-attributed hit can already have a pending death-check pop. Only one source wins.
PetSetup()
env.ns.Set("killUnitDead", true)
env.info = { 1234, 0, false }
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE")
PetDeath()
Advance(0.1)
check("pet backup: pending hit still yields one kill feed entry", #env.ns.announcer.feedEntries, 1)
check("pet backup: pending hit yields a kill frame", Visible(), "ko")

PetSetup(false)
PetDeath()
check("pet backup: legacy client API path also shows K.O.", Visible(), "ko")

-- ── Hit sounds (Experimental tab) ──────────────────────────────────────────────────────
-- Sound cannot follow the secret alpha gates, so it plays only when the hit type is plain.
Load(true)
env.ns.SetEvent("crit", "sound", "raidwarning")
local soundsBefore = env.sounds
env.ns.Test("pow")
check("hit sounds: off by default, a crit stays silent", env.sounds - soundsBefore, 0)
env.ns.Set("hitSounds", true)
soundsBefore = env.sounds
env.ns.Test("hit")
check("hit sounds: a plain non-crit hit does not play the crit sound", env.sounds - soundsBefore, 0)
soundsBefore = env.sounds
env.ns.Test("pow")
check("hit sounds: a plain crit plays its sound once", env.sounds - soundsBefore, 1)
env.ns.SetEvent("kill", "sound", "raidwarning")
env.ns.SetEvent("critkill", "sound", "raidwarning")
soundsBefore = env.sounds
env.ns.Test("overkill")
check("hit sounds: a plain crit kill plays only its own sound", env.sounds - soundsBefore, 1)
soundsBefore = env.sounds
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false))
check("hit sounds: a hidden hit type stays silent", env.sounds - soundsBefore, 0)
env.ns.Set("hitSoundsSecret", true)
soundsBefore = env.sounds
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false))
check("hit sounds: 'also when hidden' plays every hit event's sound", env.sounds - soundsBefore, 3)

-- ── Import keeps flat settings in range ────────────────────────────────────────────────
Load(true)
local function HexOf(text)
	return (text:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
local function WithNumber(text, key, n)
	return (text:gsub("(S" .. HexOf(key) .. ";)N[^;]*;", "%1N" .. n .. ";"))
end
local function WithText(text, key, v)
	return (text:gsub("(S" .. HexOf(key) .. ";)S[^;]*;", "%1S" .. HexOf(v) .. ";"))
end
local badExport = WithText(WithNumber(WithNumber(env.ns.profiles:Export("Default"), "scale", "0"), "killDelay", "1e999"), "attribution", "bogus")
local badNames = env.ns.profiles:Import(badExport, "Bad")
local badProfile = _G.KapowDB.profiles[badNames[1]]
check("import clamps a zero scale", badProfile.scale, 0.3)
check("import clamps an endless kill delay", badProfile.killDelay, 1)
check("import rejects an unknown attribution", badProfile.attribution, "recent")

-- ── More kill sources and Accurate attribution (Detect.lua, Attribution.lua) ──────────
local function FireAll(event, ...)
	for _, frame in ipairs(env.frames) do
		frame:Fire(event, ...)
	end
end

local function MyActionsLog()
	_G.QUICKBUTTON_NAME_MY_ACTIONS = "My actions"
	_G.Blizzard_CombatLog_Filters = { currentFilter = 1, filters = { { name = "My actions" } } }
	env.logOn = false
	_G.C_CombatLog = {
		AreFilteredEventsEnabled = function() return env.logOn end,
		SetFilteredEventsEnabled = function(on) env.logOn = on end,
	}
end

-- Combat log colour: your white kill line.
Load(true)
MyActionsLog()
env.ns.Set("killUnitDead", false)
env.ns.Set("killLogLine", true)
check("log line: turns the combat log's event feed on", env.logOn, true)
Fade()
FireAll("COMBAT_LOG_MESSAGE", "x", 1, 1, 1, 0)
Advance(0.3)
check("log line: a white line before any grey one is not trusted", Visible(), "none")
FireAll("COMBAT_LOG_MESSAGE", "x", 0.7, 0.7, 0.7, 0)
FireAll("COMBAT_LOG_MESSAGE", "x", 1, 1, 1, 0)
Advance(0.3)
check("log line: your white kill line shows K.O.", Visible(), "ko")
local feedAfterLine = #env.ns.announcer.feedEntries
check("log line: the kill reaches the feed as yours", env.ns.announcer.feedEntries[1].args[1]:find("You", 1, true) ~= nil, true)
FireAll("PARTY_KILL", "Player-1", Secret("Creature-1"))
Advance(0.3)
check("log line: the same kill's PARTY_KILL is not counted again", #env.ns.announcer.feedEntries, feedAfterLine)
env.now = env.now + 5
_G.Blizzard_CombatLog_Filters.filters[1].name = "Everything"
Fade()
FireAll("COMBAT_LOG_MESSAGE", "x", 1, 1, 1, 0)
Advance(0.3)
check("log line: ignored when the filter is not My actions", Visible(), "none")
env.ns.Set("killLogLine", false)
check("log line: turning it off hands the event feed back", env.logOn, false)

-- Target death event.
Load(true)
env.ns.Set("killUnitDead", false)
env.ns.Set("killTargetDied", true)
Fade()
env.info = { 1234, 0, false }
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE")
FireAll("PLAYER_TARGET_DIED")
Advance(0.2)
check("target died: the hit that killed shows K.O.", Visible(), "ko")
env.now = env.now + 5
Fade()
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE_CRIT")
FireAll("PLAYER_TARGET_DIED")
env.driver:Fire("PLAYER_TARGET_CHANGED")
Advance(0.2)
check("target died: still right after you switch target", Visible(), "overkill")
env.now = env.now + 5
Fade()
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE")
Advance(0.2)
check("target died: no event, no kill", Visible(), "none")

-- Accurate attribution.
local function Wound(flag, school, cast)
	Fade()
	if cast then
		env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", cast)
	end
	env.driver:Fire("UNIT_COMBAT", "target", "WOUND", flag or "", 1234, school)
	Advance(0.2)
	return Visible()
end
Load(true)
env.ns.Set("killUnitDead", false)
env.ns.Set("attribution", "accurate")
check("accurate: listens for your weapon swings", env.driver.events.PLAYER_SWING, true)
env.now = env.now + 5
check("accurate: a hit nothing of yours explains is someone else's", Wound("CRITICAL", 4), "none")
env.now = env.now + 5
check("accurate: a crit right after your cast is yours", Wound("CRITICAL", 4, 133), "pow")
env.now = env.now + 0.5
check("accurate: that cast is spent; the next fire hit is not yours", Wound("CRITICAL", 4), "none")
env.now = env.now + 5
check("accurate: a cast of a spell known as Fire does not take a Frost hit", Wound("CRITICAL", 16, 133), "none")
env.now = env.now + 5
env.driver:Fire("PLAYER_SWING", 2.0, 0)
env.now = env.now + 0.45
check("accurate: a physical crit 0.45 s after your swing is yours", Wound("CRITICAL", 1), "pow")
env.now = env.now + 5
env.petTarget, env.petCombat = true, true
check("accurate: a physical hit while your pet attacks counts (pet kills on)", Wound("CRITICAL", 1), "pow")
env.now = env.now + 0.3
check("accurate: the pet takes at most one hit a second", Wound("CRITICAL", 1), "none")
env.petTarget = false
env.now = env.now + 5
Fade()
env.info = { 1234, 0, true }
-- Two casts, then one hit reported by both feeds: only one cast may be spent, so a second
-- hit 0.5 s later still finds the other cast.
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 133)
env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 133)
env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE_CRIT")
env.driver:Fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 1234, 4)
Advance(0.2)
check("accurate: one hit from both feeds pops once", Visible(), "pow")
env.now = env.now + 0.5
check("accurate: one hit from both feeds spends one cast", Wound("CRITICAL", 4), "pow")

-- Combat text unit: leave it alone.
Load(true)
env.activeUnit = nil
env.ns.Set("feedUnit", "leave")
env.activeUnit = nil
env.driver:Fire("PLAYER_TARGET_CHANGED")
check("feed leave: KAPOW never sets the combat text unit", env.activeUnit, nil)
check("feed leave: the shared combat text feed is not read", env.driver.events.COMBAT_TEXT_UPDATE, nil)
check("feed leave: your target's own combat events still are", env.driver.events.UNIT_COMBAT, true)
check("feed leave: hits still pop", UnitCombat("WOUND", "CRITICAL", 4321), "pow")

-- Damage meter: overkill on OVERKILL! and confirmed interrupts.
Load(true)
env.resets = 0
_G.C_DamageMeter = {
	IsDamageMeterAvailable = function() return true end,
	GetCombatSessionSourceFromType = function() return { combatSpells = { { overkillAmount = Secret(4321) } } } end,
	ResetAllCombatSessions = function() env.resets = env.resets + 1 end,
}
env.ns.Set("meterOverkill", true)
FireAll("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
check("meter: the overkill read clears the meter", env.resets, 1)
Fade()
env.ns.Test("overkill")
check("meter: OVERKILL! shows the overkill (drawn, never read)", tostring(LabelOf("overkill")):find("+<S:4.3K> overkill", 1, true) ~= nil, true)
env.now = env.now + 5
Fade()
env.ns.Test("overkill")
check("meter: a stale overkill is not shown", LabelOf("overkill"), "987.7K")

Load(true)
_G.C_DamageMeter = { IsDamageMeterAvailable = function() return true end }
env.ns.Set("meterInterrupts", true)
local banners = #env.ns.announcer.history
FireAll("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1766)
FireAll("DAMAGE_METER_COMBAT_SESSION_UPDATED", 5, 1)
check("meter: an interrupt count change after your Kick shows You interrupted", env.ns.announcer.history[banners + 1], "interrupt")
FireAll("DAMAGE_METER_COMBAT_SESSION_UPDATED", 5, 1)
check("meter: one Kick, one banner", env.ns.announcer.history[banners + 2], nil)

-- Interrupt streaks grow.
Advance(2)
local streakScale
env.ns.announcer.stage.root.SetScale = function(_, s) streakScale = s end
env.now = env.now + 1
FireAll("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1766)
FireAll("DAMAGE_METER_COMBAT_SESSION_UPDATED", 5, 1)
check("streak: the second interrupt in a row pops bigger", streakScale ~= nil and streakScale > 1.15 and streakScale < 1.25, true)
env.driver:Fire("PLAYER_REGEN_ENABLED")
FireAll("PLAYER_REGEN_ENABLED")
Advance(2)
env.now = env.now + 1
FireAll("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1766)
FireAll("DAMAGE_METER_COMBAT_SESSION_UPDATED", 5, 1)
check("streak: a new fight starts small again", streakScale, 1)

-- Kill statistic.
Load(true)
env.statValue = 10
_G.GetStatisticsCategoryList = function() return { 100 } end
_G.GetCategoryNumAchievements = function() return 1 end
_G.GetStatistic = function() return tostring(env.statValue), false, 555 end
_G.GetAchievementInfo = function() return 555, "Total kills" end
local chatBeforeStats = #env.chat
_G.SlashCmdList.KAPOW("stats")
check("/kapow stats lists kill statistics with their number", (env.chat[chatBeforeStats + 1] or ""):find("555", 1, true) ~= nil, true)
env.ns.Set("killUnitDead", false)
env.ns.Set("killStatId", 555)
env.ns.Set("killStatistic", true)
Fade()
env.statValue = 11
FireAll("CRITERIA_UPDATE")
Advance(0.3)
check("statistic: the counter going up shows your kill", Visible(), "ko")
env.now = env.now + 5
Fade()
FireAll("CRITERIA_UPDATE")
Advance(0.3)
check("statistic: no change, no kill", Visible(), "none")

-- ── Animation settings: duration, jitter amounts, stacked banners ─────────────────────
Load(true)
env.ns.SetEvent("crit", "duration", 2)
Fade()
env.ns.Test("pow")
Advance(1.2)
check("duration 2x: a crit pop is still up after its normal second", _G.KapowFrame_pow.shown, true)
Advance(1.0)
check("duration 2x: and gone after two seconds", _G.KapowFrame_pow.shown, false)

env.ns.Set("jitterX", 0)
env.ns.Set("jitterY", 0)
env.ns.Set("jitterTilt", 0)
local jx, jy, jt = env.ns.Jitter()
check("jitter set to zero gives no offset or tilt", jx == 0 and jy == 0 and jt == 0, true)
env.ns.Set("jitterX", 50)
local inRange = true
for _ = 1, 200 do
	local x = env.ns.Jitter()
	if x < -50 or x > 50 then inRange = false end
end
check("jitter stays within the chosen sideways offset", inRange, true)
env.ns.Set("jitter", false)
env.ns.Set("jitterX", 140)
jx = env.ns.Jitter()
check("jitter off gives no offset whatever the amount", jx, 0)

Load(true)
env.ns.Set("annFirstBloodSolo", true)
env.ns.announcer:Fire("firstblood", { killer = "You", victim = "Hogger" })
env.ns.announcer:Fire("double", { count = 2 })
check("one banner at a time by default (no second banner frame)", _G.KapowBanner2, nil)
Load(true)
env.ns.Set("annStack", true)
env.ns.announcer:Fire("firstblood", { killer = "You", victim = "Hogger" })
env.ns.announcer:Fire("double", { count = 2 })
check("several at once: two banners show together", _G.KapowBanner.shown and _G.KapowBanner2 ~= nil and _G.KapowBanner2.shown, true)
Advance(2)
check("several at once: both clear after their time", _G.KapowBanner.shown or _G.KapowBanner2.shown, false)

Load(true)
local longExport = env.ns.profiles:Export("Default"):gsub("(S" .. ("duration"):gsub(".", function(c) return ("%02x"):format(c:byte()) end) .. ";)N[^;]*;", "%1N99;")
local longNames = env.ns.profiles:Import(longExport, "Long")
check("import clamps an event duration", _G.KapowDB.profiles[longNames[1]].events.crit.duration, 4)

-- ── Sound pools (game sounds now, generated files later) ───────────────────────────────
Load(true)
env.ns.SetEvent("kickoff", "enabled", true)
check("fight start defaults to the random fight-start pool", env.ns.db.events.kickoff.sound, "random:fightstart")
local poolBefore = env.sounds
env.driver:Fire("PLAYER_REGEN_DISABLED")
FireAll("PLAYER_REGEN_DISABLED")
check("random pool: a fight start plays exactly one sound", env.sounds - poolBefore, 1)
env.playedFiles = {}
_G.PlaySoundFile = function(path) env.playedFiles[#env.playedFiles + 1] = path return true end
env.ns.display.SOUNDS["random:test"] = { "Test", pool = { "Interface\\AddOns\\Kapow\\Sounds\\test\\a.ogg" } }
env.ns.SetEvent("kickoff", "sound", "random:test")
Advance(2)
FireAll("PLAYER_REGEN_DISABLED")
check("random pool: a generated file plays through PlaySoundFile", env.playedFiles[1], "Interface\\AddOns\\Kapow\\Sounds\\test\\a.ogg")
env.ns.display.SOUNDS["random:missing"] = { "Missing", pool = { "NO_SUCH_KIT", "ALSO_MISSING" } }
env.ns.SetEvent("kickoff", "sound", "random:missing")
Advance(2)
poolBefore = env.sounds
FireAll("PLAYER_REGEN_DISABLED")
check("random pool: kits this client lacks are skipped quietly", env.sounds - poolBefore, 0)
_G.PlaySoundFile = nil

-- ── UwU mode and the multi-kill timer bar ─────────────────────────────────────────────
Load(true)
env.ns.Test("pow")
check("uwu off: no UwU frame is made", _G.KapowUwU, nil)
env.ns.Set("uwu", true)
env.ns.Test("pow")
check("uwu on: a crit shows the UwU frame", _G.KapowUwU ~= nil and _G.KapowUwU.shown, true)
local function UwuAlpha()
	for _, f in ipairs(env.frames) do
		if f.parent == _G.KapowUwU then
			return f.alpha
		end
	end
end
check("uwu on: a crit opens its gate", UwuAlpha(), 1)
env.ns.Test("hit")
check("uwu on: a plain non-crit keeps its gate shut", UwuAlpha(), 0)
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false))
check("uwu on: a secret crit still opens the gate (the client decides)", UwuAlpha(), 1)
env.ns.Set("uwuSound", "raidwarning")
local uwuSounds = env.sounds
env.ns.Test("pow")
check("uwu sound: plays on a plain crit", env.sounds - uwuSounds, 1)
uwuSounds = env.sounds
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false))
check("uwu sound: not on a hidden crit (cannot be gated)", env.sounds - uwuSounds, 0)

Load(true)
env.ns.Set("annFirstBloodSolo", true)
FireAll("PARTY_KILL", "Player-1", "Creature-1")
check("timer bar off: none after a kill", _G.KapowStreakBar, nil)
env.ns.Set("annStreakBar", true)
env.now = env.now + 10
FireAll("PARTY_KILL", "Player-1", "Creature-2")
check("timer bar on: shows after your kill", _G.KapowStreakBar ~= nil and _G.KapowStreakBar.shown, true)
env.now = env.now + 1
FireAll("PARTY_KILL", "Player-1", "Creature-3")
check("timer bar: counts the chain", _G.KapowStreakBar.label.text, "x2")
env.now = env.now + 5
_G.KapowStreakBar.scripts.OnUpdate(_G.KapowStreakBar, 0.1)
check("timer bar: hides when the window runs out", _G.KapowStreakBar.shown, false)

-- ── Extras.lua and Moments.lua ────────────────────────────────────────────────────────
local NEW_EVENTS = { "combo", "countdown", "countgo", "duelstart", "duelwin", "duellose", "bosspull",
	"assist", "record", "achievement", "epicloot", "quest", "honorkill" }
local function Has(list, id)
	for _, v in ipairs(list) do
		if v == id then
			return true
		end
	end
	return false
end
local function Shown(id, from)
	for i = (from or 1), #env.ns.announcer.history do
		if env.ns.announcer.history[i] == id then
			return true
		end
	end
	return false
end

Load(true)
local allOff = true
for _, id in ipairs(NEW_EVENTS) do
	if env.ns.db.events[id].enabled then
		allOff = false
	end
end
check("extras: every new event starts off", allOff, true)
check("extras: combo counter, flash, overlays and sync start off",
	tostring(env.ns.db.comboCounter) .. env.ns.db.flash .. tostring(env.ns.db.dangerLow) .. tostring(env.ns.db.finishIt)
		.. tostring(env.ns.db.partySync) .. tostring(env.ns.db.gamepadNav),
	"falseofffalsefalsefalsefalse")
env.ns.Set("annFirstBloodSolo", true)
for _ = 1, 6 do
	Hit("DAMAGE_CRIT", nil, false)
end
FireAll("PARTY_KILL", "Player-1", "Creature-1")
Advance(10)
local leaked = false
for _, id in ipairs(env.ns.announcer.history) do
	if Has(NEW_EVENTS, id) then
		leaked = true
	end
end
check("extras: defaults add no banner to an ordinary fight", leaked, false)
check("extras: defaults make no combo, flash or warning frames",
	tostring(_G.KapowCombo) .. tostring(_G.KapowFlash) .. tostring(_G.KapowDanger) .. tostring(_G.KapowFinish), "nilnilnilnil")
check("extras: the banner spot stays where it was", select(2, env.ns.display.Offset("banner")), 260)

-- Combo counter
local function QuickHit()
	env.now = env.now + 0.5
	env.dead = false
	env.info = { 1234, 0, false }
	env.driver:Fire("UNIT_SPELLCAST_SUCCEEDED", "player")
	env.driver:Fire("COMBAT_TEXT_UPDATE", "DAMAGE")
	Advance(0.2)
end
Load(true)
env.ns.Set("comboCounter", true)
env.ns.SetEvent("combo", "enabled", true)
for _ = 1, 6 do
	QuickHit()
end
check("combo: the counter shows while hits keep coming", _G.KapowCombo and _G.KapowCombo.shown, true)
check("combo: it counts the hits", _G.KapowCombo.count.text, 6)
env.now = env.now + 3
_G.KapowCombo.scripts.OnUpdate(_G.KapowCombo, 0.1)
Advance(5)
check("combo: a 2 s gap ends the chain and hides the counter", _G.KapowCombo.shown, false)
check("combo: a chain of 6 shows the Combo banner", Shown("combo"), true)
check("combo: the best combo is saved for the character", env.ns.char.records.combo, 6)
local before = #env.ns.announcer.history
for _ = 1, 3 do
	QuickHit()
end
env.now = env.now + 3
_G.KapowCombo.scripts.OnUpdate(_G.KapowCombo, 0.1)
Advance(5)
check("combo: 3 hits stay under the minimum, no banner", Shown("combo", before + 1), false)
QuickHit()
QuickHit()
check("combo: a fresh chain counts from the start", _G.KapowCombo.count.text, 2)
env.guids.target = "Creature-9"
QuickHit()
check("combo: a new target ends the chain", _G.KapowCombo.shown, false)
env.guids.target = "Creature-1"

-- Impact flash
Load(true)
env.ns.Set("flash", "critkill")
local function FlashGates()
	local f = _G.KapowFlash
	local crit, dead
	for _, fr in ipairs(env.frames) do
		if fr.parent == f then
			crit = fr
		end
	end
	for _, fr in ipairs(env.frames) do
		if fr.parent == crit then
			dead = fr
		end
	end
	return crit.alpha * dead.alpha
end
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(true))
check("flash: a hidden crit kill lights the flash (the client decides)", _G.KapowFlash.shown and FlashGates(), 1)
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false))
check("flash crit kills: a crit that does not kill stays dark", FlashGates(), 0)
env.ns.Set("flash", "crit")
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false))
check("flash every crit: any crit lights it", FlashGates(), 1)
env.ns.Set("reduceMotion", true)
_G.KapowFlash.shown = false
Hit("DAMAGE_CRIT", nil, false)
check("reduce motion: no flash", _G.KapowFlash.shown, false)
env.ns.Set("jitter", true)
local jx, jy, jt = env.ns.Jitter()
check("reduce motion: no random offset or tilt", jx + jy + jt, 0)

-- Hidden health: low health and FINISH IT!
local function CurveMocks()
	_G.Enum.LuaCurveType = { Linear = 0, Step = 1 }
	_G.C_CurveUtil = {
		CreateCurve = function()
			local c = { points = {} }
			function c:SetType(t)
				self.type = t
			end
			function c:AddPoint(x, y)
				self.points[#self.points + 1] = { x, y }
			end
			return c
		end,
	}
	-- The client evaluates the curve on the hidden health and hands back a secret.
	_G.UnitHealthPercent = function(unit, _, curve)
		local share = env.share[unit]
		local y = 0
		for _, p in ipairs(curve.points) do
			if share >= p[1] then
				y = p[2]
			end
		end
		return Secret(y)
	end
end
local function GateOf(root)
	for _, fr in ipairs(env.frames) do
		if fr.parent == root then
			return fr
		end
	end
end
Load(true)
env.secretAlphaOK = true
CurveMocks()
env.share = { player = 0.2, target = 0.5 }
env.ns.Set("dangerLow", true)
check("low health: the overlay registers for player health", env.frames[#env.frames] ~= nil and _G.KapowDanger ~= nil, true)
check("low health: 20% at a 25% threshold opens the gate (secret, client-side)", tostring(GateOf(_G.KapowDanger).alpha), "<S:1>")
env.share.player = 0.8
FireAll("UNIT_HEALTH", "player")
check("low health: 80% shuts it", tostring(GateOf(_G.KapowDanger).alpha), "<S:0>")
env.share.player = 0.25
FireAll("UNIT_HEALTH", "player")
check("low health: exactly at the threshold counts", tostring(GateOf(_G.KapowDanger).alpha), "<S:1>")
env.deadUnits.player = true
FireAll("PLAYER_DEAD")
check("low health: hidden while you are dead", _G.KapowDanger.shown, false)
env.deadUnits.player = nil

_G.UnitCanAttack = function()
	return true
end
env.ns.Set("finishIt", true)
FireAll("PLAYER_TARGET_CHANGED")
check("finish it: 50% target stays dark", tostring(GateOf(_G.KapowFinish).alpha), "<S:0>")
env.share.target = 0.15
FireAll("UNIT_HEALTH", "target")
check("finish it: 15% target at 20% shows FINISH IT!", tostring(GateOf(_G.KapowFinish).alpha), "<S:1>")
env.dead = Secret(true)
FireAll("UNIT_HEALTH", "target")
check("finish it: a hidden death flag hides it (no corpse prompt)", _G.KapowFinish.shown, false)
env.dead = false
_G.UnitCanAttack = function()
	return false
end
FireAll("PLAYER_TARGET_CHANGED")
check("finish it: a friendly target never shows it", _G.KapowFinish.shown, false)
_G.UnitCanAttack = nil
env.ns.Set("finishIt", false)
env.ns.Set("dangerLow", false)
check("overlays off: both hide", tostring(_G.KapowDanger.shown) .. tostring(_G.KapowFinish.shown), "falsefalse")

-- Without curves: a plain health reading, nothing when it is secret.
Load(true)
_G.C_CurveUtil, _G.UnitHealthPercent = nil, nil
env.health, env.healthMax = 20, 100
env.ns.Set("dangerLow", true)
check("no curves: plain 20% opens the gate", GateOf(_G.KapowDanger).alpha, 1)
env.health = 60
FireAll("UNIT_HEALTH", "player")
check("no curves: plain 60% shuts it", GateOf(_G.KapowDanger).alpha, 0)
env.health = Secret(10)
FireAll("UNIT_HEALTH", "player")
check("no curves: secret health is never compared, the gate stays shut", GateOf(_G.KapowDanger).alpha, 0)
env.health, env.healthMax = nil, nil

-- Placing
Load(true)
env.ns.Set("bannerX", 120)
env.ns.Set("bannerY", 300)
local bx, by = env.ns.display.Offset("banner")
check("placing: banners follow the saved spot", bx .. "," .. by, "120,300")
env.ns.extras.SetUnlocked(true)
local handle = _G.KapowPlace_combo
check("placing: unlock shows a handle per movable thing", handle ~= nil and handle.shown and _G.KapowPlace_finish.shown, true)
handle.cx, handle.cy = -50, 75
_G.UIParent.cx, _G.UIParent.cy = 0, 0
handle.scripts.OnDragStop(handle)
check("placing: dropping a handle saves its offset", env.ns.db.comboX .. "," .. env.ns.db.comboY, "-50,75")
_G.SlashCmdList.KAPOW("lock")
check("placing: /kapow lock hides the handles", handle.shown, false)
env.ns.extras.ResetPlaces()
check("placing: reset puts everything back", env.ns.db.bannerX .. "," .. env.ns.db.bannerY .. "," .. env.ns.db.comboX, "0,260,-300")

-- Moments: format patterns
local M = env.ns.moments
local pat, order = M.Pattern("%2$s has fled from %1$s in a duel")
local args = M.Match("Bob has fled from Alice in a duel", { pat, order })
check("pattern: positional arguments land in format order", args[1] .. "/" .. args[2], "Alice/Bob")
args = M.Match("You receive loot: [Thing]x3", { M.Pattern("You receive loot: %sx%d") })
check("pattern: %s and %d", args[1] .. "/" .. args[2], "[Thing]/3")
check("pattern: magic characters are literal", M.Match("Gold (5)", { M.Pattern("Gold (%d)") })[1], "5")
check("pattern: no match gives nil", M.Match("something else", { M.Pattern("Duel starting: %d") }), nil)

-- Duels
Load(true)
_G.DUEL_COUNTDOWN = "Duel starting: %d"
_G.DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
_G.DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
env.names.player = "Me"
for _, id in ipairs({ "countdown", "duelstart", "duelwin", "duellose" }) do
	env.ns.SetEvent(id, "enabled", true)
end
env.ns.Set("annStack", true)
FireAll("DUEL_REQUESTED", "Bob-Realm")
for n = 3, 1, -1 do
	FireAll("CHAT_MSG_SYSTEM", "Duel starting: " .. n)
	Advance(1)
end
Advance(5)
check("duel: the countdown lines show 3, 2, 1", #env.ns.announcer.history >= 3 and env.ns.announcer.history[1], "countdown")
check("duel: then ROUND 1 ... FIGHT!", Shown("duelstart"), true)
FireAll("CHAT_MSG_SYSTEM", "Me has defeated Bob in a duel")
Advance(5)
check("duel: a knockout by you shows YOU WIN", Shown("duelwin"), true)
check("duel: the win is tallied", env.ns.char.records.total_duelwins, 1)
FireAll("CHAT_MSG_SYSTEM", "Me has fled from Bob in a duel")
Advance(5)
check("duel: fleeing shows YOU LOSE", Shown("duellose"), true)
before = #env.ns.announcer.history
FireAll("CHAT_MSG_SYSTEM", Secret("Me has defeated Bob in a duel"))
FireAll("CHAT_MSG_SYSTEM", "Alice has defeated Bob in a duel")
Advance(5)
check("duel: secret lines and other people's duels are ignored", #env.ns.announcer.history, before)

-- Countdowns
Load(true)
env.ns.SetEvent("countdown", "enabled", true)
env.ns.SetEvent("countgo", "enabled", true)
env.ns.Set("annStack", true)
FireAll("START_TIMER", 0, 5, 10)
Advance(1.5)
check("countdown: nothing before the last three seconds", #env.ns.announcer.history, 0)
Advance(4)
Advance(2)
local seq = table.concat(env.ns.announcer.history, ",")
check("countdown: 3, 2, 1, FIGHT! in step with the timer", seq, "countdown,countdown,countdown,countgo")
Load(true)
env.ns.SetEvent("countgo", "enabled", true)
FireAll("START_TIMER", 0, 5, 10)
Advance(1)
FireAll("STOP_TIMER_OF_TYPE", 0)
Advance(10)
check("countdown: a stopped timer says nothing", #env.ns.announcer.history, 0)

-- Loot, achievements, quests, honorable kills, boss pull
Load(true)
_G.LOOT_ITEM_SELF = "You receive loot: %s"
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d"
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s"
_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d"
for _, id in ipairs({ "epicloot", "achievement", "quest", "honorkill", "bosspull" }) do
	env.ns.SetEvent(id, "enabled", true)
end
env.ns.Set("annStack", true)
FireAll("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:1::|h[Big Axe]|h|r")
Advance(5)
check("loot: an epic of yours shows EPIC LOOT", Shown("epicloot"), true)
before = #env.ns.announcer.history
FireAll("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:2::|h[Green Thing]|h|r")
FireAll("CHAT_MSG_LOOT", "Bob receives loot: |cffa335ee|Hitem:1::|h[Big Axe]|h|r")
FireAll("CHAT_MSG_LOOT", Secret("You receive loot: |cffa335ee|Hitem:1::|h[Big Axe]|h|r"))
Advance(5)
check("loot: greens, other people's loot and secret lines are ignored", #env.ns.announcer.history, before)
_G.GetAchievementInfo = function(id)
	return id, "Explorer"
end
FireAll("ACHIEVEMENT_EARNED", 42, true)
Advance(5)
check("achievement: one already earned elsewhere is ignored", Shown("achievement"), false)
FireAll("ACHIEVEMENT_EARNED", 42, false)
Advance(5)
check("achievement: a new one shows", Shown("achievement"), true)
_G.C_QuestLog = { GetTitleForQuestID = function() return "Wolves" end }
FireAll("QUEST_TURNED_IN", 7, 0, 0)
Advance(5)
check("quest: turning one in shows QUEST COMPLETE", Shown("quest"), true)
local hk = 10
_G.GetPVPLifetimeStats = function()
	return hk
end
env.ns.SetEvent("honorkill", "enabled", false)
env.ns.SetEvent("honorkill", "enabled", true)
FireAll("PLAYER_PVP_KILLS_CHANGED", "player")
Advance(5)
check("honorable kill: no change, no banner", Shown("honorkill"), false)
hk = 11
FireAll("PLAYER_PVP_KILLS_CHANGED", "player")
Advance(5)
check("honorable kill: the lifetime count going up shows it", Shown("honorkill"), true)
FireAll("ENCOUNTER_START", 1, "Hogger", 1, 5)
Advance(5)
check("boss pull: ENCOUNTER_START shows ROUND 1 ... FIGHT!", Shown("bosspull"), true)

-- Records
Load(true)
env.ns.SetEvent("record", "enabled", true)
env.ns.Set("annStack", true)
M = env.ns.moments
M.CheckRecord("spree", 3)
M.CheckRecord("spree", 4)
Advance(5)
check("records: bests under the minimum are kept quietly", Shown("record"), false)
check("records: ...but saved", env.ns.char.records.spree, 4)
M.CheckRecord("spree", 5)
M.CheckRecord("spree", 6)
M.EndRun("spree")
M.CheckRecord("spree", 7)
Advance(5)
check("records: 5 over a best of 4 is quiet (4 is under the minimum)", env.ns.char.records.spree, 7)
local records = 0
for _, id in ipairs(env.ns.announcer.history) do
	if id == "record" then
		records = records + 1
	end
end
check("records: one banner per run, again after the run ends", records, 2)
_G.SlashCmdList.KAPOW("records reset")
check("records: /kapow records reset clears them", env.ns.char.records.spree, nil)

-- Assist
Load(true)
env.ns.SetEvent("assist", "enabled", true)
env.inGroup = true
Hit("DAMAGE", nil, false)
FireAll("PARTY_KILL", "Player-2", "Creature-1")
Advance(10)
check("assist: a groupmate's kill of what you hit shows ASSIST", Shown("assist"), true)
before = #env.ns.announcer.history
env.now = env.now + 20
FireAll("PARTY_KILL", "Player-2", "Creature-7")
Advance(10)
check("assist: not for something you never hit", Shown("assist", before + 1), false)

-- Party sync
Load(true)
env.inGroup = true
local sent = {}
_G.C_ChatInfo = {
	RegisterAddonMessagePrefix = function(p)
		env.prefix = p
		return true
	end,
	SendAddonMessage = function(prefix, text, channel)
		sent[#sent + 1] = prefix .. " " .. text .. " " .. channel
	end,
}
M = env.ns.moments
check("sync off: nothing is sent", M.Share("mega", 5), false)
env.ns.Set("partySync", true)
check("sync on: the prefix is registered", env.prefix, "KAPOW")
M.Share("mega", 5)
check("sync: a moment goes to the party as id and count", sent[1], "KAPOW 1|mega|5 PARTY")
M.Share("triple", 3)
check("sync: at most two a second", #sent, 1)
env.now = env.now + 1
M.Share("kill", 1)
check("sync: only shareable moments travel", #sent, 1)
env.names.player = "Me"
FireAll("CHAT_MSG_ADDON", "KAPOW", "1|mega|5", "PARTY", "Bob-Realm")
check("sync: a groupmate's moment lands in the kill feed", env.ns.announcer.feedEntries[1] ~= nil and env.ns.announcer.feedEntries[1].args[1], "Bob")
local feedCount = #env.ns.announcer.feedEntries
FireAll("CHAT_MSG_ADDON", "KAPOW", "1|mega|5", "PARTY", "Me-Realm")
FireAll("CHAT_MSG_ADDON", "KAPOW", "1|os.exit|5", "PARTY", "Bob")
FireAll("CHAT_MSG_ADDON", "KAPOW", Secret("1|mega|5"), "PARTY", "Bob")
FireAll("CHAT_MSG_ADDON", "OTHER", "1|mega|5", "PARTY", "Bob")
check("sync: own echoes, unknown ids, secret text and other prefixes are ignored", #env.ns.announcer.feedEntries, feedCount)
_G.C_ChatInfo = nil

-- Import clamps the new settings
Load(true)
local extrasExport = env.ns.profiles:Export("Default")
extrasExport = WithNumber(WithNumber(extrasExport, "comboMin", "0"), "bannerY", "1e999")
extrasExport = WithText(extrasExport, "flash", "strobe")
local extrasProfile = _G.KapowDB.profiles[env.ns.profiles:Import(extrasExport, "Extras")[1]]
check("import clamps the combo minimum", extrasProfile.comboMin, 2)
check("import clamps a place", extrasProfile.bannerY, 3000)
check("import rejects an unknown flash mode", extrasProfile.flash, "off")

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
