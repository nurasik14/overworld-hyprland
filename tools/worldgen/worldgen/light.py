"""Minecraft-style light propagation: per-voxel sky light and block light in 0..15, flood filled with falloff 1."""
from __future__ import annotations

import numpy as np
from numba import njit, prange

_DX = np.array([1, -1, 0, 0, 0, 0], dtype=np.int32)
_DY = np.array([0, 0, 1, -1, 0, 0], dtype=np.int32)
_DZ = np.array([0, 0, 0, 0, 1, -1], dtype=np.int32)


@njit(parallel=True)
def column_tops(blocks, kind):
    nx, ny, nz = blocks.shape
    top = np.full((nx, nz), -1, dtype=np.int16)
    for x in prange(nx):
        for z in range(nz):
            for y in range(ny - 1, -1, -1):
                s = blocks[x, y, z]
                if s != 0 and kind[s] != 0:
                    top[x, z] = y
                    break
    return top


@njit(parallel=True)
def _init_sky(blocks, opacity, sky, top):
    nx, ny, nz = blocks.shape
    for x in prange(nx):
        for z in range(nz):
            level = 15
            t = top[x, z]
            for y in range(ny - 1, -1, -1):
                if y > t:
                    sky[x, y, z] = 15
                    continue
                o = opacity[blocks[x, y, z]]
                if o >= 15:
                    break
                if o > 0:
                    level -= o
                    if level <= 0:
                        break
                sky[x, y, z] = level


@njit
def _flood(light, blocks, opacity, heads_v, heads_n, head, count):
    nx, ny, nz = blocks.shape
    nz_ny = ny * nz
    for level in range(15, 1, -1):
        while head[level] >= 0:
            n = head[level]
            head[level] = heads_n[n]
            v = heads_v[n]
            if light[v // nz_ny, (v // nz) % ny, v % nz] != level:
                continue  # stale entry: this voxel was raised after being queued
            x = v // nz_ny
            y = (v // nz) % ny
            z = v % nz
            for d in range(6):
                ax = x + _DX[d]
                ay = y + _DY[d]
                az = z + _DZ[d]
                if ax < 0 or ax >= nx or ay < 0 or ay >= ny or az < 0 or az >= nz:
                    continue
                o = opacity[blocks[ax, ay, az]]
                if o >= 15:
                    continue
                nl = level - (o if o > 1 else 1)
                if nl <= 0 or light[ax, ay, az] >= nl:
                    continue
                light[ax, ay, az] = nl
                if nl > 1:
                    if count >= heads_v.shape[0]:
                        grow = max(heads_v.shape[0] * 2, 1024)
                        nv = np.empty(grow, dtype=np.int32)
                        nn = np.empty(grow, dtype=np.int32)
                        nv[:count] = heads_v[:count]
                        nn[:count] = heads_n[:count]
                        heads_v = nv
                        heads_n = nn
                    heads_v[count] = (ax * ny + ay) * nz + az
                    heads_n[count] = head[nl]
                    head[nl] = count
                    count += 1


@njit
def _sky_seeds(blocks, opacity, sky, top):
    """Queue lit voxels next to a darker non-opaque neighbour. Only columns with a taller neighbour can have any."""
    nx, ny, nz = blocks.shape
    cap = 1 << 20
    heads_v = np.empty(cap, dtype=np.int32)
    heads_n = np.empty(cap, dtype=np.int32)
    head = np.full(16, -1, dtype=np.int32)
    count = 0
    for x in range(nx):
        for z in range(nz):
            hi = int(top[x, z])
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ax, az = x + dx, z + dz
                if 0 <= ax < nx and 0 <= az < nz and top[ax, az] > hi:
                    hi = int(top[ax, az])
            hi = min(hi + 1, ny - 1)
            for y in range(hi, -1, -1):
                level = sky[x, y, z]
                if level < 2:
                    if opacity[blocks[x, y, z]] >= 15:
                        break
                    continue
                darker = False
                for d in range(6):
                    ax = x + _DX[d]
                    ay = y + _DY[d]
                    az = z + _DZ[d]
                    if ax < 0 or ax >= nx or ay < 0 or ay >= ny or az < 0 or az >= nz:
                        continue
                    if sky[ax, ay, az] < level - 1 and opacity[blocks[ax, ay, az]] < 15:
                        darker = True
                        break
                if darker:
                    if count >= heads_v.shape[0]:
                        grow = heads_v.shape[0] * 2
                        nv = np.empty(grow, dtype=np.int32)
                        nn = np.empty(grow, dtype=np.int32)
                        nv[:count] = heads_v[:count]
                        nn[:count] = heads_n[:count]
                        heads_v = nv
                        heads_n = nn
                    heads_v[count] = (x * ny + y) * nz + z
                    heads_n[count] = head[level]
                    head[level] = count
                    count += 1
    return heads_v, heads_n, head, count


@njit
def _block_seeds(blocks, emission, blk):
    nx, ny, nz = blocks.shape
    cap = 1 << 16
    heads_v = np.empty(cap, dtype=np.int32)
    heads_n = np.empty(cap, dtype=np.int32)
    head = np.full(16, -1, dtype=np.int32)
    count = 0
    for x in range(nx):
        for y in range(ny):
            for z in range(nz):
                e = emission[blocks[x, y, z]]
                if e > 0:
                    blk[x, y, z] = e
                    if e > 1:
                        if count >= heads_v.shape[0]:
                            grow = heads_v.shape[0] * 2
                            nv = np.empty(grow, dtype=np.int32)
                            nn = np.empty(grow, dtype=np.int32)
                            nv[:count] = heads_v[:count]
                            nn[:count] = heads_n[:count]
                            heads_v = nv
                            heads_n = nn
                        heads_v[count] = (x * ny + y) * nz + z
                        heads_n[count] = head[e]
                        head[e] = count
                        count += 1
    return heads_v, heads_n, head, count


def compute_light(blocks: np.ndarray, opacity: np.ndarray, emission: np.ndarray, top: np.ndarray,
                  has_sky: bool = True) -> tuple[np.ndarray, np.ndarray]:
    sky = np.zeros(blocks.shape, dtype=np.uint8)
    blk = np.zeros(blocks.shape, dtype=np.uint8)
    if has_sky:
        _init_sky(blocks, opacity, sky, top)
        _flood(sky, blocks, opacity, *_sky_seeds(blocks, opacity, sky, top))
    if emission.any():
        # Emitters are not blocked by their own opacity: lava is opaque yet lights its neighbours.
        _flood(blk, blocks, opacity, *_block_seeds(blocks, emission, blk))
    return sky, blk
