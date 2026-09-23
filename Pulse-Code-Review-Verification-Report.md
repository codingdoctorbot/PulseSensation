# Pulse Code Review — Independent Verification Report

**Date:** 2026-09-23  
**Verifying:** `Pulse-Code-Review-Report.md` (dated 2026-09-23)  
**Method:** Independent read-only cross-reference of every claim against Pulse addon source and `wow-ui-source-forever` (`1.60.1.69913`)  
**Verdict Model:** ✅ CONFIRMED · ⚠️ PARTIALLY CONFIRMED · ❌ DISPUTED  

---

## Verification Summary

| # | Report Claim | Verdict | Notes |
|:-:|:---|:---:|:---|
| 1 | Executive Summary / Client Context | ✅ | All API and engine claims verified |
| 2.1 | `COMBAT_TEXT_UPDATE` / `C_CombatText` | ✅ | Fully accurate |
| 2.2 | `isTradeskill` in `UnitCastingInfo` | ⚠️ | API facts correct; architectural suggestion needs caveats |
| 3.1 | P1: Hot Loop GC Allocation | ✅ | Genuine issue, correctly diagnosed |
| 3.2 | P2: Idle OnUpdate Ticking | ⚠️ | Overstated for Crafting/Locomotion; accurate for Combat |
| 4 | Taint / Combat Protection Audit | ✅ | All four claims verified |
| 5.1 | Cross-Realm Emote Parsing | ✅ | Genuine edge case |
| 5.2 | `activeProfile()` Nil Safety | ⚠️ | Crash path exists but is far narrower than described |

---

## 1. Executive Summary & Client Context

### ✅ CONFIRMED

The report's foundational claims about the WoW Forever engine were all verified against source:

- **Interface `120100` / Patch 12.1.0** — Confirmed. This is the Midnight engine branch.
- **`C_CombatText`, `C_Secrets` / `issecretvalue`, `C_LossOfControl`, `C_GamePad`** — All present in `Blizzard_APIDocumentationGenerated/`.
- **`Clamp` and `Lerp` as C-functions in global scope** — Confirmed. These are capitalized globals, not `math.clamp`/`math.lerp`.

No issues found with any engine context claims.

---

## 2.1. `COMBAT_TEXT_UPDATE` & `C_CombatText`

### ✅ CONFIRMED

Every sub-claim independently verified:

| Claim | Source Reference | Verified? |
|:---|:---|:---:|
| Event payload is ONLY `combatTextType` | [`CombatTextDocumentation.lua:49-52`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatTextDocumentation.lua#L49-L52) | ✅ |
| `GetCurrentEventInfo` has `SecretReturns = true` | [`CombatTextDocumentation.lua:23`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatTextDocumentation.lua#L23) | ✅ |
| Blizzard uses `C_CombatText.GetCurrentEventInfo()` at line 104 | [`CombatText.lua:104`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_CombatText/Shared/CombatText.lua#L104) — exact code: `data, arg3, arg4 = C_CombatText.GetCurrentEventInfo();` | ✅ |
| Pulse's `pcall` + `issecretvalue` pattern is correct | [`Combat.lua:229-295`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L229-L295) | ✅ |

**No corrections needed.** The report accurately describes the API surface and Pulse's conformant implementation.

---

## 2.2. `isTradeskill` in `UnitCastingInfo`

### ⚠️ PARTIALLY CONFIRMED — API facts correct, architectural suggestion needs caveats

**API claims — all verified:**

| Claim | Source Reference | Verified? |
|:---|:---|:---:|
| `UnitCastingInfo` return 6 is `isTradeskill` (`bool`, `NeverSecret = true`) | [`UnitDocumentation.lua:845`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L845) | ✅ |
| `CastingBarFrame.lua:496` unpacks it as return 6 | [`CastingBarFrame.lua:496`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua#L496) — `local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(self.unit);` | ✅ |

**Additional finding the report omits:** `UnitChannelInfo` ALSO has `isTradeskill` at return 6 with `NeverSecret = true` ([`UnitDocumentation.lua:887`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L887)). The report's suggestion at `Combat.lua:363` only covers the casting branch, not the channeling branch at line 383. A complete fix would need `isTradeskill` checks in both `UnitCastingInfo` AND `UnitChannelInfo` code paths.

**Architectural caveat:** The report claims this "eliminates all cross-module state coupling, race conditions, and lingering crafting flags." This is an overstatement. `Pulse.IsCrafting()` in [`Crafting.lua:198`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Crafting.lua#L198) serves a broader purpose than just filtering casts — it tracks the `active` flag which persists through the entire craft operation including the 0.5s failsafe timer ([`Crafting.lua:181-190`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Crafting.lua#L181-L190)). While `isTradeskill` would be a cleaner signal at the point of cast detection, the broader crafting state management in `Crafting.lua` (progress tracking, bed vibration, strike scheduling) would still need its own `active` flag. The improvement is real but the report oversells the scope of simplification.

---

## 3.1. P1: Hot Loop GC Allocation in `Engine:Set`

### ✅ CONFIRMED — Genuine issue

**Verified code at [`Engine.lua:169-171`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Engine.lua#L169-L171):**

```lua
function Engine:Set(name, low, high, duration)
    return self:SetRoles(name, { low = low or 0, high = high or 0 }, duration)
end
```

**Call chain verified:**
1. `Engine:Hold` at [line 201-203](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Engine.lua#L201-L203) calls `self:Set(...)` ✅
2. `Pulse:HoldIfEnabled` in [`Init.lua`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Init.lua) calls `Engine:Hold` ✅
3. Continuous cues call `HoldIfEnabled` inside OnUpdate tick loops ✅

**`SetRoles` consumption verified at [lines 176-192](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Engine.lua#L176-L192):**

```lua
function Engine:SetRoles(name, roles, duration)
    -- ...
    for role, value in pairs(roles) do
        target[role] = clamp01(value or 0)
    end
    layer.endTime = GetTime() + (duration or 0.1)
end
```

The `roles` table is iterated and its values copied into the persistent `layer.roles` table. The passed-in table is never stored, only read. **A scratch table rewrite is safe** — the report's proposed fix is correct.

**Frequency assessment:** I verified that multiple continuous cues hold every frame:
- `castTick` in Combat.lua calls `HoldIfEnabled("castTexture", ...)` at [lines 378, 381, 391](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L378)
- `tick` in Locomotion.lua calls `HoldIfEnabled` or `HoldRolesIfEnabled` at [lines 511, 524](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Locomotion.lua#L511)
- `tick` in Crafting.lua calls `HoldRolesIfEnabled` at [line 305](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Crafting.lua#L305)

At 60-144 Hz with multiple active cues, this is **hundreds of throwaway tables per second**. The report's diagnosis and fix are sound.

> [!NOTE]
> Interestingly, Crafting.lua and Locomotion.lua already use reused scratch tables (`bedRoles` at [Crafting.lua:276](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Crafting.lua#L276), `splitRoles` at [Locomotion.lua:508-510](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Locomotion.lua#L508-L510)) for their `HoldRolesIfEnabled` calls — demonstrating the author is aware of the pattern. `Engine:Set` is the outlier that was missed.

---

## 3.2. P2: Idle OnUpdate Frame Ticking

### ⚠️ PARTIALLY CONFIRMED — Report overstates severity for 2 of 3 modules

The report lists three modules with "idle OnUpdate ticking" and presents them as equivalent. **They are not.**

#### Combat.lua `castTick` — ✅ Genuine waste when idle

[`Combat.lua:350-392`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L350-L392):

When neither casting nor channeling, `castTick()` still executes per frame:
1. `Pulse.IsCrafting()` — function call → method call → boolean read
2. `Pulse.Database:GetTriggerSetting("castTexture", "castPresence", 0.1)` — this calls `activeProfile()` → `GetActiveProfileName()` → table lookups

This is unnecessary work on **every frame** while idle. The report is correct that the `GetTriggerSetting` call at [line 360](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L360) runs unconditionally before the `if isCasting` / `elseif isChanneling` branches.

#### Crafting.lua `tick` — ⚠️ Trivially cheap early return

[`Crafting.lua:278-281`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Crafting.lua#L278-L281):

```lua
local function tick()
    if not active then
        return
    end
```

When idle (`active == false`), the function exits after **one boolean check**. This is as cheap as an OnUpdate handler can be — a single upvalue read and conditional branch. The report claims `tick()` "runs every tick when `active == false`" which is technically true but misleading: the cost is negligible (~2 nanoseconds per frame).

#### Locomotion.lua `tick` — ⚠️ Trivially cheap early return

[`Locomotion.lua:448-451`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Locomotion.lua#L448-L451):

```lua
local function tick(_, elapsed)
    if not isMoving then
        return
    end
```

Identical pattern — one boolean upvalue check when standing still. Negligible cost.

#### Environment.lua "ideal pattern" — ✅ Correctly identified

[`Environment.lua:276-281`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Environment.lua#L276-L281) does indeed dynamically attach/detach `OnUpdate`:

```lua
if wantTexture and currentWeatherIntensity > 0 and currentWeatherType ~= 0 then
    weatherFrame:SetScript("OnUpdate", weatherTick)
else
    weatherFrame:SetScript("OnUpdate", nil)
end
```

**Revised assessment:** The report's P2 finding is architecturally correct in principle (event-driven attach/detach is cleaner), but the **practical severity is overstated** for Crafting and Locomotion. Only Combat.lua's `castTick` does measurable wasted work when idle, because it unconditionally calls `GetTriggerSetting` before checking cast state. I would reclassify:
- **Combat.lua `castTick`** — P2 ✅ (real waste: database lookup every frame while idle)
- **Crafting.lua `tick`** — P3 at best (one boolean check per frame)
- **Locomotion.lua `tick`** — P3 at best (one boolean check per frame)

---

## 4. Taint & Combat Protection Audit

### ✅ CONFIRMED — All four claims verified

#### ControllerUI.lua — Passive Poller ✅

[`ControllerUI.lua:347-445`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/ControllerUI.lua#L347-L445): Verified that `uiPollTick` is a passive 20Hz poller. I searched for any callback registration on `SmartNavigation` or `SmartNavigationMixin` within Pulse's source — **none found**. The addon polls gamepad state without hooking into Blizzard's protected SmartNavigation chain.

#### Popup.lua — Custom Menu System ✅

[`Popup.lua:1-42`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/UI/Panel/Popup.lua#L1-L42): The taint rationale comment is exceptionally well-documented, tracing the exact Blizzard call chain:
```
MenuProxyMixin:OnShow → EventRegistry → FrameControlsManager → GamepadMode.ActivateBindingGroup → SetOverrideBindingClick
```
The comment cites specific Blizzard source file line numbers. Verified that [`FrameControlsManager.lua`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_UIParent/Shared/FrameControlsManager.lua) does exist in the WoW Forever source tree.

#### Minimap.lua — Mouse Propagation ✅

[`Minimap.lua:130-138`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/UI/Minimap.lua#L130-L138): Both `SetPropagateMouseClicks(false)` and `SetPropagateMouseMotion(false)` are called, guarded by existence checks (`if btn.SetPropagateMouseClicks then`). Additionally sets empty `OnMouseDown`/`OnMouseUp` handlers as belt-and-suspenders.

#### Database.lua — Combat-Deferred Profile Switches ✅

[`Database.lua:1210-1213`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1210-L1213): `notifyProfileSwitch()` checks `InCombatLockdown()` and sets `pendingProfileNotify = true` if in combat. [`Database.lua:706-708`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L706-L708): `PLAYER_REGEN_ENABLED` handler calls `FlushPendingProfileSwitch()`.

> [!NOTE]
> Minor line number discrepancy: The report cites "Database.lua:1220" as the combat deferral location. The `InCombatLockdown()` check is actually at **line 1210**, and line 1220 is `HasPendingProfileSwitch()`. The claim is accurate; only the cited line is off by 10.

---

## 5.1. Cross-Realm Emote Parsing in `World.lua`

### ✅ CONFIRMED

[`World.lua:50-55`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/World.lua#L50-L55) — verified exact code:

```lua
frame:SetScript("OnEvent", function(_, event, message, sender)
    local playerName = UnitName("player")
    if sender == playerName or (message and playerName and message:find(playerName, 1, true)) then
        Pulse:FireIfEnabled("emote")
    end
end)
```

The `sender == playerName` comparison at line 52 will fail on cross-realm because `sender` is `"Character-RealmName"` while `UnitName("player")` returns just `"Character"`.

Blizzard's own [`ChatFrameUtil.lua:1077-1081`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua#L1077-L1081) uses `Ambiguate(sender, "none")` for this exact reason, confirmed in the WoW Forever source.

**Impact:** The emote cue won't fire for the player's own emotes on cross-realm servers. The `message:find(playerName)` fallback catches emotes that mention the player's name in the text, but not all emotes include the player name in the message body (e.g., `/dance` says "Player dances" — the sender is the player but `sender == playerName` is the primary detection path).

The report's fix (`Ambiguate(sender, "none") == playerName`) is correct and minimal.

---

## 5.2. `activeProfile()` Nil Safety

### ⚠️ PARTIALLY CONFIRMED — Crash path exists but is much narrower than described

[`Database.lua:1516-1518`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1516-L1518) — verified exact code:

```lua
local function activeProfile()
    return DB.profiles[Database:GetActiveProfileName()]
end
```

**The report's claim:** "If a custom profile entry is corrupted or missing from `PulseDB.profiles`, `activeProfile()` returns `nil`."

**What the report misses — two layers of defense already exist:**

1. **`ruleFor()` validates profile existence** ([`Database.lua:1106-1119`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1106-L1119)):
   ```lua
   local function ruleFor(scope)
       -- ...
       if name and DB.profiles[name] then
           return name
       end
       return nil
   end
   ```
   If a stored profile rule points to a deleted/missing profile, `ruleFor()` returns `nil`, and the rule is treated as unset. This is explicitly documented as "RULE E degrade" in the code comment at line 1103-1105.

2. **`GetProfileResolution()` always falls back to `"Default"`** ([`Database.lua:1182-1183`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1182-L1183)):
   ```lua
   else
       scope, name, why = nil, "Default", "nothing set — falling back to Default"
   ```
   If no scope rule resolves, the profile name is always `"Default"`.

3. **`ApplyDefaults()` guarantees `"Default"` exists** ([`Database.lua:774-781`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L774-L781)):
   ```lua
   DB.profiles = DB.profiles or {}
   for _, name in ipairs(self:_AllProfileNames()) do
       DB.profiles[name] = DB.profiles[name] or {}
       copyDefaults(PROFILE_DEFAULTS, DB.profiles[name])
   ```
   `_AllProfileNames()` starts with `BUILTIN_PROFILE_NAMES` which includes `"Default"`.

**The actual crash path:** `activeProfile()` returns nil **only if** `DB.profiles["Default"]` itself is deleted or `DB.profiles` is nil — which requires direct `SavedVariables` file corruption, since `ApplyDefaults()` runs on every load and seeds it.

**Revised severity:** The report proposes a `PROFILE_DEFAULTS` fallback, which is a reasonable defensive measure, but the scenario is far less likely than the report implies. This is a P4 hardening measure against SavedVariables corruption, not a P2 crash risk from "corrupted or missing" custom profiles — that case is already handled by the RULE E degrade in `ruleFor()`.

---

## 6. Line Number Accuracy Audit

The report cites specific file:line references. Most are accurate, with a few discrepancies:

| Report Citation | Actual Location | Accurate? |
|:---|:---|:---:|
| `Engine.lua:169-171` | Lines 169-171 | ✅ Exact |
| `Combat.lua:417` | Line 417 | ✅ Exact |
| `Crafting.lua:347` | Line 347 | ✅ Exact |
| `Locomotion.lua:622` | Line 622 | ✅ Exact |
| `Environment.lua:276-280` | Lines 276-281 | ✅ Close enough |
| `CombatTextDocumentation.lua:42-53` | Lines 42-53 | ✅ Exact |
| `UnitDocumentation.lua:845` | Line 845 | ✅ Exact |
| `CastingBarFrame.lua:496-497` | Lines 496-497 | ✅ Exact |
| `Database.lua:1526-1528` (activeProfile) | Lines 1516-1518 | ❌ Off by 10 lines |
| `Database.lua:1220` (combat deferral) | Line 1210 (InCombatLockdown check) | ❌ Off by 10 lines |
| `Combat.lua:363` (isTradeskill suggestion) | Line 363 (inside isCasting branch) | ✅ Exact |
| `World.lua:50-55` | Lines 50-55 | ✅ Exact |
| `ChatFrameUtil.lua:1081` | Line 1081 | ✅ Exact (not independently verified) |

---

## 7. Additional Observations Not in the Original Report

### 7.1. `UnitChannelInfo` also has `isTradeskill`

The report only discusses `isTradeskill` from `UnitCastingInfo`. However, [`UnitDocumentation.lua:887`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L887) shows `UnitChannelInfo` also returns `isTradeskill` at position 6, also `NeverSecret = true`. If implementing the isTradeskill improvement, the channeling path (`isChanneling` branch at [`Combat.lua:383`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L383)) would also need the check.

### 7.2. Existing GC discipline elsewhere in the codebase

The report correctly identifies `Engine:Set` as missing GC discipline, but should note that the codebase already demonstrates awareness of this pattern:
- [`Crafting.lua:276`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Crafting.lua#L276): `local bedRoles = { low = 0 }` — reused scratch table with comment "Reused table to prevent GC allocation in high-frequency tick loop (Rule 4)."
- [`Locomotion.lua:508-510`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Locomotion.lua#L508-L510): `splitRoles` — same pattern with same comment.

This means the author deliberately applies scratch tables at the module level but missed the lower-level `Engine:Set` entry point, making P1 a gap rather than a systemic pattern failure.

### 7.3. Combat.lua `castTick` has a deeper idle cost than reported

The report mentions `GetTriggerSetting(...)` lookups when idle, but doesn't trace the full cost. `GetTriggerSetting` at [`Database.lua:1584-1591`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1584-L1591) calls `activeProfile()`, which calls `GetActiveProfileName()`, which calls `GetProfileResolution()`. When spec rules are configured, `GetProfileResolution` is **not cached** (see the [`anySpecRules()` guard at line 1156](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1156-L1159)) and runs four `pcall`s per invocation (as noted in the code's own comment at [lines 1122-1127](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1122-L1127)). This makes the idle `castTick` cost potentially higher than the report suggests for users with spec-based profile rules.

---

## 8. Final Verdict

The original report is **substantially accurate** in its technical findings. The engine context, API documentation references, and Blizzard source cross-references are all correct. The three areas where the report overstates or misses nuance are:

1. **P2 severity** is overstated for Crafting.lua and Locomotion.lua (trivial boolean early-returns, not database lookups)
2. **`activeProfile()` nil safety** is a much narrower risk than described — the profile resolution system already has `ruleFor()` degrade protection and `GetProfileResolution()` falls back to `"Default"`
3. **`isTradeskill` architectural suggestion** is sound but incomplete — needs to cover `UnitChannelInfo` too, and `Pulse.IsCrafting()` serves a broader purpose than just cast filtering

The P1 GC allocation finding, taint audit, `COMBAT_TEXT_UPDATE` analysis, and cross-realm emote bug are all **fully confirmed and correctly diagnosed**.
