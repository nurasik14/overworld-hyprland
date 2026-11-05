import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  SysInfoCard — the F3 debug screen (190 × 142 GUI px).
 *  The fastfetch facts (OS, kernel, uptime, packages, shell, WM, terminal) as F3 text: white Minecraft text with the
 *  hard grey shadow on translucent dark-grey row backgrounds (0x90505050, one 9 GUI px row per line, left aligned like
 *  the game).  A grass block sits in the corner where the Maomao picture used to be.  CPU, RAM and disk are boss bars
 *  (green below 70 %, yellow below 90 %, red above) with the value in the title.
 *  Data: SysInfoService (sysinfo.py; bars refresh every 5 s while the layer is visible).
 */
WidgetCard {
    id: card
    title: "System"
    guiW: 190
    guiH: 148

    readonly property var svc: SysInfoService
    // the first four rows sit beside the grass block (narrower), the rest run the full width
    readonly property var lines: [
        "Overworld Hyprland",
        svc.user.length ? svc.user + "@" + svc.host : "—",
        "OS: " + svc.os.replace(" (KDE Plasma Desktop Edition)", ""),
        "Uptime: " + svc.uptime,
        "Kernel: " + svc.kernel,
        "Packages: " + svc.packages.replace(/ \((\w+)\)/g, " $1").replace(/, /g, " · "),
        "Shell: " + svc.shell + "  Terminal: " + svc.terminal,
        "WM: " + svc.wm
    ]
    function barColor(v) { return v >= 90 ? "red" : v >= 70 ? "yellow" : "green" }

    // F3 text block
    Column {
        id: f3
        Repeater {
            model: card.lines
            delegate: Item {
                required property string modelData
                width: Math.min(row.implicitWidth + Theme.px(2), Theme.px(176) - (index < 4 ? Theme.px(36) : 0)); height: Theme.px(9)
                required property int index
                Rectangle { anchors.fill: parent; color: "#c8383838" }
                McText {
                    id: row
                    x: Theme.gui; y: -Theme.gui
                    width: parent.width - Theme.px(2)
                    text: modelData
                    color: Theme.hudText
                    shadowColor: Theme.guiTextShadow
                    shadow: true
                    elide: Text.ElideRight
                }
            }
        }
    }
    McItemIcon {   // grass block, top-right
        x: Theme.px(176 - 32); y: 0
        size: 32
        name: "grass_block"
    }

    // CPU · RAM · Disk as boss bars
    Column {
        y: Theme.px(76)
        spacing: 0
        Repeater {
            model: [
                { k: "CPU", v: card.svc.cpu, t: Math.round(card.svc.cpu) + "%" },
                { k: "RAM", v: card.svc.ram, t: Math.round(card.svc.ram) + "%" + (card.svc.ramText ? "  " + card.svc.ramText.replace(" GiB", "G").replace(" / ", "/") : "") },
                { k: "Disk", v: card.svc.disk, t: Math.round(card.svc.disk) + "%" + (card.svc.diskText ? "  " + card.svc.diskText.replace(" GiB", "G").replace(" / ", "/").replace(/ · .*$/, "") : "") }
            ]
            delegate: McProgressBar {
                required property var modelData
                width: Theme.px(176)
                kind: "boss"
                color: card.barColor(modelData.v)
                notches: 10
                value: Math.min(1, modelData.v / 100)
                title: modelData.k + ": " + modelData.t
                titleColor: Theme.guiText
            }
        }
    }
}
