# AGENT.md — PulseHaptics Engineering & Architecture Mandates

## 🚨 CRITICAL RULE #1: Target Environment & Client
**Target Client**: World of Warcraft `_classic_beta_` ("WoW Forever", `Camelot` branch, Interface `16001`, build `1.60.1.*`).
- **Engine Reality**: WoW Forever is a **modern Retail-variant client** built on Blizzard's modern engine (`C_Timer.After`, `C_Container.*`, `C_Item.*`, `EventRegistry`, `SmartNavigation` / `InputUtil` gamepad framework, modern secret-value / taint protections).
- **Source Code Storage Rule**: NEVER store or edit source code directly in the game's `Interface/AddOns/` directory. All source code and repositories MUST reside in `/home/deck/developer/wow/PulseSensation/`, connected to the game client via symbolic links:
  ```bash
  /home/deck/.local/share/Steam/steamapps/compatdata/2456904847/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/PulseHaptics -> /home/deck/developer/wow/PulseSensation/PulseHaptics
  ```

---

## 2. Lua Dialect & Sandbox Constraints
1. **Lua 5.1 Flavor**: Blizzard uses an embedded Lua 5.1 runtime. Never use Lua 5.2+ syntax (e.g., `goto`, native bitwise operators `&`/`|`). Use the built-in `bit` library (`bit.band`, `bit.bor`, `bit.lshift`) for bitwise logic.
2. **No Standard OS/IO**: The standard Lua libraries `io`, `os`, `package`, and `debug` are stripped from the WoW client for security. File I/O and network requests are strictly impossible.
3. **Data Persistence**: Data persistence is achieved exclusively via `SavedVariables` (`PulseDB`) declared in the `.toc` manifest and written on UI reload/logout.

---

## 3. Performance & Memory Discipline (Zero Garbage in Tight Loops)
- **Zero Allocations in High-Frequency Frames**: Never allocate tables (`{}`) inside `OnUpdate`, continuous oscillators, or heavy combat/locomotion events (`COMBAT_LOG_EVENT_UNFILTERED`).
- **Table Recycling**: Use table recycling pools and `wipe(tbl)` instead of instantiating new tables that trigger the Lua garbage collector and cause FPS stutters in raids and battlegrounds.
- **Event Registration**: Only register events the module actively requires (`RegisterEvent`). Unregister (`UnregisterEvent`) or pause `OnUpdate` scripts when UI frames or subsystems are hidden or inactive.

---

## 4. Execution Taint & Combat Protection
- **Zero Combat Taint**: Never write to or tamper with Blizzard protected tables or execution paths during combat.
- **Secure Action Buttons & Panels**: Modifying attributes or anchors on secure action buttons or protected Blizzard panels must be deferred when `InCombatLockdown()` is true.
- **Game Menu Integration**: Never modify Blizzard's internal `GameMenuFrame.buttons` or call `SmartNavigation_AddJumpNavigationOverride` on them. Modifying Blizzard's internal menu buttons taints them, causing `ADDON_ACTION_FORBIDDEN` and freezing the client in `FrameControlsManager`. Use the zero-taint `SetOverrideBindingClick` pattern parented to `UIParent`.
- **Hooking**: Always prefer `hooksecurefunc(table, "Method", hook)` or `hooksecurefunc("GlobalFunc", hook)` over raw function overwriting to preserve Blizzard execution integrity without taint.

---

## 5. UI Layout & Gamepad Navigation Rules
- **Sub-Target Left-to-Right Ordering**: On composite rows (like Cue Rows in `PulseHaptics/UI/Panel/Rows.lua`), sub-targets in `Gamepad.lua` must strictly follow visual left-to-right screen layout:
  1. `CHECK` (Checkbox / Toggle)
  2. `SLIDER` (Intensity Slider)
  3. `DROPDOWN` (Vibration Mode)
  4. `PLAY` (Try Texture Button `>`)
- **String Template Names for FontStrings**: Always pass string template names (e.g. `"GameFontHighlightSmall"`, `"GameFontNormal"`) to `CreateFontString(name, drawLayer, templateName)`. Never pass FontObject tables as the 3rd argument, as Blizzard's C engine expects string template names or nil.
- **Dynamic Controller Glyphs**: Adapt on-screen button prompts and legends dynamically to the active gamepad device (PlayStation Shapes `Square`/`Cross`, Xbox Letters `X`/`A`, Nintendo Reverse `Y`/`B`).

---

## 6. Localization Invariants & Quality Standards
- **Positional Specifier Parity**: Any format specifier tokens (`%s`, `%d`, `%.1f`, `%q`, `%%`) must appear in the exact same quantity, type, and sequence in both the English key and the translated value:
  ```lua
  if signature(key) == signature(value) then
      clean[key] = value
  end
  ```
- **Hardware Trademarks Remain Verbatim**: Never translate hardware names: `Sony DualSense`, `DualShock 4`, `Xbox`, `Steam Deck`, `Nintendo Switch Pro Controller`, `8BitDo`.
- **All 11 WoW Client Locales**: Maintain 100% full coverage across `enUS`, `deDE`, `esES`, `esMX`, `frFR`, `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, and `zhTW`.

---

## 7. Verification & Test Suite
Always run the offline verification suite before completing any engineering task:
```bash
cd /home/deck/developer/wow/PulseSensation
./scripts/test.sh
python3 scripts/check-locales.py --require-complete
```
