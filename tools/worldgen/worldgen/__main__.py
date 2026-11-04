"""Command line: ``uv run --project tools/worldgen python -m worldgen <command>``. See docs/WORLDGEN.md."""
from __future__ import annotations

import argparse
import json
import random
import sys
import time as _time
from pathlib import Path

from . import catalog, scenes
from .paths import WALLPAPERS
from .world import set_threads


def log(msg: str) -> None:
    print(f"[{_time.strftime('%H:%M:%S')}] {msg}", file=sys.stderr, flush=True)


def _slug(text: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in text).strip("-").replace("--", "-")


def cmd_new(a) -> int:
    """One new procedural world: what the Select World screen's "Create New World" runs."""
    scene = a.scene or random.choice([k for k in scenes.SCENES])
    if scene not in scenes.SCENES:
        print(f"unknown scene {scene!r}; known: {', '.join(scenes.SCENES)}", file=sys.stderr)
        return 2
    fixed_night = scene in ("nether", "the-end")
    time = "night" if fixed_night else a.time
    mode = "dark" if fixed_night else a.mode
    if time is None:
        time = "night" if mode == "dark" else "day"
    if mode is None:
        mode = catalog.MODE_OF_TIME[time]
    if time not in catalog.MODE_OF_TIME:
        print(f"unknown time {time!r}", file=sys.stderr)
        return 2
    seed = a.seed if a.seed is not None else random.randrange(1, 2_000_000_000)
    info = scenes.SCENES[scene]
    if a.out:
        out = Path(a.out).expanduser()
    else:
        nn = catalog.next_number(mode)
        out = WALLPAPERS / mode / f"{nn:02d}-{scene}-{time}.png"
    t0 = _time.time()
    world, shot = info["fn"](seed)
    log(f"world {scene} seed {seed} generated in {_time.time() - t0:.1f}s")
    catalog.render_wallpaper(world, shot, time, out, ss=a.ss)
    log(f"rendered in {_time.time() - t0:.1f}s total")
    thumb = WALLPAPERS / "thumbs" / (out.stem + ".png")
    catalog.write_thumb(out, thumb)
    title = f"{info['title']} (seed {seed})"
    entry = catalog.make_entry(out, mode=mode, scene=scene, time=time, title=title, seed=seed, thumb=thumb)
    if not a.no_index:
        catalog.index_update([entry])
    print(out.resolve())
    return 0


def cmd_catalog(a) -> int:
    """The shipped set: every scene at every time of day. Re-running skips what exists unless --force."""
    only = set(a.scene) if a.scene else None
    entries = []
    for key, info in scenes.SCENES.items():
        if only and key not in only:
            continue
        seed = info["seed"]
        world = shot = None
        for time in ("day", "dawn", "dusk", "night"):
            fixed = key in ("nether", "the-end")
            if fixed and time != "night":
                continue
            mode = catalog.MODE_OF_TIME[time]
            # Dawn and dusk stay out of the mode folders: the shell lists those folders and defaults to their first
            # file. index.json lists everything, and fx-world's cycle finds the variants through it.
            folder = "variants" if time in ("dawn", "dusk") else mode
            out = WALLPAPERS / folder / f"{info['nn']:02d}-{key}-{time}.png"
            thumb = WALLPAPERS / "thumbs" / (out.stem + ".png")
            title = info["title"] if fixed else f"{info['title']} ({catalog.TIME_LABEL[time]})"
            entries.append(catalog.make_entry(out, mode=mode, scene=key, time=time, title=title, seed=seed, thumb=thumb))
            if out.exists() and not a.force:
                continue
            if world is None:
                t0 = _time.time()
                world, shot = info["fn"](seed)
                log(f"{key}: generated in {_time.time() - t0:.1f}s")
            r = catalog.render_wallpaper(world, shot, time, out, ss=a.ss)
            catalog.write_thumb(out, thumb)
            log(f"{key} {time}: {r['seconds']}s -> {out}")
        del world, shot
    catalog.index_update(entries)
    return 0


SAVE_NUMBERS = {"New World": 20, "New World (1)": 21, "New World (2)": 22, "SpeedrunHunt": 23, "SpeedrunHunt (1)": 24}
# Views picked by eye where the search missed the best thing in a world: (x, y, z, yaw, pitch) in game coordinates.
SAVE_CAMERAS = {"SpeedrunHunt (1)": (69, 79, -11, 218.0, 3.0)}  # the village by the lake, under the cherry hill


def cmd_saves(a) -> int:
    """Wallpapers of the user's own worlds, framed automatically around each world's spawn."""
    from . import anvil, compose
    from .blocks import Registry

    entries = []
    for save in anvil.list_saves():
        if a.save and save.name not in a.save:
            continue
        info = anvil.level_info(save)
        nn = SAVE_NUMBERS.get(save.name, 29)
        slug = _slug(save.name)
        t0 = _time.time()
        sx, _, sz = info["spawn"]
        log(f"{save.name}: DataVersion {info['version']}, spawn {info['spawn']}, player {info['player']}")
        modern = info["version"] >= 2844
        ymin, ymax = (-16, 288) if modern else (0, 256)
        world = anvil.load_region_area(save, sx, sz, a.radius, ymin=ymin, ymax=ymax, log=log)
        if world.meta["chunks"] < 30:
            log(f"{save.name}: only {world.meta['chunks']} chunks near spawn, skipping")
            continue
        log(f"  loaded in {_time.time() - t0:.1f}s")
        seed = sum(map(ord, slug))
        if save.name in SAVE_CAMERAS:
            x, y, z, yaw, pitch = SAVE_CAMERAS[save.name]
            shot = compose.fixed_camera(world, x - world.x0, y - world.y0, z - world.z0, yaw, pitch, seed=seed, log=log)
        else:
            shot = compose.search_camera(world, sx - world.x0, sz - world.z0, spread=a.spread, seed=seed, log=log)
        for time in ("day", "night"):
            mode = catalog.MODE_OF_TIME[time]
            out = WALLPAPERS / mode / f"{nn:02d}-{slug}-{time}.png"
            thumb = WALLPAPERS / "thumbs" / (out.stem + ".png")
            r = catalog.render_wallpaper(world, shot, time, out, ss=a.ss)
            catalog.write_thumb(out, thumb)
            log(f"  {time}: {r['seconds']}s -> {out}")
            entries.append(catalog.make_entry(out, mode=mode, scene=f"save:{slug}", time=time, title=f"{save.name} — spawn",
                                              seed=None, world=save.name, thumb=thumb))
        del world
        catalog.index_update(entries)
    return 0


def cmd_dims(a) -> int:
    """Nether and End wallpapers from the user's own dimensions, where that world has been there."""
    from . import anvil, compose

    entries = []
    for save, dim, cx, cz in a.targets:
        path = Path(anvil.SAVES) / save
        info = anvil.level_info(path)
        ymin, ymax = (0, 128) if dim == "nether" else (0, 256)
        world = anvil.load_region_area(path, cx, cz, a.radius, dimension=dim, ymin=ymin, ymax=ymax, log=log)
        if world.meta["chunks"] < 30:
            log(f"{save}/{dim}: only {world.meta['chunks']} chunks, skipping")
            continue
        shot = compose.search_camera(world, cx - world.x0, cz - world.z0, spread=a.spread, seed=sum(map(ord, save + dim)), log=log)
        slug = _slug(save) + "-" + dim
        nn = 25 if dim == "nether" else 26
        out = WALLPAPERS / "dark" / f"{nn:02d}-{slug}-night.png"
        thumb = WALLPAPERS / "thumbs" / (out.stem + ".png")
        r = catalog.render_wallpaper(world, shot, "night", out, ss=a.ss)
        catalog.write_thumb(out, thumb)
        log(f"  {r['seconds']}s -> {out}")
        label = "The Nether" if dim == "nether" else "The End"
        entries.append(catalog.make_entry(out, mode="dark", scene=f"save:{slug}", time="night", title=f"{save} — {label}",
                                          seed=None, world=save, thumb=thumb))
        del world
    catalog.index_update(entries)
    return 0


def _parse_target(text: str):
    save, dim, x, z = text.rsplit(":", 3)
    return save, dim, int(x), int(z)


def main(argv=None) -> int:
    set_threads(8)
    ap = argparse.ArgumentParser(prog="worldgen")
    sub = ap.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("new", help="render one new procedural world")
    n.add_argument("--seed", type=int)
    n.add_argument("--scene")
    n.add_argument("--time")
    n.add_argument("--mode", choices=["light", "dark"])
    n.add_argument("--out")
    n.add_argument("--ss", type=int, default=2)
    n.add_argument("--no-index", action="store_true")
    n.set_defaults(func=cmd_new)
    c = sub.add_parser("catalog", help="render the shipped wallpaper set")
    c.add_argument("--scene", action="append")
    c.add_argument("--force", action="store_true")
    c.add_argument("--ss", type=int, default=2)
    c.set_defaults(func=cmd_catalog)
    s = sub.add_parser("saves", help="wallpapers of the user's worlds")
    s.add_argument("--save", action="append")
    s.add_argument("--radius", type=int, default=320)
    s.add_argument("--spread", type=int, default=90)
    s.add_argument("--ss", type=int, default=2)
    s.set_defaults(func=cmd_saves)
    d = sub.add_parser("dims", help="Nether/End wallpapers of the user's worlds")
    d.add_argument("targets", nargs="+", type=_parse_target, help="SAVE:nether|end:X:Z")
    d.add_argument("--radius", type=int, default=224)
    d.add_argument("--spread", type=int, default=70)
    d.add_argument("--ss", type=int, default=2)
    d.set_defaults(func=cmd_dims)
    p = sub.add_parser("panorama", help="cube faces, strip, lock frames")
    p.add_argument("--seed", type=int, default=12)
    p.set_defaults(func=lambda a: (__import__("worldgen.panorama", fromlist=["render_all"]).render_all(a.seed, log=log), 0)[1])
    w = sub.add_parser("wordmark", help="OVERWORLD lettering")
    w.set_defaults(func=lambda a: (__import__("worldgen.wordmark", fromlist=["render_all"]).render_all(log=log), 0)[1])
    a = ap.parse_args(argv)
    return a.func(a) or 0


if __name__ == "__main__":
    raise SystemExit(main())
