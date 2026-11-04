import QtQuick
import qs.Common

/*  BlockPatch — a small square cut out of a block texture, drawn 1 texel = 1 GUI px (nearest), so a 5-texel patch is a
 *  crisp 5×5 GUI px "mini block" (the 24 h weather columns, the note-block equaliser).
 *    texture  "block/sand" — path under assets/mc/textures (first animation frame for strips like block/water_still)
 *    size     patch side in texels = GUI px on screen (default 5)
 *    u, v     patch origin inside the texture (default: roughly the middle of a 16×16)
 *    tint     multiply colour for the grey textures (water_still); transparent = none
 */
Item {
    id: root
    property string texture: "block/stone"
    property int size: 5
    property int u: 5
    property int v: 5
    property color tint: "transparent"
    property color fallback: "#808080"               // drawn instead of the magenta missing texture (no Mojang assets, no gen/ twin)
    readonly property bool missing: Theme.tex(texture) === Theme.missingTexture
    implicitWidth: Theme.px(size)
    implicitHeight: Theme.px(size)
    width: implicitWidth
    height: implicitHeight
    layer.enabled: tint.a > 0
    layer.smooth: false
    layer.effect: ShaderEffect {
        fragmentShader: "file://" + Theme.commonDir + "/shaders/mcpalette.frag.qsb"
        property real mode: 0
        property color tint: root.tint
        property color c0: "black"; property color c1: "black"; property color c2: "black"
        property color c3: "black"; property color c4: "black"; property color c5: "black"
    }
    Rectangle { anchors.fill: parent; color: root.fallback; visible: root.missing }
    Image {
        anchors.fill: parent
        visible: !root.missing
        source: Theme.tex(root.texture)
        sourceClipRect: Qt.rect(root.u, root.v, root.size, root.size)
        smooth: false
        mipmap: false
        cache: true
    }
}
