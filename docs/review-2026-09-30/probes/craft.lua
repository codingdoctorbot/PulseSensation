-- Probe: (a) castTexture while fishing/gathering with craftTexture OFF and castTexture ON;
--        (b) PreviewCraft strike timers vs the preview token.
package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
local S = E.S
E.stubs(S .. "/head/PulseChecklist/tests/harness.lua")
print = function() end

-- capture frames so OnUpdate scripts can be driven by hand
local allFrames = {}
local realCreateFrame = CreateFrame
CreateFrame = function(...)
	local f = realCreateFrame(...)
	allFrames[#allFrames + 1] = f
	return f
end
-- controllable clock and timers
local now = 100
GetTime = function() return now end
local timers = {}
C_Timer.After = function(d, fn) timers[#timers + 1] = { at = now + d, fn = fn } end
C_Timer.NewTicker = function() return { Cancel = function() end } end
C_Timer.NewTimer = function() return { Cancel = function() end } end
local function runTimers()
	local keep = {}
	for _, t in ipairs(timers) do
		if t.at <= now then t.fn() else keep[#keep + 1] = t end
	end
	timers = keep
end

local channel = nil -- { name, spellId, startMs, endMs }
UnitChannelInfo = function()
	if not channel then return nil end
	return channel.name, channel.name, 136245, channel.startMs, channel.endMs, false, false, channel.spellId
end
UnitCastingInfo = function() return nil end
C_GamePad.IsEnabled = function() return true end
C_GamePad.GetActiveDeviceID = function() return 1 end

local files = {}
for _, f in ipairs(E.CORE) do files[#files + 1] = f end
for _, f in ipairs({ "Modules/Combat.lua", "Modules/Crafting.lua", "Modules/Casting.lua" }) do files[#files + 1] = f end
local P = E.loadAddon(S .. "/head/PulseHaptics", files)
PulseDB = nil
P.Database:Init()
P.Engine:Init()
P.Engine:RefreshDevice()
for _, name in ipairs(P.moduleOrder) do
	local m = P.modules[name]
	if m.OnEnable then m:OnEnable() end
end

-- spy on engine holds
local holds = {}
local realSetRoles = P.Engine.SetRoles
P.Engine.SetRoles = function(self, name, roles, ...)
	holds[#holds + 1] = { name = name, low = roles.low, high = roles.high, t = now }
	return realSetRoles(self, name, roles, ...)
end
local realPlayMode = P.Engine.PlayMode
local plays = {}
P.Engine.PlayMode = function(self, name, mode, scale, ...)
	plays[#plays + 1] = { name = name, mode = mode, scale = scale, t = now }
	return realPlayMode(self, name, mode, scale, ...)
end

local function driveOnUpdates(frames)
	for _, f in ipairs(allFrames) do
		local s = f.__script_OnUpdate
		if s then s(f, 0.016) end
	end
end

-- (a) castTexture ON, craftTexture OFF
P.Database:SetCue("castTexture", true)
P.Database:SetCue("craftTexture", false)
io.write("castTexture=", tostring(P.Database:GetCue("castTexture")), " craftTexture=", tostring(P.Database:GetCue("craftTexture")), "\n")

local function scenario(label, spellId, name)
	holds = {}
	channel = { name = name, spellId = spellId, startMs = now * 1000, endMs = (now + 20) * 1000 }
	P.CastActivity:_OnChannelStart("player", "Cast-guid-" .. spellId, spellId)
	for _ = 1, 30 do now = now + 0.016; driveOnUpdates() end
	local castHolds = 0
	for _, h in ipairs(holds) do if h.name == "castTexture" then castHolds = castHolds + 1 end end
	io.write(string.format("(a) %-28s castTexture holds over 30 frames = %d  IsCrafting=%s\n", label, castHolds, tostring(P.IsCrafting())))
	channel = nil
	P.CastActivity:_OnChannelStop("player", "Cast-guid-" .. spellId, spellId)
	now = now + 1
end
scenario("channel: Fishing (7620)", 7620, "Fishing")
scenario("channel: Mind Flay-like (15407)", 15407, "Mind Flay")

-- (b) PreviewCraft
holds, plays, timers = {}, {}, {}
local ok, err = P:TestCue("craftTexture")
io.write("(b) TestCue(craftTexture) -> ", tostring(ok), " ", tostring(err), "  pending timers=", #timers, "\n")
for _ = 1, 200 do
	now = now + 0.016
	runTimers()
	driveOnUpdates()
end
local thud = 0
for _, p in ipairs(plays) do if p.mode == "THUD" then thud = thud + 1 end end
io.write("(b) THUD strikes played during 3.2 s craft preview = ", thud, " (code schedules 2)\n")
