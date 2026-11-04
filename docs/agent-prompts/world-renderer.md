# world-renderer (phase 1) — voxel world wallpapers, panorama, time-of-day variants

You own: `tools/worldgen/` (uv project), `scripts/make-world.sh`, `assets/wallpapers/` (gitignored),
`assets/renders/` (gitignored), `docs/WORLDGEN.md`.

Goal: the Overworld wallpapers are **real 3D voxel renders in Minecraft's look**, made by our own renderer with
the real block textures from `assets/mc/textures/block/` (16×16, nearest-neighbour). Python + numpy (uv
project), GPU optional (you may use numba, or moderngl/EGL if it works headless on this machine — check
quickly, fall back to numpy). Quality bar: someone glancing at it must think "Minecraft screenshot with nice
shaders-lite": correct block faces, per-face shading (top 1.0, N/S 0.8, E/W 0.6), ambient occlusion at
voxel corners, sky gradient + sun/moon from `assets/mc/textures/environment/`, distance fog to the sky
colour, clouds (flat Minecraft cloud layer from `environment/clouds.png`), water with transparency, leaves
with cutout, grass/foliage tinted by biome colourmaps (`assets/mc/textures/colormap/grass.png`, `foliage.png`),
optional simple shadows from the sun. Render 1920×1080 with 2×2 supersampling.

1. **Terrain**: procedural generator (value/simplex noise heightmap + biomes: plains with flowers, birch/oak
   forest, snowy taiga with spruce, desert with cactus, cherry grove, ocean/beach, mountains with stone/snow,
   mushroom fields; caves optional) + structures (trees from real shapes, a small village house or tower
   optional).
2. **The user's own worlds (high value, best effort ≤ 40 min, then move on):** the user's saves are in
   `~/.minecraft/saves/` (READ-ONLY; copy region files you need to `/home/nurasik12/.hermes/cache/scratch/` or
   read them in place without writing). Parse Anvil `.mca` region files (zlib NBT, 1.18+ chunk format with
   palettes; use `nbtlib`/write your own minimal reader) around each world's spawn (`level.dat` SpawnX/Z) and
   render the user's real terrain as a wallpaper titled with the world name ("New World", "SpeedrunHunt"…).
   If the format beats you, document why in docs/WORLDGEN.md and skip.
3. **Wallpaper sets** — `assets/wallpapers/light/` (Day) and `assets/wallpapers/dark/` (Night), ≥ 8 each,
   file names `NN-<scene>-<time>.png`, plus **time-of-day variants** for at least 4 scenes:
   `<scene>-dawn|day|dusk|night` (fx-world's day/night cycle swaps them). Night: moon + stars, darker blue
   fog, torches/lanterns glowing optional. Include one Nether scene (netherrack, lava, glowstone,
   basalt) and one End scene (end stone, obsidian pillars, void) for the dark set. Compose for the desktop: keep
   the bottom ~90 px calmer (hotbar HUD sits there) and leave the left 40 % less busy (widget cards).
   Also write `assets/wallpapers/index.json` `[{file, mode, scene, time, title, seed, world}]` that the Select
   World screen reads (title like "Birch Forest", "SpeedrunHunt — spawn").
4. **Panorama**: 6 cube faces 1024×1024 (`assets/renders/panorama/panorama_0..5.png`, Minecraft order:
   0 front/south?, check the game's convention from minecraft.wiki) of one beautiful scene, plus a
   stitched equirectangular / wide strip `assets/renders/panorama/strip.png` for SDDM's rotating background,
   plus `assets/renders/lock-day.png` / `lock-night.png` (1920×1080 slightly blurred panorama frames for hyprlock).
5. **OVERWORLD wordmark** (original, committed in `assets/gen/wordmark/`): block lettering rendered from our own
   voxel renderer or pixel art in stone/grass textures style — BUT committed version must use our own
   generated texture (no Mojang pixels); a Mojang-textured version may go to `assets/renders/wordmark.png`.
6. **`scripts/make-world.sh [--seed N] [--scene S] [--time T] [--mode light|dark] [--out PATH]`**: renders a new
   world wallpaper in the background (used by the Select World screen's "Create New World"), prints the path,
   appends to index.json, < 3 min, `nice -n 10`, at most 8 threads.

Look at every render (Read the PNG; downscale contact sheets with magick to review many at once:
`qa/screenshots/world-renderer-sheet-*.png`). Iterate on what looks wrong (seams, z-fighting, wrong UV
orientation — side textures must be upright, grass_block_side overlay tinted, leaves tinted). Record render
times. Report in `docs/agent-reports/world-renderer.md`.
