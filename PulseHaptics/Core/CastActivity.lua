-- Pulse — Core/CastActivity.lua
--
-- Classifies the player's own spell activity into semantic outcomes. Adapted from the
-- SpellActivityClassifier prototype in Cooking/, kept as a core service because the
-- classification is reusable and nothing about it is Pulse-specific.
--
-- THE PROBLEM IT SOLVES. UNIT_SPELLCAST_SUCCEEDED fires identically for an instant ability
-- and for the completion of a three-second cast, which is why selfCastSucceeded has always
-- felt indiscriminate. Tracking whether a START was seen for the same cast turns one
-- ambiguous event into three: instant, cast completed, channel completed. Crafting is the
-- same trick against the trade-skill events.
--
-- WHAT IT DOES NOT DO. It fires no cues, owns no settings and never touches the engine — it
-- emits classifications and Modules/Casting.lua decides what is worth feeling. It reads no
-- restricted unit: every handler filters to "player" first, and nothing inspects a target,
-- an amount or an aura.
--
-- MIGRATION NOTE, worth reading before extending this. Modules/Combat.lua has already
-- been migrated to consume CastActivity:OnActivity for castTexture, but
-- Modules/AlertGeneric.lua still registers its own frame for failed and interrupted alerts.
-- Folding AlertGeneric in is a later step, and when it happens AlertGeneric.lua's
-- IGNORED_SPELL_IDS filter (the Touch of Death Notification fix, earned from a live bug
-- report) MUST come with it — the prototype routed FAILED_QUIET straight through and would
-- resurrect that spam.

local ADDON_NAME, Pulse = ...

local CastActivity = {}
Pulse.CastActivity = CastActivity

-- A pending cast is dropped after this long without an outcome. Without the sweep, a cast
-- whose STOP is never delivered keeps its entry forever and makes the next cast with the
-- same GUID look like a completion of the old one.
local STALE_TIMEOUT = 10
local SWEEP_INTERVAL = 2

CastActivity.pending = {}
CastActivity.activeChannel = nil
CastActivity.crafting = nil

local listeners = {}

-- Subscribe to every classification. The callback receives one table; see the
-- classification strings emitted below.
function CastActivity:OnActivity(callback)
	listeners[#listeners + 1] = callback
end

local function emit(result)
	result.time = GetTime()
	for _, callback in ipairs(listeners) do
		-- xpcall per listener: isolates consumers while reporting real errors to default error handler
		local errHandler = _G.geterrorhandler and _G.geterrorhandler()
		if errHandler then
			xpcall(callback, errHandler, result)
		else
			pcall(callback, result)
		end
	end
end

-- A cast is identified by its GUID where one exists. castGUID is unique per cast attempt;
-- spellID alone is not, since the same spell cast twice in a row would collide.
local function keyFor(castGUID, spellID)
	if castGUID then
		return "g:" .. tostring(castGUID)
	end
	return "s:" .. tostring(spellID or 0)
end

local function isPlayer(unit)
	return unit == "player"
end

-- Handlers

function CastActivity:_OnStart(unit, castGUID, spellID)
	if not isPlayer(unit) then
		return
	end
	self.pending[keyFor(castGUID, spellID)] = { spellID = spellID, startedAt = GetTime() }

	local crafting = self.crafting and self.crafting.spellID == spellID
	emit({
		classification = crafting and "CRAFT_CAST_START" or "CAST_START",
		spellID = spellID,
		castGUID = castGUID,
		isCrafting = crafting,
	})
end

function CastActivity:_OnChannelStart(unit, castGUID, spellID)
	if not isPlayer(unit) then
		return
	end
	self.activeChannel = {
		key = keyFor(castGUID, spellID),
		spellID = spellID,
		startedAt = GetTime(),
		succeeded = false,
	}
	emit({ classification = "CHANNEL_START", spellID = spellID, castGUID = castGUID })
end

-- The interesting one. Three different meanings arrive on this single event and are told
-- apart purely by what state was already being tracked.
function CastActivity:_OnSucceeded(unit, castGUID, spellID)
	if not isPlayer(unit) then
		return
	end
	local key = keyFor(castGUID, spellID)

	-- A crafting cast completing is a finished craft, not a finished spell.
	if self.crafting and self.crafting.spellID == spellID then
		local started = self.crafting.startedAt
		self.crafting = nil
		self.pending[key] = nil
		emit({
			classification = "CRAFT_COMPLETE",
			spellID = spellID,
			castGUID = castGUID,
			isCrafting = true,
			duration = GetTime() - (started or GetTime()),
		})
		return
	end

	-- A channel that reached its end. Checked before the pending table because a channel
	-- can also have had a START.
	if self.activeChannel and self.activeChannel.key == key then
		self.activeChannel.succeeded = true
		emit({ classification = "CHANNEL_COMPLETE", spellID = spellID, castGUID = castGUID })
		return
	end

	-- A START was seen for this exact cast, so it had a cast time.
	if self.pending[key] then
		local started = self.pending[key].startedAt
		self.pending[key] = nil
		emit({
			classification = "CAST_COMPLETE",
			spellID = spellID,
			castGUID = castGUID,
			duration = GetTime() - (started or GetTime()),
		})
		return
	end

	-- No START, no channel: it happened instantly. This is the distinction the old
	-- selfCastSucceeded cue could never make.
	emit({ classification = "INSTANT", spellID = spellID, castGUID = castGUID })
end

function CastActivity:_OnInterrupted(unit, castGUID, spellID)
	if not isPlayer(unit) then
		return
	end
	self.pending[keyFor(castGUID, spellID)] = nil
	emit({ classification = "INTERRUPTED", spellID = spellID, castGUID = castGUID })
end

local IGNORED_SPELL_IDS = { [121125] = true, [1221044] = true }

function CastActivity:_OnFailed(unit, castGUID, spellID)
	if not isPlayer(unit) then
		return
	end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
		return
	end
	if not issecretvalue(spellID) and IGNORED_SPELL_IDS[spellID] then
		return
	end
	self.pending[keyFor(castGUID, spellID)] = nil
	emit({ classification = "FAILED", spellID = spellID, castGUID = castGUID })
end

function CastActivity:_OnStop(unit, castGUID, spellID)
	if not isPlayer(unit) then
		return
	end
	local key = keyFor(castGUID, spellID)
	local pending = self.pending[key]
	self.pending[key] = nil

	-- A craft whose cast stopped without succeeding was abandoned.
	if self.crafting and self.crafting.spellID == spellID then
		local started = self.crafting.startedAt
		self.crafting = nil
		emit({
			classification = "CRAFT_STOPPED",
			spellID = spellID,
			castGUID = castGUID,
			isCrafting = true,
			duration = GetTime() - (started or GetTime()),
		})
	else
		emit({
			classification = "CAST_STOPPED",
			spellID = spellID,
			castGUID = castGUID,
			duration = pending and (GetTime() - (pending.startedAt or GetTime())) or nil,
		})
	end
end

function CastActivity:_OnChannelStop(unit, castGUID, spellID)
	if not isPlayer(unit) then
		return
	end
	local channel = self.activeChannel
	self.activeChannel = nil
	emit({
		classification = "CHANNEL_STOP",
		spellID = spellID,
		castGUID = castGUID,
		completed = channel and channel.succeeded or false,
		duration = channel and (GetTime() - channel.startedAt) or nil,
	})
end

function CastActivity:_OnCraftBegin(recipeSpellID)
	if type(recipeSpellID) ~= "number" then
		return
	end
	self.crafting = { spellID = recipeSpellID, startedAt = GetTime() }
	emit({ classification = "CRAFT_START", spellID = recipeSpellID, isCrafting = true })
end

function CastActivity:_OnCraftAborted()
	if not self.crafting then
		return
	end
	local craft = self.crafting
	self.crafting = nil
	emit({
		classification = "CRAFT_STOPPED",
		spellID = craft.spellID,
		isCrafting = true,
		duration = GetTime() - (craft.startedAt or GetTime()),
	})
end

function CastActivity:_Sweep()
	local now = GetTime()
	for key, cast in pairs(self.pending) do
		if now - (cast.startedAt or now) > STALE_TIMEOUT then
			self.pending[key] = nil
		end
	end
	if self.activeChannel and now - self.activeChannel.startedAt > STALE_TIMEOUT then
		self.activeChannel = nil
	end
	if self.crafting and now - self.crafting.startedAt > STALE_TIMEOUT then
		self.crafting = nil
	end
end

function CastActivity:Reset()
	self.pending = {}
	self.activeChannel = nil
	self.crafting = nil
end

-- Event bridge

local frame = CreateFrame("Frame")
local sweepElapsed = 0
local registered = false
local consumers = {}

local EVENTS = {
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_FAILED_QUIET",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
}

local function onSweepUpdate(_, elapsed)
	sweepElapsed = sweepElapsed + elapsed
	if sweepElapsed >= SWEEP_INTERVAL then
		sweepElapsed = 0
		CastActivity:_Sweep()
	end
end

-- Registration is gated like every other watcher here: nothing is registered while no
-- consumer wants it. Keyed by consumer so multiple modules (Casting, Crafting) do not
-- deregister each other.
function CastActivity:SetActive(consumerKey, active)
	if active == nil and type(consumerKey) == "boolean" then
		consumerKey, active = "default", consumerKey
	end
	consumerKey = consumerKey or "default"
	if active then
		consumers[consumerKey] = true
	else
		consumers[consumerKey] = nil
	end

	local shouldRegister = next(consumers) ~= nil
	if shouldRegister == registered then
		return
	end
	registered = shouldRegister
	if registered then
		for _, event in ipairs(EVENTS) do
			if frame.RegisterUnitEvent then
				frame:RegisterUnitEvent(event, "player")
			else
				frame:RegisterEvent(event)
			end
		end
		-- The two trade-skill events carry no unit token, so they need plain registration.
		frame:RegisterEvent("TRADE_SKILL_CRAFT_BEGIN")
		frame:RegisterEvent("UPDATE_TRADESKILL_CAST_STOPPED")
		frame:SetScript("OnUpdate", onSweepUpdate)
	else
		frame:UnregisterAllEvents()
		frame:SetScript("OnUpdate", nil)
		self:Reset()
	end
end

-- Reach-in for PulseDebug, read-only: consumer accounting
function CastActivity:_DebugActive()
	local consumerList = {}
	for k in pairs(consumers) do
		consumerList[#consumerList + 1] = tostring(k)
	end
	table.sort(consumerList)
	return {
		registered = registered,
		consumers = #consumerList > 0 and table.concat(consumerList, ", ") or "none",
	}
end

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "TRADE_SKILL_CRAFT_BEGIN" then
		CastActivity:_OnCraftBegin(...)
	elseif event == "UPDATE_TRADESKILL_CAST_STOPPED" then
		CastActivity:_OnCraftAborted()
	elseif event == "UNIT_SPELLCAST_START" then
		CastActivity:_OnStart(...)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		CastActivity:_OnSucceeded(...)
	elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
		CastActivity:_OnFailed(...)
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		CastActivity:_OnInterrupted(...)
	elseif event == "UNIT_SPELLCAST_STOP" then
		CastActivity:_OnStop(...)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		CastActivity:_OnChannelStart(...)
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		CastActivity:_OnChannelStop(...)
	end
end)
