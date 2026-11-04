pragma Singleton
import QtQuick
import Quickshell

/*  ShellState — which overlay surface is open.  Only one modal surface at a time.
 *  ShellState.toggle("launcher" | "network" | "power" | "wallpapers" | "notifCenter" | "brew") · open(name) · close(name) · closeAll()
 *  ShellState.hudHidden                the `hud hide|reveal` IPC (spectator hides the HUD by itself, through ConfigService.gamemode)
 *  ShellState.run(cmd)                 detached command; only logged in previews
 *  ShellState.ipc(target, fn, args…)   call another module's IpcHandler in this very process (Advancements, Statistics, Options…)
 *  Preview pin OW_PREVIEW=1: no exclusive zones, no keyboard grabs, and nothing that touches the desktop really runs.
 */
Singleton {
    id: root
    property bool launcherOpen: false
    property bool networkOpen: false
    property bool powerOpen: false
    property bool wallpapersOpen: false
    property bool notifCenterOpen: false
    property bool brewOpen: false            // brew timer settings (Brew/BrewDialog.qml)
    property bool hudHidden: false
    readonly property bool anyOpen: launcherOpen || networkOpen || powerOpen || wallpapersOpen || notifCenterOpen || brewOpen

    readonly property bool preview: Quickshell.env("OW_PREVIEW") === "1"

    signal launcherSearch(string q)      // test/IPC hook: set the launcher query
    signal networkExpand(string ssid)    // test/IPC hook: select a server row and open its password screen
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

    function run(cmd) {
        if (preview) { console.warn("DRYRUN", JSON.stringify(cmd)); return; }
        Quickshell.execDetached(cmd);
    }
    function ipc(target, fn) {
        const cmd = ["qs", "ipc", "--pid", String(Quickshell.processId), "call", target, fn];
        for (let i = 2; i < arguments.length; i++) cmd.push(String(arguments[i]));
        Quickshell.execDetached(cmd);
    }
}
