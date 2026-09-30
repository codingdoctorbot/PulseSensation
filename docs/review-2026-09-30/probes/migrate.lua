-- Probe: does an untouched v8 install receive the curated built-in profiles after upgrading
-- to HEAD (DB_VERSION 10)? Usage:
--   luajit migrate.lua make-v8 [tree] -> writes v8db.lua from a fresh install with the code
--                                        of snapshot [tree] (default "v8" = dace2ab, the last
--                                        pre-curation commit; "pre" = db2ffa5, curated v8)
--   luajit migrate.lua make-head      -> writes headfresh.lua from HEAD code (fresh install)
--   luajit migrate.lua upgrade        -> loads v8db.lua into HEAD code, compares with headfresh
package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
local mode = arg[1]
local S = E.S
local v8tree = arg[2] or "v8"

local function write(path, tbl)
	local f = assert(io.open(path, "w"))
	f:write("return " .. E.ser(tbl))
	f:close()
end

if mode == "make-v8" then
	E.stubs(S .. "/" .. v8tree .. "/PulseChecklist/tests/harness.lua")
	print = function() end
	local P = E.loadAddon(S .. "/" .. v8tree .. "/PulseHaptics", E.CORE)
	PulseDB = nil
	P.Database:Init()
	write(S .. "/v8db.lua", PulseDB)
	io.write("v8 source tree=", v8tree, " version=", tostring(PulseDB.version), "\n")
elseif mode == "make-head" then
	E.stubs(S .. "/head/PulseChecklist/tests/harness.lua")
	print = function() end
	local P = E.loadAddon(S .. "/head/PulseHaptics", E.CORE)
	PulseDB = nil
	P.Database:Init()
	write(S .. "/headfresh.lua", PulseDB)
	io.write("head version=", tostring(PulseDB.version), "\n")
elseif mode == "upgrade" then
	E.stubs(S .. "/head/PulseChecklist/tests/harness.lua")
	print = function() end
	local P = E.loadAddon(S .. "/head/PulseHaptics", E.CORE)
	PulseDB = dofile(S .. "/v8db.lua")
	local fresh = dofile(S .. "/headfresh.lua")
	local v8copy = dofile(S .. "/v8db.lua")
	P.Database:Init()
	io.write("after upgrade version=", tostring(PulseDB.version), "\n")
	io.write(string.format("%-20s %6s %6s %6s %8s %s\n", "profile", "v8on", "nowon", "curOn", "differ", "curatedVersion"))
	for _, name in ipairs({
		"Default", "Dungeon: Tank", "Dungeon: Healer", "Dungeon: Melee", "Dungeon: Caster",
		"Dungeon: Hunter", "Immersion: Melee", "Immersion: Caster", "Immersion: Ranged",
		"PvP", "Raiding", "Questing",
	}) do
		local now = PulseDB.profiles[name]
		local cur = fresh.profiles[name]
		local old = v8copy.profiles[name]
		local nOn, cOn, oOn, diff = 0, 0, 0, 0
		for _, t in ipairs(P.Triggers) do
			local a = now.triggers[t.id] and true or false
			local b = cur.triggers[t.id] and true or false
			if a then nOn = nOn + 1 end
			if b then cOn = cOn + 1 end
			if old and old.triggers[t.id] then oOn = oOn + 1 end
			if a ~= b then diff = diff + 1 end
		end
		io.write(string.format("%-20s %6d %6d %6d %8d %s\n", name, oOn, nOn, cOn, diff, tostring(now.__curatedVersion)))
	end
	-- Why: which check in isProfileUntouched fails for Default?
	local d = v8copy.profiles["Default"].triggerSettings
	io.write("v8 Default swimTexture.separateMotors=", tostring(d.swimTexture and d.swimTexture.separateMotors),
		" strokeDepth=", tostring(d.swimTexture and d.swimTexture.strokeDepth),
		" castTexture.castPresence=", tostring(d.castTexture and d.castTexture.castPresence), "\n")
	local s = PulseDB.profiles["Default"].triggerSettings
	io.write("after Default swimTexture.separateMotors=", tostring(s.swimTexture.separateMotors),
		" strokeDepth=", tostring(s.swimTexture.strokeDepth),
		" castTexture.castPresence=", tostring(s.castTexture.castPresence),
		" castSwellPeak=", tostring(s.castTexture.castSwellPeak),
		" channelHum=", tostring(s.castTexture.channelHum), "\n")
end
