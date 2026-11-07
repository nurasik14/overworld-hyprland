import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Projects
import qs.Widgets.Services

/*  NotesCard — "Notes" (190 × 130 GUI px): a pad of Paper sheets pinned to the desk, for raw, stray thoughts.  No titles, no structure.
 *  The sheet shows the current note (wrapped, fading out at the bottom when long); click it to write (NotesEditor, the same sheet
 *  on a layer that takes the keyboard, because this widget layer never does).  Footer: ◀ 2/5 ▶ (also the mouse wheel over the card), when it was
 *  last touched, + for a new sheet.  Hover the sheet: ✕ tears it off, with crumbs and "Undo" for 5 s.  Empty: "Click to scribble
 *  a thought…"; it never invents notes.  Every other way in (chat /note, `hypr-notes`, `overworld notes`, IPC target notes): NotesService.
 */
WidgetCard {
    id: card
    title: "Notes"
    guiW: 190
    guiH: 130

    property string screenName: ""             // WidgetLayout: which output's rectangle this card publishes
    property bool pinHover: false              // previews only: draw the ✕ as if hovered
    readonly property var svc: NotesService
    readonly property var note: svc.current
    readonly property bool hot: hoverer.hovered || pinHover
    readonly property string age: note ? svc.relTime(note.updated, svc.nowTick) : ""

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

    // where the paper is on the output: the editor opens right over it
    readonly property var paperRect: ({ x: card.x + paper.x + Theme.px(7), y: card.y + paper.y + Theme.px(17), w: paper.width, h: paper.height, shown: card.shown })
    onPaperRectChanged: svc.setCardRect(screenName, paperRect)
    onScreenNameChanged: svc.setCardRect(screenName, paperRect)

    HoverHandler { id: hoverer }
    MouseArea {                                // the wheel anywhere on the card flips; clicks go to what is on top of it
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => card.wheelBy(wheel.angleDelta.y)
    }

    // ---- the sheet
    PaperSheet {
        id: paper
        width: Theme.px(172); height: Theme.px(86)
        fillAlpha: Math.max(0.9, WidgetsState.cardOpacity)
        behind: Math.min(2, Math.max(0, card.svc.count - 1))
        seed: card.note ? (card.note.id.charCodeAt(card.note.id.length - 1) + card.note.id.charCodeAt(card.note.id.length - 2) * 31) : 7

        Item {
            id: writing
            x: Theme.px(6); y: Theme.px(6)
            width: parent.width - Theme.px(12)
            height: parent.height - Theme.px(6 + paper.fold + 1)
            clip: true
            readonly property bool overflows: card.note !== null && body.contentHeight > height
            readonly property var bands: [0.7, 0.45, 0.25, 0.1]
            Item {
                id: bodyClip
                width: parent.width
                height: parent.height - (writing.overflows ? writing.bands.length * Theme.px(3) : 0)
                clip: true
                McText {
                    id: body
                    visible: card.note !== null
                    width: writing.width
                    text: card.note ? card.note.text : ""
                    color: paper.ink
                    shadow: false
                    wrapMode: Text.Wrap
                }
            }
            // a long note fades out in chunky steps: the same text again, in strips of falling opacity (nothing is laid over the paper)
            Repeater {
                model: writing.overflows ? writing.bands : []
                Item {
                    required property real modelData
                    required property int index
                    y: bodyClip.height + index * height
                    width: writing.width; height: Theme.px(3)
                    clip: true
                    opacity: modelData
                    McText {
                        y: -parent.y
                        width: writing.width
                        text: body.text
                        color: paper.ink
                        shadow: false
                        wrapMode: Text.Wrap
                    }
                }
            }
            McText {
                visible: card.note === null
                width: parent.width; height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                text: "Click to scribble a thought…"
                color: paper.inkMuted
                shadow: false
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: card.openSheet()
            Accessible.role: Accessible.Button
            Accessible.name: card.note ? "Edit this note" : "Write a note"
        }
        // ✕ on hover: tear the sheet off
        Item {
            visible: card.hot && card.note !== null
            x: parent.width - Theme.px(12); y: Theme.px(3)
            width: Theme.px(10); height: Theme.px(10)
            Rectangle {
                anchors.fill: parent
                color: tearArea.containsMouse ? "#C62B2B" : "transparent"
            }
            PixelGlyph {
                anchors.centerIn: parent
                kind: "cross"
                color: tearArea.containsMouse ? "#FFFFFF" : paper.outline
            }
            MouseArea {
                id: tearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.tearOff()
                Accessible.role: Accessible.Button
                Accessible.name: "Tear off this note"
            }
        }
        PaperCrumbs {
            id: crumbs
            anchors.fill: parent
            z: 20
            colorA: paper.face
            colorB: paper.edge
        }
    }
    Connections {
        target: card.svc
        function onSheetTorn() { if (card.shown) crumbs.burst(); }
    }

    // ---- the footer: ◀ 2/5 ▶  3 min ago  +
    Item {
        x: 0; y: Theme.px(92)
        width: Theme.px(176); height: Theme.px(14)
        McButton {
            id: prevB
            visible: card.svc.count > 1
            x: 0; width: Theme.px(14); height: parent.height
            horizontalPadding: 0
            enabled: card.svc.currentIndex > 0
            soundId: ""
            activeFocusOnTab: false
            onClicked: card.flipBy(-1)
            PixelGlyph { anchors.centerIn: parent; kind: "left"; color: prevB.labelColor }
        }
        McText {
            id: pager
            visible: card.svc.count > 0
            x: card.svc.count > 1 ? Theme.px(16) : 0
            width: Theme.px(card.svc.count > 1 ? 26 : 24); height: parent.height
            horizontalAlignment: card.svc.count > 1 ? Text.AlignHCenter : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            text: (card.svc.currentIndex + 1) + "/" + card.svc.count
            color: Theme.guiText
        }
        McButton {
            id: nextB
            visible: card.svc.count > 1
            x: Theme.px(44); width: Theme.px(14); height: parent.height
            horizontalPadding: 0
            enabled: card.svc.currentIndex < card.svc.count - 1
            soundId: ""
            activeFocusOnTab: false
            onClicked: card.flipBy(1)
            PixelGlyph { anchors.centerIn: parent; kind: "right"; color: nextB.labelColor }
        }
        McText {
            x: Theme.px(card.svc.count > 1 ? 62 : 26)
            width: Theme.px(162) - x - Theme.px(2); height: parent.height
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: card.age
            color: Theme.textMuted
            elide: Text.ElideRight
        }
        McButton {
            x: Theme.px(162); width: Theme.px(14); height: parent.height
            horizontalPadding: 0
            text: "+"
            tooltip: "New sheet"
            tooltipDescription: "SUPER+ALT+N, or /note <text> in the chat"
            activeFocusOnTab: false
            onClicked: card.newSheet()
        }
    }

    // ---- undo bar (5 s after a tear-off)
    Rectangle {
        visible: card.svc.undo !== null
        x: 0; y: Theme.px(91)
        width: Theme.px(176); height: Theme.px(15)
        color: Theme.isDark ? "#e0101010" : "#f0373737"
        border.width: Theme.gui; border.color: "#000000"
        MouseArea { anchors.fill: parent }     // clicks on the bar don't reach the pager under it
        McText {
            x: Theme.px(4); y: 0
            width: parent.width - Theme.px(4 + 34)
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: card.svc.undo ? (card.svc.undo.count > 1 ? "Tore off " + card.svc.undo.count + " notes" : "Tore off " + (card.svc.undo.preview || "a note")) : ""
            color: "#ffffff"
            elide: Text.ElideRight
        }
        McButton {
            x: parent.width - Theme.px(33); y: Theme.px(1)
            width: Theme.px(32); height: Theme.px(13)
            horizontalPadding: 0
            text: "Undo"
            activeFocusOnTab: false
            onClicked: card.svc.undoRemove()
        }
    }
}
