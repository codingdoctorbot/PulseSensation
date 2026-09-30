-- PulseBridge — WeakAuras.lua
--
-- Direct WeakAuras hook and custom action bridge.
-- Allows custom WeakAuras triggers and action scripts to dispatch haptics effortlessly.

local _, Bridge = ...

Bridge.HasWeakAuras = false

local function initWeakAurasHook()
	if Bridge.HasWeakAuras then
		return
	end

	if _G.WeakAuras then
		Bridge.HasWeakAuras = true

		-- Inject helper directly into WeakAuras namespace if allowed
		if type(_G.WeakAuras) == "table" and not _G.WeakAuras.Pulse then
			_G.WeakAuras.Pulse = function(modeID, scale)
				return Bridge:Play(modeID, scale, "PB_WA")
			end
		end

		-- Global convenience alias for WeakAuras Custom Actions:
		-- Simply write `WeakAurasPulse("BURST")` inside any custom WA action script!
		_G.WeakAurasPulse = function(modeID, scale)
			return Bridge:Play(modeID, scale, "PB_WA")
		end
	end
end

local waFrame = CreateFrame("Frame")
waFrame:RegisterEvent("PLAYER_LOGIN")
waFrame:RegisterEvent("ADDON_LOADED")
waFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and arg1 == "WeakAuras") then
		initWeakAurasHook()
	end
end)
