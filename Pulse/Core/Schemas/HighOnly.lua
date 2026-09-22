-- Pulse — Core/Schemas/HighOnly.lua
-- See Standard.lua for the role contract. Routing only — strength lives on the
-- Controller calibration page.

local ADDON_NAME, Pulse = ...

Pulse.HapticSchemas = Pulse.HapticSchemas or {}

-- For a controller whose low motor produces NOTHING, not one that is merely quieter — a
-- quieter motor is a Strength slider on the calibration page, and collapsing both roles
-- onto one channel costs the ability to tell two cues apart. Every role lands on High,
-- trigger roles included, so nothing goes silent. `low` arrives at 0.6 so the two stay
-- distinguishable once they share a motor: that is telling roles apart after a collapse,
-- which is routing, not how strong the motor is.
Pulse.HapticSchemas["highOnly"] = {
    id    = "highOnly",
    order = 2,
    label = "High Motor Only",
    desc  = "Use when the low motor produces nothing you can feel at all. Everything collapses onto the high motor. If the low motor works but is just weak, use Standard and raise its Strength on the Controller calibration page instead.",
    roles = {
        low      = { channel = "High", intensity = 0.6 },
        high     = { channel = "High", intensity = 1.0 },
        ltrigger = { channel = "High", intensity = 0.6 },
        rtrigger = { channel = "High", intensity = 1.0 },
    },
}
