-- Pulse — Core/Schemas/RumbleAndTriggers.lua
--
-- All four channels at once: rumble stays on the rumble motors, and trigger roles reach the
-- trigger actuators instead of falling back onto rumble. This is the schema that makes a
-- four-channel engine actually four channels.
--
-- UNCONFIRMED, and honestly so. C_GamePad.SetVibration takes `vibrationType` as a bare
-- cstring with no enum and no documented value list in the client source
-- (Blizzard_APIDocumentationGenerated/GamePadDocumentation.lua); "LTrigger"/"RTrigger"
-- appear in Blizzard's code only as button-binding labels. The strings are inherited from
-- Tremor via TriggerEmphasis.lua, which has shipped them all along without anyone
-- confirming they do anything. An unrecognised string is a no-op rather than an error, so
-- the worst case is a silent trigger half and a trip back to Standard.

local ADDON_NAME, Pulse = ...

Pulse.HapticSchemas = Pulse.HapticSchemas or {}

Pulse.HapticSchemas["rumbleAndTriggers"] = {
    id    = "rumbleAndTriggers",
    order = 4,
    label = "Rumble + Triggers",
    desc  = "Rumble on the rumble motors, trigger cues on the triggers. Only worth choosing if you can actually feel the trigger test on the Controller calibration page — nothing documents whether this client drives trigger actuators at all.",
    roles = {
        low      = { channel = "Low",      intensity = 1.0 },
        high     = { channel = "High",     intensity = 1.0 },
        ltrigger = { channel = "LTrigger", intensity = 1.0 },
        rtrigger = { channel = "RTrigger", intensity = 1.0 },
    },
}
