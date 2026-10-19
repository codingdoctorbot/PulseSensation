"""Split the generated strips and export TGA files and review previews. Requires Pillow."""

import json
import math
import re
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent.parent
SIZE = 256
data = json.loads((ROOT / "_metadata/manifest.json").read_text())
preview_dir = ROOT / "_previews"
preview_dir.mkdir(exist_ok=True)
columns = 5
sheet = Image.new("RGB", (columns * 288, math.ceil(len(data["assets"]) / columns) * 304), (24, 27, 35))
draw = ImageDraw.Draw(sheet)
font = ImageFont.load_default(size=18)
validation = []
normalized_words = [re.sub(r"[^a-z0-9]", "", a["word"].lower()) for a in data["assets"]]
assert len(set(normalized_words)) == len(normalized_words), "Duplicate message text"
expected_frames = {f for a in data["assets"] for f in a["frames"]}
assert len(expected_frames) == len(data["assets"]) * 3
review_frames = {}

for index, asset in enumerate(data["assets"]):
    source = Image.open(ROOT / asset["source_file"]).convert("RGBA")
    assert abs(source.width / source.height - 3) < 0.03, (asset["key"], source.size)
    preview_frames = []
    (preview_dir / asset["key"].split("/")[0]).mkdir(exist_ok=True)
    for number, relative in enumerate(asset["frames"]):
        cell_box = (round(number * source.width / 3), 0, round((number + 1) * source.width / 3), source.height)
        frame = source.crop(cell_box)
        source_alpha = frame.getchannel("A")
        w, h = frame.size
        source_edge_alpha = max(source_alpha.crop(box).getextrema()[1] for box in
                               [(0, 0, 1, h), (w - 1, 0, w, h), (0, 0, w, 1), (0, h - 1, w, h)])
        assert source_edge_alpha <= 32 or asset.get("allow_effects_at_source_edge", False), (asset["key"], number, "Visible source clipping")
        # Premultiplied alpha prevents colored fringes during format-size conversion.
        fitted = ImageOps.contain(frame.convert("RGBa"), (SIZE - 8, SIZE - 8), Image.Resampling.LANCZOS).convert("RGBA")
        frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        frame.paste(fitted, ((SIZE - fitted.width) // 2, (SIZE - fitted.height) // 2))
        destination = ROOT / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            existing = Image.open(destination)
            assert existing.mode == "RGBA" and existing.tobytes() == frame.tobytes(), (relative, "Refusing to replace existing artwork")
        else:
            frame.save(destination, format="TGA", compression=None)
        frame.save(preview_dir / (asset["key"] + f"_{number + 1}.png"))

        header = destination.read_bytes()[:18]
        width, height = struct.unpack_from("<HH", header, 12)
        reopened = Image.open(destination)
        alpha = reopened.getchannel("A")
        assert header[2] == 2, "TGA must be uncompressed true-color"
        assert (width, height, header[16], header[17] & 15) == (256, 256, 32, 8)
        assert reopened.mode == "RGBA" and reopened.tobytes() == frame.tobytes()
        assert alpha.getextrema()[0] == 0 and alpha.getextrema()[1] >= 240
        assert all(alpha.getpixel(p) == 0 for p in [(0, 0), (255, 0), (0, 255), (255, 255)])
        left, top, right, bottom = alpha.getbbox()
        assert left >= 4 and top >= 4 and right <= 252 and bottom <= 252
        validation.append({"file": relative, "dimensions": [width, height], "bits_per_pixel": 32,
                           "alpha_bits": 8, "alpha_range": list(alpha.getextrema()),
                           "nontransparent_bounds": alpha.getbbox(), "roundtrip": "exact",
                           "source_cell_box": list(cell_box), "source_edge_alpha_max": source_edge_alpha,
                           "source_visible_clipping": source_edge_alpha > 32,
                           "source_edge_effects_accepted": bool(source_edge_alpha > 32 and asset.get("allow_effects_at_source_edge", False))})

        # GIFs use a solid review background; PNG and TGA files retain the true alpha.
        canvas = Image.new("RGBA", (SIZE, SIZE), (36, 40, 49, 255))
        canvas.alpha_composite(frame)
        preview_frames.append(canvas.convert("RGB"))
        if number == 1:
            x, y = (index % columns) * 288 + 16, (index // columns) * 304 + 8
            sheet.paste(canvas.convert("RGB"), (x, y))
            draw.text((x, y + 264), asset["key"], font=font, fill=(238, 240, 246))

    preview_frames[0].save(preview_dir / (asset["key"] + ".gif"),
                           save_all=True, append_images=preview_frames[1:], loop=0,
                           duration=[80, 120, 180], optimize=False)
    review_frames[asset["key"]] = preview_frames

actual_frames = {str(p.relative_to(ROOT)) for p in ROOT.rglob("*.tga")}
assert actual_frames == expected_frames, (actual_frames - expected_frames, expected_frames - actual_frames)
for category, keys in data.get("categories", {}).items():
    review = Image.new("RGB", (816, len(keys) * 292), (24, 27, 35))
    review_draw = ImageDraw.Draw(review)
    for row, key in enumerate(keys):
        for col, frame in enumerate(review_frames[key]):
            review.paste(frame, (col * 272 + 8, row * 292))
        review_draw.text((8, row * 292 + 262), key + "    01 onset / 02 peak / 03 aftershock", font=font, fill=(238, 240, 246))
    review.save(preview_dir / category / "sequence-sheet.png")

sheet.save(preview_dir / "all-messages.png")
(ROOT / "_metadata/validation.json").write_text(json.dumps(validation, indent=2) + "\n")
print(f"Exported and verified {len(validation)} TGA frames across {len(data['assets'])} messages.")
print("Verified: uncompressed true-color, 256x256, RGBA32, 8-bit alpha, transparent corners, exact decode.")
print("Saved PNG frame previews, animated GIF previews, _previews/all-messages.png and _metadata/validation.json.")
