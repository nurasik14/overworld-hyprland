"""Rendering pipeline for one wallpaper plus index.json bookkeeping (safe when several renders finish at once)."""
from __future__ import annotations

import fcntl
import json
import os
import re
import tempfile
import time as _time
from pathlib import Path

import numpy as np
from PIL import Image

from . import render as R
from . import scenes, sky
from .paths import WALLPAPERS
from .world import Camera, World, post, render, save_png

MODE_OF_TIME = {"day": "light", "dawn": "light", "dusk": "dark", "night": "dark"}
THUMB_SIZE = (320, 180)
TIME_LABEL = {"day": "Day", "dawn": "Dawn", "dusk": "Dusk", "night": "Night"}


def sky_for(world: World, shot: scenes.Shot, time: str, view=True) -> np.ndarray:
    """Parameter vector for a shot at a time of day. Dimensions without a sun use their fixed presets."""
    preset = {R.MODE_NETHER: "nether", R.MODE_END: "end"}.get(world.mode, time)
    key = time if time in shot.fog else shot.times[0]
    return sky.params(
        preset,
        view=(shot.yaw, shot.pitch) if view else None,
        sun_az=shot.sun_az[key] + shot.yaw,
        sun_el=shot.sun_el[key],
        key_az=shot.key_az[key] + shot.yaw if key in shot.key_az else None,
        key_el=shot.key_el.get(key),
        fog_dist=shot.fog[key],
        mode=world.mode,
        cloud_offset=shot.cloud_offset,
        overrides=shot.overrides.get(key),
    )


def render_wallpaper(world: World, shot: scenes.Shot, time: str, out: str | os.PathLike, *, width=1920, height=1080,
                     ss=2, grade=None) -> dict:
    t0 = _time.time()
    P = sky_for(world, shot, time)
    rgb, _, _ = render(world, shot.camera(), P, width, height, ss)
    kw = {} if grade is None else dict(grade=grade)
    save_png(post(rgb, calm=height >= 1000, **kw), out)
    return dict(seconds=round(_time.time() - t0, 1))


def write_thumb(path: str | os.PathLike, thumb_path: str | os.PathLike) -> None:
    img = Image.open(path).convert("RGB").resize(THUMB_SIZE, Image.BILINEAR)
    Path(thumb_path).parent.mkdir(parents=True, exist_ok=True)
    img.save(thumb_path, compress_level=9)


def _index_path() -> Path:
    return WALLPAPERS / "index.json"


def rel_file(path: Path) -> str:
    """Path as stored in index.json: relative to assets/wallpapers/ when inside it, else absolute."""
    p = Path(path).resolve()
    try:
        return str(p.relative_to(WALLPAPERS.resolve()))
    except ValueError:
        return str(p)


def index_update(entries: list[dict]) -> None:
    """Merge entries into index.json by file name, under a lock, with an atomic replace."""
    WALLPAPERS.mkdir(parents=True, exist_ok=True)
    lock_path = WALLPAPERS / ".index.lock"
    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        idx = _index_path()
        current = json.loads(idx.read_text()) if idx.exists() else []
        by_file = {e["file"]: e for e in current}
        for e in entries:
            by_file[e["file"]] = e
        merged = sorted(by_file.values(), key=lambda e: e["file"])
        fd, tmp = tempfile.mkstemp(dir=WALLPAPERS, prefix=".index-", suffix=".tmp")
        with os.fdopen(fd, "w") as f:
            json.dump(merged, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, idx)


def next_number(mode: str, start: int = 50) -> int:
    """Next free NN prefix for generated worlds. Numbers below 50 belong to the shipped catalogue."""
    used = set()
    for sub in ("light", "dark"):
        d = WALLPAPERS / sub
        if d.exists():
            for f in d.iterdir():
                m = re.match(r"(\d+)-", f.name)
                if m:
                    used.add(int(m.group(1)))
    n = start
    while n in used:
        n += 1
    return n


def make_entry(path: Path, *, mode, scene, time, title, seed, world=None, thumb=None) -> dict:
    return dict(
        file=rel_file(path), mode=mode, scene=scene, time=time, title=title, seed=seed, world=world,
        thumb=rel_file(thumb) if thumb else None,
    )
