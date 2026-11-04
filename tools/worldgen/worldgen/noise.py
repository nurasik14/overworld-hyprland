"""Gradient noise compiled with numba. Output is float32 grids, roughly in [-1, 1]."""
from __future__ import annotations

import numpy as np
from numba import njit, prange

_GRAD2 = np.array(
    [[1, 1], [-1, 1], [1, -1], [-1, -1], [1.414, 0], [-1.414, 0], [0, 1.414], [0, -1.414]],
    dtype=np.float32,
)
_GRAD3 = np.array(
    [[1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0], [1, 0, 1], [-1, 0, 1], [1, 0, -1], [-1, 0, -1],
     [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1], [1, 1, 0], [0, -1, 1], [-1, 1, 0], [0, -1, -1]],
    dtype=np.float32,
)


def perm_table(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed & 0xFFFFFFFF)
    p = rng.permutation(256).astype(np.int32)
    return np.concatenate([p, p, p[:2]])


@njit(fastmath=True, inline="always")
def _fade(t):
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


@njit(fastmath=True)
def perlin2(x, z, perm, grad):
    fx = np.floor(x)
    fz = np.floor(z)
    ix = int(fx) & 255
    iz = int(fz) & 255
    dx = x - fx
    dz = z - fz
    u = _fade(dx)
    v = _fade(dz)
    a = perm[ix] + iz
    b = perm[ix + 1] + iz
    g00 = grad[perm[a] & 7]
    g01 = grad[perm[a + 1] & 7]
    g10 = grad[perm[b] & 7]
    g11 = grad[perm[b + 1] & 7]
    n00 = g00[0] * dx + g00[1] * dz
    n10 = g10[0] * (dx - 1) + g10[1] * dz
    n01 = g01[0] * dx + g01[1] * (dz - 1)
    n11 = g11[0] * (dx - 1) + g11[1] * (dz - 1)
    l0 = n00 + u * (n10 - n00)
    l1 = n01 + u * (n11 - n01)
    return (l0 + v * (l1 - l0)) * 0.72


@njit(fastmath=True)
def perlin3(x, y, z, perm, grad):
    fx = np.floor(x)
    fy = np.floor(y)
    fz = np.floor(z)
    ix = int(fx) & 255
    iy = int(fy) & 255
    iz = int(fz) & 255
    dx = x - fx
    dy = y - fy
    dz = z - fz
    u = _fade(dx)
    v = _fade(dy)
    w = _fade(dz)
    a = perm[ix] + iy
    aa = perm[a] + iz
    ab = perm[a + 1] + iz
    b = perm[ix + 1] + iy
    ba = perm[b] + iz
    bb = perm[b + 1] + iz

    g = grad[perm[aa] & 15]
    n000 = g[0] * dx + g[1] * dy + g[2] * dz
    g = grad[perm[ba] & 15]
    n100 = g[0] * (dx - 1) + g[1] * dy + g[2] * dz
    g = grad[perm[ab] & 15]
    n010 = g[0] * dx + g[1] * (dy - 1) + g[2] * dz
    g = grad[perm[bb] & 15]
    n110 = g[0] * (dx - 1) + g[1] * (dy - 1) + g[2] * dz
    g = grad[perm[aa + 1] & 15]
    n001 = g[0] * dx + g[1] * dy + g[2] * (dz - 1)
    g = grad[perm[ba + 1] & 15]
    n101 = g[0] * (dx - 1) + g[1] * dy + g[2] * (dz - 1)
    g = grad[perm[ab + 1] & 15]
    n011 = g[0] * dx + g[1] * (dy - 1) + g[2] * (dz - 1)
    g = grad[perm[bb + 1] & 15]
    n111 = g[0] * (dx - 1) + g[1] * (dy - 1) + g[2] * (dz - 1)
    x0 = n000 + u * (n100 - n000)
    x1 = n010 + u * (n110 - n010)
    x2 = n001 + u * (n101 - n001)
    x3 = n011 + u * (n111 - n011)
    y0 = x0 + v * (x1 - x0)
    y1 = x2 + v * (x3 - x2)
    return y0 + w * (y1 - y0)


@njit(parallel=True, fastmath=True)
def _fbm2_grid(nx, nz, ox, oz, scale, octaves, lac, gain, perm, grad):
    out = np.empty((nx, nz), dtype=np.float32)
    for i in prange(nx):
        for j in range(nz):
            x = (i + ox) / scale
            z = (j + oz) / scale
            amp = 1.0
            total = 0.0
            norm = 0.0
            for o in range(octaves):
                total += amp * perlin2(x + o * 17.3, z - o * 9.7, perm, grad)
                norm += amp
                amp *= gain
                x *= lac
                z *= lac
            out[i, j] = total / norm * 1.6
    return out


def fbm2(nx: int, nz: int, scale: float, seed: int, octaves: int = 4, lac: float = 2.0, gain: float = 0.5,
         ox: float = 0.0, oz: float = 0.0) -> np.ndarray:
    return _fbm2_grid(nx, nz, float(ox), float(oz), float(scale), int(octaves), float(lac), float(gain),
                      perm_table(seed), _GRAD2)


@njit(parallel=True, fastmath=True)
def _sample3_columns(xs, zs, y0, ny, sx, sy, sz, octaves, perm, grad):
    n = xs.shape[0]
    out = np.empty((n, ny), dtype=np.float32)
    for c in prange(n):
        for k in range(ny):
            x = xs[c] / sx
            y = (y0 + k) / sy
            z = zs[c] / sz
            amp = 1.0
            total = 0.0
            for o in range(octaves):
                total += amp * perlin3(x, y, z, perm, grad)
                amp *= 0.5
                x *= 2.0
                y *= 2.0
                z *= 2.0
            out[c, k] = total
    return out


def noise3_columns(xs: np.ndarray, zs: np.ndarray, y0: int, ny: int, sx: float, sy: float, sz: float, seed: int,
                   octaves: int = 2) -> np.ndarray:
    """3D fractal noise sampled for selected columns only: ``out[column, y - y0]``."""
    return _sample3_columns(xs.astype(np.float64), zs.astype(np.float64), int(y0), int(ny), float(sx), float(sy),
                            float(sz), int(octaves), perm_table(seed), _GRAD3)
