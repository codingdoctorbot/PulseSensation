-- Probe: static consistency of Core/Registry.lua against Modes, modules and profiles.
package.path = ((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local E = require("env")
local S = E.S
local ROOT = S .. "/head/PulseHaptics"
E.stubs(S .. "/head/PulseChecklist/tests/harness.lua")
local printed = {}
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
local P = E.loadAddon(ROOT, E.CORE)
local out = io.write

local byID, dup = {}, {}
for _, t in ipairs(P.Triggers) do
	if byID[t.id] then dup[#dup + 1] = t.id end
	byID[t.id] = t
end
out("triggers=", #P.Triggers, " duplicates=", #dup, " ", table.concat(dup, ","), "\n")
out("load-time prints: ", #printed, "\n")
for _, l in ipairs(printed) do out("  ", l, "\n") end

local badMode, bothKinds, noKind, badTun = {}, {}, {}, {}
for _, t in ipairs(P.Triggers) do
	if t.mode and not P.Modes[t.mode] then badMode[#badMode + 1] = t.id .. "->" .. t.mode end
	if t.mode and t.continuous then bothKinds[#bothKinds + 1] = t.id end
	if not t.mode and not t.continuous then noKind[#noKind + 1] = t.id end
	for _, tun in ipairs(t.tunables or {}) do
		if not tun.boolean then
			if type(tun.default) ~= "number" or tun.default < tun.min or tun.default > tun.max then
				badTun[#badTun + 1] = t.id .. "." .. tun.key .. " default=" .. tostring(tun.default) .. " range=" .. tostring(tun.min) .. ".." .. tostring(tun.max)
			end
			local n = (tun.default - tun.min) / tun.step
			if math.abs(n - math.floor(n + 0.5)) > 1e-6 then
				badTun[#badTun + 1] = t.id .. "." .. tun.key .. " default off-grid (step " .. tun.step .. ")"
			end
		end
	end
end
out("unknown modes: ", #badMode, " ", table.concat(badMode, ","), "\n")
out("mode+continuous: ", #bothKinds, " ", table.concat(bothKinds, ","), "\n")
out("neither mode nor continuous (gate-only): ", #noKind, " ", table.concat(noKind, ","), "\n")
out("tunable problems: ", #badTun, "\n")
for _, l in ipairs(badTun) do out("  ", l, "\n") end

-- throttles of selected cues
for _, id in ipairs({ "bankClosed", "bankGold", "merchantBuy", "merchantSell", "merchantRepair", "stackSplit",
	"npcEmote", "harvestComplete", "equipChanged", "actionFailed", "selfCastInstant", "selfCastFailed",
	"merchantShow", "bankOpened", "mailShow", "trainerShow", "taxiOpened", "tradeSkillShow", "questDetail",
	"tradeRequest", "interactionWindow", "interactionWindowClosed", "itemObtained", "lootGold", "xpGained",
	"uiNavigate", "cursorPickup", "targetedByEnemy", "debuffReceived", "weatherChanged" }) do
	local t = byID[id]
	out(string.format("  %-24s exists=%-5s throttle=%-5s default=%-5s events=%s\n", id, tostring(t ~= nil),
		tostring(t and t.throttle), tostring(t and t.default), t and t.events and table.concat(t.events, "|") or "-"))
end

-- cue-id string literals used by modules/UI that are not registry ids
local function scan(path)
	local f = io.open(path)
	if not f then return end
	local src = f:read("*a")
	f:close()
	local missing = {}
	for fn, id in src:gmatch('(%u?%a+IfEnabled)%(%s*"([%w_]+)"') do
		if not byID[id] then missing[#missing + 1] = fn .. ":" .. id end
	end
	for id in src:gmatch('GetCue%(%s*"([%w_]+)"') do
		if not byID[id] then missing[#missing + 1] = "GetCue:" .. id end
	end
	for id in src:gmatch('GetTriggerSetting%(%s*"([%w_]+)"') do
		if not byID[id] then missing[#missing + 1] = "GetTriggerSetting:" .. id end
	end
	if #missing > 0 then out("  ", path:sub(#ROOT + 2), ": ", table.concat(missing, ", "), "\n") end
end
out("cue ids referenced in code but absent from Registry:\n")
local p = io.popen('find "' .. ROOT .. '" -name "*.lua" -not -path "*/Libs/*"')
for path in p:lines() do scan(path) end
p:close()

-- tunable keys read by modules that the trigger does not declare (fallback default used forever)
out("GetTriggerSetting keys not declared as tunables (and not intensity/__mode/p*_on/p*_gain):\n")
local p2 = io.popen('find "' .. ROOT .. '/Modules" "' .. ROOT .. '/Core" -name "*.lua"')
for path in p2:lines() do
	local f = io.open(path); local src = f:read("*a"); f:close()
	for id, key, def in src:gmatch('GetTriggerSetting%(%s*"([%w_]+)"%s*,%s*"([%w_]+)"%s*,%s*([^%)]+)%)') do
		local t = byID[id]
		local declared = false
		for _, tun in ipairs(t and t.tunables or {}) do
			if tun.key == key then
				declared = true
				local d = tun.boolean and (tun.default and 1 or 0) or tun.default
				if tostring(d) ~= def:gsub("%s", "") and tonumber(def) ~= d then
					out(string.format("  fallback mismatch %s.%s code=%s registry=%s (%s)\n", id, key, def, tostring(d), path:sub(#ROOT + 2)))
				end
			end
		end
		if not declared and key ~= "intensity" then
			out(string.format("  undeclared %s.%s fallback=%s (%s)\n", id, key, def, path:sub(#ROOT + 2)))
		end
	end
end
p2:close()
