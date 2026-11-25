import QtQuick
import qs.Common
import qs.Widgets.Projects
import qs.Widgets.Services

/*  NotesForm — the Book and Quill screen you write on (BookEditScreen): the card's book page one scale step bigger (`u` screen px per texel, GUI + 1,
 *  capped by the editor so book and buttons fit the output), black text in the game's 114 × 128 text box, "Page 2 of 5" top right, the page-turn
 *  arrows (forward on the last page starts a new page, as in the game), and under the book the game's buttons: New page · Tear out · Done.  The
 *  cursor is the game's: a blinking `_` after the last character, a thin bar inside the text.  Used by NotesEditor (inside the overworld-notes
 *  layer) and by the offscreen renders.
 *    active: bool    true while open: takes the keyboard
 *    u: int          screen px per book texel
 *  Keys: Enter = new line · Esc / Ctrl+Enter / Done / a click outside = save and close · Ctrl+N / New page = new page · PgUp / PgDn (also with Ctrl)
 *  and Alt+←/→ = flip · Tear out = remove this page with Undo (the editor moves on to the next one).
 *  Every keystroke goes to NotesService.typed(): saved 700 ms after the last one, an empty page is dropped on close.
 */
Item {
    id: form
    property bool active: false
    property int u: Theme.gui + 1
    signal closeAsked()

    readonly property var svc: NotesService
    readonly property alias textEdit: edit
    readonly property alias page: page
    readonly property int unitsW: 200      // the game's two 98 px buttons + gap are the widest thing on the screen
    readonly property int unitsH: 180 + 8 + 20 + 4 + 10
    width: u * unitsW
    height: u * unitsH

    property bool loading: false
    function load(text) {
        form.loading = true;
        edit.text = text;
        edit.cursorPosition = edit.length;
        form.loading = false;
        flick.contentY = Math.max(0, edit.contentHeight - flick.height);
        if (form.active) edit.forceActiveFocus();
    }
    Connections {
        target: form.svc
        function onDraftLoaded(text) { form.load(text); }
    }
    onActiveChanged: if (active) load(svc.draftText)
    Component.onCompleted: if (active) load(svc.draftText)
    Timer { interval: 30; running: form.active; onTriggered: edit.forceActiveFocus() }   // once the layer has really mapped

    // On a Cyrillic layout Qt reports the Cyrillic letter, so Ctrl+N (and TextEdit's own Ctrl+A/C/V/X/Z) would never match: fall back to
    // the physical key.  nativeScanCode is the xkb keycode on Wayland (evdev + 8).
    function latinKey(e) {
        if (e.key < 0x400 || e.key > 0x52f) return 0;
        return ({ 57: Qt.Key_N, 38: Qt.Key_A, 54: Qt.Key_C, 55: Qt.Key_V, 53: Qt.Key_X, 52: Qt.Key_Z })[e.nativeScanCode] || 0;
    }
    function keyPressed(e) {
        const ctrl = e.modifiers & Qt.ControlModifier;
        const latin = ctrl ? form.latinKey(e) : 0;
        if (latin) {
            if (latin === Qt.Key_N) form.svc.newDraft();
            else if (latin === Qt.Key_A) edit.selectAll();
            else if (latin === Qt.Key_C) edit.copy();
            else if (latin === Qt.Key_V) edit.paste();
            else if (latin === Qt.Key_X) edit.cut();
            else if (e.modifiers & Qt.ShiftModifier) edit.redo();
            else edit.undo();
            e.accepted = true;
        }
        else if (e.key === Qt.Key_Escape || (ctrl && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter))) { form.closeAsked(); e.accepted = true; }
        else if (ctrl && e.key === Qt.Key_N) { form.svc.newDraft(); e.accepted = true; }
        else if (e.key === Qt.Key_PageUp || (e.modifiers & Qt.AltModifier && e.key === Qt.Key_Left)) { form.pageBack(); e.accepted = true; }
        else if (e.key === Qt.Key_PageDown || (e.modifiers & Qt.AltModifier && e.key === Qt.Key_Right)) { form.pageForward(); e.accepted = true; }
    }
    // the arrows and keys: back = the page before; forward = the page after, or a new page past the last one (the game appends one too)
    readonly property bool hasBack: svc.draftPage > 1
    readonly property bool hasForward: svc.draftPage < svc.draftPages || !svc.isBlank(svc.draftText)
    function pageBack() { if (form.hasBack && form.svc.flipDraft(-1)) Theme.playSound("book.page"); }
    function pageForward() {
        if (!form.hasForward) return;
        if (form.svc.draftPage < form.svc.count) { if (form.svc.flipDraft(1)) Theme.playSound("book.page"); }
        else { form.svc.newDraft(); Theme.playSound("book.page"); }
    }

    MouseArea { anchors.fill: parent; onClicked: edit.forceActiveFocus() }      // clicks on the screen don't reach the dim behind it

    BookPage {
        id: page
        u: form.u
        x: form.u * (form.unitsW - 146) / 2
        MouseArea { anchors.fill: parent; onClicked: edit.forceActiveFocus() }

        McText {       // the book screen's page indicator, black like the game's
            x: page.bx(128) - width; y: page.bx(15)
            text: "Page " + form.svc.draftPage + " of " + form.svc.draftPages
            color: page.ink
            shadow: false
            font.pixelSize: 8 * form.u
        }
        Flickable {
            id: flick
            x: page.bx(16); y: page.bx(29)
            width: page.bx(114); height: page.bx(120)
            contentWidth: width
            contentHeight: edit.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            function ensureVisible(r) {
                if (contentY >= r.y) contentY = r.y;
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: edit
                width: flick.width
                height: Math.max(implicitHeight, flick.height)
                color: page.ink
                selectionColor: "#3D5BE0"
                selectedTextColor: "#FFFFFF"
                font.family: Theme.fontUi
                font.pixelSize: 8 * form.u
                font.hintingPreference: Font.PreferNoHinting
                renderType: TextEdit.NativeRendering
                antialiasing: false
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                selectByMouse: true
                activeFocusOnTab: false
                cursorVisible: form.active
                cursorDelegate: Item {
                    id: caret
                    width: form.u
                    // `_` after the last character, a thin bar inside the text, blinking 6 ticks on, 6 off like the game's fields
                    readonly property bool atEnd: edit.cursorPosition >= edit.length
                    readonly property bool on: Theme.reducedMotion || (blink.tick % 12) < 6
                    McTicker { id: blink; active: edit.cursorVisible && !Theme.reducedMotion }
                    Rectangle {
                        visible: caret.on && caret.atEnd
                        y: caret.height - page.bx(2); x: 0
                        width: page.bx(5); height: form.u
                        color: page.ink
                    }
                    Rectangle {
                        visible: caret.on && !caret.atEnd
                        y: 0
                        width: form.u; height: caret.height
                        color: page.ink
                    }
                }
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                onTextChanged: {
                    if (form.loading) return;
                    if (length > form.svc.maxChars) {   // full: refuse what was just typed or pasted, not the end of the note
                        const over = [...text].length - form.svc.maxChars;
                        if (over > 0) {
                            const before = [...text.slice(0, cursorPosition)];
                            const cut = before.slice(Math.max(0, before.length - over)).join("").length;
                            if (cut > 0) remove(cursorPosition - cut, cursorPosition);
                            else remove([...text].slice(0, form.svc.maxChars).join("").length, length);     // nothing before the caret to refuse
                            return;
                        }
                    }
                    form.svc.typed(text);
                }
                Keys.onPressed: e => form.keyPressed(e)
            }
        }
        McText {
            visible: edit.length === 0
            x: flick.x + page.bx(5); y: flick.y
            text: "Write something…"
            color: page.inkMuted
            shadow: false
            font.pixelSize: 8 * form.u
        }
        Rectangle {    // a long note: a thin brown scroll bar in the page's right margin
            visible: flick.contentHeight > flick.height + 1
            x: page.bx(131); width: page.bx(2)
            y: flick.y + flick.visibleArea.yPosition * flick.height
            height: Math.max(page.bx(6), flick.visibleArea.heightRatio * flick.height)
            color: "#8B6B4A"
        }
        BookArrow {
            visible: form.hasBack
            x: page.bx(23); y: page.bx(156)
            u: form.u
            forward: false
            onClicked: form.pageBack()
        }
        BookArrow {
            visible: form.hasForward
            x: page.bx(96); y: page.bx(156)
            u: form.u
            forward: true
            onClicked: form.pageForward()
        }
    }

    // ---- under the book: the game's buttons
    Row {
        y: form.u * (180 + 8)
        spacing: form.u * 4
        BookButton {
            width: form.u * 64; height: form.u * 20
            u: form.u
            text: "New page"
            tooltip: "New page"
            tooltipDescription: "Ctrl+N"
            onClicked: form.svc.newDraft()
        }
        BookButton {
            width: form.u * 64; height: form.u * 20
            u: form.u
            text: "Tear out"
            tooltip: "Tear out this page"
            tooltipDescription: "It can be undone for 5 seconds"
            enabled: edit.length > 0 || form.svc.draftInFile
            onClicked: form.svc.removeCurrent()
        }
        BookButton {
            width: form.u * 64; height: form.u * 20
            u: form.u
            text: "Done"
            onClicked: form.closeAsked()
        }
    }
    // the line under the buttons: how to use it, the character count when the page is nearly full, or Undo after a tear-out
    Item {
        y: form.u * (180 + 8 + 20 + 4)
        width: form.width; height: form.u * 10
        McText {
            visible: form.svc.undo === null
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.tooltipDesc
            text: edit.length > form.svc.maxChars - 200 ? [...edit.text].length + " / " + form.svc.maxChars + " characters"
                                                         : "Esc: done  Ctrl+N: new  PgUp/PgDn: flip"
            font.pixelSize: 8 * form.u
        }
        Row {
            visible: form.svc.undo !== null
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: form.u * 4
            McText {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.tooltipDesc
                text: form.svc.undo ? (form.svc.undo.count > 1 ? "Tore out " + form.svc.undo.count + " pages" : "Tore out a page") : ""
                font.pixelSize: 8 * form.u
            }
            BookButton {
                width: form.u * 40; height: form.u * 10
                u: form.u
                text: "Undo"
                onClicked: form.svc.undoRemove()
            }
        }
    }
}
