import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  WorkspaceCard — a paper slip that floats in for a moment when you switch to workspace 1–10 and tells you
 *  what that workspace is for:   [三 seal]  Title
 *                                          WORKSPACE 3
 *                                          your note …
 *  Text comes from WorkspaceNotes (~/.config/overworld/workspaces.json, set with `overworld ws`).
 *  Settings (config.json → "workspace_card"):
 *    enabled true · duration 2600 (ms) · position "top" | "center" | "bottom" · show_untitled true
 *  reveal(id) shows it on demand (IPC `workspace reveal <id>`).  Layer namespace overworld-wscard, click-through.
 */
Scope {
    id: root
    property int wid: 1
    property bool shown: false
    property bool armed: false          // ignore the focus "change" Hyprland reports while the shell starts

    readonly property bool enabled: ConfigService.get("workspace_card.enabled", true) !== false
    readonly property int duration: Math.max(800, Number(ConfigService.get("workspace_card.duration", 2600)) || 2600)
    readonly property string position: String(ConfigService.get("workspace_card.position", "top"))
    readonly property bool showUntitled: ConfigService.get("workspace_card.show_untitled", true) !== false

    readonly property string title: WorkspaceNotes.title(wid)
    readonly property string note: WorkspaceNotes.note(wid)

    function reveal(id) {
        if (id < 1 || id > 10) return;               // special/scratchpad workspaces have negative ids
        root.wid = id;
        if (!WorkspaceNotes.has(id) && !root.showUntitled) { root.shown = false; return; }
        root.shown = true;
        hideTimer.restart();
    }
    function hide() { root.shown = false; }

    Timer { id: hideTimer; interval: root.duration; onTriggered: root.shown = false }
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
            // "center" = no anchors (layer-shell centres the surface); top/bottom hang below the bar / above the OSD
            anchors.top: root.position === "top"
            anchors.bottom: root.position === "bottom"
            margins.top: (Theme.sizes.bar_height || 36) + 28
            margins.bottom: 150
            implicitWidth: card.width + 24
            implicitHeight: card.height + 24
            color: "transparent"
            mask: Region {}                                  // never steals a click
            visible: win.onFocusedScreen && (root.shown || card.opacity > 0.01)

            Rectangle {
                id: card
                readonly property int pad: Theme.space.md
                // title and note each grow up to ~50 characters (measured in their own font); then the title
                // elides and the note wraps.  TextMetrics, not implicitWidth: an elided Text reports its clipped width.
                readonly property int titleMax: Math.ceil(titleLine.advanceWidth) + 4
                readonly property int noteMax: Math.ceil(noteLine.advanceWidth) + 4
                readonly property int textWidth: Math.max(160, Math.ceil(subMetrics.advanceWidth) + 4,
                                                          Math.min(titleMax, Math.ceil(titleMetrics.advanceWidth) + 4),
                                                          Math.min(noteMax, Math.ceil(noteMetrics.advanceWidth) + 4))
                anchors.centerIn: parent
                width: pad * 2 + seal.width + Theme.space.lg + textWidth
                height: Math.max(seal.height, textCol.implicitHeight) + pad * 2
                radius: Theme.radius.md
                color: Theme.withAlpha(Theme.surface, 0.94)
                border.width: Theme.border.frame
                border.color: Theme.frame

                opacity: root.shown ? 1 : 0
                transform: Translate { y: root.shown ? 0 : (root.position === "bottom" ? 12 : -12) }
                Behavior on opacity {
                    NumberAnimation {
                        duration: ConfigService.reducedMotion ? 0 : (root.shown ? Theme.durBase : Theme.durSlow)
                        easing.type: root.shown ? Theme.easeInk : Theme.easeBrush
                    }
                }
                Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
                Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }

                Rectangle {   // scroll-mount double rule
                    anchors.fill: parent; anchors.margins: 4
                    radius: Math.max(2, parent.radius - 3)
                    color: "transparent"; border.width: 1; border.color: Theme.hairline
                }

                Seal {
                    id: seal
                    x: card.pad + 2
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    rough: false
                    glyph: TimeService.numeral(root.wid)
                    label: "Workspace " + root.wid
                }

                Column {
                    id: textCol
                    x: seal.x + seal.width + Theme.space.lg
                    width: card.textWidth
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        id: titleText
                        width: parent.width
                        text: root.title.length > 0 ? root.title : "Workspace " + root.wid
                        // CJK titles get the brush face, Latin ones the display serif
                        font.family: /[\u3040-\u30ff\u3400-\u9fff]/.test(text) ? Theme.brushFamilyFor(text) : Theme.fontSerif
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                    InkText {
                        id: subText
                        width: parent.width
                        role: "small"
                        muted: true
                        font.letterSpacing: root.title.length > 0 ? 2 : 0
                        font.capitalization: root.title.length > 0 ? Font.AllUppercase : Font.MixedCase
                        text: root.title.length > 0 ? "Workspace " + root.wid + (WorkspaceNotes.isAuto(root.wid) ? " · auto" : "")
                                                    : "no title yet · overworld ws " + root.wid
                    }
                    Rectangle {   // ink rule between label and note
                        visible: root.note.length > 0
                        width: Math.min(parent.width, 120); height: 1
                        color: Theme.hairline
                    }
                    InkText {
                        id: noteText
                        visible: root.note.length > 0
                        width: Math.min(parent.width, card.noteMax)
                        role: "body_latin"
                        text: root.note
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
                readonly property string fifty: "The quick brown fox jumps over the lazy dog again."   // 50 chars
                TextMetrics { id: titleMetrics; font: titleText.font; text: titleText.text }
                TextMetrics { id: titleLine; font: titleText.font; text: card.fifty }
                TextMetrics { id: subMetrics; font: subText.font; text: subText.text }
                TextMetrics { id: noteMetrics; font: noteText.font; text: root.note }
                TextMetrics { id: noteLine; font: noteText.font; text: card.fifty }
            }
        }
    }
}
