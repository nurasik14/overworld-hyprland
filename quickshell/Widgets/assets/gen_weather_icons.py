#!/usr/bin/env python3
"""gen_weather_icons.py — original 16×16 pixel-art weather icons for the Weather card (no Mojang art).
Writes weather/<name>.png (RGBA) with only the standard library:  python3 gen_weather_icons.py
Names: sun moon partly_day partly_night cloud fog rain snow sleet thunder
"""
import math
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weather")
N = 16


def png(path, px):
    raw = b"".join(b"\x00" + b"".join(bytes(c) for c in row) for row in px)
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def blank():
    return [[(0, 0, 0, 0)] * N for _ in range(N)]


def put(g, x, y, c):
    if 0 <= x < N and 0 <= y < N:
        g[y][x] = c


def disc_mask(cx, cy, r):
    return {(x, y) for y in range(N) for x in range(N) if (x + .5 - cx) ** 2 + (y + .5 - cy) ** 2 <= r * r}


def outline(g, mask, col):
    for (x, y) in mask:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p not in mask and 0 <= p[0] < N and 0 <= p[1] < N:
                put(g, p[0], p[1], col)


def cloud_mask(ox, oy, s=1.0):
    m = disc_mask(ox + 5.0 * s, oy + 6.5 * s, 3.2 * s) | disc_mask(ox + 9.2 * s, oy + 5.0 * s, 4.1 * s) | disc_mask(ox + 12.2 * s, oy + 7.4 * s, 2.7 * s)
    m |= {(x, y) for x in range(int(ox + 3 * s), int(ox + 14 * s)) for y in range(int(oy + 6.5 * s), int(oy + 9.5 * s)) if 0 <= x < N and 0 <= y < N}
    return {p for p in m if 0 <= p[0] < N and 0 <= p[1] < N}


def draw_cloud(g, ox, oy, s=1.0, tones=((255, 255, 255, 255), (222, 226, 238, 255), (176, 184, 204, 255)), edge=(64, 70, 96, 255)):
    m = cloud_mask(ox, oy, s)
    ys = sorted({y for _, y in m})
    top, bot = ys[0], ys[-1]
    for (x, y) in m:
        t = (y - top) / max(1, bot - top)
        put(g, x, y, tones[0] if t < 0.45 else tones[1] if t < 0.8 else tones[2])
    outline(g, m, edge)
    return m


def draw_sun(g, cx, cy, r, rays=True, clip=None):
    cols = ((255, 246, 140, 255), (255, 214, 64, 255), (244, 160, 32, 255))
    for (x, y) in disc_mask(cx, cy, r):
        d = math.hypot(x + .5 - cx, y + .5 - cy) / r
        if clip and (x, y) in clip:
            continue
        put(g, x, y, cols[0] if d < .55 else cols[1] if d < .9 else cols[2])
    if rays:
        for k in range(8):
            a = k * math.pi / 4
            for rr in (r + 1.6, r + 2.6):
                x, y = int(cx + math.cos(a) * rr), int(cy + math.sin(a) * rr)
                if clip and (x, y) in clip:
                    continue
                put(g, x, y, (255, 200, 48, 255))


def draw_moon(g, cx, cy, r, clip=None):
    full = disc_mask(cx, cy, r)
    cut = disc_mask(cx + r * .55, cy - r * .35, r * .85)
    for (x, y) in full - cut:
        if clip and (x, y) in clip:
            continue
        d = math.hypot(x + .5 - cx, y + .5 - cy) / r
        put(g, x, y, (250, 248, 214, 255) if d < .7 else (222, 220, 176, 255))
    outline_m = full - cut
    for (x, y) in outline_m:
        pass


def drops(g, pts, col=(70, 130, 255, 255), hi=(150, 190, 255, 255)):
    for (x, y) in pts:
        put(g, x, y, col)
        put(g, x, y + 1, hi if col else col)


def flake(g, x, y, col=(255, 255, 255, 255), edge=(150, 190, 235, 255)):
    put(g, x, y, col)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        put(g, x + dx, y + dy, edge)


icons = {}


def mk(name):
    g = blank()
    icons[name] = g
    return g


g = mk("sun"); draw_sun(g, 8, 8, 3.6)
g = mk("moon"); draw_moon(g, 7.5, 8.5, 5.2)
for (cx, cy) in ((11.5, 3.5), (13.5, 7.5)):
    put(g, int(cx), int(cy), (255, 255, 230, 255))
g = mk("partly_day")
m = cloud_mask(2, 5, 0.85)
draw_sun(g, 5.5, 5.5, 3.0, clip=m)
draw_cloud(g, 2, 5, 0.85)
g = mk("partly_night")
m = cloud_mask(2, 5, 0.85)
draw_moon(g, 6, 5.5, 4.0, clip=m)
draw_cloud(g, 2, 5, 0.85)
g = mk("cloud"); draw_cloud(g, 0, 3, 1.0)
g = mk("rain")
draw_cloud(g, 0, 0, 1.0, tones=((214, 220, 236, 255), (170, 180, 204, 255), (130, 140, 170, 255)))
drops(g, [(4, 11), (8, 12), (12, 11), (6, 13)])
g = mk("sleet")
draw_cloud(g, 0, 0, 1.0, tones=((214, 220, 236, 255), (170, 180, 204, 255), (130, 140, 170, 255)))
drops(g, [(4, 11), (11, 11)])
flake(g, 8, 12)
g = mk("snow")
draw_cloud(g, 0, 0, 1.0)
for (x, y) in ((4, 12), (8, 13), (12, 12)):
    flake(g, x, y)
g = mk("thunder")
draw_cloud(g, 0, 0, 1.0, tones=((120, 124, 148, 255), (92, 96, 122, 255), (66, 70, 96, 255)), edge=(32, 34, 52, 255))
bolt = [(10, 9), (9, 9), (9, 10), (8, 10), (8, 11), (7, 11), (6, 11), (10, 11), (9, 11), (8, 12), (7, 12), (7, 13), (6, 13), (6, 14), (5, 15)]
for (x, y) in bolt:
    put(g, x, y, (255, 233, 72, 255))
for (x, y) in ((9, 9), (8, 10), (7, 12)):
    put(g, x, y, (255, 255, 200, 255))
g = mk("fog")
for y, (a, b) in zip((3, 6, 9, 12), ((3, 12), (1, 10), (4, 14), (2, 11))):
    for x in range(a, b + 1):
        put(g, x, y, (214, 220, 232, 255)); put(g, x, y + 1, (150, 160, 184, 255))

os.makedirs(OUT, exist_ok=True)
for name, grid in icons.items():
    png(os.path.join(OUT, name + ".png"), grid)
print("wrote", ", ".join(sorted(icons)))
