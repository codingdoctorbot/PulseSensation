package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
local S = E.S
-- Pull LEGACY_V8_OVERRIDES out of HEAD's Database.lua text (lines 1496-1908).
local lines = {}
for l in io.lines(S .. "/head/PulseHaptics/Core/Database.lua") do lines[#lines + 1] = l end
local src = { "return {" }
for i = 1497, 1908 do src[#src + 1] = lines[i] end
local LEGACY = assert(loadstring(table.concat(src, "\n")))()
E.stubs(S .. "/head/PulseChecklist/tests/harness.lua")
print = function() end
local P = E.loadAddon(S .. "/head/PulseHaptics", E.CORE)
local v8 = dofile(S .. "/v8db.lua")
for _, name in ipairs({ "Questing", "Raiding", "PvP", "Default" }) do
  local lo = LEGACY[name]
  local mism = {}
  for _, t in ipairs(P.Triggers) do
    local cur = v8.profiles[name].triggers[t.id] and true or false
    local exp
    if lo then
      exp = lo[t.id]
      if exp == nil then exp = not lo.__exclusive and (t.default and true or false) or false else exp = exp and true or false end
    else exp = t.default and true or false end
    if cur ~= exp then mism[#mism + 1] = t.id .. (cur and "(on)" or "(off)") end
  end
  io.write(name, " legacy-table=", tostring(lo ~= nil), " exclusive=", tostring(lo and lo.__exclusive), " mismatches vs legacy=", #mism, ": ", table.concat(mism, " "), "\n")
  io.write("   masterIntensity v8=", tostring(v8.profiles[name].masterIntensity), "\n")
end
