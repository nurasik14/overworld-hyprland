#!/usr/bin/env python3
"""Prints the advancement trigger table of docs/GAMEPLAY.md from quotes/advancements.json (regenerate after lore edits)."""
import json, pathlib, sys

root = pathlib.Path(__file__).resolve().parents[2]
data = json.loads((root / "quotes" / "advancements.json").read_text())["advancements"]
by_id = {a["id"]: a for a in data}


def part(t):
    if "all" in t:
        return " AND ".join(part(x) for x in t["all"])
    out = t["event"]
    c = t.get("count", 1)
    cond = t.get("condition", {})
    bits = []
    for k, v in cond.get("where", {}).items():
        if isinstance(v, dict):
            if "in" in v: bits.append(f"{k} in {{{', '.join(v['in'][:3])}{', …' if len(v['in']) > 3 else ''}}}")
            elif "gte" in v: bits.append(f"{k} ≥ {v['gte']}")
            elif "lte" in v: bits.append(f"{k} ≤ {v['lte']}")
            elif "startswith" in v: bits.append(f"{k} starts with `{v['startswith']}`")
        else:
            bits.append(f"{k} = {json.dumps(v)}")
    if "distinct" in cond: bits.append(f"distinct {cond['distinct']}")
    if "time" in cond: bits.append(f"{cond['time']['from']}–{cond['time']['to']}")
    if "unlocked_at_least" in cond: bits.append("every other advancement unlocked")
    if c > 1 and "distinct" not in cond: out += f" ×{c}"
    elif c > 1: out += f" ×{c}"
    return out + (f" ({'; '.join(bits)})" if bits else "")


tabs = []
for a in data:
    if a["tab"] not in tabs: tabs.append(a["tab"])
for tab in tabs:
    print(f"\n#### {tab}\n\n| id | frame | title | trigger | description |\n|---|---|---|---|---|")
    for a in data:
        if a["tab"] == tab:
            print(f"| `{a['id']}` | {a['frame']} | {a['title']} | {part(a['trigger'])} | {a['description']} |")
