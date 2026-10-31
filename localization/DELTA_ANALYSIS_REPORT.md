# PulseHaptics Engineering Delta Analysis Report (58 Keys)

**Source Catalog Growth**: 1,210 $\rightarrow$ 1,268 strings (+58 additions)  
**Reference Baseline**: `PulseHaptics/Locales/enUS.lua` vs. `localization/catalogs/deDE/deDE.lua`  
**Target Coverage**: All 10 client localizations (`deDE`, `esES`, `esMX`, `frFR`, `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`)  
**Artifact & Batch Manifest**: `localization/batches/batch7_engineering_delta_58.json`

---

## 1. Executive Summary

During recent engineering iterations of PulseHaptics, the English localization catalog grew by 58 keys (from 1,210 to 1,268). The additions encompass:
1. **Specialization Profile Configuration Engine (`UI/Panel/Spec.lua`)**: Tooltips, modulation multipliers, tempo scaling, and live haptic audition triggers.
2. **Crafting & Tradeskill System (`Modules/Crafting.lua`)**: Granular profession support for 15 primary and secondary trade skills.
3. **Category Disambiguation & Accessibility Headers (`Core/Registry.lua`)**: Disambiguating world/game-feel cues, casting, and accessibility options.
4. **Dual-Motor Hardware Channels (`Core/Devices.lua`)**: Explicit ergonomic labels for high-frequency (sharp buzz) and low-frequency (heavy rumble) motors.
5. **Scope Rules & Dynamic Inheritance (`Core/Database.lua`, `Core/Locale.lua`)**: Rule hierarchy across character and specialization boundaries.

All 58 strings have been extracted into `batch7_engineering_delta_58.json`, verified for placeholder signature and color tag compliance, translated into all 10 non-English World of Warcraft client languages, and compiled into individual `translated_<locale>_batch7.json` batch payloads.

---

## 2. Categorization Breakdown

| Category | Count | Source Files | Description |
| :--- | :---: | :--- | :--- |
| **Tradeskills & Professions** | 15 | `Modules/Crafting.lua`, `Core/CastActivity.lua` | Official Blizzard profession and tradeskill labels for custom crafting cadence cues. |
| **Specialization Tuning & Sliders** | 14 | `UI/Panel/Spec.lua` | Sliders for low/high motor multipliers, speed adjustment, rate throttles, mute/emphasis badges. |
| **UI Actions & Status Badges** | 12 | `UI/Panel/Spec.lua`, `UI/Panel/Rows.lua`, `UI/QuickSetup.lua` | Button actions (`Accept`, `Apply`, `Okay`, `Test`, `Detect`) and state indicators (`ACTIVE`, `MUTED`, etc.). |
| **Registry Feature Categories** | 10 | `Core/Registry.lua` | Subsystem category headers for accessibility, combat texture, flight, casting, and social cues. |
| **Profile Scopes & Inheritance** | 5 | `Core/Database.lua`, `Core/Locale.lua`, `UI/Panel/Spec.lua` | Rules governing profile fallbacks across character and class specialization scopes. |
| **Hardware Channels & Motors** | 2 | `Core/Devices.lua` | Descriptive ergonomic labels for the left (low motor) and right (high motor) rumble actuators. |
| **Total** | **58** | | |

---

## 3. Itemized Engineering Delta Catalog

### Category A: Tradeskills & Crafting Professions (15 Keys)
*Context: `Modules/Crafting.lua` routes trade skills by recipe ID to tailored tactile beds and strike cadences.*

| ID | English Key (`source`) | Sig | Provenance & Usage |
| :---: | :--- | :---: | :--- |
| **1215** | `Alchemy` | `""` | Primary profession: fluid brewing continuous bed (cadence 0.0) |
| **1217** | `Blacksmithing` | `""` | Primary profession: rhythmic heavy anvil hammer strikes (cadence 1.1) |
| **1220** | `Cooking` | `""` | Secondary profession: light rhythmic kitchen tick (cadence 0.9) |
| **1225** | `Enchanting` | `""` | Primary profession: continuous mystical hum bed (cadence 0.0) |
| **1226** | `Engineering` | `""` | Primary profession: fast mechanical gadget tick (cadence 2.2) |
| **1231** | `First Aid` | `""` | Secondary profession: bandage application subtle bed (cadence 0.0) |
| **1232** | `Fishing` | `""` | Secondary profession: water surface continuous bed (cadence 0.0) |
| **1235** | `Herbalism` | `""` | Gathering profession: gentle continuous harvesting bed (cadence 0.0) |
| **1237** | `Inscription` | `""` | Primary profession: quill and parchment delicate bed (cadence 0.0) |
| **1238** | `Jewelcrafting` | `""` | Primary profession: rapid precision gem cutting tick (cadence 2.6) |
| **1239** | `Leatherworking` | `""` | Primary profession: steady mallet and punch taps (cadence 1.4) |
| **1242** | `Mining` | `""` | Gathering profession: heavy rhythmic pickaxe strikes (cadence 1.6) |
| **1246** | `Other crafting` | `""` | Fallback for unmapped or generic crafting recipes (cadence 1.2) |
| **1250** | `Skinning` | `""` | Gathering profession: brisk rhythmic scraping tick (cadence 1.8) |
| **1253** | `Tailoring` | `""` | Primary profession: continuous smooth needlework bed (cadence 0.0) |

---

### Category B: Feature Registry & Subsystem Categories (10 Keys)
*Context: `Core/Registry.lua` defines category headers for settings navigation and radar filtering.*

| ID | English Key (`source`) | Sig | Provenance & Usage |
| :---: | :--- | :---: | :--- |
| **1218** | `Combat and life state` | `""` | `ALERT_STATE`: Combat entry/exit, critical health, and death state |
| **1219** | `Combat texture` | `""` | `COMBAT`: Continuous tactile bed sustained during active combat |
| **1227** | `Experimental (game-feel)` | `""` | `HEALTH`: Shortened header avoiding collision with "Defaults" button |
| **1233** | `Flight and mounts` | `""` | `FLIGHT`: Continuous textures for mounts, taxis, and Skyriding |
| **1234** | `Group and social` | `""` | `ALERT_SOCIAL`: Party invites, whispers, and emote feedback |
| **1248** | `PvP` | `""` | Tactical radar notifications for hostile player targets |
| **1254** | `Target and focus` | `""` | `ALERT_UNIT_WATCH`: Target acquisition, target death, and focus alerts |
| **1257** | `World (accessibility)` | `""` | `ALERT_WORLD`: Interaction prompts, vendor, quest, and map pins |
| **1258** | `World (game-feel)` | `""` | `WORLD`: Environmental ambience, weather textures, and footing |
| **1259** | `Your casting` | `""` | `ALERT_SELF_CAST`: Player spell cast lifecycle and channel ticks |

---

### Category C: Specialization Tuning, Sliders & Tooltips (14 Keys)
*Context: `UI/Panel/Spec.lua` provides per-specialization modulation dials and live preview controls.*

| ID | English Key (`source`) | Sig | Provenance & Usage |
| :---: | :--- | :---: | :--- |
| **1211** | ` (reported as "%s")` | `s` | Disambiguates an active device's raw reported name from preset |
| **1228** | `Feel %s` | `s` | Button label to audition the active mode assigned to cue `%s` |
| **1229** | `Feels like: %s` | `s` | Summary tooltip displaying the assigned vibration waveform mode |
| **1230** | `Fires at most %s.` | `s` | Throttle limit tooltip for high-frequency combat events |
| **1243** | `Multiplies %s's high-motor intensity. 1.0 is the authored default; the top of this slider is where it stops making any further difference.` | `s` | Slider tooltip: Right motor / high-frequency actuator gain |
| **1244** | `Multiplies %s's low-motor intensity. 1.0 is the authored default; the top of this slider is where it stops making any further difference.` | `s` | Slider tooltip: Left motor / low-frequency actuator gain |
| **1247** | `Play %s right now with whatever's currently set on its sliders above.` | `s` | Test button tooltip to immediately preview the tuned sensation |
| **1251** | `Spec %s` | `s` | Fallback label when specialization ID has no localized name |
| **1252** | `Speeds up or slows down %s as a whole — both its pulses and the gaps between them, so a multi-hit mode keeps its rhythm instead of the hits stretching into their own gaps. 1.0 is the authored default.` | `s` | Slider tooltip: Temporal envelope and pulse cadence multiplier |
| **1260** | `a ramp is currently running on %s, not %s` | `s,s` | Error status when attempting overlapping ramp calibrations |
| **1263** | `once every %d minutes` | `d` | Throttle description for minute-scale recurring alerts |
| **1264** | `once every %d seconds` | `d` | Throttle description for second-scale recurring alerts |
| **1267** | `\|cff888888Silences:\|r %s` | `s` | Colored UI badge listing suppressed cues when this cue triggers |
| **1268** | `\|cffffd100Emphasizes:\|r %s` | `s` | Colored UI badge listing prioritized cues when this cue triggers |

---

### Category D: Profile Scopes & Inheritance Fallback (5 Keys)
*Context: `Core/Database.lua` & `UI/Panel/Spec.lua` hierarchical profile inheritance.*

| ID | English Key (`source`) | Sig | Provenance & Usage |
| :---: | :--- | :---: | :--- |
| **1256** | `This specialization (%s)` | `s` | Capitalized scope dropdown label for current character spec |
| **1261** | `every character` | `""` | Global fallback scope applying to all characters on account |
| **1262** | `nothing set — falling back to Default` | `""` | Inheritance resolution diagnostic when no custom rule matches |
| **1265** | `this character` | `""` | Character-wide scope overriding account default across specs |
| **1266** | `this specialization (%s)` | `s` | Lowercase scope label used inline within status descriptions |

---

### Category E: Hardware Channels & Vibration Motors (2 Keys)
*Context: `Core/Devices.lua` motor channel mapping.*

| ID | English Key (`source`) | Sig | Provenance & Usage |
| :---: | :--- | :---: | :--- |
| **1236** | `High motor (sharp rumble)` | `""` | Right-side high-frequency ERM/LRA vibration channel label |
| **1240** | `Low motor (heavy rumble)` | `""` | Left-side low-frequency heavy counterbalance motor channel label |

---

### Category F: UI Navigation, Dialog Actions & Status Indicators (12 Keys)
*Context: Core UI widgets, dialog confirmations, and state badges.*

| ID | English Key (`source`) | Sig | Provenance & Usage |
| :---: | :--- | :---: | :--- |
| **1212** | `ACTIVE` | `""` | Uppercase badge indicating an active, firing profile/rule |
| **1213** | `Accept` | `""` | Standard dialog confirmation button |
| **1214** | `Active` | `""` | Title-case status indicating an enabled subsystem |
| **1216** | `Apply` | `""` | Settings commitment button |
| **1221** | `Detect` | `""` | Controller hardware polling trigger button |
| **1222** | `Disabled` | `""` | State label for inactive/suppressed features |
| **1223** | `Duration` | `""` | Slider header for temporal length configuration |
| **1224** | `Enabled` | `""` | State label for active features |
| **1241** | `MUTED` | `""` | Uppercase badge indicating a silenced sensory channel |
| **1245** | `Okay` | `""` | Modal dialog dismiss button |
| **1249** | `Ramp` | `""` | Calibration test pattern mode |
| **1255** | `Test` | `""` | Audition button label across settings rows |

---

## 4. Technical Invariant Verification

1. **Format Specifier Parity**:
   - 16 keys contain format tokens: 13 with single `%s`, 1 with `%s, %s`, and 2 with `%d`.
   - Verified across all 10 localized translation payloads (`translated_<locale>_batch7.json`).
   - Signature checks (`tools/validate_catalog.py`) confirmed **zero signature mismatches** across all 580 translated entries ($58 \times 10$).
2. **Color Escape Differential Balance**:
   - Keys **1267** (`|cff888888Silences:|r %s`) and **1268** (`|cffffd100Emphasizes:|r %s`) contain exact matching `|c...` open and `|r` close pairs.
   - Verified that no terminating `|r` was omitted in any locale, preventing frame text tint leaks.
3. **Hardware Trademarks**:
   - All controller and vendor brand names (`DualSense`, `Xbox`, `8BitDo`, `Steam Deck`, etc.) remain untranslated across all documents.
4. **Zero Runtime Addon Code Modification**:
   - In accordance with safety rules, no files under `PulseHaptics/` and no production catalogs under `localization/catalogs/` were modified.
   - Batch 7 translations are staged safely in `localization/batches/translated_<locale>_batch7.json` ready for scheduled integration.
