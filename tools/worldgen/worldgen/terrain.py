"""Procedural terrain. A Canvas works in view-relative coordinates so every seed composes for the desktop.

The camera sits at (cx, cz) looking north. ``s`` is the lateral offset (right is positive), ``f`` the distance
ahead and ``sx`` the approximate screen x in 0..1, so a scene can say "keep the left 40 % low and open" directly.
"""
from __future__ import annotations

import numpy as np
from numba import njit, prange

from . import features as F
from . import noise as N
from .blocks import Registry
from .structures import Builder
from .world import World, blur_tint, climate_tint


def smooth(a, b, x):
    """Smoothstep from a to b. a > b gives the falling edge."""
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


# Biome climate: (temperature, downfall), from minecraft.wiki/w/Biome.
CLIMATE = {
    "plains": (0.8, 0.4), "meadow": (0.5, 0.8), "forest": (0.7, 0.8), "flower_forest": (0.7, 0.8),
    "birch_forest": (0.6, 0.6), "taiga": (0.25, 0.8), "snowy_taiga": (0.0, 0.4), "snowy": (0.0, 0.5),
    "desert": (2.0, 0.0), "savanna": (2.0, 0.0), "cherry_grove": (0.5, 0.8), "ocean": (0.5, 0.5),
    "beach": (0.8, 0.4), "peaks": (0.0, 0.9), "stony": (1.0, 0.3), "mushroom": (0.9, 1.0),
    "swamp": (0.8, 0.9), "windswept": (0.2, 0.3),
}
WATER_COLORS = {
    "default": (0x3F, 0x76, 0xE4), "cold": (0x3D, 0x57, 0xD6), "frozen": (0x39, 0x38, 0xC9),
    "warm": (0x43, 0xD5, 0xEE), "lukewarm": (0x45, 0xAD, 0xF2), "cherry": (0x5D, 0xB7, 0xEF), "meadow": (0x0E, 0x4E, 0xCF),
}


@njit(parallel=True)
def _fill(blocks, h, top, fill, depth, rock):
    nx, nz = h.shape
    for x in prange(nx):
        for z in range(nz):
            H = h[x, z]
            d = depth[x, z]
            for y in range(H + 1):
                if y == H:
                    blocks[x, y, z] = top[x, z]
                elif y > H - d:
                    blocks[x, y, z] = fill[x, z]
                else:
                    blocks[x, y, z] = rock[x, z]


@njit(parallel=True)
def _overhang(blocks, h, cols_x, cols_z, n3, y0, ny, amp, carve, top, fill, depth, rock):
    """3D density for selected columns: lets cliffs lean out and hollows cut in, then re-applies the surface."""
    for c in prange(cols_x.shape[0]):
        x = cols_x[c]
        z = cols_z[c]
        H = h[x, z]
        a = amp[x, z]
        depth_seen = -1
        for k in range(ny - 1, -1, -1):
            y = y0 + k
            if y < 1 or y >= blocks.shape[1]:
                continue
            solid = y + n3[c, k] * a < H
            if solid and carve[c, k] > 0.0 and y < H - 2:
                solid = False
            if not solid:
                blocks[x, y, z] = 0
                depth_seen = -1
            else:
                depth_seen += 1
                if depth_seen == 0:
                    blocks[x, y, z] = top[x, z]
                elif depth_seen < depth[x, z]:
                    blocks[x, y, z] = fill[x, z]
                else:
                    blocks[x, y, z] = rock[x, z]


@njit(parallel=True)
def _strata(blocks, h, stone, granite, diorite, andesite, tuff, coal, iron, copper, gravel_like, perm, grad):
    """Rock variety and ores, only where a surface can be seen (a thin shell below the lowest neighbour)."""
    nx, nz = h.shape
    for x in prange(1, nx - 1):
        for z in range(1, nz - 1):
            H = h[x, z]
            lo = min(min(h[x - 1, z], h[x + 1, z]), min(h[x, z - 1], h[x, z + 1]))
            for y in range(max(lo - 6, 0), min(H + 24, blocks.shape[1])):
                if blocks[x, y, z] != stone:
                    continue
                n = N.perlin3(x / 18.0, y / 9.0, z / 18.0, perm, grad)
                m = N.perlin3(x / 9.0 + 40.0, y / 9.0, z / 9.0, perm, grad)
                if n > 0.34:
                    blocks[x, y, z] = andesite
                elif n < -0.42:
                    blocks[x, y, z] = granite if m > 0.1 else diorite
                elif m > 0.46:
                    blocks[x, y, z] = tuff
                else:
                    hh = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
                    hh = (hh ^ (hh >> 11)) & 1023
                    if hh < 8:
                        blocks[x, y, z] = coal
                    elif hh < 12:
                        blocks[x, y, z] = iron
                    elif hh < 15:
                        blocks[x, y, z] = copper
                    elif hh < 18:
                        blocks[x, y, z] = gravel_like


@njit(parallel=True)
def _water(blocks, h, level_map, water, ice, ice_mask):
    nx, nz = h.shape
    for x in prange(nx):
        for z in range(nz):
            lv = level_map[x, z]
            if lv < 0:
                continue
            for y in range(lv, 0, -1):
                if blocks[x, y, z] != 0:
                    break
                blocks[x, y, z] = water
            if ice_mask[x, z] and blocks[x, lv, z] == water:
                blocks[x, lv, z] = ice


@njit
def _surface_heights(blocks, kind, flags, opaque_bit):
    """Highest solid (non-plant, non-leaf) surface per column, ignoring water."""
    nx, ny, nz = blocks.shape
    out = np.zeros((nx, nz), dtype=np.int32)
    for x in range(nx):
        for z in range(nz):
            for y in range(ny - 1, -1, -1):
                s = blocks[x, y, z]
                if s != 0 and (flags[s] & opaque_bit) != 0:
                    out[x, z] = y
                    break
    return out


@njit(parallel=True)
def _snow_cover(blocks, mask, snow, snow_grass, grass, kinds, flags):
    """A snow layer on whatever is highest in the column (leaves included), as the game's freeze feature does."""
    nx, ny, nz = blocks.shape
    for x in prange(nx):
        for z in range(nz):
            if not mask[x, z]:
                continue
            for y in range(ny - 2, 0, -1):
                s = blocks[x, y, z]
                if s == 0:
                    continue
                k = kinds[s]
                if k == 1 and blocks[x, y + 1, z] == 0:
                    blocks[x, y + 1, z] = snow
                    if s == grass:
                        blocks[x, y, z] = snow_grass
                break


class Canvas:
    def __init__(self, seed: int, nx=960, ny=256, nz=640, cam_back=60, tanh=0.95, reg: Registry | None = None):
        self.seed = int(seed) & 0x7FFFFFFF
        self.rng = np.random.default_rng(self.seed)
        self.reg = reg or Registry()
        self.nx, self.ny, self.nz = nx, ny, nz
        self.blocks = np.zeros((nx, ny, nz), dtype=np.uint16)
        self.cx, self.cz = nx // 2, nz - cam_back
        xi = np.arange(nx, dtype=np.float32)[:, None]
        zi = np.arange(nz, dtype=np.float32)[None, :]
        self.x = np.broadcast_to(xi, (nx, nz))
        self.z = np.broadcast_to(zi, (nx, nz))
        self.s = self.x - self.cx
        self.f = self.cz - self.z
        self.tanh = tanh
        self.sx = 0.5 + 0.5 * self.s / (np.maximum(self.f, 12.0) * tanh)
        self._nk = 0
        self.temp = np.full((nx, nz), 0.8, dtype=np.float32)
        self.down = np.full((nx, nz), 0.4, dtype=np.float32)
        self.water_color = np.zeros((nx, nz, 3), dtype=np.uint8)
        self.water_color[...] = WATER_COLORS["default"]
        self.surf = None
        self.bd = Builder(self.blocks, self.reg)

    # -- noise + shape helpers -----------------------------------------------------------------------------------
    def n(self, scale, octaves=4, gain=0.5) -> np.ndarray:
        self._nk += 1
        off = (self.seed * 31 + self._nk * 977) & 0xFFFFF
        return N.fbm2(self.nx, self.nz, scale, self.seed + self._nk * 7919, octaves=octaves, gain=gain,
                      ox=float(off % 4096), oz=float((off * 7) % 4096))

    def blob(self, s0, f0, rs, rf, wobble=None, wobble_amp=0.0):
        """1 at the centre, 0 at the rim of an ellipse in view coordinates; wobble breaks up the outline."""
        d = ((self.s - s0) / rs) ** 2 + ((self.f - f0) / rf) ** 2
        v = 1.0 - d
        if wobble is not None:
            v = v + wobble * wobble_amp
        return np.clip(v, 0.0, 1.0)

    def climate(self, mask, name):
        t, d = CLIMATE[name]
        self.temp = lerp(self.temp, t, mask)
        self.down = lerp(self.down, d, mask)

    def set_water_color(self, name, mask=None):
        c = np.asarray(WATER_COLORS[name], dtype=np.uint8)
        if mask is None:
            self.water_color[...] = c
        else:
            self.water_color[mask] = c

    # -- terrain assembly ---------------------------------------------------------------------------------------
    def layers(self, default_top="grass_block", default_fill="dirt", default_rock="stone", depth=4):
        id_ = self.reg.id
        self.top = np.full((self.nx, self.nz), self._top_id(default_top), dtype=np.uint16)
        self.fill = np.full((self.nx, self.nz), id_(default_fill), dtype=np.uint16)
        self.rock = np.full((self.nx, self.nz), id_(default_rock), dtype=np.uint16)
        self.depth = np.full((self.nx, self.nz), depth, dtype=np.int32)

    def _top_id(self, name):
        return self.reg.id(name, **(dict(snowy="false") if name in ("grass_block", "mycelium", "podzol") else {}))

    def paint(self, mask, top=None, fill=None, rock=None, depth=None):
        id_ = self.reg.id
        if top is not None:
            self.top[mask] = self._top_id(top)
        if fill is not None:
            self.fill[mask] = id_(fill)
        if rock is not None:
            self.rock[mask] = id_(rock)
        if depth is not None:
            self.depth[mask] = depth

    def build_terrain(self, h, *, sea=62, sea_mask=None, ice_mask=None, overhang=None, overhang_scale=(26, 18, 26),
                      carve=None, strata=True):
        """Lay down the columns. ``overhang`` is a per-column amplitude; ``carve`` adds tunnels where that is high."""
        H = np.clip(h, 2, self.ny - 8).astype(np.int32)
        self.h = H
        _fill(self.blocks, H, self.top, self.fill, self.depth, self.rock)
        if overhang is not None and (overhang > 0.5).any():
            xs, zs = np.nonzero(overhang > 0.5)
            amp = np.maximum(overhang, 0).astype(np.float32)
            ymin = max(int(H[xs, zs].min()) - 32, 1)
            ymax = min(int(H[xs, zs].max()) + 30, self.ny - 2)
            sx, sy, sz = overhang_scale
            n3 = N.noise3_columns(xs, zs, ymin, ymax - ymin + 1, sx, sy, sz, self.seed + 101, octaves=2)
            if carve is not None:
                c3 = N.noise3_columns(xs, zs, ymin, ymax - ymin + 1, 34, 16, 34, self.seed + 103, octaves=2)
                c3 = c3 - (0.42 + (1.0 - carve[xs, zs][:, None]) * 2.0)
            else:
                c3 = np.zeros_like(n3)
            _overhang(self.blocks, H, xs.astype(np.int32), zs.astype(np.int32), n3, ymin, ymax - ymin + 1, amp, c3,
                      self.top, self.fill, self.depth, self.rock)
        if strata:
            id_ = self.reg.id
            _strata(self.blocks, H, id_("stone"), id_("granite"), id_("diorite"), id_("andesite"), id_("tuff"),
                    id_("coal_ore"), id_("iron_ore"), id_("copper_ore"), id_("gravel"),
                    N.perm_table(self.seed + 7), N._GRAD3)
        level = np.full((self.nx, self.nz), sea, dtype=np.int32)
        if sea_mask is not None:
            level[~sea_mask] = -1
        if ice_mask is None:
            ice_mask = np.zeros((self.nx, self.nz), dtype=bool)
        _water(self.blocks, H, level, self.reg.id("water"), self.reg.id("ice"), ice_mask)
        self.refresh_surface()
        self.sea = sea

    def refresh_surface(self):
        t = self.reg.tables()
        self.surf = _surface_heights(self.blocks, t["kind"], t["flags"], 1)

    def land_mask(self):
        """Columns whose highest non-air voxel is a full land block (no water above it)."""
        cols = np.arange(self.nx)[:, None]
        rows = np.arange(self.nz)[None, :]
        above = self.blocks[cols, np.minimum(self.surf + 1, self.ny - 1), rows]
        return above == 0

    # -- scatter -------------------------------------------------------------------------------------------------
    def scatter(self, cell: int, prob) -> tuple[np.ndarray, np.ndarray]:
        """Jittered grid sampling. ``prob`` (array or scalar) is the chance a cell keeps its point."""
        gx = np.arange(0, self.nx, cell)
        gz = np.arange(0, self.nz, cell)
        xs, zs = np.meshgrid(gx, gz, indexing="ij")
        xs = xs.ravel() + self.rng.integers(0, cell, xs.size)
        zs = zs.ravel() + self.rng.integers(0, cell, zs.size)
        ok = (xs < self.nx) & (zs < self.nz)
        xs, zs = xs[ok], zs[ok]
        p = prob[xs, zs] if isinstance(prob, np.ndarray) else prob
        keep = self.rng.random(xs.size) < p
        return xs[keep], zs[keep]

    def plant_trees(self, makers, cell, prob, need=None, y_offset=0, variants=10):
        """Stamp random variants of template makers. ``need``: state ids the tree may grow on (default grass/dirt)."""
        tset = F.TemplateSet([makers[i % len(makers)](self.reg, self.rng) for i in range(variants)])
        xs, zs = self.scatter(cell, prob)
        if xs.size == 0:
            return
        if need is None:
            need = [self.reg.id("grass_block", snowy="false"), self.reg.id("dirt"), self.reg.id("podzol", snowy="false"),
                    self.reg.id("grass_block", snowy="true"), self.reg.id("coarse_dirt"), self.reg.id("mycelium", snowy="false")]
        ys = self.surf[xs, zs]
        ground = self.blocks[xs, ys, zs]
        air = self.blocks[xs, np.minimum(ys + 1, self.ny - 1), zs] == 0
        ok = np.isin(ground, need) & air
        F.stamp(self.blocks, tset, xs[ok], ys[ok] + y_offset, zs[ok], self.rng)

    def plants(self, state, density, *, need=None, upper=None):
        """Single-voxel plants (or a double plant with ``upper``). ``density`` is the chance per column."""
        d = density if isinstance(density, np.ndarray) else np.full((self.nx, self.nz), density, dtype=np.float32)
        hit = self.rng.random((self.nx, self.nz), dtype=np.float32) < d
        xs, zs = np.nonzero(hit)
        if xs.size == 0:
            return
        ys = self.surf[xs, zs]
        cur = self.blocks[xs, ys, zs]
        if need is None:
            need = [self.reg.id("grass_block", snowy="false")]
        above_ok = self.blocks[xs, np.minimum(ys + 1, self.ny - 1), zs] == 0
        above2 = self.blocks[xs, np.minimum(ys + 2, self.ny - 1), zs] == 0
        ok = np.isin(cur, need) & above_ok & (above2 if upper is not None else True)
        xs, ys, zs = xs[ok], ys[ok], zs[ok]
        self.blocks[xs, ys + 1, zs] = self.reg.state(state) if isinstance(state, str) else state
        if upper is not None:
            self.blocks[xs, ys + 2, zs] = self.reg.state(upper)

    def flowers(self, density, species, patch=26):
        """Flower patches: each patch favours a couple of species, like the game's flower features."""
        noise_field = self.n(patch, 2)
        n_sp = len(species)
        idx = (np.floor((noise_field + 1.0) * 0.5 * n_sp * 1.6).astype(np.int32)) % n_sp
        d = density if isinstance(density, np.ndarray) else np.full((self.nx, self.nz), density, dtype=np.float32)
        for i, sp in enumerate(species):
            self.plants(sp, np.where(idx == i, d, 0.0).astype(np.float32))

    def snow_cover(self, mask):
        snow = self.reg.id("snow", layers=1)
        t = self.reg.tables()
        _snow_cover(self.blocks, mask.astype(np.bool_), snow, self.reg.id("grass_block", snowy="true"),
                    self.reg.id("grass_block", snowy="false"), t["kind"], t["flags"])

    def flatten_pad(self, h, s0, f0, rs, rf, y=None, feather=14.0):
        """Level a building site; returns the new heights and the pad's Y."""
        d = np.maximum(np.abs(self.s - s0) - rs, 0) ** 2 + np.maximum(np.abs(self.f - f0) - rf, 0) ** 2
        m = smooth(feather, 0.0, np.sqrt(d))
        ix = int(np.clip(self.cx + s0, 0, self.nx - 1))
        iz = int(np.clip(self.cz - f0, 0, self.nz - 1))
        Y = float(h[ix, iz]) if y is None else float(y)
        return lerp(h, Y, m), int(round(Y)), ix, iz

    def view_to_world(self, s, f):
        return int(self.cx + s), int(self.cz - f)

    def s_at(self, sx: float, f: float) -> float:
        """Lateral offset that lands at screen x ``sx`` (0..1) at distance f."""
        return (sx - 0.5) * 2.0 * f * self.tanh

    def finish(self, mode=0, tint_override: dict | None = None, meta=None) -> World:
        g = climate_tint(self.temp, self.down, "grass")
        fol = climate_tint(self.temp, self.down, "foliage")
        if tint_override:
            if "grass" in tint_override:
                g[...] = tint_override["grass"]
            if "foliage" in tint_override:
                fol[...] = tint_override["foliage"]
        g = blur_tint(g, 4)
        fol = blur_tint(fol, 4)
        w = blur_tint(self.water_color, 4)
        world = World(self.blocks, self.reg, g, fol, w, mode=mode, meta=meta or {})
        return world.finish()
