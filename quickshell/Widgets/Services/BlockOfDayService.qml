pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

/*  BlockOfDayService — "Block / Mob of the day" from quotes/blocks-of-the-day.json (lore-writer):
 *  entries[(dayOfYear + offset) % n], deterministic by date; `next()` / `previous()` page through, `today()` goes back.
 *  Entry: { id, kind: block|item|mob|biome, name, texture, facts[2–3], tip, wiki_url, since_version }.
 *  `texture` is a path under assets/mc/textures/ without .png; mobs use their spawn egg (item/<id>_spawn_egg) because the
 *  entity textures are skin sheets, not pictures.  `textureName` is what the card draws (resolve with Theme.tex()).
 */
Singleton {
    id: root
    property var entries: []
    property int offset: 0
    readonly property int dayOfYear: {
        const now = new Date();
        const start = new Date(now.getFullYear(), 0, 0);
        return Math.floor((now - start) / 86400000);
    }
    readonly property int index: entries.length ? ((dayOfYear + offset) % entries.length + entries.length) % entries.length : -1
    readonly property var current: index >= 0 ? entries[index] : ({})
    readonly property string id: current.id || ""
    readonly property string kind: current.kind || "block"
    readonly property string name: current.name || "—"
    readonly property var facts: current.facts || []
    readonly property string tip: current.tip || ""
    readonly property string since: current.since_version || ""
    readonly property string wikiUrl: current.wiki_url || ""
    readonly property string textureName: kind === "mob" ? "item/" + id + "_spawn_egg" : (current.texture || "")
    readonly property string kindLabel: kind === "mob" ? "Mob" : kind === "item" ? "Item" : kind === "biome" ? "Biome" : "Block"

    FileView {
        id: file
        path: Theme.repoDir + "/quotes/blocks-of-the-day.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
    function parse(t) {
        try {
            const d = JSON.parse(t || "{}");
            root.entries = Array.isArray(d) ? d : (d.entries || []);
        } catch (e) { console.warn("BlockOfDayService: blocks-of-the-day.json parse error:", e); root.entries = [] }
    }
    function next() { root.offset += 1 }
    function previous() { root.offset -= 1 }
    function today() { root.offset = 0 }
    Component.onCompleted: parse(file.text())
}
