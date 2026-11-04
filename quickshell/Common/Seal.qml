import QtQuick
import qs.Common as Common

/*  Seal — the signature gesture: a square vermilion stamp with a white brush glyph.
 *  size:    14 (title bar), 24 (notification app icon / confirm), 48 (hero, hyprlock)
 *  glyph:   薬 猫 印 (default 印). Japanese 薬 is drawn with the JP brush font automatically.
 *  rough:   true → use the generated rough-edged PNG (assets/pd/seals) when one exists for the glyph; else drawn.
 *  outline: faint cream ring so the seal separates from an ink title bar (default on for size ≤ 16).
 *  Accessibility: a seal is decorative; pair it with a Latin label (Accessible.name is set from `label`).
 */
Item {
    id: root
    property int size: 14
    property string glyph: "印"
    property bool rough: size >= 32
    property bool outline: size <= 16
    property string label: ""          // Latin meaning, e.g. "Seal", "Overworld"
    property color color: Common.Theme.seal
    property color glyphColor: Common.Theme.textOnSeal

    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.Graphic
    Accessible.name: label

    readonly property bool hasImage: ["薬", "药", "猫", "印"].indexOf(glyph) >= 0

    Rectangle {
        id: square
        anchors.fill: parent
        visible: !(root.rough && root.hasImage)
        color: root.color
        radius: root.size >= 24 ? Common.Theme.radius.xs : 1
        border.width: root.outline ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.35)
        Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.size >= 24 ? 1 : 0
            text: root.glyph
            color: root.glyphColor
            font.family: Common.Theme.brushFamilyFor(root.glyph)
            font.pixelSize: Math.round(root.size * 0.72)
            renderType: Text.NativeRendering
        }
    }
    Image {
        anchors.fill: parent
        visible: root.rough && root.hasImage
        source: visible ? Common.Theme.sealImage(root.glyph) : ""
        sourceSize: Qt.size(256, 256)
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
    }
}
