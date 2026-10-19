"""Package unchanged static OFL fonts from the official Google Fonts repository."""

import hashlib
import io
import json
import re
import string
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "_fonts"
DEST.mkdir(exist_ok=True)
FAMILIES = {
    "knewave": "knewave",
    "bangers": "bangers",
    "russo-one": "russoone",
    "shojumaru": "shojumaru",
    "metal-mania": "metalmania",
    "black-ops-one": "blackopsone",
    "lilita-one": "lilitaone",
    "graduate": "graduate",
    "bubblegum-sans": "bubblegumsans",
}
THEMES = {
    "anime": ("knewave", "LIMIT BREAK!", "Brushy display lettering"),
    "comic": ("bangers", "POW! KRAKOOM!", "Slanted comic lettering"),
    "arcade": ("russo-one", "PERFECT! SUPER COMBO!", "Chunky arcade display"),
    "ninja": ("shojumaru", "SHADOW STRIKE!", "Expressive action lettering"),
    "arena": ("metal-mania", "FRAGGED! GIBBED!", "Heavy metal display"),
    "escalation": ("black-ops-one", "DOUBLE KILL! RAMPAGE!", "Heavy stencil ranks"),
    "failure": ("lilita-one", "NOPE! BONK!", "Bulky playful cartoon lettering"),
    "tactical": ("black-ops-one", "HEADSHOT! CLUTCH!", "Tactical stencil"),
    "football": ("graduate", "GOAL! WHAT A SAVE!", "Varsity sports lettering"),
    "falling": ("bubblegum-sans", "WHEEE! GRAVITY WINS!", "Bouncy cartoon lettering"),
}
REQUIRED = string.ascii_letters + string.digits + " .,!?'-+:;/\"%()[]#&="


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "PulseComic-font-pack"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


commit = json.loads(fetch("https://api.github.com/repos/google/fonts/commits/main"))["sha"]


def package(item):
    folder, upstream = item
    base = f"https://raw.githubusercontent.com/google/fonts/{commit}/ofl/{upstream}/"
    metadata = fetch(base + "METADATA.pb")
    license_bytes = fetch(base + "OFL.txt")
    license_text = license_bytes.decode("utf-8-sig")
    assert "SIL" in license_text and "Version 1.1" in license_text
    assert "Copyright" in license_text and "bundled" in license_text and "redistributed" in license_text
    names = re.findall(r'filename:\s*"([^"\[\]]+\.ttf)"', metadata.decode())
    filename = next(n for n in names if "italic" not in n.lower())
    payload = fetch(base + filename)
    assert payload[:4] == b"\x00\x01\x00\x00", (folder, "Not TrueType")
    font = TTFont(io.BytesIO(payload))
    assert "fvar" not in font, (folder, "Variable font was not requested")
    cmap = font.getBestCmap()
    missing = sorted(set(REQUIRED) - {chr(code) for code in cmap})
    assert not missing, (folder, "Missing required glyphs", missing)
    family_name = font["name"].getDebugName(1)
    internal_name = font["name"].getDebugName(6)
    target = DEST / folder
    target.mkdir(exist_ok=True)
    for name, content in [(filename, payload), ("OFL.txt", license_bytes), ("METADATA.pb", metadata)]:
        path = target / name
        if path.exists():
            assert path.read_bytes() == content, (path, "Refusing to overwrite an existing different file")
        else:
            path.write_bytes(content)
    provenance = {
        "family": family_name,
        "internal_postscript_name": internal_name,
        "file": f"_fonts/{folder}/{filename}",
        "license": "SIL Open Font License 1.1",
        "license_file": f"_fonts/{folder}/OFL.txt",
        "source_url": base + filename,
        "license_url": base + "OFL.txt",
        "upstream_directory": f"https://github.com/google/fonts/tree/{commit}/ofl/{upstream}",
        "upstream_commit": commit,
        "sha256": hashlib.sha256(payload).hexdigest(),
        "license_sha256": hashlib.sha256(license_bytes).hexdigest(),
        "unmodified_binary": True,
        "static_true_type": True,
        "glyph_check": {"required_characters": REQUIRED, "missing": missing,
                        "swedish_letters_present": all(ord(c) in cmap for c in "ÅÄÖåäö")},
        "copyright_notice": license_text.split("This Font Software")[0].strip(),
    }
    (target / "source.json").write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + "\n")
    print(f"Packaged {family_name}: static TTF, OFL 1.1, required glyphs present", flush=True)
    return folder, provenance


with ThreadPoolExecutor(max_workers=4) as pool:
    packaged = dict(pool.map(package, FAMILIES.items()))

mapping = {}
rows = []
for theme, (folder, sample, reason) in THEMES.items():
    p = packaged[folder]
    mapping[theme] = {"font_family": p["family"], "file": p["file"], "license": p["license"],
                      "license_file": p["license_file"], "source_url": p["source_url"], "reason": reason}
    rows.append(f"| {theme} | {p['family']} | `{p['file']}` |")
(DEST / "category-fonts.json").write_text(json.dumps(mapping, indent=2) + "\n")
(DEST / "font-index.json").write_text(json.dumps({"upstream_commit": commit, "fonts": packaged}, indent=2, ensure_ascii=False) + "\n")
readme = """# Redistributable display fonts

Nine unmodified static TrueType fonts cover all ten artwork themes. Black Ops One is shared by escalation and tactical; its binary is stored once. No purchase is required. Every selected binary is supplied under SIL Open Font License 1.1, downloaded with its own complete copyright/license file from the same pinned commit of the official Google Fonts source repository.

Keep each font's OFL.txt copyright and license notice with the font binary when distributing it in the addon. These files retain their original internal family names. Fonts remain under OFL; do not relicense them under the addon's code license or sell the font files by themselves. Reserved Font Names matter if making modified derivatives; this pack contains unchanged upstream binaries.

All paths below are relative to Art/. category-fonts.json supplies exact file paths, source URLs, license names and per-theme assignments. Each family/source.json records the pinned source, SHA-256, internal name and character coverage. Upstream METADATA.pb and full OFL.txt are included alongside each TTF.

| Theme | Font | TTF path |
| --- | --- | --- |
""" + "\n".join(rows) + """

One basic check confirms real static TTF format, normal Latin upper/lowercase, digits and game-text punctuation. The specimen sheet renders every theme, digits 0123456789 and punctuation once. These are display fonts; final in-game small-size readability has not been tested. Nothing was installed into the OS or connected to addon code.

Primary licensing reference: https://openfontlicense.org/ofl-faq/ . Full individual licenses in the family folders are authoritative for the shipped files.
"""
(DEST / "README.md").write_text(readme)

# One straightforward specimen, using the real packaged font binaries.
sheet = Image.new("RGB", (1400, 1720), (24, 27, 35))
draw = ImageDraw.Draw(sheet)
label_font = ImageFont.load_default(size=22)
for row, (theme, (folder, sample, reason)) in enumerate(THEMES.items()):
    y = row * 172 + 12
    p = packaged[folder]
    font_path = ROOT / p["file"]
    title = ImageFont.truetype(str(font_path), 54)
    digits = ImageFont.truetype(str(font_path), 32)
    draw.text((20, y), theme + " / " + p["family"], font=label_font, fill=(115, 203, 229))
    draw.text((20, y + 34), sample, font=title, fill=(250, 245, 224))
    draw.text((20, y + 103), "0123456789  + - / % . , ! ? ( )", font=digits, fill=(235, 235, 240))
    draw.line((20, y + 154, 1380, y + 154), fill=(68, 72, 84), width=1)
(ROOT / "_previews/fonts").mkdir(exist_ok=True)
sheet.save(ROOT / "_previews/fonts/specimen.png")

manifest_path = ROOT / "_metadata/manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest["fonts"] = {"mapping": "_fonts/category-fonts.json", "index": "_fonts/font-index.json",
                     "unique_binaries": len(packaged), "themes": list(THEMES),
                     "specimen": "_previews/fonts/specimen.png", "license": "SIL Open Font License 1.1"}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
root_readme = ROOT / "README.md"
root_readme.write_text(root_readme.read_text() + "\nFonts: _fonts/ contains nine unmodified static OFL 1.1 TTFs for all ten themes, with full licenses, source provenance and category-fonts.json. Keep OFL.txt with each distributed font. One specimen is in _previews/fonts/specimen.png.\n")
print("Complete: 9 licensed static TTF files / 10 themes, with licenses, mapping and one specimen.", flush=True)
