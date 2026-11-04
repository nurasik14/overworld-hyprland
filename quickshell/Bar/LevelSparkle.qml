import QtQuick
import qs.Common

/*  LevelSparkle — glitter around the level number when a new uptime hour starts: particle/glitter_* sprites, stepped on the tick clock.
 *  Lasts 30 ticks. Does nothing under reduced motion.
 */
Item {
    id: root
    property int startTick: -1
    readonly property int age: playing ? ticker.tick - startTick : 0
    property bool playing: false
    function play() {
        if (Theme.reducedMotion) return;
        startTick = ticker.tick;
        playing = true;
    }
    width: 1; height: 1
    McTicker {
        id: ticker
        active: true
        onTicked: n => { if (root.playing && n - root.startTick > 30) root.playing = false; }
    }
    Repeater {
        model: root.playing && Theme.hasMojangAssets ? 8 : 0      // no fallback for these particles
        McSprite {
            required property int index
            readonly property real angle: index / 8 * Math.PI * 2
            readonly property real reach: Theme.px(6 + root.age * 0.8)
            readonly property int frame: Math.min(7, Math.floor(root.age / 4))
            sprite: "particle/glitter_" + frame
            scaling: ({ type: "stretch", width: 8, height: 8 })
            x: Math.round(Math.cos(angle) * reach / Theme.gui) * Theme.gui
            y: Math.round(Math.sin(angle) * reach * 0.6 / Theme.gui) * Theme.gui
            tint: Theme.xp
        }
    }
}
