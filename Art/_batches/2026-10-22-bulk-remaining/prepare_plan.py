"""Snapshot the remaining banner list once, before bulk generation starts."""
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
source = REPO / "Kapow/Generation/generationpromptdatabase.md"
text = source.read_text().split("## Part 2")[0]
wanted, section, headers = {}, None, None
for line in text.splitlines():
    if line.startswith("### P"):
        section, headers = line.split(" —")[0][4:], None
    if not section or not line.startswith("|"):
        continue
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    if cells[0] in ("Event (KAPOW)", "Message file", "Category"):
        headers = cells
        continue
    if not headers or len(cells) != len(headers) or "Message file" not in headers:
        continue
    if all(re.fullmatch(r"[: -]+", cell) for cell in cells):
        continue
    name = cells[headers.index("Message file")].strip("`")
    category = cells[headers.index("Category")] if "Category" in headers else "arcade"
    word = cells[headers.index("`{WORD}`")].strip("`")
    key = f"{category}/{name}"
    wanted.setdefault(key, dict(key=key, category=category, name=name, word=word, priority=section))

existing = {a["key"] for a in json.loads((REPO / "Art/_metadata/manifest.json").read_text())["assets"]}
for path in (REPO / "Art/_batches").glob("*/manifest.json"):
    for entry in json.loads(path.read_text()).get("entries", []):
        if entry.get("source") and (path.parent / entry["source"]).is_file():
            existing.add(f"{entry.get('category', 'escalation')}/{entry['name']}")
remaining = [entry for key, entry in wanted.items() if key not in existing]
assert len(remaining) == 33, len(remaining)
batches = []
for start in range(0, len(remaining), 5):
    name = f"2026-10-22-batch-{7 + start // 5:02d}"
    batches.append(dict(directory=name, entries=remaining[start:start + 5]))
plan = dict(authorization="Generate all remaining; user will approve after bulk.",
            message_count=33, frame_count=99, frame_size=[256, 256],
            approval_status="pending", batches=batches)
path = HERE / "plan.json"
assert not path.exists(), "Do not overwrite or recompute an existing bulk plan."
path.write_text(json.dumps(plan, indent=2) + "\n")
print(json.dumps({"messages": 33, "frames": 99, "batches": [b["directory"] for b in batches]}))
