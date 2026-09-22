-- Pulse — Modules/AlertExperimental.lua
--
-- Accessibility cues imported from Tremor/Modules/Experimental.lua: resourceCapped,
-- targetCastStopped and actionFailed only. lowHealth35/lowHealth20 are deliberately NOT
-- imported — both are CONFIRMED permanently dead, UnitHealth("player") reading
-- unconditionally secret, and Modules/Health.lua's lowHealthWarning already covers the
-- purpose through LowHealthFrame.
--
-- The three no longer share a category or a bulk on/off switch (ALERT_EXPERIMENTAL and
-- experimentalMaster, removed 2026-09-16); each lives in Registry.lua under the category it
-- belongs to by subject, gated by its own cue toggle. This module still owns all three
-- watchers unchanged. The category gate was never a shared registration — each already has
-- its own frame and event — so it only added a manual check.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertExperimental", M)

-- The seven DESIGN.md §4.9 admits as secondary resources, in probe order.
local PowerType = (Enum and Enum.PowerType) or {}
local SECONDARY_POWERS = {
    PowerType.ComboPoints or 4,
    PowerType.SoulShards or 7,
    PowerType.HolyPower or 9,
    PowerType.Chi or 12,
    PowerType.ArcaneCharges or 16,
    PowerType.Essence or 19,
    PowerType.Runes or 5,
}

local function resolveSecondaryPower()
    for _, powerType in ipairs(SECONDARY_POWERS) do
        local max = UnitPowerMax("player", powerType)
        if not issecretvalue(max) and max and max > 0 then
            return powerType
        end
    end
    return nil
end

local cappedPower
local wasCapped = false

function M:OnEnable()
    self:_WatchResourceCapped()
    self:_WatchTargetCastStopped()
    self:_WatchActionFailed()
end

function M:_WatchResourceCapped()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        cappedPower = nil
        wasCapped = false
        if not Pulse.Database:Get("masterEnabled") then
            return
        end
        if not Pulse.Database:GetCue("resourceCapped") then
            return
        end

        cappedPower = resolveSecondaryPower()
        if Pulse.debug then
            print(("Pulse: resourceCapped resolved powerType -> %s"):format(tostring(cappedPower)))
        end

        -- CONFIRMED LIVE 2026-09-16: resolution works every time after toggling the cue
        -- off and on mid-session and fails after a hard relog. Same sync() code either way,
        -- so the difference is timing — an attempt at ADDON_LOADED can catch UnitPowerMax
        -- before the client has settled into the world. PLAYER_ENTERING_WORLD is the
        -- reliable "safe to read now" signal, registered unconditionally so a bad first
        -- attempt gets a second chance rather than being stuck all session. It fires on
        -- every later loading screen too, which is a harmless resync.
        frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")

        if not cappedPower then
            return
        end

        local power = UnitPower("player", cappedPower)
        local powerMax = UnitPowerMax("player", cappedPower)
        if not issecretvalue(power) and not issecretvalue(powerMax) and power and powerMax and powerMax > 0 then
            wasCapped = power >= powerMax
        end

        frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    end

    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            sync()
            return
        end
        M:_OnPowerUpdate()
    end)

    Pulse:BindFrame({ "resourceCapped" }, sync)
end

function M:_OnPowerUpdate()
    if not cappedPower then
        return
    end

    local power = UnitPower("player", cappedPower)
    local powerMax = UnitPowerMax("player", cappedPower)
    if issecretvalue(power) or issecretvalue(powerMax) then
        return
    end
    if not power or not powerMax or powerMax <= 0 then
        return
    end

    local capped = power >= powerMax
    if capped and not wasCapped then
        if Pulse.debug then
            print(("Pulse: resourceCapped edge crossed -> %s/%s"):format(tostring(power), tostring(powerMax)))
        end
        Pulse:FireIfEnabled("resourceCapped")
    end
    wasCapped = capped
end

function M:_WatchTargetCastStopped()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then
            return
        end
        if not Pulse.Database:GetCue("targetCastStopped") then
            return
        end
        frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
    end

    frame:SetScript("OnEvent", function()
        Pulse:FireIfEnabled("targetCastStopped")
    end)

    Pulse:BindFrame({ "targetCastStopped" }, sync)
end

function M:_WatchActionFailed()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then
            return
        end
        if not Pulse.Database:GetCue("actionFailed") then
            return
        end
        frame:RegisterEvent("UI_ERROR_MESSAGE")
    end

    -- UI_ERROR_MESSAGE fires (messageType, message), CONFIRMED against Blizzard's
    -- Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua. While dead, the client keeps
    -- silently re-attempting the queued auto-attack once per weapon-swing interval — the
    -- mechanism behind selfCastFailed's repeat-firing — and each attempt fails with
    -- LE_GAME_ERR_ATTACK_DEAD. Filtered by that messageType rather than by UnitIsDeadOrGhost,
    -- since the reason code is precise enough to drop just that failure instead of
    -- suppressing every action-failed while the player is dead.
    frame:SetScript("OnEvent", function(_, event, messageType)
        if messageType == LE_GAME_ERR_ATTACK_DEAD then
            return
        end
        Pulse:FireIfEnabled("actionFailed")
    end)

    Pulse:BindFrame({ "actionFailed" }, sync)
end
