import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  NetworkPanel — 网 · NETWORK (SUPER+N · `ipc call network toggle`), namespace overworld-network.
 *  420×600 PaperPanel under the bar at the right (DESIGN §7.3): Wi-Fi / Airplane toggles · wired status · Wi-Fi list
 *  (NetworkRow, inline connect form) · VPN list (up/down) · footer: Rescan + last nmcli message + spinner.
 *  Everything goes through Services/NetworkService (nmcli argument arrays, never shell-interpolated).
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-network"
        open: ShellState.networkOpen
        onCloseRequested: ShellState.close("network")
        property string expandedSsid: ""

        Connections { target: ShellState; function onNetworkExpand(ssid) { win.expandedSsid = ssid; } }
        onShownChanged: {
            NetworkService.polling = shown;
            if (shown) { win.expandedSsid = ""; NetworkService.lastMessage = ""; NetworkService.lastError = false; NetworkService.refresh(); }
        }

        PaperPanel {
            id: panel
            width: 420; height: 600
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Theme.space.margin
            anchors.topMargin: (Theme.sizes.bar_height || 36) + Theme.space.lg
            title: "网"
            subtitle: "Network"
            sealGlyph: "印"
            radius: Theme.radius.lg
            padding: Theme.space.md
            opacity: win.progress
            transform: Translate { x: (1 - win.progress) * 12 }

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                spacing: Theme.space.sm

                // ---- toggles + wired
                Row {
                    id: toggles
                    width: parent.width
                    spacing: Theme.space.sm
                    InkButton {
                        icon: NetworkService.wifiEnabled ? "󰤨" : "󰤮"
                        text: NetworkService.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                        checked: NetworkService.wifiEnabled
                        tooltip: "nmcli radio wifi on|off"
                        onClicked: NetworkService.setWifi(!NetworkService.wifiEnabled)
                    }
                    InkButton {
                        icon: NetworkService.airplane ? "󰀝" : "󰀞"
                        text: "Airplane"
                        checked: NetworkService.airplane
                        tooltip: "nmcli radio all off|on"
                        onClicked: NetworkService.setAirplane(!NetworkService.airplane)
                    }
                    Item { width: parent.width - toggles.children[0].width - toggles.children[1].width - wired.width - parent.spacing * 3; height: 1 }
                    Row {
                        id: wired
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: NetworkService.wiredConnected ? "󰈁" : "󰈂"
                            color: NetworkService.wiredConnected ? Theme.accent : Theme.textMuted
                            font.family: Theme.fontMono; font.pixelSize: 16
                            renderType: Text.NativeRendering
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        InkText {
                            role: "small"; muted: !NetworkService.wiredConnected
                            text: NetworkService.wiredIface.length ? (NetworkService.wiredConnected ? "wired" : "no cable") : "no ethernet"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                InkDivider { width: parent.width; brush: true; height: 10 }

                // ---- wifi list
                Item {
                    width: parent.width
                    height: parent.height - toggles.height - 10 - vpnBlock.height - footer.height - parent.spacing * 5 - 10
                    Flickable {
                        id: list
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: rows.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: rows
                            width: list.width
                            Repeater {
                                model: NetworkService.networks
                                NetworkRow {
                                    required property var modelData
                                    net: modelData
                                    width: rows.width
                                    expanded: win.expandedSsid === modelData.ssid
                                    onToggleExpanded: win.expandedSsid = (win.expandedSsid === modelData.ssid ? "" : modelData.ssid)
                                    onConnectRequested: (ssid, password) => NetworkService.connect(ssid, password, function(ok) { if (ok) win.expandedSsid = ""; })
                                    onDisconnectRequested: NetworkService.disconnect()
                                    onForgetRequested: ssid => NetworkService.forget(ssid)
                                }
                            }
                        }
                    }
                    Column {   // empty state
                        anchors.centerIn: parent
                        spacing: Theme.space.sm
                        visible: NetworkService.networks.length === 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: NetworkService.wifiEnabled ? "空" : "关"
                            font.family: Theme.fontDisplay; font.pixelSize: 40
                            color: Theme.textMuted; renderType: Text.NativeRendering
                        }
                        InkText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "body"; muted: true
                            text: NetworkService.wifiEnabled ? (NetworkService.scanning ? "scanning…" : "no networks · rescan") : "Wi-Fi is off"
                        }
                    }
                }
                InkDivider { width: parent.width; brush: true; height: 10 }

                // ---- VPN
                Column {
                    id: vpnBlock
                    width: parent.width
                    spacing: 2
                    Row {
                        spacing: Theme.space.sm
                        height: 20
                        Text { text: "󰖂"; color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: 13; renderType: Text.NativeRendering; anchors.verticalCenter: parent.verticalCenter }
                        InkText { role: "subtitle"; text: "VPN"; font.capitalization: Font.AllUppercase; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
                        InkText { role: "small"; muted: true; text: NetworkService.vpns.length === 0 ? "· no profiles (nmcli con show)" : ""; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Repeater {
                        model: NetworkService.vpns.slice(0, 3)
                        Row {
                            id: vpnRow
                            required property var modelData
                            width: vpnBlock.width
                            height: 30
                            spacing: Theme.space.sm
                            Seal { size: 14; glyph: "印"; label: "active"; opacity: vpnRow.modelData.active ? 1 : 0.15; anchors.verticalCenter: parent.verticalCenter }
                            InkText {
                                role: "body"
                                text: vpnRow.modelData.name
                                font.weight: vpnRow.modelData.active ? 700 : 400
                                width: parent.width - 14 - 60 - 80 - parent.spacing * 3
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            InkText { role: "small"; muted: true; text: vpnRow.modelData.type; width: 60; anchors.verticalCenter: parent.verticalCenter }
                            InkButton {
                                text: vpnRow.modelData.active ? "Down" : "Up"
                                accentFill: !vpnRow.modelData.active
                                implicitHeight: 24; implicitWidth: 72
                                enabled: !NetworkService.busy
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: vpnRow.modelData.active ? NetworkService.vpnDown(vpnRow.modelData.name) : NetworkService.vpnUp(vpnRow.modelData.name)
                            }
                        }
                    }
                }

                // ---- footer: rescan + status
                Row {
                    id: footer
                    width: parent.width
                    height: 32
                    spacing: Theme.space.sm
                    InkButton {
                        id: rescanBtn
                        quiet: true
                        icon: NetworkService.scanning ? "󰔟" : "󰑐"
                        text: "Rescan"
                        enabled: !NetworkService.busy
                        onClicked: NetworkService.rescan()
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {   // spinner while a command runs
                        visible: NetworkService.busy
                        text: "󰔟"
                        color: Theme.accent
                        font.family: Theme.fontMono; font.pixelSize: 14
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                        RotationAnimation on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: NetworkService.busy }
                    }
                    InkText {
                        role: "small"
                        width: parent.width - rescanBtn.width - parent.spacing * 2 - 16
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                        text: NetworkService.busy ? "nmcli is working…"
                            : NetworkService.lastMessage.length ? NetworkService.lastMessage
                            : NetworkService.networks.length + " networks · " + (NetworkService.connected ? NetworkService.activeSsid : "not connected")
                        color: NetworkService.lastError ? Theme.error : Theme.textMuted
                    }
                }
            }
        }
    }
}
