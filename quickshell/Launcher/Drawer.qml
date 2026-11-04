import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common

/*  Drawer — one labelled wooden drawer of the medicine cabinet (DESIGN §6.5).
 *    label · icon (icon name or path) · glyph (fallback CJK glyph when there is no icon) · selected · staggerIndex · tick
 *    hover: pulls 4 px down + shadow, ring gold → accent2 · selected: Seal 14 top-right · pressed: 6 px, ink wash
 *  signal activated()  (click)
 */
Item {
    id: root
    property string label: ""
    property string icon: ""
    property string glyph: ""
    property string sublabel: ""
    property bool selected: false
    property int staggerIndex: 0
    property int tick: 0
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    signal activated()
    signal hoveredChangedTo(bool h)

    width: 118
    height: 90
    Accessible.role: Accessible.Button
    Accessible.name: label

    // entrance: 40 ms stagger, opacity + 6 px rise (DESIGN §5)
    opacity: 0
    transform: Translate { id: rise; y: 6 }
    onTickChanged: enter.restart()
    Component.onCompleted: enter.start()
    SequentialAnimation {
        id: enter
        PauseAnimation { duration: Math.min(root.staggerIndex, 30) * Theme.stagger }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Theme.durBase; easing.type: Theme.easeInk }
            NumberAnimation { target: rise; property: "y"; from: 6; to: 0; duration: Theme.durBase; easing.type: Theme.easeInk }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        y: root.pressed ? 6 : (root.hovered || root.selected ? 4 : 0)
        Behavior on y { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }

        Rectangle {   // shadow when pulled
            anchors.fill: front
            anchors.topMargin: 3
            radius: front.radius
            color: Theme.shadowStrong
            opacity: root.hovered || root.selected ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        Rectangle {
            id: front
            anchors.fill: parent
            radius: Theme.radius.sm
            color: Theme.wood
            border.width: 1
            border.color: Theme.woodDark
            Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
            Rectangle {   // wood grain hint: a lighter top edge
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 1
                height: 1
                color: Qt.rgba(1, 1, 1, Theme.isDark ? 0.06 : 0.35)
            }
            Rectangle {   // ink wash on press
                anchors.fill: parent
                radius: parent.radius
                color: Theme.inkWashStrong
                opacity: root.pressed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }
        }

        Item {   // icon 32 at (12,10)
            x: 12; y: 10
            width: 32; height: 32
            IconImage {
                anchors.centerIn: parent
                implicitSize: 32
                visible: root.icon.length > 0 && status !== Image.Error
                source: root.icon.length ? (root.icon.indexOf("/") === 0 ? "file://" + root.icon : Quickshell.iconPath(root.icon, "application-x-executable")) : ""
            }
            Text {
                anchors.centerIn: parent
                visible: root.icon.length === 0
                text: root.glyph.length ? root.glyph : "药"
                font.family: Theme.fontDisplay
                font.pixelSize: 26
                color: Theme.woodDark
                renderType: Text.NativeRendering
            }
        }
        Text {   // label: LXGW WenKai 13, 2 lines
            x: 52; y: 10
            width: parent.width - 52 - 8
            text: root.label
            font.family: Theme.fontBody
            font.pixelSize: 13
            color: Theme.text
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: Theme.durTheme } }
        }
        Text {
            visible: root.sublabel.length > 0
            x: 12; y: 50
            width: parent.width - 24
            text: root.sublabel
            font.family: Theme.fontUi
            font.pixelSize: 11
            color: Theme.textMuted
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
        Rectangle {   // brass ring pull
            width: 10; height: 10; radius: 5
            x: Math.round(parent.width / 2 - 5); y: 68
            color: "transparent"
            border.width: 2
            border.color: root.hovered || root.selected ? Theme.accent2 : Theme.gold
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
            Rectangle { width: 4; height: 2; radius: 1; color: Theme.woodDark; anchors.horizontalCenter: parent.horizontalCenter; y: -2 }
        }
        Seal {   // keyboard selection marker
            anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 6
            size: 14; glyph: "印"; label: "selected"
            opacity: root.selected ? 1 : 0
            scale: root.selected ? 1 : 1.15
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
        onContainsMouseChanged: root.hoveredChangedTo(containsMouse)
    }
}
