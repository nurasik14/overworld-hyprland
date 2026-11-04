pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// The tray's model and its size, so the HUD does not need its own import of the D-Bus service in every file.
Singleton {
    readonly property var items: SystemTray.items
    readonly property int count: SystemTray.items.values.length
}
