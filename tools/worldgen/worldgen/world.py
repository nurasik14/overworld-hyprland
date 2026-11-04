"""World container, camera maths, biome tints and the render + post-processing front end."""
from __future__ import annotations

import math
import os
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from . import render as R
from .blocks import Registry
from .light import column_tops, compute_light
from .paths import MC_DIR


def set_threads(n: int = 8) -> None:
    import numba

    numba.set_num_threads(min(n, numba.config.NUMBA_NUM_THREADS))


def _colormap(name: str) -> np.ndarray:
    return np.asarray(Image.open(MC_DIR / "textures" / "colormap" / f"{name}.png").convert("RGB"), dtype=np.uint8)


def climate_tint(temp: np.ndarray, down: np.ndarray, which: str) -> np.ndarray:
    """The game's colormap lookup: x = (1 - temp) * 255, y = (1 - down * temp) * 255."""
    cm = _colormap(which)
    t = np.clip(temp, 0, 1)
    d = np.clip(down, 0, 1) * t
    x = ((1 - t) * 255).astype(np.int32)
    y = ((1 - d) * 255).astype(np.int32)
    return cm[y, x]


def blur_tint(t: np.ndarray, radius: int = 3) -> np.ndarray:
    """Biome blend: box blur over a tint map. Done in integer images so it stays fast on 800x800 maps."""
    img = Image.fromarray(t.astype(np.uint8), "RGB").filter(ImageFilter.BoxBlur(radius))
    return np.asarray(img, dtype=np.uint8).copy()


@dataclass
class World:
    blocks: np.ndarray                  # uint16 [x, y, z]
    reg: Registry
    tint_grass: np.ndarray              # uint8 [x, z, 3]
    tint_foliage: np.ndarray
    tint_water: np.ndarray
    y0: int = 0                         # real Minecraft Y of index 0
    x0: int = 0                         # real Minecraft X of index 0
    z0: int = 0
    mode: int = R.MODE_OVERWORLD
    meta: dict = field(default_factory=dict)
    tables: dict | None = None
    top: np.ndarray | None = None
    sky: np.ndarray | None = None
    blk: np.ndarray | None = None

    def finish(self) -> "World":
        """Compile tables and compute column tops + light. Call after the last block is placed."""
        self.tables = self.reg.tables()
        t = self.tables
        self.top = column_tops(self.blocks, t["kind"])
        self.sky, self.blk = compute_light(self.blocks, t["opacity"], t["emission"], self.top,
                                           has_sky=self.mode == R.MODE_OVERWORLD)
        return self

    def surface_y(self, x: int, z: int) -> int:
        return int(self.top[min(max(x, 0), self.top.shape[0] - 1), min(max(z, 0), self.top.shape[1] - 1)])


@dataclass
class Camera:
    pos: tuple[float, float, float]
    yaw: float            # degrees, clockwise from north (-Z); 0 looks north, 90 east, 180 south, 270 west
    pitch: float = 0.0    # degrees, up is positive
    fov: float = 62.0     # vertical degrees
    projection: int = 0   # 0 perspective, 1 cylinder

    def vector(self, width: int, height: int) -> np.ndarray:
        yaw, pitch = math.radians(self.yaw), math.radians(self.pitch)
        f = np.array([math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)])
        if abs(f[1]) > 0.999:
            right = np.array([math.cos(yaw), 0.0, math.sin(yaw)])
        else:
            right = np.cross(f, [0.0, 1.0, 0.0])
            right /= np.linalg.norm(right)
        up = np.cross(right, f)
        tv = math.tan(math.radians(self.fov) / 2)
        th = tv * width / height
        return np.array([*self.pos, *right, *up, *f, th, tv, self.projection], dtype=np.float64)


_SPRITES: dict[str, np.ndarray] = {}


def _float_sprite(rel: str) -> np.ndarray:
    if rel not in _SPRITES:
        _SPRITES[rel] = np.asarray(Image.open(MC_DIR / "textures" / rel).convert("RGBA"), dtype=np.float32) / 255.0
    return _SPRITES[rel]


def _clouds() -> np.ndarray:
    img = Image.open(MC_DIR / "textures" / "environment" / "clouds.png").convert("RGBA")
    a = np.asarray(img, dtype=np.uint8)
    return (a[..., 3] > 128).astype(np.uint8)


def make_ctx(world: World, P: np.ndarray, moon: str = "full_moon") -> R.Ctx:
    t = world.tables
    return R.Ctx(
        blocks=world.blocks, sky=world.sky, blk=world.blk, top=world.top,
        tg=world.tint_grass, tf=world.tint_foliage, tw=world.tint_water,
        kind=t["kind"], flags=t["flags"], selflit=t["selflit"], cube_q=t["cube_q"], cube_o=t["cube_o"],
        mq_start=t["mq_start"], mq_count=t["mq_count"], quads=t["quads"], qtex=t["qtex"], qtint=t["qtint"],
        fixed=t["fixed_tints"], atlas=t["atlas"],
        clouds=_clouds(),
        sunspr=_float_sprite("environment/celestial/sun.png"),
        moonspr=_float_sprite(f"environment/celestial/moon/{moon}.png"),
        endsky=_float_sprite("environment/end_sky.png"),
        P=P,
    )


def render(world: World, cam: Camera, P: np.ndarray, width: int = 1920, height: int = 1080, ss: int = 2,
           moon: str = "full_moon") -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Render to float arrays: rgb [h, w, 3] in display space, alpha [h, w], depth [h, w] (-1 sky, -2 void)."""
    out = np.zeros((height, width, 3), dtype=np.float32)
    depth = np.zeros((height, width), dtype=np.float32)
    alpha = np.zeros((height, width), dtype=np.float32)
    P = P.copy()
    P[R.P_TOPMAX] = max(int(world.top.max()), 0)
    R.render_image(make_ctx(world, P, moon), cam.vector(width, height), width, height, ss, out, depth, alpha)
    return out, alpha, depth


def _to_u8(a: np.ndarray) -> np.ndarray:
    return np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)


def _shoulder(rgb: np.ndarray) -> np.ndarray:
    """Soft clip above 0.8 so bright sun-lit tops and bloom roll off instead of hard clipping."""
    x = np.maximum(rgb - 0.8, 0.0)
    return np.minimum(rgb, 0.8) + x / (1.0 + x * 2.5)


def post(rgb: np.ndarray, *, bloom: float = 0.22, calm: bool = True, saturation: float = 1.05,
         grade: tuple[float, float, float] = (1.0, 1.0, 1.0), blur: float = 0.0, seed: int = 7) -> np.ndarray:
    """Bloom, gentle grade, the calm zones for the desktop HUD, and a little dither against sky banding."""
    h, w = rgb.shape[:2]
    a = rgb.astype(np.float32).copy()
    if bloom > 0:
        bright = np.maximum(a - 0.95, 0.0)
        if bright.max() > 0:
            small = _to_u8(np.minimum(bright * 1.6, 1.0))
            img = Image.fromarray(small, "RGB").resize((w // 2, h // 2), Image.BILINEAR)
            wide = np.asarray(img.filter(ImageFilter.GaussianBlur(14)), dtype=np.float32) / 255.0
            tight = np.asarray(img.filter(ImageFilter.GaussianBlur(4)), dtype=np.float32) / 255.0
            glow = (wide + tight) * 0.5
            glow = np.asarray(Image.fromarray(_to_u8(glow), "RGB").resize((w, h), Image.BILINEAR),
                              dtype=np.float32) / 255.0
            a += glow * bloom * 2.0
    a = _shoulder(a)
    if saturation != 1.0:
        lum = (a * [0.299, 0.587, 0.114]).sum(axis=-1, keepdims=True)
        a = lum + (a - lum) * saturation
    a *= np.asarray(grade, dtype=np.float32)
    a = np.clip(a, 0, 1)
    if calm and h >= 1000:
        a = _calm_zones(a)
    if blur > 0:
        a = np.asarray(Image.fromarray(_to_u8(a), "RGB").filter(ImageFilter.GaussianBlur(blur)),
                       dtype=np.float32) / 255.0
    rng = np.random.default_rng(seed)
    a = a + (rng.random(a.shape[:2] + (1,), dtype=np.float32) - 0.5) * (1.0 / 255.0)
    return _to_u8(a)


def _calm_zones(a: np.ndarray) -> np.ndarray:
    """Keep the HUD strip (bottom ~90 px) and the widget side (left 40 %) quieter.

    A depth-of-field-like soft blur plus a slight darkening, feathered so no edge is visible. The world still
    reads through; the voxels simply stop competing with text and icons.
    """
    h, w = a.shape[:2]
    soft = np.asarray(Image.fromarray(_to_u8(a), "RGB").filter(ImageFilter.GaussianBlur(2.2)),
                      dtype=np.float32) / 255.0
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    xx = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    band = 90 / h
    bottom = np.clip((yy - (1 - band * 1.8)) / (band * 0.9), 0, 1)
    bottom = bottom * bottom * (3 - 2 * bottom)
    left = np.clip((0.40 - xx) / 0.22, 0, 1)
    left = left * left * (3 - 2 * left)
    blur_mask = np.maximum(bottom, left * 0.45)[..., None]
    out = a + (soft - a) * blur_mask
    dark = (1 - 0.14 * bottom)[..., None]
    return out * dark


def save_png(u8: np.ndarray, path: str | os.PathLike, alpha: np.ndarray | None = None) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    if alpha is not None:
        img = Image.fromarray(np.dstack([u8, _to_u8(alpha)]), "RGBA")
    else:
        img = Image.fromarray(u8, "RGB")
    img.save(path, compress_level=6)
