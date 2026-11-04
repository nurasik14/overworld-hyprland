pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

/*  QuoteService — a random entry from quotes/quotes.json every 10 min (and on `next()`).
 *  Entry: { text, attribution, source, lang, cjk? }.  Falls back to the user's line when the file is missing.
 */
Singleton {
    id: root
    property var quotes: []
    property int index: -1
    readonly property var fallback: ({ text: "Do things out of love, not for love", attribution: "", source: "user", lang: "en" })
    readonly property var current: (index >= 0 && index < quotes.length) ? quotes[index] : fallback
    readonly property string text: current.text || ""
    readonly property string attribution: current.attribution || ""
    readonly property string cjk: current.cjk || ""
    readonly property string source: current.source || ""

    FileView {
        id: file
        path: Theme.repoDir + "/quotes/quotes.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
    function parse(t) {
        try {
            const d = JSON.parse(t || "[]");
            root.quotes = Array.isArray(d) ? d : (d.quotes || []);
        } catch (e) { console.warn("QuoteService: quotes.json parse error:", e); root.quotes = [] }
        if (root.index < 0) next();
    }
    function next() {
        if (!quotes.length) { root.index = -1; return }
        let i = Math.floor(Math.random() * quotes.length);
        if (quotes.length > 1 && i === index) i = (i + 1) % quotes.length;
        root.index = i;
    }
    function show(i) { if (i >= 0 && i < quotes.length) root.index = i }
    Timer { interval: 10 * 60 * 1000; running: true; repeat: true; onTriggered: root.next() }
    Component.onCompleted: parse(file.text())
}
