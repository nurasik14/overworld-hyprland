#!/usr/bin/env python3
"""Check the generated Overworld Kvantum themes: SVG is valid XML, and every element a kvconfig section refers to exists."""
import configparser, os, sys
from xml.dom import minidom
here = os.path.dirname(os.path.abspath(__file__))
rc = 0
for name in ("OverworldDay", "OverworldNight"):
    d = os.path.join(here, name)
    doc = minidom.parse(os.path.join(d, name + ".svg"))
    ids = {e.getAttribute("id") for e in doc.getElementsByTagName("g") if e.getAttribute("id")}
    cp = configparser.RawConfigParser(strict=False); cp.optionxform = str
    cp.read(os.path.join(d, name + ".kvconfig"))
    def get(sec, key, seen=()):
        if cp.has_option(sec, key): return cp.get(sec, key)
        if cp.has_option(sec, "inherits") and sec not in seen:
            return get(cp.get(sec, "inherits"), key, seen + (sec,))
        return None
    missing = set()
    for sec in cp.sections():
        if sec in ("%General", "GeneralColors", "Hacks"): continue
        fr, it, ind = get(sec, "frame") == "true", get(sec, "interior"), get(sec, "indicator.element")
        fe, ie = get(sec, "frame.element"), get(sec, "interior.element")
        # these have no "normal" drawing on purpose (transparent until hovered/selected, like KvFlat)
        optional = ("itemview", "menuitem", "menubaritem", "splitter")
        if fr and fe and fe not in optional:
            for pos in ("top","bottom","left","right","topleft","topright","bottomleft","bottomright"):
                if "%s-normal-%s" % (fe, pos) not in ids and "%s-%s" % (fe, pos) not in ids:
                    missing.add((sec, "%s-normal-%s" % (fe, pos)))
        if it != "false" and ie and ie not in optional:
            if "%s-normal" % ie not in ids and ie not in ids: missing.add((sec, ie + "-normal"))
        if ind and ind != "false":
            if not any(i.startswith(ind + "-") or i == ind for i in ids): missing.add((sec, ind))
    print(name, "ids:", len(ids), "svg ok; missing:", sorted(missing) or "none")
    if missing: rc = 1
sys.exit(rc)
