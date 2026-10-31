# HANDOFF — PulseHaptics

Last updated: **31 October 2026**  
Engineering rules: [`AGENT.md`](AGENT.md) · [`AGENTS.md`](AGENTS.md)  
Project compendium: [`PROJECT.md`](PROJECT.md) · User guide & overview: [`README.md`](README.md)  
Changelog: [`CHANGELOG.md`](CHANGELOG.md) · Localization handoff: [`HANDOFF_CLAUDE_LOCALIZATION.md`](HANDOFF_CLAUDE_LOCALIZATION.md)  

---

## 📍 Current Repository State (31 October 2026)

- **Repository**: `/home/deck/developer/wow/PulseSensation/` (symlinked at `/home/deck/developer/_from-mac/WoW/PulseSensation`)
- **Live Client Symlinks**:
  ```bash
  /home/deck/.local/share/Steam/steamapps/compatdata/2456904847/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/PulseHaptics -> /home/deck/developer/wow/PulseSensation/PulseHaptics
  /home/deck/.local/share/Steam/steamapps/compatdata/2456904847/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/PulseChecklist -> /home/deck/developer/wow/PulseSensation/PulseChecklist
  /home/deck/.local/share/Steam/steamapps/compatdata/2456904847/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/PulseDebug -> /home/deck/developer/wow/PulseSensation/PulseDebug
  /home/deck/.local/share/Steam/steamapps/compatdata/2456904847/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/PulseProfileReview -> /home/deck/developer/wow/PulseSensation/PulseProfileReview
  ```
- **Target Client**: **World of Warcraft `_classic_beta_` ("WoW Forever", Interface `16001`, build `1.60.1.*`)**. Modern Retail-variant client (`Camelot` branch).
- **SavedVariables**: `PulseDB` (persists global preferences and 12 profiles).
- **Current Version**: `0.4.0` (Tagged `v0.4.0` on `main`).
- **Test Status**: **100% green** (All 14 automated test suites in `./scripts/test.sh` pass cleanly; 100% localization coverage verified across all 11 client languages via `check-locales.py`).

---

## 🏗️ Completed Work Summary

### 1. Full Gamepad Navigation in Settings Panel (`UI/Panel/Gamepad.lua`, `Popup.lua`)
- **Horizontal Sub-Focus Within Rows**:
  - D-Pad Left/Right navigates across all interactive widgets on a single row in physical left-to-right order:
    $$\text{Checkbox (Toggle)} \longrightarrow \text{Slider (Intensity)} \longrightarrow \text{Dropdown (Vibration Mode)} \longrightarrow \text{Play Button } (>)$$
  - Pressing Left from the leftmost widget cleanly returns focus to the category sidebar.
  - Vertical navigation (Up/Down) preserves horizontal column index across adjacent rows.
- **Slider Intensity Adjust Mode**:
  - Pressing **`A`** on any slider enters adjust mode with a glowing golden focus ring (`Theme.COLOR_ACCENT` → gold).
  - D-Pad Left/Right adjusts intensity in $\pm 5\%$ increments with live tactile feedback at each step.
  - Pressing **`A`** or **`B`** commits the value and exits adjust mode.
  - Triggers **`L2 / R2`** (`LT / RT`) provide quick instant stepping at any time.
- **Dropdown List Navigation (`Popup.lua`)**:
  - Added `Popup.NavigateList(delta)` and `Popup.ConfirmList()`.
  - While a mode list is open, D-Pad Up/Down navigates entries with auto-scrolling and live haptic/audio previews. **`A`** confirms selection; **`B`** cancels.
- **Instant "Try Texture" Hotkey**:
  - Bound **`Square`** (PlayStation) / **`X`** (Xbox) anywhere on a cue row to immediately fire `tryTexture(row)`.
- **Dynamic Lowermost Bar Legend (`UI/Panel/Panel.lua`)**:
  - Contextual button legend on the bottom bar between `StatusBadge` and `CloseButton`.
  - Dynamically displays button prompts using real Blizzard controller glyphs (`|A:Gamepad_...|a`) based on active hardware.

### 2. Game Menu (Escape Menu) Integration (`UI/GameMenu.lua`)
- **Taint-Free Docked Banner**:
  - Parented to `UIParent` (strata `DIALOG`), sitting above `GameMenuFrame` (or stacked cleanly above companion crests).
  - Uses `SetOverrideBindingClick` on a separate capture button while the menu is up, clearing immediately on hide or combat onset.
  - Zero mutation of Blizzard's internal `GameMenuFrame.buttons`, eliminating `ADDON_ACTION_FORBIDDEN` and `FrameControlsManager` UI freeze crashes.
- **Dynamic Controller Hardware Detection**:
  - Detects active hardware via `InputDeviceIconSetManager` and `C_GamePad.GetDeviceMappedState`.
  - Dynamically renders PlayStation Shapes (`Square`), Xbox Letters (`X`), or Nintendo Reverse (`Y`) glyphs:
    - PlayStation: `Press [Square] to open settings`
    - Xbox: `Press [X] to open settings`
    - Nintendo: `Press [Y] to open settings`
- **Crash Prevention**:
  - Fixed `CreateFontString` bad argument error by strictly passing string template names (`"GameFontHighlightSmall"`, `"GameFontNormal"`) instead of FontObject tables.

### 3. Guided 6-Step Quick Setup Wizard (`UI/QuickSetup.lua`)
- Added an interactive first-run wizard (re-openable via `/pulse setup` or root page button):
  1. **Device Calibration & Breakaway Floor**: Hardware detection & motor spin-up calibration.
  2. **Master Intensity**: Baseline vibration volume slider.
  3. **Tactile Role Tuning**: Dual-motor balance between low and high frequency rumble.
  4. **Continuous Textures**: Tuning for swimming drag, weather patter, and spell hums.
  5. **Curated Profile Selection**: 12 pre-tuned profiles for raiding, dungeons, immersion, and PvP.
  6. **Completion & Language Picker**: One-click confirmation and dynamic locale selection.
- Responsive layout: Buttons auto-fit translated text and hint lines resize dynamically.
- Navigation via **`L1 / R1`** bumpers, **`A`** interact, and **`B`** / Escape cancel.

### 4. Complete 11-Language Localization (`Locales/`, `localization/`)
- Fully translated into all **11 World of Warcraft client languages**:
  - English (`enUS`), German (`deDE`), Spanish (`esES`), Latin American Spanish (`esMX`), French (`frFR`), Italian (`itIT`), Brazilian Portuguese (`ptBR`), Russian (`ruRU`), Korean (`koKR`), Simplified Chinese (`zhCN`), Traditional Chinese (`zhTW`).
- **1,306 localized keys** with 100% full coverage across every settings page, tooltip, profile, cue name, and chat string.
- Positional specifier parity enforced across all format tokens (`%s`, `%d`, `%.1f`).
- Automatic client language detection with an in-game language override dropdown in Quick Setup and Advanced Settings.

### 5. Windfury Proc Tracking & Experimental Tab
- Dedicated standalone tracking module for Shaman Windfury weapon imbues (`Modules/Combat.lua`).
- New "Experimental" tab in Settings for bleeding-edge combat triggers.

---

## ⚠️ Critical Gotchas & Architectural Invariants

1. **`CreateFontString` Template Strings**:
   Always pass a string template name as the 3rd argument to `CreateFontString` (e.g., `"GameFontHighlightSmall"`). Passing a FontObject table causes Blizzard's C engine to throw `bad argument #3 to 'CreateFontString'`.
2. **Sub-Target Row Traversal Order**:
   In `Gamepad.lua`, the sub-targets on cue rows MUST be inserted in strict visual left-to-right order:
   `CHECK` (1) → `SLIDER` (2) → `DROPDOWN` (3) → `PLAY` (4).
   Never invert `SLIDER` and `DROPDOWN`, or D-Pad navigation will jump backwards visually on screen.
3. **Never Mutate Blizzard GameMenu Buttons**:
   Never call `SmartNavigation_AddJumpNavigationOverride` on `GameMenuFrame.buttons`. Any modification of Blizzard's menu button tables taints execution paths during action bar styling and combat lockdown.
4. **Zero Garbage in 60Hz Engine Tick**:
   Never instantiate tables `{}` inside `Engine.lua:OnUpdate` or combat log event handlers. Always recycle tables via `wipe(tbl)`.
5. **Localization Format Token Parity**:
   Any added or modified localized string must preserve exact positional specifiers (`%s`, `%d`, etc.) in the exact same sequence, or `PulseHaptics/Core/Locale.lua` will discard the translation and fall back to English.

---

## 🧪 Verification & QA Commands

```bash
cd /home/deck/developer/wow/PulseSensation

# 1. Run all 14 offline unit and smoke test suites:
./scripts/test.sh

# 2. Verify complete 11-language coverage (0 missing keys across 1,306 entries):
python3 scripts/check-locales.py --require-complete

# 3. Format Lua source:
stylua PulseHaptics/ PulseChecklist/ PulseDebug/ PulseProfileReview/
```

---

## 🎯 Next Steps & Roadmap
1. **In-Game Verification on Steam Deck Hardware**:
   - Verify built-in Steam Deck haptics vs external Bluetooth controllers (DualSense & Xbox Wireless).
   - Confirm Game Menu banner visual anchoring above the Escape dialog.
2. **Release Distribution**:
   - Re-build release package via `./scripts/test.sh -p` to update `dist/PulseHaptics-v0.4.0.zip`.
   - Publish v0.4.0 release notes on CurseForge and Wago.
