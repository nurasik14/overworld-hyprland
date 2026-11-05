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
import "layout-plan.js" as Plan

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
    // Slots come from layout-plan.js (GUI px stacks that follow the GUI scale and the screen): two columns, flush to the
    // left / right edge; when a stack would run into the HUD chips (GUI scale 3+ at 1080p) the cards are re-dealt over up
    // to three columns, and a card with no room left gets fits = false (hidden until it is dragged somewhere).
    readonly property var cards: [weather, calendar, music, sysinfo, brew, cava, block, quote]   // reading order = stagger order
    readonly property var slots: width > 0 && height > 0 ? Plan.plan(width, height, Theme.gui, cards.map(c => ({ w: c.guiW, h: c.guiH })))
                                                         : cards.map(c => ({ x: 0, y: 0, fits: true }))

    WeatherCard    { id: weather;  index: 0; cardId: "weather";  defaultX: root.slots[0].x; defaultY: root.slots[0].y; fits: root.slots[0].fits }
    CalendarCard   { id: calendar; index: 1; cardId: "calendar"; defaultX: root.slots[1].x; defaultY: root.slots[1].y; fits: root.slots[1].fits }
    MusicCard      { id: music;    index: 2; cardId: "music";    defaultX: root.slots[2].x; defaultY: root.slots[2].y; fits: root.slots[2].fits }
    SysInfoCard    { id: sysinfo;  index: 3; cardId: "sysinfo";  defaultX: root.slots[3].x; defaultY: root.slots[3].y; fits: root.slots[3].fits }
    BrewTimerCard  { id: brew;     index: 4; cardId: "brew";     defaultX: root.slots[4].x; defaultY: root.slots[4].y; fits: root.slots[4].fits }
    CavaCard       { id: cava;     index: 5; cardId: "cava";     defaultX: root.slots[5].x; defaultY: root.slots[5].y; fits: root.slots[5].fits }
    BlockOfDayCard { id: block;    index: 6; cardId: "block";    defaultX: root.slots[6].x; defaultY: root.slots[6].y; fits: root.slots[6].fits }
    QuoteCard      { id: quote;    index: 7; cardId: "quote";    defaultX: root.slots[7].x; defaultY: root.slots[7].y; fits: root.slots[7].fits }
}
