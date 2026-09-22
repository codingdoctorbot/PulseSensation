-- Pulse — Core/Schemas/LowOnly.lua
-- See Standard.lua for the role contract. Routing only — strength lives on the
-- Controller calibration page.

local ADDON_NAME, Pulse = ...

Pulse.HapticSchemas = Pulse.HapticSchemas or {}

-- Mirror of HighOnly: for a high motor that produces nothing at all. Both rumble roles and
-- both trigger roles land on Low.
Pulse.HapticSchemas["lowOnly"] = {
    id    = "lowOnly",
    order = 3,
    label = "Low Motor Only",
    desc  = "Use when the high motor produces nothing you can feel at all. Everything collapses onto the low motor. If it works but is just weak, use Standard and raise its Strength on the Controller calibration page instead.",
    roles = {
        low      = { channel = "Low", intensity = 1.0 },
        high     = { channel = "Low", intensity = 1.0 },
        ltrigger = { channel = "Low", intensity = 0.7 },
        rtrigger = { channel = "Low", intensity = 1.0 },
    },
}
