-- KAPOW — Extras.lua
--
-- Optional extras around the pops, all off by default:
--
--   COMBO COUNTER   "12 HITS" (fighting-game style) while your hits on one target keep coming
--                   less than COMBO_GAP apart; when the chain ends with comboMin or more, the
--                   Combo banner (Events › Arcade). Hits are counted, never their amounts.
--   IMPACT FLASH    a short full-screen flash on a crit kill, any kill or any crit. The crit and
--                   death flags may be secret, so the flash sits under the same two alpha gates
--                   as the comic frames and the client decides whether it shows.
--   LOW HEALTH      red screen edges while your health is at or below dangerAt.
--   FINISH IT!      a prompt while your target's health is at or below finishAt.
--                   Health is secret in combat. Neither reads it: UnitHealthPercent evaluates a
--                   step curve (1 at or below the threshold, 0 above) inside the client, and the
--                   secret result goes straight to SetAlpha (SecretArguments AllowedWhenTainted),
--                   the way Blizzard maps health to colours. Without curves (older clients) a
--                   plain health reading is compared instead, and nothing shows when it is secret.
--   PLACING         an unlock mode with a handle per movable thing: drag, and the offset from
--                   the screen centre is saved.

local _, ns = ...

local issecretvalue = _G.issecretvalue or function()
	return false
end

local X = {}
ns.extras = X

local function Db()
	return ns.db
end

local function FontPath(key)
	local fonts = ns.display.FONTS
	local font = fonts[key] or fonts.friz
	return font[2]
end

local function SetFontSafe(fs, key, size)
	if not fs:SetFont(FontPath(key), size, "THICKOUTLINE") then
		fs:SetFont(ns.display.FONTS.friz[2], size, "THICKOUTLINE")
	end
end

local function PlainTrue(v)
	return not issecretvalue(v) and v == true
end

local function PlainFalse(v)
	return not issecretvalue(v) and v == false
end

-- ── Places ────────────────────────────────────────────────────────────────────────────

X.MOVABLE = {
	{ id = "hit", label = "Hit pops", xKey = "x", yKey = "y" },
	{ id = "banner", label = "Banners", xKey = "bannerX", yKey = "bannerY" },
	{ id = "bar", label = "Multi-kill bar", xKey = "barX", yKey = "barY" },
	{ id = "uwu", label = "UwU", xKey = "uwuX", yKey = "uwuY" },
	{ id = "combo", label = "Combo counter", xKey = "comboX", yKey = "comboY" },
	{ id = "finish", label = "FINISH IT!", xKey = "finishX", yKey = "finishY" },
}
local MOVABLE_BY_ID, PLACE_KEYS = {}, {}
for _, m in ipairs(X.MOVABLE) do
	MOVABLE_BY_ID[m.id] = m
	PLACE_KEYS[m.xKey], PLACE_KEYS[m.yKey] = true, true
end

local placed = {} -- id -> live frame that follows its saved place

function X.IsPlaceKey(key)
	return PLACE_KEYS[key] == true
end

function X.Place(id)
	local frame, m, db = placed[id], MOVABLE_BY_ID[id], Db()
	if frame and m and db then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", db[m.xKey] or 0, db[m.yKey] or 0)
	end
end

function X.PlaceAll()
	for id in pairs(placed) do
		X.Place(id)
	end
end

-- Frames that stay on screen register here so dragging moves them (hit pops and banners
-- read their place each time they show).
function X.Register(id, frame)
	placed[id] = frame
	X.Place(id)
end

-- Every place back to its default.
function X.ResetPlaces()
	local defaults = ns.DEFAULTS or {}
	for _, m in ipairs(X.MOVABLE) do
		if defaults[m.xKey] ~= nil then
			ns.Set(m.xKey, defaults[m.xKey])
			ns.Set(m.yKey, defaults[m.yKey])
		end
	end
	if X.unlocked then
		X.SetUnlocked(true)
	end
end

local handles = {}
X.unlocked = false

local function Handle(m)
	if handles[m.id] then
		return handles[m.id]
	end
	local h = CreateFrame("Frame", "KapowPlace_" .. m.id, UIParent)
	h:SetSize(170, 36)
	h:SetFrameStrata("DIALOG")
	h:SetMovable(true)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	local bg = h:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(h)
	bg:SetColorTexture(1, 0.84, 0.04, 0.35)
	local label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("CENTER", h, "CENTER", 0, 0)
	label:SetText(m.label)
	h:SetScript("OnDragStart", h.StartMoving)
	h:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local cx, cy = self:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if cx and ux then
			ns.Set(m.xKey, math.floor(cx - ux + 0.5))
			ns.Set(m.yKey, math.floor(cy - uy + 0.5))
		end
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", Db()[m.xKey], Db()[m.yKey])
	end)
	handles[m.id] = h
	return h
end

function X.SetUnlocked(on)
	X.unlocked = on and true or false
	local db = Db()
	for _, m in ipairs(X.MOVABLE) do
		local h = Handle(m)
		if X.unlocked then
			h:ClearAllPoints()
			h:SetPoint("CENTER", UIParent, "CENTER", db[m.xKey] or 0, db[m.yKey] or 0)
			h:Show()
		else
			h:Hide()
		end
	end
	if ns.Say then
		ns.Say(X.unlocked and "unlocked: drag the yellow boxes, then /kapow lock" or "locked")
	end
end

-- ── Combo counter ─────────────────────────────────────────────────────────────────────

local COMBO_GAP = 2.0
local comboCount, comboKey, comboLast = 0, nil, -100
local comboFrame

local function EnsureCombo()
	if comboFrame then
		return comboFrame
	end
	local f = CreateFrame("Frame", "KapowCombo", UIParent)
	f:SetSize(220, 70)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(false)
	f.count = f:CreateFontString(nil, "OVERLAY")
	SetFontSafe(f.count, "russo-one", 44)
	f.count:SetTextColor(1, 0.84, 0.04)
	f.count:SetPoint("CENTER", f, "CENTER", 0, 8)
	f.word = f:CreateFontString(nil, "OVERLAY")
	SetFontSafe(f.word, "russo-one", 20)
	f.word:SetTextColor(1, 0.4, 0.1)
	f.word:SetPoint("TOP", f.count, "BOTTOM", 0, -2)
	f.word:SetText("HITS")
	local pulse = f:CreateAnimationGroup()
	local up = pulse:CreateAnimation("Scale")
	if up.SetScaleFrom then
		up:SetScaleFrom(1.25, 1.25)
		up:SetScaleTo(1, 1)
	end
	up:SetDuration(0.12)
	f.pulse = pulse
	f:SetScript("OnUpdate", function()
		if GetTime() - comboLast > COMBO_GAP then
			X.EndCombo()
		end
	end)
	f:Hide()
	comboFrame = f
	X.Register("combo", f)
	return f
end

function X.EndCombo()
	local count = comboCount
	comboCount, comboKey = 0, nil
	if comboFrame then
		comboFrame:Hide()
	end
	local db = Db()
	if db and count >= (db.comboMin or 5) then
		if ns.announcer then
			ns.announcer:Fire("combo", { count = count })
		end
		if ns.moments then
			ns.moments.CheckRecord("combo", count)
			ns.moments.EndRun("combo")
			ns.moments.Share("combo", count)
		end
	end
end

-- A hit judged yours (Kapow.lua).
function X.OnMyHit(key, now)
	local db = Db()
	if not db or not db.comboCounter then
		return
	end
	if comboCount > 0 and (key ~= comboKey or now - comboLast > COMBO_GAP) then
		X.EndCombo()
	end
	comboCount, comboKey, comboLast = comboCount + 1, key, now
	if comboCount >= 2 then
		local f = EnsureCombo()
		f.count:SetText(comboCount)
		f:Show()
		if not db.reduceMotion then
			f.pulse:Stop()
			f.pulse:Play()
		end
	end
end

-- ── Impact flash ──────────────────────────────────────────────────────────────────────

local flash

local function EnsureFlash()
	if flash then
		return flash
	end
	local root = CreateFrame("Frame", "KapowFlash", UIParent)
	root:SetAllPoints(UIParent)
	root:SetFrameStrata("BACKGROUND")
	root:EnableMouse(false)
	root:Hide()
	local critGate = CreateFrame("Frame", nil, root)
	critGate:SetAllPoints(root)
	local deadGate = CreateFrame("Frame", nil, critGate)
	deadGate:SetAllPoints(critGate)
	local tex = deadGate:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(deadGate)
	tex:SetColorTexture(1, 1, 1, 1)
	if tex.SetBlendMode then
		tex:SetBlendMode("ADD")
	end
	local anim = root:CreateAnimationGroup()
	local fade = anim:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.45)
	fade:SetToAlpha(0)
	fade:SetDuration(0.3)
	anim:SetScript("OnFinished", function()
		root:Hide()
	end)
	flash = { root = root, critGate = critGate, deadGate = deadGate, tex = tex, anim = anim }
	return flash
end

local FLASH_COLORS = { critkill = { 1, 0.85, 0.4 }, kill = { 1, 0.25, 0.2 }, crit = { 1, 1, 1 } }

-- isCrit / isDead may be secret: they only reach the gates.
function X.Flash(isCrit, isDead)
	local db = Db()
	local mode = db.flash
	if mode == "off" or db.reduceMotion or not FLASH_COLORS[mode] then
		return
	end
	local f = EnsureFlash()
	if mode == "critkill" or mode == "crit" then
		ns.Gate(f.critGate, isCrit, 1, 0)
	else
		f.critGate:SetAlpha(1)
	end
	if mode == "critkill" or mode == "kill" then
		ns.Gate(f.deadGate, isDead, 1, 0)
	else
		f.deadGate:SetAlpha(1)
	end
	local c = FLASH_COLORS[mode]
	f.tex:SetColorTexture(c[1], c[2], c[3], 1)
	f.anim:Stop()
	f.root:SetAlpha(0.45)
	f.root:Show()
	f.anim:Play()
end

-- ── Health gates: low health and FINISH IT! ───────────────────────────────────────────

-- 1 at or below `threshold`, 0 above, evaluated by the client.
local function StepCurve(threshold)
	local util = _G.C_CurveUtil
	if not (util and util.CreateCurve) then
		return nil
	end
	local curve = util.CreateCurve()
	local step = _G.Enum and _G.Enum.LuaCurveType and _G.Enum.LuaCurveType.Step
	if step and curve.SetType then
		curve:SetType(step)
	end
	-- A step curve takes the last point at or below x, so the drop sits just past the
	-- threshold: exactly 25% still counts as "at or below 25%".
	curve:AddPoint(0, 1)
	curve:AddPoint(threshold + 0.001, 0)
	curve:AddPoint(1, 0)
	return curve
end

-- An alpha (maybe secret) for "health of `unit` at or below threshold". Never read here.
local function HealthAlpha(unit, curve, threshold)
	local percent = _G.UnitHealthPercent
	if percent and curve then
		local ok, alpha = pcall(percent, unit, true, curve)
		if ok and (issecretvalue(alpha) or type(alpha) == "number") then
			return alpha
		end
	end
	local now, most = UnitHealth(unit), UnitHealthMax(unit)
	if not issecretvalue(now) and not issecretvalue(most) and type(now) == "number" and type(most) == "number" and most > 0 then
		return (now / most <= threshold) and 1 or 0
	end
	return 0
end

local danger, finish
local dangerCurve, dangerCurveAt, finishCurve, finishCurveAt

local function EnsureDanger()
	if danger then
		return danger
	end
	local root = CreateFrame("Frame", "KapowDanger", UIParent)
	root:SetAllPoints(UIParent)
	root:SetFrameStrata("BACKGROUND")
	root:EnableMouse(false)
	local gate = CreateFrame("Frame", nil, root)
	gate:SetAllPoints(root)
	local tex = gate:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(gate)
	tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
	tex:SetVertexColor(1, 0.1, 0.1)
	if tex.SetBlendMode then
		tex:SetBlendMode("ADD")
	end
	local pulse = root:CreateAnimationGroup()
	local beat = pulse:CreateAnimation("Alpha")
	beat:SetFromAlpha(1)
	beat:SetToAlpha(0.35)
	beat:SetDuration(0.6)
	if pulse.SetLooping then
		pulse:SetLooping("BOUNCE")
	end
	root:Hide()
	danger = { root = root, gate = gate, pulse = pulse }
	return danger
end

local function EnsureFinish()
	if finish then
		return finish
	end
	local root = CreateFrame("Frame", "KapowFinish", UIParent)
	root:SetSize(320, 70)
	root:SetFrameStrata("HIGH")
	root:EnableMouse(false)
	local gate = CreateFrame("Frame", nil, root)
	gate:SetAllPoints(root)
	local text = gate:CreateFontString(nil, "OVERLAY")
	SetFontSafe(text, "russo-one", 40)
	text:SetTextColor(1, 0.3, 0.1)
	text:SetPoint("CENTER", gate, "CENTER", 0, 0)
	text:SetText("FINISH IT!")
	local pulse = root:CreateAnimationGroup()
	local throb = pulse:CreateAnimation("Alpha")
	throb:SetFromAlpha(1)
	throb:SetToAlpha(0.55)
	throb:SetDuration(0.45)
	if pulse.SetLooping then
		pulse:SetLooping("BOUNCE")
	end
	root:Hide()
	finish = { root = root, gate = gate, text = text, pulse = pulse }
	X.Register("finish", root)
	return finish
end

local function UpdateDanger()
	local db = Db()
	if not (db and db.enabled and db.dangerLow) then
		if danger then
			danger.root:Hide()
		end
		return
	end
	local d = EnsureDanger()
	if PlainTrue(UnitIsDeadOrGhost("player")) then
		d.root:Hide()
		return
	end
	if dangerCurveAt ~= db.dangerAt then
		dangerCurve, dangerCurveAt = StepCurve(db.dangerAt), db.dangerAt
	end
	d.gate:SetAlpha(HealthAlpha("player", dangerCurve, db.dangerAt))
	if not d.root:IsShown() then
		d.root:Show()
		if not db.reduceMotion then
			d.pulse:Play()
		end
	end
end

local function UpdateFinish()
	local db = Db()
	if not (db and db.enabled and db.finishIt) then
		if finish then
			finish.root:Hide()
		end
		return
	end
	local f = EnsureFinish()
	local exists = UnitExists("target")
	local hostile = UnitCanAttack and UnitCanAttack("player", "target")
	-- A hidden death flag counts as dead: a corpse at 0% would otherwise show FINISH IT!.
	if not PlainTrue(exists) or not PlainTrue(hostile) or not PlainFalse(UnitIsDead("target")) then
		f.root:Hide()
		return
	end
	if finishCurveAt ~= db.finishAt then
		finishCurve, finishCurveAt = StepCurve(db.finishAt), db.finishAt
	end
	f.gate:SetAlpha(HealthAlpha("target", finishCurve, db.finishAt))
	if not f.root:IsShown() then
		f.root:Show()
		if not db.reduceMotion then
			f.pulse:Play()
		end
	end
end

-- ── Wiring ────────────────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		if unit == "player" then
			UpdateDanger()
		elseif unit == "target" then
			UpdateFinish()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdateFinish()
	else -- PLAYER_ENTERING_WORLD, PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST
		UpdateDanger()
		UpdateFinish()
	end
end)

function X.Sync()
	local db = Db()
	if not db then
		return
	end
	frame:UnregisterAllEvents()
	local wantDanger = db.enabled and db.dangerLow
	local wantFinish = db.enabled and db.finishIt
	if wantDanger or wantFinish then
		local units = {}
		if wantDanger then
			units[#units + 1] = "player"
		end
		if wantFinish then
			units[#units + 1] = "target"
			frame:RegisterEvent("PLAYER_TARGET_CHANGED")
		end
		pcall(frame.RegisterUnitEvent, frame, "UNIT_HEALTH", unpack(units))
		pcall(frame.RegisterUnitEvent, frame, "UNIT_MAXHEALTH", unpack(units))
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		frame:RegisterEvent("PLAYER_DEAD")
		frame:RegisterEvent("PLAYER_ALIVE")
		frame:RegisterEvent("PLAYER_UNGHOST")
	end
	UpdateDanger()
	UpdateFinish()
	if not (db.enabled and db.comboCounter) and comboCount > 0 then
		comboCount, comboKey = 0, nil
		if comboFrame then
			comboFrame:Hide()
		end
	end
	X.PlaceAll()
end

-- For the window's buttons and tests.
X.UpdateDanger, X.UpdateFinish = UpdateDanger, UpdateFinish
