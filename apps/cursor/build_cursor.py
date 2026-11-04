#!/usr/bin/env python3
"""Build the Overworld cursor theme (original art from cursors.py) as Xcursor + hyprcursor.

  build.sh [--out DIR] [--install]      (build.sh runs this with the assetforge uv env: needs Pillow)

  DIR/Overworld/                 Xcursor theme: index.theme + cursors/<name> (+ alias symlinks)
                                 and the hyprcursor theme: manifest.hl + hyprcursors/*.hlc
  --install                      copy DIR/Overworld to ~/.local/share/icons/Overworld  (does NOT activate it)
Default DIR: ~/.cache/overworld/cursor-build.   Sizes: 24, 32, 48 px (16-px art grid, nearest-neighbour: x1.5, x2, x3).
"""
import argparse
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cursors as cur  # noqa: E402

SIZES = (24, 32, 48)
NAME = "Overworld"


def scaled(img, size):
    return img.resize((size, size), Image.NEAREST)


def hot(hs, size):
    return (min(size - 1, round(hs[0] * size / cur.G)), min(size - 1, round(hs[1] * size / cur.G)))


# ------------------------------------------------------------------------------------------------ Xcursor
def xcursor_bytes(frames, hotspot, delay):
    chunks = []
    for size in SIZES:
        for img in frames:
            im = scaled(img, size)
            xh, yh = hot(hotspot, size)
            pix = bytearray()
            raw = im.tobytes()
            for (r, g, b, a) in zip(raw[0::4], raw[1::4], raw[2::4], raw[3::4]):
                # premultiplied ARGB, little-endian
                pix += struct.pack("<I", (a << 24) | ((r * a // 255) << 16) | ((g * a // 255) << 8) | (b * a // 255))
            head = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, size, size, xh, yh, delay if len(frames) > 1 else 0)
            chunks.append((size, head + bytes(pix)))
    ntoc = len(chunks)
    pos = 16 + ntoc * 12
    out = b"Xcur" + struct.pack("<III", 16, 0x10000, ntoc)
    toc = b""
    body = b""
    for size, data in chunks:
        toc += struct.pack("<III", 0xFFFD0002, size, pos + len(body))
        body += data
    return out + toc + body


def build_xcursor(root):
    cdir = root / "cursors"
    cdir.mkdir(parents=True, exist_ok=True)
    for shape, fn in cur.SHAPES.items():
        frames, hs = fn()
        (cdir / shape).write_bytes(xcursor_bytes(frames, hs, cur.ANIMATED.get(shape, 0)))
        for alias in cur.ALIASES.get(shape, []):
            link = cdir / alias
            if link.exists() or link.is_symlink():
                link.unlink()
            link.symlink_to(shape)
    (root / "index.theme").write_text(f"[Icon Theme]\nName={NAME}\nComment=Overworld pixel cursors (original art)\nInherits=Adwaita\n")


# ------------------------------------------------------------------------------------------------ hyprcursor
def build_hyprcursor(src, root):
    shutil.rmtree(src, ignore_errors=True)
    (src / "hyprcursors").mkdir(parents=True)
    (src / "manifest.hl").write_text(f"name = {NAME}\ndescription = Overworld pixel cursors (original art)\nversion = 0.1\ncursors_directory = hyprcursors\n")
    for shape, fn in cur.SHAPES.items():
        frames, hs = fn()
        d = src / "hyprcursors" / shape
        d.mkdir()
        lines = ["resize_algorithm = none", f"hotspot_x = {hs[0] / cur.G:.4f}", f"hotspot_y = {hs[1] / cur.G:.4f}"]
        lines += [f"define_override = {a}" for a in cur.ALIASES.get(shape, [])]
        for size in SIZES:
            for i, img in enumerate(frames):
                fname = f"{shape}_{size}_{i}.png"
                scaled(img, size).save(d / fname)
                delay = cur.ANIMATED.get(shape, 0) if len(frames) > 1 else 0
                lines.append(f"define_size = {size}, {fname}" + (f", {delay}" if delay else ""))
        (d / "meta.hl").write_text("\n".join(lines) + "\n")
    out = root.parent / "hypr-out"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    r = subprocess.run(["hyprcursor-util", "--create", str(src), "--output", str(out)], capture_output=True, text=True)
    print(r.stdout.strip()[-400:], r.stderr.strip()[-400:], file=sys.stderr)
    made = next(out.glob("theme_*"), None)
    if r.returncode or made is None:
        raise SystemExit("hyprcursor-util --create failed")
    shutil.copy(made / "manifest.hl", root / "manifest.hl")
    shutil.rmtree(root / "hyprcursors", ignore_errors=True)
    shutil.copytree(made / "hyprcursors", root / "hyprcursors")


def preview(path):
    names = list(cur.SHAPES)
    cell = 80
    cols = 8
    rows = -(-len(names) // cols)
    sheet = Image.new("RGB", (cols * cell, rows * cell * 2 + 8), "#444")
    from PIL import ImageDraw, ImageFont
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(str(Path.home() / ".local/share/fonts/overworld/OverworldMojangles-Regular.ttf"), 8)
    except Exception:
        font = ImageFont.load_default()
    for band, bg in enumerate(("#e8e8e8", "#303038")):
        for i, n in enumerate(names):
            x, y = (i % cols) * cell, band * (rows * cell + 8) + (i // cols) * cell
            d.rectangle([x + 2, y + 2, x + cell - 3, y + cell - 3], fill=bg)
            frames, hs = cur.SHAPES[n]()
            im = scaled(frames[0], 48).resize((64, 64), Image.NEAREST) if False else frames[0].resize((64, 64), Image.NEAREST)
            sheet.paste(im, (x + 8, y + 4), im)
            d.rectangle([x + 8 + hs[0] * 4 - 1, y + 4 + hs[1] * 4 - 1, x + 8 + hs[0] * 4 + 1, y + 4 + hs[1] * 4 + 1], outline="#ff00ff")
            d.text((x + cell // 2, y + cell - 8), n, fill="#000" if band == 0 else "#fff", font=font, anchor="mm")
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=Path.home() / ".cache/overworld/cursor-build")
    ap.add_argument("--install", action="store_true")
    ap.add_argument("--preview", type=Path)
    a = ap.parse_args()
    root = a.out / NAME
    shutil.rmtree(root, ignore_errors=True)
    root.mkdir(parents=True)
    build_xcursor(root)
    build_hyprcursor(a.out / "hypr-src", root)
    if a.preview:
        preview(a.preview)
    n_x = len(list((root / "cursors").iterdir()))
    n_h = len(list((root / "hyprcursors").glob("*.hlc")))
    print(f"built {root}: {n_x} xcursor names, {n_h} hyprcursor shapes")
    if a.install:
        dst = Path.home() / ".local/share/icons" / NAME
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(root, dst, symlinks=True)
        print(f"installed to {dst} (not activated)")


if __name__ == "__main__":
    main()
