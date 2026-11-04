import QtQuick
import qs.Common

/*  AdvFrame — the advancement window frame (gui/advancements/window, 252×140 in a 256×256 sheet) at any size.
 *  The corners are copied texel for texel, the edges stretch a one-texel strip, the middle is transparent.
 *  The frame's grey bevel follows Night through the same palette shader McNineSlice uses.
 *    size in GUI px: guiWidth × guiHeight;  inner area: x 9, y 18, w−18, h−27
 */
Item {
    id: root
    property int guiWidth: 252
    property int guiHeight: 140
    readonly property url src: Theme.tex("gui/advancements/window")
    readonly property int g: Theme.gui
    width: guiWidth * g
    height: guiHeight * g

    component Piece: Image {
        property rect clip: Qt.rect(0, 0, 1, 1)
        source: root.src
        sourceClipRect: clip
        smooth: false
        fillMode: Image.Stretch
        cache: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: Theme.isDark
        layer.smooth: false
        layer.effect: ShaderEffect {
            fragmentShader: "file://" + Theme.commonDir + "/shaders/mcpalette.frag.qsb"
            property real mode: 1
            property color tint: "transparent"
            property color c0: Theme.colOf("dark", "panelOutline")
            property color c1: Theme.colOf("dark", "slotDark")
            property color c2: Theme.colOf("dark", "panelShadow")
            property color c3: Theme.colOf("dark", "slot")
            property color c4: Theme.colOf("dark", "panel")
            property color c5: Theme.colOf("dark", "panelLight")
        }
        // corners
        Piece { clip: Qt.rect(0, 0, 9, 18);     x: 0; y: 0; width: 9 * root.g; height: 18 * root.g }
        Piece { clip: Qt.rect(243, 0, 9, 18);   x: root.width - 9 * root.g; y: 0; width: 9 * root.g; height: 18 * root.g }
        Piece { clip: Qt.rect(0, 131, 9, 9);    x: 0; y: root.height - 9 * root.g; width: 9 * root.g; height: 9 * root.g }
        Piece { clip: Qt.rect(243, 131, 9, 9);  x: root.width - 9 * root.g; y: root.height - 9 * root.g; width: 9 * root.g; height: 9 * root.g }
        // edges
        Piece { clip: Qt.rect(100, 0, 1, 18);   x: 9 * root.g; y: 0; width: root.width - 18 * root.g; height: 18 * root.g }
        Piece { clip: Qt.rect(100, 131, 1, 9);  x: 9 * root.g; y: root.height - 9 * root.g; width: root.width - 18 * root.g; height: 9 * root.g }
        Piece { clip: Qt.rect(0, 60, 9, 1);     x: 0; y: 18 * root.g; width: 9 * root.g; height: root.height - 27 * root.g }
        Piece { clip: Qt.rect(243, 60, 9, 1);   x: root.width - 9 * root.g; y: 18 * root.g; width: 9 * root.g; height: root.height - 27 * root.g }
    }
}
