import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

/*  Osd — the Options slider above the hotbar (volume / brightness), namespace overworld-osd, click-through.
 *  "Master Volume: 75%" (OFF when muted), "Brightness: Moody (4%)" … "Brightness: 54%" … "Bright (100%)", like the Options screen.
 *  show("volume" | "brightness") from IPC; appears on its own when the Pipewire sink volume changes. Auto-hide 1.2 s.
 */
Scope {
    id: root
    property string kind: "volume"
    property bool shown: false

    function show(k) {
        if (k === "brightness") AudioService.refreshBrightness();
        root.kind = k === "brightness" ? "brightness" : "volume";
        root.shown = true;
        hideTimer.restart();
    }
    Timer { id: hideTimer; interval: 1200; onTriggered: root.shown = false }
    Connections {
        target: AudioService
        function onVolumeShown() { root.show("volume"); }
        function onBrightnessShown() { root.show("brightness"); }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "overworld-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.bottom: true
            margins.bottom: Theme.px(64)
            implicitWidth: Theme.px(150)
            implicitHeight: Theme.px(20)
            color: "transparent"
            mask: Region {}          // click-through
            visible: root.shown || slider.opacity > 0.01

            readonly property bool isBrightness: root.kind === "brightness"
            // the handle stops at the end of the track; the number keeps counting past 100 % and turns red (§c)
            readonly property real value: isBrightness ? AudioService.brightness : Math.min(1, AudioService.volume)
            readonly property int percent: Math.round((isBrightness ? AudioService.brightness : AudioService.volume) * 100)
            readonly property bool overdrive: !isBrightness && !AudioService.muted && percent > 100
            readonly property string label: {
                if (!isBrightness) return AudioService.muted ? "Master Volume: OFF" : "Master Volume: " + percent + "%";
                if (!AudioService.brightnessAvailable) return "Brightness: no device";
                if (percent >= 100) return "Brightness: Bright (100%)";
                if (percent <= 25) return "Brightness: Moody (" + percent + "%)";
                return "Brightness: " + percent + "%";
            }

            McSlider {
                id: slider
                anchors.fill: parent
                from: 0; to: 1
                value: AudioService.muted && !win.isBrightness ? 0 : win.value
                text: win.label
                codes: win.overdrive ? "Master Volume: §c" + win.percent + "%" : ""
                highlighted: true
                soundId: ""
                opacity: root.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.guiFade; easing.type: Theme.easeGui } }
            }
        }
    }
}
