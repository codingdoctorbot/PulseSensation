#!/usr/bin/env python3
"""Check English source keys and locale catalogs. --update-english adds missing keys only.

A translation file uses the same English keys as Locales/enUS.lua and calls
Pulse.Locale:Register("frFR", {...}). Load it after enUS.lua in the addon TOC.
This tool never reads or changes the separate localization/ translation workspace.
"""
from pathlib import Path
import argparse
import json
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
ADDON = ROOT / "PulseHaptics"
LEXER = re.compile(r'--\[(=*)\[.*?\]\1\]|--[^\n]*|\[(=*)\[.*?\]\2\]|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_][A-Za-z_0-9]*|\.\.|==|~=|[^\s]', re.S)
FIELDS = {"label", "desc", "caveat", "summary", "emphasizes", "silences", "heading", "body", "title", "tooltip", "buttonText", "description"}
MAPS = {"CATEGORY_LABELS", "CHANNEL_LABELS", "BUILTIN_PROFILE_NAMES"}


def tokens(text):
    return [m.group() for m in LEXER.finditer(text) if not m.group().startswith("--")]


def is_literal(token):
    return token.startswith(('"', "'")) or bool(re.match(r'^\[=*\[', token))


def decode(raw):
    if raw[0] == '[':
        match = re.match(r'\[(=*)\[', raw)
        value = raw[match.end():-len(match.group(1))-2]
        return value[1:] if value.startswith('\n') else value
    escapes = {'n': '\n', 'r': '\r', 't': '\t', 'a': '\a', 'b': '\b', 'f': '\f', 'v': '\v', '\\': '\\', '"': '"', "'": "'", '\n': '\n'}
    return re.sub(r'\\(\d{1,3}|.)', lambda m: chr(int(m[1])) if m[1].isdigit() else escapes.get(m[1], m[1]), raw[1:-1], flags=re.S)


def catalog(path):
    ts = tokens(path.read_text())
    entries, duplicates = {}, []
    for i in range(len(ts)-4):
        if ts[i] == '[' and is_literal(ts[i+1]) and ts[i+2:i+4] == [']', '='] and is_literal(ts[i+4]):
            key, value = decode(ts[i+1]), decode(ts[i+4])
            if key in entries:
                duplicates.append(key)
            entries[key] = value
    return entries, duplicates


def source_keys():
    found = set()
    for path in sorted(ADDON.rglob('*.lua')):
        if any(part in ('Libs', 'Locales') for part in path.parts) :
            continue
        ts = tokens(path.read_text())
        i = 0
        map_depth = 0
        while i < len(ts):
            if i >= 2 and ts[i] == '{' and ts[i-1] == '=' and ts[i-2] in MAPS:
                map_depth = 1
            elif map_depth and ts[i] == '{':
                map_depth += 1
            elif map_depth and ts[i] == '}':
                map_depth -= 1
            if not is_literal(ts[i]):
                i += 1
                continue
            end, pieces = i, [decode(ts[i])]
            while end+2 < len(ts) and ts[end+1] == '..' and is_literal(ts[end+2]):
                end += 2
                pieces.append(decode(ts[end]))
            value = ''.join(pieces)
            field = path.name != 'Locale.lua' and i >= 2 and ts[i-1] == '=' and ts[i-2] in FIELDS
            call = i >= 2 and ts[i-1] == '(' and ts[i-2] in ('L', 'Text')
            welcome = i >= 2 and ts[i-1] == '(' and ts[i-2] == '=' and i >= 3 and ts[i-3] == 'BODY_TEXT'
            if field or call or welcome or (map_depth and (i == 0 or ts[i-1] != '[')):
                if value:
                    found.add(value)
            i = end+1
    return found


def signature(text):
    return re.findall(r'%(?:%|[-+ #0]*\d*\.?\d*([cdeEfgGiouXxqs]))', text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--update-english', action='store_true', help='append newly referenced English keys; retain existing keys')
    parser.add_argument('--require-complete', action='store_true', help='require every installed translation to cover every English key')
    args = parser.parse_args()
    toc_paths = {line.strip().replace("\\", "/") for line in (ADDON / "PulseHaptics.toc").read_text().splitlines()}
    english_path = ADDON / 'Locales/enUS.lua'
    english, duplicates = catalog(english_path)
    required = source_keys()
    missing = required - english.keys()
    if args.update_english and missing:
        # Existing keys remain stable for work-in-progress translation catalogs.
        english.update({key: key for key in missing})
        english_path.write_text('-- English source catalog. Keys are the authored English text.\n-- Run python3 scripts/check-locales.py --update-english after adding UI text.\nlocal _, Pulse = ...\nPulse.Locale:Register("enUS", {\n' + ''.join(' [' + json.dumps(k, ensure_ascii=False) + '] = ' + json.dumps(v, ensure_ascii=False) + ',\n' for k, v in sorted(english.items())) + '})\n')
        print(f'Added {len(missing)} English keys; retained all existing keys.')
        missing = set()
    errors = []
    if duplicates:
        errors.append(f'{len(duplicates)} duplicate English keys')
    errors.extend(f'Missing English key: {key!r}' for key in sorted(missing))
    errors.extend(f'English value differs from its key: {key!r}' for key, value in english.items() if key != value)
    print(f'English: {len(english)} keys; {len(required)} referenced source strings; {len(missing)} missing.')
    for path in sorted((ADDON / 'Locales').glob('*.lua')):
        if path == english_path:
            continue
        if f"Locales/{path.name}" not in toc_paths:
            errors.append(f"{path.name}: catalog is not listed in PulseHaptics.toc")
        ts = tokens(path.read_text())
        declared = [decode(ts[i+2]) for i in range(len(ts)-2) if ts[i] == "Register" and ts[i+1] == "(" and is_literal(ts[i+2])]
        if declared != [path.stem]:
            errors.append(f"{path.name}: Register locale must match the filename")
        values, repeated = catalog(path)
        if repeated:
            errors.append(f'{path.name}: duplicate keys')
        for key, value in values.items():
            if key not in english:
                errors.append(f'{path.name}: unknown English key {key!r}')
            if not value or signature(key) != signature(value):
                errors.append(f'{path.name}: empty value or format mismatch for {key!r}')
        uncovered = english.keys() - values.keys()
        if args.require_complete and uncovered:
            errors.append(f'{path.name}: {len(uncovered)} untranslated keys')
        print(f'{path.name}: {len(values)} translated keys; {len(uncovered)} use English fallback.')
    for error in errors:
        print('ERROR:', error, file=sys.stderr)
    return bool(errors)


if __name__ == '__main__':
    sys.exit(main())
