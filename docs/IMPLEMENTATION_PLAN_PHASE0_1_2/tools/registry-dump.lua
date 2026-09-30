-- IMPLEMENTATION_PLAN_PHASE0_1_2/tools/registry-dump.lua
--
-- Dumps every trigger in PulseHaptics/Core/Registry.lua: id, functional category, mode,
-- throttle, default, continuous, declarative events, and settings page/section. Standalone
-- analysis tool (not an addon file, not linted or packaged). Run from the repository root:
--
--   luajit IMPLEMENTATION_PLAN_PHASE0_1_2/tools/registry-dump.lua > registry-dump.txt
local P = {}
assert(loadfile("PulseHaptics/Core/Registry.lua"))("PulseHaptics", P)
local where = {}
for _, page in ipairs(P.Registry:GetPages()) do
	for _, section in ipairs(page.sections) do
		for _, cue in ipairs(section.cues) do
			where[cue] = page.id .. "/" .. section.label
		end
	end
end
print(
	("%-26s %-17s %-11s %-6s %-7s %-5s %s | %s"):format(
		"id",
		"category",
		"mode",
		"thr",
		"default",
		"cont",
		"events",
		"page/section"
	)
)
for _, t in ipairs(P.Triggers) do
	print(
		("%-26s %-17s %-11s %-6s %-7s %-5s %s | %s"):format(
			t.id,
			t.category,
			tostring(t.mode),
			tostring(t.throttle),
			tostring(t.default),
			tostring(t.continuous and true or false),
			t.events and table.concat(t.events, ",") or "",
			where[t.id] or "-"
		)
	)
end
print(("\n%d triggers"):format(#P.Triggers))
