-- Probe environment: reuses the stub WoW API from the repo's own harness.lua (everything
-- above its "Load the addon" marker), then offers loadAddon(root, files).
--
-- PROBE_SNAPSHOTS names a directory holding `git archive` extracts of the commits the
-- review compared (head = ad0ef89, h2 = 1ca6a24, pre = db2ffa5, v8 = dace2ab). run.sh
-- creates it; the probes read the addon from there and never from the working tree, so
-- a live edit to the repo cannot change a result.
local S = os.getenv("PROBE_SNAPSHOTS")
if not S or S == "" then
	error("PROBE_SNAPSHOTS is not set — run the probes through run.sh")
end
local E = {}
E.S = S

function E.stubs(harnessPath)
	local f = assert(io.open(harnessPath))
	local src = f:read("*a")
	f:close()
	local cut = src:find("%-%- ── Load the addon")
	src = src:sub(1, cut - 1)
	local chunk = assert(loadstring(src, "=harness-stubs"))
	chunk()
	-- quiet the print stub unless asked
	E.realPrint = print
end

E.CORE = {
	"Core/Init.lua",
	"Core/Database.lua",
	"Core/Modes.lua",
	"Core/Devices.lua",
	"Core/Waves.lua",
	"Core/Schemas/Standard.lua",
	"Core/Schemas/Inverted.lua",
	"Core/Schemas/LowOnly.lua",
	"Core/Schemas/HighOnly.lua",
	"Core/Engine.lua",
	"Core/CastActivity.lua",
	"Core/Registry.lua",
}

function E.loadAddon(root, files, quiet)
	local Pulse = {}
	for _, rel in ipairs(files) do
		local chunk, err = loadfile(root .. "/" .. rel)
		if not chunk then
			error("LOAD FAIL " .. rel .. ": " .. tostring(err))
		end
		local ok, runErr = pcall(chunk, "PulseHaptics", Pulse)
		if not ok then
			error("RUN FAIL " .. rel .. ": " .. tostring(runErr))
		end
	end
	return Pulse
end

-- Plain serializer for SavedVariables-shaped tables.
local function ser(v, indent)
	indent = indent or ""
	local t = type(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "number" or t == "boolean" or t == "nil" then
		return tostring(v)
	elseif t == "table" then
		local parts = { "{\n" }
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in ipairs(keys) do
			local ks = type(k) == "string" and string.format("[%q]", k) or ("[" .. tostring(k) .. "]")
			parts[#parts + 1] = indent .. "  " .. ks .. " = " .. ser(v[k], indent .. "  ") .. ",\n"
		end
		parts[#parts + 1] = indent .. "}"
		return table.concat(parts)
	end
	return "nil"
end
E.ser = ser

return E
