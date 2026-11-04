"""OVERWORLD block lettering, built from voxels with our own renderer.

Two versions: one textured with original procedural pixel art that contains no Mojang pixels (safe to commit, in
assets/gen/wordmark/) and one with the real block textures (assets/renders/wordmark.png, gitignored).
"""
from __future__ import annotations

import numpy as np

from . import render as R
from . import sky
from .blocks import Registry
from .paths import GEN_WORDMARK, RENDERS
from .world import Camera, World, post, render, save_png

# Our own 5x7 block font, drawn for this wordmark.
GLYPHS = {
    "O": ["#####", "#####", "##.##", "##.##", "##.##", "#####", "#####"],
    "V": ["##.##", "##.##", "##.##", "##.##", "#####", ".###.", "..#.."],
    "E": ["#####", "#####", "##...", "####.", "##...", "#####", "#####"],
    "R": ["####.", "#####", "##.##", "#####", "####.", "##.##", "##.##"],
    "W": ["##...##", "##...##", "##.#.##", "##.#.##", "#######", "###.###", "##...##"],
    "L": ["##...", "##...", "##...", "##...", "##...", "#####", "#####"],
    "D": ["####.", "#####", "##.##", "##.##", "##.##", "#####", "####."],
}


def _noise_tex(palette, seed, bias=None) -> np.ndarray:
    """A 16x16 tile: clustered noise mapped onto a small palette, the way pixel artists shade stone."""
    rng = np.random.default_rng(seed)
    base = rng.random((16, 16))
    smooth = (base + np.roll(base, 1, 0) + np.roll(base, 1, 1) + np.roll(base, -1, 0) + np.roll(base, -1, 1)) / 5
    v = (smooth - smooth.min()) / (np.ptp(smooth) + 1e-6)
    if bias is not None:
        v = np.clip(v + bias, 0, 1)
    idx = np.minimum((v * len(palette)).astype(int), len(palette) - 1)
    pal = np.asarray(palette, dtype=np.uint8)
    rgb = pal[idx]
    a = np.full((16, 16, 1), 255, dtype=np.uint8)
    return np.concatenate([rgb, a], axis=-1)


def own_textures() -> dict[str, np.ndarray]:
    """Original pixel art for the committed wordmark."""
    stone = _noise_tex([(92, 94, 98), (112, 114, 118), (128, 130, 134), (146, 148, 152), (160, 162, 166)], 11)
    dirt = _noise_tex([(90, 62, 42), (110, 76, 52), (128, 90, 62), (146, 104, 72)], 12)
    grass_top = _noise_tex([(70, 118, 44), (86, 138, 52), (102, 156, 60), (120, 172, 70)], 13)
    side = dirt.copy()
    rng = np.random.default_rng(14)
    grass_px = _noise_tex([(70, 118, 44), (86, 138, 52), (102, 156, 60)], 15)
    for x in range(16):
        d = 3 + int(rng.integers(0, 4))
        side[:d, x] = grass_px[:d, x]
    # Chiselled edge on stone so individual blocks read at wordmark size.
    for i in range(16):
        stone[0, i, :3] = np.minimum(stone[0, i, :3].astype(int) + 26, 255).astype(np.uint8)
        stone[i, 0, :3] = np.minimum(stone[i, 0, :3].astype(int) + 18, 255).astype(np.uint8)
        stone[15, i, :3] = (stone[15, i, :3] * 0.6).astype(np.uint8)
        stone[i, 15, :3] = (stone[i, 15, :3] * 0.7).astype(np.uint8)
    return {"gen/stone": stone, "gen/dirt": dirt, "gen/grass_top": grass_top, "gen/grass_side": side}


def build(reg: Registry, stone, grass, dirt, depth=3) -> World:
    word = "OVERWORLD"
    pad = 3
    gap = 2
    width = sum(len(GLYPHS[ch][0]) for ch in word) + (len(word) - 1) * gap + pad * 2
    h = 7
    nx, ny, nz = width, h + pad * 2, depth + pad * 2
    b = np.zeros((nx, ny, nz), dtype=np.uint16)
    x = pad
    for ch in word:
        rows = GLYPHS[ch]
        w = len(rows[0])
        for ry, row in enumerate(rows):
            y = pad + h - 1 - ry
            for rx, cell in enumerate(row):
                if cell == "#":
                    for z in range(pad, pad + depth):
                        b[x + rx, y, z] = stone
        x += w + gap
    # Grass caps the highest block of each column, so every letter is a small piece of terrain.
    for xx in range(nx):
        for zz in range(pad, pad + depth):
            col = b[xx, :, zz]
            for y in range(ny - 2, 0, -1):
                if col[y] == stone:
                    b[xx, y, zz] = grass
                    break
    tint = np.zeros((nx, nz, 3), dtype=np.uint8)
    tint[...] = (124, 189, 107)
    return World(b, reg, tint.copy(), tint.copy(), tint.copy(), meta=dict(width=width, h=h, pad=pad, depth=depth)).finish()


def _render_word(world: World, out, width: int, height: int, ss: int) -> None:
    m = world.meta
    nx, ny, nz = world.blocks.shape
    cx = nx / 2
    # From above, like the top of a hill, so the grass caps and the depth of the letters show.
    dist = m["width"] * 0.72
    drop = 13.0
    cam = Camera((cx, ny / 2 + dist * np.tan(np.radians(drop)), nz / 2 + dist), yaw=0.0, pitch=-drop, fov=30.0)
    P = sky.params("day", sun_az=200.0, sun_el=55.0, key_az=205.0, key_el=55.0, fog_dist=0.0, transparent=True)
    P[R.P_CLOUD] = 0.0
    rgb, alpha, _ = render(world, cam, P, width, height, ss)
    u8 = post(rgb, bloom=0.0, calm=False, saturation=1.05)
    # Trim transparent margin.
    ys, xs = np.nonzero(alpha > 0.01)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # Un-premultiply antialiased edges: rgb was averaged with transparent black.
    a = alpha[..., None]
    un = np.where(a > 0.01, u8.astype(np.float32) / np.maximum(a, 0.01), 0)
    u8 = np.clip(un, 0, 255).astype(np.uint8)
    save_png(u8[y0:y1, x0:x1], out, alpha[y0:y1, x0:x1])


def render_all(log=print) -> list:
    outs = []
    # Committed: only our generated pixel art reaches the image.
    reg = Registry(extra_textures=own_textures())
    st = reg.add_box_block("wm_stone", {"all": "gen/stone"})
    gr = reg.add_box_block("wm_grass", {"up": "gen/grass_top", "down": "gen/dirt", "north": "gen/grass_side",
                                        "south": "gen/grass_side", "west": "gen/grass_side", "east": "gen/grass_side"})
    di = reg.add_box_block("wm_dirt", {"all": "gen/dirt"})
    world = build(reg, st, gr, di)
    # This image is committed, so prove it draws only with the generated textures.
    allowed = {reg.tex_ids[name] for name in own_textures()}
    if not set(reg.qtex) <= allowed:
        raise RuntimeError("committed wordmark would use a Mojang texture")
    GEN_WORDMARK.mkdir(parents=True, exist_ok=True)
    for name, w, h in (("overworld.png", 1600, 520), ("overworld-small.png", 800, 260)):
        p = GEN_WORDMARK / name
        _render_word(world, p, w, h, 3)
        outs.append(p)
    # Local version with the real textures.
    reg2 = Registry()
    world2 = build(reg2, reg2.id("stone"), reg2.id("grass_block", snowy="false"), reg2.id("dirt"))
    p = RENDERS / "wordmark.png"
    _render_word(world2, p, 1600, 520, 3)
    outs.append(p)
    log("wordmark: " + ", ".join(str(o) for o in outs))
    return outs
