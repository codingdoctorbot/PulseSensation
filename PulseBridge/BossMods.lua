-- PulseBridge — BossMods.lua
--
-- Automatic haptic dispatcher for BigWigs and Deadly Boss Mods (DBM).
-- Safely hooks boss mechanic messages and special warnings without execution taint.

local _, Bridge = ...

Bridge.HasBigWigs = false
Bridge.HasDBM = false

---------------------------------------------------------------------------
-- Keyword Haptic Classifier (Zero Table Allocation)
---------------------------------------------------------------------------

local function classifyMessage(text)
	if not text or text == "" then
		return "TAP", 0.5
	end
	local lower = string.lower(text)

	-- Priority 1: Lethal movement / avoid mechanics
	if string.find(lower, "run away") or string.find(lower, "move away") or string.find(lower, "spread") then
		return "SURGE", 1.0
	end

	-- Priority 2: Taunt / Tank swap
	if string.find(lower, "taunt") or string.find(lower, "swap") then
		return "THUMP", 1.0
	end

	-- Priority 3: Interrupt / Spellcast warning
	if string.find(lower, "interrupt") or string.find(lower, "kick") or string.find(lower, "casting") then
		return "DEFLECT", 0.9
	end

	-- Priority 4: Stun / Soak
	if string.find(lower, "soak") or string.find(lower, "stack") then
		return "PULSE_BEAT", 0.8
	end

	-- Default gentle notification
	return "TAP", 0.5
end

---------------------------------------------------------------------------
-- BigWigs Hook
---------------------------------------------------------------------------

local function initBigWigs()
	if Bridge.HasBigWigs then
		return
	end

	local bw = _G.BigWigsLoader or _G.BigWigs
	if bw and bw.RegisterMessage then
		Bridge.HasBigWigs = true

		local listener = {}
		function listener:OnBigWigsMessage(_, _, text, _, _, emphasis)
			if not Bridge.db or not Bridge.db.enabled or not Bridge.db.bigwigsEnabled then
				return
			end
			if emphasis then
				Bridge:Play("IMPACT", 1.0, "PB_BigWigs")
			else
				local mode, scale = classifyMessage(text)
				Bridge:Play(mode, scale, "PB_BigWigs")
			end
		end

		bw.RegisterMessage(listener, "BigWigs_Message", "OnBigWigsMessage")
	end
end

---------------------------------------------------------------------------
-- Deadly Boss Mods (DBM) Hook
---------------------------------------------------------------------------

local function initDBM()
	if Bridge.HasDBM then
		return
	end

	if _G.DBM and type(_G.DBM.RegisterCallback) == "function" then
		Bridge.HasDBM = true

		_G.DBM:RegisterCallback("DBM_SpecialWarning", function(_, _, text, warningType)
			if not Bridge.db or not Bridge.db.enabled or not Bridge.db.dbmEnabled then
				return
			end

			-- DBM warning types: "runaway", "you", "target", "interrupt", etc.
			local wt = warningType and string.lower(tostring(warningType)) or ""
			if wt == "runaway" or wt == "you" then
				Bridge:Play("SURGE", 1.0, "PB_DBM")
			elseif wt == "interrupt" then
				Bridge:Play("DEFLECT", 0.9, "PB_DBM")
			elseif wt == "taunt" then
				Bridge:Play("THUMP", 1.0, "PB_DBM")
			else
				local mode, scale = classifyMessage(text)
				Bridge:Play(mode, scale, "PB_DBM")
			end
		end)

		_G.DBM:RegisterCallback("DBM_Announce", function(_, _, text)
			if not Bridge.db or not Bridge.db.enabled or not Bridge.db.dbmEnabled then
				return
			end
			local mode, scale = classifyMessage(text)
			Bridge:Play(mode, scale * 0.7, "PB_DBM")
		end)
	end
end

---------------------------------------------------------------------------
-- Registration Frame
---------------------------------------------------------------------------

local bossFrame = CreateFrame("Frame")
bossFrame:RegisterEvent("PLAYER_LOGIN")
bossFrame:RegisterEvent("ADDON_LOADED")
bossFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_LOGIN" then
		initBigWigs()
		initDBM()
	elseif event == "ADDON_LOADED" then
		if arg1 == "BigWigs" or arg1 == "BigWigs_Core" then
			initBigWigs()
		elseif arg1 == "DBM-Core" or arg1 == "DBM" then
			initDBM()
		end
	end
end)
