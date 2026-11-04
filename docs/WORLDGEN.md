# World generator and renderer

`tools/worldgen/` makes every Overworld world picture: wallpapers, the title-screen panorama, lock-screen frames and
the wordmark. It is our own voxel renderer written in Python with [numba](https://numba.pydata.org/) (Python compiled
to machine code at run time), and it draws with the game's real block textures from `assets/mc/`.

Nothing it produces with Mojang textures is committed (BRIEF §1.9). Those outputs live in gitignored
`assets/wallpapers/` and `assets/renders/`, and the commands below recreate them. Only the wordmark in
`assets/gen/wordmark/` is committed, and it uses textures generated here, with no Mojang pixels.

## Commands

```sh
scripts/make-world.sh [--seed N] [--scene S] [--time T] [--mode light|dark] [--out PATH]   # one new world

cd tools/worldgen
uv run python -m worldgen catalog [--scene S] [--force]    # the shipped set; skips files that exist
uv run python -m worldgen saves [--save NAME]              # your own worlds, framed around spawn
uv run python -m worldgen dims "New World (2):nether:-26:154" "New World (2):end:0:0"
uv run python -m worldgen panorama                         # cube faces, strips, lock frames
uv run python -m worldgen wordmark
```

Set `NUMBA_NUM_THREADS=8` and prefix `nice -n 10` for long runs. `make-world.sh` does both itself.

## Output files

| path | what |
|---|---|
| `assets/wallpapers/light/NN-<scene>-day.png` | Day mode wallpapers, 1920x1080 |
| `assets/wallpapers/dark/NN-<scene>-night.png` | Night mode wallpapers, including the Nether and End scenes |
| `assets/wallpapers/variants/NN-<scene>-dawn.png`, `-dusk.png` | Time-of-day variants |
| `assets/wallpapers/thumbs/*.png` | 320x180 thumbnails for the Select World rows |
| `assets/wallpapers/index.json` | The catalogue the shell reads |
| `assets/renders/panorama/panorama_0..5.png` | Cube faces, 1024x1024 |
| `assets/renders/panorama/strip.png`, `strip-night.png`, `strip-dusk.png` | Seamless 5760x1080 strips for SDDM |
| `assets/renders/lock-day.png`, `lock-night.png` | Slightly blurred frames for hyprlock |
| `assets/renders/wordmark.png` | OVERWORLD with the real textures (local only) |
| `assets/gen/wordmark/overworld.png`, `overworld-small.png` | OVERWORLD with our own textures (committed) |

Dawn and dusk sit in `variants/` because the shell lists `light/` and `dark/` and defaults to the first file: a Day
desktop should open on a day picture. `make-world.sh` still writes to the mode folder, so a world you create shows up
in the list.

### `index.json`

An array of:

```json
{"file": "light/01-plains-day.png", "mode": "light", "scene": "plains", "time": "day",
 "title": "Flower Plains (Day)", "seed": 41, "world": null, "thumb": "thumbs/01-plains-day.png"}
```

- `file` and `thumb` are relative to `assets/wallpapers/`, or absolute when `--out` pointed elsewhere.
- `mode` is `light` or `dark`. `time` is `dawn`, `day`, `dusk` or `night`.
- `world` is the save folder name for your own worlds (`scene` is then `save:<slug>` and `seed` is null), else null.
- To swap a wallpaper with the time of day, find the entry with the same `scene` and the wanted `time`.

Writes go through a lock and an atomic rename, so concurrent renders cannot corrupt the file.

### Panorama convention

From [minecraft.wiki/w/Panorama](https://minecraft.wiki/w/Panorama) and
[Tutorial:Making custom panoramas](https://minecraft.wiki/w/Tutorial:Making_custom_panoramas): `panorama_0..3` run
left to right (each face is 90 degrees clockwise from the last), `panorama_4` sits above `panorama_0` with its bottom
edge bordering 0's top, `panorama_5` sits below with its top edge bordering 0's bottom. The wiki states that layout;
the rotation of 4 and 5 follows from it. The faces get no bloom or other screen-space filter, so their edges meet.

## How the renderer works

There is no mesh. For every pixel a ray steps through the voxel grid one cell at a time (Amanatides-Woo traversal),
so seams and z-fighting cannot happen. The image is rendered with 4 rays per pixel (a rotated 2x2 grid).

| part | file | what it does |
|---|---|---|
| Blocks | `blocks.py` | Compiles the game's real `blockstates/` and `models/` JSON into textured rectangles: variants, multipart, parent chains, element and block rotations, uvlock, tint indices, the grass-side overlay. Stairs, doors, fences and plants need no special cases. |
| Light | `light.py` | The game's 0-15 sky light and block light, flood filled per voxel. |
| Ray march | `render.py` | Texture sampling with mipmaps, cutouts by alpha test, per-face shading (top 1.0, N/S 0.8, E/W 0.6, bottom 0.5), smooth lighting and ambient occlusion between voxel corners, sun shadows with dappled leaves, water with Fresnel reflection, ripples and absorption, distance fog, clouds, sun, moon, stars. |
| Sky | `sky.py` | Time-of-day presets. |
| Terrain | `terrain.py`, `features.py`, `structures.py`, `noise.py` | Heightmaps from gradient noise, 3D overhangs, rock strata and ores, tree shapes that follow the game's foliage placers, small builds. |
| Scenes | `scenes.py`, `panorama.py` | One art-directed recipe per scene. |
| Your worlds | `nbt.py`, `anvil.py`, `compose.py` | Save reader and automatic camera. |
| Finishing | `world.py` | Bloom, tone curve, and the calm zones described below. |

### Choices you may want to change

- **Daylight comes from behind the camera even when the sun is in frame.** A visible sun would backlight every face
  you see, so `key_az` in a `Shot` lights the scene from behind at full day and night. Dawn and dusk stay physical for
  their long shadows and silhouettes.
- **Calm zones.** `world._calm_zones` softly blurs the bottom ~90 px (and darkens it slightly) for the hotbar, and
  lightly blurs the left 40 % for widget cards. Scene recipes also keep tall things to the right and start plants
  just above the strip.
- **Block light fills what sky light leaves** (`render._lit`), so torches glow at night but not at noon, as in the game.
- **Leaves render brighter than the game's** (`leaf_gain`), because distant canopies otherwise read almost black.

## Composition for a new scene

`Canvas` works in view coordinates: the camera looks north from near the south edge, `c.s` is the lateral offset,
`c.f` the distance ahead and `c.sx` the approximate screen x from 0 to 1. `c.s_at(0.75, 120)` answers "where is three
quarters across the screen at distance 120?" Add a function to `scenes.py` and an entry in `SCENES`.

## Your worlds

`anvil.py` opens region files read-only and never writes under `~/.minecraft`. It reads both chunk layouts your saves
use: DataVersion 2567 (1.16.5, `Level.Sections`, numeric biomes) and 4671 (1.21.11, `sections`, named biomes).
Half-generated chunks at the edge of the explored area are skipped, and fog is set so it closes in before the view
reaches them. `compose.py` renders about 1500 tiny previews per world and scores them for sky share, depth, colour,
openness and calm zones, and `saves` renders the winner at day and night.

Block-entity blocks (chests, beds) are simple boxes; signs, banners and heads are not drawn. Mobs and dropped items
are not read.

## Performance

Measured on this machine (16 cores, limited to 8 threads, nice 10):

| job | time |
|---|---|
| `make-world.sh`, numba cache in place | 10-14 s, about 1.1 GB peak RAM |
| `make-world.sh`, first run (compiles the renderer) | 28 s |
| One 1920x1080 frame at 2x2 supersampling | 3-6 s |
| One of your worlds: load, search about 1500 views, render day + night | 20-30 s |
| Panorama: 6 faces, 3 strips, 2 lock frames | 68 s |
| Everything (46 wallpapers, panorama, wordmark) | about 6 minutes |

It runs on the CPU only. The GPU is not used: the CPU path met the three-minute limit by a wide margin, so moderngl/EGL
was not tried.

## Known limits

- The panorama's village and lake exist in the world, but the hill's crest hides most of them from the camera.
- Water always sits at one height per block; flowing water is not sloped.
- The automatic camera can still leave a treetop low in the frame (`New World`, `New World (1)`). `SAVE_CAMERAS` in
  `__main__.py` overrides the search per world; `SpeedrunHunt (1)` uses it to frame the village.
