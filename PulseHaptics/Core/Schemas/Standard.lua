-- Pulse — Core/Schemas/Standard.lua
--
-- A schema answers exactly ONE question: when a layer asks for a logical role, which
-- physical C_GamePad channel fires, and at what relative level if the mapping is not
-- one-to-one. Core/Engine.lua resolves this every OnUpdate tick.
--
-- 2026-09-21: schemas are ROUTING ONLY. How hard a motor has to be driven — strength
-- balance, breakaway floor, response times, response curve — lives in Core/Devices.lua and
-- the Controller calibration page, tunable per channel by feel. "High Motor Only" used to
-- do double duty as both "my low motor is dead" (routing) and "the high motor is too loud"
-- (balance); only one of those is routing.
--
-- Trigger roles are deliberately UNMAPPED here. A schema that names no mapping for
-- `ltrigger`/`rtrigger` gets Engine.lua's fallback instead — ltrigger follows low, rtrigger
-- follows high — so a cue that asks for a trigger is still felt on a controller with no
-- trigger actuators. Pick "Rumble + Triggers" to route them for real.

local ADDON_NAME, Pulse = ...

Pulse.HapticSchemas = Pulse.HapticSchemas or {}

Pulse.HapticSchemas["standard"] = {
    id    = "standard",
    order = 1,
    label = "Standard Rumble",
    desc  = "Both rumble motors work normally. Start here, then balance their strength on the Controller calibration page.",
    roles = {
        low  = { channel = "Low",  intensity = 1.0 },
        high = { channel = "High", intensity = 1.0 },
    },
}
