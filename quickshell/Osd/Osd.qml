import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

/*  Osd — a small paper slip at the bottom centre with an ink bar (volume / brightness).  namespace overworld-osd.
 *  show("volume" | "brightness") from IPC; appears automatically on Pipewire sink volume changes.  Auto-hide 1.2 s.
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
            exclusionMode: ExclusionMode.Ignore
            anchors.bottom: true
            margins.bottom: 72
            implicitWidth: 280
            implicitHeight: 56
            color: "transparent"
            mask: Region {}          // click-through
            visible: root.shown || slip.opacity > 0.01

            readonly property real value: root.kind === "brightness" ? AudioService.brightness : Math.min(1, AudioService.volume)
            readonly property string glyph: root.kind === "brightness" ? (AudioService.brightness < 0.34 ? "󰃞" : (AudioService.brightness < 0.67 ? "󰃟" : "󰃠")) : AudioService.volumeGlyph()
            readonly property string label: root.kind === "brightness" ? (AudioService.brightnessAvailable ? "亮 · Brightness" : "亮 · Brightness · no backlight device") : (AudioService.muted ? "音 · Muted" : "音 · Volume")

            Rectangle {
                id: slip
                anchors.fill: parent
                radius: Theme.radius.md
                color: Theme.surface
                border.width: Theme.border.frame
                border.color: Theme.frame
                opacity: root.shown ? 1 : 0
                transform: Translate { y: root.shown ? 0 : 8 }
                Behavior on opacity { NumberAnimation { duration: root.shown ? Theme.durFast : Theme.durBase; easing.type: Theme.easeDrift } }
                Rectangle {   // inner hairline
                    anchors.fill: parent; anchors.margins: 4
                    radius: Math.max(2, parent.radius - 3)
                    color: "transparent"; border.width: 1; border.color: Theme.hairline
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.space.md
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    spacing: Theme.space.md
                    Text {
                        text: win.glyph
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 20
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        width: parent.width - 20 - 44 - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        InkText { role: "small"; muted: true; text: win.label }
                        Item {   // ink bar
                            width: parent.width; height: 6
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surfaceAlt; border.width: 1; border.color: Theme.hairline }
                            Rectangle {
                                width: Math.max(6, parent.width * win.value); height: parent.height; radius: 3
                                color: AudioService.muted && root.kind === "volume" ? Theme.textMuted : Theme.accent
                                Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
                            }
                        }
                    }
                    InkText {
                        role: "clock_bar"
                        width: 44
                        horizontalAlignment: Text.AlignRight
                        text: root.kind === "brightness" && !AudioService.brightnessAvailable ? "—" : Math.round(win.value * 100) + "%"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
