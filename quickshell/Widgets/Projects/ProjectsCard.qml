import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  ProjectsCard — "Projects" (190 × 150 GUI px): a Book and Quill's to-do list, what is built and what is still in progress.
 *  Two sections: In Progress (unchecked, file order) and Built (checked, grey and struck through, newest first, the latest 5 then
 *  "+N more"; click the Built header to fold it).  Each row: the game's checkbox (click = toggle; `xp.orb` when it becomes built,
 *  `ui.click` otherwise), the title (elided, hover = tooltip with the note and dates), a ✕ that shows on hover.  Remove asks no
 *  question: the card offers "Undo" for 5 s instead (also /project undo).  Double-click a title = edit in the dialog, the "+" in
 *  the title bar = add.  Empty at first: it never invents projects.  Data and every other way in (chat /project, the
 *  CLI `overworld projects`, IPC target projects): ProjectsService.  Typing happens in Projects/ProjectsDialog.qml, a layer that
 *  takes the keyboard (this widget layer never does).  Becoming built posts "Nurasik built [Title]!" in the chat (ChatService).
 */
WidgetCard {
    id: card
    title: "Projects"
    guiW: 190
    guiH: 150

    readonly property var svc: ProjectsService
    property bool builtOpen: true          // the Built section is unfolded
    property bool builtAll: false          // …and shows more than the latest 5
    property int pinHover: -1              // previews only: row number (0-based, in list order) drawn as hovered
    property bool pinTip: false            // previews only: …with its tooltip
    readonly property int builtShown: builtAll ? svc.built.length : Math.min(5, svc.built.length)
    readonly property int hiddenBuilt: svc.built.length - builtShown

    function toggleItem(it) {
        Theme.playSound(it.status === "built" ? "ui.click" : "xp.orb");
        svc.toggle(it.id);
    }
    function removeItem(it) {
        Theme.playSound("ui.click");
        svc.remove(it.id);
    }

    // "+" in the title bar (above the drag handle, which would otherwise swallow the click)
    McButton {
        parent: card
        z: 200
        x: card.width - Theme.px(8 + 16); y: Theme.px(2)
        width: Theme.px(16); height: Theme.px(13)
        horizontalPadding: 0
        text: "+"
        tooltip: "Add a project"
        tooltipDescription: "or /project add <name> in the chat"
        activeFocusOnTab: false
        onClicked: card.svc.openDialog("")
    }

    // ---- empty state
    Item {
        anchors.fill: parent
        visible: card.svc.count === 0
        McItemIcon {
            x: Theme.px(72); y: Theme.px(10)
            size: 32
            name: "writable_book"
        }
        McText {
            y: Theme.px(52); width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No projects yet"
            color: Theme.guiText
        }
        McText {
            y: Theme.px(66); width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            text: "Click +, or type\n/project add <name>"
            color: Theme.textMuted
        }
    }

    // ---- the list
    Flickable {
        id: flick
        visible: card.svc.count > 0
        x: 0; y: 0
        width: Theme.px(176 - 8); height: Theme.px(126)
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: flick.width

            // In Progress
            Item {
                width: parent.width; height: Theme.px(11)
                McText { x: 0; anchors.verticalCenter: parent.verticalCenter; text: "In Progress"; color: Theme.guiText }
                McText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: card.svc.inProgress.length
                    color: Theme.textMuted
                }
            }
            Repeater {
                model: card.svc.inProgress
                ProjectRow {
                    required property var modelData
                    required property int index
                    hoverPin: card.pinHover === index
                    tipPin: card.pinTip && card.pinHover === index
                    width: col.width
                    item: modelData
                    onToggled: it => card.toggleItem(it)
                    onRemoveRequested: it => card.removeItem(it)
                    onEditRequested: it => card.svc.openDialog(it.id)
                }
            }
            McText {
                visible: card.svc.inProgress.length === 0
                width: parent.width; height: Theme.px(13)
                verticalAlignment: Text.AlignVCenter
                text: "Nothing in progress, start one with +"
                color: Theme.textMuted
                elide: Text.ElideRight
            }
            Item { width: 1; height: Theme.px(3) }

            // Built ✔
            Item {
                visible: card.svc.built.length > 0
                width: parent.width; height: Theme.px(11)
                PixelGlyph {
                    id: fold
                    x: 0; anchors.verticalCenter: parent.verticalCenter
                    kind: card.builtOpen ? "down" : "right"
                    color: Theme.guiText
                }
                McText {
                    id: builtTitle
                    x: Theme.px(10); anchors.verticalCenter: parent.verticalCenter
                    text: "Built"
                    color: Theme.guiText
                }
                PixelGlyph {
                    x: builtTitle.x + builtTitle.width + Theme.px(4); anchors.verticalCenter: parent.verticalCenter
                    kind: "check"
                    color: Theme.chatReadable("a")
                }
                McText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: card.svc.built.length
                    color: Theme.textMuted
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.builtOpen = !card.builtOpen
                }
            }
            Repeater {
                model: card.builtOpen ? card.svc.built.slice(0, card.builtShown) : []
                ProjectRow {
                    required property var modelData
                    required property int index
                    hoverPin: card.pinHover === card.svc.inProgress.length + index
                    tipPin: card.pinTip && card.pinHover === card.svc.inProgress.length + index
                    width: col.width
                    item: modelData
                    onToggled: it => card.toggleItem(it)
                    onRemoveRequested: it => card.removeItem(it)
                    onEditRequested: it => card.svc.openDialog(it.id)
                }
            }
            Item {
                visible: card.builtOpen && (card.hiddenBuilt > 0 || card.builtAll) && card.svc.built.length > 5
                width: parent.width; height: Theme.px(13)
                McText {
                    x: Theme.px(15); anchors.verticalCenter: parent.verticalCenter
                    text: card.builtAll ? "Show less" : "+" + card.hiddenBuilt + " more"
                    color: Theme.link
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.builtAll = !card.builtAll
                }
            }
        }
    }
    McScrollbar {
        flickable: flick
        visible: flick.visible && scrollable
        x: Theme.px(176 - 6); y: 0
        height: flick.height
    }

    // ---- undo bar (5 s after a remove)
    Rectangle {
        visible: card.svc.undo !== null
        x: 0; y: Theme.px(126 - 15)
        width: Theme.px(176); height: Theme.px(15)
        color: Theme.isDark ? "#e0101010" : "#f0373737"
        border.width: Theme.gui; border.color: "#000000"
        McText {
            x: Theme.px(4); y: 0
            width: parent.width - Theme.px(4 + 34)
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: card.svc.undo ? (card.svc.undo.count > 1 ? "Removed " + card.svc.undo.count + " projects" : "Removed " + card.svc.undo.title) : ""
            color: "#ffffff"
            elide: Text.ElideRight
        }
        McButton {
            x: parent.width - Theme.px(33); y: Theme.px(1)
            width: Theme.px(32); height: Theme.px(13)
            horizontalPadding: 0
            text: "Undo"
            activeFocusOnTab: false
            onClicked: card.svc.undoRemove()
        }
    }
}
