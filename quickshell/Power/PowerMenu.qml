import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  PowerMenu — the Game Menu, the Esc screen (SUPER+Escape · `ipc call power toggle`), namespace overworld-power.
 *    Back to Game · Advancements | Statistics · Options... | Lock · Sleep in Bed (suspend) | Respawn (reboot) ·
 *    Save and Quit to Title (logout) · Quit Game (shutdown)
 *  Logout, reboot and shutdown go through the confirm screen; there Enter on the default "No" goes back, Y or Yes confirms.
 *  Keys: arrows move · Enter activates · Esc back · letters L O S R P jump to Lock, lOgout, Suspend, Reboot, shutdown (Power).
 *  Advancements, Statistics and Options are qs-features' screens, opened through their IPC.
 *  With OW_PREVIEW=1 no command really runs (they are logged instead).
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-power"
        title: confirmAction ? "" : "Game Menu"
        titleY: 40
        open: ShellState.powerOpen
        onCloseRequested: {
            if (confirmAction) { confirmAction = null; contentItem.forceActiveFocus(); }
            else ShellState.close("power");
        }
        closeOnClickOutside: false

        readonly property var actions: ({
            back: { label: "Back to Game" },
            advancements: { label: "Advancements", ipc: "advancements" },
            statistics: { label: "Statistics", ipc: "stats" },
            options: { label: "Options...", ipc: "options" },
            lock: { label: "Lock", key: "L", cmd: ["hyprlock"] },
            sleep: { label: "Sleep in Bed", key: "S", cmd: ["systemctl", "suspend"] },
            respawn: { label: "Respawn", key: "R", cmd: ["systemctl", "reboot"], confirm: "Respawn?", detail: "This restarts the computer." },
            logout: { label: "Save and Quit to Title", key: "O", cmd: ["hyprctl", "dispatch", "exit"], confirm: "Save and quit to title?", detail: "This ends the Hyprland session." },
            quit: { label: "Quit Game", key: "P", cmd: ["systemctl", "poweroff"], confirm: "Are you sure you want to quit the game?", detail: "This shuts the computer down." }
        })
        // The screen as rows, left to right; arrows walk this grid.
        readonly property var grid: [
            ["back"],
            ["advancements", "statistics"],
            ["options", "lock"],
            ["sleep", "respawn"],
            ["logout"],
            ["quit"]
        ]
        property int row: 0
        property int col: 0
        property var confirmAction: null
        property int confirmChoice: 1     // 0 yes, 1 no
        readonly property string selectedKey: grid[row][Math.min(col, grid[row].length - 1)]

        onShownChanged: if (shown) { row = 0; col = 0; confirmAction = null; contentItem.forceActiveFocus(); }

        function run(key) {
            const a = win.actions[key];
            if (!a) return;
            if (key === "back") { ShellState.close("power"); return; }
            if (a.ipc) { ShellState.close("power"); ShellState.ipc(a.ipc, "open"); return; }
            if (a.confirm) { win.confirmAction = a; win.confirmChoice = 1; return; }
            win.execute(a);
        }
        function execute(a) {
            ShellState.close("power");
            win.confirmAction = null;
            ShellState.run(a.cmd);
        }
        function moveRow(d) { win.row = (win.row + d + win.grid.length) % win.grid.length; win.col = Math.min(win.col, win.grid[win.row].length - 1); }
        function moveCol(d) { const n = win.grid[win.row].length; win.col = (win.col + d + n) % n; }

        Item {
            focus: true
            Keys.onPressed: event => {
                const k = event.key;
                if (win.confirmAction) {
                    if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Tab) win.confirmChoice = 1 - win.confirmChoice;
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                        Theme.playSound("ui.click");
                        if (win.confirmChoice === 0) win.execute(win.confirmAction); else win.confirmAction = null;
                    }
                    else if (event.text.toUpperCase() === "Y") { Theme.playSound("ui.click"); win.execute(win.confirmAction); }
                    else if (event.text.toUpperCase() === "N") { Theme.playSound("ui.click"); win.confirmAction = null; }
                    else return;
                    event.accepted = true;
                    return;
                }
                if (k === Qt.Key_Up) win.moveRow(-1);
                else if (k === Qt.Key_Down) win.moveRow(1);
                else if (k === Qt.Key_Left) win.moveCol(-1);
                else if (k === Qt.Key_Right || k === Qt.Key_Tab) win.moveCol(1);
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { Theme.playSound("ui.click"); win.run(win.selectedKey); }
                else {
                    const t = event.text.toUpperCase();
                    const hit = Object.keys(win.actions).find(a => win.actions[a].key === t);
                    if (!hit || !t.length) return;
                    Theme.playSound("ui.click");
                    win.run(hit);
                }
                event.accepted = true;
            }
        }

        component MenuButton: McButton {
            required property string actionKey
            text: win.actions[actionKey].label
            highlighted: win.selectedKey === actionKey
            activeFocusOnTab: false
            onHoveredChanged: if (hovered) {
                for (let r = 0; r < win.grid.length; r++) {
                    const c = win.grid[r].indexOf(actionKey);
                    if (c >= 0) { win.row = r; win.col = c; }
                }
            }
            onClicked: win.run(actionKey)
        }

        // ------------------------------------------------------------ the pause screen
        Column {
            visible: !win.confirmAction
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.px(62)
            spacing: Theme.px(4)
            MenuButton { actionKey: "back"; width: Theme.px(204) }
            Item { width: 1; height: Theme.px(8) }
            Row {
                spacing: Theme.px(8)
                MenuButton { actionKey: "advancements"; small: true }
                MenuButton { actionKey: "statistics"; small: true }
            }
            Row {
                spacing: Theme.px(8)
                MenuButton { actionKey: "options"; small: true }
                MenuButton { actionKey: "lock"; small: true }
            }
            Row {
                spacing: Theme.px(8)
                MenuButton { actionKey: "sleep"; small: true }
                MenuButton { actionKey: "respawn"; small: true }
            }
            Item { width: 1; height: Theme.px(8) }
            MenuButton { actionKey: "logout"; width: Theme.px(204) }
            MenuButton { actionKey: "quit"; width: Theme.px(204) }
        }

        // ------------------------------------------------------------ the confirm screen
        Column {
            visible: !!win.confirmAction
            anchors.centerIn: parent
            spacing: Theme.px(10)
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.hudText
                text: win.confirmAction ? win.confirmAction.confirm : ""
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.tooltipDesc
                text: win.confirmAction ? win.confirmAction.detail : ""
            }
            Item { width: 1; height: Theme.px(6) }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(8)
                McButton {
                    text: "Yes"
                    highlighted: win.confirmChoice === 0
                    activeFocusOnTab: false
                    onHoveredChanged: if (hovered) win.confirmChoice = 0
                    onClicked: win.execute(win.confirmAction)
                }
                McButton {
                    text: "No"
                    highlighted: win.confirmChoice === 1
                    activeFocusOnTab: false
                    onHoveredChanged: if (hovered) win.confirmChoice = 1
                    onClicked: win.confirmAction = null
                }
            }
        }
    }
}
