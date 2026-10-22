-- KAPOW — Display.lua
--
-- Draws one event: its art (a three-frame flipbook), title and detail line, with one of the
-- animation presets, at the chosen position, color, size and sound. Used by the comic hit
-- frames (Kapow.lua, inside their secret alpha gates) and by the banners
-- (Announcer.lua).
--
-- A "stage" is one drawable: an outer root that moves and fades, and a container holding the
-- art texture and two font strings. For the hit frames the container is the inner death
-- gate, so everything drawn stays under the gates; animation only ever runs on the root.
-- All animation values are plain.

local _, ns = ...

local D = {}
ns.display = D

local ART_SIZE = 256

D.COLORS = {
	gold = { 1.00, 0.84, 0.04 },
	red = { 1.00, 0.22, 0.18 },
	green = { 0.35, 1.00, 0.40 },
	blue = { 0.35, 0.75, 1.00 },
	white = { 1.00, 1.00, 1.00 },
	purple = { 0.78, 0.45, 1.00 },
	orange = { 1.00, 0.55, 0.10 },
}
D.COLOR_ORDER = { "gold", "orange", "red", "green", "blue", "purple", "white" }

-- key -> { label, path }. "auto" takes the font of the art's category (ART_FONTS), or
-- TEXT_FONT when there is no art. Then the game's own fonts, then the display fonts that
-- ship in Art/_fonts (ArtCatalog.lua).
D.FONTS = {
	auto = { "Match the art" },
	friz = { "Friz Quadrata (game)", "Fonts\\FRIZQT__.TTF" },
	arial = { "Arial Narrow (game)", "Fonts\\ARIALN.TTF" },
	skurri = { "Skurri (game)", "Fonts\\skurri.ttf" },
	morpheus = { "Morpheus (game)", "Fonts\\MORPHEUS.ttf" },
}
D.FONT_ORDER = { "auto", "friz", "arial", "skurri", "morpheus" }
for _, font in ipairs(ns.ART_FONTS or {}) do
	D.FONTS[font[1]] = { font[2], font[3] }
	D.FONT_ORDER[#D.FONT_ORDER + 1] = font[1]
end
D.TEXT_FONT = D.FONTS["black-ops-one"] and "black-ops-one" or "friz"

-- key -> { label, SOUNDKIT name } or { label, pool = { entries } }. A pool plays one entry at
-- random each time: a SOUNDKIT name, or a file path (generated sounds, SoundCatalog.lua). A
-- kit this client lacks is skipped at play time. All standard sounds are the game's own.
D.SOUNDS = {
	none = { "None" },
	raidwarning = { "Raid warning", "RAID_WARNING" },
	readycheck = { "Ready check", "READY_CHECK" },
	quest = { "Quest complete", "IG_QUEST_LIST_COMPLETE" },
	alarm = { "Alarm", "ALARM_CLOCK_WARNING_3" },
	countdown = { "Countdown: go!", "UI_BATTLEGROUND_COUNTDOWN_FINISHED" },
	queuepop = { "Queue pop", "PVP_THROUGH_QUEUE" },
	record = { "New record", "UI_CHALLENGES_NEW_RECORD" },
	legendary = { "Legendary loot", "UI_LEGENDARY_LOOT_TOAST" },
	bossemote = { "Boss emote", "RAID_BOSS_EMOTE_WARNING" },
	stunned = { "Stunned", "UI_LOSS_OF_CONTROL_START" },
	["random:fightstart"] = { "Random: fight start", pool = {
		"UI_BATTLEGROUND_COUNTDOWN_FINISHED", "PVP_THROUGH_QUEUE", "RAID_WARNING", "UI_LOSS_OF_CONTROL_START",
	} },
	["random:victory"] = { "Random: victory", pool = {
		"UI_CHALLENGES_NEW_RECORD", "UI_LEGENDARY_LOOT_TOAST", "UI_EPICLOOT_TOAST", "IG_QUEST_LIST_COMPLETE",
		"UI_PERSONAL_LOOT_BANNER",
	} },
	["random:alert"] = { "Random: alert", pool = {
		"RAID_WARNING", "RAID_BOSS_EMOTE_WARNING", "ALARM_CLOCK_WARNING_2", "READY_CHECK",
	} },
}
D.SOUND_ORDER = {
	"none", "raidwarning", "readycheck", "quest", "alarm", "countdown", "queuepop", "record", "legendary",
	"bossemote", "stunned", "random:fightstart", "random:victory", "random:alert",
}

-- Generated sound files (SoundCatalog.lua): join a built-in pool of the same id, or add one.
for poolId, pool in pairs(ns.SOUND_FILES or {}) do
	local key = "random:" .. poolId
	local entry = D.SOUNDS[key]
	if not entry then
		entry = { "Random: " .. (pool.label or poolId), pool = {} }
		D.SOUNDS[key] = entry
		D.SOUND_ORDER[#D.SOUND_ORDER + 1] = key
	end
	for _, file in ipairs(pool.files or {}) do
		entry.pool[#entry.pool + 1] = file
	end
end

D.POSITIONS = {
	comic = { "Comic spot (/kapow pos)" },
	banner = { "Top banner (drag with /kapow unlock)", 0, 260 },
	low = { "Low centre", 0, -160 },
	left = { "Left", -380, 120 },
	right = { "Right", 380, 120 },
}
D.POSITION_ORDER = { "comic", "banner", "low", "left", "right" }

-- Presets: whether the art flips through its three frames, and how the root moves. Slam and
-- Still show the peak frame only; their "three frames" twins move the same way and flip.
D.ANIMS = {
	flipbook = { label = "Flipbook pop", flip = true },
	slam = { label = "Slam in", flip = false },
	slamflip = { label = "Slam in (three frames)", flip = true },
	bounce = { label = "Bounce", flip = true },
	rise = { label = "Rise and fade", flip = true },
	shake = { label = "Shake", flip = true },
	static = { label = "Still", flip = false },
	stillflip = { label = "Still (three frames)", flip = true, calm = true },
}
D.ANIM_ORDER = { "flipbook", "slam", "slamflip", "bounce", "rise", "shake", "static", "stillflip" }

-- ── Building ──────────────────────────────────────────────────────────────────────────

-- Adds art, title and detail line to `container`, animated through `root`.
-- life: seconds on screen before the fade completes.
function D.NewStage(root, container, life)
	local stage = { root = root, container = container, life = life, groups = {}, showId = 0 }

	stage.tex = container:CreateTexture(nil, "ARTWORK")
	stage.tex:SetSize(ART_SIZE, ART_SIZE)
	stage.tex:SetPoint("CENTER", container, "CENTER", 0, 0)

	stage.sub = container:CreateFontString(nil, "OVERLAY")
	stage.sub:SetFont(D.FONTS.friz[2], 26, "THICKOUTLINE")
	stage.sub:SetTextColor(1, 1, 1)
	stage.sub:SetShadowOffset(2, -2)

	stage.title = container:CreateFontString(nil, "OVERLAY")
	stage.title:SetFont(D.FONTS.friz[2], 54, "THICKOUTLINE")
	stage.font = "friz"
	stage.title:SetShadowOffset(3, -3)

	return stage
end

local function ScaleFromTo(anim, from, to)
	if anim.SetScaleFrom then
		anim:SetScaleFrom(from, from)
		anim:SetScaleTo(to, to)
	else
		anim:SetFromScale(from, from)
		anim:SetToScale(to, to)
	end
end

local function Fade(group, life, order)
	local fade = group:CreateAnimation("Alpha")
	fade:SetOrder(order)
	fade:SetStartDelay(math.max(0, life - 0.35))
	fade:SetDuration(0.35)
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
end

local BUILDERS = {}

function BUILDERS.flipbook(group, life)
	local pop = group:CreateAnimation("Scale")
	pop:SetOrder(1)
	pop:SetDuration(0.12)
	ScaleFromTo(pop, 0.6, 1.0)
	pop:SetSmoothing("OUT")
	Fade(group, life - 0.12, 2)
end

function BUILDERS.slam(group, life)
	local slam = group:CreateAnimation("Scale")
	slam:SetOrder(1)
	slam:SetDuration(0.14)
	ScaleFromTo(slam, 1.8, 1.0)
	slam:SetSmoothing("OUT")
	Fade(group, life - 0.14, 2)
end

function BUILDERS.bounce(group, life)
	local up = group:CreateAnimation("Scale")
	up:SetOrder(1)
	up:SetDuration(0.12)
	ScaleFromTo(up, 0.3, 1.15)
	up:SetSmoothing("OUT")
	local settle = group:CreateAnimation("Scale")
	settle:SetOrder(2)
	settle:SetDuration(0.08)
	ScaleFromTo(settle, 1.0, 1 / 1.15)
	Fade(group, life - 0.2, 3)
end

function BUILDERS.rise(group, life)
	local rise = group:CreateAnimation("Translation")
	rise:SetOrder(1)
	rise:SetDuration(life)
	rise:SetOffset(0, 70)
	rise:SetSmoothing("OUT")
	local fade = group:CreateAnimation("Alpha")
	fade:SetOrder(1)
	fade:SetStartDelay(life * 0.5)
	fade:SetDuration(life * 0.5)
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
end

function BUILDERS.shake(group, life)
	local offsets = { 10, -16, 12, -8, 2 }
	for i, dx in ipairs(offsets) do
		local move = group:CreateAnimation("Translation")
		move:SetOrder(i)
		move:SetDuration(0.04)
		move:SetOffset(dx, 0)
	end
	Fade(group, life - 0.2, #offsets + 1)
end

function BUILDERS.static(group, life)
	Fade(group, life, 1)
end

BUILDERS.slamflip = BUILDERS.slam
BUILDERS.stillflip = BUILDERS.static

-- When the fade of each preset begins (Rise fades over its second half).
local function FadeStart(preset, life)
	if preset == "rise" then
		return life * 0.5
	end
	return math.max(0, life - 0.35)
end

-- One animation group per preset and duration, built on first use (preset -> life -> group).
local function Group(stage, preset, life)
	local byLife = stage.groups[preset]
	if not byLife then
		byLife = {}
		stage.groups[preset] = byLife
	end
	local group = byLife[life]
	if not group then
		group = stage.root:CreateAnimationGroup()
		BUILDERS[preset](group, life)
		byLife[life] = group
	end
	return group
end

local function StopAll(stage)
	for _, byLife in pairs(stage.groups) do
		for _, group in pairs(byLife) do
			group:Stop()
		end
	end
end

-- ── Playing ───────────────────────────────────────────────────────────────────────────

local function Layout(stage, hasArt)
	local title, sub, container = stage.title, stage.sub, stage.container
	title:ClearAllPoints()
	sub:ClearAllPoints()
	if hasArt then
		-- The word is in the art. The detail line sits in its calm lower area, the title
		-- under the art.
		sub:SetPoint("CENTER", container, "CENTER", 0, -62)
		title:SetPoint("TOP", container, "CENTER", 0, -ART_SIZE / 2 + 6)
	else
		title:SetPoint("CENTER", container, "CENTER", 0, 14)
		sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
	end
end

-- One sound entry: a file path (it has a backslash) or a SOUNDKIT name. True if it played.
local function PlayEntry(entry)
	if string.find(entry, "\\", 1, true) then
		return _G.PlaySoundFile and _G.PlaySoundFile(entry, "Master") and true or false
	end
	local kit = SOUNDKIT and SOUNDKIT[entry]
	if kit then
		_G.PlaySound(kit)
		return true
	end
	return false
end

local function PlayEventSound(key)
	if not ns.db.annSound then
		return
	end
	local sound = D.SOUNDS[key]
	if not sound then
		return
	end
	local pool = sound.pool
	if pool then
		-- A random start, then onwards, so a kit or file this client lacks is skipped.
		local count = #pool
		if count == 0 then
			return
		end
		local start = math.random(1, count)
		for i = 0, count - 1 do
			if PlayEntry(pool[(start + i - 1) % count + 1]) then
				return
			end
		end
	elseif sound[2] then
		PlayEntry(sound[2])
	end
end

-- One of D.SOUNDS by key (Event sounds switch respected), for callers outside an event.
function D.PlaySound(key)
	PlayEventSound(key)
end

-- A font file the client cannot load leaves the text on the game font.
local function SetFonts(stage, path)
	if not stage.title:SetFont(path, 54, "THICKOUTLINE") then
		stage.title:SetFont(D.FONTS.friz[2], 54, "THICKOUTLINE")
	end
	if not stage.sub:SetFont(path, 26, "THICKOUTLINE") then
		stage.sub:SetFont(D.FONTS.friz[2], 26, "THICKOUTLINE")
	end
end

-- Where a position key puts the stage, before jitter.
function D.Offset(pos)
	local p = D.POSITIONS[pos] or D.POSITIONS.banner
	if pos == "comic" then
		return ns.db.x, ns.db.y
	end
	if pos == "banner" and ns.db.bannerX then
		return ns.db.bannerX, ns.db.bannerY
	end
	return p[2], p[3]
end

-- Shows `cfg` on `stage`. `values` fills the text templates (may hold secrets).
-- opts: dx, dy, tilt (jitter), silent (skip the sound), sizeMul; onDone: called when it has faded out.
-- cfg.duration stretches the whole show, flipbook included (1 = the stage's own length).
function D.Play(stage, cfg, values, opts, onDone)
	local entry = ns.art.Resolve(cfg.art)
	local preset = D.ANIMS[cfg.anim] and cfg.anim or "slam"
	if ns.db.reduceMotion and preset ~= "static" and not D.ANIMS[preset].calm then
		preset = D.ANIMS[preset].flip and "rise" or "static" -- no slam, bounce or shake
	end
	local flip = entry and D.ANIMS[preset].flip
	local stretch = math.min(4, math.max(0.25, tonumber(cfg.duration) or 1))
	if ns.db.reduceMotion then
		stretch = math.min(stretch, 0.75) -- Extras: calmer, shorter shows
	end
	local life = stage.life * stretch

	stage.showId = stage.showId + 1
	local showId = stage.showId

	if entry then
		stage.tex:SetTexture(entry.frames[flip and 1 or 2])
		stage.tex:SetRotation(opts and opts.tilt or 0)
		stage.tex:Show()
	else
		stage.tex:Hide()
	end
	Layout(stage, entry ~= nil)

	local font = cfg.font
	if font == "auto" or not D.FONTS[font] then
		font = (entry and ns.art.FontFor(entry.category)) or D.TEXT_FONT
	end
	if stage.font ~= font then
		stage.font = font
		SetFonts(stage, D.FONTS[font] and D.FONTS[font][2] or D.FONTS.friz[2])
	end

	local c = D.COLORS[cfg.color] or D.COLORS.gold
	stage.title:SetTextColor(c[1], c[2], c[3])
	ns.ComposeText(stage.title, cfg.title, values)
	if cfg.details then
		ns.ComposeText(stage.sub, cfg.sub, values)
	else
		stage.sub:SetText("")
	end

	local root = stage.root
	local x, y = D.Offset(cfg.pos)
	root:ClearAllPoints()
	root:SetPoint("CENTER", UIParent, "CENTER", x + (opts and opts.dx or 0), y + (opts and opts.dy or 0))
	-- A zero scale errors. sizeMul: Announcer streaks grow their banner.
	root:SetScale(math.max(0.05, (ns.db.scale or 1) * (cfg.size or 1) * (opts and opts.sizeMul or 1)))
	root:SetAlpha(1)
	StopAll(stage)
	root:Show()
	Group(stage, preset, life):Play()

	if flip then
		-- The art's timing: onset, peak, then the aftershock holds until the end. With
		-- frameHold = "peak" (Experimental tab) the peak holds instead and the aftershock
		-- arrives as the fade begins.
		local times = ns.art.FRAME_TIMES
		local aftershock = (times[1] + times[2]) * stretch
		if ns.db.frameHold == "peak" then
			aftershock = math.max(aftershock, FadeStart(preset, life))
		end
		C_Timer.After(times[1] * stretch, function()
			if stage.showId == showId then
				stage.tex:SetTexture(entry.frames[2])
			end
		end)
		C_Timer.After(aftershock, function()
			if stage.showId == showId then
				stage.tex:SetTexture(entry.frames[3])
			end
		end)
	end

	C_Timer.After(life, function()
		if stage.showId ~= showId then
			return -- a newer show took over this stage
		end
		root:Hide()
		if onDone then
			onDone()
		end
	end)

	if not (opts and opts.silent) then
		PlayEventSound(cfg.sound)
	end
end

-- Stops a stage at once.
function D.Stop(stage)
	stage.showId = stage.showId + 1
	StopAll(stage)
	stage.root:Hide()
end
