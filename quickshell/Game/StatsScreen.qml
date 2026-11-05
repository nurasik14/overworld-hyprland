import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  StatsScreen — layer `overworld-stats` (IPC `stats open`): the game's Statistics list screen. General / Items (apps opened) /
 *  Mobs (windows mined by app) in the footer, Done closes. Keys: Left/Right or Tab switch tab · Up/Down/PageUp/PageDown scroll · Esc.
 *  Numbers are event counts (windows, workspaces, notifications, brews, screenshots …) — never keystrokes. Source: Stats.qml.
 */
Variants {
    model: Quickshell.screens

    ScreenWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-stats"
        open: GameUi.statsOpen
        background: "menu"
        title: "Statistics"
        titleY: 12
        footerHeight: 56
        onCloseRequested: GameUi.close("stats")

        property int tabIndex: 0
        property bool confirmReset: false
        readonly property var tabNames: ["general", "items", "mobs"]
        readonly property var tabLabels: ["General", "Items", "Mobs"]
        onShownChanged: { if (shown) list.contentY = 0; else confirmReset = false; }
        Connections {
            target: StatsState
            function onTabRequested(name) { const i = win.tabNames.indexOf(String(name).toLowerCase()); if (i >= 0) win.tabIndex = i; }
        }

        // ------------------------------------------------------------ rows
        function n(v) { return String(Math.round(v)).replace(/\B(?=(\d{3})+(?!\d))/g, ","); }
        readonly property var general: {
            const r = Stats.revision;
            const t = k => Stats.total(k), s = k => Stats.session(k);
            const rows = [
                { name: "Time Played", session: GameCore.durationText(Stats.sessionSeconds), total: GameCore.durationText(Stats.playSeconds) },
                { name: "Games Started", session: "1", total: n(Stats.sessions) },
                { name: "Windows Placed", session: n(s("windowsOpened")), total: n(t("windowsOpened")) },
                { name: "Windows Closed", session: n(s("windowsClosed")), total: n(t("windowsClosed")) },
                { name: "Windows Mined", session: n(s("windowsMined")), total: n(t("windowsMined")) },
                { name: "Workspaces Visited", session: n(s("workspaceSwitches")), total: n(t("workspaceSwitches")) },
                { name: "Distance Walked", session: n(s("distance")) + " blocks", total: n(t("distance")) + " blocks" },
                { name: "Notifications Received", session: n(s("notifications")), total: n(t("notifications")) },
                { name: "Urgent Notifications", session: n(s("urgentNotifications")), total: n(t("urgentNotifications")) },
                { name: "Brews Started", session: n(s("brewsStarted")), total: n(t("brewsStarted")) },
                { name: "Brews Completed", session: n(s("brewsDone")), total: n(t("brewsDone")) },
                { name: "Times Well Rested", session: n(s("restsDone")), total: n(t("restsDone")) },
                { name: "Screenshots Taken", session: n(s("screenshots")), total: n(t("screenshots")) },
                { name: "Apps Launched", session: n(s("launches")), total: n(t("launches")) },
                { name: "Chat Commands Used", session: n(s("commands")), total: n(t("commands")) },
                { name: "Worlds Visited", session: n(s("wallpapers")), total: n(t("wallpapers")) },
                { name: "Worlds Created", session: n(s("worlds")), total: n(t("worlds")) },
                { name: "Experience Levels Gained", session: n(s("levels")), total: n(t("levels")) },
                { name: "Networks Joined", session: n(s("connections")), total: n(t("connections")) },
                { name: "Game Mode Changes", session: n(s("gamemodeSwitches")), total: n(t("gamemodeSwitches")) },
                { name: "Times Died", session: n(s("deaths")), total: n(t("deaths")) },
                { name: "Advancements Made", session: n(s("advancements")), total: Advancements.unlockedCount + " / " + Advancements.total }
            ];
            return rows;
        }
        readonly property var appRows: {
            const r = Stats.revision;
            const out = [];
            for (const cls in Stats.apps) out.push({ cls: cls, opened: Stats.apps[cls].opened || 0, mined: Stats.apps[cls].mined || 0 });
            return out;
        }
        readonly property var itemRows: appRows.filter(a => a.opened > 0).sort((a, b) => b.opened - a.opened)
        readonly property var mobRows: appRows.filter(a => a.mined > 0).sort((a, b) => b.mined - a.mined)

        Rectangle { anchors.fill: parent; z: -1; color: "#b0101010" }   // the world behind is a real desktop: keep the list readable
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) { win.tabIndex = (win.tabIndex + 1) % 3; event.accepted = true; }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { win.tabIndex = (win.tabIndex + 2) % 3; event.accepted = true; }
                else if (event.key === Qt.Key_Down) { list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + Theme.px(20)); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { list.contentY = Math.max(0, list.contentY - Theme.px(20)); event.accepted = true; }
                else if (event.key === Qt.Key_PageDown) { list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + list.height); event.accepted = true; }
                else if (event.key === Qt.Key_PageUp) { list.contentY = Math.max(0, list.contentY - list.height); event.accepted = true; }
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) { win.tabIndex = event.key - Qt.Key_1; event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.closeRequested(); event.accepted = true; }
            }
            onActiveFocusChanged: if (!activeFocus && win.shown && !win.confirmReset) forceActiveFocus()

            readonly property int listW: Math.min(Theme.px(320), parent.width - Theme.px(40))

            // column headers (General only)
            McText {
                visible: win.tabIndex === 0
                x: (parent.width - parent.listW) / 2 + parent.listW - Theme.px(150); y: Theme.px(38)
                text: "This session"; color: "#aaaaaa"
            }
            McText {
                visible: win.tabIndex === 0
                x: (parent.width - parent.listW) / 2 + parent.listW - Theme.px(6) - width; y: Theme.px(38)
                text: "Total"; color: "#aaaaaa"
            }
            Flickable {
                id: list
                x: (parent.width - parent.listW) / 2
                y: Theme.px(50)
                width: parent.listW
                height: parent.height - Theme.px(50 + 60)
                clip: true
                contentWidth: width
                contentHeight: col.height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                Column {
                    id: col
                    width: list.width
                    Repeater {
                        model: win.tabIndex === 0 ? win.general : win.tabIndex === 1 ? win.itemRows : win.mobRows
                        Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            width: col.width; height: Theme.px(20)
                            color: rowArea.containsMouse ? "#40ffffff" : (index % 2 === 0 ? "#30000000" : "transparent")
                            MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            McItemIcon {
                                visible: win.tabIndex > 0
                                x: Theme.px(2); y: Theme.px(2)
                                app: win.tabIndex > 0 ? row.modelData.cls : ""
                            }
                            McText {
                                x: Theme.px(win.tabIndex === 0 ? 6 : 24); anchors.verticalCenter: parent.verticalCenter
                                text: win.tabIndex === 0 ? row.modelData.name : row.modelData.cls
                                color: "#ffffff"
                            }
                            McText {   // session column
                                visible: win.tabIndex === 0
                                x: parent.width - Theme.px(150); anchors.verticalCenter: parent.verticalCenter
                                text: win.tabIndex === 0 ? row.modelData.session : ""
                                color: "#aaaaaa"
                            }
                            McText {   // total / count column
                                anchors.right: parent.right; anchors.rightMargin: Theme.px(6); anchors.verticalCenter: parent.verticalCenter
                                text: win.tabIndex === 0 ? row.modelData.total : win.tabIndex === 1 ? "Used " + win.n(row.modelData.opened) + "×" : "Mined " + win.n(row.modelData.mined) + "×"
                                color: "#ffffff"
                            }
                        }
                    }
                }
                McText {
                    visible: win.tabIndex > 0 && col.height === 0
                    anchors.horizontalCenter: parent.horizontalCenter; y: Theme.px(24)
                    text: win.tabIndex === 1 ? "No apps opened yet" : "No windows mined yet"
                    color: "#aaaaaa"
                }
            }
            McScrollbar { visible: scrollable; flickable: list; anchors { left: list.right; top: list.top; bottom: list.bottom; leftMargin: Theme.px(2) } }

            // footer: tab buttons + Done
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(30)
                spacing: Theme.px(4)
                Repeater {
                    model: win.tabLabels
                    McButton {
                        required property string modelData
                        required property int index
                        small: true
                        text: modelData
                        highlighted: win.tabIndex === index
                        onClicked: win.tabIndex = index
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(6)
                spacing: Theme.px(6)
                McButton {
                    text: "Reset Statistics"
                    width: Theme.px(150)
                    onClicked: win.confirmReset = true
                }
                McButton {
                    text: "Done"
                    width: Theme.px(98)
                    onClicked: win.closeRequested()
                }
            }

            AdvancementsConfirm {
                z: 50
                shown: win.confirmReset
                title: "Reset all statistics?"
                detail: "This cannot be undone."
                onConfirmed: { win.confirmReset = false; Stats.reset(); parent.forceActiveFocus(); }
                onCancelled: { win.confirmReset = false; parent.forceActiveFocus(); }
            }
        }
    }
}
