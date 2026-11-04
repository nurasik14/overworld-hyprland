# Asset credits

Overworld Hyprland is a **Minecraft-inspired** theme. It is an unofficial fan project: not made by, endorsed by or
associated with Mojang Studios or Microsoft. "Minecraft" is a trademark of Mojang Studios; the project never uses the
Minecraft logo or wordmark (its own wordmark is **OVERWORLD**, in our own block lettering).

> **Theme system, switchable.** Overworld is layered on top of the JaKooLit Hyprland dotfiles. Turn it on with
> `overworld on` and off with `overworld off`; the assets listed here are used only while the theme is on.

## 1. Mojang assets — fetched, never redistributed

Textures, models, blockstates, the bitmap font, splash texts, language files, sound effects and `sounds.json` are
© Mojang Studios. **None of them is in this repository.** `scripts/fetch-minecraft-assets.sh` recreates them on the
user's own machine, from the user's own `~/.minecraft` installation (read-only) or, failing that, from Mojang's
servers (`piston-meta.mojang.com`, `resources.download.minecraft.net`, sha1-verified) — the same files the official
launcher downloads — into `assets/mc/`. Everything derived from them is built locally and stays out of git:

| local path (all gitignored) | what | built by |
|---|---|---|
| `assets/mc/` | extracted jar assets + sounds | `scripts/fetch-minecraft-assets.sh` |
| `assets/fonts/OverworldMojangles-{Regular,Bold}.ttf` (+ copy in `~/.local/share/fonts/overworld/`) | TTF built from the jar's bitmap font PNGs | `tools/assetforge/build_font.py` |
| `assets/icons/mc/**` | inventory-style icons rendered from the jar's models/textures | `tools/assetforge/render_icons.py` |
| `assets/wallpapers/`, `assets/renders/` | world renders using Mojang textures | `tools/worldgen`, `scripts/make-world.sh` |

Used for personal desktop theming only. Without these assets the theme falls back to the original art below.

## 2. Third-party fonts

| file | source | licence |
|---|---|---|
| Monocraft (Nerd-Font-patched TTC, installed in `~/.local/share/fonts/overworld/`, not committed) | [IdreesInc/Monocraft](https://github.com/IdreesInc/Monocraft), patched with Nerd Fonts glyphs | SIL OFL 1.1 |
| Apothecary-era fonts still installed by the legacy theme (Yuji Syuku, Ma Shan Zheng, …) | Google Fonts | SIL OFL 1.1 |

## 3. Original art, sound and code (committed — project licence, MIT, see `LICENSE`)

All generated from scratch by scripts in this repository; nothing is copied from Mojang or other artwork.

| path | what | generator |
|---|---|---|
| `assets/gen/textures/**` | fallback GUI sprites (widgets, hotbar, hearts/food/armor, boss bars, toasts, tooltip, server-list pings, advancements, creative-inventory tabs, destroy stages, sun/moon/rain/snow/clouds, `gui/inventory-panel`, `misc/missing.png`) — same paths/sizes/`.mcmeta` as the Mojang sprites they stand in for | `tools/assetforge/gen_textures.py` |
| `assets/gen/icons/**` | fallback app/item icons (isometric blocks from procedural textures + flat pixel art) | `tools/assetforge/gen_icons.py` |
| `assets/gen/sounds/*.wav` | fallback UI/block sounds synthesised with numpy | `tools/assetforge/make_sounds.py` |
| `tokens/sounds.json`, `tokens/items.json` | sound-id and app→icon maps (data only; reference Mojang file *names*, not files) | `tools/assetforge/build_sounds_map.py`, hand-edited |
| `apps/cursor/**`, installed `Overworld` cursor theme | pixel-art cursors (Xcursor + hyprcursor) | `apps/cursor/build.sh` |
| `assets/sounds/*.wav` (brew-done, notify, …) | inherited from the Apothecary theme (generated; project licence) | `scripts/make-sounds.py` |

## 4. Legacy Apothecary material

The theme was forked from the author's Apothecary Hyprland theme. Its generated textures (`assets/pd/…`, CC0 / project
licence) and fetched character art (`assets/art/`, `assets/wallpapers/` from the Apothecary build — copyrighted by their
holders, personal use only, never redistributed, gitignored) are being replaced by Minecraft equivalents by the
respective agents; anything still present is listed in the Apothecary repository's own `assets/CREDITS.md`.
