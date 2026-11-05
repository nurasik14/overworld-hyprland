# adv-reset (follow-up) — "Reset advancements" button

You own: `quickshell/Game/Advancements*.qml`, `quickshell/Game/AdvancementsState.qml`, `quickshell/Game/ChatCommands.js`,
`quickshell/Game/ChatService.qml` (only for the chat command), `scripts/overworld` (only a new `advancements reset`
verb + help text), `docs/GAMEPLAY.md`, `quotes/chat.json` (help text only).

## THE USER IS AT THE DESK (hard rules, override BRIEF where stricter)
- No screenshots with scripts/dev-shot.sh (disabled), no workspace switching, no on-screen previews/windows
  (`qs -p`, test-mode greeters, kitty test windows), no `overworld on/off/light/dark/gamemode`, no sound.
- Visual verification = offscreen renders: `QT_QPA_PLATFORM=offscreen` + a small QML/Python harness that grabs
  the scene to PNG (window.contentItem.grabToImage or QQuickWindow::grabWindow), then Read the PNG yourself.
- No sudo, no git commits. Edit only the files listed as yours.

The user asked: "Can you add a button to reset the advancements?"
1. Advancements screen (`AdvancementsScreen.qml`): a Minecraft button "Reset Advancements" (bottom bar next to Done,
   or wherever the layout allows) → opens a Minecraft-style confirm screen ("Reset all advancements?" / "This
   cannot be undone." / buttons "Reset" (red text) and "Cancel", Cancel focused by default, Esc = cancel).
2. Reset clears all advancement progress + unlocked state in `~/.config/overworld/advancements.json` (in-place
   write, same mechanism as the engine; keep the file valid), resets the engine's in-memory state so the tree
   immediately shows everything locked, does NOT re-grant silently-credited items on the spot (the engine credits
   uptime etc. at shell start — make sure a reset is not instantly undone by that logic within the same session;
   document what happens at next shell start), posts a chat line "[Overworld] Advancements have been reset", and
   emits `GameEvents.emit("advancement.reset", {})`. Statistics are NOT reset (separate option: add a
   "Reset Statistics" button on the Statistics screen with the same confirm pattern, clearing stats.json).
3. Also: IPC `advancements reset` (confirm-less, for scripts), CLI `overworld advancements reset [--yes]`
   (asks y/N on a tty unless --yes), chat `/advancement reset` (asks to type `/advancement reset confirm`).
4. Test without touching the real files: point the engine at a temp state (the existing selftest/env mechanism —
   see docs/agent-reports/qs-features.md) in an OFFSCREEN harness, unlock 2, reset, assert all locked and the
   file valid; render the confirm screen offscreen to PNG and view it (Day + Night). Back up the real
   advancements.json/stats.json to ~/.hermes/cache/scratch/ before anything and verify byte-identical after.
5. QML edits hot-reload the user's live shell: keep every save syntactically valid, check
   `~/.cache/overworld/qs.log` right after each save for errors from your files.
Report in docs/agent-reports/adv-reset.md (with the "please try" steps for the user).
