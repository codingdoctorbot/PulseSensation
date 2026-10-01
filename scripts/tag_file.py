#!/usr/bin/env python3
"""
Sets native macOS Finder color tags (labels) on files via extended attributes.
Works on macOS 10.9 through modern macOS versions without extra dependencies.
"""
import os
import plistlib
import subprocess
import sys

COLOR_MAP = {
    "None": 0,
    "Gray": 1,
    "Green": 2,
    "Purple": 3,
    "Blue": 4,
    "Yellow": 5,
    "Red": 6,
    "Orange": 7,
}

TAG_NUM_MAP = {
    "None": 0,
    "Orange": 1,
    "Red": 2,
    "Yellow": 3,
    "Blue": 4,
    "Purple": 5,
    "Green": 6,
    "Gray": 7,
}


def set_finder_tag(filepath: str, tag_color: str = "Green") -> bool:
    if not os.path.exists(filepath):
        print(f"Error: file not found: {filepath}", file=sys.stderr)
        return False

    num = TAG_NUM_MAP.get(tag_color, 6)
    tag_str = f"{tag_color}\n{num}"
    plist_bytes = plistlib.dumps([tag_str], fmt=plistlib.FMT_BINARY)

    # 1. Modern macOS UserTags plist (Spotlight & Finder Tags)
    subprocess.run(
        ["xattr", "-w", "-x", "com.apple.metadata:_kMDItemUserTags", plist_bytes.hex(), filepath],
        check=True,
    )

    # 2. Classic 32-byte FinderInfo (Immediate Finder color dot in UI)
    c_idx = COLOR_MAP.get(tag_color, 2)
    finder_info = bytearray(32)
    finder_info[9] = c_idx * 2
    subprocess.run(
        ["xattr", "-w", "-x", "com.apple.FinderInfo", finder_info.hex(), filepath],
        check=True,
    )

    print(f"Tagged in Finder: [{tag_color}] {filepath}")
    return True


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/tag_file.py <filepath> [Color]")
        print("Colors: Green, Blue, Red, Orange, Yellow, Purple, Gray")
        sys.exit(1)

    target_path = sys.argv[1]
    chosen_color = sys.argv[2] if len(sys.argv) > 2 else "Green"
    set_finder_tag(target_path, chosen_color)
