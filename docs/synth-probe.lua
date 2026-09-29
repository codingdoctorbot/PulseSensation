-- Signal-synthesis probe. Loads the REAL working-tree Core/Devices.lua, Schemas/Standard.lua,
-- Modes.lua and Engine.lua (Engine optionally patched IN MEMORY for A/B variants; nothing on
-- disk is touched), drives OnUpdate at a chosen frame rate with a C_Timer scheduler, and
-- records what C_GamePad.SetVibration receives.
-- usage (from the repo root): luajit synth-probe.lua PulseHaptics
-- Supporting evidence for HAPTIC_SYNTHESIS_CRITIQUE.md (sections A-G map to the report).
local ROOT = assert(arg[1], "PulseHaptics root")

local W -- current world
function GetTime() return W.now end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function issecretvalue() return false end
C_Timer = { After = function(d, fn) W.timers[#W.timers + 1] = { at = W.now + d, fn = fn } end }
function CreateFrame()
	local f = { scripts = {} }
	function f:SetScript(kind, fn) self.scripts[kind] = fn; if kind == "OnUpdate" then W.onUpdate = fn end end
	function f:RegisterEvent() end
	return f
end
C_GamePad = {
	IsEnabled = function() return true end,
	GetActiveDeviceID = function() return 1 end,
	SetVibration = function(ch, v) W.out[ch] = v; W.sends = W.sends + 1 end,
	StopVibration = function() W.out.Low = 0; W.out.High = 0 end,
}

local function readFile(p) local f = assert(io.open(p)); local s = f:read("*a"); f:close(); return s end
local ENGINE_SRC = readFile(ROOT .. "/Core/Engine.lua")

local function presetTuning(id, extra)
	local t = {}
	local device = Pulse_Devices[id]
	for _, ch in ipairs({ "Low", "High" }) do
		local over = device.channels and device.channels[ch]
		local row = {}
		for k, d in pairs(Pulse_DEFAULTS) do
			local v = over and over[k]
			if v == nil then v = d end
			row[k] = v
		end
		if extra and extra[ch] then for k, v in pairs(extra[ch]) do row[k] = v end end
		t[ch] = row
	end
	return t
end

-- opts: preset, extra(per-channel overrides), master, fps, order("timersFirst"|"updateFirst"), patch(fn src->src)
local function newWorld(opts)
	W = { now = 100.0, timers = {}, out = { Low = 0, High = 0 }, sends = 0 }
	local Pulse = {}
	local function load(rel) assert(loadfile(ROOT .. "/" .. rel))("PulseHaptics", Pulse) end
	load("Core/Devices.lua")
	Pulse_Devices, Pulse_DEFAULTS = Pulse.Devices, Pulse.CHANNEL_DEFAULTS
	load("Core/Schemas/Standard.lua")
	load("Core/Modes.lua")
	local tuning = presetTuning(opts.preset or "xbox", opts.extra)
	Pulse.Database = {
		Get = function(_, key)
			if key == "masterIntensity" then return opts.master or 0.7 end
			if key == "defaultHapticSchema" then return "standard" end
			if key == "masterEnabled" then return true end
		end,
		GetChannelTuning = function(_, ch, key, default)
			local v = tuning[ch] and tuning[ch][key]
			if v == nil then return default end
			return v
		end,
		GetModeTuning = function(_, _, _, default) return default end,
		GetChangeEpsilon = function() return Pulse.CHANGE_EPSILON_DEFAULT end,
		OnGlobalChanged = function() end,
	}
	local src = ENGINE_SRC
	-- instrumentation: expose per-channel overdrive state each drive call
	src = src:gsub("(local isOverdriving = %(now < %(overdriveUntilByChannel%[channel%] or 0%)%))",
		"%1\n\t_G.__OD[channel] = isOverdriving")
	if opts.patch then src = opts.patch(src) end
	_G.__OD = {}
	assert(load and loadstring or load)
	assert((loadstring or load)(src, "=Engine.lua"))("PulseHaptics", Pulse)
	W.Pulse, W.E = Pulse, Pulse.Engine
	W.E:RefreshDevice()
	W.fps, W.order = opts.fps or 60, opts.order or "timersFirst"
	return W
end

local function fireTimers()
	local i = 1
	while i <= #W.timers do
		local t = W.timers[i]
		if t.at <= W.now + 1e-9 then table.remove(W.timers, i); t.fn() else i = i + 1 end
	end
end

-- advance one frame; `events` = function run as game-event code this frame (same slot as timers)
local function frame(events)
	local dt = 1 / W.fps
	W.now = W.now + dt
	-- which layers exist and are unexpired at the moment OnUpdate samples them
	local function sampleAndUpdate()
		local alive = 0
		for _, l in ipairs(W.E:_DebugLayers()) do if l.remaining > 0 then alive = alive + 1 end end
		W.aliveAtUpdate = alive
		W.onUpdate(nil, dt)
	end
	if W.order == "timersFirst" then
		fireTimers(); if events then events() end; sampleAndUpdate()
	else
		sampleAndUpdate(); fireTimers(); if events then events() end
	end
	return W.out.Low, W.out.High
end

local function fmt(v) return ("%.3f"):format(v) end
local P = print

------------------------------------------------------------------------------------------
P("== A. Overdrive: how long the boosted drive is actually held, by frame rate ==")
P("Xbox preset (working tree), master 0.7, BLIP (Low 0.48 x 50 ms), coast trim off to isolate.")
P(("%-5s %-26s %-24s %s"):format("fps", "Low: boosted frames (ms)", "held until (ms)", "Low sent, first 5 frames"))
for _, fps in ipairs({ 30, 35, 40, 45, 50, 60, 90, 144 }) do
	newWorld({ fps = fps, extra = { Low = { coastCoeff = 0 } } })
	local t0 = nil
	local boosted, lastBoostIdx, vals = {}, 0, {}
	for i = 1, 12 do
		local lo = frame(i == 1 and function() W.E:PlayMode("x", "BLIP", 1.0) end or nil)
		if i == 1 then t0 = W.now end
		if __OD.Low then boosted[#boosted + 1] = ("%.0f"):format((W.now - t0) * 1000); lastBoostIdx = i end
		if i <= 5 then vals[#vals + 1] = fmt(lo) end
	end
	local heldUntil = lastBoostIdx * (1000 / fps)
	P(("%-5d %-26s %-24s %s"):format(fps, table.concat(boosted, ","), ("%.1f (cfg 30)"):format(heldUntil), table.concat(vals, " ")))
end

P("\nHigh channel, SNAP (High 0.95 x 40 ms), coast off:")
for _, fps in ipairs({ 30, 60, 144 }) do
	newWorld({ fps = fps, extra = { Low = { coastCoeff = 0 } } })
	local lastBoostIdx = 0
	for i = 1, 10 do
		frame(i == 1 and function() W.E:PlayMode("x", "SNAP", 1.0) end or nil)
		if __OD.High then lastBoostIdx = i end
	end
	P(("  %3d fps: boost held %.1f ms (cfg 15)"):format(fps, lastBoostIdx * 1000 / fps))
end

------------------------------------------------------------------------------------------
P("\n== A2. Overdrive size after the floor/gamma map (Xbox Low, gamma .88, floor .125) ==")
do
	local function map(v, fl, g) v = math.min(1, v); return fl + (1 - fl) * v ^ g end
	P(("%-7s %-9s %-9s %-10s %-14s"):format("wanted", "mapped", "boosted", "ratio", "above-floor ratio"))
	for _, w in ipairs({ 0.05, 0.1, 0.2, 0.34, 0.5, 0.69, 0.8, 1.0 }) do
		local a, b = map(w, 0.125, 0.88), map(w * 1.45, 0.125, 0.88)
		P(("%-7.2f %-9.3f %-9.3f %-10.3f %-14.3f"):format(w, a, b, b / a, (b - 0.125) / (a - 0.125)))
	end
end

------------------------------------------------------------------------------------------
P("\n== A3. Rotor model: does the 1.45x/30 ms kick make spin-up '3x faster'? ==")
P("First-order rotor above breakaway: speed' = (drive_above_floor - speed)/tau_m. MODEL, tau_m assumed.")
P("Drive = what the engine sends (zero-order hold per frame, 60 fps). t90 = time for speed to reach 90% of final.")
do
	local function runTrace(extra, mode, frames)
		newWorld({ fps = 60, extra = extra })
		local tr = {}
		for i = 1, frames do tr[i] = frame(i == 1 and function() W.E:PlayMode("x", mode, 1.0) end or nil) end
		return tr
	end
	local off = runTrace({ Low = { overdriveBoost = 1.0, coastCoeff = 0 } }, "LONG", 24)
	local on = runTrace({ Low = { coastCoeff = 0 } }, "LONG", 24)
	local bang = nil -- ideal: full drive until the rotor reaches target, computed below
	for _, tau in ipairs({ 0.040, 0.085, 0.120 }) do
		local function t90(trace)
			local fl, s, dt = 0.125, 0, 1 / 60
			local final = (trace[#trace] - fl) / (1 - fl)
			for i = 1, #trace do
				local d = math.max(0, (trace[i] - fl) / (1 - fl))
				-- integrate within the frame in 10 sub-steps
				for _ = 1, 10 do s = s + (d - s) * (dt / 10) / tau end
				if s >= 0.9 * final then return i * dt * 1000 end
			end
			return nil
		end
		-- ideal bang-bang: drive 1.0 until speed reaches target, then hold target
		local fl = 0.125
		local target = (on[#on] - fl) / (1 - fl)
		local tb = -tau * math.log(1 - target * 0.9) * 1000 -- full drive (1.0) until 90% of target
		P(("  tau_m %3.0f ms: t90 no-OD %5.1f ms | OD 1.45x/30ms %5.1f ms | ideal full-drive kick %5.1f ms"):format(
			tau * 1000, t90(off), t90(on), tb))
	end
	P(("  (LONG = Low 0.70 x 450 ms, master 0.7 -> steady send %.3f)"):format(on[#on]))
end

------------------------------------------------------------------------------------------
P("\n== B. Coast trim: holes and dropped steps in real modes (Xbox preset, master 0.7) ==")
P("segments = separate on-runs of the cue's layer as OnUpdate samples it; odTrig = overdrive onsets.")
local MODES = { "TAP", "SNAP", "MICRO_TAP", "CLICK", "TICK", "BLIP", "IMPACT", "CRACK", "THUD", "BRAKE", "WOBBLE", "SURGE", "RISING", "FALLING", "DEFLECT", "DRAW", "STUTTER", "STACCATO", "BURST", "PULSE_BEAT" }
local function modeRun(modeID, fps, order, coast)
	newWorld({ fps = fps, order = order, extra = not coast and { Low = { coastCoeff = 0 } } or nil })
	local segs, inSeg, framesOn, od, prevOD = 0, false, 0, 0, { Low = false, High = false }
	local peakL, peakH = 0, 0
	for i = 1, math.floor(fps * 1.6) do
		local lo, hi = frame(i == 1 and function() W.E:PlayMode("cue", modeID, 1.0) end or nil)
		local on = W.aliveAtUpdate > 0
		if on and not inSeg then segs = segs + 1 end
		inSeg = on
		if on then framesOn = framesOn + 1 end
		for _, ch in ipairs({ "Low", "High" }) do
			if __OD[ch] and not prevOD[ch] then od = od + 1 end
			prevOD[ch] = __OD[ch] or false
			__OD[ch] = false
		end
		peakL, peakH = math.max(peakL, lo), math.max(peakH, hi)
	end
	return segs, framesOn, od, peakL, peakH
end
P("columns: seg/frames/odTrig pkLow,pkHigh.  T = cue code runs before OnUpdate in the frame, U = after")
P(("%-10s %-22s %-22s %-22s %-22s %-22s"):format("mode", "60T coast OFF", "60T coast ON", "60U coast ON", "30U coast OFF", "30U coast ON"))
for _, m in ipairs(MODES) do
	local function s(r) return ("%d/%d/%d %.2f,%.2f"):format(r[1], r[2], r[3], r[4], r[5]) end
	P(("%-10s %-22s %-22s %-22s %-22s %-22s"):format(m,
		s({ modeRun(m, 60, "timersFirst", false) }), s({ modeRun(m, 60, "timersFirst", true) }),
		s({ modeRun(m, 60, "updateFirst", true) }), s({ modeRun(m, 30, "updateFirst", false) }),
		s({ modeRun(m, 30, "updateFirst", true) })))
end

------------------------------------------------------------------------------------------
P("\n== C. Sidechain ducking: closed form, role space ==")
P("out = d*c + t*(1-d*c), d = max(0.30, 1-0.65t). Floor 0.30 needs t > 1.077; roles are clamped to 1.")
P(("%-5s | %s"):format("c\\t", "t=0.10  t=0.28  t=0.55  t=0.70  t=0.95  (value = ducked out; [x] = out without duck)"))
for _, c in ipairs({ 0.10, 0.30, 0.50, 0.70, 0.90 }) do
	local row = {}
	for _, t in ipairs({ 0.10, 0.28, 0.55, 0.70, 0.95 }) do
		local d = math.max(0.30, 1 - 0.65 * t)
		local o = d * c + t * (1 - d * c)
		local n = c + t * (1 - c)
		row[#row + 1] = ("%.3f[%.3f]%s"):format(o, n, o < c and "v" or " ")
	end
	P(("%-5.2f | %s"):format(c, table.concat(row, " ")))
end
P("v = transient LOWERS the output below the bed alone (dip instead of hit)")

P("\n== C2. Ducking in the engine: cast swell + a transient on the same (High) role ==")
P("castTexture held every frame (Low 0.10 presence, High 0.70 x progress); cue fired at progress 0.9.")
local NO_DUCK = function(src)
	return (src:gsub("local duckingFactor = math%.max%(0%.30, 1%.0 %- %(trans %* 0%.65%)%)", "local duckingFactor = 1.0"))
end
local ADDITIVE = function(src)
	src = src:gsub("local duckingFactor = math%.max%(0%.30, 1%.0 %- %(trans %* 0%.65%)%)", "local duckingFactor = 1.0")
	return (src:gsub("frameRoleTotals%[role%] = clamp01%(duckedCont %+ trans %* %(1%.0 %- duckedCont%)%)",
		"frameRoleTotals[role] = clamp01(duckedCont + trans)"))
end
local function castScenario(variant, cueMode, cueKind)
	newWorld({ fps = 60, patch = variant })
	local castLen, fireAt = 2.0, 1.8
	local n = math.floor(castLen * 60)
	local before, peak, minDuring = nil, 0, 9
	for i = 1, n + 20 do
		local tt = i / 60
		frame(function()
			if tt <= castLen then W.E:Hold("castTexture", 0.10, 0.70 * (tt / castLen)) end
			if math.abs(tt - fireAt) < 1e-6 or (tt >= fireAt and tt < fireAt + 1 / 60 - 1e-9) then
				if cueKind == "mode" then W.E:PlayMode("cue", cueMode, 1.0)
				else W.E:Set("lowHealthTexture", 0.7, 0.7, 0.05, true) end
			end
		end)
		if tt < fireAt then before = W.out.High end
		if tt >= fireAt and tt < fireAt + 0.12 then
			peak = math.max(peak, W.out.High); minDuring = math.min(minDuring, W.out.High)
		end
	end
	return before, peak, minDuring
end
P(("%-26s %-26s %-26s %-26s"):format("cue on High role", "duck (tree): pre/peak/min", "no duck: pre/peak/min", "clamp(c+t): pre/peak/min"))
for _, cue in ipairs({ { "TICK", "mode" }, { "TAP", "mode" }, { "MICRO_TAP", "mode" }, { "SNAP", "mode" }, { "heartbeat lub 0.7", "hb" } }) do
	local r = {}
	for _, v in ipairs({ false, NO_DUCK, ADDITIVE }) do
		local a, b, c = castScenario(v or nil, cue[1], cue[2])
		r[#r + 1] = ("%.3f/%.3f/%.3f"):format(a, b, c)
	end
	P(("%-26s %-26s %-26s %-26s"):format(cue[1], r[1], r[2], r[3]))
end

------------------------------------------------------------------------------------------
P("\n== D. Shaped footfall hit by an unrelated transient on the same role (SHAPED_YIELD) ==")
local BOOT = { kickTime = 0.022, kickGain = 1.6, cut = 0.06, tau = { low = 0.040, high = 0.018, default = 0.030 } }
for _, withTick in ipairs({ false, true }) do
	newWorld({ fps = 60 })
	local tr = {}
	for i = 1, 12 do
		local lo = frame(function()
			if i == 1 then W.E:Hold("locomotion", 0.35, 0.21, 0.045, true, BOOT) end
			if withTick and i == 2 then W.E:Set("uiTick", 0.12, 0, 0.035, true) end
		end)
		tr[#tr + 1] = fmt(lo)
	end
	P(("  %-24s Low per frame: %s"):format(withTick and "footfall + 0.12 Low tick" or "footfall alone", table.concat(tr, " ")))
end

------------------------------------------------------------------------------------------
P("\n== E. 20 s overlapping combat mix, Xbox preset, master 0.7, 60 fps, cue code before OnUpdate ==")
P("2.0 s cast swells back to back; heartbeat lub-dub (0.7/0.2, 50 ms, 0.36 s apart) every 0.9 s;")
P("THUD every 2.6 s (melee hit); SNAP every 1.7 s; TICK every 0.45 s; BOOT footfall every 0.5 s.")
local function combat(extra, patch)
	newWorld({ fps = 60, extra = extra, patch = patch })
	local stats = { odL = 0, odH = 0, sends = 0, both = 0, lowHardHighSoft = 0, frames = 0, holesL = 0 }
	local prev = { Low = false, High = false }
	local lastLow = 0
	local N = 20 * 60
	local function every(i, period, phase) return (i - phase) % math.floor(period * 60 + 0.5) == 0 and i >= phase end
	local BOOTs = { kickTime = 0.022, kickGain = 1.6, cut = 0.06, tau = { low = 0.040, high = 0.018, default = 0.030 } }
	for i = 1, N do
		local tt = i / 60
		local lo, hi = frame(function()
			local p = (tt % 2.0) / 2.0
			W.E:Hold("castTexture", 0.10, 0.70 * p)
			if every(i, 0.9, 3) then W.E:Set("lowHealthTexture", 0.7, 0.7, 0.05, true) end
			if every(i, 0.9, 3 + 22) then W.E:Set("lowHealthTexture", 0.2, 0.2, 0.05, true) end
			if every(i, 2.6, 17) then W.E:PlayMode("meleeHit", "THUD", 1.0) end
			if every(i, 1.7, 41) then W.E:PlayMode("proc", "SNAP", 1.0) end
			if every(i, 0.45, 7) then W.E:PlayMode("uiTick", "TICK", 1.0) end
			if every(i, 0.5, 11) then W.E:Hold("locomotion", 0.35, 0.21, 0.045, true, BOOTs) end
		end)
		for _, ch in ipairs({ "Low", "High" }) do
			if __OD[ch] and not prev[ch] then stats[ch == "Low" and "odL" or "odH"] = stats[ch == "Low" and "odL" or "odH"] + 1 end
			prev[ch] = __OD[ch] or false; __OD[ch] = false
		end
		stats.frames = stats.frames + 1
		if lo > 0.13 and hi > 0.10 then stats.both = stats.both + 1 end
		if lo >= 0.6 and hi > 0.09 and hi <= 0.3 then stats.lowHardHighSoft = stats.lowHardHighSoft + 1 end
		lastLow = lo
	end
	stats.sends = W.sends
	return stats
end
for _, v in ipairs({
	{ "working tree (OD+coast+duck)", nil, nil },
	{ "no coast trim", { Low = { coastCoeff = 0 } }, nil },
	{ "no OD, no coast (duck only)", { Low = { overdriveBoost = 1, overdriveDuration = 0, coastCoeff = 0 }, High = { overdriveBoost = 1, overdriveDuration = 0 } }, nil },
}) do
	local s = combat(v[2], v[3])
	P(("  %-30s OD onsets Low %3d High %3d (per s: %.1f/%.1f) | SetVibration calls %d (%.0f/s) | both motors above floor %4.1f%% | Low>=0.6 & High<=0.3 %4.1f%%"):format(
		v[1], s.odL, s.odH, s.odL / 20, s.odH / 20, s.sends, s.sends / 20, 100 * s.both / s.frames, 100 * s.lowHardHighSoft / s.frames))
end

P("\n== F. controls: 60 fps, cue code AFTER OnUpdate, coast OFF (fair baseline for the 60U column) ==")
for _, m in ipairs({ "SNAP", "MICRO_TAP", "STUTTER", "STACCATO", "BURST", "TAP", "IMPACT" }) do
	local r = { modeRun(m, 60, "updateFirst", false) }
	P(("  %-10s %d/%d/%d %.2f,%.2f"):format(m, r[1], r[2], r[3], r[4], r[5]))
end
P("\n== G. combat mix: overdrive onsets that land on an already-spinning rotor ==")
do
	newWorld({ fps = 60 })
	local prev, spinning, total = { Low = false, High = false }, 0, 0
	local lastOut = { Low = 0, High = 0 }
	local floor = { Low = 0.125, High = 0.095 }
	local BOOTs = { kickTime = 0.022, kickGain = 1.6, cut = 0.06, tau = { low = 0.040, high = 0.018, default = 0.030 } }
	local function every(i, period, phase) return (i - phase) % math.floor(period * 60 + 0.5) == 0 and i >= phase end
	for i = 1, 1200 do
		local tt = i / 60
		frame(function()
			W.E:Hold("castTexture", 0.10, 0.70 * ((tt % 2.0) / 2.0))
			if every(i, 0.9, 3) then W.E:Set("lowHealthTexture", 0.7, 0.7, 0.05, true) end
			if every(i, 0.9, 25) then W.E:Set("lowHealthTexture", 0.2, 0.2, 0.05, true) end
			if every(i, 2.6, 17) then W.E:PlayMode("meleeHit", "THUD", 1.0) end
			if every(i, 1.7, 41) then W.E:PlayMode("proc", "SNAP", 1.0) end
			if every(i, 0.45, 7) then W.E:PlayMode("uiTick", "TICK", 1.0) end
			if every(i, 0.5, 11) then W.E:Hold("locomotion", 0.35, 0.21, 0.045, true, BOOTs) end
		end)
		for _, ch in ipairs({ "Low", "High" }) do
			if __OD[ch] and not prev[ch] then
				total = total + 1
				if lastOut[ch] >= floor[ch] then spinning = spinning + 1 end
			end
			prev[ch] = __OD[ch] or false; __OD[ch] = false
			lastOut[ch] = W.out[ch]
		end
	end
	P(("  %d of %d overdrive onsets fired while the previous frame was already driving that motor at or above its floor"):format(spinning, total))
	-- same mix with no cast texture (no bed): how many kicks land within 70 ms of the motor last being driven
end

------------------------------------------------------------------------------------------
P("\n== H. Upside checks: WP5 send cap at high fps; overdrive (and overdrive + coast) on isolated taps ==")
P("Rotor model as in A3 (first-order above floor, tau_m ASSUMED). Peak = highest relative rotor speed reached.")
local NOCAP = function(s) return (s:gsub("local MIN_TELEMETRY_INTERVAL = 0%.0125", "local MIN_TELEMETRY_INTERVAL = 0")) end
local BOOTs = { kickTime = 0.022, kickGain = 1.6, cut = 0.06, tau = { low = 0.040, high = 0.018, default = 0.030 } }
local function mix(fps, patch)
  newWorld({ fps = fps, patch = patch })
  local N = 20 * fps
  local function every(i, period, phase) return (i - phase) % math.floor(period * fps + 0.5) == 0 and i >= phase end
  for i = 1, N do
    local tt = i / fps
    frame(function()
      W.E:Hold("castTexture", 0.10, 0.70 * ((tt % 2.0) / 2.0))
      if every(i, 0.9, 3) then W.E:Set("lowHealthTexture", 0.7, 0.7, 0.05, true) end
      if every(i, 2.6, 17) then W.E:PlayMode("meleeHit", "THUD", 1.0) end
      if every(i, 0.45, 7) then W.E:PlayMode("uiTick", "TICK", 1.0) end
      if every(i, 0.5, 11) then W.E:Hold("locomotion", 0.35, 0.21, 0.045, true, BOOTs) end
    end)
  end
  return W.sends / 20
end
for _, fps in ipairs({ 60, 144, 240 }) do
  P(("WP5 cap: %3d fps  sends/s with cap %.0f, without cap %.0f"):format(fps, mix(fps), mix(fps, NOCAP)))
end
-- isolated tap from silence: rotor speed reached by end of the tap, OD on vs off (tau_m assumed)
for _, m in ipairs({ "BLIP", "IMPACT", "THUMP" }) do
  for _, tau in ipairs({ 0.040, 0.085 }) do
    local function run(extra)
      newWorld({ fps = 60, extra = extra })
      local s, fl, peak = 0, 0.125, 0
      for i = 1, 30 do
        local lo = frame(i == 1 and function() W.E:PlayMode("x", m, 1.0) end or nil)
        local d = math.max(0, (lo - fl) / (1 - fl))
        for _ = 1, 10 do s = s + (d - s) * (1 / 600) / tau end
        if s > peak then peak = s end
      end
      return peak
    end
    local off = run({ Low = { overdriveBoost = 1, coastCoeff = 0 } })
    local on = run({ Low = { coastCoeff = 0 } })
    local onC = run(nil)
    P(("OD isolated %-6s tau_m %3.0f ms: peak rotor speed (Low, rel.) no-OD %.3f | OD %.3f (%+.0f%%) | OD+coast %.3f (%+.0f%%)"):format(
      m, tau * 1000, off, on, 100 * (on / off - 1), onC, 100 * (onC / off - 1)))
  end
end
