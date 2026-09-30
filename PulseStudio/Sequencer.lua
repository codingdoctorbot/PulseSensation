-- PulseStudio — Sequencer.lua
--
-- In-memory multi-track timeline model for PulseStudio.
-- Tracks separate Low and High motor blocks, offsets, and durations.

local _, Studio = ...

Studio.Blocks = {}
Studio.SelectedBlockID = nil
local nextBlockID = 1

function Studio:Clear()
	Studio.Blocks = {}
	Studio.SelectedBlockID = nil
	nextBlockID = 1
end

function Studio:AddBlock(role, start, duration, intensity)
	local id = nextBlockID
	nextBlockID = nextBlockID + 1

	local block = {
		id = id,
		role = role or "low",
		start = math.max(0.0, start or 0.0),
		duration = math.max(0.020, duration or 0.100),
		intensity = math.max(0.05, math.min(1.0, intensity or 0.75)),
	}

	tinsert(Studio.Blocks, block)
	Studio.SelectedBlockID = id
	return block
end

function Studio:RemoveBlock(id)
	for idx, b in ipairs(Studio.Blocks) do
		if b.id == id then
			tremove(Studio.Blocks, idx)
			if Studio.SelectedBlockID == id then
				Studio.SelectedBlockID = Studio.Blocks[1] and Studio.Blocks[1].id or nil
			end
			return true
		end
	end
	return false
end

function Studio:GetSelectedBlock()
	if not Studio.SelectedBlockID then
		return nil
	end
	for _, b in ipairs(Studio.Blocks) do
		if b.id == Studio.SelectedBlockID then
			return b
		end
	end
	return nil
end

function Studio:UpdateSelectedBlock(key, value)
	local b = self:GetSelectedBlock()
	if not b then
		return
	end

	if key == "start" then
		b.start = math.max(0.0, value or 0.0)
	elseif key == "duration" then
		b.duration = math.max(0.020, value or 0.020)
	elseif key == "intensity" then
		b.intensity = math.max(0.05, math.min(1.0, value or 0.5))
	elseif key == "role" then
		b.role = value or "low"
	end
end

---------------------------------------------------------------------------
-- Import Built-in Modes for Remixing
---------------------------------------------------------------------------

function Studio:LoadBuiltin(modeID)
	if not _G.Pulse or not _G.Pulse.Modes or not _G.Pulse.Modes[modeID] then
		return false
	end

	local modeDef = _G.Pulse.Modes[modeID]
	self:Clear()

	if modeDef.continuous then
		-- Continuous modes get 1 held block per motor
		if (modeDef.low or 0) > 0 then
			self:AddBlock("low", 0.0, 0.40, modeDef.low)
		end
		if (modeDef.high or 0) > 0 then
			self:AddBlock("high", 0.0, 0.40, modeDef.high)
		end
		return true
	end

	local baseDur = modeDef.baseDuration or 0.10
	local curTime = 0.0

	for _, step in ipairs(modeDef.steps or {}) do
		if step.gap then
			curTime = curTime + (step.gap or 0)
		else
			local dur = (step.relDuration or 1.0) * baseDur
			local mag = step.relIntensity or 1.0
			local r = step.role or "both"
			self:AddBlock(r, curTime, dur, mag)
			curTime = curTime + dur
		end
	end
	return true
end
