-- KAPOW — Versus.lua
--
-- VS intro (off by default; its own tab): you on the left, your opponent on the right, as large
-- translucent 3D models, with the VS art between them. It slides in, the VS slams through its
-- three frames, it holds, and it fades, all within versusDuration seconds (2 to 4).
--
-- Triggers (each optional): a duel starting, a boss pull, the FIGHT! at the end of an
-- arena / battleground / pull-timer countdown, and plain entering combat with an attackable
-- target. Moments.lua and the combat event below call V.Trigger; a cooldown keeps the intro
-- from repeating.
--
-- The opponent's model: SetUnit is documented RequiresDeclassifiedUnitIdentity (ReturnWithError).
-- oUF's portrait element calls SetUnit on any unit token, secret GUID or not, and its 3D
-- portraits keep working in restricted content, so the flag most likely concerns the unit
-- token argument rather than the unit's name or GUID. SetUnit is therefore always tried, inside
-- pcall; if it errors or reports failure, versusFallback decides: you and VS, VS alone, or no
-- intro. versusStrictIdentity (off) restores the first, cautious version: skip the opponent
-- whenever C_Secrets.ShouldUnitIdentityBeSecret says its identity is secret. Nothing about the
-- opponent is read or compared; the model is only drawn.
--
-- Drawn on the BACKGROUND strata by default (under action bars, unit frames and KAPOW's own
-- banners, over the world). The window's Test button draws it over everything instead.

local _, ns = ...

local issecretvalue = _G.issecretvalue or function()
	return false
end

local V = {}
ns.versus = V

local PORTRAIT_W, PORTRAIT_H = 360, 460 -- each model at 100%
local VS_SIZE = 300 -- the VS art at 100% (its texture is 512x512)
local OVERLAP = 70 -- how far each model reaches under the VS
local SLIDE = 140 -- pixels each model slides in from
local SLIDE_TIME = 0.35
local VS_DELAY = 0.15 -- the VS lands just after the models start moving
local POP_TIME = 0.2 -- VS scales from POP_FROM to 1 over this
local POP_FROM = 1.5
local FADE_IN, FADE_OUT = 0.2, 0.5
local COOLDOWN = 10 -- seconds before another trigger may show it
local FACING = 0.45 -- radians each model turns toward the middle (sign unverified in game)
local ZOOM = 0.55 -- portrait zoom: chest and head rather than the whole body

local VS_KEY = "arcade/versus"

local TRIGGERS = {
	duelstart = "versusDuel",
	bosspull = "versusBoss",
	countgo = "versusCountdown",
	kickoff = "versusCombat",
}

local root, left, right, vs
local showing, elapsed, life, lastShown = false, 0, 3, -math.huge
local vsFrames, vsStep
local hasLeft, hasRight

local function Db()
	return ns.db
end

local function Num(key, fallback)
	local db = Db()
	local v = db and tonumber(db[key])
	return v or fallback
end

-- ── Frames ────────────────────────────────────────────────────────────────────────────

local function NewModel()
	local model = CreateFrame("PlayerModel", nil, root)
	model:EnableMouse(false)
	model:SetSize(PORTRAIT_W, PORTRAIT_H)
	return model
end

local function Build()
	if root then
		return
	end
	-- Parentless first, then parented: SmartNavigation post-hooks CreateFrame.
	root = CreateFrame("Frame", "KapowVersus")
	root:SetParent(UIParent)
	root:EnableMouse(false)
	root:SetSize(2 * PORTRAIT_W + VS_SIZE - 2 * OVERLAP, PORTRAIT_H)
	root:Hide()

	left = NewModel()
	right = NewModel()

	vs = root:CreateTexture(nil, "OVERLAY")
	vs:SetPoint("CENTER")

	root:SetScript("OnUpdate", function(_, dt)
		V.Step(dt)
	end)
end

local function SetModelUnit(model, unit)
	model:ClearModel()
	local ok, success = pcall(model.SetUnit, model, unit)
	if not ok or success == false then
		return false
	end
	pcall(model.SetPortraitZoom, model, ZOOM)
	pcall(model.SetCamDistanceScale, model, 1)
	return true
end

-- A unit whose model may be drawn: it exists (and, in strict mode, its identity is plain).
local function Drawable(unit)
	local ok, exists = pcall(UnitExists, unit)
	if not ok or issecretvalue(exists) or not exists then
		return false
	end
	local secrets = _G.C_Secrets
	if Db().versusStrictIdentity and secrets and secrets.ShouldUnitIdentityBeSecret then
		local known, secret = pcall(secrets.ShouldUnitIdentityBeSecret, unit)
		if not known or issecretvalue(secret) or secret then
			return false
		end
	end
	return true
end

-- The first candidate whose model loads into `model`, or nil.
local function Opponent(trigger, model)
	local candidates = trigger == "bosspull" and { "boss1", "target" } or { "target" }
	for _, unit in ipairs(candidates) do
		if Drawable(unit) and SetModelUnit(model, unit) then
			return unit
		end
	end
end

-- ── Playback ──────────────────────────────────────────────────────────────────────────

local function Layout()
	local db = Db()
	local reduce = db.reduceMotion
	local slide = reduce and 0 or SLIDE
	local t = elapsed
	local s = math.min(1, t / SLIDE_TIME)
	s = 1 - (1 - s) * (1 - s) -- ease out
	local offset = slide * (1 - s)

	local envelope = 1
	if t < FADE_IN then
		envelope = t / FADE_IN
	elseif t > life - FADE_OUT then
		envelope = math.max(0, (life - t) / FADE_OUT)
	end

	local portraitAlpha = Num("versusPortraitAlpha", 0.35) * envelope
	left:ClearAllPoints()
	left:SetPoint("LEFT", root, "LEFT", -offset, 0)
	left:SetAlpha(portraitAlpha)
	right:ClearAllPoints()
	right:SetPoint("RIGHT", root, "RIGHT", offset, 0)
	right:SetAlpha(portraitAlpha)

	local vt = t - VS_DELAY
	if vt < 0 then
		vs:SetAlpha(0)
		return
	end
	local pop = 1
	if not reduce and vt < POP_TIME then
		pop = POP_FROM - (POP_FROM - 1) * (vt / POP_TIME)
	end
	local size = VS_SIZE * Num("versusVsSize", 1) * pop
	vs:SetSize(size, size)
	vs:SetAlpha(Num("versusVsAlpha", 0.7) * envelope)

	-- Onset, peak, aftershock at the art's own frame times, then the aftershock holds.
	if vsFrames and vsStep < 3 then
		local times = ns.art.FRAME_TIMES
		local at = times[1]
		if vsStep == 2 then
			at = times[1] + times[2]
		end
		if vt >= at then
			vsStep = vsStep + 1
			vs:SetTexture(vsFrames[vsStep])
		end
	end
end

function V.Step(dt)
	if not showing then
		return
	end
	elapsed = elapsed + dt
	if elapsed >= life then
		V.Stop()
		return
	end
	Layout()
end

function V.Stop()
	showing = false
	if root then
		root:Hide()
		left:ClearModel()
		right:ClearModel()
	end
end

-- Shows the intro now. trigger: the event that asked (for the opponent unit); test: draw it
-- over the settings window and ignore the cooldown, with a stand-in when there is no target.
function V.Play(trigger, test)
	local db = Db()
	if not db then
		return
	end
	Build()

	local opponent = Opponent(trigger, right)
	local fallback = db.versusFallback or "you"
	if not opponent and fallback == "skip" and not test then
		right:ClearModel()
		return
	end

	hasLeft = (opponent or fallback == "you" or test) and SetModelUnit(left, "player") or false
	hasRight = opponent ~= nil
	if test and not hasRight then
		-- Nothing targeted: the Test button mirrors you so both sides can be judged.
		hasRight = SetModelUnit(right, "player")
	end
	left:SetShown(hasLeft)
	right:SetShown(hasRight)
	pcall(left.SetFacing, left, FACING)
	pcall(right.SetFacing, right, -FACING)

	local art = ns.art.Get(VS_KEY)
	vsFrames, vsStep = art and art.frames, 1
	vs:SetTexture(vsFrames and vsFrames[1] or nil)
	vs:SetShown(vsFrames ~= nil)

	root:SetScale(Num("versusSize", 1))
	root:ClearAllPoints()
	root:SetPoint("CENTER", UIParent, "CENTER", 0, Num("versusY", 40))
	root:SetFrameStrata((test or not db.versusBehind) and "FULLSCREEN" or "BACKGROUND")

	life = math.min(4, math.max(2, Num("versusDuration", 3)))
	elapsed, showing = 0, true
	lastShown = GetTime()
	Layout()
	root:Show()
end

function V.Test()
	V.Play("test", true)
end

-- Whether a trigger is wanted (Moments.lua registers the events it needs for these too).
-- Kapow.lua's SyncSources runs Moments' and this file's Sync whenever a versus* key changes.
function V.Wants(id)
	local db = Db()
	local key = TRIGGERS[id]
	return key and db and db.enabled and db.versus and db[key] and true or false
end

function V.Trigger(id)
	if not V.Wants(id) or showing then
		return
	end
	if GetTime() - lastShown < COOLDOWN then
		return
	end
	if id == "kickoff" then
		-- Plain combat only shows it against something attackable you have targeted.
		local ok, attackable = pcall(UnitCanAttack, "player", "target")
		if not ok or issecretvalue(attackable) or not attackable then
			return
		end
	end
	V.Play(id)
end

-- ── Events ────────────────────────────────────────────────────────────────────────────

local driver = CreateFrame("Frame")
driver:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		V.Trigger("kickoff")
	else -- leaving the world: zoning, logging out, reloading
		V.Stop()
	end
end)

function V.Sync()
	driver:UnregisterAllEvents()
	local db = Db()
	if not db or not db.enabled or not db.versus then
		V.Stop()
		return
	end
	driver:RegisterEvent("PLAYER_LEAVING_WORLD")
	if db.versusCombat then
		driver:RegisterEvent("PLAYER_REGEN_DISABLED")
	end
end
