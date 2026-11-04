import QtQuick
import qs.Common as Common

/*  InkButton — text / icon button with ink-wash states.
 *    text, icon (Nerd Font glyph), primary (seal-filled confirm), accentFill (accent-filled), quiet (no border)
 *    hover = ink wash 8 %, pressed = 16 %, focus ring = 1 px seal, disabled = 45 % opacity, no pointer.
 *    Keyboard: activeFocusOnTab, Enter/Return/Space activate.  signal clicked().
 *    Height 32 (control_height); use `large: true` for 48.
 */
Item {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool accentFill: false
    property bool quiet: false
    property bool large: false
    property bool enabled: true
    property bool checked: false
    property string tooltip: ""
    property int horizontalPadding: Common.Theme.space.md
    readonly property bool filled: primary || accentFill
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed || keyDown
    property bool keyDown: false
    property bool focusRingVisible: activeFocus     // overridable (previews / custom focus scopes)
    signal clicked()

    implicitHeight: large ? (Common.Theme.sizes.control_height_large || 48) : (Common.Theme.sizes.control_height || 32)
    implicitWidth: Math.max(implicitHeight, row.implicitWidth + horizontalPadding * 2)
    opacity: enabled ? 1 : (Common.Theme.opacity.disabled || 0.45)
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text.length ? text : tooltip
    Accessible.onPressAction: if (enabled) root.clicked()

    readonly property color fillColor: primary ? Common.Theme.seal : (accentFill ? Common.Theme.accent : "transparent")
    readonly property color fgColor: primary ? Common.Theme.textOnSeal : (accentFill ? Common.Theme.textOnAccent : Common.Theme.text)

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Common.Theme.radius.sm
        color: root.fillColor
        border.width: root.quiet || root.filled ? 0 : Common.Theme.border.hairline
        border.color: root.checked ? Common.Theme.seal : Common.Theme.hairline
        Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Common.Theme.durFast } }
    }
    Rectangle {   // ink wash (hover / pressed / checked)
        anchors.fill: parent
        radius: bg.radius
        color: root.filled ? Qt.rgba(1, 1, 1, 1) : Common.Theme.inkWash
        opacity: root.pressed ? (root.filled ? 0.18 : 1.0)
               : root.hovered ? (root.filled ? 0.10 : 0.6)
               : root.checked ? 0.4 : 0
        Behavior on opacity { NumberAnimation { duration: Common.Theme.durFast; easing.type: Easing.OutCubic } }
    }
    Rectangle {   // pressed: a touch more ink
        anchors.fill: parent
        radius: bg.radius
        color: Common.Theme.inkWashStrong
        visible: !root.filled
        opacity: root.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Common.Theme.durFast } }
    }
    Rectangle {   // focus ring (keyboard only), 1 px seal, 2 px outside
        anchors.fill: parent
        anchors.margins: -2
        radius: bg.radius + 2
        color: "transparent"
        border.width: Common.Theme.border.focus
        border.color: Common.Theme.focusRing
        visible: root.focusRingVisible
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Common.Theme.space.sm
        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.fgColor
            font.family: Common.Theme.fontMono
            font.pixelSize: root.large ? 20 : 15
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Common.Theme.durTheme } }
        }
        Text {
            visible: root.text.length > 0
            text: root.text
            color: root.fgColor
            font.family: Common.Theme.fontUi
            font.pixelSize: Common.Theme.fontFor("ui").pixelSize
            font.weight: root.filled ? 600 : 500
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Common.Theme.durTheme } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.forceActiveFocus(); root.clicked() }
    }
    Keys.onPressed: event => {
        if (!root.enabled) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.keyDown = true; event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (root.keyDown && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.keyDown = false; event.accepted = true; root.clicked();
        }
    }
}
