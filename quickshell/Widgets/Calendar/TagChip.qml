import QtQuick
import qs.Common
import qs.Widgets.Services

/*  TagChip — the small coloured label for an event's tag ([class] [opp] [email] …): a darkened chat colour with the tag in white.
 *  Unknown tags get the grey one.  Width follows the text (5 characters at most).
 */
Rectangle {
    id: chip
    property string tag: ""
    readonly property string shown: tag.length > 5 ? tag.slice(0, 5) : tag
    readonly property string code: CalendarService.tagCode(tag)
    visible: tag.length > 0
    width: visible ? label.implicitWidth + Theme.px(5) : 0
    height: Theme.px(9)
    color: Qt.darker(Theme.chat[code], 2.1)
    border.width: Theme.gui
    border.color: Qt.darker(Theme.chat[code], 1.35)
    antialiasing: false
    McText {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Theme.gui
        text: chip.shown
        color: "#ffffff"
    }
}
