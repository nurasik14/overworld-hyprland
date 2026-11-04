import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  BrewDialog — the brewing stand GUI (SUPER+SHIFT+B · click the brew card's clock · `overworld brew set` · `ipc call brew open`),
 *  namespace overworld-brew.
 *  Top: the real gui/container/brewing_stand texture with the live timer on it: the arrow is the phase's progress, the bubbles rise
 *  while it runs, blaze powder is the fuel gauge (time left), nether wart sits in the top slot, one bottle fills per finished brew.
 *  Below: two fields, any duration (25 · 50m · 1h30 · 90s · 1:30; rest 0 = no rest), preset buttons, the plain-language summary.
 *  Enter = save and start (idle) / save (a brew is running, it keeps going) · Tab next field · Up/Down ±1 min · Esc close.
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
        property bool flagged: false

        onShownChanged: if (shown) {
            workField.text = t.short(t.workSeconds);
            restField.text = t.short(t.breakSeconds);
            win.flagged = false;
            focusField(workField);
        }

        function focusField(f) { f.input.forceActiveFocus(); f.input.selectAll(); }
        function step(f, delta) {                       // Up/Down in a field: ±1 min
            const isWork = f === workField;
            let s = t.parse(f.text);
            if (isNaN(s)) s = isWork ? t.workSeconds : t.breakSeconds;
            s = Math.max(isWork ? 60 : 0, Math.min(t.maxSeconds, s + delta));
            f.text = t.short(s);
        }
        function flagErrors() { win.flagged = true; errorReset.restart(); }
        function save() {
            if (!ok) { flagErrors(); return false; }
            if (ShellState.preview) console.warn("DRYRUN brew save", workSec, restSec);
            else t.save(workSec, restSec);
            return true;
        }
        function saveAndStart() {
            if (!save()) return;
            if (ShellState.preview) console.warn("DRYRUN brew start", workSec, restSec);
            else t.startWith(workSec + "s", restSec + "s");
            ShellState.close("brew");
        }
        function accept() {
            if (t.active) { if (save()) ShellState.close("brew"); }
            else saveAndStart();
        }
        function fieldKey(f, other, event) {
            if (event.key === Qt.Key_Up) { win.step(f, 60); event.accepted = true; }
            else if (event.key === Qt.Key_Down) { win.step(f, -60); event.accepted = true; }
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { win.focusField(other); event.accepted = true; }
        }
        Timer { id: errorReset; interval: 700; onTriggered: win.flagged = false }

        // ---- ticks for the bubbles
        McTicker { id: clock; active: win.shown && win.t.running }

        McPanel {
            id: panel
            width: Theme.px(176)
            height: Theme.px(198)
            x: Math.round((parent.width - width) / 2 / Theme.gui) * Theme.gui
            y: Math.round((parent.height - height) / 2 / Theme.gui) * Theme.gui
            padding: 0

            MouseArea { anchors.fill: parent }       // clicks on the panel don't reach the screen behind

            // ---- the stand: the top of the real texture
            readonly property bool hasStand: Theme._texFile("gui/container/brewing_stand").length > 0
            Item {
                visible: panel.hasStand
                width: Theme.px(176); height: Theme.px(74)
                clip: true
                McSprite { sprite: "gui/container/brewing_stand"; nightRemap: Theme.isDark }
            }
            Repeater {   // no Mojang assets and no fallback texture: the slots alone still work
                model: panel.hasStand ? [] : [[16, 16], [78, 16], [55, 50], [78, 57], [101, 50]]
                McSlot { required property var modelData; x: Theme.px(modelData[0]); y: Theme.px(modelData[1]); enabled: false }
            }
            McText {
                y: Theme.px(5)
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Brewing Stand"
                guiTitle: true
            }
            McItemIcon {   // ingredient: there is something in the stand while a brew runs
                visible: win.t.active
                x: Theme.px(79); y: Theme.px(17)
                name: win.t.phase === "breaking" ? "cookie" : "nether_wart"
            }
            McItemIcon {   // fuel
                visible: win.t.active
                x: Theme.px(17); y: Theme.px(17)
                name: "blaze_powder"
            }
            Repeater {     // bottles: one fills per finished brew, in threes
                model: [{ x: 56, y: 51 }, { x: 79, y: 58 }, { x: 102, y: 51 }]
                McItemIcon {
                    required property var modelData
                    required property int index
                    readonly property int filled: win.t.sessions === 0 ? 0 : ((win.t.sessions - 1) % 3) + 1
                    x: Theme.px(modelData.x); y: Theme.px(modelData.y)
                    visible: index < filled      // the texture already draws the empty bottle's outline
                    name: "potion"
                }
            }
            Item {         // arrow, downward
                x: Theme.px(97); y: Theme.px(16)
                width: Theme.px(9)
                height: Theme.px(Math.round(28 * (win.t.active ? win.t.progress : 0)))
                clip: true
                visible: panel.hasStand
                McSprite { sprite: "container/brewing_stand/brew_progress"; scaling: ({ type: "stretch", width: 9, height: 28 }) }
            }
            Item {         // bubbles rise from the bottom in the game's seven steps
                readonly property var steps: [29, 24, 20, 16, 11, 6, 0]
                readonly property int h: win.t.running ? steps[Math.floor(clock.tick / 2) % 7] : 0
                x: Theme.px(63); y: Theme.px(14 + 29 - h)
                width: Theme.px(12)
                height: Theme.px(h)
                clip: true
                visible: panel.hasStand
                McSprite { y: -Theme.px(29 - parent.h); sprite: "container/brewing_stand/bubbles"; scaling: ({ type: "stretch", width: 12, height: 29 }) }
            }
            Item {         // fuel gauge: time left in the phase
                x: Theme.px(60); y: Theme.px(44)
                height: Theme.px(4)
                width: Theme.px(Math.round(18 * (win.t.active ? 1 - win.t.progress : 1)))
                clip: true
                visible: panel.hasStand
                McSprite { sprite: "container/brewing_stand/fuel_length"; scaling: ({ type: "stretch", width: 18, height: 4 }) }
            }

            // ---- the settings
            Column {
                x: Theme.px(7); y: Theme.px(75)
                width: Theme.px(162)
                spacing: Theme.gui

                FieldRow {
                    label: "Brew"
                    McTextField {
                        id: workField
                        width: Theme.px(130); height: Theme.px(16)
                        placeholderText: "25, 50m, 1h30, 1:30"
                        onAccepted: win.accept()
                        Component.onCompleted: workField.input.Keys.pressed.connect(e => win.fieldKey(workField, restField, e))
                    }
                }
                PresetRow {
                    presets: [["15m", 900], ["25m", 1500], ["45m", 2700], ["50m", 3000], ["1h", 3600], ["1h30", 5400]]
                    current: win.workSec
                    onPicked: s => { workField.text = win.t.short(s); win.focusField(workField); }
                }
                FieldRow {
                    label: "Rest"
                    McTextField {
                        id: restField
                        width: Theme.px(130); height: Theme.px(16)
                        placeholderText: "5, 10m, 0 = no rest"
                        onAccepted: win.accept()
                        Component.onCompleted: restField.input.Keys.pressed.connect(e => win.fieldKey(restField, workField, e))
                    }
                }
                PresetRow {
                    presets: [["none", 0], ["5m", 300], ["10m", 600], ["15m", 900], ["20m", 1200], ["30m", 1800]]
                    current: win.restSec
                    onPicked: s => { restField.text = s ? win.t.short(s) : "0"; win.focusField(restField); }
                }

                McText {   // what will happen
                    width: parent.width
                    height: Theme.px(30)
                    wrapMode: Text.WordWrap
                    color: win.ok && !win.flagged ? Theme.guiText : Theme.chatReadable("c")
                    text: !win.workOk ? (isNaN(win.workSec) ? "Can't read the brew time: " + win.hint + "." : "Brew must be between 1 s and 24 h.")
                        : !win.restOk ? (isNaN(win.restSec) ? "Can't read the rest time: " + win.hint + " (0 = no rest)." : "Rest must be 24 h or less.")
                        : "Brew " + win.t.human(win.workSec) + (win.restSec > 0 ? ", then rest " + win.t.human(win.restSec) + "." : ", no rest.")
                          + (win.t.active ? " The running brew keeps its time; new lengths apply from the next one." : "")
                }
                Row {
                    spacing: Theme.px(2)
                    McButton {
                        width: Theme.px(52)
                        text: "Cancel"
                        activeFocusOnTab: false
                        onClicked: ShellState.close("brew")
                    }
                    McButton {
                        width: Theme.px(52)
                        text: "Save"
                        activeFocusOnTab: false
                        enabled: win.ok
                        onClicked: if (win.save()) ShellState.close("brew")
                    }
                    McButton {
                        width: Theme.px(54)
                        text: win.t.active ? "Restart" : "Start"
                        tooltip: win.t.active ? "Restart now" : "Save and start"
                        activeFocusOnTab: false
                        enabled: win.ok
                        onClicked: win.saveAndStart()
                    }
                }
            }
        }
        McText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: panel.y + panel.height + Theme.px(6)
            color: Theme.tooltipDesc
            text: (win.t.active ? "Enter: save" : "Enter: save and start") + "   Tab: next field   Up/Down: 1 min   Esc: close"
        }

        component FieldRow: Row {
            id: fieldRow
            property string label: ""
            spacing: Theme.px(2)
            McText {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(30)
                text: fieldRow.label
                color: Theme.guiText
            }
        }
        component PresetRow: Row {
            id: presetRow
            property var presets: []
            property real current: -1
            signal picked(int seconds)
            x: Theme.px(32)
            spacing: 0
            Repeater {
                model: presetRow.presets
                McButton {
                    required property var modelData
                    width: Theme.px(modelData[0].length > 3 ? 30 : 20)
                    height: Theme.px(14)
                    horizontalPadding: 0
                    text: modelData[0]
                    highlighted: presetRow.current === modelData[1]
                    activeFocusOnTab: false
                    onClicked: presetRow.picked(modelData[1])
                }
            }
        }
    }
}
