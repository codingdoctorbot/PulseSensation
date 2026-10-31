#!/usr/bin/env python3
"""
Merges translated key-value pairs into the target catalog Lua file.
Ensures proper Lua 5.1 string escaping and calls validate_catalog.py.
"""

import sys
import os
import json
import re
import subprocess
import fcntl

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CATALOGS_DIR = os.path.join(BASE_DIR, "catalogs")

def escape_lua_str(s):
    # Escape backslashes, double quotes, and handle newlines
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", "\\n")
    s = s.replace("\r", "\\r")
    s = s.replace("\t", "\\t")
    return s

def unescape_lua_str(s):
    escape_map = {"\\": "\\", "\"": "\"", "\'": "\'", "n": "\n", "r": "\r", "t": "\t"}
    def repl(m):
        c = m.group(1)
        if c in escape_map:
            return escape_map[c]
        if c.isdigit():
            return chr(int(m.group(0)[1:]))
        return m.group(0)
    return re.sub(r"\\([\\\"'nrt]|\d{1,3})", repl, s)

def parse_existing_catalog(lua_path):
    entries = {}
    if not os.path.exists(lua_path):
        return entries
    pattern = re.compile(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"', re.DOTALL)
    with open(lua_path, "r", encoding="utf-8") as f:
        content = f.read()
    for m in pattern.finditer(content):
        k = unescape_lua_str(m.group(1))
        v = unescape_lua_str(m.group(2))
        entries[k] = v
    return entries

def write_catalog(locale_code, entries, lua_path):
    lines = [
        f'-- {locale_code} translation catalog for PulseHaptics.',
        f'-- English strings serve as stable keys. Untranslated entries fall back to enUS.',
        'local _, Pulse = ...',
        f'Pulse.Locale:Register("{locale_code}", {{'
    ]
    # Sort keys for deterministic output
    for k in sorted(entries.keys()):
        v = entries[k]
        escaped_k = escape_lua_str(k)
        escaped_v = escape_lua_str(v)
        lines.append(f' ["{escaped_k}"] = "{escaped_v}",')
    lines.append('})')
    lines.append('')

    with open(lua_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def main():
    if len(sys.argv) < 3:
        print("Usage: merge_translations.py <locale_code> <translations.json>")
        sys.exit(1)

    locale_code = sys.argv[1]
    json_path = sys.argv[2]

    lua_path = os.path.join(CATALOGS_DIR, locale_code, f"{locale_code}.lua")
    if not os.path.exists(os.path.dirname(lua_path)):
        print(f"Error: Directory for locale {locale_code} does not exist.")
        sys.exit(1)

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # data can be { "key": "value", ... } or { "items": [ { "source": ..., "target": ... } ] }
    new_pairs = {}
    if isinstance(data, dict):
        if "items" in data:
            for item in data["items"]:
                if "source" in item and "target" in item and item["target"]:
                    new_pairs[item["source"]] = item["target"]
        else:
            new_pairs = data

    lock_file = lua_path + ".lock"
    with open(lock_file, "w") as lock_fd:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        try:
            existing = parse_existing_catalog(lua_path)
            before_count = len(existing)
            existing.update(new_pairs)
            after_count = len(existing)

            write_catalog(locale_code, existing, lua_path)
            print(f"Updated {locale_code}.lua: {before_count} -> {after_count} entries (+{len(new_pairs)} updated)")
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)

    # Run validation
    validator = os.path.join(BASE_DIR, "tools", "validate_catalog.py")
    res = subprocess.run([sys.executable, validator, lua_path])
    if res.returncode != 0:
        print(f"Validation FAILED for {locale_code}!")
        sys.exit(1)

if __name__ == "__main__":
    main()
