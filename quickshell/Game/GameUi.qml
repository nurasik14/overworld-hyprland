pragma Singleton
import QtQuick
import Quickshell
import qs.Services

/*  GameUi — which Game screen is open. One screen at a time; opening one closes the launcher/network/… modals (ShellState).
 *    screens: advancements · stats · options · switcher        (the chat has its own flag: chatOpen + chatPrefill)
 *    GameUi.open("stats") · close(name) · toggle(name) · closeAll()
 *  Other modules (the game menu) may call `qs -c overworld ipc call advancements open` or GameEvents.emit("ui.open", {screen: "stats"}).
 */
Singleton {
    id: root
    property bool advancementsOpen: false
    property bool statsOpen: false
    property bool optionsOpen: false
    property bool switcherOpen: false
    property bool chatOpen: false
    property string chatPrefill: ""
    property string optionsPage: "main"
    readonly property var names: ["advancements", "stats", "options", "switcher"]
    readonly property bool anyOpen: advancementsOpen || statsOpen || optionsOpen || switcherOpen || chatOpen

    // a launcher / network / power / wallpapers / brew modal opening takes over from our screens
    Connections {
        target: ShellState
        function onAnyOpenChanged() { if (ShellState.anyOpen) root.closeAll(); }
    }

    function isOpen(name) { return root[name + "Open"] === true; }
    function closeScreens() { for (let i = 0; i < names.length; i++) root[names[i] + "Open"] = false; }
    function closeAll() { closeScreens(); chatOpen = false; }
    function open(name) {
        if (names.indexOf(name) < 0) return;
        if (isOpen(name)) return;
        ShellState.closeAll();
        chatOpen = false;
        closeScreens();
        root[name + "Open"] = true;
    }
    function close(name) { root[name + "Open"] = false; }
    function toggle(name) { isOpen(name) ? close(name) : open(name); }
    function openChat(prefill) {
        ShellState.closeAll();
        closeScreens();
        chatPrefill = prefill || "";
        chatOpen = true;
    }
    function closeChat() { chatOpen = false; }
}
