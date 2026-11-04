# hyprland-engineer report (phase 2)

Status: **done.** Overworld is installed and OFF. Apothecary is back ON in dark mode, compared against a snapshot taken before the run.

## Deliverables

| item | files |
|---|---|
| Coexistence + switch | `scripts/overworld` (theme handover), `scripts/install.sh`, `scripts/uninstall.sh`, `hypr/overworld.conf` (no gateway exec-once) |
| Look + motion + rules | `hypr/decorations.conf`, `animations.conf`, `rules.conf`, `on.conf`, `off.conf` |
| CLI | `scripts/overworld`: kill, chat, f3, gamemode (4 modes + switcher + status + on/off/toggle aliases), weather, daycycle, sound, world new, advancements, stats, options, screenshot, `help <verb>` for every verb; status shows previous theme, game mode, day cycle |
| Keybinds | `hypr/keybinds.conf`, `docs/KEYBINDS.md` |
| Title-screen lock + idle | `hypr/hyprlock.conf`, `hypr/hypridle.conf`, `hypr/scripts/{splash,quote,lock-assets}.sh` (`shichen.sh` removed) |
| SDDM | `sddm/overworld/Main.qml`, `splashes.js`, `quotes.js`, `metadata.desktop`, `.gitignore`; `scripts/install-sddm.sh`; `docs/SUDO-STEPS.md` (`Palette.js` removed) |
| wlogout | themed by app-theming in `apps/wlogout`, installed by `apps/install.sh`, which `install.sh` calls. Nothing in `apps/` changed by me |
| Docs | `docs/INSTALL.md`, `docs/KEYBINDS.md` |
| Tests | `hypr/test/check-config.sh`, `handover-sandbox.sh`, `live-roundtrip.sh`, `greeter-shot.sh`, `lock-sim.sh` |

## Decisions

- **Handover works on Apothecary's files, not `apothecary off` + `apothecary on`.** The CLI would start waybar and mako only to stop them, `apothecary on` waits 10 s for waybar and plays its login sound. `on` removes its `enabled`, points its `active.conf` at `off.conf`, stops `qs -c apothecary` and runs its `apps/apply-mode.sh off`; `off` reverses that. Its `prev-wallpaper` and `mako-was-active` stay, so a later `apothecary off` still restores stock. Fallback if `~/.config/apothecary/repo` is gone: its public CLI (on), stock desktop (off).
- **`notif_claim`, added after a live failure.** Mako is D-Bus activatable, so anything calling `org.freedesktop.Notifications` in the gap between two shells starts it, and the new shell then cannot take the name. After starting a shell the CLI keeps mako and swaync down until `qs` owns the name (max 4 s).
- **Game mode file** belongs to qs-features' `GameMode.qml`. The CLI asks the shell over IPC, or without a shell writes the same file and runs `scripts/game/apply-gamemode.sh`. A leftover `visible|hidden` reads as adventure. `reload`, `repair`, `light|dark` re-apply the adventure/spectator keywords after their `hyprctl reload`. `off` returns to survival first, so DND goes back.
- **Keys:** chat = SUPER+SHIFT+T (T is the game's chat key, SUPER+T stays Day/Night). Advancements = SUPER+L (the game's L), stats = SUPER+SHIFT+L, options = SUPER+O. My additions, in the spirit of the game's F keys: SUPER+F1 hides the HUD, SUPER+F2 takes a screenshot.
- **Cursor env:** `env =` lines in on.conf. Measured: a new process gets `XCURSOR_THEME=Overworld` after `on` and the previous value after `off`, because `hyprctl reload` re-reads `env` lines.
- **Close animation 100 ms** (fx-interactions asked for ≤ 100 ms), not the prompt's ~150 ms: the window has already broken in the shell.
- **Window size rules:** `size 60% 60%` is ignored without an error on Hyprland 0.56 (the window opened at 1892×1016). Tested on a throw-away window, `size (monitor_w*0.60) (monitor_h*0.60)` works; all rules in `rules.conf` converted. The Apothecary original has the same bug; reported, not touched.
- **Hard shadow kept:** `sharp = true`, offset 5 5, `rgba(000000b0)`. Viewed at 3× in a crop of the Day screenshot: a crisp offset silhouette with no soft falloff.
- **SDDM:** a scrolled strip, not Qt Quick 3D: a cube depends on the greeter's GPU, a texture scroll does not. `Mode=auto` picks Day or Night by the clock. Sleep in Bed kept next to Respawn and Quit Game, as Apothecary had suspend. The quote stays, where the game prints its copyright line. Monocraft is not bundled: nothing on the screen uses it.
- **hyprlock splash** picks its line from the current 10-minute window, not at random: text and hard shadow are two labels and must agree. hyprlock cannot pulse it.
- **Day N** = day of the year, the same as `TimeService` in the shell.

## Verified, and how

**Live on the real desktop**, `hypr/test/live-roundtrip.sh`. Four runs because the first three found problems (below); Overworld was on 16, 14, 18 and 16 s, about a minute in total.

Final run, all PASS, `ROUND TRIP OK`:
- `install.sh` twice earlier (run 1): no config errors, snapshot unchanged ("visually a no-op").
- `overworld on` from a running Apothecary, 1.9 s under the stress below: `hyprctl configerrors` empty, `qs -c overworld` running, Apothecary's shell stopped, waybar and mako never started, `previous-theme` = `apothecary dark`, rounding 0, border 3, SUPER+Q bound to `overworld kill`, no key newly doubled, cursor env set, test window floats at 1152×648.
- `overworld dark`: no config errors, colours follow.
- `gamemode adventure` → animations off; `gamemode survival` → back on; `f3 on|off`; IPC `gamemode get`, `world status`.
- `overworld kill <address>` on my own test window, through the real `qs -c overworld`: closed; the shell reports `mined overworld-test`, and `placed overworld-test (metal)` for the opening.
- `overworld off`, 0.7 s: no config errors, `apothecary status` as before, and a snapshot diff with no differences: wallpaper, hypridle, hyprlock link, the stock lock file's md5, its state links, 5 gsettings keys, rounding, border, SUPER+Q, layer list, mako and waybar stopped. `qs` owns the notification name.
- All this with `busctl` hammering `GetServerInformation` during on and off, to force the mako race: the journal shows mako being activated and stopped repeatedly, and the shell wins the name both ways.

**Without touching the session:**
- `hypr/test/check-config.sh`, ALL OK: `Hyprland --verify-config` on the real `hyprland.conf` + `on.conf`, both modes; every `$ow_*` in hyprlock.conf exists in both modes; every `cmd[]` runs by hand and prints; every option name is in the hyprlock binary (`fail_timeout` moved to `general` because of this); 43 keys against JaKooLit's two files: 20 free, 23 unbound first, none bound twice by us.
- `hypr/test/handover-sandbox.sh`, 64/64: install twice, on, on again, repair with mako activated, off, stock path both ways, Apothecary gone, verbs without a shell, help pages, uninstall, in a throw-away `$HOME` with session commands stubbed.
- `timeout 2 hypridle -c hypr/hypridle.conf`: parses. Its "another service provides ScreenSaver" lines are the running hypridle, expected.
- `sddm-greeter-qt6 --test-mode`, fullscreen on workspace 77: no QML errors, Day and Night viewed, text crisp at 2× zoom.
- Full shell: `timeout 15 qs -p quickshell` with private state dirs: only the expected notification warning and a `.desktop` escape warning from swappy's entry.

**Screenshots (all viewed):** `qa/screenshots/hypr-on-day.png`, `hypr-on-night.png`, `hypr-on-f3.png`, `hypr-after-off.png`, `hyprland-engineer-sddm.png`, `hyprland-engineer-sddm-night.png`; `hyprland-engineer-lock-sim-day.png`, `-night.png` are ImageMagick composites, **not hyprlock output**.

## NOT verified

- **hyprlock has never run** (running it is blocked, and it would lock the session). Layout from a simulation; `rotate = 20` assumes the documented counter-clockwise direction; font sizes assume 1 pt = 1.33 px. If the splash tilts the wrong way, flip the sign.
- **SDDM as the real greeter** (needs sudo). Login, Respawn, Quit Game and Sleep in Bed were not exercised; the power buttons are greyed out in test mode. Tab order and hover states not exercised: no input may be sent.
- **No key was physically pressed**: binds were read back from `hyprctl binds` and their commands run through the CLI, not through the keyboard. Chat, advancements, stats and options screens were not opened by me.
- **The stock path (`previous-theme` = stock) and `uninstall.sh` ran only in the sandbox**, not on the live desktop, because the desktop has Apothecary on.
- **`session-start` at a real login**, hypridle's timeouts firing, gamemode `spectator` and `creative` live, `sound`, `weather`, `daycycle`, `world new`, `screenshot` live.
- **wlogout:** I read its link chain (with the theme off it resolves to Apothecary's files, as it should) but did not view it.
- No sound was played anywhere: `sounds` stayed false, so the `door.open` login cue has not been heard.

## Problems found by the live runs

| run | what | outcome |
|---|---|---|
| 1, 3 | test window never appeared | Most likely `apps/apply-mode.sh` sending SIGUSR1 to a kitty still starting up (default action: terminate). Inferred from the timing, and it stopped once the window opened after apply-mode finished. Filed for app-theming; a test workaround here, not a fix |
| 2 | mako D-Bus activated in the gap, and **left running under Apothecary** after `off`, so its shell had no notification server | Fixed with `apothecary repair` at once, then properly with `notif_claim`; stress-tested in runs 3 and 4 |
| 2 | `size 60% 60%` ignored | Fixed in `rules.conf` |
| 1 | "no key bound twice" failed | Test bug: JaKooLit's own duplicates (SUPER+Tab, SUPER+CTRL+K, SUPER+ALT+V). Now compared against the list from before the switch |

## Left on the machine

- Installed: hook line 53 in `hyprland.conf` after Apothecary's, links, `~/.config/overworld/` state, `apps/install.sh` backups (`*.pre-overworld`). Overworld `mode` is `dark`.
- Removed after my runs, after looking at them: `~/.config/overworld/advancements.json` and `gamemode`, written by the test runs. `config.json` untouched, `"sounds": false`.
- `apothecary repair` was run once to clear the mako state above; it also did a `hyprctl reload`.
- A harmless `OW_ENVTEST_DELETEME=1` is in the live Hyprland's environment from checking `hyprctl keyword env`; it goes at next login.
- The active workspace is 77. It already was before my first screenshot, and I may not dispatch `workspace`. Filed for whoever finishes last.

## Requests

All addressed to me are marked done in `docs/REQUESTS.md`. Filed: `apply-mode.sh` SIGUSR1 race (app-theming, qa-reviewer); hyprlock's first real lock, workspace 77, Day-mode chat/System card contrast, icon theme warning, unused `fetch-minecraft-sounds.sh` (qa-reviewer); Apothecary's `size` bug (orchestrator, for the user).
