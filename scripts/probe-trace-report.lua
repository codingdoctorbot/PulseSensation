-- scripts/probe-trace-report.lua
--
-- Offline report for PulseProbe event-order traces (Phase 0). Usage:
--   luajit scripts/probe-trace-report.lua <path to SavedVariables/PulseProbe.lua>
-- Prints, per dumped scenario, the gap distribution (ms, from GetTimePreciseSec) and the
-- same-frame rate for every event pair the Phase 1 constants depend on.

local path = assert(arg[1], "usage: probe-trace-report.lua <PulseProbe.lua>")
local env = {}
local chunk = assert(loadfile(path))
setfenv(chunk, env)
chunk()
local db = assert(env.PulseProbeDB, "no PulseProbeDB in file")

-- A -> B: for each A, the first B after it within WITHIN seconds. `signed` also counts how
-- often B arrived shortly BEFORE A (an ordering check, not a gap).
local PAIRS = {
	{ "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "vendor: money -> bag settle (sign tells order)", signed = true },
	{ "HOOK_RepairAllItems", "UPDATE_INVENTORY_DURABILITY", "repair: call -> confirmation (REPAIR_WINDOW)" },
	{ "UPDATE_INVENTORY_DURABILITY", "PLAYER_MONEY", "repair: confirmation -> debit (DEBIT_WINDOW)" },
	{ "LOOT_CLOSED", "BAG_UPDATE_DELAYED", "loot: close -> trailing bag settle (LOOT_TAIL)" },
	{ "LOOT_SLOT_CLEARED", "LOOT_SLOT_CLEARED", "loot: slot -> next slot (autoloot spacing)" },
	{
		"PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
		"PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
		"window: hide -> show (chain)",
	},
	{ "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "TIMER0", "window: hide -> next-frame timer (deferral)" },
	{ "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "UIPANEL_LEFT", "window: show -> panel poll sees it (bus window)" },
	{ "MAIL_INBOX_UPDATE", "ITEM_PUSH", "mail: inbox update -> item arrives" },
	{ "ITEM_PUSH", "ITEM_PUSH", "intake: item -> next item (bulk spacing)" },
	{ "PLAYER_REGEN_DISABLED", "UNIT_THREAT_SITUATION_UPDATE", "pull: regen -> threat (pull bus)" },
}
local WITHIN = 2.0

local function quantile(sorted, q)
	if #sorted == 0 then
		return nil
	end
	local i = math.max(1, math.min(#sorted, math.floor(q * #sorted + 0.5)))
	return sorted[i]
end

for _, t in ipairs(db.traces or {}) do
	print(
		("\n== %s  (build %s, interface %s, %d rows)"):format(
			t.scenario,
			tostring(t.build),
			tostring(t.interface),
			#t.rows
		)
	)
	for _, pair in ipairs(PAIRS) do
		local a, b, label = pair[1], pair[2], pair[3]
		local gaps, sameFrame, before = {}, 0, 0
		for i, row in ipairs(t.rows) do
			if row[1] == a then
				for j = i + 1, #t.rows do
					local other = t.rows[j]
					if other[4] - row[4] > WITHIN then
						break
					end
					if other[1] == b then
						gaps[#gaps + 1] = (other[4] - row[4]) * 1000
						if other[2] == row[2] then
							sameFrame = sameFrame + 1
						end
						break
					end
				end
				if pair.signed then -- does B also occur BEFORE this A, closer than after?
					for j = i - 1, 1, -1 do
						local other = t.rows[j]
						if row[4] - other[4] > WITHIN then
							break
						end
						if other[1] == b then
							before = before + 1
							break
						end
					end
				end
			end
		end
		if #gaps > 0 then
			table.sort(gaps)
			print(
				("  %-52s n=%-3d p50=%7.1f  p95=%7.1f  max=%7.1f ms  same-frame=%d%s"):format(
					label,
					#gaps,
					quantile(gaps, 0.5),
					quantile(gaps, 0.95),
					gaps[#gaps],
					sameFrame,
					pair.signed and ("  B-before-A=" .. before) or ""
				)
			)
		end
	end
	for _, row in ipairs(t.rows) do
		if row[1] == "PLAYER_REGEN_DISABLED" then
			print(
				("  REGEN_DISABLED: InCombatLockdown()=%s UnitAffectingCombat=%s"):format(
					tostring(row[6]),
					tostring(row[7])
				)
			)
		elseif row[1] == "LOOT_READY" then
			print(("  LOOT_READY: autoloot=%s GetNumLootItems()=%s"):format(tostring(row[6]), tostring(row[7])))
		end
	end
end
