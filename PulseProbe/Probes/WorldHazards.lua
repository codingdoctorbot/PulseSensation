-- PulseProbe — Probes/WorldHazards.lua
--
-- Hooks native Blizzard screen shake utilities and intercepts environmental trauma.
-- Tests: ScriptAnimationUtil.ShakeFrame (boss quakes), ENVIRONMENTAL_DAMAGE (Lava, Slime, Falling).

local ADDON_NAME, Probe = ...

local WH = {}
Probe.WorldHazards = WH

WH.isShakeHooked = false

local frame = CreateFrame("Frame")
local playerGUID = nil
local lastShakeTime = 0
local lastEnvDamageTime = 0

-- 1. Native Screen Shake Hook (hooksecurefunc guarantees zero taint on Blizzard UI)
local function onScreenShakeHook(region, shakeConfig, duration, frequency)
	if region ~= UIParent then
		return
	end

	local now = GetTime()
	if now - lastShakeTime < 0.250 then -- 250ms throttle
		return
	end
	lastShakeTime = now

	local dur = (type(duration) == "number" and duration > 0) and duration or 0.35
	local freq = (type(frequency) == "number") and frequency or 0
	local payload = string.format("UIParent Shake | dur=%.2fs freq=%.1f", dur, freq)

	-- Verify taint status of execution path
	local isTainted = (issecurevariable and not issecurevariable("UIParent")) or false
	Probe:AddLogEntry("World", "ShakeFrame (ScreenShake)", payload, false, isTainted, "screenShake")
end

-- 2. Environmental Hazards (Lava, Slime, Fire, Falling)
local function onCombatLogEvent()
	local _, event, _, _, _, _, _, destGUID, _, _, _, environmentalType, amount = CombatLogGetCurrentEventInfo()

	if event ~= "ENVIRONMENTAL_DAMAGE" then
		return
	end

	if not playerGUID then
		playerGUID = UnitGUID("player")
	end

	if destGUID == playerGUID then
		local now = GetTime()
		if now - lastEnvDamageTime < 0.300 then
			return
		end
		lastEnvDamageTime = now

		local envType = string.upper(tostring(environmentalType or "UNKNOWN"))
		local dmg = amount or 0
		local cue = "envDamageFalling"

		if envType == "LAVA" then
			cue = "envDamageLava"
		elseif envType == "SLIME" then
			cue = "envDamageSlime"
		elseif envType == "FALLING" then
			cue = "envDamageFalling"
		elseif envType == "FIRE" then
			cue = "envDamageLava"
		end

		local payload = string.format("Type: %s | Amount: %d damage", envType, dmg)
		Probe:AddLogEntry("World", "ENVIRONMENTAL_DAMAGE", payload, false, false, cue)
	end
end

function WH:OnInit(probeCore)
	frame:SetScript("OnEvent", onCombatLogEvent)

	if ScriptAnimationUtil and type(ScriptAnimationUtil.ShakeFrame) == "function" then
		hooksecurefunc(ScriptAnimationUtil, "ShakeFrame", onScreenShakeHook)
		self.isShakeHooked = true
	end
end

function WH:OnEnable()
	playerGUID = UnitGUID("player")
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

Probe:RegisterProbe("WorldHazards", WH)
