import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  WorkspaceCard — the /title command, on every switch to workspace 1–10: big title + subtitle, the game's tick timings
 *  (fade-in 10, stay 70, fade-out 20; 1 tick = 50 ms). The title is your workspace title or quotes/titles.json's default for that
 *  slot; the subtitle is your note, else a line for the dominant app. A reveal while it is up keeps it up and swaps the text.
 *  Settings (config.json → "workspace_card"): enabled true · duration (ms, overrides the 70 ticks of stay) · position "center"|"top"|"bottom"
 *  · show_untitled true.  reveal(id) shows it on demand (IPC `workspace reveal <id>`). Namespace overworld-wscard, click-through.
 */
Scope {
    id: root
    property int wid: 1
    property bool shown: false
    property bool armed: false          // ignore the focus "change" Hyprland reports while the shell starts
    property string titleText: ""
    property string subtitleText: ""

    readonly property bool enabled: ConfigService.get("workspace_card.enabled", true) !== false
    readonly property int stayMs: {
        const d = Number(ConfigService.get("workspace_card.duration", 0));
        return d > 0 ? Math.max(800, d) : (Theme.ticks.title_stay || 70) * 50;
    }
    readonly property string position: String(ConfigService.get("workspace_card.position", "center"))
    readonly property bool showUntitled: ConfigService.get("workspace_card.show_untitled", true) !== false

    function reveal(id) {
        if (id < 1 || id > 10) return;               // special/scratchpad workspaces have negative ids
        root.wid = id;
        if (!WorkspaceNotes.has(id) && !root.showUntitled) { root.shown = false; return; }
        const info = HyprlandState.info(id);
        root.titleText = WorkspaceNotes.displayTitle(id);
        root.subtitleText = WorkspaceNotes.subtitle(id, info.cls, info.count) + (WorkspaceNotes.isAuto(id) ? " · auto" : "");
        root.shown = true;
        hideTimer.restart();
    }
    function hide() { root.shown = false; }

    Timer { id: hideTimer; interval: Theme.ticksMs(Theme.ticks.title_in || 10) + root.stayMs; onTriggered: root.shown = false }
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }

    Connections {
        target: HyprlandState
        function onFocusedIdChanged() {
            if (root.armed && root.enabled) root.reveal(HyprlandState.focusedId);
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool onFocusedScreen: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === modelData.name

            WlrLayershell.namespace: "overworld-wscard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            // "center" = no anchors (layer-shell centres the surface); top/bottom keep clear of the toasts and the HUD
            anchors.left: true
            anchors.right: true
            anchors.top: root.position === "top"
            anchors.bottom: root.position === "bottom"
            margins.top: Theme.px(40)
            margins.bottom: Theme.px(70)
            implicitHeight: Theme.px(64)
            color: "transparent"
            mask: Region {}                                  // never steals a click
            visible: win.onFocusedScreen && (root.shown || content.opacity > 0.004)

            Item {
                id: content
                anchors.fill: parent
                opacity: root.shown ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ticksMs(root.shown ? (Theme.ticks.title_in || 10) : (Theme.ticks.title_out || 20))
                        easing.type: Easing.Linear
                    }
                }

                McText {   // /title draws at 4× the font, the subtitle at 2×; a long title drops to 2× before it would leave the screen
                    id: titleLine
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: subtitleLine.top
                    units: fitProbe.implicitWidth > parent.width - Theme.px(20) ? 2 : 4
                    width: Math.min(implicitWidth, parent.width - Theme.px(20))
                    elide: Text.ElideRight
                    text: root.titleText
                    color: Theme.hudText
                }
                Text {   // measures the title at 4× without drawing it
                    id: fitProbe
                    visible: false
                    text: root.titleText
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontPx(4)
                }
                McText {
                    id: subtitleLine
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    visible: root.subtitleText.length > 0
                    units: 2
                    width: Math.min(implicitWidth, parent.width - Theme.px(20))
                    elide: Text.ElideRight
                    text: root.subtitleText
                    color: Theme.hudText
                }
            }
        }
    }
}
