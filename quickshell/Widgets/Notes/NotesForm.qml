import QtQuick
import qs.Common
import qs.Widgets.Projects
import qs.Widgets.Services

/*  NotesForm — the sheet you write on: the card's paper, slightly larger, with a blinking cursor at the end of the text, the page in the corner and
 *  a Done button under it, in the spirit of the game's book and sign screens.  Used by NotesEditor (inside the overworld-notes layer)
 *  and by the offscreen renders.
 *    active: bool    true while open: takes the keyboard
 *  Keys: Enter = new line · Esc / Ctrl+Enter / Done / a click outside = save and close · Ctrl+N = new sheet · Ctrl+PgUp / PgDn = flip.
 *  Every keystroke goes to NotesService.typed(): saved 700 ms after the last one, an empty sheet is dropped on close.
 */
Item {
    id: form
    property bool active: false
    signal closeAsked()

    readonly property var svc: NotesService
    readonly property int sheetW: 216      // GUI px
    readonly property int sheetH: 150
    readonly property alias textEdit: edit
    width: Theme.px(sheetW)
    height: Theme.px(sheetH + 4 + 20 + 3 + 10)

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
        else if (ctrl && e.key === Qt.Key_PageUp) { if (form.svc.flipDraft(-1)) Theme.playSound("book.page"); e.accepted = true; }
        else if (ctrl && e.key === Qt.Key_PageDown) { if (form.svc.flipDraft(1)) Theme.playSound("book.page"); e.accepted = true; }
    }

    MouseArea { anchors.fill: parent; onClicked: edit.forceActiveFocus() }      // clicks on the sheet don't reach the dim behind it

    PaperSheet {
        id: paper
        width: Theme.px(form.sheetW); height: Theme.px(form.sheetH)
        seed: form.svc.draftId.length ? form.svc.draftId.charCodeAt(form.svc.draftId.length - 1) + form.svc.draftId.charCodeAt(form.svc.draftId.length - 2) * 31 : 7
        fold: 10

        McText {       // the book screen's page indicator
            anchors.right: parent.right; anchors.rightMargin: Theme.px(7)
            y: Theme.px(5)
            text: "Page " + form.svc.draftPage + " of " + form.svc.draftPages
            color: paper.inkMuted
            shadow: false
        }
        Flickable {
            id: flick
            x: Theme.px(7); y: Theme.px(16)
            width: parent.width - Theme.px(14)
            height: parent.height - Theme.px(16 + paper.fold + 1)
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
                color: paper.ink
                selectionColor: "#7A9BD0"
                selectedTextColor: "#FFFFFF"
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontPx(1)
                font.hintingPreference: Font.PreferNoHinting
                renderType: TextEdit.NativeRendering
                antialiasing: false
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                activeFocusOnTab: false
                cursorVisible: form.active
                cursorDelegate: Item {
                    id: caret
                    width: Theme.gui
                    // `_` after the last character, a thin bar inside the text, blinking 6 ticks on, 6 off like the game's fields
                    readonly property bool atEnd: edit.cursorPosition >= edit.length
                    readonly property bool on: Theme.reducedMotion || (blink.tick % 12) < 6
                    McTicker { id: blink; active: edit.cursorVisible && !Theme.reducedMotion }
                    Rectangle {
                        visible: caret.on && caret.atEnd
                        y: caret.height - Theme.px(2); x: Theme.gui
                        width: Theme.px(5); height: Theme.gui
                        color: paper.ink
                    }
                    Rectangle {
                        visible: caret.on && !caret.atEnd
                        width: Theme.gui; height: caret.height
                        color: paper.ink
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
            x: flick.x + Theme.px(6); y: flick.y
            text: "Write something…"
            color: paper.inkMuted
            shadow: false
        }
        McScrollbar {
            flickable: flick
            visible: scrollable
            x: parent.width - Theme.px(7); y: flick.y
            height: flick.height
        }
    }

    // ---- under the sheet: flip, new, Done
    Row {
        y: Theme.px(form.sheetH + 4)
        x: 0
        spacing: Theme.px(2)
        McButton {
            id: prevB
            width: Theme.px(20); height: Theme.px(20)
            horizontalPadding: 0
            enabled: form.svc.draftPage > 1
            soundId: "book.page"
            activeFocusOnTab: false
            onClicked: form.svc.flipDraft(-1)
            PixelGlyph { anchors.centerIn: parent; kind: "left"; color: prevB.labelColor }
        }
        McButton {
            id: nextB
            width: Theme.px(20); height: Theme.px(20)
            horizontalPadding: 0
            enabled: form.svc.draftPage < form.svc.count
            soundId: "book.page"
            activeFocusOnTab: false
            onClicked: form.svc.flipDraft(1)
            PixelGlyph { anchors.centerIn: parent; kind: "right"; color: nextB.labelColor }
        }
        McButton {
            width: Theme.px(20); height: Theme.px(20)
            horizontalPadding: 0
            text: "+"
            tooltip: "New sheet"
            tooltipDescription: "Ctrl+N"
            activeFocusOnTab: false
            onClicked: form.svc.newDraft()
        }
        McButton {
            width: Theme.px(form.sheetW - 3 * 22)
            text: "Done"
            activeFocusOnTab: false
            onClicked: form.closeAsked()
        }
    }
    McText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(form.sheetH + 4 + 20 + 3)
        color: Theme.tooltipDesc
        text: edit.length > form.svc.maxChars - 200 ? [...edit.text].length + " / " + form.svc.maxChars + " characters"
                                                     : "Esc: done  Ctrl+N: new  Ctrl+PgUp/PgDn: flip"
    }
}
