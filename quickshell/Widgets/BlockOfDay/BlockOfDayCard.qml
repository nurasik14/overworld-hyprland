import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  BlockOfDayCard — Block / Item / Mob / Biome of the day in an item frame (190 × 138 GUI px).
 *  BlockOfDayService picks quotes/blocks-of-the-day.json entries[dayOfYear % n]: the texture in the frame (mobs show their
 *  spawn egg), the name, the kind and the version it first appeared in, then the facts one at a time (they rotate every
 *  12 s, "1/3") and the tip.  Left click → next entry, right click → previous (the date's pick comes back after a restart).
 */
WidgetCard {
    id: card
    title: "Block of the Day"
    guiW: 190
    guiH: 138

    readonly property var svc: BlockOfDayService
    property int factIndex: 0
    readonly property int factCount: svc.facts.length
    readonly property string fact: factCount ? svc.facts[factIndex % factCount] : ""
    Connections { target: card.svc; function onIndexChanged() { card.factIndex = 0 } }
    Timer { interval: 12000; running: card.visible && card.factCount > 1; repeat: true; onTriggered: card.factIndex = (card.factIndex + 1) % card.factCount }

    // ---- item frame: dark outline, tan wooden border, the frame's back with the texture on it
    Item {
        id: frame
        width: Theme.px(46); height: Theme.px(46)
        Rectangle { anchors.fill: parent; color: "#5B3F22" }
        Rectangle { x: Theme.gui; y: Theme.gui; width: parent.width - Theme.px(2); height: parent.height - Theme.px(2); color: "#C8B07A" }   // fallback tan
        Image {
            x: Theme.gui; y: Theme.gui; width: parent.width - Theme.px(2); height: parent.height - Theme.px(2)
            source: Theme.tex("block/birch_planks"); fillMode: Image.Tile; smooth: false
            visible: source.toString() !== Theme.missingTexture
        }
        Rectangle { x: Theme.px(3); y: Theme.px(3); width: Theme.px(40); height: Theme.px(40); color: "#7A4A2A" }
        Image {
            x: Theme.px(3); y: Theme.px(3); width: Theme.px(40); height: Theme.px(40)
            source: Theme.tex("block/item_frame"); fillMode: Image.Tile; smooth: false
            visible: source.toString() !== Theme.missingTexture
        }
        Image {   // the entry's texture: first animation frame (square crop), 2 GUI px per texel
            id: tex
            x: Theme.px(7); y: Theme.px(7); width: Theme.px(32); height: Theme.px(32)
            source: Theme.tex(card.svc.textureName)
            sourceClipRect: Qt.rect(0, 0, implicitWidth, Math.min(implicitWidth, implicitHeight))
            smooth: false
            fillMode: Image.PreserveAspectFit
        }
        Rectangle { x: Theme.px(3); y: Theme.px(3); width: Theme.px(40); height: Theme.gui; color: "#40000000" }
    }

    // ---- name, kind, since
    McText {
        x: Theme.px(52); y: Theme.px(2); width: Theme.px(124)
        text: card.svc.name
        color: Theme.guiText
        elide: Text.ElideRight
    }
    McText {
        x: Theme.px(52); y: Theme.px(14); width: Theme.px(124)
        text: card.svc.kindLabel
        color: Theme.chatReadable(card.svc.kind === "mob" ? "c" : card.svc.kind === "item" ? "b" : card.svc.kind === "biome" ? "a" : "e")
        elide: Text.ElideRight
    }
    McText {
        x: Theme.px(52); y: Theme.px(26); width: Theme.px(124)
        text: card.svc.since.length ? "Since " + card.svc.since : ""
        color: Theme.textMuted
        elide: Text.ElideRight
    }
    McText {
        x: Theme.px(52); y: Theme.px(36); width: Theme.px(124)
        text: card.factCount > 1 ? "Fact " + (card.factIndex + 1) + "/" + card.factCount : ""
        color: Theme.textMuted
        horizontalAlignment: Text.AlignRight
    }

    // ---- fact + tip
    McText {
        y: Theme.px(50); width: Theme.px(176); height: Theme.px(30)
        text: card.fact
        color: Theme.guiText
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
    McText {
        y: Theme.px(82); width: Theme.px(176); height: Theme.px(30)
        text: card.svc.tip.length ? "Tip: " + card.svc.tip : ""
        color: Theme.chatReadable("a")
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => { if (mouse.button === Qt.RightButton) card.svc.previous(); else card.svc.next() }
        Accessible.role: Accessible.Button
        Accessible.name: "Next block of the day"
    }
}
