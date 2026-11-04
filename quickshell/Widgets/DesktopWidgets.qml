import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets.Services
import qs.Widgets.Weather
import qs.Widgets.Music
import qs.Widgets.Calendar
import qs.Widgets.SysInfo
import qs.Widgets.Quote
import qs.Widgets.HerbOfDay
import qs.Widgets.BrewTimer
import qs.Widgets.Cava

/*  DesktopWidgets — the desktop widget layer (one PanelWindow per screen, layer `bottom`).
 *
 *  Cards sit at the exact 1920×1080 slots of docs/DESIGN.md §7 (absolute screen coordinates; the window
 *  covers the whole output with exclusionMode Ignore, so y = 60 is "bar 36 + margin 24").  Right/bottom
 *  anchored slots are re-based on other resolutions (x = width − (1920 − x)).
 *  Click-through: `mask` = union of the visible card rectangles, so the desktop receives everything else.
 *  Visibility: WidgetsState.visible (IPC `widgets toggle|show|hide`), each card staggers 40 ms (WidgetCard).
 *  Moving: drag a card by its title bar; positions persist in ~/.config/overworld/widget-positions.json,
 *  `defaultX/defaultY` are the DESIGN.md slots (IPC `widgets layout` puts every card back).
 */
Variants {
    id: root
    model: Quickshell.screens
    readonly property bool widgetsVisible: WidgetsState.visible   // kept for shell.qml compatibility

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "overworld-widgets"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        readonly property bool shown: WidgetsState.visible
        function rx(x) { return width - (1920 - x) }      // right-column slots
        function by(y) { return height - (1080 - y) }     // bottom-row slots

        // while a card is dragged the whole layer takes input, so a fast flick can't outrun the card's region
        Item { id: dragCatcher; anchors.fill: parent }
        mask: Region {
            Region { item: WidgetsState.dragging ? dragCatcher : null }
            Region { item: win.shown && weather.shown ? weather : null }
            Region { item: win.shown && music.shown ? music : null }
            Region { item: win.shown && calendar.shown ? calendar : null }
            Region { item: win.shown && sysinfo.shown ? sysinfo : null }
            Region { item: win.shown && quote.shown ? quote : null }
            Region { item: win.shown && herb.shown ? herb : null }
            Region { item: win.shown && brew.shown ? brew : null }
            Region { item: win.shown && cava.shown ? cava : null }
        }

        // reading order = stagger order (left column top→bottom, then right column, then the bottom row)
        WeatherCard  { id: weather;  index: 0; cardId: "weather";  defaultX: 24; defaultY: 60 }
        CalendarCard { id: calendar; index: 1; cardId: "calendar"; defaultX: win.rx(1516); defaultY: 60 }
        MusicCard    { id: music;    index: 2; cardId: "music";    defaultX: 24; defaultY: 376 }
        SysInfoCard  { id: sysinfo;  index: 3; cardId: "sysinfo";  defaultX: win.rx(1476); defaultY: 336 }
        BrewTimerCard { id: brew;    index: 4; cardId: "brew";    defaultX: 24; defaultY: win.by(812) }
        CavaCard     { id: cava;     index: 5; cardId: "cava";     defaultX: win.rx(1536); defaultY: win.by(652) }
        HerbCard     { id: herb;     index: 6; cardId: "herb";     defaultX: Math.round(win.width / 2 - 190); defaultY: win.by(812) }
        QuoteCard    { id: quote;    index: 7; cardId: "quote";    defaultX: win.rx(1436); defaultY: win.by(848) }
    }
}
