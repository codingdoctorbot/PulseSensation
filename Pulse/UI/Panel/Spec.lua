-- Pulse — UI/Panel/Spec.lua
--
-- What the panel contains, as data. One function per page, each returning a flat array of
-- row specs in render order.
--
-- Ported control for control from the retired Blizzard-framework panel, with the framework
-- calls swapped for plain closures. Every setting keeps its exact variable, label, tooltip
-- and range, because the saved values did not migrate.
--
-- THREE THINGS CHANGED ON PURPOSE, each an improvement the new presentation makes possible
-- rather than a liberty taken:
--
--   1. Cross-page dependency is back on. Cue rows grey out under "Enable Pulse" and the
--      loss-of-control cues under ccMaster. The old panel had to switch that off
--      (PARENT_CUES_TO_MASTER = false), because Blizzard's IsParentInitializerInLayout
--      linearly scans the whole current layout for a parent that is on another page and
--      therefore never found — twice per element, on every refresh. Here a dependency is a
--      closure reading the database, so a cross-page parent costs the same as a same-page
--      one: nothing.
--
--   2. Indentation is real. Subordinate rows carry an actual 15px indent and the smaller
--      font, instead of three literal spaces glued onto the label because the indent never
--      rendered.
--
--   3. The two display toggles no longer need a /reload. "Show per-cue detail controls" and
--      "Show a Play button on every cue" hide and show rows that are already built rather
--      than deciding whether to register them, and their tooltips say so.

local ADDON_NAME, Pulse = ...

local Panel = Pulse.UI.Panel

local Spec = {}
Panel.Spec = Spec

local db = nil -- resolved at build time, not load time

local function database()
    db = db or Pulse.Database
    return db
end

-- ── Tooltip assembly ──────────────────────────────────────────────────────────

-- Plain-English phrasing for a throttle, shown only when it is long enough to shape
-- expectations: the sub-second de-spam throttles most triggers carry are invisible in
-- practice and only clutter the tooltip.
local NOTABLE_THROTTLE = 1.0

local function formatThrottle(seconds)
    if seconds >= 60 and seconds % 60 == 0 then
        local minutes = seconds / 60
        return minutes == 1 and "once a minute" or ("once every " .. minutes .. " minutes")
    end
    if seconds == math.floor(seconds) then
        return "once every " .. seconds .. " seconds"
    end
    return string.format("once every %.1f seconds", seconds)
end

-- Ordered for how a tooltip is read: what it is, what it feels like, what changes how often
-- you feel it, then whatever is worth a second thought before switching it on.
local function triggerTooltip(trigger)
    local parts = { trigger.desc }

    local mode = trigger.mode and Pulse.Modes[trigger.mode]
    if mode then
        parts[#parts + 1] = "Feels like: " .. mode.label
    elseif trigger.continuous then
        parts[#parts + 1] =
            "A continuous texture — a steady feeling for as long as it's happening, not a single pulse."
    end

    if trigger.throttle and trigger.throttle >= NOTABLE_THROTTLE then
        parts[#parts + 1] = "Fires at most " .. formatThrottle(trigger.throttle) .. "."
    end

    if trigger.caveat then
        parts[#parts + 1] = trigger.caveat
    end

    return table.concat(parts, "\n\n")
end

-- ── Dependency predicates ─────────────────────────────────────────────────────

local function masterOn()
    return database():Get("masterEnabled") and true or false
end

-- A cue is editable when the master switch is on and, if its category has a master cue of
-- its own (currently only ccMaster for ALERT_CC), that one is on too. The master lookup is
-- keyed on trigger.category, not on the page: a page can mix categories, and ccMaster must
-- keep gating only the loss-of-control cues.
local function cueGate(trigger)
    local masterID = Pulse.Registry.ALERT_CATEGORY_MASTER[trigger.category]
    if masterID and trigger.id ~= masterID then
        return function()
            return masterOn() and (database():GetCue(masterID) and true or false)
        end
    end
    return masterOn
end

-- A cue's subordinate rows need the cue itself switched on as well.
local function subordinateGate(trigger)
    local gate = cueGate(trigger)
    return function()
        return gate() and (database():GetCue(trigger.id) and true or false)
    end
end

local function advancedShown()
    return database():Get("showAdvancedCueControls") and true or false
end

local function testButtonsShown()
    return database():Get("showCueTestButtons") and true or false
end

-- ── Shared row factories ──────────────────────────────────────────────────────

local function modeOptions()
    local options = {}
    for _, modeID in ipairs(Pulse.ModeOrder) do
        local mode = Pulse.Modes[modeID]
        options[#options + 1] = { value = modeID, label = modeID, tooltip = mode and mode.label }
    end
    return options
end

local function cueCheckbox(trigger)
    return {
        kind = "checkbox",
        label = trigger.label,
        tooltip = triggerTooltip(trigger),
        get = function()
            return database():GetCue(trigger.id)
        end,
        set = function(value)
            database():SetCue(trigger.id, value)
        end,
        enabledWhen = cueGate(trigger),
    }
end

-- Every cue that plays something gets this, unconditionally. Not declared per trigger the
-- way a real tunable is: it is the generic "intensity" key Database:ApplyDefaults seeds,
-- not a bespoke dial one cue happens to need.
local function cueIntensitySlider(trigger)
    local default = trigger.defaultIntensity or 1.0
    return {
        kind = "slider",
        child = true,
        label = "Intensity",
        tooltip = "Scales this cue on top of the overall intensity on the Pulse page.",
        min = 0.0,
        max = 1.5,
        step = 0.05,
        get = function()
            return database():GetTriggerSetting(trigger.id, "intensity", default)
        end,
        set = function(value)
            database():SetTriggerSetting(trigger.id, "intensity", value, 0.0, 1.5)
        end,
        enabledWhen = subordinateGate(trigger),
        visibleWhen = advancedShown,
    }
end

-- Which preset shape a discrete trigger plays, overriding its Registry.lua `mode` default.
local function cueModeDropdown(trigger)
    return {
        kind = "dropdown",
        child = true,
        label = "Feels like",
        tooltip = 'Which of the preset shapes this specific cue plays when it fires. "'
            .. trigger.mode
            .. '" is recommended — pick a different one to change how just '
            .. 'this cue feels, without affecting anything else that also uses "'
            .. trigger.mode
            .. '".',
        options = modeOptions,
        get = function()
            return database():GetTriggerMode(trigger.id) or trigger.mode
        end,
        set = function(value)
            database():SetTriggerMode(trigger.id, value)
        end,
        enabledWhen = subordinateGate(trigger),
        visibleWhen = advancedShown,
    }
end

-- A bespoke dial or sub-option a specific cue declares (Registry.lua's `tunables`).
-- Booleans are stored as 0/1 in the same numeric store as the sliders, so a tunable can
-- change shape without moving its saved value.
local function tunableRow(trigger, tunable, opts)
    opts = opts or {}
    -- `x and nil or y` always yields y, so these two are spelled out. See the same note
    -- in cueTestButton below.
    local enabledWhen = nil
    if not opts.ungated then
        enabledWhen = subordinateGate(trigger)
    end

    local visibleWhen = nil
    if not opts.alwaysVisible then
        visibleWhen = advancedShown
    end

    if tunable.boolean then
        local default = tunable.default and 1 or 0
        return {
            kind = "checkbox",
            child = true,
            label = tunable.label,
            tooltip = tunable.desc or "",
            get = function()
                return database():GetTriggerSetting(trigger.id, tunable.key, default) == 1
            end,
            set = function(value)
                database():SetTriggerSetting(trigger.id, tunable.key, value and 1 or 0, 0, 1)
            end,
            enabledWhen = enabledWhen,
            visibleWhen = visibleWhen,
        }
    end

    return {
        kind = "slider",
        child = true,
        label = tunable.label,
        tooltip = tunable.desc or "",
        min = tunable.min,
        max = tunable.max,
        step = tunable.step,
        get = function()
            return database():GetTriggerSetting(trigger.id, tunable.key, tunable.default)
        end,
        set = function(value)
            database():SetTriggerSetting(trigger.id, tunable.key, value, tunable.min, tunable.max)
        end,
        enabledWhen = enabledWhen,
        visibleWhen = visibleWhen,
    }
end

-- The per-cue preview row. Deliberately NOT gated on the cue's own checkbox, because
-- Pulse:TestCue bypasses the enabled check on purpose: you should not have to switch a cue
-- on to find out what it feels like, and greying the button would contradict what pressing
-- it does.
local function cueTestButton(trigger, labelOverride, child)
    if not Pulse:CanTestCue(trigger.id) then
        return nil
    end

    local tooltip
    if trigger.continuous then
        tooltip = "Play a few seconds of this texture at its current intensity. A flat "
            .. "sample, not the real curve — the live version is shaped by speed, depth or "
            .. "cast progress, none of which exist in a settings panel."
    else
        tooltip = "Play this cue exactly as it is configured right now — its own intensity, "
            .. 'and its own "Feels like" shape if you changed it. Works whether or not the '
            .. "cue is switched on, and needs a connected controller."
    end

    -- An overridden label means the Continuous textures page is using this preview button
    -- as its group heading, where it always renders because it IS the heading. Written out
    -- rather than as `labelOverride and nil or testButtonsShown`, which reads the right way
    -- round and evaluates the wrong way: `x and nil` is nil and `nil or testButtonsShown`
    -- is testButtonsShown, so the heading would vanish with previews switched off.
    local visibleWhen = nil
    if labelOverride == nil then
        visibleWhen = testButtonsShown
    end

    if child == nil then
        child = (labelOverride == nil)
    end

    return {
        kind = "button",
        child = child,
        label = labelOverride or ("Feel " .. (trigger.label or trigger.id)),
        buttonText = "Play",
        tooltip = tooltip,
        onClick = function()
            local ok, reason = Pulse:TestCue(trigger.id)
            if not ok then
                print("Pulse: " .. reason .. ", so there is nothing to test.")
            end
        end,
        visibleWhen = visibleWhen,
    }
end

-- ── Dialogs ───────────────────────────────────────────────────────────────────
--
-- Pulse's own, not StaticPopup. StaticPopup_Show reaches HandlePopupShown ->
-- FrameControlsManager:FrameShown -> a protected binding call whenever gamepad UI is on,
-- the same wall the dropdowns hit (UI/Panel/Popup.lua).
--
-- Same dialogs, same wording, same two buttons. The accept button names the action rather
-- than saying "Okay": at the point of deleting a profile the button should say Delete.

local function confirm(text, acceptText, onAccept)
    Panel.Popup.Confirm(text, acceptText, onAccept)
end

local function prompt(text, default, acceptText, onAccept)
    Panel.Popup.Prompt(text, default, acceptText, onAccept)
end

local function report(ok, reason)
    if not ok and reason then
        print("Pulse: " .. reason)
    end
end

-- ── Root page ─────────────────────────────────────────────────────────────────

-- The old root page's order, control for control: master switch, profile picker and its
-- four buttons, overall intensity, the two display toggles, the schema, the mode tester,
-- debug logging, category masters last. No section headings, because the old page had
-- none — this rewrite preserves the organisation and leaves regrouping as a separate
-- decision from replacing the framework under it.
function Spec.BuildRootPage()
    local rows = {}
    local store = database()

    rows[#rows + 1] = {
        kind = "checkbox",
        label = "Enable Pulse",
        tooltip = "Master switch. With this off, nothing registers and nothing costs anything.",
        get = function()
            return store:Get("masterEnabled")
        end,
        set = function(value)
            store:Set("masterEnabled", value)
        end,
    }

    rows[#rows + 1] = {
        kind = "dropdown",
        label = "Profile",
        tooltip = "Which saved cue configuration is active on this character. Every cue's "
            .. "on/off, its intensity and its mode override belong to the profile picked "
            .. "here; the master switch, the schema and the calibration stay global.",
        options = function()
            local options = {}
            for _, name in ipairs(store:GetProfileNames()) do
                options[#options + 1] = { value = name, label = name }
            end
            return options
        end,
        get = function()
            return store:GetActiveProfileName()
        end,
        set = function(value)
            store:SetActiveProfileName(value)
        end,
    }

    -- Creating, copying, renaming, deleting and the automatic rules moved to the Profiles
    -- page on 2026-09-22. What stays is the one thing most people touch — which profile am
    -- I on — plus a line saying why, since with rules in play the dropdown alone no longer
    -- tells the whole story.
    rows[#rows + 1] = {
        kind = "text",
        child = true,
        font = "GameFontDisableSmall",
        gap = 6,
        body = function()
            local _, name, why = store:GetProfileResolution()
            local line = ('Using "%s" — set for %s.'):format(name, why)
            if store:HasPendingProfileSwitch() then
                line = line .. " Takes effect when you leave combat."
            end
            return line .. " Rules and management are on the Profiles page."
        end,
    }

    rows[#rows + 1] = {
        kind = "slider",
        label = "Overall intensity",
        tooltip = "Multiplies every trigger's intensity. Part of the current profile, not global.",
        min = 0.0,
        max = 1.0,
        step = 0.05,
        get = function()
            return store:Get("masterIntensity")
        end,
        set = function(value)
            store:Set("masterIntensity", value)
        end,
    }

    rows[#rows + 1] = {
        kind = "checkbox",
        label = "Show per-cue detail controls",
        tooltip = 'Adds each cue\'s own intensity slider, "Feels like" shape picker and any '
            .. "bespoke dials to its page. Off by default: a shorter list is easier to read "
            .. "when you just want to switch cues on and off. Takes effect immediately in "
            .. "this panel — no /reload needed.",
        get = function()
            return store:Get("showAdvancedCueControls")
        end,
        set = function(value)
            store:Set("showAdvancedCueControls", value)
        end,
    }

    rows[#rows + 1] = {
        kind = "checkbox",
        label = "Show a Play button on every cue",
        tooltip = "Adds a row under each cue that plays it, so you can find out what "
            .. "something feels like without waiting for it to happen. Useful while tuning, "
            .. "but it doubles the length of every page. The mode tester below still works "
            .. "either way. Takes effect immediately — no /reload needed.",
        get = function()
            return store:Get("showCueTestButtons")
        end,
        set = function(value)
            store:Set("showCueTestButtons", value)
        end,
    }

    rows[#rows + 1] = {
        kind = "dropdown",
        label = "Vibration schema",
        tooltip = "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.",
        options = function()
            local options = {}
            for _, schema in ipairs(Pulse.Registry:GetSchemaOptions()) do
                options[#options + 1] = { value = schema.id, label = schema.label, tooltip = schema.desc }
            end
            return options
        end,
        get = function()
            return store:Get("defaultHapticSchema")
        end,
        set = function(value)
            store:Set("defaultHapticSchema", value)
        end,
    }

    -- The mode tester's selection is panel state, not a saved preference, so it lives on
    -- the Spec table rather than in the database.
    Spec.testModeID = Spec.testModeID or Pulse.ModeOrder[1]

    rows[#rows + 1] = {
        kind = "dropdown",
        label = "Mode to test",
        tooltip = "Pick a mode to test below.",
        options = modeOptions,
        get = function()
            return Spec.testModeID
        end,
        set = function(value)
            Spec.testModeID = value
        end,
    }

    rows[#rows + 1] = {
        kind = "button",
        label = "Test the selected mode",
        buttonText = "Play it",
        tooltip = "There is no way to detect which motors a controller actually drives — "
            .. "pick a schema above, then play a few modes to find out.",
        onClick = function()
            local ok, reason = Pulse:TestMode(Spec.testModeID or Pulse.ModeOrder[1])
            if not ok then
                print("Pulse: " .. reason .. ", so there is nothing to test.")
            end
        end,
    }

    -- Backing store is the plain Pulse.debug variable (Core/Init.lua), not the database —
    -- a testing aid that resets on reload, not worth persisting across logins.
    rows[#rows + 1] = {
        kind = "checkbox",
        label = "Debug logging",
        tooltip = "Prints every option you change and every cue that actually fires to "
            .. "chat, in real time. Same as /pulse debug — off by default, and resets to "
            .. "off on /reload since it's a testing aid, not a saved preference.",
        get = function()
            return Pulse.debug
        end,
        set = function(value)
            Pulse.debug = value and true or false
            print(
                "Pulse: debug " .. (Pulse.debug and "ON — option changes and cue firings will print here." or "OFF")
            )
        end,
    }

    -- Category masters last, where the old panel appended them. ccMaster is the only one
    -- left, rendering next to "Enable Pulse" rather than inside the list it gates, so
    -- nothing has to be indented to show it is not a sibling of the cues below it.
    for _, categoryName in ipairs(Pulse.Registry:GetCategories()) do
        local masterTriggerID = Pulse.Registry.ALERT_CATEGORY_MASTER[categoryName]
        if masterTriggerID then
            local trigger = Pulse.Registry:GetTrigger(masterTriggerID)
            if trigger then
                rows[#rows + 1] = cueCheckbox(trigger)
            end
        end
    end

    return rows
end

-- ── Cue pages ─────────────────────────────────────────────────────────────────

-- One cue and everything that belongs to it: the checkbox, then its intensity, its mode
-- override, any bespoke tunables, and its preview button, as indented subordinate rows.
local function cueBlock(rows, trigger)
    rows[#rows + 1] = cueCheckbox(trigger)

    -- A gate-only trigger with neither a mode nor a texture (padDisconnected) has nothing
    -- to scale, so it gets no intensity dial.
    if trigger.mode or trigger.continuous then
        rows[#rows + 1] = cueIntensitySlider(trigger)
    end

    if trigger.mode then
        rows[#rows + 1] = cueModeDropdown(trigger)
    end

    -- Tunables marked devTuning render on the Continuous textures page instead, not
    -- doubled up here too.
    if trigger.tunables and not trigger.devTuning then
        for _, tunable in ipairs(trigger.tunables) do
            rows[#rows + 1] = tunableRow(trigger, tunable)
        end
    end

    local test = cueTestButton(trigger)
    if test then
        rows[#rows + 1] = test
    end
end

function Spec.BuildCuePage(page)
    local rows = {}
    for _, section in ipairs(page.sections) do
        if #section.triggers > 0 then
            rows[#rows + 1] = { kind = "header", label = section.label }
            for _, trigger in ipairs(section.triggers) do
                cueBlock(rows, trigger)
            end
        end
    end
    return rows
end

-- ── Cue index ─────────────────────────────────────────────────────────────────

-- Every cue in the addon on one page, alphabetically, each saying where its own controls
-- are and whether it is currently on. Clicking a line goes there.
--
-- WHY ALPHABETICAL AND NOT GROUPED. Grouped by page it would be the sidebar with extra
-- steps. Alphabetical is what the rest of the window cannot do: the pages are organised by
-- what a cue is ABOUT, the right way to browse and the wrong way to look something up —
-- "was the low-health heartbeat under Character or under Combat?" has no answer you can
-- reason your way to.
--
-- It also closes the search box's one real gap. Search is scoped to the page in view
-- (Content.lua says why), so searching THIS page searches every cue's name, description and
-- location at once: the cross-page search by another route, without building all 764
-- controls to do it.
--
-- Rows are `index`, not `button`: they change nothing, they report and they navigate. The
-- control counts quoted elsewhere deliberately exclude them.
function Spec.BuildCueIndexPage()
    local entries = {}

    for _, page in ipairs(Pulse.Registry:GetPages()) do
        if page.hasCues then
            for _, section in ipairs(page.sections) do
                for _, trigger in ipairs(section.triggers) do
                    entries[#entries + 1] = {
                        trigger = trigger,
                        pageID = page.id,
                        location = page.label .. "  ·  " .. section.label,
                    }
                end
            end
        end
    end

    -- A category master has no page of its own (Core/Registry.lua says why); it renders on
    -- the root page. Still a cue, so still in the index, pointing where it lives.
    for _, categoryName in ipairs(Pulse.Registry:GetCategories()) do
        local masterID = Pulse.Registry.ALERT_CATEGORY_MASTER[categoryName]
        local trigger = masterID and Pulse.Registry:GetTrigger(masterID)
        if trigger then
            entries[#entries + 1] = {
                trigger = trigger,
                pageID = "root",
                location = "Pulse",
            }
        end
    end

    -- Tie-broken on id so the order is stable, not merely sorted: two cues sharing a label
    -- would otherwise swap places between builds, and table.sort wants a strict ordering.
    table.sort(entries, function(a, b)
        local labelA = a.trigger.label or a.trigger.id
        local labelB = b.trigger.label or b.trigger.id
        if labelA == labelB then
            return a.trigger.id < b.trigger.id
        end
        return labelA < labelB
    end)

    -- Count cues per letter for section header labels
    local letterCounts = {}
    for _, entry in ipairs(entries) do
        local label = entry.trigger.label or entry.trigger.id
        local first = string.upper(string.sub(label, 1, 1))
        if not string.match(first, "^[A-Z]$") then
            first = "#"
        end
        letterCounts[first] = (letterCounts[first] or 0) + 1
    end

    local rows = {
        {
            kind = "text",
            font = "GameFontDisableSmall",
            gap = 10,
            body = ("Directory of all %d vibration cues in Pulse, in alphabetical order. Click any entry to jump directly to its controls."):format(
                #entries
            ),
        },
    }

    local currentLetter = nil
    for _, entry in ipairs(entries) do
        local trigger, pageID = entry.trigger, entry.pageID
        local label = trigger.label or trigger.id
        local first = string.upper(string.sub(label, 1, 1))
        if not string.match(first, "^[A-Z]$") then
            first = "#"
        end

        if first ~= currentLetter then
            currentLetter = first
            local count = letterCounts[currentLetter] or 1
            rows[#rows + 1] = {
                kind = "header",
                label = ("%s (%d)"):format(currentLetter, count),
            }
        end

        rows[#rows + 1] = {
            kind = "index",
            label = label,
            tooltip = triggerTooltip(trigger),
            location = entry.location,
            get = function()
                return database():GetCue(trigger.id)
            end,
            onClick = function()
                Panel.GoToPage(pageID)
            end,
        }
    end

    return rows
end

-- The spec row names the actual specialization rather than saying "specialization", so
-- the page reads as being about this character rather than about the feature.
local function child_label_spec(specName, specID)
    return specName and ("This specialization (" .. specName .. ")")
        or ("This specialization (" .. tostring(specID) .. ")")
end

-- ── Profiles ──────────────────────────────────────────────────────────────────

-- The profile system's own page: which profile is in force and why, the rules that decide
-- it, and everything that creates or destroys one.
--
-- WHAT A RULE IS. Three scopes, most specific first — this specialization, this character,
-- every character. Each one names a profile or names nothing. The first that names one
-- wins; the rest fall through. "No rule" everywhere means Default.
--
-- A scope holds a NAME, not its own copy of every setting, which is what lets five
-- characters point at one "Raiding" and have editing it once change it for all five. Why
-- it works that way is argued where the resolution lives — see "Which profile is active,
-- and why" in Core/Database.lua.
function Spec.BuildProfilesPage()
    local rows = {}
    local store = database()

    local function profileOptions(includeNone)
        local options = {}
        if includeNone then
            options[#options + 1] = {
                value = "",
                label = "No rule",
                tooltip = "Leave this scope with no opinion and let the next one decide.",
            }
        end
        for _, name in ipairs(store:GetProfileNames()) do
            options[#options + 1] = { value = name, label = name }
        end
        return options
    end

    local function ruleDropdown(scope, label, tooltip)
        return {
            kind = "dropdown",
            label = label,
            tooltip = tooltip,
            options = function()
                return profileOptions(true)
            end,
            get = function()
                return store:GetProfileRule(scope) or ""
            end,
            set = function(value)
                if value == "" then
                    store:ClearProfileForScope(scope)
                else
                    local ok, reason = store:SetProfileForScope(scope, value)
                    if not ok then
                        print("Pulse: " .. (reason or "could not set that rule"))
                    end
                end
            end,
        }
    end

    rows[#rows + 1] = { kind = "header", label = "Active profile" }

    rows[#rows + 1] = {
        kind = "text",
        gap = 10,
        body = function()
            local _, name, why = store:GetProfileResolution()
            local line = ("Pulse is using |cffffd100%s|r, because a rule is set for %s."):format(name, why)
            if store:HasPendingProfileSwitch() then
                line = line
                    .. "\n\nA profile change is waiting: cues re-register when you "
                    .. "leave combat, so nothing is rebuilt mid-pull."
            end
            return line
        end,
    }

    rows[#rows + 1] = {
        kind = "dropdown",
        label = "Profile",
        tooltip = "Which profile to use right now. This writes to whichever rule is "
            .. "currently in force, so picking here always changes what you are actually "
            .. "using rather than editing a rule something more specific is overriding.",
        options = function()
            return profileOptions(false)
        end,
        get = function()
            return store:GetActiveProfileName()
        end,
        set = function(value)
            store:SetActiveProfileName(value)
        end,
    }

    rows[#rows + 1] = { kind = "header", label = "Rules" }

    rows[#rows + 1] = {
        kind = "text",
        gap = 10,
        body = "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and "
            .. "lets the one below it decide; with none of them set, Pulse uses Default.",
    }

    -- Only offered when the character has a specialization to key on. Without one
    -- GetSpecInfo returns nil, a spec rule could never match, and a dropdown that can never
    -- do anything is worse than no dropdown.
    local specID, specName = store:GetSpecInfo()
    if specID then
        rows[#rows + 1] = ruleDropdown(
            store.SCOPE_SPEC,
            child_label_spec(specName, specID),
            "Applies only while this character is in this specialization. Switching "
                .. "specialization switches profile with it, with no further action from you."
        )
    end

    rows[#rows + 1] = ruleDropdown(
        store.SCOPE_CHARACTER,
        "This character",
        "Applies to this character whatever specialization it is in. This is the rule the "
            .. "profile picker on the Pulse page has always written to."
    )

    rows[#rows + 1] = ruleDropdown(
        store.SCOPE_ACCOUNT,
        "Every character",
        "The fallback for any character with no rule of its own — including characters "
            .. "you have not logged into yet. Set this to the profile you mostly want, then "
            .. "override the handful of characters that differ."
    )

    -- Says out loud when a rule you just set is overridden by a more specific one. Without
    -- it, setting "Every character" on a character that already has its own rule appears to
    -- do nothing, and the only way to find out why is to know the scope order. Finding 9 in
    -- helpdocs/CodeReview-2026-09-22.md.
    rows[#rows + 1] = {
        kind = "text",
        child = true,
        font = "GameFontDisableSmall",
        gap = 6,
        body = function()
            local inForce = store:GetProfileResolution()
            local shadowed = {}
            local scopes = {
                { scope = store.SCOPE_SPEC, label = "This specialization" },
                { scope = store.SCOPE_CHARACTER, label = "This character" },
                { scope = store.SCOPE_ACCOUNT, label = "Every character" },
            }
            for _, entry in ipairs(scopes) do
                if entry.scope ~= inForce and store:GetProfileRule(entry.scope) then
                    shadowed[#shadowed + 1] = entry.label
                end
            end
            if #shadowed == 0 then
                return ""
            end
            return (
                "Set but not in force: |cffffd100%s|r. A more specific rule above is "
                .. "winning — clear it to let these take over."
            ):format(table.concat(shadowed, "|r, |cffffd100"))
        end,
    }

    if not specID then
        rows[#rows + 1] = {
            kind = "text",
            child = true,
            font = "GameFontDisableSmall",
            gap = 6,
            body = "This character reports no specialization, so there is no "
                .. "per-specialization rule to set. The row appears by itself on a "
                .. "character that has one.",
        }
    end

    rows[#rows + 1] = { kind = "header", label = "Manage" }

    rows[#rows + 1] = {
        kind = "button",
        label = "New profile",
        buttonText = "Create...",
        tooltip = "Create a new profile from Registry.lua's stock defaults and switch to it.",
        onClick = function()
            prompt("Name the new profile:", "", "Create", function(value)
                report(store:CreateProfile(value))
            end)
        end,
    }

    -- The one genuinely new operation: "Raiding, but quieter" used to mean rebuilding 151
    -- cues by hand, the only way to make a profile being from stock defaults.
    rows[#rows + 1] = {
        kind = "button",
        label = "Copy this profile",
        buttonText = "Copy...",
        tooltip = "Create a new profile that starts as an exact copy of the one in use, "
            .. "and switch to it. The two are independent from the first edit.",
        onClick = function()
            local name = store:GetActiveProfileName()
            prompt(('Copy "%s" to a new profile named:'):format(name), name .. " copy", "Copy", function(value)
                report(store:DuplicateProfile(name, value))
            end)
        end,
    }

    rows[#rows + 1] = {
        kind = "button",
        label = "Rename this profile",
        buttonText = "Rename...",
        tooltip = "Rename the profile in use. Every rule pointing at it follows the rename. "
            .. "Built-in profiles can't be renamed.",
        onClick = function()
            local name = store:GetActiveProfileName()
            prompt(('Rename "%s" to:'):format(name), name, "Rename", function(value)
                report(store:RenameProfile(name, value))
            end)
        end,
    }

    rows[#rows + 1] = {
        kind = "button",
        label = "Delete this profile",
        buttonText = "Delete...",
        tooltip = "Delete the profile in use. Every rule naming it is cleared, so those "
            .. "scopes fall through to the next one down. Built-in profiles can't be deleted.",
        onClick = function()
            local name = store:GetActiveProfileName()
            confirm(('Delete profile "%s"? This can\'t be undone.'):format(name), "Delete", function()
                report(store:DeleteProfile(name))
            end)
        end,
    }

    rows[#rows + 1] = {
        kind = "button",
        label = "Reset this profile",
        buttonText = "Reset...",
        tooltip = "Put the profile in use back to its stock defaults — works on built-ins "
            .. "too, restoring their curated content rather than blank Registry.lua defaults.",
        onClick = function()
            local name = store:GetActiveProfileName()
            confirm(
                (
                    'Reset profile "%s" to defaults? Every cue, intensity and mode '
                    .. "override in it goes back to stock values. This can't be undone."
                ):format(name),
                "Reset",
                function()
                    report(store:ResetProfileToDefaults(name))
                end
            )
        end,
    }

    return rows
end

-- ── Crafting ──────────────────────────────────────────────────────────────────

-- Everything about the craft texture in one place: the master toggle, the two shared
-- strengths, and a toggle plus a strength for every profession.
--
-- Grouped by whether the profession HAS a rhythm rather than by whether the character has
-- it. Two reasons: the player's professions come back from GetProfessionInfo as a localised
-- name and a skill line, and turning that into an Enum.Profession is another lookup that
-- can fail, whereas "does this profession strike anything" is a fact Modules/Crafting.lua
-- already owns — and someone about to level a profession can set it up first.
function Spec.BuildCraftingPage()
    local rows = {}
    local store = database()
    local professions = Pulse.Professions

    local function craftGate()
        return masterOn() and (store:GetCue("craftTexture") and true or false)
    end

    rows[#rows + 1] = { kind = "header", label = "Crafting texture" }

    rows[#rows + 1] = {
        kind = "text",
        gap = 10,
        body = "A bed you feel for the length of a craft, with the profession's own work "
            .. "rhythm struck over it. While a craft is running this replaces |cffffd100"
            .. "Casting texture|r rather than layering with it, so one action is one "
            .. "sensation.\n\nThe profession is read from the recipe by id, so it does not "
            .. "depend on your language. Anything that does not resolve still gets a "
            .. "generic work rhythm rather than going quiet.",
    }

    rows[#rows + 1] = {
        kind = "checkbox",
        label = "Feel crafting",
        tooltip = "The master switch for this page. Also on the Casting page, where the "
            .. "cue lives alongside the other casting cues.",
        get = function()
            return store:GetCue("craftTexture")
        end,
        set = function(value)
            store:SetCue("craftTexture", value)
        end,
        enabledWhen = masterOn,
    }

    rows[#rows + 1] = {
        kind = "slider",
        child = true,
        label = "Bed strength",
        tooltip = "Multiplies the continuous layer under every craft, on top of each "
            .. "profession's own weight. This is the part you feel for the whole craft "
            .. "rather than the individual blows.",
        min = 0.0,
        max = 2.0,
        step = 0.05,
        get = function()
            return store:GetTriggerSetting("craftTexture", "bedGain", 1.0)
        end,
        set = function(v)
            store:SetTriggerSetting("craftTexture", "bedGain", v, 0.0, 2.0)
        end,
        enabledWhen = craftGate,
    }

    rows[#rows + 1] = {
        kind = "slider",
        child = true,
        label = "Strike strength",
        tooltip = "Multiplies every impact, on top of each profession's own weight. Set "
            .. "it to zero for a craft you feel but never get hit by.",
        min = 0.0,
        max = 2.0,
        step = 0.05,
        get = function()
            return store:GetTriggerSetting("craftTexture", "strikeGain", 1.0)
        end,
        set = function(v)
            store:SetTriggerSetting("craftTexture", "strikeGain", v, 0.0, 2.0)
        end,
        enabledWhen = craftGate,
    }

    if not professions then
        return rows
    end

    local function professionRows(header, note, wantsRhythm)
        local matching = {}
        for _, id in ipairs(professions.order) do
            local work = professions.work[id]
            if work and ((work.cadence or 0) > 0) == wantsRhythm then
                matching[#matching + 1] = { id = id, work = work }
            end
        end
        if #matching == 0 then
            return
        end

        rows[#rows + 1] = { kind = "header", label = header }
        rows[#rows + 1] = {
            kind = "text",
            child = true,
            font = "GameFontDisableSmall",
            gap = 8,
            body = note,
        }

        for _, entry in ipairs(matching) do
            local id, work = entry.id, entry.work
            local onKey = professions.EnabledKey(id)
            local gainKey = professions.GainKey(id)

            local function professionOn()
                return craftGate() and store:GetTriggerSetting("craftTexture", onKey, 1) == 1
            end

            rows[#rows + 1] = {
                kind = "checkbox",
                label = work.label,
                tooltip = wantsRhythm and ("%s is felt as %s struck about %.1f times a second, over the bed."):format(
                    work.label,
                    work.mode or "an impact",
                    work.cadence
                ) or ("%s has no impacts — it is the bed alone, for the length of the craft."):format(
                    work.label
                ),
                get = function()
                    return store:GetTriggerSetting("craftTexture", onKey, 1) == 1
                end,
                set = function(value)
                    store:SetTriggerSetting("craftTexture", onKey, value and 1 or 0, 0, 1)
                end,
                enabledWhen = craftGate,
            }

            rows[#rows + 1] = {
                kind = "slider",
                child = true,
                label = "Strength",
                tooltip = ("Scales both the bed and the strikes for %s, before the two " .. "shared strengths above."):format(
                    work.label
                ),
                min = 0.0,
                max = 2.0,
                step = 0.05,
                get = function()
                    return store:GetTriggerSetting("craftTexture", gainKey, 1.0)
                end,
                set = function(v)
                    store:SetTriggerSetting("craftTexture", gainKey, v, 0.0, 2.0)
                end,
                enabledWhen = professionOn,
            }
        end
    end

    professionRows(
        "Professions with a rhythm",
        "These strike. The shape and the rate come from the craft — a hammer is slower and "
            .. "heavier than a pick — and the last blow lands on completion.",
        true
    )

    professionRows(
        "Professions without one",
        "Nothing about these is percussive, so they get the bed alone. Inventing a hammer "
            .. "for enchanting would be inventing a sensation that is not there.",
        false
    )

    return rows
end

-- ── Motor & Timing ────────────────────────────────────────────────────────────

-- Per-mode motor/duration tuning. Only modes in Pulse.ModeRoleInfo get a row, which is
-- every discrete mode. A low or high slider appears only if the mode uses that role
-- somewhere in its steps, and each slider's ceiling is that role's derived ceiling, so the
-- range stops exactly where it stops mattering.
function Spec.BuildModeTuningPage()
    local rows = {}
    local store = database()

    local function tuningSlider(modeID, key, label, minValue, maxValue, step, tooltip)
        return {
            kind = "slider",
            child = true,
            label = label,
            tooltip = tooltip,
            min = minValue,
            max = maxValue,
            step = step,
            get = function()
                return store:GetModeTuning(modeID, key, 1.0)
            end,
            set = function(value)
                store:SetModeTuning(modeID, key, value, minValue, maxValue)
            end,
        }
    end

    for _, modeID in ipairs(Pulse.ModeOrder) do
        local roleInfo = Pulse.ModeRoleInfo[modeID]
        if roleInfo then
            -- A heading per mode with the mode's own one-line description under it.
            -- "STUTTER — Low motor" says nothing about what STUTTER feels like, and the
            -- answer was already in Core/Modes.lua serving as a dropdown tooltip
            -- elsewhere. Tuning a shape you cannot name is guesswork.
            rows[#rows + 1] = { kind = "header", label = modeID }

            local mode = Pulse.Modes[modeID]
            if mode and mode.label then
                rows[#rows + 1] = {
                    kind = "text",
                    font = "GameFontDisableSmall",
                    gap = 8,
                    body = mode.label,
                }
            end

            if roleInfo.hasLow then
                rows[#rows + 1] = tuningSlider(
                    modeID,
                    "lowMult",
                    "Low motor",
                    0.0,
                    roleInfo.lowCeiling,
                    0.05,
                    "Multiplies "
                        .. modeID
                        .. "'s low-motor intensity. 1.0 is the authored "
                        .. "default; the top of this slider is where it stops making any further difference."
                )
            end
            if roleInfo.hasHigh then
                rows[#rows + 1] = tuningSlider(
                    modeID,
                    "highMult",
                    "High motor",
                    0.0,
                    roleInfo.highCeiling,
                    0.05,
                    "Multiplies "
                        .. modeID
                        .. "'s high-motor intensity. 1.0 is the authored "
                        .. "default; the top of this slider is where it stops making any further difference."
                )
            end
            if roleInfo.hasTrigger then
                rows[#rows + 1] = tuningSlider(
                    modeID,
                    "triggerMult",
                    "Trigger actuator",
                    0.0,
                    roleInfo.triggerCeiling,
                    0.05,
                    "Multiplies "
                        .. modeID
                        .. "'s trigger intensity. 1.0 is the authored "
                        .. "default; the top of this slider is where it stops making any further difference."
                )
            end
            rows[#rows + 1] = tuningSlider(
                modeID,
                "durMult",
                "Duration",
                0.25,
                3.0,
                0.05,
                "Speeds up or slows down "
                    .. modeID
                    .. " as a whole — both its pulses and "
                    .. "the gaps between them, so a multi-hit mode keeps its rhythm instead of "
                    .. "the hits stretching into their own gaps. 1.0 is the authored default."
            )

            rows[#rows + 1] = {
                kind = "button",
                child = true,
                label = "Feel " .. modeID,
                buttonText = "Play it",
                tooltip = "Play " .. modeID .. " right now with whatever's currently set on its sliders above.",
                onClick = function()
                    local ok, reason = Pulse:TestMode(modeID)
                    if not ok then
                        print("Pulse: " .. reason .. ", so there is nothing to test.")
                    end
                end,
            }
        end
    end

    rows[#rows + 1] = {
        kind = "button",
        label = "Reset motor & timing",
        buttonText = "Reset...",
        tooltip = "Reset every mode's motor, trigger, and duration multiplier on this page "
            .. "back to 1.0. Doesn't touch cues, per-cue intensity, or per-trigger mode picks.",
        onClick = function()
            confirm(
                "Reset every mode's motor, trigger, and duration multiplier back to " .. "1.0? This can't be undone.",
                "Reset",
                function()
                    store:ResetModeTuning()
                end
            )
        end,
    }

    return rows
end

-- ── Controller calibration ────────────────────────────────────────────────────

-- The layer that answers "how does this motor need to be driven", as opposed to Motor &
-- Timing, which answers "how should this MODE feel", and the schema dropdown, which
-- answers "which motor should this role reach".
function Spec.BuildCalibrationPage()
    local rows = {}
    local store = database()

    local function probeButton(label, buttonText, run, tooltip, child)
        return {
            kind = "button",
            child = child,
            label = label,
            buttonText = buttonText,
            tooltip = tooltip,
            onClick = function()
                local ok, reason = run()
                if not ok then
                    print("Pulse: " .. (reason or "could not run that"))
                end
            end,
        }
    end

    rows[#rows + 1] = { kind = "header", label = "Routing & Schema" }

    rows[#rows + 1] = {
        kind = "dropdown",
        label = "Vibration schema",
        tooltip = "Which physical motors each trigger drives. Start with Standard Rumble or Rumble + Triggers, then calibrate the motors below.",
        options = function()
            local options = {}
            for _, schema in ipairs(Pulse.Registry:GetSchemaOptions()) do
                options[#options + 1] = { value = schema.id, label = schema.label, tooltip = schema.desc }
            end
            return options
        end,
        get = function()
            return store:Get("defaultHapticSchema")
        end,
        set = function(value)
            store:Set("defaultHapticSchema", value)
        end,
    }

    rows[#rows + 1] = { kind = "header", label = "Hardware & Presets" }

    -- Picking from the dropdown only remembers the choice; Apply writes the values. A
    -- preset overwrites trimming you may have spent a while on, so it must never happen as
    -- a side effect of browsing the list.
    rows[#rows + 1] = {
        kind = "dropdown",
        label = "Controller",
        tooltip = "Which controller you are holding. Picking one changes nothing on its own "
            .. "— press Apply below to load its starting values. These are starting points "
            .. "reasoned from what kind of actuators each controller uses, not measurements: "
            .. "Ramp is what measures YOUR controller, and whatever you enter afterwards wins.",
        options = function()
            local options = {}
            for _, id in ipairs(Pulse.DEVICE_ORDER) do
                local device = Pulse.Devices[id]
                if device then
                    options[#options + 1] = { value = id, label = device.label, tooltip = device.note }
                end
            end
            return options
        end,
        get = function()
            return store:GetDevicePreset()
        end,
        set = function(value)
            store:SetDevicePreset(value)
        end,
    }

    rows[#rows + 1] = {
        kind = "text",
        child = true,
        font = "GameFontDisableSmall",
        gap = 8,
        body = function()
            local id = store:GetDevicePreset()
            local dev = Pulse.Devices[id]
            if not dev then
                return ""
            end
            local trigText = dev.triggers and "|cff00ff00Supported|r" or "|cff888888None|r"
            return ("Actuator profile: %s  ·  Triggers: %s\n%s"):format(dev.label or id, trigText, dev.note or "")
        end,
    }

    rows[#rows + 1] = probeButton(
        "Load its starting values",
        "Apply",
        function()
            local id = store:GetDevicePreset()
            local device = Pulse.Devices[id]
            local confirmMsg = (
                'Apply the "%s" starting point? This overwrites every motor\'s strength, '
                .. "floor, timing and curve with that controller's values — any trimming you "
                .. "have already done is lost."
            ):format(device and device.label or id)
            if device and device.triggers and store:Get("defaultHapticSchema") ~= "rumbleAndTriggers" then
                confirmMsg = confirmMsg
                    .. '\n\n|cff4db8ffTip: Since this controller has trigger actuators, consider setting Vibration schema to "Rumble + Triggers" above to route trigger cues to them.|r'
            end
            confirm(confirmMsg, "Apply", function()
                local ok, reason = store:ApplyDevicePreset(id)
                report(ok, reason or "could not apply that preset")
            end)
            return true
        end,
        "Overwrite every motor's calibration with the selected controller's starting "
            .. "values. Ask first, because this discards any trimming you have already done.",
        true
    )

    -- Optional, never automatic. Reads the controller's reported name and ids and says
    -- which row it thinks you want; a wrong guess neither selects nor applies.
    rows[#rows + 1] = probeButton(
        "Which controller is this?",
        "Detect",
        function()
            if type(Pulse.DetectDevice) ~= "function" then
                return false, "detection unavailable"
            end
            local deviceID, presetID, name = Pulse.DetectDevice()
            if not deviceID then
                return false, "no controller detected"
            end
            local device = presetID and Pulse.Devices[presetID]
            if device then
                print(
                    ("Pulse: this looks like a %s%s. Pick it above, then press Apply."):format(
                        device.label,
                        name and (' (reported as "' .. name .. '")') or ""
                    )
                )
            elseif name then
                print(
                    ('Pulse: controller reports itself as "%s", which isn\'t in the list. Use Generic and Ramp each motor.'):format(
                        name
                    )
                )
            else
                print("Pulse: controller found, but it reports no usable name. Use Generic and Ramp each motor.")
            end
            return true
        end,
        "Asks the controller what it is and suggests a row from the list above. Only "
            .. "prints a suggestion — it never selects or applies anything for you.",
        true
    )

    for _, channel in ipairs(Pulse.CHANNELS) do
        local label = Pulse.CHANNEL_LABELS[channel] or channel
        if not Pulse.CHANNEL_CONFIRMED[channel] then
            -- "unconfirmed" is about the API: nothing documents whether this client accepts
            -- the channel name at all. Whether YOUR controller has the hardware is the
            -- separate question Detect and Apply answer.
            label = label .. " (unconfirmed)"
        end

        -- Doubles as this channel's group heading: a button row renders its name on the
        -- left, so one row both labels the group and gives it a probe.
        rows[#rows + 1] = probeButton(
            label,
            "Test",
            function()
                return Pulse.Engine:ProbeChannel(channel, 0.5, 1.5)
            end,
            "Drive this motor at half power for a second and a half, bypassing every "
                .. "setting on this page and every schema. If you feel nothing here, this channel "
                .. "does not work on your controller and no amount of tuning below will change that."
        )

        rows[#rows + 1] = probeButton(
            "Find breakaway floor",
            "Ramp",
            function()
                return Pulse.Engine:RampChannel(channel)
            end,
            "Climbs this motor slowly from silence to half power over eight seconds, "
                .. "printing each step to chat. Watch the chat, and note the number showing when "
                .. "you FIRST feel anything — that is this motor's breakaway floor. Type it into "
                .. "the slider below and quiet cues stop disappearing. Pressing Test cancels a "
                .. "ramp in progress.",
            true
        )

        rows[#rows + 1] = probeButton(
            "Mark floor from ramp",
            "Set Floor",
            function()
                local ramp = Pulse.Engine:GetActiveRamp()
                if ramp and ramp.channel == channel then
                    local floorVal = ramp.magnitude
                    store:SetChannelTuning(channel, "floor", floorVal, 0.0, 0.40)
                    Pulse.Engine:StopRamp(channel)
                    print(("Pulse: captured %s breakaway floor at %.3f"):format(channel, floorVal))
                    return true
                elseif ramp then
                    return false, ("a ramp is currently running on " .. ramp.channel .. ", not " .. channel)
                else
                    return false,
                        "no ramp is running on this channel (press Ramp first, then Set Floor when you feel it)"
                end
            end,
            "Captures the active vibration level from a running Ramp sweep and writes it "
                .. "directly to this motor's Breakaway floor slider below, then stops the ramp. "
                .. "Press this the moment you first feel the motor move!",
            true
        )

        for _, tunable in ipairs(Pulse.CHANNEL_TUNABLES) do
            local default = Pulse.CHANNEL_DEFAULTS[tunable.key]
            rows[#rows + 1] = {
                kind = "slider",
                child = true,
                label = tunable.label,
                tooltip = tunable.desc or "",
                min = tunable.min,
                max = tunable.max,
                step = tunable.step,
                get = function()
                    return store:GetChannelTuning(channel, tunable.key, default)
                end,
                set = function(value)
                    store:SetChannelTuning(channel, tunable.key, value, tunable.min, tunable.max)
                end,
            }
        end
    end

    rows[#rows + 1] = {
        kind = "slider",
        label = "Change threshold",
        tooltip = "How far a motor has to move before the addon bothers telling the client "
            .. "about it. Raise it to cut the number of calls; too high and slow fades turn "
            .. "into visible steps. Shared by every channel — this is a call-rate setting, "
            .. "not a motor property.",
        min = 0.0,
        max = 0.02,
        step = 0.0005,
        get = function()
            return store:GetChangeEpsilon()
        end,
        set = function(value)
            store:SetChangeEpsilon(value)
        end,
    }

    rows[#rows + 1] = {
        kind = "button",
        label = "Reset calibration",
        buttonText = "Reset...",
        tooltip = "Put every motor's strength, floor, timing and curve back to the engine "
            .. "defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.",
        onClick = function()
            confirm(
                "Reset every motor's strength, floor, timing and curve back to the "
                    .. "engine defaults? This can't be undone.",
                "Reset",
                function()
                    store:ResetChannelTuning()
                end
            )
        end,
    }

    return rows
end

-- ── Continuous textures ───────────────────────────────────────────────────────

-- Raw-value tunables for the continuous cues (Registry.lua's `devTuning = true` marker), on
-- their own page rather than cluttering the tabs a normal user reads.
--
-- Deliberately ungated: the matching cue's checkbox lives on another page and each tunable's
-- tooltip says so. Always visible too — this page is nothing but detail controls, so hiding
-- them behind the detail toggle would leave it blank.
function Spec.BuildContinuousPage()
    local rows = {}

    for _, trigger in ipairs(Pulse.Triggers) do
        if trigger.devTuning and trigger.tunables then
            -- A real heading, the cue's own description under it, then a Play row. Using
            -- the Play button's label AS the heading kept the page one row shorter and cost
            -- the description, which here is the thing saying what the dials shape.
            rows[#rows + 1] = { kind = "header", label = trigger.label }

            if trigger.desc then
                rows[#rows + 1] = {
                    kind = "text",
                    font = "GameFontDisableSmall",
                    gap = 8,
                    body = trigger.desc,
                }
            end

            local test = cueTestButton(trigger, "Feel this texture", true)
            if test then
                rows[#rows + 1] = test
            end

            for _, tunable in ipairs(trigger.tunables) do
                rows[#rows + 1] = tunableRow(trigger, tunable, { ungated = true, alwaysVisible = true })
            end
        end
    end

    return rows
end

-- ── Guide ─────────────────────────────────────────────────────────────────────

-- Core/Guide.lua rendered as text blocks. The old panel needed
-- RegisterCanvasLayoutSubcategory, the Settings API building controls and nothing that
-- renders a paragraph; here a paragraph is another kind of row.
local function markup(text)
    text = text:gsub("%*%*(.-)%*%*", "|cffffd100%1|r")
    text = text:gsub("\n    ", "\n   ")
    return text
end

function Spec.BuildGuidePage()
    local rows = {}
    for _, section in ipairs(Pulse.Guide or {}) do
        rows[#rows + 1] = { kind = "header", label = section.heading }
        rows[#rows + 1] = { kind = "text", body = markup(section.body), gap = 8 }
    end
    return rows
end

-- ── Page list ─────────────────────────────────────────────────────────────────

-- Sidebar order, matching the old panel's registration order: the root page, one page per
-- PAGE_LAYOUT entry that has cues, the three tuning pages, then the guide.
function Spec.BuildPages()
    local pages = {}

    pages[#pages + 1] = { id = "root", label = "Pulse", indent = 0, build = Spec.BuildRootPage }

    -- First of the children, before the cue pages it indexes.
    pages[#pages + 1] = { id = "cueIndex", label = "Cue index", indent = 1, build = Spec.BuildCueIndexPage }
    pages[#pages + 1] = { id = "profiles", label = "Profiles", indent = 1, build = Spec.BuildProfilesPage }
    pages[#pages + 1] = { id = "crafting", label = "Crafting", indent = 1, build = Spec.BuildCraftingPage }

    for _, page in ipairs(Pulse.Registry:GetPages()) do
        if page.hasCues then
            pages[#pages + 1] = {
                id = page.id,
                label = page.label,
                indent = 1,
                build = function()
                    return Spec.BuildCuePage(page)
                end,
            }
        end
    end

    pages[#pages + 1] = { id = "modeTuning", label = "Motor & Timing", indent = 1, build = Spec.BuildModeTuningPage }
    pages[#pages + 1] = {
        id = "calibration",
        label = "Controller calibration",
        indent = 1,
        build = Spec.BuildCalibrationPage,
    }
    pages[#pages + 1] = {
        id = "continuous",
        label = "Continuous textures",
        indent = 1,
        build = Spec.BuildContinuousPage,
    }

    if Pulse.Guide and #Pulse.Guide > 0 then
        pages[#pages + 1] = { id = "guide", label = "Guide", indent = 1, build = Spec.BuildGuidePage }
    end

    return pages
end
