"""Vegetation templates (shapes follow the game's tree and foliage placers) and a fast numba stamper."""
from __future__ import annotations

import math

import numpy as np
from numba import njit


class Template:
    """Sparse voxel template built in Python, stamped thousands of times from numba."""

    def __init__(self):
        self.vox: dict[tuple[int, int, int], tuple[int, int]] = {}

    def put(self, x, y, z, state, force=0):
        cur = self.vox.get((x, y, z))
        if cur is None or force >= cur[1]:
            self.vox[(x, y, z)] = (state, force)

    def leaf(self, x, y, z, state):
        if (x, y, z) not in self.vox:
            self.vox[(x, y, z)] = (state, 0)

    def line(self, a, b, state_for_axis, force=1):
        """Log line between two points; the log axis follows the dominant direction, like branch placers do."""
        dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        n = max(abs(dx), abs(dy), abs(dz), 1)
        axis = "y" if abs(dy) >= max(abs(dx), abs(dz)) else ("x" if abs(dx) >= abs(dz) else "z")
        for i in range(n + 1):
            t = i / n
            self.put(round(a[0] + dx * t), round(a[1] + dy * t), round(a[2] + dz * t), state_for_axis(axis), force)


def _disc(t: Template, cx, y, cz, r, leaf, rng, corner_keep=0.5):
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            corner = abs(dx) == r and abs(dz) == r and r > 0
            if corner and rng.random() > corner_keep:
                continue
            t.leaf(cx + dx, y, cz + dz, leaf)


def oak(reg, rng, log="oak_log", leaves="oak_leaves", hmin=4, hmax=6) -> Template:
    t = Template()
    s_log = reg.id(log, axis="y")
    s_leaf = reg.id(leaves)
    h = int(rng.integers(hmin, hmax + 1))
    for y in range(h):
        t.put(0, y + 1, 0, s_log, 1)
    top = h + 1
    for offset in (-3, -2):
        _disc(t, 0, top + offset, 0, 2, s_leaf, rng, 0.5)
    _disc(t, 0, top - 1, 0, 1, s_leaf, rng, 0.5)
    _disc(t, 0, top, 0, 1, s_leaf, rng, 0.0)
    return t


def fancy_oak(reg, rng, log="oak_log", leaves="oak_leaves") -> Template:
    t = Template()
    leaf = reg.id(leaves)
    log_for = lambda axis: reg.id(log, axis=axis)
    h = int(rng.integers(7, 13))
    t.line((0, 1, 0), (0, h, 0), log_for)
    n = int(rng.integers(4, 7))
    ends = [(0, h, 0)]
    for i in range(n):
        ang = rng.random() * math.tau
        y = int(h * (0.45 + 0.5 * rng.random()))
        dist = 2.0 + rng.random() * (h * 0.42)
        ex = round(math.cos(ang) * dist)
        ez = round(math.sin(ang) * dist)
        ey = min(y + int(dist * 0.5), h + 1)
        t.line((0, y - int(dist * 0.4), 0), (ex, ey, ez), log_for)
        ends.append((ex, ey, ez))
    for ex, ey, ez in ends:
        for dy, r in ((-1, 3), (0, 4), (1, 3), (2, 2)):
            for dx in range(-r, r + 1):
                for dz in range(-r, r + 1):
                    if dx * dx + dz * dz <= r * r + 1 - (0.6 if rng.random() < 0.3 else 0):
                        t.leaf(ex + dx, ey + dy, ez + dz, leaf)
    return t


def spruce(reg, rng, log="spruce_log", leaves="spruce_leaves", hmin=7, hmax=12) -> Template:
    """The game's SpruceFoliagePlacer: disc radius grows downward, falling back to 1 each time it hits the limit."""
    t = Template()
    s_log = reg.id(log, axis="y")
    s_leaf = reg.id(leaves)
    h = int(rng.integers(hmin, hmax + 1))
    for y in range(h - int(rng.integers(0, 2))):
        t.put(0, y + 1, 0, s_log, 1)
    top = h + 1
    leaf_start = int(rng.integers(1, 3))
    r = int(rng.integers(0, 2))
    limit, max_r = 1, int(rng.integers(2, 4))
    y = top
    while y > leaf_start:
        _disc(t, 0, y, 0, r, s_leaf, rng, 0.0)
        if r >= limit:
            r = 1
            limit = min(limit + 1, max_r)
        else:
            r += 1
        y -= 1
    return t


def pine(reg, rng) -> Template:
    t = Template()
    s_log = reg.id("spruce_log", axis="y")
    s_leaf = reg.id("spruce_leaves")
    h = int(rng.integers(8, 14))
    for y in range(h):
        t.put(0, y + 1, 0, s_log, 1)
    top = h + 1
    n = int(rng.integers(3, 5))
    for i in range(n + 1):
        y = top - i
        r = 0 if i == 0 else (1 if i < n else 2 if i % 2 == 0 else 1)
        _disc(t, 0, y, 0, r, s_leaf, rng, 0.0)
    return t


def mega_spruce(reg, rng) -> Template:
    t = Template()
    s_log = reg.id("spruce_log", axis="y")
    s_leaf = reg.id("spruce_leaves")
    h = int(rng.integers(18, 30))
    for y in range(h):
        for dx in (0, 1):
            for dz in (0, 1):
                t.put(dx, y + 1, dz, s_log, 1)
    top = h + 2
    span = int(h * (0.6 + rng.random() * 0.2))
    rad = 0
    for i in range(span):
        y = top - i
        limit = min(i // 3 + 1, 5)
        rad = (rad + 1) if rad < limit else max(limit - 2, 1)
        if rad <= 0:
            rad = 1
        for dx in range(-rad, rad + 2):
            for dz in range(-rad, rad + 2):
                ax = dx - 0.5
                az = dz - 0.5
                if ax * ax + az * az <= (rad + 0.25) ** 2:
                    t.leaf(dx, y, dz, s_leaf)
    return t


def cherry(reg, rng) -> Template:
    """A cherry tree: forked trunk with wide, flat, drooping pink canopies."""
    t = Template()
    leaf = reg.id("cherry_leaves")
    log_for = lambda axis: reg.id("cherry_log", axis=axis)
    h = int(rng.integers(4, 8))
    t.line((0, 1, 0), (0, h, 0), log_for)
    n = int(rng.integers(2, 4))
    first = rng.random() * math.tau
    ends = []
    for i in range(n):
        ang = first + i * math.tau / n + rng.normal(0, 0.3)
        dist = int(rng.integers(3, 6))
        rise = int(rng.integers(3, 6))
        ex, ez = round(math.cos(ang) * dist), round(math.sin(ang) * dist)
        ey = h + rise
        mx, mz = round(ex * 0.6), round(ez * 0.6)
        t.line((0, h, 0), (mx, h + 1, mz), log_for)
        t.line((mx, h + 1, mz), (ex, ey, ez), log_for)
        ends.append((ex, ey, ez))
    if rng.random() < 0.5:
        ends.append((0, h + int(rng.integers(3, 6)), 0))
        t.line((0, h, 0), ends[-1], log_for)
    for ex, ey, ez in ends:
        for dy, r in ((-2, 3), (-1, 4), (0, 4), (1, 3), (2, 2)):
            rr = r + 0.3
            for dx in range(-r, r + 1):
                for dz in range(-r, r + 1):
                    d = dx * dx + dz * dz
                    if d <= rr * rr and not (d >= (r - 0.6) ** 2 and rng.random() < 0.35):
                        t.leaf(ex + dx, ey + dy, ez + dz, leaf)
        # Hanging leaves around the rim.
        for _ in range(int(rng.integers(10, 22))):
            ang = rng.random() * math.tau
            dist = 2.0 + rng.random() * 2.0
            dx, dz = round(math.cos(ang) * dist), round(math.sin(ang) * dist)
            for k in range(int(rng.integers(1, 4))):
                t.leaf(ex + dx, ey - 3 - k, ez + dz, leaf)
    return t


def huge_red_mushroom(reg, rng) -> Template:
    t = Template()
    stem = reg.id("mushroom_stem", down=False, east=True, north=True, south=True, up=False, west=True)
    cap = reg.id("red_mushroom_block", down=False, east=True, north=True, south=True, up=True, west=True)
    h = int(rng.integers(6, 11))
    for y in range(h):
        t.put(0, y + 1, 0, stem, 1)
    top = h + 1
    r = 2 if h < 8 else 3
    for dx in range(-(r - 1), r):
        for dz in range(-(r - 1), r):
            t.leaf(dx, top + 1, dz, cap)
    for y in range(top - r, top + 1):
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                edge = abs(dx) == r or abs(dz) == r
                corner = abs(dx) == r and abs(dz) == r
                if edge and not corner:
                    t.leaf(dx, y, dz, cap)
    return t


def huge_brown_mushroom(reg, rng) -> Template:
    t = Template()
    stem = reg.id("mushroom_stem", down=False, east=True, north=True, south=True, up=False, west=True)
    cap = reg.id("brown_mushroom_block", down=False, east=True, north=True, south=True, up=True, west=True)
    h = int(rng.integers(5, 10))
    for y in range(h):
        t.put(0, y + 1, 0, stem, 1)
    r = int(rng.integers(3, 5))
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            if not (abs(dx) == r and abs(dz) == r):
                t.leaf(dx, h + 1, dz, cap)
    return t


def cactus(reg, rng) -> Template:
    t = Template()
    s = reg.id("cactus", age=0)
    for y in range(int(rng.integers(1, 5))):
        t.put(0, y + 1, 0, s, 1)
    return t


def bush(reg, rng, leaves="oak_leaves", log="oak_log") -> Template:
    t = Template()
    leaf = reg.id(leaves)
    t.put(0, 1, 0, reg.id(log, axis="y"), 1)
    r = int(rng.integers(1, 3))
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            if dx * dx + dz * dz <= r * r + (rng.random() < 0.3):
                t.leaf(dx, 1, dz, leaf)
    t.leaf(0, 2, 0, leaf)
    if r > 1:
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if rng.random() < 0.7:
                t.leaf(dx, 2, dz, leaf)
    return t


def boulder(reg, rng, blocks=("cobblestone", "mossy_cobblestone", "stone", "andesite")) -> Template:
    t = Template()
    states = [reg.id(b) for b in blocks]
    r = 1.0 + rng.random() * 2.0
    n = int(r) + 1
    for dx in range(-n, n + 1):
        for dy in range(-n, n + 1):
            for dz in range(-n, n + 1):
                if dx * dx + (dy * 1.3) ** 2 + dz * dz <= r * r + rng.random() * 0.8:
                    t.put(dx, dy + 1, dz, states[int(rng.integers(0, len(states)))], 1)
    return t


def nether_fungus(reg, rng, kind="crimson") -> Template:
    t = Template()
    stem = reg.id(f"{kind}_stem", axis="y")
    wart = reg.id("nether_wart_block" if kind == "crimson" else "warped_wart_block")
    glow = reg.id("shroomlight")
    h = int(rng.integers(5, 17))
    for y in range(h):
        t.put(0, y + 1, 0, stem, 1)
    r = 2 + h // 5
    for dy in range(0, r + 2):
        rr = r - dy * 0.6
        ir = int(math.ceil(rr))
        for dx in range(-ir, ir + 1):
            for dz in range(-ir, ir + 1):
                if dx * dx + dz * dz <= rr * rr + 0.5:
                    state = glow if rng.random() < 0.07 else wart
                    t.leaf(dx, h + dy, dz, state)
    # Vines hanging from the crimson cap's rim.
    if kind == "crimson":
        vine = reg.id("weeping_vines_plant")
        for _ in range(int(rng.integers(3, 9))):
            ang = rng.random() * math.tau
            dx, dz = round(math.cos(ang) * r), round(math.sin(ang) * r)
            for k in range(int(rng.integers(1, 5))):
                t.leaf(dx, h - 1 - k, dz, vine)
    return t


def chorus(reg, rng) -> Template:
    t = Template()
    cells: dict[tuple[int, int, int], bool] = {}
    flowers = []

    def grow(p, depth):
        h = int(rng.integers(2, 5))
        for i in range(h):
            q = (p[0], p[1] + i, p[2])
            cells[q] = True
        top = (p[0], p[1] + h - 1, p[2])
        if depth >= 3:
            flowers.append((top[0], top[1] + 1, top[2]))
            return
        branched = False
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if rng.random() < 0.55:
                side = (top[0] + dx, top[1], top[2] + dz)
                cells[side] = True
                grow((side[0], side[1] + 1, side[2]), depth + 1)
                branched = True
        if not branched:
            flowers.append((top[0], top[1] + 1, top[2]))

    grow((0, 1, 0), 0)
    for (x, y, z) in cells:
        props = {}
        for name, (dx, dy, dz) in dict(north=(0, 0, -1), south=(0, 0, 1), east=(1, 0, 0), west=(-1, 0, 0),
                                       up=(0, 1, 0), down=(0, -1, 0)).items():
            q = (x + dx, y + dy, z + dz)
            props[name] = q in cells or q in flowers or (name == "down" and y == 1)
        t.put(x, y, z, reg.id("chorus_plant", **props), 1)
    for f in flowers:
        t.put(*f, reg.id("chorus_flower", age=5), 1)
    return t


class TemplateSet:
    """A pool of template variants flattened into arrays for numba."""

    def __init__(self, templates: list[Template]):
        offs, cnts = [], []
        dx, dy, dz, st, fo = [], [], [], [], []
        for t in templates:
            offs.append(len(dx))
            cnts.append(len(t.vox))
            for (x, y, z), (state, force) in t.vox.items():
                dx.append(x)
                dy.append(y)
                dz.append(z)
                st.append(state)
                fo.append(force)
        self.count = len(templates)
        self.offs = np.asarray(offs, dtype=np.int32)
        self.cnts = np.asarray(cnts, dtype=np.int32)
        self.dx = np.asarray(dx, dtype=np.int32)
        self.dy = np.asarray(dy, dtype=np.int32)
        self.dz = np.asarray(dz, dtype=np.int32)
        self.st = np.asarray(st, dtype=np.uint16)
        self.fo = np.asarray(fo, dtype=np.uint8)


@njit
def _stamp(blocks, xs, ys, zs, which, offs, cnts, dx, dy, dz, st, fo):
    nx, ny, nz = blocks.shape
    for i in range(xs.shape[0]):
        k = which[i]
        o = offs[k]
        for j in range(o, o + cnts[k]):
            x = xs[i] + dx[j]
            y = ys[i] + dy[j]
            z = zs[i] + dz[j]
            if x < 0 or x >= nx or y < 0 or y >= ny or z < 0 or z >= nz:
                continue
            if fo[j] > 0 or blocks[x, y, z] == 0:
                blocks[x, y, z] = st[j]


def stamp(blocks: np.ndarray, tset: TemplateSet, xs, ys, zs, rng: np.random.Generator) -> None:
    xs = np.asarray(xs, dtype=np.int32)
    if xs.size == 0:
        return
    which = rng.integers(0, tset.count, size=xs.size).astype(np.int32)
    _stamp(blocks, xs, np.asarray(ys, dtype=np.int32), np.asarray(zs, dtype=np.int32), which, tset.offs, tset.cnts,
           tset.dx, tset.dy, tset.dz, tset.st, tset.fo)
