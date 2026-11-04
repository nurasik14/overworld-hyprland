"""Art-directed scene recipes. Each builds a world for a seed and returns it with the camera that frames it.

Layout rule shared by every recipe: the camera looks north from near the south edge. Tall things go right of the
view axis (the left 40 % of the desktop holds widget cards), and nothing busy stands in the first ~45 blocks
(those fill the bottom ~90 px where the hotbar HUD sits).
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from . import features as F
from . import render as R
from . import structures as S
from .terrain import Canvas, lerp, smooth
from .world import Camera, World

FOV = 58.0
TANH = 0.985


@dataclass
class Shot:
    """Everything about how a scene is framed and lit, except the time-of-day presets themselves."""

    pos: tuple[float, float, float]
    yaw: float = 0.0
    pitch: float = 1.0
    fov: float = FOV
    fog: dict = field(default_factory=lambda: dict(day=300.0, dawn=250.0, dusk=250.0, night=210.0))
    sun_az: dict = field(default_factory=lambda: dict(day=27.0, dawn=24.0, dusk=26.0, night=31.0))
    sun_el: dict = field(default_factory=lambda: dict(day=18.0, dawn=8.0, dusk=5.0, night=18.0))
    key_az: dict = field(default_factory=lambda: dict(day=128.0, night=140.0))
    key_el: dict = field(default_factory=lambda: dict(day=52.0, night=46.0))
    cloud_offset: tuple[float, float] = (0.0, 0.0)
    times: tuple[str, ...] = ("day", "dawn", "dusk", "night")
    overrides: dict = field(default_factory=dict)  # time -> sky.TIMES overrides

    def camera(self, projection=0) -> Camera:
        return Camera(self.pos, self.yaw, self.pitch, self.fov, projection)


def _cam_at(c: Canvas, height: float, s=0.0, f=0.0) -> tuple[float, float, float]:
    x, z = c.view_to_world(s, f)
    ground = max(int(c.surf[x, z]), getattr(c, "sea", 0))
    return (x + 0.5, ground + height, z + 0.5)


FLOWERS_COMMON = [
    "minecraft:dandelion", "minecraft:poppy", "minecraft:oxeye_daisy", "minecraft:azure_bluet", "minecraft:cornflower",
]
TULIPS = ["minecraft:red_tulip", "minecraft:orange_tulip", "minecraft:white_tulip", "minecraft:pink_tulip"]


def _beach(c: Canvas, h, sea=62, sand="sand", band=1.5, noise_amp=1.5):
    wob = c.n(30, 2) * noise_amp
    mask = h + wob < sea + band
    c.paint(mask, top=sand, fill=sand, depth=4)
    return mask


def _lake_floor(c: Canvas, h, sea=62):
    under = h < sea
    m = c.n(20, 2)
    c.paint(under & (m > 0.15), top="gravel", fill="gravel")
    c.paint(under & (m < -0.2), top="clay", fill="clay")
    c.paint(under & (m >= -0.2) & (m <= 0.15), top="sand", fill="sand")


def _under_plants(c: Canvas, density, sea=62):
    """Seagrass and kelp on the bed of the water."""
    d = density if isinstance(density, np.ndarray) else np.full((c.nx, c.nz), density, dtype=np.float32)
    water = c.reg.id("water")
    hit = c.rng.random((c.nx, c.nz), dtype=np.float32) < d
    xs, zs = np.nonzero(hit)
    if xs.size == 0:
        return
    ys = c.surf[xs, zs]
    ok = c.blocks[xs, np.minimum(ys + 1, c.ny - 1), zs] == water
    xs, ys, zs = xs[ok], ys[ok], zs[ok]
    c.blocks[xs, ys + 1, zs] = c.reg.id("seagrass")
    for i in c.rng.choice(xs.size, size=min(xs.size // 5, 4000), replace=False) if xs.size else []:
        top = int(ys[i]) + 1 + int(c.rng.integers(2, 11))
        for y in range(int(ys[i]) + 1, min(top, c.sea)):
            if c.blocks[xs[i], y, zs[i]] in (water, c.reg.id("seagrass")):
                c.blocks[xs[i], y, zs[i]] = c.reg.id("kelp_plant")


def _lily_pads(c: Canvas, density, sea=62):
    water = c.reg.id("water")
    hit = c.rng.random((c.nx, c.nz), dtype=np.float32) < density
    xs, zs = np.nonzero(hit)
    if xs.size == 0:
        return
    ok = (c.blocks[xs, sea, zs] == water) & (c.blocks[xs, sea + 1, zs] == 0) & (c.surf[xs, zs] >= sea - 3)
    c.blocks[xs[ok], sea + 1, zs[ok]] = c.reg.id("lily_pad")


def _rough_rise(c: Canvas, rise: float, rough: float = 1.0) -> np.ndarray:
    """Ground that falls away from the camera, broken up enough that its steps never line up into rings."""
    near = smooth(190, 20, c.f) * smooth(420, 200, np.abs(c.s))
    bumps = 5.5 * c.n(62, 3) + 3.0 * c.n(26, 2) + 1.2 * c.n(11, 2)
    return rise * smooth(125, 22, c.f) * smooth(330, 170, np.abs(c.s)) + rough * bumps * near


def _near_trees(c: Canvas, far_from: float = 62.0, near_from: float = 30.0) -> np.ndarray:
    """Trees may come close on the right where they frame the view, but stay back on the widget side."""
    right = smooth(0.58, 0.72, c.sx)
    start = lerp(far_from, near_from, right)
    return smooth(start - 12, start + 10, c.f)


def plains(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers()
    base = 67 + 2.6 * c.n(190, 4) + 1.1 * c.n(58, 3)
    far = smooth(150, 430, c.f)
    hills = 30 * far * (0.45 + 0.9 * c.n(170, 4))
    right = 20 * c.blob(240, 170, 210, 150, c.n(70, 3), 0.45)
    h = base + np.maximum(hills, -2) + right
    lake = c.blob(-140, 240, 230, 100, c.n(54, 3), 0.4)
    h = lerp(h, 54 + 3 * c.n(30, 2), smooth(0.02, 0.4, lake))
    h += _rough_rise(c, 11.0)
    hs = c.s_at(0.74, 142)
    h, Y, ix, iz = c.flatten_pad(h, hs, 142, 13, 11, feather=20)
    h, Y2, ix2, iz2 = c.flatten_pad(h, hs + 34, 162, 9, 9, y=Y, feather=18)
    c.climate(far, "forest")
    _beach(c, h)
    _lake_floor(c, h)
    c.build_terrain(h, ice_mask=None)
    # Vegetation.
    cluster = smooth(0.02, 0.28, c.n(95, 3))
    left = smooth(0.43, 0.2, c.sx)
    keep = _near_trees(c, 70.0, 34.0) * (1 - 0.82 * left)
    pad = smooth(46, 26, np.hypot(c.s - (hs + 14), c.f - 150))
    # Leave a sight line to the homestead so its lights read at night.
    sight = smooth(0.12, 0.06, np.abs(c.sx - 0.77)) * smooth(175, 140, c.f)
    dens = (0.10 + 0.72 * cluster * (0.35 + 0.65 * far)) * keep * (1 - pad) * (1 - 0.95 * sight)
    c.plant_trees([F.oak, F.oak, F.oak, F.fancy_oak], 8, dens.astype(np.float32))
    bushes = 0.05 * keep * (1 - pad)
    c.plant_trees([F.bush], 9, bushes.astype(np.float32))
    c.refresh_surface()
    calm = smooth(22, 38, c.f)
    tuft = 0.05 + 0.34 * smooth(-0.1, 0.3, c.n(30, 3))
    c.plants("minecraft:short_grass", (tuft * calm).astype(np.float32))
    c.plants("minecraft:tall_grass[half=lower]", (0.012 * calm).astype(np.float32), upper="minecraft:tall_grass[half=upper]")
    flowery = smooth(0.0, 0.26, c.n(34, 3)) * smooth(24, 40, c.f)
    c.flowers((0.11 * flowery).astype(np.float32), FLOWERS_COMMON + TULIPS)
    c.plants("minecraft:rose_bush[half=lower]", (0.004 * flowery).astype(np.float32), upper="minecraft:rose_bush[half=upper]")
    c.plants("minecraft:peony[half=lower]", (0.004 * flowery).astype(np.float32), upper="minecraft:peony[half=upper]")
    _lily_pads(c, 0.006)
    _under_plants(c, 0.04)
    # A little homestead on the right.
    S.house(c.bd, ix - 3, Y + 1, iz - 4)
    S.house(c.bd, ix2 - 3, Y2 + 1, iz2 - 3, w=7, d=7, log="spruce_log", plank="spruce_planks", stair="spruce_stairs", slab="spruce_slab", door="spruce_door")
    S.lamp_post(c.bd, ix + 8, Y + 1, iz + 6)
    S.lamp_post(c.bd, ix - 6, Y + 1, iz + 6)
    S.farm(c.bd, ix - 16, Y + 1, iz - 1)
    c.refresh_surface()
    shot = Shot(_cam_at(c, 11), pitch=-2.0, cloud_offset=(float(seed % 3000), 410.0))
    return c.finish(), shot


def birch_forest(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers()
    h = 70 + 7 * c.n(160, 4) + 2.5 * c.n(46, 3)
    far = smooth(200, 480, c.f)
    h += 30 * far * (0.5 + 0.8 * c.n(150, 4))
    # Clearing and pond on the left.
    clearing = c.blob(c.s_at(0.17, 190), 190, 210, 135, c.n(60, 3), 0.35)
    h = lerp(h, 65 + 1.2 * c.n(40, 2), smooth(0.0, 0.5, clearing))
    pond = c.blob(c.s_at(0.2, 215), 215, 105, 45, c.n(30, 3), 0.45)
    h = lerp(h, 57, smooth(0.05, 0.4, pond))
    # Rising ground on the right, so the forest wall climbs up the frame.
    h += 20 * c.blob(240, 230, 220, 190, c.n(60, 3), 0.3)
    # The camera stands on a rise above the clearing.
    h += _rough_rise(c, 13.0)
    c.climate(np.ones((c.nx, c.nz), dtype=np.float32), "birch_forest")
    _lake_floor(c, h)
    _beach(c, h, band=0.5, noise_amp=0.8)
    c.build_terrain(h)
    keep = _near_trees(c, 84.0, 34.0) * (1 - 0.94 * smooth(0.3, 0.75, clearing))
    dens = 0.86 * np.clip(keep, 0, 1)
    tall_birch = lambda r, g: F.oak(r, g, log="birch_log", leaves="birch_leaves", hmin=8, hmax=13)
    birch = lambda r, g: F.oak(r, g, log="birch_log", leaves="birch_leaves", hmin=5, hmax=8)
    c.plant_trees([birch, birch, tall_birch, tall_birch, F.oak], 6, dens.astype(np.float32), variants=18)
    c.refresh_surface()
    calm = smooth(22, 38, c.f)
    c.plants("minecraft:short_grass", ((0.08 + 0.34 * smooth(-0.1, 0.3, c.n(30, 3))) * calm).astype(np.float32))
    c.plants("minecraft:fern", (0.03 * calm).astype(np.float32))
    bloom = (0.4 + 0.6 * smooth(0.1, 0.65, clearing)) * smooth(0.0, 0.25, c.n(34, 3)) * smooth(24, 40, c.f)
    c.flowers((0.22 * bloom + 0.012 * calm).astype(np.float32),
              ["minecraft:allium", "minecraft:azure_bluet", "minecraft:oxeye_daisy", "minecraft:cornflower",
               "minecraft:lily_of_the_valley", "minecraft:pink_tulip"], patch=22)
    c.plants("minecraft:lilac[half=lower]", (0.008 * bloom).astype(np.float32), upper="minecraft:lilac[half=upper]")
    c.plants("minecraft:rose_bush[half=lower]", (0.006 * bloom).astype(np.float32), upper="minecraft:rose_bush[half=upper]")
    _lily_pads(c, 0.012)
    _under_plants(c, 0.05)
    c.refresh_surface()
    shot = Shot(_cam_at(c, 12), pitch=-2.5, cloud_offset=(1200.0 + seed % 2000, 900.0))
    return c.finish(), shot


def snowy_taiga(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers()
    h = 72 + 7 * c.n(170, 4) + 2.2 * c.n(50, 3)
    ridge = 1 - np.abs(c.n(240, 5, gain=0.55)) * 2.2
    mts = 132 * smooth(250, 500, c.f) * np.clip(ridge, 0, 1) ** 1.3 * (0.65 + 0.5 * c.n(320, 2))
    h += mts
    lake = c.blob(c.s_at(0.2, 200), 200, 200, 80, c.n(50, 3), 0.4)
    h = lerp(h, 56, smooth(0.02, 0.4, lake))
    h += 12 * c.blob(230, 210, 190, 140, c.n(60, 3), 0.3)
    h += _rough_rise(c, 8.0)
    hs = c.s_at(0.73, 118)
    h, Y, ix, iz = c.flatten_pad(h, hs, 118, 11, 10, feather=18)
    c.climate(np.ones((c.nx, c.nz), dtype=np.float32), "snowy_taiga")
    c.set_water_color("frozen")
    high = h > 118
    c.paint(high, top="snow_block", fill="snow_block", depth=3)
    pod = c.n(26, 2) > 0.28
    c.paint(pod & ~high, top="podzol")
    _lake_floor(c, h)
    # Steep faces show stone.
    gx, gz = np.gradient(h.astype(np.float32))
    steep = np.hypot(gx, gz) > 1.6
    c.paint(steep & (h > 100), top="stone", fill="stone", depth=2)
    c.build_terrain(h, ice_mask=(c.n(36, 3) > -0.3), overhang=6.0 * smooth(120, 170, h))
    keep = _near_trees(c, 66.0, 32.0) * (1 - 0.94 * smooth(0.52, 0.32, c.sx)) * smooth(136, 110, h)
    site = smooth(40, 20, np.hypot(c.s - hs, c.f - 118))
    sight = smooth(0.11, 0.05, np.abs(c.sx - 0.74)) * smooth(150, 118, c.f)
    dens = (0.28 + 0.34 * smooth(0, 0.3, c.n(80, 3))) * keep * (1 - site) * (1 - 0.95 * sight)
    pod_id = c.reg.id("podzol", snowy="false")
    need = [c.reg.id("grass_block", snowy="false"), c.reg.id("dirt"), pod_id, c.reg.id("snow_block")]
    c.plant_trees([F.spruce, F.spruce, F.spruce, F.pine, F.pine, F.mega_spruce], 7, dens.astype(np.float32), need=need, variants=18)
    c.refresh_surface()
    c.plants("minecraft:fern", (0.04 * smooth(24, 40, c.f)).astype(np.float32), need=need)
    c.plants("minecraft:sweet_berry_bush[age=3]", (0.012 * smooth(24, 40, c.f)).astype(np.float32), need=need)
    c.plant_trees([lambda r, g: F.bush(r, g, leaves="spruce_leaves", log="spruce_log")], 13, (0.5 * smooth(24, 40, c.f) * (1 - smooth(0.42, 0.25, c.sx))).astype(np.float32), need=need)
    S.house(c.bd, ix - 3, Y + 1, iz - 4, log="spruce_log", plank="spruce_planks", stair="spruce_stairs", slab="spruce_slab", door="spruce_door")
    S.lamp_post(c.bd, ix + 8, Y + 1, iz + 6, fence="spruce_fence")
    c.snow_cover(np.ones((c.nx, c.nz), dtype=bool))
    c.refresh_surface()
    over = dict(
        day=dict(zen=(0.42, 0.60, 0.92), hor=(0.82, 0.88, 0.97)),
        dawn=dict(zen=(0.42, 0.52, 0.80), hor=(0.97, 0.80, 0.74)),
    )
    shot = Shot(_cam_at(c, 11), pitch=-2.0, fog=dict(day=330.0, dawn=280.0, dusk=270.0, night=220.0),
                cloud_offset=(2100.0 + seed % 900, 40.0), overrides=over)
    return c.finish(), shot


_MESA_BANDS = ["terracotta", "orange_terracotta", "terracotta", "yellow_terracotta", "white_terracotta", "terracotta",
               "red_terracotta", "terracotta", "orange_terracotta", "brown_terracotta", "terracotta",
               "light_gray_terracotta", "terracotta", "yellow_terracotta", "red_terracotta", "terracotta"]


def desert(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers("sand", "sand", "sandstone", depth=5)
    dunes = 2.6 * c.n(120, 3) + 0.9 * np.abs(c.n(40, 2))
    h = 68 + dunes + 8 * smooth(180, 460, c.f) * c.n(160, 3)
    # Mesas on the right and a distant line of them, stepped into terraces.
    mesa = c.blob(250, 240, 170, 110, c.n(46, 3), 0.55)
    far_mesa = np.clip(c.blob(-60, 430, 460, 110, c.n(50, 3), 0.7) + c.blob(150, 400, 170, 90, c.n(50, 3), 0.7), 0, 1)
    m = np.maximum(smooth(0.05, 0.25, mesa), smooth(0.08, 0.3, far_mesa))
    top_h = 96 + 22 * (c.n(120, 2) + 0.3)
    step = np.floor((lerp(h, top_h, m)) / 5) * 5
    h = lerp(h, step, smooth(0.0, 0.25, m))
    mesa_mask = m > 0.05
    c.climate(np.ones((c.nx, c.nz), dtype=np.float32), "desert")
    # Oasis on the left: real water with reeds.
    os_ = c.s_at(0.22, 135)
    oasis = c.blob(os_, 135, 92, 42, c.n(34, 3), 0.45)
    h = lerp(h, 60, smooth(0.05, 0.4, oasis))
    oasis_rim = c.blob(os_, 135, 128, 66, c.n(34, 3), 0.3)
    c.paint(oasis_rim > 0.2, top="grass_block", fill="dirt")
    c.climate(smooth(0.05, 0.3, oasis_rim), "forest")
    h += _rough_rise(c, 8.0, rough=0.55)
    h, Y, ix, iz = c.flatten_pad(h, c.s_at(0.66, 112), 112, 10, 10, feather=18)
    c.paint(mesa_mask, top="red_sand", fill="terracotta", rock="terracotta", depth=2)
    c.build_terrain(h, sea_mask=oasis > 0.0, strata=False)
    # Terracotta strata.
    band_ids = [c.reg.id(n) for n in _MESA_BANDS]
    base_t = c.reg.id("terracotta")
    for y in range(60, 150):
        layer = c.blocks[:, y, :]
        layer[layer == base_t] = band_ids[y % len(band_ids)]
    # Ponds keep a sand floor.
    keep = smooth(26, 42, c.f)
    sand_id = c.reg.id("sand")
    need = [sand_id, c.reg.id("red_sand")]
    dens = 0.26 * keep * (1 - 0.7 * smooth(0.40, 0.2, c.sx))
    c.plant_trees([F.cactus], 11, dens.astype(np.float32), need=need)
    c.refresh_surface()
    c.plants("minecraft:dead_bush", (0.009 * keep).astype(np.float32), need=need)
    pad_ok = (oasis_rim > 0.1).astype(np.float32)
    c.plants("minecraft:short_grass", 0.3 * pad_ok)
    c.plants("minecraft:poppy", 0.015 * pad_ok)
    birch = lambda r, g: F.oak(r, g, log="jungle_log", leaves="jungle_leaves", hmin=6, hmax=9)
    c.plant_trees([birch, F.bush], 9, (0.45 * (oasis_rim > 0.3) * (oasis <= 0.03)).astype(np.float32))
    # Sugar cane on the water's edge.
    water = c.reg.id("water")
    edge = np.zeros((c.nx, c.nz), dtype=bool)
    wmask = c.blocks[:, 60, :] == water
    edge[1:-1, 1:-1] = wmask[2:, 1:-1] | wmask[:-2, 1:-1] | wmask[1:-1, 2:] | wmask[1:-1, :-2]
    edge &= ~wmask & (c.rng.random(edge.shape) < 0.22)
    for x, z in zip(*np.nonzero(edge)):
        y = int(c.surf[x, z])
        if c.blocks[x, y + 1, z] == 0 and y <= 63:
            for k in range(1, int(c.rng.integers(2, 5))):
                c.blocks[x, y + k, z] = c.reg.id("sugar_cane")
    S.well(c.bd, ix, Y + 1, iz)
    S.house(c.bd, ix + 14, Y + 1, iz - 6, w=7, d=7, log="stripped_oak_log", plank="smooth_sandstone", stair="sandstone_stairs", slab="sandstone_slab", found="sandstone", door="acacia_door")
    S.lamp_post(c.bd, ix - 5, Y + 1, iz + 5)
    c.refresh_surface()
    over = dict(
        day=dict(zen=(0.40, 0.60, 0.98), hor=(0.92, 0.89, 0.82), amb=(0.78, 0.76, 0.72), dir=(0.56, 0.50, 0.38)),
        dawn=dict(hor=(0.99, 0.80, 0.60)),
        dusk=dict(hor=(0.98, 0.62, 0.40)),
    )
    shot = Shot(_cam_at(c, 10), pitch=-2.0, fog=dict(day=370.0, dawn=320.0, dusk=300.0, night=240.0),
                cloud_offset=(40.0 + seed % 1500, 1700.0), overrides=over)
    return c.finish(), shot


def cherry_grove(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers()
    h = 74 + 9 * c.n(150, 4) + 3 * c.n(44, 3)
    ridge = np.clip(1 - np.abs(c.n(230, 5, gain=0.55)) * 2.2, 0, 1)
    h += 84 * smooth(240, 500, c.f) * ridge ** 1.2 * (0.6 + 0.5 * c.n(300, 2))
    h += 18 * c.blob(260, 180, 220, 160, c.n(70, 3), 0.3)
    pond = c.blob(c.s_at(0.2, 180), 180, 160, 62, c.n(40, 3), 0.42)
    h = lerp(h, 57, smooth(0.03, 0.4, pond))
    h += _rough_rise(c, 9.0)
    hs = c.s_at(0.7, 116)
    h, Y, ix, iz = c.flatten_pad(h, hs, 116, 8, 8, feather=16)
    c.climate(np.ones((c.nx, c.nz), dtype=np.float32), "cherry_grove")
    c.set_water_color("cherry")
    c.paint(h > 128, top="snow_block", fill="snow_block", depth=3)
    gx, gz = np.gradient(h.astype(np.float32))
    c.paint((np.hypot(gx, gz) > 1.7) & (h > 95), top="stone", fill="stone", depth=2)
    _lake_floor(c, h)
    c.build_terrain(h, overhang=5.0 * smooth(112, 150, h))
    keep = _near_trees(c, 56.0, 30.0) * (1 - 0.9 * smooth(0.5, 0.3, c.sx)) * smooth(118, 100, h)
    site = smooth(30, 16, np.hypot(c.s - hs, c.f - 116))
    c.plant_trees([F.cherry], 12, (0.56 * keep * (1 - site)).astype(np.float32), variants=14)
    c.refresh_surface()
    calm = smooth(22, 38, c.f)
    c.plants("minecraft:short_grass", ((0.08 + 0.30 * smooth(-0.1, 0.3, c.n(30, 3))) * calm).astype(np.float32))
    c.plants("minecraft:tall_grass[half=lower]", (0.008 * calm).astype(np.float32), upper="minecraft:tall_grass[half=upper]")
    petals = smooth(-0.1, 0.25, c.n(30, 3)) * smooth(24, 40, c.f)
    for amount, face in ((4, "north"), (3, "east"), (4, "south"), (2, "west")):
        c.plants(f"minecraft:pink_petals[facing={face},flower_amount={amount}]", (0.07 * petals).astype(np.float32))
    c.flowers((0.016 * smooth(24, 40, c.f)).astype(np.float32), ["minecraft:pink_tulip", "minecraft:allium", "minecraft:oxeye_daisy", "minecraft:lily_of_the_valley"])
    _lily_pads(c, 0.010)
    _under_plants(c, 0.03)
    S.pavilion(c.bd, ix, Y + 1, iz)
    c.refresh_surface()
    pink = (0xB6, 0xDB, 0x61)
    w = c.finish(tint_override=dict(grass=pink, foliage=pink))
    over = dict(day=dict(zen=(0.46, 0.64, 0.98), hor=(0.92, 0.86, 0.95)), dawn=dict(hor=(0.99, 0.80, 0.82)))
    shot = Shot(_cam_at(c, 11), pitch=-2.0, fog=dict(day=340.0, dawn=280.0, dusk=270.0, night=220.0),
                cloud_offset=(900.0 + seed % 1000, 2600.0), overrides=over)
    return w, shot


def ocean_beach(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers("sand", "sand", "stone", depth=5)
    wob = 26 * c.n(90, 3)
    coast = c.s - 0.26 * c.f - 26 + wob  # > 0 is land, sweeping away to the right as it recedes
    h = 62 + np.where(coast > 0, np.minimum(coast * 0.085, 7.0), np.maximum(coast * 0.11, -24.0)) + 0.9 * c.n(26, 2)
    # Headland behind the beach, with a cliff seaward.
    hs = c.s_at(0.78, 175)
    head = c.blob(hs, 175, 76, 62, c.n(38, 3), 0.42)
    h = np.where(head > 0.03, np.maximum(h, 63 + 19 * smooth(0.03, 0.42, head)), h)
    h += 16 * smooth(70, 270, coast) * (0.5 + 0.7 * c.n(120, 3))
    # Islands on the horizon.
    for s0, f0, rs, rf, hgt in ((-250, 400, 90, 40, 26), (-40, 470, 120, 44, 40), (-300, 240, 42, 24, 12)):
        isl = c.blob(s0, f0, rs, rf, c.n(30, 3), 0.5)
        h = np.where(isl > 0.0, np.maximum(h, 58 + hgt * smooth(0.0, 0.8, isl)), h)
    c.climate(np.ones((c.nx, c.nz), dtype=np.float32), "beach")
    c.set_water_color("lukewarm")
    land = h >= 66.5
    c.paint(land, top="grass_block", fill="dirt", depth=4)
    c.paint(h < 66.5, top="sand", fill="sand", depth=4)
    gx, gz = np.gradient(h.astype(np.float32))
    c.paint((np.hypot(gx, gz) > 1.5) & (h > 64), top="stone", fill="stone", depth=2)
    c.build_terrain(h)
    dens = 0.34 * (land & (c.f > 40)) * smooth(0.40, 0.55, c.sx) * (1 - smooth(34, 14, np.hypot(c.s - hs, c.f - 175)))
    c.plant_trees([F.oak, F.oak, F.fancy_oak], 9, dens.astype(np.float32))
    keep = land & (c.f > 44)
    c.refresh_surface()
    c.plants("minecraft:short_grass", 0.28 * keep.astype(np.float32))
    c.flowers((0.02 * keep).astype(np.float32), FLOWERS_COMMON)
    sand_id = c.reg.id("sand")
    _under_plants(c, 0.016 * (c.f > 90))
    # Lighthouse on the headland, a pier from the beach.
    lx, lz = c.view_to_world(hs, 175)
    ly = int(c.surf[lx, lz]) + 1
    S.lighthouse(c.bd, lx, ly, lz, h=24)
    px, pz = c.view_to_world(0.26 * 112 + 30, 112)
    for x in range(px - 46, px):
        c.bd.box(x, 64, pz - 1, x, 64, pz + 1, "oak_planks")
        if (x - px) % 6 == 0:
            c.bd.box(x, 54, pz - 1, x, 63, pz - 1, "oak_log", axis="y")
            c.bd.box(x, 54, pz + 1, x, 63, pz + 1, "oak_log", axis="y")
            c.bd.set(x, 65, pz - 1, "oak_fence", north="false", south="false", east="false", west="false")
            c.bd.set(x, 66, pz - 1, "lantern", hanging="false")
    c.refresh_surface()
    over = dict(day=dict(zen=(0.33, 0.58, 0.98), hor=(0.74, 0.88, 1.0)))
    shot = Shot(_cam_at(c, 16), fog=dict(day=420.0, dawn=320.0, dusk=300.0, night=250.0), pitch=-0.5,
                cloud_offset=(300.0 + seed % 1200, 2200.0), overrides=over)
    return c.finish(), shot


def mountains(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers()
    base = 66 + 5 * c.n(120, 4)
    ridge = np.clip(1 - np.abs(c.n(190, 5, gain=0.55)) * 2.0, 0, 1)
    ridge2 = np.clip(1 - np.abs(c.n(75, 4, gain=0.5)) * 2.2, 0, 1)
    massif = np.clip(c.blob(250, 430, 400, 250) * 1.5, 0, 1)
    back = smooth(330, 520, c.f)
    M = np.maximum(massif ** 0.8, back * 0.82)
    h = base + (150 * ridge ** 1.45 + 22 * ridge2 * ridge) * M
    # Keep the left valley open: river and meadow.
    valley = smooth(0.40, 0.14, c.sx) * smooth(500, 340, c.f)
    h = lerp(h, 65 + 3 * c.n(80, 3), valley * 0.97)
    river = np.exp(-(((c.s + 130 + 42 * c.n(120, 2) + (c.f - 150) * 0.42) / 13.0) ** 2)) * smooth(60, 130, c.f)
    h = lerp(h, 58, river)
    h += _rough_rise(c, 11.0)
    c.climate(smooth(95, 135, h), "windswept")
    c.climate(smooth(70, 90, h) * (1 - smooth(95, 135, h)), "taiga")
    c.climate(smooth(145, 165, h), "peaks")
    c.set_water_color("cold")
    gx, gz = np.gradient(h.astype(np.float32))
    slope = np.hypot(gx, gz)
    stone_mask = (h > 108) | (slope > 1.5)
    c.paint(stone_mask & (h > 80), top="stone", fill="stone", depth=2)
    c.paint((c.n(30, 3) > 0.25) & (h > 105) & (h < 150), top="gravel", fill="gravel", depth=2)
    c.paint((h > 150 + 8 * c.n(40, 3)) & (slope < 2.2), top="snow_block", fill="snow_block", depth=3)
    _lake_floor(c, h)
    ohang = 11.0 * smooth(90, 135, h)
    c.build_terrain(h, overhang=ohang, carve=smooth(90, 120, h))
    keep = (1 - smooth(70, 30, c.f)) * smooth(118, 95, h)
    forest = smooth(-0.15, 0.2, c.n(100, 3))
    dens = 0.55 * forest * keep * (1 - 0.82 * smooth(0.46, 0.26, c.sx))
    c.plant_trees([F.spruce, F.spruce, F.pine, F.mega_spruce], 6, dens.astype(np.float32), variants=14)
    c.refresh_surface()
    calm = 1 - 0.8 * smooth(55, 30, c.f)
    c.plants("minecraft:short_grass", (0.28 * calm).astype(np.float32))
    c.flowers((0.03 * smooth(40, 70, c.f) * smooth(0.5, 0.2, c.sx)).astype(np.float32), ["minecraft:cornflower", "minecraft:allium", "minecraft:oxeye_daisy", "minecraft:azure_bluet", "minecraft:dandelion"])
    _under_plants(c, 0.02)
    # A stone watch tower on the shoulder of the massif.
    tx, tz = c.view_to_world(c.s_at(0.70, 150), 150)
    ty = int(c.surf[tx, tz]) + 1
    S.tower(c.bd, tx, ty, tz, rng=c.rng, h=15)
    c.snow_cover(smooth(150, 160, h.astype(np.float32)) > 0.5)
    c.refresh_surface()
    shot = Shot(_cam_at(c, 9), pitch=4.0, fog=dict(day=470.0, dawn=380.0, dusk=360.0, night=280.0),
                cloud_offset=(2400.0, 1300.0 + seed % 800))
    return c.finish(), shot


def mushroom_fields(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, tanh=TANH)
    c.layers("mycelium", "dirt", "stone")
    island = c.blob(190, 200, 300, 175, c.n(90, 3), 0.55)
    small1 = c.blob(-260, 320, 120, 70, c.n(40, 3), 0.5)
    small2 = c.blob(40, 470, 220, 80, c.n(40, 3), 0.5)
    k = np.maximum.reduce([smooth(0.0, 0.5, island), smooth(0.0, 0.7, small1) * 0.8, smooth(0.0, 0.7, small2)])
    h = 46 + 24 * k + 3.0 * c.n(70, 3) * k + 1.4 * c.n(24, 2)
    h += 14 * smooth(0.45, 1.0, island) * (0.5 + 0.6 * c.n(90, 3))
    fore = smooth(82, 30, c.f) * smooth(220, 110, np.abs(c.s))
    h = lerp(h, 69 + 2.6 * c.n(44, 3), fore) + _rough_rise(c, 2.0, rough=0.8)
    # A cove on the left of the camera, so the view opens onto water there.
    cove = smooth(0.42, 0.20, c.sx) * smooth(50, 100, c.f)
    h = lerp(h, 52, cove * 0.92)
    c.climate(np.ones((c.nx, c.nz), dtype=np.float32), "mushroom")
    under = h < 62
    c.paint(under, top="gravel", fill="gravel")
    c.paint(under & (c.n(30, 2) > 0), top="clay", fill="clay")
    c.build_terrain(h)
    myc = c.reg.id("mycelium", snowy="false")
    keep = _near_trees(c, 62.0, 30.0) * (1 - 0.97 * smooth(0.52, 0.36, c.sx))
    c.plant_trees([F.huge_red_mushroom, F.huge_red_mushroom, F.huge_brown_mushroom], 13, (0.42 * keep).astype(np.float32), need=[myc], variants=16)
    c.refresh_surface()
    calm = smooth(22, 38, c.f)
    patch_m = 0.015 + 0.08 * smooth(0.0, 0.3, c.n(26, 3))
    c.plants("minecraft:red_mushroom", (patch_m * calm).astype(np.float32), need=[myc])
    c.plants("minecraft:brown_mushroom", ((0.095 - patch_m) * calm).astype(np.float32), need=[myc])
    _under_plants(c, 0.02)
    c.refresh_surface()
    over = dict(
        day=dict(zen=(0.47, 0.62, 0.96), hor=(0.86, 0.82, 0.93), amb=(0.76, 0.74, 0.80)),
    )
    shot = Shot(_cam_at(c, 11), pitch=-1.0, fog=dict(day=350.0, dawn=290.0, dusk=270.0, night=220.0),
                cloud_offset=(1700.0, 2900.0 + seed % 700), overrides=over)
    return c.finish(), shot


def nether(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, nx=760, ny=140, nz=540, cam_back=40, tanh=TANH)
    c.layers("netherrack", "netherrack", "netherrack")
    lava_y = 31
    rough = 8 * c.n(70, 4) + 3 * c.n(20, 2)
    shelf = c.blob(255, 130, 215, 190, c.n(70, 3), 0.55)
    far_w = c.blob(-80, 440, 300, 70, c.n(50, 3), 0.7)
    k = np.maximum(smooth(0.03, 0.34, shelf), smooth(0.05, 0.4, far_w))
    h = 22 + 26 * k + rough * (0.25 + 0.75 * k)
    # Cliffs climb on the right, up into the ceiling.
    wall = smooth(240, 360, c.s) + smooth(240, 110, c.s) * 0
    h += 76 * np.clip(wall, 0, 1) * (0.7 + 0.5 * c.n(50, 3))
    spikes = np.clip(c.n(26, 3) - 0.40, 0, 1) * 3.0 * k * smooth(0.48, 0.70, c.sx)
    h += 34 * spikes
    # The camera stands on a low ledge.
    ledge = smooth(120, 62, np.hypot((c.s - 30) * 0.8, c.f + 22))
    h = lerp(h, 56 + 2.5 * c.n(18, 2), ledge)
    # Low islands and pillars break up the lava sea in the middle distance.
    for s0, f0, rs, rf, top_y in ((-30, 300, 70, 40, 44), (-220, 250, 44, 30, 40), (120, 340, 80, 46, 52), (-120, 400, 90, 40, 58)):
        isl = c.blob(s0, f0, rs, rf, c.n(24, 3), 0.55)
        h = np.where(isl > 0.0, np.maximum(h, 30 + (top_y - 30) * smooth(0.0, 0.6, isl)), h)
    biome = c.n(120, 3)
    land = h > lava_y + 1
    c.paint(land & (biome > 0.05), top="crimson_nylium", depth=1)
    warped = land & (c.n(170, 3) > 0.26)
    c.paint(warped, top="warped_nylium", depth=1)
    basalt = c.n(60, 3) < -0.25
    c.paint(basalt & land, top="basalt", fill="basalt", rock="basalt", depth=6)
    c.paint((h <= lava_y + 3) & (c.n(30, 3) > 0.1), top="soul_sand", fill="soul_sand", depth=2)
    c.build_terrain(h, sea=-1, sea_mask=np.zeros((c.nx, c.nz), dtype=bool), strata=False)
    # Lava sea.
    lava = c.reg.id("lava")
    for y in range(2, lava_y + 1):
        layer = c.blocks[:, y, :]
        layer[layer == 0] = lava
    # Ceiling.
    ceil = (110 + 10 * c.n(90, 4) + 7 * c.n(24, 3)).astype(np.int32)
    drip = np.clip(c.n(22, 3) - 0.3, 0, 1) * 80 * smooth(0.3, 0.6, c.sx)
    ceil = np.maximum((ceil - drip).astype(np.int32), 74)
    rack = c.reg.id("netherrack")
    for y in range(66, c.ny):
        mask = y >= ceil
        layer = c.blocks[:, y, :]
        layer[mask] = rack
    c.refresh_surface()
    surf_floor = np.minimum(h.astype(np.int32), ceil - 1)
    c.surf = surf_floor
    # Vegetation.
    crim = c.reg.id("crimson_nylium")
    warp = c.reg.id("warped_nylium")
    keep = (1 - smooth(70, 40, c.f)) * (1 - 0.9 * smooth(0.50, 0.32, c.sx))
    fungus_c = lambda r, g: F.nether_fungus(r, g, "crimson")
    fungus_w = lambda r, g: F.nether_fungus(r, g, "warped")
    c.plant_trees([fungus_c], 8, (0.45 * keep).astype(np.float32), need=[crim], variants=12)
    c.plant_trees([fungus_w], 8, (0.45 * keep).astype(np.float32), need=[warp], variants=12)
    c.plants("minecraft:crimson_roots", (0.10 * keep).astype(np.float32), need=[crim])
    c.plants("minecraft:crimson_fungus", (0.02 * keep).astype(np.float32), need=[crim])
    c.plants("minecraft:warped_roots", (0.10 * keep).astype(np.float32), need=[warp])
    c.plants("minecraft:nether_sprouts", (0.08 * keep).astype(np.float32), need=[warp])
    c.plants("minecraft:fire[age=0,east=false,north=false,south=false,up=false,west=false]", (0.0035 * keep).astype(np.float32), need=[c.reg.id("netherrack")])
    # Glowstone clusters under the ceiling.
    gx, gz = c.scatter(30, 0.55)
    glow = c.reg.id("glowstone")
    for x, z in zip(gx, gz):
        cy = int(ceil[x, z]) - 1
        if cy < 60:
            continue
        for _ in range(int(c.rng.integers(30, 90))):
            dx, dy, dz = c.rng.integers(-3, 4), -c.rng.integers(0, 6), c.rng.integers(-3, 4)
            if dx * dx + dz * dz > 9 - dy:
                continue
            xx, yy, zz = x + dx, cy + dy, z + dz
            if 0 <= xx < c.nx and 0 <= zz < c.nz and c.blocks[xx, yy, zz] == 0:
                c.blocks[xx, yy, zz] = glow
    # Lava falls pouring from the ceiling into the sea.
    for _ in range(14):
        x, z = c.view_to_world(float(c.rng.uniform(-60, 360)), float(c.rng.uniform(150, 420)))
        top_y = int(ceil[x, z]) - 1
        floor_y = int(h[x, z])
        for y in range(top_y, max(floor_y, lava_y), -1):
            for xx, zz in ((x, z), (x + 1, z), (x, z + 1), (x + 1, z + 1)):
                if c.blocks[xx, y, zz] in (0, glow):
                    c.blocks[xx, y, zz] = lava
    # A fortress span running out across the lava sea.
    bx0, bz = c.view_to_world(-300, 205)
    bx1, _ = c.view_to_world(240, 205)
    S.fortress_bridge_x(c.bd, bx0, bx1, 62, bz)
    # The ledge's ruined portal.
    px, pz = c.view_to_world(44, 44)
    S.nether_portal(c.bd, px, int(h[px, pz]) + 1, pz)
    shot = Shot((c.cx + 0.5, 68.0, c.cz + 0.5), pitch=-4.0, yaw=0.0, times=("night",),
                fog=dict(night=230.0), sun_az=dict(night=0.0), sun_el=dict(night=90.0))
    w = c.finish(mode=R.MODE_NETHER)
    return w, shot


def the_end(seed: int) -> tuple[World, Shot]:
    c = Canvas(seed, nx=880, ny=200, nz=620, cam_back=70, tanh=TANH)
    c.layers("end_stone", "end_stone", "end_stone", depth=1)
    main = c.blob(170, 285, 235, 190, c.n(50, 3), 0.28)
    isl_a = c.blob(-300, 320, 110, 66, c.n(30, 3), 0.42)
    isl_b = c.blob(-90, 480, 150, 60, c.n(30, 3), 0.42)
    isl_c = c.blob(-420, 150, 60, 38, c.n(20, 3), 0.42)
    isl_d = c.blob(500, 440, 130, 70, c.n(30, 3), 0.42)
    mask_main = smooth(0.0, 0.12, main)
    k = np.maximum.reduce([mask_main, smooth(0.0, 0.14, isl_a), smooth(0.0, 0.14, isl_b),
                           smooth(0.0, 0.14, isl_c), smooth(0.0, 0.14, isl_d)])
    top = 62 + 5 * c.n(70, 3) + 2 * c.n(20, 2) + 1.5 * (smooth(0.0, 0.5, main))
    h = np.where(k > 0.02, top, 0)
    c.build_terrain(np.maximum(h, 2), sea=-1, sea_mask=np.zeros((c.nx, c.nz), dtype=bool), strata=False)
    # Hollow out below each island: floating, tapering undersides over the void.
    depth = 6 + 48 * np.sqrt(np.clip(k, 0, 1)) * (0.6 + 0.5 * c.n(40, 3))
    bottom = (h - depth).astype(np.int32)
    col = k <= 0.02
    for y in range(0, c.ny):
        layer = c.blocks[:, y, :]
        layer[(y < bottom) | col] = 0
    c.surf = np.maximum(h.astype(np.int32), 0)
    # The ring of obsidian pillars on the main island.
    ox, oz = c.view_to_world(170, 285)
    obsidian = c.reg.id("obsidian")
    for i in range(10):
        ang = i * 2 * np.pi / 10 + 0.35
        px = int(ox + np.cos(ang) * 150 * 0.72)
        pz = int(oz + np.sin(ang) * 118 * 0.72)
        radius = int(3 + (i * 7 % 3))
        height = 76 + (i * 13 % 28) + 6
        for x in range(px - radius, px + radius + 1):
            for z in range(pz - radius, pz + radius + 1):
                if (x - px) ** 2 + (z - pz) ** 2 <= radius * radius + 1:
                    c.bd.box(x, 40, z, x, height, z, obsidian)
        c.bd.set(px, height + 1, pz, "bedrock")
        c.bd.set(px, height + 2, pz, "fire", age=0)
    # Exit-portal fountain at the centre.
    ground = int(c.surf[ox, oz])
    for x in range(ox - 3, ox + 4):
        for z in range(oz - 3, oz + 4):
            d2 = (x - ox) ** 2 + (z - oz) ** 2
            if d2 <= 10:
                c.bd.set(x, ground, z, "bedrock")
            if d2 <= 5:
                c.bd.set(x, ground + 1, z, "end_portal")
    c.bd.box(ox, ground + 1, oz, ox, ground + 4, oz, "bedrock")
    # Chorus groves on the outer islands, an end-city tower on the right.
    es = c.reg.id("end_stone")
    outer = np.maximum.reduce([smooth(0, 0.3, isl_a), smooth(0, 0.3, isl_b), smooth(0, 0.3, isl_c), smooth(0, 0.3, isl_d)])
    c.plant_trees([F.chorus], 9, (0.42 * outer).astype(np.float32), need=[es], variants=12)
    c.plant_trees([F.chorus], 26, (0.1 * mask_main * smooth(0.45, 0.5, c.sx)).astype(np.float32), need=[es], variants=6)
    tx, tz = c.view_to_world(345, 380)
    S.end_tower(c.bd, tx, int(c.surf[tx, tz]) + 1, tz, h=48, rng=c.rng)
    tx2, tz2 = c.view_to_world(-90, 480)
    S.end_tower(c.bd, tx2, int(c.surf[tx2, tz2]) + 1, tz2, h=30, rng=c.rng)
    w = c.finish(mode=R.MODE_END)
    shot = Shot((c.cx + 0.5, 90.0, c.cz + 0.5), pitch=-2.0, times=("night",), fog=dict(night=700.0),
                sun_az=dict(night=0.0), sun_el=dict(night=90.0))
    return w, shot


SCENES = {
    "plains": dict(fn=plains, title="Flower Plains", nn=1, seed=41),
    "birch-forest": dict(fn=birch_forest, title="Birch Forest", nn=2, seed=7),
    "snowy-taiga": dict(fn=snowy_taiga, title="Snowy Taiga", nn=3, seed=23),
    "desert": dict(fn=desert, title="Desert Oasis", nn=4, seed=88),
    "cherry-grove": dict(fn=cherry_grove, title="Cherry Grove", nn=5, seed=5),
    "ocean-beach": dict(fn=ocean_beach, title="Lighthouse Beach", nn=6, seed=64),
    "mountains": dict(fn=mountains, title="Windswept Peaks", nn=7, seed=19),
    "mushroom-fields": dict(fn=mushroom_fields, title="Mushroom Fields", nn=8, seed=33),
    "nether": dict(fn=nether, title="The Nether", nn=9, seed=66),
    "the-end": dict(fn=the_end, title="The End", nn=10, seed=99),
}
