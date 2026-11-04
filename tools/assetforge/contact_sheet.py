#!/usr/bin/env python3
"""Contact sheet of a directory of icons: contact_sheet.py <icon-dir> <out.png> [--size 64] [--cols 12] [--bg #2b2b2b] [--label]"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("dir", type=Path)
ap.add_argument("out", type=Path)
ap.add_argument("--size", type=int, default=64)
ap.add_argument("--cols", type=int, default=12)
ap.add_argument("--bg", default="#3a3a3a")
a = ap.parse_args()
files = sorted(a.dir.glob("*.png"))
font = None
fp = Path.home() / ".local/share/fonts/overworld/OverworldMojangles-Regular.ttf"
try:
    font = ImageFont.truetype(str(fp), 8)
except Exception:
    font = ImageFont.load_default()
cw, ch = a.size + 16, a.size + 22
rows = -(-len(files) // a.cols)
sheet = Image.new("RGB", (a.cols * cw, rows * ch), a.bg)
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    x, y = (i % a.cols) * cw, (i // a.cols) * ch
    im = Image.open(f).convert("RGBA")
    if im.width != a.size:
        im = im.resize((a.size, a.size), Image.NEAREST)
    d.rectangle([x + 4, y + 4, x + cw - 5, y + a.size + 7], fill="#8b8b8b", outline="#222")
    sheet.paste(im, (x + 8, y + 6), im)
    d.text((x + cw // 2, y + a.size + 16), f.stem[:16], fill="#ffffff", font=font, anchor="mm")
a.out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(a.out)
print(f"{len(files)} icons -> {a.out} {sheet.size}")
