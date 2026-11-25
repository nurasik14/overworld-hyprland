import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Projects
import qs.Widgets.Services

/*  NotesCard — "Notes" (160 × 204 GUI px): the open page of Minecraft's Book and Quill, one note per page.  The page is gui/book.png at the GUI
 *  scale (BookPage.qml), the note is written on it in the game's black Mojangles inside the game's 114-texel text box (12 lines of the shell's 10-texel pitch; a longer note
 *  ends in "…" here and scrolls in the editor), "Page 2 of 5" top right, the real page-turn arrows at the bottom (hover = the highlighted sprite;
 *  the wheel over the card flips too).  Click the page to write (NotesEditor: the same page, bigger, on a layer that takes the keyboard, because
 *  this widget layer never does).  Hover: ✕ tears the page out (paper crumbs, "Undo" for 5 s).  Between the arrows: + for a new page.  Empty:
 *  an empty page with a hint; it never invents notes.  Every other way in (chat /note, `hypr-notes`, `overworld notes`, IPC target notes): NotesService.
 *  The Projects card is a Book and Quill too, but as a closed item with a list; this one is the open page you write on.
 */
WidgetCard {
    id: card
    title: "Notes"
    guiW: 160
    guiH: 204

    property string screenName: ""             // WidgetLayout: which output's rectangle this card publishes
    property bool pinHover: false              // previews only: draw the ✕ as if hovered
    property bool pinArrow: false              // previews only: draw the ▶ arrow as if hovered
    readonly property var svc: NotesService
    readonly property var note: svc.current
    readonly property bool hot: hoverer.hovered || pinHover
    // when it was last touched, short enough to sit left of "Page 12 of 12": now · 5 min · 3 h · 2 d
    readonly property string age: {
        const t = note ? Date.parse(note.updated || "") : NaN;
        if (isNaN(t)) return "";
        const min = Math.floor((svc.nowTick - t) / 60000);
        return min < 1 ? "just now" : min < 60 ? min + " min" : min < 1440 ? Math.floor(min / 60) + " h" : Math.floor(min / 1440) + " d";
    }
    readonly property alias page: page
    readonly property alias bookItem: page

    function tearOff() {
        if (!note) return;
        Theme.playSound("book.page");
        svc.remove(note.id);
    }
    function flipBy(delta) {
        if (svc.flip(delta)) Theme.playSound("book.page");
    }
    function openSheet() { svc.openEditor("current"); }
    function newSheet() { svc.openEditor("new"); }
    property real wheelRest: 0
    function wheelBy(dy) {                     // a notch is 120; a touchpad's small steps add up to one
        wheelRest += dy;
        if (Math.abs(wheelRest) < 120) return;
        const d = wheelRest > 0 ? -1 : 1;
        wheelRest = 0;
        flipBy(d);
    }

    // where the page is on the output: the editor opens right over it
    readonly property var paperRect: ({ x: card.x + page.x + Theme.px(7), y: card.y + page.y + Theme.px(17), w: page.width, h: page.height, shown: card.shown })
    onPaperRectChanged: svc.setCardRect(screenName, paperRect)
    onScreenNameChanged: svc.setCardRect(screenName, paperRect)

    HoverHandler { id: hoverer }
    MouseArea {                                // the wheel anywhere on the card flips; clicks go to what is on top of it
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => card.wheelBy(wheel.angleDelta.y)
    }

    // ---- the page
    BookPage {
        id: page
        u: Theme.gui
        MouseArea {                            // a click anywhere on the page writes
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: card.openSheet()
            Accessible.role: Accessible.Button
            Accessible.name: card.note ? "Edit this note" : "Write a note"
        }
        // the note, in the game's text box
        Item {
            id: box
            x: page.bx(16); y: page.bx(29)
            width: page.bx(114); height: page.bx(120)
            clip: true
            McText {
                visible: card.note !== null
                width: parent.width
                height: parent.height
                text: card.note ? card.note.text : ""
                color: page.ink
                shadow: false
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 12
                elide: Text.ElideRight
            }
            McText {
                visible: card.note === null
                width: parent.width
                text: "Click to write a note…"
                color: page.inkMuted
                shadow: false
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
        // "Page 2 of 5", right edge at the game's x
        McText {
            visible: card.svc.count > 0
            x: page.bx(128) - width; y: page.bx(15)
            text: "Page " + (card.svc.currentIndex + 1) + " of " + card.svc.count
            color: page.ink
            shadow: false
        }
        // when it was last touched, top left (the ✕ takes its place while the page is hovered)
        McText {
            visible: card.svc.count > 0 && !(card.hot && card.note !== null)
            x: page.bx(16); y: page.bx(15)
            width: page.bx(40)
            text: card.age
            color: page.inkMuted
            shadow: false
            elide: Text.ElideRight
        }
        // ✕ on hover: tear the page out
        Item {
            visible: card.hot && card.note !== null
            x: page.bx(14); y: page.bx(13)
            width: page.bx(11); height: page.bx(11)
            Rectangle {
                anchors.fill: parent
                color: tearArea.containsMouse ? "#C62B2B" : "transparent"
            }
            PixelGlyph {
                anchors.centerIn: parent
                kind: "cross"
                color: tearArea.containsMouse ? "#FFFFFF" : "#6B2B22"
            }
            MouseArea {
                id: tearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.tearOff()
                Accessible.role: Accessible.Button
                Accessible.name: "Tear out this page"
            }
        }
        // the page-turn arrows (hidden at the ends, like the game's), with + for a new page between them
        BookArrow {
            visible: card.svc.currentIndex > 0
            x: page.bx(23); y: page.bx(156)
            u: page.u
            forward: false
            onClicked: card.flipBy(-1)
        }
        BookArrow {
            id: fwd
            visible: card.svc.count > 0 && card.svc.currentIndex < card.svc.count - 1
            x: page.bx(96); y: page.bx(156)
            u: page.u
            forward: true
            pinned: card.pinArrow
            onClicked: card.flipBy(1)
        }
        BookButton {
            x: page.bx(60); y: page.bx(156)
            width: page.bx(26); height: page.bx(13)
            u: page.u
            text: "+"
            tooltip: "New page"
            tooltipDescription: "SUPER+ALT+N, or /note <text> in the chat"
            onClicked: card.newSheet()
        }
        PaperCrumbs {
            id: crumbs
            anchors.fill: parent
            z: 20
            colorA: "#FFFAEE"
            colorB: "#E2CF9E"
            colorC: "#7B4A2B"
        }
        // undo bar (5 s after a tear-out), over the arrow row
        Rectangle {
            visible: card.svc.undo !== null
            x: page.bx(15); y: page.bx(154)
            width: page.bx(116); height: page.bx(17)
            color: "#F0201810"
            border.width: Theme.gui; border.color: "#000000"
            MouseArea { anchors.fill: parent }     // clicks on the bar don't reach the arrows under it
            McText {
                x: page.bx(4); y: 0
                width: parent.width - page.bx(4 + 34)
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: card.svc.undo ? (card.svc.undo.count > 1 ? "Tore out " + card.svc.undo.count + " pages" : "Tore out " + (card.svc.undo.preview || "a page")) : ""
                color: "#ffffff"
                elide: Text.ElideRight
            }
            BookButton {
                x: parent.width - page.bx(33); y: page.bx(2)
                width: page.bx(32); height: page.bx(13)
                u: page.u
                text: "Undo"
                onClicked: card.svc.undoRemove()
            }
        }
    }
    Connections {
        target: card.svc
        function onSheetTorn() { if (card.shown) crumbs.burst(); }
    }
}
