#!/usr/bin/env python3
"""Original fallback icons -> assets/gen/icons/ (committed; our own pixel art, used when assets/icons/mc is absent).

Same layout as assets/icons/mc: <name>.png (16x16) and {32,48,64}/<name>.png.  Flat items are drawn with PIL primitives
on a 16x16 canvas (no anti-aliasing); blocks are isometric cubes built from our own procedurally generated textures,
rendered with the same rasteriser as render_icons.py.  Nothing here is copied from Mojang art.

Usage: gen_icons.py [--out DIR]
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_icons as ri  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


# ------------------------------------------------------------------ procedural textures (16x16, original)
def hexc(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def noise_tex(base, var=14, seed=0):
    r = np.random.default_rng(seed)
    b = np.array(hexc(base)[:3], float)
    a = np.zeros((16, 16, 4), np.uint8)
    n = r.integers(-var, var + 1, (16, 16, 1))
    a[..., :3] = np.clip(b + n, 0, 255)
    a[..., 3] = 255
    return a


def tex(draw_fn, base, var=10, seed=0):
    a = noise_tex(base, var, seed)
    im = Image.fromarray(a)
    d = ImageDraw.Draw(im)
    draw_fn(d)
    return np.asarray(im)


def border(d, col, w=1):
    for i in range(w):
        d.rectangle([i, i, 15 - i, 15 - i], outline=hexc(col))


def cube(models, name, top, left, right, S):
    for k, v in (("t", top), ("l", left), ("r", right)):
        models.virtual[f"g:{name}:{k}"] = Image.fromarray(v)
    el = {"from": [0, 0, 0], "to": [16, 16, 16], "faces": {
        "up": {"texture": f"#t", "uv": [0, 0, 16, 16]}, "south": {"texture": "#l", "uv": [0, 0, 16, 16]},
        "east": {"texture": "#r", "uv": [0, 0, 16, 16]}, "north": {"texture": "#r", "uv": [0, 0, 16, 16]},
        "west": {"texture": "#l", "uv": [0, 0, 16, 16]}, "down": {"texture": "#r", "uv": [0, 0, 16, 16]}}}
    m = {"textures": {k: f"g:{name}:{k}" for k in "tlr"}, "elements": [el], "builtin": None,
         "display": {"gui": {"rotation": [30, 225, 0], "translation": [0, 0, 0], "scale": [0.625] * 3}}}
    return ri.render_model(models, m, S)


def stone_t(seed=1, base="#7d7d7d"):
    def f(d):
        pass
    return tex(f, base, 12, seed)


def planks_t(base="#a07840", seed=2):
    def f(d):
        for y in (3, 7, 11, 15):
            d.line([(0, y), (15, y)], fill=hexc("#6d4f28"))
        for x, y0 in ((5, 0), (11, 4), (3, 8), (9, 12)):
            d.line([(x, y0), (x, y0 + 3)], fill=hexc("#6d4f28"))
    return tex(f, base, 8, seed)


# ------------------------------------------------------------------ block icons
def block(models, name, S):
    if name == "stone":
        t = stone_t(1)
        return cube(models, name, t, stone_t(2, "#707070"), stone_t(3, "#626262"), S)
    if name == "grass_block":
        top = noise_tex("#5fa13a", 14, 4)
        side = noise_tex("#8a6038", 12, 5)
        side[:4, :, :3] = noise_tex("#5fa13a", 12, 6)[:4, :, :3]
        return cube(models, name, top, side, (side * np.array([1, 1, 1, 1])).astype(np.uint8), S)
    if name == "command_block":
        def front(d):
            border(d, "#4a2e1c")
            d.rectangle([4, 4, 11, 11], outline=hexc("#e0c9a8"))
            d.line([(6, 6), (9, 8), (6, 10)], fill=hexc("#e0c9a8"))
        def side(d):
            border(d, "#4a2e1c")
            for y in (4, 8, 12):
                d.line([(3, y), (12, y)], fill=hexc("#6a4128"))
        return cube(models, name, tex(side, "#b0714a", 8, 7), tex(front, "#b0714a", 8, 8), tex(side, "#9a6240", 8, 9), S)
    if name == "chest":
        def front(d):
            border(d, "#3a2512")
            d.line([(1, 6), (14, 6)], fill=hexc("#3a2512"))
            d.rectangle([7, 5, 8, 8], fill=hexc("#c8c8c8"))
        def side(d):
            border(d, "#3a2512")
            d.line([(1, 6), (14, 6)], fill=hexc("#3a2512"))
        return cube(models, name, tex(lambda d: border(d, "#3a2512"), "#b58a4a", 8, 10), tex(front, "#a37a3c", 8, 11), tex(side, "#8f6a32", 8, 12), S)
    if name == "jukebox":
        def top(d):
            border(d, "#2a1810")
            d.rectangle([6, 6, 9, 9], fill=hexc("#120a06"))
        return cube(models, name, tex(top, "#6a4228", 8, 13), tex(lambda d: border(d, "#2a1810"), "#7a4e2e", 8, 14), tex(lambda d: border(d, "#2a1810"), "#66402a", 8, 15), S)
    if name == "crafting_table":
        def top(d):
            border(d, "#4a3018")
            for i in (4, 8, 12):
                d.line([(i, 1), (i, 14)], fill=hexc("#6d4f28"))
                d.line([(1, i), (14, i)], fill=hexc("#6d4f28"))
        return cube(models, name, tex(top, "#b58a50", 8, 16), planks_t("#9a7038", 17), planks_t("#86602e", 18), S)
    if name == "note_block":
        def side(d):
            border(d, "#3a2418")
            d.rectangle([6, 5, 9, 10], outline=hexc("#241408"))
        return cube(models, name, tex(side, "#8a5a38", 8, 19), tex(side, "#7a4f30", 8, 20), tex(side, "#684228", 8, 21), S)
    if name == "barrel":
        def side(d):
            for x in (0, 5, 10, 15):
                d.line([(x, 0), (x, 15)], fill=hexc("#4a3218"))
            d.line([(0, 3), (15, 3)], fill=hexc("#6a6a6a"))
            d.line([(0, 12), (15, 12)], fill=hexc("#6a6a6a"))
        def top(d):
            border(d, "#4a3218")
            d.rectangle([4, 4, 11, 11], outline=hexc("#4a3218"))
        return cube(models, name, tex(top, "#9a7440", 8, 22), tex(side, "#8c6a38", 8, 23), tex(side, "#795a30", 8, 24), S)
    if name == "tnt":
        def side(d):
            d.rectangle([0, 5, 15, 10], fill=hexc("#e8e0d0"))
            d.line([(0, 5), (15, 5)], fill=hexc("#a02828"))
            d.line([(0, 10), (15, 10)], fill=hexc("#a02828"))
            d.line([(4, 6), (4, 9)], fill=hexc("#303030"))
            d.line([(7, 6), (7, 9)], fill=hexc("#303030"))
            d.line([(5, 6), (6, 6)], fill=hexc("#303030"))
            d.line([(10, 6), (11, 9)], fill=hexc("#303030"))
        return cube(models, name, tex(lambda d: d.rectangle([6, 6, 9, 9], fill=hexc("#5a4a3a")), "#c04040", 8, 25), tex(side, "#c03a36", 6, 26), tex(side, "#a83230", 6, 27), S)
    if name == "end_portal_frame":
        def top(d):
            d.rectangle([3, 3, 12, 12], fill=hexc("#2a7a68"))
            d.rectangle([5, 5, 10, 10], fill=hexc("#0c2a24"))
            border(d, "#b8b090")
        return cube(models, name, tex(top, "#d8d0a0", 6, 28), tex(lambda d: border(d, "#807a5c"), "#c8c08c", 8, 29), tex(lambda d: border(d, "#706a4e"), "#b4ac7a", 8, 30), S)
    if name == "enchanting_table":
        def top(d):
            border(d, "#2a0c18")
            d.rectangle([2, 2, 13, 13], outline=hexc("#d0e0e0"))
            d.rectangle([5, 5, 10, 10], fill=hexc("#2a0c18"))
        # a slab-like table: shorter cube (top face lowered) by shrinking the box
        t, l, r = tex(top, "#b02838", 10, 31), tex(lambda d: border(d, "#14080c"), "#241822", 8, 32), tex(lambda d: border(d, "#14080c"), "#1c1218", 8, 33)
        for k, v in (("t", t), ("l", l), ("r", r)):
            models.virtual[f"g:{name}:{k}"] = Image.fromarray(v)
        el = {"from": [0, 0, 0], "to": [16, 12, 16], "faces": {
            "up": {"texture": "#t", "uv": [0, 0, 16, 16]}, "south": {"texture": "#l", "uv": [0, 0, 16, 12]}, "east": {"texture": "#r", "uv": [0, 0, 16, 12]},
            "north": {"texture": "#r", "uv": [0, 0, 16, 12]}, "west": {"texture": "#l", "uv": [0, 0, 16, 12]}}}
        m = {"textures": {k: f"g:{name}:{k}" for k in "tlr"}, "elements": [el], "builtin": None,
             "display": {"gui": {"rotation": [30, 225, 0], "translation": [0, -1, 0], "scale": [0.625] * 3}}}
        return ri.render_model(models, m, S)
    return None


# ------------------------------------------------------------------ flat icons (16x16)
def flat(name):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    C = hexc
    if name == "compass":
        d.ellipse([1, 1, 14, 14], fill=C("#5a5a62"), outline=C("#26262c"))
        d.ellipse([3, 3, 12, 12], fill=C("#d8d4c4"), outline=C("#8a8678"))
        d.polygon([(8, 3), (6, 8), (9, 8)], fill=C("#d03030"))
        d.polygon([(8, 12), (6, 8), (9, 8)], fill=C("#303030"))
    elif name == "clock":
        d.ellipse([1, 1, 14, 14], fill=C("#d6a52e"), outline=C("#6a4a10"))
        d.ellipse([3, 3, 12, 12], fill=C("#f0e4b8"), outline=C("#9a7a28"))
        d.line([(8, 8), (8, 4)], fill=C("#40300a")); d.line([(8, 8), (11, 9)], fill=C("#40300a"))
    elif name == "music_disc_cat":
        d.ellipse([1, 1, 14, 14], fill=C("#141418"), outline=C("#000000"))
        d.ellipse([4, 4, 11, 11], fill=C("#7ac86a"), outline=C("#3a7a30"))
        d.rectangle([7, 7, 8, 8], fill=C("#141418"))
        d.line([(3, 4), (5, 2)], fill=C("#3a3a44"))
    elif name in ("writable_book", "book", "enchanted_book"):
        cover = {"writable_book": "#5a4a8a", "book": "#7a4a2a", "enchanted_book": "#6a3aa8"}[name]
        d.rectangle([2, 1, 13, 14], fill=C(cover), outline=C("#1c1228"))
        d.rectangle([3, 2, 4, 13], fill=C("#3a2a5a" if name != "book" else "#4a2a14"))
        d.rectangle([12, 2, 12, 13], fill=C("#e8dcb8"))
        d.rectangle([6, 4, 10, 6], fill=C("#d8b84a"))
        if name == "enchanted_book":
            for p in ((7, 9), (9, 11), (6, 12), (10, 8)):
                im.putpixel(p, C("#e0b0ff"))
        if name == "writable_book":
            d.line([(8, 14), (13, 9)], fill=C("#e8e8f0")); d.line([(13, 9), (14, 6)], fill=C("#f4f4ff"))
    elif name == "bell":
        d.pieslice([2, 1, 13, 12], 180, 360, fill=C("#e0b030"), outline=C("#6a4a08"))
        d.rectangle([2, 7, 13, 11], fill=C("#e0b030"), outline=C("#6a4a08"))
        d.rectangle([1, 11, 14, 12], fill=C("#c89020"))
        d.ellipse([6, 12, 9, 15], fill=C("#8a6a18"))
        d.rectangle([7, 0, 8, 1], fill=C("#6a4a08"))
    elif name == "paper":
        d.rectangle([2, 2, 13, 13], fill=C("#f4f0e4"), outline=C("#9a9684"))
        for y in (5, 7, 9, 11):
            d.line([(4, y), (11, y)], fill=C("#b8b4a4"))
    elif name == "comparator":
        d.rectangle([1, 6, 14, 14], fill=C("#8a8a8e"), outline=C("#38383c"))
        for x, y in ((3, 2), (11, 2), (7, 4)):
            d.rectangle([x, y, x + 1, y + 4], fill=C("#d02020"))
            im.putpixel((x, y), C("#ff9a8a"))
        d.line([(3, 12), (12, 12)], fill=C("#38383c"))
    elif name == "redstone":
        r = np.random.default_rng(3)
        for _ in range(26):
            x, y = int(r.normal(8, 2.6)), int(r.normal(8, 2.6))
            if 1 <= x <= 14 and 1 <= y <= 14:
                im.putpixel((x, y), C(["#c01818", "#e03030", "#8a0c0c"][int(r.integers(3))]))
    elif name == "lever":
        d.rectangle([3, 11, 12, 14], fill=C("#8a8a8e"), outline=C("#38383c"))
        d.line([(8, 11), (11, 3)], fill=C("#8a5a2a"), width=2)
        d.rectangle([10, 1, 12, 3], fill=C("#a87838"))
    elif name == "spyglass":
        d.line([(3, 13), (12, 4)], fill=C("#b87333"), width=3)
        d.line([(3, 13), (6, 10)], fill=C("#7a4a1a"), width=3)
        d.ellipse([11, 1, 14, 4], fill=C("#a8e0f0"), outline=C("#5a3a14"))
    elif name == "painting":
        d.rectangle([1, 2, 14, 13], fill=C("#7a5428"), outline=C("#3a2810"))
        d.rectangle([3, 4, 12, 11], fill=C("#7ab8e8"))
        d.polygon([(3, 11), (7, 7), (10, 11)], fill=C("#4a8a3a"))
        d.polygon([(8, 11), (11, 8), (12, 11)], fill=C("#3a7230"))
        im.putpixel((10, 5), C("#fff0a0"))
    elif name == "brush":
        d.line([(2, 14), (9, 7)], fill=C("#8a5a2a"), width=2)
        d.polygon([(8, 8), (13, 3), (14, 4), (10, 9)], fill=C("#d8d0b0"), outline=C("#8a8268"))
        d.line([(9, 6), (11, 8)], fill=C("#b0a888"))
    elif name == "goat_horn":
        d.arc([1, 1, 14, 14], 20, 200, fill=C("#d8cbb0"), width=4)
        d.rectangle([11, 9, 14, 12], fill=C("#b8a888"))
        d.arc([1, 1, 14, 14], 20, 200, fill=C("#8a7a5a"), width=1)
    elif name == "filled_map" or name == "map":
        d.rectangle([2, 2, 13, 13], fill=C("#d8c490"), outline=C("#6a5428"))
        d.line([(6, 2), (6, 13)], fill=C("#b8a470")); d.line([(10, 2), (10, 13)], fill=C("#b8a470"))
        d.rectangle([4, 5, 6, 7], fill=C("#5a9a4a")); d.rectangle([8, 8, 11, 10], fill=C("#4a7ab8"))
    elif name == "name_tag":
        d.polygon([(3, 3), (13, 3), (14, 8), (13, 13), (3, 13), (2, 8)], fill=C("#d8c8a0"), outline=C("#6a5a30"))
        im.putpixel((4, 8), C("#6a5a30"))
        d.line([(1, 8), (3, 8)], fill=C("#a08040"))
    elif name == "tripwire_hook":
        d.rectangle([5, 1, 10, 4], fill=C("#a07840"), outline=C("#4a3418"))
        d.line([(8, 4), (8, 11)], fill=C("#b0b0b8"), width=2)
        d.line([(8, 11), (12, 13)], fill=C("#b0b0b8"), width=2)
        im.putpixel((12, 12), C("#e0e0f0"))
    elif name == "hopper":
        d.polygon([(1, 3), (14, 3), (10, 9), (10, 14), (5, 14), (5, 9)], fill=C("#6a6a72"), outline=C("#26262c"))
        d.rectangle([2, 4, 13, 5], fill=C("#3a3a40"))
    elif name == "ender_pearl":
        d.ellipse([2, 2, 13, 13], fill=C("#1e8a74"), outline=C("#0c3a30"))
        d.ellipse([4, 4, 9, 9], fill=C("#38c0a0"))
        im.putpixel((5, 5), C("#c8fff0"))
    elif name == "empty":
        pass
    else:
        return None
    return np.asarray(im)


def names():
    d = json.loads((REPO / "tokens/items.json").read_text())
    n = {v for k, v in d.items() if isinstance(v, str) and k != "_comment"} | {r["item"] for r in d.get("_title_rules", [])}
    return sorted(n)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=REPO / "assets/gen/icons")
    a = ap.parse_args()
    models = ri.Models(Path("/nonexistent"))
    sizes = (16, 32, 48, 64)
    for s in sizes:
        (a.out if s == 16 else a.out / str(s)).mkdir(parents=True, exist_ok=True)
    done, miss = [], []
    for n in names():
        for s in sizes:
            arr = block(models, n, s)
            if arr is None:
                f = flat(n)
                if f is not None:
                    arr = np.asarray(Image.fromarray(f).resize((s, s), Image.NEAREST)) if s != 16 else f
            if arr is None:
                break
            Image.fromarray(arr).save((a.out if s == 16 else a.out / str(s)) / f"{n}.png")
        else:
            done.append(n)
            continue
        miss.append(n)
    print(f"{len(done)} fallback icons -> {a.out}; missing: {' '.join(miss) or '-'}")


if __name__ == "__main__":
    main()
