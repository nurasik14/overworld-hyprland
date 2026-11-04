import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  NotificationCenter — the desk of notes (SUPER+I · `ipc call notifications toggle`), namespace overworld-notifcenter.
 *  Right-side 420 px PaperPanel under the bar: DND toggle · Clear all · notes grouped by app · per-item dismiss ·
 *  empty state "无 · No notes on the desk" with an enso.
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
        onShownChanged: if (!shown) NotificationService.markRead()

        PaperPanel {
            id: panel
            width: 420
            height: parent.height - (Theme.sizes.bar_height || 36) - Theme.space.lg - Theme.space.margin
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Theme.space.margin
            anchors.topMargin: (Theme.sizes.bar_height || 36) + Theme.space.lg
            title: "报"
            subtitle: "Notifications"
            sealGlyph: "印"
            radius: Theme.radius.lg
            padding: Theme.space.md
            opacity: win.progress
            transform: Translate { x: (1 - win.progress) * 12 }

            MouseArea { anchors.fill: parent }   // keep scrim clicks out

            Column {
                anchors.fill: parent
                spacing: Theme.space.md

                Row {   // header controls
                    id: header
                    width: parent.width
                    spacing: Theme.space.sm
                    InkButton {
                        id: dndBtn
                        icon: NotificationService.dnd ? "󰂛" : "󰂚"
                        text: NotificationService.dnd ? "Do not disturb · on" : "Do not disturb · off"
                        checked: NotificationService.dnd
                        tooltip: "Toggle do-not-disturb"
                        onClicked: NotificationService.toggleDnd()
                    }
                    Item { width: parent.width - clearBtn.width - dndBtn.width - parent.spacing * 2; height: 1 }
                    InkButton {
                        id: clearBtn
                        icon: "󰃢"
                        text: "Clear all"
                        quiet: true
                        enabled: NotificationService.count > 0
                        onClicked: NotificationService.dismissAll()
                    }
                }
                InkDivider { width: parent.width; brush: true; height: 10 }

                Item {   // list / empty state
                    width: parent.width
                    height: parent.height - header.height - 10 - parent.spacing * 3 - footer.height

                    Column {   // empty state
                        anchors.centerIn: parent
                        spacing: Theme.space.sm
                        visible: NotificationService.count === 0
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: Theme.texture("enso-ink")
                            width: 72; height: 72
                            sourceSize: Qt.size(144, 144)
                            opacity: 0.6
                            smooth: true; mipmap: true; asynchronous: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "无"
                            font.family: Theme.fontDisplay; font.pixelSize: 32
                            color: Theme.textMuted
                            renderType: Text.NativeRendering
                        }
                        InkText { anchors.horizontalCenter: parent.horizontalCenter; role: "body"; muted: true; text: "No notes on the desk" }
                        InkText { anchors.horizontalCenter: parent.horizontalCenter; role: "small"; muted: true; text: NotificationService.dnd ? "do not disturb is on" : "notifications will be kept here" }
                    }

                    Flickable {
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: list.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        visible: NotificationService.count > 0
                        Column {
                            id: list
                            width: parent.width
                            spacing: Theme.space.md
                            Repeater {
                                model: NotificationService.groups
                                Column {
                                    id: group
                                    required property var modelData
                                    width: list.width
                                    spacing: Theme.space.sm
                                    Row {   // app header
                                        width: parent.width
                                        spacing: Theme.space.sm
                                        Seal {
                                            size: 14
                                            glyph: NotificationService.appGlyph(group.modelData.app)
                                            label: group.modelData.app
                                            color: Theme.frame
                                            glyphColor: Theme.titlebarText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        InkText {
                                            role: "ui"
                                            font.weight: 600
                                            text: group.modelData.app
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        InkText {
                                            role: "small"; muted: true
                                            text: group.modelData.notes.length + (group.modelData.notes.length === 1 ? " note" : " notes")
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Item { width: parent.width - 14 - 180 - parent.spacing * 3; height: 1 }
                                        InkButton {
                                            quiet: true
                                            text: "dismiss"
                                            implicitHeight: 24
                                            horizontalPadding: 6
                                            tooltip: "Dismiss every note from " + group.modelData.app
                                            onClicked: { const ns = group.modelData.notes.slice(); for (let i = 0; i < ns.length; i++) NotificationService.dismiss(ns[i]); }
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Repeater {
                                        model: group.modelData.notes
                                        NoteCard {
                                            required property var modelData
                                            note: modelData
                                            compact: true
                                            width: group.width
                                            onCloseClicked: NotificationService.dismiss(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    id: footer
                    width: parent.width; height: 18
                    InkText {
                        role: "small"; muted: true
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: NotificationService.count + " on the desk · esc close"
                    }
                }
            }
        }
    }
}
