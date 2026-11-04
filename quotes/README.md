# quotes/ — text content for the Overworld Hyprland theme

All text here is original writing (own words, no copied passages). Minecraft facts were checked against
minecraft.wiki when written; Mojang's own `assets/mc/texts/splashes.txt` is **not** copied (the shell may mix lines
from it in at runtime). Validate everything with `python3 quotes/check.py [assets/mc]` (JSON syntax, limits, every
texture/icon path, advancement tree, event names).

Placeholders in `{braces}` are filled in at runtime. `{player}` defaults to `Nurasik`.

## splashes.json
`{"splashes": [{"text", "seasonal"?: {"from": "MM-DD", "to": "MM-DD"}}]}` — 272 splashes, text ≤ 40 chars.
`seasonal` entries show only inside the (inclusive, year-wrapping) date range, e.g. Nauryz Mar 21–23, New Year
Dec 31–Jan 2, Halloween Oct 30–Nov 1; on those dates prefer them like the game does.

## blocks-of-the-day.json
`{"entries": [{id, kind: "block"|"item"|"mob"|"biome", name, texture, facts[2–3], tip, wiki_url, since_version}]}` —
125 entries. `texture` is a path under `assets/mc/textures/` without `.png` (`block/…`, `item/…`, `entity/…`; biomes
use a representative block texture). Pick `entries[dayOfYear % n]`. `since_version` is the Java version named in
the wiki page's History.

## advancements.json
`{"advancements": [{id, tab, parent, frame, title ≤ 24, description, icon, trigger, hidden?}]}` — 60 entries.
- `tab`: overworld | adventure | husbandry | nether | end; exactly one root per tab (`parent: null`).
- `frame`: task | goal | challenge. `icon`: item/block name from assets/mc (resolved as `item/<n>`, `block/<n>`,
  `block/<n>_front|_side|_top`, or `item/<n>_00` for animated clocks/compasses).
- `trigger`: `{event, count?, condition?}` or `{all: [trigger, …]}` (every sub-trigger satisfied; counts are
  cumulative lifetime counts, default 1). `event` is a BRIEF §4.4 event, plus three derived pseudo-events the
  engine computes itself: `$resume` (wall clock jumped forward > 2 min = suspend/resume), `$time` (checked once a
  minute while the session is active), `$day` (once per local day of activity).
- `condition` keys (all optional, AND-combined, evaluated on the event's data):
  - `where`: `{field: value}` equals; or `{field: {in:[…]|gte:n|lte:n|startswith:s}}`. Window class compare is
    case-insensitive.
  - `distinct`: field name — `count` then means *distinct values seen* of that field (workspace ids, modes, dates).
    `$day` uses `distinct: "date"` over `YYYY-MM-DD`.
  - `time`: `{from:"HH:MM", to:"HH:MM"}` local time (wraps midnight).
  - `unlocked_at_least: "all_others"` — on `advancement` events: every other advancement unlocked.
- Uptime advancements use `xp.levelup {level}` (level = hours of uptime).

## chat.json
`player_default`, `help` (`per_page`, `header`, `usage`, `footer`, `commands[]` with `name`, `usage`,
`description`, `args[]` for tab completion: `{name, type: choice|duration|workspace|app|text|command, choices?}`),
`errors` (game-voice error lines), `ok` (command success lines), `system` (join/leave, screenshot, advancement
chat lines, battery, Wi-Fi …), `death_messages[]` (24, low-battery screen), `death_screen` (title/buttons/hardcore
variant), `tips[]` (42 loading-screen tips; key names follow BRIEF §4.7 and must stay in sync with
docs/KEYBINDS.md), `now_playing` (media/boss-bar formats), `misc`.

## titles.json
`defaults[]` — `{ws, title, subtitle, icon}` for workspaces 1–10 (used when the user has no title);
`subtitles{category: [lines]}` — random /title subtitle by dominant-app category (`{count}` = window count);
`categories{category: [window classes]}` — class → category map; `title_format` — the real /title tick timings.

## quotes.json
`[{text, attribution, source: "original", lang}]` — short lines for the Quote widget, hyprlock and fastfetch
(same shape the Apothecary consumers read).

## herbs.json (legacy)
Apothecary leftover, still read by `quickshell/Widgets/Services/HerbService.qml`; remove once qs-widgets switches
the card to `blocks-of-the-day.json` (see docs/REQUESTS.md).
