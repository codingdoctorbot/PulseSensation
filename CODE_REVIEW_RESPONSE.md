# Response to the v0.3.0-beta Deep Code Review

**Reviewed document:** *PulseHaptics v0.3.0-beta — Deep Code Review* (2026-10-01)
**Checked against:** `main` at `947aac4`

Each finding was checked against the source. Where a finding is a real bug, it was reproduced
with a small Lua script, and the fix below was applied to a scratch copy and tested: both
reproduction scripts pass and all 9 test suites in `scripts/test.sh` still pass. **No code in
the repository has been changed yet.** This document only proposes the fixes.

## Summary

| ID | The review says | Verdict | What to do |
|---|---|---|---|
| F-01 | TOC is missing Forever Beta's interface `16001` (release blocker) | **Probably wrong.** Your own in-client check says `120100` | Run one command in game to settle it |
| F-02 | An unrelated spell can complete a craft | True, with 3 more places like it, but **rare in practice** (live client log below) | Fix below (tested); low priority |
| F-03 | Ocean detection only works in English | True, but minor: the setting is off by default | Small fix below |
| F-04 | One broken listener stops the others from hearing a change | **True** | Fix below (tested) |
| F-05 | Event registration isn't consistently protected | True as a design point; nothing breaks today | Optional |
| F-06 | README cue count is stale | **Wrong.** 190 cues in 16 categories is correct | Nothing |
| F-07 | Timers have no shared cancel system | Opinion, not a bug | Nothing now |
| F-08 | Compatibility checks are duplicated | Opinion, not a bug | Nothing now |
| F-09 | "AlertExperimental" is still loaded | Only the filename is left over | Optional rename |
| F-10 | No event-sequence tests | Overstated: the tests exist outside the release zip | Add the new tests below |

**Recommended order:** check F-01 → fix F-04 → fix F-02 and F-03 when convenient.

---

## F-01 — "The TOC doesn't declare Forever Beta" (probably wrong)

**What the review says.** The first line of `PulseHaptics.toc` is
`## Interface: 120100, 110200, 110100`. The review says Forever Beta's interface number is
`16001`, so WoW would treat the addon as built for a different game version.

**Is it true?** Probably not. The TOC itself records that `120100` was **confirmed on your live
client** with `/dump select(4, GetBuildInfo())`, and the README badge says "Forever / Classic
Beta (120100)". The code also relies on APIs from the 12.x client (for example `issecretvalue`),
and it runs without errors. The review trusted a wiki over a check made inside the game.

The review makes the same mistake elsewhere: it says `C_GamePad.SetVibration` supports
`LTrigger` and `RTrigger` because the wiki says so. `Core/Devices.lua` records a live test from
2026-09-29 where those channels do **not** vibrate.

**In plain English.** The interface number tells WoW which game version an addon was made for.
If it's wrong, WoW marks the addon "out of date" and won't load it unless the player ticks
"Load out of date AddOns". Since the addon already loads and runs on your client, the number is
almost certainly right.

**What to do.** In the Forever Beta client, type:

```
/dump select(4, GetBuildInfo())
```

- **Prints `120100`:** the review is wrong, and nothing needs to change.
- **Prints `16001`:** add it to the list rather than replacing what's there:
  `## Interface: 120100, 16001`

---

## F-02 — Crafting: other spells are mistaken for the craft (real bug, rare in practice)

**The bug.** When you start crafting, `Core/CastActivity.lua` remembers the craft, and then
waits for "a cast succeeded", "a cast stopped" or "a cast failed" events to learn how it ended.
Normally it matches those events to the craft by the cast's ID. When it has no ID recorded, it
**guesses**, and the guesses are too generous:

| Where | The guess | What goes wrong |
|---|---|---|
| `_OnSucceeded` (line 142) | "Nothing else is being tracked, so this must be the craft" | Casting any **instant spell** during the craft counts as **finishing** the craft |
| `_OnStop` (line 307) | Same guess | Any other cast stopping counts as **abandoning** the craft |
| `_OnFailed` (line 261) | "No ID recorded, so any failure is the craft's" | Pressing any button that **fails** ("not ready yet", "out of range") abandons the craft |
| `_OnInterrupted` (line 219) | Same as `_OnFailed` | Any interrupted cast abandons the craft |

The review found only the first row.

**What a player notices.**
- A "craft complete" vibration fires the moment they use an instant ability (a mount, a
  trinket, a buff) while crafting, even though the item isn't finished.
- The real completion vibration then **never comes**, because the addon has already decided the
  craft is over.
- A misclick that fails mid-craft can cut off the crafting texture early.
- The craft duration the addon reports is wrong.

**Reproduced.** All four rows above reproduce in a script (Appendix A). The real-craft cases
already work, and still do after the fix:

| Scenario | Before | After |
|---|---|---|
| Real craft: cast start, craft begins, succeeds | ✅ complete | ✅ complete |
| Real craft: craft begins, cast start, succeeds | ✅ complete | ✅ complete |
| Real craft: cast started 0.8 s before the craft event | ✅ complete | ✅ complete |
| Real craft: success carries the recipe's ID, no start seen | ✅ complete | ✅ complete |
| Real craft fails (player moved) | ✅ stopped | ✅ stopped |
| Instant spell succeeds during the craft | ❌ "craft complete" | ✅ ignored |
| Another cast fails during the craft | ❌ "craft stopped" | ✅ ignored |
| Another cast stops during the craft | ❌ "craft stopped" | ✅ ignored |
| Another cast is interrupted during the craft | ❌ "craft stopped" | ✅ ignored |

**The fix.** Keep the guess, but only accept a cast the addon **saw start**. Crafts have a cast
bar, so the craft's own cast always starts first. Instant spells and failed button presses
never do, so they can no longer be mistaken for the craft.

```diff
--- a/PulseHaptics/Core/CastActivity.lua
+++ b/PulseHaptics/Core/CastActivity.lua
@@ function CastActivity:_OnSucceeded(unit, castGUID, spellID)
 		elseif self.crafting.spellID == spellID then
 			isCrafting = true
-		elseif next(self.pending) == nil or self.pending[key] ~= nil then
-			-- A player can only craft one item at a time; if self.crafting is active
-			-- and any tracked cast (or test event) finishes, consume crafting state.
+		elseif self.pending[key] ~= nil then
+			-- Uncorrelated craft: accept only a cast we actually watched START. An event with
+			-- no START behind it (an instant spell, an off-GCD ability) is never the craft —
+			-- an empty pending table is absence of evidence, not a match.
 			isCrafting = true
 		end

@@ function CastActivity:_OnInterrupted(unit, castGUID, spellID)
 		self.activeChannel.interruptedBy = "interrupt"
 	end
+	-- Read before clearing: with no cast GUID on record, only a cast we watched START may
+	-- end the craft. Otherwise any failed button press would abandon it.
+	local wasPending = self.pending[key] ~= nil
 	self.pending[key] = nil
 	if
 		self.crafting
-		and (not self.crafting.castGUID or self.crafting.castGUID == castGUID or self.crafting.castSpellID == spellID)
+		and (
+			(not self.crafting.castGUID and wasPending)
+			or (castGUID and self.crafting.castGUID == castGUID)
+			or (spellID and self.crafting.castSpellID == spellID)
+		)
 	then

@@ function CastActivity:_OnFailed(unit, castGUID, spellID)
 		self.activeChannel.interruptedBy = "failed"
 	end
+	local wasPending = self.pending[key] ~= nil -- see _OnInterrupted
 	self.pending[key] = nil
 	if
 		self.crafting
-		and (not self.crafting.castGUID or self.crafting.castGUID == castGUID or self.crafting.castSpellID == spellID)
+		and (
+			(not self.crafting.castGUID and wasPending)
+			or (castGUID and self.crafting.castGUID == castGUID)
+			or (spellID and self.crafting.castSpellID == spellID)
+		)
 	then

@@ function CastActivity:_OnStop(unit, castGUID, spellID)
 		elseif self.crafting.spellID == spellID then
 			isCrafting = true
-		elseif next(self.pending) == nil or pending ~= nil then
+		elseif pending ~= nil then
+			-- Same rule as _OnSucceeded: only a cast we watched START can be the craft.
 			isCrafting = true
 		end
```

The `(castGUID and …)` and `(spellID and …)` guards stop two missing IDs from counting as a
match (`nil == nil` is true in Lua).

**Why not the review's fix.** The review suggests removing the guess entirely and expiring each
craft after **2 seconds**. Many crafts take longer than 2 seconds, so every one of them would
lose its completion vibration. The fix above keeps every real craft working (see the table) and
only rejects events that can't be the craft.

**Evidence from the live client (2026-10-01).** A debug log of one Blacksmithing craft (Rough
Sharpening Stone, recipe 2660), with every cue enabled, shows this order:

| # | Chat line | Event |
|---|---|---|
| 1 | Craft started | `TRADE_SKILL_CRAFT_BEGIN`, **first** |
| 2 | Cast sent | `UNIT_SPELLCAST_SENT` |
| 3 | Your cast started | `UNIT_SPELLCAST_START`, **after** the craft event |
| 4 | Crafting texture holding | the texture runs |
| 5 | Craft finished, then Your cast succeeded | one `UNIT_SPELLCAST_SUCCEEDED` |
| 6 | Your cast ended | `UNIT_SPELLCAST_STOP` |
| 7 | Item obtained, Loot received, skill up | loot and skill messages |

The craft event arrives first and the cast start right after it, so `_OnStart` records the
craft's cast ID at step 3. From then on, every success, stop or failure is matched by that ID,
and the guessing code never runs. The bug can only happen in the instant between steps 1 and 3,
or if a cast start is never delivered. **So it is real but rare: low priority, not the P1 the
review gave it.** The fix is still worth making because it is small and tested, and it leaves
this normal path untouched (it is the "craft begins, then cast start, then succeeds" row
above).

**One trade-off to know about.** A craft with **no cast bar at all**, and no matching IDs, will
no longer get a completion vibration. The log confirms a normal craft does have a cast start,
so this only matters for unusual cases. Not yet observed: repeat crafting ("Create All"). Craft
three items with debug on and check that "Craft started" appears three times.

**Deliberately left alone.** `_OnStart` (line 90) lets any new cast take over the craft's
tracking. That looks like a bug, but it is probably what makes **repeat crafting** ("Create
All") work, since each item is a new cast. Changing it needs testing in game first.

---

## F-04 — One broken listener silences the rest (real bug)

**The bug.** When a setting changes, `Core/Database.lua` tells every part of the addon that
asked to hear about it (its "listeners"). It calls them one after another with no protection
(`notify`, line 1225). If one of them hits an error, **the loop stops there**: the setting is
already saved, but every listener after the broken one never hears about the change.

**What a player notices.** This matters most when switching profiles (for example, entering a
raid). A profile switch notifies every module at once (`Database.lua:2532-2534`). If one module
has a bug, the modules after it keep running on the **old profile's settings**:
- cues the new profile turned off keep firing, or the reverse;
- the intensity changes in some places but not others;
- the settings window shows the new profile while the vibrations follow the old one.

It stays wrong until something else happens to refresh those modules, so it looks random and
is hard to report.

**Reproduced** (Appendix B): with one failing listener, changing `masterIntensity` saves the
value, but the next listener never runs, and the caller (such as a slider) gets an error.

| | Before | After |
|---|---|---|
| Value saved | yes | yes |
| Later listener notified | **no** | yes |
| Caller gets an error | **yes** | no; the error is reported to WoW's error handler (BugSack etc.) instead |

**The fix.** Wrap each listener on its own, so one failure is reported but the rest still run.
This is the same pattern `CastActivity.lua:51-62` already uses:

```diff
--- a/PulseHaptics/Core/Database.lua
+++ b/PulseHaptics/Core/Database.lua
@@ local function notify(listeners, key)
 	if not list then
 		return
 	end
+	-- One listener per call, each isolated: a bug in one module must not stop the rest from
+	-- hearing a change that has already been saved (same pattern as CastActivity's emit).
+	local errHandler = _G.geterrorhandler and _G.geterrorhandler()
 	for _, callback in ipairs(list) do
-		callback()
+		if errHandler then
+			xpcall(callback, errHandler)
+		else
+			pcall(callback)
+		end
 	end
 end
```

Don't use the review's §17.2 version: it passes `debugstack` as the error handler, which throws
away the actual error message.

---

## F-03 — Ocean detection only works in English (real, minor)

**The bug.** With "Ocean zones only" on, the ocean swell (`Modules/Movement.lua:49-88`) only
plays if the zone's **name** contains an English word like "Sea", "Coast", "Bay" or "Port".
Zone names are translated, so on a German, French or Spanish client those words never appear.
The word list also includes very general words ("Port", "Sound", "Channel", "Cape"), so a lake
inside a zone with one of those names counts as ocean.

**What a player notices.**
- **Non-English players:** the ocean swell never plays in the ocean (only in deep "fatigue"
  water), and nothing explains why.
- **English players:** now and then the swell plays in a lake or river.

**How serious.** Low. The ocean texture is **off by default**, and the worst case is one
optional texture playing in the wrong water.

**Fix.** The review's suggestion of looking the map ID up in a table of ocean maps doesn't work
in WoW: open sea is part of each zone's map, so there is no "ocean" map ID to look for. Two
smaller changes do help:

1. On non-English clients, don't let the English-only check block the texture:

```lua
-- Modules/Movement.lua, near OCEAN_PATTERNS
-- Zone names are localised; these English patterns only mean something on English clients.
local OCEAN_NAMES_READABLE = (type(GetLocale) ~= "function")
	or GetLocale() == "enUS" or GetLocale() == "enGB"
```

```lua
-- Movement.lua:250
if not oceanOnly or isOceanZone or isFatigueWater or not OCEAN_NAMES_READABLE then
```

2. Make the setting say what it does (`Core/Registry.lua:327`):

```lua
label = "Ocean zones only (guessed from zone name)",
desc = "When set to 1, plays the swell only where the zone name suggests sea or coast, or in "
	.. "deep-water fatigue. English game clients only; other languages always play it. "
	.. "Set to 0 to feel the swell in all swimming water.",
```

Translated word lists can be added later, one language at a time.

---

## F-05 — Event registration isn't consistently protected (optional)

**What it means.** Most modules register for game events directly (99 places). If a future
patch removed one of those events, that module would hit an error when it loads. A few places
(`Core/Init.lua`, `Modules/ControllerUI.lua`) already protect against this.

**What a player notices today.** Nothing: every event exists on the current client. This
protects against future patches rather than fixing a bug, so the shared helper the review
suggests (§17.3) is reasonable to adopt **gradually**, module by module, as files are touched
for other reasons.

## F-06 — "The README count is stale" (wrong)

The review counted 200 entries in `Core/Registry.lua`. Ten of them are `PAGE_GATE` entries,
which are the on/off switches for whole pages, not cues. **That leaves exactly 190 cues in 16
categories**, matching the README. No change is needed. The review's general point (generate
the numbers instead of typing them) is fine as a future improvement.

## F-07, F-08 — Shared timer and compatibility helpers (opinion)

These are suggestions about code structure, not bugs. The review itself says the engine's timer
protection is good, and found no case where a module's timer causes a problem. Worth doing only
if those areas are being reworked anyway.

## F-09 — "AlertExperimental is still loaded" (mostly naming)

The "experimental" category was dissolved on 2026-09-16, and its cues were regrouped by subject
(see the comments in `Modules/AlertExperimental.lua`). The file name is the only thing left
over. Renaming it to something like `AlertState.lua` would be a tidy-up, not a fix.

## F-10 — "There are no event-sequence tests" (overstated)

The review only had the release zip, so it didn't see `PulseChecklist/tests/`. That folder has 9
test suites, including `crafting-test.lua`, which drives real craft events, and `engine-test.lua`,
which has a controllable timer queue. What is genuinely missing are tests for the two bugs above:
**add Appendix A and Appendix B as tests** alongside the fixes.

---

## Appendix A — craft reproduction (becomes a test)

Run from the repo root with `lua5.1 craft-repro.lua PulseHaptics`. Before the fix it reports 4
wrong scenarios, and after it reports `ALL OK`.

```lua
local ROOT = arg[1] or "PulseHaptics"

local now = 1000
function GetTime() return now end
function issecretvalue() return false end
function UnitIsDeadOrGhost() return false end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
local FrameMT = { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end }
function CreateFrame() return setmetatable({}, FrameMT) end
C_Timer = { After = function() end }

local Pulse = { modules = {}, moduleOrder = {}, debug = false }
function Pulse:RegisterModule() end
assert(loadfile(ROOT .. "/Core/CastActivity.lua"))("Pulse", Pulse)
local CA = Pulse.CastActivity

local seen = {}
CA:OnActivity(function(r) seen[#seen + 1] = r.classification end)

local fails = 0
local function scenario(label, want, fn)
	CA:Reset(); seen = {}; now = now + 100
	fn()
	local got = table.concat(seen, ",")
	if got ~= want then fails = fails + 1 end
	print(("%-4s %-58s got: %s"):format(got == want and "ok" or "BUG", label, got))
end

scenario("craft: START then CRAFT_BEGIN then SUCCEEDED", "CAST_START,CRAFT_START,CRAFT_COMPLETE", function()
	CA:_OnStart("player", "g-craft", 3333); now = now + 0.1
	CA:_OnCraftBegin(1234); now = now + 3
	CA:_OnSucceeded("player", "g-craft", 3333)
end)
scenario("craft: CRAFT_BEGIN then START then SUCCEEDED", "CRAFT_START,CRAFT_CAST_START,CRAFT_COMPLETE", function()
	CA:_OnCraftBegin(1234); now = now + 0.05
	CA:_OnStart("player", "g-craft", 3333); now = now + 3
	CA:_OnSucceeded("player", "g-craft", 3333)
end)
scenario("craft: START 0.8s before CRAFT_BEGIN, then SUCCEEDED", "CAST_START,CRAFT_START,CRAFT_COMPLETE", function()
	CA:_OnStart("player", "g-craft", 3333); now = now + 0.8
	CA:_OnCraftBegin(1234); now = now + 3
	CA:_OnSucceeded("player", "g-craft", 3333)
end)
scenario("craft: recipe-ID SUCCEEDED, no START seen", "CRAFT_START,CRAFT_COMPLETE", function()
	CA:_OnCraftBegin(1234); now = now + 3
	CA:_OnSucceeded("player", nil, 1234)
end)
scenario("craft: real cast FAILED (e.g. moved)", "CAST_START,CRAFT_START,CRAFT_STOPPED,FAILED", function()
	CA:_OnStart("player", "g-craft", 3333); now = now + 0.1
	CA:_OnCraftBegin(1234); now = now + 1
	CA:_OnFailed("player", "g-craft", 3333)
end)
scenario("unrelated instant SUCCEEDED during craft", "CRAFT_START,INSTANT", function()
	CA:_OnCraftBegin(1234); now = now + 1
	CA:_OnSucceeded("player", "g-other", 5555)
end)
scenario("unrelated FAILED during craft", "CRAFT_START,FAILED", function()
	CA:_OnCraftBegin(1234); now = now + 1
	CA:_OnFailed("player", "g-other", 6666)
end)
scenario("unrelated STOP during craft", "CRAFT_START,CAST_STOPPED", function()
	CA:_OnCraftBegin(1234); now = now + 1
	CA:_OnStop("player", "g-other", 7777)
end)
scenario("unrelated INTERRUPTED during craft", "CRAFT_START,INTERRUPTED", function()
	CA:_OnCraftBegin(1234); now = now + 1
	CA:_OnInterrupted("player", "g-other", 8888)
end)

print(fails == 0 and "ALL OK" or (fails .. " scenario(s) wrong"))
```

## Appendix B — listener reproduction (becomes a test)

Run from the repo root with `lua5.1 listener-repro.lua PulseHaptics`. It uses the existing test
harness to load the whole addon.

```lua
local root = arg[1] or "PulseHaptics"
arg = { [0] = "PulseChecklist/tests/harness.lua", root }
local realPrint = print
print = function() end            -- silence the harness's own checks
io.write = function() end
dofile("PulseChecklist/tests/harness.lua")
print = realPrint

local laterListenerRan = false
Pulse.Database:OnGlobalChanged("masterIntensity", function() error("a module's listener has a bug") end)
Pulse.Database:OnGlobalChanged("masterIntensity", function() laterListenerRan = true end)

local ok = pcall(Pulse.Database.Set, Pulse.Database, "masterIntensity", 0.55)
print("Set() raised an error:", not ok)
print("later listener still ran:", laterListenerRan)
print(laterListenerRan and ok and "ALL OK" or "BUG")
```

## How the fixes were checked

- Lua 5.1, run on a scratch copy of the repo with both fixes applied.
- Appendix A: 4 wrong scenarios before, `ALL OK` after, with all 5 real-craft scenarios
  unchanged.
- Appendix B: `BUG` before, `ALL OK` after.
- `scripts/test.sh --fast`: all 9 suites pass, before and after.
- Not checked: luacheck (not installed here), and anything that needs the live game client.
  That includes the F-01 build number and the `/etrace` check in F-02.
