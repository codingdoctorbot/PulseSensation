# PulseHaptics Translation Batches & Work Breakdown

To ensure high-effort, zero-shortcut translation of all 1,268 strings across 10 target localizations (total 12,680 strings), the catalog is divided into 7 modular, domain-specific batches.

Translating by domain preserves contextual nuance (e.g. knowing whether a word is an action button, a slider label, or a combat log event description).

---

## Batch Structure & Domain Breakdown

### Batch 1: Core Navigation & Interface Controls (661 strings)
- **Partitioned into**: Batch 1a (330 strings) & Batch 1b (331 strings).
- **Focus**: Root settings window, category navigation, Gamepad button prompts (`%s Activate • %s Categories`), dropdown options, profile management buttons, master enable/disable switches.
- **Key Challenges**: Keeping button action verbs concise and natural for controller tooltips.
- **Placeholder Safety**: Format sequences like `%s (%d)`, `%s Toggle • |cff38BDF8▶|r Next Control`.

### Batch 2: Hardware Presets & Controller Calibration (107 strings)
- **Focus**: Controller presets (DualSense, Xbox, 8BitDo, Steam Deck, Switch Pro), calibration test routines (Ramp test, Threshold test, Deadzone adjustment, Motor balance test).
- **Key Challenges**: Brand names must remain strictly untranslated (e.g. `8BitDo (Ultimate / Pro 2)`). Technical haptic terms (low motor, high motor, ramp, detent) must be translated idiomatically.
- **Protected Trademarks**: DualSense, Xbox, Steam Deck, 8BitDo, Switch Pro, XInput, Bluetooth.

### Batch 3: Combat Cues & Class Abilities (153 strings)
- **Focus**: Melee swings (main-hand, off-hand dual wield), spellcasting, Windfury extra attacks, lethal strike cues (Execute, Overpower), target death, defensive cooldown activations (Shield Wall, Ice Block, Divine Shield, Turtle, Cloak).
- **Key Challenges**: Strict adherence to Blizzard's official localized spell names as documented in `GLOSSARY.md`.
- **Special Mechanics**: Sub-50% weapon speed timing explanations, defensive cooldown impact cues.

### Batch 4: Locomotion, World & Environment (136 strings)
- **Focus**: Movement gait (footfalls on foot, hoofbeats mounted), flight path taxi rides, Skyriding / dragonriding ascend, swimming buoyancy, underwater breath depletion, drowning damage thud, weather textures (rain, snow, storm).
- **Key Challenges**: Evocative, sensory descriptions conveying physical weight and rhythm.
- **Blizzard Terminology**: Gathering nodes, mineral veins, herb nodes, skinning loot, flight paths, waypoint pins.

### Batch 5: Economy, Social, Interface & Crafting (108 strings)
- **Focus**: Bag item additions, personal & guild bank latch thuds, coin clinks on vendor transactions, auction house open, emote clicks, controller party targeting modifier, craft completion chimes, profession-specific work rhythms struck over continuous beds.
- **Key Challenges**: Distinction between bank vault doors vs regular UI clicks; profession work rhythms (Blacksmithing hammer vs Alchemy brewing).

### Batch 6: Advanced Motor & Timing, Continuous Textures & Guide (45 strings)
- **Focus**: Duration envelope sliders, S-curve multipliers, frequency response, continuous texture master toggles, guide articles explaining triggers vs modes and per-cue customization.
- **Key Challenges**: Technical acoustics/vibration terminology; multi-paragraph guide entries with Markdown bolding (`**trigger**`, `**mode**`).

### Batch 7: Engineering Delta Additions (58 strings)
- **Focus**: Additions from addon engineering refactoring (professions, UI status tags, templated dynamic cues, scope inheritance tags).
- **Key Challenges**: Strict placeholder parity (`s,s` on `a ramp is currently running on %s, not %s`; `%d` on `once every %d minutes`).
- **File**: `localization/batches/batch7_engineering_delta_58.json`.

---

## Batch Progress Matrix

| Batch | Description | Strings | deDE | frFR | esES | esMX | itIT | ptBR | ruRU | koKR | zhCN | zhTW |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **B1a** | Navigation & UI (Part 1) | 330 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **B1b** | Navigation & UI (Part 2) | 331 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **B2** | Hardware & Calibration | 107 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **B3** | Combat & Abilities | 153 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **B4** | World & Locomotion | 136 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **B5** | Economy, Social, Craft | 108 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **B6** | Motor, Tuning & Guide | 45 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **B7** | Engineering Delta (New) | 58 | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| **Total** | | **1,268** | **100%** | **100%** | **100%** | **100%** | **100%** | **100%** | **100%** | **100%** | **100%** | **100%** |

*(Note: Batches 1–6 [1,210 strings] are 100% complete and validated inside `localization/catalogs/`. Batch 7 [58 engineering delta strings] is 100% translated and validated in staging files `translated_<locale>_batch7.json`, ready for integration upon instruction).*
