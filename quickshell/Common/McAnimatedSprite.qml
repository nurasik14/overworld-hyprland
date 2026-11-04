import QtQuick
import qs.Common

/*  McAnimatedSprite — strip-animated textures stepped on the shared 20 TPS clock, using their .mcmeta.
 *  Handles `frametime`, `frames` (plain indices or {index,time}) and `height`, like block/water_still, block/nether_portal,
 *  block/lava_still (ping-pong), block/fire_0 and GUI sprites with animation data.
 *    sprite: string     "block/water_still" (same path rules as McNineSlice)
 *    frameTime: int     ticks per frame, default from mcmeta (1 when absent)
 *    running: bool      default true; reducedMotion freezes on the first frame
 *    tint: color        multiply, e.g. Theme.water for the grey water strip
 *    columns, rows: int tile the frame to fill width/height; default 1×1 stretched to the item size
 *    scroll: bool       for non-strip textures like misc/enchanted_glint_item (mcmeta has no animation): slides the tile
 *    frame: int         current frame index (read)
 *  Size: explicit, else frame size × Theme.gui.
 *
 *    McAnimatedSprite { sprite: "block/water_still"; tint: Theme.water }
 *    McAnimatedSprite { sprite: "block/nether_portal"; width: Theme.px(32); height: Theme.px(32) }
 */
Item {
    id: root
    property string sprite: ""
    property bool running: true
    property color tint: "transparent"
    property int columns: 1
    property int rows: 1
    property bool scroll: false
    readonly property var anim: sprite.length ? Theme.spriteMeta(sprite).animation : null
    property int frameTime: anim && anim.frametime ? anim.frametime : 1
    readonly property url resolved: sprite.length ? Theme.tex(Theme.spritePath(sprite)) : ""

    readonly property int frameW: probe.implicitWidth
    readonly property int frameH: anim && anim.height ? anim.height : (scroll ? probe.implicitHeight : frameW)
    readonly property int frameCount: frameH > 0 ? Math.max(1, Math.floor(probe.implicitHeight / frameH)) : 1

    // Timeline: one entry per tick-long step, expanded once from mcmeta so a lookup per tick is a plain index.
    readonly property var timeline: {
        const out = [];
        const list = anim && anim.frames ? anim.frames : null;
        const n = list ? list.length : frameCount;
        for (let i = 0; i < n; i++) {
            const e = list ? list[i] : i;
            const index = typeof e === "number" ? e : e.index;
            const time = typeof e === "number" ? frameTime : (e.time || frameTime);
            for (let t = 0; t < time; t++) out.push(index);
        }
        return out.length ? out : [0];
    }
    McTicker { id: clock; active: (root.visible || root.layer.enabled) && root.running && !Theme.reducedMotion && (root.timeline.length > 1 || root.scroll) }
    readonly property int frame: scroll ? 0 : timeline[clock.tick % timeline.length]

    implicitWidth: Math.max(frameW, 1) * Theme.gui * columns
    implicitHeight: Math.max(frameH, 1) * Theme.gui * rows

    Image { id: probe; visible: false; source: root.resolved }

    Item {
        anchors.fill: parent
        clip: true
        layer.enabled: root.tint.a > 0
        layer.smooth: false
        layer.effect: ShaderEffect {
            fragmentShader: "file://" + Theme.commonDir + "/shaders/mcpalette.frag.qsb"
            property real mode: 0
            property color tint: root.tint
            property color c0: "black"; property color c1: "black"; property color c2: "black"
            property color c3: "black"; property color c4: "black"; property color c5: "black"
        }

        Image {   // scroll mode: the glint tile drifts diagonally, about one texture per 3 s
            visible: root.scroll
            source: root.scroll ? root.resolved : ""
            smooth: false
            fillMode: Image.Tile
            readonly property int tilePx: Math.max(root.frameW, 1)
            width: root.width + tilePx * 2
            height: root.height + tilePx * 2
            x: -(clock.tick * 2 % tilePx)
            y: -(clock.tick % tilePx)
        }

        Grid {
            visible: !root.scroll
            columns: root.columns
            rows: root.rows
            Repeater {
                model: root.scroll ? 0 : root.columns * root.rows
                Item {
                    width: root.width / root.columns
                    height: root.height / root.rows
                    clip: true
                    Image {
                        source: root.resolved
                        smooth: false
                        width: parent.width
                        height: root.frameH > 0 ? parent.height * root.frameCount : 0
                        y: -root.frame * parent.height
                    }
                }
            }
        }
    }
}
