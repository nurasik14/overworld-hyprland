import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  Placer — the block-place window open.
 *
 *  Every Hyprland `openwindow` event becomes `window.open {cls,title}` on the bus. After the window has mapped (~90 ms) it gets
 *  the placing effect: `block.place.<material>` and a small puff of dust particles along its lower edge and sides.
 *  Skipped (the event still goes out): more than 3 windows opened within 1 s, adventure/spectator mode, config interact.place=false,
 *  floating popups / menus / notifications (floating and smaller than 420×260, empty class, pinned or hidden), a window that opened on a
 *  workspace that is not the one on screen, reduced motion for the dust (the sound stays).
 *  Placer.place(address) runs the effect for a given window without an event (IPC `interact place`).
 */
Scope {
    id: root
    property var recent: []           // timestamps of the last openwindow events
    property var queue: []            // { bare, cls, title, force }
    property string lastResult: ""
    readonly property bool enabled: ConfigService.get("interact.place", true) !== false
    readonly property string mode: ConfigService.gamemode

    function bare(a) { return String(a || "").toLowerCase().replace(/^0x/, ""); }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "openwindow") return;
            const p = ev.parse(4);                 // address, workspace name, class, title
            if (!p || p.length < 3) return;
            root._opened(p[0], p[1], p[2], p[3] || "");
        }
    }

    function _opened(address, wsName, cls, title) {
        if (!cls.length) return;                       // nameless X11 popups: not a window the user opened
        GameEvents.emit("window.open", { cls: cls, title: title });
        const now = Date.now();
        recent = recent.filter(t => now - t < 1000).concat([now]);
        if (recent.length > 3) { lastResult = "skipped: more than 3 windows in 1 s"; return; }
        if (!enabled) { lastResult = "skipped: interact.place is off"; return; }
        if (mode === "adventure" || mode === "spectator") { lastResult = "skipped: " + mode + " mode"; return; }
        if (String(wsName).indexOf("special:") === 0) { lastResult = "skipped: special workspace"; return; }
        queue = queue.concat([{ bare: bare(address), cls: cls, title: title, force: false }]);
        settle.start();
    }

    function place(address) {            // IPC: no checks except that the window exists
        queue = queue.concat([{ bare: bare(address), cls: "", title: "", force: true }]);
        settle.start();
    }

    Timer { id: settle; interval: 90; onTriggered: root._next() }
    function _next() {
        if (queryProc.running || !queue.length) return;
        queryProc.running = true;
    }
    Process {
        id: queryProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector { onStreamFinished: root._clients(text) }
        onExited: { if (root.queue.length) settle.start(); }
    }
    function _clients(text) {
        const item = queue[0];
        queue = queue.slice(1);
        if (!item) return;
        let list = [];
        try { list = JSON.parse(text); } catch (e) { return; }
        const w = list.find(c => bare(c.address) === item.bare);
        if (!w || w.mapped === false || w.hidden) { lastResult = "skipped: window gone"; return; }
        const rect = { x: w.at[0], y: w.at[1], w: w.size[0], h: w.size[1] };
        const cls = String(w["class"] || "");
        if (!item.force) {
            if (w.pinned) { lastResult = "skipped: pinned"; return; }
            if (w.floating && (rect.w < 420 || rect.h < 260)) { lastResult = "skipped: small floating window"; return; }
            const visible = w.workspace && w.workspace.id === HyprlandState.focusedId;
            if (!visible) { lastResult = "skipped: not on the visible workspace"; return; }
        }
        const material = InteractFx.materialFor(cls, w.title);
        InteractFx.sound("block.place." + material);
        const n = Math.round(Math.max(22, Math.min(44, 20 + rect.w / 70)) * InteractFx.particleFactor);
        if (!ConfigService.reducedMotion && n > 0) InteractFx.add("dust", rect, { count: n }, 2500);
        lastResult = "placed " + cls + " (" + material + ")";
    }
}
