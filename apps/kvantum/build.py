#!/usr/bin/env python3
"""apps/kvantum/build.py - generate the Overworld Kvantum themes (Minecraft-GUI look).

    python3 build.py            # writes OverworldDay/ and OverworldNight/ next to this file

Outputs  OverworldDay/OverworldDay.{svg,kvconfig}  (colours from tokens/out/light/palette.json)
         OverworldNight/OverworldNight.{svg,kvconfig} (colours from tokens/out/dark/palette.json)

Only the python3 standard library is used.  The output is deterministic (idempotent).
Everything is drawn from 1px rectangles on an integer grid (shape-rendering=crispEdges); there are no
curves, gradients or rounded corners.  Frames are 9-slice pieces named `<element>-<state>-<position>`
and the interior is `<element>-<state>` (Kvantum's convention); pieces are sampled from a per-element
"shade" function  shade(x, y, W, H) -> colour | None | (colour, opacity)  so every state stays consistent.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


# ----------------------------------------------------------------------------------------- colour utils
def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb2hex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    """a*(1-t) + b*t"""
    ra, rb = hex2rgb(a), hex2rgb(b)
    return rgb2hex([ra[i] + (rb[i] - ra[i]) * t for i in range(3)])


def lum(h):
    def f(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = hex2rgb(h)
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast(a, b):
    la, lb = lum(a), lum(b)
    if la < lb:
        la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)


def over(fg_rgba, bg):
    """blend '#rrggbbaa' over '#rrggbb'"""
    fg = fg_rgba.lstrip("#")
    a = int(fg[6:8], 16) / 255.0 if len(fg) == 8 else 1.0
    return mix(bg, "#" + fg[:6], a)


# ------------------------------------------------------------------------------------------- SVG sheet
class Sheet:
    """Shelf-packs elements into one SVG.  Every element is a <g id=..> whose first child is a full-size
    (possibly invisible) rect, so QSvgRenderer's bounds-on-element equals the piece size exactly."""

    WIDTH = 512

    def __init__(self):
        self.items = []     # (id, w, h, ops)
        self.ids = set()

    def add(self, eid, w, h, ops):
        assert eid not in self.ids, eid
        self.ids.add(eid)
        self.items.append((eid, w, h, ops))

    def render(self):
        x = y = 2
        shelf = 0
        out = []
        for eid, w, h, ops in self.items:
            if x + w + 2 > self.WIDTH:
                x = 2
                y += shelf + 2
                shelf = 0
            out.append(self._g(eid, x, y, w, h, ops))
            x += w + 2
            shelf = max(shelf, h)
        height = y + shelf + 2
        head = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="%d" height="%d" '
                'viewBox="0 0 %d %d" shape-rendering="crispEdges">\n' % (self.WIDTH, height, self.WIDTH, height))
        return head + "\n".join(out) + "\n</svg>\n"

    @staticmethod
    def _g(eid, ox, oy, w, h, ops):
        s = ['<g id="%s" shape-rendering="crispEdges">' % eid,
             '<rect x="%d" y="%d" width="%d" height="%d" fill="#000000" fill-opacity="0"/>' % (ox, oy, w, h)]
        for (x, y, rw, rh, col, op) in ops:
            o = "" if op >= 1 else ' fill-opacity="%.3f"' % op
            s.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"%s/>' % (ox + x, oy + y, rw, rh, col, o))
        s.append("</g>")
        return "".join(s)


def norm(v):
    """shade result -> (colour, opacity) or None"""
    if v is None:
        return None
    if isinstance(v, tuple):
        return v
    return (v, 1.0)


def raster(shade, W, H, x0=0, y0=0, w=None, h=None):
    """Sample shade() over a window of the virtual WxH box and merge horizontal runs into rects."""
    w = W if w is None else w
    h = H if h is None else h
    ops = []
    for y in range(h):
        run = None
        for x in range(w):
            v = norm(shade(x0 + x, y0 + y, W, H))
            if run and v == run[2]:
                run[1] += 1
                continue
            if run and run[2] is not None:
                ops.append((run[0], y, run[1], 1, run[2][0], run[2][1]))
            run = [x, 1, v]
        if run and run[2] is not None:
            ops.append((run[0], y, run[1], 1, run[2][0], run[2][1]))
    # merge vertically identical consecutive rows
    merged = []
    for op in ops:
        if merged:
            p = merged[-1]
            if p[0] == op[0] and p[2] == op[2] and p[4] == op[4] and p[5] == op[5] and p[1] + p[3] == op[1]:
                merged[-1] = (p[0], p[1], p[2], p[3] + 1, p[4], p[5])
                continue
        merged.append(op)
    # second pass for rows that were not adjacent in list order
    changed = True
    while changed:
        changed = False
        for i, a in enumerate(merged):
            for j, b in enumerate(merged):
                if i != j and a[0] == b[0] and a[2] == b[2] and a[4] == b[4] and a[5] == b[5] and a[1] + a[3] == b[1]:
                    merged[i] = (a[0], a[1], a[2], a[3] + b[3], a[4], a[5])
                    del merged[j]
                    changed = True
                    break
            if changed:
                break
    return merged


POS = {
    "topleft": (0, 0), "top": (1, 0), "topright": (2, 0),
    "left": (0, 1), "right": (2, 1),
    "bottomleft": (0, 2), "bottom": (1, 2), "bottomright": (2, 2),
}


def nine(sh, name, n, shade, interior=True, suffix=""):
    """Emit  name-top/.../name-bottomright (+ name interior).  n = frame width in px (all sides)."""
    W = H = 2 * n + 1
    cols = [(0, n), (n, 1), (n + 1, n)]
    for pos, (cx, cy) in POS.items():
        x0, wd = cols[cx]
        y0, ht = cols[cy]
        sh.add("%s-%s%s" % (name, pos, suffix), wd, ht, raster(shade, W, H, x0, y0, wd, ht))
    if interior:
        sh.add(name + suffix, 1, 1, raster(shade, W, H, n, n, 1, 1))


def solid(sh, eid, w, h, shade):
    sh.add(eid, w, h, raster(shade, w, h))


# ----------------------------------------------------------------------------------------------- shades
def ring_bevel(ol, hi, lo, body, b=1):
    """Minecraft widget/button shading: 1px outline, then b px of hi on top/left and lo on bottom/right, body.
    The top-right and bottom-left bevel pixels are body (as in the game's sprite)."""
    def f(x, y, W, H):
        d = min(x, y, W - 1 - x, H - 1 - y)
        if d == 0:
            return ol
        if d <= b:
            tl = (y == d) or (x == d)
            br = (W - 1 - x == d) or (H - 1 - y == d)
            if tl and br:
                return body
            return hi if tl else lo
        return body
    return f


def flat(col):
    return lambda x, y, W, H: col


def ring2(outer, inner, body):
    def f(x, y, W, H):
        if x == 0 or y == 0 or x == W - 1 or y == H - 1:
            return outer
        if x == 1 or y == 1 or x == W - 2 or y == H - 2:
            return inner
        return body
    return f


def ring1(edge, body):
    def f(x, y, W, H):
        if x == 0 or y == 0 or x == W - 1 or y == H - 1:
            return edge
        return body
    return f


def bevel1(tl, br, body, corner=None):
    """1px bevel: tl on top/left, br on bottom/right (mixed corners = corner or body)"""
    corner = corner or body

    def f(x, y, W, H):
        t, l, b, r = y == 0, x == 0, y == H - 1, x == W - 1
        if (t and r) or (b and l):
            return corner
        if t or l:
            return tl
        if b or r:
            return br
        return body
    return f


def pixel_disc(size, r_in=0.0):
    """Octagon-ish pixel circle mask helper: returns set of (x,y) inside the circle of diameter `size`."""
    c = (size - 1) / 2.0
    rad = size / 2.0
    pts = set()
    for y in range(size):
        for x in range(size):
            if (x - c) ** 2 + (y - c) ** 2 <= (rad - 0.35) ** 2:
                pts.add((x, y))
    return pts


def arrow_ops(direction, size, fill, outline):
    """Pixel triangle arrow inside a size x size box, with 1px outline (outline drawn first)."""
    # build for 'down' on a size grid, then rotate
    half = size // 2
    rows = []   # (y, x0, x1)
    k = 0
    y = 1
    wdt = size - 2
    while wdt >= 1:
        rows.append((y, (size - wdt) // 2, wdt))
        y += 1
        wdt -= 2
    # fill triangle: rows from width size-4.. ; outline = the same triangle grown by 1px
    tri_fill = []
    y = 2
    wdt = size - 4
    while wdt >= 1:
        tri_fill.append((y, (size - wdt) // 2, wdt))
        y += 1
        wdt -= 2
    tri_out = [(r[0], r[1], r[2]) for r in rows]
    # outline also needs the row above the first fill row to be covered (rows start at y=1)
    pix_out = set()
    for (yy, xx, ww) in tri_out:
        for i in range(ww):
            pix_out.add((xx + i, yy))
    pix_fill = set()
    for (yy, xx, ww) in tri_fill:
        for i in range(ww):
            pix_fill.add((xx + i, yy))

    def rot(p):
        x, y = p
        if direction == "down":
            return (x, y)
        if direction == "up":
            return (x, size - 1 - y)
        if direction == "right":
            return (y, x)
        if direction == "left":
            return (size - 1 - y, x)
    ops = []
    for p in sorted(pix_out, key=lambda q: (q[1], q[0])):
        x, y = rot(p)
        ops.append((x, y, 1, 1, outline, 1.0))
    for p in sorted(pix_fill, key=lambda q: (q[1], q[0])):
        x, y = rot(p)
        ops.append((x, y, 1, 1, fill, 1.0))
    return ops


# ----------------------------------------------------------------------------------------------- themes
def load_palette(mode):
    with open(os.path.join(ROOT, "tokens", "out", mode, "palette.json")) as f:
        return json.load(f)


def theme_colours(name, p):
    day = name == "Day"
    c = {}
    c["panel"] = p["panel"]
    c["hi"] = p["panelLight"]
    c["lo"] = p["panelShadow"]
    c["ol"] = p["panelOutline"]
    c["slot"] = p["slot"]
    c["slotDark"] = p["slotDark"]
    c["slotLight"] = p["slotLight"]
    c["text"] = p["text"]
    c["btnText"] = p["buttonText"]
    c["btnTextDis"] = p["buttonTextDisabled"]
    c["white"] = "#ffffff"
    c["focus"] = p["fieldBorderFocus"]
    c["fieldFill"] = p["fieldFill"]
    c["fieldBorder"] = p["fieldBorder"]
    c["fieldText"] = p["fieldText"]
    c["xp"] = p["xp"]
    c["check"] = p["chatGreen"]
    c["tipFill"] = p["tooltipFill"][:7]
    c["tipTop"] = over(p["tooltipBorderTop"], c["tipFill"])
    c["tipBot"] = over(p["tooltipBorderBottom"], c["tipFill"])
    c["tipText"] = p["tooltipTitle"]
    if day:
        # numbers read from the game's widget/button*.png (1.21.11): body 6F6F6F, hi AAAAAA, lo 565656
        c["btn"], c["btnHi"], c["btnLo"] = "#6f6f6f", "#aaaaaa", "#565656"
        c["btnHov"], c["btnHovHi"], c["btnHovLo"] = "#6f6f6f", "#afafaf", "#5c5c5c"
        c["btnPress"] = "#5e5e5e"
        c["btnDis"], c["btnDisHi"], c["btnDisLo"] = "#333333", "#3d3d3d", "#2b2b2b"
        c["track"] = "#2c2c2c"           # slider/checkbox/progress groove body (widget/slider.png)
        c["trackDis"] = "#1c1c1c"
        c["highlight"] = p["accent"]       # selection (white text on it)
        c["highlightIn"] = mix(p["accent"], c["panel"], 0.35)
        c["disText"] = "#808080"
        c["base"] = p["slotDark"]          # dark "inventory" views: white Text role (also used for line edits)
        c["altBase"] = p["ink2"]
        c["tabNorm"], c["tabHov"] = "#a0a0a0", "#b4b4b4"
        c["menuFill"], c["menuEdge"] = "#2c2c2c", "#555555"
        c["fillGreen"], c["fillGreenLo"], c["fillGreenHi"] = c["xp"], "#4fa811", "#c2ff8a"
        c["link"], c["linkv"] = p["link"], p["plum"]
    else:
        c["btn"] = mix(p["panel"], p["panelLight"], 0.5)
        c["btnHi"] = mix(p["panelLight"], "#ffffff", 0.12)
        c["btnLo"] = p["panelShadow"]
        c["btnHov"] = mix(c["btn"], "#ffffff", 0.06)
        c["btnHovHi"] = mix(c["btnHi"], "#ffffff", 0.2)
        c["btnHovLo"] = c["btnLo"]
        c["btnPress"] = mix(c["btn"], "#000000", 0.2)
        c["btnDis"], c["btnDisHi"], c["btnDisLo"] = p["slot"], p["slotLight"], p["slotDark"]
        c["track"] = p["slot"]
        c["trackDis"] = p["slotDark"]
        c["highlight"] = p["accentSoft"]
        c["highlightIn"] = mix(p["accentSoft"], c["panel"], 0.35)
        c["disText"] = "#8c8c98"
        c["base"] = p["bg1"]
        c["altBase"] = p["bg2"]
        c["tabNorm"], c["tabHov"] = p["slot"], mix(p["slot"], p["panelLight"], 0.5)
        c["menuFill"], c["menuEdge"] = p["bg1"], p["panelLight"]
        c["fillGreen"], c["fillGreenLo"], c["fillGreenHi"] = c["xp"], "#4fa811", "#c2ff8a"
        c["link"], c["linkv"] = p["link"], "#c58bff"
    c["day"] = day
    return c


def build_svg(c):
    sh = Sheet()
    ol = c["ol"]

    # ---- buttons (widget/button, button_highlighted, button_disabled) ----
    def btn(st):
        if st == "normal":
            return ring_bevel(ol, c["btnHi"], c["btnLo"], c["btn"], 2)
        if st == "focused":
            return ring_bevel(c["white"], c["btnHovHi"], c["btnHovLo"], c["btnHov"], 2)
        if st == "pressed":    # inverted bevel, darker body
            return ring_bevel(ol, c["btnLo"], c["btnHi"], c["btnPress"], 2)
        if st == "toggled":    # latched: inverted bevel + green outline
            return ring_bevel(c["check"], c["btnLo"], c["btnHi"], c["btnPress"], 2)
        if st == "disabled":
            return ring_bevel(ol, c["btnDisHi"], c["btnDisLo"], c["btnDis"], 2)
    for st in ("normal", "focused", "pressed", "toggled", "disabled"):
        nine(sh, "button-" + st, 3, btn(st))

    # ---- tool buttons: flat until hovered ----
    nine(sh, "tbutton-normal", 3, lambda x, y, W, H: None)
    for st in ("focused", "pressed", "toggled"):
        nine(sh, "tbutton-" + st, 3, btn(st))
    nine(sh, "tbutton-disabled", 3, lambda x, y, W, H: None)

    # ---- text fields (widget/text_field): A0A0A0 border, black fill; focused = white border ----
    def field(border, fill):
        return ring2(border, fill, fill)
    nine(sh, "lineedit-normal", 2, field(c["fieldBorder"], c["fieldFill"]))
    nine(sh, "lineedit-focused", 2, field(c["focus"], c["fieldFill"]))
    nine(sh, "lineedit-disabled", 2, field(c["slotLight"] if not c["day"] else "#555555", c["track"]))

    # ---- generic sunken frame (inventory slot: dark top/left, light bottom/right) ----
    for st in ("normal", "focused"):
        nine(sh, "common-" + st, 1, bevel1(c["slotDark"] if c["day"] else c["ol"], c["hi"], c["slot"], c["slot"]),
             interior=False)

    # ---- group box: etched line ----
    dark_etch = "#555555" if c["day"] else c["lo"]
    light_etch = c["hi"]

    def etched(x, y, W, H):
        # outer ring dark top/left + light bottom/right; inner ring reversed
        if x == 0 or y == 0 or x == W - 1 or y == H - 1:
            return dark_etch if (x == 0 or y == 0) and not (x == W - 1 or y == H - 1) else (
                light_etch if (x == W - 1 or y == H - 1) and not (x == 0 or y == 0) else dark_etch)
        if x == 1 or y == 1 or x == W - 2 or y == H - 2:
            return light_etch if (x == 1 or y == 1) and not (x == W - 2 or y == H - 2) else (
                dark_etch if (x == W - 2 or y == H - 2) and not (x == 1 or y == 1) else light_etch)
        return None
    nine(sh, "group-normal", 2, etched, interior=False)

    # ---- tabs (creative-inventory tabs: outline, bevel, selected one joined to the panel) ----
    def tab(st):
        body = {"normal": c["tabNorm"], "focused": c["tabHov"], "toggled": c["panel"]}[st]
        edge = c["white"] if st == "focused" else ol
        hi = c["hi"] if st != "normal" else mix(body, "#ffffff", 0.35)

        def f(x, y, W, H):
            if y >= H - 2 and st == "toggled":
                # joined to the pane: open at the bottom, side outlines continue
                if x == 0 or x == W - 1:
                    return edge
                return body
            if x == 0 or y == 0 or x == W - 1 or y == H - 1:
                return edge
            if x == 1 or y == 1:
                return hi
            return body
        return f
    for st in ("normal", "focused", "toggled"):
        nine(sh, "tab-" + st, 2, tab(st))
        nine(sh, "floating-tab-" + st, 2, tab(st))
    # pane under the tabs
    nine(sh, "tabframe-normal", 2, ring_bevel(ol, c["hi"], c["lo"], c["panel"]), interior=False)
    for side, dims in (("top", (1, 2)), ("bottom", (1, 2)), ("left", (2, 1)), ("right", (2, 1))):
        for j in ("leftjunct", "rightjunct"):
            # the junction caps are the plain edge piece
            src = [it for it in sh.items if it[0] == "tabframe-normal-" + side][0]
            sh.add("tabframe-normal-%s-%s" % (side, j), src[1], src[2], list(src[3]))

    # ---- progress bar (XP bar): dark track + green fill ----
    nine(sh, "progress-normal", 2, ring2(ol, c["slotDark"] if not c["day"] else "#373737", "#1a1a1a" if c["day"] else c["slotDark"]),
         interior=True)
    nine(sh, "progress-disabled", 2, ring2(ol, c["trackDis"], c["trackDis"]), interior=True)

    def prog(hi, body, lo):
        def f(x, y, W, H):
            if y == 0:
                return hi
            if y == H - 1:
                return lo
            return body
        return f
    nine(sh, "progress-pattern-normal", 1, prog(c["fillGreenHi"], c["fillGreen"], c["fillGreenLo"]))
    nine(sh, "progress-pattern-disabled", 1, prog("#8a8a8a", "#6f6f6f", "#4a4a4a"))

    # ---- slider: groove (dark track) + filled part + button-style handle ----
    nine(sh, "slider-normal", 2, ring2(ol, c["track"], c["track"]))
    nine(sh, "slider-toggled", 2, ring2(ol, c["fillGreenLo"], c["fillGreenLo"]))
    for st in ("normal", "focused", "pressed", "disabled"):
        nine(sh, "slidercursor-" + st, 3, btn(st))

    # ---- check boxes / radio buttons (widget/checkbox: black outline, dark body, white outline on hover) ----
    def box_shade(edge, body):
        return lambda x, y, W, H: (edge if (x in (0, W - 1) or y in (0, H - 1)) else body)
    CB = 16
    cb_states = {
        "normal": (ol, c["track"]), "focused": (c["white"], c["track"]),
        "pressed": (c["white"], c["btnPress"] if not c["day"] else "#1c1c1c"),
        "disabled": (ol, c["trackDis"]),
    }
    check_pts = [(12, 3), (11, 4), (10, 5), (9, 6), (8, 7), (7, 8), (6, 9), (5, 8), (4, 7), (3, 6)]
    check_cells = set()
    for (x, y) in check_pts:
        check_cells.add((x, y))
        check_cells.add((x + 1, y))
    check_cells = {(x, y + 1) for (x, y) in check_cells}

    def with_marks(base, cells, col):
        def f(x, y, W, H):
            if (x, y) in cells:
                return col
            return base(x, y, W, H)
        return f
    dash = {(x, y) for x in range(4, 12) for y in (7, 8)}
    for st, (edge, body) in cb_states.items():
        mark = c["check"] if st != "disabled" else "#707070"
        b = box_shade(edge, body)
        solid(sh, "checkbox-%s" % st if st != "normal" else "checkbox-normal", CB, CB, b)
        solid(sh, "checkbox-checked-%s" % st, CB, CB, with_marks(b, check_cells, mark))
        solid(sh, "checkbox-tristate-%s" % st, CB, CB, with_marks(b, dash, mark))
    disc = pixel_disc(CB)
    disc_in = pixel_disc(CB - 2)
    core = {(x + 5, y + 5) for (x, y) in pixel_disc(6)}

    def radio_shade(edge, body, mark=None):
        def f(x, y, W, H):
            if mark and (x, y) in core:
                return mark
            if (x, y) in {(a + 1, b + 1) for (a, b) in disc_in}:
                return body
            if (x, y) in disc:
                return edge
            return None
        return f
    for st, (edge, body) in cb_states.items():
        mark = c["check"] if st != "disabled" else "#707070"
        solid(sh, "radio-%s" % st, CB, CB, radio_shade(edge, body))
        solid(sh, "radio-checked-%s" % st, CB, CB, radio_shade(edge, body, mark))

    # ---- scrollbar: thin dark track, bevelled light thumb (creative-inventory scroller) ----
    nine(sh, "scrollbargroove-normal", 1, ring1(ol, c["slotDark"] if not c["day"] else "#373737"))

    def thumb(st):
        body = {"normal": c["panel"], "focused": mix(c["panel"], "#ffffff", 0.18 if c["day"] else 0.1),
                "pressed": mix(c["panel"], "#000000", 0.12)}[st]
        if st == "pressed":
            return ring_bevel(ol, c["lo"] if not c["day"] else "#555555", c["hi"], body)
        return ring_bevel(ol, c["hi"], c["lo"] if not c["day"] else "#555555", body)
    for st in ("normal", "focused", "pressed"):
        nine(sh, "scrollbarslider-" + st, 2, thumb(st))

    # ---- item views: hover = faint wash + outline, selected = highlight with white outline ----
    wash = ("#ffffff", 0.14)
    nine(sh, "itemview-focused", 1, lambda x, y, W, H: (c["fieldBorder"], 1.0) if (x in (0, W - 1) or y in (0, H - 1)) else wash)
    nine(sh, "itemview-pressed", 1, lambda x, y, W, H: (c["white"], 1.0) if (x in (0, W - 1) or y in (0, H - 1)) else (c["highlight"], 1.0))
    nine(sh, "itemview-toggled", 1, lambda x, y, W, H: (c["white"], 1.0) if (x in (0, W - 1) or y in (0, H - 1)) else (c["highlight"], 1.0))

    # ---- menus (dark grey, black outline) ----
    nine(sh, "menu-normal", 2, ring2(ol, c["menuEdge"], c["menuFill"]))
    for st in ("pressed", "toggled", "focused"):
        nine(sh, "menuitem-" + st, 1, lambda x, y, W, H: (c["white"], 1.0) if (x in (0, W - 1) or y in (0, H - 1)) else (c["highlight"], 1.0))
    for st in ("focused", "pressed", "toggled"):
        nine(sh, "menubaritem-" + st, 1, lambda x, y, W, H: (c["white"], 1.0) if (x in (0, W - 1) or y in (0, H - 1)) else (c["highlight"], 1.0))

    # ---- tooltip: #100010 with the purple frame ----
    def tip(x, y, W, H):
        if x in (0, W - 1) or y in (0, H - 1):
            return c["tipFill"]
        if y == 1 or x == 1:
            return c["tipTop"] if (y == 1 and x < W - 1) or x == 1 else c["tipBot"]
        if y == H - 2 or x == W - 2:
            return c["tipBot"]
        return c["tipFill"]
    nine(sh, "tooltip-normal", 2, tip)
    # Kvantum asks for plain 'tooltip' (interior + frame) in some paths
    nine(sh, "tooltip", 2, tip)

    # ---- title bar (MDI) ----
    solid(sh, "titlebar-normal", 4, 4, flat("#373737" if c["day"] else c["lo"]))
    solid(sh, "titlebar-focused", 4, 4, flat("#373737" if c["day"] else c["hi"]))

    # ---- splitter / grips ----
    solid(sh, "splitter-normal", 1, 1, lambda x, y, W, H: None)
    solid(sh, "splitter-focused", 1, 1, flat((c["highlight"], 0.5)))
    solid(sh, "splitter-pressed", 1, 1, flat(c["highlight"]))
    for st, col in (("normal", c["lo"] if not c["day"] else "#555555"), ("focused", c["white"]), ("pressed", c["white"])):
        # three 2x2 dots (dark with a light shadow), 16 px tall
        def grip(x, y, W, H, col=col):
            if x < 2 and y % 5 < 2 and y < 12:
                return col
            if 1 <= x < 3 and 1 <= y % 5 < 3 and y < 13 and not (x < 2 and y % 5 < 2):
                return c["hi"]
            return None
        solid(sh, "splitter-grip-%s" % st, 4, 14, grip)

    def tgrip(x, y, W, H):
        if x in (1, 2) and y % 4 in (0, 1):
            return "#555555" if c["day"] else c["lo"]
        if x in (2, 3) and y % 4 in (1, 2) and not (x == 2 and y % 4 == 1):
            return c["hi"]
        return None
    solid(sh, "toolbar-handle", 5, 16, tgrip)
    nine(sh, "toolbar-normal", 1, lambda x, y, W, H: None, interior=False)

    def rgrip(col, light):
        def f(x, y, W, H):
            d = (W - 1 - x) + (H - 1 - y)
            if d <= 11 and d % 4 == 0 and d != 0:
                return col
            if d <= 11 and d % 4 == 1 and d != 1:
                return light
            return None
        return f
    solid(sh, "resize-grip-normal", 13, 13, rgrip("#555555" if c["day"] else c["lo"], c["hi"]))
    solid(sh, "resize-grip-focused", 13, 13, rgrip(c["white"], c["lo"] if not c["day"] else "#555555"))
    solid(sh, "header-separator", 2, 16, lambda x, y, W, H: ("#555555" if c["day"] else c["lo"]) if x == 0 else c["hi"])

    # ---- arrows (white with a black outline, readable on any background) ----
    AR = 9
    for d in ("up", "down", "left", "right"):
        for st in ("normal", "focused", "pressed", "toggled", "disabled"):
            fill = {"normal": c["white"], "focused": "#ffffa0", "pressed": "#ffffa0", "toggled": c["white"],
                    "disabled": "#707070"}[st]
            sh.add("arrow-%s-%s" % (d, st), AR, AR,
                   arrow_ops(d, AR, fill, ol))
    return sh


# --------------------------------------------------------------------------------------------- kvconfig
def build_kvconfig(name, c, p):
    day = c["day"]
    T = c["text"]                      # text on panels
    WHITE = "#ffffff"
    hl_text = "#ffffff"
    L = []
    w = L.append

    def sec(title, **kw):
        w("[%s]" % title)
        for k, v in kw.items():
            w("%s=%s" % (k.replace("__", "."), v))
        w("")

    comment = "Overworld Hyprland - %s (Minecraft GUI: bevelled 1px-outline widgets, no rounding, generated by build.py)" % name
    w("[%General]")
    w("author=Overworld")
    w("comment=" + comment)
    for k, v in [("x11drag", "all"), ("alt_mnemonic", "true"), ("left_tabs", "false"), ("attach_active_tab", "true"),
                 ("group_toolbar_buttons", "false"), ("spread_progressbar", "true"), ("progressbar_thickness", "8"),
                 ("composite", "false"), ("translucent_windows", "false"), ("blurring", "false"),
                 ("popup_blurring", "false"), ("menu_shadow_depth", "0"), ("tooltip_shadow_depth", "0"),
                 ("spread_menuitems", "true"), ("splitter_width", "5"), ("scroll_width", "12"),
                 ("scroll_min_extent", "32"), ("scroll_arrows", "false"), ("combo_as_lineedit", "true"),
                 ("inline_spin_indicators", "true"), ("slider_width", "6"), ("slider_handle_width", "16"),
                 ("slider_handle_length", "10"), ("check_size", "16"), ("toolbar_icon_size", "16"),
                 ("animate_states", "false"), ("transient_groove", "false"), ("transient_scrollbar", "false"),
                 ("reduce_window_opacity", "0"), ("reduce_menu_opacity", "0"), ("small_icon_size", "16"),
                 ("button_contents_shift", "true"), ("layout_spacing", "4"), ("layout_margin", "6"),
                 ("submenu_overlap", "0"), ("submenu_delay", "250"), ("scrollbar_in_view", "false"),
                 ("no_inactive_tab", "false"), ("tooltip_delay", "-1"), ("click_behavior", "0"),
                 ("merge_menubar_with_toolbar", "false"), ("fill_rubberband", "false")]:
        w("%s=%s" % (k, v))
    w("")

    sec("GeneralColors", **{
        "window__color": c["panel"], "base__color": c["base"], "alt__base__color": c["altBase"],
        "button__color": c["btn"], "light__color": c["hi"], "mid__light__color": mix(c["panel"], c["hi"], 0.5),
        "dark__color": c["lo"] if not day else "#555555", "mid__color": mix(c["panel"], c["lo"] if not day else "#555555", 0.5),
        "highlight__color": c["highlight"],
        "inactive__highlight__color": mix(c["highlight"], c["panel"], 0.4),
        "text__color": ("#ffffff" if day else T), "window__text__color": T, "button__text__color": c["btnText"],
        "disabled__text__color": c["disText"], "tooltip__base__color": c["tipFill"],
        "tooltip__text__color": c["tipText"], "highlight__text__color": hl_text,
        "link__color": c["link"], "link__visited__color": c["linkv"],
    })
    sec("Hacks", respect_darkness="true", transparent_ktitle_label="true", transparent_dolphin_view="false",
        transparent_pcmanfm_sidepane="false", blur_translucent="false", centered_forms="false", kinetic_scrolling="false",
        middle_click_scroll="false", opaque_colors="true", normal_default_pushbutton="true",
        iconless_pushbutton="false", iconless_menu="false", disabled_icon_opacity="0.6", lxqtmainmenu_iconsize="0",
        scroll_jump_workaround="false", single_top_toolbar="false", no_selection_tint="false", tint_on_mouseover="0",
        style_vertical_toolbars="false", transparent_menutitle="false", blur_only_active_window="false",
        respect_darkness_fix="false")

    shadow = dict(text__shadow="1", text__shadow__xshift="1", text__shadow__yshift="1",
                  text__shadow__color="#3f3f3f", text__shadow__alpha="255", text__shadow__depth="1")
    noshadow = dict(text__shadow="0")
    FOCUS_TXT = "#ffffa0" if day else "#ffffa0"     # the game's highlighted-button text colour

    sec("PanelButtonCommand", frame="true", frame__element="button", frame__top="3", frame__bottom="3",
        frame__left="3", frame__right="3", interior="true", interior__element="button", indicator__size="9",
        text__normal__color=c["btnText"], text__focus__color=FOCUS_TXT, text__press__color=c["btnText"],
        text__toggle__color=c["btnText"], text__margin="1", text__iconspacing="4", indicator__element="arrow",
        text__margin__top="3", text__margin__bottom="3", text__margin__left="5", text__margin__right="5", **shadow)
    sec("PanelButtonTool", inherits="PanelButtonCommand", interior__element="tbutton", frame__element="tbutton",
        text__normal__color=T, text__focus__color=c["btnText"], text__press__color=c["btnText"],
        text__toggle__color=c["btnText"], text__margin__top="2", text__margin__bottom="2", text__margin__left="2",
        text__margin__right="2", **noshadow)
    sec("Dock", inherits="PanelButtonCommand", frame="true", interior="true", text__normal__color=T, **noshadow)
    sec("DockTitle", inherits="PanelButtonCommand", frame="false", interior="false", text__normal__color=T,
        text__focus__color=T, text__bold="true", **noshadow)
    sec("IndicatorSpinBox", inherits="PanelButtonCommand", indicator__element="arrow", frame__top="2",
        frame__bottom="2", frame__left="2", frame__right="2", indicator__size="9", text__normal__color=c["fieldText"],
        text__focus__color=c["fieldText"], **noshadow)
    sec("RadioButton", inherits="PanelButtonCommand", frame="false", interior__element="radio", text__normal__color=T,
        text__focus__color=T, text__press__color=T, text__toggle__color=T, text__margin__left="4", **noshadow)
    sec("CheckBox", inherits="PanelButtonCommand", frame="false", interior__element="checkbox", text__normal__color=T,
        text__focus__color=T, text__press__color=T, text__toggle__color=T, text__margin__left="4", **noshadow)
    sec("GenericFrame", inherits="PanelButtonCommand", frame="true", interior="false", frame__element="common",
        interior__element="common", frame__top="1", frame__bottom="1", frame__left="1", frame__right="1",
        text__normal__color=T, **noshadow)
    sec("LineEdit", inherits="PanelButtonCommand", frame__element="lineedit", interior__element="lineedit",
        text__margin__left="3", text__margin__right="3", text__margin__top="3", text__margin__bottom="3",
        text__normal__color=c["fieldText"], text__focus__color=c["fieldText"], text__press__color=c["fieldText"],
        text__toggle__color=c["fieldText"], **noshadow)
    sec("DropDownButton", inherits="PanelButtonCommand", indicator__element="arrow-down")
    sec("IndicatorArrow", indicator__element="arrow", indicator__size="9")
    sec("ToolboxTab", inherits="PanelButtonCommand", text__normal__color=T, **noshadow)
    sec("Tab", inherits="PanelButtonCommand", interior__element="tab", frame__element="tab", indicator__element="tab",
        text__margin__left="6", text__margin__right="6", text__margin__top="3", text__margin__bottom="3",
        frame__top="2", frame__bottom="2", frame__left="2", frame__right="2",
        text__normal__color=("#373737" if day else T), text__focus__color=("#1a1a1a" if day else FOCUS_TXT),
        text__press__color=T, text__toggle__color=T, min_width="+4", min_height="+2", **noshadow)
    sec("TabFrame", inherits="PanelButtonCommand", frame__element="tabframe", interior="false", frame__top="2",
        frame__bottom="2", frame__left="2", frame__right="2", **noshadow)
    sec("TreeExpander", inherits="PanelButtonCommand", frame="false", interior="false", indicator__size="9",
        text__normal__color=T, **noshadow)
    sec("HeaderSection", inherits="PanelButtonCommand", frame__top="3", frame__bottom="3", frame__left="3",
        frame__right="3", text__margin__top="2", text__margin__bottom="2")
    sec("SizeGrip", inherits="PanelButtonCommand", frame="false", interior="false", indicator__element="resize-grip",
        indicator__size="13")
    sec("Toolbar", inherits="PanelButtonCommand", indicator__element="toolbar", indicator__size="5", text__margin="0",
        frame="false", interior="false", text__normal__color=T, **noshadow)
    sec("Slider", inherits="PanelButtonCommand", frame__element="slider", interior__element="slider",
        frame__top="2", frame__bottom="2", frame__left="2", frame__right="2", **noshadow)
    sec("SliderCursor", inherits="PanelButtonCommand", frame="true", frame__element="slidercursor",
        interior="true", interior__element="slidercursor", frame__top="3", frame__bottom="3", frame__left="3",
        frame__right="3")
    sec("Progressbar", inherits="PanelButtonCommand", frame__element="progress", interior__element="progress",
        frame__top="2", frame__bottom="2", frame__left="2", frame__right="2", text__margin="0",
        text__normal__color=WHITE, text__focus__color=WHITE, text__press__color=WHITE, text__toggle__color=WHITE,
        text__bold="true", text__shadow="1", text__shadow__xshift="1", text__shadow__yshift="1",
        text__shadow__color="#000000", text__shadow__alpha="255", text__shadow__depth="1")
    sec("ProgressbarContents", inherits="PanelButtonCommand", frame="true", frame__element="progress-pattern",
        interior__element="progress-pattern", frame__top="1", frame__bottom="1", frame__left="1", frame__right="1")
    sec("ItemView", inherits="PanelButtonCommand", text__margin="1", text__margin__top="1", text__margin__bottom="1",
        text__margin__left="2", text__margin__right="2", frame__element="itemview", interior__element="itemview",
        frame__top="1", frame__bottom="1", frame__left="1", frame__right="1", text__normal__color=WHITE,
        text__focus__color=WHITE, text__press__color=hl_text, text__toggle__color=hl_text, **noshadow)
    sec("Splitter", inherits="PanelButtonCommand", interior__element="splitter", frame="false",
        frame__top="0", frame__bottom="0", frame__left="1", frame__right="1", indicator__element="splitter-grip",
        indicator__size="14")
    sec("Scrollbar", inherits="PanelButtonCommand", indicator__size="9")
    sec("ScrollbarSlider", inherits="PanelButtonCommand", frame__element="scrollbarslider",
        interior__element="scrollbarslider", frame__top="2", frame__bottom="2", frame__left="2", frame__right="2")
    sec("ScrollbarGroove", inherits="PanelButtonCommand", interior__element="scrollbargroove",
        frame__element="scrollbargroove", frame__top="1", frame__bottom="1", frame__left="1", frame__right="1")
    sec("MenuItem", inherits="PanelButtonCommand", frame="true", frame__element="menuitem",
        interior__element="menuitem", indicator__element="arrow", text__normal__color=WHITE, text__focus__color=WHITE,
        text__press__color=WHITE, text__toggle__color=WHITE, text__margin__top="2", text__margin__bottom="2",
        text__margin__left="4", text__margin__right="4", frame__top="1", frame__bottom="1", frame__left="1",
        frame__right="1", **noshadow)
    sec("MenuBarItem", inherits="PanelButtonCommand", interior__element="menubaritem", frame__element="menubaritem",
        frame__top="1", frame__bottom="1", frame__left="1", frame__right="1", text__margin__left="6",
        text__margin__right="6", text__margin__top="2", text__margin__bottom="2", text__normal__color=T,
        text__focus__color=WHITE, text__press__color=WHITE, text__toggle__color=WHITE, **noshadow)
    sec("TitleBar", inherits="PanelButtonCommand", frame="false", interior__element="titlebar",
        text__normal__color="#c0c0c0", text__focus__color=WHITE, text__bold="true", **noshadow)
    sec("ComboBox", inherits="PanelButtonCommand")
    sec("Menu", inherits="PanelButtonCommand", frame__top="2", frame__bottom="2", frame__left="2", frame__right="2",
        frame__element="menu", interior__element="menu", text__normal__color=WHITE, **noshadow)
    sec("GroupBox", inherits="GenericFrame", frame="true", frame__element="group", text__margin="0",
        frame__top="2", frame__bottom="2", frame__left="2", frame__right="2", text__normal__color=T, **noshadow)
    sec("TabBarFrame", inherits="GenericFrame", frame="false", interior="false", **noshadow)
    sec("ToolTip", inherits="GenericFrame", frame__top="2", frame__bottom="2", frame__left="2", frame__right="2",
        interior="true", text__margin="2", interior__element="tooltip", frame__element="tooltip",
        text__normal__color=c["tipText"], **noshadow)
    sec("StatusBar", inherits="GenericFrame", frame="false", interior="false", text__normal__color=T)
    sec("Window", interior="false")
    return "\n".join(L).rstrip("\n") + "\n"


def contrast_report(name, c):
    pairs = [
        ("text/window", c["text"], c["panel"]),
        ("base text/base", "#ffffff", c["base"]),
        ("highlight.text/highlight", "#ffffff", c["highlight"]),
        ("button.text/button", c["btnText"], c["btn"]),
        ("button focus text/hover button", "#ffffa0", c["btnHov"]),
        ("button.text/pressed", c["btnText"], c["btnPress"]),
        ("field text/field", c["fieldText"], c["fieldFill"]),
        ("tooltip", c["tipText"], c["tipFill"]),
        ("menu text/menu", "#ffffff", c["menuFill"]),
        ("tab text/tab normal", "#373737" if c["day"] else c["text"], c["tabNorm"]),
        ("tab text/tab hover", "#1a1a1a" if c["day"] else "#ffffa0", c["tabHov"]),
        ("tab text/tab selected", c["text"], c["panel"]),
        ("disabled text/button disabled", c["btnTextDis"], c["btnDis"]),
    ]
    for lab, a, b in pairs:
        yield lab, a, b, contrast(a, b)


def main():
    themes = [("Day", "light"), ("Night", "dark")]
    bad = 0
    for short, mode in themes:
        name = "Overworld" + short
        p = load_palette(mode)
        c = theme_colours(short, p)
        sh = build_svg(c)
        d = os.path.join(HERE, name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, name + ".svg"), "w") as f:
            f.write(sh.render())
        with open(os.path.join(d, name + ".kvconfig"), "w") as f:
            f.write(build_kvconfig(name, c, p))
        print("built %s (%d svg elements)" % (name, len(sh.items)))
        for lab, a, b, r in contrast_report(name, c):
            flag = "" if r >= 4.5 else "   <-- below 4.5"
            if r < 4.5 and lab != "disabled text/button disabled":
                bad += 1
            print("   %-34s %s on %s  %.2f%s" % (lab, a, b, r, flag))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
