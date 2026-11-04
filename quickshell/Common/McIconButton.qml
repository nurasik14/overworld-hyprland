import QtQuick
import qs.Common

/*  McIconButton — small square McButton with an icon instead of a label. Everything else is McButton's API.
 *    item: string         item name, centred at 16 GUI px
 *    sprite: string       GUI sprite instead of an item ("icon/search", 15 px or smaller sprites look right here)
 *    size: int            GUI px per side; default 20
 *
 *    McIconButton { item: "barrier"; tooltip: "Close"; onClicked: panel.close() }
 *    McIconButton { sprite: "icon/language"; tooltip: "Language" }
 */
McButton {
    id: root
    property string item: ""
    property string sprite: ""
    property int size: 20
    implicitWidth: Theme.px(size)
    implicitHeight: Theme.px(size)

    McItemIcon {
        visible: root.item.length > 0
        anchors.centerIn: parent
        name: root.item
        opacity: root.enabled ? 1 : 0.5
    }
    McSprite {
        visible: root.sprite.length > 0
        anchors.centerIn: parent
        sprite: root.sprite
        opacity: root.enabled ? 1 : 0.5
    }
}
