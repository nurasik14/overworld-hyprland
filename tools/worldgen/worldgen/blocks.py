"""Block registry: compiles real Minecraft blockstates + block models into flat arrays for the ray marcher.

A "state" is a string such as ``minecraft:oak_stairs[facing=east,half=bottom,shape=straight]``; each distinct
string gets a uint16 id. Compiling a state resolves the blockstate JSON (variants or multipart), the model
parent chain and the element list into textured rectangles ("quads"). Full cubes are also indexed per face so
the marcher can reach them in O(1); anything else is intersected quad by quad.

Face order everywhere: 0 down (-Y), 1 up (+Y), 2 north (-Z), 3 south (+Z), 4 west (-X), 5 east (+X).
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from .paths import MC_DIR

FACES = ["down", "up", "north", "south", "west", "east"]
NORMALS = {
    "down": (0, -1, 0), "up": (0, 1, 0), "north": (0, 0, -1),
    "south": (0, 0, 1), "west": (-1, 0, 0), "east": (1, 0, 0),
}

# kinds
AIR, CUBE, MODEL, WATER, LAVA = 0, 1, 2, 3, 4
# flags
F_OPAQUE = 1        # full opaque cube: blocks light, counts for ambient occlusion
F_WATERLOGGED = 2   # voxel also holds water
F_RANDROT = 4       # top texture randomly rotated per position, like the game's variant lists
F_NOSHADOW = 8      # thin plant: does not cast a sun shadow
F_TRANSLUCENT = 16  # partial alpha, composited instead of alpha-tested
F_CULLSAME = 32     # glass-like: no face between two identical neighbours
F_LEAVES = 64       # cutout cube

# tint ids
T_NONE, T_GRASS, T_FOLIAGE, T_WATER = 0, 1, 2, 3
FIXED_TINTS = {
    "birch": 0x80A755, "spruce": 0x619961, "mangrove": 0x92C648, "lily_pad": 0x208030,
    "stem": 0xE0C71C, "redstone": 0xB01010,
}

GRASS_TINTED = {
    "grass_block", "short_grass", "grass", "tall_grass", "fern", "large_fern", "potted_fern", "sugar_cane",
    "bush", "pink_petals", "wildflowers",
}
FOLIAGE_TINTED = {
    "oak_leaves", "jungle_leaves", "acacia_leaves", "dark_oak_leaves", "vine",
}
FIXED_TINTED = {
    "birch_leaves": "birch", "spruce_leaves": "spruce", "mangrove_leaves": "mangrove", "lily_pad": "lily_pad",
    "melon_stem": "stem", "pumpkin_stem": "stem", "attached_melon_stem": "stem", "attached_pumpkin_stem": "stem",
    "redstone_wire": "redstone",
}

# name -> light level (vanilla values; minecraft.wiki/w/Light#Light-emitting_blocks)
EMISSION = {
    "glowstone": 15, "sea_lantern": 15, "lantern": 15, "jack_o_lantern": 15, "shroomlight": 15, "beacon": 15,
    "lava": 15, "fire": 15, "ochre_froglight": 15, "verdant_froglight": 15, "pearlescent_froglight": 15,
    "end_gateway": 15, "end_portal": 15, "conduit": 15, "torch": 14, "wall_torch": 14, "end_rod": 14,
    "furnace_lit": 13, "soul_lantern": 10, "soul_torch": 10, "soul_wall_torch": 10, "soul_fire": 10,
    "crying_obsidian": 10, "nether_portal": 11, "enchanting_table": 7, "ender_chest": 7, "glow_lichen": 7,
    "amethyst_cluster": 5, "magma_block": 3, "cave_vines_lit": 14, "redstone_torch_lit": 7, "copper_bulb_lit": 15,
    "campfire_lit": 15, "soul_campfire_lit": 10, "redstone_lamp_lit": 15, "sea_pickle": 6, "candle_lit": 6,
    "brown_mushroom": 1, "dragon_egg": 1, "sculk_sensor": 1, "large_amethyst_bud": 4, "medium_amethyst_bud": 2,
    "small_amethyst_bud": 1, "firefly_bush": 2, "torchflower": 0, "open_eyeblossom": 0,
}
LIT_BLOCKS = {
    "furnace": "furnace_lit", "blast_furnace": "furnace_lit", "smoker": "furnace_lit",
    "campfire": "campfire_lit", "soul_campfire": "soul_campfire_lit", "redstone_lamp": "redstone_lamp_lit",
    "redstone_torch": "redstone_torch_lit", "redstone_wall_torch": "redstone_torch_lit",
    "cave_vines": "cave_vines_lit", "cave_vines_plant": "cave_vines_lit", "candle": "candle_lit",
    "copper_bulb": "copper_bulb_lit",
}
# Shown at full brightness (the visible surface is the light source). Everything else only lights its neighbours.
SELF_LIT = {
    "glowstone", "sea_lantern", "jack_o_lantern", "shroomlight", "lava", "fire", "soul_fire", "ochre_froglight",
    "verdant_froglight", "pearlescent_froglight", "torch", "wall_torch", "soul_torch", "soul_wall_torch",
    "lantern", "soul_lantern", "end_rod", "nether_portal", "magma_block", "crying_obsidian", "beacon",
    "campfire", "soul_campfire", "redstone_lamp", "cave_vines", "cave_vines_plant", "end_portal", "end_gateway",
}
ALWAYS_WATERLOGGED = {"kelp", "kelp_plant", "seagrass", "tall_seagrass", "bubble_column"}
AIR_NAMES = {"air", "cave_air", "void_air", "structure_void", "barrier", "light", "moving_piston"}
THIN_PLANTS = {
    "short_grass", "grass", "tall_grass", "fern", "large_fern", "dandelion", "poppy", "blue_orchid", "allium",
    "azure_bluet", "red_tulip", "orange_tulip", "white_tulip", "pink_tulip", "oxeye_daisy", "cornflower",
    "lily_of_the_valley", "sunflower", "lilac", "rose_bush", "peony", "dead_bush", "seagrass", "tall_seagrass",
    "pink_petals", "wildflowers", "torch", "wall_torch", "soul_torch", "soul_wall_torch", "red_mushroom",
    "brown_mushroom", "crimson_roots", "warped_roots", "nether_sprouts", "crimson_fungus", "warped_fungus",
    "fire", "soul_fire", "vine", "lily_pad", "kelp", "kelp_plant", "bush",
    "leaf_litter", "firefly_bush", "torchflower", "wheat", "carrots", "potatoes", "beetroots", "redstone_wire",
    "rail", "powered_rail", "detector_rail", "activator_rail", "ladder", "tripwire", "cobweb", "nether_wart",
}
# Blocks with no model JSON elements because the game draws them as block entities. name -> (texture, box in 1/16).
ENTITY_BOXES = {
    "chest": ("oak_planks", (1, 0, 1, 15, 14, 15)),
    "trapped_chest": ("oak_planks", (1, 0, 1, 15, 14, 15)),
    "ender_chest": ("obsidian", (1, 0, 1, 15, 14, 15)),
    "white_bed": ("white_wool", (0, 0, 0, 16, 9, 16)),
    "red_bed": ("red_wool", (0, 0, 0, 16, 9, 16)),
    "blue_bed": ("blue_wool", (0, 0, 0, 16, 9, 16)),
    "shulker_box": ("purpur_block", (0, 0, 0, 16, 16, 16)),
}
RENAMES = {"grass": "short_grass", "grass_path": "dirt_path", "sign": "oak_sign", "wall_sign": "oak_wall_sign"}
DROPPED_PROPS = {"waterlogged", "distance", "persistent", "power", "stage", "moisture", "hatch"}


def parse_state(state: str) -> tuple[str, dict]:
    """``minecraft:foo[a=b,c=d]`` -> ("foo", {"a": "b", "c": "d"})."""
    name, props = state, {}
    if "[" in state:
        name, rest = state.split("[", 1)
        for pair in rest.rstrip("]").split(","):
            if "=" in pair:
                k, v = pair.split("=", 1)
                props[k] = v
    return name.removeprefix("minecraft:"), props


def state_key(name: str, props: dict | None = None) -> str:
    if not props:
        return f"minecraft:{name}"
    return f"minecraft:{name}[" + ",".join(f"{k}={props[k]}" for k in sorted(props)) + "]"


def _rot_x(p, deg):
    a = math.radians(deg)
    c, s = round(math.cos(a), 10), round(math.sin(a), 10)
    return (p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c)


def _rot_y(p, deg):
    a = math.radians(deg)
    c, s = round(math.cos(a), 10), round(math.sin(a), 10)
    return (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)


def _rot_z(p, deg):
    a = math.radians(deg)
    c, s = round(math.cos(a), 10), round(math.sin(a), 10)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])


def _face_vertices(face, fr, to):
    x0, y0, z0 = fr
    x1, y1, z1 = to
    return {
        "down": [(x0, y0, z1), (x0, y0, z0), (x1, y0, z0), (x1, y0, z1)],
        "up": [(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)],
        "north": [(x1, y1, z0), (x1, y0, z0), (x0, y0, z0), (x0, y1, z0)],
        "south": [(x0, y1, z1), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1)],
        "west": [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)],
        "east": [(x1, y1, z1), (x1, y0, z1), (x1, y0, z0), (x1, y1, z0)],
    }[face]


def _default_uv(face, fr, to):
    x0, y0, z0 = fr
    x1, y1, z1 = to
    return {
        "down": (x0, 1 - z1, x1, 1 - z0),
        "up": (x0, z0, x1, z1),
        "north": (1 - x1, 1 - y1, 1 - x0, 1 - y0),
        "south": (x0, 1 - y1, x1, 1 - y0),
        "west": (z0, 1 - y1, z1, 1 - y0),
        "east": (1 - z1, 1 - y1, 1 - z0, 1 - y0),
    }[face]


def _locked_uv(n, p):
    """Position-derived UV used for uvlock: the texture stays aligned to the world when the model rotates."""
    x, y, z = p
    ax = max(range(3), key=lambda i: abs(n[i]))
    if ax == 1:
        return (x, z) if n[1] > 0 else (x, 1 - z)
    if ax == 2:
        return (1 - x, 1 - y) if n[2] < 0 else (x, 1 - y)
    return (z, 1 - y) if n[0] < 0 else (1 - z, 1 - y)


def _load_texture(path: Path) -> np.ndarray:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if h > w:  # animation strip: first frame
        img = img.crop((0, 0, w, w))
    if img.size != (16, 16):
        img = img.resize((16, 16), Image.NEAREST)
    return np.asarray(img, dtype=np.uint8)


def _mip_chain(rgba: np.ndarray) -> np.ndarray:
    """5 mip levels, alpha-weighted so cutout edges do not pick up the transparent texels' colour."""
    out = np.zeros((5, 16, 16, 4), dtype=np.uint8)
    out[0] = rgba
    cur = rgba.astype(np.float32)
    for lod in range(1, 5):
        s = cur.shape[0] // 2
        a = cur[..., 3:4]
        prem = cur[..., :3] * a
        prem = (prem[0::2, 0::2] + prem[1::2, 0::2] + prem[0::2, 1::2] + prem[1::2, 1::2]) / 4
        al = (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4
        rgb = np.where(al > 0, prem / np.maximum(al, 1e-3), 0)
        cur = np.concatenate([rgb, al], axis=-1)
        out[lod, :s, :s] = np.clip(cur + 0.5, 0, 255).astype(np.uint8)
    return out


class Registry:
    def __init__(self, mc_dir: Path = MC_DIR, extra_textures: dict[str, np.ndarray] | None = None):
        self.mc = Path(mc_dir)
        self.extra_textures = extra_textures or {}
        self.ids: dict[str, int] = {}
        self.tex_ids: dict[str, int] = {}
        self.tex_mips: list[np.ndarray] = []
        self.tex_alpha: list[tuple[bool, bool]] = []  # (has_hole, has_partial)
        self.model_cache: dict[str, dict] = {}
        self.blockstate_cache: dict[str, dict | None] = {}
        self.quads: list[list[float]] = []
        self.qtex: list[int] = []
        self.qtint: list[int] = []
        self.kind: list[int] = []
        self.flags: list[int] = []
        self.opacity: list[int] = []
        self.emission: list[int] = []
        self.selflit: list[float] = []
        self.cube_q: list[list[int]] = []
        self.cube_o: list[list[int]] = []
        self.mq_start: list[int] = []
        self.mq_count: list[int] = []
        self.fixed_tints: list[tuple[float, float, float]] = []
        self.fixed_index: dict[str, int] = {}
        self.custom_boxes: dict[str, tuple] = {}
        self._tex("block/dirt")  # texture 0 is always valid
        self.id("air")

    # -- public ------------------------------------------------------------------------------------------------
    def id(self, name: str, **props) -> int:
        return self.state(state_key(name.removeprefix("minecraft:"), {k: str(v).lower() for k, v in props.items()}))

    def state(self, key: str) -> int:
        i = self.ids.get(key)
        if i is None:
            i = self._compile(key)
            self.ids[key] = i
        return i

    def add_box_block(self, name: str, textures: dict[str, str]) -> int:
        """A custom full cube, e.g. the wordmark's own-texture letters. ``textures``: face name or "all"."""
        self.custom_boxes[name] = textures
        return self.state(f"minecraft:{name}")

    def tables(self) -> dict:
        n_q = max(len(self.quads), 1)
        quads = np.zeros((n_q, 20), dtype=np.float32)
        if self.quads:
            quads[: len(self.quads)] = np.asarray(self.quads, dtype=np.float32)
        qtex = np.zeros(n_q, dtype=np.int32)
        qtint = np.zeros(n_q, dtype=np.int16)
        qtex[: len(self.qtex)] = self.qtex
        qtint[: len(self.qtint)] = self.qtint
        fixed = np.zeros((max(len(self.fixed_tints), 1), 3), dtype=np.float32)
        if self.fixed_tints:
            fixed[: len(self.fixed_tints)] = np.asarray(self.fixed_tints, dtype=np.float32)
        return dict(
            kind=np.asarray(self.kind, dtype=np.uint8),
            flags=np.asarray(self.flags, dtype=np.uint8),
            opacity=np.asarray(self.opacity, dtype=np.uint8),
            emission=np.asarray(self.emission, dtype=np.uint8),
            selflit=np.asarray(self.selflit, dtype=np.float32),
            cube_q=np.asarray(self.cube_q, dtype=np.int32),
            cube_o=np.asarray(self.cube_o, dtype=np.int32),
            mq_start=np.asarray(self.mq_start, dtype=np.int32),
            mq_count=np.asarray(self.mq_count, dtype=np.int32),
            quads=quads,
            qtex=qtex,
            qtint=qtint,
            fixed_tints=fixed,
            atlas=np.stack(self.tex_mips),
        )

    # -- textures ----------------------------------------------------------------------------------------------
    def _tex(self, ref: str) -> int:
        ref = ref.removeprefix("minecraft:")
        i = self.tex_ids.get(ref)
        if i is not None:
            return i
        if ref in self.extra_textures:
            rgba = self.extra_textures[ref]
        else:
            path = self.mc / "textures" / f"{ref}.png"
            if path.exists():
                rgba = _load_texture(path)
            else:  # the game's magenta/black "missing texture"
                rgba = np.zeros((16, 16, 4), dtype=np.uint8)
                rgba[..., 3] = 255
                rgba[:8, :8, 0] = rgba[:8, :8, 2] = 248
                rgba[8:, 8:, 0] = rgba[8:, 8:, 2] = 248
        i = len(self.tex_mips)
        self.tex_ids[ref] = i
        self.tex_mips.append(_mip_chain(rgba))
        a = rgba[..., 3]
        self.tex_alpha.append((bool((a < 128).any()), bool(((a > 8) & (a < 247)).any())))
        return i

    # -- models ------------------------------------------------------------------------------------------------
    def _model(self, ref: str) -> dict:
        ref = ref.removeprefix("minecraft:")
        if ref in self.model_cache:
            return self.model_cache[ref]
        path = self.mc / "models" / f"{ref}.json"
        m = json.loads(path.read_text()) if path.exists() else {}
        textures, elements, ao = {}, None, True
        if "parent" in m and not m["parent"].startswith("builtin/"):
            parent = self._model(m["parent"])
            textures.update(parent["textures"])
            elements = parent["elements"]
            ao = parent["ao"]
        textures.update(m.get("textures", {}))
        if "elements" in m:
            elements = m["elements"]
        if "ambientocclusion" in m:
            ao = m["ambientocclusion"]
        out = {"textures": textures, "elements": elements or [], "ao": ao}
        self.model_cache[ref] = out
        return out

    def _blockstate(self, name: str) -> dict | None:
        if name in self.blockstate_cache:
            return self.blockstate_cache[name]
        path = self.mc / "blockstates" / f"{name}.json"
        bs = json.loads(path.read_text()) if path.exists() else None
        self.blockstate_cache[name] = bs
        return bs

    @staticmethod
    def _resolve_texture(textures: dict, ref: str | None) -> str | None:
        seen = 0
        while ref and ref.startswith("#") and seen < 8:
            ref = textures.get(ref[1:])
            seen += 1
        return ref

    @staticmethod
    def _when_matches(when: dict, props: dict) -> bool:
        if "OR" in when:
            return any(Registry._when_matches(w, props) for w in when["OR"])
        if "AND" in when:
            return all(Registry._when_matches(w, props) for w in when["AND"])
        for k, v in when.items():
            if str(props.get(k, "false")) not in str(v).split("|"):
                return False
        return True

    def _pick_variants(self, name: str, props: dict) -> tuple[list[dict], bool]:
        """Models for this state, plus whether the game randomises this block's rotation."""
        bs = self._blockstate(name)
        if bs is None:
            return [], False
        if "multipart" in bs:
            out = []
            for part in bs["multipart"]:
                if "when" not in part or self._when_matches(part["when"], props):
                    apply = part["apply"]
                    out.append(apply[0] if isinstance(apply, list) else apply)
            return out, False
        variants = bs.get("variants", {})
        for key, value in variants.items():
            conds = dict(c.split("=", 1) for c in key.split(",") if "=" in c)
            if all(props.get(k) == v for k, v in conds.items()):
                if isinstance(value, list):
                    randrot = len(value) > 1 and len({v.get("y", 0) for v in value}) > 1
                    return [value[0]], randrot
                return [value], False
        # Property mismatch (older save, trimmed props): fall back to the first variant.
        if variants:
            value = next(iter(variants.values()))
            return [value[0] if isinstance(value, list) else value], False
        return [], False

    def _add_quad(self, verts, uvs, tex, tint, shade) -> int:
        v = np.asarray(verts, dtype=np.float64)
        eu = v[3] - v[0]
        ev = v[1] - v[0]
        lu2, lv2 = float(eu @ eu), float(ev @ ev)
        if lu2 < 1e-9 or lv2 < 1e-9:
            return -1
        n = np.cross(ev, eu)
        n = n / max(np.linalg.norm(n), 1e-9)
        uv0 = np.asarray(uvs[0], dtype=np.float64)
        du = np.asarray(uvs[3], dtype=np.float64) - uv0
        dv = np.asarray(uvs[1], dtype=np.float64) - uv0
        # Vanilla diffuse: top 1.0, bottom 0.5, north/south 0.8, east/west 0.6 (generalised for rotated quads).
        sh = 1.0
        if shade:
            sh = min(n[0] ** 2 * 0.6 + n[1] ** 2 * (3 + n[1]) / 4 + n[2] ** 2 * 0.8, 1.0)
        q = [*v[0], *(eu / lu2), *(ev / lv2), *n, *uv0, *du, *dv, float(n @ v[0]), sh]
        self.quads.append(q)
        self.qtex.append(tex)
        self.qtint.append(tint)
        return len(self.quads) - 1

    def _tint_for(self, name: str) -> int:
        if name in GRASS_TINTED:
            return T_GRASS
        if name in FOLIAGE_TINTED:
            return T_FOLIAGE
        if name in FIXED_TINTED:
            key = FIXED_TINTED[name]
            if key not in self.fixed_index:
                c = FIXED_TINTS[key]
                self.fixed_index[key] = len(self.fixed_tints) + 4
                self.fixed_tints.append(((c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255))
            return self.fixed_index[key]
        return T_NONE

    def _bake(self, name: str, variant: dict, cube_faces: dict) -> tuple[list[int], bool, bool]:
        """Bake one model variant. Returns quad ids, whether it is a single full cube, and the model's AO flag."""
        model = self._model(variant.get("model", ""))
        rx, ry = variant.get("x", 0), variant.get("y", 0)
        uvlock = variant.get("uvlock", False)
        tint_kind = self._tint_for(name)
        quads: list[int] = []
        elements = model["elements"]
        all_full = bool(elements)
        for el in elements:
            fr = [c / 16 for c in el["from"]]
            to = [c / 16 for c in el["to"]]
            if fr != [0, 0, 0] or to != [1, 1, 1] or "rotation" in el:
                all_full = False
        for eidx, el in enumerate(elements):
            fr = tuple(c / 16 for c in el["from"])
            to = tuple(c / 16 for c in el["to"])
            rot = el.get("rotation")
            for face, spec in el.get("faces", {}).items():
                texname = self._resolve_texture(model["textures"], spec.get("texture"))
                if not texname:
                    continue
                tex = self._tex(texname)
                verts = _face_vertices(face, fr, to)
                if rot:
                    verts = [self._rotate_element(p, rot) for p in verts]
                if rx or ry:
                    verts = [self._rotate_block(p, rx, ry) for p in verts]
                uv = spec.get("uv")
                u0, v0, u1, v1 = [c / 16 for c in uv] if uv else _default_uv(face, fr, to)
                corners = [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]
                shift = int(spec.get("rotation", 0)) // 90
                uvs = [corners[(i + shift) % 4] for i in range(4)]
                n = np.cross(np.subtract(verts[1], verts[0]), np.subtract(verts[3], verts[0]))
                if uvlock and (rx or ry):
                    ln = np.linalg.norm(n) or 1
                    uvs = [_locked_uv(n / ln, p) for p in verts]
                tint = tint_kind if "tintindex" in spec else T_NONE
                q = self._add_quad(verts, uvs, tex, tint, el.get("shade", True))
                if q < 0:
                    continue
                quads.append(q)
                if all_full:
                    # Direction after the variant's rotation decides which cube face slot this goes in.
                    nn = self.quads[q][9:12]
                    slot = self._normal_slot(nn)
                    cube_faces.setdefault(slot, []).append(q)
        return quads, all_full, model["ao"]

    @staticmethod
    def _normal_slot(n) -> int:
        ax = max(range(3), key=lambda i: abs(n[i]))
        if ax == 1:
            return 1 if n[1] > 0 else 0
        if ax == 2:
            return 3 if n[2] > 0 else 2
        return 5 if n[0] > 0 else 4

    @staticmethod
    def _rotate_element(p, rot):
        origin = [c / 16 for c in rot.get("origin", (8, 8, 8))]
        q = [p[i] - origin[i] for i in range(3)]
        axis = rot.get("axis")
        if axis is None:  # newer per-axis form
            for ax, fn in (("x", _rot_x), ("y", _rot_y), ("z", _rot_z)):
                if rot.get(ax):
                    q = list(fn(q, rot[ax]))
        else:
            angle = rot.get("angle", 0)
            if rot.get("rescale"):
                s = 1 / max(math.cos(math.radians(abs(angle))), 1e-3)
                for i, ax in enumerate("xyz"):
                    if ax != axis:
                        q[i] *= s
            q = list({"x": _rot_x, "y": _rot_y, "z": _rot_z}[axis](q, angle))
        return tuple(q[i] + origin[i] for i in range(3))

    @staticmethod
    def _rotate_block(p, rx, ry):
        q = (p[0] - 0.5, p[1] - 0.5, p[2] - 0.5)
        if rx:
            q = _rot_x(q, -rx)
        if ry:
            q = _rot_y(q, -ry)
        return (q[0] + 0.5, q[1] + 0.5, q[2] + 0.5)

    # -- compile -----------------------------------------------------------------------------------------------
    def _register(self, kind, flags, opacity, emission, selflit, cube_q=None, cube_o=None, start=0, count=0) -> int:
        i = len(self.kind)
        self.kind.append(kind)
        self.flags.append(flags)
        self.opacity.append(opacity)
        self.emission.append(emission)
        self.selflit.append(selflit)
        self.cube_q.append(cube_q or [-1] * 6)
        self.cube_o.append(cube_o or [-1] * 6)
        self.mq_start.append(start)
        self.mq_count.append(count)
        return i

    def _cube_from_textures(self, face_textures: list[str], tint=T_NONE) -> list[int]:
        out = []
        for i, face in enumerate(FACES):
            verts = _face_vertices(face, (0, 0, 0), (1, 1, 1))
            u0, v0, u1, v1 = 0.0, 0.0, 1.0, 1.0
            uvs = [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]
            out.append(self._add_quad(verts, uvs, self._tex(face_textures[i]), tint, True))
        return out

    def _compile(self, key: str) -> int:
        name, props = parse_state(key)
        name = RENAMES.get(name, name)
        if len(self.kind) >= 65000:
            return 0
        if name in AIR_NAMES:
            return self._register(AIR, 0, 0, 0, 0.0)
        light = EMISSION.get(name, 0)
        lit = props.get("lit") == "true"
        if name in LIT_BLOCKS:
            light = EMISSION.get(LIT_BLOCKS[name], 0) if lit else 0
        selflit = (light / 15 if name in SELF_LIT and (name not in LIT_BLOCKS or lit) else 0.0)
        if name in ("water", "bubble_column"):
            cq = self._cube_from_textures(["block/water_still"] * 6, T_WATER)
            return self._register(WATER, F_WATERLOGGED | F_TRANSLUCENT, 1, 0, 0.0, cq)
        if name == "lava":
            cq = self._cube_from_textures(["block/lava_still"] * 6)
            return self._register(LAVA, F_OPAQUE, 15, 15, 1.0, cq)
        if name in self.custom_boxes:
            t = self.custom_boxes[name]
            faces = [t.get(f, t.get("all")) for f in FACES]
            cq = self._cube_from_textures(faces)
            return self._register(CUBE, F_OPAQUE, 15, 0, 0.0, cq)

        waterlogged = props.get("waterlogged") == "true" or name in ALWAYS_WATERLOGGED
        props = {k: v for k, v in props.items() if k not in DROPPED_PROPS}
        canonical = state_key(name, props) + ("~w" if waterlogged else "")
        if canonical in self.ids and canonical != key:
            return self.ids[canonical]

        variants, randrot = self._pick_variants(name, props)
        cube_faces: dict[int, list[int]] = {}
        quads: list[int] = []
        is_full = bool(variants)
        ao = True
        for variant in variants:
            q, full, ao_m = self._bake(name, variant, cube_faces)
            quads += q
            is_full = is_full and full
            ao = ao and ao_m
        if not quads and name in ENTITY_BOXES or (not quads and name.endswith("_bed")):
            texname, box = ENTITY_BOXES.get(name, (name.replace("_bed", "_wool"), (0, 0, 0, 16, 9, 16)))
            for face in FACES:
                fr, to = tuple(c / 16 for c in box[:3]), tuple(c / 16 for c in box[3:])
                verts = _face_vertices(face, fr, to)
                u0, v0, u1, v1 = _default_uv(face, fr, to)
                uvs = [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]
                q = self._add_quad(verts, uvs, self._tex(f"block/{texname}"), T_NONE, True)
                if q >= 0:
                    quads.append(q)
            is_full = False
        if not quads:
            i = self._register(AIR, F_WATERLOGGED if waterlogged else 0, 0, light, selflit)
            self.ids[canonical] = i
            return i

        flags = 0
        if waterlogged:
            flags |= F_WATERLOGGED
        if randrot:
            flags |= F_RANDROT
        if name in THIN_PLANTS or not ao and name not in ("cactus",):
            flags |= F_NOSHADOW
        # A cube's second layer (the grass side overlay) is decoration: only the base layer decides opacity.
        base_quads = [lst[0] for lst in cube_faces.values()] if is_full and len(cube_faces) == 6 else quads
        has_hole = any(self.tex_alpha[self.qtex[q]][0] for q in base_quads)
        has_partial = any(self.tex_alpha[self.qtex[q]][1] for q in base_quads)
        leaves = name.endswith("_leaves")
        if has_partial and not leaves and (name.endswith("glass") or name.endswith("glass_pane")
                                           or name in ("ice", "slime_block", "honey_block", "nether_portal",
                                                       "tinted_glass", "frosted_ice")):
            flags |= F_TRANSLUCENT
        if name.endswith("glass") or name.endswith("glass_pane") or name in ("ice", "slime_block", "honey_block"):
            flags |= F_CULLSAME

        if is_full and len(cube_faces) == 6:
            cq, co = [-1] * 6, [-1] * 6
            for slot, lst in cube_faces.items():
                cq[slot] = lst[0]
                if len(lst) > 1:
                    co[slot] = lst[1]
            opaque = not has_hole and not (flags & F_TRANSLUCENT)
            if opaque:
                flags |= F_OPAQUE
            if leaves:
                flags |= F_LEAVES
            op = 15 if opaque else (1 if leaves or name == "ice" else 0)
            i = self._register(CUBE, flags, op, light, selflit, cq, co)
        else:
            # Model quads must be contiguous in the table.
            start = len(self.quads)
            for q in quads:
                self.quads.append(self.quads[q])
                self.qtex.append(self.qtex[q])
                self.qtint.append(self.qtint[q])
            i = self._register(MODEL, flags, 0, light, selflit, start=start, count=len(quads))
        self.ids[canonical] = i
        return i
