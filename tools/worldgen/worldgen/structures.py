"""Small hand-placed builds: houses, tower, lighthouse, well, fortress bridge, end city tower and so on.

Each takes a Builder bound to a world. Coordinates are world indices; ``facing`` is the direction the build faces.
"""
from __future__ import annotations

import numpy as np


class Builder:
    def __init__(self, blocks: np.ndarray, reg):
        self.b = blocks
        self.reg = reg

    def set(self, x, y, z, state: str | int, **props):
        s = self.reg.id(state, **props) if isinstance(state, str) else state
        if 0 <= x < self.b.shape[0] and 0 <= y < self.b.shape[1] and 0 <= z < self.b.shape[2]:
            self.b[x, y, z] = s

    def box(self, x0, y0, z0, x1, y1, z1, state: str | int, **props):
        """Inclusive box."""
        s = self.reg.id(state, **props) if isinstance(state, str) else state
        self.b[max(x0, 0):x1 + 1, max(y0, 0):y1 + 1, max(z0, 0):z1 + 1] = s

    def clear(self, x0, y0, z0, x1, y1, z1):
        self.b[max(x0, 0):x1 + 1, max(y0, 0):y1 + 1, max(z0, 0):z1 + 1] = 0

    def pillar_down(self, x, y, z, state: str | int, limit=40, **props):
        """Foundation: extend down until solid ground."""
        s = self.reg.id(state, **props) if isinstance(state, str) else state
        for yy in range(y, max(y - limit, 0), -1):
            if self.b[x, yy, z] != 0 and self.reg.kind[self.b[x, yy, z]] != 2:
                break
            self.b[x, yy, z] = s


def house(bd: Builder, x, y, z, *, w=7, d=9, log="oak_log", plank="oak_planks", stair="oak_stairs", slab="oak_slab",
          found="cobblestone", door="oak_door", torch=True, wall_h=3):
    """Gable-roofed house. (x, y, z) is the floor corner with the lowest coordinates; the door is on the south side."""
    x1, z1 = x + w - 1, z + d - 1
    for xx in range(x - 1, x1 + 2):
        for zz in range(z - 1, z1 + 2):
            bd.pillar_down(xx, y - 1, zz, found)
    bd.clear(x - 2, y, z - 2, x1 + 2, y + 14, z1 + 2)
    bd.box(x, y - 1, z, x1, y - 1, z1, found)
    for yy in range(y, y + wall_h):
        for xx in range(x, x1 + 1):
            for zz in (z, z1):
                bd.set(xx, yy, zz, plank)
        for zz in range(z, z1 + 1):
            for xx in (x, x1):
                bd.set(xx, yy, zz, plank)
        for cx, cz in ((x, z), (x1, z), (x, z1), (x1, z1)):
            bd.set(cx, yy, cz, log, axis="y")
    # Windows: glass panes along the long walls, one each side of the door.
    pane_ns = dict(east=True, west=True, north=False, south=False)
    pane_ew = dict(north=True, south=True, east=False, west=False)
    for zz in range(z + 2, z1 - 1, 3):
        for xx in (x, x1):
            bd.set(xx, y + 1, zz, "glass_pane", **pane_ew)
    mid = x + w // 2
    for xx in (x + 1, x1 - 1):
        bd.set(xx, y + 1, z1, "glass_pane", **pane_ns)
        bd.set(xx, y + 1, z, "glass_pane", **pane_ns)
    bd.set(mid, y, z1, door, facing="south", half="lower", hinge="left", open="false")
    bd.set(mid, y + 1, z1, door, facing="south", half="upper", hinge="left", open="false")
    bd.set(mid, y - 1, z1 + 1, "cobblestone_slab", type="top")
    if torch:
        bd.set(mid - 1, y + 2, z1 + 1, "wall_torch", facing="south")
        bd.set(mid + 1, y + 2, z1 + 1, "wall_torch", facing="south")
    # Lantern lights the inside (windows glow at night).
    bd.set(x + w // 2, y + wall_h - 1, z + d // 2, "lantern", hanging="true")
    # Gable roof over the width.
    half = w // 2 + 1
    ry = y + wall_h
    for i in range(half + 1):
        xa, xb = x - 1 + i, x1 + 1 - i
        for zz in range(z - 1, z1 + 2):
            if xa < xb:
                bd.set(xa, ry + i, zz, stair, facing="east", half="bottom", shape="straight")
                bd.set(xb, ry + i, zz, stair, facing="west", half="bottom", shape="straight")
            elif xa == xb:
                bd.set(xa, ry + i, zz, slab, type="bottom")
        # Gable infill.
        for zz in (z, z1):
            for xx in range(xa + 1, xb):
                bd.set(xx, ry + i, zz, plank)


def lamp_post(bd: Builder, x, y, z, h=3, fence="oak_fence"):
    for k in range(h):
        bd.set(x, y + k, z, fence, north="false", south="false", east="false", west="false")
    bd.set(x, y + h, z, "torch")


def farm(bd: Builder, x, y, z, w=7, d=5, crop="wheat"):
    bd.box(x - 1, y - 1, z - 1, x + w, y - 1, z + d, "oak_log", axis="x")
    for xx in range(x, x + w):
        for zz in range(z, z + d):
            if xx == x + w // 2:
                bd.set(xx, y - 1, zz, "water")
            else:
                bd.set(xx, y - 1, zz, "farmland", moisture=7)
                bd.set(xx, y, zz, crop, age=7)


def tower(bd: Builder, x, y, z, *, r=3, h=16, wall="stone_bricks", accent="mossy_stone_bricks", rng=None):
    """Round-ish watch tower with crenellations and lanterns on top."""
    rng = rng or np.random.default_rng(0)
    for xx in range(x - r, x + r + 1):
        for zz in range(z - r, z + r + 1):
            d2 = (xx - x) ** 2 + (zz - z) ** 2
            if d2 <= r * r + 1:
                bd.pillar_down(xx, y - 1, zz, wall)
                for yy in range(y, y + h):
                    if d2 >= (r - 1) ** 2 + 1 or yy in (y + h - 1,):
                        bd.set(xx, yy, zz, accent if rng.random() < 0.25 else wall)
                    else:
                        bd.set(xx, yy, zz, 0)
    # Parapet.
    for xx in range(x - r - 1, x + r + 2):
        for zz in range(z - r - 1, z + r + 2):
            d2 = (xx - x) ** 2 + (zz - z) ** 2
            if (r + 0.3) ** 2 <= d2 <= (r + 1.2) ** 2:
                bd.set(xx, y + h - 1, zz, wall)
                if (xx + zz) % 2 == 0:
                    bd.set(xx, y + h, zz, wall)
    # Arrow slits and a door.
    for yy in range(y + 4, y + h - 2, 4):
        bd.set(x, yy, z + r, 0)
        bd.set(x + r, yy, z, 0)
        bd.set(x - r, yy, z, 0)
    bd.set(x, y, z + r, 0)
    bd.set(x, y + 1, z + r, 0)
    bd.set(x - 2, y + h, z, "lantern", hanging="false")
    bd.set(x + 2, y + h, z, "lantern", hanging="false")
    bd.set(x, y + h, z - 2, "lantern", hanging="false")
    bd.set(x, y + h, z + 2, "lantern", hanging="false")


def lighthouse(bd: Builder, x, y, z, *, h=26):
    """A striped lighthouse with a glowing lantern room."""
    r = 3
    for yy in range(y - 12, y + h):
        band = (yy - y) // 5 % 2
        wall = "white_concrete" if band == 0 else "red_concrete"
        for xx in range(x - r, x + r + 1):
            for zz in range(z - r, z + r + 1):
                d2 = (xx - x) ** 2 + (zz - z) ** 2
                if d2 <= r * r + 1:
                    bd.set(xx, yy, zz, wall if d2 >= (r - 1) ** 2 + 1 else "stone")
    top = y + h
    for xx in range(x - r - 1, x + r + 2):
        for zz in range(z - r - 1, z + r + 2):
            d2 = (xx - x) ** 2 + (zz - z) ** 2
            if d2 <= (r + 1) ** 2 + 1:
                bd.set(xx, top, zz, "stone_brick_slab", type="bottom")
    for yy in range(top + 1, top + 4):
        for xx in range(x - 2, x + 3):
            for zz in range(z - 2, z + 3):
                edge = abs(xx - x) == 2 or abs(zz - z) == 2
                if edge and not (abs(xx - x) == 2 and abs(zz - z) == 2):
                    bd.set(xx, yy, zz, "glass")
                elif edge:
                    bd.set(xx, yy, zz, "dark_oak_fence", north="false", south="false", east="false", west="false")
                elif abs(xx - x) <= 1 and abs(zz - z) <= 1:
                    bd.set(xx, yy, zz, "sea_lantern" if yy == top + 2 else "glowstone")
    bd.box(x - 2, top + 4, z - 2, x + 2, top + 4, z + 2, "dark_prismarine")
    bd.box(x - 1, top + 5, z - 1, x + 1, top + 5, z + 1, "dark_prismarine")
    bd.set(x, top + 6, z, "dark_prismarine")


def dock(bd: Builder, x, y, z0, z1, width=3):
    """Pier running along z at height y."""
    for z in range(min(z0, z1), max(z0, z1) + 1):
        for xx in range(x, x + width):
            bd.set(xx, y, z, "oak_planks")
        if (z - z0) % 4 == 0:
            for xx in (x, x + width - 1):
                for yy in range(y - 6, y):
                    bd.set(xx, yy, z, "oak_log", axis="y")
                bd.set(xx, y + 1, z, "oak_fence", north="false", south="false", east="false", west="false")
                if (z - z0) % 8 == 0:
                    bd.set(xx, y + 2, z, "lantern", hanging="false")


def well(bd: Builder, x, y, z, stone="sandstone", slab="sandstone_slab"):
    for xx in range(x - 2, x + 3):
        for zz in range(z - 2, z + 3):
            bd.pillar_down(xx, y - 1, zz, stone)
    bd.box(x - 1, y - 1, z - 1, x + 1, y - 1, z + 1, "water")
    for xx in range(x - 2, x + 3):
        for zz in range(z - 2, z + 3):
            if abs(xx - x) == 2 or abs(zz - z) == 2:
                bd.set(xx, y, zz, stone)
    for cx, cz in ((x - 1, z - 1), (x + 1, z - 1), (x - 1, z + 1), (x + 1, z + 1)):
        bd.box(cx, y + 1, cz, cx, y + 2, cz, stone)
    bd.box(x - 1, y + 3, z - 1, x + 1, y + 3, z + 1, slab, type="bottom")
    bd.set(x, y + 3, z, "lantern", hanging="true")


def pavilion(bd: Builder, x, y, z, plank="cherry_planks", log="cherry_log", stair="cherry_stairs", r=3):
    """Open-sided pavilion: four posts and a two-step roof with hanging lanterns."""
    for xx in range(x - r, x + r + 1):
        for zz in range(z - r, z + r + 1):
            bd.pillar_down(xx, y - 1, zz, plank)
    for cx, cz in ((x - r, z - r), (x + r, z - r), (x - r, z + r), (x + r, z + r)):
        bd.box(cx, y, cz, cx, y + 3, cz, log, axis="y")
    for i, ry in enumerate((y + 4, y + 5, y + 6)):
        rr = r + 1 - i
        for xx in range(x - rr, x + rr + 1):
            for zz in range(z - rr, z + rr + 1):
                if abs(xx - x) == rr:
                    bd.set(xx, ry, zz, stair, facing="east" if xx < x else "west", half="bottom", shape="straight")
                elif abs(zz - z) == rr:
                    bd.set(xx, ry, zz, stair, facing="south" if zz < z else "north", half="bottom", shape="straight")
                else:
                    bd.set(xx, ry, zz, plank)
    bd.set(x - r + 1, y + 3, z - r + 1, "lantern", hanging="true")
    bd.set(x + r - 1, y + 3, z - r + 1, "lantern", hanging="true")
    bd.set(x - r + 1, y + 3, z + r - 1, "lantern", hanging="true")
    bd.set(x + r - 1, y + 3, z + r - 1, "lantern", hanging="true")


def fortress_bridge(bd: Builder, x, y, z0, z1, width=5):
    """A nether-brick fortress span: deck, walls with fence windows, buttressed arches down to the lava."""
    a, b = min(z0, z1), max(z0, z1)
    for z in range(a, b + 1):
        bd.box(x, y, z, x + width - 1, y, z, "nether_bricks")
        bd.box(x, y + 1, z, x, y + 2, z, "nether_bricks")
        bd.box(x + width - 1, y + 1, z, x + width - 1, y + 2, z, "nether_bricks")
        if z % 3 == 1:
            bd.set(x, y + 2, z, "nether_brick_fence", north="true", south="true", east="false", west="false")
            bd.set(x + width - 1, y + 2, z, "nether_brick_fence", north="true", south="true", east="false", west="false")
        if z % 12 < 3:
            bd.box(x - 1, y - 40, z, x + width, y - 1, z, "nether_bricks")
        elif z % 12 == 3 or z % 12 == 11:
            bd.box(x - 1, y - 6, z, x + width, y - 1, z, "nether_bricks")
        elif z % 12 == 4 or z % 12 == 10:
            bd.box(x, y - 3, z, x + width - 1, y - 1, z, "nether_bricks")
        elif z % 12 in (5, 9):
            bd.box(x, y - 2, z, x + width - 1, y - 1, z, "nether_bricks")
        else:
            bd.box(x, y - 1, z, x + width - 1, y - 1, z, "nether_bricks")


def fortress_bridge_x(bd: Builder, x0, x1, y, z, width=5):
    """The same span running along x, so a camera looking north sees its arches side on."""
    a, b = min(x0, x1), max(x0, x1)
    for x in range(a, b + 1):
        bd.box(x, y, z, x, y, z + width - 1, "nether_bricks")
        bd.box(x, y + 1, z, x, y + 2, z, "nether_bricks")
        bd.box(x, y + 1, z + width - 1, x, y + 2, z + width - 1, "nether_bricks")
        if x % 3 == 1:
            bd.set(x, y + 2, z + width - 1, "nether_brick_fence", east="true", west="true", north="false", south="false")
        m = x % 14
        if m < 3:
            bd.box(x, 2, z - 1, x, y - 1, z + width, "nether_bricks")
        elif m in (3, 13):
            bd.box(x, y - 7, z - 1, x, y - 1, z + width, "nether_bricks")
        elif m in (4, 12):
            bd.box(x, y - 4, z, x, y - 1, z + width - 1, "nether_bricks")
        elif m in (5, 11):
            bd.box(x, y - 3, z, x, y - 1, z + width - 1, "nether_bricks")
        elif m in (6, 10):
            bd.box(x, y - 2, z, x, y - 1, z + width - 1, "nether_bricks")
        else:
            bd.box(x, y - 1, z, x, y - 1, z + width - 1, "nether_bricks")
        if m == 1:
            bd.set(x, y + 3, z, "lantern", hanging="false")
            bd.set(x, y + 3, z + width - 1, "lantern", hanging="false")


def nether_portal(bd: Builder, x, y, z):
    """Obsidian frame with the portal lit, facing south (axis x)."""
    for xx in range(x, x + 4):
        bd.set(xx, y, z, "obsidian")
        bd.set(xx, y + 4, z, "obsidian")
    for yy in range(y, y + 5):
        bd.set(x, yy, z, "obsidian")
        bd.set(x + 3, yy, z, "obsidian")
    for xx in range(x + 1, x + 3):
        for yy in range(y + 1, y + 4):
            bd.set(xx, yy, z, "nether_portal", axis="x")


def end_tower(bd: Builder, x, y, z, *, h=26, rng=None):
    """A purpur end-city style tower: stacked square floors with end rods at the corners."""
    rng = rng or np.random.default_rng(1)
    r = 3
    yy = y
    while yy < y + h:
        floor_h = int(rng.integers(5, 8))
        for xx in range(x - r, x + r + 1):
            for zz in range(z - r, z + r + 1):
                edge = abs(xx - x) == r or abs(zz - z) == r
                for k in range(floor_h):
                    if edge:
                        corner = abs(xx - x) == r and abs(zz - z) == r
                        bd.set(xx, yy + k, zz, "purpur_pillar" if corner else "purpur_block", **(dict(axis="y") if corner else {}))
                    elif k == 0:
                        bd.set(xx, yy + k, zz, "end_stone_bricks")
                    else:
                        bd.set(xx, yy + k, zz, 0)
        for win in range(-1, 2):
            bd.set(x + win, yy + 2, z + r, "magenta_stained_glass")
            bd.set(x + r, yy + 2, z + win, "magenta_stained_glass")
            bd.set(x - r, yy + 2, z + win, "magenta_stained_glass")
            bd.set(x + win, yy + 2, z - r, "magenta_stained_glass")
        yy += floor_h
        # Eaves.
        for xx in range(x - r - 1, x + r + 2):
            for zz in range(z - r - 1, z + r + 2):
                if abs(xx - x) == r + 1 or abs(zz - z) == r + 1:
                    bd.set(xx, yy, zz, "purpur_slab", type="bottom")
                else:
                    bd.set(xx, yy, zz, "end_stone_bricks")
        yy += 1
        for cx, cz in ((x - r - 1, z - r - 1), (x + r + 1, z - r - 1), (x - r - 1, z + r + 1), (x + r + 1, z + r + 1)):
            bd.set(cx, yy, cz, "end_rod", facing="up")
        r = max(r - int(rng.integers(0, 2)), 2)
    bd.box(x - 1, yy, z - 1, x + 1, yy + 1, z + 1, "purpur_block")
    bd.set(x, yy + 2, z, "end_rod", facing="up")
