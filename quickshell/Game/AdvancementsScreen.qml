import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  AdvancementsScreen — layer `overworld-advancements` (IPC `advancements open`). The game's advancement window: tabs above
 *  (root advancement icon, selected one joins the window), tiled tab background, the tree with task/goal/challenge frames,
 *  connecting lines, hover box with title / description / progress, drag or wheel to pan. Keys: Tab / Shift+Tab or 1–5 switch tab,
 *  arrows pan, Home recentres, Esc closes. Below the window: Reset Advancements (→ AdvancementsConfirm) and Done.
 */
Variants {
    model: Quickshell.screens

    ScreenWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-advancements"
        open: GameUi.advancementsOpen
        onCloseRequested: GameUi.close("advancements")

        readonly property int g: Theme.gui
        property int tabIndex: 0
        readonly property var tab: Advancements.tabs.length ? Advancements.tabs[Math.min(tabIndex, Advancements.tabs.length - 1)] : null
        readonly property int guiW: Math.max(200, Math.min(400, Math.floor(win.width / g) - 30))
        readonly property int guiH: Math.max(120, Math.min(300, Math.floor(win.height / g) - 70))
        property var hovered: null          // advancement under the pointer
        property real hoverX: 0
        property real hoverY: 0
        property bool confirmReset: false

        function recentre() {
            if (!tab) return;
            const innerH = (guiH - 27) * g;
            const rootY = (Advancements.byId[tab.root] ? Advancements.byId[tab.root].y : 0) + 13;
            tree.x = Theme.px(14);
            tree.y = Math.round(innerH / 2 - rootY * g);
            clampPan();
        }
        function clampPan() {
            if (!tab) return;
            const innerW = (guiW - 18) * g, innerH = (guiH - 27) * g;
            const tw = (tab.width - Advancements.nodeDx + 26) * g, th = (tab.height - Advancements.nodeDy + 26) * g;
            const margin = Theme.px(14);
            if (tw + 2 * margin <= innerW) tree.x = margin;
            else tree.x = Math.max(innerW - tw - margin, Math.min(margin, tree.x));
            if (th + 2 * margin <= innerH) tree.y = Math.round((innerH - th) / 2);
            else tree.y = Math.max(innerH - th - margin, Math.min(margin, tree.y));
        }
        function setTab(i) {
            if (Advancements.tabs.length === 0) return;
            const n = Advancements.tabs.length;
            const next = (i + n) % n;
            if (next !== tabIndex) Theme.playSound("book.page");
            tabIndex = next; hovered = null; recentre();
        }
        onShownChanged: { if (shown) { hovered = null; Qt.callLater(recentre); } else confirmReset = false; }
        onGuiHChanged: Qt.callLater(recentre)
        onGuiWChanged: Qt.callLater(recentre)
        function hover(adv) {      // places the hover box at the node (pointer entered, or IPC `advancements inspect`)
            hoverX = inner.x + tree.x + adv.x * g;
            hoverY = inner.y + tree.y + adv.y * g;
            hovered = adv;
        }
        Connections {
            target: AdvancementsState
            function onTabRequested(id) { const i = Advancements.tabs.findIndex(t => t.id === id); if (i >= 0) win.setTab(i); }
            function onResetDialogRequested() { GameUi.open("advancements"); Qt.callLater(() => { win.confirmReset = true; }); }
            function onInspectRequested(id) {
                const a = Advancements.byId[id];
                if (!a) return;
                win.setTab(Advancements.tabs.findIndex(t => t.id === a.tab));
                Qt.callLater(() => win.hover(a));
            }
        }
        Component.onCompleted: Qt.callLater(recentre)

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                const step = Theme.px(16);
                if (event.key === Qt.Key_Tab) { win.setTab(win.tabIndex + 1); event.accepted = true; }
                else if (event.key === Qt.Key_Backtab) { win.setTab(win.tabIndex - 1); event.accepted = true; }
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) { win.setTab(event.key - Qt.Key_1); event.accepted = true; }
                else if (event.key === Qt.Key_Left) { tree.x += step; win.clampPan(); event.accepted = true; }
                else if (event.key === Qt.Key_Right) { tree.x -= step; win.clampPan(); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { tree.y += step; win.clampPan(); event.accepted = true; }
                else if (event.key === Qt.Key_Down) { tree.y -= step; win.clampPan(); event.accepted = true; }
                else if (event.key === Qt.Key_Home) { win.recentre(); event.accepted = true; }
            }

            Item {
                id: frameBox
                width: win.guiW * win.g; height: win.guiH * win.g
                anchors.centerIn: parent

                // tab background, tiled, clipped to the inner area
                Item {
                    id: inner
                    x: Theme.px(9); y: Theme.px(18)
                    width: Theme.px(win.guiW - 18); height: Theme.px(win.guiH - 27)
                    clip: true
                    McNineSlice {
                        x: -Theme.px(16) + (tree.x % Theme.px(16)); y: -Theme.px(16) + (tree.y % Theme.px(16))
                        width: inner.width + Theme.px(32); height: inner.height + Theme.px(32)
                        sprite: win.tab ? win.tab.background : ""
                        scaling: ({ type: "tile", width: 16, height: 16 })
                    }
                    // a little shade so Night keeps the dark look
                    Rectangle { anchors.fill: parent; color: "#000000"; opacity: Theme.isDark ? 0.25 : 0 }

                    MouseArea {
                        id: pan
                        anchors.fill: parent
                        hoverEnabled: true
                        drag.target: tree
                        drag.axis: Drag.XAndYAxis
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
                        onPositionChanged: { if (drag.active) win.hovered = null; win.clampPan(); }
                        onReleased: win.clampPan()
                        onWheel: wheel => { tree.y += wheel.angleDelta.y > 0 ? Theme.px(14) : -Theme.px(14); tree.x += wheel.angleDelta.x > 0 ? Theme.px(14) : (wheel.angleDelta.x < 0 ? -Theme.px(14) : 0); win.clampPan(); }
                        onClicked: win.hovered = null
                    }

                    Item {
                        id: tree
                        // lines first, then the frames
                        Repeater {
                            model: win.tab ? win.tab.items : []
                            Item {
                                id: edges
                                required property var modelData
                                readonly property var adv: modelData
                                Repeater {
                                    model: edges.adv.parent && (!edges.adv.hidden || Advancements.isUnlocked(edges.adv.id)) ? [edges.adv.parent] : []
                                    Item {
                                        id: line
                                        required property string modelData
                                        readonly property var p: Advancements.byId[modelData]
                                        readonly property bool done: Advancements.isUnlocked(edges.adv.id)
                                        readonly property real x0: (p.x + 13) * win.g
                                        readonly property real y0: (p.y + 13) * win.g
                                        readonly property real x1: (edges.adv.x + 13) * win.g
                                        readonly property real y1: (edges.adv.y + 13) * win.g
                                        readonly property real xm: Math.round(((p.x + 26 + edges.adv.x) / 2) * win.g / win.g) * win.g
                                        readonly property color inner: done ? "#ffffff" : "#808080"
                                        // 3 GUI px black shadow, 1 GUI px coloured line (the game's connectors)
                                        Repeater {
                                            model: [
                                                { x: Math.min(line.x0, line.xm) - win.g, y: line.y0 - win.g, w: Math.abs(line.xm - line.x0) + 3 * win.g, h: 3 * win.g, c: "#000000" },
                                                { x: line.xm - win.g, y: Math.min(line.y0, line.y1) - win.g, w: 3 * win.g, h: Math.abs(line.y1 - line.y0) + 3 * win.g, c: "#000000" },
                                                { x: Math.min(line.xm, line.x1) - win.g, y: line.y1 - win.g, w: Math.abs(line.x1 - line.xm) + 3 * win.g, h: 3 * win.g, c: "#000000" },
                                                { x: Math.min(line.x0, line.xm), y: line.y0, w: Math.abs(line.xm - line.x0) + win.g, h: win.g, c: line.inner },
                                                { x: line.xm, y: Math.min(line.y0, line.y1), w: win.g, h: Math.abs(line.y1 - line.y0) + win.g, c: line.inner },
                                                { x: Math.min(line.xm, line.x1), y: line.y1, w: Math.abs(line.x1 - line.xm) + win.g, h: win.g, c: line.inner }
                                            ]
                                            Rectangle { required property var modelData; x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; color: modelData.c }
                                        }
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: win.tab ? win.tab.items : []
                            Item {
                                id: node
                                required property var modelData
                                readonly property var adv: modelData
                                readonly property bool done: Advancements.isUnlocked(adv.id)
                                readonly property bool masked: adv.hidden === true && !done
                                visible: !masked
                                x: adv.x * win.g; y: adv.y * win.g
                                width: Theme.px(26); height: Theme.px(26)
                                McSprite { anchors.fill: parent; sprite: "advancements/" + node.adv.frame + "_frame_" + (node.done ? "obtained" : "unobtained") }
                                McItemIcon { x: Theme.px(5); y: Theme.px(5); source: Advancements.iconUrl(node.adv.icon); opacity: node.done ? 1 : 0.55 }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: win.hover(node.adv)
                                    onExited: if (win.hovered === node.adv) win.hovered = null
                                }
                            }
                        }
                    }
                }

                AdvFrame { guiWidth: win.guiW; guiHeight: win.guiH }

                // header text: title left, progress right
                McText {
                    x: Theme.px(8); y: Theme.px(6) - Theme.px(1)
                    text: "Advancements"
                    guiTitle: true
                }
                McText {
                    anchors.right: parent.right; anchors.rightMargin: Theme.px(8)
                    y: Theme.px(6) - Theme.px(1)
                    readonly property var c: win.tab ? Advancements.tabCounts(win.tab.id) : ({ done: 0, total: 0 })
                    text: win.tab ? win.tab.title + "  " + c.done + "/" + c.total : ""
                    guiTitle: true
                }

                // tabs above the window
                Repeater {
                    model: Advancements.tabs
                    Item {
                        id: tabItem
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === win.tabIndex
                        readonly property bool isLast: index === Advancements.tabs.length - 1
                        x: Theme.px(4 + index * 32); y: -Theme.px(28)
                        width: Theme.px(28); height: Theme.px(32)
                        z: selected ? 2 : 1
                        McSprite {
                            anchors.fill: parent
                            sprite: "advancements/tab_above_" + (tabItem.index === 0 ? "left" : tabItem.isLast ? "right" : "middle") + (tabItem.selected ? "_selected" : "")
                            nightRemap: Theme.isDark
                        }
                        McItemIcon { x: Theme.px(6); y: Theme.px(9); source: Advancements.iconUrl(tabItem.modelData.icon) }
                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.setTab(tabItem.index)
                        }
                        McTooltip {
                            visible: tabArea.containsMouse
                            title: tabItem.modelData.title
                            description: Advancements.tabCounts(tabItem.modelData.id).done + " of " + Advancements.tabCounts(tabItem.modelData.id).total + " advancements"
                            target: tabArea; targetX: tabArea.mouseX; targetY: tabArea.mouseY
                        }
                    }
                }

                // bottom bar: Reset Advancements (asks first) + Done
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height + Theme.px(5)
                    spacing: Theme.px(6)
                    McButton {
                        text: "Reset Advancements"
                        width: Theme.px(150)
                        activeFocusOnTab: false
                        onClicked: win.confirmReset = true
                    }
                    McButton {
                        text: "Done"
                        width: Theme.px(98)
                        activeFocusOnTab: false
                        onClicked: win.closeRequested()
                    }
                }

                // hover box (the game's title_box / box_obtained sprites) drawn above everything
                Item {
                    id: hoverBox
                    visible: win.hovered !== null
                    z: 20
                    readonly property var adv: win.hovered || ({ title: "", description: "", frame: "task", id: "" })
                    readonly property bool done: win.hovered ? Advancements.isUnlocked(adv.id) : false
                    readonly property var prog: win.hovered ? Advancements.progress(adv.id) : ({ text: "" })
                    readonly property string status: done ? "Obtained " + Qt.formatDateTime(new Date(Advancements.unlockedAt(adv.id)), "d MMM HH:mm") : prog.text
                    readonly property int textW: Math.max(titleText.implicitWidth, Math.min(Theme.px(180), descText.implicitWidth), statusText.implicitWidth)
                    width: Theme.px(29 + 8) + textW
                    height: Theme.px(7 + 12 + 5) + descText.height + (status.length ? Theme.px(10) : 0)
                    x: Math.min(win.hoverX - Theme.px(3), frameBox.width - width - Theme.px(4))
                    y: Math.max(Theme.px(10), Math.min(win.hoverY, frameBox.height - height - Theme.px(4)))
                    McNineSlice { anchors.fill: parent; sprite: "advancements/" + (hoverBox.done ? "box_obtained" : "box_unobtained") }
                    McText { id: titleText; x: Theme.px(29); y: Theme.px(6); text: hoverBox.adv.title; color: "#ffffff" }
                    McText {
                        id: descText
                        x: Theme.px(29); y: Theme.px(18)
                        width: Math.min(Theme.px(180), implicitWidth)
                        text: hoverBox.adv.description
                        color: "#ffffff"
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.FixedHeight; lineHeight: Theme.px(9)
                    }
                    McText {
                        id: statusText
                        x: Theme.px(29); y: descText.y + descText.height + Theme.px(2)
                        visible: hoverBox.status.length > 0
                        text: hoverBox.status
                        color: hoverBox.done ? "#ffffff" : "#ffff55"
                    }
                    McSprite {   // the frame sits over the left end of the box, exactly over the node's own frame
                        x: Theme.px(3); y: 0
                        sprite: "advancements/" + hoverBox.adv.frame + "_frame_" + (hoverBox.done ? "obtained" : "unobtained")
                    }
                    McItemIcon { x: Theme.px(8); y: Theme.px(5); source: Advancements.iconUrl(hoverBox.adv.icon) }
                }
            }

            AdvancementsConfirm {
                z: 50
                shown: win.confirmReset
                title: "Reset all advancements?"
                detail: "This cannot be undone."
                onConfirmed: { win.confirmReset = false; Advancements.reset(); win.hovered = null; stage.forceActiveFocus(); }
                onCancelled: { win.confirmReset = false; stage.forceActiveFocus(); }
            }
        }
    }
}
