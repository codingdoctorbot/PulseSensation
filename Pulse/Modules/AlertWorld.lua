-- Pulse — Modules/AlertWorld.lua
--
-- Accessibility cues, imported from Tremor/Modules/World.lua. All generic except
-- afkToggle, which must fire on the actual flag flip rather than on every
-- PLAYER_FLAGS_CHANGED. Not to be confused with this addon's own native WORLD category
-- (Modules/World.lua) — different category id (ALERT_WORLD vs WORLD), different triggers,
-- no overlap.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("AlertWorld", M)

local CUSTOM = { afkToggle = true }
local wasFlagged = false

local function currentFlagged()
    local afk = UnitIsAFK("player")
    local dnd = UnitIsDND("player")
    if issecretvalue(afk) or issecretvalue(dnd) then return nil end
    return (afk or dnd) and true or false
end

function M:OnEnable()
    Pulse:WatchCategory("ALERT_WORLD", CUSTOM)
    self:_WatchFlags()
end

function M:_WatchFlags()
    local frame = CreateFrame("Frame")

    local function sync()
        frame:UnregisterAllEvents()
        if not Pulse.Database:Get("masterEnabled") then return end
        if not Pulse.Database:GetCue("afkToggle") then return end
        wasFlagged = (currentFlagged() == true)
        frame:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", "player")
    end

    frame:SetScript("OnEvent", function()
        M:_OnFlagsChanged()
    end)

    Pulse:BindFrame({ "afkToggle" }, sync)
end

function M:_OnFlagsChanged()
    local flagged = currentFlagged()
    if flagged == nil then return end

    if flagged ~= wasFlagged then
        wasFlagged = flagged
        Pulse:FireIfEnabled("afkToggle")
    end
end
