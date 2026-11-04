import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  NetworkPanel — the Multiplayer screen (SUPER+N · `ipc call network toggle`), namespace overworld-network.
 *  Wi-Fi networks are servers: name, grey MOTD (security, band), ping bars for signal. Below them the LAN section: wired + VPN.
 *  Footer as in the game: Join Server · Direct Connection (hidden SSID) · Airplane toggle / Wi-Fi toggle · Forget · Refresh · Cancel.
 *  A secured network with no saved profile gets the password screen; failures show as red text. Everything goes through
 *  Services/NetworkService (nmcli argument arrays, never shell-interpolated). Keys: Up/Down select · Enter join · F5 refresh · Esc back.
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-network"
        background: "menu"
        title: view === "list" ? "Play Multiplayer" : view === "direct" ? "Direct Connection" : "Join Server"
        headerHeight: 33
        footerHeight: view === "list" ? 60 : 0
        closeOnClickOutside: false
        open: ShellState.networkOpen
        onCloseRequested: {
            if (view !== "list") view = "list";
            else ShellState.close("network");
        }

        property string view: "list"            // list | password | direct
        property int selected: 0
        property string pendingSsid: ""
        property bool pendingEnterprise: false
        property bool confirmForget: false

        readonly property var rows: {
            const out = [];
            const nets = NetworkService.networks;
            for (let i = 0; i < nets.length; i++) out.push({ kind: "wifi", net: nets[i], key: "wifi:" + nets[i].ssid });
            out.push({ kind: "header", key: "header" });
            if (NetworkService.wiredIface.length) out.push({ kind: "wired", key: "wired" });
            const v = NetworkService.vpns;
            for (let i = 0; i < v.length; i++) out.push({ kind: "vpn", vpn: v[i], key: "vpn:" + v[i].name });
            return out;
        }
        readonly property var current: rows[selected] || null
        readonly property var currentNet: current && current.kind === "wifi" ? current.net : null

        Connections { target: ShellState; function onNetworkExpand(ssid) { win.expand(ssid); } }
        onShownChanged: {
            NetworkService.polling = shown;
            if (shown) {
                win.view = "list"; win.selected = 0; win.confirmForget = false;
                NetworkService.lastMessage = ""; NetworkService.lastError = false; NetworkService.refresh();
                list.forceActiveFocus();
            }
        }
        onSelectedChanged: confirmForget = false
        onViewChanged: if (view === "list") list.forceActiveFocus()

        function expand(ssid) {
            for (let i = 0; i < rows.length; i++) {
                if (rows[i].kind === "wifi" && rows[i].net.ssid === ssid) {
                    win.selected = i;
                    list.positionViewAtIndex(i, ListView.Contain);
                    win.join(rows[i]);
                    return;
                }
            }
        }
        function moveSelection(d) {
            let i = win.selected + d;
            if (rows[i] && rows[i].kind === "header") i += d;
            if (i >= 0 && i < rows.length) {
                win.selected = i;
                list.positionViewAtIndex(i, ListView.Contain);
            }
        }
        function join(row) {
            if (!row) return;
            if (row.kind === "vpn") {
                if (row.vpn.active) NetworkService.vpnDown(row.vpn.name); else NetworkService.vpnUp(row.vpn.name);
                return;
            }
            if (row.kind !== "wifi") return;
            const n = row.net;
            if (n.active) return;
            if (n.secured && !n.known) {
                win.pendingSsid = n.ssid;
                win.pendingEnterprise = n.enterprise;
                pw.text = ""; showPw.checked = false;
                win.view = "password";
                pw.input.forceActiveFocus();
                return;
            }
            NetworkService.connect(n.ssid, "");
        }
        function submitPassword() {
            if (!pw.text.length) { pw.input.forceActiveFocus(); return; }
            NetworkService.connect(win.pendingSsid, pw.text, ok => { if (ok) win.view = "list"; });
        }
        function submitDirect() {
            const ssid = directSsid.text.trim();
            if (!ssid.length) { directSsid.input.forceActiveFocus(); return; }
            NetworkService.connect(ssid, directPw.text, ok => { if (ok) win.view = "list"; }, true);
        }
        function forgetCurrent() {
            if (!currentNet) return;
            if (!confirmForget) { confirmForget = true; return; }
            NetworkService.forget(currentNet.ssid);
            confirmForget = false;
        }

        // ------------------------------------------------------------ header line: scanning or the last nmcli message (red on failure)
        McText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.px(19)
            width: Math.min(implicitWidth, parent.width - Theme.px(20))
            elide: Text.ElideRight
            visible: text.length > 0 && win.view === "list"
            darkGround: true
            color: NetworkService.lastError ? Theme.chat["c"] : Theme.tooltipDesc
            text: NetworkService.busy ? "Connecting to the server..."
                : NetworkService.scanning ? "Scanning..."
                : NetworkService.lastMessage
        }

        // ------------------------------------------------------------ the server list
        Item {
            anchors.fill: parent
            anchors.topMargin: Theme.px(33)
            anchors.bottomMargin: Theme.px(60)
            visible: win.view === "list"

            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: Theme.px(2)
                anchors.bottomMargin: Theme.px(2)
                clip: true
                model: win.rows
                boundsBehavior: Flickable.StopAtBounds
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Up) { win.moveSelection(-1); event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { win.moveSelection(1); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.join(win.current); event.accepted = true; }
                    else if (event.key === Qt.Key_F5) { NetworkService.rescan(); event.accepted = true; }
                }
                delegate: Loader {
                    id: rowLoader
                    required property var modelData
                    required property int index
                    width: list.width
                    height: Theme.px(modelData.kind === "header" ? 16 : 36)
                    sourceComponent: modelData.kind === "header" ? headerRow : serverRow
                }
            }
            McScrollbar {
                flickable: list
                x: Math.round(parent.width / 2) + Theme.px(158)
                y: 0
                height: parent.height
            }
            McText {
                anchors.centerIn: parent
                visible: NetworkService.networks.length === 0
                color: Theme.tooltipDesc
                text: NetworkService.wifiEnabled ? (NetworkService.scanning ? "Scanning..." : "No servers found") : "Wi-Fi is off"
            }
        }

        Component {
            id: headerRow
            McText {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.tooltipDesc
                text: "LAN Worlds"
            }
        }
        Component {
            id: serverRow
            Item {
                id: row
                readonly property var entry: parent.modelData
                readonly property int rowIndex: parent.index
                readonly property bool isSelected: win.selected === rowIndex
                readonly property var net: entry.kind === "wifi" ? entry.net : null
                readonly property var vpn: entry.kind === "vpn" ? entry.vpn : null
                readonly property bool isActive: net ? net.active : vpn ? vpn.active : NetworkService.wiredConnected
                readonly property bool joinable: net ? !net.active : vpn !== null
                readonly property int level: net ? NetworkService.pingLevel(net.signal) : 5
                readonly property bool pinging: NetworkService.busy && isSelected

                McTicker { id: rowTick; active: row.pinging }

                Rectangle {   // the game's selected row: white outline, black fill
                    x: Math.round((parent.width - width) / 2)
                    width: Theme.px(305)
                    height: Theme.px(36)
                    color: row.isSelected ? "#000000" : "transparent"
                    border.width: row.isSelected ? Theme.gui : 0
                    border.color: Theme.focusRing

                    McItemIcon {
                        x: Theme.px(2); y: Theme.px(2)
                        size: 32
                        name: row.entry.kind === "wired" ? "redstone_lamp"
                            : row.entry.kind === "vpn" ? (row.isActive ? "ender_eye" : "ender_pearl")
                            : row.isActive ? "beacon"
                            : row.net.known ? "grass_block"
                            : row.net.enterprise ? "ender_chest"
                            : row.net.secured ? "iron_door" : "oak_door"
                    }
                    Rectangle {   // hover over the icon: darker, with the join arrow on it
                        x: Theme.px(2); y: Theme.px(2)
                        width: Theme.px(32); height: Theme.px(32)
                        color: "#A0909090"
                        visible: rowArea.containsMouse && row.joinable
                        McSprite {
                            sprite: iconHover.hovered ? "server_list/join_highlighted" : "server_list/join"
                        }
                        HoverHandler { id: iconHover }
                    }
                    McText {
                        x: Theme.px(36); y: Theme.px(2)
                        width: parent.width - Theme.px(36 + 50)
                        elide: Text.ElideRight
                        color: Theme.hudText
                        text: row.net ? row.net.ssid : row.vpn ? row.vpn.name : "Wired (" + NetworkService.wiredIface + ")"
                    }
                    McText {
                        x: Theme.px(36); y: Theme.px(12)
                        width: parent.width - Theme.px(40)
                        elide: Text.ElideRight
                        color: "#808080"
                        text: row.net ? NetworkService.motd(row.net) : row.vpn ? row.vpn.type.toUpperCase() + " · " + (row.vpn.device.length ? row.vpn.device : "no device") : NetworkService.wiredState
                    }
                    McText {
                        x: Theme.px(36); y: Theme.px(22)
                        width: parent.width - Theme.px(40)
                        elide: Text.ElideRight
                        darkGround: true
                        codes: row.isActive ? "§aConnected" : row.net && row.net.known ? "§7Saved" : ""
                        visible: codes.length > 0
                    }
                    McSprite {   // ping bars, animating while nmcli works on this row
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(5)
                        y: Theme.px(4)
                        sprite: row.pinging ? "server_list/pinging_" + (Math.floor(rowTick.tick / 2) % 5 + 1)
                              : row.entry.kind === "wired" ? (row.isActive ? "server_list/ping_5" : "server_list/unreachable")
                              : row.vpn ? (row.isActive ? "server_list/ping_5" : "server_list/unreachable")
                              : "server_list/ping_" + row.level
                    }
                    McText {
                        visible: row.net !== null
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(18)
                        y: Theme.px(2)
                        color: "#808080"
                        text: row.net ? row.net.signal + "%" : ""
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: mouse => {
                            win.selected = row.rowIndex;
                            if (mouse.x < Theme.px(34) && row.joinable) win.join(row.entry);
                        }
                        onDoubleClicked: win.join(row.entry)
                    }
                }
            }
        }

        // ------------------------------------------------------------ footer: the game's two button rows
        Column {
            visible: win.view === "list"
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - Theme.px(52)
            spacing: Theme.px(4)
            Row {
                spacing: Theme.px(4)
                anchors.horizontalCenter: parent.horizontalCenter
                McButton {
                    width: Theme.px(100)
                    readonly property bool isConn: !!win.currentNet && win.currentNet.active
                    text: isConn ? "Disconnect" : win.current && win.current.kind === "vpn" && win.current.vpn.active ? "Disconnect" : "Join Server"
                    enabled: !NetworkService.busy && !!win.current && win.current.kind !== "wired"
                    onClicked: isConn ? NetworkService.disconnect() : win.join(win.current)
                }
                McButton {
                    width: Theme.px(100)
                    text: "Direct Connection"
                    enabled: NetworkService.wifiEnabled
                    tooltip: "Hidden network"
                    tooltipDescription: "Join by SSID"
                    onClicked: { directSsid.text = ""; directPw.text = ""; win.view = "direct"; directSsid.input.forceActiveFocus(); }
                }
                McToggle {
                    width: Theme.px(100)
                    label: "Airplane"
                    checked: NetworkService.airplane
                    onToggled: c => NetworkService.setAirplane(c)
                }
            }
            Row {
                spacing: Theme.px(4)
                anchors.horizontalCenter: parent.horizontalCenter
                McToggle {
                    width: Theme.px(74)
                    label: "Wi-Fi"
                    checked: NetworkService.wifiEnabled
                    enabled: !NetworkService.airplane
                    onToggled: c => NetworkService.setWifi(c)
                }
                McButton {
                    width: Theme.px(74)
                    text: win.confirmForget ? "Sure?" : "Forget"
                    enabled: !!win.currentNet && win.currentNet.known
                    tooltip: "Delete the saved profile"
                    tooltipDescription: "Click again to confirm"
                    onClicked: win.forgetCurrent()
                }
                McButton {
                    width: Theme.px(74)
                    text: "Refresh"
                    enabled: !NetworkService.busy
                    onClicked: NetworkService.rescan()
                }
                McButton {
                    width: Theme.px(74)
                    text: "Cancel"
                    onClicked: ShellState.close("network")
                }
            }
        }

        // ------------------------------------------------------------ password screen
        Column {
            visible: win.view === "password"
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height / 4)
            width: Theme.px(200)
            spacing: Theme.px(4)
            McText { color: Theme.tooltipDesc; text: "Password for " + win.pendingSsid; width: parent.width; elide: Text.ElideRight }
            McText {
                visible: win.pendingEnterprise
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.chat["e"]
                text: "This is an enterprise (802.1X) network: it needs a saved profile, a password alone will not do."
            }
            McTextField {
                id: pw
                width: parent.width
                echoMode: showPw.checked ? TextInput.Normal : TextInput.Password
                onAccepted: win.submitPassword()
            }
            McCheckbox {
                id: showPw
                text: "Show password"
                labelColor: Theme.hudText
            }
            McText {
                visible: NetworkService.lastError && NetworkService.lastMessage.length > 0
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.chat["c"]
                text: NetworkService.lastMessage
            }
            Item { width: 1; height: Theme.px(8) }
            McButton {
                width: parent.width
                text: NetworkService.busy ? "Connecting..." : "Join Server"
                enabled: !NetworkService.busy && pw.text.length > 0
                onClicked: win.submitPassword()
            }
            McButton {
                width: parent.width
                text: "Cancel"
                onClicked: win.closeRequested()
            }
        }

        // ------------------------------------------------------------ direct connection: hidden SSID
        Column {
            visible: win.view === "direct"
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height / 4)
            width: Theme.px(200)
            spacing: Theme.px(4)
            McText { color: Theme.tooltipDesc; text: "Network Name" }
            McTextField {
                id: directSsid
                width: parent.width
                onAccepted: directPw.input.forceActiveFocus()
            }
            McText { color: Theme.tooltipDesc; text: "Password (empty = open network)" }
            McTextField {
                id: directPw
                width: parent.width
                echoMode: TextInput.Password
                onAccepted: win.submitDirect()
            }
            McText {
                visible: NetworkService.lastError && NetworkService.lastMessage.length > 0
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.chat["c"]
                text: NetworkService.lastMessage
            }
            Item { width: 1; height: Theme.px(8) }
            McButton {
                width: parent.width
                text: NetworkService.busy ? "Connecting..." : "Join Server"
                enabled: !NetworkService.busy && directSsid.text.trim().length > 0
                onClicked: win.submitDirect()
            }
            McButton {
                width: parent.width
                text: "Cancel"
                onClicked: win.closeRequested()
            }
        }
    }
}
