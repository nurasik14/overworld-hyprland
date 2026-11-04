import QtQuick
import qs.Common

/*  McProgressBar — the XP bar and the boss bar, real hud/experience_bar_* and boss_bar/* sprites.
 *    kind: "xp"|"boss"       default "xp"
 *    value: real             0..1
 *    color: string           boss colour: pink, blue, red, green, yellow, purple, white; default "white"
 *    notches: int            boss overlay: 0, 6, 10, 12, 20; default 0
 *    title: string           boss: centred white text above the bar
 *    level: int              xp: the green outlined number centred above the bar; -1 hides it (default)
 *    animated: bool          value eases on change; default: boss only (the game's XP bar jumps, its boss bar lerps)
 *  Height: bar 5 GUI px, plus 10 for a title/level line. Default width 182 GUI px; other widths keep the end caps sharp.
 *
 *    McProgressBar { value: 0.42; level: 7 }
 *    McProgressBar { kind: "boss"; color: "purple"; notches: 10; title: "Brewing: essay"; value: 0.7 }
 */
Item {
    id: root
    property string kind: "xp"
    property real value: 0
    property string color: "white"
    property int notches: 0
    property string title: ""
    property int level: -1
    property bool animated: kind === "boss"
    readonly property bool isBoss: kind === "boss"
    readonly property bool hasLine: isBoss ? title.length > 0 : level >= 0
    readonly property var _edge: ({ type: "nine_slice", width: 182, height: 5, border: { left: 2, top: 0, right: 2, bottom: 0 } })
    readonly property string _bg: isBoss ? "boss_bar/" + color + "_background" : "hud/experience_bar_background"
    readonly property string _fg: isBoss ? "boss_bar/" + color + "_progress" : "hud/experience_bar_progress"
    property real _shown: Math.min(1, Math.max(0, value))
    Behavior on _shown { enabled: root.animated; NumberAnimation { duration: Theme.durBase; easing.type: Easing.Linear } }

    implicitWidth: Theme.px(182)
    implicitHeight: Theme.px(hasLine ? 15 : 5)

    McText {
        visible: root.isBoss && root.title.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, root.width)
        text: root.title
        color: Theme.hudText
        elide: Text.ElideRight
    }
    McOutlineText {
        visible: !root.isBoss && root.level >= 0
        anchors.horizontalCenter: parent.horizontalCenter
        text: String(root.level)
    }

    Item {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.px(5)
        McNineSlice {
            anchors.fill: parent
            sprite: root._bg
            scaling: root._edge
        }
        McNineSlice {   // notches are overlays: drawn over the colour, not instead of it
            visible: root.isBoss && root.notches > 0
            anchors.fill: parent
            sprite: root.isBoss && root.notches > 0 ? "boss_bar/notched_" + root.notches + "_background" : ""
            scaling: root._edge
        }
        Item {   // progress: the full sprite, revealed left to right in whole GUI pixels
            width: Math.round(root._shown * bar.width / Theme.gui) * Theme.gui
            height: parent.height
            clip: true
            McNineSlice {
                width: bar.width
                height: bar.height
                sprite: root._fg
                scaling: root._edge
            }
            McNineSlice {
                visible: root.isBoss && root.notches > 0
                width: bar.width
                height: bar.height
                sprite: root.notches > 0 ? "boss_bar/notched_" + root.notches + "_progress" : ""
                scaling: root._edge
            }
        }
    }
}
