import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  BrewDialog — 煎 · BREW TIMER settings (SUPER+SHIFT+B · click the brew card's clock · `overworld brew set` ·
 *  `ipc call brew open`), namespace overworld-brew.
 *  Two fields, any duration (25 · 50m · 1h30 · 90s · 1:30; rest 0 = no rest) + preset chips.
 *  ⏎ = save and start (idle) / save (a brew is running, it keeps going) · Tab next field · ↑/↓ ±1 min · Esc close.
 *  Saving runs `overworld brew set` (config.json brew.work / brew.break) via BrewTimer.save().
 */
Variants {
    id: root
    model: Quickshell.screens
    property bool onlyFocusedScreen: true      // previews render on a headless output


    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-brew"
        onlyFocusedScreen: root.onlyFocusedScreen
        open: ShellState.brewOpen
        onCloseRequested: ShellState.close("brew")

        readonly property var t: BrewTimer
        readonly property real workSec: t.parse(workField.text)     // real, not int: NaN = unreadable
        readonly property real restSec: t.parse(restField.text)
        readonly property bool workOk: t.validWork(workSec)
        readonly property bool restOk: t.validRest(restSec)
        readonly property bool ok: workOk && restOk
        readonly property string hint: "try 25, 50m, 1h30, 90s or 1:30"

        onShownChanged: if (shown) {
            workField.text = t.short(t.workSeconds);
            restField.text = t.short(t.breakSeconds);
            workField.error = false; restField.error = false;
            focusField(workField);
        }

        function focusField(f) { f.forceActiveFocus(); f.input.selectAll(); }
        function step(f, delta) {                       // ↑/↓ in a field: ±1 min
            const isWork = f === workField;
            let s = t.parse(f.text);
            if (isNaN(s)) s = isWork ? t.workSeconds : t.breakSeconds;
            s = Math.max(isWork ? 60 : 0, Math.min(t.maxSeconds, s + delta));
            f.text = t.short(s);
        }
        function flagErrors() {
            workField.error = !workOk; restField.error = !restOk;
            errorReset.restart();
        }
        function save() {
            if (!ok) { flagErrors(); return false; }
            t.save(workSec, restSec);
            return true;
        }
        function saveAndStart() {
            if (!save()) return;
            t.startWith(workSec + "s", restSec + "s");
            ShellState.close("brew");
        }
        function accept() {
            if (t.active) { if (save()) ShellState.close("brew"); }
            else saveAndStart();
        }
        Timer { id: errorReset; interval: 700; onTriggered: { workField.error = false; restField.error = false; } }

        PaperPanel {
            id: panel
            width: 460; height: 352
            anchors.centerIn: parent
            title: "煎"
            subtitle: "Brew timer"
            sealGlyph: "药"
            radius: Theme.radius.lg
            padding: Theme.space.lg
            opacity: win.progress
            transform: Translate { y: (1 - win.progress) * 12 }

            MouseArea { anchors.fill: parent }       // clicks on the panel don't reach the scrim

            Column {
                anchors.fill: parent
                spacing: Theme.space.sm

                // ---- brew
                Row {
                    width: parent.width
                    spacing: Theme.space.md
                    InkText { text: "Brew"; role: "subtitle"; width: 48; anchors.verticalCenter: parent.verticalCenter }
                    InkField {
                        id: workField
                        width: parent.width - 48 - parent.spacing
                        icon: "󰔟"
                        placeholder: "25 · 50m · 1h30 · 1:30"
                        onAccepted: win.accept()
                        onEscaped: ShellState.close("brew")
                        onNavigate: key => {
                            if (key === Qt.Key_Up) win.step(workField, 60);
                            else if (key === Qt.Key_Down) win.step(workField, -60);
                            else if (key === Qt.Key_Tab) win.focusField(restField);
                        }
                    }
                }
                Row {
                    x: 48 + Theme.space.md
                    spacing: 6
                    Repeater {
                        model: [["15m", 900], ["25m", 1500], ["45m", 2700], ["50m", 3000], ["1h", 3600], ["1h30", 5400]]
                        InkButton {
                            required property var modelData
                            text: modelData[0]; quiet: true; implicitHeight: 24; horizontalPadding: 8
                            checked: win.workSec === modelData[1]
                            activeFocusOnTab: false
                            onClicked: { workField.text = win.t.short(modelData[1]); win.focusField(workField); }
                        }
                    }
                }

                Item { width: 1; height: 2 }

                // ---- rest
                Row {
                    width: parent.width
                    spacing: Theme.space.md
                    InkText { text: "Rest"; role: "subtitle"; width: 48; anchors.verticalCenter: parent.verticalCenter }
                    InkField {
                        id: restField
                        width: parent.width - 48 - parent.spacing
                        icon: "󰒲"
                        placeholder: "5 · 10m · 0 = no rest"
                        onAccepted: win.accept()
                        onEscaped: ShellState.close("brew")
                        onNavigate: key => {
                            if (key === Qt.Key_Up) win.step(restField, 60);
                            else if (key === Qt.Key_Down) win.step(restField, -60);
                            else if (key === Qt.Key_Tab) win.focusField(workField);
                        }
                    }
                }
                Row {
                    x: 48 + Theme.space.md
                    spacing: 6
                    Repeater {
                        model: [["none", 0], ["5m", 300], ["10m", 600], ["15m", 900], ["20m", 1200], ["30m", 1800]]
                        InkButton {
                            required property var modelData
                            text: modelData[0]; quiet: true; implicitHeight: 24; horizontalPadding: 8
                            checked: win.restSec === modelData[1]
                            activeFocusOnTab: false
                            onClicked: { restField.text = modelData[1] ? win.t.short(modelData[1]) : "0"; win.focusField(restField); }
                        }
                    }
                }

                InkDivider { width: parent.width; brush: true; height: 10 }

                // ---- what will happen
                InkText {
                    width: parent.width
                    role: "small"
                    wrapMode: Text.WordWrap
                    color: win.ok ? Theme.text : Theme.error
                    text: !win.workOk ? (isNaN(win.workSec) ? "Can't read the brew time — " + win.hint + "." : "Brew must be between 1 s and 24 h.")
                        : !win.restOk ? (isNaN(win.restSec) ? "Can't read the rest time — " + win.hint + " (0 = no rest)." : "Rest must be 24 h or less.")
                        : "Brew " + win.t.human(win.workSec) + (win.restSec > 0 ? ", then rest " + win.t.human(win.restSec) + "." : ", no rest.")
                          + (win.t.active ? "  The running brew keeps its time; new lengths apply from the next one." : "")
                }

                Item { width: 1; height: Theme.space.xs }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.space.sm
                    InkButton { text: "Cancel"; quiet: true; activeFocusOnTab: false; onClicked: ShellState.close("brew") }
                    InkButton {
                        text: "Save"; icon: "󰆓"
                        activeFocusOnTab: false
                        primary: win.t.active
                        enabled: win.ok
                        onClicked: if (win.save()) ShellState.close("brew")
                    }
                    InkButton {
                        text: win.t.active ? "Restart now" : "Start"; icon: "󰐊"
                        activeFocusOnTab: false
                        primary: !win.t.active
                        enabled: win.ok
                        onClicked: win.saveAndStart()
                    }
                }
            }
        }
        InkText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: panel.bottom; anchors.topMargin: Theme.space.lg
            role: "small"; muted: true
            opacity: win.progress
            text: (win.t.active ? "⏎ save" : "⏎ save + start") + " · tab next field · ↑↓ ±1 min · esc close"
        }
    }
}
