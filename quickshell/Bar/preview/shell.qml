//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Bar
import qs.Launcher
import qs.Notifications
import qs.Network
import qs.Power
import qs.Wallpapers
import qs.Osd
import qs.Brew
import qs.Widgets.Services

/*  Preview of every qs-core surface on top of the running desktop:
 *      source scripts/dev-env.sh
 *      OW_PREVIEW=1 OW_MODE=light OW_SURFACE=launcher qs -p quickshell/Bar/preview
 *  OW_PREVIEW=1 pins no exclusive zone, no keyboard grab, and only logs commands (DRYRUN lines) instead of touching the desktop.
 *  OW_SURFACE: hud | launcher | notifications | notifcenter | network | power | wallpapers | osd | brightness | title | brew | bossbar
 *  OW_FAKE_STATS='{"battery":18,"charging":false,"ram":0.4,"cpu":0.7,"uptime":3.5,"swap":0.6}' fakes the HUD numbers.
 *  OW_SELFTEST=1 drives the real pointer and key handlers with synthetic QtTest events (no compositor involved: the real pointer stays
 *  where it is, nothing reaches other windows) and prints PASS/FAIL lines.
 */
ShellRoot {
    id: root
    readonly property string surface: Quickshell.env("OW_SURFACE") || "hud"

    Bar { id: hud }
    BossBar { id: boss }
    Launcher { id: launcher }
    Notifications { id: notes }
    NotificationCenter { id: center }
    NetworkPanel { id: network }
    PowerMenu { id: power }
    WallpaperPicker { id: worlds }
    Osd { id: osd }
    WorkspaceCard { id: wsCard }
    BrewDialog { id: brew }

    SelfTest {
        id: selftest
        active: Quickshell.env("OW_SELFTEST") === "1"
        hud: hud
        launcher: launcher
        notes: notes
        center: center
        network: network
        power: power
        worlds: worlds
        brew: brew
        osd: osd
        card: wsCard
    }

    Timer {
        interval: 700; running: true
        onTriggered: {
            switch (root.surface) {
            case "launcher": ShellState.open("launcher"); break;
            case "notifcenter":
                root.fakeNotes();
                ShellState.open("notifCenter");
                break;
            case "notifications": root.fakeNotes(); break;
            case "network": ShellState.open("network"); break;
            case "power": ShellState.open("power"); break;
            case "wallpapers": ShellState.open("wallpapers"); break;
            case "osd": osd.show("volume"); pin.restart(); break;
            case "brightness": osd.show("brightness"); pin.restart(); break;
            case "title": wsCard.reveal(2); break;
            case "brew": ShellState.open("brew"); break;
            case "bossbar": BrewTimer.start("25m"); BrewTimer.remaining = 900; break;
            case "itemname": hud.instances[0].showItemName(4); break;
            case "hudtip": selftest.hoverSlot(3); break;
            case "stacks": selftest.fakeStacks(); break;
            case "levelup": after.wait = 500; after.action = () => { SystemStats.uptimeHours = SystemStats.level + 1.02; }; after.start(); break;
            case "widgetsmenu": WidgetsState.menuOpen = true; break;
            case "launcher-tip": ShellState.open("launcher"); after.action = () => selftest.hoverAppSlot(12); after.start(); break;
            case "launcher-calc": ShellState.open("launcher"); after.action = () => ShellState.launcherSearch("=2^10 + 42"); after.start(); break;
            case "launcher-search": ShellState.open("launcher"); after.action = () => ShellState.launcherSearch("ki"); after.start(); break;
            case "launcher-fav": ShellState.open("launcher"); after.action = () => selftest.pickFavourites(); after.start(); break;
            case "power-confirm": ShellState.open("power"); after.action = () => power.instances[0].run("quit"); after.start(); break;
            case "network-password": ShellState.open("network"); after.wait = 1600; after.action = () => selftest.openPassword(); after.start(); break;
            case "wallpapers-create": ShellState.open("wallpapers"); after.action = () => worlds.instances[0].create(); after.start(); break;
            case "wallpapers-delete": ShellState.open("wallpapers"); after.action = () => { worlds.instances[0].view = "delete"; }; after.start(); break;
            }
        }
    }
    Timer { id: after; property var action: null; property int wait: 400; interval: wait; onTriggered: if (action) action() }
    Timer { id: pin; interval: 1000; repeat: true; onTriggered: osd.show(root.surface === "brightness" ? "brightness" : "volume") }
    function fakeNotes() {
        NotificationService.test("Backup finished", "All 3 snapshots are <b>safe</b>. Next run tomorrow.", "normal", "kitty");
        NotificationService.test("Battery critical", "Plug in now or lose your work.", "critical", "UPower");
        NotificationService.test("Update available", "A quiet little note.", "low", "firefox");
        NotificationService.test("New message", "Are you coming to the lecture?", "normal", "org.telegram.desktop");
    }

    IpcHandler {
        target: "preview"
        function run(js: string): string { return String(eval(js)); }
    }
}
