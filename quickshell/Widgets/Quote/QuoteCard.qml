import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  QuoteCard — an oak sign with a message and the title screen's splash on its corner (190 × 78 GUI px).
 *  The board is the real sign texture (entity/signs/oak, the 24 × 12 front face tiled at 1 texel = 1 GUI px) with black
 *  sign lettering; the yellow splash pulses at the top-right corner like on the title screen.  Message =
 *  quotes/quotes.json, splash = quotes/splashes.json (seasonal lines in season) plus Mojang's own list when
 *  assets/mc/texts/splashes.txt exists (read at runtime, never copied) — see QuoteService.  Click the sign for the next
 *  one; both rotate every 10 minutes.
 */
WidgetCard {
    id: card
    title: "Sign"
    guiW: 190
    guiH: 78

    readonly property var svc: QuoteService
    readonly property bool hasAttr: svc.attribution.length > 0

    Item {
        id: board
        width: Theme.px(176); height: Theme.px(54)
        clip: true
        Rectangle { anchors.fill: parent; color: "#6B4F2A" }
        Grid {   // the sign's front face, repeated
            visible: Theme.tex("entity/signs/oak") !== Theme.missingTexture
            columns: Math.ceil(board.width / Theme.px(24))
            Repeater {
                model: Math.ceil(board.width / Theme.px(24)) * Math.ceil(board.height / Theme.px(12))
                Image {
                    width: Theme.px(24); height: Theme.px(12)
                    source: Theme.tex("entity/signs/oak")
                    sourceClipRect: Qt.rect(2, 2, 24, 12)
                    smooth: false
                }
            }
        }
        // 1 GUI px dark edge, like the sign's side faces
        Rectangle { width: parent.width; height: Theme.gui; color: "#5A4220" }
        Rectangle { y: parent.height - Theme.gui; width: parent.width; height: Theme.gui; color: "#5A4220" }
        Rectangle { width: Theme.gui; height: parent.height; color: "#5A4220" }
        Rectangle { x: parent.width - Theme.gui; width: Theme.gui; height: parent.height; color: "#5A4220" }

        Column {
            anchors.centerIn: parent
            width: Theme.px(160)
            spacing: Theme.px(2)
            McText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.svc.text
                color: "#000000"
                shadow: false
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            McText {
                visible: card.hasAttr
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: "— " + card.svc.attribution
                color: "#3B2A10"
                shadow: false
                elide: Text.ElideLeft
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.svc.next()
            Accessible.role: Accessible.Button
            Accessible.name: "Next message"
        }
    }

    // the splash pulses on the card's top-right corner; the game's formula makes its drawn width 180·w/(w+32) GUI px
    // for a text w GUI px wide, so keep its right end inside the card
    McText { id: splashMeasure; visible: false; text: card.svc.splash }
    McSplash {
        parent: card
        readonly property real w: splashMeasure.implicitWidth / Theme.gui
        readonly property real shown: 180 * w / (w + 32) * units          // GUI px
        units: 0.75
        x: card.width - Theme.px(shown / 2 * 0.94 + 6)
        y: Theme.px(8)
        z: 150
        text: card.svc.splash
    }
}
