# tools/assetforge

uv project (Pillow, numpy, fonttools) that builds Overworld's derived assets. Run any script with `uv run python <script>`.

| script | output | needs Mojang assets (`assets/mc`) |
|---|---|---|
| `build_font.py` | `assets/fonts/OverworldMojangles-{Regular,Bold}.ttf` (gitignored) | yes |
| `render_icons.py` | `assets/icons/mc/{,32,48,64}/<name>.png` (gitignored), names from `tokens/items.json` | yes |
| `gen_icons.py` | `assets/gen/icons/**` original fallback icons (committed) | no |
| `gen_textures.py` | `assets/gen/textures/**` original fallback GUI sprites + `.mcmeta` (committed) | no |
| `make_sounds.py` | `assets/gen/sounds/*.wav` synthesized fallback sounds (committed) | no |
| `build_sounds_map.py` | `tokens/sounds.json` (validates all paths; stdlib only) | for validation |
| `check_textures.py` | compares fallback textures with the Mojang twins (size + nine-slice) | yes |
| `contact_sheet.py`, `contact_textures.py` | QA contact sheets | – |

`scripts/fetch-minecraft-assets.sh --build` fetches `assets/mc` and runs the first two. Cursor theme: `apps/cursor/build.sh`.
