-- Pulse — Modules/Flight.lua
--
-- Two cue groups: mountUp/dismount, and glideThrust, the Skyriding thrust texture, which
-- ramps through a tunable exponential ease-in curve (see thrillCurve below).

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Flight", M)

-- Mount / dismount

local mountFrame = CreateFrame("Frame")
local wasMounted = false
local mountStateReady = false

local function syncMount()
    mountFrame:UnregisterAllEvents()
    if not Pulse.Database:Get("masterEnabled") then
        return
    end
    if not (Pulse.Database:GetCue("mountUp") or Pulse.Database:GetCue("dismount")) then
        return
    end

    -- Re-seed live state on sync so toggling the cue or profile while mounted
    -- does not misfire or stay unseeded until the next zoning event.
    wasMounted = IsMounted()
    mountStateReady = true

    mountFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    mountFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

mountFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        wasMounted = IsMounted()
        mountStateReady = true
        return
    end
    local mounted = IsMounted()
    if mountStateReady then
        if mounted and not wasMounted then
            Pulse:FireIfEnabled("mountUp")
        elseif wasMounted and not mounted then
            Pulse:FireIfEnabled("dismount")
        end
    end
    wasMounted = mounted
    mountStateReady = true
end)

-- Skyriding / dragonriding thrust

local glideFrame = CreateFrame("Frame")

-- Hand-rolled: native math.clamp is CONFIRMED absent on this client (Core/Engine.lua).

local function clamp01(v)
    if v < 0 then
        return 0
    end
    if v > 1 then
        return 1
    end
    return v
end

-- Low = Constant baseline "flying" presence (floored, lightly nudged by speed).
-- High = Speed-thrill intensity, ramping toward peak boost via thrillCurve.

local function glideTick()
    if not C_PlayerInfo or type(C_PlayerInfo.GetGlidingInfo) ~= "function" then
        return
    end
    local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()

    -- Guard against protected or secret combat stats, which throw if compared directly. A
    -- hidden value aborts the tick.

    if issecretvalue(isGliding) or issecretvalue(forwardSpeed) then
        return
    end
    if not isGliding or not forwardSpeed or forwardSpeed < 65 then
        return
    end

    -- forwardSpeed ranges 65 (min gliding) to 100 (max boost).

    local ratio = clamp01((forwardSpeed - 65) * (1 / 35))
    local presenceFloor = Pulse.Database:GetTriggerSetting("glideThrust", "presenceFloor", 0.15)
    local thrillPeak = Pulse.Database:GetTriggerSetting("glideThrust", "thrillPeak", 0.7)
    local thrillCurve = Pulse.Database:GetTriggerSetting("glideThrust", "thrillCurve", 2.0)
    local low = presenceFloor + (1 - presenceFloor) * (ratio * 0.3)
    local high = (ratio ^ thrillCurve) * thrillPeak
    Pulse:HoldIfEnabled("glideThrust", low, high)
end

local function syncGlide()
    glideFrame:SetScript("OnUpdate", nil)
    if not Pulse.Database:Get("masterEnabled") then
        return
    end
    if not Pulse.Database:GetCue("glideThrust") then
        return
    end
    glideFrame:SetScript("OnUpdate", glideTick)
end

function M:OnEnable()
    Pulse:BindFrame({ "mountUp", "dismount" }, syncMount)
    Pulse:BindFrame({ "glideThrust" }, syncGlide)
end

-- Reach-in for PulseDebug, read-only
function M:_DebugFlight()
    return {
        wasMounted = wasMounted,
        mountStateReady = mountStateReady,
        isMounted = IsMounted and IsMounted() or false,
    }
end
