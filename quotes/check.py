#!/usr/bin/env python3
"""Validate everything in quotes/: JSON syntax, limits, texture/icon paths, advancement tree.
Usage: python3 quotes/check.py [path-to-assets/mc]   (exit 1 on any error)"""
import json, os, sys, re

HERE = os.path.dirname(os.path.abspath(__file__))
MC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "assets", "mc")
TEX = os.path.join(MC, "textures")
EVENTS = {"window.open", "window.kill", "workspace", "screenshot", "brew.start", "brew.done", "rest.done", "notify",
          "battery", "net.connect", "launcher.launch", "chat.command", "mode", "gamemode", "wallpaper.set",
          "world.created", "advancement", "xp.levelup", "death", "$resume", "$time", "$day"}
errs = []
def err(m): errs.append(m)
def load(n):
    with open(os.path.join(HERE, n), encoding="utf-8") as f: return json.load(f)
def tex(p): return os.path.isfile(os.path.join(TEX, p + ".png"))

sp = load("splashes.json")["splashes"]
if len(sp) < 150: err(f"splashes: only {len(sp)}")
for s in sp:
    if len(s["text"]) > 40: err(f"splash too long: {s['text']}")
    if "seasonal" in s and not all(re.fullmatch(r"\d\d-\d\d", s["seasonal"][k]) for k in ("from", "to")): err(f"bad seasonal {s}")
print("splashes", len(sp), "seasonal", sum("seasonal" in s for s in sp))

bd = load("blocks-of-the-day.json")["entries"]
if len(bd) < 120: err(f"blocks-of-the-day: only {len(bd)}")
seen = set()
for e in bd:
    if e["id"] in seen: err(f"dup id {e['id']}")
    seen.add(e["id"])
    if e["kind"] not in ("block", "item", "mob", "biome"): err(f"{e['id']}: kind")
    if not tex(e["texture"]): err(f"{e['id']}: missing texture {e['texture']}")
    if not 2 <= len(e["facts"]) <= 3: err(f"{e['id']}: facts count {len(e['facts'])}")
    if not e["wiki_url"].startswith("https://minecraft.wiki/w/") or not e["tip"] or not e["since_version"]: err(f"{e['id']}: fields")
print("blocks-of-the-day", len(bd))

adv = load("advancements.json")["advancements"]
ids = {a["id"] for a in adv}
if not 40 <= len(adv) <= 60: err(f"advancements count {len(adv)}")
roots = {}
def icon_ok(n):
    c = [f"item/{n}", f"block/{n}"] + [f"block/{n}{s}" for s in ("_front", "_side", "_top")] + [f"item/{n}_00"]
    return any(tex(x) for x in c)
def check_trigger(t, i):
    for sub in t.get("all", []): check_trigger(sub, i)
    if "all" not in t and t.get("event") not in EVENTS: err(f"{i}: bad event {t.get('event')}")
for a in adv:
    i = a["id"]
    if len(a["title"]) > 24: err(f"{i}: title too long")
    if a["frame"] not in ("task", "goal", "challenge"): err(f"{i}: frame")
    if a["tab"] not in ("overworld", "adventure", "husbandry", "nether", "end"): err(f"{i}: tab")
    if a["parent"] is None: roots[a["tab"]] = roots.get(a["tab"], 0) + 1
    elif a["parent"] not in ids: err(f"{i}: parent {a['parent']}")
    elif next(x for x in adv if x["id"] == a["parent"])["tab"] != a["tab"]: err(f"{i}: parent in other tab")
    if not icon_ok(a["icon"]): err(f"{i}: missing icon {a['icon']}")
    check_trigger(a["trigger"], i)
for t in ("overworld", "adventure", "husbandry", "nether", "end"):
    if roots.get(t) != 1: err(f"tab {t}: {roots.get(t)} roots")
print("advancements", len(adv))

ch = load("chat.json")
if len(ch["tips"]) < 30 or len(ch["death_messages"]) < 15: err("chat tips/deaths too few")
for k in ("help", "errors", "system", "death_messages", "tips", "now_playing"):
    if k not in ch: err(f"chat.{k} missing")
print("chat: commands", len(ch["help"]["commands"]), "tips", len(ch["tips"]), "deaths", len(ch["death_messages"]))

ti = load("titles.json")
if [d["ws"] for d in ti["defaults"]] != list(range(1, 11)): err("titles.defaults must cover 1..10")
for d in ti["defaults"]:
    if not icon_ok(d["icon"]): err(f"titles ws{d['ws']}: missing icon {d['icon']}")
json.dumps(load("quotes.json"))

for e in errs: print("ERROR:", e)
print("OK" if not errs else f"{len(errs)} error(s)")
sys.exit(1 if errs else 0)
