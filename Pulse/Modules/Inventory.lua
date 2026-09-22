-- Pulse — Modules/Inventory.lua
--
-- Tactile inventory feedback: slot acquisition, consumption, and bag-full alarms.
-- Monitors total free bag slots via C_Container.CalculateTotalNumberOfFreeBagSlots on
-- BAG_UPDATE_DELAYED (the settled post-batch event) and watches UI_ERROR_MESSAGE for
-- full inventory rejections. Zero-allocation design with defensive secrecy guards.

local ADDON_NAME, Pulse = ...

local M = {}
Pulse:RegisterModule("Inventory", M)

local WATCHED = { "bagItemAdded", "bagItemUsed", "bagFull" }

local frame = CreateFrame("Frame")
local lastFreeSlots = nil

local function getFreeBagSlots()
	if C_Container and type(C_Container.CalculateTotalNumberOfFreeBagSlots) == "function" then
		local ok, free = pcall(C_Container.CalculateTotalNumberOfFreeBagSlots)
		if ok and not issecretvalue(free) and type(free) == "number" then
			return free
		end
	end
	return nil
end

local function isInventoryFullError(messageType, message)
	if issecretvalue(message) or issecretvalue(messageType) then
		return false
	end
	if type(ERR_INV_FULL) == "string" and message == ERR_INV_FULL then
		return true
	end
	if type(ERR_ITEM_MAX_COUNT) == "string" and message == ERR_ITEM_MAX_COUNT then
		return true
	end
	return false
end

-- Checks if standard storage, merchant, or mail frames are currently open to avoid
-- treating selling, banking, or mailing items as consuming them.
local function isInteractingWithStorageOrMerchant()
	if MerchantFrame and MerchantFrame:IsShown() then
		return true
	end
	if BankFrame and BankFrame:IsShown() then
		return true
	end
	if MailFrame and MailFrame:IsShown() then
		return true
	end
	if TradeFrame and TradeFrame:IsShown() then
		return true
	end
	if GuildBankFrame and GuildBankFrame:IsShown() then
		return true
	end
	if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
		return true
	end
	if C_PlayerInteractionManager and type(C_PlayerInteractionManager.IsInteractingWithNpcOfType) == "function" then
		if Enum and Enum.PlayerInteractionType then
			local e = Enum.PlayerInteractionType
			if e.Merchant and C_PlayerInteractionManager.IsInteractingWithNpcOfType(e.Merchant) then
				return true
			end
			if e.Banker and C_PlayerInteractionManager.IsInteractingWithNpcOfType(e.Banker) then
				return true
			end
			if e.GuildBanker and C_PlayerInteractionManager.IsInteractingWithNpcOfType(e.GuildBanker) then
				return true
			end
			if e.MailInfo and C_PlayerInteractionManager.IsInteractingWithNpcOfType(e.MailInfo) then
				return true
			end
			if e.Auctioneer and C_PlayerInteractionManager.IsInteractingWithNpcOfType(e.Auctioneer) then
				return true
			end
			if e.TradePartner and C_PlayerInteractionManager.IsInteractingWithNpcOfType(e.TradePartner) then
				return true
			end
		end
	end
	return false
end

function M:OnEnable()
	local function sync()
		frame:UnregisterAllEvents()
		lastFreeSlots = nil
		if not Pulse.Database:Get("masterEnabled") then
			return
		end

		local anyWatched = false
		for _, cueID in ipairs(WATCHED) do
			if Pulse.Database:GetCue(cueID) then
				anyWatched = true
				break
			end
		end
		if not anyWatched then
			return
		end

		frame:RegisterEvent("BAG_UPDATE_DELAYED")
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		if Pulse.Database:GetCue("bagFull") then
			frame:RegisterEvent("UI_ERROR_MESSAGE")
			pcall(frame.RegisterEvent, frame, "BAG_OVERFLOW_WITH_FULL_INVENTORY")
		end

		lastFreeSlots = getFreeBagSlots()
	end

	frame:SetScript("OnEvent", function(_, event, arg1, arg2)
		if event == "PLAYER_ENTERING_WORLD" then
			lastFreeSlots = getFreeBagSlots()
			return
		end

		if event == "BAG_OVERFLOW_WITH_FULL_INVENTORY" then
			Pulse:FireIfEnabled("bagFull")
			return
		end

		if event == "UI_ERROR_MESSAGE" then
			if isInventoryFullError(arg1, arg2) then
				Pulse:FireIfEnabled("bagFull")
			end
			return
		end

		if event == "BAG_UPDATE_DELAYED" then
			local free = getFreeBagSlots()
			if free == nil then
				return
			end

			if lastFreeSlots == nil then
				lastFreeSlots = free
				return
			end

			if free < lastFreeSlots then
				Pulse:FireIfEnabled("bagItemAdded")
			elseif free > lastFreeSlots then
				if not isInteractingWithStorageOrMerchant() then
					Pulse:FireIfEnabled("bagItemUsed")
				end
			end

			if free == 0 and lastFreeSlots > 0 then
				Pulse:FireIfEnabled("bagFull")
			end

			lastFreeSlots = free
		end
	end)

	Pulse:BindFrame(WATCHED, sync)
end
