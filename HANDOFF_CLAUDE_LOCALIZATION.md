# HANDOFF: Complete Localization Integration for PulseHaptics

**Target Agent**: Claude Code Opus  
**Addon**: `PulseHaptics` (World of Warcraft Classic / WoW Forever)  
**Workspace Root**: `/home/deck/developer/wow/PulseSensation`  
**Target Client**: World of Warcraft `_classic_beta_` (Engine: Embedded Lua 5.1)  
**Date**: October 25, 2026  

---

## 1. Executive Summary & Objective

The localization team has completed the authoring, formatting, and signature verification for all **10 non-English World of Warcraft client localizations** (`deDE`, `esES`, `esMX`, `frFR`, `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`).

During recent engineering, the English source catalog ([`PulseHaptics/Locales/enUS.lua`](file:///home/deck/developer/wow/PulseSensation/PulseHaptics/Locales/enUS.lua)) expanded from **1,210 to 1,268 keys (+58 delta strings)** across newly refactored features (crafting cadences, spec profile sliders, UI badges, and category headers).

All 58 delta additions have been categorized, translated for all 10 locales, and staged in [`localization/batches/`](file:///home/deck/developer/wow/PulseSensation/localization/batches/).

### Primary Objectives
1. **Merge the 58 delta keys** into the 10 catalog files under `localization/catalogs/`, bringing each to exactly 1,268 entries (100% full coverage).
2. **Deploy the 10 completed catalogs** into the runtime addon directory at [`PulseHaptics/Locales/`](file:///home/deck/developer/wow/PulseSensation/PulseHaptics/Locales/).
3. **Register the catalogs in the addon manifest** ([`PulseHaptics/PulseHaptics.toc`](file:///home/deck/developer/wow/PulseSensation/PulseHaptics/PulseHaptics.toc)) in sequence directly below `Locales/enUS.lua`.
4. **Run the project test suite** ([`scripts/check-locales.py`](file:///home/deck/developer/wow/PulseSensation/scripts/check-locales.py) and [`scripts/test.sh`](file:///home/deck/developer/wow/PulseSensation/scripts/test.sh)) to guarantee zero syntax errors, zero missing keys, and 100% test passes.

---

## 2. Directory Structure & File Manifest

### Workspace Separation
- **`PulseHaptics/`**: Production addon directory. Until this handoff, this directory remained isolated. Only `enUS.lua` currently resides in `PulseHaptics/Locales/`.
- **`localization/`**: Dedicated localization workshop where translation batches and modular catalogs are developed, validated, and staged.

```
/home/deck/developer/wow/PulseSensation/
├── PulseHaptics/
│   ├── PulseHaptics.toc               # TOC manifest (Add catalog entries here)
│   ├── Core/
│   │   └── Locale.lua                 # Engine localization core (signature validation & fallback)
│   └── Locales/
│       └── enUS.lua                   # English source reference (1,268 keys)
│       └── <locale>.lua               # [TARGET DESTINATION for deployed catalogs]
│
├── localization/
│   ├── GLOSSARY.md                    # Blizzard official terms & trademark compendium
│   ├── BATCHES.md                     # Domain batch breakdown & progress matrix
│   ├── DELTA_ANALYSIS_REPORT.md       # Comprehensive breakdown of the 58 delta keys
│   ├── batches/
│   │   ├── batch7_engineering_delta_58.json     # Manifest of the 58 added keys
│   │   └── translated_<locale>_batch7.json      # Staged translations for the 58 keys (10 files)
│   ├── catalogs/
│   │   └── <locale>/<locale>.lua                # Staged catalogs (currently 1,210 baseline entries)
│   └── tools/
│       ├── merge_translations.py      # Thread-safe JSON batch-to-Lua merger
│       └── validate_catalog.py        # Lua 5.1 syntax and placeholder signature validator
│
└── scripts/
    ├── check-locales.py               # Addon catalog coverage tester (--require-complete)
    └── test.sh                        # Unified QA runner (luacheck + 14 offline Lua test suites)
```

---

## 3. Supported Locales & Inventory

| Locale Code | Language | WoW Locale Name | Staged Baseline (`catalogs/`) | Batch 7 Staging (`batches/`) | Target Deployed |
| :--- | :--- | :--- | :---: | :---: | :---: |
| `deDE` | German | Deutsch | 1,210 keys | 58 keys | `PulseHaptics/Locales/deDE.lua` (1,268) |
| `esES` | Spanish (Spain) | Español (España) | 1,210 keys | 58 keys | `PulseHaptics/Locales/esES.lua` (1,268) |
| `esMX` | Spanish (Latin America) | Español (Latinoamérica) | 1,210 keys | 58 keys | `PulseHaptics/Locales/esMX.lua` (1,268) |
| `frFR` | French | Français | 1,210 keys | 58 keys | `PulseHaptics/Locales/frFR.lua` (1,268) |
| `itIT` | Italian | Italiano | 1,210 keys | 58 keys | `PulseHaptics/Locales/itIT.lua` (1,268) |
| `ptBR` | Portuguese (Brazil) | Português (Brasil) | 1,210 keys | 58 keys | `PulseHaptics/Locales/ptBR.lua` (1,268) |
| `ruRU` | Russian | Русский | 1,210 keys | 58 keys | `PulseHaptics/Locales/ruRU.lua` (1,268) |
| `koKR` | Korean | 한국어 | 1,210 keys | 58 keys | `PulseHaptics/Locales/koKR.lua` (1,268) |
| `zhCN` | Simplified Chinese | 简体中文 | 1,210 keys | 58 keys | `PulseHaptics/Locales/zhCN.lua` (1,268) |
| `zhTW` | Traditional Chinese | 繁體中文 | 1,210 keys | 58 keys | `PulseHaptics/Locales/zhTW.lua` (1,268) |

---

## 4. Engineering Invariants & Safeguards

When integrating or testing, observe the following invariants enforced by `PulseHaptics`:

### Invariant 1: Positional Specifier Signature Parity
In `PulseHaptics/Core/Locale.lua`:
```lua
if signature(key) == signature(value) then
    clean[key] = value
end
```
Any format specifier tokens (`%s`, `%d`, `%.1f`, `%q`, `%%`) must appear in the exact same quantity, type, and sequence in both the key and the translated value. Any discrepancy causes the runtime engine to drop the translation and fall back to English. All 580 items across the 10 Batch 7 files have already passed this check.

### Invariant 2: Hardware Trademarks Remain Verbatim
Never localize hardware brand names or controller protocols:
- `Sony DualSense`, `DualShock 4`
- `Xbox`, `Xbox Wireless Controller`
- `8BitDo`, `8BitDo Ultimate / Pro 2`
- `Steam Deck`
- `Nintendo Switch Pro Controller`
- `XInput`, `Bluetooth`, `USB`, `Pulse`

### Invariant 3: Color Escape Code Balance
Any Blizzard color sequence `|c[0-9a-fA-F]{8}` must be terminated by a balancing `|r`. Never allow trailing open color tags.

### Invariant 4: Lua 5.1 Syntax Sandbox
The WoW client uses an embedded Lua 5.1 interpreter. Do not use Lua 5.2+ features (`goto`, bitwise operators `&`/`|`). All catalogs use standard ASCII/UTF-8 table registration:
```lua
local _, Pulse = ...
Pulse.Locale:Register("<locale>", {
    ["English Key"] = "Translated Value",
})
```

---

## 5. Step-by-Step Integration Runbook

Execute the following steps from the repository root: `/home/deck/developer/wow/PulseSensation`.

### Step 1: Merge Batch 7 into the 10 Catalogs
Run `merge_translations.py` for each of the 10 locales, followed immediately by `validate_catalog.py` to confirm that each catalog reaches exactly 1,268 entries with 0 missing keys:

```bash
cd /home/deck/developer/wow/PulseSensation

for loc in deDE esES esMX frFR itIT ptBR ruRU koKR zhCN zhTW; do
  echo "=========================================================="
  echo "Merging Batch 7 into ${loc}..."
  python3 localization/tools/merge_translations.py "${loc}" "localization/batches/translated_${loc}_batch7.json"
  echo "Validating ${loc}..."
  python3 localization/tools/validate_catalog.py "localization/catalogs/${loc}/${loc}.lua"
done
```

**Expected Output for Each Locale**:
- `Catalog entries: 1268`
- `Missing keys (will fall back to English): 0`
- `Translated coverage: 1268/1268 (100.0%)`
- `✓ All validation checks passed!`

---

### Step 2: Deploy Catalogs to Addon Runtime
Copy all 10 verified catalog files from `localization/catalogs/<locale>/<locale>.lua` into `PulseHaptics/Locales/<locale>.lua`:

```bash
for loc in deDE esES esMX frFR itIT ptBR ruRU koKR zhCN zhTW; do
  echo "Deploying ${loc}.lua to PulseHaptics/Locales/..."
  cp "localization/catalogs/${loc}/${loc}.lua" "PulseHaptics/Locales/${loc}.lua"
done
```

Verify that 11 files now exist in `PulseHaptics/Locales/` (`enUS.lua` + 10 target locales):
```bash
ls -1 PulseHaptics/Locales/
```

---

### Step 3: Register Catalogs in `PulseHaptics.toc`
Edit `PulseHaptics/PulseHaptics.toc`. 

Locate lines 32–34:
```toc
Core/Locale.lua
Locales/enUS.lua
```

Insert the 10 localized catalogs immediately below `Locales/enUS.lua`:
```toc
Core/Locale.lua
Locales/enUS.lua
Locales/deDE.lua
Locales/esES.lua
Locales/esMX.lua
Locales/frFR.lua
Locales/itIT.lua
Locales/ptBR.lua
Locales/ruRU.lua
Locales/koKR.lua
Locales/zhCN.lua
Locales/zhTW.lua
```

---

### Step 4: Addon Completeness & QA Verification

Run the project verification tools to validate full catalog integrity:

#### 1. Addon Locale Completeness Check
```bash
python3 scripts/check-locales.py --require-complete
```
*Verification standard: Exits with returncode 0. Every installed language reports 1,268 keys, 0 missing.*

#### 2. Offline Localization Test Harness
```bash
./scripts/test.sh -f localization-test
```
*Verification standard: Reports `PASS` across all 4,400+ localization checks with 0 failures.*

#### 3. Full QA Battery & Luacheck Analysis
```bash
./scripts/test.sh
```
*Verification standard: Static analysis (`luacheck`) and all 14 test suites pass cleanly with 0 failures.*

---

## 6. Rollback / Emergency Recovery

If any catalog requires restoration:
- Untracked files in `PulseHaptics/Locales/` can be removed via:
  ```bash
  git checkout -- PulseHaptics/PulseHaptics.toc
  rm -f PulseHaptics/Locales/{deDE,esES,esMX,frFR,itIT,ptBR,ruRU,koKR,zhCN,zhTW}.lua
  ```
- The staged baseline catalogs can always be restored from `localization/catalogs/<locale>/<locale>.lua`.

---

## 7. Reference Materials & Reusable Skill
- **Permanent Localization Reference Skill**: Installed at [`~/.gemini/config/skills/wow-addon-translator/`](file:///home/deck/.gemini/config/skills/wow-addon-translator/) with terminology compendiums, Blizzard spell ID mappings, and regional dialect invariants.
- **Delta Analysis**: Review [`localization/DELTA_ANALYSIS_REPORT.md`](file:///home/deck/developer/wow/PulseSensation/localization/DELTA_ANALYSIS_REPORT.md) for detailed descriptions of all 58 added keys.
