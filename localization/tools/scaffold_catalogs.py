#!/usr/bin/env python3
"""
Scaffolds all 10 target localization catalog files with proper Lua headers,
metadata, and locale registration.
"""

import os

LOCALES = [
    ("deDE", "German", "Deutsch"),
    ("esES", "Spanish (Spain)", "Español (España)"),
    ("esMX", "Spanish (Latin America)", "Español (Latinoamérica)"),
    ("frFR", "French", "Français"),
    ("itIT", "Italian", "Italiano"),
    ("ptBR", "Portuguese (Brazil)", "Português (Brasil)"),
    ("ruRU", "Russian", "Русский"),
    ("koKR", "Korean", "한국어"),
    ("zhCN", "Simplified Chinese", "简体中文"),
    ("zhTW", "Traditional Chinese", "繁體中文"),
]

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CATALOGS_DIR = os.path.join(BASE_DIR, "catalogs")

def main():
    for code, eng_name, native_name in LOCALES:
        loc_dir = os.path.join(CATALOGS_DIR, code)
        os.makedirs(loc_dir, exist_ok=True)
        lua_path = os.path.join(loc_dir, f"{code}.lua")

        if not os.path.exists(lua_path):
            content = f"""-- {native_name} ({eng_name}) translation catalog for PulseHaptics.
-- English strings serve as stable keys. Untranslated entries fall back to enUS.
local _, Pulse = ...
Pulse.Locale:Register("{code}", {{
    -- Translated strings will be added here in batches.
}})
"""
            with open(lua_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Created: {lua_path}")
        else:
            print(f"Exists: {lua_path}")

        # Also create a notes.md in each folder
        notes_path = os.path.join(loc_dir, "notes.md")
        if not os.path.exists(notes_path):
            with open(notes_path, "w", encoding="utf-8") as f:
                f.write(f"""# {native_name} ({code}) Localization Notes

- **Language**: {eng_name}
- **WoW Client Code**: `{code}`
- **Source Catalog**: `PulseHaptics/Locales/enUS.lua`
- **Glossary**: Refer to `../../GLOSSARY.md` for official Blizzard ability translations and protected hardware names.

## Guidelines & Typography
- Preserve all format specifiers (`%s`, `%d`, `%.1f`) in identical count and order.
- Preserve all color codes (`|cff...|r`) and markdown formatting (`**...**`).
- Do not translate hardware trademarks: DualSense, Xbox, Steam Deck, 8BitDo, Switch Pro.
""")
            print(f"Created: {notes_path}")

if __name__ == "__main__":
    main()
