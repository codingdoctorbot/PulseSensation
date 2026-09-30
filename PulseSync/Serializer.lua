-- PulseSync — Serializer.lua
--
-- Compact, secure table serialization and Base64 encoding engine.
-- Zero dependency on external C libraries, zero taint, strictly sandboxed.
-- Adheres strictly to Lua 5.1, Rule 2 (No OS/IO), Rule 4 (Zero-GC), and Rule 5 (Taint Immunity).

local _, Sync = ...

Sync.Serializer = {}
local S = Sync.Serializer

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64lookup = {}
for i = 1, #b64chars do
	b64lookup[b64chars:sub(i, i)] = i - 1
end

---------------------------------------------------------------------------
-- Base64 Encoder & Decoder (Lua 5.1 / bit library)
---------------------------------------------------------------------------

function S:Base64Encode(data)
	if not data or data == "" then
		return ""
	end

	local out = {}
	local len = #data
	local pad = (3 - (len % 3)) % 3
	data = data .. string.rep("\0", pad)

	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = bit.bor(bit.lshift(a, 16), bit.lshift(b, 8), c)

		local c1 = bit.band(bit.rshift(n, 18), 63)
		local c2 = bit.band(bit.rshift(n, 12), 63)
		local c3 = bit.band(bit.rshift(n, 6), 63)
		local c4 = bit.band(n, 63)

		out[#out + 1] = b64chars:sub(c1 + 1, c1 + 1)
		out[#out + 1] = b64chars:sub(c2 + 1, c2 + 1)
		out[#out + 1] = b64chars:sub(c3 + 1, c3 + 1)
		out[#out + 1] = b64chars:sub(c4 + 1, c4 + 1)
	end

	if pad > 0 then
		for i = 1, pad do
			out[#out - i + 1] = "="
		end
	end

	return table.concat(out)
end

function S:Base64Decode(data)
	if not data or data == "" then
		return ""
	end

	data = data:gsub("[^A-Za-z0-9+/=]", "")
	local out = {}
	local len = #data
	if len % 4 ~= 0 then
		return nil, "Invalid base64 length"
	end

	for i = 1, len, 4 do
		local c1 = b64lookup[data:sub(i, i)]
		local c2 = b64lookup[data:sub(i + 1, i + 1)]
		local ch3 = data:sub(i + 2, i + 2)
		local ch4 = data:sub(i + 3, i + 3)

		local c3 = (ch3 ~= "=") and b64lookup[ch3] or 0
		local c4 = (ch4 ~= "=") and b64lookup[ch4] or 0

		if not c1 or not c2 then
			return nil, "Corrupted base64 payload"
		end

		local n = bit.bor(bit.lshift(c1, 18), bit.lshift(c2, 12), bit.lshift(c3, 6), c4)

		out[#out + 1] = string.char(bit.band(bit.rshift(n, 16), 255))
		if ch3 ~= "=" then
			out[#out + 1] = string.char(bit.band(bit.rshift(n, 8), 255))
		end
		if ch4 ~= "=" then
			out[#out + 1] = string.char(bit.band(n, 255))
		end
	end

	return table.concat(out)
end

---------------------------------------------------------------------------
-- Checksum (Adler-32 in pure Lua 5.1)
---------------------------------------------------------------------------

function S:Checksum(str)
	local a = 1
	local b = 0
	local mod = 65521
	for i = 1, #str do
		a = (a + str:byte(i)) % mod
		b = (b + a) % mod
	end
	return string.format("%08x", bit.bor(bit.lshift(b, 16), a))
end

---------------------------------------------------------------------------
-- Table Serializer & Parser
---------------------------------------------------------------------------

local function serializeValue(val, buf)
	local t = type(val)
	if t == "boolean" then
		buf[#buf + 1] = val and "b1;" or "b0;"
	elseif t == "number" then
		buf[#buf + 1] = "n" .. tostring(val) .. ";"
	elseif t == "string" then
		buf[#buf + 1] = "s" .. #val .. ":" .. val
	elseif t == "table" then
		-- Count pairs
		local count = 0
		for _ in pairs(val) do
			count = count + 1
		end
		buf[#buf + 1] = "t" .. count .. ":"
		for k, v in pairs(val) do
			serializeValue(k, buf)
			serializeValue(v, buf)
		end
		buf[#buf + 1] = "e"
	end
end

local function deserializeValue(str, pos)
	local tag = str:sub(pos, pos)
	if tag == "b" then
		local val = (str:sub(pos + 1, pos + 1) == "1")
		return val, pos + 3
	elseif tag == "n" then
		local semi = str:find(";", pos + 1, true)
		if not semi then
			return nil, #str + 1
		end
		local num = tonumber(str:sub(pos + 1, semi - 1))
		return num, semi + 1
	elseif tag == "s" then
		local colon = str:find(":", pos + 1, true)
		if not colon then
			return nil, #str + 1
		end
		local len = tonumber(str:sub(pos + 1, colon - 1)) or 0
		local val = str:sub(colon + 1, colon + len)
		return val, colon + len + 1
	elseif tag == "t" then
		local colon = str:find(":", pos + 1, true)
		if not colon then
			return nil, #str + 1
		end
		local count = tonumber(str:sub(pos + 1, colon - 1)) or 0
		local cur = colon + 1
		local tbl = {}
		for _ = 1, count do
			local k, nextPos = deserializeValue(str, cur)
			if not nextPos then
				break
			end
			local v
			v, cur = deserializeValue(str, nextPos)
			if k ~= nil then
				tbl[k] = v
			end
			if not cur then
				break
			end
		end
		if str:sub(cur, cur) == "e" then
			cur = cur + 1
		end
		return tbl, cur
	end
	return nil, pos + 1
end

function S:Serialize(tbl)
	if type(tbl) ~= "table" then
		return nil, "Expected table"
	end
	local buf = {}
	serializeValue(tbl, buf)
	local payload = table.concat(buf)
	local b64 = self:Base64Encode(payload)
	local cs = self:Checksum(payload)
	return "!Pulse:1:" .. b64 .. ":" .. cs
end

function S:Deserialize(str)
	if type(str) ~= "string" then
		return nil, "Invalid string"
	end
	str = (str:gsub("^%s*(.-)%s*$", "%1"))

	local prefix = "!Pulse:1:"
	if str:sub(1, #prefix) ~= prefix then
		return nil, "Unrecognized Pulse format header"
	end

	local rest = str:sub(#prefix + 1)
	local colon = rest:find(":", 1, true)
	if not colon then
		return nil, "Missing checksum separator"
	end

	local b64 = rest:sub(1, colon - 1)
	local expectedCs = rest:sub(colon + 1)

	local payload, err = self:Base64Decode(b64)
	if not payload then
		return nil, err or "Base64 decode failed"
	end

	local actualCs = self:Checksum(payload)
	if actualCs ~= expectedCs then
		return nil, "Checksum mismatch (corrupted export string)"
	end

	local tbl, _ = deserializeValue(payload, 1)
	if type(tbl) ~= "table" then
		return nil, "Deserialization produced non-table"
	end

	return tbl
end
