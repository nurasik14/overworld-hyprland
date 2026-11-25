import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services
import "NotesPlace.js" as NotesPlace

/*  NotesEditor — the layer you type on (namespace overworld-notes), a full-screen overlay like the brew dialog with the keyboard grabbed
 *  (Exclusive), because the widget layer never takes focus.  The dim is light and the book page opens exactly over the card's
 *  page, one scale step larger, so it feels like writing on the note itself; with the card hidden it opens in the middle of the screen.
 *  Opened by a click on the card, its +, SUPER+ALT+N, /note, `ipc call notes open|newSheet`; NotesService.editorOpen drives it.
 *  The book screen itself is Notes/NotesForm.qml.
 */
Variants {
    id: root
    model: Quickshell.screens
    property bool onlyFocusedScreen: true
    Component.onDestruction: NotesService.flushNow()     // a shell reload or quit: nothing typed is lost (see NotesService)

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-notes"
        onlyFocusedScreen: root.onlyFocusedScreen
        open: NotesService.editorOpen
        background: "none"                   // the light dim below instead of the menu gradient: the desk stays in view
        onCloseRequested: NotesService.closeEditor()

        Rectangle { anchors.fill: parent; color: "#50101010" }   // alpha < hypr's ignore_alpha 0.35 for overworld-*: the world behind stays sharp

        readonly property var rect: NotesService.cardRects[modelData.name] || null

        NotesForm {
            // the book one step bigger than on the card, as far as book and buttons still fit this output
            u: Math.max(Theme.gui, Math.min(Theme.gui + 1, Math.floor((parent.height - Theme.px(8)) / unitsH)))
            readonly property var place: NotesPlace.place(win.rect, parent.width, parent.height, width, height, Theme.gui, Theme.px(6))
            x: place.x; y: place.y
            active: win.shown
            onCloseAsked: NotesService.closeEditor()
        }
    }
}
