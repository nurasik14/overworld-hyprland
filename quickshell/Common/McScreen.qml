import QtQuick
import qs.Common

/*  McScreen — a full-screen GUI layer: dimmed background, centred title, Esc closes, fast fade (≤ 150 ms).
 *  Fill a layer window with it; the window itself (keyboard focus, namespace) stays with the owner.
 *    title: string          white, centred at titleY GUI px; "" hides it
 *    titleY: int            GUI px from the top; default 20 (the game's Options) — the pause menu uses 40
 *    background: "gradient"|"menu"
 *        gradient  the in-world menu gradient #C0101010 → #D0101010 (default)
 *        menu      the 1.21 list screen: translucent gui/menu_background over the world, a darker gui/menu_list_background between
 *                  the header and footer separators at headerHeight/footerHeight (the wallpaper plays the panorama)
 *    headerHeight, footerHeight: int   GUI px; default 33
 *    opened: bool           visible state; open(), close(), toggle()
 *    closeOnEscape: bool    default true
 *    content                default property: children fill the screen below; use anchors.centerIn etc.
 *    signals opening(), closed() (after the fade)
 *
 *    McScreen { id: menu; title: "Game Menu"; titleY: 40
 *        Column { anchors.centerIn: parent; McButton { text: "Back to Game"; wide: true; onClicked: menu.close() } }
 *    }
 */
FocusScope {
    id: root
    property string title: ""
    property int titleY: 20
    property string background: "gradient"
    property int headerHeight: 33
    property int footerHeight: 33
    property bool opened: false
    property bool closeOnEscape: true
    default property alias content: contentArea.data
    readonly property alias contentItem: contentArea
    signal opening()
    signal closed()

    function open() { if (!opened) { opened = true; opening(); forceActiveFocus(); } }
    function close() { if (opened) opened = false; }
    function toggle() { opened ? close() : open(); }

    opacity: opened ? 1 : 0
    visible: opened || opacity > 0      // opened first: an invisible item cannot take the focus open() gives it
    Behavior on opacity {
        SequentialAnimation {
            NumberAnimation { duration: Theme.guiFade; easing.type: Theme.easeGui }
            ScriptAction { script: if (!root.opened) root.closed() }
        }
    }
    Keys.onEscapePressed: event => {
        if (root.closeOnEscape) { root.close(); event.accepted = true; }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.background === "gradient"
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.menuGradientTop }
            GradientStop { position: 1; color: Theme.menuGradientBottom }
        }
    }
    Item {
        anchors.fill: parent
        visible: root.background === "menu"
        McNineSlice {
            anchors.fill: parent
            sprite: visible ? "gui/menu_background" : ""
            scaling: ({ type: "tile", width: 16, height: 16 })
        }
        McNineSlice {
            anchors { left: parent.left; right: parent.right }
            y: Theme.px(root.headerHeight)
            height: parent.height - Theme.px(root.headerHeight + root.footerHeight)
            sprite: visible ? "gui/menu_list_background" : ""
            scaling: ({ type: "tile", width: 16, height: 16 })
        }
        McNineSlice {
            anchors { left: parent.left; right: parent.right }
            y: Theme.px(root.headerHeight) - Theme.px(2)
            height: Theme.px(2)
            sprite: visible ? "gui/header_separator" : ""
            scaling: ({ type: "tile", width: 32, height: 2 })
        }
        McNineSlice {
            anchors { left: parent.left; right: parent.right }
            y: parent.height - Theme.px(root.footerHeight)
            height: Theme.px(2)
            sprite: visible ? "gui/footer_separator" : ""
            scaling: ({ type: "tile", width: 32, height: 2 })
        }
    }
    MouseArea {   // the layer eats clicks that hit no widget, like the game
        anchors.fill: parent
    }
    McText {
        visible: root.title.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(root.titleY - 1)
        text: root.title
        color: Theme.hudText
    }
    Item {
        id: contentArea
        anchors.fill: parent
    }
}
