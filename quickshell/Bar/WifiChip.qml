import QtQuick
import qs.Common
import qs.Services

// Wi-Fi as the multiplayer ping bars. Click: the Multiplayer screen.
HudSlot {
    highlighted: ShellState.networkOpen
    tooltip: !NetworkService.wifiEnabled ? "Wi-Fi off" : NetworkService.connected ? NetworkService.activeSsid : NetworkService.wiredConnected ? "Wired" : "Not connected"
    tooltipDescription: (NetworkService.connected ? NetworkService.activeSignal + "% signal\n" : "") + "Open Multiplayer\nSuper+N"
    tooltipCategory: "Network"
    onClicked: ShellState.toggle("network")
    McItemIcon {
        visible: NetworkService.wiredConnected && !NetworkService.connected
        x: Theme.gui; y: Theme.gui
        name: "redstone"
    }
    McSprite {
        visible: NetworkService.connected || !NetworkService.wiredConnected
        anchors.centerIn: parent
        sprite: NetworkService.connected ? "server_list/ping_" + NetworkService.pingLevel(NetworkService.activeSignal) : "server_list/unreachable"
    }
}
