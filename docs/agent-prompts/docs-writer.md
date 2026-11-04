# docs-writer (phase 4) — README, user guide, changelog

You own: `README.md`, `docs/HYPRLAND-GUIDE.md`, `docs/GUIDE.md` (new), `CHANGELOG.md` (new), `docs/screenshots/`
(curated copies of the best qa/screenshots — these may show Mojang textures, so put them in docs/screenshots
ONLY if they are our renders without Mojang pixels; otherwise reference qa/screenshots paths in the local
guide and leave a "screenshots: run scripts/fetch-minecraft-assets.sh" note — check what is committed vs
gitignored).

The user is an intermediate programmer, a beginner in QML/Quickshell/Hyprland/bash, and wants to understand
how the theme works. Write from the REAL files only (configs, `hyprctl binds -j`, CLI help output, agent
reports, qa/REPORT.md), never from memory:
1. `README.md`: what Overworld is, feature tour (HUD mapping table, screens, game systems, world effects,
   interactions), install/switch on/off (coexists with Apothecary), first-run steps (fetch assets, fonts,
   sounds on/off, sudo steps), keybind cheat sheet, CLI reference, config.json keys, credits/licensing
   (Mojang assets fetched not redistributed).
2. `docs/GUIDE.md`: "How it works" for a learner — the layer stack (Hyprland → hypr/*.conf → Quickshell
   config → Common components → modules → services → event bus → scripts), how a key press becomes a
   block-break animation end-to-end (trace it through the real files with file:line references), how to
   add a chat command, an advancement, a widget card, a sound; how to debug (qs logs, IPC, hyprctl).
3. `docs/HYPRLAND-GUIDE.md`: update the Apothecary guide for Overworld (binds, rules, animations explained).
4. `CHANGELOG.md`: 1.0.0 entry listing everything built (from agent reports).
Verify every command you document by running its `--help`/`help` (read-only ones only). Report in
`docs/agent-reports/docs-writer.md`.
