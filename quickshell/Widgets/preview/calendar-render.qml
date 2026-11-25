//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Widgets.Calendar
import qs.Widgets.Services

/*  Offscreen render of the Clock & Calendar card and its quick-add panel, and a driver of the real handlers (no compositor, nothing live is touched).
 *  Use preview/calendar-render.sh: it makes a temp HOME + cache, fictional events (tests/gcal-fixture.py) and a fake backend, then runs
 *      OW_RENDER_OUT=/tmp/x.png OW_RENDER_WHAT=card|tip|agenda|busy|rowtip|edit|editerr|act OW_MODE=light|dark  qs -p quickshell/Widgets/preview/calendar-render.qml
 *  card = month view · tip = the hovered day's tooltip · agenda = a selected day · busy = a day with 9 events, scrolled · rowtip = hovered event row ·
 *  edit / editerr = the quick-add panel over the card (typed line / a line that does not parse) · act = no picture: real mouse and key events (QtTest's
 *  TestEvent, delivered to this offscreen window only), PASS / FAIL lines.  not-configured / offline / loading come from how the .sh sets the backend up.
 */
ShellRoot {
    id: root
    readonly property string what: Quickshell.env("OW_RENDER_WHAT") || "card"
    readonly property bool loadingView: Quickshell.env("OW_RENDER_STATE") === "loading"      // shoot before the first sync is over
    readonly property bool editView: what === "edit" || what === "editerr" || what === "act"
    readonly property var svc: CalendarService
    Window {
        id: win
        width: 640
        height: root.editView ? 460 : 440
        visible: true
        color: "#4E6B45"
        Image {
            anchors.fill: parent
            source: Quickshell.env("OW_RENDER_BG") ? "file://" + Quickshell.env("OW_RENDER_BG") : ""
            fillMode: Image.PreserveAspectCrop
        }
        Item {
            id: stage
            anchors.fill: parent
            CalendarCard {
                id: card
                cardId: "calendar"
                x: 150; y: 20
                defaultX: 150; defaultY: 20
                screenName: "render"
            }
            Rectangle { anchors.fill: parent; visible: root.svc.addOpen; color: "#50101010" }
            MouseArea {        // the layer's "click outside"
                anchors.fill: parent
                enabled: root.svc.addOpen
                onClicked: root.svc.closeAdd()
            }
            CalendarForm {
                id: form
                visible: root.svc.addOpen
                x: 225; y: 150
                active: root.svc.addOpen
                onCloseAsked: root.svc.closeAdd()
            }
        }

        function dayAt(n) { return root.svc.addDays(root.svc.todayKey, n); }
        function setup() {
            const w = root.what;
            if (w === "tip") card.pinDay = dayAt(parseInt(Quickshell.env("OW_RENDER_PIN") || "2"));
            else if (w === "agenda") root.svc.selectDay(dayAt(parseInt(Quickshell.env("OW_RENDER_DAY") || "0")));
            else if (w === "busy") root.svc.selectDay(dayAt(2));
            else if (w === "rowtip") { root.svc.selectDay(dayAt(0)); card.pinRow = 1; }
            else if (w === "edit" || w === "editerr") {
                root.svc.selectDay(dayAt(0));
                root.svc.openAdd(dayAt(1));
                form.field.text = w === "edit" ? "9:30-11 Lab @MMW2450" : "14:00";
                root.svc.parse(form.field.text, dayAt(1));
            }
        }
        // wait for the first read of the cache (the service syncs by itself), then arrange, then shoot
        property int waited: 0
        Timer {
            interval: 200; repeat: true; running: root.what !== "act"
            onTriggered: {
                win.waited += 200;
                const ready = root.svc.loaded || root.loadingView || win.waited > 6000;
                if (!ready || win.waited < (root.loadingView ? 800 : 1200)) return;
                stop();
                win.setup();
                late.start();
            }
        }
        Timer {
            id: late; interval: parseInt(Quickshell.env("OW_RENDER_LATE") || "900")
            onTriggered: {
                if (root.what === "busy") { card.agendaFlick.contentY = Theme.px(11) * 2; }
                win.shoot();
            }
        }
        function shoot() {
            win.contentItem.grabToImage(function (r) {          // the window, not the stage: tooltips live on the window's content item
                const out = Quickshell.env("OW_RENDER_OUT") || "/tmp/ow-calendar.png";
                console.warn("render: state=" + root.svc.state + " events=" + root.svc.events.length + " saved", r.saveToFile(out), out);
                Qt.quit();
            });
        }

        // ---------------------------------------------------------------- OW_RENDER_WHAT=act
        TestEvent { id: ev }
        FileView { id: openLog; path: Quickshell.env("OW_RENDER_OPENLOG"); blockLoading: true; printErrors: false }
        FileView { id: notifyLog; path: Quickshell.env("OW_NOTIFY_LOG"); blockLoading: true; printErrors: false }
        FileView { id: backendLog; path: Quickshell.env("FAKE_LOG"); blockLoading: true; printErrors: false }
        property int fails: 0
        property int passes: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (ok) win.passes++; else win.fails++; }
        function typeText(s) { for (let i = 0; i < s.length; i++) ev.keyClickChar(s[i], Qt.NoModifier, -1); }
        function pos(item, xx, yy) { return item.mapToItem(null, xx === undefined ? item.width / 2 : xx, yy === undefined ? item.height / 2 : yy); }
        function clickOn(item, xx, yy) { const p = pos(item, xx, yy); ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1); }
        function dblClickOn(item, xx, yy) { const p = pos(item, xx, yy); ev.mouseDoubleClickSequence(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1); }
        function moveTo(item, xx, yy) { const p = pos(item, xx, yy); ev.mouseMove(win.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier); }
        function wheelOn(item, dy) { const p = pos(item); ev.mouseWheel(win.contentItem, p.x, p.y, Qt.NoButton, Qt.NoModifier, 0, dy, -1); }
        function cellOf(key) {
            const g = card.agenda ? card.weekRow : card.monthGrid;
            for (let i = 0; i < g.children.length; i++) if (g.children[i].key === key) return g.children[i];
            return null;
        }
        function rows() { const l = card.agendaList, out = []; for (let i = 0; i < l.children.length; i++) if (l.children[i].event) out.push(l.children[i]); return out; }
        readonly property var acts: [
            () => {
                win.pass("harness: events loaded, state ok", root.svc.loaded && root.svc.state === "ok" && root.svc.events.length >= 12, root.svc.state + "/" + root.svc.events.length);
                win.pass("month view, no selection", !card.agenda && root.svc.selectedDay === "");
                const c = win.cellOf(win.dayAt(0));
                win.pass("today's slot shows a stack count of 5", c && c.count === 5, c && c.count);
                win.pass("the Next strip names the next event", card.nextStrip.info.event !== null && card.nextStrip.text.length > 0, card.nextStrip.text);
                win.moveTo(win.cellOf(win.dayAt(0)));
            },
            () => {
                win.pass("hover lights the slot", win.cellOf(win.dayAt(0)).hot);
                win.clickOn(win.cellOf(win.dayAt(0)));
            },
            () => {
                win.pass("a click selects the day", root.svc.selectedDay === win.dayAt(0) && card.agenda, root.svc.selectedDay);
                win.pass("the week view shows 7 slots with the day selected", card.weekRow.visible && win.cellOf(win.dayAt(0)) !== null && win.cellOf(win.dayAt(0)).selected);
                win.pass("the agenda lists 5 events (4 timed + all day first)", win.rows().length === 5 && win.rows()[0].event.allDay, win.rows().length);
                win.clickOn(win.rows()[1]);
            },
            () => {
                openLog.reload();
                win.pass("a click on an event asks for it to be opened (the stub logged `open fx0`)", String(openLog.text()).indexOf("open fx0") >= 0, String(openLog.text()).trim());
                win.wheelOn(card.weekRow, -120);
            },
            () => {
                win.pass("wheel down over the week moves to next week", root.svc.selectedDay === win.dayAt(7), root.svc.selectedDay);
                win.wheelOn(card.weekRow, 120);
            },
            () => {
                win.pass("wheel up moves back", root.svc.selectedDay === win.dayAt(0), root.svc.selectedDay);
                win.clickOn(card.monthButton);
            },
            () => {
                win.pass("▲ shows the month again and clears the selection", !card.agenda && root.svc.selectedDay === "");
                const before = root.svc.month;
                win.wheelOn(card.monthGrid, -120);
                win.wheelStart = before;
            },
            () => {
                win.pass("wheel down over the grid = next month", root.svc.month === (win.wheelStart + 1) % 12, root.svc.month);
                win.wheelOn(card.monthGrid, 120);
            },
            () => {
                win.pass("wheel up = back", root.svc.month === win.wheelStart, root.svc.month);
                win.clickOn(card.monthBarItem, Theme.px(4), Theme.px(6));
            },
            () => {
                win.pass("the < button = previous month", root.svc.month === (win.wheelStart + 11) % 12, root.svc.month);
                win.clickOn(card.monthBarItem, Theme.px(88), Theme.px(6));
            },
            () => {
                win.pass("click the month name = today's month", root.svc.month === new Date().getMonth(), root.svc.month);
                win.dblClickOn(win.cellOf(win.dayAt(1)));
            },
            () => {
                win.pass("double-click on a day of the month opens the quick-add panel for it", root.svc.addOpen && root.svc.addDay === win.dayAt(1), root.svc.addDay);
                win.pass("the field has the keyboard", form.field.input.activeFocus);
                win.typeText("9:30-11 Lab @MMW2450");
            },
            () => {
                win.pass("typed text is in the field", form.field.text === "9:30-11 Lab @MMW2450", form.field.text);
            },
            () => {
                win.pass("the preview shows the parsed line", root.svc.previewText.indexOf("09:30-11:00 · Lab @MMW2450") >= 0, root.svc.previewText);
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            },
            () => {
                win.pass("Enter starts saving", root.svc.adding || !root.svc.addOpen);
            },
            () => {
                win.pass("the panel closes after the add", !root.svc.addOpen, root.svc.addError);
                backendLog.reload(); notifyLog.reload();   // FileView.reload() is not synchronous: read it in the next step
                win.dblClickOn(win.cellOf(win.dayAt(1)));
            },
            () => {
                const re = new RegExp("calendar create --summary Lab --start " + win.dayAt(1) + "T09:30:00[+-]\\d\\d:\\d\\d --end " + win.dayAt(1) + "T11:00:00[+-]\\d\\d:\\d\\d --location MMW2450");
                win.pass("the backend got exactly that create (fake backend log)", re.test(String(backendLog.text())), String(backendLog.text()).split("\n").filter(l => l.indexOf("create") >= 0).join("|"));
                win.pass("the 'Event added' notification was sent (notify-send stub)", String(notifyLog.text()).indexOf("Event added") >= 0 && String(notifyLog.text()).indexOf("Lab") >= 0, String(notifyLog.text()).trim());
                win.pass("open again", root.svc.addOpen);
                win.typeText("14:00");
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            },
            () => {
                win.pass("a line without a title is refused with a message and the panel stays", root.svc.addOpen && root.svc.addError.length > 0, root.svc.addError);
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            },
            () => {
                win.pass("Esc closes", !root.svc.addOpen);
                root.svc.deselect();
            },
            () => {
                win.clickOn(card.addButton);   // not visible in month view: nothing happens
            },
            () => {
                win.pass("the + is not live in the month view", !root.svc.addOpen);
                root.svc.selectDay(win.dayAt(0));
            },
            () => {
                win.clickOn(card.addButton);
            },
            () => {
                win.pass("the + opens the panel for the selected day", root.svc.addOpen && root.svc.addDay === win.dayAt(0), root.svc.addDay);
                ev.mouseClick(win.contentItem, win.width - 4, 4, Qt.LeftButton, Qt.NoModifier, -1);
            },
            () => {
                win.pass("a click outside closes", !root.svc.addOpen);
                root.svc.selectDay(win.dayAt(2));
            },
            () => {
                win.pass("a busy day scrolls", card.agendaFlick.scrollable && win.rows().length === 10, win.rows().length);
                win.wheelOn(card.agendaFlick, -120);
            },
            () => {
                win.pass("the wheel scrolls the agenda", card.agendaFlick.contentY > 0, card.agendaFlick.contentY);
                root.svc.deselect();
            },
            () => {
                win.pass("end", true);
                console.warn("RESULT " + win.passes + " passed, " + win.fails + " failed");
                Qt.quit();
            }
        ]
        property int wheelStart: 0
        property int actStep: 0
        Timer {
            interval: 350; repeat: true; running: root.what === "act"
            onTriggered: {
                if (win.actStep === 0 && !(root.svc.loaded && win.visible)) { win.waited += 350; if (win.waited < 8000) return; }
                if (win.actStep >= win.acts.length) { stop(); return; }
                const f = win.acts[win.actStep++];
                try { f(); } catch (e) { win.pass("step " + win.actStep + " threw " + e, false); }
            }
        }
    }
}
