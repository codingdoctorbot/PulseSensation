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
-- In the client string.format("%s", secret) yields a secret string. Here it yields a marker
-- the assertions can recognise, proving the secret travelled to SetText untouched.
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
		"SetScale", "SetTexture", "SetRotation", "SetStatusBarTexture", "SetStatusBarColor",
		"SetClipsChildren", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
		"SetColorTexture",
	}) do
		r[m] = noop
	end
	function r:SetSize(w, h)
		self.w, self.h = w, h
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
		fs.SetFont, fs.SetTextColor, fs.SetShadowOffset = noop, noop, noop
		function fs:SetText(t)
			self.text = t
		end
		function fs:SetFormattedText(fmt, ...)
			self.text = string.format(fmt, ...)
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

local function Load(modern)
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
		function f:SetScript(n, fn)
			scripts[n] = fn
		end
		function f:Fire(e, ...)
			if events[e] and scripts.OnEvent then
				scripts.OnEvent(self, e, ...)
			end
		end
		f.events = events
		env.frames[#env.frames + 1] = f
		if name then
			_G[name] = f
		end
		return f
	end
	_G.UnitIsDead = function()
		return env.dead
	end
	_G.UnitHealth = function()
		return env.health
	end
	_G.UnitHealthMax = function()
		return env.healthMax
	end
	_G.Enum = modern and { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 } } or nil
	_G.C_Spell = { IsCurrentSpell = function() return false end }
	-- The client's abbreviator; this one refuses secrets, so the addon must fall back.
	_G.AbbreviateNumbers = modern
			and function(n)
				if isSecret(n) then
					refuse()
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
	_G.PulseComicDB = nil

	-- TOC order, one shared addon namespace, as the client does it.
	env.ns = {}
	for _, file in ipairs({ "PulseComic.lua", "Meter.lua" }) do
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
	env.info = { "x", amount, crit }
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
check("secret amount reaches SetText after abbreviator refuses it", LabelOf("pow"), "<S:98765>")
Hit(Secret("DAMAGE_CRIT"), Secret(true), Secret(false), nil, Secret("98765"))
check("secret string amount reaches SetText", LabelOf("pow"), "<S:98765>")
Hit("DAMAGE_CRIT", nil, false, nil, "missing")
check("missing amount gives an empty label", LabelOf("pow"), "")
_G.SlashCmdList.PULSECOMIC("numbers")
Hit("DAMAGE_CRIT", nil, false)
check("/comic numbers off clears the label", LabelOf("pow"), "")
_G.SlashCmdList.PULSECOMIC("numbers")
Hit("DAMAGE_CRIT", nil, false)
check("/comic numbers on restores it", LabelOf("pow"), "1.2K")

check("plain HEAL is ignored", Hit("HEAL", false, false), "none")
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
check("debug output reports the width probe", (env.chat[#env.chat] or ""):match("width=(%S+)") ~= nil, true)
local hiddenProbe = env.labels[#env.labels]
check("width probe is not one of the visible labels", LabelOf("pow") ~= hiddenProbe.text or hiddenProbe.text == nil, true)

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
	"isCrit", "isDead", "ret2", "ret3", "value", "amount", "width",
	"health", "healthNow", "healthPrior", "healthMax", "healthLast", "healthBefore", "source", "max",
}
local offenders = {}
for _, file in ipairs({ "PulseComic.lua", "Meter.lua" }) do
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
