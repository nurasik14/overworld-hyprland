#!/usr/bin/env python3
"""Generate tokens/sounds.json (the id -> files map used by scripts/ow-sound) and validate every path.

Schema per id:  {"files": ["mc:<path under assets/mc/sounds>", ...],     random variant of those that exist
                 "fallback": ["gen:<name in assets/gen/sounds>", ...],  used when none of `files` exist
                 "volume": 0..1, "category": "ui|toasts|blocks|ambient", "desc": "..."}
or an alias:    {"alias": "<other id>"}
Run:  python3 tools/assetforge/build_sounds_map.py [--check-only]   (plain stdlib python is enough)
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def mc(*names, n=None):
    return [f"mc:{x}" for x in names]


def numbered(prefix, count):
    return [f"mc:{prefix}{i}" for i in range(1, count + 1)]


def g(*names):
    return [f"gen:{n}" for n in names]


S = {}


def add(id_, files, fb, vol, cat, desc):
    S[id_] = {"files": files, "fallback": fb, "volume": vol, "category": cat, "desc": desc}


# ---- UI ---------------------------------------------------------------------------------------------------
add("ui.click", mc("random/click"), g("click"), 0.5, "ui", "button / slot click")
add("ui.click.stereo", mc("random/click_stereo"), g("click"), 0.5, "ui", "alternative button click")
add("ui.toast.in", mc("ui/toast/in"), g("toast_in"), 0.6, "toasts", "toast slides in")
add("ui.toast.out", mc("ui/toast/out"), g("toast_out"), 0.5, "toasts", "toast slides out")
add("ui.toast.challenge", mc("ui/toast/challenge_complete"), g("challenge"), 0.7, "toasts", "Challenge Complete! toast")
add("notify", mc("note/pling"), g("notify"), 0.35, "toasts", "normal notification arrives")
add("notify.urgent", mc("ui/toast/challenge_complete"), g("notify_urgent"), 0.6, "toasts", "urgent notification")
add("xp.orb", mc("random/orb"), g("orb"), 0.45, "ui", "experience orb pickup")
add("xp.levelup", mc("random/levelup"), g("levelup"), 0.6, "ui", "level up (uptime hour)")
add("chest.open", mc("block/chest/open"), g("chest_open"), 0.55, "ui", "open a chest / panel")
add("chest.close", numbered("block/chest/close", 3), g("chest_close"), 0.55, "ui", "close a chest / panel")
add("door.open", numbered("block/wooden_door/open", 2), g("door_open"), 0.5, "ui", "wooden door opens")
add("door.close", numbered("block/wooden_door/close", 3), g("door_close"), 0.5, "ui", "wooden door closes")
add("book.page", numbered("item/book/open_flip", 3), g("page"), 0.5, "ui", "book page turn")
add("item.pickup", mc("random/pop"), g("pop"), 0.45, "ui", "item pickup pop")
add("brew.done", numbered("block/brewing_stand/brew", 2), g("brew"), 0.7, "ui", "brew timer finished")
add("brew.drink", mc("random/drink"), g("drink"), 0.6, "ui", "rest finished: drink the potion")
add("anvil.land", mc("random/anvil_land"), g("anvil"), 0.45, "ui", "anvil lands")
add("anvil.use", mc("random/anvil_use"), g("anvil"), 0.45, "ui", "anvil used")
add("bell", ["mc:block/bell/bell_use01", "mc:block/bell/bell_use02"], g("bell"), 0.5, "ui", "bell rings")
add("note.harp", mc("note/harp"), g("harp"), 0.5, "ui", "note block: harp")
add("note.pling", mc("note/pling"), g("notify"), 0.5, "ui", "note block: pling")
add("player.hurt", numbered("damage/hit", 3), g("hurt"), 0.55, "ui", "player takes damage (low battery warning)")
add("player.death", numbered("damage/hit", 3), g("death"), 0.7, "ui", "You died!")
add("villager.no", numbered("mob/villager/no", 3), g("hurt"), 0.5, "ui", "error / refused")
add("villager.yes", numbered("mob/villager/yes", 3), g("pop"), 0.5, "ui", "accepted")
# ---- ambient / weather -------------------------------------------------------------------------------------
add("portal.trigger", mc("portal/trigger"), g("portal"), 0.15, "ambient", "very quiet portal whoosh")
add("lightning", numbered("ambient/weather/thunder", 3), g("thunder"), 0.3, "ambient", "thunder (quiet)")
add("lightning.impact", numbered("random/explode", 4), g("thunder"), 0.2, "ambient", "lightning strike crack (quiet)")
add("rain.ambient", numbered("ambient/weather/rain", 4), g("rain"), 0.15, "ambient", "rain loop segment (quiet)")

# ---- block materials ---------------------------------------------------------------------------------------
mats = {  # material: (break, place, hit)  — same sound events the game uses for these block sound types
    "stone": (numbered("dig/stone", 4), numbered("dig/stone", 4), numbered("step/stone", 4), 0.7),
    "wood": (numbered("dig/wood", 4), numbered("dig/wood", 4), numbered("step/wood", 4), 0.7),
    "glass": (numbered("random/glass", 3), numbered("dig/stone", 4), numbered("step/stone", 4), 0.65),
    "grass": (numbered("dig/grass", 4), numbered("dig/grass", 4), numbered("step/grass", 4), 0.7),
    "wool": (numbered("dig/cloth", 4), numbered("dig/cloth", 4), numbered("step/cloth", 4), 0.7),
    "metal": (numbered("dig/stone", 4), numbered("dig/stone", 4), numbered("step/stone", 4), 0.7),
}
for m, (brk, plc, hit, vol) in mats.items():
    add(f"block.break.{m}", brk, g(f"break_{m}_1", f"break_{m}_2"), vol, "blocks", f"{m} block broken (window closes)")
    add(f"block.place.{m}", plc, g(f"place_{m}_1", f"place_{m}_2"), vol * .85, "blocks", f"{m} block placed (window opens)")
    add(f"block.hit.{m}", hit, g(f"hit_{m}_1", f"hit_{m}_2"), vol * .6, "blocks", f"{m} block hit (mining tick)")

# ---- aliases (friendly synonyms) ----------------------------------------------------------------------------
ALIAS = {"challenge": "ui.toast.challenge", "ui.toast.challenge_complete": "ui.toast.challenge", "ui.button.click": "ui.click",
         "brew": "brew.done", "drink": "brew.drink", "levelup": "xp.levelup", "pickup": "item.pickup",
         "block.break": "block.break.stone", "block.place": "block.place.stone", "block.hit": "block.hit.stone"}
for a, t in ALIAS.items():
    S[a] = {"alias": t}

REQUIRED = """ui.click ui.toast.in ui.toast.out ui.toast.challenge notify notify.urgent xp.orb xp.levelup chest.open
chest.close door.open door.close book.page item.pickup brew.done brew.drink anvil.land bell note.harp portal.trigger
player.hurt player.death lightning rain.ambient""".split() + [f"block.{k}.{m}" for k in ("break", "place", "hit") for m in mats]


def validate():
    bad = 0
    for id_, e in S.items():
        if "alias" in e:
            assert e["alias"] in S, id_
            continue
        for f in e["files"]:
            p = REPO / "assets/mc/sounds" / (f[3:] + ".ogg")
            if not p.is_file():
                print(f"MISSING mc: {id_}: {p}"); bad += 1
        for f in e["fallback"]:
            if not (REPO / "assets/gen/sounds" / (f[4:] + ".wav")).is_file():
                print(f"MISSING gen: {id_}: {f}"); bad += 1
    for r in REQUIRED:
        if r not in S:
            print(f"MISSING id {r}"); bad += 1
    return bad


if __name__ == "__main__":
    bad = validate()
    if "--check-only" not in sys.argv:
        out = {"_comment": "generated by tools/assetforge/build_sounds_map.py; mc: -> assets/mc/sounds/<p>.ogg, gen: -> assets/gen/sounds/<p>.wav; "
                           "categories ui|toasts|blocks|ambient follow config.json sound_volume",
               **S}
        (REPO / "tokens/sounds.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n")
        print(f"wrote tokens/sounds.json ({len(S)} ids)")
    sys.exit(1 if bad else 0)
