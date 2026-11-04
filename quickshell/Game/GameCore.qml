pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  GameCore — locations, helpers and the shared texts of the Game module.
 *    stateDir          ~/.config/overworld, or $OW_STATE_DIR (tests: every file this module writes goes there)
 *    run(argv)         execDetached, or — with OW_GAME_DRYRUN=1 — only log the command (dryRunLogged)
 *    ipc(target, fn, args…)   `qs <OW_QS_ARGS|-c overworld> ipc call target fn args…` against the running shell
 *    cli(args…)        scripts/overworld args…
 *    t(path, vars)     text from quotes/chat.json ("ok.time_day"), {placeholders} filled; returns "" when missing
 *    player            display name: config.json "player", else chat.json player_default
 */
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: Quickshell.env("OW_STATE_DIR") || (home + "/.config/overworld")
    readonly property string repoDir: Theme.repoDir
    readonly property string quotesDir: repoDir + "/quotes"
    readonly property string gameScripts: repoDir + "/scripts/game"
    readonly property bool dryRun: Quickshell.env("OW_GAME_DRYRUN") === "1"
    readonly property var qsArgs: (Quickshell.env("OW_QS_ARGS") || "-c overworld").split(" ").filter(s => s.length)
    property var chatTexts: ({})
    readonly property string player: Theme.config.player || chatTexts.player_default || "Nurasik"
    signal dryRunLogged(string line)

    function statePath(name) { return stateDir + "/" + name; }

    function run(argv) {
        if (dryRun) { dryRunLogged(argv.join(" ")); return; }
        Quickshell.execDetached(argv);
    }
    function ipc(target, fn, args) {
        run(["qs"].concat(qsArgs, ["ipc", "call", target, fn], args || []));
    }
    function cli(args) { run([repoDir + "/scripts/overworld"].concat(args)); }

    function t(path, vars) {
        const parts = path.split(".");
        let cur = chatTexts;
        for (let i = 0; i < parts.length; i++) {
            if (cur === null || typeof cur !== "object" || !(parts[i] in cur)) return "";
            cur = cur[parts[i]];
        }
        return typeof cur === "string" ? fmt(cur, vars) : "";
    }
    function fmt(s, vars) {
        const v = Object.assign({ player: root.player }, vars || {});
        return s.replace(/\{(\w+)\}/g, (m, k) => (k in v ? String(v[k]) : m));
    }

    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function dateKey(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
    // 90 → "1m 30s", 3700 → "1h 1m"; used by the statistics screen and /msg
    function durationText(sec) {
        sec = Math.max(0, Math.floor(sec));
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
        if (h > 0) return h + "h " + m + "m";
        if (m > 0) return m + "m " + s + "s";
        return s + "s";
    }

    FileView {
        path: root.quotesDir + "/chat.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.chatTexts = JSON.parse(text()); } catch (e) { console.warn("GameCore: chat.json:", e); } }
    }
}
