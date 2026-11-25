import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services
import "CalendarPlace.js" as CalendarPlace

/*  CalendarEditor — the layer you type a new event on (namespace overworld-calendar), a full-screen overlay like the Notes editor with the keyboard
 *  grabbed (Exclusive), because the widget layer never takes focus.  The dim is light, and the panel opens right over the Clock & Calendar card;
 *  with the card hidden it opens in the middle of the screen.  CalendarService.addOpen drives it: a double-click on a day, the + of the agenda,
 *  IPC `calendar newEvent`.  The panel itself is Calendar/CalendarForm.qml.
 */
Variants {
    id: root
    model: Quickshell.screens
    property bool onlyFocusedScreen: true

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-calendar"
        onlyFocusedScreen: root.onlyFocusedScreen
        open: CalendarService.addOpen
        background: "none"                   // the light dim below instead of the menu gradient: the desk stays in view
        onCloseRequested: CalendarService.closeAdd()

        Rectangle { anchors.fill: parent; color: "#50101010" }   // alpha < hypr's ignore_alpha 0.35 for overworld-*: the world behind stays sharp

        readonly property var rect: CalendarService.cardRects[modelData.name] || null

        CalendarForm {
            readonly property var place: CalendarPlace.place(win.rect, parent.width, parent.height, width, height, Theme.gui, Theme.px(6))
            x: place.x; y: place.y
            active: win.shown
            onCloseAsked: CalendarService.closeAdd()
        }
    }
}
