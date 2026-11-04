import QtQuick
import qs.Common
import qs.Services

/*  NetworkRow — one Wi-Fi network (DESIGN §6.6): signal glyph · SSID (bold when connected) · lock · nn% · seal when connected.
 *  expanded → inline connect form (password + show toggle, Connect / Cancel) or, for the connected one, Disconnect / Forget.
 */
Item {
    id: root
    property var net: null            // { ssid, signal, security, secured, enterprise, active, known }
    property bool expanded: false
    property bool confirmForget: false
    readonly property bool active: net ? net.active : false
    signal toggleExpanded()
    signal connectRequested(string ssid, string password)
    signal disconnectRequested()
    signal forgetRequested(string ssid)

    width: parent ? parent.width : 400
    implicitHeight: 44 + (expanded ? form.implicitHeight + Theme.space.sm : 0)
    Behavior on implicitHeight { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
    clip: true
    Accessible.role: Accessible.ListItem
    Accessible.name: net ? (net.ssid + " " + net.signal + "%" + (active ? " connected" : "")) : ""

    onExpandedChanged: {
        root.confirmForget = false;
        if (expanded) { pw.text = ""; pw.error = false; if (!root.active && root.net && root.net.secured && !root.net.known) pw.forceActiveFocus(); }
    }

    Rectangle {   // hover / selected wash
        anchors.fill: parent
        radius: Theme.radius.sm
        color: Theme.inkWash
        opacity: root.expanded ? 1 : (rowMouse.containsMouse ? 0.6 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }
    Rectangle {   // 2 px accent rule on the left when selected
        width: 2; height: 44 - 12
        anchors.left: parent.left; y: 6
        color: Theme.accent
        visible: root.expanded
    }

    Row {
        id: row
        width: parent.width
        height: 44
        spacing: Theme.space.sm
        leftPadding: Theme.space.md
        rightPadding: Theme.space.md
        Text {
            text: root.net ? NetworkService.signalGlyph(root.net.signal) : "󰤯"
            color: root.active ? Theme.accent : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 18
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            opacity: NetworkService.busy && root.expanded ? pulse.value : 1
        }
        InkText {
            role: "body"
            text: root.net ? root.net.ssid : ""
            font.weight: root.active ? 700 : 400
            width: parent.width - parent.leftPadding - parent.rightPadding - 22 - 20 - 40 - (root.active ? 90 : 0) - parent.spacing * 4
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.net && root.net.secured ? (root.net.enterprise ? "󰦝" : "󰌾") : ""
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: 13
            renderType: Text.NativeRendering
            width: 20
            anchors.verticalCenter: parent.verticalCenter
        }
        Row {
            visible: root.active
            spacing: 4
            width: 90
            anchors.verticalCenter: parent.verticalCenter
            Seal { size: 14; glyph: "印"; label: "connected"; anchors.verticalCenter: parent.verticalCenter }
            InkText { role: "small"; muted: true; text: "connected"; anchors.verticalCenter: parent.verticalCenter }
        }
        InkText {
            role: "small"; muted: true
            text: root.net ? root.net.signal + "%" : ""
            width: 40
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: rowMouse
        anchors.fill: row
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleExpanded()
    }
    SequentialAnimation {   // signal glyph pulses while a command runs
        id: pulse
        property real value: 1
        running: NetworkService.busy && root.expanded
        loops: Animation.Infinite
        NumberAnimation { target: pulse; property: "value"; to: 0.5; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { target: pulse; property: "value"; to: 1; duration: 600; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) value = 1
    }

    // ---- inline form
    Column {
        id: form
        anchors.top: row.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: Theme.space.md + 22 + Theme.space.sm
        anchors.rightMargin: Theme.space.md
        spacing: Theme.space.sm
        visible: root.expanded
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        // connected → Disconnect / Forget
        Row {
            visible: root.active
            spacing: Theme.space.sm
            InkButton { text: "Disconnect"; icon: "󰤮"; onClicked: root.disconnectRequested() }
            InkButton {
                text: root.confirmForget ? "Forget · confirm" : "Forget"
                icon: root.confirmForget ? "印" : "󰆴"
                primary: root.confirmForget
                tooltip: "Delete the saved profile"
                onClicked: { if (root.confirmForget) { root.forgetRequested(root.net.ssid); root.confirmForget = false; } else root.confirmForget = true; }
            }
            InkButton { text: "Cancel"; quiet: true; onClicked: root.toggleExpanded() }
        }
        // not connected → password (if secured and not saved) + Connect / Cancel
        InkField {
            id: pw
            visible: !root.active && root.net && root.net.secured
            width: parent.width
            password: true
            icon: "󰌾"
            placeholder: root.net && root.net.known ? "saved · password optional" : (root.net && root.net.enterprise ? "enterprise (802.1X): use a saved profile" : "password · 密码")
            onAccepted: root.submit()
            onEscaped: root.toggleExpanded()
        }
        Row {
            visible: !root.active
            spacing: Theme.space.sm
            InkButton {
                primary: true
                text: NetworkService.busy ? "Connecting…" : "Connect"
                icon: "印"
                enabled: !NetworkService.busy
                onClicked: root.submit()
            }
            InkButton {
                visible: root.net && root.net.known
                text: root.confirmForget ? "Forget · confirm" : "Forget"
                quiet: !root.confirmForget
                primary: root.confirmForget
                onClicked: { if (root.confirmForget) { root.forgetRequested(root.net.ssid); root.confirmForget = false; } else root.confirmForget = true; }
            }
            InkButton { text: "Cancel"; quiet: true; onClicked: root.toggleExpanded() }
        }
        InkText {   // inline nmcli result for this row
            visible: root.expanded && NetworkService.lastMessage.length > 0 && !NetworkService.busy
            role: "small"
            width: parent.width
            wrapMode: Text.Wrap
            text: (NetworkService.lastError ? "⚠ " : "✓ ") + NetworkService.lastMessage
            color: NetworkService.lastError ? Theme.error : Theme.success
        }
        Item { width: 1; height: 2 }
    }
    function submit() {
        if (!root.net) return;
        if (root.net.secured && !root.net.known && pw.text.length === 0) { pw.error = true; pw.shake(); pw.forceActiveFocus(); return; }
        pw.error = false;
        root.connectRequested(root.net.ssid, pw.text);
    }
    Connections {
        target: NetworkService
        function onLastErrorChanged() { if (root.expanded && NetworkService.lastError) pw.error = true; }
    }
}
