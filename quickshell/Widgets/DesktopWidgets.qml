import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets.Services

/*  DesktopWidgets — the desktop widget layer: eight Minecraft objects on the wallpaper (one PanelWindow per screen,
 *  layer `bottom`, namespace overworld-widgets).
 *
 *  Layout (WidgetLayout; numbers for 1920 × 1080 at GUI scale 2 — the bar is 0–36, the bottom-centre ~110 px stay free for the HUD):
 *    left column,  x 24:        Weather 60 · Jukebox 372 · Brewing stand 596 · Block of the day 776   (ends at y 1052)
 *    right column, flush right: Clock & Calendar 60 · System (F3) 384 · Note block 692 · Sign 868  (ends at y 1024)
 *  The slots are stacks in GUI px, so they follow the GUI scale and the screen width.
 *  Click-through: `mask` = union of the visible card rectangles, so the desktop receives everything else.
 *  Visibility: WidgetsState.visible (IPC `widgets toggle|reveal|hide`) and the per-card switches; each card staggers 40 ms.
 *  Moving: drag a card by its title bar (while dragging the whole layer takes input so a fast flick cannot lose the card);
 *  positions persist in ~/.config/overworld/widget-positions.json, double-click the title bar or IPC `widgets layout`
 *  puts every card back on its slot.
 */
Variants {
    id: root
    model: Quickshell.screens
    readonly property bool widgetsVisible: WidgetsState.visible   // kept for shell.qml compatibility

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        // OW_WIDGETS_LAYER=top is for preview screenshots only (other agents' test windows would cover a bottom layer)
        WlrLayershell.layer: Quickshell.env("OW_WIDGETS_LAYER") === "top" ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.namespace: "overworld-widgets"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        readonly property bool shown: WidgetsState.visible

        // while a card is dragged the whole layer takes input, so a fast flick can't outrun the card's region
        Item { id: dragCatcher; anchors.fill: parent }
        WidgetLayout { id: layout; anchors.fill: parent }
        mask: Region {
            Region { item: WidgetsState.dragging ? dragCatcher : null }
            Region { item: win.shown && layout.weather.shown ? layout.weather : null }
            Region { item: win.shown && layout.music.shown ? layout.music : null }
            Region { item: win.shown && layout.calendar.shown ? layout.calendar : null }
            Region { item: win.shown && layout.sysinfo.shown ? layout.sysinfo : null }
            Region { item: win.shown && layout.quote.shown ? layout.quote : null }
            Region { item: win.shown && layout.block.shown ? layout.block : null }
            Region { item: win.shown && layout.brew.shown ? layout.brew : null }
            Region { item: win.shown && layout.cava.shown ? layout.cava : null }
        }
    }
}
