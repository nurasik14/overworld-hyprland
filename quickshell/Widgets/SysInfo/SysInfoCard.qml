import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  SysInfoCard — 系统 · SYSTEM (420 × 300), fastfetch-style in the mono font.
 *  Left: Maomao (assets/art/fastfetch-maomao[-dark].png, hidden when missing).  Right: Nerd glyph + label +
 *  value rows (OS, Kernel, Uptime, Packages, Shell, WM, Terminal) and three ink bars (CPU, RAM, Disk).
 */
WidgetCard {
    id: card
    title: "系统"
    subtitle: SysInfoService.user.length ? (SysInfoService.user + "@" + SysInfoService.host) : "System"
    sealGlyph: "印"
    width: 420
    height: 300

    readonly property var svc: SysInfoService
    readonly property bool hasImage: art.status === Image.Ready
    readonly property int artWidth: 118
    function nf(cp) { return String.fromCodePoint(cp) }

    Item {   // portrait (square-cornered clip; a 1 px hairline frames it)
        id: artBox
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: card.hasImage ? card.artWidth : 0
        visible: card.hasImage
        clip: true
        Image {
            id: art
            anchors.fill: parent
            source: "file://" + Theme.repoDir + "/assets/art/fastfetch-maomao" + (Theme.isDark ? "-dark" : "") + ".png"
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(420, 500)
            asynchronous: true
            smooth: true; mipmap: true
        }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Theme.hairline }
    }

    Column {
        id: rows
        anchors.left: artBox.right; anchors.leftMargin: card.hasImage ? Theme.space.md : 0
        anchors.right: parent.right; anchors.top: parent.top
        spacing: 2
        readonly property int labelW: 66
        Repeater {
            model: [
                { g: nf(0xF033D), k: "OS", v: card.svc.os.replace(" (KDE Plasma Desktop Edition)", "").replace(" Linux", "") },
                { g: nf(0xF0493), k: "Kernel", v: card.svc.kernel },
                { g: nf(0xF0150), k: "Uptime", v: card.svc.uptime },
                { g: nf(0xF03D7), k: "Packages", v: card.svc.packages.replace(/ \((\w+)\)/g, " $1").replace(/, /g, " · ") },
                { g: nf(0xF018D), k: "Shell", v: card.svc.shell },
                { g: nf(0xF0614), k: "WM", v: card.svc.wm },
                { g: nf(0xF07B7), k: "Terminal", v: card.svc.terminal }
            ]
            delegate: Row {
                required property var modelData
                spacing: Theme.space.sm
                height: 17
                InkText { role: "mono"; font.pixelSize: 12; text: modelData.g; color: Theme.accent; width: 14; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                InkText { role: "mono"; font.pixelSize: 12; text: modelData.k; muted: true; width: rows.labelW; anchors.verticalCenter: parent.verticalCenter }
                InkText { role: "mono"; font.pixelSize: 12; text: modelData.v; width: rows.width - rows.labelW - 14 - 2 * Theme.space.sm; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Column {
        anchors.left: rows.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        spacing: 6
        Repeater {
            model: [
                { g: nf(0xF061A), k: "CPU", v: card.svc.cpu, t: Math.round(card.svc.cpu) + "%" },
                { g: nf(0xF035B), k: "RAM", v: card.svc.ram, t: Math.round(card.svc.ram) + "%" + (card.svc.ramText ? " · " + card.svc.ramText.replace(" GiB", "G").replace(" / ", "/") : "") },
                { g: nf(0xF02CA), k: "Disk", v: card.svc.disk, t: Math.round(card.svc.disk) + "%" + (card.svc.diskText ? " · " + card.svc.diskText.replace(" GiB", "G").replace(" / ", "/").replace(/ · .*$/, "") : "") }
            ]
            delegate: Item {
                required property var modelData
                width: parent.width
                height: 18
                InkText { id: g; role: "mono"; font.pixelSize: 12; text: modelData.g; color: Theme.accent; width: 14; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                InkText { id: k; role: "mono"; font.pixelSize: 12; text: modelData.k; muted: true; width: 34; anchors.left: g.right; anchors.leftMargin: Theme.space.sm; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    id: track
                    anchors.left: k.right; anchors.right: pct.left; anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6; radius: 2
                    color: Theme.surfaceAlt
                    border.width: 1; border.color: Theme.hairline
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        anchors.margins: 1
                        width: Math.max(0, (parent.width - 2) * Math.min(1, modelData.v / 100))
                        radius: 1
                        color: modelData.v > 90 ? Theme.seal : Theme.text
                        Behavior on width { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.durBase } }
                    }
                }
                InkText { id: pct; role: "mono"; font.pixelSize: 11; text: modelData.t; muted: true; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 128; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
            }
        }
    }
}
