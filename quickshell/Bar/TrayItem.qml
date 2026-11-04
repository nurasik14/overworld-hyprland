import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Common
import qs.Services

/*  TrayItem — one StatusNotifierItem in a slot: left click activate, middle secondaryActivate, right = native menu, wheel scroll. */
HudSlot {
    id: root
    required property SystemTrayItem modelData
    iconSource: modelData.icon
    tooltip: modelData.tooltipTitle.length ? modelData.tooltipTitle : (modelData.title || modelData.id)
    tooltipCategory: "Tray"
    soundId: ""

    QsMenuAnchor {
        id: menuAnchor
        menu: root.modelData.menu
        anchor.item: root
        anchor.window: root.QsWindow.window
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.bottom: Theme.gui
    }
    onClicked: {
        if (modelData.onlyMenu && modelData.hasMenu) menuAnchor.open();
        else modelData.activate();
    }
    onRightClicked: if (modelData.hasMenu) menuAnchor.open()
    onMiddleClicked: modelData.secondaryActivate()
    onWheelMoved: d => modelData.scroll(d * 120, false)
}
