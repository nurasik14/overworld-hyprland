"""Repository paths, resolved from this file so the tools work from any working directory."""
from __future__ import annotations

import os
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
ASSETS = REPO / "assets"
MC_DIR = ASSETS / "mc"
WALLPAPERS = ASSETS / "wallpapers"
RENDERS = ASSETS / "renders"
GEN_WORDMARK = ASSETS / "gen" / "wordmark"
QA_SHOTS = REPO / "qa" / "screenshots"
SAVES = Path(os.path.expanduser("~/.minecraft/saves"))
