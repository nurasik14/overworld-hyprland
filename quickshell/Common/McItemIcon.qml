import QtQuick
import QtQuick.Effects
import qs.Common

/*  McItemIcon — an item or block icon, nearest-neighbour scaled.
 *    name: string     item name ("compass", "command_block"): assets/icons/mc → assets/gen/icons → item/ → block/ → missing
 *    app: string      app class ("kitty"): name comes from tokens/items.json through Theme.itemFor
 *    appTitle: string window title, for the title rules in items.json (kitty running nvim → writable_book)
 *    source: url      explicit image (e.g. an app icon file) instead of name/app
 *    size: int        GUI px per side, default 16
 *    glint: bool      enchanted shimmer: scrolling misc/enchanted_glint_item, masked to the icon's shape
 *
 *    McItemIcon { app: "kitty"; appTitle: windowTitle }
 *    McItemIcon { name: "golden_apple"; glint: true }
 */
Item {
    id: root
    property string name: ""
    property string app: ""
    property string appTitle: ""
    property url source: ""
    property int size: 16
    property bool glint: false
    readonly property string resolvedName: name.length ? name : (app.length ? Theme.itemFor(app, appTitle) : "")
    readonly property url resolved: source.toString().length ? source : (resolvedName.length ? Theme.iconUrl(resolvedName) : "")

    implicitWidth: Theme.px(size)
    implicitHeight: Theme.px(size)

    Image {
        id: icon
        anchors.fill: parent
        source: root.resolved
        smooth: false
        mipmap: false
        fillMode: Image.PreserveAspectFit
        layer.enabled: root.glint
        layer.smooth: false
        onStatusChanged: if (status === Image.Error && source.toString() !== Theme.missingTexture) source = Theme.missingTexture
    }
    Loader {
        active: root.glint
        anchors.fill: parent
        sourceComponent: Item {
            McAnimatedSprite {
                id: shimmer
                anchors.fill: parent
                sprite: "misc/enchanted_glint_item"
                scroll: true
                visible: false
                layer.enabled: true
                layer.smooth: false
            }
            MultiEffect {
                anchors.fill: parent
                source: shimmer
                maskEnabled: true
                maskSource: icon
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0
                opacity: 0.7
            }
        }
    }
}
