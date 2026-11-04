"""The title-screen world: a vista in every direction, camera in the middle, for cube faces, strip and lock frames.

Cube faces follow the game's convention (minecraft.wiki/w/Panorama and Tutorial:Making_custom_panoramas):
panorama_0..3 run left to right (each 90 degrees clockwise from the last), panorama_4 is above panorama_0 with its
bottom edge bordering 0's top, panorama_5 is below with its top edge bordering 0's bottom.
"""
from __future__ import annotations

import time as _time

import numpy as np
from PIL import Image, ImageFilter

from . import features as F
from . import render as R
from . import structures as S
from . import catalog
from .paths import RENDERS
from .scenes import FLOWERS_COMMON, TULIPS, Shot, _beach, _cam_at, _lake_floor, _lily_pads, _under_plants
from .terrain import Canvas, lerp, smooth
from .world import Camera, post, render, save_png, _shoulder, _to_u8

FRONT_YAW = 20.0  # the view the title screen opens on


def build(seed: int = 12):
    """A hilltop between a lake, forest, cherry slopes, a coast and a wall of mountains."""
    c = Canvas(seed, nx=860, ny=256, nz=860, cam_back=430, tanh=1.0)
    c.layers()
    r = np.hypot(c.s, c.f)
    ang = np.degrees(np.arctan2(c.s, c.f)) % 360  # 0 north, 90 east, 180 south, 270 west
    warp = 30 * c.n(120, 3)
    a = (ang + warp) % 360
    def sector(a0, a1, soft=26.0):
        # Circular distance from the sector's middle, so nothing jumps where the angle wraps from 360 to 0.
        mid, half = (a0 + a1) / 2, (a1 - a0) / 2
        d = np.abs(((a - mid + 180.0) % 360.0) - 180.0)
        return smooth(half + soft, half - soft, d)
    north = sector(-10, 70)
    east = sector(70, 160)
    south = sector(160, 250)
    west = sector(250, 340)
    # Base rolling land and the central hill the camera stands on.
    h = 68 + 4.5 * c.n(170, 4) + 1.8 * c.n(44, 3)
    # High enough to look down on the valley, the village and the water, not just across a meadow.
    h += (42 + 4 * c.n(50, 3)) * smooth(140, 22, r) + (5.5 * c.n(62, 3) + 3.0 * c.n(26, 2)) * smooth(230, 60, r)
    # North: the mountain wall.
    ridge = np.clip(1 - np.abs(c.n(180, 5, gain=0.55)) * 2.0, 0, 1)
    wall = smooth(150, 300, r)
    mts = (north + 0.55 * east) * wall * (142 * ridge ** 1.4 + 18 * np.clip(1 - np.abs(c.n(70, 4)) * 2.2, 0, 1))
    h += mts
    # South: a coast.
    sea_mask = south * smooth(95, 170, r)
    h = lerp(h, 46 + 3 * c.n(40, 2), np.clip(sea_mask * 1.3, 0, 1))
    # A lake below the hill to the east.
    lx, lz = 160, 90
    lake = c.blob(lx, lz, 105, 82, c.n(50, 3), 0.42)
    h = lerp(h, 54, smooth(0.03, 0.4, lake))
    # Islands out to sea.
    for s0, f0, rs, rf, hgt in ((-170, -300, 56, 40, 24), (60, -340, 76, 44, 32)):
        isl = c.blob(s0, f0, rs, rf, c.n(30, 3), 0.5)
        h = np.where(isl > 0.0, np.maximum(h, 56 + hgt * smooth(0.0, 0.8, isl)), h)
    # West: cherry slopes rise up.
    h += west * 26 * smooth(70, 240, r) * (0.55 + 0.6 * c.n(120, 3))
    # Village pad, on the way down to the lake.
    vx, vf = 42, 92
    h, Y, ix, iz = c.flatten_pad(h, vx, vf, 16, 13, feather=18)
    # Climate.
    c.climate(north * smooth(90, 140, h) * smooth(170, 220, r), "taiga")
    c.climate(east, "forest")
    c.climate(west, "cherry_grove")
    c.set_water_color("lukewarm", south > 0.4)
    gx, gz = np.gradient(h.astype(np.float32))
    slope = np.hypot(gx, gz)
    # Rock and snow belong to the far mountains; the camera's hill is high but stays green.
    far = r > 170
    c.paint(far & ((h > 108) | ((slope > 1.5) & (h > 84))), top="stone", fill="stone", depth=2)
    c.paint(far & (h > 148 + 8 * c.n(40, 3)) & (slope < 2.2), top="snow_block", fill="snow_block", depth=3)
    _beach(c, h, band=2.0, noise_amp=1.5)
    _lake_floor(c, h)
    c.build_terrain(h, overhang=9.0 * smooth(100, 140, h) * smooth(150, 230, r), carve=smooth(100, 130, h))
    # Trees per sector, none right around the camera.
    clear = smooth(30, 52, r)
    pad = 1 - smooth(42, 24, np.hypot(c.s - vx, c.f - vf))
    tree = smooth(-0.12, 0.2, c.n(84, 3)) * clear * pad
    high_cut = np.where(r > 170, smooth(116, 96, h), 1.0)
    c.plant_trees([F.spruce, F.spruce, F.pine, F.mega_spruce], 7, (0.5 * north * tree * high_cut).astype(np.float32), variants=12)
    birch = lambda rg, g: F.oak(rg, g, log="birch_log", leaves="birch_leaves", hmin=5, hmax=10)
    c.plant_trees([F.oak, F.oak, F.fancy_oak, birch], 8, (0.62 * east * tree * high_cut).astype(np.float32), variants=14)
    c.plant_trees([F.cherry], 12, (0.55 * west * tree * high_cut).astype(np.float32), variants=12)
    c.plant_trees([F.oak, F.fancy_oak], 13, (0.34 * south * tree * high_cut).astype(np.float32), variants=8)
    c.refresh_surface()
    near = smooth(4, 12, r)
    c.plants("minecraft:short_grass", ((0.05 + 0.34 * smooth(-0.1, 0.3, c.n(30, 3))) * near).astype(np.float32))
    c.plants("minecraft:tall_grass[half=lower]", (0.012 * near).astype(np.float32), upper="minecraft:tall_grass[half=upper]")
    c.flowers((0.09 * smooth(0.0, 0.26, c.n(34, 3)) * near).astype(np.float32), FLOWERS_COMMON + TULIPS)
    for amount, face in ((4, "north"), (3, "east"), (4, "south"), (2, "west")):
        c.plants(f"minecraft:pink_petals[facing={face},flower_amount={amount}]", (0.05 * west * smooth(-0.1, 0.25, c.n(30, 3))).astype(np.float32))
    _lily_pads(c, 0.008)
    _under_plants(c, 0.03)
    # The village: three houses, a farm, lamps; a lighthouse on the south shore.
    S.house(c.bd, ix - 12, Y + 1, iz - 4)
    S.house(c.bd, ix + 5, Y + 1, iz - 5, w=7, d=7, log="spruce_log", plank="spruce_planks", stair="spruce_stairs", slab="spruce_slab", door="spruce_door")
    S.house(c.bd, ix - 4, Y + 1, iz - 15, w=7, d=7)
    S.farm(c.bd, ix - 4, Y + 1, iz + 5)
    for dx, dz in ((-14, 7), (13, 7), (0, -2)):
        S.lamp_post(c.bd, ix + dx, Y + 1, iz + dz)
    lhx, lhz = c.view_to_world(-60, -190)
    S.lighthouse(c.bd, lhx, int(c.surf[lhx, lhz]) + 1, lhz, h=24)
    # A watch tower on the camera's hill, just off the summit.
    tx, tz = c.view_to_world(-24, 36)
    S.tower(c.bd, tx, int(c.surf[tx, tz]) + 1, tz, r=3, h=12, rng=c.rng)
    c.refresh_surface()
    world = c.finish()
    pos = _cam_at(c, 8.5)
    sa = dict(day=FRONT_YAW + 35, dawn=FRONT_YAW + 30, dusk=FRONT_YAW + 30, night=FRONT_YAW + 40)
    shot = Shot(pos, yaw=0.0, pitch=0.0, fov=62.0,
                fog=dict(day=270.0, dawn=230.0, dusk=230.0, night=190.0),
                sun_az=sa, cloud_offset=(1500.0, 610.0))
    return world, shot


def _tone(rgb: np.ndarray, seed=3) -> np.ndarray:
    """Same tone curve as post(), without any screen-space filter, so cube faces and the strip's ends meet exactly."""
    a = _shoulder(rgb.astype(np.float32))
    lum = (a * [0.299, 0.587, 0.114]).sum(axis=-1, keepdims=True)
    a = np.clip(lum + (a - lum) * 1.05, 0, 1)
    rng = np.random.default_rng(seed)
    return _to_u8(a + (rng.random(a.shape[:2] + (1,), dtype=np.float32) - 0.5) / 255.0)


def render_all(seed: int = 12, *, ss: int = 2, log=print) -> dict:
    t0 = _time.time()
    world, shot = build(seed)
    log(f"panorama world built in {_time.time() - t0:.1f}s, top {int(world.top.max())}")
    out = RENDERS / "panorama"
    out.mkdir(parents=True, exist_ok=True)
    timings = {}
    # Cube faces: fov 90, no screen-space filter so edges line up.
    P = catalog.sky_for(world, shot, "day", view=False)
    faces = [(FRONT_YAW, 0.0), (FRONT_YAW + 90, 0.0), (FRONT_YAW + 180, 0.0), (FRONT_YAW + 270, 0.0),
             (FRONT_YAW, 90.0), (FRONT_YAW, -90.0)]
    t1 = _time.time()
    for i, (yaw, pitch) in enumerate(faces):
        rgb, _, _ = render(world, Camera(shot.pos, yaw, pitch, 90.0), P, 1024, 1024, ss)
        save_png(_tone(rgb), out / f"panorama_{i}.png")
    timings["faces"] = round(_time.time() - t1, 1)
    # Seamless strips: a cylinder over the full width, 1080 tall, for SDDM's rotating background.
    t1 = _time.time()
    for time, name in (("day", "strip.png"), ("night", "strip-night.png"), ("dusk", "strip-dusk.png")):
        P = catalog.sky_for(world, shot, time, view=False)
        cam = Camera(shot.pos, FRONT_YAW, 0.0, 60.0, projection=1)
        rgb, _, _ = render(world, cam, P, 5760, 1080, ss)
        save_png(_tone(rgb), out / name)
    timings["strips"] = round(_time.time() - t1, 1)
    # Lock-screen frames: the panorama's opening view, slightly blurred.
    t1 = _time.time()
    for time, name in (("day", "lock-day.png"), ("night", "lock-night.png")):
        lock_shot = Shot(shot.pos, yaw=FRONT_YAW, pitch=0.0, fov=62.0, fog=shot.fog, sun_az={k: v - FRONT_YAW for k, v in shot.sun_az.items()},
                         cloud_offset=shot.cloud_offset)
        P = catalog.sky_for(world, lock_shot, time)
        rgb, _, _ = render(world, lock_shot.camera(), P, 1920, 1080, ss)
        save_png(post(rgb, calm=False, blur=2.6), RENDERS / name)
    timings["lock"] = round(_time.time() - t1, 1)
    timings["total"] = round(_time.time() - t0, 1)
    log(f"panorama done: {timings}")
    return timings
