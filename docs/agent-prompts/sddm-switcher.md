# sddm-switcher (follow-up) — login screen with a theme button (look + desktop theme)

You own: `sddm/` (new wrapper theme `sddm/hyprthemes/`, keep `sddm/overworld/` working), `scripts/install-sddm.sh`,
new `scripts/theme-session` + `sessions/*.desktop`, `scripts/overworld` (only a new offline `prepare` verb if
needed), `docs/SUDO-STEPS.md`, `docs/LOGIN.md` (new). Read-only: `~/Projects/apothecary-hyprland/sddm/apothecary`
(copy it into the wrapper at install time, don't edit the original), `/usr/share/sddm/themes/silent` (the user's
current login theme "SilentSDDM" with `ConfigFile=configs/waguri.conf` — the "Waguri" look; it uses components/,
qmldir, sectioned config keys like `LockScreen.Clock/...`, fonts, a waguri.mp4 background), `/etc/sddm.conf`
(`Current=silent`, DisplayServer=wayland, Qt6 greeter).

## THE USER IS AT THE DESK (hard rules, override BRIEF where stricter)
- No screenshots with scripts/dev-shot.sh (disabled), no workspace switching, no on-screen previews/windows
  (`qs -p`, test-mode greeters, kitty test windows), no `overworld on/off/light/dark/gamemode`, no sound.
- Visual verification = offscreen renders: `QT_QPA_PLATFORM=offscreen` + a small QML/Python harness that grabs
  the scene to PNG (window.contentItem.grabToImage or QQuickWindow::grabWindow), then Read the PNG yourself.
- No sudo, no git commits. Edit only the files listed as yours.

User request: "SDDM login is not right (still Waguri). Add a button on the login screen to select the themes" →
clarified: the button switches BOTH the login screen's look (Waguri / Overworld / Apothecary) AND which desktop
theme the session logs into (Overworld / Apothecary / stock-with-Waguri).

Design to implement (improve it if you find a better way, document why):
1. **Wrapper SDDM theme `hyprthemes`** (Qt6, `/usr/share/sddm/themes/hyprthemes` after install): `Main.qml` hosts
   the three looks and a small always-visible **theme button** (top-right corner, styled neutrally or per look;
   keyboard reachable; cycles or opens a 3-item menu: "Waguri", "Overworld", "Apothecary"). The chosen look is
   remembered across boots (Qt `QtCore.Settings` / `Qt.labs.settings` — persisted in the sddm user's home
   /var/lib/sddm; verify which import works in this Qt version offscreen). Switching should cross-fade.
   The hard part: each sub-theme expects SDDM's `config` context object with ITS OWN keys (Silent reads a
   sectioned ConfigFile; Overworld/Apothecary read theme.conf [General]). Investigate SDDM's config API and the
   three themes' config access, then pick a robust approach, e.g. (a) a merged wrapper theme.conf whose keys don't
   collide (check!) with each sub-theme loaded via Loader from its own subdirectory so relative asset paths
   resolve, or (b) give each sub-theme a JS/QML shim object named `config` (patch the copied sub-theme
   sources at install time with a scripted, reproducible transform — never by hand-editing the user's
   /usr/share files), or (c) anything better. Silent's video background, fonts and components must still work.
2. **Desktop theme coupling:** SDDM can only pass the chosen *session* to the login. Create session files
   (installed to /usr/share/wayland-sessions/ by the sudo script): "Hyprland · Overworld", "Hyprland ·
   Apothecary", "Hyprland · Stock" with `Exec=/usr/local/bin/hypr-theme-session <theme>` (installed copy of
   `scripts/theme-session`). That wrapper runs as the user BEFORE Hyprland: switches the theme state offline
   (state files + symlinks only, no hyprctl — Overworld: `~/.config/overworld/{enabled,active.conf,previous-theme}`,
   Apothecary: `~/.config/apothecary/{enabled,active.conf}`; read both CLIs (`scripts/overworld`,
   `~/Projects/apothecary-hyprland/scripts/apothecary`) to replicate exactly what on/off change on disk incl.
   hyprlock.conf link chain, waybar/mako handling happens at session-start via exec-once — verify each theme's
   session-start path handles a cold start; add an `overworld prepare <on|off>` verb if cleaner), logs to
   ~/.cache/hypr-theme-session.log, then `exec /usr/bin/start-hyprland`. Must be safe if a theme repo is missing
   (falls back to stock), and idempotent. In the greeter, choosing a look also selects the matching session in
   `sessionModel` (and the session selector still works for Plasma etc.; picking another session manually keeps
   the look).
3. **`scripts/install-sddm.sh`** gains `hyprthemes` mode: `sudo scripts/install-sddm.sh hyprthemes` builds the
   wrapper (copies silent, overworld, apothecary themes + fonts into it, applies any scripted shims), installs
   session files + /usr/local/bin/hypr-theme-session, sets `/etc/sddm.conf.d/zz-hyprthemes.conf` `[Theme]
   Current=hyprthemes` (leave /etc/sddm.conf untouched), and `revert` restores the previous state exactly. A
   `prepare` step that builds everything into a user-writable staging dir without sudo, so you can test.
4. **Test without sudo:** build into staging; run the greeter offscreen
   (`QT_QPA_PLATFORM=offscreen sddm-greeter-qt6 --test-mode --theme <staging>/hyprthemes` if it renders offscreen;
   otherwise a QML harness with fake `config`/`sddm`/`userModel`/`sessionModel`/`keyboard` objects) and grab PNGs of
   all three looks + the theme menu, view them. Test theme-session with a fake HOME copy of both state dirs
   (never the real ones) for every transition (stock→overworld, overworld→apothecary, apothecary→stock, repeated),
   asserting resulting files/symlinks; `bash -n` everything; `desktop-file-validate` the session files.
5. Docs: `docs/LOGIN.md` (how it works, how to add a look) + the exact sudo command in `docs/SUDO-STEPS.md`.
Report in docs/agent-reports/sddm-switcher.md with the one sudo command the user must run and what they'll see.
