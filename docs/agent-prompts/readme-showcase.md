# readme-showcase (follow-up) — demo photos + a capability showcase in README.md

You own: `README.md`, `docs/screenshots/` (committed images), `.gitignore` (only to un-ignore docs/screenshots if
needed). Read-only: everything else, especially `qa/screenshots/` (≈250 PNGs from the build: `qa-NN-*` = live QA
with Overworld fully ON in Day and Night — prefer these; `qs-core-*`, `qs-widgets-*`, `qs-features-*`, `fx-*`,
`apps-*`, `hypr-*`, `world-renderer-sheet-*`, `design-preview-*`, `hyprland-engineer-sddm*` = per-agent shots; MANY
early per-agent shots show the old Apothecary bar/cards underneath — do not use those, check every pick), the
wallpapers in `assets/wallpapers/{light,dark}/` and `assets/renders/` (panorama strips, lock frames, wordmark),
`assets/gen/wordmark/` (committed OVERWORLD wordmark), and the docs (`docs/*.md`, qa/REPORT.md, CHANGELOG.md).

## THE USER IS AT THE DESK
Do not take new screenshots of the live desktop (scripts/dev-shot.sh is disabled), no on-screen previews, no
theme switching, no sound, no git commits, no sudo. Build the showcase from existing images only (ImageMagick for
crops/montages/resizing is fine).

## Task
The user asked: "add the demo photos of the theme. Showcase full of its capabilities inside README".
1. Pick the best ~16–24 images that together show EVERY capability: full desktop Day + Night (HUD hotbar,
   hearts/hunger/air/XP, boss bar, 8 widget cards), launcher (creative inventory + tooltip + calculator), toasts
   incl. challenge, chat console with commands, gamemode switcher, advancements tree, statistics, options, game
   menu + quit confirm, select world + "Create New World" loading screen, multiplayer/network screen, OSD slider,
   /title workspace card, brewing stand + boss bar, F3 debug, rain/snow/thunder overlay, mining a window (crack
   stages + fragment burst), death screen, XP orbs, hyprlock/SDDM title screen (if a real/test-mode capture exists
   — label simulated ones honestly), app theming (kitty+fastfetch, rofi, GTK/Kvantum, btop, nvim), wallpapers
   (contact sheet of voxel renders incl. "your own Minecraft saves"), cursor sheet.
   VIEW every candidate (Read the PNG) before choosing; reject ones with visual bugs, Apothecary leftovers, or
   QA-only debug overlays.
2. **Privacy scrub (mandatory):** the user publishes this repo. Blur/pixelate or crop out: Wi-Fi SSIDs other than
   generic ones, MAC/IP addresses, notification contents that look personal, window titles with personal paths or
   project names unrelated to the theme, real names other than the user's in-game name "Nurasik", email addresses,
   the user's music track titles/album art is OK only if it is clearly a public song (else blur). Note every
   scrub in your report.
3. Optimize: convert to WebP or PNG-8/quantized at ≤ 1600 px wide (full-desktop) / natural size for crops, target
   total ≤ 12 MB; name them `docs/screenshots/NN-<what>.webp|png`. Make 2–3 GIF/WebP animations only if frames
   exist (e.g. mining stages, day→night variants of one scene) — keep each ≤ 2 MB.
4. README: a hero image at the top (Day/Night side-by-side or a split), the OVERWORLD wordmark, then a
   "Showcase" section organised by capability (HUD, Screens, Game systems, World effects, Interactions,
   Wallpapers & worlds, Lock & login, Apps) with each image + 1–2 lines on what it shows and the key/command that
   opens it (take keys from docs/KEYBINDS.md — verify, don't invent). Use HTML `<img width=…>` tables for
   side-by-side pairs. Keep the existing README content (install, CLI, config, credits) after the showcase,
   tidied. Add a short note under credits that screenshots show Minecraft textures © Mojang Studios used for
   demonstration; the repo itself does not ship Mojang assets.
5. Make sure `docs/screenshots/` is NOT gitignored (check `git check-ignore`) and every README image path
   resolves (script: extract paths, test -f each). Report in docs/agent-reports/readme-showcase.md with the
   image list, sizes and scrubs.
