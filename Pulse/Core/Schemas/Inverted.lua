-- Pulse — Core/Schemas/Inverted.lua
--
-- Swapped / inverted motor routing: low-frequency roles go to the High motor, and high-frequency
-- roles go to the Low motor. For third-party gamepads wired in reverse, left-handed setups,
-- or players who prefer heavy rumble on the right hand.

local ADDON_NAME, Pulse = ...

Pulse.HapticSchemas = Pulse.HapticSchemas or {}

Pulse.HapticSchemas["inverted"] = {
    id = "inverted",
    order = 6,
    label = "Swapped / Inverted Rumble",
    desc = "Reverses the rumble motors: heavy low-frequency thuds go to the High motor, and sharp high-frequency ticks go to the Low motor. For reverse-wired or custom controller grips.",
    roles = {
        low = { channel = "High", intensity = 1.0 },
        high = { channel = "Low", intensity = 1.0 },
    },
}
