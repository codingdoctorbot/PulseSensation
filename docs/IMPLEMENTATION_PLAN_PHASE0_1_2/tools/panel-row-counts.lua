-- IMPLEMENTATION_PLAN_PHASE0_1_2/tools/panel-row-counts.lua
--
-- Rows the 12 cue pages build today (UI/Panel/Spec.lua cueBlock, detail controls and Play
-- buttons shown - both default on) versus one-line cue rows (plan P2.3; bespoke tunables stay
-- as child rows). Section headers counted in both. Run from the repository root:
--   luajit IMPLEMENTATION_PLAN_PHASE0_1_2/tools/panel-row-counts.lua
local P = {}
assert(loadfile("PulseHaptics/Core/Registry.lua"))("PulseHaptics", P)
-- Core/Init.lua BESPOKE_PREVIEW: continuous cues with a module preview (all testable).
local bespoke = {
	lowHealthWarning = 1,
	lowHealthTexture = 1,
	breathTexture = 1,
	weatherTexture = 1,
	waterTexture = 1,
	swimTexture = 1,
	oceanTexture = 1,
	taxiRide = 1,
	stealthTexture = 1,
	glideThrust = 1,
	castTexture = 1,
	craftTexture = 1,
	locomotion = 1,
}
local now, compact, cues = 0, 0, 0
for _, page in ipairs(P.Registry:GetPages()) do
	local a, b = 0, 0
	for _, s in ipairs(page.sections) do
		a, b = a + 1, b + 1
		for _, t in ipairs(s.triggers) do
			cues = cues + 1
			local tunables = (t.tunables and not t.devTuning) and #t.tunables or 0
			a = a
				+ 1
				+ ((t.mode or t.continuous) and 1 or 0)
				+ (t.mode and 1 or 0)
				+ tunables
				+ ((bespoke[t.id] or t.mode or t.continuous) and 1 or 0)
			b = b + 1 + tunables
		end
	end
	print(("%-18s now=%3d  one-line=%3d  (-%d%%)"):format(page.id, a, b, math.floor(100 * (a - b) / a + 0.5)))
	now, compact = now + a, compact + b
end
print(("TOTAL %d cues: %d rows now, %d one-line, -%.0f%%"):format(cues, now, compact, 100 * (now - compact) / now))
