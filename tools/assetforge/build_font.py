#!/usr/bin/env python3
"""Build the proportional Minecraft bitmap font as TTF: family "Overworld Mojangles".

Reads the jar's font providers (assets/mc/font/include/default.json + textures/font/*.png) and emits
assets/fonts/OverworldMojangles-{Regular,Bold}.ttf — square pixel outlines, 1 px = 128 units, UPM 1024
(8 px = 1 em, so the font is crisp at 8, 16, 24, 32 ... px).

Advance widths follow the game: rightmost non-blank column + 1 (scaled), +1 px spacing; space = 4.
Bold emulates the game: the glyph drawn again offset by +1 px, advance +1.

Usage: build_font.py [--mc DIR] [--out DIR]
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from PIL import Image

PX = 128  # font units per source pixel
UPM = 1024  # = 8 px
ASCENT_PX = 8  # hhea ascender  (line box = 10 px = 1.25 em; accented capitals poke above, which is fine)
DESCENT_PX = 2


def codepoints(s):
    """JSON gives lone surrogates for astral chars; recombine them, then split into codepoints."""
    return [ord(c) for c in s.encode("utf-16", "surrogatepass").decode("utf-16", "replace")]


def load_providers(mc: Path):
    inc = json.loads((mc / "font/include/default.json").read_text())
    space = json.loads((mc / "font/include/space.json").read_text())
    provs = []
    for p in inc["providers"] + space["providers"]:
        if p["type"] in ("bitmap", "space"):
            provs.append(p)
    return provs


def read_bitmap(mc: Path, p):
    """yield (codepoint, bitmap(bool HxW), advance_px, ascent_px_of_glyph_row0, scale) for a bitmap provider."""
    name = p["file"].split(":", 1)[-1]
    img = Image.open(mc / "textures" / name).convert("RGBA")
    a = np.asarray(img)[:, :, 3] > 0
    rows = [codepoints(r) for r in p["chars"]]
    ncols = max(len(r) for r in rows)
    cw = img.width // ncols
    ch = img.height // len(rows)
    height = p.get("height", 8)
    scale = height / ch
    ascent = p["ascent"]
    for ri, row in enumerate(rows):
        for ci, cp in enumerate(row):
            if cp == 0:
                continue
            cell = a[ri * ch:(ri + 1) * ch, ci * cw:(ci + 1) * cw]
            cols = np.where(cell.any(axis=0))[0]
            if len(cols) == 0:
                continue
            actual = cols.max() + 1
            adv = int(0.5 + actual * scale) + 1
            yield cp, cell, adv, ascent, scale


def rects_from_bitmap(bm, ascent, scale):
    """merge a boolean bitmap into rectangles (font units); row r spans y in [ascent-r-1, ascent-r] px."""
    h, w = bm.shape
    runs = {}  # (x0,x1) -> list of [row_start,row_end]
    open_runs = {}
    out = []
    for r in range(h + 1):
        cur = set()
        if r < h:
            x = 0
            while x < w:
                if bm[r, x]:
                    x0 = x
                    while x < w and bm[r, x]:
                        x += 1
                    cur.add((x0, x))
                else:
                    x += 1
        for k in list(open_runs):
            if k not in cur:
                out.append((k, open_runs.pop(k), r))
        for k in cur:
            if k not in open_runs:
                open_runs[k] = r
    rects = []
    for (x0, x1), r0, r1 in out:
        # r0..r1 rows (exclusive end)
        ytop = (ascent - r0 * scale)
        ybot = (ascent - r1 * scale)
        rects.append((round(x0 * scale * PX), round(ybot * PX), round(x1 * scale * PX), round(ytop * PX)))
    return rects


def draw(rects):
    pen = TTGlyphPen(None)
    for x0, y0, x1, y1 in rects:
        pen.moveTo((x0, y0))
        pen.lineTo((x0, y1))
        pen.lineTo((x1, y1))
        pen.lineTo((x1, y0))
        pen.closePath()
    return pen.glyph()


def glyph_name(cp):
    return f"uni{cp:04X}" if cp <= 0xFFFF else f"u{cp:05X}"


def bold_bitmap(bm):
    out = np.zeros((bm.shape[0], bm.shape[1] + 1), dtype=bool)
    out[:, :-1] |= bm
    out[:, 1:] |= bm
    return out


def build(mc: Path, outdir: Path):
    glyphs = {}  # cp -> (bitmap, adv, ascent, scale)  first provider wins
    spaces = {}
    for p in load_providers(mc):
        if p["type"] == "space":
            for ch, adv in p["advances"].items():
                for cp in codepoints(ch):
                    spaces.setdefault(cp, adv)
        else:
            for cp, bm, adv, asc, scale in read_bitmap(mc, p):
                glyphs.setdefault(cp, (bm, adv, asc, scale))
    for cp in spaces:
        glyphs.pop(cp, None)
    print(f"{len(glyphs)} bitmap glyphs, {len(spaces)} space glyphs", file=sys.stderr)

    outdir.mkdir(parents=True, exist_ok=True)
    for style in ("Regular", "Bold"):
        bold = style == "Bold"
        order = [".notdef"]
        cmap, glyf, hmtx = {}, {}, {}
        # .notdef: hollow box 5x7
        nd = np.zeros((7, 5), dtype=bool)
        nd[0, :] = nd[-1, :] = True
        nd[:, 0] = nd[:, -1] = True
        nd = bold_bitmap(nd) if bold else nd
        glyf[".notdef"] = draw(rects_from_bitmap(nd, 7, 1.0))
        hmtx[".notdef"] = ((7 + (1 if bold else 0)) * PX, 0)
        for cp, (bm, adv, asc, scale) in sorted(glyphs.items()):
            if cp > 0x10FFFF or 0xD800 <= cp <= 0xDFFF:
                continue
            name = glyph_name(cp)
            b = bold_bitmap(bm) if bold else bm
            glyf[name] = draw(rects_from_bitmap(b, asc, scale))
            hmtx[name] = ((adv + (1 if bold else 0)) * PX, 0)
            cmap[cp] = name
            order.append(name)
        for cp, adv in spaces.items():
            name = glyph_name(cp)
            glyf[name] = TTGlyphPen(None).glyph()
            hmtx[name] = ((adv + (1 if bold and adv else 0)) * PX, 0)
            cmap[cp] = name
            order.append(name)
        # NBSP = space
        if 0xA0 not in cmap:
            glyf["uni00A0"] = TTGlyphPen(None).glyph()
            hmtx["uni00A0"] = hmtx[glyph_name(0x20)]
            cmap[0xA0] = "uni00A0"
            order.append("uni00A0")

        # glyph bounds for the win metrics
        fb = FontBuilder(UPM, isTTF=True)
        fb.setupGlyphOrder(order)
        fb.setupCharacterMap(cmap)
        fb.setupGlyf(glyf)
        # recompute bearings (lsb) from glyph bounds
        metrics = {}
        for n in order:
            g = glyf[n]
            g.recalcBounds(fb.font["glyf"]) if hasattr(g, "recalcBounds") else None
            lsb = getattr(g, "xMin", 0) if g.numberOfContours else 0
            metrics[n] = (hmtx[n][0], lsb)
        fb.setupHorizontalMetrics(metrics)
        fb.setupHorizontalHeader(ascent=ASCENT_PX * PX, descent=-DESCENT_PX * PX, lineGap=0)
        fb.setupNameTable({
            "familyName": "Overworld Mojangles",
            "styleName": style,
            "uniqueFontIdentifier": f"OverworldMojangles-{style}",
            "fullName": f"Overworld Mojangles {style}" if bold else "Overworld Mojangles",
            "psName": f"OverworldMojangles-{style}",
            "version": "Version 1.0",
            "licenseDescription": "Glyph bitmaps (c) Mojang Studios; generated locally by tools/assetforge/build_font.py. "
                                  "Not redistributed.",
        })
        ys = [g.yMax for g in glyf.values() if g.numberOfContours]
        yn = [g.yMin for g in glyf.values() if g.numberOfContours]
        fb.setupOS2(
            sTypoAscender=ASCENT_PX * PX, sTypoDescender=-DESCENT_PX * PX, sTypoLineGap=0,
            usWinAscent=max(ys), usWinDescent=-min(yn),
            usWeightClass=700 if bold else 400, fsType=0,
            fsSelection=(0x20 if bold else 0x40) | 0x80,  # BOLD/REGULAR + USE_TYPO_METRICS
            sxHeight=5 * PX, sCapHeight=7 * PX, xAvgCharWidth=6 * PX,
            ulUnicodeRange1=0xFFFFFFFF, ulUnicodeRange2=0xFFFFFFFF, version=4,
        )
        fb.setupPost(isFixedPitch=0, underlinePosition=-PX, underlineThickness=PX)
        fb.font["head"].macStyle = 1 if bold else 0
        # pixel font: no grid-fitting, no smoothing hint needed; gasp = smoothing off for crispness at integer scales
        from fontTools.ttLib import newTable
        gasp = newTable("gasp")
        gasp.version = 1
        gasp.gaspRange = {0xFFFF: 0x000A}  # GRIDFIT | SYMMETRIC_SMOOTHING
        fb.font["gasp"] = gasp
        path = outdir / f"OverworldMojangles-{style}.ttf"
        fb.save(path)
        print(f"wrote {path} ({path.stat().st_size // 1024} KiB, {len(order)} glyphs)", file=sys.stderr)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    repo = Path(__file__).resolve().parents[2]
    ap.add_argument("--mc", type=Path, default=repo / "assets/mc")
    ap.add_argument("--out", type=Path, default=repo / "assets/fonts")
    a = ap.parse_args()
    build(a.mc, a.out)
