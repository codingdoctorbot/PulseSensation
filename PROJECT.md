# PROJECT.md — PulseHaptics Project Compendium

## 1. Project Overview & Vision
**PulseHaptics** (part of the `PulseSensation` suite) is an advanced, high-fidelity tactile vibration framework for World of Warcraft. It transforms combat impacts, spellcasting crescendos, shaped locomotion footfalls, flight turbulence, environmental weather, and user interface actions into granular, customizable controller rumble.

- **Primary Target Client**: World of Warcraft `_classic_beta_` ("WoW Forever", Interface `16001`, build `1.60.1.*`).
- **Compatibility Clients**: Interface `120100` (The War Within), `110200`, `110100`.
- **Supported Controllers**: Sony PlayStation DualSense & DualShock 4, Microsoft Xbox Wireless & Elite, Valve Steam Deck, Nintendo Switch Pro, and 8BitDo Ultimate / Pro 2.
- **Repository Root**: `/home/deck/developer/wow/PulseSensation/`
- **Current Version**: `0.4.0` (Full 11-language localization & full gamepad navigation).

---

## 2. Core Architecture & Subsystem Map

The codebase is organized into four main layers:

```
/home/deck/developer/wow/PulseSensation/
├── PulseHaptics/                      # Main Production Addon
│   ├── Core/                          # Engine, Database, Devices, Modes, Arbiter
│   ├── Modules/                       # Gameplay Event Listeners & Cues
│   ├── UI/                            # Settings Panel, Quick Setup, Game Menu, Minimap
│   ├── Locales/                       # All 11 Official Client Translations
│   └── Media/                         # Icons, Atlases, Background Textures
│
├── PulseChecklist/                    # In-Game QA Verification Checklist (190 Cues)
├── PulseDebug/                        # Real-Time Haptic Oscilloscope & Telemetry HUD
├── PulseProfileReview/                # Profile Comparison & Auditing Tool
├── localization/                      # Translation Batches, Tools & Catalogs
└── scripts/                           # Automated Verification & Test Battery
```

### Layer 1: Core Engine & Data (`PulseHaptics/Core/`)
* **`Init.lua`**: Addon initialization, module dependency graph, `/pulse` command dispatcher, and first-run wizard trigger.
* **`Engine.lua`**: High-performance continuous vibration engine running on a 60Hz tick. Features dual-motor role arbitration (High/Low frequency), soft breakaway floors for motor spin-up, exponential decay envelopes, and zero-deadband snap to eliminate motor stall whine.
* **`Database.lua`**: SavedVariables manager (`PulseDB`), 12 built-in profiles, custom profile slots, versioned data migrations (v1 → v12), and corrupt payload quarantine.
* **`Modes.lua`**: Catalog of 35 distinct vibration patterns (transients, impacts, continuous textures, pulses, and crescendos).
* **`Devices.lua`**: Pre-calibrated hardware profiles (DualSense, Xbox, Steam Deck, Switch Pro, 8BitDo) and 4 hardware motor schemas (`standard`, `high_only`, `low_only`, `inverted`).
* **`Arbiter.lua`**: Event arbitration and episode bus. Coalesces rapid multi-event bursts (vendor transactions, corpse looting, window transitions) to prevent machine-gun rumble overlap.
* **`Locale.lua`**: Dynamic runtime localization system with strict format signature validation and fallback.
* **`Registry.lua`**: Catalog of 190+ cues, category hierarchies, and page gates.

### Layer 2: Gameplay Modules (`PulseHaptics/Modules/`)
Event-driven modules that translate Blizzard API events into tactile cues:
* **Combat**: Weapon swings, crits, parries, blocks, damage taken, combo points, execute warnings.
* **Casting**: Build-up crescendo, channel hum, instant casts, cast completion, interruptions.
* **Locomotion**: Shaped footfalls with 6 physical surface timbres (Boot, Hoof, Paw, Heavy, Claw, Metal) and stereo left/right motor split.
* **Movement & Flight**: Mount gallop cadence, takeoff thrust, landing impacts, dragonriding turbulence.
* **Environment & Weather**: Rain patter, blizzard chatter, storm rumble, breath exhaustion, swimming fluid drag.
* **Tradeskills**: Crafting cadences, mining pick strikes, herbalism rustles, fishing bobber dips.
* **Interface & Controller UI**: Radial menus, dialog popups, soft-target locks.
* **Alerts & Tactical Radar**: Loss of control stuns, kick windows, boss telegraphs, threat transitions.
* **Windfury**: Standalone multi-strike proc tracking module for Shaman weapon imbues.

### Layer 3: Presentation & User Interface (`PulseHaptics/UI/`)
* **Settings Window (`UI/Panel/`)**: Full-featured settings interface with category master gates, collapsible sections, global search, and 100% gamepad navigation (`Gamepad.lua`, `Popup.lua`, `Rows.lua`, `Sidebar.lua`, `Spec.lua`, `Theme.lua`).
* **Quick Setup Wizard (`UI/QuickSetup.lua`)**: 6-step guided calibration wizard for hardware, master intensity, motor roles, continuous textures, profiles, and language selection.
* **Game Menu Integration (`UI/GameMenu.lua`)**: Taint-free docked banner above Blizzard's Escape menu featuring dynamic hardware button glyphs (PlayStation Square, Xbox X, Nintendo Switch Y).
* **Minimap Shortcut (`UI/Minimap.lua`)**: LDB-compatible minimap icon.

### Layer 4: Companion Diagnostic Addons
* **`PulseChecklist`**: Interactive in-game checklist to test and verify all 190 individual cues with export/import QA reports.
* **`PulseDebug`**: Floating or docked real-time oscilloscope (`/pulse scope`) showing RMS motor energy, saturation meters, and active haptic layer telemetry.
* **`PulseProfileReview`**: Visual tool for comparing cue states across profiles.

---

## 3. Key Specifications & Capabilities

| Metric | Specification |
| :--- | :--- |
| **Granular Haptic Cues** | **190+** distinct gameplay cues across 16 categories |
| **Pre-Tuned Profiles** | **12** built-in profiles (Default, 6 Dungeon specs, 3 Immersion specs, PvP, Raiding, Questing) |
| **Haptic Modes** | **35** dual-motor vibration shapes |
| **Supported Locales** | **11** official client languages (1,306 localized keys, 100% complete) |
| **Gamepad Navigation** | 100% controller navigable (D-Pad, bumpers, triggers, hotkey preview) |
| **Garbage Discipline** | **Zero table allocations** in 60Hz engine tick or high-frequency events |
| **Taint Safety** | 100% taint-immune; zero overrides on Blizzard secure frames or combat tables |

---

## 4. Slash Commands Reference

| Command | Action |
| :--- | :--- |
| `/pulse` or `/pulsehaptics` | Open the main Settings window |
| `/pulse setup` or `/pulsewizard` | Open the 6-step Quick Setup wizard |
| `/pulse scope` | Toggle the real-time haptic oscilloscope & telemetry HUD |
| `/pulse test <mode>` | Test a specific vibration mode (e.g. `thud`, `snap`, `wave`, `heartbeat`) |
| `/pulse enableall` | Enable all cues in the active profile |
| `/pulse disableall` | Disable all cues in the active profile |
| `/pulse stop` or `/pulse mute` | Immediately silence all active vibrations |
| `/pulse profile [name]` | Inspect or switch the active profile |
| `/pulse minimap` | Toggle the minimap icon |
| `/pulse debug` | Toggle debug logging to chat |
| `/pcheck` | Open PulseChecklist QA verification tool |
| `/pdebug` | Open PulseDebug diagnostic HUD |
| `/pulsereview` | Open PulseProfileReview auditing tool |

---

## 5. Development & Test Toolchain
All development is verified through automated test scripts:
```bash
# Run all 14 unit and smoke test suites
./scripts/test.sh

# Run fast test pass without linter
./scripts/test.sh -f

# Verify 100% translation coverage across all 11 languages
python3 scripts/check-locales.py --require-complete

# Format Lua code
stylua PulseHaptics/ PulseChecklist/ PulseDebug/ PulseProfileReview/
```
