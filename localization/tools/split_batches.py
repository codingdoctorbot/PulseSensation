#!/usr/bin/env python3
"""
Extracts the 1,210 strings from enUS.lua into 6 cleanly categorized batches (JSON format).
Each item contains:
- id: integer sequence
- source: exact English key
- signature: placeholder signature
- context: source file / section context
"""

import os
import re
import json

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ENUS_PATH = os.path.join(BASE_DIR, "../PulseHaptics/Locales/enUS.lua")
BATCHES_DIR = os.path.join(BASE_DIR, "batches")
os.makedirs(BATCHES_DIR, exist_ok=True)

def extract_signature(text):
    result = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == "%":
            if i + 1 < n and text[i+1] == "%":
                i += 2
            else:
                m = re.match(r"^%[-+ #0]*\d*\.?\d*([cdeEfgGiouXxqs])", text[i:])
                if m:
                    result.append(m.group(1))
                i += 1
        else:
            i += 1
    return ",".join(result)

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

def load_enus_keys():
    pattern = re.compile(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"', re.DOTALL)
    with open(ENUS_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    entries = []
    for m in pattern.finditer(content):
        k = unescape_lua_str(m.group(1))
        entries.append(k)
    return entries

def categorize_key(k):
    kl = k.lower()

    # Batch 2: Hardware, Controllers, Calibration
    if any(term in kl for term in [
        "controller", "dualsense", "dualshock", "xbox", "8bitdo", "steam deck", "switch pro",
        "deadzone", "calibration", "threshold test", "ramp", "gamepad", "stick", "d-pad", "thumbstick"
    ]):
        return 2

    # Batch 3: Combat, Weapons, Abilities, Spells
    if any(term in kl for term in [
        "combat", "swing", "windfury", "shield wall", "ice block", "divine shield", "turtle",
        "overpower", "execute", "riposte", "revenge", "crit", "spell", "channel", "interrupt",
        "threat", "taunt", "dodge", "parry", "block", "bleed", "off-hand", "main-hand", "dual-wield",
        "berserk", "stealth", "lethal", "damage taken"
    ]):
        return 3

    # Batch 4: Locomotion, World, Environment
    if any(term in kl for term in [
        "footfall", "footstep", "hoofbeat", "mount", "flight path", "taxi", "skyriding",
        "swim", "breath", "drown", "water", "buoyancy", "weather", "rain", "snow", "storm",
        "fall", "landing", "jump", "ping", "waypoint", "reticle", "interaction"
    ]):
        return 4

    # Batch 5: Economy, Social, Crafting, Interface
    if any(term in kl for term in [
        "craft", "profession", "recipe", "item", "bag", "bank", "vault", "loot", "merchant",
        "auction", "gold", "coin", "mail", "honor", "reputation", "emote", "party", "raid",
        "whisper", "guild", "shapeshift"
    ]):
        return 5

    # Batch 6: Advanced Motor & Timing, Guides
    if any(term in kl for term in [
        "hüllkurve", "envelope", "motor & timing", "s-curve", "frequency", "continuous texture",
        "lub-dub", "haptic", "low-motor", "high-motor", "duration", "fade", "detent", "bed alone",
        "**trigger**", "a **trigger** is an occasion", "guide"
    ]) or len(k) > 250:
        return 6

    # Batch 1: Core Navigation, UI Controls, Settings
    return 1

def main():
    keys = load_enus_keys()
    print(f"Loaded {len(keys)} keys from enUS.lua")

    batches = {1: [], 2: [], 3: [], 4: [], 5: [], 6: []}

    for idx, k in enumerate(keys, 1):
        cat = categorize_key(k)
        batches[cat].append({
            "id": idx,
            "source": k,
            "signature": extract_signature(k),
        })

    names = {
        1: ("batch1_ui_navigation.json", "Core Navigation & UI Controls"),
        2: ("batch2_hardware_calibration.json", "Hardware Presets & Calibration"),
        3: ("batch3_combat_abilities.json", "Combat Cues & Class Abilities"),
        4: ("batch4_world_locomotion.json", "World, Environment & Locomotion"),
        5: ("batch5_economy_social_crafting.json", "Economy, Social, Interface & Crafting"),
        6: ("batch6_motor_timing_guide.json", "Motor Tuning, Continuous Textures & Guide"),
    }

    for b_num, (filename, desc) in names.items():
        out_path = os.path.join(BATCHES_DIR, filename)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({
                "batch_id": b_num,
                "name": desc,
                "count": len(batches[b_num]),
                "items": batches[b_num]
            }, f, indent=2, ensure_ascii=False)
        print(f"Batch {b_num} ({desc}): {len(batches[b_num])} strings -> {filename}")

if __name__ == "__main__":
    main()
