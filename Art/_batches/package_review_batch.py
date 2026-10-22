"""Copy a user-approved batch into the separate unimplemented-art collection."""

import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys


REPO = Path(__file__).resolve().parents[2]
BATCHES = REPO / "Art/_batches"
DEST = REPO / "Kapow/UnimplementedArt"


def save(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def main(batch_name):
    batch = BATCHES / batch_name
    manifest_file = batch / "manifest.json"
    manifest = json.loads(manifest_file.read_text())
    inventory_file = DEST / "inventory.json"
    inventory = json.loads(inventory_file.read_text())
    additions, copies = [], []
    for entry in manifest["entries"]:
        category, name = entry["category"], entry["name"]
        declared_size = entry.get("frame_size", [256, 256])
        frame_size = (declared_size, declared_size) if isinstance(declared_size, int) else tuple(declared_size)
        assert frame_size in ((256, 256), (512, 512)), frame_size
        item = {
            "key": f"{category}/{name}", "word": entry["word"],
            "variant": "selected", "source_batch": batch_name,
            "source_manifest": str(manifest_file.relative_to(REPO)),
            "source_png": str((batch / entry["source"]).relative_to(REPO)),
            "approval_status": "approved", "implemented": False, "frames": [],
            "frame_size": list(frame_size),
        }
        assert len(entry["frames"]) == 3
        for index, relative in enumerate(entry["frames"], 1):
            assert relative == f"{category}/{name}_{index}.tga", relative
            source, target = batch / relative, DEST / relative
            data = source.read_bytes()
            assert data[2] == 2 and data[16] == 32 and data[17] & 15 == 8, source
            assert struct.unpack_from("<HH", data, 12) == frame_size, source
            if target.exists() and target.read_bytes() != data:
                raise RuntimeError(f"Refusing to overwrite different artwork: {target}")
            digest = hashlib.sha256(data).hexdigest()
            copies.append((source, target, digest))
            item["frames"].append({"file": relative, "sha256": digest})
        additions.append(item)

    for asset in inventory["assets"]:
        asset.setdefault("frame_size", [256, 256])
    existing = {(a["key"], a["variant"]): a for a in inventory["assets"]}
    for item in additions:
        identity = (item["key"], item["variant"])
        if identity in existing and existing[identity] != item:
            raise RuntimeError(f"Conflicting inventory entry: {identity}")
        existing[identity] = item
    for source, target, digest in copies:
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copy2(source, target)
        assert hashlib.sha256(target.read_bytes()).hexdigest() == digest, target

    inventory["assets"] = list(existing.values())
    inventory["message_count"] = len({a["key"] for a in inventory["assets"]})
    inventory["sequence_count"] = len(inventory["assets"])
    inventory["frame_count"] = sum(len(a["frames"]) for a in inventory["assets"])
    sizes = sorted({tuple(a.get("frame_size", [256, 256])) for a in inventory["assets"]})
    inventory["format"] = "Uncompressed 32-bit RGBA TGA; per-asset frame_size, default256x256"
    inventory["description"] = "User-approved artwork packaged separately for future integration; original orange alternatives retained."
    evidence = f"User approved {batch_name} with: approve"
    if evidence not in inventory["approval_evidence"]:
        inventory["approval_evidence"].append(evidence)
    save(inventory_file, inventory)

    readme = DEST / "README.md"
    content = readme.read_text().split("\n\n")
    content[1] = (
        f"{inventory['message_count']} user-reviewed messages, {inventory['sequence_count']} three-frame sequences "
        f"including five alternate orange versions ({inventory['frame_count']} TGA files)."
    )
    content[2] = (
        "Files: `<category>/<message>_1.tga` through `_3.tga`. Frame order: onset, peak, aftershock. "
        "Each is an uncompressed 32-bit RGBA TGA with alpha. Dimensions: "
        + ", ".join(f"{width}x{height}" for width, height in sizes)
        + "; see each asset's frame_size in inventory (default256x256)."
    )
    readme.write_text("\n\n".join(content))

    manifest.update(approval_status="approved", approval_evidence="User: approve",
                    copied_to_addon_unimplemented=True, implemented=False,
                    packaged_destination="Kapow/UnimplementedArt")
    for entry in manifest["entries"]:
        entry["approval_status"] = "approved"
    save(manifest_file, manifest)
    progress_file = batch / "progress.json"
    progress = json.loads(progress_file.read_text())
    progress.update(approval_status="approved", status="packaged_unimplemented",
                    packaged_destination="Kapow/UnimplementedArt")
    save(progress_file, progress)
    workflow_file = BATCHES / "workflow.json"
    workflow = json.loads(workflow_file.read_text())
    for record in workflow["batches"]:
        if record["directory"] == batch_name:
            record.update(approval_status="approved", status="packaged_unimplemented")
    workflow["active_review_task"].update(approval_status="approved", status="packaged_unimplemented")
    workflow["integration"] = (
        f"{inventory['frame_count']} TGA frames copied to Kapow/UnimplementedArt: "
        f"{inventory['message_count']} messages, {inventory['sequence_count']} sequences including "
        "five original orange alternatives. No catalog or trigger integration."
    )
    save(workflow_file, workflow)
    print(json.dumps({"new_frames": len(copies), "total_messages": inventory["message_count"],
                      "total_frames": inventory["frame_count"], "copies_verified": True,
                      "destination": str(DEST)}))


if __name__ == "__main__":
    main(sys.argv[1])
