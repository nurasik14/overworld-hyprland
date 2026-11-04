import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  ChatOverlay — layer `overworld-chat`, bottom-left above the HUD. Always mapped (click-through while closed) so lines posted by
 *  system events show for 10 s and fade like the game's chat; open it (`chat open`, `chat command`) to type.
 *  Keys while open: Enter send · Esc close · Up/Down history · Tab / Shift+Tab complete · PageUp/PageDown or wheel scroll the log.
 *  Closed: ≤ 10 lines, each visible for Theme.ticks.chat_hold ticks and fading over chat_fade. Open: the last 20, no fading.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property bool onFocusedScreen: !Hyprland.focusedMonitor || !win.screen || Hyprland.focusedMonitor.name === win.screen.name
        readonly property bool chatOpen: GameUi.chatOpen && onFocusedScreen
        readonly property bool grabKeys: Quickshell.env("OW_NOFOCUS") !== "1"
        readonly property int g: Theme.gui
        readonly property int holdMs: Theme.ticksMs(Theme.ticks.chat_hold || 200) || 10000
        readonly property int fadeMs: Theme.ticksMs(Theme.ticks.chat_fade || 20) || 1000
        property double now: Date.now()
        property int scrollBack: 0

        WlrLayershell.namespace: "overworld-chat"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: win.chatOpen && win.grabKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; bottom: true }
        implicitWidth: Theme.px(344)
        implicitHeight: Theme.px(40 + 20 * 10 + 14 + 70)
        color: "transparent"
        mask: Region { x: 0; y: 0; width: win.chatOpen ? win.width : 0; height: win.chatOpen ? win.height : 0 }

        // keep the clock running only while something is on screen
        readonly property var visibleLines: {
            const all = ChatService.lines;
            const n = chatOpen ? 20 : 10;
            const out = [];
            const end = all.length - (chatOpen ? scrollBack : 0);
            for (let i = Math.max(0, end - n); i < end; i++) out.push(all[i]);
            return out;
        }
        readonly property bool fresh: ChatService.lines.length > 0 && (now - ChatService.lines[ChatService.lines.length - 1].t) < holdMs + 200
        Timer { interval: 100; repeat: true; running: win.fresh || win.chatOpen; onTriggered: win.now = Date.now() }
        Connections { target: ChatService; function onLinePosted(line) { win.now = Date.now(); win.scrollBack = 0; } }
        Connections { target: ChatService; function onCleared() { win.scrollBack = 0; } }

        onChatOpenChanged: {
            if (chatOpen) {
                Hyprland.refreshToplevels();
                input.text = GameUi.chatPrefill;
                input.cursorPosition = input.text.length;
                ChatService.histPos = -1; ChatService.resetCycle();
                scrollBack = 0;
                input.forceActiveFocus();
            }
        }

        // ------------------------------------------------------------ log
        Column {
            id: log
            x: win.g * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(win.chatOpen ? 14 : 40) + (win.chatOpen ? 0 : 0)
            width: Theme.px(330)
            Repeater {
                model: win.visibleLines
                Item {
                    id: row
                    required property var modelData
                    readonly property real age: win.now - modelData.t
                    readonly property real alpha: win.chatOpen ? 1 : Math.max(0, Math.min(1, (win.holdMs - age) / win.fadeMs))
                    visible: alpha > 0.01
                    width: log.width
                    height: visible ? Math.max(Theme.px(10), txt.implicitHeight) : 0
                    opacity: alpha
                    Rectangle { anchors.fill: parent; color: "#80000000" }
                    McText {
                        id: txt
                        x: Theme.px(2)
                        width: parent.width - Theme.px(4)
                        codes: row.modelData.text
                        color: row.modelData.color || Theme.hudText
                        darkGround: true
                        wrapMode: Text.Wrap
                    }
                    // advancement lines: hovering the green bracket shows the advancement like the game's hover text
                    McText { id: prefixMeasure; visible: false; text: row.modelData.hover ? row.modelData.hover.prefix : ""; color: "white" }
                    McText { id: labelMeasure; visible: false; text: row.modelData.hover ? row.modelData.hover.label : ""; color: "white" }
                    MouseArea {
                        id: hoverArea
                        enabled: win.chatOpen && row.modelData.hover !== null
                        x: txt.x + prefixMeasure.contentWidth
                        width: labelMeasure.contentWidth
                        height: parent.height
                        hoverEnabled: true
                    }
                    McTooltip {
                        visible: hoverArea.containsMouse && row.modelData.hover !== null
                        title: row.modelData.hover ? row.modelData.hover.title : ""
                        description: row.modelData.hover ? row.modelData.hover.description : ""
                        category: row.modelData.hover ? ({ task: "Advancement", goal: "Goal", challenge: "Challenge" })[row.modelData.hover.frame] || "" : ""
                        target: hoverArea; targetX: hoverArea.mouseX; targetY: hoverArea.mouseY
                    }
                }
            }
        }
        MouseArea {   // wheel scrolls the log while open
            anchors.fill: log
            enabled: win.chatOpen
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const d = wheel.angleDelta.y > 0 ? 3 : -3;
                win.scrollBack = Math.max(0, Math.min(Math.max(0, ChatService.lines.length - 20), win.scrollBack + d));
            }
        }

        // ------------------------------------------------------------ suggestions + usage
        readonly property var completion: win.chatOpen ? ChatService.completions(input.text) : ({ items: [], start: 0, prefix: "" })
        readonly property string usageLine: {
            const w = input.text.charAt(0) === "/" ? input.text.slice(1).split(/\s+/)[0].toLowerCase() : "";
            const s = ChatService.commandSpecs[w];
            return s && input.text.indexOf(" ") > 0 ? s.usage : "";
        }
        Column {
            id: suggest
            x: win.g * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(14)
            visible: win.chatOpen && (win.completion.items.length > 0 || win.usageLine.length > 0)
            z: 5
            Rectangle {
                visible: win.usageLine.length > 0
                width: Theme.px(330); height: Theme.px(11); color: "#d0101010"
                McText { x: Theme.px(2); y: Theme.px(1); text: win.usageLine; color: "#aaaaaa" }
            }
            Repeater {
                model: win.completion.items.slice(0, 8)
                Rectangle {
                    required property string modelData
                    required property int index
                    width: Theme.px(330); height: Theme.px(11)
                    color: "#d0101010"
                    readonly property bool picked: ChatService.cycle.index === index && ChatService.cycle.last === input.text
                    McText { x: Theme.px(2); y: Theme.px(1); text: parent.modelData; color: parent.picked ? "#ffff55" : "#aaaaaa" }
                }
            }
        }
        // ------------------------------------------------------------ input
        Rectangle {
            id: bar
            visible: win.chatOpen
            x: win.g * 2; width: Theme.px(330); height: Theme.px(12)
            anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(2)
            color: "#80000000"
            McText {
                x: Theme.px(2); y: Theme.px(1)
                visible: input.text.length === 0
                text: GameCore.t("misc.chat_placeholder") || "Chat message..."
                color: "#707070"
            }
            McTicker { id: blink; active: win.chatOpen }
            TextInput {
                id: input
                x: Theme.px(2); y: Theme.px(1)
                width: parent.width - Theme.px(4)
                color: "#ffffff"
                selectionColor: Theme.fieldSelection
                selectedTextColor: "#ffffff"
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontPx(1)
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.NativeRendering
                maximumLength: 256
                clip: true
                cursorDelegate: Rectangle { width: win.g; color: "#ffffff"; visible: Math.floor(blink.tick / 6) % 2 === 0 || Theme.reducedMotion }
                onTextEdited: ChatService.resetCycle()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { GameUi.closeChat(); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { input.text = ChatService.historyPrev(input.text); input.cursorPosition = input.text.length; event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { input.text = ChatService.historyNext(input.text); input.cursorPosition = input.text.length; event.accepted = true; }
                    else if (event.key === Qt.Key_Tab) { input.text = ChatService.tab(input.text, false); input.cursorPosition = input.text.length; event.accepted = true; }
                    else if (event.key === Qt.Key_Backtab) { input.text = ChatService.tab(input.text, true); input.cursorPosition = input.text.length; event.accepted = true; }
                    else if (event.key === Qt.Key_PageUp) { win.scrollBack = Math.min(Math.max(0, ChatService.lines.length - 20), win.scrollBack + 10); event.accepted = true; }
                    else if (event.key === Qt.Key_PageDown) { win.scrollBack = Math.max(0, win.scrollBack - 10); event.accepted = true; }
                }
                onAccepted: {
                    const t = input.text;
                    input.text = "";
                    GameUi.closeChat();
                    ChatService.submit(t);
                }
            }
        }
    }
}
