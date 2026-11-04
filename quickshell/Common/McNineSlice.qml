import QtQuick
import qs.Common

/*  McNineSlice — draws any GUI sprite pixel-perfect using its .mcmeta `gui.scaling` (nine_slice | tile | stretch).
 *    sprite: string      "widget/button" (rooted at gui/sprites) or "gui/menu_background", "block/stone"…
 *    source: url         explicit image URL instead of `sprite` (skips mcmeta unless `scaling` is given)
 *    scaling: var        override mcmeta: { type:"nine_slice", width, height, border: n | {left,top,right,bottom}, stretch_inner }
 *    scaleFactor: int    source pixels → screen pixels; default Theme.gui
 *    tint: color         multiply the sprite by this colour (recolor: true is implied; default transparent = off)
 *    nightRemap: bool    swap the Java GUI greys for the Night palette (tabs, grey sprites on Night panels)
 *    readonly meta       the Theme.spriteMeta() result
 *  Size: explicit, else the sprite's natural size × scaleFactor. Corners and edges stay at exact source pixels.
 *
 *    McNineSlice { sprite: "widget/button"; width: Theme.px(150); height: Theme.px(20) }
 */
Item {
    id: root
    property string sprite: ""
    property url source: ""
    property var scaling: null
    property int scaleFactor: Theme.gui
    property color tint: "transparent"
    property bool nightRemap: false

    readonly property var meta: sprite.length ? Theme.spriteMeta(sprite) : ({ scaling: Theme._normScaling(null), animation: null })
    readonly property var scale9: scaling ? Theme._normScaling(scaling) : meta.scaling
    readonly property url resolved: sprite.length ? Theme.tex(Theme.spritePath(sprite)) : source
    readonly property bool recolored: nightRemap || tint.a > 0
    readonly property bool isNine: scale9.type === "nine_slice"
    readonly property bool isTile: scale9.type === "tile"

    implicitWidth: (scale9.width > 0 ? scale9.width : natural.implicitWidth) * scaleFactor
    implicitHeight: (scale9.height > 0 ? scale9.height : natural.implicitHeight) * scaleFactor

    Image {   // only measures the natural size when the sprite has no mcmeta dimensions
        id: natural
        visible: false
        source: root.scale9.width > 0 && root.scale9.height > 0 ? "" : root.resolved
    }

    Item {
        id: canvas
        anchors.fill: parent
        layer.enabled: root.recolored
        layer.smooth: false
        layer.effect: ShaderEffect {
            fragmentShader: "file://" + Theme.commonDir + "/shaders/mcpalette.frag.qsb"
            property real mode: root.nightRemap ? 1 : 0
            property color tint: root.tint
            property color c0: Theme.colOf("dark", "panelOutline")
            property color c1: Theme.colOf("dark", "slotDark")
            property color c2: Theme.colOf("dark", "panelShadow")
            property color c3: Theme.colOf("dark", "slot")
            property color c4: Theme.colOf("dark", "panel")
            property color c5: Theme.colOf("dark", "panelLight")
        }

        // The sprite is drawn at source resolution and scaled by an integer, so every texel stays a crisp square.
        BorderImage {
            visible: root.isNine
            source: root.isNine ? root.resolved : ""
            transformOrigin: Item.TopLeft
            scale: root.scaleFactor
            smooth: false
            width: Math.ceil(root.width / root.scaleFactor)
            height: Math.ceil(root.height / root.scaleFactor)
            // the game clamps each border to half the drawn size, so a sprite can be drawn smaller than its borders
            border.left: Math.min(root.scale9.border.left, Math.floor(width / 2))
            border.top: Math.min(root.scale9.border.top, Math.floor(height / 2))
            border.right: Math.min(root.scale9.border.right, Math.floor(width / 2))
            border.bottom: Math.min(root.scale9.border.bottom, Math.floor(height / 2))
            horizontalTileMode: root.scale9.stretchInner ? BorderImage.Stretch : BorderImage.Repeat
            verticalTileMode: root.scale9.stretchInner ? BorderImage.Stretch : BorderImage.Repeat
        }
        Image {
            visible: !root.isNine
            source: !root.isNine ? root.resolved : ""
            transformOrigin: Item.TopLeft
            scale: root.scaleFactor
            smooth: false
            width: Math.ceil(root.width / root.scaleFactor)
            height: Math.ceil(root.height / root.scaleFactor)
            fillMode: root.isTile ? Image.Tile : Image.Stretch
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignTop
        }
    }
}
