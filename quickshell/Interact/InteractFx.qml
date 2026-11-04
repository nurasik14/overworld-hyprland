pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  InteractFx — the effect registry the Interact module shares between its logic (Miner, PlaceFx, XpFx …) and the
 *  full-screen effect layers (FxLayer, one per output, namespace overworld-break).
 *
 *    InteractFx.add(kind, rect, payload) → id     kind: "mine" | "burst" | "dust" | "orbs" | "pickup"; rect = {x,y,w,h} in
 *                                                 global (Hyprland layout) pixels; payload is any JS object, read by the effect
 *    InteractFx.setStage(id, n)                   the crack stage (0..9) of a "mine" effect
 *    InteractFx.remove(id)                        effects remove themselves when they finish
 *    InteractFx.payload(id)
 *    InteractFx.materialFor(cls, title)           stone | wood | glass | grass | wool | metal   (materials.json)
 *    InteractFx.particleFactor                    1 / 0.5 / 0.2 from config `particles` (all | decreased | minimal)
 *    InteractFx.screenFor(rect)                   index into Quickshell.screens of the output that holds the rect's centre
 */
Singleton {
    id: root
    readonly property alias model: fxModel
    readonly property int count: fxModel.count
    property var _payloads: ({})
    property var _expires: ({})
    property int _next: 1

    ListModel { id: fxModel }

    // ttl (ms): a safety net — an effect whose layer never reported back (no output, crashed delegate) is dropped after it
    function add(kind, rect, payload, ttl) {
        const id = root._next++;
        root._payloads[id] = payload || ({});
        root._expires[id] = Date.now() + (ttl || 5000);
        sweeper.running = true;
        fxModel.append({ eid: id, kind: kind, gx: Math.round(rect.x), gy: Math.round(rect.y), gw: Math.round(rect.w), gh: Math.round(rect.h), stage: 0 });
        return id;
    }
    function _index(id) {
        for (let i = 0; i < fxModel.count; i++) if (fxModel.get(i).eid === id) return i;
        return -1;
    }
    function setStage(id, n) { const i = _index(id); if (i >= 0) fxModel.setProperty(i, "stage", n); }
    function remove(id) {
        const i = _index(id);
        if (i >= 0) fxModel.remove(i);
        delete root._payloads[id];
        delete root._expires[id];
    }
    function payload(id) { return root._payloads[id] || ({}); }
    function clear() { fxModel.clear(); root._payloads = ({}); root._expires = ({}); }
    Timer {
        id: sweeper
        interval: 1000; repeat: true
        onTriggered: {
            const now = Date.now();
            for (let i = fxModel.count - 1; i >= 0; i--) {
                const id = fxModel.get(i).eid;
                if ((root._expires[id] || 0) < now) root.remove(id);
            }
            if (fxModel.count === 0) running = false;
        }
    }

    // test hook: OW_INTERACT_SLOWMO=4 plays every particle effect 4× slower (screenshots of 0.5 s effects)
    readonly property real slow: Math.max(1, Number(Quickshell.env("OW_INTERACT_SLOWMO")) || 1)

    // every sound of this module goes through here; OW_INTERACT_DEBUG=1 logs "interact sound <id>" (ow-sound runs detached, its dry-run output is lost)
    readonly property bool debug: Quickshell.env("OW_INTERACT_DEBUG") === "1"
    function sound(id) {
        if (debug) console.warn("interact sound", id);
        Theme.playSound(id);
    }
    function log() { if (debug) console.warn.apply(console, ["interact"].concat(Array.prototype.slice.call(arguments))); }

    // ---------------------------------------------------------------- particles setting
    readonly property real particleFactor: ({ "all": 1, "decreased": 0.5, "minimal": 0.2 })[ConfigService.particles] ?? 1

    // ---------------------------------------------------------------- outputs
    function screenFor(rect) {
        const cx = rect.x + rect.w / 2, cy = rect.y + rect.h / 2;
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            const s = list[i];
            if (cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height) return i;
        }
        return list.length ? 0 : -1;
    }

    // ---------------------------------------------------------------- materials.json
    property var _rules: []
    property string _default: "stone"
    readonly property string materialsPath: Theme.repoDir + "/quickshell/Interact/materials.json"
    FileView {
        id: materialsFile
        path: root.materialsPath
        blockLoading: true
        printErrors: false
        onLoaded: root._parseMaterials(text())
        onLoadFailed: error => console.warn("InteractFx: materials.json:", error)
    }
    Connections {   // Theme finds the repo root asynchronously in the worst case; look again once it has
        target: Theme
        function onRepoIndexChanged() { materialsFile.reload(); }
    }
    function _parseMaterials(t) {
        try {
            const j = JSON.parse(t);
            root._default = j.default || "stone";
            root._rules = (j.rules || []).map(r => ({
                material: r.material,
                cls: r.class ? new RegExp(r.class, "i") : null,
                title: r.title ? new RegExp(r.title, "i") : null
            }));
        } catch (e) { console.warn("InteractFx: bad materials.json:", e); }
    }
    function materialFor(cls, title) {
        const c = String(cls || ""), t = String(title || "");
        for (let i = 0; i < root._rules.length; i++) {
            const r = root._rules[i];
            if (r.cls && !r.cls.test(c)) continue;
            if (r.title && !r.title.test(t)) continue;
            return r.material;
        }
        return root._default;
    }
    Component.onCompleted: _parseMaterials(materialsFile.text())
}
