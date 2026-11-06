import QtQuick
import qs.Common

/*  McToggle — the Options cycle button: a McButton printing "Label: ON" / "Label: OFF". All of McButton's API applies.
 *    label: string       text before the colon
 *    checked: bool
 *    onText, offText     default "ON", "OFF"
 *    signal toggled(bool checked)
 *
 *    McToggle { label: "Particles"; checked: cfg.particles; onToggled: c => cfg.particles = c }
 */
McButton {
    id: root
    property string label: ""
    property bool checked: false
    property string onText: "ON"
    property string offText: "OFF"
    signal toggled(bool checked)

    text: (label.length ? label + ": " : "") + (checked ? onText : offText)
    // Emit first: a toggle bound to a store (`checked: Options.get(…)`) updates through its binding, and assigning `checked`
    // here would break that binding for good (the button then shows a stale value and the next click writes the wrong one).
    // Only a toggle nothing updated (standalone, or an async service) flips itself.
    onClicked: {
        const want = !checked;
        toggled(want);
        if (checked !== want) checked = want;
    }
}
