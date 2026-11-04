pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

/*  HyprlandState — workspaces 1–10, focused workspace, focused window title.
 *  HyprlandState.workspace(id) → HyprlandWorkspace | null
 *  HyprlandState.exists(id) / occupied(id) / isActive(id) · HyprlandState.go(id) · HyprlandState.cycle(±1)
 *  HyprlandState.title (active toplevel title, "" when none)
 */
Singleton {
    id: root

    readonly property var workspaces: Hyprland.workspaces.values
    readonly property var focused: Hyprland.focusedWorkspace
    readonly property int focusedId: focused ? focused.id : 1
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
    function go(id) { Hyprland.dispatch("workspace " + id); }
    function cycle(delta) {
        let next = focusedId + delta;
        if (next < 1) next = 10;
        if (next > 10) next = 1;
        go(next);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                || n === "createworkspace" || n === "destroyworkspace" || n === "workspace" || n === "focusedmon") {
                Hyprland.refreshWorkspaces();
                root.revision++;
            }
            if (n === "activewindow" || n === "activewindowv2") root.revision++;
        }
    }
}
