import QtQuick
import qs.Common
import qs.Widgets.Services
import qs.Widgets.Weather
import qs.Widgets.Music
import qs.Widgets.Calendar
import qs.Widgets.SysInfo
import qs.Widgets.Quote
import qs.Widgets.BlockOfDay
import qs.Widgets.BrewTimer
import qs.Widgets.Cava

/*  WidgetLayout — the eight cards on their default slots (two columns of stacked cards, see DesktopWidgets).  An Item sized like the
 *  screen; DesktopWidgets puts it in the layer window, the offscreen render harness (preview/render.qml) in a plain window.
 */
Item {
    id: root
    property alias weather: weather
    property alias music: music
    property alias calendar: calendar
    property alias sysinfo: sysinfo
    property alias brew: brew
    property alias cava: cava
    property alias block: block
    property alias quote: quote
    // Slots are stacks in GUI px, so they follow the GUI scale: left column 12 GUI px from the edge, right column flush to
    // 12 GUI px from the right edge, 3 GUI px of air between cards, first card at 8 GUI px (there is no top bar; the column must end above the HUD's chips at the bottom).
    readonly property int edge: Theme.px(12)
    readonly property int gap: Theme.px(6)
    readonly property int firstY: Theme.px(8)

    // reading order = stagger order (left column top→bottom, then right column)
    WeatherCard    { id: weather;  index: 0; cardId: "weather";  defaultX: root.edge;                       defaultY: root.firstY }
    CalendarCard   { id: calendar; index: 1; cardId: "calendar"; defaultX: root.width - root.edge - width;  defaultY: root.firstY }
    MusicCard      { id: music;    index: 2; cardId: "music";    defaultX: root.edge;                       defaultY: weather.defaultY + weather.height + root.gap }
    SysInfoCard    { id: sysinfo;  index: 3; cardId: "sysinfo";  defaultX: root.width - root.edge - width;  defaultY: calendar.defaultY + calendar.height + root.gap }
    BrewTimerCard  { id: brew;     index: 4; cardId: "brew";     defaultX: root.edge;                       defaultY: music.defaultY + music.height + root.gap }
    CavaCard       { id: cava;     index: 5; cardId: "cava";     defaultX: root.width - root.edge - width;  defaultY: sysinfo.defaultY + sysinfo.height + root.gap }
    BlockOfDayCard { id: block;    index: 6; cardId: "block";    defaultX: root.edge;                       defaultY: brew.defaultY + brew.height + root.gap }
    QuoteCard      { id: quote;    index: 7; cardId: "quote";    defaultX: root.width - root.edge - width;  defaultY: cava.defaultY + cava.height + root.gap }
}
