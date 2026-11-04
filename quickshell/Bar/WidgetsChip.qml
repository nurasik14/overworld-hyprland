import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.Services

// Desktop widgets: click = the menu (each card + reset), middle-click = all on/off.
HudSlot {
    id: chip
    item: "item_frame"
    opacity: WidgetsState.visible ? 1 : 0.55
    highlighted: WidgetsState.menuOpen
    tooltip: WidgetsState.menuOpen ? "" : "Item Frame"
    tooltipDescription: "Desk widgets " + (WidgetsState.visible ? "shown" : "hidden") + "\nClick: choose cards\nMiddle-click, Super+G: all"
    tooltipCategory: "Widgets"
    onClicked: WidgetsState.menuOpen = !WidgetsState.menuOpen
    onMiddleClicked: WidgetsState.toggle()
    WidgetsMenu { target: chip }
}
