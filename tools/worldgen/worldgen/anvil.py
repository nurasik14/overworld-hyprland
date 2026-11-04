"""Read the user's own saves: Anvil region files, both the pre-1.18 and the current chunk format.

Everything here opens files read-only. Region files are read directly from ~/.minecraft/saves/ and nothing is
written there. Supported chunk layouts:

* DataVersion >= 2844 (1.18+): root ``sections[]`` with ``block_states{palette,data}``, ``biomes{palette,data}``.
* DataVersion < 2844 (e.g. 2567 = 1.16.5): ``Level.Sections[]`` with ``Palette``/``BlockStates``, ``Level.Biomes``.
"""
from __future__ import annotations

import math
import os
import struct
import zlib
from pathlib import Path

import numpy as np

from . import nbt
from . import render as R
from .blocks import Registry, state_key
from .paths import SAVES
from .world import World, _colormap, blur_tint

SECTION = 16

# Biome climate (temperature, downfall), from minecraft.wiki/w/Biome. Unknown names fall back to plains.
BIOME_CLIMATE = {
    "plains": (0.8, 0.4), "sunflower_plains": (0.8, 0.4), "snowy_plains": (0.0, 0.5), "ice_spikes": (0.0, 0.5),
    "desert": (2.0, 0.0), "swamp": (0.8, 0.9), "mangrove_swamp": (0.8, 0.9), "forest": (0.7, 0.8),
    "flower_forest": (0.7, 0.8), "birch_forest": (0.6, 0.6), "dark_forest": (0.7, 0.8), "pale_garden": (0.7, 0.8),
    "old_growth_birch_forest": (0.6, 0.6), "old_growth_pine_taiga": (0.3, 0.8), "old_growth_spruce_taiga": (0.25, 0.8),
    "taiga": (0.25, 0.8), "snowy_taiga": (-0.5, 0.4), "savanna": (2.0, 0.0), "savanna_plateau": (2.0, 0.0),
    "windswept_hills": (0.2, 0.3), "windswept_gravelly_hills": (0.2, 0.3), "windswept_forest": (0.2, 0.3),
    "windswept_savanna": (2.0, 0.0), "jungle": (0.95, 0.9), "sparse_jungle": (0.95, 0.8), "bamboo_jungle": (0.95, 0.9),
    "badlands": (2.0, 0.0), "eroded_badlands": (2.0, 0.0), "wooded_badlands": (2.0, 0.0), "meadow": (0.5, 0.8),
    "cherry_grove": (0.5, 0.8), "grove": (-0.2, 0.8), "snowy_slopes": (-0.3, 0.9), "frozen_peaks": (-0.7, 0.9),
    "jagged_peaks": (-0.7, 0.9), "stony_peaks": (1.0, 0.3), "river": (0.5, 0.5), "frozen_river": (0.0, 0.5),
    "beach": (0.8, 0.4), "snowy_beach": (0.05, 0.3), "stony_shore": (0.2, 0.3), "warm_ocean": (0.5, 0.5),
    "lukewarm_ocean": (0.5, 0.5), "deep_lukewarm_ocean": (0.5, 0.5), "ocean": (0.5, 0.5), "deep_ocean": (0.5, 0.5),
    "cold_ocean": (0.5, 0.5), "deep_cold_ocean": (0.5, 0.5), "frozen_ocean": (0.0, 0.5), "deep_frozen_ocean": (0.5, 0.5),
    "mushroom_fields": (0.9, 1.0), "dripstone_caves": (0.8, 0.4), "lush_caves": (0.5, 0.5), "deep_dark": (0.8, 0.4),
}
# Biomes whose colours are fixed in the game's code rather than read from the colormaps.
BIOME_GRASS = {"swamp": 0x6A7039, "mangrove_swamp": 0x6A7039, "badlands": 0x90814D, "eroded_badlands": 0x90814D,
               "wooded_badlands": 0x90814D, "cherry_grove": 0xB6DB61, "pale_garden": 0x778272}
BIOME_FOLIAGE = {"swamp": 0x6A7039, "mangrove_swamp": 0x8DB127, "badlands": 0x9E814D, "eroded_badlands": 0x9E814D,
                 "wooded_badlands": 0x9E814D, "cherry_grove": 0xB6DB61, "pale_garden": 0x878D76}
BIOME_WATER = {"swamp": 0x617B64, "mangrove_swamp": 0x3A7A6A, "meadow": 0x0E4ECF, "cherry_grove": 0x5DB7EF,
               "warm_ocean": 0x43D5EE, "lukewarm_ocean": 0x45ADF2, "deep_lukewarm_ocean": 0x45ADF2,
               "cold_ocean": 0x3D57D6, "deep_cold_ocean": 0x3D57D6, "snowy_taiga": 0x3D57D6, "snowy_beach": 0x3D57D6,
               "frozen_ocean": 0x3938C9, "deep_frozen_ocean": 0x3938C9, "frozen_river": 0x3938C9, "snowy_plains": 0x3938C9}

# Old numeric biome ids, for the pre-1.18 worlds. minecraft.wiki/w/Biome/ID, keys are 1.16 ids, values modern names.
OLD_BIOMES = {
    0: "ocean", 1: "plains", 2: "desert", 3: "windswept_hills", 4: "forest", 5: "taiga", 6: "swamp", 7: "river",
    10: "frozen_ocean", 11: "frozen_river", 12: "snowy_plains", 14: "mushroom_fields", 16: "beach", 18: "forest",
    19: "taiga", 21: "jungle", 22: "jungle", 23: "sparse_jungle", 24: "deep_ocean", 25: "stony_shore",
    26: "snowy_beach", 27: "birch_forest", 28: "birch_forest", 29: "dark_forest", 30: "snowy_taiga", 31: "snowy_taiga",
    32: "old_growth_pine_taiga", 33: "old_growth_pine_taiga", 34: "windswept_forest", 35: "savanna",
    36: "savanna_plateau", 37: "badlands", 38: "wooded_badlands", 39: "badlands", 44: "warm_ocean", 45: "lukewarm_ocean",
    46: "cold_ocean", 47: "deep_lukewarm_ocean", 48: "deep_lukewarm_ocean", 49: "deep_cold_ocean", 50: "deep_frozen_ocean",
    129: "sunflower_plains", 130: "desert", 131: "windswept_gravelly_hills", 132: "flower_forest", 133: "taiga",
    134: "swamp", 140: "ice_spikes", 149: "jungle", 155: "old_growth_birch_forest", 156: "old_growth_birch_forest",
    157: "dark_forest", 158: "snowy_taiga", 160: "old_growth_spruce_taiga", 161: "old_growth_spruce_taiga",
    162: "windswept_gravelly_hills", 163: "windswept_savanna", 164: "windswept_savanna", 165: "eroded_badlands",
    168: "bamboo_jungle", 169: "bamboo_jungle",
}


def level_info(save: str | os.PathLike) -> dict:
    """Spawn, player position and identity from level.dat, for both layouts of the spawn data."""
    path = Path(save)
    data = nbt.read_gzip_file(path / "level.dat")["Data"]
    spawn = data.get("spawn")
    if spawn and "pos" in spawn:
        sx, sy, sz = (int(v) for v in spawn["pos"][:3])
    else:
        sx, sy, sz = int(data.get("SpawnX", 0)), int(data.get("SpawnY", 64)), int(data.get("SpawnZ", 0))
    player = data.get("Player") or {}
    pos = player.get("Pos")
    return dict(
        name=data.get("LevelName", path.name), folder=path.name, version=int(data.get("DataVersion", 0)),
        spawn=(sx, sy, sz), player=tuple(float(v) for v in pos) if pos is not None and len(pos) == 3 else None,
        player_dim=str(player.get("Dimension", "")), day_time=int(data.get("DayTime", 0)),
    )


def region_dir(save: str | os.PathLike, dimension: str = "overworld") -> Path:
    sub = {"overworld": "region", "nether": "DIM-1/region", "end": "DIM1/region"}[dimension]
    return Path(save) / sub


def _read_chunk(region_bytes: bytes, index: int) -> dict | None:
    off = struct.unpack_from(">I", region_bytes, index * 4)[0]
    sector, count = off >> 8, off & 255
    if sector == 0 or count == 0:
        return None
    pos = sector * 4096
    if pos + 5 > len(region_bytes):
        return None
    length, comp = struct.unpack_from(">IB", region_bytes, pos)
    payload = region_bytes[pos + 5 : pos + 4 + length]
    if comp == 2:
        raw = zlib.decompress(payload)
    elif comp == 1:
        import gzip

        raw = gzip.decompress(payload)
    elif comp == 3:
        raw = payload
    else:  # 4 = LZ4, 127 = custom: not used by these saves; skip the chunk rather than fail the world.
        return None
    return nbt.parse(raw)


def _unpack(longs: np.ndarray, bits: int, count: int, spanning: bool) -> np.ndarray:
    """Unpack the packed palette indices of a section."""
    arr = np.asarray(longs).astype(np.uint64)
    if spanning:  # before 1.16 entries crossed long boundaries; kept so older saves still decode
        idx = np.arange(count, dtype=np.uint64) * np.uint64(bits)
        lo = idx // np.uint64(64)
        sh = idx % np.uint64(64)
        out = arr[lo.astype(np.int64)] >> sh
        cross = (sh + np.uint64(bits)) > np.uint64(64)
        if cross.any():
            hi = np.minimum(lo + np.uint64(1), np.uint64(arr.size - 1)).astype(np.int64)
            out = np.where(cross, out | (arr[hi] << (np.uint64(64) - sh)), out)
        return (out & np.uint64((1 << bits) - 1)).astype(np.int32)
    per = 64 // bits
    need = int(math.ceil(count / per))
    arr = arr[:need]
    shifts = np.arange(per, dtype=np.uint64) * np.uint64(bits)
    mask = np.uint64((1 << bits) - 1)
    vals = (arr[:, None] >> shifts[None, :]) & mask
    return vals.reshape(-1)[:count].astype(np.int32)


def _palette_ids(reg: Registry, palette: list, cache: dict) -> np.ndarray:
    ids = np.zeros(len(palette), dtype=np.uint16)
    for i, entry in enumerate(palette):
        name = entry.get("Name", "minecraft:air").removeprefix("minecraft:")
        props = entry.get("Properties") or None
        key = state_key(name, props)
        v = cache.get(key)
        if v is None:
            v = reg.state(key)
            cache[key] = v
        ids[i] = v
    return ids


def load_region_area(save: str | os.PathLike, center_x: int, center_z: int, radius: int, *, dimension="overworld",
                     ymin: int = -64, ymax: int = 320, reg: Registry | None = None, log=None) -> World:
    """Build a World from the chunks in a square of ``radius`` blocks around (center_x, center_z)."""
    save = Path(save)
    reg = reg or Registry()
    rdir = region_dir(save, dimension)
    x0 = (center_x - radius) & ~15
    z0 = (center_z - radius) & ~15
    x1 = ((center_x + radius) | 15) + 1
    z1 = ((center_z + radius) | 15) + 1
    nx, nz = x1 - x0, z1 - z0
    ny = ymax - ymin
    blocks = np.zeros((nx, ny, nz), dtype=np.uint16)
    biome_names: dict[str, int] = {}
    biome_map = np.zeros((nx, nz), dtype=np.uint16)
    has_chunk = np.zeros((nx, nz), dtype=bool)
    cache: dict[str, int] = {}
    regions: dict[tuple[int, int], bytes | None] = {}
    loaded = 0
    skipped = 0
    for cx in range(x0 >> 4, x1 >> 4):
        for cz in range(z0 >> 4, z1 >> 4):
            rk = (cx >> 5, cz >> 5)
            if rk not in regions:
                path = rdir / f"r.{rk[0]}.{rk[1]}.mca"
                try:
                    with open(path, "rb") as f:
                        regions[rk] = f.read()
                except OSError:
                    regions[rk] = None
            data = regions[rk]
            if not data:
                skipped += 1
                continue
            try:
                chunk = _read_chunk(data, (cx & 31) + (cz & 31) * 32)
            except (zlib.error, ValueError, IndexError, struct.error):
                chunk = None
            if chunk is None:
                skipped += 1
                continue
            if _place_chunk(chunk, cx, cz, x0, z0, ymin, ymax, blocks, reg, cache, biome_names, biome_map, has_chunk):
                loaded += 1
            else:
                skipped += 1
    if log:
        log(f"{save.name}/{dimension}: {loaded} chunks loaded, {skipped} missing or not full, {len(reg.kind)} states")
    tg, tf, tw = _biome_tints(biome_map, biome_names)
    mode = {"overworld": R.MODE_OVERWORLD, "nether": R.MODE_NETHER, "end": R.MODE_END}[dimension]
    world = World(blocks, reg, tg, tf, tw, y0=ymin, x0=x0, z0=z0, mode=mode)
    world.meta["has_chunk"] = has_chunk
    world.meta["chunks"] = loaded
    return world.finish()


def _place_chunk(chunk, cx, cz, x0, z0, ymin, ymax, blocks, reg, cache, biome_names, biome_map, has_chunk) -> bool:
    level = chunk.get("Level")
    modern = "sections" in chunk
    status = str((chunk if modern else (level or {})).get("Status", "full")).removeprefix("minecraft:")
    # Chunks at the edge of the explored area may be half generated; those are terrain without features or light.
    if status not in ("full", "postprocessed", "spawn", "heightmaps", "fullchunk"):
        return False
    secs = chunk["sections"] if modern else (level or {}).get("Sections") or []
    px, pz = (cx << 4) - x0, (cz << 4) - z0
    if px < 0 or pz < 0 or px + 16 > blocks.shape[0] or pz + 16 > blocks.shape[2]:
        return False
    placed = False
    surface_biome = None
    for sec in secs:
        sy = int(sec.get("Y", sec.get("y", -999)))
        if sy == -999:
            continue
        y_base = (sy * 16) - ymin
        if y_base < 0 or y_base + 16 > blocks.shape[1]:
            continue
        if modern:
            bs = sec.get("block_states")
            if not bs or "palette" not in bs:
                continue
            palette, packed = bs["palette"], bs.get("data")
        else:
            palette, packed = sec.get("Palette"), sec.get("BlockStates")
            if palette is None:
                continue
        ids = _palette_ids(reg, palette, cache)
        if len(palette) == 1 or packed is None or len(packed) == 0:
            blocks[px:px + 16, y_base:y_base + 16, pz:pz + 16] = ids[0]
            placed = True
        else:
            bits = max(4, int(math.ceil(math.log2(len(palette))))) if len(palette) > 1 else 4
            idx = _unpack(packed, bits, 4096, spanning=False).reshape(16, 16, 16)  # [y, z, x]
            blocks[px:px + 16, y_base:y_base + 16, pz:pz + 16] = ids[idx].transpose(2, 0, 1)
            placed = True
        if modern and "biomes" in sec:
            b = sec["biomes"]
            pal = b.get("palette") or []
            if pal:
                # A section's biomes are a 4x4x4 cube; a surface estimate per quart column is plenty for tinting.
                if len(pal) == 1 or "data" not in b:
                    names = np.zeros((4, 4, 4), dtype=np.int32)
                else:
                    bbits = max(1, int(math.ceil(math.log2(len(pal)))))
                    names = _unpack(b["data"], bbits, 64, spanning=False).reshape(4, 4, 4)
                if sy >= 3 and (surface_biome is None or sy <= 7):  # Y 48..127: where the terrain surface usually is
                    surface_biome = (pal, names[2])
    if not placed:
        return False
    has_chunk[px:px + 16, pz:pz + 16] = True
    if modern and surface_biome is not None:
        pal, grid = surface_biome
        for qz in range(4):
            for qx in range(4):
                name = str(pal[int(grid[qz, qx])]).removeprefix("minecraft:")
                k = biome_names.setdefault(name, len(biome_names))
                biome_map[px + qx * 4:px + qx * 4 + 4, pz + qz * 4:pz + qz * 4 + 4] = k
    elif not modern and level is not None:
        raw = level.get("Biomes")
        if raw is not None and len(raw) >= 1024:
            ids = np.asarray(raw, dtype=np.int32)
            # 1024 entries: 4x4 per quart layer, 64 layers. Layer 16 is about Y 64.
            layer = ids[16 * 16 : 16 * 16 + 16].reshape(4, 4)
            for qz in range(4):
                for qx in range(4):
                    name = OLD_BIOMES.get(int(layer[qz, qx]), "plains")
                    k = biome_names.setdefault(name, len(biome_names))
                    biome_map[px + qx * 4:px + qx * 4 + 4, pz + qz * 4:pz + qz * 4 + 4] = k
    return True


def _biome_tints(biome_map: np.ndarray, biome_names: dict[str, int]):
    """Per-biome grass, foliage and water colours -> per-column tint maps, blended like the game's biome blend."""
    if not biome_names:
        biome_names = {"plains": 0}
    n = max(biome_names.values()) + 1
    grass_cm, foliage_cm = _colormap("grass"), _colormap("foliage")
    g = np.zeros((n, 3), dtype=np.uint8)
    f = np.zeros((n, 3), dtype=np.uint8)
    w = np.zeros((n, 3), dtype=np.uint8)

    def rgb(c):
        return (c >> 16 & 255, c >> 8 & 255, c & 255)

    for name, i in biome_names.items():
        temp, down = BIOME_CLIMATE.get(name, (0.8, 0.4))
        t = min(max(temp, 0.0), 1.0)
        d = min(max(down, 0.0), 1.0) * t
        x, y = int((1 - t) * 255), int((1 - d) * 255)
        g[i] = rgb(BIOME_GRASS[name]) if name in BIOME_GRASS else grass_cm[y, x]
        f[i] = rgb(BIOME_FOLIAGE[name]) if name in BIOME_FOLIAGE else foliage_cm[y, x]
        w[i] = rgb(BIOME_WATER.get(name, 0x3F76E4))
    return (blur_tint(g[biome_map], 4), blur_tint(f[biome_map], 4), blur_tint(w[biome_map], 4))


def list_saves() -> list[Path]:
    if not SAVES.exists():
        return []
    return sorted(p for p in SAVES.iterdir() if (p / "level.dat").exists())
