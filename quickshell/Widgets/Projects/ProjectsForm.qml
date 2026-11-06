import QtQuick
import qs.Common
import qs.Widgets.Services

/*  ProjectsForm — the add / edit panel of the Projects card: Title (autofocus), Note (optional), "Already built" checkbox,
 *  Add / Save (Enter) and Cancel (Esc).  Used by ProjectsDialog (inside the overworld-projects layer) and by the offscreen renders.
 *    active: bool        true while visible: resets the fields from the service (editId = "" → a new project) and focuses the title
 *    editId: string      the project being edited ("" = adding); edit mode adds the move up / down buttons
 *    signals done() (saved or added: the dialog closes)  cancelled()
 *  Keys: Enter (in a field) accepts · Tab next field · Esc cancels (the surrounding FocusScope handles it).
 */
Item {
    id: form
    property bool active: false
    property string editId: ""
    signal done()
    signal cancelled()

    readonly property var svc: ProjectsService
    property string loadedId: ""
    readonly property var editItem: loadedId.length ? svc.byId(loadedId) : null
    readonly property bool editing: editItem !== null
    property bool flagged: false

    width: panel.width
    height: panel.height + Theme.px(16)

    function load() {
        const it = form.editId.length ? svc.byId(form.editId) : null;
        form.loadedId = it ? it.id : "";
        titleField.text = it ? it.title : "";
        noteField.text = it ? (it.note || "") : "";
        builtBox.checked = it ? it.status === "built" : false;
        form.flagged = false;
        titleField.input.forceActiveFocus();
        titleField.input.selectAll();
    }
    onActiveChanged: if (active) load()
    onEditIdChanged: if (active) load()
    Connections {      // the list may arrive after the form (first load of the file): pick the project up then
        target: form.svc
        function onItemsChanged() { if (form.active && form.editId.length && !form.editing) form.load() }
    }
    Component.onCompleted: if (active) load()

    function accept() {
        const t = svc.clean(titleField.text);
        if (!t.length) { form.flagged = true; flagReset.restart(); titleField.input.forceActiveFocus(); return; }
        if (form.editing) {
            const it = form.editItem;
            svc.rename(it.id, t, noteField.text);
            if ((it.status === "built") !== builtBox.checked) svc.setBuilt(it.id, builtBox.checked);
        } else {
            svc.add(t, noteField.text, builtBox.checked);
        }
        form.done();
    }
    function fieldKey(next, event) {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { next.input ? next.input.forceActiveFocus() : next.forceActiveFocus(); event.accepted = true; }
    }
    Timer { id: flagReset; interval: 900; onTriggered: form.flagged = false }

    McPanel {
        id: panel
        width: Theme.px(176)
        height: Theme.px(108)
        padding: 0
        title: ""

        MouseArea { anchors.fill: parent }       // clicks on the panel don't reach the dim behind it

        McText {
            y: Theme.px(5)
            anchors.horizontalCenter: parent.horizontalCenter
            text: form.editing ? "Edit Project" : "New Project"
            guiTitle: true
        }

        Row {
            x: Theme.px(7); y: Theme.px(19)
            spacing: Theme.px(2)
            McText { anchors.verticalCenter: parent.verticalCenter; width: Theme.px(28); text: "Title"; color: Theme.guiText }
            McTextField {
                id: titleField
                width: Theme.px(132); height: Theme.px(16)
                placeholderText: form.flagged ? "Give it a name" : "What are you building?"
                maxLength: 120
                onAccepted: form.accept()
                Component.onCompleted: titleField.input.Keys.pressed.connect(e => form.fieldKey(noteField, e))
            }
        }
        Row {
            x: Theme.px(7); y: Theme.px(39)
            spacing: Theme.px(2)
            McText { anchors.verticalCenter: parent.verticalCenter; width: Theme.px(28); text: "Note"; color: Theme.guiText }
            McTextField {
                id: noteField
                width: Theme.px(132); height: Theme.px(16)
                placeholderText: "optional"
                maxLength: 240
                onAccepted: form.accept()
                Component.onCompleted: noteField.input.Keys.pressed.connect(e => form.fieldKey(builtBox, e))
            }
        }
        McCheckbox {
            id: builtBox
            x: Theme.px(5); y: Theme.px(57)
            text: form.editing ? "Built" : "Already built"
            labelColor: Theme.guiText
            soundId: ""
            Keys.onPressed: e => { if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { titleField.input.forceActiveFocus(); e.accepted = true; } }
        }
        Row {   // reorder (editing, in-progress projects only: built ones are ordered by when they were built): moves it inside its section
            visible: form.editing && form.editItem.status !== "built"
            x: Theme.px(100); y: Theme.px(60)
            spacing: Theme.px(2)
            McButton {
                width: Theme.px(36); height: Theme.px(14); horizontalPadding: 0
                text: "Up"; activeFocusOnTab: false
                tooltip: "Move up in the list"
                onClicked: form.svc.move(form.loadedId, -1)
            }
            McButton {
                width: Theme.px(36); height: Theme.px(14); horizontalPadding: 0
                text: "Down"; activeFocusOnTab: false
                tooltip: "Move down in the list"
                onClicked: form.svc.move(form.loadedId, 1)
            }
        }
        Row {
            x: Theme.px(7); y: Theme.px(82)
            spacing: Theme.px(2)
            McButton {
                width: Theme.px(79); text: "Cancel"; activeFocusOnTab: false
                onClicked: form.cancelled()
            }
            McButton {
                width: Theme.px(79); text: form.editing ? "Save" : "Add"; activeFocusOnTab: false
                enabled: svc.clean(titleField.text).length > 0
                onClicked: form.accept()
            }
        }
    }
    McText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.height + Theme.px(5)
        color: Theme.tooltipDesc
        text: "Enter: " + (form.editing ? "save" : "add") + "   Tab: next field   Esc: close"
    }
}
