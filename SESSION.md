# PulseSensation / PulseHaptics — Development Session Log

Engineering session log for `PulseSensation` (native controller haptic suite for WoW Forever).  
Current project state and architecture invariants: [`../HANDOFF.md`](../HANDOFF.md).  
Experimental Audio Haptics fork: [`../../SonicHaptics/HANDOFF.md`](../../SonicHaptics/HANDOFF.md).

---

## Session: October 2026 — v0.4.0 Release: Full 11-Language Localization & Polish

### 1. Goals & Accomplishments
- **Full Localization (v0.4.0)**:
  - Translated into all 11 World of Warcraft client languages: English (`enUS`), German (`deDE`), Spanish (`esES`), Latin American Spanish (`esMX`), French (`frFR`), Italian (`itIT`), Brazilian Portuguese (`ptBR`), Russian (`ruRU`), Korean (`koKR`), Simplified Chinese (`zhCN`), Traditional Chinese (`zhTW`).
  - 1,306 localized keys across every settings panel, quick setup wizard card, tooltip, profile, cue name, and chat string.
  - Built `scripts/check-locales.py` to enforce 100% key completeness and format specifier parity (`%s`, `%d`, etc.).
  - Added in-game language override dropdown in Quick Setup step 1 and Advanced Settings.
- **Quick Setup Dynamic Layout**:
  - Dynamically sized buttons and hint cards to accommodate variable text lengths in German, Russian, and French.
  - Step 5 profile review cards expand dynamically without text clipping.
- **Gamepad Navigation Refinements (`UI/Panel/Gamepad.lua`)**:
  - Full D-Pad horizontal sub-focus traversal across row elements: Checkbox $\to$ Slider $\to$ Mode Dropdown $\to$ Play button.
  - Dedicated Slider Adjust mode activated by **`A`** with golden glowing border and live vibration feedback.
  - Added lowermost dynamic controller button legend displaying native Blizzard controller button glyphs.
- **Game Menu Integration (`UI/GameMenu.lua`)**:
  - Clean docked banner parented to `UIParent` above `GameMenuFrame`.
  - Zero mutation of Blizzard's `GameMenuFrame.buttons` array, completely avoiding `ADDON_ACTION_FORBIDDEN` taint crashes.
- **Audio Haptics Exploration**:
  - Researched wideband multi-actuator crossover via audio loopback driver. Prototyped and branched into companion project `SonicHaptics` (`/home/deck/developer/wow/SonicHaptics`).
  - Confirmed native `C_GamePad.SetVibration` remains the primary daily-driver engine due to WoW's single-device audio output bleed and latency advantages.

---

## Session: October 2026 — v0.3.3 & v0.3.4 Maintenance & Safety
- **v0.3.4 Motor Ramping Safety**:
  - Added cancellation tokens so closing Advanced Settings immediately terminates running motor calibration ramps and multi-step cue previews.
- **v0.3.3 Guided Setup Wizard**:
  - Designed 6-step interactive first-run wizard (`UI/QuickSetup.lua`) with controller bumper navigation (`L1 / R1`) and live calibration.
