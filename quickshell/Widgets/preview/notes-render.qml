//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Common
import qs.Widgets
import qs.Widgets.Notes
import qs.Widgets.Services

/*  Offscreen render of the Notes card or its editor, and a driver of the real handlers (no compositor, nothing live is touched):
 *      HYPR_NOTES_FILE=<temp json> OW_RENDER_OUT=/tmp/x.png OW_RENDER_WHAT=card|undo|edit|act [OW_RENDER_PIN=1] [OW_RENDER_FLIP=n] [OW_RENDER_NEW=1] [OW_RENDER_LATE=ms]
 *      OW_MODE=light|dark OW_WIDGETS_OPACITY=0.72 HOME=<temp home> QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/notes-render.qml
 *  card/undo = the card; edit = the form as it sits over the card, on the light dim; act = no picture, real key and mouse events (QtTest's
 *  TestEvent, delivered to this offscreen window only) through the form and the card, PASS / FAIL lines.
 */
ShellRoot {
    id: root
    readonly property string what: Quickshell.env("OW_RENDER_WHAT") || "card"
    readonly property bool cardView: what === "card" || what === "undo"
    Window {
        id: win
        width: root.cardView ? card.width + 40 : form.width + 80
        height: root.cardView ? card.height + 40 : form.height + 60
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
            NotesCard {
                id: card
                cardId: "notes"
                x: 20; y: 20
                defaultX: 20; defaultY: 20
                pinHover: Quickshell.env("OW_RENDER_PIN") === "1"
                pinArrow: Quickshell.env("OW_RENDER_ARROW") === "1"
                screenName: "render"
            }
            Rectangle { anchors.fill: parent; visible: NotesService.editorOpen; color: "#50101010" }
            MouseArea {        // the layer's "click outside"
                anchors.fill: parent
                enabled: NotesService.editorOpen
                onClicked: NotesService.closeEditor()
            }
            NotesForm {
                id: form
                visible: NotesService.editorOpen
                x: 40; y: 30
                u: parseInt(Quickshell.env("OW_RENDER_U") || "0") || (Theme.gui + 1)
                active: NotesService.editorOpen
                onCloseAsked: NotesService.closeEditor()
            }
        }
        Timer {
            interval: 1200
            running: root.what !== "act"
            onTriggered: {
                const flip = parseInt(Quickshell.env("OW_RENDER_FLIP") || "0");
                if (flip) NotesService.goTo(NotesService.sheets[flip - 1].id);
                if (root.what === "undo") { NotesService.removeCurrent(); late.start(); return; }
                if (root.what === "edit") { NotesService.openEditor(Quickshell.env("OW_RENDER_NEW") === "1" ? "new" : "current"); late.start(); return; }
                late.interval = 200; late.start();
            }
        }
        Timer { id: late; interval: parseInt(Quickshell.env("OW_RENDER_LATE") || "700"); onTriggered: win.shoot() }
        function shoot() {
            stage.grabToImage(function (r) {
                const out = Quickshell.env("OW_RENDER_OUT") || "/tmp/ow-notes.png";
                console.warn("render: saved", r.saveToFile(out), out);
                Qt.quit();
            });
        }

        // ---------------------------------------------------------------- OW_RENDER_WHAT=act
        TestEvent { id: ev }
        property int fails: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (!ok) win.fails++; }
        function typeText(s) {
            for (let i = 0; i < s.length; i++) ev.keyClickChar(s[i], Qt.NoModifier, -1);
        }
        function clickOn(item, xx, yy) {
            const p = item.mapToItem(null, xx === undefined ? item.width / 2 : xx, yy === undefined ? item.height / 2 : yy);
            ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        }
        function textOf() { return form.textEdit.text; }
        property int actStep: 0
        readonly property var svc: NotesService
        readonly property var acts: [
            () => { win.pass("harness: 3 sheets", win.svc.count === 3, win.svc.count); win.clickOn(card.contentItem, Theme.px(40), Theme.px(40)); },
            () => {
                win.pass("a click on the sheet opens the editor on the current sheet", win.svc.editorOpen && win.svc.draftText === win.svc.current.text, win.svc.draftText);
                win.pass("the text has the keyboard", form.textEdit.activeFocus);
                win.pass("cursor at the end", form.textEdit.cursorPosition === form.textEdit.length);
                win.typeText("ab");
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                win.typeText("cd");
            },
            () => {
                win.pass("typing reaches the sheet; Enter is a newline", win.svc.draftText.endsWith("ab\ncd"), JSON.stringify(win.svc.draftText));
                win.pass("not closed by Enter", win.svc.editorOpen);
                ev.keyClick(Qt.Key_N, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+N: a blank sheet", win.svc.draftText === "" && textOf() === "" && !win.svc.draftInFile);
                win.pass("…the sheet before it was saved", win.svc.sheets.some(s => s.text.endsWith("ab\ncd")));
                win.pass("…page 4 of 4", win.svc.draftPage === 4 && win.svc.draftPages === 4, win.svc.draftPage + "/" + win.svc.draftPages);
                win.typeText("newest");
            },
            () => {
                ev.keyClick(Qt.Key_PageUp, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+PgUp flips back and saves", win.svc.draftPage === 3 && textOf() === win.svc.sheets[2].text && win.svc.sheets[3].text === "newest", win.svc.draftPage);
                ev.keyClick(Qt.Key_PageDown, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+PgDn flips forward", win.svc.draftPage === 4 && textOf() === "newest", win.svc.draftPage);
                ev.keyClick(Qt.Key_Return, Qt.ControlModifier, -1);
            },
            () => {
                win.pass("Ctrl+Enter closes", !win.svc.editorOpen);
                win.clickOn(card.contentItem, Theme.px(40), Theme.px(40));
            },
            () => {
                win.pass("open again", win.svc.editorOpen);
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            },
            () => {
                win.pass("Esc closes", !win.svc.editorOpen);
                win.clickOn(card.contentItem, Theme.px(40), Theme.px(40));
            },
            () => {
                ev.mouseClick(win.contentItem, win.width - 4, 4, Qt.LeftButton, Qt.NoModifier, -1);
            },
            () => {
                win.pass("a click outside closes", !win.svc.editorOpen);
                win.clickOn(card.contentItem, Theme.px(40), Theme.px(40));
            },
            () => {
                form.textEdit.selectAll();
                ev.keyClick(Qt.Key_Delete, Qt.NoModifier, -1);
                win.pass("select all + Delete empties it", textOf() === "" && win.svc.draftText === "");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            },
            () => {
                win.pass("an emptied sheet is dropped on close, undo offered", win.svc.count === 3 && win.svc.undo !== null, win.svc.count);
                win.svc.undoRemove();
            },
            () => {
                win.pass("undo restores", win.svc.count === 4, win.svc.count);
                win.pass("flipBy off the end does nothing", (card.flipBy(1), win.svc.currentIndex === win.svc.count - 1));
                card.wheelBy(60); card.wheelBy(60);
            },
            () => {
                win.pass("two half notches of wheel flip one sheet back", win.svc.currentIndex === win.svc.count - 2, win.svc.currentIndex);
                card.wheelBy(-120);
            },
            () => {
                win.pass("a notch the other way flips forward", win.svc.currentIndex === win.svc.count - 1, win.svc.currentIndex);
                ev.mouseWheel(win.contentItem, card.x + Theme.px(60), card.y + Theme.px(60), Qt.NoButton, Qt.NoModifier, 0, 120, -1);
            },
            () => {
                win.pass("a real wheel event over the sheet flips", win.svc.currentIndex === win.svc.count - 2, win.svc.currentIndex);
                ev.mouseMove(win.contentItem, card.x + Theme.px(60), card.y + Theme.px(60), -1, Qt.NoButton, Qt.NoModifier);
            },
            () => {
                win.pass("hover on the card shows the ✕", card.hot);
                win.clickOn(card.contentItem, Theme.px(19), Theme.px(18));
            },
            () => {
                win.pass("a click on the ✕ tears the sheet off, without opening the editor", win.svc.count === 3 && win.svc.undo !== null && !win.svc.editorOpen, win.svc.count);
            },
            () => {
                win.pass("the Undo bar's button brings it back", (win.clickOn(card.contentItem, Theme.px(114), Theme.px(162)), true));
            },
            () => {
                win.pass("…count back", win.svc.count === 4 && win.svc.undo === null, win.svc.count);
                win.clickOn(card.contentItem, Theme.px(73), Theme.px(162));
            },
            () => {
                win.pass("the + button opens a blank sheet", win.svc.editorOpen && win.svc.draftText === "" && !win.svc.draftInFile);
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            },
            () => {
                win.pass("nothing typed: nothing added", win.svc.count === 4 && !win.svc.editorOpen);
                const pos = win.svc.currentIndex;
                win.clickOn(card.contentItem, Theme.px(34), Theme.px(162));
                win.pass("the ◀ arrow (sync check next step)", true);
                win.flipFrom = pos;
            },
            () => {
                win.pass("◀ flips back", win.svc.currentIndex === win.flipFrom - 1, win.svc.currentIndex);
                win.svc.removeCurrent();
            },
            () => {
                const at = win.svc.currentIndex;
                win.clickOn(card.contentItem, Theme.px(34), Theme.px(162));         // ◀ is under the Undo bar
                win.flipFrom = at;
            },
            () => {
                win.pass("a click on the Undo bar does not reach the pager under it", win.svc.currentIndex === win.flipFrom, win.svc.currentIndex);
                win.svc.undoRemove();
            },
            // ---- the book screen's own controls: arrows, PgUp/PgDn, Alt+arrows, New page / Tear out / Done
            () => {
                win.svc.goTo(win.svc.sheets[win.svc.count - 1].id);
                win.svc.openEditor("current");
            },
            () => {
                win.pass("book: opens on the last page", win.svc.draftPage === win.svc.count && win.svc.draftPages === win.svc.count, win.svc.draftPage + "/" + win.svc.draftPages);
                win.pass("book: ◀ shown, ▶ shown on the last page of a written note (it starts a new page)", form.hasBack && form.hasForward);
                win.clickOn(form.page, form.page.bx(107), form.page.bx(162));
            },
            () => {
                win.pass("book: ▶ on the last page = a new blank page", win.svc.draftPage === win.svc.count + 1 && win.svc.draftText === "" && !win.svc.draftInFile, win.svc.draftPage + "/" + win.svc.draftPages);
                win.pass("book: …a blank last page has no ▶", !form.hasForward);
                win.clickOn(form.page, form.page.bx(34), form.page.bx(162));
            },
            () => {
                win.pass("book: ◀ goes back, the blank page leaves nothing behind", win.svc.draftPage === win.svc.count && win.svc.draftPages === win.svc.count, win.svc.draftPage + "/" + win.svc.draftPages);
                ev.keyClick(Qt.Key_PageUp, Qt.NoModifier, -1);
            },
            () => {
                win.pass("book: PgUp flips back", win.svc.draftPage === win.svc.count - 1, win.svc.draftPage);
                ev.keyClick(Qt.Key_Right, Qt.AltModifier, -1);
            },
            () => {
                win.pass("book: Alt+→ flips forward", win.svc.draftPage === win.svc.count, win.svc.draftPage);
                ev.keyClick(Qt.Key_PageDown, Qt.NoModifier, -1);
            },
            () => {
                win.pass("book: PgDn on the last page = new page", win.svc.draftPage === win.svc.count + 1 && win.svc.draftText === "", win.svc.draftPage);
                ev.keyClick(Qt.Key_Left, Qt.AltModifier, -1);
            },
            () => {
                win.pass("book: Alt+← flips back", win.svc.draftPage === win.svc.count, win.svc.draftPage);
                win.clickOn(form, form.u * 32, form.u * 198);                                   // New page
            },
            () => {
                win.pass("book: New page button", win.svc.draftPage === win.svc.count + 1 && win.svc.draftText === "", win.svc.draftPage);
                win.typeText("zz");
            },
            () => {
                win.pass("book: typing on the new page", win.svc.draftText === "zz", win.svc.draftText);
                win.clickOn(form, form.u * 100, form.u * 198);                                  // Tear out
            },
            () => {
                win.pass("book: Tear out on an unsaved page keeps the typed text for Undo and moves on", win.svc.undo !== null && win.svc.undo.count === 1 && win.svc.draftText !== "zz" && win.svc.editorOpen, win.svc.draftText);
                win.svc.undoRemove();
            },
            () => {
                const n = win.svc.count;
                win.flipFrom = n;
                win.clickOn(form, form.u * 100, form.u * 198);                                  // Tear out the page shown
            },
            () => {
                win.pass("book: Tear out removes a saved page (undo offered, still editing)", win.svc.count === win.flipFrom - 1 && win.svc.undo !== null && win.svc.editorOpen, win.svc.count);
                win.svc.undoRemove();
            },
            () => {
                win.pass("book: …and Undo brings it back", win.svc.count === win.flipFrom, win.svc.count);
                win.clickOn(form, form.u * 168, form.u * 198);                                  // Done
            },
            () => {
                win.pass("book: Done closes", !win.svc.editorOpen);
            },
            // ---- a saved position stays valid when the card grew: kept on the screen, not reset
            () => {
                WidgetsState.setPos("notes", 5000, 5000);
            },
            () => {
                const par = card.parent;
                win.pass("a saved position past the screen edge is clamped onto it (not reset)", card.x + card.width <= par.width && card.y + card.height <= par.height && card.x >= 0 && card.y >= 0 && card.x > 0 && card.y > 0, card.x + "," + card.y);
                WidgetsState.setPos("notes", 20, 20);
            },
            () => {
                win.pass("a saved position that fits is kept as it is", card.x === 20 && card.y === 20, card.x + "," + card.y);
                WidgetsState.resetPos("notes");
            },
            () => {
                win.svc.openEditor("new");
            },
            () => {
                const e = form.textEdit;
                e.text = "A" + "m".repeat(3996) + "END";                           // full, 4000
                e.cursorPosition = 1;
                e.insert(1, "PASTED-IN");
                win.pass("full: a paste is refused, the end of the note stays", e.text.length === 4000 && e.text.endsWith("END") && e.text.indexOf("PASTED") < 0, e.text.length + " " + e.text.slice(-3));
                win.pass("…the draft has the same", win.svc.draftText === e.text);
                e.text = "🦊".repeat(3999);
                e.insert(e.length, "🦊🦊🦊");
                win.pass("full counts characters: emoji are not cut in half", [...e.text].length === 4000 && e.length === 8000, e.length);
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
                console.warn("notes-render act done: " + win.fails + " failed");
                Qt.quit();
            }
        ]
        property int flipFrom: 0
        Timer {
            interval: 450; repeat: true; running: root.what === "act"
            onTriggered: {
                if (win.actStep >= win.acts.length) return;
                const f = win.acts[win.actStep++];
                f();
            }
        }
    }
}
