-- Pulse — Modules/AlertSocial.lua
--
-- Accessibility cues, imported from Tremor/Modules/Social.lua. All generic except bgQueue,
-- which needs per-queue transition tracking or it is unusable (UPDATE_BATTLEFIELD_STATUS
-- fires repeatedly for every queued battlefield on every status change).

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertSocial", M)

local CUSTOM = { bgQueue = true }
local wasConfirming = {}   -- queue index -> was this queue in the ready-to-enter state

function M:OnEnable()
    Pulse:WatchCategory("ALERT_SOCIAL", CUSTOM)
    self:_WatchBattlefieldStatus()
end

function M:_WatchBattlefieldStatus()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        wipe(wasConfirming)
        if not Pulse.Database:Get("masterEnabled") then return end
        if not Pulse.Database:GetCue("bgQueue") then return end
        frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    end

    frame:SetScript("OnEvent", function()
        M:_OnBattlefieldStatus()
    end)

    Pulse:BindFrame({ "bgQueue" }, sync)
end

function M:_OnBattlefieldStatus()
    for index = 1, GetMaxBattlefieldID() do
        local status = GetBattlefieldStatus(index)
        if issecretvalue(status) then return end

        local confirming = (status == "confirm")
        if confirming and not wasConfirming[index] then
            Pulse:FireIfEnabled("bgQueue")
        end
        wasConfirming[index] = confirming
    end
end
