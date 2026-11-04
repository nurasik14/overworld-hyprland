import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  CavaCard — 声 · CAVA (360 × 180).  24 ink bars with 2 px rounded tops, heights smoothed (120 ms);
 *  idle state (no audio / no cava) rests every bar at 2 px.  CavaService stops cava while the layer is hidden.
 */
WidgetCard {
    id: card
    title: "声"
    subtitle: "Cava"
    sealGlyph: "印"
    width: 360
    height: 180

    readonly property var svc: CavaService

    Item {
        id: strip
        anchors.fill: parent
        readonly property int n: card.svc.bars
        readonly property real gap: 4
        readonly property real barW: (width - gap * (n - 1)) / n
        readonly property real maxH: height - 14
        Repeater {
            model: strip.n
            delegate: Rectangle {
                required property int index
                readonly property real v: card.svc.values[index] || 0
                x: index * (strip.barW + strip.gap)
                width: strip.barW
                anchors.bottom: parent.bottom
                height: Math.max(2, strip.maxH * v / 100)
                radius: 2
                color: Theme.text
                opacity: card.svc.idle ? 0.35 : 0.9
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
            }
        }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.hairline; opacity: 0.6 }
        InkText {
            anchors.top: parent.top; anchors.right: parent.right
            role: "small"; muted: true
            visible: card.svc.idle
            text: card.svc.available ? "silence · 静" : "cava not running"
            opacity: 0.8
        }
    }
}
