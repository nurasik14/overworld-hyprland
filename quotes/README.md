# quotes/ — text content for the Overworld Hyprland theme

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (the stock desktop returns in about 5 s, no logout); `overworld status` shows which state is active.
> The quotes and herbs here appear on the desktop widgets, which are shown only while the theme is on. How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

**Decorative content, not medical advice.** `herbs.json` exists to put a pretty
"Herb / Poison of the day" card on a desktop. The `fact` and `caution` fields
summarise widely documented pharmacology and history in one sentence each and
were written cautiously, but they are not dosing guidance and must never be used
as such. Consult a physician or pharmacist for anything real.

## quotes.json

Array of `{"text", "attribution", "source", "lang", "cjk"?}`.

| source | what it is |
|---|---|
| `Dhammapada N (tr. F. Max Müller, 1881, public domain)` | Verses from Müller's 1881 translation (*Sacred Books of the East* vol. X), checked against the Project Gutenberg text (#2017). Verse numbers follow Müller. |
| `Analects b:c (tr. James Legge, 1893, public domain)` | James Legge, *The Chinese Classics* vol. 1 (2nd ed. 1893), checked against the Wikisource transcription. Book:chapter follow Legge's numbering where it differs from modern editions (noted in `source`). `cjk` carries the Chinese original. |
| `The Overworld Diaries, ep 1` | Short lines from the TV anime (Crunchyroll English subtitles) as transcribed on the fan wiki's episode‑1 transcript. Only lines that could be checked against that transcript are included. |
| `original` | Original in‑character lines written for this theme (not from the novel or anime). `attribution` is empty on purpose. |
| `user` | The user's own line, unattributed by request. |

## herbs.json

Array of `{"id", "name_en", "name_cjk", "reading", "kind", "fact", "caution", "maomao_note", "plate"}`.

- `kind` is `herb`, `poison` or `both` (useful drug *and* dangerous).
- `reading` is pinyin and/or Japanese romanisation.
- `maomao_note` lines are **original writing** in Maomao's deadpan voice. They are
  not quotations from Natsu Hyuuga's novels, the manga or the anime.
- `plate` points to a theme‑recolourable ink mask (black ink on alpha, WebP) cut
  from a public‑domain plate of *植物名實圖考* (Wu Qijun, 1848, Wikimedia Commons);
  see `assets/pd/plates/` and `assets/CREDITS.md`. 14 entries have one (ginseng,
  licorice, ephedra, angelica, safflower, chrysanthemum, lotus, jujube, aconite,
  poppy, ginger, mugwort, goji, cinnamon). `null` means no mask is committed:
  seven more are mapped in `assets/pd/plates/fetch-plates.py` but not yet fetched
  (rhubarb, mint, camphor, apricot, gelsemium, henbane, oleander — run
  `fetch-plates.py` then `make-masks.py`, which refreshes this field); the rest
  (datura, foxglove, belladonna, hemlock, castor bean, star anise, clove, lily of
  the valley, reishi, and the minerals/animal drugs) have no plate in that book.
  Widgets must treat `null` as "show the fallback glyph".
