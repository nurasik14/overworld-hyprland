#!/usr/bin/env python3
"""Generate the wlogout pixel-art icons (original art, 16x16 grid, <rect>s with crispEdges).
   usage: python3 apps/wlogout/gen-icons.py   -> icons/<action>-<day|night>.svg
   Day and Night share the same art (black outlines read on both button bodies); two files per action because style.css picks icons/<label>-@MODE@.svg."""
import pathlib
OUT = pathlib.Path(__file__).parent / "icons"

ICONS = {
 # padlock: Lock
 "lock": ({"K":"#101010","G":"#d0d0d0","g":"#8b8b8b","Y":"#f2c230","y":"#ffe98a","o":"#b07d0c"}, """
................
................
.....KKKKKK.....
....KGGGGGgK....
....KGKKKKgK....
....KGK..KgK....
....KGK..KgK....
..KKKKKKKKKKKK..
..KyyyyyyyyyYK..
..KyYYYYYYYYoK..
..KyYYYKKYYYoK..
..KyYYYKKYYYoK..
..KyYYYYKYYYoK..
..KyYYYYYYYYoK..
..KooooooooooK..
..KKKKKKKKKKKK..
""".strip().splitlines()),
 # oak door: Save and Quit to Title
 "logout": ({"K":"#101010","P":"#b8945f","p":"#d0ac72","o":"#7a5a30","H":"#e8e8e8","h":"#9a9a9a"}, """
................
....KKKKKKKK....
...KppppppppK...
...KpPPPPPPoK...
...KpPPPPPPoK...
...KpPPPPPPoK...
...KpppppppoK...
...KpPPPPPPoK...
...KpPPPPHhoK...
...KpPPPPhhoK...
...KpPPPPPPoK...
...KpppppppoK...
...KpPPPPPPoK...
...KpPPPPPPoK...
...KpPPPPPPoK...
...KKKKKKKKKK...
""".strip().splitlines()),
 # bed: Sleep in Bed
 "suspend": ({"K":"#101010","R":"#c42b2b","r":"#e45a5a","d":"#8a1c1c","W":"#f4f4f4","w":"#c8c8d0","B":"#a8844f","b":"#6d5430"}, """
................
................
................
................
................
..KKKKKKKKKKKK..
.KWWWKrrrrrrrrK.
.KWwWKRRRRRRRRK.
.KWwWKRRRRRRRdK.
.KWWwKRRRRRRRdK.
.KKKKKddddddddK.
.KBBBBBBBBBBBBK.
.KbKKKKKKKKKKbK.
.KbK..........K.
.KbK.........bK.
.KKK.........KK.
""".strip().splitlines()),
 # campfire: Hibernate
 "hibernate": ({"K":"#101010","L":"#8a5a2b","l":"#5e3b17","Y":"#ffd23a","O":"#ff8a1c","R":"#e0331c","S":"#7f7f7f","s":"#4d4d4d"}, """
................
.......K........
......KOK.......
......KOOK..K...
.....KOYOOKKOK..
....KOOYYOOOOK..
....KOYYYYOOOK..
....KOYYYYYOOK..
.....KOYYYOOK...
......KOOOOK....
..KKKKKKKKKKKKK.
.KLlLLLLLLlLLLK.
KLlLKKKKKKKLlLLK
KKKKK.......KKKK
................
................
""".strip().splitlines()),
 # totem of undying: Respawn
 "reboot": ({"K":"#101010","Y":"#f2c230","y":"#ffe98a","o":"#b07d0c","G":"#4aa63a","g":"#2f7a28","W":"#ffffff","E":"#1e1e1e","B":"#8a5a2b"}, """
................
......KKKK......
....KKyyYYKK....
...KyYYYYYYoK...
..KyYYYYYYYYoK..
..KYYEWYYWEYoK..
..KYYEEYYEEYoK..
..KYYYYBBYYYoK..
...KYYYBBYYoK...
..KKKGGYYGGKKK..
.KyYYKGGGGKYYoK.
.KYYYoKGGKoYYYK.
..KKKKKggKKKKK..
......KGGK......
......KggK......
......KKKK......
""".strip().splitlines()),
 # TNT: Quit Game
 "shutdown": ({"K":"#101010","R":"#d8331f","r":"#f06a52","d":"#9a1c10","W":"#f4f4f4","w":"#c8c8c8","T":"#2a2a2a"}, """
................
KKKKKKKKKKKKKKKK
KrrrrrrrrrrrrrdK
KRRRRRRRRRRRRRdK
KRRRRRRRRRRRRRdK
KWWWWWWWWWWWWWwK
KWTTTWTWWTWTTTwK
KWWTWWTTWTWWTWwK
KWWTWWTWTTWWTWwK
KWWTWWTWWTWWTWwK
KWWTWWTWWTWWTWwK
KWWWWWWWWWWWWWwK
KRRRRRRRRRRRRRdK
KRRRRRRRRRRRRRdK
Kddddddddddddddd
KKKKKKKKKKKKKKKK
""".strip().splitlines()),
}

def svg(pal, rows, night):
    assert len(rows) == 16, len(rows)
    rects = []
    for y, row in enumerate(rows):
        assert len(row) >= 15, (y, row)
        row = row.ljust(16, ".")[:16]
        x = 0
        while x < 16:
            ch = row[x]
            if ch == ".":
                x += 1; continue
            x2 = x
            while x2 + 1 < 16 and row[x2 + 1] == ch: x2 += 1
            rects.append(f'<rect x="{x}" y="{y}" width="{x2-x+1}" height="1" fill="{pal[ch]}"/>')
            x = x2 + 1
    halo = ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" shape-rendering="crispEdges">'
            + halo + "".join(rects) + "</svg>\n")

if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for name, (pal, rows) in ICONS.items():
        for mode in ("day", "night"):
            (OUT / f"{name}-{mode}.svg").write_text(svg(pal, rows, mode == "night"))
    # remove the old light/dark (Apothecary kanji) icons
    for old in OUT.glob("*-light.svg"): old.unlink()
    for old in OUT.glob("*-dark.svg"): old.unlink()
    print("ok", sorted(p.name for p in OUT.iterdir()))
