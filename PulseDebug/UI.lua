-- PulseDebug — UI.lua
--
-- A window for the questions chat cannot answer. Debug.lua's commands each print one
-- snapshot: fine for "is the pad enabled", useless for "what does this hold actually do
-- while it decays", which is most of what Pulse does. Re-typing /pdebug layers eight times
-- and reading eight blocks of scrollback is not watching a texture fade.
--
-- So: the same readouts, on a frame, with a Live toggle that re-renders them ~10x a second.
-- A hold fired from the settings panel or /pdebug hold can then be watched all the way down
-- instead of sampled.
--
-- Same stance as PulseChecklist's window — a genuinely custom frame using plain Blizzard
-- templates, not Pulse's own panel theme. This is a developer tool; it has no reason to
-- inherit Pulse's "look like Blizzard's own settings panel" constraint, and coupling it to
-- Pulse/UI/Panel/Theme.lua would make a troubleshooting tool break whenever the thing it
-- troubleshoots gets restyled.
--
-- Templates used are the ones PulseChecklist already relies on: BACKDROP_DIALOG_32_32
-- (Blizzard_SharedXML/Backdrop.lua), UIPanelCloseButton, UIPanelButtonTemplate and
-- UIPanelScrollFrameTemplate.

local ADDON_NAME = ...

local wipe = wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

local FRAME_WIDTH = 660
local FRAME_HEIGHT = 500
local REFRESH_RATE = 0.1 -- 10Hz. Fast enough to read a release curve, slow enough that
-- rebuilding the whole string every tick costs nothing visible.

local GOOD = "|cff44ff44"
local BAD = "|cffff5555"
local WARN = "|cffffcc00"
local DIM = "|cff999999"
local HEAD = "|cffffffff"
local R = "|r"

local function core()
	local P = _G.Pulse
	if not P or not P.Database or not P.Registry or not P.Engine then
		return nil
	end
	return P
end

local function flag(value)
	return value and (GOOD .. "yes" .. R) or (BAD .. "no" .. R)
end

---------------------------------------------------------------------------
-- Main frame
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "PulseDebugUIFrame", UIParent, "BackdropTemplate")
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop(BACKDROP_DIALOG_32_32)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("Pulse Debug")

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

---------------------------------------------------------------------------
-- Body: one FontString in a scroll frame
---------------------------------------------------------------------------

-- One string rebuilt per render rather than a row widget per line. The views are at most a
-- few dozen lines and are replaced wholesale every tick while Live is on, so pooling row
-- frames would buy nothing and cost the complexity of recycling them.
--
-- WoW ships no monospace font, so the %-Ns padding below lines columns up approximately
-- rather than exactly. Readable, not a table.
---------------------------------------------------------------------------
-- Sticky HUD: Last fired cue banner (persists across all views)
---------------------------------------------------------------------------

local stickyHudFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
stickyHudFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -98)
stickyHudFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -98)
stickyHudFrame:SetHeight(52)
stickyHudFrame:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 10,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
stickyHudFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.85)
stickyHudFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)

local stickyHudTitle = stickyHudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stickyHudTitle:SetPoint("TOPLEFT", stickyHudFrame, "TOPLEFT", 6, -4)
stickyHudTitle:SetText("|cffffd100LAST FIRED (STICKY HUD):|r")

local stickyHudText = stickyHudFrame:CreateFontString(nil, "OVERLAY", "ChatFontSmall")
stickyHudText:SetPoint("TOPLEFT", stickyHudTitle, "BOTTOMLEFT", 0, -2)
stickyHudText:SetPoint("BOTTOMRIGHT", stickyHudFrame, "BOTTOMRIGHT", -6, 2)
stickyHudText:SetJustifyH("LEFT")
stickyHudText:SetJustifyV("TOP")
stickyHudText:SetText(DIM .. "No cues captured yet. Fire any cue in-game or via action buttons." .. R)

local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -156)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 18)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(FRAME_WIDTH - 60, 1)
scrollFrame:SetScrollChild(scrollChild)

local body = scrollChild:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
body:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
body:SetWidth(FRAME_WIDTH - 60)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")

---------------------------------------------------------------------------
-- Views
---------------------------------------------------------------------------

-- Each view returns a plain string. Keeping them pure makes the Live path trivial: the
-- refresh loop just calls the current one again and assigns the result.

local views = {}
local viewOrder = { "state", "layers", "channels", "log", "modules", "schema" }
local currentView = "layers"

local function line(label, value)
	return string.format("%-28s %s", label, value or "")
end

function views.state(P)
	local out = {}
	out[#out + 1] = HEAD .. "— device —" .. R
	out[#out + 1] = line("GamePadEnable", tostring(C_CVar.GetCVar("GamePadEnable")))
	out[#out + 1] = line("Pulse sees a pad", flag(P.Engine:IsDeviceReady()))

	out[#out + 1] = ""
	out[#out + 1] = HEAD .. "— pulse —" .. R
	out[#out + 1] = line("masterEnabled", flag(P.Database:Get("masterEnabled")))
	out[#out + 1] = line("profile", tostring(P.Database:GetActiveProfileName()))
	if type(P.Database.GetProfileResolution) == "function" then
		out[#out + 1] = line("profile resolution", tostring(P.Database:GetProfileResolution()))
	end
	if type(P.Database.HasPendingProfileSwitch) == "function" then
		out[#out + 1] = line("pending switch", flag(P.Database:HasPendingProfileSwitch()))
	end
	out[#out + 1] = line("masterIntensity", tostring(P.Database:Get("masterIntensity")))
	out[#out + 1] = line("schema", tostring(P.Database:Get("defaultHapticSchema")))

	local total, enabled = 0, 0
	for _, category in ipairs(P.Registry:GetCategories()) do
		for _, trigger in ipairs(P.Registry:GetTriggersByCategory(category)) do
			total = total + 1
			if P.Database:GetCue(trigger.id) then
				enabled = enabled + 1
			end
		end
	end
	out[#out + 1] = line("triggers enabled", string.format("%d of %d", enabled, total))
	out[#out + 1] = line("active layers", tostring(#P.Engine:_DebugLayers()))
	return table.concat(out, "\n")
end

function views.layers(P)
	local layers = P.Engine:_DebugLayers()
	if #layers == 0 then
		return DIM
			.. "Nothing blending into the channel right now."
			.. R
			.. "\n\n"
			.. DIM
			.. "Turn Live on, then fire a continuous cue — /pdebug hold "
			.. "<id>, or the settings panel's mode tester — and watch it decay here."
			.. R
	end

	-- Four roles, not two: a layer may drive ltrigger/rtrigger only (Locomotion's split
	-- footfalls do), so a nil column has to read as blank rather than 0.00.
	local function cell(value)
		if value == nil then
			return DIM .. "  -   " .. R
		end
		return string.format("%-6.2f", value)
	end

	local out = {}
	out[#out + 1] = HEAD
		.. string.format("%-22s %-7s %-7s %-7s %-7s %s", "layer", "low", "high", "ltrig", "rtrig", "left")
		.. R
	for _, layer in ipairs(layers) do
		out[#out + 1] = string.format(
			"%-22s %s %s %s %s %.2fs",
			layer.name,
			cell(layer.low),
			cell(layer.high),
			cell(layer.ltrigger),
			cell(layer.rtrigger),
			math.max(layer.remaining, 0)
		)
	end
	return table.concat(out, "\n")
end

local channelPeaks = {}
local recentPeaks = {}
local recentPeakTimes = {}
local PEAK_HOLD_SECONDS = 1.5

local function updateRecentPeak(channel, mag)
	if not mag or mag <= 0 then
		return
	end
	recentPeaks[channel] = math.max(recentPeaks[channel] or 0, mag)
	recentPeakTimes[channel] = (type(GetTime) == "function") and GetTime() or 0
	if mag > (channelPeaks[channel] or 0) then
		channelPeaks[channel] = mag
	end
end

function views.channels(P)
	local channels = P.Engine:_DebugChannels()
	if not next(channels) then
		return DIM .. "No channel has been driven yet this session." .. R
	end
	local out = {}
	out[#out + 1] = HEAD
		.. string.format("%-14s %-9s %-9s %-9s %s", "channel", "smoothed", "hold 1.5s", "peak", "last set")
		.. R
	local now = (type(GetTime) == "function") and GetTime() or 0
	for channel, info in pairs(channels) do
		local curSmoothed = info.smoothed or 0
		if curSmoothed > (channelPeaks[channel] or 0) then
			channelPeaks[channel] = curSmoothed
		end
		if curSmoothed > (recentPeaks[channel] or 0) then
			recentPeaks[channel] = curSmoothed
			recentPeakTimes[channel] = now
		end
		local rPeak = recentPeaks[channel] or 0
		if (now - (recentPeakTimes[channel] or 0)) > PEAK_HOLD_SECONDS then
			rPeak = curSmoothed
			recentPeaks[channel] = curSmoothed
		end
		out[#out + 1] = string.format(
			"%-14s %-9.2f %-9.2f %-9.2f %s",
			channel,
			curSmoothed,
			rPeak,
			channelPeaks[channel] or 0,
			tostring(info.lastSet)
		)
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Event log (rolling buffer with millisecond capture)
---------------------------------------------------------------------------

local eventLog = {}
local MAX_LOG_ENTRIES = 50
local lastFiredEvents = {}

local function updateStickyHud()
	if not stickyHudText then
		return
	end
	if #lastFiredEvents == 0 then
		stickyHudText:SetText(DIM .. "No cues captured yet. Fire any cue in-game or via action buttons." .. R)
		return
	end
	local lines = {}
	for i = 1, math.min(#lastFiredEvents, 3) do
		local ev = lastFiredEvents[i]
		local sec = math.floor(ev.time)
		local ms = math.floor((ev.time - sec) * 1000)
		local tStr = string.format("%02d.%03d", sec % 60, ms)
		local actColor = (ev.action == "FIRE") and "|cff44ff44"
			or ((ev.action == "HOLD") and "|cff00ccff" or "|cffffcc00")
		local extraStr = (ev.extra and ev.extra ~= "") and ("  " .. DIM .. ev.extra .. R) or ""
		lines[#lines + 1] =
			string.format("|cff888888[%s]|r %s%-4s|r |cffffffff%s|r%s", tStr, actColor, ev.action, ev.id, extraStr)
	end
	stickyHudText:SetText(table.concat(lines, "\n"))
end

local function recordEvent(action, triggerID, extra)
	local now = (type(GetTime) == "function") and GetTime() or 0
	local entry = {
		time = now,
		action = action,
		id = tostring(triggerID or "unknown"),
		extra = extra and tostring(extra) or "",
	}
	table.insert(eventLog, 1, entry)
	if #eventLog > MAX_LOG_ENTRIES then
		table.remove(eventLog)
	end
	table.insert(lastFiredEvents, 1, entry)
	if #lastFiredEvents > 3 then
		table.remove(lastFiredEvents)
	end
	if updateStickyHud then
		updateStickyHud()
	end
end

local hooked = false
local function ensureHooks()
	if hooked then
		return
	end
	local P = core()
	if not P or not P.Engine then
		return
	end
	if type(hooksecurefunc) ~= "function" then
		return
	end
	hooked = true
	if type(P.Fire) == "function" then
		hooksecurefunc(P, "Fire", function(_, triggerID, roleOrSchema, strength)
			local detail = ""
			if roleOrSchema then
				detail = tostring(roleOrSchema)
			end
			if strength then
				detail = (detail ~= "" and (detail .. " ") or "") .. string.format("@%.2f", strength)
			end
			recordEvent("FIRE", triggerID, detail)
		end)
	end
	if type(P.Hold) == "function" then
		hooksecurefunc(P, "Hold", function(_, triggerID, low, high, duration)
			local detail = string.format("L:%.2f H:%.2f (%.2fs)", low or 0, high or 0, duration or 0)
			recordEvent("HOLD", triggerID, detail)
		end)
	end
	if type(P.Stop) == "function" then
		hooksecurefunc(P, "Stop", function(_, triggerID)
			recordEvent("STOP", triggerID, "")
		end)
	end
	if type(P.PlayMode) == "function" then
		hooksecurefunc(P, "PlayMode", function(_, mode)
			recordEvent("MODE", tostring(mode or "unknown"), "")
		end)
	end
	if type(P.Engine.RawChannel) == "function" then
		hooksecurefunc(P.Engine, "RawChannel", function(_, channel, mag, dur)
			updateRecentPeak(channel, mag)
			recordEvent("RAW", channel, string.format("%.2f (%.2fs)", mag or 0, dur or 0))
		end)
	end
end

function views.log(P)
	ensureHooks()
	if #eventLog == 0 then
		return DIM
			.. "No haptic events recorded yet this session."
			.. R
			.. "\n\n"
			.. DIM
			.. "Cues fired via gameplay or test commands will appear here"
			.. "\nwith timestamps so short pulses (TICK, THUD) are captured."
			.. R
	end

	local out = {}
	out[#out + 1] = HEAD .. string.format("%-10s %-6s %-24s %s", "time", "act", "cue / channel", "detail") .. R
	for _, entry in ipairs(eventLog) do
		local detail = (entry.detail and entry.detail ~= "") and entry.detail or (entry.extra or "")
		out[#out + 1] = string.format("%-10.3f %-6s %-24s %s", entry.time, entry.action, entry.id, detail)
	end
	return table.concat(out, "\n")
end

-- Module introspection.
--
-- Pulse exposes read-only reach-ins on the modules whose state is otherwise invisible from
-- outside their file: Locomotion's _DebugGait, Crafting's _DebugCraft, Interaction's
-- _DebugInteraction. Nothing consumed them before this view existed — they were written for
-- a caller that was never built.
--
-- Discovered rather than listed: any module gaining a _Debug* function is picked up here
-- with no edit, which is the point of scanning instead of hardcoding three names.
local function debugFunctionsFor(module)
	local found = {}
	for key, value in pairs(module) do
		if type(value) == "function" and type(key) == "string" and key:find("^_Debug") then
			found[#found + 1] = key
		end
	end
	table.sort(found)
	return found
end

local function formatValue(value)
	local kind = type(value)
	if kind == "number" then
		-- Integers stay integers; a gait cadence reading 0.43 should not print as 0.
		if value == math.floor(value) then
			return tostring(value)
		end
		return string.format("%.3f", value)
	elseif kind == "boolean" then
		return flag(value)
	elseif kind == "nil" then
		return DIM .. "nil" .. R
	elseif kind == "table" then
		return DIM .. "{table}" .. R
	end
	return tostring(value)
end

function views.modules(P)
	local out = {}
	local any = false

	if P.CastActivity and type(P.CastActivity._DebugActive) == "function" then
		any = true
		out[#out + 1] = HEAD .. "CastActivity (Core)" .. R
		local ok, result = pcall(P.CastActivity._DebugActive, P.CastActivity)
		if not ok then
			out[#out + 1] = "  " .. BAD .. "_DebugActive errored" .. R
		elseif type(result) ~= "table" then
			out[#out + 1] = "  " .. DIM .. "_DebugActive" .. R .. "  " .. formatValue(result)
		else
			out[#out + 1] = "  " .. DIM .. "_DebugActive" .. R
			local keys = {}
			for field in pairs(result) do
				keys[#keys + 1] = tostring(field)
			end
			table.sort(keys)
			for _, field in ipairs(keys) do
				out[#out + 1] = string.format("      %-22s %s", field, formatValue(result[field]))
			end
		end
		out[#out + 1] = ""
	end

	for _, name in ipairs(P.moduleOrder) do
		local module = P.modules[name]
		local functions = module and debugFunctionsFor(module) or {}
		if #functions > 0 then
			any = true
			out[#out + 1] = HEAD .. name .. R
			for _, key in ipairs(functions) do
				-- pcall: a reach-in reads live module state, and a module mid-teardown can
				-- hand back something unexpected. A debug window erroring is worse than a
				-- debug window saying it could not read.
				local ok, result = pcall(module[key], module)
				if not ok then
					out[#out + 1] = "  " .. BAD .. key .. " errored" .. R
				elseif type(result) ~= "table" then
					out[#out + 1] = "  " .. DIM .. key .. R .. "  " .. formatValue(result)
				else
					out[#out + 1] = "  " .. DIM .. key .. R
					local keys = {}
					for field in pairs(result) do
						keys[#keys + 1] = tostring(field)
					end
					table.sort(keys)
					for _, field in ipairs(keys) do
						out[#out + 1] = string.format("      %-22s %s", field, formatValue(result[field]))
					end
				end
			end
			out[#out + 1] = ""
		end
	end

	if not any then
		return DIM .. "No module exposes a _Debug* reach-in." .. R
	end
	return table.concat(out, "\n")
end

function views.schema(P)
	if type(P.Engine._ActiveSchema) ~= "function" then
		return BAD .. "Engine._ActiveSchema not found." .. R
	end
	local schema = P.Engine:_ActiveSchema()
	if not schema then
		return BAD .. "No active schema." .. R
	end

	local out = {}
	out[#out + 1] = HEAD .. tostring(schema.id) .. R .. "  " .. (schema.label or "")
	out[#out + 1] = ""
	local roles = {}
	for role in pairs(schema.roles or {}) do
		roles[#roles + 1] = role
	end
	table.sort(roles)
	for _, role in ipairs(roles) do
		local def = schema.roles[role]
		out[#out + 1] =
			line("  " .. role, string.format("%s @ %.2f", def.channel or (DIM .. "silent" .. R), def.intensity or 1.0))
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------

local function render()
	local P = core()
	if not P then
		body:SetText(BAD .. "Pulse is not loaded." .. R)
		scrollChild:SetHeight(40)
		return
	end
	if updateStickyHud then
		updateStickyHud()
	end
	local view = views[currentView]
	local ok, text = pcall(view, P)
	body:SetText(ok and text or (BAD .. "view errored: " .. R .. tostring(text)))
	-- The scroll child has to match the text or UIPanelScrollFrameTemplate has nothing to
	-- scroll against and the bar sits dead at the top.
	scrollChild:SetHeight(math.max(body:GetStringHeight() + 8, 1))
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

local buttons = {}

local function highlightActive()
	for id, button in pairs(buttons) do
		-- Disabling the active one is the cheapest unambiguous "you are here" with stock
		-- templates: it greys out and stops taking clicks, no extra texture needed.
		button:SetEnabled(id ~= currentView)
	end
end

local function selectView(id)
	currentView = id
	highlightActive()
	render()
end

local BUTTON_LABEL = {
	state = "State",
	layers = "Layers",
	channels = "Channels",
	log = "Log",
	modules = "Modules",
	schema = "Schema",
}

local previous
for _, id in ipairs(viewOrder) do
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(94, 22)
	button:SetText(BUTTON_LABEL[id])
	if previous then
		button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
	else
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -48)
	end
	button:SetScript("OnClick", function()
		selectView(id)
	end)
	buttons[id] = button
	previous = button
end

---------------------------------------------------------------------------
-- Live toggle
---------------------------------------------------------------------------

-- The reason this file exists. Off by default: a window that re-renders forever in the
-- background is not what someone wants left open after they have finished looking.
local live = false

local liveCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
liveCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -74)
liveCheck:SetSize(22, 22)

local liveLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
liveLabel:SetPoint("LEFT", liveCheck, "RIGHT", 2, 0)
liveLabel:SetText("Live")

local liveHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
liveHint:SetPoint("LEFT", liveLabel, "RIGHT", 10, 0)
liveHint:SetText("re-reads 10x a second — watch a hold decay instead of sampling it")

liveCheck:SetScript("OnClick", function(self)
	live = self:GetChecked() and true or false
	render()
end)

---------------------------------------------------------------------------
-- Interactive action buttons (instant motor and decay testing)
---------------------------------------------------------------------------

local function attachTooltip(widget, text)
	widget:SetScript("OnEnter", function(self)
		if _G.GameTooltip then
			_G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
			_G.GameTooltip:SetText(text, 1, 1, 1)
			_G.GameTooltip:Show()
		end
	end)
	widget:SetScript("OnLeave", function()
		if _G.GameTooltip then
			_G.GameTooltip:Hide()
		end
	end)
end

local btnStop = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnStop:SetSize(66, 20)
btnStop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -74)
btnStop:SetText("Stop All")
btnStop:SetScript("OnClick", function()
	local P = core()
	if P and P.Engine then
		if type(P.Engine.StopAll) == "function" then
			P.Engine:StopAll()
		end
		if type(P.Engine.CancelAll) == "function" then
			P.Engine:CancelAll()
		end
	end
	render()
end)
attachTooltip(btnStop, "Emergency silence: stop all active vibration pulses and held layers")

local btnThud = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnThud:SetSize(46, 20)
btnThud:SetPoint("RIGHT", btnStop, "LEFT", -4, 0)
btnThud:SetText("Thud")
btnThud:SetScript("OnClick", function()
	local P = core()
	if P and type(P.PlayMode) == "function" then
		P:PlayMode("THUD")
	elseif P and type(P.Fire) == "function" then
		P:Fire("pdebug_thud", "Both", 0.8)
	end
	render()
end)
attachTooltip(btnThud, "Play heavy 40ms THUD transient")

local btnTick = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnTick:SetSize(42, 20)
btnTick:SetPoint("RIGHT", btnThud, "LEFT", -4, 0)
btnTick:SetText("Tick")
btnTick:SetScript("OnClick", function()
	local P = core()
	if P and type(P.PlayMode) == "function" then
		P:PlayMode("TICK")
	elseif P and type(P.Fire) == "function" then
		P:Fire("pdebug_tick", "Both", 0.5)
	end
	render()
end)
attachTooltip(btnTick, "Play sharp 12ms TICK transient")

local btnHold = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnHold:SetSize(62, 20)
btnHold:SetPoint("RIGHT", btnTick, "LEFT", -4, 0)
btnHold:SetText("Hold 2s")
btnHold:SetScript("OnClick", function()
	local P = core()
	if P and P.Engine and type(P.Engine.HoldLayer) == "function" then
		P.Engine:HoldLayer("debug_hold", 0.6, 0.6, 2.0)
	elseif P and type(P.Hold) == "function" then
		P:Hold("debug_hold", 0.6, 0.6, 2.0)
	end
	render()
end)
attachTooltip(btnHold, "Hold both motors at 60% for 2s (decay visible in Live view)")

local btnClear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnClear:SetSize(46, 20)
btnClear:SetPoint("RIGHT", btnHold, "LEFT", -4, 0)
btnClear:SetText("Clear")
btnClear:SetScript("OnClick", function()
	wipe(eventLog)
	wipe(channelPeaks)
	wipe(lastFiredEvents)
	if updateStickyHud then
		updateStickyHud()
	end
	render()
end)
attachTooltip(btnClear, "Clear rolling event log, sticky HUD, and channel peaks")

local elapsedSinceRender = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	if not live then
		return
	end
	elapsedSinceRender = elapsedSinceRender + elapsed
	if elapsedSinceRender < REFRESH_RATE then
		return
	end
	elapsedSinceRender = 0
	render()
end)

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------

local function Toggle()
	if frame:IsShown() then
		frame:Hide()
		return
	end
	highlightActive()
	render()
	frame:Show()
end

-- Hook early if Pulse is already available
if core() then
	ensureHooks()
end

-- Debug.lua's `commands` table is a local, so the slash command there resolves this at call
-- time through the global rather than the two files sharing a namespace.
_G.PulseDebugUI = {
	Toggle = Toggle,
	Show = function(view)
		if view and views[view] then
			currentView = view
		end
		highlightActive()
		render()
		frame:Show()
	end,
	ClearLog = function()
		wipe(eventLog)
		wipe(lastFiredEvents)
		if updateStickyHud then
			updateStickyHud()
		end
		render()
	end,
	ResetPeaks = function()
		wipe(channelPeaks)
		render()
	end,
	RecordEvent = recordEvent,
}

SLASH_PULSEDEBUGUI1 = "/pdui"
SlashCmdList["PULSEDEBUGUI"] = function()
	Toggle()
end
