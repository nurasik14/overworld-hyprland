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
    onClicked: {
        checked = !checked;
        toggled(checked);
    }
}
