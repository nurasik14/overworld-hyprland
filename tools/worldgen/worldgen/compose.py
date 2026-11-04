"""Automatic framing for terrain nobody art-directed: the user's real worlds.

Renders hundreds of tiny previews from candidate viewpoints and scores each like a photo editor would: enough sky,
depth, colour, nothing right in front of the lens, quieter on the left and bottom where the desktop's widgets and
hotbar sit, and no view of the unexplored void beyond the generated chunks.
"""
from __future__ import annotations

import math

import numpy as np

from . import render as R
from . import sky
from .scenes import FOV, Shot
from .world import Camera, World, render

PW, PH = 128, 72


def _score(rgb: np.ndarray, depth: np.ndarray, *, want_sky: float) -> float:
    h, w = depth.shape
    sky_frac = float((depth == -1).mean())
    void = float((depth == -2).mean())
    near = float(((depth > 0) & (depth < 4)).mean())
    near2 = float(((depth > 0) & (depth < 12)).mean())
    d = depth[depth > 0]
    if d.size < 16:
        return -10.0
    variety = float(np.log(d + 1).std())
    far = float((d > 50).mean())
    rg = rgb[..., 0] - rgb[..., 1]
    yb = 0.5 * (rgb[..., 0] + rgb[..., 1]) - rgb[..., 2]
    colour = float(np.hypot(rg.std(), yb.std()) + 0.3 * np.hypot(rg.mean(), yb.mean()))
    lum = np.clip(rgb, 0, 1).mean(axis=-1)
    e = np.abs(np.diff(lum, axis=1))[:-1] + np.abs(np.diff(lum, axis=0))[:, :-1]
    left = float(e[:, : int(0.4 * w)].mean())
    right = float(e[:, int(0.4 * w) :].mean())
    bottom = float(e[int(0.86 * h) :].mean())
    bright = float(lum.mean())
    return (
        -2.6 * abs(sky_frac - want_sky)
        - 7.0 * void
        - 5.0 * near
        - 1.2 * near2
        + 0.65 * variety
        + 0.5 * far
        + 1.4 * colour
        + 1.2 * (right - left)
        - 1.5 * bottom
        + 0.4 * min(bright, 0.5)
    )


def _foreground_block(world: World, x: int, y: int, z: int, yaw: float) -> float:
    """Share of the near view fan that rises to near eye level: treetops and ridges right in front of the lens."""
    nx, nz = world.top.shape
    hits = total = 0
    for off in (-40, -26, -13, 0, 13, 26, 40):
        a = math.radians(yaw + off)
        dx, dz = math.sin(a), -math.cos(a)
        for dist in (5, 9, 14, 20, 27, 35):
            ix, iz = int(x + dx * dist), int(z + dz * dist)
            if 0 <= ix < nx and 0 <= iz < nz:
                total += 1
                if world.top[ix, iz] >= y - 10:
                    hits += 1
    return hits / max(total, 1)


def _reach(world: World, x: float, z: float, yaw: float, limit: float = 700.0) -> float:
    """Distance along a view direction until the explored chunks end."""
    has = world.meta.get("has_chunk")
    if has is None:
        return limit
    nx, nz = has.shape
    best = limit
    for off in (-34, -17, 0, 17, 34):
        a = math.radians(yaw + off)
        dx, dz = math.sin(a), -math.cos(a)
        t = 0.0
        while t < limit:
            ix, iz = int(x + dx * t), int(z + dz * t)
            if ix < 0 or iz < 0 or ix >= nx or iz >= nz or not has[ix, iz]:
                best = min(best, t)
                break
            t += 8.0
    return best


def _overworld_candidates(world: World, cx: int, cz: int, rng: np.random.Generator, spread: int):
    nx, nz = world.top.shape
    pts = [(cx, cz)]
    has = world.meta.get("has_chunk")
    for _ in range(90):
        a = rng.random() * math.tau
        r = spread * math.sqrt(rng.random())
        x, z = int(cx + math.cos(a) * r), int(cz + math.sin(a) * r)
        if 8 <= x < nx - 8 and 8 <= z < nz - 8 and (has is None or has[x, z]):
            pts.append((x, z))
    return pts


def search_camera(world: World, cx: int, cz: int, *, spread: int = 90, seed: int = 1, tries: int = 26, log=None) -> Shot:
    """Pick the best camera near index coordinates (cx, cz)."""
    rng = np.random.default_rng(seed)
    mode = world.mode
    want_sky = {R.MODE_OVERWORLD: 0.40, R.MODE_NETHER: 0.0, R.MODE_END: 0.45}[mode]
    preset = {R.MODE_OVERWORLD: "day", R.MODE_NETHER: "nether", R.MODE_END: "end"}[mode]
    P = sky.params(preset, sun_az=30.0, fog_dist=0.0 if mode != R.MODE_NETHER else 200.0, mode=mode, shadows=False,
                   cloud_offset=(float(seed % 3000), 700.0))
    if mode == R.MODE_OVERWORLD:
        P[R.P_CLOUD] = 0.0
    pts = _overworld_candidates(world, cx, cz, rng, spread)[:tries]
    results = []
    ny = world.blocks.shape[1]
    t = world.tables
    for x, z in pts:
        if mode == R.MODE_NETHER:
            ys = _nether_openings(world, x, z)
        else:
            ground = int(world.top[x, z])
            if ground <= 0:
                continue
            ys = [ground + h for h in (7, 14, 26)]
        for y in ys:
            if y >= ny - 2 or world.blocks[x, y, z] != 0:
                continue
            for k in range(10):
                yaw = k * 36.0 + rng.random() * 8
                for pitch in (-5.0, 3.0) if mode != R.MODE_NETHER else (-8.0,):
                    cam = Camera((x + 0.5, y + 0.5, z + 0.5), yaw, pitch, FOV)
                    rgb, _, depth = render(world, cam, P, PW, PH, 1)
                    s = _score(rgb, depth, want_sky=want_sky)
                    # Prefer views that do not run off the explored area soon.
                    reach = _reach(world, x, z, yaw)
                    s += 0.9 * min(reach / 300.0, 1.0)
                    if mode != R.MODE_NETHER:
                        s -= 5.0 * _foreground_block(world, x, y, z, yaw)
                    results.append((s, x, y, z, yaw, pitch))
    if not results:
        raise RuntimeError("no open viewpoint found")
    results.sort(key=lambda r: -r[0])
    s, x, y, z, yaw, pitch = results[0]
    if log:
        log(f"  best of {len(results)} candidates: score {s:.2f}")
    if mode == R.MODE_OVERWORLD:
        return _overworld_shot(world, x, y, z, yaw, pitch, seed, log)
    reach = _reach(world, x, z, yaw)
    fog_base = float(np.clip(reach * 0.60, 70.0, 420.0))
    if log:
        log(f"  camera ({x + world.x0}, {y + world.y0}, {z + world.z0}) yaw {yaw:.0f} pitch {pitch:.0f}, reach {reach:.0f}")
    night_fog = fog_base * (1.1 if mode == R.MODE_NETHER else 2.0)
    return Shot((x + 0.5, y + 0.5, z + 0.5), yaw=yaw, pitch=pitch, fog=dict(night=night_fog), times=("night",),
                sun_az=dict(night=0.0), sun_el=dict(night=90.0))


def _overworld_shot(world: World, x: int, y: int, z: int, yaw: float, pitch: float, seed: int, log=None) -> Shot:
    reach = _reach(world, x, z, yaw)
    fog_base = float(np.clip(reach * 0.60, 70.0, 420.0))
    if log:
        log(f"  camera ({x + world.x0}, {y + world.y0}, {z + world.z0}) yaw {yaw:.0f} pitch {pitch:.0f}, "
            f"explored reach {reach:.0f}, fog {fog_base:.0f}")
    fog = dict(day=fog_base, dawn=fog_base * 0.85, dusk=fog_base * 0.85, night=fog_base * 0.75)
    # Keep the sun and moon inside the frame whatever the pitch.
    el = dict(day=pitch + 15.0, dawn=8.0, dusk=5.0, night=pitch + 15.0)
    el = {k: max(v, 5.0) for k, v in el.items()}
    return Shot((x + 0.5, y + 0.5, z + 0.5), yaw=yaw, pitch=pitch, fog=fog, sun_el=el,
                cloud_offset=(float(seed % 3000), 700.0))


def fixed_camera(world: World, x: int, y: int, z: int, yaw: float, pitch: float, seed: int = 1, log=None) -> Shot:
    return _overworld_shot(world, x, y, z, yaw, pitch, seed, log)


def _nether_openings(world: World, x: int, z: int) -> list[int]:
    """Air pockets above solid ground, low enough to see across the lava sea."""
    col = world.blocks[x, :, z]
    kinds = world.tables["kind"]
    out = []
    y = 26
    while y < min(world.blocks.shape[1] - 12, 110) and len(out) < 2:
        if kinds[col[y]] != 0 and all(col[y + k] == 0 for k in range(1, 8)):
            out.append(y + 6)
            y += 18
        y += 1
    return out
