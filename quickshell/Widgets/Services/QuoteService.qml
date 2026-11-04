pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

/*  QuoteService — the sign's message and the splash on its corner.
 *    quote   a random entry of quotes/quotes.json ({text, attribution, source, lang}) every 10 min and on `next()`;
 *            falls back to the user's own line when the file is missing.
 *    splash  a random line from the pool  quotes/splashes.json (seasonal entries only inside their date range and
 *            preferred then, like the game)  +  Mojang's own assets/mc/texts/splashes.txt WHEN IT EXISTS (read at
 *            runtime, never copied into the repo).  A new one is picked with every `next()` and every 10 min.
 */
Singleton {
    id: root
    property var quotes: []
    property int index: -1
    readonly property var fallback: ({ text: "Do things out of love, not for love", attribution: "", source: "user", lang: "en" })
    readonly property var current: (index >= 0 && index < quotes.length) ? quotes[index] : fallback
    readonly property string text: current.text || ""
    readonly property string attribution: current.attribution || ""
    readonly property string source: current.source || ""

    property var ownSplashes: []
    property var mojangSplashes: []
    property string splash: "Hyprland btw!"

    FileView {
        id: file
        path: Theme.repoDir + "/quotes/quotes.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
    FileView {
        id: splashFile
        path: Theme.repoDir + "/quotes/splashes.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parseSplashes(text())
        onFileChanged: reload()
    }
    FileView {   // Mojang's list: optional, local only (asset-forge's fetch script extracts it)
        id: mojangFile
        path: Theme.assetsDir + "/mc/texts/splashes.txt"
        blockLoading: true
        printErrors: false
        onLoaded: root.parseMojang(text())
    }

    function parse(t) {
        try {
            const d = JSON.parse(t || "[]");
            root.quotes = Array.isArray(d) ? d : (d.quotes || []);
        } catch (e) { console.warn("QuoteService: quotes.json parse error:", e); root.quotes = [] }
        if (root.index < 0) nextQuote();
    }
    function inSeason(r) {     // "MM-DD" range, inclusive, may wrap the year end
        const n = new Date();
        const today = ("0" + (n.getMonth() + 1)).slice(-2) + "-" + ("0" + n.getDate()).slice(-2);
        return r.from <= r.to ? (today >= r.from && today <= r.to) : (today >= r.from || today <= r.to);
    }
    property var seasonal: []
    function parseSplashes(t) {
        try {
            const d = JSON.parse(t || "{}");
            const list = Array.isArray(d) ? d : (d.splashes || []);
            root.ownSplashes = list.filter(s => !s.seasonal).map(s => s.text);
            root.seasonal = list.filter(s => s.seasonal && inSeason(s.seasonal)).map(s => s.text);
        } catch (e) { console.warn("QuoteService: splashes.json parse error:", e); root.ownSplashes = []; root.seasonal = [] }
        nextSplash();
    }
    function parseMojang(t) {
        root.mojangSplashes = (t || "").split("\n").map(l => l.trim()).filter(l => l.length > 0 && l.length <= 40 && l.indexOf("§") < 0);
    }
    function pick(list) { return list.length ? list[Math.floor(Math.random() * list.length)] : "" }
    function nextQuote() {
        if (!quotes.length) { root.index = -1; return }
        let i = Math.floor(Math.random() * quotes.length);
        if (quotes.length > 1 && i === index) i = (i + 1) % quotes.length;
        root.index = i;
    }
    function nextSplash() {
        // in season the game shows the seasonal line most of the time; otherwise our own pool, one in four from Mojang's
        let s = "";
        if (root.seasonal.length && Math.random() < 0.6) s = pick(root.seasonal);
        else if (root.mojangSplashes.length && Math.random() < 0.25) s = pick(root.mojangSplashes);
        else s = pick(root.ownSplashes);
        if (s.length) root.splash = s;
    }
    function next() { nextQuote(); nextSplash() }
    function show(i) { if (i >= 0 && i < quotes.length) root.index = i }
    Timer { interval: 10 * 60 * 1000; running: true; repeat: true; onTriggered: root.next() }
    Component.onCompleted: { parse(file.text()); parseSplashes(splashFile.text()); parseMojang(mojangFile.text()) }
}
