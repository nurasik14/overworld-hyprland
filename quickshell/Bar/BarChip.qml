import QtQuick
import qs.Common

/*  BarChip — 28 px high bar item: Nerd glyph (mono 13) + optional small text, ink-wash hover, tooltip, click / wheel.
 *    glyph · text · tooltip · glyphColor · textColor · active (seal ring) · signal clicked() · signal wheel(int delta)
 */
Item {
    id: root
    property string glyph: ""
    property string text: ""
    property string tooltip: ""
    property color glyphColor: Theme.text
    property color textColor: Theme.textMuted
    property bool active: false
    property bool enabled: true
    property int glyphSize: 14
    property int padding: Theme.space.sm
    readonly property bool hovered: mouse.containsMouse
    signal clicked(var mouseEvent)
    signal wheel(int delta)

    implicitHeight: 28
    implicitWidth: Math.max(28, row.implicitWidth + padding * 2)
    opacity: enabled ? 1 : (Theme.opacity.disabled || 0.45)
    Accessible.role: Accessible.Button
    Accessible.name: tooltip.length ? tooltip : text

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.sm
        color: Theme.inkWash
        opacity: mouse.pressed ? 1.0 : (root.hovered ? 0.7 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.sm
        color: "transparent"
        border.width: 1
        border.color: Theme.focusRing
        visible: root.active
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        Text {
            visible: root.glyph.length > 0
            text: root.glyph
            color: root.glyphColor
            font.family: Theme.fontMono
            font.pixelSize: root.glyphSize
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.durTheme } }
        }
        Text {
            visible: root.text.length > 0
            text: root.text
            color: root.textColor
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontFor("small").pixelSize
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.durTheme } }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: ev => root.clicked(ev)
        onWheel: ev => { root.wheel(ev.angleDelta.y > 0 ? 1 : -1); ev.accepted = true; }
    }
    BarTooltip { target: root; text: root.tooltip; shown: root.hovered }
}
