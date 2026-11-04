pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common

/*  HyprlandState — workspaces 1–10, focused workspace, focused window title, and what is in each workspace.
 *  HyprlandState.workspace(id) → HyprlandWorkspace | null
 *  HyprlandState.exists(id) / occupied(id) / isActive(id) · HyprlandState.go(id) · HyprlandState.cycle(±1)
 *  HyprlandState.title (active toplevel title, "" when none) · appClass
 *  HyprlandState.info(id) → { count, item, cls, title, apps: [{ item, cls, title, count }] }   the hotbar slot: dominant app first
 *  HyprlandState.specials → [{ id, name, count, item, cls, apps }]  occupied special workspaces · activeSpecial (name or "")
 *  HyprlandState.toggleSpecial(name)
 *  Emits `workspace {id}` when the focused workspace changes.
 */
Singleton {
    id: root

    readonly property var workspaces: Hyprland.workspaces.values
    readonly property var focused: Hyprland.focusedWorkspace
    property int _fakeFocus: parseInt(Quickshell.env("OW_FAKE_WS") || "0")   // previews only: dev-shot sits on workspace 77
    readonly property int focusedId: _fakeFocus > 0 ? _fakeFocus : (focused ? focused.id : 1)
    readonly property var activeToplevel: Hyprland.activeToplevel
    readonly property string title: activeToplevel ? (activeToplevel.title || "") : ""
    readonly property string appClass: activeToplevel && activeToplevel.lastIpcObject ? (activeToplevel.lastIpcObject["class"] || "") : ""
    property int revision: 0     // bumped on window events so occupancy bindings re-evaluate

    function workspace(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) if (list[i].id === id) return list[i];
        return null;
    }
    function exists(id) { return root.revision >= 0 && workspace(id) !== null; }
    function occupied(id) {
        const w = workspace(id);
        if (!w) return false;
        if (w.toplevels && w.toplevels.values && w.toplevels.values.length > 0) return true;
        const o = w.lastIpcObject || {};
        return (o.windows || 0) > 0;
    }
    function isActive(id) { return root.revision >= 0 && focusedId === id; }
    function go(id) {
        if (ShellState.preview) { console.warn("DRYRUN workspace", id); return; }
        Hyprland.dispatch("workspace " + id);
    }
    function cycle(delta) {
        let next = focusedId + delta;
        if (next < 1) next = 10;
        if (next > 10) next = 1;
        go(next);
    }

    // ---------------------------------------------------------------- what the hotbar shows
    property var slots: ({})        // workspace id → summary
    property var specials: []
    property string activeSpecial: ""
    function info(id) { return root.slots[id] || { count: 0, item: "", cls: "", title: "", apps: [] }; }
    function toggleSpecial(name) {
        const short = String(name).replace(/^special:?/, "");
        if (ShellState.preview) { console.warn("DRYRUN togglespecialworkspace", short); return; }
        Hyprland.dispatch("togglespecialworkspace " + short);
    }
    function _summary(windows) {       // windows: [{cls, title}] → the item with the most windows comes first
        const byItem = {}, order = [];
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            const item = Theme.itemFor(w.cls, w.title);
            if (!byItem[item]) { byItem[item] = { item: item, cls: w.cls, title: w.title, count: 0 }; order.push(item); }
            byItem[item].count++;
        }
        const apps = order.map(k => byItem[k]);
        apps.sort((a, b) => b.count - a.count);
        const top = apps[0] || { item: "", cls: "", title: "" };
        return { count: windows.length, item: top.item, cls: top.cls, title: top.title, apps: apps };
    }
    function rebuild() {
        const list = Hyprland.toplevels.values;
        const groups = {}, names = {};
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            const ws = t.workspace;
            if (!ws) continue;
            const ipc = t.lastIpcObject || {};
            const cls = ipc["class"] || ipc["initialClass"] || (t.wayland ? t.wayland.appId : "") || "";
            (groups[ws.id] = groups[ws.id] || []).push({ cls: cls, title: t.title || "" });
            names[ws.id] = ws.name;
        }
        const out = {}, spec = [];
        for (const id in groups) {
            const s = _summary(groups[id]);
            out[id] = s;
            if (Number(id) < 0) spec.push(Object.assign({ id: Number(id), name: names[id] }, s));
        }
        root.slots = out;
        root.specials = spec;
    }
    Timer { id: rebuildSoon; interval: 120; onTriggered: { Hyprland.refreshToplevels(); rebuildLater.restart(); root.rebuild(); } }
    Timer { id: rebuildLater; interval: 350; onTriggered: root.rebuild() }   // refreshToplevels answers asynchronously
    Connections { target: Hyprland.toplevels; function onValuesChanged() { rebuildSoon.restart(); } }
    Component.onCompleted: rebuildSoon.restart()

    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }
    onFocusedIdChanged: if (armed) GameEvents.emit("workspace", { id: focusedId })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2" || n === "windowtitle" || n === "windowtitlev2") rebuildSoon.restart();
            if (n === "activespecial") root.activeSpecial = (event.data || "").split(",")[0];
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                || n === "createworkspace" || n === "destroyworkspace" || n === "workspace" || n === "focusedmon") {
                Hyprland.refreshWorkspaces();
                root.revision++;
            }
            if (n === "activewindow" || n === "activewindowv2") root.revision++;
        }
    }
}
