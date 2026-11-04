"""Time-of-day presets: everything the renderer needs to know about the sky and the light for one frame."""
from __future__ import annotations

import math

import numpy as np

from . import render as R


def _hex(c: int) -> tuple[float, float, float]:
    return ((c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255)


def _dir(az_deg: float, el_deg: float) -> np.ndarray:
    """Direction from azimuth (degrees clockwise from north, -Z) and elevation."""
    az, el = math.radians(az_deg), math.radians(el_deg)
    return np.array([math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el)])


def _basis(d: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    up = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.95 else np.array([0.0, 0.0, -1.0])
    u = np.cross(up, d)
    u = u / np.linalg.norm(u)
    v = np.cross(d, u)
    return u, v


def _sprite_plane(d: np.ndarray, view: tuple[float, float] | None):
    """(normal, u, v, centre_u, centre_v) of a celestial sprite's plane.

    With a view (yaw, pitch) the plane is parallel to the image, so the sun or moon is exactly square on screen
    wherever it sits in the frame; otherwise it faces the viewer, which is right for panorama and strip.
    """
    if view is not None:
        yaw, pitch = math.radians(view[0]), math.radians(view[1])
        f = np.array([math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)])
        if float(f @ d) > 0.15:
            r = np.cross(f, [0.0, 1.0, 0.0])
            r /= np.linalg.norm(r)
            up = np.cross(r, f)
            cs = float(d @ f)
            return f, r, up, float(d @ r) / cs, float(d @ up) / cs
    u, v = _basis(d)
    return d, u, v, 0.0, 0.0


# Numbers are display-space (the game shades in gamma space too), tuned by eye against renders.
TIMES = {
    "day": dict(
        zen=_hex(0x5E97F5), hor=_hex(0xC4DCFF), glow=_hex(0xFFFFFF), glowstr=0.0,
        amb=(0.66, 0.68, 0.72), dir=(0.42, 0.39, 0.33), blk=(0.9, 0.72, 0.5), mn=(0.02, 0.02, 0.025),
        sunstr=1.0, moonstr=0.0, stars=0.0, cloud=1.0, ctop=(1.0, 1.0, 1.0), fogp=2.4,
        sun_el=34.0, key="sun",
    ),
    "dawn": dict(
        zen=_hex(0x5A7CC4), hor=_hex(0xF5C8A8), glow=_hex(0xFF9A5C), glowstr=0.95,
        amb=(0.56, 0.54, 0.60), dir=(0.86, 0.60, 0.40), blk=(1.0, 0.72, 0.45), mn=(0.02, 0.02, 0.03),
        sunstr=1.0, moonstr=0.0, stars=0.05, cloud=1.0, ctop=(1.0, 0.84, 0.76), fogp=2.0,
        sun_el=9.0, key="sun",
    ),
    "dusk": dict(
        zen=_hex(0x37457F), hor=_hex(0xEC9A72), glow=_hex(0xFF5A2E), glowstr=1.0,
        amb=(0.52, 0.45, 0.58), dir=(1.0, 0.54, 0.28), blk=(1.0, 0.70, 0.42), mn=(0.02, 0.02, 0.035),
        sunstr=1.0, moonstr=0.0, stars=0.08, cloud=1.0, ctop=(0.98, 0.66, 0.56), fogp=2.0,
        sun_el=6.0, key="sun",
    ),
    "night": dict(
        zen=_hex(0x080C22), hor=_hex(0x1C2A4C), glow=_hex(0x000000), glowstr=0.0,
        amb=(0.31, 0.37, 0.54), dir=(0.26, 0.32, 0.48), blk=(1.45, 0.98, 0.52), mn=(0.02, 0.025, 0.04),
        sunstr=0.0, moonstr=1.0, stars=1.0, cloud=0.85, ctop=(0.22, 0.26, 0.38), fogp=2.0,
        sun_el=38.0, key="moon",
    ),
    "nether": dict(
        zen=_hex(0x3A0D0A), hor=_hex(0x6A2310), glow=_hex(0x000000), glowstr=0.0,
        amb=(0.0, 0.0, 0.0), dir=(0.0, 0.0, 0.0), blk=(1.25, 0.86, 0.58), mn=(0.46, 0.28, 0.24),
        sunstr=0.0, moonstr=0.0, stars=0.0, cloud=0.0, ctop=(0, 0, 0), fogp=1.6,
        sun_el=90.0, key="sun",
    ),
    "end": dict(
        zen=_hex(0x0E0A18), hor=_hex(0x241A36), glow=_hex(0x000000), glowstr=0.0,
        amb=(0.0, 0.0, 0.0), dir=(0.0, 0.0, 0.0), blk=(0.95, 0.75, 1.0), mn=(0.62, 0.58, 0.74),
        sunstr=0.0, moonstr=0.0, stars=0.0, cloud=0.0, ctop=(0, 0, 0), fogp=1.5,
        sun_el=90.0, key="sun",
    ),
}


def params(time: str, *, view: tuple[float, float] | None = None, sun_az: float, sun_el: float | None = None, moon_az: float | None = None,
           moon_el: float | None = None, key_az: float | None = None, key_el: float | None = None, fog_dist: float = 260.0, cloud_y: float = 236.0,
           cloud_offset: tuple[float, float] = (0.0, 0.0), mode: int = R.MODE_OVERWORLD,
           top_max: int = 255, transparent: bool = False, shadows: bool = True, overrides: dict | None = None,
           ) -> np.ndarray:
    """Build the P vector. ``sun_az`` is the key light's azimuth, chosen per scene so it frames the composition."""
    t = dict(TIMES[time])
    if overrides:
        t.update(overrides)
    el = sun_el if sun_el is not None else t["sun_el"]
    sun = _dir(sun_az, el)
    moon = _dir(moon_az if moon_az is not None else sun_az, moon_el if moon_el is not None else el)
    sf, su, sv, scu, scv = _sprite_plane(sun, view)
    mf, mu, mv, mcu, mcv = _sprite_plane(moon, view)
    # The sky sprite and the key light may differ: a sun in frame would backlight every face the camera sees, so
    # scenes at full day and night light from behind the camera. Low-sun times stay physical for the long shadows.
    key = moon if t["key"] == "moon" else sun
    if key_az is not None:
        key = _dir(key_az, key_el if key_el is not None else el)
    P = np.zeros(R.P_COUNT, dtype=np.float64)
    P[R.P_SUN:R.P_SUN + 3] = sun
    P[R.P_SUNSTR] = t["sunstr"]
    P[R.P_MOON:R.P_MOON + 3] = moon
    P[R.P_MOONSTR] = t["moonstr"]
    P[R.P_ZEN:R.P_ZEN + 3] = t["zen"]
    P[R.P_HOR:R.P_HOR + 3] = t["hor"]
    P[R.P_GLOW:R.P_GLOW + 3] = t["glow"]
    P[R.P_GLOWSTR] = t["glowstr"]
    P[R.P_AMB:R.P_AMB + 3] = t["amb"]
    P[R.P_DIR:R.P_DIR + 3] = t["dir"]
    P[R.P_LDIR:R.P_LDIR + 3] = key
    P[R.P_BLK:R.P_BLK + 3] = t["blk"]
    P[R.P_MIN:R.P_MIN + 3] = t["mn"]
    P[R.P_FOGD] = fog_dist
    P[R.P_FOGP] = t["fogp"]
    P[R.P_STARS] = t["stars"]
    P[R.P_CLOUD] = t["cloud"]
    P[R.P_CLOUDY] = cloud_y
    P[R.P_COX], P[R.P_COZ] = cloud_offset
    P[R.P_CTOP:R.P_CTOP + 3] = t["ctop"]
    P[R.P_MODE] = mode
    P[R.P_WABS] = t.get("wabs", 0.11)
    P[R.P_SHADOWS] = 1.0 if shadows and np.abs(np.asarray(t["dir"])).sum() > 0 else 0.0
    P[R.P_AO] = t.get("ao", 1.0)
    P[R.P_REFL] = t.get("refl", 1.0)
    P[R.P_ALPHA] = 1.0 if transparent else 0.0
    P[R.P_TOPMAX] = top_max
    P[R.P_SUNU:R.P_SUNU + 3] = su
    P[R.P_SUNV:R.P_SUNV + 3] = sv
    P[R.P_MOONU:R.P_MOONU + 3] = mu
    P[R.P_MOONV:R.P_MOONV + 3] = mv
    P[R.P_SUNF:R.P_SUNF + 3] = sf
    P[R.P_MOONF:R.P_MOONF + 3] = mf
    P[R.P_SUNC], P[R.P_SUNC + 1] = scu, scv
    P[R.P_MOONC], P[R.P_MOONC + 1] = mcu, mcv
    P[R.P_SUNSZ] = t.get("sun_size", 0.17)
    P[R.P_MOONSZ] = t.get("moon_size", 0.13)
    P[R.P_SOFT] = t.get("soft", 0.012)
    P[R.P_SELFGLOW] = t.get("selfglow", {"day": 0.15, "dawn": 0.35, "dusk": 0.55, "night": 1.1, "nether": 0.5,
                                         "end": 0.4}.get(time, 0.15))
    return P
