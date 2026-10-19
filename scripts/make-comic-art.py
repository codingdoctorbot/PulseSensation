#!/usr/bin/env python3
"""Generate KAPOW's comic-burst textures (pow / ko / overkill) as 256x256 32-bit TGA.

Usage:  python3 scripts/make-comic-art.py Kapow/Media [path/to/BoldItalic.ttf]

Needs Pillow. The lettering was rendered with Poppins Bold Italic (SIL Open Font License);
pass any heavy italic TTF as the second argument, or set COMIC_FONT. Only the rendered
textures ship; the font file itself is not distributed.
"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
FONT = (sys.argv[2] if len(sys.argv) > 2 else None) or os.environ.get("COMIC_FONT") \
    or "/usr/share/fonts/truetype/google-fonts/Poppins-BoldItalic.ttf"
if not os.path.exists(FONT):
    sys.exit(f"Font not found: {FONT}. Pass a bold italic .ttf as the second argument or set COMIC_FONT.")
S = 4            # supersample
N = 256 * S      # final texture is 256x256 (power of two, square so rotation does not skew)
C = N // 2

def burst(points, r_out, r_in, seed, jitter=0.18, rot=0.0):
    rnd = random.Random(seed)
    pts = []
    for i in range(points * 2):
        a = rot + math.pi * i / points
        base = r_out if i % 2 == 0 else r_in
        r = base * (1 + rnd.uniform(-jitter, jitter) * (1 if i % 2 == 0 else 0.5))
        pts.append((C + r * math.cos(a), C + r * math.sin(a)))
    return pts

def fit_font(text, max_w):
    size = 200 * S
    while size > 10:
        f = ImageFont.truetype(FONT, size)
        l, t, r, b = f.getbbox(text, stroke_width=int(size * 0.07))
        if r - l <= max_w:
            return f
        size -= 4
    return f

def make(name, text, fill, ring, text_fill, points, seed, tilt):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outer = burst(points, N * 0.47, N * 0.30, seed)
    d.polygon(outer, fill=(0, 0, 0, 255))                                   # black outline
    inner = [(C + (x - C) * 0.93, C + (y - C) * 0.93) for x, y in outer]
    d.polygon(inner, fill=ring)                                              # colour ring
    inner2 = [(C + (x - C) * 0.80, C + (y - C) * 0.80) for x, y in outer]
    d.polygon(inner2, fill=fill)                                             # body
    # halftone dots, comic-print feel
    dots = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dots)
    step = 14 * S
    for gy in range(0, N, step):
        for gx in range(0, N, step):
            off = (step // 2) if (gy // step) % 2 else 0
            x, y = gx + off, gy
            dist = math.hypot(x - C, y - C) / (N * 0.4)
            rad = max(0.0, (dist - 0.35)) * 3.2 * S
            if rad > 0.4:
                dd.ellipse((x - rad, y - rad, x + rad, y + rad), fill=(0, 0, 0, 70))
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).polygon(inner2, fill=255)
    img.paste(dots, (0, 0), Image.composite(dots.split()[3], Image.new("L", (N, N), 0), mask))
    # lettering
    font = fit_font(text, int(N * 0.62))
    sw = int(font.size * 0.07)
    txt = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    td = ImageDraw.Draw(txt)
    l, t, r, b = font.getbbox(text, stroke_width=sw)
    pos = (C - (l + r) / 2, C - (t + b) / 2)
    td.text((pos[0] + 5 * S, pos[1] + 6 * S), text, font=font, fill=(0, 0, 0, 255), stroke_width=sw, stroke_fill=(0, 0, 0, 255))
    td.text(pos, text, font=font, fill=text_fill, stroke_width=sw, stroke_fill=(0, 0, 0, 255))
    txt = txt.rotate(tilt, resample=Image.BICUBIC, center=(C, C))
    img = Image.alpha_composite(img, txt)
    img = img.resize((256, 256), Image.LANCZOS)
    img.save(f"{OUT}/{name}.tga")                 # 32-bit RGBA TGA, what the WoW client wants

make("pow",      "POW!",      (255, 214, 10, 255), (255, 120, 20, 255), (255, 255, 255, 255), 11, 3, 8)
make("ko",       "K.O.!",     (80, 190, 255, 255), (30, 110, 220, 255), (255, 255, 255, 255), 9, 7, -7)
make("overkill", "OVERKILL!", (255, 60, 50, 255),  (255, 170, 0, 255),  (255, 240, 120, 255), 15, 5, 6)
