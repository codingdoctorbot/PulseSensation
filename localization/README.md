# PulseHaptics Localization System

## 1. Overview & Supported Localizations

PulseHaptics supports all **11 official World of Warcraft client localizations**. English (`enUS`) is the source language and fallback baseline. The 10 localized target languages are:

| Code | Language | WoW Locale Name | Status |
| :--- | :--- | :--- | :--- |
| `enUS` | English (Source) | `enUS` / `enGB` | Complete (1,268 strings) |
| `deDE` | German | Deutsch | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `esES` | Spanish (Spain) | Español (España) | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `esMX` | Spanish (Latin America) | Español (Latinoamérica) | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `frFR` | French | Français | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `itIT` | Italian | Italiano | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `ptBR` | Portuguese (Brazil) | Português (Brasil) | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `ruRU` | Russian | Русский | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `koKR` | Korean | 한국어 | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `zhCN` | Simplified Chinese | 简体中文 | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |
| `zhTW` | Traditional Chinese | 繁體中文 | 100% Baseline (1,210/1,210) + Batch 7 Staged (58/58) |

---

## 2. Architecture & Division of Responsibility

- **Engineering & Code Integration**: Handled strictly by the code implementation team / ChatGPT. This includes `PulseHaptics/Core/Locale.lua`, UI binding hooks, TOC manifests, and runtime settings.
- **Localization Documents & Catalogs**: Handled here in `localization/`:
  - `localization/GLOSSARY.md`: Master multi-language glossary of protected brand names, official Blizzard spell/ability names, and haptic terminology.
  - `localization/BATCHES.md`: Breakdown and tracking of the 1,268 strings across 7 logical domains.
  - `localization/catalogs/<locale>/`: Modular translation files and release-ready Lua catalogs.
  - `localization/tools/validate_catalog.py`: Automated Lua 5.1 and placeholder signature verification.

---

## 3. Localization Rules & Strict Technical Invariants

### Invariant 1: Format Specifier Signature Parity
PulseHaptics' runtime engine enforces strict signature matching:
```lua
if signature(key) == signature(value) then
    clean[key] = value
end
```
If a key contains `%s (%d)`, the translation **must contain exactly `%s` and `%d` in that sequence**. Any missing, extra, or mismatched token causes the engine to reject the entry and silently fall back to English.

### Invariant 2: Brand & Hardware Trademarks Remain Intact
Do NOT translate or transliterate hardware trademarks:
- `Sony DualSense`, `DualShock 4`
- `Xbox`, `Xbox Wireless Controller`
- `8BitDo`, `8BitDo Ultimate / Pro 2`
- `Steam Deck`
- `Nintendo Switch Pro Controller`
- Protocol names: `XInput`, `Bluetooth`, `USB`

### Invariant 3: Official Blizzard Terminology
Never invent translations for abilities, spells, or core game systems. Always use official Blizzard localized terms from the WoW game client (documented in `GLOSSARY.md`).
Examples:
- *Windfury*: `deDE`: *Windzorn*, `frFR`: *Furie-des-vents*, `esES`/`esMX`: *Viento Furioso*, `ruRU`: *Неистовство ветра*, `koKR`: *질풍*, `zhCN`: *风怒*, `zhTW`: *風怒*.
- *Shield Wall*: `deDE`: *Schildwall*, `frFR`: *Mur protecteur*, `ruRU`: *Глухая оборона*, `zhCN`: *盾墙*.

### Invariant 4: Color Code & Markup Integrity
Blizzard UI color escape codes (`|cff38BDF8`, `|cffffd100`, `|r`) and Markdown tags (`**bold**`) must be preserved and balanced identically to the source text.

---

## 4. Subagent Model & Effort Strategy

Subagent execution follows strict sequential discipline (**one subagent at a time**):
1. **Linguistic Complexity & CJK / Russian**: Use high effort (`pro` or `inherit`) for Korean (`koKR`), Chinese (`zhCN`, `zhTW`), Russian (`ruRU`), and German (`deDE`) due to grammar, case inflections, and character encoding nuances.
2. **Romance Languages**: Use balanced effort (`flash`) for French (`frFR`), Spanish (`esES`, `esMX`), Italian (`itIT`), and Portuguese (`ptBR`).
3. **Automated Verification & Audits**: Use fast subagents (`flash_lite`) with `validate_catalog.py` to ensure 100% syntactic and signature compliance.
