-- PulseChecklist/tests/cue-audit.lua
-- Comprehensive audit verifying every cue in Registry.lua, its mode, and its triggering logic across modules.

local scriptDir = arg[0]:match("^(.-)[^/\\]*$")
if scriptDir == "" then
	scriptDir = "./"
end

-- Load harness to get the full mock environment
dofile(scriptDir .. "harness.lua")

print("\n================== COMPREHENSIVE CUE & MODE AUDIT ==================")

-- 1. Modes validation
print("\n--- 1. AUDITING MODES ---")
local totalModes = #Pulse.ModeOrder
local modeErrors = 0
for _, modeID in ipairs(Pulse.ModeOrder) do
	local mode = Pulse.Modes[modeID]
	if not mode then
		print("FAIL: Mode in ModeOrder has no definition in Modes table:", modeID)
		modeErrors = modeErrors + 1
	else
		if mode.continuous then
			if type(mode.low) ~= "number" or type(mode.high) ~= "number" then
				print("FAIL: Continuous mode missing low/high numbers:", modeID)
				modeErrors = modeErrors + 1
			end
		else
			if not mode.steps or #mode.steps == 0 then
				print("FAIL: Discrete mode has no steps:", modeID)
				modeErrors = modeErrors + 1
			else
				for stepIdx, step in ipairs(mode.steps) do
					if not step.gap then
						if not step.role or not step.relIntensity or not step.relDuration then
							print("FAIL: Mode " .. modeID .. " step " .. stepIdx .. " invalid definition")
							modeErrors = modeErrors + 1
						end
					end
				end
			end
		end
	end
end
print(string.format("Audited %d modes: %d errors.", totalModes, modeErrors))

-- 2. Triggers in Registry
print("\n--- 2. AUDITING TRIGGERS IN REGISTRY.LUA ---")
local totalTriggers = #Pulse.Triggers
local discreteCount = 0
local continuousCount = 0
local triggerModeErrors = 0
local triggerIDMap = {}

for _, trig in ipairs(Pulse.Triggers) do
	if triggerIDMap[trig.id] then
		print("FAIL: Duplicate trigger ID:", trig.id)
		triggerModeErrors = triggerModeErrors + 1
	end
	triggerIDMap[trig.id] = trig

	if trig.continuous then
		continuousCount = continuousCount + 1
	elseif trig.silent then
		-- Intentional silent / housekeeping cue (e.g. padDisconnected clearing active vibrations)
	else
		discreteCount = discreteCount + 1
		if not trig.mode then
			print("FAIL: Cue " .. trig.id .. " has no mode specified")
			triggerModeErrors = triggerModeErrors + 1
		elseif not Pulse.Modes[trig.mode] then
			print("FAIL: Cue " .. trig.id .. " references nonexistent mode: " .. tostring(trig.mode))
			triggerModeErrors = triggerModeErrors + 1
		end
	end
end
print(
	string.format(
		"Total Cues in Registry: %d (Discrete: %d, Continuous: %d)",
		totalTriggers,
		discreteCount,
		continuousCount
	)
)
print(string.format("Trigger definition / mode reference errors: %d", triggerModeErrors))

-- 3. Scanning for which modules handle which triggers
print("\n--- 3. CHECKING TRIGGER COVERAGE ACROSS CODEBASE ---")

-- Read all Module files and find Fire/Hold calls
local triggersHandled = {}

-- Load list of all module files
local MODULE_FILES = {
	"Modules/Movement.lua",
	"Modules/Flight.lua",
	"Modules/Combat.lua",
	"Modules/Environment.lua",
	"Modules/World.lua",
	"Modules/Inventory.lua",
	"Modules/Encounter.lua",
	"Modules/Health.lua",
	"Modules/Casting.lua",
	"Modules/Locomotion.lua",
	"Modules/PlayerState.lua",
	"Modules/Crafting.lua",
	"Modules/Interaction.lua",
	"Modules/AlertGeneric.lua",
	"Modules/AlertLossOfControl.lua",
	"Modules/AlertThreat.lua",
	"Modules/AlertUnitWatch.lua",
	"Modules/AlertSocial.lua",
	"Modules/AlertWorld.lua",
	"Modules/AlertDevice.lua",
	"Modules/AlertExperimental.lua",
	"Modules/ControllerUI.lua",
	"Core/CastActivity.lua",
	"Core/Registry.lua",
}

local ROOT = arg[1] or "PulseHaptics"

for _, relPath in ipairs(MODULE_FILES) do
	local f = io.open(ROOT .. "/" .. relPath, "r") or io.open(relPath, "r")
	if f then
		local content = f:read("*a")
		f:close()
		for trigID in pairs(triggerIDMap) do
			-- Look for exact string match of trigger ID in code
			if content:find('"' .. trigID .. '"', 1, true) or content:find("'" .. trigID .. "'", 1, true) then
				triggersHandled[trigID] = (triggersHandled[trigID] or 0) + 1
			end
		end
	end
end

local unreferenced = {}
for _, trig in ipairs(Pulse.Triggers) do
	-- Note: Registry itself has "trig.id", so count should be >= 2 (Registry + owning module)
	-- Unless it's an ALERT category trigger watched via WatchCategory
	local count = triggersHandled[trig.id] or 0
	if count < 2 then
		table.insert(unreferenced, { id = trig.id, category = trig.category, count = count })
	end
end

print(string.format("Triggers with direct module reference: %d / %d", totalTriggers - #unreferenced, totalTriggers))

print("\n--- 4. AUDITING ALERT / WATCH_CATEGORY CUES ---")
local alertEventErrors = 0
for _, u in ipairs(unreferenced) do
	local trig = triggerIDMap[u.id]
	if not trig.events or #trig.events == 0 then
		print(string.format("WARNING: Alert cue %s has no events declared", u.id))
		alertEventErrors = alertEventErrors + 1
	else
		for _, ev in ipairs(trig.events) do
			if type(ev) ~= "string" or ev == "" then
				print(string.format("ERROR: Alert cue %s has invalid event %s", u.id, tostring(ev)))
				alertEventErrors = alertEventErrors + 1
			end
		end
	end
end
print(string.format("Checked %d WatchCategory cues: %d errors.", #unreferenced, alertEventErrors))

print("\n================== AUDIT FINISHED ==================")
