package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
local S = E.S
E.stubs(S .. "/h2/PulseChecklist/tests/harness.lua")
print = function() end
local now = 0
GetTime = function() return now end
local frames = {}
local rc = CreateFrame
CreateFrame = function(...) local f = rc(...); frames[#frames + 1] = f; return f end
local sent = {}
C_GamePad.IsEnabled = function() return true end
C_GamePad.GetActiveDeviceID = function() return 1 end
C_GamePad.SetVibration = function(ch, v) sent[ch] = v end
local P = E.loadAddon(S .. "/h2/PulseHaptics", E.CORE)
PulseDB = nil
P.Database:Init(); P.Engine:Init(); P.Engine:RefreshDevice()
local tick
for _, f in ipairs(frames) do if f.__script_OnUpdate then local s, fr = f.__script_OnUpdate, f; tick = function(dt) s(fr, dt) end end end
for _ = 1, 30 do now = now + 1/60; P.Engine:Hold("probe", 0.5, 0.3); tick(1/60) end
local o = P.Engine:GetChannelOutputs({})
local d = P.Engine:_DebugChannels()
local keys = {}
for k in pairs(d) do keys[#keys + 1] = k end
io.write(string.format("SetVibration sent: Low=%.3f High=%.3f\n", sent.Low or -1, sent.High or -1))
io.write(string.format("GetChannelOutputs: low=%.3f high=%.3f anyActive=%s\n", o.low, o.high, tostring(o.anyActive)))
io.write("_DebugChannels keys: ", table.concat(keys, ","), "  (Oscilloscope fallback reads .low/.high: ", tostring(d.low), ",", tostring(d.high), ")\n")
io.write("GetActiveLayerCount: ", P.Engine:GetActiveLayerCount(), "\n")
