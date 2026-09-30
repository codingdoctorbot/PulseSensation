-- PulseProbe — Core.lua
--
-- The telemetry engine, circular log ring-buffer, and probe registration dispatcher.
-- Built for World of Warcraft Forever (_classic_beta_, build 1.60.1.69913, Interface 120100).
-- Adheres strictly to Lua 5.1, Rule 4 (Zero-GC in tight loops), and Rule 5 (Taint Immunity).

local ADDON_NAME, Probe = ...
_G.PulseProbe = Probe

Probe.Name = ADDON_NAME
Probe.Version = "0.1.0"
Probe.Probes = {}
Probe.Listeners = {}

-- Static colors for diagnostic output
Probe.Colors = {
	PRIMARY = "|cff00ccff",
	SUCCESS = "|cff44ff44",
	WARNING = "|cffffcc00",
	DANGER = "|cffff4444",
	MUTED = "|cff888888",
	HIGHLIGHT = "|cffffffff",
	RESET = "|r",
}

-- Ring-buffer configuration (fixed 100 entries, zero GC allocation on push)
local MAX_LOG_ENTRIES = 100
Probe.LogEntries = {}
for i = 1, MAX_LOG_ENTRIES do
	Probe.LogEntries[i] = {
		id = i,
		timestamp = 0,
		timeStr = "",
		category = "",
		eventName = "",
		payloadStr = "",
		isSecret = false,
		isTainted = false,
		mockCue = "",
	}
end
Probe.LogCount = 0
Probe.LogHead = 0 -- Pointer to newest entry (1..MAX_LOG_ENTRIES)
Probe.IsPaused = false

---------------------------------------------------------------------------
-- Circular Log Buffer (Zero GC)
---------------------------------------------------------------------------

function Probe:AddLogEntry(category, eventName, payloadStr, isSecret, isTainted, mockCue)
	if self.IsPaused then
		return
	end

	self.LogHead = (self.LogHead % MAX_LOG_ENTRIES) + 1
	if self.LogCount < MAX_LOG_ENTRIES then
		self.LogCount = self.LogCount + 1
	end

	local entry = self.LogEntries[self.LogHead]
	entry.timestamp = GetTime()
	entry.timeStr = date("%H:%M:%S")
	entry.category = category or "General"
	entry.eventName = eventName or "UNKNOWN"
	entry.payloadStr = payloadStr or ""
	entry.isSecret = isSecret and true or false
	entry.isTainted = isTainted and true or false
	entry.mockCue = mockCue or ""

	-- Dispatch to audio & haptic simulator
	if self.AudioHaptic and self.AudioHaptic.OnProbeFired then
		self.AudioHaptic:OnProbeFired(category, eventName, mockCue)
	end

	-- Notify UI listeners
	if self.UI and self.UI.OnNewLogEntry then
		self.UI:OnNewLogEntry(entry)
	end
end

function Probe:ClearLogs()
	self.LogCount = 0
	self.LogHead = 0
	if self.UI and self.UI.RefreshLogView then
		self.UI:RefreshLogView()
	end
end

---------------------------------------------------------------------------
-- Event-order trace (Phase 0 measurement)
---------------------------------------------------------------------------
--
-- A second, much larger ring for ordering questions the 100-entry display log cannot
-- answer: which event of a pair arrives first, whether two arrive in the same frame, and
-- how far apart they are in wall time. Struct-of-arrays, sized once, overwritten in
-- place: recording an event stores references and numbers, never builds a table or a
-- string (Rule 4).
--
-- Three clocks, because none is sufficient alone:
--   frame    increments once per OnUpdate. Same value = delivered between the same two frames.
--   arrival  1, 2, 3 ... within one frame: delivery order inside that frame.
--   precise  GetTimePreciseSec() (OsDocumentation.lua) — monotonic, sub-millisecond.
--   profile  debugprofilestop() (FrameScriptDocumentation.lua) — ms since the LAST
--            debugprofilestart() by ANY addon, so kept only as a cross-check; this file
--            never calls debugprofilestart(), which would reset every other profiler.
-- GetTime() is deliberately absent: it is frame-cached, so it cannot order same-frame events.

local TRACE_CAP = 4096
local tEvent, tFrame, tArrival, tPrecise, tProfile = {}, {}, {}, {}, {}
local tA1, tA2, tA3 = {}, {}, {}
for i = 1, TRACE_CAP do
	tEvent[i], tFrame[i], tArrival[i], tPrecise[i], tProfile[i] = "", 0, 0, 0, 0
	tA1[i], tA2[i], tA3[i] = false, false, false
end

local trace = { head = 0, count = 0, running = false, scenario = "", frame = 0, arrival = 0 }
Probe.TraceState = trace

local SECRET = "<secret>"
local preciseClock = (type(GetTimePreciseSec) == "function") and GetTimePreciseSec or GetTime
local profileClock = (type(debugprofilestop) == "function") and debugprofilestop or function()
	return 0
end

-- Numbers, booleans and strings are stored as-is (a string the client passed in already
-- exists; keeping a reference allocates nothing). Anything else is reduced to its type
-- name; secret values are masked, never compared or formatted.
local function scalar(v)
	if v == nil then
		return false
	end
	if issecretvalue and issecretvalue(v) then
		return SECRET
	end
	local kind = type(v)
	if kind == "number" or kind == "boolean" or kind == "string" then
		return v
	end
	return kind
end

local clockFrame = CreateFrame("Frame")
clockFrame:SetScript("OnUpdate", function()
	trace.frame = trace.frame + 1
	trace.arrival = 0
end)

function Probe:Record(event, a1, a2, a3)
	if not trace.running then
		return
	end
	trace.arrival = trace.arrival + 1
	local i = (trace.head % TRACE_CAP) + 1
	trace.head = i
	if trace.count < TRACE_CAP then
		trace.count = trace.count + 1
	end
	tEvent[i] = event
	tFrame[i] = trace.frame
	tArrival[i] = trace.arrival
	tPrecise[i] = preciseClock()
	tProfile[i] = profileClock()
	tA1[i], tA2[i], tA3[i] = scalar(a1), scalar(a2), scalar(a3)
end

function Probe:TraceStart(scenario)
	trace.head, trace.count = 0, 0
	trace.scenario = scenario or "unnamed"
	trace.running = true
end

function Probe:TraceStop()
	trace.running = false
end

-- The only place that allocates: copies the ring, oldest first, into SavedVariables for
-- offline analysis (scripts/probe-trace-report.lua). Player-initiated, never in play.
function Probe:TraceDump()
	local db = self.DB
	if not db then
		return 0
	end
	db.traces = db.traces or {}
	local rows = {}
	local first = (trace.count < TRACE_CAP) and 1 or ((trace.head % TRACE_CAP) + 1)
	for n = 0, trace.count - 1 do
		local i = ((first - 1 + n) % TRACE_CAP) + 1
		rows[#rows + 1] = {
			tEvent[i],
			tFrame[i],
			tArrival[i],
			tPrecise[i],
			tProfile[i],
			tA1[i],
			tA2[i],
			tA3[i],
		}
	end
	db.traces[#db.traces + 1] = {
		scenario = trace.scenario,
		build = select(2, GetBuildInfo()),
		interface = select(4, GetBuildInfo()),
		rows = rows,
	}
	return #rows
end

---------------------------------------------------------------------------
-- Probe Module Registration
---------------------------------------------------------------------------

function Probe:RegisterProbe(name, moduleTable)
	self.Probes[name] = moduleTable
	if moduleTable.OnInit then
		moduleTable:OnInit(self)
	end
end

---------------------------------------------------------------------------
-- Slash Command & Lifecycle Frame
---------------------------------------------------------------------------

local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_LOGIN")

coreFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		_G.PulseProbeDB = _G.PulseProbeDB
			or {
				soundEnabled = true,
				hapticsEnabled = true,
				autoShowOnLogin = false,
				categoryFilters = {
					Combat = true,
					Pets = true,
					World = true,
					Navigation = true,
					Economy = true,
					Errors = true,
				},
			}
		Probe.DB = _G.PulseProbeDB

		-- Initialize modules that require saved variables
		for _, probeMod in pairs(Probe.Probes) do
			if probeMod.OnDBReady then
				probeMod:OnDBReady(Probe.DB)
			end
		end
	elseif event == "PLAYER_LOGIN" then
		for _, probeMod in pairs(Probe.Probes) do
			if probeMod.OnEnable then
				probeMod:OnEnable()
			end
		end

		local C = Probe.Colors
		print(
			C.PRIMARY
				.. "[PulseProbe]"
				.. C.RESET
				.. " v"
				.. Probe.Version
				.. " loaded. Type "
				.. C.HIGHLIGHT
				.. "/probe"
				.. C.RESET
				.. " or "
				.. C.HIGHLIGHT
				.. "/pulselab"
				.. C.RESET
				.. " to open the Cue Laboratory."
		)

		if Probe.DB and Probe.DB.autoShowOnLogin and Probe.UI then
			Probe.UI:Show()
		end
	end
end)

SLASH_PULSEPROBE1 = "/probe"
SLASH_PULSEPROBE2 = "/pulselab"
SlashCmdList["PULSEPROBE"] = function(msg)
	local cmd = msg and msg:trim():lower() or ""
	local verb, rest = cmd:match("^trace%s*(%S*)%s*(.*)$")
	if verb then
		if verb == "start" then
			Probe:TraceStart(rest ~= "" and rest or "unnamed")
			print(Probe.Colors.PRIMARY .. "[PulseProbe]" .. Probe.Colors.RESET .. " trace started: " .. rest)
		elseif verb == "stop" then
			Probe:TraceStop()
			print(Probe.Colors.PRIMARY .. "[PulseProbe]" .. Probe.Colors.RESET .. " trace stopped")
		elseif verb == "mark" then
			Probe:Record("MARK", rest)
		elseif verb == "dump" then
			local n = Probe:TraceDump()
			print(
				Probe.Colors.PRIMARY
					.. "[PulseProbe]"
					.. Probe.Colors.RESET
					.. (" dumped %d rows; /reload to write"):format(n)
			)
		end
		return
	end
	if cmd == "clear" then
		Probe:ClearLogs()
		print(Probe.Colors.PRIMARY .. "[PulseProbe]" .. Probe.Colors.RESET .. " Log cleared.")
	elseif cmd == "sound" then
		Probe.DB.soundEnabled = not Probe.DB.soundEnabled
		print(
			Probe.Colors.PRIMARY
				.. "[PulseProbe]"
				.. Probe.Colors.RESET
				.. " Mock Sound: "
				.. (Probe.DB.soundEnabled and (Probe.Colors.SUCCESS .. "ON") or (Probe.Colors.DANGER .. "OFF"))
				.. Probe.Colors.RESET
		)
	elseif cmd == "haptic" or cmd == "rumble" then
		Probe.DB.hapticsEnabled = not Probe.DB.hapticsEnabled
		print(
			Probe.Colors.PRIMARY
				.. "[PulseProbe]"
				.. Probe.Colors.RESET
				.. " Gamepad Haptics: "
				.. (Probe.DB.hapticsEnabled and (Probe.Colors.SUCCESS .. "ON") or (Probe.Colors.DANGER .. "OFF"))
				.. Probe.Colors.RESET
		)
	else
		if Probe.UI then
			Probe.UI:Toggle()
		else
			print(Probe.Colors.DANGER .. "[PulseProbe] UI not yet loaded." .. Probe.Colors.RESET)
		end
	end
end
