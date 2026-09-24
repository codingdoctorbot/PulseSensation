-- Pulse — Modules/Environment.lua
--
-- alphafeatures.md G2 (underwater breath, MIRROR_TIMER_START/"BREATH", drowning damage)
-- and G14 (weather, C_Weather/WEATHER_CHANGED, continuous weather texture).

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Environment", M)

-- Breath: MIRROR_TIMER_START("BREATH") brackets a countdown. Its payload (timerName, value,
-- maxValue, scale) is the player's own environment state, not a restricted unit read, so no
-- RULE A concern.
--
-- Drowning damage / suffocation occurs when breath depletes to 0 while remaining underwater.
-- Continuous breathTexture panics towards zero and holds heavy choking pulses while drowning,
-- accompanied by discrete drowningDamage thuds.

local function lerp(from, to, factor)
	return from + (to - from) * factor
end

-- Helper to check if player is submerged or in water without throwing secret value errors (RULE B)
local function isPlayerSubmerged()
	if type(IsSubmerged) == "function" then
		local ok, under = pcall(IsSubmerged)
		if ok and not issecretvalue(under) then
			return under and true or false -- Authoritative: false when floating at surface
		end
	end
	-- Fallback only if IsSubmerged is missing or threw error
	if type(IsSwimming) == "function" then
		local ok, swim = pcall(IsSwimming)
		if ok and not issecretvalue(swim) and swim then
			return true
		end
	end
	return false
end

local breathFrame = CreateFrame("Frame")
local breathTicker = nil
local warnedLowBreath = false
local breathMaxValue = nil
local lastGasp = 0
local lastRemaining = nil
local DEPLETED = 0.05
local isDrowning = false
local lastDrownDamageTime = 0

local function stopBreathTicker()
	if breathTicker then
		breathTicker:Cancel()
		breathTicker = nil
	end
	warnedLowBreath = false
	breathMaxValue = nil
	lastGasp = 0
	lastRemaining = nil
	isDrowning = false
	lastDrownDamageTime = 0
end

local function startBreathTicker(maxValue)
	stopBreathTicker()
	breathMaxValue = maxValue
	lastRemaining = nil
	isDrowning = false

	-- 0.1s poll for breath depletion and drowning state
	breathTicker = C_Timer.NewTicker(0.1, function()
		if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
			stopBreathTicker()
			return
		end

		local submerged = isPlayerSubmerged()

		-- Check drowning state
		if isDrowning then
			if not submerged then
				-- Player surfaced! Play relief gasp and stop.
				isDrowning = false
				Pulse:HoldIfEnabled("breathTexture", 0.4, 0.4, 0.15)
				stopBreathTicker()
				return
			end

			-- In drowning mode: suffocation damage tick every 1.5s
			local now = GetTime()
			local drownInterval = Pulse.Database:GetTriggerSetting("breathTexture", "drownInterval", 1.5)
			if now - lastDrownDamageTime >= drownInterval then
				lastDrownDamageTime = now
				local drownPeak = Pulse.Database:GetTriggerSetting("breathTexture", "drownPeak", 0.85)
				Pulse:HoldIfEnabled("breathTexture", drownPeak, drownPeak, 0.20)
				Pulse:FireIfEnabled("drowningDamage")
			end
			return
		end

		if not breathMaxValue or breathMaxValue <= 0 then
			return
		end
		local current = GetMirrorTimerProgress("BREATH")

		-- Mirror timer expired or reached 0
		if not current or current <= 0 then
			-- If still submerged, transition into drowning only if breath was depleted!
			if submerged and lastRemaining and lastRemaining <= DEPLETED then
				isDrowning = true
				lastDrownDamageTime = 0 -- fire immediate first drowning pulse
			else
				stopBreathTicker()
			end
			return
		end

		local remaining = current / breathMaxValue
		lastRemaining = remaining
		if remaining < 0.25 and not warnedLowBreath then
			Pulse:FireIfEnabled("breathWarning")
			warnedLowBreath = true
		end

		local startThreshold = Pulse.Database:GetTriggerSetting("breathTexture", "dangerStartThreshold", 0.70)
		if remaining < startThreshold then
			local midThreshold = Pulse.Database:GetTriggerSetting("breathTexture", "midBreathThreshold", 0.40)
			local lateThreshold = Pulse.Database:GetTriggerSetting("breathTexture", "lateBreathThreshold", 0.15)
			local heartRateCalm = Pulse.Database:GetTriggerSetting("breathTexture", "heartRateCalm", 30)
			local heartRateCritical = Pulse.Database:GetTriggerSetting("breathTexture", "heartRateCritical", 100)
			local MID_RATE, LATE_RATE = 40, 65

			local heartRate
			if remaining >= midThreshold then
				local segProgress = (startThreshold - remaining) / (startThreshold - midThreshold)
				heartRate = lerp(heartRateCalm, MID_RATE, segProgress)
			elseif remaining >= lateThreshold then
				local segProgress = (midThreshold - remaining) / (midThreshold - lateThreshold)
				heartRate = lerp(MID_RATE, LATE_RATE, segProgress)
			else
				local segProgress = (lateThreshold - remaining) / lateThreshold
				heartRate = lerp(LATE_RATE, heartRateCritical, segProgress)
			end

			local gap = 60 / heartRate
			local now = GetTime()
			if now - lastGasp >= gap then
				lastGasp = now
				local peak = Pulse.Database:GetTriggerSetting("breathTexture", "gaspPeak", 0.6)
				local lub = peak
				local dub = peak * (0.2 / 0.7)
				Pulse:HoldIfEnabled("breathTexture", lub, lub, 0.05)
				C_Timer.After(0.36, function()
					Pulse:HoldIfEnabled("breathTexture", dub, dub, 0.05)
				end)
			end
		end
	end)
end

local function syncBreath()
	breathFrame:UnregisterAllEvents()
	if not Pulse.Database:Get("masterEnabled") then
		stopBreathTicker()
		return
	end
	if
		not (
			Pulse.Database:GetCue("breathWarning")
			or Pulse.Database:GetCue("breathTexture")
			or Pulse.Database:GetCue("drowningDamage")
		)
	then
		stopBreathTicker()
		return
	end
	breathFrame:RegisterEvent("MIRROR_TIMER_START")
	breathFrame:RegisterEvent("MIRROR_TIMER_STOP")
	breathFrame:RegisterEvent("PLAYER_DEAD")

	-- Seed from live state: if already underwater and breath is draining, resume rather than going silent
	if not breathTicker and type(GetMirrorTimerProgress) == "function" then
		local current = GetMirrorTimerProgress("BREATH")
		if current and current > 0 then
			local maxVal = nil
			if type(GetMirrorTimerInfo) == "function" then
				for i = 1, 3 do
					local timer, _, mVal = GetMirrorTimerInfo(i)
					if timer == "BREATH" and mVal and mVal > 0 then
						maxVal = mVal
						break
					end
				end
			end
			local m = maxVal or math.max(current, 30000)
			startBreathTicker(m)
			lastRemaining = current / m
		end
	end
end

breathFrame:SetScript("OnEvent", function(_, event, timerName, value, maxValue)
	if event == "PLAYER_DEAD" then
		stopBreathTicker()
		return
	end
	if timerName ~= "BREATH" then
		return
	end
	if event == "MIRROR_TIMER_START" then
		local m = maxValue or 30000
		startBreathTicker(m)
		if value and m and m > 0 then
			lastRemaining = value / m
		end
	elseif event == "MIRROR_TIMER_STOP" then
		if isPlayerSubmerged() and lastRemaining and lastRemaining <= DEPLETED then
			-- Breath ran out while underwater; transition to drowning suffocation
			isDrowning = true
			lastDrownDamageTime = 0
		else
			stopBreathTicker()
		end
	end
end)

-- Weather — C_Weather.GetCurrentWeather() / WEATHER_CHANGED
-- Returns WeatherInfo { type = WeatherType, intensity = number (0.0 - 1.0) }
-- WeatherType: 0=Clear, 1=Rain, 2=Snow, 3=Sandstorm, 4=Miscellaneous

local weatherFrame = CreateFrame("Frame")
local currentWeatherType = 0
local currentWeatherIntensity = 0
local staticWeatherRole = { low = 0, high = 0 }

local function weatherTick()
	if currentWeatherIntensity <= 0 or currentWeatherType == 0 then
		return
	end

	local intensity = currentWeatherIntensity
	if currentWeatherType == 1 then
		-- Rain: high motor micro-drops patter
		local flutter = Pulse.Waves.Sine(0.04 * intensity, 8.0, 0.4)
		flutter = Pulse.Haptics.MicroFlutter(flutter)
		staticWeatherRole.low = 0
		staticWeatherRole.high = flutter
	elseif currentWeatherType == 2 then
		-- Snow: gentle crystalline drift
		local drift = Pulse.Waves.Sine(0.02 * intensity, 0.1, 0.2)
		drift = Pulse.Haptics.MicroFlutter(drift)
		staticWeatherRole.low = 0
		staticWeatherRole.high = drift
	elseif currentWeatherType == 3 then
		-- Sandstorm: heavy abrasive gusts on both motors
		local gust = Pulse.Waves.Sine(0.06 * intensity, 0.25, 0.5)
		gust = Pulse.Haptics.MicroFlutter(gust)
		staticWeatherRole.low = gust
		staticWeatherRole.high = gust * 0.7
	else
		-- Miscellaneous / atmospheric wind rumble
		local wind = Pulse.Waves.Sine(0.03 * intensity, 0.2, 0.3)
		wind = Pulse.Haptics.MicroFlutter(wind)
		staticWeatherRole.low = wind
		staticWeatherRole.high = 0
	end

	Pulse:HoldRolesIfEnabled("weatherTexture", staticWeatherRole)
end

local function updateCurrentWeather()
	if not C_Weather or type(C_Weather.GetCurrentWeather) ~= "function" then
		currentWeatherType = 0
		currentWeatherIntensity = 0
		weatherFrame:SetScript("OnUpdate", nil)
		return
	end

	local ok, info = pcall(C_Weather.GetCurrentWeather)
	if ok and info and type(info) == "table" then
		currentWeatherType = info.type or 0
		currentWeatherIntensity = info.intensity or 0
	else
		currentWeatherType = 0
		currentWeatherIntensity = 0
	end

	local wantTexture = Pulse.Database:Get("masterEnabled") and Pulse.Database:GetCue("weatherTexture")
	if wantTexture and currentWeatherIntensity > 0 and currentWeatherType ~= 0 then
		weatherFrame:SetScript("OnUpdate", weatherTick)
	else
		weatherFrame:SetScript("OnUpdate", nil)
	end
end

local function syncWeather()
	weatherFrame:UnregisterAllEvents()
	weatherFrame:SetScript("OnUpdate", nil)
	if not Pulse.Database:Get("masterEnabled") then
		return
	end
	if not (Pulse.Database:GetCue("weatherChanged") or Pulse.Database:GetCue("weatherTexture")) then
		return
	end
	if not C_Weather or type(C_Weather.GetCurrentWeather) ~= "function" then
		return
	end

	weatherFrame:RegisterEvent("WEATHER_CHANGED")
	weatherFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	updateCurrentWeather()
end

weatherFrame:SetScript("OnEvent", function(_, event)
	if event == "WEATHER_CHANGED" then
		Pulse:FireIfEnabled("weatherChanged")
	end
	updateCurrentWeather()
end)

function M:OnEnable()
	Pulse:BindFrame({ "breathWarning", "breathTexture", "drowningDamage" }, syncBreath)
	Pulse:BindFrame({ "weatherChanged", "weatherTexture" }, syncWeather)
end

function M:_DebugEnvironment()
	return {
		breathTickerActive = breathTicker ~= nil,
		isDrowning = isDrowning,
		weatherRegistered = weatherFrame:IsEventRegistered("WEATHER_CHANGED") and true or false,
		weatherType = currentWeatherType,
		weatherIntensity = currentWeatherIntensity,
	}
end
