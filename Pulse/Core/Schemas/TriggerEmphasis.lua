-- Pulse — Core/Schemas/TriggerEmphasis.lua
--
-- Everything on the triggers, nothing on the rumble motors — for a controller where the
-- trigger actuators are easier to feel than the rumble. Ported from Tremor; these are the
-- original "LTrigger"/"RTrigger" strings this project has always carried without
-- confirming. See RumbleAndTriggers.lua for why they are unverified.

local ADDON_NAME, Pulse = ...

Pulse.HapticSchemas = Pulse.HapticSchemas or {}

Pulse.HapticSchemas["triggerEmphasis"] = {
    id    = "triggerEmphasis",
    order = 5,
    label = "Triggers Only",
    desc  = "Sends everything to the trigger actuators and silences the rumble motors. Test the triggers on the Controller calibration page before choosing this — if they do nothing, this schema is silence.",
    roles = {
        low      = { channel = "LTrigger", intensity = 0.7 },
        high     = { channel = "RTrigger", intensity = 1.0 },
        ltrigger = { channel = "LTrigger", intensity = 1.0 },
        rtrigger = { channel = "RTrigger", intensity = 1.0 },
    },
}
