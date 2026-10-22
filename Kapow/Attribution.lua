-- KAPOW — Attribution.lua
--
-- "Accurate" hit attribution: the third "Hits that count" choice (General tab).
--
-- Condensed from MikScrollingBattleText's Forever engine (Combat/Mine.lua, itself adapted from
-- Forever Combat Text). The game reports a hit on your target (amount, school, crit) but not who
-- made it, and the combat log is closed. What it does report readably is what you and your pet
-- do: your casts with their spell (UNIT_SPELLCAST_SUCCEEDED), your weapon swings (PLAYER_SWING,
-- Forever only) and your own lines in the combat log (Detect.lua). A hit is matched to those by
-- time and school, decided a moment after it landed so a swing or a line reported just after
-- its hit still counts. First rule that fits wins:
--
--   1. a combat-log line of yours came within LINE_WINDOW of the hit
--   2. a weapon swing of yours: a physical hit within the swing window. A melee hit is reported
--      about 0.45 s after its swing (MSBT measured 0.42-0.47 s on 1.60.1.70450); the delay is
--      learned from your own swings. Ranged shots fly up to 2 s.
--   3. a cast of yours within CAST_WINDOW (a bolt in flight), oldest first, whose school, learned
--      from that spell's first hit, matches
--   4. a tick of a damage-over-time of yours: a steady beat (0.9-3.3 s) of one school, within
--      DOT_MEMORY of a cast of yours of that school
--   5. your pet attacking your target: a physical hit, at most one per PET_GAP
--
-- Nothing fits: someone else's. Only plain values are read: the school comes from UNIT_COMBAT
-- when it is plain, and is otherwise unknown (then the school checks are skipped).

local _, ns = ...

local issecretvalue = _G.issecretvalue or function()
	return false
end

local AT = {}
ns.attribution = AT

local LINE_WINDOW = 0.1
local CAST_WINDOW = 3.0
local SWING_MIN, SWING_MAX = 0.25, 0.9 -- before a delay is learned
local SWING_EARLY, SWING_LATE = 0.10, 0.15
local SWING_AFTER = 0.35 -- a swing may be reported this long after its own hit
local RANGED_WINDOW = 2.0
local TICK_MIN, TICK_MAX, TICK_SLACK = 0.9, 3.3, 0.35
local DOT_MEMORY = 30
local PET_GAP = 1.0
local PHYSICAL = 1
local MAX = 16
local LAG_SAMPLES = 9
local RANGED = 2 -- Enum.PlayerSwingType.Ranged

local casts, swings, lags = {}, {}, {}
local learnedDelay -- median melee swing-to-hit delay, once three are known
local spellSchool = {} -- spellID -> school its first matched hit had (this session)
local schoolCastAt = {} -- school -> when you last cast a spell of it
local beats = {} -- school -> { last = time, interval = seconds }
local petLast = -100

local function Push(list, entry)
	if #list >= MAX then
		table.remove(list, 1)
	end
	list[#list + 1] = entry
end

local function LearnDelay(lag)
	if #lags >= LAG_SAMPLES then
		table.remove(lags, 1)
	end
	lags[#lags + 1] = lag
	if #lags >= 3 then
		local sorted = {}
		for i, v in ipairs(lags) do
			sorted[i] = v
		end
		table.sort(sorted)
		learnedDelay = sorted[math.floor((#sorted + 1) / 2)]
	end
end

local function SwingWindow(ranged)
	if ranged then
		return 0, RANGED_WINDOW
	end
	if not learnedDelay then
		return SWING_MIN, SWING_MAX
	end
	return math.max(0.05, learnedDelay - SWING_EARLY), learnedDelay + SWING_LATE
end

function AT.Reset()
	for _, list in ipairs({ casts, swings, lags }) do
		for i = #list, 1, -1 do
			list[i] = nil
		end
	end
	learnedDelay = nil
	for k in pairs(spellSchool) do
		spellSchool[k] = nil
	end
	for k in pairs(schoolCastAt) do
		schoolCastAt[k] = nil
	end
	for k in pairs(beats) do
		beats[k] = nil
	end
	petLast = -100
end

-- UNIT_SPELLCAST_SUCCEEDED for "player" (unit, castGUID, spellID). Player casts are plain.
function AT.OnCast(unit, spellID)
	if unit ~= "player" or issecretvalue(spellID) or type(spellID) ~= "number" then
		return
	end
	local now = GetTime()
	Push(casts, { at = now, spell = spellID })
	local school = spellSchool[spellID]
	if school then
		schoolCastAt[school] = now
	end
end

-- PLAYER_SWING (swingDuration, swingType).
function AT.OnSwing(swingType)
	local ranged = not issecretvalue(swingType) and swingType == RANGED
	Push(swings, { at = GetTime(), ranged = ranged })
end

local function PetOnTarget()
	local exists = UnitExists("pet")
	if issecretvalue(exists) or not exists then
		return false
	end
	local ok, same = pcall(UnitIsUnit, "pettarget", "target")
	return ok and not issecretvalue(same) and same == true
end

-- Who made a hit that landed at `hitAt` with `school` (maybe nil or secret): "you", "pet" or nil.
function AT.Match(school, hitAt)
	local known = (not issecretvalue(school) and type(school) == "number") and school or nil
	local physical = known == nil or known == PHYSICAL

	-- A steady beat of one school marks ticks (updated for every hit of a known school).
	local tick = false
	if known then
		local beat = beats[known]
		if beat then
			local gap = hitAt - beat.last
			if beat.interval and math.abs(gap - beat.interval) <= TICK_SLACK and gap >= TICK_MIN and gap <= TICK_MAX then
				tick = true
			end
			beat.interval, beat.last = gap, hitAt
		else
			beats[known] = { last = hitAt }
		end
	end

	-- 1. A combat-log line of yours with the hit.
	local detect = ns.detect
	if detect and detect.sawGreyLine and math.abs(detect.lastMineLineAt - hitAt) <= LINE_WINDOW then
		return "you"
	end

	-- 2. A weapon swing of yours.
	if physical then
		for _, swing in ipairs(swings) do
			if not swing.used then
				local lag = hitAt - swing.at
				local early, late = SwingWindow(swing.ranged)
				if (lag >= early and lag <= late) or (lag < 0 and -lag <= SWING_AFTER) then
					swing.used = true
					if not swing.ranged and lag >= 0.05 then
						LearnDelay(lag)
					end
					return "you"
				end
			end
		end
	end

	-- 3. A cast of yours, oldest first, whose school fits.
	for _, cast in ipairs(casts) do
		local since = hitAt - cast.at
		if not cast.used and since >= 0 and since <= CAST_WINDOW then
			local castSchool = spellSchool[cast.spell]
			if castSchool == nil or known == nil or castSchool == known then
				cast.used = true
				if castSchool == nil and known then
					spellSchool[cast.spell] = known
					schoolCastAt[known] = cast.at
				end
				return "you"
			end
		end
	end

	-- 4. A tick of a damage-over-time of yours.
	if tick and hitAt - (schoolCastAt[known] or -100) <= DOT_MEMORY then
		return "you"
	end

	-- 5. Your pet attacking your target.
	if physical and hitAt - petLast >= PET_GAP and PetOnTarget() then
		petLast = hitAt
		return "pet"
	end
	return nil
end
