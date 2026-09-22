-- Pulse — Modules/Environment.lua
--
-- alphafeatures.md G2 (underwater breath, MIRROR_TIMER_START/"BREATH") and G14 (weather,
-- C_Weather/WEATHER_CHANGED — new as of Patch 12.1.5, unverified in-game here).

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Environment", M)

-- Breath: MIRROR_TIMER_START("BREATH") brackets a countdown. Its payload (timerName, value,
-- maxValue, scale) is the player's own environment state, not a restricted unit read, so no
-- RULE A concern.
--
-- CONFIRMED BROKEN IN-GAME 2026-09-15: GetMirrorTimerInfo's real signature is
-- `timer, initial, maxvalue, scale, paused, label = GetMirrorTimerInfo(id)`, where `timer`
-- is the type STRING ("BREATH") and `initial` is the value when the timer STARTED, not a
-- live reading. Calling it every tick expecting (value, maxValue) divided a string by a
-- number and threw silently. The live value is `GetMirrorTimerProgress(timerType)`, which
-- takes the type string rather than an index and returns 0 when inactive. maxValue is
-- captured once from the START event, being static for the timer's duration.

local function lerp(from, to, factor) return from + (to - from) * factor end

local breathFrame = CreateFrame("Frame")
local breathTicker = nil
local warnedLowBreath = false
local breathMaxValue = nil
local lastGasp = 0

local function stopBreathTicker()
    if breathTicker then
        breathTicker:Cancel()
        breathTicker = nil
    end
    warnedLowBreath = false
    breathMaxValue = nil
    lastGasp = 0
end

local function startBreathTicker(maxValue)
    stopBreathTicker()
    breathMaxValue = maxValue
    -- 0.1s, not 0.5s (continuous.md §4): breathTexture's gasp gap shrinks to as little
    -- as 0.1s near drowning, and a 0.5s poll cannot distinguish that from any other
    -- short gap, so the acceleration would be theoretical rather than felt.
    -- breathWarning's threshold check just runs more often, still gated by
    -- warnedLowBreath.
    breathTicker = C_Timer.NewTicker(0.1, function()
        if not breathMaxValue or breathMaxValue <= 0 then return end
        local current = GetMirrorTimerProgress("BREATH")
        if not current or current <= 0 then return end -- 0 also means "not active"
        local remaining = current / breathMaxValue
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
                C_Timer.After(0.36, function() Pulse:HoldIfEnabled("breathTexture", dub, dub, 0.05) end)
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
    if not (Pulse.Database:GetCue("breathWarning") or Pulse.Database:GetCue("breathTexture")) then
        stopBreathTicker()
        return
    end
    breathFrame:RegisterEvent("MIRROR_TIMER_START")
    breathFrame:RegisterEvent("MIRROR_TIMER_STOP")

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
            startBreathTicker(maxVal or math.max(current, 30000))
        end
    end
end

breathFrame:SetScript("OnEvent", function(_, event, timerName, value, maxValue)
    if timerName ~= "BREATH" then return end
    if event == "MIRROR_TIMER_START" then
        startBreathTicker(maxValue)
    elseif event == "MIRROR_TIMER_STOP" then
        stopBreathTicker()
    end
end)

-- Weather — C_Weather.GetCurrentWeather() / WEATHER_CHANGED, Patch 12.1.5. Return shape
-- not verified live here (alphafeatures.md G14): fires generically on any change rather
-- than filtering to storm-type weather until that's confirmed.

local weatherFrame = CreateFrame("Frame")

local function syncWeather()
    weatherFrame:UnregisterAllEvents()
    if not Pulse.Database:Get("masterEnabled") then return end
    if not Pulse.Database:GetCue("weatherChanged") then return end
    if not C_Weather or type(C_Weather.GetCurrentWeather) ~= "function" then return end
    weatherFrame:RegisterEvent("WEATHER_CHANGED")
end

weatherFrame:SetScript("OnEvent", function() Pulse:FireIfEnabled("weatherChanged") end)

function M:OnEnable()
    Pulse:BindFrame({ "breathWarning", "breathTexture" }, syncBreath)
    Pulse:BindFrame({ "weatherChanged" }, syncWeather)
end

function M:_DebugEnvironment()
    return {
        breathTickerActive = breathTicker ~= nil,
        weatherRegistered = weatherFrame:IsEventRegistered("WEATHER_CHANGED") and true or false,
    }
end
