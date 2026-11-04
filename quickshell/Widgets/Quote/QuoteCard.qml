import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  QuoteCard — 言 · QUOTE (460 × 120).  EB Garamond italic, attribution right-aligned (may be empty),
 *  optional CJK original above the English.  Click → next quote (QuoteService also rotates every 10 min).
 */
WidgetCard {
    id: card
    title: "言"
    subtitle: "Quote"
    sealGlyph: "印"
    width: 460
    height: 120
    padding: 12

    readonly property var svc: QuoteService
    readonly property bool hasCjk: svc.cjk.length > 0
    readonly property bool hasAttr: svc.attribution.length > 0

    Column {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        InkText {
            visible: card.hasCjk
            role: "body"
            font.pixelSize: 13
            muted: true
            text: card.svc.cjk
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            text: "“" + card.svc.text + "”"
            color: Theme.text
            font.family: Theme.fontSerifBody
            font.italic: true
            font.pixelSize: card.svc.text.length > 110 ? 15 : (card.svc.text.length > 70 || card.hasCjk ? 16 : 18)
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: card.hasCjk ? 2 : 3
            elide: Text.ElideRight
            lineHeight: 1.15
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: Theme.durTheme } }
        }
        InkText {
            visible: card.hasAttr
            role: "small"
            muted: true
            text: "— " + card.svc.attribution
            width: parent.width
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.svc.next()
        Accessible.role: Accessible.Button
        Accessible.name: "Next quote"
    }
}
