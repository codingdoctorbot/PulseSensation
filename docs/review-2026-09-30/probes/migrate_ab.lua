-- A/B: same upgrade as migrate.lua "upgrade", but with the four tunable defaults that
-- ad0ef89 changed put back to their v8 values in memory before Database:Init runs.
package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
local S = E.S
E.stubs(S .. "/head/PulseChecklist/tests/harness.lua")
print = function() end
local P = E.loadAddon(S .. "/head/PulseHaptics", E.CORE)
local OLD = { swimTexture = { separateMotors = true, strokeDepth = 0.55 },
              castTexture = { castPresence = 0.1, castSwellPeak = 0.7, channelHum = 0.2 } }
for _, t in ipairs(P.Triggers) do
  if OLD[t.id] then for _, tun in ipairs(t.tunables) do if OLD[t.id][tun.key] ~= nil then tun.default = OLD[t.id][tun.key] end end end
end
PulseDB = dofile(S .. "/v8db.lua")
local fresh = dofile(S .. "/headfresh.lua")
P.Database:Init()
for _, name in ipairs({ "Dungeon: Tank", "Immersion: Melee", "PvP", "Raiding", "Questing" }) do
  local diff = 0
  for _, t in ipairs(P.Triggers) do
    if (PulseDB.profiles[name].triggers[t.id] and true or false) ~= (fresh.profiles[name].triggers[t.id] and true or false) then diff = diff + 1 end
  end
  io.write(string.format("B (old tunable defaults restored): %-18s differ=%d\n", name, diff))
end
