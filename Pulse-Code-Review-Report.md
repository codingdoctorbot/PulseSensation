# Pulse — Full Addon Code Review & Technical Audit (WoW Forever Verified)

**Date:** 2026-09-23  
**Target Client:** World of Warcraft `_classic_beta_` ("WoW Forever")  
**Engine & Build Version:** `1.60.1.69977` (Interface `120100` / Patch 12.1.0)  
**Verified Against:** `wow-ui-source-forever` (`1.60.1.69913` / `Blizzard_FrameXML`)  
**Repository:** `/Users/erik2/Developer/WoW/PulseSensation`  
**Static Analysis Result:** 0 errors / 0 warnings across 53 Lua source files (`luacheck`)

---

## 1. Executive Summary & Client Context

A common misconception when targeting "WoW Forever" (`_classic_beta_`) is treating it as an old Classic engine branch (e.g. 1.12 or 1.14/1.15). 

Inspection of `/Applications/World of Warcraft/.build.info` and the internal Blizzard interface source code at `wow-ui-source-forever` (`version.txt: 1.60.1.69913`) confirms:
- **WoW Forever is built on the modern 12.x / Midnight client engine (Interface `120100`) running a Classic-shaped roster.**
- The C-subsystems include modern APIs: `C_CombatText`, `C_Secrets` / `issecretvalue`, `C_LossOfControl`, `C_GamePad`, `C_PlayerInfo`, `C_TradeSkillUI`, and `C_Container`.
- Global math utilities `Clamp(val, min, max)` and `Lerp(from, to, factor)` exist as C-functions in the global namespace (capitalized), while `math.clamp` and `math.lerp` in the Lua standard table are nil.

This audit cross-references Pulse's source code against the live `wow-ui-source-forever` codebase to verify architectural claims, performance discipline, and engine compatibility.

---

## 2. Review of Earlier Hypotheses vs. Verified Engine Reality

Cross-referencing against Blizzard's source code yielded critical clarifications on earlier findings:

### 1. `COMBAT_TEXT_UPDATE` & `C_CombatText` (Clarified)
- **Earlier Hypothesis**: On Classic builds, `COMBAT_TEXT_UPDATE` might pass data directly as event arguments (`arg2 = data`), requiring a fallback if `C_CombatText` was missing.
- **Engine Source Truth** ([`CombatTextDocumentation.lua:42-53`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatTextDocumentation.lua#L42-L53)):
  ```lua
  Events = {
      {
          Name = "CombatTextUpdate",
          LiteralName = "COMBAT_TEXT_UPDATE",
          Payload = { { Name = "combatTextType", Type = "cstring", Nilable = false } }
      }
  }
  ```
  In WoW Forever, the event payload contains **only** `combatTextType`. There is **no `arg2` or `data` in the event payload**.
- **Blizzard Implementation** ([`Blizzard_CombatText/Shared/CombatText.lua:104`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_CombatText/Shared/CombatText.lua#L104)):
  ```lua
  elseif ( event == "COMBAT_TEXT_UPDATE" ) then
      data, arg3, arg4 = C_CombatText.GetCurrentEventInfo();
      messageType = arg1;
  ```
- **Verdict**: Pulse's commit `11622b7` (which switched to `pcall(C_CombatText.GetCurrentEventInfo)`) is **100% correct**. The returns of `GetCurrentEventInfo` are flagged `SecretReturns = true`, so Pulse's `issecretvalue(data)` and `issecretvalue(arg3)` checks are strictly required.

---

### 2. Crafting vs. Casting Detection: `isTradeskill` in `UnitCastingInfo` (New High-Value Discovery)
- **Context**: Pulse previously struggled with `Pulse.IsCrafting()` suppression where stale crafting states could accidentally silence normal spell casts (`castTexture`).
- **Engine Source Truth** ([`UnitDocumentation.lua:845`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L845) and [`CastingBarFrame.lua:496-497`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua#L496-L497)):
  ```lua
  local name, text, texture, startTime, endTime, isTradeSkill = UnitCastingInfo(self.unit);
  ```
  `UnitCastingInfo("player")` **return 6 is `isTradeSkill` (boolean)**, and in `UnitDocumentation.lua` it is explicitly declared:
  ```lua
  { Name = "isTradeskill", Type = "bool", Nilable = false, NeverSecret = true }
  ```
- **Architectural Solution**:
  In [`Combat.lua:363`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L363), instead of polling `Pulse.IsCrafting()` across modules, Pulse can directly read:
  ```lua
  local name, _, _, startTimeMs, endTimeMs, isTradeskill = UnitCastingInfo("player")
  if isTradeskill then
      return -- Native trade skill cast: let Crafting.lua handle it
  end
  ```
  This eliminates all cross-module state coupling, race conditions, and lingering crafting flags.

---

## 3. Confirmed Performance & Memory Findings (Rule 4 Audit)

### 🔴 P1. Hot Loop Garbage Allocation in `Engine:Set` / `Engine:Hold`
- **Location**: [`Pulse/Core/Engine.lua:169-171`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Engine.lua#L169-L171)
- **Analysis**:
  ```lua
  function Engine:Set(name, low, high, duration)
      return self:SetRoles(name, { low = low or 0, high = high or 0 }, duration)
  end
  ```
  `Engine:Hold` calls `Engine:Set`. Every continuous texture (`swimTexture`, `waterTexture`, `glideThrust`, `castTexture`, `lowHealthTexture`, `weatherTexture`) invokes `Pulse:HoldIfEnabled` on frame ticks.
  At 60–144 Hz, this creates **60 to 144 temporary tables per second per continuous cue**.
- **Fix**:
  Because `SetRoles` immediately iterates over `roles` and copies numeric values into `layer.roles`, hoisting a static reusable scratch table completely eliminates this allocation:
  ```lua
  local scratchRoles = {}
  function Engine:Set(name, low, high, duration)
      scratchRoles.low = low or 0
      scratchRoles.high = high or 0
      scratchRoles.ltrigger = nil
      scratchRoles.rtrigger = nil
      return self:SetRoles(name, scratchRoles, duration)
  end
  ```

---

### 🟡 P2. Idle `OnUpdate` Frame Ticking in Modules
- **Locations**:
  - `castFrame` in [`Pulse/Modules/Combat.lua:417`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L417)
  - `pollFrame` in [`Pulse/Modules/Crafting.lua:347`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Crafting.lua#L347)
  - `pollFrame` in [`Pulse/Modules/Locomotion.lua:622`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Locomotion.lua#L622)
- **Analysis**:
  When these cues are enabled in user settings, their frames register an `OnUpdate` handler continuously at 60–144 Hz even when idle:
  - `Combat.lua`: `castTick()` runs every tick doing `Pulse.Database:GetTriggerSetting(...)` lookups when neither casting nor channeling.
  - `Crafting.lua`: `tick()` runs every tick when `active == false`.
  - `Locomotion.lua`: `tick()` runs every tick when standing still (`isMoving == false`).
- **Ideal Model** ([`Pulse/Modules/Environment.lua:276-280`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Environment.lua#L276-L280)):
  `weatherFrame` attaches `OnUpdate` **only while weather intensity > 0**, and clears it (`nil`) when weather ceases.
- **Fix**:
  - `Combat.lua`: Set `OnUpdate` in `CastActivity:OnActivity` on `CAST_START`/`CHANNEL_START`; clear on completion/stop.
  - `Crafting.lua`: Set `OnUpdate` in `beginCraft()`; clear in `endCraft()`.
  - `Locomotion.lua`: Set `OnUpdate` on `PLAYER_STARTED_MOVING`; clear on `PLAYER_STOPPED_MOVING`.

---

## 4. Execution Taint & Combat Protection Audit (Rule 5)

A comprehensive audit against `wow-ui-source-forever` shows Pulse's taint defenses are exemplary:

| System | Implementation | Verification in `wow-ui-source-forever` |
|:---|:---|:---|
| **Controller UI** | Passive 20Hz poller in [`ControllerUI.lua`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/ControllerUI.lua) | Blizzard's `SmartNavigationMixin:UninitializeGamepad()` invokes `GamepadMode.DeactivateBindingGroup()` (protected C-call). Pulse registers no callbacks on `SmartNavigation`, keeping the stack 100% untainted. |
| **Dropdown Menus** | Custom multi-column palette in [`Popup.lua`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/UI/Panel/Popup.lua) | Blizzard's `MenuProxyMixin:OnShow` invokes `FrameControlsManager` which calls `SetOverrideBindingClick` (protected). Pulse's standalone popup completely avoids this path. |
| **Minimap Button** | Standalone frame in [`Minimap.lua`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/UI/Minimap.lua) | Calls `SetPropagateMouseClicks(false)` and `SetPropagateMouseMotion(false)`, preventing click-through to ping location attributes on the minimap underneath. |
| **Profile Switches** | Combat-deferred notifications in [`Database.lua:1220`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1220) | Checks `InCombatLockdown()` and defers all event re-bindings until `PLAYER_REGEN_ENABLED`. |

---

## 5. Functional & Logic Edge Cases

### 1. Cross-Realm Emote Parsing in `World.lua`
- **Location**: [`Pulse/Modules/World.lua:50-55`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/World.lua#L50-L55)
- **Analysis**:
  ```lua
  frame:SetScript("OnEvent", function(_, event, message, sender)
      local playerName = UnitName("player")
      if sender == playerName or (message and playerName and message:find(playerName, 1, true)) then
          Pulse:FireIfEnabled("emote")
      end
  end)
  ```
  In cross-realm zones, `sender` is formatted as `"Character-Realm"`, causing `sender == playerName` to evaluate to `false`.
- **Engine Source Truth** ([`ChatFrameUtil.lua:1081`](file:///Users/erik2/Developer/WoW/DevelopmentplusReference/Developer%20Documents/WOW%20SOURCECODE/wow-ui-source-forever/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua#L1081)):
  Blizzard uses `Ambiguate(sender, "none")` across the interface.
- **Fix**: Use `Ambiguate(sender, "none") == playerName`.

---

### 2. Nil Safety in `Database:activeProfile()`
- **Location**: [`Pulse/Core/Database.lua:1526-1528`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1526-L1528)
- **Analysis**:
  ```lua
  local function activeProfile()
      return DB.profiles[Database:GetActiveProfileName()]
  end
  ```
  If a custom profile entry is corrupted or missing from `PulseDB.profiles`, `activeProfile()` returns `nil`. Subsequent table accesses (`.triggers`, `.masterIntensity`) throw a fatal Lua error.
- **Fix**:
  ```lua
  local function activeProfile()
      local name = Database:GetActiveProfileName()
      local p = DB and DB.profiles and DB.profiles[name]
      if not p then
          p = DB and DB.profiles and DB.profiles["Default"]
      end
      return p or PROFILE_DEFAULTS
  end
  ```

---

## 6. Actionable Implementation Plan

| Step | Area | Target File | Impact |
|:---:|:---|:---|:---|
| **1** | **GC Optimization** | [`Core/Engine.lua:170`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Engine.lua#L170) | Hoist `scratchRoles` table to eliminate 60–144 allocations/sec. |
| **2** | **Casting Architecture** | [`Modules/Combat.lua:363`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/Combat.lua#L363) | Use return 6 (`isTradeskill`, `NeverSecret`) of `UnitCastingInfo` to decouple from `Pulse.IsCrafting()`. |
| **3** | **CPU Optimization** | `Combat.lua`, `Crafting.lua`, `Locomotion.lua` | Dynamically attach `OnUpdate` only when actively casting, crafting, or moving. |
| **4** | **Database Resilience** | [`Core/Database.lua:1526`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Core/Database.lua#L1526) | Add `"Default"` / `PROFILE_DEFAULTS` fallback to `activeProfile()`. |
| **5** | **Realm Parsing** | [`Modules/World.lua:52`](file:///Users/erik2/Developer/WoW/PulseSensation/Pulse/Modules/World.lua#L52) | Use `Ambiguate(sender, "none") == playerName`. |
