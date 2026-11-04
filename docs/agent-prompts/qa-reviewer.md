# qa-reviewer (phase 3) — live integration QA + fixes, ends with Overworld ON

In phase 3 every builder has finished, so you may edit ANY file in the repo to fix integration bugs (keep
fixes minimal and note each in your report with file:line). You own `qa/` (REPORT.md, screenshots).

Read: BRIEF.md, docs/STATUS.md, every `docs/agent-reports/*.md`, docs/REQUESTS.md (unresolved requests are
bugs to triage), docs/KEYBINDS.md, docs/QUICKSHELL.md.

Steps:
1. Static: `bash -n` all scripts; json/toml parse all configs; `grep -rn "apothecary\|Maomao\|薬\|herb"
   quickshell/ hypr/ scripts/ apps/ tokens/` for leftovers that are user-visible (keep deliberate
   coexistence code); full config load `timeout 15 qs -p quickshell` with zero errors (list remaining warnings).
2. Install + switch ON for real: `scripts/install.sh`, `overworld on` (Apothecary hands over). Verify
   `overworld status`, `hyprctl configerrors` empty, `hyprctl layers -j` namespaces, waybar/mako stopped,
   one `qs -c overworld` running, keybinds present (`hyprctl binds -j`). Sounds stay disabled (config).
3. Feature matrix — exercise every BRIEF §5 parity item and every BRIEF §2 feature through IPC/CLI (never
   power actions, never connect/disconnect Wi-Fi, never media controls, never type into the user's windows),
   screenshot each surface in Day AND Night via `scripts/dev-shot.sh` (`qa/screenshots/qa-NN-<what>-<mode>.png`),
   LOOK at each screenshot critically against "does this look and behave like real Minecraft?" and "is any
   text clipped/overlapping/unreadable?". Test block-break only on your own `overworld-test` kitty on ws 77.
   Test chat commands that are harmless (/help, /tp 77? no — /tp to an empty ws then back, /weather rain then
   auto, /time set day then night, /gamemode spectator then survival, /advancement list, /stats, /f3, /seed
   only if you restore the wallpaper after).
4. Performance: CPU/RSS of `qs -c overworld` idle (30 s sample) with widgets visible, with rain, with F3;
   compare to Apothecary's ~0.7 % / 332 MB. Investigate anything > 3 % idle.
5. Round trip: `overworld off` (Apothecary must come back exactly: `apothecary status`), then `overworld on`
   again. Keep the OFF window short.
6. Fix what you find (prioritise: crashes/QML errors → broken features → visual bugs → polish). Re-verify
   after each fix. If a big feature is broken beyond a quick fix, document it precisely in REPORT.md under
   "Needs a fix pass" with file, symptom, cause hypothesis, acceptance test — the orchestrator will launch a
   targeted fix agent.
7. `qa/REPORT.md`: summary, feature matrix (PASS/FAIL/UNTESTED + screenshot), fixes made, open issues by
   severity, performance numbers, pending sudo steps, first-run instructions for the user.
End state: **Overworld ON in Day mode** (or Night if local time is between sunset and sunrise — use the
daycycle logic), widgets shown, sounds still disabled in config (the orchestrator decides), no test windows
left, workspace back to where it was. Report in `docs/agent-reports/qa-reviewer.md` too.
