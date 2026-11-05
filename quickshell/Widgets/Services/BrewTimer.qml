pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets.Services
import "duration.js" as Dur

/*  BrewTimer — the brewing-stand focus timer (pomodoro).
 *    Brew (work) and rest lengths are any duration (duration.js grammar: 25 · 90s · 1h30 · 1:30), saved in
 *    config.json brew.work / brew.break (default 25 min / 5 min; rest 0 = no break).  State idle | working |
 *    breaking | paused.  On finish: the sound ids `brew.done` (brew finished) / `brew.drink` (rest over) through
 *    Theme.playSound → scripts/ow-sound (silent when config.json sounds=false) and a notification.
 *    Events (BRIEF §4.4): brew.start {} when a brew begins, brew.done {} when it finishes, rest.done {} when the rest is over.
 *    A finished brew rolls into the rest (if any), a finished rest returns to idle.
 *  Setting: the brew dialog (Brew/BrewDialog.qml: SUPER+SHIFT+B or click the clock), scrolling on the card
 *    (nudge(), saved after a short pause), or `overworld brew set <brew> [rest]`.  Every write goes through the CLI.
 *  IPC: qs -c overworld ipc call brew start <dur> | startWith <brew> <rest> | toggle | pause | reset |
 *       add <dur> | sound brew|rest (preview) | open | status | settings
 */
Singleton {
    id: root
    property string state: "idle"            // idle | working | breaking | paused
    property string pausedPhase: "working"    // phase to resume when paused
    property int remaining: 0                 // seconds
    property int total: 0                     // seconds of the current phase
    property int sessions: 0                  // completed brews since startup
    property int sessionBreak: -1             // one-off rest for the running session (startWith); -1 = saved value

    // saved lengths; a pending nudge (scroll on the card) shows at once and is written after saveDelay
    property int pendingWork: -1
    property int pendingBreak: -1
    readonly property int workSeconds: pendingWork >= 0 ? pendingWork : WidgetsConfig.brewWorkSeconds
    readonly property int breakSeconds: pendingBreak >= 0 ? pendingBreak : WidgetsConfig.brewBreakSeconds
    readonly property int workMinutes: Math.round(workSeconds / 60)      // legacy readers
    readonly property int breakMinutes: Math.round(breakSeconds / 60)
    readonly property int maxSeconds: 86400

    readonly property bool running: state === "working" || state === "breaking"
    readonly property bool active: state !== "idle"
    readonly property real progress: total > 0 ? 1 - remaining / total : 0
    readonly property string phase: state === "paused" ? pausedPhase : state
    readonly property string mmss: Dur.clock(state === "idle" ? workSeconds : remaining)
    readonly property string label: state === "idle" ? "Ready" : state === "paused" ? "Paused" : state === "working" ? "Brewing" : "Resting"

    // helpers for the card / dialog
    function parse(text) { return Dur.parse(text) }
    function human(s) { return Dur.human(s) }
    function short(s) { return Dur.short(s) }
    function fmt(s) { return Dur.clock(s) }
    function validWork(s) { return !isNaN(s) && s >= 1 && s <= maxSeconds }
    function validRest(s) { return !isNaN(s) && s >= 0 && s <= maxSeconds }

    Timer {
        id: tick
        interval: 1000; repeat: true
        running: root.running
        onTriggered: {
            if (root.remaining > 1) { root.remaining -= 1; return }
            root.remaining = 0;
            root.finishPhase();
        }
    }

    // ---- control
    function start(work) {                       // one-off brew length; empty / invalid = the saved one
        const w = work === undefined || work === "" ? NaN : Dur.parse(work);
        root.sessionBreak = -1;
        beginWork(validWork(w) ? w : workSeconds);
    }
    function startWith(work, rest) {             // one-off brew + rest (the saved lengths stay as they are)
        const w = Dur.parse(work), r = Dur.parse(rest);
        root.sessionBreak = validRest(r) ? r : -1;
        beginWork(validWork(w) ? w : workSeconds);
    }
    function beginWork(sec) {
        root.total = sec; root.remaining = sec;
        root.state = "working";
        GameEvents.emit("brew.start", {});
    }
    function startBreak() {
        const r = root.sessionBreak >= 0 ? root.sessionBreak : breakSeconds;
        root.total = r; root.remaining = r;
        root.state = "breaking";
    }
    function pause() { if (running) { root.pausedPhase = root.state; root.state = "paused" } }
    function resume() { if (state === "paused") root.state = pausedPhase }
    function toggle() {
        if (state === "idle") start("");
        else if (state === "paused") resume();
        else pause();
    }
    function reset() { root.state = "idle"; root.remaining = 0; root.total = 0; root.sessionBreak = -1 }
    function add(dur) {                          // stretch the running (or paused) phase
        const s = Dur.parse(dur);
        if (!active || isNaN(s) || s <= 0) return;
        root.remaining = Math.min(root.remaining + s, maxSeconds);
        root.total = Math.min(root.total + s, maxSeconds);
    }
    function finishPhase() {
        if (state === "working") {
            root.sessions += 1;
            GameEvents.emit("brew.done", {});
            const r = root.sessionBreak >= 0 ? root.sessionBreak : breakSeconds;
            if (r > 0) {
                notify("Brewing complete", Dur.human(total) + " brewed. Rest for " + Dur.human(r) + ".", "brew");
                startBreak();
            } else {
                notify("Brewing complete", Dur.human(total) + " brewed.", "brew");
                reset();
            }
        } else {
            GameEvents.emit("rest.done", {});
            notify("Back to the crafting table", "Rest over.", "rest");
            reset();
        }
    }

    // ---- saving (every write goes through `overworld brew set`, which edits config.json in place)
    function save(work, rest) {                  // seconds; -1 keeps that one unchanged
        if (work >= 1) root.pendingWork = work;  // show the new values at once
        if (rest >= 0) root.pendingBreak = rest;
        if (saver.running) { root.resave = true; return }    // written again when the current write exits
        saver.command = [Theme.repoDir + "/scripts/overworld", "brew", "set", "--quiet",
                         work >= 1 ? work + "s" : "-", rest >= 0 ? rest + "s" : "-"];
        saver.running = true;
    }
    function nudge(which, delta) {               // scroll on the card: ±delta seconds, written after saveDelay
        if (which === "work") root.pendingWork = Math.max(60, Math.min(maxSeconds, workSeconds + delta));
        else root.pendingBreak = Math.max(0, Math.min(maxSeconds, breakSeconds + delta));
        saveDelay.restart();
    }
    property bool resave: false
    Timer {
        id: saveDelay
        interval: 700
        onTriggered: root.save(root.pendingWork, root.pendingBreak)
    }
    Process {
        id: saver
        onExited: (code) => {
            if (code !== 0) console.warn("BrewTimer: overworld brew set failed (" + code + ")");
            if (root.resave) { root.resave = false; root.save(root.pendingWork, root.pendingBreak); return }
            clearPending.restart();             // give WidgetsConfig a moment to re-read config.json
        }
    }
    Timer { id: clearPending; interval: 400; onTriggered: if (!saveDelay.running) { root.pendingWork = -1; root.pendingBreak = -1 } }

    function openDialog() { ShellState.open("brew") }

    function playSound(kind) {                   // "brew" = brewing-stand done, "rest" = drinking the potion
        Theme.playSound(kind === "rest" ? "brew.drink" : "brew.done");
    }
    function notify(title, body, kind) {
        // notify-send wants a themed icon name or a file: the brewing stand icon (Mojang art, else asset-forge's, else the missing texture)
        notifier.command = ["notify-send", "-a", "Overworld", "-i", String(Theme.iconUrl("brewing_stand")).replace(/^file:\/\//, ""), title, body];
        notifier.running = true;
        playSound(kind);
    }
    Process { id: notifier }

    IpcHandler {
        target: "brew"
        function start(work: string): void { root.start(work) }
        function startWith(work: string, rest: string): void { root.startWith(work, rest) }
        function toggle(): void { root.toggle() }
        function pause(): void { root.pause() }
        function reset(): void { root.reset() }
        function add(dur: string): void { root.add(dur) }
        function sound(kind: string): void { root.playSound(kind === "rest" ? "rest" : "brew") }   // preview
        function open(): void { root.openDialog() }
        function status(): string { return root.state + " " + root.mmss + " (" + root.phase + ")" }
        function settings(): string { return "brew=" + Dur.short(root.workSeconds) + " rest=" + Dur.short(root.breakSeconds) }
    }
}
