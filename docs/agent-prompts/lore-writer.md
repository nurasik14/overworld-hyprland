# lore-writer (phase 1) — all text content

You own: `quotes/` (replace the Apothecary herbs/quotes content; keep the old files only if something still
reads them — check with grep — otherwise delete `quotes/herbs.json` and rewrite `quotes/README.md`).

Write accurate, fun, Minecraft-voiced text the shell displays. Facts must be checkable on minecraft.wiki — use
WebFetch on https://minecraft.wiki pages to verify; mark anything unverifiable `"source": "original"`. Never
copy long passages; short factual statements in your own words.

1. `quotes/splashes.json`: 150+ ORIGINAL splash texts in Minecraft's style but about this desktop/user
   (Hyprland, Fedora, Linux, kitty, Hong Kong, CityU, Kazakhstan, coding, Hermes agent, late-night building,
   "Also try Apothecary!", "Now with 100% more hearts!", "Tiling is a lifestyle!"…), ≤ 40 chars each, plus a
   flag for seasonal ones (date ranges like the game's Christmas/New Year/Halloween/birthday splashes — make
   ones for Nauryz (Mar 21–23), New Year, Halloween). The real `assets/mc/texts/splashes.txt` exists
   (Mojang's, not ours) — the shell may mix in random lines from it at runtime; do not copy it.
2. `quotes/blocks-of-the-day.json`: 120+ entries `{id, kind: "block"|"item"|"mob"|"biome", name, texture
   (path under assets/mc/textures without .png, e.g. "block/amethyst_block", or "entity/…" for mobs — check the
   file exists), facts: [2–3 short verified facts], tip: one practical tip, wiki_url, since_version}`. Verify
   every texture path exists in `assets/mc/textures/`.
3. `quotes/advancements.json`: 40–60 desktop advancements for qs-features to implement:
   `{id, tab: "overworld"|"adventure"|"husbandry"|"nether"|"end", parent, frame: "task"|"goal"|"challenge",
   title (Minecraft-pun title ≤ 24 chars), description, icon (item/block name from assets/mc), trigger: {event
   (from BRIEF §4.4 event names), count?, condition?}, hidden?}` — e.g. "Getting an Upgrade" (open a
   terminal), "Monster Hunter" (mine 100 windows), "Sleep Through the Night" (suspend and resume), "Night Owl"
   (active after 02:00), "Brewed Awakening" (finish 10 brews), "Adventuring Time" (visit all 10 workspaces),
   "Free the End" (close 1000 windows), "Hot Tourist Destinations" (switch to dark mode), "Diamonds!" (connect
   to Wi-Fi), "Isn't It Iron Pick" (uptime 3 h), "Cover Me in Debris" (get 100 notifications),
   "How Did We Get Here?" (challenge: lots of conditions) … Each trigger must be computable from the events
   list (or from battery/uptime/time-of-day values) — keep it implementable.
4. `quotes/chat.json`: the chat console texts — `/help` pages for every command in BRIEF §2 "another level"
   (usage line + one-line description, Minecraft-style), error messages in the game's voice ("Unknown command.
   Type "/help" for help.", "Incorrect argument for command"), join/leave style system lines ("Nurasik joined the
   game" at login, "Nurasik left the game" at logout), death messages for the low-battery screen ("Nurasik ran
   out of battery", "Nurasik was slain by a kernel panic", 15+), loading-screen tips ("Press SUPER+F3 to see
   the debug screen", …, 30+), and "Now Playing" format.
5. `quotes/titles.json`: workspace /title subtitles by app category and default biome-style names for
   workspaces 1–10 ("Spawn", "The Workshop", "Library", …) used when the user has no title.
6. `quotes/README.md`: schema of every file.

Validate all JSON with `python3 -m json.tool`, and a small script that checks every texture path exists.
Report in `docs/agent-reports/lore-writer.md`.
