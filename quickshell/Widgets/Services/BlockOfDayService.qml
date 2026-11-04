pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

/*  HerbService — "Herb / Poison of the day" from quotes/herbs.json: herbs[dayOfYear % n], `next()` cycles.
 *  Entry: { id, name_en, name_cjk, reading, kind (herb|poison|both), fact, caution, maomao_note, plate|null }.
 *  plateUrl is "" when the plate is null or the file is missing (the card hides the image area).
 */
Singleton {
    id: root
    property var herbs: []
    property int offset: 0
    readonly property int dayOfYear: {
        const now = new Date();
        const start = new Date(now.getFullYear(), 0, 0);
        return Math.floor((now - start) / 86400000);
    }
    readonly property int index: herbs.length ? ((dayOfYear + offset) % herbs.length + herbs.length) % herbs.length : -1
    readonly property var current: index >= 0 ? herbs[index] : ({})
    readonly property string nameEn: current.name_en || "—"
    readonly property string nameCjk: current.name_cjk || ""
    readonly property string reading: current.reading || ""
    readonly property string kind: current.kind || "herb"
    readonly property string fact: current.fact || ""
    readonly property string caution: current.caution || ""
    readonly property string note: current.maomao_note || ""
    readonly property string plate: current.plate ? current.plate : ""
    readonly property string plateUrl: plate.length ? ("file://" + Theme.repoDir + "/" + plate) : ""

    FileView {
        id: file
        path: Theme.repoDir + "/quotes/herbs.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
    function parse(t) {
        try {
            const d = JSON.parse(t || "[]");
            root.herbs = Array.isArray(d) ? d : (d.herbs || []);
        } catch (e) { console.warn("HerbService: herbs.json parse error:", e); root.herbs = [] }
    }
    function next() { root.offset += 1 }
    function previous() { root.offset -= 1 }
    function today() { root.offset = 0 }
    Component.onCompleted: parse(file.text())
}
