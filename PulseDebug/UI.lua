-- PulseDebug — UI.lua
--
-- A window for the questions chat cannot answer. Debug.lua's commands each print one
-- snapshot: fine for "is the pad enabled", useless for "what does this hold actually do
-- while it decays", which is most of what Pulse does. Re-typing /pdebug layers eight times
-- and reading eight blocks of scrollback is not watching a texture fade.
--
-- So: the same readouts, on a frame, with a Live toggle that re-renders them ~10x a second.
-- A hold fired from the settings panel or /pdebug hold can then be watched all the way down
-- instead of sampled.
--
-- Same stance as PulseChecklist's window — a genuinely custom frame using plain Blizzard
-- templates, not Pulse's own panel theme. This is a developer tool; it has no reason to
-- inherit Pulse's "look like Blizzard's own settings panel" constraint, and coupling it to
-- Pulse/UI/Panel/Theme.lua would make a troubleshooting tool break whenever the thing it
-- troubleshoots gets restyled.
--
-- Templates used are the ones PulseChecklist already relies on: BACKDROP_DIALOG_32_32
-- (Blizzard_SharedXML/Backdrop.lua), UIPanelCloseButton, UIPanelButtonTemplate and
-- UIPanelScrollFrameTemplate.

local ADDON_NAME = ...

local FRAME_WIDTH  = 660
local FRAME_HEIGHT = 500
local REFRESH_RATE = 0.1   -- 10Hz. Fast enough to read a release curve, slow enough that
                           -- rebuilding the whole string every tick costs nothing visible.

local GOOD = "|cff44ff44"
local BAD  = "|cffff5555"
local WARN = "|cffffcc00"
local DIM  = "|cff999999"
local HEAD = "|cffffffff"
local R    = "|r"

local function core()
    local P = _G.Pulse
    if not P or not P.Database or not P.Registry or not P.Engine then return nil end
    return P
end

local function flag(value)
    return value and (GOOD .. "yes" .. R) or (BAD .. "no" .. R)
end

---------------------------------------------------------------------------
-- Main frame
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "PulseDebugUIFrame", UIParent, "BackdropTemplate")
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop(BACKDROP_DIALOG_32_32)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("Pulse Debug")

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

---------------------------------------------------------------------------
-- Body: one FontString in a scroll frame
---------------------------------------------------------------------------

-- One string rebuilt per render rather than a row widget per line. The views are at most a
-- few dozen lines and are replaced wholesale every tick while Live is on, so pooling row
-- frames would buy nothing and cost the complexity of recycling them.
--
-- WoW ships no monospace font, so the %-Ns padding below lines columns up approximately
-- rather than exactly. Readable, not a table.
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -96)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 18)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(FRAME_WIDTH - 60, 1)
scrollFrame:SetScrollChild(scrollChild)

local body = scrollChild:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
body:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
body:SetWidth(FRAME_WIDTH - 60)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")

---------------------------------------------------------------------------
-- Views
---------------------------------------------------------------------------

-- Each view returns a plain string. Keeping them pure makes the Live path trivial: the
-- refresh loop just calls the current one again and assigns the result.

local views = {}
local viewOrder = { "state", "layers", "channels", "modules", "schema" }
local currentView = "layers"

local function line(label, value)
    return string.format("%-28s %s", label, value or "")
end

function views.state(P)
    local out = {}
    out[#out + 1] = HEAD .. "— device —" .. R
    out[#out + 1] = line("GamePadEnable", tostring(C_CVar.GetCVar("GamePadEnable")))
    out[#out + 1] = line("Pulse sees a pad", flag(P.Engine:IsDeviceReady()))

    out[#out + 1] = ""
    out[#out + 1] = HEAD .. "— pulse —" .. R
    out[#out + 1] = line("masterEnabled", flag(P.Database:Get("masterEnabled")))
    out[#out + 1] = line("profile", tostring(P.Database:GetActiveProfileName()))
    out[#out + 1] = line("masterIntensity", tostring(P.Database:Get("masterIntensity")))
    out[#out + 1] = line("schema", tostring(P.Database:Get("defaultHapticSchema")))

    local total, enabled = 0, 0
    for _, category in ipairs(P.Registry:GetCategories()) do
        for _, trigger in ipairs(P.Registry:GetTriggersByCategory(category)) do
            total = total + 1
            if P.Database:GetCue(trigger.id) then enabled = enabled + 1 end
        end
    end
    out[#out + 1] = line("triggers enabled", string.format("%d of %d", enabled, total))
    out[#out + 1] = line("active layers", tostring(#P.Engine:_DebugLayers()))
    return table.concat(out, "\n")
end

function views.layers(P)
    local layers = P.Engine:_DebugLayers()
    if #layers == 0 then
        return DIM .. "Nothing blending into the channel right now." .. R ..
               "\n\n" .. DIM .. "Turn Live on, then fire a continuous cue — /pdebug hold " ..
               "<id>, or the settings panel's mode tester — and watch it decay here." .. R
    end

    -- Four roles, not two: a layer may drive ltrigger/rtrigger only (Locomotion's split
    -- footfalls do), so a nil column has to read as blank rather than 0.00.
    local function cell(value)
        if value == nil then return DIM .. "  -   " .. R end
        return string.format("%-6.2f", value)
    end

    local out = {}
    out[#out + 1] = HEAD .. string.format("%-22s %-7s %-7s %-7s %-7s %s",
        "layer", "low", "high", "ltrig", "rtrig", "left") .. R
    for _, layer in ipairs(layers) do
        out[#out + 1] = string.format("%-22s %s %s %s %s %.2fs",
            layer.name, cell(layer.low), cell(layer.high),
            cell(layer.ltrigger), cell(layer.rtrigger),
            math.max(layer.remaining, 0))
    end
    return table.concat(out, "\n")
end

function views.channels(P)
    local channels = P.Engine:_DebugChannels()
    if not next(channels) then
        return DIM .. "No channel has been driven yet this session." .. R
    end
    local out = {}
    out[#out + 1] = HEAD .. string.format("%-16s %-10s %s", "channel", "smoothed", "last set") .. R
    for channel, info in pairs(channels) do
        out[#out + 1] = string.format("%-16s %-10.2f %s",
            channel, info.smoothed or 0, tostring(info.lastSet))
    end
    return table.concat(out, "\n")
end

-- Module introspection.
--
-- Pulse exposes read-only reach-ins on the modules whose state is otherwise invisible from
-- outside their file: Locomotion's _DebugGait, Crafting's _DebugCraft, Interaction's
-- _DebugInteraction. Nothing consumed them before this view existed — they were written for
-- a caller that was never built.
--
-- Discovered rather than listed: any module gaining a _Debug* function is picked up here
-- with no edit, which is the point of scanning instead of hardcoding three names.
local function debugFunctionsFor(module)
    local found = {}
    for key, value in pairs(module) do
        if type(value) == "function" and type(key) == "string" and key:find("^_Debug") then
            found[#found + 1] = key
        end
    end
    table.sort(found)
    return found
end

local function formatValue(value)
    local kind = type(value)
    if kind == "number" then
        -- Integers stay integers; a gait cadence reading 0.43 should not print as 0.
        if value == math.floor(value) then return tostring(value) end
        return string.format("%.3f", value)
    elseif kind == "boolean" then
        return flag(value)
    elseif kind == "nil" then
        return DIM .. "nil" .. R
    elseif kind == "table" then
        return DIM .. "{table}" .. R
    end
    return tostring(value)
end

function views.modules(P)
    local out = {}
    local any = false

    for _, name in ipairs(P.moduleOrder) do
        local module = P.modules[name]
        local functions = module and debugFunctionsFor(module) or {}
        if #functions > 0 then
            any = true
            out[#out + 1] = HEAD .. name .. R
            for _, key in ipairs(functions) do
                -- pcall: a reach-in reads live module state, and a module mid-teardown can
                -- hand back something unexpected. A debug window erroring is worse than a
                -- debug window saying it could not read.
                local ok, result = pcall(module[key], module)
                if not ok then
                    out[#out + 1] = "  " .. BAD .. key .. " errored" .. R
                elseif type(result) ~= "table" then
                    out[#out + 1] = "  " .. DIM .. key .. R .. "  " .. formatValue(result)
                else
                    out[#out + 1] = "  " .. DIM .. key .. R
                    local keys = {}
                    for field in pairs(result) do keys[#keys + 1] = tostring(field) end
                    table.sort(keys)
                    for _, field in ipairs(keys) do
                        out[#out + 1] = string.format("      %-22s %s",
                            field, formatValue(result[field]))
                    end
                end
            end
            out[#out + 1] = ""
        end
    end

    if not any then
        return DIM .. "No module exposes a _Debug* reach-in." .. R
    end
    return table.concat(out, "\n")
end

function views.schema(P)
    if type(P.Engine._ActiveSchema) ~= "function" then
        return BAD .. "Engine._ActiveSchema not found." .. R
    end
    local schema = P.Engine:_ActiveSchema()
    if not schema then return BAD .. "No active schema." .. R end

    local out = {}
    out[#out + 1] = HEAD .. tostring(schema.id) .. R .. "  " .. (schema.label or "")
    out[#out + 1] = ""
    local roles = {}
    for role in pairs(schema.roles or {}) do roles[#roles + 1] = role end
    table.sort(roles)
    for _, role in ipairs(roles) do
        local def = schema.roles[role]
        out[#out + 1] = line("  " .. role, string.format("%s @ %.2f",
            def.channel or (DIM .. "silent" .. R), def.intensity or 1.0))
    end
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------

local function render()
    local P = core()
    if not P then
        body:SetText(BAD .. "Pulse is not loaded." .. R)
        scrollChild:SetHeight(40)
        return
    end
    local view = views[currentView]
    local ok, text = pcall(view, P)
    body:SetText(ok and text or (BAD .. "view errored: " .. R .. tostring(text)))
    -- The scroll child has to match the text or UIPanelScrollFrameTemplate has nothing to
    -- scroll against and the bar sits dead at the top.
    scrollChild:SetHeight(math.max(body:GetStringHeight() + 8, 1))
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

local buttons = {}

local function highlightActive()
    for id, button in pairs(buttons) do
        -- Disabling the active one is the cheapest unambiguous "you are here" with stock
        -- templates: it greys out and stops taking clicks, no extra texture needed.
        button:SetEnabled(id ~= currentView)
    end
end

local function selectView(id)
    currentView = id
    highlightActive()
    render()
end

local BUTTON_LABEL = {
    state    = "State",
    layers   = "Layers",
    channels = "Channels",
    modules  = "Modules",
    schema   = "Schema",
}

local previous
for _, id in ipairs(viewOrder) do
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(96, 22)
    button:SetText(BUTTON_LABEL[id])
    if previous then
        button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    else
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -48)
    end
    button:SetScript("OnClick", function() selectView(id) end)
    buttons[id] = button
    previous = button
end

---------------------------------------------------------------------------
-- Live toggle
---------------------------------------------------------------------------

-- The reason this file exists. Off by default: a window that re-renders forever in the
-- background is not what someone wants left open after they have finished looking.
local live = false

local liveCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
liveCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -74)
liveCheck:SetSize(22, 22)

local liveLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
liveLabel:SetPoint("LEFT", liveCheck, "RIGHT", 2, 0)
liveLabel:SetText("Live")

local liveHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
liveHint:SetPoint("LEFT", liveLabel, "RIGHT", 10, 0)
liveHint:SetText("re-reads 10x a second — watch a hold decay instead of sampling it")

liveCheck:SetScript("OnClick", function(self)
    live = self:GetChecked() and true or false
    render()
end)

local elapsedSinceRender = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if not live then return end
    elapsedSinceRender = elapsedSinceRender + elapsed
    if elapsedSinceRender < REFRESH_RATE then return end
    elapsedSinceRender = 0
    render()
end)

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------

local function Toggle()
    if frame:IsShown() then
        frame:Hide()
        return
    end
    highlightActive()
    render()
    frame:Show()
end

-- Debug.lua's `commands` table is a local, so the slash command there resolves this at call
-- time through the global rather than the two files sharing a namespace.
_G.PulseDebugUI = {
    Toggle = Toggle,
    Show   = function(view)
        if view and views[view] then currentView = view end
        highlightActive()
        render()
        frame:Show()
    end,
}

SLASH_PULSEDEBUGUI1 = "/pdui"
SlashCmdList["PULSEDEBUGUI"] = function() Toggle() end
