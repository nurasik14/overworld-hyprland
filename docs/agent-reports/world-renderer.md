# world-renderer report

Status: all 6 deliverables done and checked by looking at the renders. Nothing is committed (orchestrator's job).
The first run was cut off during scene tuning and was resumed at 06:32; everything below is from the finished state.

## Deliverables

| # | deliverable | path |
|---|---|---|
| Engine | Voxel ray marcher using real blockstates, models and textures | `tools/worldgen/` (uv project, Python 3.12, numba) |
| 1 | Terrain: 8 Overworld biomes + Nether + End, trees, structures | `tools/worldgen/worldgen/{terrain,features,structures,noise,scenes}.py` |
| 2 | The user's worlds: all 5 saves at spawn, plus New World (2)'s Nether and End | `anvil.py`, `nbt.py`, `compose.py`; wallpapers numbered 20-26 |
| 3 | Wallpapers: 13 Day, 17 Night, 16 dawn/dusk variants; 46 thumbnails | `assets/wallpapers/{light,dark,variants,thumbs}/`, `index.json` |
| 4 | Panorama: 6 faces, 3 strips, 2 lock frames | `assets/renders/panorama/`, `assets/renders/lock-{day,night}.png` |
| 5 | Wordmark: own textures (committed) and real textures (local) | `assets/gen/wordmark/overworld{,-small}.png`, `assets/renders/wordmark.png` |
| 6 | World creation script | `scripts/make-world.sh` |
| Docs | Commands, file formats, how it works | `docs/WORLDGEN.md` |

Time-of-day variants: all 8 Overworld scenes have dawn, day, dusk and night (the brief asked for at least 4 scenes).

## Decisions

- CPU with numba; GPU not tried. A frame takes 3-6 s, far inside the limit, and it needs no GPU context on the desktop.
- Dawn and dusk go in `assets/wallpapers/variants/`, not `light/` and `dark/`, because `scripts/overworld` defaults to
  the first file in the mode folder, which would have been a dawn picture. `index.json` lists everything.
- `index.json` has one extra field beyond the brief, `thumb`.
- Full day and night light the scene from behind the camera while the sun or moon sprite stays in frame. This is not
  physical, but a visible sun otherwise backlights every face. Dawn and dusk stay physical.
- `make-world.sh` emits `world.created` itself; qs-core was told not to repeat it.
- The panorama title screen opens at yaw 20, facing the mountains.
- `SpeedrunHunt (1)` uses a hand-picked camera because the search missed its village.

## Verified, and how

- Every sheet and several full-size wallpapers were viewed with the Read tool. Fixed along the way: non-opaque grass,
  oversized sprites, ocean floor above sea level, mycelium state mismatch, torch light in daylight, stars through clouds,
  a cliff from an angle wrap in the panorama, flat foregrounds.
- Models and UVs: close-up test bench of about 65 block types. Faces upright, grass overlay tinted, leaves tinted, doors,
  stairs, fences, furnace and glass correct.
- Chunk formats: DataVersion 2567 (New World, New World (1)) and 4671 (the other three). 1176-1681 chunks per world.
- Saves untouched: `find ~/.minecraft/saves -newermt '2026-11-05 02:00'` returned nothing.
- Panorama seams, numeric: mean edge difference 0.6-3.6 between neighbouring faces (all 6 joins) against 4.0 between
  adjacent columns inside a face. Strip wrap 1.8-2.7 against 1.5-3.0 inside. Orientation of faces 4 and 5 follows the
  wiki's stated edges (minecraft.wiki/w/Panorama, Tutorial:Making_custom_panoramas).
- Calm zones, numeric: mean edge energy over 46 wallpapers is 2.51 in the bottom strip, 3.90 in the left 40 %, 5.98 in
  the right 60 %.
- `make-world.sh`: 3 runs, exit 0. 28 s (first compile), 10 s, 14 s; peak RAM 1.2 GB. Index entry and `world.created`
  line written. Unknown scene exits 2. Random seeds gave good pictures. Test files were deleted afterwards.
- `index.json`: 46 entries, every `file` and `thumb` exists. Sizes checked with `magick identify`.
- Wordmark: the build raises an error if any quad uses a non-generated texture, so the committed PNG holds no Mojang
  pixels. `git check-ignore` confirms Mojang-derived outputs are ignored and the wordmark, code and docs are not.
- Safety: no sound, no grim or dev-shot (nothing here draws to the screen), no Hyprland or session changes, no sudo.

## Not verified

- No shell has consumed `index.json` or `make-world.sh` yet; qs-core and fx-world have not been run against them.
- The wallpapers, lock frames and strip have not been seen on the live desktop, hyprlock or SDDM.
- Exit codes 3 (no Mojang assets) and 4 (no uv) were not triggered.

## Open issues

- The panorama's village and lake are mostly hidden behind the hill's crest. The view is still attractive; moving them
  or raising the camera would show them.
- New World and New World (1) have a treetop low in the frame, partly in the HUD strip.
- Night plains: the homestead's lights are subtle at this distance.
- Test runs wrote 3 `world.created` lines to the live `/run/user/1000/overworld/events.jsonl`, pointing at files since
  deleted. Anything replaying that file will see them; a listener that was running would count 3 worlds.
- Chests and beds are plain boxes; signs, banners and heads are not drawn; mobs and items are not read.

## Requests filed (docs/REQUESTS.md)

- qs-core: how Select World reads the index and runs `make-world.sh`.
- fx-world: how to find time-of-day variants.
- hyprland-engineer: lock and SDDM image paths (gitignored, so install must copy them), and the stale hint at
  `scripts/overworld:141`.
- asset-forge: credit `assets/gen/wordmark/` as original work.

## Review images

`qa/screenshots/world-renderer-sheet-{day,night,dawndusk,saves,makeworld,panorama-cross,strips,lock}.png`,
`world-renderer-wordmark.png`, `world-renderer-makeworld-seed12345.png`. Large sheets can show banding and colour shifts
when downscaled for display (seen as reddish End pillars); the full-size files do not have them.
