import QtQuick
import qs.Common

/*  KeyedSprite — a sprite the game draws with additive blending (environment/celestial/sun, the moon phases): black means
 *  "nothing", so luminance becomes alpha (shaders/blackkey.frag).  Nearest sampling.  Size it like an Image.
 */
Item {
    id: root
    property url file
    Image { id: img; visible: false; source: root.file; smooth: false }
    ShaderEffect {
        anchors.fill: parent
        property variant source: img
        fragmentShader: Qt.resolvedUrl("shaders/blackkey.frag.qsb")
    }
}
