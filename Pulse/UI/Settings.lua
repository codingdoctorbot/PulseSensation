-- Pulse — UI/Settings.lua
--
-- The Pulse entry in Blizzard's AddOns settings list. A splash page with one button on it.
--
-- Until 2026-09-22 this file WAS the settings panel: ~764 controls registered with
-- Blizzard's Settings API at login and rendered through a recycling ScrollBox, which is
-- what crashed the client on closing the panel with a controller live
-- (UI/Panel/Content.lua has the mechanism). UI/Panel/ replaces it, with every control moved
-- across unchanged — same labels, tooltips, ranges and Pulse.Database keys, so nothing
-- saved had to migrate. See UIguide.md.
--
-- WHY KEEP AN ENTRY HERE. Discoverability: Esc → Options → AddOns is where a player looks
-- for an addon's settings, and an addon missing from that list looks broken.
--
-- WHY A CANVAS RATHER THAN INITIALIZERS. A canvas category is one frame Pulse owns and the
-- Settings framework merely displays — no list, no ScrollBox, no element pool, no
-- initializers, so not one of the constructs implicated in the crash is left anywhere in
-- this addon's Blizzard-facing code. And the Settings list builds controls and nothing that
-- renders a paragraph or a wordmark.

local ADDON_NAME, Pulse = ...

Pulse.UI = Pulse.UI or {}
local UISettings = {}
Pulse.UI.Settings = UISettings

-- Artwork

-- YOUR OWN BACKGROUND IMAGE GOES HERE.
--
-- Left nil, the page draws a vertical gradient, which needs no files and cannot fail to
-- load. Set a texture path and that image is used full-bleed:
--
--     local BACKGROUND_TEXTURE = "Interface\\AddOns\\Pulse\\Media\\welcome"
--
-- The file goes in Pulse/Media/ as welcome.tga or welcome.blp, and the path above leaves the
-- extension OFF — the client adds it. TGA must be 32-bit uncompressed with power-of-two
-- dimensions (512x512, 1024x512, 1024x1024); anything else silently fails to load and gives
-- a blank rectangle rather than an error. The canvas is roughly 680x600, so 1024x1024
-- cropped by TEXCOORD or 1024x512 stretched both work.
--
-- Deliberately shipped with no picture: this addon has no artwork of its own, and a
-- borrowed Blizzard texture on the front page would be someone else's art presented as
-- Pulse's.
local BACKGROUND_TEXTURE = "Interface\\AddOns\\Pulse\\Media\\SettingsBG"
local TEX_W, TEX_H = 512, 512

-- Pulse's accent. Picked to sit with the addon's own icon (Spell_Nature_HealingWaveGreater)
-- rather than against it.
local ACCENT = { r = 0.30, g = 0.72, b = 1.00 }

local BG_TOP = { r = 0.03, g = 0.05, b = 0.08 }
local BG_BOTTOM = { r = 0.07, g = 0.12, b = 0.18 }

-- Dynamic cover cropping: keeps the texture centered without stretching or aspect distortion.
local function fitCover(texture, parent)
    if not texture or not parent then
        return
    end
    local w, h = parent:GetSize()
    if not w or w <= 0 or not h or h <= 0 then
        return
    end
    local frameAspect, texAspect = w / h, TEX_W / TEX_H
    if frameAspect > texAspect then
        local v = (1 - texAspect / frameAspect) / 2
        texture:SetTexCoord(0, 1, v, 1 - v)
    else
        local u = (1 - frameAspect / texAspect) / 2
        texture:SetTexCoord(u, 1 - u, 0, 1)
    end
end

-- Biggest font first. The pattern Modules/Locomotion.lua's formID uses: read through the
-- named globals and fall back rather than assume, so a client without the display fonts
-- gets a smaller wordmark rather than an error.
local WORDMARK_FONTS = {
    "Game60Font",
    "SystemFont_Shadow_Huge2",
    "SystemFont_Shadow_Huge1",
    "GameFontNormalHuge",
    "GameFontNormalLarge",
}

local function firstFont(candidates)
    for _, name in ipairs(candidates) do
        if type(_G[name]) == "table" then
            return name
        end
    end
    return "GameFontNormal"
end

local BODY_TEXT = 'Every cue, its intensity and "feels like" shape, your profiles, per-mode motor and '
    .. "timing tuning, controller calibration, the mode tester and the guide — all of it "
    .. "is in Pulse's own window.\n\n"
    .. "It draws itself rather than living as pages in this panel, which is what lets it "
    .. "build only what you are looking at instead of every control in the addon at every "
    .. "login."

-- Build

local function addonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(get) ~= "function" then
        return nil
    end
    local ok, version = pcall(get, ADDON_NAME, "Version")
    if ok and type(version) == "string" then
        return version
    end
    return nil
end

-- One texture if a picture was supplied, two if it draws its own: a flat base underneath,
-- so a gradient that fails to apply still leaves something solid rather than a see-through
-- page. With a background texture, an atmospheric scrim is layered over it to preserve
-- contrast and typography readability.
local function buildBackground(canvas)
    local base = canvas:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints(canvas)

    if BACKGROUND_TEXTURE then
        base:SetTexture(BACKGROUND_TEXTURE)
        canvas.bgTexture = base
        fitCover(base, canvas)

        -- Atmospheric dark scrim for high contrast and readability over the ripple artwork
        local scrim = canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
        scrim:SetAllPoints(canvas)
        scrim:SetColorTexture(1, 1, 1, 1)
        if type(CreateColor) == "function" and scrim.SetGradient then
            pcall(
                scrim.SetGradient,
                scrim,
                "VERTICAL",
                CreateColor(0.02, 0.03, 0.05, 0.82),
                CreateColor(0.01, 0.02, 0.03, 0.55)
            )
        else
            scrim:SetColorTexture(0.02, 0.03, 0.05, 0.70)
        end
        return base
    end

    base:SetColorTexture(BG_TOP.r, BG_TOP.g, BG_TOP.b, 1)

    local gradient = canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetAllPoints(canvas)
    gradient:SetColorTexture(1, 1, 1, 1)
    if type(CreateColor) == "function" and gradient.SetGradient then
        pcall(
            gradient.SetGradient,
            gradient,
            "VERTICAL",
            CreateColor(BG_BOTTOM.r, BG_BOTTOM.g, BG_BOTTOM.b, 1),
            CreateColor(BG_TOP.r, BG_TOP.g, BG_TOP.b, 1)
        )
    else
        gradient:Hide()
    end
    return base
end

-- The rule under the wordmark, in two halves so it fades in from nothing and back out.
-- SetGradient takes two stops, and a bar that just stops at both ends reads as a box.
local function buildAccentRule(canvas, anchorTo)
    if type(CreateColor) ~= "function" then
        return nil
    end

    local clear = CreateColor(ACCENT.r, ACCENT.g, ACCENT.b, 0)
    local solid = CreateColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.85)

    local left = canvas:CreateTexture(nil, "ARTWORK")
    left:SetSize(130, 2)
    left:SetPoint("TOPRIGHT", anchorTo, "BOTTOM", 0, -10)
    left:SetColorTexture(1, 1, 1, 1)

    local right = canvas:CreateTexture(nil, "ARTWORK")
    right:SetSize(130, 2)
    right:SetPoint("TOPLEFT", anchorTo, "BOTTOM", 0, -10)
    right:SetColorTexture(1, 1, 1, 1)

    if not (left.SetGradient and pcall(left.SetGradient, left, "HORIZONTAL", clear, solid)) then
        left:Hide()
    end
    if not (right.SetGradient and pcall(right.SetGradient, right, "HORIZONTAL", solid, clear)) then
        right:Hide()
    end
    return left
end

-- SharedButtonLargeTemplate is Blizzard's primary call-to-action, the red three-slice
-- button, which stretches to whatever size it is given
-- (Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:80). Falls back to the
-- ordinary panel button if absent: the page is useless without something to press.
local function buildButton(canvas)
    local ok, button = pcall(CreateFrame, "Button", nil, canvas, "SharedButtonLargeTemplate")
    if not ok or not button then
        button = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
        button:SetSize(240, 28)
    else
        button:SetSize(280, 44)
    end
    button:SetText("Open Pulse settings")
    button:SetScript("OnClick", function()
        if Pulse.UI.Panel and Pulse.UI.Panel.Open then
            Pulse.UI.Panel.Open()
        end
    end)
    return button
end

function UISettings:Build()
    if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
        -- No Settings API to attach to. The window is reachable by slash command anyway,
        -- so this is a missing shortcut rather than a missing feature.
        return
    end

    local canvas = CreateFrame("Frame", nil, UIParent)
    canvas:Hide()

    buildBackground(canvas)

    local wordmark = canvas:CreateFontString(nil, "OVERLAY", firstFont(WORDMARK_FONTS))
    wordmark:SetJustifyH("CENTER")
    wordmark:SetPoint("TOP", canvas, "TOP", 0, -64)
    wordmark:SetText("PULSE")
    wordmark:SetTextColor(1, 1, 1)
    if wordmark.SetShadowColor then
        wordmark:SetShadowColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
        wordmark:SetShadowOffset(0, -2)
    end

    local rule = buildAccentRule(canvas, wordmark)

    local tagline = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tagline:SetJustifyH("CENTER")
    tagline:SetPoint("TOP", rule or wordmark, "BOTTOM", 0, -18)
    tagline:SetText("What the game is doing, felt through the controller.")
    tagline:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)

    local body = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetJustifyH("CENTER")
    body:SetJustifyV("TOP")
    body:SetSpacing(4)
    body:SetPoint("TOP", tagline, "BOTTOM", 0, -22)
    body:SetText(BODY_TEXT)

    local open = buildButton(canvas)
    open:SetPoint("TOP", body, "BOTTOM", 0, -30)

    local hint = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetJustifyH("CENTER")
    hint:SetSpacing(2)
    hint:SetPoint("TOP", open, "BOTTOM", 0, -16)
    hint:SetText(
        "|cffffd100/pulseui|r opens it too. "
            .. "|cffffd100/pulse debug|r toggles logging, "
            .. "|cffffd100/pulse test <mode>|r plays a single shape."
    )

    local version = addonVersion()
    if version then
        local stamp = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        stamp:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -16, 14)
        stamp:SetText(version)
    end

    -- A FontString anchored on one point has no width of its own, so wrapping has to be
    -- told what to wrap to. Recomputed whenever the container resizes.
    local function layout()
        if canvas.bgTexture then
            fitCover(canvas.bgTexture, canvas)
        end
        local width = canvas:GetWidth()
        if not width or width <= 0 then
            return
        end
        local available = math.min(470, width - 80)
        if available < 1 then
            return
        end
        body:SetWidth(available)
        hint:SetWidth(available)
        tagline:SetWidth(width - 60)
    end

    canvas:SetScript("OnShow", layout)
    canvas:SetScript("OnSizeChanged", layout)

    local category = Settings.RegisterCanvasLayoutCategory(canvas, "Pulse")
    Settings.RegisterAddOnCategory(category)

    self.canvas = canvas
    self.category = category
    return category
end
