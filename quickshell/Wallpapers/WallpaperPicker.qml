import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  WallpaperPicker — a handscroll of thumbnails at the bottom (SUPER+W · `ipc call wallpapers toggle`), namespace overworld-wallpapers.
 *  Lists PNG/JPG in <repo>/assets/wallpapers/<Theme.mode>; the current one (~/.config/overworld/wallpaper-<mode>) wears a seal.
 *  Click / Enter → `overworld wallpaper <path>` when the CLI exists, else `awww img …` + write wallpaper-<mode>.
 *  Keys: ←/→ move · Enter apply · Esc close.
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-wallpapers"
        open: ShellState.wallpapersOpen
        onCloseRequested: ShellState.close("wallpapers")

        readonly property string dir: Theme.assetsDir + "/wallpapers/" + Theme.mode
        readonly property string currentPath: Theme.stateDir + "/wallpaper-" + Theme.mode
        property var files: []
        property string current: ""
        property int selected: 0
        property bool cliExists: false
        property string status: ""

        FileView {
            id: currentFile
            path: win.currentPath
            watchChanges: true
            printErrors: false
            onLoaded: win.current = text().trim()
            onFileChanged: reload()
            onLoadFailed: win.current = ""
        }
        Process {
            id: lister
            command: ["find", win.dir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const ls = (text || "").split("\n").map(l => l.trim()).filter(l => l.length);
                    ls.sort();
                    win.files = ls;
                    let i = -1;
                    for (let k = 0; k < ls.length; k++) if (win.fileName(ls[k]) === win.fileName(win.current)) { i = k; break; }
                    win.selected = i >= 0 ? i : 0;
                    strip.positionViewAtIndex(win.selected, ListView.Center);
                }
            }
        }
        Process {
            id: cliProbe
            command: ["sh", "-c", "test -x \"$HOME/.local/bin/overworld\" && echo yes || echo no"]
            stdout: StdioCollector { onStreamFinished: win.cliExists = (text || "").trim() === "yes" }
        }
        Connections {
            target: ShellState
            function onWallpaperAction(action, arg) {
                if (action === "select") { win.selected = Math.max(0, Math.min(win.files.length - 1, arg)); strip.positionViewAtIndex(win.selected, ListView.Contain); }
                else if (action === "apply") win.apply(win.selected);
                else if (action === "next") win.move(1);
                else if (action === "prev") win.move(-1);
            }
        }
        onShownChanged: if (shown) { win.status = ""; currentFile.reload(); lister.running = true; cliProbe.running = true; }
        onDirChanged: if (shown) lister.running = true

        function fileName(p) { const i = p.lastIndexOf("/"); return i >= 0 ? p.substring(i + 1) : p; }
        function prettyName(p) {
            return fileName(p).replace(/\.[^.]+$/, "").replace(/^\d+-/, "").replace(/-/g, " ");
        }
        function apply(i) {
            const p = win.files[i];
            if (!p) return;
            SoundService.play("seal");
            if (win.cliExists) {
                Quickshell.execDetached(["overworld", "wallpaper", p]);
            } else {
                Quickshell.execDetached(["awww", "img", p, "--transition-type", "grow", "--transition-duration", "1.2",
                                         "--transition-fps", "165", "--transition-bezier", ".22,1,.36,1"]);
                Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/overworld\" && printf '%s' \"$1\" > \"$HOME/.config/overworld/wallpaper-$2\"",
                                         "overworld-wallpaper", p, Theme.mode]);
            }
            win.current = p;
            win.status = "set · " + prettyName(p);
        }
        function move(d) {
            if (!win.files.length) return;
            win.selected = Math.max(0, Math.min(win.files.length - 1, win.selected + d));
            strip.positionViewAtIndex(win.selected, ListView.Contain);
        }

        Item {
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left) { win.move(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Right) { win.move(1); event.accepted = true; }
                else if (event.key === Qt.Key_Home) { win.move(-9999); event.accepted = true; }
                else if (event.key === Qt.Key_End) { win.move(9999); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { win.apply(win.selected); event.accepted = true; }
            }
        }

        // ---- the handscroll
        Item {
            id: scroll
            width: Math.min(parent.width - 2 * Theme.space.margin, 1240)
            height: 236
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space.margin + 16
            opacity: win.progress
            transform: Translate { y: (1 - win.progress) * 12 }

            MouseArea { anchors.fill: parent }

            Rectangle {   // shadow
                anchors.fill: paper; anchors.topMargin: 8
                radius: 4; color: Theme.shadowStrong; opacity: 0.8
            }
            Rectangle {   // left roller
                width: 14; height: parent.height + 16; y: -8; x: -6; radius: 7
                color: Theme.woodDark
                Rectangle { anchors.fill: parent; anchors.margins: 3; radius: 4; color: Theme.gold; opacity: 0.25 }
            }
            Rectangle {   // right roller
                width: 14; height: parent.height + 16; y: -8; x: parent.width - 8; radius: 7
                color: Theme.woodDark
                Rectangle { anchors.fill: parent; anchors.margins: 3; radius: 4; color: Theme.gold; opacity: 0.25 }
            }
            Rectangle {
                id: paper
                anchors.fill: parent
                anchors.leftMargin: 4; anchors.rightMargin: 4
                color: Theme.surface
                border.width: Theme.border.frame
                border.color: Theme.frame
                Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
                Item {
                    anchors.fill: parent; anchors.margins: 2; clip: true
                    Image { anchors.fill: parent; source: Theme.texture("ground-tile"); fillMode: Image.Tile; opacity: Theme.textureOpacity; smooth: false; asynchronous: true }
                }
                Rectangle { anchors.fill: parent; anchors.margins: 6; color: "transparent"; border.width: 1; border.color: Theme.hairline }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.space.lg
                    spacing: Theme.space.sm

                    Row {   // header
                        id: head
                        width: parent.width
                        spacing: Theme.space.md
                        Text {
                            text: "画"
                            font.family: Theme.fontDisplay; font.pixelSize: 24
                            color: Theme.seal; renderType: Text.NativeRendering
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        InkText {
                            role: "subtitle"; text: "Wallpapers · " + (Theme.isDark ? "Inner Palace 后宫" : "Overworld 药屋")
                            font.capitalization: Font.AllUppercase; font.letterSpacing: 1.2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        InkText {
                            role: "small"; muted: true
                            text: win.files.length + " sheets · ←→ move · ⏎ set · esc close" + (win.status.length ? " · " + win.status : "")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    ListView {
                        id: strip
                        width: parent.width
                        height: parent.height - head.height - parent.spacing
                        orientation: ListView.Horizontal
                        spacing: Theme.space.md
                        clip: true
                        model: win.files
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: Theme.durBase
                        delegate: Item {
                            id: thumb
                            required property string modelData
                            required property int index
                            readonly property bool isCurrent: win.current.length > 0 && win.fileName(modelData) === win.fileName(win.current)
                            readonly property bool isSelected: win.selected === index
                            width: 256; height: strip.height
                            Accessible.role: Accessible.Button
                            Accessible.name: win.prettyName(modelData)

                            Column {
                                anchors.fill: parent
                                spacing: 6
                                Item {
                                    width: parent.width; height: 144
                                    y: thumb.isSelected || thumbMouse.containsMouse ? -2 : 0
                                    Behavior on y { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.surfaceAlt
                                        border.width: thumb.isSelected ? 2 : 1
                                        border.color: thumb.isSelected ? Theme.accent : (thumb.isCurrent ? Theme.seal : Theme.hairline)
                                        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                                        Image {
                                            anchors.fill: parent; anchors.margins: 2
                                            source: "file://" + thumb.modelData
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize.width: 320
                                            smooth: true
                                            cache: true
                                        }
                                        Rectangle {   // hover wash
                                            anchors.fill: parent; anchors.margins: 2
                                            color: Theme.inkWash
                                            opacity: thumbMouse.containsMouse ? 0.6 : 0
                                        }
                                        Seal {
                                            visible: thumb.isCurrent
                                            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                                            size: 24; glyph: "印"; label: "current wallpaper"
                                            rotation: -6
                                        }
                                    }
                                }
                                InkText {
                                    role: "small"
                                    muted: !thumb.isSelected
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: win.prettyName(thumb.modelData) + (thumb.isCurrent ? " · current" : "")
                                    font.family: Theme.fontBody
                                }
                            }
                            MouseArea {
                                id: thumbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: win.selected = thumb.index
                                onClicked: win.apply(thumb.index)
                            }
                        }
                        Column {   // empty state
                            anchors.centerIn: parent
                            visible: win.files.length === 0
                            spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "空"; font.family: Theme.fontDisplay; font.pixelSize: 36; color: Theme.textMuted; renderType: Text.NativeRendering }
                            InkText { anchors.horizontalCenter: parent.horizontalCenter; role: "body"; muted: true; text: "no wallpapers in " + win.dir }
                            InkText { anchors.horizontalCenter: parent.horizontalCenter; role: "small"; muted: true; text: "run assets/fetch-art.sh and scripts/make-wallpapers.sh" }
                        }
                    }
                }
            }
        }
    }
}
