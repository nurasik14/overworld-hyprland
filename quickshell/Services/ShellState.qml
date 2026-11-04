pragma Singleton
import QtQuick
import Quickshell

/*  ShellState — which overlay surface is open.  Only one modal surface at a time.
 *  ShellState.toggle("launcher" | "network" | "power" | "wallpapers" | "notifCenter" | "brew") · open(name) · close(name) · closeAll()
 */
Singleton {
    id: root
    property bool launcherOpen: false
    property bool networkOpen: false
    property bool powerOpen: false
    property bool wallpapersOpen: false
    property bool notifCenterOpen: false
    property bool brewOpen: false            // brew timer settings (Brew/BrewDialog.qml)
    readonly property bool anyOpen: launcherOpen || networkOpen || powerOpen || wallpapersOpen || notifCenterOpen || brewOpen

    signal launcherSearch(string q)      // test/IPC hook: set the launcher query
    signal networkExpand(string ssid)    // test/IPC hook: expand a Wi-Fi row
    signal wallpaperAction(string action, int arg)   // "select" <index> | "apply" | "next" | "prev"
    readonly property var names: ["launcher", "network", "power", "wallpapers", "notifCenter", "brew"]

    function isOpen(name) { return root[name + "Open"] === true; }
    function closeAll() { for (let i = 0; i < names.length; i++) root[names[i] + "Open"] = false; }
    function open(name) { if (isOpen(name)) return; closeAll(); root[name + "Open"] = true; }
    function close(name) { root[name + "Open"] = false; }
    function toggle(name) {
        const was = isOpen(name);
        closeAll();
        root[name + "Open"] = !was;
    }
}
