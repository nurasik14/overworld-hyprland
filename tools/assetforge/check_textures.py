#!/usr/bin/env python3
"""Compare assets/gen/textures against assets/mc/textures: same size + same .mcmeta scaling for every path that exists in both,
and list required Mojang sprites that have no fallback.  Usage: check_textures.py"""
import json
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
gen, mc = REPO / "assets/gen/textures", REPO / "assets/mc/textures"
bad = same = 0
for p in sorted(gen.rglob("*.png")):
    rel = p.relative_to(gen)
    q = mc / rel
    if not q.exists():
        print("no mc twin (ours only):", rel)
        continue
    a, b = Image.open(p).size, Image.open(q).size
    ma, mb = Path(str(p) + ".mcmeta"), Path(str(q) + ".mcmeta")
    sa = json.loads(ma.read_text()).get("gui") if ma.exists() else None
    sb = json.loads(mb.read_text()).get("gui") if mb.exists() else None
    if a != b or sa != sb:
        bad += 1
        print(f"MISMATCH {rel}: size {a} vs {b}; mcmeta {sa} vs {sb}")
    else:
        same += 1
print(f"{same} identical size+mcmeta, {bad} mismatches")
want = []
for sub in ("gui/sprites/widget", "gui/sprites/hud", "gui/sprites/toast", "gui/sprites/tooltip", "gui/sprites/boss_bar", "gui/sprites/server_list",
            "environment"):
    for q in (mc / sub).rglob("*.png"):
        rel = q.relative_to(mc)
        if not (gen / rel).exists():
            want.append(str(rel))
for q in (mc / "block").glob("destroy_stage_*.png"):
    if not (gen / q.relative_to(mc)).exists():
        want.append(str(q.relative_to(mc)))
print("Mojang sprites in the requested groups without a fallback:", len(want))
for w in want:
    print("  ", w)
