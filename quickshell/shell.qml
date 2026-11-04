import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Bar
import qs.Launcher
import qs.Notifications
import qs.Network
import qs.Power
import qs.Wallpapers
import qs.Osd
import qs.Widgets
import qs.Brew
import qs.Game
import qs.World
import qs.Interact

/*  Overworld Hyprland — Quickshell entry.  `qs -c overworld`
 *  Surfaces (layer namespaces): overworld-bar (the HUD) · overworld-bossbar · overworld-widgetsmenu · overworld-launcher · overworld-notif ·
 *  overworld-notifcenter · overworld-network · overworld-power · overworld-wallpapers · overworld-osd · overworld-wscard · overworld-brew ·
 *  overworld-widgets (qs-widgets) and the Game, World and Interact modules' own
 *  IPC: qs -c overworld ipc call <target> <fn>   — see docs/QUICKSHELL.md
 */
ShellRoot {
    id: shell

    Bar {}
    BossBar {}
    Launcher {}
    Notifications {}
    NotificationCenter {}
    NetworkPanel {}
    PowerMenu {}
    WallpaperPicker {}
    Osd { id: osd }
    WorkspaceCard { id: wsCard }
    DesktopWidgets {}
    BrewDialog {}

    // phase-2 modules (stubs until their owners land them; each owns its IpcHandlers)
    GameSystems {}      // qs-features: chat console, advancements, statistics, options screen
    WorldFx {}          // fx-world: day/night cycle, weather overlay, F3 debug screen
    Interactions {}     // fx-interactions: block-break close, place-block open, screenshot, low-battery screens

    // ------------------------------------------------------------ IPC (BRIEF §4)
    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggle("launcher"); }
        function open(): void { ShellState.open("launcher"); }
        function close(): void { ShellState.close("launcher"); }
        function search(q: string): void { ShellState.open("launcher"); ShellState.launcherSearch(q); }
    }
    IpcHandler {
        target: "network"
        function toggle(): void { ShellState.toggle("network"); }
        function open(): void { ShellState.open("network"); }
        function close(): void { ShellState.close("network"); }
        function expand(ssid: string): void { ShellState.open("network"); ShellState.networkExpand(ssid); }
        function connect(ssid: string): void { NetworkService.connect(ssid, ""); }
        function rescan(): void { NetworkService.rescan(); }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { ShellState.toggle("power"); }
        function open(): void { ShellState.open("power"); }
        function close(): void { ShellState.close("power"); }
    }
    IpcHandler {
        target: "wallpapers"
        function toggle(): void { ShellState.toggle("wallpapers"); }
        function open(): void { ShellState.open("wallpapers"); }
        function close(): void { ShellState.close("wallpapers"); }
        function select(index: int): void { ShellState.open("wallpapers"); ShellState.wallpaperAction("select", index); }
        function apply(): void { ShellState.wallpaperAction("apply", 0); }
        function next(): void { ShellState.open("wallpapers"); ShellState.wallpaperAction("next", 0); }
        function prev(): void { ShellState.open("wallpapers"); ShellState.wallpaperAction("prev", 0); }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { ShellState.toggle("notifCenter"); }
        function open(): void { ShellState.open("notifCenter"); }
        function close(): void { ShellState.close("notifCenter"); }
        function dnd(): void { NotificationService.toggleDnd(); }
        function setDnd(on: bool): void { NotificationService.setDnd(on); }
        function test(summary: string, body: string, urgency: string): void { NotificationService.test(summary, body, urgency, "Overworld"); }
        function clear(): void { NotificationService.dismissAll(); }
        function status(): string {
            return (NotificationService.dnd ? "dnd " : "") + NotificationService.count + " notes, " + NotificationService.unread + " unread";
        }
    }
    IpcHandler {
        target: "theme"
        function toggle(): void { Theme.toggleMode(); }
        function set(mode: string): void { Theme.setMode(mode); }
        function get(): string { return Theme.mode; }
    }
    IpcHandler {
        target: "osd"
        function volume(): void { osd.show("volume"); }
        function brightness(): void { osd.show("brightness"); }
    }
    IpcHandler {
        target: "workspace"
        // `reveal` (not `show`: the qs CLI swallows a function named show)
        function reveal(id: int): void { wsCard.reveal(id); }
        function current(): void { wsCard.reveal(HyprlandState.focusedId); }
        function hide(): void { wsCard.hide(); }
        function title(id: int): string { return WorkspaceNotes.title(id); }
    }
    IpcHandler {
        target: "hud"
        function reveal(): void { ShellState.hudHidden = false; }
        function hide(): void { ShellState.hudHidden = true; }
        function toggle(): void { ShellState.hudHidden = !ShellState.hudHidden; }
        function status(): string { return ShellState.hudHidden || ConfigService.isSpectator ? "hidden" : "shown"; }
    }
    IpcHandler {
        target: "shell"
        function closeAll(): void { ShellState.closeAll(); }
        function status(): string {
            return "mode=" + Theme.mode + " launcher=" + ShellState.launcherOpen + " network=" + ShellState.networkOpen
                 + " power=" + ShellState.powerOpen + " wallpapers=" + ShellState.wallpapersOpen
                 + " notifCenter=" + ShellState.notifCenterOpen + " dnd=" + NotificationService.dnd
                 + " wifi=" + NetworkService.activeSsid + " networks=" + NetworkService.networks.length;
        }
    }
}
