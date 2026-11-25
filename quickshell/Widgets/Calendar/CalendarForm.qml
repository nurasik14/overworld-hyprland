import QtQuick
import qs.Common
import qs.Widgets.Services

/*  CalendarForm — the quick-add panel: one Minecraft text field, a preview of what the line will become (parsed by `hypr-gcal parse`, the
 *  same parser the CLI uses) and Add / Cancel.  Used by CalendarEditor (inside the overworld-calendar layer) and by the offscreen renders.
 *    active: bool    true while open: takes the keyboard
 *  Natural input:  14:00 Meeting @MMW2450 · 9:30-11 Lab · 2pm for 90m Call · all day Exam    (the day is the one you opened it on).
 *  Enter = add · Esc / Cancel / a click outside = close.  "Saving…" while the CLI runs; an error stays in the panel under the field.
 */
McPanel {
    id: form
    property bool active: false
    signal closeAsked()
    readonly property var svc: CalendarService
    readonly property alias field: field

    title: "Add event"
    width: Theme.px(200)
    height: Theme.px(118)

    function submit() {
        if (svc.adding || !field.text.trim().length) return;
        svc.add(field.text, svc.addDay);
    }
    function reset() {
        field.text = "";
        svc.addError = "";
        svc.previewText = ""; svc.previewError = "";
        if (form.active) field.input.forceActiveFocus();
    }
    onActiveChanged: if (active) reset()
    Component.onCompleted: if (active) reset()
    Timer { interval: 30; running: form.active; onTriggered: field.input.forceActiveFocus() }   // once the layer has really mapped
    Connections {
        target: form.svc
        function onAdded(text) { form.closeAsked(); }
    }
    Timer { id: previewTimer; interval: 220; onTriggered: form.svc.parse(field.text, form.svc.addDay) }

    MouseArea { parent: form; anchors.fill: parent; onClicked: field.input.forceActiveFocus() }   // clicks on the panel don't reach the dim behind it

    McText {
        x: Theme.px(1); y: 0
        text: form.svc.fmtDay(form.svc.addDay, "dddd d MMMM yyyy")
        color: Theme.guiText
        shadow: false
    }
    McTextField {
        id: field
        y: Theme.px(12)
        width: Theme.px(186)
        placeholderText: "14:00 Meeting @MMW2450"
        maxLength: 200
        enabled: !form.svc.adding
        onAccepted: form.submit()
        onEscapePressed: form.closeAsked()
        onEdited: { form.svc.addError = ""; previewTimer.restart(); }
    }
    McText {      // what will be created / what is wrong
        x: Theme.px(1); y: Theme.px(34); width: Theme.px(184)
        elide: Text.ElideRight
        shadow: false
        text: form.svc.adding ? "Saving…"
            : form.svc.addError.length ? form.svc.cap(form.svc.addError)
            : form.svc.previewError.length ? form.svc.cap(form.svc.previewError)
            : form.svc.previewText.length ? "→ " + form.svc.previewText : " "
        color: form.svc.adding ? Theme.chatReadable("6") : (form.svc.addError.length || form.svc.previewError.length) ? Theme.chatReadable("c") : Theme.chatReadable("2")
    }
    McText {
        x: Theme.px(1); y: Theme.px(46); width: Theme.px(184)
        wrapMode: Text.Wrap
        color: Theme.textMuted
        shadow: false
        text: "14:00 Meeting @place · 9:30-11 Lab · 2pm for 90m Call · all day Exam"
    }
    Row {
        y: Theme.px(71)
        spacing: Theme.px(4)
        McButton {
            width: Theme.px(91)
            text: form.svc.adding ? "Saving…" : "Add"
            enabled: !form.svc.adding && field.text.trim().length > 0
            activeFocusOnTab: false
            onClicked: form.submit()
        }
        McButton {
            width: Theme.px(91)
            text: "Cancel"
            activeFocusOnTab: false
            onClicked: form.closeAsked()
        }
    }
}
