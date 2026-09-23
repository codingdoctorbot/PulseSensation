-- Pulse — Modules/Movement.lua
--
-- alphafeatures.md G1 (falling/landing, scored by fall duration), G3 (swimming
-- resistance), G16 (taxi as a bracketed ambient window).
--
-- Landing and swimming both need an OnUpdate poll. That frame is registered only while at
-- least one trigger needing it is enabled, so the addon costs nothing when they are off.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Movement", M)

local pollFrame = CreateFrame("Frame")
local fallStartTime = nil
local wasFalling, wasFlying = false, false
-- CONFIRMED 2026-09-16: raw GetUnitSpeed updates in coarse, discrete jumps rather than
-- smoothly, which is what produced a felt pause that survived both the wobble-shape and the
-- hysteresis fixes — neither smoothed the ratio itself. This does: an exponential catch-up
-- applied one layer before HoldIfEnabled sees it, absorbing a jump in the raw data into a
-- gradual slide.
local smoothedSwimRatio = 0

local HARD_LANDING_AIRTIME = 2.5
local SOFT_LANDING_AIRTIME = 0.8

-- Recycled role tables to prevent GC allocation in pollLandingAndSwim loop (Rule 4)
local staticLowRole = { low = 0 }
local staticHighRole = { high = 0 }
local staticOceanRole = { low = 0, high = 0 }

local TWO_PI = math.pi * 2
local isOceanZone = false
local isFatigueWater = false
local zoneFrame = CreateFrame("Frame")

local function safeGetText(fn)
	if type(fn) ~= "function" then
		return ""
	end
	local ok, text = pcall(fn)
	if ok and text and not issecretvalue(text) and type(text) == "string" then
		return text
	end
	return ""
end

local function updateOceanZone()
	local subZone = safeGetText(GetSubZoneText)
	local zone = safeGetText(GetZoneText)
	local minimapZone = safeGetText(GetMinimapZoneText)

	local combined = (subZone .. " " .. zone .. " " .. minimapZone):lower()

	if
		combined:find("sea")
		or combined:find("ocean")
		or combined:find("coast")
		or combined:find("shore")
		or combined:find("bay")
		or combined:find("cove")
		or combined:find("beach")
		or combined:find("tide")
		or combined:find("deep")
		or combined:find("abyssal")
		or combined:find("reef")
		or combined:find("cape")
		or combined:find("gulf")
		or combined:find("channel")
		or combined:find("strait")
		or combined:find("sound")
		or combined:find("fjord")
		or combined:find("harbor")
		or combined:find("port")
	then
		isOceanZone = true
	else
		isOceanZone = false
	end
end

zoneFrame:SetScript("OnEvent", function(_, event, timerName)
	if event == "MIRROR_TIMER_START" then
		if timerName == "EXHAUSTION" then
			isFatigueWater = true
		end
	elseif event == "MIRROR_TIMER_STOP" then
		if timerName == "EXHAUSTION" then
			isFatigueWater = false
		end
	else
		updateOceanZone()
	end
end)

-- Hand-rolled, not the native math.clamp — CONFIRMED missing on the live client
-- (Core/Engine.lua's math.lerp failed the same way). Lua Errors/unfixedpulse.rtf.
local function clamp01(v)
	if v < 0 then
		return 0
	end
	if v > 1 then
		return 1
	end
	return v
end

-- combat-detection.md §3: fires "jumped" from the same hook that seeds fallStartTime rather
-- than adding a second. FireIfEnabled checks masterEnabled and the cue itself, so this is
-- free while the cue is off, and one timestamp write is cheap enough to leave
-- unconditional.
if type(hooksecurefunc) == "function" and type(_G.JumpOrAscendStart) == "function" then
	hooksecurefunc("JumpOrAscendStart", function()
		fallStartTime = GetTime()
		Pulse:FireIfEnabled("jumped")
	end)
end

local function pollLandingAndSwim(_, elapsed)
	local falling, flying = IsFalling(), IsFlying()

	-- A fall not started by a jump — walked off a ledge, knocked back, dismounted mid-air
	-- — never fires JumpOrAscendStart, so without this the cue only ever fired for
	-- jump-initiated falls. Falling turning true with nothing already marking a start
	-- covers every other case. The jump hook still wins when it fires, by being earlier:
	-- IT ALSO CAPTURES THE ASCENT, WHICH IsFalling() DOES NOT COUNT AS FALLING.
	if falling and not wasFalling and not fallStartTime then
		fallStartTime = GetTime()
	end

	if (wasFalling and not falling) or (wasFlying and not flying and not falling) then
		if fallStartTime then
			local airTime = GetTime() - fallStartTime
			if airTime > HARD_LANDING_AIRTIME then
				Pulse:FireIfEnabled("landingHard")
			elseif airTime > SOFT_LANDING_AIRTIME then
				Pulse:FireIfEnabled("landingSoft")
			end
		elseif wasFlying and not flying and not falling then
			Pulse:FireIfEnabled("landingSoft")
		end
		fallStartTime = nil
	end
	wasFalling, wasFlying = falling, flying

	-- ── In water ───────────────────────────────────────────────────────────────
	-- Two independent layers since 2026-09-21, with the engine's max blend doing the
	-- crossover: floating gives ambient only, swimming hard lets effort rise past it and
	-- dominate, ambient never disappears and nothing swaps formula. No threshold and
	-- therefore no hysteresis — effort scales from the speed ratio, already zero at rest.
	-- One cue doing both jobs through an if/else on a speed threshold is what made seven
	-- rounds of tuning fail to settle: one set of knobs describing two sensations.
	if IsSwimming() then
		local wantAmbient = Pulse.Database:GetCue("waterTexture")
		local wantEffort = Pulse.Database:GetCue("swimTexture")
		local wantOcean = Pulse.Database:GetCue("oceanTexture")

		if wantAmbient or wantEffort or wantOcean then
			local current, _, _, swimSpeed = GetUnitSpeed("player")
			-- RULE B, kept verbatim from the pre-split code and earned the hard way: a
			-- real live error repeated 766 times. GetUnitSpeed can return secret values,
			-- especially in combat (C_Secrets.ShouldUnitStatsBeSecret) and COMPARING a
			-- secret throws rather than reading as nil. Guarded before either value is
			-- touched; if secret, effort goes quiet for this tick (RULE E) — but ambient
			-- does not, because it never reads speed at all. One more thing the split
			-- buys: being in water still feels like being in water while your speed is
			-- unreadable.
			local speedReadable = not issecretvalue(current) and not issecretvalue(swimSpeed)

			-- Ambient: you are IN water. Buoyancy, not effort. Slow, near-subliminal, and
			-- present whether or not you are going anywhere.
			if wantAmbient then
				local baseline = Pulse.Database:GetTriggerSetting("waterTexture", "baseline", 0.04)
				local rate = Pulse.Database:GetTriggerSetting("waterTexture", "waveRate", 0.15)
				-- 0.0, matching Core/Registry.lua's declared default. It was 0.40 here,
				-- which meant any path reaching an unseeded profile turned the swell on
				-- at 40% — the exact thing that registry entry's comment forbids, since a
				-- rolling swell suggests ocean and this cue fires in rivers too.
				local depth = Pulse.Database:GetTriggerSetting("waterTexture", "waveDepth", 0.0)

				-- Fully under feels heavier than bobbing at the surface. IsSubmerged is
				-- confirmed present in the client's API list; if it ever is not, or throws,
				-- ambient stays flat and loses nothing (RULE E).
				local boost = Pulse.Database:GetTriggerSetting("waterTexture", "submergedBoost", 1.5)
				if boost ~= 1.0 and type(IsSubmerged) == "function" then
					local ok, under = pcall(IsSubmerged)
					-- Guard BEFORE the truthiness test, not after. IsSubmerged returns
					-- a boolean, and a secret boolean throws when evaluated rather than
					-- reading as nil — which is the 766-repeat failure this file's own
					-- RULE B comment above is about. Every other read in this addon
					-- orders it this way; this one did not.
					if ok and not issecretvalue(under) and under then
						baseline = baseline * boost
					end
				end

				-- The shape every new continuous cue in this addon should copy: decide a
				-- baseline from state, hand it to a wave, keep the output alive. The old
				-- idle branch swung to TRUE ZERO every ~5.2s, so the motor actually cut
				-- out while floating — MicroFlutter plus the calibration layer's breakaway
				-- floor is the proper fix for that, rather than the hand-rolled floor the
				-- moving branch used to carry.
				local value = Pulse.Waves.Sine(baseline, rate, depth)
				value = Pulse.Haptics.MicroFlutter(value)
				-- LOW role, and the pairing with effort's HIGH below is the whole point.
				-- Splitting the cue in two was not enough on its own: both layers used to
				-- emit on `low`, so they landed on one motor and the engine max-blended
				-- them. Two consequences, both felt. A 0.15Hz swell and a 0.5-1Hz stroke
				-- max()-ed together produce an irregular envelope rather than two
				-- sensations — they beat, worst around the speed where their amplitudes
				-- cross. And at full swimming speed max(0.04, 0.12) is simply the stroke,
				-- so the ambient layer contributed nothing exactly when you are most
				-- surrounded by water.
				--
				-- The large eccentric mass is also the right actuator for this: slow to
				-- spin up, slow to coast down, which is what buoyancy feels like.
				staticLowRole.low = value
				Pulse:HoldRolesIfEnabled("waterTexture", staticLowRole)
			end

			-- Ocean swell: oceanic gravity swells and coastal wave surges.
			-- Real fluid wave physics via second-harmonic Stokes drift shaping on the heavy
			-- motor, with crisp surface froth and spray on the high motor at peak crest.
			if wantOcean then
				local oceanOnly = Pulse.Database:GetTriggerSetting("oceanTexture", "oceanOnly", 1) == 1
				if not oceanOnly or isOceanZone or isFatigueWater then
					local strength = Pulse.Database:GetTriggerSetting("oceanTexture", "swellStrength", 0.14)
					local period = Pulse.Database:GetTriggerSetting("oceanTexture", "swellPeriod", 9.0)
					local harmonic = Pulse.Database:GetTriggerSetting("oceanTexture", "harmonicCrest", 0.35)
					local spray = Pulse.Database:GetTriggerSetting("oceanTexture", "surfaceSpray", 0.08)

					local freq = (period > 0) and (1.0 / period) or 0.11
					local now = GetTime()

					-- Heave displacement: ±75% wave swing around baseline strength.
					-- Stokes drift asymmetric shaping (h = 0.35) produces a steep rise and long trough.
					local swellValue = Pulse.Waves.Harmonic(strength, freq, 0.75, harmonic, 0, 0, now)
					swellValue = Pulse.Haptics.MicroFlutter(swellValue)
					staticOceanRole.low = swellValue

					-- Surface spray & froth:
					-- Shimmers on the high motor during the upper crest of the wave (sin(theta) > 0.5).
					-- Fades out when submerged underwater.
					local sprayValue = 0
					if spray > 0 then
						local isUnder = false
						if type(IsSubmerged) == "function" then
							local ok, under = pcall(IsSubmerged)
							if ok and not issecretvalue(under) and under then
								isUnder = true
							end
						end

						if not isUnder then
							local theta = TWO_PI * freq * now
							local crestFactor = math.sin(theta)
							if crestFactor > 0.5 then
								local crestIntensity = (crestFactor - 0.5) * 2.0
								sprayValue = Pulse.Haptics.MicroFlutter(spray * crestIntensity)
							end
						end
					end
					staticOceanRole.high = sprayValue

					Pulse:HoldRolesIfEnabled("oceanTexture", staticOceanRole)
				end
			end

			-- Effort: you are working AGAINST water. Scales with how fast you are actually
			-- moving relative to your own swim speed.
			if wantEffort and speedReadable and current and swimSpeed and swimSpeed > 0 then
				local targetRatio = clamp01(current / swimSpeed)
				-- Raw GetUnitSpeed updates in coarse jumps; this absorbs them into a slide.
				-- The fresh-entry snap is kept: without it, relogging mid-swim at speed
				-- would fade in from a stale zero over the smoothing window instead of
				-- matching what the player is actually doing. Frame-rate independent (tau = 0.075s).
				if smoothedSwimRatio <= 0 and targetRatio > 0 then
					smoothedSwimRatio = targetRatio
				else
					local dt = elapsed or 0.016
					if dt > 0.25 then
						dt = 0.25
					end
					local alpha = 1.0 - math.exp(-dt / 0.075)
					smoothedSwimRatio = smoothedSwimRatio + (targetRatio - smoothedSwimRatio) * alpha
				end
				local ratio = smoothedSwimRatio

				if ratio > 0.01 then
					local peak = Pulse.Database:GetTriggerSetting("swimTexture", "peak", 0.10)
					local strokeMin = Pulse.Database:GetTriggerSetting("swimTexture", "strokeRateMin", 0.45)
					local strokeMax = Pulse.Database:GetTriggerSetting("swimTexture", "strokeRateMax", 0.95)
					local depth = Pulse.Database:GetTriggerSetting("swimTexture", "strokeDepth", 0.55)
					local harmonic = Pulse.Database:GetTriggerSetting("swimTexture", "strokeAsymmetry", 0.35)

					-- The one real change of character, and the reason to expect this to
					-- succeed where six earlier rounds felt "rough". Every previous version
					-- was amplitude modulation of a constant — a swell. A swim stroke is not
					-- a swell, it is pull, glide, pull: hard on one side of the cycle, soft
					-- on the other. A pure sine cannot express that asymmetry; a second
					-- harmonic can, which is exactly what Waves.Harmonic exists for.
					--
					-- Stroke rate rises with speed too, so swimming faster strokes faster
					-- rather than merely harder.
					local rate = strokeMin + (strokeMax - strokeMin) * ratio
					local value = Pulse.Waves.Harmonic(peak * ratio, rate, depth, harmonic, 1.2)

					-- HIGH role, which reverses an earlier decision — and the reason it is
					-- now safe is the calibration layer.
					--
					-- The old code deliberately kept swimming off `high`, because `high`
					-- resolves to the physically STRONGER motor under Standard and there
					-- was no way to trim it; that is what made swimming feel loud and
					-- choppy in 2026-09-16 testing. Core/Devices.lua now gives every
					-- channel its own Strength slider, so an over-loud motor is a knob
					-- rather than a reason to avoid a channel entirely.
					--
					-- And the small fast mass is the right actuator for a stroke: it can
					-- start and stop inside one pull, which the large one cannot. Buoyancy
					-- on the slow motor, effort on the quick one, one sensation each, no
					-- max-blend collision between them.
					--
					-- separateMotors = false puts it back on `low` beside the ambient
					-- layer, for anyone whose high motor is unbearable or dead.
					if Pulse.Database:GetTriggerSetting("swimTexture", "separateMotors", 1) == 1 then
						staticHighRole.high = value
						Pulse:HoldRolesIfEnabled("swimTexture", staticHighRole)
					else
						staticLowRole.low = value
						Pulse:HoldRolesIfEnabled("swimTexture", staticLowRole)
					end
				end
			elseif not wantEffort then
				smoothedSwimRatio = 0
			end
		end
	else
		smoothedSwimRatio = 0
	end
end

local function syncPoll()
	local needed = Pulse.Database:Get("masterEnabled")
		and (
			Pulse.Database:GetCue("landingSoft")
			or Pulse.Database:GetCue("landingHard")
			or Pulse.Database:GetCue("swimTexture")
			or Pulse.Database:GetCue("waterTexture")
			or Pulse.Database:GetCue("oceanTexture")
		)
	pollFrame:SetScript("OnUpdate", needed and pollLandingAndSwim or nil)
end

-- Taxi: bracketed by PLAYER_CONTROL_LOST/GAINED, filtered to UnitOnTaxi so fear and other
-- control-loss cases don't light this up too.

local taxiFrame = CreateFrame("Frame")
local onTaxiRide = false
-- Bumped by syncTaxi and by PLAYER_CONTROL_GAINED, so a deferred UnitOnTaxi check from an
-- earlier PLAYER_CONTROL_LOST cannot re-arm the texture after the ride ended or the cue was
-- switched off (2026-09-21). Without it, disabling taxiRide inside the 0.1s window left an
-- OnUpdate running all session with no registered event left to stop it.
local taxiToken = 0

-- continuous.md §2: a sine oscillator rather than one flat value. Sustained constant
-- vibration fades from perception within a second or two, so a slow wingbeat-like
-- undulation reads as alive over a multi-minute flight where a flat drone goes numb.
-- Standardized onto Pulse.Waves.Sine and kept alive across crests with MicroFlutter.
local function taxiTick()
	if onTaxiRide then
		local amplitude = Pulse.Database:GetTriggerSetting("taxiRide", "windAmplitude", 0.1)
		local cycleSeconds = Pulse.Database:GetTriggerSetting("taxiRide", "waveCycleSeconds", 1.75)
		local frequency = (cycleSeconds > 0) and (1.0 / cycleSeconds) or 0.57
		-- Oscillates ±33% around a 0.75 baseline (range: 0.5 * amp .. 1.0 * amp)
		local value = Pulse.Waves.Sine(amplitude * 0.75, frequency, 0.33)
		value = Pulse.Haptics.MicroFlutter(value)
		Pulse:HoldIfEnabled("taxiRide", value, value)
	end
end

local function syncTaxi()
	taxiToken = taxiToken + 1
	taxiFrame:UnregisterAllEvents()
	onTaxiRide = false
	taxiFrame:SetScript("OnUpdate", nil)
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if
		not (
			Pulse.Database:GetCue("taxiRide")
			or Pulse.Database:GetCue("taxiTakeoff")
			or Pulse.Database:GetCue("taxiLanding")
		)
	then
		return
	end
	taxiFrame:RegisterEvent("PLAYER_CONTROL_LOST")
	taxiFrame:RegisterEvent("PLAYER_CONTROL_GAINED")
	-- Seed from live state: if already on a flight path, preserve vibration rather than going silent
	if UnitOnTaxi and UnitOnTaxi("player") then
		onTaxiRide = true
		if Pulse.Database:GetCue("taxiRide") then
			taxiFrame:SetScript("OnUpdate", taxiTick)
		end
	end
end

-- RULE A habit kept even though these events carry no restricted payload: no varargs.
taxiFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_CONTROL_LOST" then
		-- Deferred: UnitOnTaxi does not read true at the instant control is lost. Token
		-- guarded so the check is abandoned if anything cancelled the ride meanwhile.
		taxiToken = taxiToken + 1
		local token = taxiToken
		C_Timer.After(0.1, function()
			if taxiToken ~= token then
				return
			end
			if UnitOnTaxi and UnitOnTaxi("player") then
				local wasRiding = onTaxiRide
				onTaxiRide = true
				if not wasRiding then
					Pulse:FireIfEnabled("taxiTakeoff")
				end
				if Pulse.Database:GetCue("taxiRide") then
					taxiFrame:SetScript("OnUpdate", taxiTick)
				end
			end
		end)
	elseif event == "PLAYER_CONTROL_GAINED" then
		taxiToken = taxiToken + 1
		if onTaxiRide then
			Pulse:FireIfEnabled("taxiLanding")
		end
		onTaxiRide = false
		taxiFrame:SetScript("OnUpdate", nil)
	end
end)

-- Shapeshift form — GetShapeshiftForm()/UPDATE_SHAPESHIFT_FORM, player's own state, no
-- secrecy concern. One generic occurrence cue for any change, not split by direction —
-- forms chain (Bear -> Cat -> Moonkin without passing back through caster form), so
-- mountUp/dismount's two-cue shape doesn't map cleanly here the way it does for mounting.

local formFrame = CreateFrame("Frame")
local lastForm = nil

local function syncForm()
	formFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not Pulse.Database:GetCue("formChanged") then
		return
	end
	lastForm = GetShapeshiftForm()
	formFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
end

formFrame:SetScript("OnEvent", function()
	local current = GetShapeshiftForm()
	if current ~= lastForm then
		lastForm = current
		Pulse:FireIfEnabled("formChanged")
	end
end)

function M:OnEnable()
	Pulse:BindFrame({ "landingSoft", "landingHard", "swimTexture", "waterTexture", "oceanTexture" }, syncPoll)
	Pulse:BindFrame({ "taxiRide", "taxiTakeoff", "taxiLanding" }, syncTaxi)
	Pulse:BindFrame({ "formChanged" }, syncForm)

	zoneFrame:RegisterEvent("ZONE_CHANGED")
	zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	zoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
	zoneFrame:RegisterEvent("MINIMAP_UPDATE_SUBZONE")
	zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	zoneFrame:RegisterEvent("MIRROR_TIMER_START")
	zoneFrame:RegisterEvent("MIRROR_TIMER_STOP")
	updateOceanZone()
end

function M:_DebugMovement()
	return {
		onTaxiRide = onTaxiRide,
		wasFalling = wasFalling,
		wasFlying = wasFlying,
		smoothedSwimRatio = smoothedSwimRatio,
		shapeshiftForm = lastForm,
		isOceanZone = isOceanZone,
		isFatigueWater = isFatigueWater,
	}
end
