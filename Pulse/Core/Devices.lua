-- Pulse — Core/Devices.lua
--
-- Physical motor characteristics, one entry per output channel: how a motor needs to be
-- driven. Core/Schemas/*.lua answers the separate question of which channel a logical role
-- goes to. Kept apart because "Low Motor Only" exists for a DEAD strong motor, a routing
-- fact, while "the high motor is twice as strong as the low one" is a hardware fact. Merged,
-- you would get four schemas times every controller, and a dead motor would look like the
-- same kind of problem as a loud one.
--
-- Named Devices, not Profiles: Core/Database.lua already owns "profiles" (the Default/
-- Raiding/Questing/PvP playstyle slots), and a second meaning for that word in one database
-- is a trap.
--
-- STORAGE: global, beside masterEnabled/defaultHapticSchema/modeTuning, never per playstyle
-- profile — the same reasoning Database.lua committed to for modeTuning. Motor calibration
-- is not something raiding and questing could sensibly disagree on.

local ADDON_NAME, Pulse = ...

-- The four physical channel names passed to C_GamePad.SetVibration as `vibrationType`.
-- CONFIRMED from Blizzard_APIDocumentationGenerated/GamePadDocumentation.lua that the
-- argument is a bare cstring with NO enum and NO documented value list anywhere in the
-- client source — "LTrigger"/"RTrigger" appear in Blizzard's code only as button-binding
-- labels (Blizzard_SharedXML/SharedConstants.lua:75-76), never as vibration types. So:
--
--   "Low" / "High"          — confirmed live, every cue in this addon uses them.
--   "LTrigger" / "RTrigger" — NOT CONFIRMED HERE, but reportedly real: the strings Tremor
--                             has always used (Core/Schemas/TriggerEmphasis.lua), reported
--                             listed as valid by community documentation with DualSense
--                             among the responding hardware. Nothing in the source archive
--                             corroborates it, so the UI keeps them labelled unconfirmed
--                             until somebody here actually feels one.
--
-- A wrong string is a no-op rather than an error (SetVibration takes any cstring), so an
-- unsupported channel goes silent — which is why a schema routing to a dead channel needs
-- the fallback in Engine.lua's resolver.
Pulse.CHANNELS = { "Low", "High", "LTrigger", "RTrigger" }

Pulse.CHANNEL_LABELS = {
    Low = "Low motor (heavy rumble)",
    High = "High motor (sharp rumble)",
    LTrigger = "Left trigger",
    RTrigger = "Right trigger",
}

Pulse.CHANNEL_CONFIRMED = {
    Low = true,
    High = true,
    LTrigger = false,
    RTrigger = false,
}

-- Every value reproduces the engine's pre-calibration behaviour exactly, so installing this
-- layer changes nothing until someone moves a slider.
--
--   gain      1.0    no-op.
--   gamma     1.0    exact no-op: x^1.0 == x.
--   floor     0.0    exact no-op: 0 + (1-0)*x == x. NOT the old FLOOR constant — that was
--                    an output GATE deciding when to call StopVibration and never touched
--                    the value sent; this is an input remap lifting small values over the
--                    motor's breakaway threshold. The old gate still exists in Engine.lua
--                    under its own name, unchanged.
--   attackTau 0.075  the old ATTACK_RATE = 0.2 was a fraction applied PER FRAME, not a time
--   releaseTau 0.028 constant at all — the same cue decayed roughly four times faster at
--                    144fps than at 36fps. No frame-rate-free number exists to lift, so
--                    these are the taus reproducing the old rates at 60fps:
--                    tau = -dt / ln(1 - rate), dt = 1/60. Identical feel at 60, correct
--                    everywhere else. The one field that is a behaviour change.
--
-- Low and High start identical only because the old shared constants did. They are
-- physically different actuators — the low motor's large eccentric mass really is slower to
-- spin up and coast down than the high motor's small one — so the two rows wanting
-- different taus is expected, not a bug. That is what the calibration page is for.
Pulse.CHANNEL_DEFAULTS = {
    gain = 1.0,
    gamma = 1.0,
    floor = 0.0,
    attackTau = 0.075,
    releaseTau = 0.028,
}

-- Drives the calibration page generically, same discipline as Registry.lua's `tunables`:
-- adding a knob here adds its slider with no UI file edit.
Pulse.CHANNEL_TUNABLES = {
    {
        key = "gain",
        label = "Strength",
        min = 0.0,
        max = 2.0,
        step = 0.05,
        desc = 'Balances this motor against the others. Raise it if this motor is the weak one on your controller, lower it if it drowns everything else out. This is the knob the old "Low Motor Only"/"High Motor Only" schemas were being misused for — those still exist, but for a motor that is actually dead, not merely quieter.',
    },
    {
        key = "floor",
        label = "Breakaway floor",
        min = 0.0,
        max = 0.40,
        step = 0.005,
        desc = 'The smallest value that makes this motor actually spin. Anything above zero is remapped into the range above this floor, so a quiet cue still moves the mass instead of dying silently. Zero input still means completely off. Use "Ramp" below to find your controller\'s real figure.',
    },
    {
        key = "attackTau",
        label = "Attack time (s)",
        min = 0.005,
        max = 0.30,
        step = 0.005,
        desc = "How long this motor takes to reach a new, stronger level. Higher is softer and more gradual; lower is snappier. 0.075 reproduces the engine's old behaviour at 60fps.",
    },
    {
        key = "releaseTau",
        label = "Release time (s)",
        min = 0.005,
        max = 0.30,
        step = 0.005,
        desc = "How long this motor takes to fall back toward silence. Too high and consecutive taps blur into one buzz; too low and sustained textures sound chopped. 0.028 reproduces the engine's old behaviour at 60fps.",
    },
    {
        key = "gamma",
        label = "Response curve",
        min = 0.40,
        max = 2.50,
        step = 0.05,
        desc = "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.",
    },
}

-- Shape of the Ramp probe on the calibration page (Core/Engine.lua drives it).
--
-- Proportioned against where the answer plausibly lives rather than across the whole range.
-- The first version used peak 0.5, step 0.025: a third of the sweep sat above any plausible
-- breakaway point, and the reading landed on a 0.025 grid, so a floor of "about 0.15" could
-- only be reported as ±0.0125 — ±8% of the figure being measured.
--
-- No measurement backs the 0.40 ceiling; it is an instrument-design choice, not a claim
-- about hardware. Resolution belongs where the reading is, and anything still silent at 40%
-- is a dead motor rather than a high floor, which the Test button answers faster.
--
-- 40 steps at 0.4s is about sixteen seconds. Long for a button, trivial for something
-- pressed once per controller.
Pulse.RAMP_PEAK = 0.40
Pulse.RAMP_STEP = 0.01
Pulse.RAMP_STEP_SECONDS = 0.4

-- Anti-spam threshold: how far a channel has to move before it is worth another
-- SetVibration call. Global rather than per-channel — it is a call-rate optimisation, not a
-- motor property, and nothing has suggested the two motors want different values.
Pulse.CHANGE_EPSILON_DEFAULT = 0.0015

-- ── Device presets ──────────────────────────────────────────────────────────────────────
--
-- READ THIS BEFORE TRUSTING A NUMBER BELOW. These are STARTING POINTS derived from actuator
-- class, not measurements — nothing here has been put on an oscilloscope for this addon.
-- What IS solid is which class a controller belongs to, public checkable hardware fact, and
-- the classes differ enough that seeding from the right one beats the wrong one:
--
--   ERM   eccentric rotating mass, a weight on a motor shaft. Must overcome static friction
--         to turn at all, so it has a real breakaway threshold, and takes time to spin up
--         and longer to coast down. The large (low-frequency) motor is slower and
--         higher-threshold than the small one. DualShock 4, Xbox main and trigger motors.
--   LRA   voice coil, a mass on a spring driven electromagnetically. Near-instant, far more
--         linear, much lower threshold — no friction to break away from in the same way.
--         DualSense, Steam Deck, Switch Pro (HD Rumble).
--
-- Seeding an LRA pad with ERM numbers is what this table prevents: a DualSense on a 0.12
-- floor and a 90ms attack feels mushy and over-floored, for no reason but defaults shaped
-- for a different actuator. Every row is still only a start — the Ramp button measures YOUR
-- controller and outranks anything here.
--
-- `triggers` records whether the hardware is reported to have driveable trigger vibration.
-- Xbox One and later have a small dedicated impulse ERM per trigger; DualSense's adaptive
-- trigger assembly is reported to drive as a vibration source as well as resistance, and
-- this project HAS NOT FELT IT. Blizzard's side is unconfirmed either way: the gamepad layer
-- is SDL (C_GamePad.AddSDLMapping exists) and SetVibration takes a bare cstring, so the
-- accepted channel names are client-side and not discoverable from the source archive.
-- Treat the field as "worth trying the Test button", not as a guarantee.

local ERM_LOW = { floor = 0.12, attackTau = 0.090, releaseTau = 0.060 }
local ERM_HIGH = { floor = 0.10, attackTau = 0.050, releaseTau = 0.035 }
local LRA = { floor = 0.04, attackTau = 0.020, releaseTau = 0.015 }

local function copy(src, extra)
    local t = {}
    for k, v in pairs(src) do
        t[k] = v
    end
    if extra then
        for k, v in pairs(extra) do
            t[k] = v
        end
    end
    return t
end

Pulse.DEVICE_ORDER = {
    "default",
    "ds4",
    "dualsense",
    "xbox",
    "xbox_elite",
    "switchpro",
    "8bitdo",
    "steamdeck",
    "steamcontroller2",
    "steamcontroller",
}

Pulse.Devices = {
    -- The no-op row. Identical to CHANNEL_DEFAULTS, so selecting it is the same as pressing
    -- Reset calibration: whatever the engine did before this layer existed.
    default = {
        id = "default",
        label = "Generic / unknown",
        triggers = false,
        note = "No assumptions. Every value is the engine's own default. Use this if your controller is not listed, then Ramp each motor.",
        channels = {},
    },

    ds4 = {
        id = "ds4",
        label = "DualShock 4 (PS4)",
        triggers = false,
        note = "Two ERM motors, large and small. No trigger actuators — the L2/R2 triggers on a DS4 are analogue inputs only.",
        channels = { Low = copy(ERM_LOW), High = copy(ERM_HIGH) },
    },

    dualsense = {
        id = "dualsense",
        label = "DualSense (PS5)",
        triggers = true,
        note = "Voice-coil main actuators: quick, linear, low threshold. Trigger vibration is reported to work on this controller — the adaptive trigger assembly can be driven as a vibration source, not only as force-feedback resistance. Unverified here, and the trigger numbers are the least-founded in this table.",
        channels = {
            Low = copy(LRA),
            High = copy(LRA),
            -- Least-founded row in the file, deliberately conservative. The adaptive
            -- trigger is a geared motor assembly rather than a bare voice coil, so it
            -- plausibly has more friction than the main haptics and less than a classic
            -- ERM; seeded between the two. A guess with reasoning attached, not a
            -- measurement — if the trigger Test feels wrong, Ramp it.
            LTrigger = { floor = 0.08, attackTau = 0.030, releaseTau = 0.025 },
            RTrigger = { floor = 0.08, attackTau = 0.030, releaseTau = 0.025 },
        },
    },

    xbox = {
        id = "xbox",
        label = "Xbox (One / Series)",
        triggers = true,
        note = "Two ERM main motors plus a small impulse motor in each trigger — the one listed controller where trigger vibration genuinely exists. The trigger motors are tiny, so they start seeded louder and higher-floored than the main pair.",
        channels = {
            Low = copy(ERM_LOW),
            High = copy(ERM_HIGH),
            LTrigger = { floor = 0.15, gain = 1.20, attackTau = 0.040, releaseTau = 0.030 },
            RTrigger = { floor = 0.15, gain = 1.20, attackTau = 0.040, releaseTau = 0.030 },
        },
    },

    xbox_elite = {
        id = "xbox_elite",
        label = "Xbox Elite Series 2",
        triggers = true,
        note = "Two heavy ERM body motors plus impulse motors in both triggers. Slightly firmer trigger floor to compensate for weighted trigger stops.",
        channels = {
            Low = copy(ERM_LOW),
            High = copy(ERM_HIGH),
            LTrigger = { floor = 0.16, gain = 1.25, attackTau = 0.035, releaseTau = 0.028 },
            RTrigger = { floor = 0.16, gain = 1.25, attackTau = 0.035, releaseTau = 0.028 },
        },
    },

    switchpro = {
        id = "switchpro",
        label = "Switch Pro Controller",
        triggers = false,
        note = "HD Rumble is a pair of linear actuators. Driven through a generic rumble call rather than Nintendo's own API it tends to read weak, hence the raised strength.",
        channels = {
            Low = copy(LRA, { floor = 0.06, gain = 1.20 }),
            High = copy(LRA, { floor = 0.06, gain = 1.20 }),
        },
    },

    ["8bitdo"] = {
        id = "8bitdo",
        label = "8BitDo (Ultimate / Pro 2)",
        triggers = false,
        note = "Asymmetric ERM rumble motors common on Mac and PC. Slightly higher breakaway floor to overcome initial mechanical friction.",
        channels = {
            Low = copy(ERM_LOW, { floor = 0.14, attackTau = 0.080, releaseTau = 0.050 }),
            High = copy(ERM_HIGH, { floor = 0.12, attackTau = 0.045, releaseTau = 0.030 }),
        },
    },

    steamdeck = {
        id = "steamdeck",
        label = "Steam Deck (LCD & OLED)",
        triggers = false,
        note = "Dual trackpad LRAs driven by smart haptic drivers. Emulated dual-motor rumble requires elevated Low gain (+20%) to match traditional chassis displacement, while a 35ms attack tau smooths square-wave steps to eliminate audible trackpad chatter.",
        channels = {
            Low = copy(LRA, { floor = 0.050, gain = 1.20, attackTau = 0.035, releaseTau = 0.020, gamma = 0.90 }),
            High = copy(LRA, { floor = 0.040, gain = 1.05, attackTau = 0.015, releaseTau = 0.015 }),
        },
    },

    steamcontroller2 = {
        id = "steamcontroller2",
        label = "Steam Controller 2 (2026)",
        triggers = false,
        note = "Quad-LRA architecture: two trackpad LRAs for interface clicks plus two dedicated high-output grip LRAs for body rumble. Instantaneous transient response, wide dynamic range, and zero trackpad chatter.",
        channels = {
            Low = copy(LRA, { floor = 0.035, gain = 1.10, attackTau = 0.020, releaseTau = 0.015 }),
            High = copy(LRA, { floor = 0.035, gain = 1.05, attackTau = 0.015, releaseTau = 0.012 }),
        },
    },

    steamcontroller = {
        id = "steamcontroller",
        label = "Steam Controller (v1)",
        triggers = false,
        note = "Dual circular trackpad linear voice coils with no body rumble motors. Emulated rumble turns the touchpads into acoustic transducers; raised floor and 40ms attack prevent trigger spring rattle and harsh metallic buzz.",
        channels = {
            Low = copy(LRA, { floor = 0.060, gain = 1.10, attackTau = 0.040, releaseTau = 0.030 }),
            High = copy(LRA, { floor = 0.040, gain = 1.00, attackTau = 0.020, releaseTau = 0.020 }),
        },
    },
}

-- ── Detection ───────────────────────────────────────────────────────────────────────────
--
-- C_GamePad.GetDeviceRawState(deviceID) returns a GamePadRawState carrying `name`,
-- `vendorID` and `productID` (Blizzard_APIDocumentationGenerated/GamePadDocumentation.lua
-- :428-430, read from source). Name matching first: SDL normalises controller names, and a
-- name survives hardware revisions that change a product id. Vendor/product is the
-- fallback, vendor-only the last resort.
--
-- Detection only ever SUGGESTS. Nothing applies without the player pressing Apply, so a
-- wrong guess costs a dropdown selection rather than their calibration.
local NAME_PATTERNS = {
    { "dualsense", "dualsense" },
    { "ps5", "dualsense" },
    { "dualshock", "ds4" },
    { "ps4", "ds4" },
    { "steam deck", "steamdeck" },
    { "steam virtual gamepad", "steamdeck" },
    { "steam controller 2", "steamcontroller2" },
    { "steam controller", "steamcontroller" },
    { "nintendo", "switchpro" },
    { "switch pro", "switchpro" },
    { "pro controller", "switchpro" },
    { "elite", "xbox_elite" },
    { "xbox", "xbox" },
    { "xinput", "xbox" },
    { "8bitdo", "8bitdo" },
    { "sn30", "8bitdo" },
    { "pro 2", "8bitdo" },
    { "ultimate", "8bitdo" },
    { "wireless controller", "dualsense" },
}

-- USB vendor ids. Well established and unlikely to move.
local VENDOR_SONY = 0x054C
local VENDOR_MICROSOFT = 0x045E
local VENDOR_NINTENDO = 0x057E
local VENDOR_VALVE = 0x28DE

local PRODUCT_MAP = {
    [VENDOR_SONY] = {
        [0x05C4] = "ds4", -- DualShock 4 v1
        [0x09CC] = "ds4", -- DualShock 4 v2
        [0x0CE6] = "dualsense", -- DualSense
        [0x0DF2] = "dualsense", -- DualSense Edge
    },
    [VENDOR_NINTENDO] = {
        [0x2009] = "switchpro",
    },
    [VENDOR_VALVE] = {
        [0x1102] = "steamcontroller", -- Steam Controller v1 (USB wired)
        [0x1142] = "steamcontroller", -- Steam Controller v1 (wireless dongle)
        [0x1106] = "steamcontroller", -- Steam Controller v1 (BLE)
        [0x11FF] = "steamdeck", -- Steam Virtual Gamepad (Steam Input)
        [0x1201] = "steamcontroller2", -- Steam Controller 2 (wired)
        [0x1202] = "steamcontroller2", -- Steam Controller 2 (wireless)
        [0x1205] = "steamdeck", -- Steam Deck (LCD & OLED)
    },
}

-- Vendor-only fallback, for a product id this table has never heard of.
local VENDOR_FALLBACK = {
    [VENDOR_MICROSOFT] = "xbox", -- Microsoft gamepads are Xbox-pattern throughout
    [VENDOR_NINTENDO] = "switchpro",
    [VENDOR_VALVE] = "steamdeck", -- Default Valve controllers to modern LRA haptic profile
}

-- Returns deviceID, detectedPresetID, rawName — any may be nil. Never applies anything and
-- never errors: every read is guarded, because a controller reporting something unexpected
-- should cost a suggestion, not a Lua error on the settings page.
function Pulse.DetectDevice()
    if not C_GamePad or type(C_GamePad.GetActiveDeviceID) ~= "function" then
        return nil
    end
    local okID, deviceID = pcall(C_GamePad.GetActiveDeviceID)
    if not okID or not deviceID then
        return nil
    end
    if type(C_GamePad.GetDeviceRawState) ~= "function" then
        return deviceID
    end

    local okState, state = pcall(C_GamePad.GetDeviceRawState, deviceID)
    if not okState or type(state) ~= "table" then
        return deviceID
    end

    local name = state.name
    if issecretvalue(name) or type(name) ~= "string" then
        name = nil
    end

    if name then
        local lowered = name:lower()
        for _, entry in ipairs(NAME_PATTERNS) do
            if lowered:find(entry[1], 1, true) then
                return deviceID, entry[2], name
            end
        end
    end

    local vendor, product = state.vendorID, state.productID
    if issecretvalue(vendor) or type(vendor) ~= "number" then
        vendor = nil
    end
    if issecretvalue(product) or type(product) ~= "number" then
        product = nil
    end

    if vendor then
        local byProduct = PRODUCT_MAP[vendor]
        if byProduct and product and byProduct[product] then
            return deviceID, byProduct[product], name
        end
        if VENDOR_FALLBACK[vendor] then
            return deviceID, VENDOR_FALLBACK[vendor], name
        end
    end

    return deviceID, nil, name
end
