-- PulseComic — UI/ProfilesPage.lua
--
-- The Profiles tab. Profiles are account-wide; this character uses one of them or follows
-- the account default. New, copy, rename, delete and reset act on the profile in use;
-- export puts a string in the box to copy, import adds the pasted profile(s) beside the
-- existing ones (never over them).

local _, ns = ...

local ACCOUNT = "__account__" -- "follow the account default" in the character dropdown
local DELETE_CONFIRM = 4 -- seconds to click Delete a second time

local nameText = "" -- the Name box: new, copy, rename, import
local themeChoice = "tactical"
local pendingTheme, pendingThemeAt
local boxText = "" -- the export / import box
local status = ""
local pendingDelete, pendingDeleteAt

local function P()
	return ns.profiles
end

local function Status(text)
	status = text
	ns.ui.Refresh()
end

local function NamesDropdown(label, tooltip, get, set, withAccount)
	local function text(value)
		if value == ACCOUNT then
			return "Account default (" .. P():DefaultName() .. ")"
		end
		return value
	end
	return {
		type = "dropdown",
		label = label,
		tooltip = tooltip,
		get = get,
		set = set,
		text = text,
		build = function(root, isSelected, setSelected)
			if withAccount then
				root:CreateRadio(text(ACCOUNT), isSelected, setSelected, ACCOUNT)
			end
			for _, name in ipairs(P():Names()) do
				root:CreateRadio(name, isSelected, setSelected, name)
			end
		end,
	}
end

local function Specs()
	return {
		{ type = "header", label = "Profiles" },
		{
			type = "note",
			textFunc = function()
				return "In use: " .. P():ActiveName() .. (P():HasCharacterChoice() and "  (chosen for this character)" or "  (the account default)")
			end,
		},
		NamesDropdown(
			"This character uses",
			"Each character can use its own profile or follow the account default.",
			function()
				return P():HasCharacterChoice() and P():ActiveName() or ACCOUNT
			end,
			function(value)
				P():Use(value ~= ACCOUNT and value or nil)
				Status("this character now uses " .. P():ActiveName())
			end,
			true
		),
		NamesDropdown("Account default", "The profile every character without its own choice uses.", function()
			return P():DefaultName()
		end, function(value)
			P():SetDefault(value)
			Status("account default is now " .. value)
		end),
		{
			type = "edit",
			label = "Name",
			tooltip = "Name for New, Copy, Rename and Import.",
			get = function()
				return nameText
			end,
			set = function(text)
				nameText = text
			end,
			maxLetters = 40,
		},
		{
			type = "buttons",
			label = "",
			buttons = {
				{
					"New",
					function()
						local name, err = P():Create(nameText)
						if name then
							P():Use(name)
							Status("created " .. name .. " from defaults; this character uses it")
						else
							Status(err)
						end
					end,
				},
				{
					"Copy",
					function()
						local name, err = P():Create(nameText, P():ActiveName())
						if name then
							P():Use(name)
							Status("copied to " .. name .. "; this character uses it")
						else
							Status(err)
						end
					end,
				},
			},
		},
		{
			type = "buttons",
			label = "",
			buttons = {
				{
					"Rename",
					function()
						local name, err = P():Rename(P():ActiveName(), nameText)
						Status(name and ("renamed to " .. name) or err)
					end,
				},
				{
					"Delete",
					function()
						local name = P():ActiveName()
						if pendingDelete == name and GetTime() - pendingDeleteAt <= DELETE_CONFIRM then
							pendingDelete = nil
							local ok, err = P():Delete(name)
							Status(ok and ("deleted " .. name) or err)
						else
							pendingDelete, pendingDeleteAt = name, GetTime()
							Status("click Delete again within " .. DELETE_CONFIRM .. " seconds to delete " .. name)
						end
					end,
				},
				{
					"Reset",
					function()
						local name = P():ActiveName()
						P():Reset(name)
						Status(name .. " reset to defaults")
					end,
				},
			},
		},
		{
			type = "note",
			textFunc = function()
				return status
			end,
		},

		{ type = "header", label = "Themes" },
		{
			type = "dropdown",
			label = "Theme",
			tooltip = "A ready-made look for every event. Themes use their own art where it exists and title text where it does not yet.",
			get = function()
				return themeChoice
			end,
			set = function(value)
				themeChoice = value
			end,
			text = function(value)
				local theme = ns.themes.Get(value)
				return theme and theme.label or value
			end,
			build = function(root, isSelected, setSelected)
				for _, theme in ipairs(ns.themes.LIST) do
					root:CreateRadio(theme.label, isSelected, setSelected, theme.id)
				end
			end,
		},
		{
			type = "note",
			textFunc = function()
				local theme = ns.themes.Get(themeChoice)
				return theme and theme.description or ""
			end,
		},
		{
			type = "buttons",
			label = "",
			buttons = {
				{
					"New from theme",
					function()
						local name, err = P():CreateFromTheme(nameText, themeChoice)
						if name then
							P():Use(name)
							Status("created " .. name .. "; this character uses it")
						else
							Status(err)
						end
					end,
				},
				{
					"Apply here",
					function()
						local name = P():ActiveName()
						local label = ns.themes.Get(themeChoice).label
						if pendingTheme == themeChoice and GetTime() - pendingThemeAt <= DELETE_CONFIRM then
							pendingTheme = nil
							P():ApplyTheme(name, themeChoice)
							Status(label .. " applied to " .. name)
						else
							pendingTheme, pendingThemeAt = themeChoice, GetTime()
							Status("click Apply here again to replace every event look in " .. name .. " with " .. label)
						end
					end,
				},
			},
		},

		{ type = "column" },
		{ type = "header", label = "Export / import" },
		{
			type = "buttons",
			label = "",
			buttons = {
				{
					"Export this",
					function()
						boxText = P():Export(P():ActiveName()) or ""
						Status("exported " .. P():ActiveName() .. ": click the box, Ctrl+A, Ctrl+C")
					end,
				},
				{
					"Export all",
					function()
						boxText = P():ExportAll()
						Status("exported every profile: click the box, Ctrl+A, Ctrl+C")
					end,
				},
			},
		},
		{
			type = "edit",
			label = "String",
			tooltip = "Exports appear here. To import, paste a PCOMIC1: string here.",
			get = function()
				return boxText
			end,
			set = function(text)
				boxText = text
			end,
			maxLetters = 0,
		},
		{ type = "note", label = "Import adds profiles beside yours; a single profile takes the Name on the left if set." },
		{
			type = "buttons",
			label = "",
			buttons = {
				{
					"Import",
					function()
						local added, err = P():Import(boxText, nameText ~= "" and nameText or nil)
						if added then
							Status("imported " .. table.concat(added, ", "))
						else
							Status("import failed: " .. tostring(err))
						end
					end,
				},
			},
		},
	}
end

ns.ui.pages.profiles = {
	label = "Profiles",
	order = 3,
	Build = function(parent)
		local rows, height = ns.ui.BuildColumns(parent, Specs())
		return {
			height = height,
			Refresh = function()
				for _, row in ipairs(rows) do
					row:RefreshValue()
				end
			end,
		}
	end,
}
