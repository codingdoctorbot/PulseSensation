-- PulseChecklist/tests/phase2-test.lua
--
-- Phase 2: page switches (non-destructive group gates), fold state, one-line cue rows and
-- simple view. Runs on top of harness.lua's full mock environment (real Database, Registry,
-- Init, Spec, Content, Rows, Sidebar, Panel), the way cue-audit.lua does.

local scriptDir = arg[0]:match("^(.-)[^/\\]*$")
if scriptDir == "" then
	scriptDir = "./"
end
dofile(scriptDir .. "harness.lua")

io.write("\n================== PHASE 2 ==================\n")

local failures = 0
local function check(label, got, want)
	local ok = (got == want)
	if not ok then
		failures = failures + 1
	end
	io.write(("%-66s %-8s %s\n"):format(label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
end

local P = _G.Pulse
local DB = P.Database
local R = P.Registry

-- ── Gate data ─────────────────────────────────────────────────────────────────

local gates, pageGates = 0, 0
for _, t in ipairs(P.Triggers) do
	if t.gate then
		gates = gates + 1
		check("gate " .. t.id .. " plays nothing (no mode)", t.mode == nil and not t.continuous, true)
	end
end
check("10 new page switches", gates, 10)
for pageID, gateID in pairs(R.PAGE_GATES) do
	pageGates = pageGates + 1
	check("PAGE_GATES." .. pageID .. " resolves to a trigger", R:GetTrigger(gateID) ~= nil, true)
end
check("11 pages gated (CONTROLLER deliberately not)", pageGates, 11)
check("padDisconnected is never behind a switch", R.CUE_GATE.padDisconnected, nil)
check("CONTROLLER_UI cues rely on controllerUIMaster, not a second gate", R.CUE_GATE.uiNavigate, nil)
check("bagItemAdded sits behind gateWorld", R.CUE_GATE.bagItemAdded, "gateWorld")

-- ── Seeding: every profile starts with every switch ON, __exclusive included ──

local allOn = true
for _, name in ipairs(DB:GetProfileNames()) do
	local prof = _G.PulseDB.profiles[name]
	for _, t in ipairs(P.Triggers) do
		if t.gate and prof.triggers[t.id] ~= true then
			allOn = false
			io.write("  gate OFF: " .. name .. " / " .. t.id .. "\n")
		end
	end
end
check("every built-in and custom profile seeds every switch ON", allOn, true)

DB:SetAllCues(false)
check("'Disable all cues' leaves page switches alone", DB:GetCue("gateWorld"), true)
DB:SetAllCues(true)

-- ── Non-destructive runtime gate ──────────────────────────────────────────────

-- critLanded: no throttle of its own, so every call below is decided by the gate alone.
DB:SetCue("critLanded", true)
check("gate open: critLanded plays", P:FireIfEnabled("critLanded"), true)
DB:SetCue("gateCombat", false)
check("gate closed: critLanded dropped", P:FireIfEnabled("critLanded"), false)
check("  the cue's own switch is untouched", DB:GetCue("critLanded"), true)
check("  IsCueActive reports it inactive (so modules unregister)", P:IsCueActive("critLanded"), false)
check("  a cue on another page is unaffected", P:GatesOpen("bagItemAdded"), true)
DB:SetCue("gateCombat", true)
check("gate reopened: critLanded plays again", P:FireIfEnabled("critLanded"), true)

-- ── Fold state and one-line rows ──────────────────────────────────────────────

local Panel = P.UI.Panel
local window = Panel.EnsureBuilt()
check("window builds", window ~= nil, true)
Panel.GoToPage("WORLD")
local page = window.Content.page
local sections, cueRows, oldStyleRows = 0, 0, 0
for _, row in ipairs(page.rows) do
	local kind = row.spec and row.spec.kind
	if kind == "section" then
		sections = sections + 1
	elseif kind == "cue" then
		cueRows = cueRows + 1
	elseif kind == "slider" and row.spec.label == "Intensity" then
		oldStyleRows = oldStyleRows + 1
	end
end
local worldCues = 0
for _, s in ipairs(page.sections or {}) do
	worldCues = worldCues + #s.triggers
end
check("WORLD page: one section header per section", sections > 0, true)
check("WORLD page: exactly one cue row per cue", cueRows, 31 - sections)
check("WORLD page: no separate Intensity rows remain", oldStyleRows, 0)

local key = "WORLD/Loot & inventory"
local header, member
for _, row in ipairs(page.rows) do
	if row.spec and row.spec.sectionKey == key then
		if row.isSectionHeader then
			header = row
		elseif not member and row.spec.kind == "cue" then
			member = row
		end
	end
end
check("found the Loot & inventory header and a cue under it", header ~= nil and member ~= nil, true)

DB:SetSectionCollapsed(key, true)
window.Content:LayoutRows()
check("folded: header still shown", header:IsShown(), true)
check("folded: its cues hidden", member:IsShown(), false)
window.Content:SetFilter(member.spec.label)
check("search reaches into a folded section", member:IsShown(), true)
window.Content:SetFilter("")
window.Content:LayoutRows()
check("search cleared: folded again", member:IsShown(), false)
DB:SetSectionCollapsed(key, false)
window.Content:LayoutRows()
check("unfolded: cue shown", member:IsShown(), true)
check("fold state is global, not per profile", _G.PulseDB.collapsedSections ~= nil, true)

-- ── Simple view ───────────────────────────────────────────────────────────────

local function visibleSidebarPages()
	local n = 0
	for _, button in ipairs(window.Sidebar.buttons) do
		if button:IsShown() then
			n = n + 1
		end
	end
	return n
end
local allPages = visibleSidebarPages()
local advancedBefore = DB:Get("showAdvancedCueControls")
DB:Set("simpleView", true)
Panel.ApplySimpleView()
check("simple view: sidebar trimmed", visibleSidebarPages() < allPages, true)
check("simple view: lands on the switches page", window.Sidebar.selectedPage.id, "switches")
check("simple view never rewrites showAdvancedCueControls", DB:Get("showAdvancedCueControls"), advancedBefore)
DB:Set("simpleView", false)
Panel.ApplySimpleView()
check("simple view off: every page back", visibleSidebarPages(), allPages)

io.write(failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n"))
os.exit(failures == 0 and 0 or 1)
