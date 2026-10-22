"""Copy the ten user-reviewed banners into Kapow's separate unimplemented art folder."""

import hashlib
import json
from pathlib import Path
import shutil
import struct


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
BATCHES = ROOT / "_batches"
DEST = REPO / "Kapow" / "UnimplementedArt"
SELECTION = [
    ("first-blood", "FIRST BLOOD!", "2026-10-21-recolor-01"),
    ("triple-kill", "TRIPLE KILL!", "2026-10-21-batch-01"),
    ("mega-kill", "MEGA KILL!", "2026-10-21-batch-01"),
    ("ultra-kill", "ULTRA KILL!", "2026-10-21-recolor-01"),
    ("monster-kill", "MONSTER KILL!", "2026-10-21-recolor-01"),
    ("ludicrous-kill", "LUDICROUS KILL!", "2026-10-21-recolor-01"),
    ("killing-spree", "KILLING SPREE!", "2026-10-21-batch-02"),
    ("dominating", "DOMINATING!", "2026-10-21-recolor-01"),
    ("unstoppable", "UNSTOPPABLE!", "2026-10-21-batch-02"),
    ("godlike", "GODLIKE!", "2026-10-21-batch-02"),
]
ORANGE_ALTERNATES = [
    ("first-blood", "FIRST BLOOD!", "2026-10-21-batch-01"),
    ("ultra-kill", "ULTRA KILL!", "2026-10-21-batch-01"),
    ("monster-kill", "MONSTER KILL!", "2026-10-21-batch-01"),
    ("ludicrous-kill", "LUDICROUS KILL!", "2026-10-21-batch-02"),
    ("dominating", "DOMINATING!", "2026-10-21-batch-02"),
]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    # Preflight all source headers and destination conflicts before any copy.
    planned = []
    entries = []
    selections = [(name, word, batch, Path("."), "selected") for name, word, batch in SELECTION]
    selections += [(name, word, batch, Path("original-orange"), "original-orange") for name, word, batch in ORANGE_ALTERNATES]
    for name, word, batch, prefix, variant in selections:
        item = {
            "key": "escalation/" + name,
            "word": word,
            "variant": variant,
            "source_batch": batch,
            "source_manifest": str((BATCHES / batch / "manifest.json").relative_to(REPO)),
            "source_png": str((BATCHES / batch / "_sources" / "escalation" / (name + ".png")).relative_to(REPO)),
            "approval_status": "approved",
            "implemented": False,
            "frames": [],
        }
        for frame in (1, 2, 3):
            asset_relative = Path("escalation") / f"{name}_{frame}.tga"
            relative = prefix / asset_relative
            source = BATCHES / batch / asset_relative
            data = source.read_bytes()
            assert len(data) >= 18, source
            width, height = struct.unpack_from("<HH", data, 12)
            assert data[2] == 2 and data[16] == 32, source
            assert (width, height) == (256, 256), source
            assert data[17] & 15 == 8, source
            target = DEST / relative
            if target.exists() and target.read_bytes() != data:
                raise RuntimeError(f"Refusing to overwrite different existing artwork: {target}")
            planned.append((source, target, digest(data)))
            item["frames"].append({"file": str(relative), "sha256": digest(data)})
        entries.append(item)

    for source, target, expected in planned:
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copy2(source, target)
        assert digest(target.read_bytes()) == expected, target

    inventory = {
        "description": "User-reviewed unimplemented artwork from batches 01 and 02, using five approved recolors and retaining all five original orange alternatives.",
        "format": "Uncompressed 256x256 32-bit RGBA TGA",
        "frame_order": ["onset", "peak", "aftershock"],
        "message_count": len(SELECTION),
        "sequence_count": len(entries),
        "alternate_orange_sequences": len(ORANGE_ALTERNATES),
        "frame_count": len(planned),
        "implemented": False,
        "known_limitations": ["DOMINATING recolor retains small teal slivers near frame edges after one targeted cleanup. Both edit versions and all original artwork are preserved in source batches."],
        "approval_evidence": ["User: looks good after done export as usual and follow the naming conventions (copy to addon folder (tho new folder) unimplemented art", "User: maybe also keep all orange copies as well they also look good enough, waste of compute not to save it"],
        "assets": entries,
    }
    (DEST / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
    (DEST / "README.md").write_text(
        "# Unimplemented art\n\n"
        "Ten user-reviewed escalation banners plus five alternate orange versions, "
        "three frames each (45 TGA files). The five approved recolors are selected.\n\n"
        "Files: `escalation/<message>_1.tga` through `_3.tga`. "
        "Frame order: onset, peak, aftershock. Each is an uncompressed 256x256 32-bit RGBA TGA with alpha.\n\n"
        "The five original orange alternatives are in `original-orange/escalation/`, "
        "with identical logical filenames. TRIPLE KILL, MEGA KILL and KILLING SPREE already "
        "retain their original orange art in the primary escalation folder. All originals "
        "also remain intact in their source batches.\n\n"
        "These files are packaged for future integration. They are not registered in ArtCatalog, "
        "referenced by the TOC, or connected to events/triggers.\n\n"
        "`inventory.json` records selected source batches, original PNG/prompt manifest paths, "
        "and copied-file hashes. High-resolution PNGs and comparison sheets stay in "
        "`Art/_batches/` at repository root.\n"
    )
    print(json.dumps({"folder": str(DEST), "messages": len(SELECTION), "sequences": len(entries), "frames": len(planned), "copies_verified": True}))


if __name__ == "__main__":
    main()
