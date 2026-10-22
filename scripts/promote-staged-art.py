#!/usr/bin/env python3
"""Promote the approved staged artwork in Kapow/UnimplementedArt into the master Art/ pack.

    python3 scripts/promote-staged-art.py          # copy and merge
    python3 scripts/promote-staged-art.py --check  # report what would change, write nothing

Reads Kapow/UnimplementedArt/inventory.json. For every approved sequence it checks each
staged TGA against the inventory's SHA-256, copies the bytes unchanged to
Art/<category>/<message>_<1|2|3>.tga and adds the message to Art/_metadata/manifest.json with
its word, prompt and provenance (source batch, batch manifest, high-resolution source). The
staging folder is left as it is.

The five original orange alternatives (variant "original-orange") get their own keys,
escalation/<message>-orange, in their own category, so the selected recolors stay the
escalation defaults and random escalation picks are not weighted toward the duplicated words.

Nothing is overwritten: a destination file that exists with different bytes, or a key that is
already in the manifest with different frames, stops the run before anything is written.
Afterwards run scripts/make-art-catalog.py to regenerate Kapow/ArtCatalog.lua.
"""

import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "Art"
STAGING = ROOT / "Kapow" / "UnimplementedArt"
INVENTORY = STAGING / "inventory.json"
MANIFEST = ART / "_metadata" / "manifest.json"

ORANGE_CATEGORY = "escalation-orange"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def batch_entry(manifest_path, category, message):
    """The batch manifest's entry for one message, or {} when it cannot be found."""
    path = ROOT / manifest_path
    if not path.is_file():
        return {}
    entries = json.loads(path.read_text()).get("entries", [])
    for entry in entries:
        if entry.get("category") == category and entry.get("name") == message:
            return entry
    return {}


def plan():
    inventory = json.loads(INVENTORY.read_text())
    manifest = json.loads(MANIFEST.read_text())
    existing = {asset["key"]: asset for asset in manifest["assets"]}

    copies, assets, problems = [], [], []
    for item in inventory["assets"]:
        if item.get("approval_status") != "approved":
            problems.append(f"{item['key']} ({item.get('variant')}): not approved, skipped")
            continue
        category, message = item["key"].split("/", 1)
        orange = item.get("variant") == "original-orange"
        key = f"{item['key']}-orange" if orange else item["key"]
        listed_in = ORANGE_CATEGORY if orange else category

        frames = []
        for index, frame in enumerate(item["frames"], start=1):
            src = STAGING / frame["file"]
            if not src.is_file():
                problems.append(f"{key}: staged frame missing: {frame['file']}")
                continue
            if sha256(src) != frame["sha256"]:
                problems.append(f"{key}: {frame['file']} does not match the inventory hash")
                continue
            rel = f"{key}_{index}.tga"
            dst = ART / rel
            if dst.is_file() and sha256(dst) != frame["sha256"]:
                problems.append(f"{key}: Art/{rel} exists with different bytes; not overwritten")
                continue
            frames.append(rel)
            if not dst.is_file():
                copies.append((src, dst))
        if len(frames) != 3:
            continue

        if key in existing:
            if existing[key]["frames"] != frames:
                problems.append(f"{key}: already in the manifest with other frames")
            continue

        batch = batch_entry(item["source_manifest"], category, message)
        asset = {
            "key": key,
            "word": item["word"],
            "style": batch.get("palette") or batch.get("style") or "",
            "source_file": item["source_png"].removeprefix("Art/"),
            "generation_source": item["source_manifest"],
            "prompt": batch.get("prompt", ""),
            "categories": [listed_in],
            "frames": frames,
            "variant": item.get("variant", "selected"),
            "source_batch": item.get("source_batch"),
            "sha256": [frame["sha256"] for frame in item["frames"]],
        }
        if item.get("frame_size") and list(item["frame_size"]) != [256, 256]:
            asset["frame_size"] = list(item["frame_size"])
        assets.append((listed_in, asset))
    return manifest, copies, assets, problems


def main():
    check_only = "--check" in sys.argv[1:]
    manifest, copies, assets, problems = plan()

    for problem in problems:
        print("problem:", problem, file=sys.stderr)
    if any("not overwritten" in p or "other frames" in p or "hash" in p or "missing" in p for p in problems):
        print("stopped before writing anything", file=sys.stderr)
        return 1

    print(f"{len(copies)} TGA files to copy, {len(assets)} sequences to add to the manifest")
    if check_only:
        for _, asset in assets:
            print("  ", asset["key"], asset["word"])
        return 0

    for src, dst in copies:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)

    categories = manifest["categories"]
    for listed_in, asset in assets:
        manifest["assets"].append(asset)
        categories.setdefault(listed_in, [])
        if asset["key"] not in categories[listed_in]:
            categories[listed_in].append(asset["key"])

    keys = {asset["key"] for asset in manifest["assets"]}
    manifest["counts"] = {
        "unique_messages": len(keys),
        "frames_per_message": 3,
        "tga_files": 3 * len(keys),
        "category_memberships": sum(len(v) for v in categories.values()),
    }
    manifest["promoted_from_staging"] = {
        "inventory": str(INVENTORY.relative_to(ROOT)),
        "note": "Approved staged sequences copied byte for byte by scripts/promote-staged-art.py; "
        "orange originals listed as escalation/<message>-orange in the escalation-orange category.",
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"copied {len(copies)} files; manifest now lists {len(keys)} sequences")
    return 0


if __name__ == "__main__":
    sys.exit(main())
