-- Offline smoke test for Pulse's custom settings panel.
--
-- Loads the real Core files and the new UI/Panel tree against a stub WoW API, then builds
-- every page's row specs and exercises each row's get/set. This cannot prove the frames
-- look right, but it does prove the files load in TOC order, that every closure resolves,
-- and that no page builder errors on the real Registry data.

local ROOT = arg[1] or "."

-- ── Stub WoW API ──────────────────────────────────────────────────────────────

local frames = {}

-- Auto-stub only things that look like widget METHODS. A real frame returns nil for an
-- unset data field, and the panel code relies on that (`if row.MeasureHeight then`,
-- `if self.page then`), so handing back a no-op function for every unknown key would make
-- the harness lie about which branch runs.
local METHOD_PREFIXES = {
	"Set",
	"Get",
	"Is",
	"Has",
	"Can",
	"Enable",
	"Disable",
	"Register",
	"Unregister",
	"Clear",
	"Create",
	"Add",
	"Remove",
	"Show",
	"Hide",
	"Play",
	"Stop",
	"Start",
	"Update",
	"Desaturate",
	"Hook",
	"Raise",
	"Lower",
	"Click",
	"Init",
	"Release",
	"Mark",
	"Select",
	"Toggle",
	"Generate",
	"Insert",
	"Find",
	"Advance",
	"Scroll",
	"Calculate",
	"Pan",
}

-- Exact names, for real widget methods whose spelling does not start with one of the
-- verb prefixes. Kept exact rather than adding a prefix, because a prefix like
-- "Increment" would turn the FIELD control.IncrementButton into a function and silently
-- defeat the `if control.IncrementButton then` guard it is meant to test.
local METHOD_NAMES = {
	HighlightText = true,
	Finalize = true,
	ClearFocus = true,
}

local function looksLikeMethod(key)
	if type(key) ~= "string" then
		return false
	end
	if METHOD_NAMES[key] then
		return true
	end
	for _, prefix in ipairs(METHOD_PREFIXES) do
		if key:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local FrameMT = {}
FrameMT.__index = function(tbl, key)
	if not looksLikeMethod(key) then
		return nil
	end
	local fn = function(self, ...)
		return nil
	end
	rawset(tbl, key, fn)
	return fn
end

local function newFrame(frameType, name, parent, template)
	local f = setmetatable({}, FrameMT)
	f.__frameType = frameType
	f.__name = name
	f.__parent = parent
	f.__template = template
	f.__children = {}
	f.__shown = true
	rawset(f, "GetParent", function()
		return parent
	end)
	rawset(f, "GetChildren", function()
		return unpack(f.__children)
	end)
	rawset(f, "IsShown", function()
		return f.__shown
	end)
	rawset(f, "IsVisible", function()
		return f.__shown
	end)
	rawset(f, "Show", function()
		f.__shown = true
	end)
	rawset(f, "Hide", function()
		f.__shown = false
	end)
	rawset(f, "SetShown", function(_, v)
		f.__shown = v and true or false
	end)
	rawset(f, "GetWidth", function()
		return 620
	end)
	rawset(f, "GetHeight", function()
		return 26
	end)
	rawset(f, "GetStringHeight", function()
		return 30
	end)
	rawset(f, "IsObjectType", function(_, t)
		return frameType == t
	end)
	rawset(f, "SetScript", function(_, script, fn)
		f["__script_" .. script] = fn
	end)
	rawset(f, "GetScript", function(_, script)
		return f["__script_" .. script]
	end)
	rawset(f, "HookScript", function(_, script, fn)
		f["__hook_" .. script] = fn
	end)
	rawset(f, "CreateFontString", function()
		return newFrame("FontString")
	end)
	rawset(f, "CreateTexture", function()
		return newFrame("Texture")
	end)
	rawset(f, "GetText", function()
		return ""
	end)
	rawset(f, "GetChecked", function()
		return f.__checked
	end)
	rawset(f, "SetChecked", function(_, v)
		f.__checked = v
	end)
	rawset(f, "GetValue", function()
		return f.__value
	end)
	rawset(f, "SetValue", function(_, v)
		f.__value = v
	end)
	rawset(f, "IsEnabled", function()
		return true
	end)
	rawset(f, "GetFrameLevel", function()
		return 10
	end)
	rawset(f, "GetStringWidth", function()
		return 100
	end)
	rawset(f, "RegisterCallback", function() end)
	rawset(f, "Init", function() end)
	if parent and parent.__children then
		table.insert(parent.__children, f)
	end
	if frameType == "Frame" and template == "MinimalSliderWithSteppersTemplate" then
		f.Slider = newFrame("Slider", nil, f)
	end
	if template == "SettingsDropdownWithButtonsTemplate" then
		f.Dropdown = newFrame("DropdownButton", nil, f)
		rawset(f.Dropdown, "SetupMenu", function(_, generator)
			f.__generator = generator
		end)
		rawset(f.Dropdown, "IsMenuOpen", function()
			return false
		end)
	end
	if template == "SettingsFrameTemplate" then
		f.NineSlice = { Text = newFrame("FontString") }
		f.ClosePanelButton = newFrame("Button", nil, f)
	end
	if template == "SearchBoxTemplate" then
		f.Instructions = newFrame("FontString")
	end
	frames[#frames + 1] = f
	return f
end

function CreateFrame(frameType, name, parent, template)
	local f = newFrame(frameType, name, parent, template)
	if name then
		_G[name] = f
	end
	return f
end

UIParent = newFrame("Frame", "UIParent")

function Mixin(object, ...)
	for i = 1, select("#", ...) do
		for k, v in pairs((select(i, ...))) do
			object[k] = v
		end
	end
	return object
end

function CreateFromMixins(...)
	return Mixin({}, ...)
end

function GenerateClosure(fn, ...)
	local args = { ... }
	return function(...)
		return fn(unpack(args), ...)
	end
end

function EnumUtil_MakeEnum(...) end
EnumUtil = {
	MakeEnum = function(...)
		local t, i = {}, 1
		for _, name in ipairs({ ... }) do
			t[name] = i
			i = i + 1
		end
		return t
	end,
}

MinimalSliderWithSteppersMixin = {
	Label = EnumUtil.MakeEnum("Left", "Right", "Top", "Min", "Max"),
	Event = { OnValueChanged = "OnValueChanged" },
}

C_Timer = {
	After = function(_, fn) end,
	NewTimer = function()
		return { Cancel = function() end }
	end,
}
C_GamePad = {
	GetAllDeviceIDs = function()
		return {}
	end,
	GetDeviceMappedState = function()
		return nil
	end,
	SetVibration = function() end,
	GetDeviceRawState = function()
		return nil
	end,
	GetActiveDeviceID = function()
		return nil
	end,
	GetDeviceMappings = function()
		return {}
	end,
}
C_Spell = {
	IsCurrentSpell = function()
		return false
	end,
	GetSpellInfo = function()
		return nil
	end,
}
C_LossOfControl = {
	GetActiveLossOfControlDataCount = function()
		return 0
	end,
	GetActiveLossOfControlData = function()
		return nil
	end,
}
C_AddOns = {
	IsAddOnLoaded = function()
		return false
	end,
}
C_Map = {
	GetBestMapForUnit = function()
		return nil
	end,
}
C_UnitAuras = {
	GetAuraDataByIndex = function()
		return nil
	end,
}
C_Container = {}
Enum = Enum or {}
Enum.PlayerInteractionType = {
	TradePartner = 1,
	Gossip = 3,
	QuestGiver = 4,
	Merchant = 5,
	TaxiNode = 6,
	Trainer = 7,
	Banker = 8,
	GuildBanker = 10,
	Vendor = 12,
	MailInfo = 17,
	SpiritHealer = 18,
	AreaSpiritHealer = 19,
	Binder = 20,
	Auctioneer = 21,
	StableMaster = 22,
	VoidStorageBanker = 26,
	BlackMarketAuctioneer = 27,
	ProfessionsCraftingOrder = 58,
	Professions = 59,
	ProfessionsCustomerOrder = 60,
	CharacterBanker = 67,
	AccountBanker = 68,
	PetUntrainer = 80,
}
Enum.Profession = {
	FirstAid = 0,
	Blacksmithing = 1,
	Leatherworking = 2,
	Alchemy = 3,
	Herbalism = 4,
	Cooking = 5,
	Mining = 6,
	Tailoring = 7,
	Engineering = 8,
	Enchanting = 9,
	Fishing = 10,
	Skinning = 11,
	Jewelcrafting = 12,
	Inscription = 13,
	Archaeology = 14,
}
recipeProfession = Enum.Profession.Blacksmithing
C_TradeSkillUI = {
	GetProfessionInfoByRecipeID = function(_)
		return { profession = recipeProfession }
	end,
}
function GetProfessions()
	return 1, 2
end
function GetProfessionInfo(index)
	return "Blacksmithing", nil, 100, 300, 0, 0, 164
end
function UnitCastingInfo()
	return nil
end
C_Item = {}

Settings = {
	RegisterCanvasLayoutCategory = function(frame, name)
		return { ID = name, name = name, canvas = frame }
	end,
	RegisterAddOnCategory = function() end,
}
StaticPopupDialogs = {}
function StaticPopup_Show() end
SlashCmdList = {}
UISpecialFrames = {}
ACCEPT, CANCEL, OKAY, CLOSE, CUSTOM = "Accept", "Cancel", "Okay", "Close", "Custom"
NORMAL_FONT_COLOR = {
	r = 1,
	g = 0.82,
	b = 0,
	GetRGB = function(s)
		return 1, 0.82, 0
	end,
}
GRAY_FONT_COLOR = {
	r = 0.5,
	g = 0.5,
	b = 0.5,
	GetRGB = function(s)
		return 0.5, 0.5, 0.5
	end,
}
SOUNDKIT = {}
function PlaySound() end
function print(...)
	io.write("[print] ")
	local t = { ... }
	for i = 1, #t do
		io.write(tostring(t[i]), "\t")
	end
	io.write("\n")
end
function strtrim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
function strsplit(sep, str, limit)
	local s = tostring(str or "")
	if limit and limit == 2 then
		local pos = s:find(sep, 1, true)
		if pos then
			return s:sub(1, pos - 1), s:sub(pos + #sep)
		else
			return s
		end
	end
	local out = {}
	for part in s:gmatch("[^" .. sep .. "]+") do
		out[#out + 1] = part
	end
	return unpack(out)
end
function tinsert(t, v)
	table.insert(t, v)
end
function tremove(t, i)
	return table.remove(t, i)
end
function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end
function tContains(t, v)
	for _, x in ipairs(t) do
		if x == v then
			return true
		end
	end
	return false
end
function CopyTable(source, shallow)
	local out = {}
	for k, v in pairs(source) do
		if type(v) == "table" and not shallow then
			out[k] = CopyTable(v)
		else
			out[k] = v
		end
	end
	return out
end
specIndex, specId, specLabel = nil, 62, "Arcane"
function GetSpecialization()
	return specIndex
end
function GetSpecializationInfo(index)
	if not index then
		return nil
	end
	return specId, specLabel
end

inCombat = false
function InCombatLockdown()
	return inCombat
end

function CreateColor(r, g, b, a)
	return {
		r = r,
		g = g,
		b = b,
		a = a,
		GetRGB = function(s)
			return s.r, s.g, s.b
		end,
	}
end
local secretSentinel = {}
function issecretvalue(val)
	if val == secretSentinel then
		return true
	end
	if type(val) == "table" and rawget(val, "__is_secret") then
		return true
	end
	return false
end
function UnitExists()
	return true
end
function UnitCanAttack()
	return true
end
function UnitIsUnit()
	return false
end
function UnitCastingInfo()
	return nil
end
function UnitChannelInfo()
	return nil
end
function securecall(fn, ...)
	return fn(...)
end
function securecallfunction(fn, ...)
	return fn(...)
end
function GetRealmName()
	return "TestRealm"
end
function UnitName()
	return "Tester"
end
function GetTime()
	return 0
end
function GetBuildInfo()
	return "12.1.0", "00000", "date", 120100
end
function IsAddOnLoaded()
	return false
end
function GetLocale()
	return "enUS"
end
function date()
	return ""
end
unpack = unpack or table.unpack
loadstring = loadstring or load
if not math.log10 then
	math.log10 = function(x)
		return math.log(x, 10)
	end
end

_G = _G or _ENV

-- ── Load the addon ────────────────────────────────────────────────────────────

local ADDON_NAME = "Pulse"
local Pulse = {}

local FILES = {
	"Core/Init.lua",
	"Core/Database.lua",
	"Core/Modes.lua",
	"Core/Devices.lua",
	"Core/Waves.lua",
	"Core/Schemas/Standard.lua",
	"Core/Schemas/HighOnly.lua",
	"Core/Schemas/LowOnly.lua",
	"Core/Schemas/RumbleAndTriggers.lua",
	"Core/Schemas/TriggerEmphasis.lua",
	"Core/Schemas/Inverted.lua",
	"Core/Engine.lua",
	"Core/CastActivity.lua",
	"Core/Registry.lua",
	"Core/Guide.lua",
	"Modules/Crafting.lua",
	"Modules/Interaction.lua",
	"Modules/AlertUnitWatch.lua",
	"UI/Settings.lua",
	"UI/Panel/Theme.lua",
	"UI/Panel/Popup.lua",
	"UI/Panel/Rows.lua",
	"UI/Panel/Sidebar.lua",
	"UI/Panel/Gamepad.lua",
	"UI/Panel/Content.lua",
	"UI/Panel/Spec.lua",
	"UI/Panel/Panel.lua",
}

for _, relative in ipairs(FILES) do
	local path = ROOT .. "/" .. relative
	local chunk, err = loadfile(path)
	if not chunk then
		io.write("LOAD FAIL  " .. relative .. ": " .. tostring(err) .. "\n")
	else
		local ok, runErr = pcall(chunk, ADDON_NAME, Pulse)
		if not ok then
			io.write("RUN FAIL   " .. relative .. ": " .. tostring(runErr) .. "\n")
		else
			io.write("loaded     " .. relative .. "\n")
		end
	end
end

-- ── Exercise the spec ─────────────────────────────────────────────────────────

io.write("\n--- building pages ---\n")

local ok, err = pcall(function()
	Pulse.Database:Init()
end)
if not ok then
	io.write("Database:Init failed: " .. tostring(err) .. "\n")
end

local Spec = Pulse.UI.Panel.Spec
local pages = Spec.BuildPages()
io.write(("%d pages\n"):format(#pages))

local totalRows, controls, indexEntries, failures = 0, 0, 0, 0
for _, page in ipairs(pages) do
	local okBuild, specs = pcall(page.build)
	if not okBuild then
		io.write(("BUILD FAIL %-28s %s\n"):format(page.label, tostring(specs)))
		failures = failures + 1
	else
		totalRows = totalRows + #specs
		local kinds = {}
		for _, s in ipairs(specs) do
			kinds[s.kind] = (kinds[s.kind] or 0) + 1
			-- index rows navigate and report; they change nothing, so they are not
			-- controls and must not inflate the count the docs quote.
			if s.kind == "index" then
				indexEntries = indexEntries + 1
			elseif s.kind ~= "header" and s.kind ~= "text" then
				controls = controls + 1
			end

			-- Every getter and predicate must run without erroring.
			if s.get then
				local okGet, valOrErr = pcall(s.get)
				if not okGet then
					io.write(("GET FAIL   %-20s %-28s %s\n"):format(page.label, tostring(s.label), tostring(valOrErr)))
					failures = failures + 1
				end
			end
			if s.enabledWhen then
				local okEn, e = pcall(s.enabledWhen)
				if not okEn then
					io.write(("GATE FAIL  %-20s %-28s %s\n"):format(page.label, tostring(s.label), tostring(e)))
					failures = failures + 1
				end
			end
			if s.visibleWhen then
				local okVis, e = pcall(s.visibleWhen)
				if not okVis then
					io.write(("VIS FAIL   %-20s %-28s %s\n"):format(page.label, tostring(s.label), tostring(e)))
					failures = failures + 1
				end
			end
			if s.options then
				local okOpt, opts = pcall(s.options)
				if not okOpt then
					io.write(("OPT FAIL   %-20s %-28s %s\n"):format(page.label, tostring(s.label), tostring(opts)))
					failures = failures + 1
				elseif #opts == 0 then
					io.write(("OPT EMPTY  %-20s %s\n"):format(page.label, tostring(s.label)))
				end
			end
			if s.kind == "slider" then
				if type(s.min) ~= "number" or type(s.max) ~= "number" or type(s.step) ~= "number" then
					io.write(
						("SLIDER BAD %-20s %-28s min=%s max=%s step=%s\n"):format(
							page.label,
							tostring(s.label),
							tostring(s.min),
							tostring(s.max),
							tostring(s.step)
						)
					)
					failures = failures + 1
				elseif s.max <= s.min then
					io.write(
						("SLIDER RNG %-20s %-28s min=%s max=%s\n"):format(
							page.label,
							tostring(s.label),
							tostring(s.min),
							tostring(s.max)
						)
					)
					failures = failures + 1
				end
			end
			if s.kind == "button" and type(s.onClick) ~= "function" then
				io.write(("BUTTON BAD %-20s %s\n"):format(page.label, tostring(s.label)))
				failures = failures + 1
			end
		end
		local parts = {}
		for kind, count in pairs(kinds) do
			parts[#parts + 1] = kind .. "=" .. count
		end
		table.sort(parts)
		io.write(("%-34s %4d rows   %s\n"):format(page.label, #specs, table.concat(parts, " ")))
	end
end

io.write(("\ntotal rows %d, of which controls %d and index entries %d\n"):format(totalRows, controls, indexEntries))

-- ── Build the real window and walk every page ─────────────────────────────────

io.write("\n--- building the window ---\n")

local PanelModule = Pulse.UI.Panel
local okWin, winOrErr = pcall(PanelModule.EnsureBuilt)
if not okWin or not winOrErr then
	io.write("EnsureBuilt failed: " .. tostring(winOrErr) .. "\n")
	failures = failures + 1
else
	local window = winOrErr
	io.write("window built\n")

	local builtRows = 0
	for _, page in ipairs(window.pageList) do
		local okSel, selErr = pcall(window.Sidebar.Select, window.Sidebar, page)
		if not okSel then
			io.write(("SELECT FAIL %-30s %s\n"):format(page.label, tostring(selErr)))
			failures = failures + 1
		else
			builtRows = builtRows + (page.rows and #page.rows or 0)

			if (page.skippedRows or 0) > 0 then
				io.write(("ROW DROPPED %-28s %d spec(s) failed to build\n"):format(page.label, page.skippedRows))
				failures = failures + 1
			end

			-- Round-trip every value through its own setter: read it, write the same
			-- thing back, read it again. Catches a getter and setter that disagree about
			-- units or type, which is the failure the two panels sharing one store would
			-- otherwise hide until something was saved wrong.
			for _, row in ipairs(page.rows or {}) do
				local spec = row.spec
				if spec and spec.get and spec.set then
					local okGet, value = pcall(spec.get)
					if okGet then
						local okSet, setErr = pcall(spec.set, value)
						if not okSet then
							io.write(
								("SET FAIL   %-20s %-28s %s\n"):format(
									page.label,
									tostring(spec.label),
									tostring(setErr)
								)
							)
							failures = failures + 1
						else
							local okAfter, after = pcall(spec.get)
							if
								okAfter
								and type(value) == "number"
								and type(after) == "number"
								and math.abs(after - value) > 0.0001
							then
								io.write(
									("ROUNDTRIP  %-20s %-28s %s -> %s\n"):format(
										page.label,
										tostring(spec.label),
										tostring(value),
										tostring(after)
									)
								)
								failures = failures + 1
							end
						end
					end
				end
				if row.RefreshValue then
					local okRef, refErr = pcall(row.RefreshValue)
					if not okRef then
						io.write(
							("REFRESH    %-20s %-28s %s\n"):format(
								page.label,
								tostring(spec and spec.label),
								tostring(refErr)
							)
						)
						failures = failures + 1
					end
				end
			end

			local okLayout, layoutErr = pcall(window.Content.LayoutRows, window.Content)
			if not okLayout then
				io.write(("LAYOUT FAIL %-30s %s\n"):format(page.label, tostring(layoutErr)))
				failures = failures + 1
			end
		end
	end
	io.write(("built %d row frames across %d pages\n"):format(builtRows, #window.pageList))

	-- The cue index is only worth having if its lines actually navigate. Click every one
	-- and check the window ends up somewhere, since Panel.GoToPage is resolved at click
	-- time from a file that loads after the one declaring the closure.
	local indexPage
	for _, page in ipairs(window.pageList) do
		if page.id == "cueIndex" then
			indexPage = page
		end
	end
	if not indexPage then
		io.write("INDEX MISSING: no cueIndex page\n")
		failures = failures + 1
	else
		window.Sidebar:Select(indexPage)
		local clicked, landed = 0, 0
		for _, row in ipairs(indexPage.rows or {}) do
			if row.spec and row.spec.kind == "index" then
				clicked = clicked + 1
				local okClick, clickErr = pcall(row.spec.onClick)
				if not okClick then
					io.write(("INDEX CLICK %-28s %s\n"):format(tostring(row.spec.label), tostring(clickErr)))
					failures = failures + 1
				elseif window.Content.page and window.Content.page ~= indexPage then
					landed = landed + 1
				end
				window.Sidebar:Select(indexPage)
			end
		end
		io.write(("cue index: %d entries, %d navigated\n"):format(clicked, landed))
		if clicked == 0 or landed ~= clicked then
			failures = failures + 1
		end
	end

	-- Filtering, and the dependency pass.
	local okFilter, filterErr = pcall(window.Content.SetFilter, window.Content, "intensity")
	if not okFilter then
		io.write("FILTER FAIL: " .. tostring(filterErr) .. "\n")
		failures = failures + 1
	end
	pcall(window.Content.SetFilter, window.Content, "")

	local okRefresh, refreshErr = pcall(window.Content.RefreshRows, window.Content)
	if not okRefresh then
		io.write("REFRESH FAIL: " .. tostring(refreshErr) .. "\n")
		failures = failures + 1
	end

	-- Master switch off must grey the cue rows, and back on must restore them.
	-- By id, not by position: the cue index was inserted at position 2 and index rows
	-- carry no dependency, so a positional pick would silently assert nothing.
	local combatPage
	for _, page in ipairs(window.pageList) do
		if page.id == "COMBAT" then
			combatPage = page
		end
	end
	assert(combatPage, "harness: no COMBAT page to test dependencies against")

	Pulse.Database:Set("masterEnabled", false)
	window.Sidebar:Select(combatPage)
	window.Content:RefreshRows()
	local greyed, total = 0, 0
	for _, row in ipairs(window.Content.page.rows) do
		if row.spec and row.spec.enabledWhen then
			total = total + 1
			if row.lastEnabled == false then
				greyed = greyed + 1
			end
		end
	end
	io.write(("master off: %d/%d dependent rows greyed\n"):format(greyed, total))
	if total > 0 and greyed ~= total then
		failures = failures + 1
	end

	Pulse.Database:Set("masterEnabled", true)
	window.Content:RefreshRows()
	local live = 0
	for _, row in ipairs(window.Content.page.rows) do
		if row.spec and row.spec.enabledWhen and row.lastEnabled then
			live = live + 1
		end
	end
	io.write(("master on: %d/%d dependent rows live\n"):format(live, total))
end

io.write("\n--- welcome page ---\n")
local okWelcome, welcomeErr = pcall(Pulse.UI.Settings.Build, Pulse.UI.Settings)
if not okWelcome then
	io.write("Settings:Build failed: " .. tostring(welcomeErr) .. "\n")
	failures = failures + 1
else
	io.write(
		"welcome page built, category = "
			.. tostring(Pulse.UI.Settings.category and Pulse.UI.Settings.category.ID)
			.. "\n"
	)
end

io.write("\n--- owned dropdown and dialogs ---\n")
do
	local Popup = Pulse.UI.Panel.Popup

	local function check(label, got, want)
		local ok = (got == want)
		if not ok then
			failures = failures + 1
		end
		io.write(("%-46s %-14s %s\n"):format(label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
	end

	-- No dropdown row may still be wired to Blizzard's Menu system. SetupMenu is the one
	-- call that reaches the protected binding path, so its absence is the whole fix and
	-- is worth asserting rather than trusting.
	local setupMenuCalls = 0
	local window = Pulse.UI.Panel.EnsureBuilt()
	local dropdowns, wired = 0, 0
	for _, page in ipairs(window.pageList) do
		window.Sidebar:Select(page)
		for _, row in ipairs(page.rows or {}) do
			if row.spec and row.spec.kind == "dropdown" and row.Dropdown then
				dropdowns = dropdowns + 1
				if row.Dropdown.__generator ~= nil then
					wired = wired + 1
				end
			end
		end
	end
	check("dropdown rows found", dropdowns > 0, true)
	check("none wired to Blizzard's menu", wired, 0)

	-- The owned list opens, reports, and selects.
	local picked
	local owner = CreateFrame("Frame", nil, UIParent)
	Popup.OpenList(
		owner,
		{
			{ value = "a", label = "Alpha" },
			{ value = "b", label = "Beta" },
		},
		"a",
		function(v)
			picked = v
		end
	)
	check("list opens", Popup.IsListOpen(), true)
	Popup.CloseList()
	check("list closes", Popup.IsListOpen(), false)

	-- Multi-column categorized palette opens for modes and triggers
	local palettePicked
	local modeOptions = {
		{ value = "TAP", label = "TAP", category = "Snappy & Taps" },
		{ value = "THUD", label = "THUD", category = "Heavy Impacts" },
		{ value = "TRIGGER_CLICK", label = "TRIGGER_CLICK", category = "Triggers & Textures" },
	}
	Popup.OpenList(owner, modeOptions, "THUD", function(v)
		palettePicked = v
	end)
	check("multi-column palette opens", Popup.IsListOpen(), true)
	Popup.CloseList()
	check("multi-column palette closes", Popup.IsListOpen(), false)

	-- Dialogs run their accept handler with the typed value.
	local confirmed = false
	Popup.Confirm("Delete it?", "Delete", function()
		confirmed = true
	end)
	local dialogFrame = _G["PulsePanelDialog"]
	check("confirm dialog exists", dialogFrame ~= nil, true)
	if dialogFrame then
		dialogFrame.accepted()
		check("confirm ran its handler", confirmed, true)
	end

	local typed
	Popup.Prompt("Name it:", "Raiding copy", "Copy", function(v)
		typed = v
	end)
	if dialogFrame then
		dialogFrame.accepted()
		check("prompt ran its handler", typed ~= nil, true)
	end
end

io.write("\n--- profile system ---\n")
do
	local db = Pulse.Database
	local SPEC, CHAR, ACCT = db.SCOPE_SPEC, db.SCOPE_CHARACTER, db.SCOPE_ACCOUNT

	local notifies = 0
	db:OnCueChanged("combatEnter", function()
		notifies = notifies + 1
	end)

	local function check(label, got, want)
		local ok = (got == want)
		if not ok then
			failures = failures + 1
		end
		io.write(("%-46s %-14s %s\n"):format(label, tostring(got), ok and "ok" or ("FAIL want " .. tostring(want))))
	end

	local function scopeOf()
		local scope = db:GetProfileResolution()
		return scope
	end

	-- Start from nothing.
	db:ClearProfileForScope(SPEC)
	db:ClearProfileForScope(CHAR)
	db:ClearProfileForScope(ACCT)
	specIndex = nil
	check("no rules -> Default", db:GetActiveProfileName(), "Default")
	check("no rules -> no scope", scopeOf(), nil)

	db:SetProfileForScope(ACCT, "Raiding")
	check("account rule wins when alone", db:GetActiveProfileName(), "Raiding")
	check("  scope reported", scopeOf(), ACCT)

	db:SetProfileForScope(CHAR, "Questing")
	check("character beats account", db:GetActiveProfileName(), "Questing")
	check("  scope reported", scopeOf(), CHAR)

	-- No specialization: a spec rule cannot be set and cannot win.
	local okSpec, reason = db:SetProfileForScope(SPEC, "PvP")
	check("spec rule refused without a spec", okSpec, false)
	check("  and says why", reason, "this character has no specialization")

	-- Now give the character one.
	specIndex = 1
	db:SetProfileForScope(SPEC, "PvP")
	check("spec beats character", db:GetActiveProfileName(), "PvP")
	check("  scope reported", scopeOf(), SPEC)

	-- Changing spec with no rule for the new one falls back down the chain.
	specId, specLabel = 63, "Fire"
	check("different spec falls to character", db:GetActiveProfileName(), "Questing")
	specId, specLabel = 62, "Arcane"
	check("back to the ruled spec", db:GetActiveProfileName(), "PvP")

	db:ClearProfileForScope(SPEC)
	check("clearing spec falls to character", db:GetActiveProfileName(), "Questing")
	db:ClearProfileForScope(CHAR)
	check("clearing character falls to account", db:GetActiveProfileName(), "Raiding")

	-- Copy seeds from the source and switches to it.
	local okDup = db:DuplicateProfile("Raiding", "Raiding quiet")
	check("duplicate succeeds", okDup, true)
	check("  and becomes active", db:GetActiveProfileName(), "Raiding quiet")
	local found = false
	for _, n in ipairs(db:GetProfileNames()) do
		if n == "Raiding quiet" then
			found = true
		end
	end
	check("  and is listed", found, true)

	-- Rules follow a rename through every scope.
	db:SetProfileForScope(SPEC, "Raiding quiet")
	db:RenameProfile("Raiding quiet", "Quiet")
	check("rename follows the spec rule", db:GetProfileRule(SPEC), "Quiet")
	check("  and stays active", db:GetActiveProfileName(), "Quiet")

	-- Delete clears rules rather than repointing them.
	db:SetProfileForScope(CHAR, "Quiet")
	db:DeleteProfile("Quiet")
	check("delete clears the spec rule", db:GetProfileRule(SPEC), nil)
	check("delete clears the character rule", db:GetProfileRule(CHAR), nil)
	check("  and falls through to account", db:GetActiveProfileName(), "Raiding")

	-- Combat defers the re-registration, not the decision.
	specIndex = nil
	inCombat = true
	notifies = 0
	db:SetProfileForScope(CHAR, "Questing")
	check("in combat: rule applies at once", db:GetActiveProfileName(), "Questing")
	check("in combat: listeners not fired", notifies, 0)
	check("in combat: switch is pending", db:HasPendingProfileSwitch(), true)
	inCombat = false
	db:FlushPendingProfileSwitch()
	check("out of combat: listeners fired", notifies > 0, true)
	db:ClearProfileForScope(CHAR)
	db:ClearProfileForScope(ACCT)

	-- New Curated Default Profiles & Metadata
	check("Dungeon: Tank is built-in", db:IsBuiltinProfile("Dungeon: Tank"), true)
	check("Dungeon: Healer is built-in", db:IsBuiltinProfile("Dungeon: Healer"), true)
	check("Immersion: Melee is built-in", db:IsBuiltinProfile("Immersion: Melee"), true)
	check("Immersion: Caster is built-in", db:IsBuiltinProfile("Immersion: Caster"), true)

	local tankMeta = db:GetDefaultProfileMeta("Dungeon: Tank")
	check("tank metadata category", tankMeta and tankMeta.category, "dungeon")
	check("tank metadata intensity", tankMeta and tankMeta.intensity, 0.80)

	db:SetActiveProfileName("Dungeon: Tank")
	check("tank active", db:GetActiveProfileName(), "Dungeon: Tank")
	check("tank has threatLost", db:GetCue("threatLost"), true)
	check("tank silences weatherChanged", db:GetCue("weatherChanged"), false)

	db:SetActiveProfileName("Immersion: Melee")
	check("immersion melee active", db:GetActiveProfileName(), "Immersion: Melee")
	check("immersion melee has locomotion", db:GetCue("locomotion"), true)
	check("immersion melee has weatherChanged", db:GetCue("weatherChanged"), true)

	db:SetActiveProfileName("PvP")
	check("pvp active", db:GetActiveProfileName(), "PvP")
	check("pvp has ccMaster", db:GetCue("ccMaster"), true)
	check("pvp silences lootGold", db:GetCue("lootGold"), false)

	-- Slash command /pulse profile
	local slash = SlashCmdList["PULSE"]
	check("slash command PULSE exists", type(slash), "function")
	slash("profile")
	slash("profile Tank")
	check("slash profile Tank switches to Dungeon: Tank", db:GetActiveProfileName(), "Dungeon: Tank")
	slash("profile nonexistent_profile_xyz")
	check("slash profile nonexistent leaves current profile untouched", db:GetActiveProfileName(), "Dungeon: Tank")
	slash("profile Immersion: Caster")
	check("slash profile exact name matches", db:GetActiveProfileName(), "Immersion: Caster")

	-- Profiles page Rename/Delete disabled for built-ins
	local profilesPage = nil
	for _, p in ipairs(Pulse.UI.Panel.Spec.BuildPages()) do
		if p.id == "profiles" then
			profilesPage = p
			break
		end
	end
	check("profiles page exists", type(profilesPage), "table")
	local profRows = profilesPage.build()
	local renameRow, deleteRow = nil, nil
	for _, r in ipairs(profRows) do
		if r.label == "Rename this profile" then
			renameRow = r
		end
		if r.label == "Delete this profile" then
			deleteRow = r
		end
	end
	check("rename button found", type(renameRow), "table")
	check("delete button found", type(deleteRow), "table")
	check("rename disabled when built-in active", renameRow.enabledWhen(), false)
	check("delete disabled when built-in active", deleteRow.enabledWhen(), false)

	-- AlertUnitWatch UNIT_AURA secret value resilience
	local unitWatchMod = Pulse.modules["AlertUnitWatch"]
	check("AlertUnitWatch module registered", type(unitWatchMod), "table")
	if unitWatchMod then
		unitWatchMod:OnEnable()

		local secretAuras = setmetatable({ __is_secret = true }, {
			__ipairs = function()
				error("bad argument #1 to 'ipairs' (table expected, got secret)")
			end,
		})

		local firedCount = 0
		local origFire = Pulse.FireIfEnabled
		Pulse.FireIfEnabled = function(self, cueID)
			if cueID == "targetBigDefensive" then
				firedCount = firedCount + 1
			end
		end

		-- Secret table in addedAuras must NOT error
		local okAura, _ = pcall(function()
			for _, f in ipairs(frames) do
				local fn = f:GetScript("OnEvent")
				if fn then
					fn(f, "UNIT_AURA", "target", {
						addedAuras = secretAuras,
						isFullUpdate = true,
					})
				end
			end
		end)
		check("UNIT_AURA with secret addedAuras does not error", okAura, true)

		-- Entire updateInfo secret must NOT error
		local okSecInfo, _ = pcall(function()
			for _, f in ipairs(frames) do
				local fn = f:GetScript("OnEvent")
				if fn then
					fn(f, "UNIT_AURA", "target", secretAuras)
				end
			end
		end)
		check("UNIT_AURA with secret updateInfo does not error", okSecInfo, true)

		-- Malformed updateInfo (nil, boolean, string) must NOT error
		pcall(function()
			for _, f in ipairs(frames) do
				local fn = f:GetScript("OnEvent")
				if fn then
					fn(f, "UNIT_AURA", "target", nil)
					fn(f, "UNIT_AURA", "target", "unexpected_string")
				end
			end
		end)

		-- Valid big defensive should fire
		_G.C_UnitAuras = {
			AuraIsBigDefensive = function(spellID)
				return spellID == 871
			end,
		}
		for _, f in ipairs(frames) do
			local fn = f:GetScript("OnEvent")
			if fn then
				fn(f, "UNIT_AURA", "target", {
					addedAuras = {
						{ spellId = 871 },
					},
				})
			end
		end
		Pulse.FireIfEnabled = origFire
	end

	-- Engine Fine-Tunings: Watchdog, Dual-Lane Smoothing, Immersion Saturating Mixer
	local engineOnUpdate = nil
	for _, f in ipairs(frames) do
		local script = f:GetScript("OnUpdate")
		if script then
			engineOnUpdate = script
			break
		end
	end
	check("Engine OnUpdate frame script found", type(engineOnUpdate), "function")

	if engineOnUpdate then
		local setVibrationCalls = 0
		local lastSetChannel, lastSetVal = nil, nil
		C_GamePad.IsEnabled = function()
			return true
		end
		C_GamePad.GetActiveDeviceID = function()
			return 1
		end
		C_GamePad.SetVibration = function(channel, val)
			setVibrationCalls = setVibrationCalls + 1
			lastSetChannel = channel
			lastSetVal = val
		end

		Pulse.Database:Set("masterIntensity", 1.0)
		Pulse.Engine:RefreshDevice()
		check("Engine device is ready for test", Pulse.Engine:IsDeviceReady(), true)

		-- Test 1: Immersion-First Saturating Mixing
		-- Two continuous textures (0.30 and 0.20) combine to ~0.44, not max 0.30
		Pulse.Engine:Hold("waterAmbiance", 0.30, 0.30)
		Pulse.Engine:Hold("mountGallop", 0.20, 0.20)
		-- Step frames to allow continuous smoothing filter (75ms tau) to settle
		for _ = 1, 10 do
			engineOnUpdate(nil, 0.05)
		end
		check("Continuous textures merge via saturating sum", lastSetVal and lastSetVal > 0.40, true)

		-- Transient impact layers on top without ducking continuous texture (snaps via fast transient tau)
		Pulse.Engine:Set("impactThud", 0.50, 0.50, 0.05, true)
		engineOnUpdate(nil, 0.05)
		check("Transient layers on top of continuous baseline", lastSetVal and lastSetVal > 0.65, true)

		-- Let transient settle to steady state
		for _ = 1, 5 do
			engineOnUpdate(nil, 0.05)
		end

		-- Test 2: Output Transport Watchdog
		-- Once steady, next tick within 250ms does not trigger redundant SetVibration
		setVibrationCalls = 0
		engineOnUpdate(nil, 0.05)
		check("Steady vibration within 250ms does not re-send (epsilon gate)", setVibrationCalls, 0)

		-- Advance time past 250ms watchdog interval with unchanged steady input
		local origGetTime = GetTime
		local mockTime = origGetTime() + 0.35
		GetTime = function()
			return mockTime
		end
		engineOnUpdate(nil, 0.05)
		check("Steady vibration past 250ms triggers watchdog refresh", setVibrationCalls > 0, true)
		GetTime = origGetTime

		Pulse.Engine:StopAll()
	end
end

io.write("\n" .. (failures == 0 and "NO FAILURES\n" or ("FAILURES: " .. failures .. "\n")))
