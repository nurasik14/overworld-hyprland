import QtQuick
import Quickshell.Bluetooth
import qs.Common
import qs.Services

// Bluetooth as an ender pearl (an eye when something is connected), stack count = connected devices. Click: blueman.
HudSlot {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter ? adapter.enabled : false
    readonly property int connected: Bluetooth.devices.values.filter(d => d.connected).length
    item: !adapter ? "barrier" : connected > 0 ? "ender_eye" : "ender_pearl"
    count: connected
    tooltip: !adapter ? "No Bluetooth adapter" : btOn ? "Bluetooth on" : "Bluetooth off"
    tooltipDescription: (adapter && btOn ? connected + " connected\n" : "") + "Click: blueman"
    tooltipCategory: "Bluetooth"
    opacity: adapter && !btOn ? 0.55 : 1
    onClicked: ShellState.run(["sh", "-c", "command -v blueman-manager >/dev/null 2>&1 && exec blueman-manager"])
}
