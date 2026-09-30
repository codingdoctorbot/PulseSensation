-- Probe: settings-page placement of every cue, and which built-in profiles have catalogue
-- metadata (F-08). Runs against 1ca6a24.
package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
E.stubs(E.S .. "/h2/PulseChecklist/tests/harness.lua")
print = function() end
local P = E.loadAddon(E.S .. "/h2/PulseHaptics", E.CORE)

local seen, dups, n = {}, {}, 0
for _, page in ipairs(P.Registry:GetPages()) do
	for _, sec in ipairs(page.sections) do
		for _, t in ipairs(sec.triggers) do
			n = n + 1
			if seen[t.id] then
				dups[#dups + 1] = t.id .. " (" .. seen[t.id] .. " & " .. page.id .. ")"
			end
			seen[t.id] = page.id
		end
	end
end
local unique = 0
for _ in pairs(seen) do
	unique = unique + 1
end
local unplaced = {}
for _, t in ipairs(P.Triggers) do
	if not seen[t.id] then
		unplaced[#unplaced + 1] = t.id
	end
end
io.write("triggers=", #P.Triggers, " placements=", n, " unique=", unique, " duplicates=", #dups, " ", table.concat(dups, ", "), "\n")
io.write("not on any page (category masters render on the root page): ", table.concat(unplaced, ", "), "\n")

PulseDB = nil
P.Database:Init()
local meta = {}
for _, m in ipairs(P.DEFAULT_PROFILE_METADATA) do
	meta[m.id] = true
end
local missing = {}
for _, name in ipairs(P.Database:GetProfileNames()) do
	if P.Database:IsBuiltinProfile(name) and not meta[name] then
		missing[#missing + 1] = name
	end
end
io.write("built-in profiles: ", #P.Database:GetProfileNames(), "  with catalogue metadata: ", #P.DEFAULT_PROFILE_METADATA, "\n")
io.write("built-ins absent from the 'Default profiles' page: ", table.concat(missing, ", "), "\n")
