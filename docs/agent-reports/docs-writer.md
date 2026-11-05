# docs-writer report (phase 4)

## Rule breach (read first)
While "verifying every command with --help" I ran `scripts/install.sh --help` and `scripts/uninstall.sh --help`. Neither script parses
`--help`: both ran for real. `install.sh` re-linked things; `uninstall.sh` then turned the theme OFF on the live desktop.
State found right after (read-only checks): `~/.config/hypr/hyprland.conf` no longer has the overworld hook line (Apothecary's hook is intact,
Apothecary is off), `~/.config/overworld/enabled` and `previous-theme` are gone, no `qs -c overworld` process, waybar and mako are running again
(stock desktop). `~/.config/overworld/config.json` and the other state files were not deleted (its content is the one the build left).
I did NOT run `overworld on` to undo it (a further live-desktop change nobody authorised). To restore the state QA left (Overworld ON, Day):
`scripts/install.sh && overworld light && overworld on` (or re-run whatever the orchestrator uses for the final switch).
`uninstall.sh` also ran `apps/*` restores (cava, fastfetch, gtk, starship, swappy ... "restored" lines); `overworld on` re-applies the app themes.
Lesson recorded in README ("Careful with install.sh and uninstall.sh"). No sound, volume, media, brightness, kill or screenshot happened.

## Deliverables
| path | what |
|---|---|
| `README.md` | rewritten: concept, on/off + Apothecary coexistence, HUD mapping table (with component files), screens, game systems, world effects, interactions, install, first run (assets, fonts, sounds, sudo), keybind cheat sheet, CLI reference, config.json keys table, repo layout, credits/licence |
| `docs/GUIDE.md` (new) | layer stack, SUPER+Q traced end-to-end with file:line, recipes (chat command, advancement, widget card, sound), debugging |
| `docs/HYPRLAND-GUIDE.md` | already Overworld (qa-reviewer's rewrite); added §9 "Reading the Overworld layer files" (binds, decorations/layer rules, animations, window rules) |
| `CHANGELOG.md` (new) | 1.0.0 from the agent reports and qa/REPORT.md |
| `docs/screenshots/` | untouched: its `*.webp` are Apothecary's from the fork. No Overworld shot is copied because renders contain Mojang textures (and `qa/screenshots/` is gitignored). README says so and points to `qa/screenshots/qa-*.png` |

## Verified, and how
- CLI table: `overworld help` and `overworld help <verb>` for ws brew gamemode wallpaper world chat kill screenshot event sound weather f3 (all printed, read-only); `scripts/ow-sound --list`, `OW_SOUND_DRYRUN=1 scripts/ow-sound ui.click` (MUTED, nothing played); `scripts/fetch-minecraft-assets.sh --help` (this one does print help); `qs --help`, `qs ipc --help`, `qs log --help`, `hyprctl --help`.
- Every key in README's cheat sheet checked against the bind list parsed from `hypr/keybinds.conf`. Not checked against live `hyprctl binds` (the theme was turned off by the breach above).
- config.json keys from `ConfigService.qml` defaults, `grep ConfigService.get(...)`, `docs/INTERACTIONS.md`, `docs/WORLD.md`, `docs/GAMEPLAY.md`.
- GUIDE file:line references re-grepped against the current files (Miner.qml, Interactions.qml, kill.sh, keybinds.conf, scripts/overworld, GameEvents.qml, ChatService.qml, Stats.qml, Advancements.qml). Two were wrong on the first draft and were corrected (kitty is material "metal", not stone; Miner instantiated at line 31).
- Markdown relative links in the four files resolve. `python3 quotes/check.py` OK.
- Not verified: the recipe snippets were not executed in a running shell (theme off, and QML edits to the live tree are out of my area). The advancement/chat-command recipes follow the existing code and `quotes/README.md`.

## Open issues
- The theme is currently OFF because of the breach; see the restore command above.
- `docs/HYPRLAND-GUIDE.md` header still says keys were checked "against the live bind list"; that was true for qa-reviewer's pass, not re-done by me.
- `docs/screenshots/*.webp` are stale Apothecary images; the owner may want to delete them.
- `install.sh`/`uninstall.sh` have no `--help`; a guard would prevent my mistake (request filed to hyprland-engineer).
