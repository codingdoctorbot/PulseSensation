-- Pulse — Core/Engine.lua
--
-- The only file that calls C_GamePad. Several textures are legitimately felt at once (an
-- ambient cast hum with a crit thump over it), so this is a blended/smoothed model — named
-- layers, max-blend, low-pass smoothing — with Tremor's role/schema system on top, so
-- hardware that cannot drive both motors gets something sensible rather than half its
-- layers going silent. Tremor's own Haptics.lua ran one active cue with preempt-or-drop
-- arbitration: the right model for "a late buzz is misinformation", the wrong one for
-- texture.
--
-- Two kinds of layer:
--   discrete   — PlayMode() schedules a shape (Core/Modes.lua) as a timed sequence of
--                Set() calls under one name, then the layer expires on its own.
--   continuous — Hold() sets a short-lived layer that the CALLER re-arms every tick (or
--                every natural update, like UNIT_HEALTH) for as long as its state is true.
--                Stop calling and it decays within one refresh window — "gone the instant
--                the state ends".
--
-- CONFIRMED IN-GAME 2026-09-15: `math.lerp` does not exist on the live client — "attempt
-- to call a nil value" at the line that used it, on every OnUpdate tick once any layer was
-- active (Lua Errors/unfixedpulse.rtf). Hand-rolled arithmetic replaces it. The same fix
-- was applied preemptively to every `math.clamp` call in this addon (Modules/Movement.lua,
-- Modules/Flight.lua): identical unverified signature, and both would have failed the same
-- way the moment their trigger fired.
--
-- Every layer is role-space (low/high), never a literal channel — schema resolution happens
-- once per tick in OnUpdate, applied continuously rather than per mode-step.

local ADDON_NAME, Pulse = ...

local Engine = {}
Pulse.Engine = Engine

local layers = {} -- name -> { roles = {role -> magnitude}, endTime }
local rawHolds = {} -- channel -> { magnitude, endTime }, calibration probe only
local rampToken = 0 -- bumped to cancel an in-flight RampChannel sweep

-- Bumped by StopAll, first thing. Every scheduled callback in this file captures it and
-- refuses to run if it has moved, which is what makes StopAll mean what its name says.
--
-- WHY A SECOND TOKEN, when layerTokens and rampToken already exist: they answer a different
-- question. A layer token cancels ONE logical sequence — re-firing a cue while its previous
-- steps are in flight, so the old sequence stops editing a layer the new one owns — and
-- deliberately does not care about anything outside that layer. rampToken is the same idea
-- for the calibration sweep. Neither can express "everything scheduled before now is void",
-- which is exactly what StopAll is for.
--
-- What this deliberately does NOT do is stop a module re-arming a continuous cue on its
-- next tick. That is a fresh synchronous call, not stale scheduled work, and a texture
-- resuming when the controller comes back is correct.
local engineGeneration = 0
local layerTokens = {} -- name -> token, so PlayMode re-triggers cancel their own stale steps
local smoothedByChannel = {}
local lastSetByChannel = {}
local lastSentTimeByChannel = {}

local WATCHDOG_INTERVAL = 0.250 -- 250ms keep-alive heartbeat to prevent motor firmware sleep
local ROLES_LIST = { "low", "high", "ltrigger", "rtrigger" }

-- Scratch tables for OnUpdate blending (recycled via wipe to ensure zero GC in tight loops - Rule 4)
local frameRoleTotals = {}
local roleContinuousTotal = {}
local roleTransientTotal = {}
local roleHasTransient = {}
local channelHasTransient = {}
local frameTarget = {}

local deviceReady = false

local REFRESH_WINDOW = 0.35 -- Hold() layers expire this long after the last refresh

local function clamp01(v)
	if v < 0 then
		return 0
	end
	if v > 1 then
		return 1
	end
	return v
end

-- Frame-rate-independent smoothing (2026-09-21). The old model applied a fixed FRACTION of
-- the remaining distance per OnUpdate tick — ATTACK_RATE = 0.2, RELEASE_RATE = 0.45 — which
-- is not a time constant: the same cue decayed roughly four times faster at 144fps than at
-- 36fps, so every continuous texture and every mode's tail changed feel with frame rate.
-- The header's 2026-09-15 note blames the release rate for heartbeat knocks blurring
-- together, and this is a large part of why that was so hard to tune.
--
--   alpha = 1 - exp(-dt / tau)
--
-- `dt` is the elapsed argument OnUpdate is handed. tau is the time to close ~63% of the
-- gap. Core/Devices.lua seeds attackTau = 0.075 and releaseTau = 0.028, the exact taus
-- reproducing the old rates at 60fps, so this feels identical at 60 and correct everywhere
-- else. Per channel, because the low motor's large eccentric mass is genuinely slower than
-- the high motor's small one — one shared pair of numbers was always wrong on hardware.
local function smoothTowards(current, wanted, dt, attackTau, releaseTau)
	local tau = (wanted < current) and releaseTau or attackTau
	if not tau or tau <= 0 or not dt or dt <= 0 then
		return wanted
	end
	local alpha = 1.0 - math.exp(-dt / tau)
	if alpha >= 1 then
		return wanted
	end
	return current + (wanted - current) * alpha
end

-- Purely a "has everything gone quiet" test, feeding the decision to call StopVibration; it
-- never alters a value on its way to the motor. NOT a channel's `floor` (Core/Devices.lua),
-- which is an input remap lifting small values over the breakaway threshold. Different
-- mechanism, different side of the pipeline, and the two coexist.
local SILENCE_GATE = 0.004

-- Per-channel calibration, read live so a slider move is felt on the next frame with no
-- reload. Falls back to Devices.lua's defaults, every one of which is a no-op or an exact
-- lift of what the engine did before this layer existed.
local function channelConfig(channel, key)
	return Pulse.Database:GetChannelTuning(channel, key, Pulse.CHANNEL_DEFAULTS[key])
end

-- Role -> physical channel, with the fallback the trigger roles need. A schema naming no
-- mapping for a role — every schema written before trigger roles existed — sends trigger
-- roles to the rumble motor of matching character rather than dropping them: ltrigger
-- follows low, rtrigger follows high. A cue asking for a trigger is always felt as
-- SOMETHING, even on a pad with no trigger actuators.
local ROLE_FALLBACK = { ltrigger = "low", rtrigger = "high" }

local function resolveRole(schema, role)
	local roles = schema and schema.roles
	if not roles then
		return nil
	end
	local def = roles[role]
	if def then
		return def
	end
	local fallback = ROLE_FALLBACK[role]
	return fallback and roles[fallback] or nil
end

-- Device state (ported from Tremor/Core/Haptics.lua — same reasoning, same shape)

function Engine:RefreshDevice()
	if not C_GamePad or type(C_GamePad.IsEnabled) ~= "function" or type(C_GamePad.GetActiveDeviceID) ~= "function" then
		deviceReady = false
		self:StopAll()
		return
	end
	local okEnabled, enabled = pcall(C_GamePad.IsEnabled)
	local okID, deviceID = pcall(C_GamePad.GetActiveDeviceID)
	deviceReady = (okEnabled and enabled and okID and deviceID) and true or false
	if not deviceReady then
		self:StopAll()
	end
end

function Engine:IsDeviceReady()
	return deviceReady
end

function Engine:StopAll()
	-- First, so that anything already scheduled is void before the state it would touch
	-- is cleared.
	engineGeneration = engineGeneration + 1
	rampToken = (rampToken or 0) + 1
	self.activeRamp = nil
	layers = {}
	rawHolds = {}
	smoothedByChannel = {}
	lastSetByChannel = {}
	wipe(lastSentTimeByChannel)
	wipe(frameRoleTotals)
	wipe(roleContinuousTotal)
	wipe(roleTransientTotal)
	wipe(roleHasTransient)
	wipe(channelHasTransient)
	wipe(frameTarget)
	if C_GamePad and C_GamePad.StopVibration then
		pcall(C_GamePad.StopVibration)
	end
end

function Engine:_ActiveSchema()
	local id = Pulse.Database:Get("defaultHapticSchema")
	return Pulse.HapticSchemas[id] or Pulse.HapticSchemas["standard"]
end

-- Layer API — everything else in the addon goes through Set/Hold/PlayMode, never
-- C_GamePad directly.

-- Low-level: set (or refresh) a named layer's role-space target directly. How every module
-- in this addon talks to the engine. A layer carries a SPARSE role table rather than fixed
-- fields, so a four-role engine costs a two-role caller nothing — no zero-filled
-- ltrigger/rtrigger entries on the hundred-odd layers that will never use them.
-- Reused table to prevent GC allocation in high-frequency hold/tick loops (Rule 4).
local scratchRoles = { low = 0, high = 0 }

function Engine:Set(name, low, high, duration, isTransient)
	scratchRoles.low = low or 0
	scratchRoles.high = high or 0
	return self:SetRoles(name, scratchRoles, duration, isTransient)
end

-- The role-space entry point. `roles` is sparse: name only what this layer drives.
-- Recognised roles are "low", "high", "ltrigger", "rtrigger"; anything else is ignored by
-- the resolver rather than erroring, so a typo goes quiet instead of breaking a frame.
-- `isTransient`: true for sharp discrete clicks/impacts (fast ~10ms attack), false for
-- sustained immersion textures (smooth 75ms attack).
function Engine:SetRoles(name, roles, duration, isTransient)
	local layer = layers[name]
	if not layer then
		layer = { roles = {} }
		layers[name] = layer
	end
	local target = layer.roles
	-- Rewritten rather than merged: a layer refreshed each tick with a different role set
	-- must not keep yesterday's roles alive.
	for role in pairs(target) do
		target[role] = nil
	end
	for role, value in pairs(roles) do
		target[role] = clamp01(value or 0)
	end
	layer.endTime = GetTime() + (duration or 0.1)
	layer.isTransient = (isTransient == true)
end

-- Continuous hold: the caller re-invokes this every tick the state is true. Stop calling and
-- the layer expires within REFRESH_WINDOW on its own; no explicit stop needed.
--
-- `duration` defaults to REFRESH_WINDOW. It exists for callers wanting a single short-lived
-- blip rather than a layer a later tick keeps refreshing — Health.lua's lub-dub knocks,
-- where a duration shorter than the gap between them lets the value decay toward zero in
-- between instead of stepping from one held target straight to the next.
function Engine:Hold(name, low, high, duration)
	scratchRoles.low = low or 0
	scratchRoles.high = high or 0
	self:SetRoles(name, scratchRoles, duration or REFRESH_WINDOW, false)
end

-- Role-space sibling of Hold, existing so callers get REFRESH_WINDOW by default rather than
-- SetRoles' raw 0.1. Reaching SetRoles directly for a continuous cue is a trap: a duration
-- shorter than the caller's own re-arm interval expires between ticks and the texture
-- stutters, and an explicit 0 gives a layer already dead the moment it is created.
function Engine:HoldRoles(name, roles, duration)
	self:SetRoles(name, roles, duration or REFRESH_WINDOW, false)
end

function Engine:StopLayer(name)
	layers[name] = nil
end

-- StopLayer's stronger sibling: also bumps the layer's PlayMode token, so steps a previous
-- PlayMode already handed to C_Timer no-op when they fire instead of overwriting whatever is
-- set next. StopLayer alone clears the layer but leaves the token, and a scheduled step
-- re-Sets it a moment later. The per-cue preview button needs this — mashing it across a
-- discrete shape and then a continuous hold is exactly where a stale step lands on top.
function Engine:CancelLayer(name)
	layerTokens[name] = (layerTokens[name] or 0) + 1
	layers[name] = nil
end

-- Discrete shapes: Core/Modes.lua supplies the vocabulary. PlayMode schedules one shape's
-- steps as a sequence of Set() calls under `name`. A second PlayMode call on the same name
-- cancels the first mid-sequence via its own per-name token rather than interleaving.

function Engine:PlayMode(name, modeID, scale, intensityOverride)
	local mode = Pulse.Modes[modeID]
	if not mode then
		return
	end
	scale = scale or 1.0

	layerTokens[name] = (layerTokens[name] or 0) + 1
	local token = layerTokens[name]
	local generation = engineGeneration

	if mode.continuous then
		-- A discrete trigger asking for a continuous mode gets one held pulse at
		-- REFRESH_WINDOW length — a sample of the texture, not an infinite hold. Modules
		-- wanting the real held version call Hold() every tick themselves.
		--
		-- previewPattern (Core/Modes.lua) is the exception: PATTER/DRIFT's labels claim a
		-- time-varying quality a single flat Set() cannot demonstrate, so their preview
		-- schedules a real sequence. Every step re-checks layerTokens[name] == token, the
		-- same guard the discrete loop below uses, so mashing the test button cancels the
		-- previous sequence rather than interleaving.
		if mode.previewPattern == "jitter" then
			-- PATTER: brief low-motor blips at random offsets across ~1.2s rather than one
			-- steady hold, so it reads as irregular patter instead of a buzz.
			local magnitude = (mode.low or 0) * scale
			for _ = 1, 6 do
				local at = math.random() * 1.2
				local mag = magnitude * (0.5 + math.random() * 0.5)
				C_Timer.After(at, function()
					if engineGeneration ~= generation then
						return
					end
					if layerTokens[name] ~= token then
						return
					end
					self:Set(name, mag, 0, 0.08, true)
				end)
			end
			return
		end
		if mode.previewPattern == "fade" then
			-- DRIFT: an explicit 5-step ramp from near-zero to the mode's target across
			-- ~1s. The shared attack smoothing already ramps toward any target, but DRIFT's
			-- target is tiny (0.08) and that ramp completes in a handful of ticks — too
			-- fast to register as a deliberate fade. This makes the fade the thing being
			-- demonstrated rather than an incidental side effect of a small number.
			local target = (mode.low or 0) * scale
			local steps = 5
			for step = 1, steps do
				local at = (step - 1) * (1.0 / steps)
				local mag = target * (step / steps)
				C_Timer.After(at, function()
					if engineGeneration ~= generation then
						return
					end
					if layerTokens[name] ~= token then
						return
					end
					self:Set(name, mag, 0, REFRESH_WINDOW, false)
				end)
			end
			return
		end
		self:Set(name, (mode.low or 0) * scale, (mode.high or 0) * scale, REFRESH_WINDOW, false)
		return
	end

	-- Per-mode motor/duration tuning. durMult scales the WHOLE schedule — the on-pulses and
	-- the {gap} steps between them — not just baseDuration. STUTTER's gaps are fixed literal
	-- seconds, not derived from baseDuration, so scaling only the on-pulses would stretch
	-- each hit while the silences stayed fixed, and past some multiplier the hits would eat
	-- their own gaps and stop being distinct taps. Scaling everything preserves the mode's
	-- rhythm while changing its pace.
	local lowMult = Pulse.Database:GetModeTuning(modeID, "lowMult", 1.0)
	local highMult = Pulse.Database:GetModeTuning(modeID, "highMult", 1.0)
	local triggerMult = Pulse.Database:GetModeTuning(modeID, "triggerMult", 1.0)
	local durMult = Pulse.Database:GetModeTuning(modeID, "durMult", 1.0)

	local offset = 0
	for _, step in ipairs(mode.steps) do
		if step.gap then
			offset = offset + step.gap * durMult
		else
			local duration = step.relDuration * (mode.baseDuration or 0.25) * durMult
			local mag = clamp01(step.relIntensity * scale * (intensityOverride or 1.0))
			-- Sparse: a step names one role (or "both") and only that role is emitted.
			-- Low/high/trigger roles are scaled by their respective multiplier from the
			-- Motor & Timing page.
			local roles = {}
			local r = step.role
			if r == "both" then
				roles.low = clamp01(mag * lowMult)
				roles.high = clamp01(mag * highMult)
			elseif r == "high" then
				roles.high = clamp01(mag * highMult)
			elseif r == "ltrigger" or r == "rtrigger" then
				roles[r] = clamp01(mag * triggerMult)
			else
				roles.low = clamp01(mag * lowMult)
			end
			local at = offset
			C_Timer.After(at, function()
				if engineGeneration ~= generation then
					return
				end
				if layerTokens[name] ~= token then
					return
				end
				if not deviceReady then
					return
				end
				self:SetRoles(name, roles, duration, true)
			end)
			offset = offset + duration
		end
	end
end

-- OnUpdate: blend every live layer into role-space, resolve roles to physical channels
-- through the active schema (a schema that maps both roles to the same channel collapses
-- them there via max, same as two layers colliding on one channel), smooth with the local
-- `smoothTowards` helper above (slower attack, faster release), and only call SetVibration
-- when a channel's value actually moved.

-- Hoisted to file-scope to eliminate closure allocation on every OnUpdate frame tick (Rule 4).
local function driveChannel(channel, wanted, last, dt, epsilon, now, isTransient)
	if rawHolds[channel] then
		return false
	end

	if wanted and wanted > 0 then
		wanted = clamp01(wanted * channelConfig(channel, "gain"))
		local gamma = channelConfig(channel, "gamma")
		if gamma and gamma ~= 1.0 then
			wanted = wanted ^ gamma
		end
		local floor = channelConfig(channel, "floor")
		if floor and floor > 0 then
			wanted = floor + (1.0 - floor) * wanted
		end
		wanted = clamp01(wanted)
	else
		-- Zero in, zero out, unconditionally. The breakaway floor must never turn a
		-- silent channel into a permanently humming one.
		wanted = 0
	end

	-- Dual-lane adaptive smoothing:
	-- Transient impacts use fast transientAttackTau (10-12ms) for punchy, immediate tactile feedback.
	-- Continuous immersion textures use attackTau (75ms) for smooth, non-fatiguing rumble.
	local attackTau = isTransient and channelConfig(channel, "transientAttackTau")
		or channelConfig(channel, "attackTau")
	local releaseTau = channelConfig(channel, "releaseTau")

	local smoothed = smoothTowards(smoothedByChannel[channel] or 0, wanted, dt, attackTau, releaseTau)
	smoothedByChannel[channel] = smoothed

	local isOn = smoothed > SILENCE_GATE
	local delta = math.abs(smoothed - (last or -1))
	local timeSinceLast = now - (lastSentTimeByChannel[channel] or 0)

	-- Output watchdog: re-send vibration every WATCHDOG_INTERVAL (250ms) even if delta <= epsilon
	-- to prevent controller hardware firmware timeouts on steady continuous textures.
	if delta > epsilon or (isOn and timeSinceLast >= WATCHDOG_INTERVAL) then
		if C_GamePad and C_GamePad.SetVibration then
			pcall(C_GamePad.SetVibration, channel, smoothed)
		end
		lastSetByChannel[channel] = smoothed
		lastSentTimeByChannel[channel] = now
	end
	return isOn
end

local frame = CreateFrame("Frame")

local function onEngineTick(elapsed)
	if not deviceReady then
		return
	end
	-- Deliberately NOT gated on masterEnabled: normal triggers already will not set a layer
	-- while it is off (Pulse:FireIfEnabled/HoldIfEnabled check first), so this loop does
	-- nothing either way. But the panel's "Test the selected mode" button and /pulse test
	-- call PlayMode directly, and calibration has to work before the addon is switched on —
	-- requiring someone to enable an addon before finding out whether their controller
	-- vibrates at all is backwards.

	local now = GetTime()
	local dt = elapsed or 0
	-- A loading screen or an alt-tab can hand back an enormous elapsed. Capping it keeps
	-- the exponential honest rather than letting one frame snap every channel.
	if dt > 0.25 then
		dt = 0.25
	end

	-- Raw calibration holds bypass everything below — schema, gain, gamma, floor and
	-- smoothing — on purpose. The calibration page exists to MEASURE those, so its probe
	-- has to reach the motor unprocessed or it would be measuring its own corrections.
	local anyRaw = false
	for channel, hold in pairs(rawHolds) do
		if now >= hold.endTime then
			rawHolds[channel] = nil
			C_GamePad.SetVibration(channel, 0)
			lastSetByChannel[channel] = 0
			smoothedByChannel[channel] = 0
			lastSentTimeByChannel[channel] = 0
		else
			anyRaw = true
			local timeSinceLast = now - (lastSentTimeByChannel[channel] or 0)
			if
				math.abs(hold.magnitude - (lastSetByChannel[channel] or -1)) > 0
				or timeSinceLast >= WATCHDOG_INTERVAL
			then
				C_GamePad.SetVibration(channel, hold.magnitude)
				lastSetByChannel[channel] = hold.magnitude
				smoothedByChannel[channel] = hold.magnitude
				lastSentTimeByChannel[channel] = now
			end
		end
	end

	-- Blend every live layer into role-space, saturating sum for continuous immersion cues,
	-- with transients layered harmoniously on top without ducking or killing immersion.
	-- Recycled tables (wipe): zero allocation in high-frequency loop (Rule 4).
	wipe(frameRoleTotals)
	wipe(roleContinuousTotal)
	wipe(roleTransientTotal)
	wipe(roleHasTransient)
	wipe(channelHasTransient)

	local hasRoles = false
	for name, layer in pairs(layers) do
		if now >= layer.endTime then
			layers[name] = nil
		else
			local isTransient = layer.isTransient
			for role, value in pairs(layer.roles) do
				if value > 0 then
					hasRoles = true
					if isTransient then
						roleHasTransient[role] = true
						if value > (roleTransientTotal[role] or 0) then
							roleTransientTotal[role] = value
						end
					else
						-- Continuous immersion layering: saturating sum keeps textures alive together
						local existing = roleContinuousTotal[role] or 0
						roleContinuousTotal[role] = 1.0 - (1.0 - existing) * (1.0 - value)
					end
				end
			end
		end
	end

	-- Combine continuous immersion baseline with punchy transients.
	-- Immersion-first: continuous baseline is NEVER muted or ducked!
	-- Transients layer harmoniously on top:
	if hasRoles then
		for _, role in ipairs(ROLES_LIST) do
			local cont = roleContinuousTotal[role] or 0
			local trans = roleTransientTotal[role] or 0
			if trans > 0 and cont > 0 then
				-- Transient rides directly on top of the immersion baseline:
				frameRoleTotals[role] = clamp01(cont + trans * (1.0 - cont))
			elseif trans > 0 then
				frameRoleTotals[role] = clamp01(trans)
			elseif cont > 0 then
				frameRoleTotals[role] = clamp01(cont)
			end
		end
	end

	local masterIntensity = Pulse.Database:Get("masterIntensity") or 1.0
	local schema = Engine:_ActiveSchema()

	-- Role -> channel, collapsing collisions through schema routing.
	-- Recycled table (wipe): zero allocation in high-frequency loop.
	wipe(frameTarget)
	local hasTargets = false
	if hasRoles then
		for role, magnitude in pairs(frameRoleTotals) do
			local def = resolveRole(schema, role)
			if def and def.channel then
				local channelMag = clamp01(magnitude * masterIntensity * (def.intensity or 1.0))
				if channelMag > 0 then
					hasTargets = true
					if channelMag > (frameTarget[def.channel] or 0) then
						frameTarget[def.channel] = channelMag
					end
					if roleHasTransient[role] then
						channelHasTransient[def.channel] = true
					end
				end
			end
		end
	end

	local epsilon = Pulse.Database:GetChangeEpsilon()
	local anyOn = false

	if hasTargets then
		for channel, wanted in pairs(frameTarget) do
			if
				driveChannel(channel, wanted, lastSetByChannel[channel], dt, epsilon, now, channelHasTransient[channel])
			then
				anyOn = true
			end
		end
	end

	-- Channels that were on and now have no target at all need to decay too, not just
	-- channels present in this tick's `target` — walk everything we last set.
	for channel, last in pairs(lastSetByChannel) do
		if not (hasTargets and frameTarget[channel]) and last > 0 then
			if driveChannel(channel, 0, last, dt, epsilon, now, false) then
				anyOn = true
			end
		end
	end

	if not anyOn and not anyRaw and next(lastSetByChannel) then
		if C_GamePad and C_GamePad.StopVibration then
			pcall(C_GamePad.StopVibration)
		end
		wipe(smoothedByChannel)
		wipe(lastSetByChannel)
		wipe(lastSentTimeByChannel)
	end
end

local lastErrorTime = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	local ok, err = pcall(onEngineTick, elapsed)
	if not ok then
		Engine.lastError = tostring(err)
		Engine.errorCount = (Engine.errorCount or 0) + 1
		local now = GetTime()
		if now - lastErrorTime > 5.0 then
			lastErrorTime = now
			if Pulse and Pulse.debug then
				print("Pulse: Engine OnUpdate error: " .. tostring(err))
			end
		end
		if C_GamePad and C_GamePad.StopVibration then
			pcall(C_GamePad.StopVibration)
		end
		wipe(smoothedByChannel)
		wipe(lastSetByChannel)
		wipe(lastSentTimeByChannel)
	end
end)

function Engine:GetLastError()
	return self.lastError, self.errorCount or 0
end

-- Calibration probe. The addon cannot measure a motor; the person holding it can, so the
-- job here is to present an unprocessed, predictable stimulus and get out of the way.

-- Drive one channel at one magnitude for `duration`, bypassing schema routing and every
-- calibration transform. Used by the controller-calibration page.
function Engine:RawChannel(channel, magnitude, duration)
	self:RefreshDevice()
	if not deviceReady then
		return false, "no controller detected"
	end
	rawHolds[channel] = {
		magnitude = clamp01(magnitude or 0),
		endTime = GetTime() + (duration or 0.5),
	}
	return true
end

-- A slow linear climb on one channel, announcing where it has got to. How you find a
-- motor's breakaway floor without an oscilloscope: start it, wait until you first feel
-- anything, read the last number printed. Stepped rather than continuously swept, so the
-- printed figure and the sensation line up instead of the number having moved on by the
-- time you register the buzz.
--
-- Shape comes from Core/Devices.lua (RAMP_PEAK / RAMP_STEP / RAMP_STEP_SECONDS) rather than
-- being hardcoded — it is instrument calibration, the same kind of data as everything else
-- in that file.
function Engine:RampChannel(channel, peak)
	self:RefreshDevice()
	if not deviceReady then
		return false, "no controller detected"
	end

	peak = peak or Pulse.RAMP_PEAK
	local increment = Pulse.RAMP_STEP
	local interval = Pulse.RAMP_STEP_SECONDS
	local steps = math.max(1, math.floor(peak / increment + 0.5))

	rampToken = (rampToken or 0) + 1
	local token = rampToken
	local generation = engineGeneration

	print(
		("Pulse: ramping %s from 0 to %d%% in steps of %.3f, about %d seconds. Say when you FIRST feel anything and use the number on that line."):format(
			channel,
			math.floor(peak * 100 + 0.5),
			increment,
			math.floor(steps * interval + 0.5)
		)
	)

	for step = 1, steps do
		C_Timer.After((step - 1) * interval, function()
			if engineGeneration ~= generation then
				return
			end
			if rampToken ~= token then
				return
			end
			local magnitude = increment * step
			self.activeRamp = {
				channel = channel,
				magnitude = magnitude,
				step = step,
				steps = steps,
				token = token,
			}
			-- Held slightly longer than the interval so there is no silent gap between
			-- steps for the mass to coast down through — a gap would read as a pulse train
			-- rather than a climb, and you would feel the gaps instead of the threshold.
			Engine:RawChannel(channel, magnitude, interval + 0.15)
			print(("Pulse: %s  %.3f   (%d/%d)"):format(channel, magnitude, step, steps))
		end)
	end

	C_Timer.After(steps * interval, function()
		if engineGeneration ~= generation then
			return
		end
		if rampToken ~= token then
			return
		end
		-- Stop the PROBE, not everything. StopAll clears every layer, both smoothing tables
		-- and the whole raw-hold set, so finishing a sixteen-second ramp through it would
		-- cut every live gameplay cue — a swim or glide texture running at the time goes
		-- silent until its next Hold refresh.
		if self.activeRamp and self.activeRamp.token == token then
			self.activeRamp = nil
		end
		Engine:_StopRawChannel(channel)
		print("Pulse: ramp finished. Enter the value you first felt as this channel's Breakaway floor.")
	end)
	return true
end

function Engine:GetActiveRamp()
	return self.activeRamp
end

-- What the calibration page's Test button calls. Distinct from RawChannel because a ramp
-- drives RawChannel internally every step — if RawChannel cancelled ramps it would cancel
-- its own. Pressing Test during a ramp should stop the ramp, so that lives here.
function Engine:ProbeChannel(channel, magnitude, duration)
	rampToken = (rampToken or 0) + 1
	self.activeRamp = nil
	return self:RawChannel(channel, magnitude, duration)
end

-- Releases one channel's raw hold and silences just that channel. Used by the ramp's own
-- terminator and by StopRamp; neither has business stopping the rest of the addon.
--
-- Nothing currently calls StopRamp: the calibration page's Test button interrupts a ramp
-- through ProbeChannel, which bumps rampToken so the remaining timers no-op and then drives
-- the channel itself. StopRamp is kept as the explicit "stop and go quiet" that
-- ProbeChannel is not.
function Engine:_StopRawChannel(channel)
	rawHolds[channel] = nil
	smoothedByChannel[channel] = nil
	lastSetByChannel[channel] = nil
	if deviceReady and C_GamePad and C_GamePad.SetVibration then
		pcall(C_GamePad.SetVibration, channel, 0)
	end
end

function Engine:StopRamp(channel)
	rampToken = (rampToken or 0) + 1
	self.activeRamp = nil
	if channel then
		self:_StopRawChannel(channel)
	else
		-- No channel named: the caller does not know which ramp is running, so every
		-- raw hold goes. Still narrower than StopAll, which would take the layers too.
		for name in pairs(rawHolds) do
			self:_StopRawChannel(name)
		end
	end
end

function Engine:Init()
	local deviceFrame = CreateFrame("Frame")
	deviceFrame:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
	deviceFrame:RegisterEvent("GAME_PAD_CONNECTED")
	deviceFrame:RegisterEvent("GAME_PAD_DISCONNECTED")
	deviceFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	deviceFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
	deviceFrame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LEAVING_WORLD" then
			Engine:StopAll()
			return
		end
		Engine:RefreshDevice()
	end)
	local function sync()
		if not Pulse.Database:Get("masterEnabled") then
			Engine:StopAll()
			return
		end
		Engine:RefreshDevice()
	end
	Pulse.Database:OnGlobalChanged("masterEnabled", sync)
	sync()
end

-- Debug accessors — read-only, type-checked at the call site. Nothing but PulseDebug/
-- Debug.lua should call these; they exist because `layers`, `smoothedByChannel` and
-- `lastSetByChannel` are upvalues, and "what is actually blending into the channel right
-- now" has no other way to be observed from outside.

-- Snapshot list of {name, low, high, remaining} for every live layer, remaining in seconds.
-- A copy, not the live table, so a debug command can walk it without risking a concurrent
-- modification if OnUpdate fires mid-iteration.
function Engine:_DebugLayers()
	local now = GetTime()
	local snapshot = {}
	for name, layer in pairs(layers) do
		snapshot[#snapshot + 1] = {
			name = name,
			low = layer.roles.low,
			high = layer.roles.high,
			ltrigger = layer.roles.ltrigger,
			rtrigger = layer.roles.rtrigger,
			remaining = layer.endTime - now,
		}
	end
	return snapshot
end

-- Returns {channel -> {smoothed, lastSet}} for every physical channel the engine has ever
-- driven this session.
function Engine:_DebugChannels()
	local snapshot = {}
	for channel, smoothed in pairs(smoothedByChannel) do
		snapshot[channel] = { smoothed = smoothed, lastSet = lastSetByChannel[channel] }
	end
	for channel, lastSet in pairs(lastSetByChannel) do
		if not snapshot[channel] then
			snapshot[channel] = { smoothed = smoothedByChannel[channel], lastSet = lastSet }
		end
	end
	return snapshot
end
