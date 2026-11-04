#!/usr/bin/env python3
"""Original fallback GUI art -> assets/gen/textures/<same relative path as the Mojang texture>.png (+ .png.mcmeta).

Used by Theme.tex() when assets/mc is absent.  Every sprite has the same size and nine-slice metadata as the sprite it
stands in for, but all pixels are drawn here from scratch (own palette, own shapes).  Committed (project licence).

Usage: gen_textures.py [--out DIR]
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT = None
MC = []  # written paths (for the report / contact sheet)


def C(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


# own palette
OUTL, DARK, MID, LIGHT, HI, WHITE = C("#101014"), C("#2a2a31"), C("#5d5d6b"), C("#8d8d9d"), C("#c5c5d4"), C("#ffffff")
FILL, FILL_HOT, FILL_OFF = C("#6e6e7e"), C("#7d7e9a"), C("#3b3b44")
CLEAR = (0, 0, 0, 0)


class Img:
    def __init__(self, w, h, bg=CLEAR):
        self.im = Image.new("RGBA", (w, h), bg)
        self.d = ImageDraw.Draw(self.im)
        self.w, self.h = w, h

    def rect(self, x0, y0, x1, y1, fill=None, outline=None):  # inclusive-exclusive
        if x1 <= x0 or y1 <= y0:
            return
        self.d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=fill, outline=outline)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), c)

    def line(self, p0, p1, c):
        self.d.line([p0, p1], fill=c)

    def bitmap(self, rows, ox, oy, pal):
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in pal:
                    self.px(ox + x, oy + y, pal[ch])

    def bevel_box(self, x0, y0, x1, y1, fill, hi, lo, outline, bevel=1, notch=True):
        """outlined rectangle with a lit top/left and shaded bottom/right bevel; corners notched"""
        self.rect(x0, y0, x1, y1, fill=outline)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill=fill)
        for i in range(bevel):
            self.rect(x0 + 1 + i, y0 + 1 + i, x1 - 1 - i, y0 + 2 + i, fill=hi)
            self.rect(x0 + 1 + i, y0 + 1 + i, x0 + 2 + i, y1 - 1 - i, fill=hi)
            self.rect(x0 + 1 + i, y1 - 2 - i, x1 - 1 - i, y1 - 1 - i, fill=lo)
            self.rect(x1 - 2 - i, y0 + 1 + i, x1 - 1 - i, y1 - 1 - i, fill=lo)
        if notch:
            for (cx, cy) in ((x0, y0), (x1 - 1, y0), (x0, y1 - 1), (x1 - 1, y1 - 1)):
                self.px(cx, cy, CLEAR)

    def save(self, rel, meta=None):
        p = OUT / (rel + ".png")
        p.parent.mkdir(parents=True, exist_ok=True)
        self.im.save(p)
        if meta:
            Path(str(p) + ".mcmeta").write_text(json.dumps(meta, indent=4) + "\n")
        MC.append(rel)


def nine(w, h, border):
    return {"gui": {"scaling": {"type": "nine_slice", "width": w, "height": h, "border": border}}}


def noise_fill(img, box, base, var, seed):
    r = np.random.default_rng(seed)
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            n = int(r.integers(-var, var + 1))
            img.px(x, y, tuple(max(0, min(255, c + n)) for c in base[:3]) + (base[3],))


S = "gui/sprites/"


# ============================================================================== widgets
def widgets():
    # --- buttons (200x20, border 3 / disabled 1)
    for name, fill, hi, lo, out, b in (("button", FILL, HI, MID, OUTL, 3), ("button_highlighted", FILL_HOT, WHITE, LIGHT, WHITE, 3), ("button_disabled", FILL_OFF, MID, DARK, OUTL, 1)):
        im = Img(200, 20)
        if name == "button_highlighted":
            im.rect(0, 0, 200, 20, fill=WHITE)
            im.rect(1, 1, 199, 19, fill=OUTL)
            im.bevel_box(1, 1, 199, 19, fill, C("#aeb0d4"), C("#4e5070"), OUTL, bevel=1, notch=False)
        else:
            im.bevel_box(0, 0, 200, 20, fill, hi, lo, out, bevel=2 if b == 3 else 1, notch=True)
        im.save(S + "widget/" + name, nine(200, 20, b))
    # --- slider track / handle
    for name, edge in (("slider", MID), ("slider_highlighted", WHITE)):
        im = Img(200, 20)
        im.rect(0, 0, 200, 20, fill=edge)
        im.rect(1, 1, 199, 19, fill=C("#17171c"))
        im.save(S + "widget/" + name, nine(200, 20, 1))
    for name, fill in (("slider_handle", FILL), ("slider_handle_highlighted", FILL_HOT)):
        im = Img(8, 20)
        im.bevel_box(0, 0, 8, 20, fill, HI if name == "slider_handle" else WHITE, MID, OUTL, bevel=1, notch=False)
        im.save(S + "widget/" + name, {"gui": {"scaling": {"type": "nine_slice", "width": 8, "height": 20, "border": {"left": 2, "top": 2, "right": 2, "bottom": 3}}}})
    # --- text field
    for name, edge in (("text_field", LIGHT), ("text_field_highlighted", WHITE)):
        im = Img(200, 20)
        im.rect(0, 0, 200, 20, fill=edge)
        im.rect(1, 1, 199, 19, fill=C("#050507"))
        im.save(S + "widget/" + name, nine(200, 20, 1))
    # --- checkbox (20x20): box 20x20, tick when selected
    for sel in (False, True):
        for hot in (False, True):
            name = "checkbox" + ("_selected" if sel else "") + ("_highlighted" if hot else "")
            im = Img(20, 20)
            im.rect(0, 0, 20, 20, fill=WHITE if hot else LIGHT)
            im.rect(1, 1, 19, 19, fill=C("#050507"))
            if sel:
                for i, (x, y) in enumerate([(5, 10), (6, 11), (7, 12), (8, 11), (9, 10), (10, 9), (11, 8), (12, 7), (13, 6)]):
                    im.px(x, y, C("#8bd45e"))
                    im.px(x, y + 1, C("#8bd45e"))
                    im.px(x, y + 2, C("#4c8a30"))
            im.save(S + "widget/" + name)
    # --- scrollers (6x32, border 1)
    im = Img(6, 32)
    im.rect(0, 0, 6, 32, fill=OUTL)
    im.rect(1, 1, 5, 31, fill=LIGHT)
    im.rect(1, 1, 5, 2, fill=HI)
    im.rect(4, 1, 5, 31, fill=MID)
    im.save(S + "widget/scroller", nine(6, 32, 1))
    im = Img(6, 32)
    im.rect(0, 0, 6, 32, fill=MID)
    im.rect(1, 1, 5, 31, fill=C("#0a0a0d"))
    im.save(S + "widget/scroller_background", nine(6, 32, 1))
    # --- tabs (130x24, border L2 T2 R2 B0): header tabs
    for name, fill, edge in (("tab", FILL_OFF, MID), ("tab_highlighted", C("#4a4a58"), LIGHT), ("tab_selected", FILL, HI), ("tab_selected_highlighted", FILL_HOT, WHITE)):
        im = Img(130, 24)
        im.rect(0, 0, 130, 24, fill=OUTL)
        im.rect(1, 1, 129, 24, fill=fill)
        im.rect(1, 1, 129, 2, fill=edge)
        im.rect(1, 1, 2, 24, fill=edge)
        im.px(0, 0, CLEAR); im.px(129, 0, CLEAR)
        im.save(S + "widget/" + name, {"gui": {"scaling": {"type": "nine_slice", "width": 130, "height": 24, "border": {"left": 2, "top": 2, "right": 2, "bottom": 0}}}})
    # --- small buttons
    for hot in (False, True):
        im = Img(14, 14)
        im.bevel_box(0, 0, 14, 14, FILL_HOT if hot else FILL, WHITE if hot else HI, MID, OUTL)
        for i in range(4, 10):
            im.px(i, i, WHITE); im.px(i, 13 - i, WHITE)
        im.save(S + "widget/cross_button" + ("_highlighted" if hot else ""))
    for d in ("backward", "forward"):
        for hot in (False, True):
            im = Img(23, 13)
            col = C("#fff2a8") if hot else C("#e4e4ee")
            for k in range(7):
                x = (4 + k) if d == "forward" else (18 - k)
                im.line((x, 2 + k if k < 5 else 12 - k + 0), (x, 11 - k if k < 5 else 6), col) if False else None
            # triangle arrow
            pts = [(4, 2), (4, 11), (19, 6.5)] if d == "forward" else [(19, 2), (19, 11), (4, 6.5)]
            im.d.polygon(pts, fill=col, outline=OUTL)
            im.save(S + "widget/page_" + d + ("_highlighted" if hot else ""))


# ============================================================================== HUD
HEART = [".xx.xx.", "xxxxxxx", "xxxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]
DRUM = ["...xxx.", "..xxxxx", "..xxxxx", "..xxxx.", ".xxx...", "bb.....", "bb....."]
ARMOR = ["xx.x.xx", "xxxxxxx", "xxxxxxx", ".xxxxx.", ".xxxxx.", ".xxxxx.", "..xxx.."]


def shape_img(rows, w=9, h=9, ox=1, oy=1, cols=None, half=False):
    im = Img(w, h)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == ".":
                continue
            if half and x > 3:
                continue
            c = cols.get(ch, cols["x"]) if cols else WHITE
            # simple light/dark shading: top-left lit, bottom dark
            im.px(ox + x, oy + y, c)
    return im


def shaded(rows, base, light, dark, ox=1, oy=1, half=False, w=9, h=9, extra=None):
    im = Img(w, h)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "." or (half and x > 3):
                continue
            c = base
            if ch == "x":
                if y <= 1 and x <= 3 and (x, y) != (0, 0):
                    c = light if (x, y) in ((1, 1), (1, 0), (2, 1)) else base
                if y >= len(rows) - 3 or x >= len(r) - 2:
                    c = dark
            elif extra and ch in extra:
                c = extra[ch]
            im.px(ox + x, oy + y, c)
    return im


def container(rows, ox=1, oy=1, outline=OUTL, inner=C("#1c1416"), w=9, h=9):
    im = Img(w, h)
    mask = {(ox + x, oy + y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}
    for (x, y) in list(mask):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in mask:
                    im.px(x + dx, y + dy, outline)
    for (x, y) in mask:
        im.px(x, y, inner)
    return im


def hud():
    heart_variants = {  # name -> (base, light, dark)
        "": (C("#d42a2a"), C("#ff8a7a"), C("#8a1414")), "poisoned_": (C("#8aa02a"), C("#c8e06a"), C("#4e5e14")),
        "withered_": (C("#3a3236"), C("#6a5e64"), C("#161214")), "frozen_": (C("#5ab4e8"), C("#c8f0ff"), C("#2a6a9e")),
        "absorbing_": (C("#e8b82a"), C("#fff0a0"), C("#9a6e0a")), "hardcore_": (C("#d42a2a"), C("#ff8a7a"), C("#8a1414")),
    }
    kinds = {"": "", "poisoned_": "poisoned_", "withered_": "withered_", "frozen_": "frozen_", "absorbing_": "absorbing_"}
    for hc in (False, True):
        for kind in kinds:
            b, l, d = heart_variants[kind]
            for blink in (False, True):
                sfx = "_blinking" if blink else ""
                bb, ll, dd = ((tuple(min(255, c + 60) for c in b[:3]) + (255,), WHITE, b) if blink else (b, l, d))
                for half in (False, True):
                    im = shaded(HEART, bb, ll, dd, half=half)
                    if hc:  # hardcore: a gold stud on the left lobe
                        im.px(2, 2, C("#ffe27a"))
                    im.save(S + "hud/heart/" + kind + ("hardcore_" if hc else "") + ("half" if half else "full") + sfx)
    for hc in (False, True):
        for blink in (False, True):
            im = container(HEART, inner=C("#2a1218") if not hc else C("#2a1a08"), outline=C("#ffffff") if blink else (C("#c8a028") if hc else OUTL))
            im.save(S + "hud/heart/container" + ("_hardcore" if hc else "") + ("_blinking" if blink else ""))
    for nm, base in (("vehicle_", C("#c07a2a")),):
        for k in ("full", "half"):
            shaded(HEART, base, C("#f0c070"), C("#6a3e10"), half=(k == "half")).save(S + "hud/heart/vehicle_" + k)
    container(HEART, inner=C("#201408")).save(S + "hud/heart/vehicle_container")
    # food
    for suffix, base, light, dark, bone in (("", C("#c8783a"), C("#f0b070"), C("#7a3e16"), C("#ece4d0")), ("_hunger", C("#7e9a3a"), C("#b8d070"), C("#46561c"), C("#ece4d0"))):
        for k in ("full", "half"):
            shaded(DRUM, base, light, dark, half=(k == "half"), extra={"b": bone}).save(S + f"hud/food_{k}{suffix}")
        container(DRUM, inner=C("#201408")).save(S + f"hud/food_empty{suffix}")
    # armor
    for k in ("full", "half"):
        shaded(ARMOR, C("#c4c8d8"), WHITE, C("#6e7488"), half=(k == "half")).save(S + f"hud/armor_{k}")
    container(ARMOR, inner=C("#181a22")).save(S + "hud/armor_empty")
    # air bubbles
    for nm in ("air", "air_bursting", "air_empty"):
        im = Img(9, 9)
        if nm == "air":
            im.d.ellipse([1, 1, 7, 7], outline=C("#7ad0ff"), fill=C("#2a6a9e"))
            im.px(3, 3, WHITE); im.px(3, 2, WHITE)
        elif nm == "air_bursting":
            for (x, y) in ((1, 1), (7, 1), (1, 7), (7, 7), (4, 0), (4, 8), (0, 4), (8, 4)):
                im.px(x, y, C("#bfeaff"))
        else:
            im.d.ellipse([1, 1, 7, 7], outline=C("#33414e"))
        im.save(S + "hud/" + nm)
    # crosshair (bbox 3..12)
    im = Img(15, 15)
    for i in range(3, 12):
        if i != 7:
            im.px(i, 7, WHITE); im.px(7, i, WHITE)
    im.px(7, 7, WHITE)
    im.save(S + "hud/crosshair")
    # effect backgrounds
    for nm, edge in (("effect_background", LIGHT), ("effect_background_ambient", C("#5ab4e8"))):
        im = Img(24, 24)
        im.bevel_box(0, 0, 24, 24, C("#34343e"), edge, DARK, OUTL)
        im.save(S + "hud/" + nm)
    # xp / jump bars
    def bar(name, prog=None, col=None, cool=False):
        im = Img(182, 5)
        if prog is None:
            im.rect(0, 0, 182, 5, fill=OUTL)
            im.rect(1, 1, 181, 4, fill=C("#26262c"))
            im.rect(1, 3, 181, 4, fill=C("#1a1a1f"))
        else:
            im.rect(0, 1, 182, 4, fill=col[0])
            im.rect(0, 1, 182, 2, fill=col[1])
            im.rect(0, 3, 182, 4, fill=col[2])
        im.save(S + "hud/" + name)
    bar("experience_bar_background")
    bar("experience_bar_progress", 1, (C("#7ed44a"), C("#c6f58a"), C("#3f8a22")))
    bar("jump_bar_background")
    bar("jump_bar_progress", 1, (C("#c8a02a"), C("#f5dc78"), C("#7a5a10")))
    bar("jump_bar_cooldown", 1, (C("#8a8a98"), C("#c8c8d6"), C("#55555f")))
    # hotbar 182x22: 9 slots of 20 px; selection 24x23
    im = Img(182, 22)
    im.rect(0, 0, 182, 22, fill=OUTL)
    im.rect(1, 1, 181, 21, fill=C("#4a4a56"))
    im.rect(1, 1, 181, 2, fill=LIGHT)
    for i in range(9):
        x = 3 + i * 20
        im.rect(x, 3, x + 17, 20, fill=C("#17171c"))
        im.rect(x, 3, x + 17, 4, fill=OUTL)
        im.rect(x + 17, 4, x + 18, 20, fill=LIGHT)
        im.rect(x, 20, x + 18, 21, fill=LIGHT)
    for (x, y) in ((0, 0), (181, 0), (0, 21), (181, 21)):
        im.px(x, y, CLEAR)
    im.save(S + "hud/hotbar")
    im = Img(24, 23)
    im.rect(0, 0, 24, 23, fill=OUTL)
    im.rect(1, 1, 23, 22, fill=WHITE)
    im.rect(3, 3, 21, 20, fill=OUTL)
    im.rect(4, 4, 20, 19, fill=CLEAR)
    im.rect(0, 0, 24, 23, fill=None)
    # punch the inside transparent, keep a bright 2px frame
    im2 = Img(24, 23)
    im2.rect(0, 0, 24, 23, fill=OUTL)
    im2.rect(1, 1, 23, 22, fill=WHITE)
    im2.rect(3, 3, 21, 20, fill=CLEAR)
    im2.save(S + "hud/hotbar_selection")
    for side in ("left", "right"):
        im = Img(29, 24)
        x0 = 0 if side == "left" else 7
        im.rect(x0, 1, x0 + 22, 23, fill=OUTL)
        im.rect(x0 + 1, 2, x0 + 21, 22, fill=C("#4a4a56"))
        im.rect(x0 + 1, 2, x0 + 21, 3, fill=LIGHT)
        sx = x0 + (2 if side == "left" else 2)
        im.rect(sx + 1, 4, sx + 19, 21, fill=C("#17171c"))
        im.save(S + "hud/hotbar_offhand_" + side)


def extras():
    # locked / unlocked padlock buttons (20x20)
    for lk in ("locked", "unlocked"):
        for state in ("", "_highlighted", "_disabled"):
            im = Img(20, 20)
            fill = FILL_OFF if state == "_disabled" else (FILL_HOT if state else FILL)
            im.bevel_box(0, 0, 20, 20, fill, WHITE if state == "_highlighted" else HI, MID, OUTL)
            gold = C("#e8c040") if state != "_disabled" else C("#6a6a52")
            im.rect(6, 9, 14, 16, fill=gold, outline=OUTL)
            im.px(10, 12, OUTL); im.px(10, 13, OUTL)
            if lk == "locked":
                im.rect(7, 4, 8, 9, fill=LIGHT); im.rect(12, 4, 13, 9, fill=LIGHT); im.rect(7, 3, 13, 4, fill=LIGHT)
            else:
                im.rect(7, 4, 8, 7, fill=LIGHT); im.rect(7, 3, 13, 4, fill=LIGHT); im.rect(12, 3, 13, 5, fill=LIGHT)
            im.save(S + f"widget/{lk}_button{state}")
    # attack indicators
    im = Img(16, 4); im.rect(0, 0, 16, 4, fill=OUTL); im.rect(1, 1, 15, 3, fill=C("#26262c")); im.save(S + "hud/crosshair_attack_indicator_background")
    im = Img(16, 4); im.rect(0, 1, 16, 3, fill=C("#e8e8f2")); im.save(S + "hud/crosshair_attack_indicator_progress")
    im = Img(16, 16)
    im.line((3, 12), (12, 3), WHITE); im.line((4, 12), (12, 4), WHITE); im.line((2, 10), (5, 13), WHITE); im.px(1, 14, WHITE)
    im.save(S + "hud/crosshair_attack_indicator_full")
    im = Img(18, 18); im.rect(0, 0, 18, 18, fill=C("#26262c", 200)); im.d.rectangle([0, 0, 17, 17], outline=MID); im.save(S + "hud/hotbar_attack_indicator_background")
    im = Img(18, 18); im.rect(1, 1, 17, 17, fill=C("#e8e8f2", 160)); im.save(S + "hud/hotbar_attack_indicator_progress")


# ============================================================================== boss bars
BOSS = {"pink": "#f05a9a", "blue": "#4a7ae8", "red": "#e03a3a", "green": "#4cc84a", "yellow": "#f0d03a", "purple": "#9a4ae0", "white": "#f0f0f4"}


def boss():
    def mix(c, f):
        return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)
    for nm, hexcol in BOSS.items():
        col = C(hexcol)
        im = Img(182, 5)
        im.rect(0, 0, 182, 5, fill=mix(col, 0.35))
        im.rect(0, 0, 182, 1, fill=mix(col, 0.55))
        im.rect(0, 4, 182, 5, fill=mix(col, 0.2))
        im.save(S + f"boss_bar/{nm}_background")
        im = Img(182, 5)
        im.rect(0, 0, 182, 5, fill=col)
        im.rect(0, 0, 182, 1, fill=mix(col, 1.25))
        im.rect(0, 4, 182, 5, fill=mix(col, 0.65))
        im.save(S + f"boss_bar/{nm}_progress")
    for n in (6, 10, 12, 20):
        for kind in ("background", "progress"):
            im = Image.open(OUT / (S + f"boss_bar/white_{kind}.png")).copy()
            d = ImageDraw.Draw(im)
            for i in range(1, n):
                x = round(i * 182 / n)
                d.line([(x, 0), (x, 4)], fill=(0, 0, 0, 255))
            p = OUT / (S + f"boss_bar/notched_{n}_{kind}.png")
            im.save(p)
            MC.append(S + f"boss_bar/notched_{n}_{kind}")


# ============================================================================== toasts / tooltips / panels
def panel(w, h, fill=C("#34343e"), hi=LIGHT, lo=DARK, out=OUTL, bevel=1):
    im = Img(w, h)
    im.bevel_box(0, 0, w, h, fill, hi, lo, out, bevel=bevel)
    return im


def toasts():
    for nm in ("advancement", "recipe"):
        # plain centre: the game (and our McNineSlice) tiles/stretches it, the item icon is drawn separately
        im = panel(160, 32, fill=C("#3a3a46") if nm == "advancement" else C("#3a342a"), hi=C("#7a7a8c") if nm == "advancement" else C("#8a7a5a"))
        im.save(S + "toast/" + nm)
    im = panel(160, 32, fill=C("#3a3a46"), hi=C("#7a7a8c"), bevel=1)
    im.save(S + "toast/tutorial", nine(160, 32, 3))
    im = panel(160, 32, fill=C("#30303a"), hi=C("#6a6a7c"))
    im.save(S + "toast/now_playing", nine(160, 32, 4))
    im = panel(160, 64, fill=C("#30303a"), hi=C("#6a6a7c"))
    im.save(S + "toast/system", {"gui": {"scaling": {"type": "nine_slice", "width": 160, "height": 64, "border": {"left": 17, "top": 30, "right": 4, "bottom": 4}}}})
    for nm in ("mouse", "movement_keys", "recipe_book", "right_click", "social_interactions", "tree", "wooden_planks"):
        im = panel(20, 20, fill=C("#5a4a34") if nm == "wooden_planks" else C("#3a3a46"))
        im.save(S + "toast/" + nm)
    # tooltip: dark translucent fill + purple gradient frame (nine-slice 9/10); the sprites keep an 8-9 px fully transparent
    # outer margin (the game draws them 9 px outside the text), the visible shape is bbox 8..91 / 9..90
    im = Img(100, 100)
    im.rect(9, 8, 91, 92, fill=C("#100010", 240))
    im.rect(8, 9, 92, 91, fill=C("#100010", 240))
    im.save(S + "tooltip/background", nine(100, 100, 9))
    im = Img(100, 100)

    def grad(t, a=255):
        return (int(80 + (40 - 80) * t), 0, int(255 + (120 - 255) * t), a)
    for i in range(10, 90):  # vertical edges, colour runs top -> bottom
        t = (i - 10) / 79
        for x in (9, 90):
            im.px(x, i, grad(t, 120))
        for x in (10, 89):
            im.px(x, i, grad(t))
    for x in range(10, 90):
        im.px(x, 9, grad(0, 120)); im.px(x, 10, grad(0))
        im.px(x, 90, grad(1, 120)); im.px(x, 89, grad(1))
    im.save(S + "tooltip/frame", {"gui": {"scaling": {"type": "nine_slice", "width": 100, "height": 100, "border": 10, "stretch_inner": True}}})
    # popup / generic panels
    im = panel(236, 34, fill=C("#30303a"), hi=C("#6a6a7c"))
    im.save(S + "popup/background", nine(236, 34, 6))


def container_sprites():
    im = Img(18, 18)
    im.rect(0, 0, 18, 18, fill=C("#ffffff"))
    im.rect(0, 0, 17, 17, fill=C("#26262c"))
    im.rect(1, 1, 17, 17, fill=C("#4a4a54"))
    im.rect(1, 1, 17, 17, fill=C("#34343c"))
    im.rect(0, 0, 18, 18, fill=None)
    # inset slot: dark top/left, light bottom/right
    im2 = Img(18, 18)
    im2.rect(0, 0, 18, 18, fill=C("#e8e8f2"))
    im2.rect(0, 0, 17, 17, fill=C("#0c0c10"))
    im2.rect(1, 1, 17, 17, fill=C("#3b3b44"))
    im2.px(17, 0, CLEAR); im2.px(0, 17, CLEAR)
    im2.save(S + "container/slot")
    for nm, a in (("slot_highlight_back", 150), ("slot_highlight_front", 110)):
        im = Img(24, 24)
        if nm == "slot_highlight_back":
            im.rect(4, 4, 20, 20, fill=C("#ffffff", a))
        else:
            im.rect(4, 4, 20, 20, fill=C("#ffffff", a))
        im.save(S + "container/" + nm, nine(24, 24, 4))
    for nm, fill in (("selection", None), ("slot", C("#17171c"))):
        im = Img(26, 26)
        if nm == "slot":
            im.rect(0, 0, 26, 26, fill=C("#17171c", 220)); im.rect(0, 0, 26, 26, fill=None)
            im.rect(0, 0, 26, 26, outline=None)
            im.d.rectangle([0, 0, 25, 25], outline=MID)
        else:
            im.d.rectangle([0, 0, 25, 25], outline=WHITE)
            im.d.rectangle([1, 1, 24, 24], outline=WHITE)
        im.save(S + "gamemode_switcher/" + nm)
    # creative inventory scroller + tabs (alpha bboxes match the sprites they replace)
    for nm, enabled in (("scroller", True), ("scroller_disabled", False)):
        im = Img(12, 15)
        im.bevel_box(0, 0, 12, 15, LIGHT if enabled else C("#4a4a54"), HI if enabled else MID, MID if enabled else DARK, OUTL, notch=False)
        im.save(S + "container/creative_inventory/" + nm)
    for pos in ("top", "bottom"):
        for sel in (True, False):
            for i in range(1, 8):
                im = Img(26, 32)
                if pos == "top":
                    y0, y1 = (0, 32) if sel else (2, 32)
                else:
                    y0, y1 = (0, 32) if sel else (0, 28)
                fill = C("#4a4a58") if sel else C("#2e2e38")
                im.rect(0, y0, 26, y1, fill=OUTL)
                im.rect(1, y0 + (1 if pos == "top" else 0), 25, y1 - (0 if pos == "top" else 1), fill=fill)
                if sel:
                    im.rect(1, y0 + 1 if pos == "top" else y0, 25, y0 + 2 if pos == "top" else y0 + 1, fill=LIGHT)
                im.save(S + f"container/creative_inventory/tab_{pos}_{'selected' if sel else 'unselected'}_{i}")


def advancements():
    # boxes (200x26, border 10)
    for nm, fill, edge in (("box_obtained", C("#3a4a3a"), C("#8ad46a")), ("box_unobtained", C("#2c2c34"), MID), ("title_box", C("#34343e"), LIGHT)):
        im = panel(200, 26, fill=fill, hi=edge, lo=DARK)
        im.save(S + "advancements/" + nm, nine(200, 26, 10))
    # frames 26x26: task = square, goal = rounded (round-ish), challenge = spiked
    for kind in ("task", "goal", "challenge"):
        for ob in (True, False):
            im = Img(26, 26)
            col = {"task": C("#e0c040"), "goal": C("#d09a2a"), "challenge": C("#b060e0")}[kind] if ob else MID
            dark = tuple(int(c * 0.5) for c in col[:3]) + (255,)
            if kind == "task":
                im.rect(1, 1, 25, 25, fill=OUTL); im.rect(2, 2, 24, 24, fill=col); im.rect(4, 4, 22, 22, fill=dark); im.rect(5, 5, 21, 21, fill=C("#17171c"))
            elif kind == "goal":
                im.d.ellipse([0, 0, 25, 25], fill=OUTL); im.d.ellipse([1, 1, 24, 24], fill=col); im.d.ellipse([3, 3, 22, 22], fill=dark); im.d.ellipse([4, 4, 21, 21], fill=C("#17171c"))
            else:
                for (x0, y0) in ((0, 12), (12, 0), (12, 25), (25, 12)):
                    im.px(x0, y0, col)
                im.d.polygon([(13, 0), (25, 13), (13, 25), (0, 13)], fill=OUTL)
                im.d.polygon([(13, 2), (23, 13), (13, 23), (2, 13)], fill=col)
                im.d.polygon([(13, 5), (20, 13), (13, 20), (6, 13)], fill=dark)
                im.d.polygon([(13, 6), (18, 13), (13, 18), (8, 13)], fill=C("#17171c"))
            im.save(S + f"advancements/{kind}_frame_{'obtained' if ob else 'unobtained'}")
    # tabs: (w,h,bbox_unselected, orientation)
    boxes = {"above_left": (0, 4, 28, 30), "above_middle": (0, 4, 28, 29), "above_right": (0, 4, 28, 31), "below_left": (0, 1, 28, 28), "below_middle": (0, 1, 28, 28),
             "below_right": (0, 2, 28, 28), "left_bottom": (4, 0, 29, 28), "left_middle": (4, 0, 29, 28), "left_top": (4, 0, 29, 28),
             "right_bottom": (3, 0, 28, 28), "right_middle": (3, 0, 28, 28), "right_top": (3, 0, 28, 28)}
    for key, (x0, y0, x1, y1) in boxes.items():
        vertical = key.startswith("above") or key.startswith("below")
        w, h = (28, 32) if vertical else (32, 28)
        for sel in (False, True):
            im = Img(w, h)
            bx = (0, 0, w, h) if sel else (x0, y0, x1, y1)
            im.rect(*bx, fill=OUTL)
            im.rect(bx[0] + 1, bx[1] + 1, bx[2] - 1, bx[3] - 1, fill=C("#4a4a58") if sel else C("#2e2e38"))
            im.save(S + f"advancements/tab_{key}" + ("_selected" if sel else ""))


# ============================================================================== server list / icons
def pings():
    levels = {5: ("#5adc4a", 5), 4: ("#8ad43a", 4), 3: ("#e0d03a", 3), 2: ("#e0903a", 2), 1: ("#e04a3a", 1)}
    def bars(n, col, off=C("#33333c")):
        im = Img(10, 8)
        for i in range(5):
            h = 2 + i
            c = C(col) if i < n else off
            im.rect(i * 2, 8 - h, i * 2 + 2 if False else i * 2 + 1, 8, fill=c)
            im.rect(i * 2, 8 - h, i * 2 + 1, 8, fill=c)
            im.rect(i * 2 + 1, 8 - h, i * 2 + 2, 8, fill=tuple(int(v * 0.7) for v in c[:3]) + (255,)) if i < n else None
        return im
    for k, (col, n) in levels.items():
        for base in ("server_list/ping_", "icon/ping_"):
            bars(n, col).save(S + base + str(k))
    for k in range(1, 6):
        bars(k, "#9a9aa8", C("#2a2a32")).save(S + f"server_list/pinging_{k}")
    bars(0, "#000000", C("#4a4a56")).save(S + "icon/ping_unknown")
    im = Img(10, 8)
    for i in range(5):
        im.rect(i * 2, 6 - i if False else 8 - (2 + i), i * 2 + 2, 8, fill=C("#3a2a2a"))
    for i in range(1, 8):
        im.px(1 + i, 1 + (i % 7), C("#ff4a3a")); im.px(8 - i + 1 if 8 - i + 1 < 10 else 9, 1 + (i % 7), C("#ff4a3a"))
    im.save(S + "server_list/unreachable")
    im = Img(10, 8)
    im.rect(1, 1, 9, 8, fill=C("#4a1414"))
    for i in range(2, 8):
        im.px(i, i - 1, C("#ff6a5a")); im.px(9 - i, i - 1, C("#ff6a5a"))
    im.save(S + "server_list/incompatible")
    # 32x32 arrow buttons
    def arrow32(direction, hot, name_dir, tex_dir="server_list"):
        im = Img(32, 32)
        col = WHITE if hot else C("#c4c4d4")
        if direction == "join":
            pts = [(8, 6), (8, 26), (25, 16)]
        elif direction == "up":
            pts = [(6, 22), (26, 22), (16, 8)]
        else:
            pts = [(6, 10), (26, 10), (16, 24)]
        im.d.polygon(pts, fill=col, outline=OUTL)
        im.save(S + f"{tex_dir}/{name_dir}" + ("_highlighted" if hot else ""))
    for hot in (False, True):
        arrow32("join", hot, "join")
        arrow32("up", hot, "move_up")
        arrow32("down", hot, "move_down")
        for nm, d in (("join", "join"), ("marked_join", "join")):
            arrow32(d, hot, nm, "world_list")
        for tdir, nm, d in (("transferable_list", "move_up", "up"), ("transferable_list", "move_down", "down"), ("transferable_list", "select", "join"), ("transferable_list", "unselect", "join")):
            arrow32(d, hot, nm, tdir)
        for nm, col in (("warning", "#f0c83a"), ("error", "#e04a3a")):
            im = Img(32, 32)
            im.d.polygon([(16, 5), (28, 27), (4, 27)], fill=C(col), outline=OUTL)
            im.d.rectangle([15, 12, 16, 20], fill=OUTL); im.px(15, 23, OUTL); im.px(16, 23, OUTL)
            im.save(S + f"world_list/{nm}" + ("_highlighted" if hot else ""))
    # misc small icons
    im = Img(12, 12)
    im.d.ellipse([1, 1, 8, 8], outline=WHITE)
    im.line((8, 8), (11, 11), WHITE); im.line((7, 8), (10, 11), WHITE)
    im.save(S + "icon/search")
    im = Img(9, 8)
    for (x, y) in [(1, 4), (2, 5), (3, 6), (4, 5), (5, 4), (6, 3), (7, 2)]:
        im.px(x, y, C("#8bd45e")); im.px(x, y + 1, C("#4c8a30"))
    im.save(S + "icon/checkmark")
    im = Img(10, 10)
    im.d.ellipse([0, 0, 9, 9], fill=C("#e0803a"), outline=OUTL)
    im.rect(4, 2, 6, 6, fill=WHITE); im.rect(4, 7, 6, 8, fill=WHITE)
    im.save(S + "icon/unseen_notification")
    im = Img(20, 20)
    im.d.ellipse([1, 1, 18, 18], fill=C("#3a6ab8"), outline=OUTL)
    im.rect(9, 4, 11, 6, fill=WHITE); im.rect(9, 8, 11, 16, fill=WHITE)
    im.save(S + "icon/info")


# ============================================================================== block / environment / misc
def destroy_stages():
    rng = np.random.default_rng(77)
    pts = {(8, 8)}
    layers = []
    # grow cracks outward: each stage adds a few random walks from existing points
    for stage in range(10):
        for _ in range(1 + stage // 2):
            x, y = list(pts)[int(rng.integers(len(pts)))]
            for _ in range(2 + stage):
                x = max(0, min(15, x + int(rng.integers(-1, 2))))
                y = max(0, min(15, y + int(rng.integers(-1, 2))))
                pts.add((x, y))
        layers.append(set(pts))
    for i, ps in enumerate(layers):
        im = Img(16, 16)
        for (x, y) in ps:
            im.px(x, y, (0, 0, 0, 150 + min(80, i * 8)))
        im.save("block/destroy_stage_%d" % i)


def environment():
    # sun 32x32: bright square disc with a soft ring
    im = Img(32, 32)
    im.rect(4, 4, 28, 28, fill=C("#fff6c0", 90))
    im.rect(6, 6, 26, 26, fill=C("#ffe66a"))
    im.rect(8, 8, 24, 24, fill=C("#fffbe0"))
    im.save("environment/celestial/sun")
    # moon phases
    phases = ["full_moon", "waning_gibbous", "third_quarter", "waning_crescent", "new_moon", "waxing_crescent", "first_quarter", "waxing_gibbous"]
    cov = {"full_moon": 0.0, "waning_gibbous": -0.3, "third_quarter": -0.5, "waning_crescent": -0.8, "new_moon": 1.0, "waxing_crescent": 0.8, "first_quarter": 0.5, "waxing_gibbous": 0.3}
    r = np.random.default_rng(5)
    for ph in phases:
        im = Img(32, 32)
        for y in range(4, 28):
            for x in range(4, 28):
                n = int(r.integers(-8, 9)) if True else 0
                base = 214 + n
                im.px(x, y, (base, base, min(255, base + 12), 255))
        for (cx, cy, cr) in ((11, 12, 3), (20, 18, 4), (14, 21, 2)):
            im.d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=(168, 168, 184, 255))
        # shadow: columns darkened to the dark side
        c = cov[ph]
        if c != 0.0:
            for y in range(4, 28):
                for x in range(4, 28):
                    t = (x - 4) / 23  # 0..1 left->right
                    dark = (t > 1 - abs(c)) if c > 0 else (t < abs(c))
                    if c == 1.0:
                        dark = True
                    if dark:
                        im.px(x, y, (24, 26, 40, 255) if c == 1.0 else (30, 32, 46, 255))
        im.save(f"environment/celestial/moon/{ph}")
    # rain/snow 64x256 tiles (soft streaks / flakes)
    r = np.random.default_rng(11)
    im = Img(64, 256)
    for _ in range(60):
        x, y, ln = int(r.integers(64)), int(r.integers(256)), int(r.integers(10, 22))
        for k in range(ln):
            a = int(110 * (1 - k / ln)) + 20
            im.px(x, (y + k) % 256, (190, 215, 255, a))
    im.save("environment/rain")
    im = Img(64, 256)
    for _ in range(90):
        x, y = int(r.integers(64)), int(r.integers(256))
        im.px(x, y, (255, 255, 255, 210))
        if r.random() < 0.3:
            im.px((x + 1) % 64, y, (255, 255, 255, 140)); im.px(x, (y + 1) % 256, (255, 255, 255, 140))
    im.save("environment/snow")
    # clouds 256x256: blocky white blobs on 8x8 cells (tileable: the grid wraps)
    r = np.random.default_rng(21)
    g = r.random((32, 32))
    for _ in range(3):  # smooth with wrap-around so the tile stays seamless
        g = (g + np.roll(g, 1, 0) + np.roll(g, -1, 0) + np.roll(g, 1, 1) + np.roll(g, -1, 1)) / 5
    thr = np.quantile(g, 0.62)
    im = Img(256, 256)
    for cy in range(32):
        for cx in range(32):
            if g[cy, cx] > thr:
                im.rect(cx * 8, cy * 8, cx * 8 + 8, cy * 8 + 8, fill=(255, 255, 255, 255))
    im.save("environment/clouds")


def anim_and_menu():
    r = np.random.default_rng(99)
    # water_still: 16x512 = 32 frames, frametime 2
    im = Img(16, 512)
    for f in range(32):
        for y in range(16):
            for x in range(16):
                w = math.sin((x + f * 0.5) * math.pi / 8) * 0.5 + math.sin((y - f * 0.5) * math.pi / 4) * 0.5 + math.sin((x + y + f * 0.25) * math.pi / 8) * 0.5
                k = int(34 * w)
                im.px(x, f * 16 + y, (max(0, 40 + k // 2), max(0, 90 + k), min(255, 210 + k // 2), 200))
    im.save("block/water_still", {"animation": {"frametime": 2}})
    # lava_still: 16x320 = 20 frames, ping-pong order like the original
    im = Img(16, 320)
    for f in range(20):
        for y in range(16):
            for x in range(16):
                w = math.sin((x * 1.0 + f * 0.8) * math.pi / 6) + math.sin((y - f * 0.6) * math.pi / 5) + r.normal(0, 0.15)
                k = int(46 * w)
                im.px(x, f * 16 + y, (min(255, 225 + k // 2), max(0, min(255, 110 + k)), max(0, 18 + k // 8), 255))
    im.save("block/lava_still", {"animation": {"frametime": 2, "frames": list(range(20)) + list(range(18, 0, -1))}})
    # nether_portal: 16x512 = 32 frames: drifting violet swirls
    im = Img(16, 512)
    for f in range(32):
        for y in range(16):
            for x in range(16):
                w = math.sin((x + y) * math.pi / 8 + f * math.pi / 16) * 0.5 + math.sin((x - y) * math.pi / 6 - f * math.pi / 16) * 0.5
                k = int(48 * w)
                im.px(x, f * 16 + y, (max(0, min(255, 120 + k)), 20 + max(0, k // 4), max(0, min(255, 210 + k)), 190))
    im.save("block/nether_portal", {"animation": {}})
    # fire_0: 16x512 = 32 frames; the original plays them in a rotated order
    im = Img(16, 512)
    for f in range(32):
        for x in range(16):
            h = 6 + int(5 * (math.sin((x * 0.9 + f * 0.7)) * 0.5 + 0.5) + 3 * r.random())
            for y in range(16):
                depth = 15 - y
                if depth < h:
                    t = depth / h
                    col = (255, int(220 - 150 * t), int(60 * (1 - t)), 255) if r.random() > 0.1 + 0.4 * t else CLEAR
                    im.px(x, f * 16 + y, col)
    im.save("block/fire_0", {"animation": {"frames": list(range(16, 32)) + list(range(0, 16))}})
    # enchanted glint (128x128, blur): diagonal violet bands
    im = Img(128, 128)
    for y in range(128):
        for x in range(128):
            v = (math.sin((x + y) * math.pi / 22) * 0.5 + 0.5) * 0.7 + (math.sin((x * 0.5 - y) * math.pi / 40) * 0.5 + 0.5) * 0.3
            im.px(x, y, (int(70 + 120 * v), int(30 + 40 * v), int(140 + 110 * v), 255))
    im.save("misc/enchanted_glint_item", {"texture": {"blur": True}})
    # menu backgrounds: 16x16 tiles, separators 32x2
    for nm, base, a in (("menu_background", "#2c2a30", 255), ("menu_list_background", "#1c1b20", 255),
                        ("inworld_menu_background", "#2c2a30", 190), ("inworld_menu_list_background", "#1c1b20", 190)):
        im = Img(16, 16)
        b = C(base)
        for y in range(16):
            for x in range(16):
                n = int(r.integers(-6, 7))
                im.px(x, y, (b[0] + n, b[1] + n, b[2] + n, a))
        im.save("gui/" + nm)
    for nm in ("header_separator", "footer_separator", "inworld_header_separator", "inworld_footer_separator"):
        im = Img(32, 2)
        top, bot = (C("#050507"), C("#6a6a78")) if "header" in nm else (C("#6a6a78"), C("#050507"))
        im.rect(0, 0, 32, 1, fill=top)
        im.rect(0, 1, 32, 2, fill=bot)
        im.save("gui/" + nm)


def misc():
    # missing texture: magenta/black 2x2 checker in 16x16
    im = Img(16, 16)
    im.rect(0, 0, 16, 16, fill=C("#f800f8"))
    im.rect(0, 0, 8, 8, fill=C("#000000"))
    im.rect(8, 8, 16, 16, fill=C("#000000"))
    im.save("misc/missing")
    # generic inventory panel: 32x32 nine-slice(4), classic light-grey bevelled GUI (Day) and a dark twin (Night)
    for nm, fill, hi, lo in (("inventory-panel", C("#c6c6c6"), WHITE, C("#555555")), ("inventory-panel_dark", C("#2c2c34"), C("#5a5a68"), C("#101014"))):
        im = Img(32, 32)
        im.rect(0, 0, 32, 32, fill=C("#000000"))
        im.rect(1, 1, 31, 31, fill=fill)
        im.rect(1, 1, 31, 3, fill=hi); im.rect(1, 1, 3, 31, fill=hi)
        im.rect(29, 3, 31, 31, fill=lo); im.rect(3, 29, 31, 31, fill=lo)
        for (x, y) in ((0, 0), (31, 0), (0, 31), (31, 31)):
            im.px(x, y, CLEAR)
        im.px(30, 1, fill); im.px(1, 30, fill)
        im.save("gui/" + nm, nine(32, 32, 4))


def main():
    global OUT
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=REPO / "assets/gen/textures")
    OUT = ap.parse_args().out
    for f in (widgets, hud, extras, anim_and_menu, boss, toasts, container_sprites, advancements, pings, destroy_stages, environment, misc):
        f()
    print(f"{len(MC)} fallback textures -> {OUT}")


if __name__ == "__main__":
    main()
