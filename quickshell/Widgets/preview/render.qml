//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  Offscreen render of the whole card layout, no compositor involved (nothing touches the live session):
 *      OW_RENDER_OUT=/tmp/x.png [OW_RENDER_BG=wallpaper.png] [OW_MODE=dark] [OW_WIDGETS_DEMO=1] QT_QPA_PLATFORM=offscreen \
 *          qs -p quickshell/Widgets/preview/render.qml
 *  Draws a 1920×1080 window (backdrop = the wallpaper given, else flat grey-green), waits OW_RENDER_WAIT ms (default 2500,
 *  so services finish loading), saves it with grabToImage and quits.
 */
ShellRoot {
    Window {
        id: win
        width: 1920; height: 1080
        visible: true
        color: "#4E6B45"
        Image {
            anchors.fill: parent
            source: Quickshell.env("OW_RENDER_BG") ? "file://" + Quickshell.env("OW_RENDER_BG") : ""
            fillMode: Image.PreserveAspectCrop
        }
        WidgetLayout { id: layout; anchors.fill: parent }
        Timer {
            interval: parseInt(Quickshell.env("OW_RENDER_WAIT") || "2500")
            running: true
            onTriggered: win.contentItem.grabToImage(function (r) {
                const out = Quickshell.env("OW_RENDER_OUT") || "/tmp/ow-widgets.png";
                console.warn("render: saved", r.saveToFile(out), out);
                Qt.quit();
            })
        }
    }
}
