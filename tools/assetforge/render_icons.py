#!/usr/bin/env python3
"""Render Minecraft-style inventory icons from the extracted jar models -> assets/icons/mc/ (gitignored, © Mojang).

  blocks  -> isometric "inventory" renders like the game: the model's display.gui transform (tilted 30°, scale 0.625),
             faces shaded top 1.0 / left 0.8 / right 0.6 (down 0.5), nearest-neighbour texture sampling, no AA
  items   -> the flat layer textures (first animation frame), nearest-neighbour

Output:  assets/icons/mc/<name>.png (16x16 base)   and   assets/icons/mc/{32,48,64}/<name>.png
         (flat items: integer nearest upscale of the base; blocks: rendered natively at that size, like the game at GUI scale 2-4)
Names come from tokens/items.json (all values) + EXTRA below.  `empty` is a transparent icon.

Usage: render_icons.py [--mc DIR] [--out DIR] [--items tokens/items.json] [name ...]
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]

# extra names worth having pre-rendered (hotbar / launcher / chat icons for the rest of the shell)
EXTRA = """stone grass_block dirt cobblestone oak_planks oak_log bookshelf furnace blast_furnace smoker anvil tnt enchanting_table
brewing_stand potion glass_bottle experience_bottle emerald diamond gold_ingot iron_ingot redstone_torch torch lantern campfire
bucket water_bucket lava_bucket iron_door oak_door totem_of_undying elytra nether_star beacon crafting_table ender_chest
trapped_chest jukebox note_block lectern cartography_table smithing_table loom stonecutter barrel repeater redstone_lamp observer
piston dispenser dropper hopper stone_button oak_sign item_frame filled_map map name_tag lead saddle blaze_powder nether_wart
blaze_rod ender_eye heart_of_the_sea sculk_sensor target daylight_detector lodestone composter cake cookie bread apple
golden_apple netherite_pickaxe diamond_pickaxe iron_pickaxe iron_sword diamond_sword fishing_rod bow arrow shears flint_and_steel
clock compass spyglass recovery_compass writable_book written_book knowledge_book book enchanted_book paper bell goat_horn
music_disc_cat music_disc_13 music_disc_pigstep painting brush redstone lever comparator tripwire_hook command_block
chain_command_block repeating_command_block barrier structure_block end_portal_frame ender_pearl glowstone
obsidian crying_obsidian netherrack deepslate bedrock sand gravel oak_leaves glass ice snow_block pumpkin carved_pumpkin
sea_lantern amethyst_block copper_block gold_block iron_block diamond_block emerald_block lapis_block redstone_block""".split()

SPECIAL_FLAT = {"compass": "item/compass_16", "recovery_compass": "item/recovery_compass_16", "clock": "item/clock_00"}

# light: top 1.0, left 0.8, right 0.6, bottom 0.5
SHADE = {"up": 1.0, "left": 0.8, "right": 0.6, "down": 0.5}


# ----------------------------------------------------------------------------------------------- model loading
class Models:
    def __init__(self, mc: Path):
        self.mc = mc
        self.tex_cache = {}
        self.virtual = {}  # virtual textures (name -> PIL RGBA)
        c = mc / "textures/colormap/grass.png"
        self.grass = tuple(Image.open(c).convert("RGB").getpixel((51, 173))) if c.exists() else (0x91, 0xBD, 0x59)
        c = mc / "textures/colormap/foliage.png"
        self.foliage = tuple(Image.open(c).convert("RGB").getpixel((51, 173))) if c.exists() else (0x77, 0xAB, 0x2F)

    @staticmethod
    def norm(ref):
        return ref.split(":", 1)[-1]

    def model_path(self, ref):
        return self.mc / "models" / (self.norm(ref) + ".json")

    def load(self, ref, depth=0):
        """merged model: textures (child wins), elements+display from the nearest ancestor that has them, builtin flag"""
        ref = self.norm(ref)
        out = {"textures": {}, "elements": None, "display": {}, "builtin": None}
        if ref.startswith("builtin/"):
            out["builtin"] = ref.split("/", 1)[1]
            return out
        p = self.model_path(ref)
        if not p.is_file() or depth > 12:
            return None
        j = json.loads(p.read_text())
        parent = self.load(j["parent"], depth + 1) if "parent" in j else {"textures": {}, "elements": None, "display": {}, "builtin": None}
        if parent is None:
            return None
        out["builtin"] = parent["builtin"]
        out["textures"] = {**parent["textures"], **j.get("textures", {})}
        out["elements"] = j.get("elements", parent["elements"])
        out["display"] = {**parent["display"], **j.get("display", {})}
        return out

    def resolve_tex(self, textures, ref, depth=0):
        while ref and ref.startswith("#") and depth < 12:
            ref = textures.get(ref[1:])
            depth += 1
        return ref if ref and not ref.startswith("#") else None

    def texture(self, ref):
        """first animation frame as RGBA ndarray (h,w,4) or None"""
        if ref in self.virtual:
            return np.asarray(self.virtual[ref])
        ref = self.norm(ref)
        if ref in self.tex_cache:
            return self.tex_cache[ref]
        p = self.mc / "textures" / (ref + ".png")
        arr = None
        if p.is_file():
            im = Image.open(p).convert("RGBA")
            if im.height > im.width and im.height % im.width == 0:
                im = im.crop((0, 0, im.width, im.width))
            arr = np.asarray(im)
        self.tex_cache[ref] = arr
        return arr


# ----------------------------------------------------------------------------------------------- rasteriser
def rot_matrix(rx, ry, rz):
    rx, ry, rz = map(math.radians, (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rx @ Ry @ Rz


def default_uv(face, f, t):
    x1, y1, z1 = f
    x2, y2, z2 = t
    return {"down": [x1, 16 - z2, x2, 16 - z1], "up": [x1, z1, x2, z2],
            "north": [16 - x2, 16 - y2, 16 - x1, 16 - y1], "south": [x1, 16 - y2, x2, 16 - y1],
            "west": [z1, 16 - y2, z2, 16 - y1], "east": [16 - z2, 16 - y2, 16 - z1, 16 - y1]}[face]


def face_quad(face, f, t):
    """vertices v0..v3 in model space; v0 -> (u1,v1), v1 -> (u1,v2), v3 -> (u2,v1)  (FaceBakery order)"""
    x1, y1, z1 = f
    x2, y2, z2 = t
    return {
        "down": [(x1, y1, z2), (x1, y1, z1), (x2, y1, z1), (x2, y1, z2)],
        "up": [(x1, y2, z1), (x1, y2, z2), (x2, y2, z2), (x2, y2, z1)],
        "north": [(x2, y2, z1), (x2, y1, z1), (x1, y1, z1), (x1, y2, z1)],
        "south": [(x1, y2, z2), (x1, y1, z2), (x2, y1, z2), (x2, y2, z2)],
        "west": [(x1, y2, z1), (x1, y1, z1), (x1, y1, z2), (x1, y2, z2)],
        "east": [(x2, y2, z2), (x2, y1, z2), (x2, y1, z1), (x2, y2, z1)],
    }[face]


def tint_for(models, texname):
    n = texname or ""
    if "grass" in n or "fern" in n or "tall_grass" in n or "sugar_cane" in n:
        return models.grass
    if "leaves" in n or "vine" in n or "lily_pad" in n:
        return models.foliage
    return None


def render_model(models: Models, model, S, yaw_flip=True):
    """isometric render of a merged block model at SxS px -> RGBA ndarray"""
    gui = model["display"].get("gui", {"rotation": [30, 225, 0], "translation": [0, 0, 0], "scale": [0.625] * 3})
    rx, ry, rz = gui.get("rotation", [30, 225, 0])
    tr = np.array(gui.get("translation", [0, 0, 0]), float) / 16
    sc = np.array(gui.get("scale", [1, 1, 1]), float)
    # Mojang's GUI space is mirrored relative to ours: yaw 225 shows the south face on the left, east on the right
    R = rot_matrix(rx, (180 - ry) if yaw_flip else ry, rz)
    img = np.zeros((S, S, 4), np.float64)
    zbuf = np.full((S, S), -1e9)
    ys, xs = np.mgrid[0:S, 0:S]
    px = (xs + 0.5) / S - 0.5  # screen x in [-.5,.5]
    py = 0.5 - (ys + 0.5) / S  # screen y up

    for el in model["elements"] or []:
        f, t = np.array(el["from"], float), np.array(el["to"], float)
        erot = el.get("rotation")
        for fname, fd in el.get("faces", {}).items():
            texref = models.resolve_tex(model["textures"], fd.get("texture", ""))
            tex = models.texture(texref) if texref else None
            if tex is None:
                continue
            uv = fd.get("uv") or default_uv(fname, f, t)
            quad = np.array(face_quad(fname, f, t), float)
            if erot:
                o = np.array(erot["origin"], float)
                ax = {"x": 0, "y": 1, "z": 2}[erot["axis"]]
                a = math.radians(erot["angle"])
                c, s = math.cos(a), math.sin(a)
                M = np.eye(3)
                i, j = [(1, 2), (2, 0), (0, 1)][ax]
                M[i, i], M[i, j], M[j, i], M[j, j] = c, -s, s, c
                quad = (quad - o) @ M.T + o
            P = ((quad - 8) / 16 * sc) @ R.T + tr  # (4,3) screen-space
            A, B = P[3] - P[0], P[1] - P[0]
            det = A[0] * B[1] - A[1] * B[0]
            if abs(det) < 1e-9:
                continue
            # which side is the face on? derive from the *unrotated* face name + yaw so light is stable
            nrm = {"up": (0, 1, 0), "down": (0, -1, 0), "north": (0, 0, -1), "south": (0, 0, 1), "west": (-1, 0, 0), "east": (1, 0, 0)}[fname]
            n_s = R @ np.array(nrm, float)
            if n_s[2] <= 1e-6 and not erot:
                continue  # back face
            if fname == "up":
                shade = SHADE["up"]
            elif fname == "down":
                shade = SHADE["down"]
            else:
                shade = SHADE["left"] if n_s[0] <= 0 else SHADE["right"]
            dx, dy = px - P[0][0], py - P[0][1]
            a_ = (dx * B[1] - dy * B[0]) / det
            b_ = (A[0] * dy - A[1] * dx) / det
            eps = 1e-6
            inside = (a_ >= -eps) & (a_ < 1 - eps * 0) & (b_ >= -eps) & (b_ < 1)
            if not inside.any():
                continue
            u1, v1, u2, v2 = uv
            rot = fd.get("rotation", 0)
            aa, bb = a_, b_
            if rot == 90:
                aa, bb = b_, 1 - a_
            elif rot == 180:
                aa, bb = 1 - a_, 1 - b_
            elif rot == 270:
                aa, bb = 1 - b_, a_
            u = u1 + aa * (u2 - u1)
            v = v1 + bb * (v2 - v1)
            th, tw = tex.shape[:2]
            ti = np.clip((u / 16 * tw).astype(int), 0, tw - 1)
            tj = np.clip((v / 16 * th).astype(int), 0, th - 1)
            col = tex[tj, ti].astype(np.float64)
            z = P[0][2] + a_ * A[2] + b_ * B[2]
            tint = tint_for(models, texref) if "tintindex" in fd else None
            vis = inside & (col[..., 3] > 0) & (z >= zbuf)
            if not vis.any():
                continue
            rgb = col[..., :3].copy()
            if tint:
                rgb = rgb * np.array(tint) / 255.0
            rgb *= shade
            img[vis, :3] = rgb[vis]
            img[vis, 3] = col[..., 3][vis]
            zbuf[vis] = z[vis]
    return np.clip(img, 0, 255).astype(np.uint8)


# ----------------------------------------------------------------------------------------------- special models
def chest_model(models: Models, kind="normal"):
    """the chest has no JSON model (builtin/entity): build one from the 64x64 entity texture"""
    p = models.mc / f"textures/entity/chest/{kind}.png"
    if not p.is_file():
        return None
    im = Image.open(p).convert("RGBA")

    def crop(name, x, y, w, h):
        models.virtual[f"v:{kind}:{name}"] = im.crop((x, y, x + w, y + h))
        return f"v:{kind}:{name}"

    def box(prefix, u0, v0, w, h, d):
        # entity boxes are stored upside-down/back-to-front (the chest model is rotated 180° about X):
        # top/bottom swap, the latch side ("back" region) is our north face, west/east are mirrored
        def mirror(n):
            models.virtual[n] = models.virtual[n].transpose(Image.FLIP_LEFT_RIGHT)
            return n
        return {"up": crop(prefix + "up", u0 + d + w, v0, w, d), "down": crop(prefix + "down", u0 + d, v0, w, d),
                "west": mirror(crop(prefix + "west", u0, v0 + d, d, h)), "north": crop(prefix + "north", u0 + 2 * d + w, v0 + d, w, h),
                "east": mirror(crop(prefix + "east", u0 + d + w, v0 + d, d, h)), "south": crop(prefix + "south", u0 + d, v0 + d, w, h)}

    def el(frm, to, texs):
        return {"from": frm, "to": to, "faces": {f: {"texture": f"#{t}", "uv": [0, 0, 16, 16]} for f, t in texs.items()}}

    base, lid, lock = box("b", 0, 19, 14, 10, 14), box("l", 0, 0, 14, 5, 14), box("k", 0, 0, 2, 4, 1)
    textures = {v: v for d in (base, lid, lock) for v in d.values()}
    return {"textures": textures, "builtin": None, "display": {"gui": {"rotation": [30, 45, 0], "translation": [0, 0, 0], "scale": [0.625] * 3}},
            "elements": [el([1, 0, 1], [15, 10, 15], base), el([1, 9, 1], [15, 14, 15], lid), el([7, 7, 0], [9, 11, 1], lock)]}


SPECIAL_ENTITY = {"chest": lambda m: chest_model(m, "normal"), "trapped_chest": lambda m: chest_model(m, "trapped"),
                  "ender_chest": lambda m: chest_model(m, "ender")}


# ----------------------------------------------------------------------------------------------- per-name rendering
def build_icon(models: Models, name, S):
    """-> RGBA ndarray SxS (flat items are rendered at 16 and nearest-upscaled by the caller), kind"""
    if name == "empty":
        return np.zeros((S, S, 4), np.uint8), "empty"
    item = models.load(f"item/{name}")
    blk = models.load(f"block/{name}")
    # flat item (item/generated, handheld, …)
    model = item if item is not None else blk
    if name in SPECIAL_ENTITY and (item is None or item.get("builtin") == "entity" or not (item or {}).get("elements")):
        model = SPECIAL_ENTITY[name](models)
        if model:
            return render_model(models, model, S), "block"
    if model is None:
        ref = SPECIAL_FLAT.get(name)
        if ref and models.texture(ref) is not None:
            return flat_from_layers(models, [ref], S), "flat"
        return None, None
    if model["builtin"] == "generated" or (model["elements"] is None and any(k.startswith("layer") for k in model["textures"])):
        layers = [model["textures"][k] for k in sorted(k for k in model["textures"] if k.startswith("layer"))]
        return flat_from_layers(models, [models.resolve_tex(model["textures"], l) for l in layers], S), "flat"
    if model["elements"]:
        return render_model(models, model, S), "block"
    if blk is not None and blk["elements"]:
        return render_model(models, blk, S), "block"
    # builtin/entity or element-less model: fall back on the particle texture as a flat cube
    return None, None


def flat_from_layers(models, refs, S):
    out = np.zeros((16, 16, 4), np.float64)
    for r in refs:
        t = models.texture(r) if r else None
        if t is None:
            continue
        im = Image.fromarray(t).resize((16, 16), Image.NEAREST) if t.shape[0] != 16 or t.shape[1] != 16 else Image.fromarray(t)
        a = np.asarray(im).astype(np.float64)
        al = a[..., 3:4] / 255
        out[..., :3] = a[..., :3] * al + out[..., :3] * (1 - al)
        out[..., 3:4] = np.maximum(out[..., 3:4], a[..., 3:4])
    out = out.astype(np.uint8)
    if S == 16:
        return out
    return np.asarray(Image.fromarray(out).resize((S, S), Image.NEAREST))


def names_from_tokens(tokens: Path):
    d = json.loads(tokens.read_text())
    names = {v for k, v in d.items() if isinstance(v, str) and k != "_comment"}
    names |= {r["item"] for r in d.get("_title_rules", [])}
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mc", type=Path, default=REPO / "assets/mc")
    ap.add_argument("--out", type=Path, default=REPO / "assets/icons/mc")
    ap.add_argument("--items", type=Path, default=REPO / "tokens/items.json")
    ap.add_argument("names", nargs="*")
    a = ap.parse_args()
    models = Models(a.mc)
    names = sorted(set(a.names) if a.names else names_from_tokens(a.items) | set(EXTRA))
    sizes = (16, 32, 48, 64)
    for s in sizes:
        (a.out if s == 16 else a.out / str(s)).mkdir(parents=True, exist_ok=True)
    ok, missing = [], []
    for n in names:
        done = False
        for s in sizes:
            arr, kind = build_icon(models, n, s)
            if arr is None:
                break
            Image.fromarray(arr).save((a.out if s == 16 else a.out / str(s)) / f"{n}.png")
            done = True
        (ok if done else missing).append(n)
    print(f"rendered {len(ok)} icons x {len(sizes)} sizes -> {a.out}", file=sys.stderr)
    if missing:
        print("no model/texture for: " + " ".join(missing), file=sys.stderr)


if __name__ == "__main__":
    main()
