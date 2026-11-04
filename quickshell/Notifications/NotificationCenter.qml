import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  NotificationCenter — the chat history (SUPER+I · `ipc call notifications toggle`), namespace overworld-notifcenter.
 *  Chat look: #80000000 plate, white text with shadow, one group per app. Above it: Difficulty (Normal / Peaceful = do not
 *  disturb) and Clear Chat. Click a line to dismiss it, the cross dismisses a whole app, closing marks everything read.
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-notifcenter"
        open: ShellState.notifCenterOpen
        onCloseRequested: ShellState.close("notifCenter")
        onShownChanged: {
            if (shown) { list.contentY = 0; list.forceActiveFocus(); }
            else NotificationService.markRead();
        }

        Item {
            id: pane
            width: Theme.px(260)
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: Theme.px(4); topMargin: Theme.px(4); bottomMargin: Theme.px(44) }
            MouseArea { anchors.fill: parent }

            Row {
                id: head
                spacing: Theme.px(2)
                McButton {
                    width: Theme.px(150)
                    text: "Difficulty: " + (NotificationService.dnd ? "Peaceful" : "Normal")
                    tooltip: NotificationService.dnd ? "Peaceful" : "Normal"
                    tooltipDescription: NotificationService.dnd ? "Notes wait here, no toasts" : "Toasts appear in the corner"
                    onClicked: NotificationService.toggleDnd()
                }
                McButton {
                    width: Theme.px(108)
                    text: "Clear Chat"
                    enabled: NotificationService.count > 0
                    onClicked: NotificationService.dismissAll()
                }
            }

            Rectangle {
                id: plate
                anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: footer.top; topMargin: Theme.px(2); bottomMargin: Theme.px(2) }
                color: "#80000000"
            }

            McText {
                anchors.centerIn: plate
                visible: NotificationService.count === 0
                color: Theme.tooltipDesc
                text: NotificationService.dnd ? "No new messages (Peaceful)" : "No new messages"
            }

            Flickable {
                id: list
                anchors.fill: plate
                anchors.margins: Theme.px(3)
                anchors.rightMargin: Theme.px(9)
                contentWidth: width
                contentHeight: rows.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: NotificationService.count > 0
                Keys.onPressed: event => {
                    const step = event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : event.key === Qt.Key_PageUp ? -8 : event.key === Qt.Key_PageDown ? 8 : 0;
                    if (!step) return;
                    list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + step * Theme.px(10)));
                    event.accepted = true;
                }
                Column {
                    id: rows
                    width: list.width
                    spacing: Theme.px(4)
                    Repeater {
                        model: NotificationService.groups
                        Column {
                            id: group
                            required property var modelData
                            width: rows.width
                            spacing: Theme.gui
                            Item {   // the app: <name> as in chat, with the count and a dismiss cross
                                width: parent.width
                                height: Theme.px(10)
                                McText {
                                    width: parent.width - Theme.px(14)
                                    darkGround: true
                                    codes: "§e<" + group.modelData.app + "> §8" + group.modelData.notes.length + (group.modelData.notes.length === 1 ? " message" : " messages")
                                    elide: Text.ElideRight
                                }
                                McSprite {
                                    anchors.right: parent.right
                                    sprite: crossArea.containsMouse ? "widget/cross_button_highlighted" : "widget/cross_button"
                                    MouseArea {
                                        id: crossArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            const ns = group.modelData.notes.slice();
                                            for (let i = 0; i < ns.length; i++) NotificationService.dismiss(ns[i]);
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: group.modelData.notes
                                Item {
                                    id: line
                                    required property var modelData
                                    width: group.width
                                    height: lineCol.implicitHeight + Theme.gui
                                    Rectangle { anchors.fill: parent; color: "#30ffffff"; visible: lineArea.containsMouse }
                                    MouseArea {
                                        id: lineArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotificationService.dismiss(line.modelData)
                                    }
                                    Column {
                                        id: lineCol
                                        width: parent.width
                                        McText {
                                            width: parent.width
                                            darkGround: true
                                            wrapMode: Text.Wrap
                                            codes: "§8" + Qt.formatDateTime(new Date(line.modelData.time), "HH:mm") + " "
                                                + (line.modelData.critical ? "§d" : line.modelData.low ? "§7" : "§f") + line.modelData.summary
                                        }
                                        McText {
                                            visible: text.length > 0
                                            width: parent.width
                                            color: Theme.tooltipDesc
                                            text: line.modelData.body
                                            textFormat: Text.StyledText
                                            linkColor: Theme.chat["b"]
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 4
                                            elide: Text.ElideRight
                                            onLinkActivated: link => ShellState.run(["xdg-open", link])
                                        }
                                        Flow {
                                            visible: line.modelData.actions && line.modelData.actions.length > 0
                                            width: parent.width
                                            spacing: Theme.px(2)
                                            Repeater {
                                                model: line.modelData.actions || []
                                                McButton {
                                                    required property var modelData
                                                    fit: true
                                                    height: Theme.px(14)
                                                    horizontalPadding: Theme.px(4)
                                                    text: modelData.text || modelData.identifier
                                                    onClicked: modelData.invoke()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            McScrollbar {
                flickable: list
                anchors { right: plate.right; rightMargin: Theme.px(1); top: list.top; bottom: list.bottom }
            }

            McText {
                id: footer
                anchors { left: parent.left; bottom: parent.bottom }
                color: Theme.tooltipDesc
                text: NotificationService.count + " in history   Esc: close"
            }
        }
    }
}
