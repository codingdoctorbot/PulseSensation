-- Probe: steady-state motor command for default continuous-cue levels, through the REAL
-- Engine.lua of a given tree, per device preset. Usage: luajit softfloor.lua <tree> <master>
package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
local S = E.S
local tree = arg[1] or "head"
local master = tonumber(arg[2] or "0.7")
E.stubs(S .. "/" .. tree .. "/PulseChecklist/tests/harness.lua")
print = function() end
local now = 0
GetTime = function() return now end
local frames = {}
local realCreateFrame = CreateFrame
CreateFrame = function(...) local f = realCreateFrame(...); frames[#frames + 1] = f; return f end
local sent = {}
C_GamePad.IsEnabled = function() return true end
C_GamePad.GetActiveDeviceID = function() return 1 end
C_GamePad.SetVibration = function(ch, v) sent[ch] = v end
C_GamePad.StopVibration = function() sent.Low = 0; sent.High = 0 end
local P = E.loadAddon(S .. "/" .. tree .. "/PulseHaptics", E.CORE)
PulseDB = nil
P.Database:Init()
P.Engine:Init()
P.Engine:RefreshDevice()
P.Database:Set("masterIntensity", master)
local tick
for _, f in ipairs(frames) do
	local s = f.__script_OnUpdate
	if s then tick = function(dt) s(f, dt) end end
end

local CUES = {
	{ "waterTexture baseline", "low", 0.04 },
	{ "castPresence (fishing: only signal)", "low", 0.06 },
	{ "stealthTexture baseline", "low", 0.06 },
	{ "taxiRide mean (0.1*0.75)", "low", 0.075 },
	{ "swimTexture peak (full speed)", "low", 0.10 },
	{ "craftTexture bed (Blacksmithing)", "low", 0.10 },
	{ "channelHum (non-fishing channel)", "high", 0.12 },
	{ "weather rain (intensity 1.0)", "high", 0.12 },
	{ "oceanTexture swellStrength", "low", 0.14 },
	{ "glideThrust presenceFloor", "low", 0.15 },
	{ "castSwellPeak at completion", "high", 0.40 },
}
local PRESETS = { "default", "xbox", "ds4", "8bitdo", "xbox_elite", "dualsense" }

local function steady(role, value)
	P.Engine:StopAll()
	for k in pairs(sent) do sent[k] = nil end
	local low = role == "low" and value or 0
	local high = role == "high" and value or 0
	for _ = 1, 90 do
		now = now + 1 / 60
		P.Engine:Hold("probe", low, high, nil, false)
		tick(1 / 60)
	end
	return sent[role == "low" and "Low" or "High"] or 0
end

io.write(string.format("tree=%s master=%.2f  (cell = steady motor command / preset floor; * = below floor)\n", tree, master))
io.write(string.format("%-38s", "cue (role, authored value)"))
for _, p in ipairs(PRESETS) do io.write(string.format("%13s", p)) end
io.write("\n")
for _, c in ipairs(CUES) do
	io.write(string.format("%-38s", c[1] .. " " .. c[2] .. " " .. c[3]))
	for _, p in ipairs(PRESETS) do
		P.Database:ApplyDevicePreset(p)
		local ch = c[2] == "low" and "Low" or "High"
		local floor = P.Database:GetChannelTuning(ch, "floor", 0)
		local v = steady(c[2], c[3])
		local mark = (floor > 0 and v < floor) and "*" or " "
		io.write(string.format("  %5.3f/%4.3f%s", v, floor, mark))
	end
	io.write("\n")
end
