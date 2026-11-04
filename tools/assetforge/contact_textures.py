#!/usr/bin/env python3
"""Contact sheet of assets/gen/textures (selected groups) on a checkerboard -> out.png.  Usage: contact_textures.py out.png [scale]"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
G = REPO / "assets/gen/textures"
scale = int(sys.argv[2]) if len(sys.argv) > 2 else 2
font = ImageFont.truetype(str(Path.home() / ".local/share/fonts/overworld/OverworldMojangles-Regular.ttf"), 8)
groups = ["gui/sprites/widget", "gui/sprites/hud", "gui/sprites/hud/heart", "gui/sprites/boss_bar", "gui/sprites/toast", "gui/sprites/tooltip", "gui/sprites/server_list",
          "gui/sprites/icon", "gui/sprites/container", "gui/sprites/container/creative_inventory", "gui/sprites/advancements", "gui/sprites/world_list", "gui/sprites/gamemode_switcher",
          "block", "environment", "environment/celestial", "environment/celestial/moon", "misc", "gui"]
W = 1500
items = []
for g in groups:
    for p in sorted((G / g).glob("*.png")):
        items.append((g, p))
x = y = 4
rowh = 0
placed = []
for g, p in items:
    im = Image.open(p).convert("RGBA")
    w, h = im.width * scale, im.height * scale
    if w > 420 * 1:  # cap huge ones
        k = max(1, 420 // im.width)
        w, h = im.width * k, im.height * k
    if x + w + 4 > W:
        x, y, rowh = 4, y + rowh + 12, 0
    placed.append((p, x, y, w, h))
    x += w + 6
    rowh = max(rowh, h)
H = y + rowh + 12
sheet = Image.new("RGB", (W, H), "#555")
d = ImageDraw.Draw(sheet)
for p, x, y, w, h in placed:
    im = Image.open(p).convert("RGBA").resize((w, h), Image.NEAREST)
    chk = Image.new("RGBA", (w, h), "#777")
    cd = ImageDraw.Draw(chk)
    for cy in range(0, h, 8):
        for cx in range(0, w, 8):
            if (cx // 8 + cy // 8) % 2:
                cd.rectangle([cx, cy, cx + 7, cy + 7], fill="#8a8a8a")
    chk.alpha_composite(im)
    sheet.paste(chk.convert("RGB"), (x, y))
sheet.save(sys.argv[1])
print(len(placed), "sprites ->", sys.argv[1], sheet.size)
