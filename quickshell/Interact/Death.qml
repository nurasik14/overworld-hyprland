import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  Death — the low-battery "You Died!" screen and its warning.
 *
 *    ≤ 15 % discharging, once per discharge cycle:  player.hurt + `battery {percent, charging:false, flash:true}` (the HUD blinks the hearts)
 *    ≤ 5 %  discharging, once per discharge cycle:  the death screen — red tint, "You died!", a death message from quotes/chat.json,
 *           "Score: <uptime minutes>", [Respawn] = dismiss, [Title Screen] = loginctl lock-session; sound player.death
 *    A cycle ends when the charger is connected. Never in creative mode; config `death_screen` false turns the screen off (the
 *    warning stays). The "already happened" flags live in $XDG_RUNTIME_DIR/overworld/battery-cycle.json, so a shell restart at 4 %
 *    does not show it twice. IPC `interact death` / `interact respawn` drive it by hand (they ignore the flags and the battery).
 *  OW_INTERACT_DRYRUN=1: the Title Screen button only logs instead of locking.
 */
Scope {
    id: root
    property bool open: false
    property string message: ""
    property int score: 0
    property bool hurtDone: false
    property bool deathDone: false
    property bool flagsLoaded: false
    readonly property bool dryRun: Quickshell.env("OW_INTERACT_DRYRUN") === "1"

    readonly property bool present: SystemStats.batteryPresent
    readonly property bool charging: SystemStats.charging
    readonly property bool discharging: SystemStats.discharging
    readonly property int percent: SystemStats.percent
    readonly property bool creative: ConfigService.isCreative
    readonly property bool deathEnabled: ConfigService.get("death_screen", true) !== false

    // ---------------------------------------------------------------- texts
    property var texts: ({})
    FileView {
        id: chatFile
        path: Theme.repoDir + "/quotes/chat.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.texts = JSON.parse(text()); } catch (e) { console.warn("Death: chat.json:", e); } }
    }
    readonly property string player: Theme.config.player || texts.player_default || "Nurasik"
    readonly property var ui: texts.death_screen || ({})
    function _pickMessage() {
        const list = texts.death_messages || ["{player} ran out of battery"];
        return list[Math.floor(Math.random() * list.length)].replace(/\{player\}/g, player);
    }

    // ---------------------------------------------------------------- cycle flags (survive a shell restart)
    readonly property string flagPath: GameEvents.runtimeDir + "/battery-cycle.json"
    FileView {
        id: flagFile
        path: root.flagPath
        blockLoading: true
        printErrors: false
    }
    function _readFlags() {
        try { const j = JSON.parse(flagFile.text()); hurtDone = !!j.hurt; deathDone = !!j.died; } catch (e) { hurtDone = false; deathDone = false; }
    }
    Process { id: flagWriter }
    function _saveFlags() {
        if (hurtDone || deathDone) {
            flagWriter.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", flagPath,
                                  JSON.stringify({ hurt: hurtDone, died: deathDone })];
        } else flagWriter.command = ["rm", "-f", flagPath];
        flagWriter.running = false;
        flagWriter.running = true;
    }
    Component.onCompleted: { _readFlags(); flagsLoaded = true; evaluate(); }

    // ---------------------------------------------------------------- the rules
    function evaluate() {
        if (!flagsLoaded || !present) return;
        if (charging) {
            confirm.stop(); confirm.ok = false;
            if (hurtDone || deathDone) { hurtDone = false; deathDone = false; _saveFlags(); }
            return;
        }
        if (creative || !discharging) return;      // Unknown/Empty/NotCharging states never count as dying
        if (percent <= 15 && !confirm.running && !confirm.ok) { confirm.start(); return; }   // must hold for 20 s
        if (!confirm.ok) return;
        const pct = percent;
        const dying = pct <= 5 && deathEnabled && !deathDone;
        if (pct <= 15 && !hurtDone) {
            hurtDone = true;
            if (!dying) InteractFx.sound("player.hurt");
            InteractFx.log("battery flash", pct);
            GameEvents.emit("battery", { percent: pct, charging: false, flash: true });
            _saveFlags();
        }
        if (dying) {
            deathDone = true;
            _saveFlags();
            show();
        }
    }
    // a low reading must survive 20 s of discharging before hurt/death fire (UPower glitches at boot/resume read 0 %)
    Timer {
        id: confirm
        property bool ok: false
        interval: 20000
        onTriggered: { ok = root.discharging && root.percent <= 15; root.evaluate(); }
    }
    onPercentChanged: { if (percent > 15) confirm.ok = false; evaluate(); }
    onDischargingChanged: evaluate()
    onChargingChanged: evaluate()
    onPresentChanged: evaluate()
    onCreativeChanged: evaluate()

    function show() {
        if (open) return;
        message = _pickMessage();
        score = Math.floor(SystemStats.uptimeHours * 60);
        InteractFx.sound("player.death");
        InteractFx.log("death screen", message, score);
        deathEvent.start();
        open = true;
    }
    // GameEvents.emit loses a line when two are emitted in the same tick (the first Process is still starting): keep them apart
    Timer { id: deathEvent; interval: 200; onTriggered: GameEvents.emit("death", {}) }
    function respawn() { open = false; }
    function titleScreen() {
        open = false;
        if (dryRun) { console.warn("DRYRUN loginctl lock-session"); return; }
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }

    // ---------------------------------------------------------------- the screen (on the focused output)
    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor;
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) if (m && list[i].name === m.name) return list[i];
        return list.length ? list[0] : null;
    }
    PanelWindow {
        id: win
        screen: root.focusedScreen
        WlrLayershell.namespace: "overworld-death"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open && !ShellState.preview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: false

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) { unmap.stop(); win.visible = true; screen.opened = true; screen.forceActiveFocus(); }
                else { screen.opened = false; unmap.restart(); }
            }
        }
        Timer { id: unmap; interval: Theme.guiFade + 40; onTriggered: if (!root.open) win.visible = false }

        McScreen {
            id: screen
            anchors.fill: parent
            background: "none"
            closeOnEscape: false
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.respawn();
                    event.accepted = true;
                }
            }

            Rectangle {    // the game's death-screen gradient: 0x60500000 at the top to 0xA0803030 at the bottom
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#60500000" }
                    GradientStop { position: 1; color: "#A0803030" }
                }
            }
            MouseArea { anchors.fill: parent }       // modal: nothing below gets clicks

            McText {                                  // "You died!" at 2× scale, y = 60 GUI px
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.px(60) - implicitHeight / 2
                units: 2
                text: root.ui.title || "You died!"
                color: "#ffffff"
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.px(85)
                width: Math.min(implicitWidth, parent.width - Theme.px(40))
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.message
                color: "#ffffff"
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.px(100)
                codes: "§f" + String(root.ui.score || "Score: {score}").replace("{score}", "§e" + root.score)
                darkGround: true
            }
            Column {
                id: buttons
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height / 4 / Theme.gui) * Theme.gui + Theme.px(72)
                spacing: Theme.px(4)
                McButton {
                    text: root.ui.respawn || "Respawn"
                    wide: true
                    onClicked: root.respawn()
                }
                McButton {
                    text: root.ui.title_screen || "Title Screen"
                    wide: true
                    onClicked: root.titleScreen()
                }
            }
        }
    }
}
