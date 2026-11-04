"""The voxel ray marcher (numba). Amanatides-Woo grid traversal, so there are no meshes, seams or z-fighting.

Shading follows the game's look: per-face diffuse (top 1.0, N/S 0.8, E/W 0.6, bottom 0.5), smooth lighting and
ambient occlusion interpolated between voxel corners, biome tints, cutouts through alpha testing. On top of it
sit the "shaders-lite" extras: sun shadows, water reflection + Fresnel + absorption, distance fog, bloom (post).
"""
from __future__ import annotations

from collections import namedtuple

import numpy as np
from numba import njit, prange

# Indices into the parameter vector P (see sky.py).
P_SUN, P_SUNSTR, P_MOON, P_MOONSTR = 0, 3, 4, 7
P_ZEN, P_HOR, P_GLOW, P_GLOWSTR = 8, 11, 14, 17
P_AMB, P_DIR, P_LDIR, P_BLK, P_MIN = 18, 21, 24, 27, 30
P_FOGD, P_FOGP, P_STARS = 33, 34, 35
P_CLOUD, P_CLOUDY, P_COX, P_COZ, P_CTOP = 36, 37, 38, 39, 40
P_MODE, P_WABS, P_SHADOWS, P_AO, P_REFL, P_ALPHA, P_TOPMAX = 43, 44, 45, 46, 47, 48, 49
P_SUNU, P_SUNV, P_MOONU, P_MOONV = 50, 53, 56, 59
P_SUNSZ, P_MOONSZ, P_SOFT, P_SELFGLOW = 62, 63, 64, 65
P_SUNF, P_SUNC, P_MOONF, P_MOONC = 66, 69, 71, 74
P_COUNT = 76

MODE_OVERWORLD, MODE_NETHER, MODE_END = 0, 1, 2
P_END_TINT_R, P_END_TINT_G, P_END_TINT_B = 0.015, 0.008, 0.035

EV_NONE, EV_CUBE, EV_QUAD, EV_WATER = 0, 1, 2, 3
K_AIR, K_CUBE, K_MODEL, K_WATER, K_LAVA = 0, 1, 2, 3, 4
F_OPAQUE, F_WATERLOGGED, F_RANDROT, F_NOSHADOW, F_TRANSLUCENT, F_CULLSAME, F_LEAVES = 1, 2, 4, 8, 16, 32, 64
FLUID_H = 0.889

Ctx = namedtuple(
    "Ctx",
    "blocks sky blk top tg tf tw kind flags selflit cube_q cube_o mq_start mq_count quads qtex qtint fixed atlas "
    "clouds sunspr moonspr endsky P",
)

_FN = np.array([[0, -1, 0], [0, 1, 0], [0, 0, -1], [0, 0, 1], [-1, 0, 0], [1, 0, 0]], dtype=np.int32)


@njit(fastmath=True, inline="always")
def _hash3(x, y, z):
    h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
    h ^= (h >> 13)
    h = (h * 1274126177) & 0x7FFFFFFF
    h ^= (h >> 16)
    return h


@njit(fastmath=True, error_model="numpy")
def _alpha_at(c, q, lx, ly, lz, lod):
    Q = c.quads
    rx = lx - Q[q, 0]
    ry = ly - Q[q, 1]
    rz = lz - Q[q, 2]
    a = rx * Q[q, 3] + ry * Q[q, 4] + rz * Q[q, 5]
    b = rx * Q[q, 6] + ry * Q[q, 7] + rz * Q[q, 8]
    u = Q[q, 12] + a * Q[q, 14] + b * Q[q, 16]
    v = Q[q, 13] + a * Q[q, 15] + b * Q[q, 17]
    size = 16 >> lod
    ui = int(np.floor(u * size)) & (size - 1)
    vi = int(np.floor(v * size)) & (size - 1)
    return c.atlas[c.qtex[q], lod, vi, ui, 3]


@njit(fastmath=True, error_model="numpy", inline="always")
def _lod_of(fp):
    if fp < 1.5:
        return 0
    if fp < 3.0:
        return 1
    if fp < 6.0:
        return 2
    if fp < 12.0:
        return 3
    return 4


@njit(fastmath=True, error_model="numpy")
def _is_watery(c, s):
    return c.kind[s] == K_WATER or (c.flags[s] & F_WATERLOGGED) != 0


@njit(fastmath=True, error_model="numpy")
def march(c, ox, oy, oz, dx, dy, dz, t0, tlimit, in_water, lodk):
    """Walk the grid from t0 until something visible. Returns (event, x, y, z, face, quad, t)."""
    nx, ny, nz = c.blocks.shape
    tmin = t0
    tmax = tlimit
    if abs(dx) < 1e-9:
        if ox < 0.0 or ox > nx:
            return EV_NONE, 0, 0, 0, 0, -1, tlimit
        dx = 1e-9
    a = (0.0 - ox) / dx
    b = (nx - ox) / dx
    if a > b:
        a, b = b, a
    tmin = max(tmin, a)
    tmax = min(tmax, b)
    if abs(dy) < 1e-9:
        dy = 1e-9
    a = (0.0 - oy) / dy
    b = (ny - oy) / dy
    if a > b:
        a, b = b, a
    tmin = max(tmin, a)
    tmax = min(tmax, b)
    if abs(dz) < 1e-9:
        if oz < 0.0 or oz > nz:
            return EV_NONE, 0, 0, 0, 0, -1, tlimit
        dz = 1e-9
    a = (0.0 - oz) / dz
    b = (nz - oz) / dz
    if a > b:
        a, b = b, a
    tmin = max(tmin, a)
    tmax = min(tmax, b)
    if tmin >= tmax:
        return EV_NONE, 0, 0, 0, 0, -1, tlimit

    tb = tmin + 1e-5
    x = int(np.floor(ox + dx * tb))
    y = int(np.floor(oy + dy * tb))
    z = int(np.floor(oz + dz * tb))
    x = min(max(x, 0), nx - 1)
    y = min(max(y, 0), ny - 1)
    z = min(max(z, 0), nz - 1)
    sx = 1 if dx > 0 else -1
    sy = 1 if dy > 0 else -1
    sz = 1 if dz > 0 else -1
    tdx = abs(1.0 / dx)
    tdy = abs(1.0 / dy)
    tdz = abs(1.0 / dz)
    tnx = ((x + 1 if dx > 0 else x) - ox) / dx
    tny = ((y + 1 if dy > 0 else y) - oy) / dy
    tnz = ((z + 1 if dz > 0 else z) - oz) / dz
    t_enter = tmin
    axis = -1
    prev = 0
    topmax = int(c.P[P_TOPMAX])
    lox = ox - x
    loy = oy - y
    loz = oz - z

    while True:
        if tnx < tny:
            if tnx < tnz:
                t_exit, nxt = tnx, 0
            else:
                t_exit, nxt = tnz, 2
        else:
            if tny < tnz:
                t_exit, nxt = tny, 1
            else:
                t_exit, nxt = tnz, 2
        s = 0
        if y <= c.top[x, z]:
            s = c.blocks[x, y, z]
        if s != 0:
            k = c.kind[s]
            f = c.flags[s]
            watery = k == K_WATER or (f & F_WATERLOGGED) != 0
            if in_water and not watery:
                in_water = False
            if watery and not in_water:
                # Water starts here: find the surface crossing.
                h = 1.0
                if y + 1 < ny:
                    above = c.blocks[x, y + 1, z]
                    if not _is_watery(c, above):
                        h = FLUID_H
                ytop = y + h
                entry_y = oy + dy * t_enter
                if entry_y >= ytop - 1e-6:
                    if dy < 0.0:
                        tp = (ytop - oy) / dy
                        if tp < t_exit:
                            return EV_WATER, x, y, z, 1, -1, max(tp, t_enter)
                elif axis >= 0 and k == K_WATER:
                    face = 0
                    if axis == 0:
                        face = 4 if sx > 0 else 5
                    elif axis == 1:
                        face = 0 if sy > 0 else 1
                    else:
                        face = 2 if sz > 0 else 3
                    return EV_WATER, x, y, z, face, -1, t_enter
            if k == K_CUBE:
                if axis >= 0 and not ((f & F_CULLSAME) != 0 and prev == s):
                    if axis == 0:
                        face = 4 if sx > 0 else 5
                    elif axis == 1:
                        face = 0 if sy > 0 else 1
                    else:
                        face = 2 if sz > 0 else 3
                    if (f & F_OPAQUE) != 0:
                        return EV_CUBE, x, y, z, face, -1, t_enter
                    q = c.cube_q[s, face]
                    lod = _lod_of(t_enter * lodk)
                    al = _alpha_at(c, q, ox + dx * t_enter - x, oy + dy * t_enter - y, oz + dz * t_enter - z, lod)
                    if al >= (8 if (f & F_TRANSLUCENT) != 0 else 128):
                        return EV_CUBE, x, y, z, face, -1, t_enter
            elif k == K_MODEL:
                best = -1
                bt = t_exit + 1e-4
                st = c.mq_start[s]
                lod = _lod_of(t_enter * lodk)
                thr = 8 if (f & F_TRANSLUCENT) != 0 else 128
                Q = c.quads
                lx0 = ox - x
                ly0 = oy - y
                lz0 = oz - z
                for qi in range(st, st + c.mq_count[s]):
                    denom = dx * Q[qi, 9] + dy * Q[qi, 10] + dz * Q[qi, 11]
                    if denom >= -1e-6:
                        continue
                    tq = (Q[qi, 18] - (lx0 * Q[qi, 9] + ly0 * Q[qi, 10] + lz0 * Q[qi, 11])) / denom
                    if tq <= t0 + 1e-5 or tq >= bt:
                        continue
                    lx = lx0 + dx * tq
                    ly = ly0 + dy * tq
                    lz = lz0 + dz * tq
                    rx = lx - Q[qi, 0]
                    ry = ly - Q[qi, 1]
                    rz = lz - Q[qi, 2]
                    pa = rx * Q[qi, 3] + ry * Q[qi, 4] + rz * Q[qi, 5]
                    if pa < 0.0 or pa > 1.0:
                        continue
                    pb = rx * Q[qi, 6] + ry * Q[qi, 7] + rz * Q[qi, 8]
                    if pb < 0.0 or pb > 1.0:
                        continue
                    if _alpha_at(c, qi, lx, ly, lz, lod) < thr:
                        continue
                    best = qi
                    bt = tq
                if best >= 0:
                    return EV_QUAD, x, y, z, 0, best, bt
            elif k == K_LAVA and axis >= 0:
                ytop = y + FLUID_H
                entry_y = oy + dy * t_enter
                if entry_y >= ytop - 1e-6:
                    if dy < 0.0:
                        tp = (ytop - oy) / dy
                        if tp < t_exit:
                            return EV_CUBE, x, y, z, 1, -1, max(tp, t_enter)
                else:
                    if axis == 0:
                        face = 4 if sx > 0 else 5
                    elif axis == 1:
                        face = 0 if sy > 0 else 1
                    else:
                        face = 2 if sz > 0 else 3
                    return EV_CUBE, x, y, z, face, -1, t_enter
        elif in_water:
            in_water = False
        if t_exit >= tmax:
            return EV_NONE, 0, 0, 0, 0, -1, tlimit
        prev = s
        t_enter = t_exit
        axis = nxt
        if nxt == 0:
            x += sx
            tnx += tdx
            if x < 0 or x >= nx:
                return EV_NONE, 0, 0, 0, 0, -1, tlimit
        elif nxt == 1:
            y += sy
            tny += tdy
            if y < 0 or y >= ny or (sy > 0 and y > topmax):
                return EV_NONE, 0, 0, 0, 0, -1, tlimit
        else:
            z += sz
            tnz += tdz
            if z < 0 or z >= nz:
                return EV_NONE, 0, 0, 0, 0, -1, tlimit


@njit(fastmath=True, error_model="numpy")
def shadow_ray(c, ox, oy, oz, dx, dy, dz):
    """1.0 when the point sees the light, 0.0 when something is in the way. Alpha tests leaves for dappled light."""
    nx, ny, nz = c.blocks.shape
    if dy <= 1e-4:
        return 0.0
    if abs(dx) < 1e-9:
        dx = 1e-9
    if abs(dz) < 1e-9:
        dz = 1e-9
    x = int(np.floor(ox))
    y = int(np.floor(oy))
    z = int(np.floor(oz))
    if x < 0 or x >= nx or y < 0 or y >= ny or z < 0 or z >= nz:
        return 1.0
    sx = 1 if dx > 0 else -1
    sz = 1 if dz > 0 else -1
    tdx = abs(1.0 / dx)
    tdy = abs(1.0 / dy)
    tdz = abs(1.0 / dz)
    tnx = ((x + 1 if dx > 0 else x) - ox) / dx
    tny = (y + 1 - oy) / dy
    tnz = ((z + 1 if dz > 0 else z) - oz) / dz
    t_enter = 0.0
    axis = -1
    topmax = int(c.P[P_TOPMAX])
    while True:
        if tnx < tny:
            if tnx < tnz:
                t_exit, nxt = tnx, 0
            else:
                t_exit, nxt = tnz, 2
        else:
            if tny < tnz:
                t_exit, nxt = tny, 1
            else:
                t_exit, nxt = tnz, 2
        if y <= c.top[x, z]:
            s = c.blocks[x, y, z]
            if s != 0:
                k = c.kind[s]
                f = c.flags[s]
                if k == K_CUBE:
                    if axis >= 0:
                        if (f & F_OPAQUE) != 0:
                            return 0.0
                        if (f & F_LEAVES) != 0:
                            if axis == 0:
                                face = 4 if sx > 0 else 5
                            elif axis == 1:
                                face = 0
                            else:
                                face = 2 if sz > 0 else 3
                            al = _alpha_at(c, c.cube_q[s, face], ox + dx * t_enter - x, oy + dy * t_enter - y,
                                           oz + dz * t_enter - z, 0)
                            if al >= 128:
                                return 0.0
                elif k == K_LAVA:
                    if axis >= 0:
                        return 0.0
                elif k == K_MODEL and (f & (F_NOSHADOW | F_TRANSLUCENT)) == 0:
                    Q = c.quads
                    st = c.mq_start[s]
                    lx0 = ox - x
                    ly0 = oy - y
                    lz0 = oz - z
                    for qi in range(st, st + c.mq_count[s]):
                        denom = dx * Q[qi, 9] + dy * Q[qi, 10] + dz * Q[qi, 11]
                        if abs(denom) < 1e-6:
                            continue
                        tq = (Q[qi, 18] - (lx0 * Q[qi, 9] + ly0 * Q[qi, 10] + lz0 * Q[qi, 11])) / denom
                        if tq <= 1e-3 or tq > t_exit + 1e-4:
                            continue
                        rx = lx0 + dx * tq - Q[qi, 0]
                        ry = ly0 + dy * tq - Q[qi, 1]
                        rz = lz0 + dz * tq - Q[qi, 2]
                        pa = rx * Q[qi, 3] + ry * Q[qi, 4] + rz * Q[qi, 5]
                        pb = rx * Q[qi, 6] + ry * Q[qi, 7] + rz * Q[qi, 8]
                        if 0.0 <= pa <= 1.0 and 0.0 <= pb <= 1.0:
                            if _alpha_at(c, qi, lx0 + dx * tq, ly0 + dy * tq, lz0 + dz * tq, 0) >= 128:
                                return 0.0
        t_enter = t_exit
        axis = nxt
        if nxt == 0:
            x += sx
            tnx += tdx
            if x < 0 or x >= nx:
                return 1.0
        elif nxt == 1:
            y += 1
            tny += tdy
            if y > topmax or y >= ny:
                return 1.0
        else:
            z += sz
            tnz += tdz
            if z < 0 or z >= nz:
                return 1.0


@njit(fastmath=True, error_model="numpy", inline="always")
def _cell(c, x, y, z):
    """(opaque, sky, block) of a voxel. Outside the grid: open sky."""
    nx, ny, nz = c.blocks.shape
    if x < 0 or x >= nx or y >= ny or z < 0 or z >= nz or y < 0:
        return 0.0, 15.0, 0.0
    s = c.blocks[x, y, z]
    if (c.flags[s] & F_OPAQUE) != 0:
        return 1.0, 0.0, 0.0
    return 0.0, float(c.sky[x, y, z]), float(c.blk[x, y, z])


@njit(fastmath=True, error_model="numpy")
def smooth_light(c, x, y, z, face, lx, ly, lz):
    """Game-style smooth lighting: light + occlusion at the 4 face corners, bilinearly interpolated across the face."""
    ax = x + _FN[face, 0]
    ay = y + _FN[face, 1]
    az = z + _FN[face, 2]
    if face <= 1:
        t1x, t1y, t1z, t2x, t2y, t2z = 1, 0, 0, 0, 0, 1
        fu, fv = lx, lz
    elif face <= 3:
        t1x, t1y, t1z, t2x, t2y, t2z = 1, 0, 0, 0, 1, 0
        fu, fv = lx, ly
    else:
        t1x, t1y, t1z, t2x, t2y, t2z = 0, 0, 1, 0, 1, 0
        fu, fv = lz, ly
    fu = min(max(fu, 0.0), 1.0)
    fv = min(max(fv, 0.0), 1.0)
    _, s0, b0 = _cell(c, ax, ay, az)
    ao = 0.0
    sk = 0.0
    bl = 0.0
    for su in range(2):
        du = 2 * su - 1
        wu = fu if su == 1 else 1.0 - fu
        for sv in range(2):
            dv = 2 * sv - 1
            w = wu * (fv if sv == 1 else 1.0 - fv)
            o1, s1, b1 = _cell(c, ax + du * t1x, ay + du * t1y, az + du * t1z)
            o2, s2, b2 = _cell(c, ax + dv * t2x, ay + dv * t2y, az + dv * t2z)
            if o1 > 0.5 and o2 > 0.5:
                o3, s3, b3 = 1.0, 0.0, 0.0
            else:
                o3, s3, b3 = _cell(c, ax + du * t1x + dv * t2x, ay + du * t1y + dv * t2y, az + du * t1z + dv * t2z)
            ao += w * (1.0 + (1.0 - 0.8 * o1) + (1.0 - 0.8 * o2) + (1.0 - 0.8 * o3)) * 0.25
            cnt = 4.0 - o1 - o2 - o3
            sk += w * (s0 + s1 + s2 + s3) / cnt
            bl += w * (b0 + b1 + b2 + b3) / cnt
    return ao, sk / 15.0, bl / 15.0


@njit(fastmath=True, error_model="numpy", inline="always")
def _lit(sk, bl, di, P, ch):
    """Light for one channel. Block light fills what sky light leaves, so torches do not glow in full daylight."""
    a = sk * sk * (0.35 + 0.65 * sk) * (P[P_AMB + ch] + P[P_DIR + ch] * di) + P[P_MIN + ch]
    b = bl * (0.2 + 0.8 * bl) * P[P_BLK + ch]
    return a + b * max(1.0 - a, 0.0)


@njit(fastmath=True, error_model="numpy")
def _sprite(tex, dx, dy, dz, sx, sy, sz, ux, uy, uz, vx, vy, vz, cu, cv, half):
    """Sprite on a plane with normal s, centred at (cu, cv) in that plane's coordinates."""
    cs = dx * sx + dy * sy + dz * sz
    if cs <= 0.0:
        return 0.0, 0.0, 0.0
    px = (dx * ux + dy * uy + dz * uz) / cs - cu
    py = (dx * vx + dy * vy + dz * vz) / cs - cv
    u = (px / half + 1.0) * 0.5
    v = (1.0 - py / half) * 0.5
    if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
        return 0.0, 0.0, 0.0
    h, w, _ = tex.shape
    t = tex[int(v * h), int(u * w)]
    return t[0] * t[3], t[1] * t[3], t[2] * t[3]


@njit(fastmath=True, error_model="numpy")
def _stars(dx, dy, dz):
    ax, ay, az = abs(dx), abs(dy), abs(dz)
    if ax >= ay and ax >= az:
        f = 0 if dx > 0 else 1
        u, v = dy / ax, dz / ax
    elif ay >= az:
        f = 2 if dy > 0 else 3
        u, v = dx / ay, dz / ay
    else:
        f = 4 if dz > 0 else 5
        u, v = dx / az, dy / az
    n = 560
    iu = int((u + 1.0) * 0.5 * n)
    iv = int((v + 1.0) * 0.5 * n)
    h = _hash3(iu, iv, f + 31)
    if (h & 1023) < 6:
        return 0.35 + 0.65 * ((h >> 10) & 255) / 255.0
    return 0.0


@njit(fastmath=True, error_model="numpy")
def _gradient(c, dx, dy, dz):
    """Sky colour without sprites: horizon -> zenith ramp plus the sunrise/sunset fan on the sun's side."""
    P = c.P
    up = max(dy, 0.0)
    t = min(up / 0.62, 1.0)
    t = 1.0 - (1.0 - t) * (1.0 - t)
    r = P[P_HOR] + (P[P_ZEN] - P[P_HOR]) * t
    g = P[P_HOR + 1] + (P[P_ZEN + 1] - P[P_HOR + 1]) * t
    b = P[P_HOR + 2] + (P[P_ZEN + 2] - P[P_HOR + 2]) * t
    if dy < 0.0:
        k = 1.0 - min(-dy * 2.0, 1.0) * 0.2
        r *= k
        g *= k
        b *= k
    gs = P[P_GLOWSTR]
    if gs > 0.0:
        h = np.sqrt(dx * dx + dz * dz) + 1e-6
        hs = np.sqrt(P[P_SUN] * P[P_SUN] + P[P_SUN + 2] * P[P_SUN + 2]) + 1e-6
        az = (dx * P[P_SUN] + dz * P[P_SUN + 2]) / (h * hs)
        fan = (az * 0.5 + 0.5)
        fan = fan * fan * fan
        band = np.exp(-abs(dy) * 5.5)
        g0 = min(gs * fan * band, 1.0)
        r += (P[P_GLOW] - r) * g0
        g += (P[P_GLOW + 1] - g) * g0
        b += (P[P_GLOW + 2] - b) * g0
    return r, g, b


@njit(fastmath=True, error_model="numpy")
def _end_sky(c, dx, dy, dz):
    ax, ay, az = abs(dx), abs(dy), abs(dz)
    if ax >= ay and ax >= az:
        u, v = dz / ax, dy / ax
    elif ay >= az:
        u, v = dx / ay, dz / ay
    else:
        u, v = dx / az, dy / az
    tex = c.endsky
    h, w, _ = tex.shape
    # Tiled like the game's end sky, but coarse enough that the speckle reads as a texture and not as noise.
    ui = int(np.floor((u + 1.0) * 1.2 * w)) % w
    vi = int(np.floor((v + 1.0) * 1.2 * h)) % h
    t = tex[vi, ui]
    # The texture is high-contrast speckle; pulling it toward its mean keeps the look without reading as static.
    k = 0.26
    mean = 0.34
    return ((mean + (t[0] - mean) * 0.5) * k + P_END_TINT_R,
            (mean + (t[1] - mean) * 0.5) * k + P_END_TINT_G,
            (mean + (t[2] - mean) * 0.5) * k + P_END_TINT_B)


@njit(fastmath=True, error_model="numpy")
def sky_color(c, dx, dy, dz, stars=True):
    P = c.P
    mode = int(P[P_MODE])
    if mode == MODE_END:
        return _end_sky(c, dx, dy, dz)
    r, g, b = _gradient(c, dx, dy, dz)
    if mode == MODE_NETHER:
        return r, g, b
    st = P[P_STARS]
    if stars and st > 0.0 and dy > -0.05:
        sb = _stars(dx, dy, dz) * st * min(1.0, (dy + 0.05) * 5.0)
        if sb > 0.0:
            r += sb
            g += sb
            b += sb * 1.05
    ss = P[P_SUNSTR]
    if ss > 0.0:
        sr, sg, sb2 = _sprite(c.sunspr, dx, dy, dz, P[P_SUNF], P[P_SUNF + 1], P[P_SUNF + 2],
                              P[P_SUNU], P[P_SUNU + 1], P[P_SUNU + 2],
                              P[P_SUNV], P[P_SUNV + 1], P[P_SUNV + 2], P[P_SUNC], P[P_SUNC + 1], P[P_SUNSZ])
        r += sr * ss
        g += sg * ss
        b += sb2 * ss
        cs = dx * P[P_SUN] + dy * P[P_SUN + 1] + dz * P[P_SUN + 2]
        if cs > 0.0:
            cs2 = cs * cs
            cs4 = cs2 * cs2
            cs16 = cs4 * cs4
            cs16 = cs16 * cs16
            halo = (cs16 * 0.06 + cs16 * cs16 * cs16 * 0.14) * ss
            r += halo * P[P_DIR] * 1.1
            g += halo * P[P_DIR + 1] * 1.1
            b += halo * P[P_DIR + 2] * 1.1
    ms = P[P_MOONSTR]
    if ms > 0.0:
        sr, sg, sb2 = _sprite(c.moonspr, dx, dy, dz, P[P_MOONF], P[P_MOONF + 1], P[P_MOONF + 2],
                              P[P_MOONU], P[P_MOONU + 1], P[P_MOONU + 2],
                              P[P_MOONV], P[P_MOONV + 1], P[P_MOONV + 2], P[P_MOONC], P[P_MOONC + 1], P[P_MOONSZ])
        r += sr * ms
        g += sg * ms
        b += sb2 * ms
        cs = dx * P[P_MOON] + dy * P[P_MOON + 1] + dz * P[P_MOON + 2]
        if cs > 0.0:
            cs2 = cs * cs
            cs4 = cs2 * cs2
            cs16 = cs4 * cs4
            cs16 = cs16 * cs16 * cs16 * cs16
            halo = cs16 * 0.10 * ms
            r += halo * 0.7
            g += halo * 0.8
            b += halo
    return r, g, b


@njit(fastmath=True, error_model="numpy")
def fog_color(c, dx, dy, dz):
    return _gradient(c, dx, dy * 0.3, dz)


@njit(fastmath=True, error_model="numpy", inline="always")
def _fog_factor(c, t):
    fd = c.P[P_FOGD]
    if fd <= 0.0:
        return 0.0
    return 1.0 - np.exp(-((t / fd) ** c.P[P_FOGP]))


@njit(fastmath=True, error_model="numpy")
def clouds_hit(c, ox, oy, oz, dx, dy, dz, tmax):
    """The flat Minecraft cloud layer, 12 blocks per texel of clouds.png and 4 blocks thick. Returns (r,g,b,a,t)."""
    P = c.P
    st = P[P_CLOUD]
    if st <= 0.0 or abs(dy) < 1e-4:
        return 0.0, 0.0, 0.0, 0.0, tmax
    y0 = P[P_CLOUDY]
    y1 = y0 + 4.0
    t0 = (y0 - oy) / dy
    t1 = (y1 - oy) / dy
    if t0 > t1:
        t0, t1 = t1, t0
    t0 = max(t0, 0.0)
    t1 = min(t1, min(tmax, 6000.0))
    if t0 >= t1:
        return 0.0, 0.0, 0.0, 0.0, tmax
    cell = 12.0
    cx = (ox + dx * t0 + P[P_COX]) / cell
    cz = (oz + dz * t0 + P[P_COZ]) / cell
    i = int(np.floor(cx))
    j = int(np.floor(cz))
    ddx = dx if abs(dx) > 1e-9 else 1e-9
    ddz = dz if abs(dz) > 1e-9 else 1e-9
    sx = 1 if ddx > 0 else -1
    sz = 1 if ddz > 0 else -1
    tdx = abs(cell / ddx)
    tdz = abs(cell / ddz)
    tnx = t0 + ((i + (1 if ddx > 0 else 0)) - cx) * cell / ddx
    tnz = t0 + ((j + (1 if ddz > 0 else 0)) - cz) * cell / ddz
    t = t0
    # Which surface was entered: 0 top, 1 bottom, 2 x side, 3 z side.
    surf = 0 if dy < 0 else 1
    for _ in range(400):
        if c.clouds[j & 255, i & 255] != 0:
            if surf == 0:
                sh = 1.0
            elif surf == 1:
                sh = 0.86
            elif surf == 2:
                sh = 0.94
            else:
                sh = 0.9
            fade = 1.0 - min(t / 5200.0, 1.0)
            a = 0.82 * st * fade * fade
            f = 1.0 - np.exp(-((t / (P[P_FOGD] * 7.0 + 1.0)) ** 1.5))
            fr, fg, fb = _gradient(c, dx, dy * 0.3, dz)
            r = P[P_CTOP] * sh
            g = P[P_CTOP + 1] * sh
            b = P[P_CTOP + 2] * sh
            return r + (fr - r) * f, g + (fg - g) * f, b + (fb - b) * f, a, t
        if tnx < tnz:
            t = tnx
            tnx += tdx
            i += sx
            surf = 2
        else:
            t = tnz
            tnz += tdz
            j += sz
            surf = 3
        if t >= t1:
            break
    return 0.0, 0.0, 0.0, 0.0, tmax


@njit(fastmath=True, error_model="numpy")
def sample_surface(c, s, q, x, y, z, face, lx, ly, lz, lod):
    """Albedo of quad q at a local position, biome tint applied. Returns (r, g, b, a)."""
    Q = c.quads
    rx = lx - Q[q, 0]
    ry = ly - Q[q, 1]
    rz = lz - Q[q, 2]
    pa = rx * Q[q, 3] + ry * Q[q, 4] + rz * Q[q, 5]
    pb = rx * Q[q, 6] + ry * Q[q, 7] + rz * Q[q, 8]
    u = Q[q, 12] + pa * Q[q, 14] + pb * Q[q, 16]
    v = Q[q, 13] + pa * Q[q, 15] + pb * Q[q, 17]
    if face == 1 and (c.flags[s] & F_RANDROT) != 0:
        h = _hash3(x, y, z) & 3
        if h == 1:
            u, v = v, 1.0 - u
        elif h == 2:
            u, v = 1.0 - u, 1.0 - v
        elif h == 3:
            u, v = 1.0 - v, u
    size = 16 >> lod
    ui = int(np.floor(u * size)) & (size - 1)
    vi = int(np.floor(v * size)) & (size - 1)
    t = c.atlas[c.qtex[q], lod, vi, ui]
    k = 1.0 / 255.0
    r = t[0] * k
    g = t[1] * k
    b = t[2] * k
    a = t[3] * k
    tn = c.qtint[q]
    if tn != 0:
        if tn == 1:
            tr, tg, tb = c.tg[x, z, 0] * k, c.tg[x, z, 1] * k, c.tg[x, z, 2] * k
        elif tn == 2:
            tr, tg, tb = c.tf[x, z, 0] * k, c.tf[x, z, 1] * k, c.tf[x, z, 2] * k
        elif tn == 3:
            tr, tg, tb = c.tw[x, z, 0] * k, c.tw[x, z, 1] * k, c.tw[x, z, 2] * k
        else:
            tr, tg, tb = c.fixed[tn - 4, 0], c.fixed[tn - 4, 1], c.fixed[tn - 4, 2]
        r *= tr
        g *= tg
        b *= tb
    return r, g, b, a


@njit(fastmath=True, error_model="numpy")
def shade(c, ev, s, q, x, y, z, face, th, ox, oy, oz, dx, dy, dz, lodk, use_shadow, j1, j2):
    """Lit colour of an opaque or cutout surface hit."""
    P = c.P
    Q = c.quads
    px = ox + dx * th
    py = oy + dy * th
    pz = oz + dz * th
    lx = px - x
    ly = py - y
    lz = pz - z
    nx = Q[q, 9]
    ny = Q[q, 10]
    nz = Q[q, 11]
    cosv = abs(dx * nx + dy * ny + dz * nz)
    lod = _lod_of(th * lodk / max(cosv, 0.4))
    r, g, b, _ = sample_surface(c, s, q, x, y, z, face, lx, ly, lz, lod)
    if ev == EV_CUBE:
        qo = c.cube_o[s, face]
        if qo >= 0:
            r2, g2, b2, a2 = sample_surface(c, s, qo, x, y, z, face, lx, ly, lz, lod)
            r += (r2 - r) * a2
            g += (g2 - g) * a2
            b += (b2 - b) * a2
        ao, sk, bl = smooth_light(c, x, y, z, face, lx, ly, lz)
    else:
        ao = 1.0
        sk = c.sky[x, y, z] / 15.0
        bl = c.blk[x, y, z] / 15.0
        # A model face on the voxel's boundary is lit from the neighbour it looks into when that one is open.
        if s != 0 and (c.flags[s] & F_NOSHADOW) == 0:
            ax = x + int(np.round(nx))
            ay = y + int(np.round(ny))
            az = z + int(np.round(nz))
            _, s2, b2 = _cell(c, ax, ay, az)
            sk = max(sk, s2 / 15.0)
            bl = max(bl, b2 / 15.0)
    ao = 1.0 - (1.0 - ao) * P[P_AO]
    leaf_gain = 1.0
    if (c.flags[s] & F_LEAVES) != 0:
        sk = max(sk, 0.92)
        ao = 0.55 + 0.45 * ao
        leaf_gain = 1.45
    sl = c.selflit[s]
    if sl > 0.0:
        # Light sources ignore shading. Darker times push them past white so the bloom pass makes them glow.
        boost = 0.9 if c.kind[s] == K_LAVA else 1.0 + P[P_SELFGLOW] * sl
        return r * boost, g * boost, b * boost
    ldx = P[P_LDIR]
    ldy = P[P_LDIR + 1]
    ldz = P[P_LDIR + 2]
    ndl = nx * ldx + ny * ldy + nz * ldz
    plant = (c.flags[s] & F_NOSHADOW) != 0 and ev == EV_QUAD
    if plant:
        ndl = max(ldy, 0.2)
    vis = 0.0
    if ndl > 0.0 and sk > 0.05 and P[P_SHADOWS] > 0.0:
        if use_shadow:
            soft = P[P_SOFT]
            sdx = ldx + j1 * soft
            sdy = ldy
            sdz = ldz + j2 * soft
            k = 0.003
            vis = shadow_ray(c, px + nx * k, py + ny * k, pz + nz * k, sdx, sdy, sdz)
        else:
            vis = 1.0
    fs = Q[q, 19] * ao * leaf_gain
    di = ndl * vis if ndl > 0.0 else 0.0
    return r * fs * _lit(sk, bl, di, P, 0), g * fs * _lit(sk, bl, di, P, 1), b * fs * _lit(sk, bl, di, P, 2)


@njit(fastmath=True, error_model="numpy")
def sky_and_clouds(c, ox, oy, oz, dx, dy, dz):
    cr, cg, cb, ca, _ = clouds_hit(c, ox, oy, oz, dx, dy, dz, 1e9)
    r, g, b = sky_color(c, dx, dy, dz, ca <= 0.0)
    if ca > 0.0:
        r += (cr - r) * ca
        g += (cg - g) * ca
        b += (cb - b) * ca
    return r, g, b


@njit(fastmath=True, error_model="numpy")
def reflect_color(c, ox, oy, oz, dx, dy, dz, lodk):
    ev, x, y, z, face, q, th = march(c, ox, oy, oz, dx, dy, dz, 0.02, 520.0, False, lodk * 1.5)
    if ev == EV_NONE or ev == EV_WATER:
        return sky_and_clouds(c, ox, oy, oz, dx, dy, dz)
    s = c.blocks[x, y, z]
    if ev == EV_CUBE:
        q = c.cube_q[s, face]
    r, g, b = shade(c, ev, s, q, x, y, z, face, th, ox, oy, oz, dx, dy, dz, lodk, False, 0.0, 0.0)
    f = _fog_factor(c, th)
    if f > 0.001:
        fr, fg, fb = fog_color(c, dx, dy, dz)
        r += (fr - r) * f
        g += (fg - g) * f
        b += (fb - b) * f
    return r, g, b


@njit(fastmath=True, error_model="numpy")
def _ripple(px, pz, amp):
    # Quantised to the texture grid so reflections shimmer in blocky steps instead of smooth waves.
    qx = np.floor(px * 8.0) / 8.0
    qz = np.floor(pz * 8.0) / 8.0
    a = 1.7 * qx + 0.9 * qz
    b = 0.7 * qx - 2.3 * qz + 1.3
    d = 3.1 * qx + 2.3 * qz + 0.7
    e = 0.31 * qx + 0.23 * qz
    nx = (np.cos(a) * 1.7 + np.cos(b) * 0.7 + np.cos(d) * 1.55 + np.cos(e) * 0.6) * amp
    nz = (np.cos(a) * 0.9 - np.cos(b) * 2.3 + np.cos(d) * 1.15 + np.sin(e) * 0.6) * amp
    return nx, nz


@njit(fastmath=True, error_model="numpy")
def trace(c, ox, oy, oz, dx, dy, dz, lodk, j1, j2):
    """Primary ray: composites translucent layers front to back. Returns (r, g, b, alpha, depth)."""
    P = c.P
    ar = 0.0
    ag = 0.0
    ab = 0.0
    tr = 1.0
    t = 0.0
    in_water = False
    wt0 = 0.0
    wr = 0.0
    wg = 0.0
    wb = 0.0
    first = -1.0
    alpha = 1.0
    wk = P[P_WABS]
    tlimit = 4000.0
    for _ in range(14):
        ev, x, y, z, face, q, th = march(c, ox, oy, oz, dx, dy, dz, t, tlimit, in_water, lodk)
        if ev == EV_NONE:
            if P[P_ALPHA] > 0.0 and first < 0.0:
                return 0.0, 0.0, 0.0, 0.0, -1.0
            r, g, b = sky_and_clouds(c, ox, oy, oz, dx, dy, dz)
            if in_water:
                dist = 24.0
                wa = np.exp(-wk * dist)
                r = r * wa + wr * (1.0 - wa)
                g = g * wa + wg * (1.0 - wa)
                b = b * wa + wb * (1.0 - wa)
            ar += tr * r
            ag += tr * g
            ab += tr * b
            if first < 0.0:
                first = -1.0 if dy >= 0.0 else -2.0
            break
        if first < 0.0:
            first = th
        f = _fog_factor(c, th) if P[P_ALPHA] <= 0.0 else 0.0
        fr, fg, fb = 0.0, 0.0, 0.0
        if f > 0.001:
            fr, fg, fb = fog_color(c, dx, dy, dz)
        s = c.blocks[x, y, z]
        if ev == EV_WATER:
            px = ox + dx * th
            py = oy + dy * th
            pz = oz + dz * th
            nx = float(_FN[face, 0])
            ny = float(_FN[face, 1])
            nz = float(_FN[face, 2])
            if face == 1:
                amp = 0.012 / (1.0 + th / 90.0)
                rx, rz = _ripple(px, pz, amp)
                nx, nz = rx, rz
                ln = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
                nx *= ln
                ny *= ln
                nz *= ln
            cs = -(dx * nx + dy * ny + dz * nz)
            if cs < 0.0:
                cs = 0.0
            fres = 1.0 - cs
            fres2 = fres * fres
            fres = 0.03 + 0.97 * fres2 * fres2 * fres
            fres = min(fres * P[P_REFL], 0.9)
            qw = max(c.cube_q[s, 1], 0)
            lod = _lod_of(th * lodk / max(cs, 0.4))
            if c.kind[s] != K_WATER:
                # Waterlogged block: tint from the biome, water alpha like the real texture.
                k = 1.0 / 255.0
                r0, g0, b0, a0 = 0.55 * c.tw[x, z, 0] * k, 0.55 * c.tw[x, z, 1] * k, 0.55 * c.tw[x, z, 2] * k, 0.7
            else:
                r0, g0, b0, a0 = sample_surface(c, s, qw, x, y, z, 1, px - x, 0.5, pz - z, lod)
            sk = 1.0
            bl = 0.0
            if y + 1 < c.blocks.shape[1]:
                sk = c.sky[x, y + 1, z] / 15.0
                bl = c.blk[x, y + 1, z] / 15.0
            ldx, ldy, ldz = P[P_LDIR], P[P_LDIR + 1], P[P_LDIR + 2]
            vis = 0.0
            if ldy > 0.0 and sk > 0.05 and P[P_SHADOWS] > 0.0:
                vis = shadow_ray(c, px, py + 0.01, pz, ldx + j1 * P[P_SOFT], ldy, ldz + j2 * P[P_SOFT])
            di = ldy * vis if ldy > 0.0 else 0.0
            lr = _lit(sk, bl, di, P, 0)
            lg = _lit(sk, bl, di, P, 1)
            lb = _lit(sk, bl, di, P, 2)
            er, eg, eb = r0 * lr, g0 * lg, b0 * lb
            T = (1.0 - fres) * (1.0 - a0)
            mix = (1.0 - fres) * a0
            er *= mix
            eg *= mix
            eb *= mix
            if fres > 0.015 and P[P_REFL] > 0.0:
                ddn = 2.0 * cs
                rdx = dx + ddn * nx
                rdy = dy + ddn * ny
                rdz = dz + ddn * nz
                if rdy < 0.01:
                    rdy = 0.01
                ln = 1.0 / np.sqrt(rdx * rdx + rdy * rdy + rdz * rdz)
                rdx *= ln
                rdy *= ln
                rdz *= ln
                rr, rg, rb = reflect_color(c, px, py + 0.02, pz, rdx, rdy, rdz, lodk)
                er += rr * fres
                eg += rg * fres
                eb += rb * fres
                sp = rdx * ldx + rdy * ldy + rdz * ldz
                if sp > 0.98 and vis > 0.0:
                    sp2 = sp * sp
                    sp4 = sp2 * sp2
                    sp16 = sp4 * sp4
                    sp16 = sp16 * sp16
                    sp64 = sp16 * sp16
                    sp256 = sp64 * sp64
                    spec = sp256 * sp256 * vis * 1.6
                    er += spec * P[P_DIR]
                    eg += spec * P[P_DIR + 1]
                    eb += spec * P[P_DIR + 2]
            ar += tr * ((1.0 - f) * er + f * fr * (1.0 - T))
            ag += tr * ((1.0 - f) * eg + f * fg * (1.0 - T))
            ab += tr * ((1.0 - f) * eb + f * fb * (1.0 - T))
            tr *= T
            in_water = True
            wt0 = th
            wr, wg, wb = r0 * lr * 0.75, g0 * lg * 0.75, b0 * lb * 0.75
            t = th + 1e-3
            continue
        if ev == EV_CUBE:
            q = c.cube_q[s, face]
        if q < 0:
            t = th + 1e-3
            continue
        if (c.flags[s] & F_TRANSLUCENT) != 0:
            lod = _lod_of(th * lodk)
            r, g, b, a = sample_surface(c, s, q, x, y, z, face, ox + dx * th - x, oy + dy * th - y, oz + dz * th - z,
                                        lod)
            sk = c.sky[x, y, z] / 15.0
            bl = c.blk[x, y, z] / 15.0
            sl = c.selflit[s]
            fs = c.quads[q, 19]
            r *= max(fs * _lit(sk, bl, 0.5, P, 0), sl)
            g *= max(fs * _lit(sk, bl, 0.5, P, 1), sl)
            b *= max(fs * _lit(sk, bl, 0.5, P, 2), sl)
            ar += tr * a * ((1.0 - f) * r + f * fr)
            ag += tr * a * ((1.0 - f) * g + f * fg)
            ab += tr * a * ((1.0 - f) * b + f * fb)
            tr *= 1.0 - a
            t = th + 1e-3
            continue
        r, g, b = shade(c, ev, s, q, x, y, z, face, th, ox, oy, oz, dx, dy, dz, lodk, True, j1, j2)
        if in_water:
            wa = np.exp(-wk * (th - wt0))
            r = r * wa + wr * (1.0 - wa)
            g = g * wa + wg * (1.0 - wa)
            b = b * wa + wb * (1.0 - wa)
        ar += tr * (r + (fr - r) * f)
        ag += tr * (g + (fg - g) * f)
        ab += tr * (b + (fb - b) * f)
        break
    if P[P_CLOUD] > 0.0 and first > 0.0:
        hy = oy + dy * first
        cy = P[P_CLOUDY]
        if hy > cy or oy > cy + 4.0:
            cr, cg, cb, ca, _ = clouds_hit(c, ox, oy, oz, dx, dy, dz, first)
            if ca > 0.0:
                ar += (cr - ar) * ca
                ag += (cg - ag) * ca
                ab += (cb - ab) * ca
    return ar, ag, ab, alpha, first


# cam: 0-2 position, 3-5 right, 6-8 up, 9-11 forward, 12 tan(hfov/2), 13 tan(vfov/2), 14 projection (0 perspective,
# 1 cylinder: the x axis is yaw over the full image width, used for the seamless SDDM strip).
@njit(parallel=True, fastmath=True, error_model="numpy", cache=True)
def render_image(c, cam, W, H, ss, out, depth, alpha):
    if ss == 2:
        ox_s = np.array([0.375, 0.875, 0.125, 0.625])
        oy_s = np.array([0.125, 0.375, 0.625, 0.875])
    else:
        n = ss * ss
        ox_s = np.empty(n)
        oy_s = np.empty(n)
        for i in range(ss):
            for j in range(ss):
                ox_s[i * ss + j] = (j + 0.5) / ss
                oy_s[i * ss + j] = (i + 0.5) / ss
    ns = ox_s.shape[0]
    lodk = (2.0 * cam[13] / (H * ss)) * 16.0
    nchunks = 96
    inv = 1.0 / ns
    for ch in prange(nchunks):
        for py in range(ch, H, nchunks):
            for px in range(W):
                sr = 0.0
                sg = 0.0
                sb = 0.0
                sa = 0.0
                dmin = 1e12
                dany = -1.0
                for k in range(ns):
                    su = (px + ox_s[k]) / W
                    sv = (py + oy_s[k]) / H
                    if cam[14] > 0.5:
                        ang = (su - 0.5) * 2.0 * np.pi
                        cx = np.cos(ang)
                        sx = np.sin(ang)
                        ry = (0.5 - sv) * 2.0 * cam[13]
                        dx = cam[9] * cx + cam[3] * sx + cam[6] * ry
                        dy = cam[10] * cx + cam[4] * sx + cam[7] * ry
                        dz = cam[11] * cx + cam[5] * sx + cam[8] * ry
                    else:
                        rx = (su * 2.0 - 1.0) * cam[12]
                        ry = (1.0 - sv * 2.0) * cam[13]
                        dx = cam[9] + cam[3] * rx + cam[6] * ry
                        dy = cam[10] + cam[4] * rx + cam[7] * ry
                        dz = cam[11] + cam[5] * rx + cam[8] * ry
                    ln = 1.0 / np.sqrt(dx * dx + dy * dy + dz * dz)
                    dx *= ln
                    dy *= ln
                    dz *= ln
                    h = _hash3(px, py, k + 7)
                    j1 = ((h & 1023) / 1023.0 - 0.5) * 2.0
                    j2 = (((h >> 10) & 1023) / 1023.0 - 0.5) * 2.0
                    r, g, b, a, d = trace(c, cam[0], cam[1], cam[2], dx, dy, dz, lodk, j1, j2)
                    sr += r
                    sg += g
                    sb += b
                    sa += a
                    if d > 0.0 and d < dmin:
                        dmin = d
                    if d < dany:
                        dany = d
                out[py, px, 0] = sr * inv
                out[py, px, 1] = sg * inv
                out[py, px, 2] = sb * inv
                alpha[py, px] = sa * inv
                depth[py, px] = dmin if dmin < 1e11 else dany
