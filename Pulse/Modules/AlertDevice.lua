-- Pulse — Modules/AlertDevice.lua
--
-- Accessibility cues, imported from Tremor/Modules/Device.lua. Controller battery and
-- connection state.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertDevice", M)

-- C_GamePad.GetPowerLevel() returns Enum.GamePadPowerLevel:
--   0 Critical, 1 Low, 2 Medium, 3 High, 4 Wired, 5 Unknown
local PowerLevel = (Enum and Enum.GamePadPowerLevel) or {}
local LOW_LEVELS = {
    [PowerLevel.Critical or 0] = true,
    [PowerLevel.Low or 1] = true,
}

local wasLow = false

local function currentLow()
    local level = C_GamePad.GetPowerLevel()
    if issecretvalue(level) then
        return nil
    end
    if level == nil then
        return nil
    end
    return LOW_LEVELS[level] and true or false
end

function M:OnEnable()
    self:_WatchConnected()
    self:_WatchBattery()
    self:_WatchDisconnect()
end

function M:_WatchConnected()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then
            return
        end
        if not Pulse.Database:GetCue("padConnected") then
            return
        end
        frame:RegisterEvent("GAME_PAD_CONNECTED")
    end

    -- Not the generic watcher: Engine:PlayMode drops everything while its cached
    -- deviceReady is false, and Engine's own frame refreshes that from this same event with
    -- no defined order against this one. Refreshing here first makes the cue independent of
    -- registration order.
    frame:SetScript("OnEvent", function()
        Pulse.Engine:RefreshDevice()
        Pulse:FireIfEnabled("padConnected")
    end)

    Pulse:BindFrame({ "padConnected" }, sync)
end

function M:_WatchBattery()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then
            return
        end
        if not Pulse.Database:GetCue("padBattery") then
            return
        end
        wasLow = (currentLow() == true)
        frame:RegisterEvent("GAME_PAD_POWER_CHANGED")
    end

    frame:SetScript("OnEvent", function()
        M:_OnPowerChanged()
    end)

    Pulse:BindFrame({ "padBattery" }, sync)
end

function M:_OnPowerChanged()
    local low = currentLow()
    if low == nil then
        return
    end

    if low and not wasLow then
        Pulse:FireIfEnabled("padBattery")
    end
    wasLow = low
end

function M:_WatchDisconnect()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then
            return
        end
        if not Pulse.Database:GetCue("padDisconnected") then
            return
        end
        frame:RegisterEvent("GAME_PAD_DISCONNECTED")
    end

    frame:SetScript("OnEvent", function()
        Pulse:FireIfEnabled("padDisconnected")
        Pulse.Engine:StopAll()
    end)

    Pulse:BindFrame({ "padDisconnected" }, sync)
end
