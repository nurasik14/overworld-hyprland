//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Widgets.Weather

/*  Every sky condition side by side (dev aid for the Weather card):
 *      OW_MODE=light OW_WIDGETS_LAYER=top qs -p quickshell/Widgets/preview/skies.qml     (then scripts/dev-shot.sh …)
 */
ShellRoot {
    PanelWindow {
        anchors { top: true; left: true }
        margins { top: 80; left: 30 }
        implicitWidth: 6 * Theme.px(88) + 20; implicitHeight: 2 * Theme.px(58) + 20
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "overworld-widgets-skies"
        exclusionMode: ExclusionMode.Ignore
        color: "#C6C6C6"
        Grid {
            x: 10; y: 10; columns: 6; spacing: 0
            Repeater {
                model: [
                    { kind: "clear", day: true, code: 0, h: 12 }, { kind: "clear", day: true, code: 1, h: 7 }, { kind: "cloudy", day: true, code: 2, h: 16 },
                    { kind: "cloudy", day: true, code: 3, h: 10 }, { kind: "rain", day: true, code: 63, h: 14 }, { kind: "thunder", day: true, code: 95, h: 15 },
                    { kind: "clear", day: false, code: 0, h: 23 }, { kind: "cloudy", day: false, code: 2, h: 20 }, { kind: "rain", day: false, code: 65, h: 21 },
                    { kind: "snow", day: true, code: 73, h: 11 }, { kind: "snow", day: false, code: 71, h: 1 }, { kind: "fog", day: true, code: 45, h: 9 }
                ]
                SkyWindow {
                    required property var modelData
                    width: Theme.px(84); height: Theme.px(54)
                    kind: modelData.kind; day: modelData.day; code: modelData.code; hourOverride: modelData.h
                }
            }
        }
    }
}
