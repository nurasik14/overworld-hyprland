import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  WallpaperPicker — the Select World screen (SUPER+W · `ipc call wallpapers toggle`), namespace overworld-wallpapers.
 *  Rows come from assets/wallpapers/index.json for the current mode (title, thumb; variants of other times are left out), plus any
 *  other picture in assets/wallpapers/<mode>/. The current one (~/.config/overworld/wallpaper-<mode>) is marked.
 *  Play Selected World → `overworld wallpaper <path>` when the CLI exists, else `awww img …` + write wallpaper-<mode>; emits wallpaper.set.
 *  Create New World → scripts/make-world.sh --mode <mode> in the background behind the game's chunk-loading screen; it emits
 *  world.created itself and the new world ends up selected. Delete World asks first and refuses the world in use.
 *  Keys: Up/Down select · Home/End · Enter play · Esc cancel · typing searches.
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-wallpapers"
        background: "menu"
        title: view === "list" ? "Select World" : view === "delete" ? "" : "Create New World"
        titleY: view === "list" ? 8 : 20
        headerHeight: view === "list" ? 48 : 0
        footerHeight: view === "list" ? 60 : 0
        closeOnClickOutside: false
        open: ShellState.wallpapersOpen
        onCloseRequested: {
            if (view === "delete") view = "list";
            else if (view === "create" && creator.running) ShellState.close("wallpapers");   // keeps generating; selected when done
            else if (view !== "list") view = "list";
            else ShellState.close("wallpapers");
        }

        property string view: "list"     // list | create | delete
        onViewChanged: {   // the field is hidden outside the list: without this Esc would have nowhere to go
            if (view === "list") search.input.forceActiveFocus();
            else contentItem.forceActiveFocus();
        }
        readonly property string wallDir: Theme.assetsDir + "/wallpapers"
        readonly property string dir: wallDir + "/" + Theme.mode
        readonly property string currentPath: Theme.stateDir + "/wallpaper-" + Theme.mode
        readonly property string playedPath: Theme.home + "/.cache/overworld/worlds-played.json"
        property var index: []
        property var files: []
        property var played: ({})
        property string current: ""
        property int selected: 0
        property bool cliExists: false
        property string pendingSelect: ""

        // ------------------------------------------------------------ sources
        readonly property var worlds: {
            const fromIndex = {};
            for (let i = 0; i < index.length; i++) fromIndex[index[i].file] = index[i];
            const prefix = Theme.mode + "/";
            const out = [];
            for (let i = 0; i < files.length; i++) {
                const rel = prefix + fileName(files[i]);
                const e = fromIndex[rel] || {};
                out.push({
                    path: files[i], rel: rel,
                    title: e.title || prettyName(files[i]),
                    thumb: e.thumb ? "file://" + wallDir + "/" + e.thumb : "file://" + files[i],
                    seed: e.seed, scene: e.scene || "", world: e.world || "", time: e.time || ""
                });
            }
            return out;
        }
        readonly property string filter: search.text.trim().toLowerCase()
        readonly property var rows: filter.length ? worlds.filter(w => w.title.toLowerCase().indexOf(filter) >= 0 || w.scene.indexOf(filter) >= 0) : worlds
        readonly property var currentRow: rows[selected] || null
        onRowsChanged: {
            if (pendingSelect.length) {
                const i = rows.findIndex(w => w.path === pendingSelect);
                if (i >= 0) { selected = i; pendingSelect = ""; list.positionViewAtIndex(i, ListView.Contain); return; }
            }
            if (selected >= rows.length) selected = Math.max(0, rows.length - 1);
        }

        FileView {
            id: indexFile
            path: win.wallDir + "/index.json"
            watchChanges: true
            printErrors: false
            onLoaded: { try { win.index = JSON.parse(text()) || []; } catch (e) { win.index = []; } }
            onFileChanged: reload()
            onLoadFailed: win.index = []
        }
        FileView {
            id: currentFile
            path: win.currentPath
            watchChanges: true
            printErrors: false
            onLoaded: win.current = text().trim()
            onFileChanged: reload()
            onLoadFailed: win.current = ""
        }
        FileView {
            id: playedFile
            path: win.playedPath
            printErrors: false
            atomicWrites: false
            onLoaded: { try { win.played = JSON.parse(text()) || {}; } catch (e) { win.played = {}; } }
        }
        Process {
            id: lister
            command: ["find", win.dir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"]
            // the mode flipped while a find was still running: its answer is for the old folder, so run it again
            onExited: if (win.listAgain) { win.listAgain = false; lister.running = true; }
            stdout: StdioCollector {
                onStreamFinished: {
                    if (win.listAgain) return;
                    const ls = (text || "").split("\n").map(l => l.trim()).filter(l => l.length);
                    ls.sort();
                    win.files = ls;
                    if (win.pendingSelect.length) return;
                    const i = win.rows.findIndex(w => win.fileName(w.path) === win.fileName(win.current));
                    win.selected = i >= 0 ? i : 0;
                    list.positionViewAtIndex(win.selected, ListView.Center);
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
                if (action === "select") { win.selected = Math.max(0, Math.min(win.rows.length - 1, arg)); list.positionViewAtIndex(win.selected, ListView.Contain); }
                else if (action === "apply") win.apply(win.selected);
                else if (action === "next") win.move(1);
                else if (action === "prev") win.move(-1);
            }
        }
        onShownChanged: {
            if (shown) {
                if (!creator.running && !fakeGen.running) win.view = "list";
                search.text = "";
                currentFile.reload(); indexFile.reload(); playedFile.reload();
                lister.running = true; cliProbe.running = true;
                search.input.forceActiveFocus();
            }
        }
        property bool listAgain: false
        onDirChanged: {
            if (!shown) return;
            win.files = [];                       // never show the old mode's worlds under the new mode
            if (lister.running) win.listAgain = true; else lister.running = true;
        }

        function fileName(p) { const i = p.lastIndexOf("/"); return i >= 0 ? p.substring(i + 1) : p; }
        function prettyName(p) {
            const s = fileName(p).replace(/\.[^.]+$/, "").replace(/^\d+-/, "").replace(/-/g, " ");
            return s.charAt(0).toUpperCase() + s.slice(1);
        }
        function isCurrent(p) { return win.current.length > 0 && win.fileName(p) === win.fileName(win.current); }
        function apply(i) {
            const w = win.rows[i];
            if (!w) return;
            if (win.cliExists) {
                ShellState.run(["overworld", "wallpaper", w.path]);
            } else {
                ShellState.run(["awww", "img", w.path, "--transition-type", "grow", "--transition-duration", "1.2",
                                "--transition-fps", "165", "--transition-bezier", ".22,1,.36,1"]);
                ShellState.run(["sh", "-c", "mkdir -p \"$HOME/.config/overworld\" && printf '%s' \"$1\" > \"$HOME/.config/overworld/wallpaper-$2\"",
                                "overworld-wallpaper", w.path, Theme.mode]);
            }
            GameEvents.emit("wallpaper.set", { path: w.path });
            win.current = w.path;
            const copy = Object.assign({}, win.played);
            copy[win.fileName(w.path)] = Date.now();
            win.played = copy;
            if (!ShellState.preview) {
                ShellState.run(["mkdir", "-p", Theme.home + "/.cache/overworld"]);
                playedFile.setText(JSON.stringify(copy) + "\n");
            }
            ShellState.close("wallpapers");
        }
        function move(d) {
            if (!win.rows.length) return;
            win.selected = Math.max(0, Math.min(win.rows.length - 1, win.selected + d));
            list.positionViewAtIndex(win.selected, ListView.Contain);
        }
        function handleKey(event) {
            const k = event.key;
            if (k === Qt.Key_Up) win.move(-1);
            else if (k === Qt.Key_Down) win.move(1);
            else if (k === Qt.Key_PageUp) win.move(-5);
            else if (k === Qt.Key_PageDown) win.move(5);
            else if (k === Qt.Key_Home) win.move(-9999);
            else if (k === Qt.Key_End) win.move(9999);
            else return;
            event.accepted = true;
        }
        function randomWorld() {
            if (win.rows.length) win.move(Math.floor(Math.random() * win.rows.length) - win.selected);
        }

        // ------------------------------------------------------------ Create New World
        property real genProgress: 0
        property double genStart: 0
        property string genError: ""
        property string genOutput: ""
        function create() {
            win.view = "create";
            win.genError = ""; win.genOutput = ""; win.genProgress = 0;
            win.genStart = Date.now();
            if (ShellState.preview) { console.warn("DRYRUN make-world --mode", Theme.mode); fakeGen.restart(); return; }
            creator.command = [Theme.repoDir + "/scripts/make-world.sh", "--mode", Theme.mode];
            creator.running = true;
        }
        function cancelCreate() {
            fakeGen.stop();
            if (creator.running) creator.running = false;
            win.view = "list";
        }
        Timer {   // previews: 6 s of pretend
            id: fakeGen
            interval: 6000
            onTriggered: win.view = "list"
        }
        Process {
            id: creator
            stdout: StdioCollector { onStreamFinished: win.genOutput = (text || "").trim() }
            stderr: StdioCollector { id: creatorErr }
            onExited: (code, status) => {
                if (code === 0) {
                    win.pendingSelect = win.genOutput.split("\n").pop();
                    lister.running = true; indexFile.reload();
                    win.view = "list";
                    Theme.playSound("xp.levelup");
                } else if (win.view === "create") {
                    const lines = (creatorErr.text || "").trim().split("\n");
                    win.genError = lines[lines.length - 1] || "Generation failed (" + code + ")";
                }
            }
        }
        // about 15 s with numba's cache, up to a minute without: the bar slows down instead of guessing
        Timer {
            interval: 200; repeat: true
            running: win.view === "create" && (creator.running || fakeGen.running)
            onTriggered: win.genProgress = 1 - Math.exp(-(Date.now() - win.genStart) / 12000)
        }

        // ------------------------------------------------------------ list view
        McTextField {
            id: search
            visible: win.view === "list"
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.px(22)
            width: Theme.px(200)
            placeholderText: "Search for worlds"
            onAccepted: win.apply(win.selected)
            Component.onCompleted: search.input.Keys.pressed.connect(win.handleKey)
        }
        Item {
            anchors.fill: parent
            anchors.topMargin: Theme.px(48)
            anchors.bottomMargin: Theme.px(60)
            visible: win.view === "list"
            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: Theme.px(2)
                anchors.bottomMargin: Theme.px(2)
                clip: true
                model: win.rows
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: win.selected === index
                    width: list.width
                    height: Theme.px(36)
                    Rectangle {
                        x: Math.round((parent.width - width) / 2)
                        width: Theme.px(305)
                        height: Theme.px(36)
                        color: row.isSelected ? "#000000" : "transparent"
                        border.width: row.isSelected ? Theme.gui : 0
                        border.color: Theme.focusRing
                        Image {
                            id: thumb
                            x: Theme.px(2); y: Theme.px(2)
                            width: Theme.px(56); height: Theme.px(32)
                            source: row.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: Theme.px(112)
                            asynchronous: true
                            smooth: true
                            cache: true
                        }
                        Rectangle {
                            anchors.fill: thumb
                            color: "#A0909090"
                            visible: rowArea.containsMouse
                            McSprite {
                                anchors.centerIn: parent
                                sprite: thumbHover.hovered ? "world_list/join_highlighted" : "world_list/join"
                            }
                            HoverHandler { id: thumbHover }
                        }
                        McText {
                            x: Theme.px(61); y: Theme.px(2)
                            width: parent.width - Theme.px(65)
                            elide: Text.ElideRight
                            color: Theme.hudText
                            text: row.modelData.title
                        }
                        McText {
                            x: Theme.px(61); y: Theme.px(12)
                            width: parent.width - Theme.px(65)
                            elide: Text.ElideRight
                            color: "#808080"
                            text: {
                                const when = win.played[win.fileName(row.modelData.path)];
                                return win.fileName(row.modelData.path) + (when ? " (" + Qt.formatDateTime(new Date(when), "dd/MM/yyyy HH:mm") + ")" : "");
                            }
                        }
                        McText {
                            x: Theme.px(61); y: Theme.px(22)
                            width: parent.width - Theme.px(65)
                            elide: Text.ElideRight
                            darkGround: true
                            codes: (win.isCurrent(row.modelData.path) ? "§aPlaying now§7, " : "§7") + "Survival Mode"
                                + (row.modelData.seed !== null && row.modelData.seed !== undefined ? ", Seed: " + row.modelData.seed : "")
                                + (row.modelData.world.length ? ", " + row.modelData.world : "")
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: mouse => {
                                win.selected = row.index;
                                if (mouse.x < Theme.px(58)) win.apply(row.index);
                            }
                            onDoubleClicked: win.apply(row.index)
                        }
                    }
                }
            }
            McScrollbar {
                flickable: list
                x: Math.round(parent.width / 2) + Theme.px(158)
                y: 0
                height: parent.height
            }
            Column {
                anchors.centerIn: parent
                visible: win.rows.length === 0
                spacing: Theme.px(2)
                McText { anchors.horizontalCenter: parent.horizontalCenter; color: Theme.tooltipDesc; text: win.filter.length ? "No worlds found" : "No worlds in " + win.dir }
                McText { anchors.horizontalCenter: parent.horizontalCenter; visible: !win.filter.length; color: "#808080"; text: "Create New World, or run scripts/make-world.sh" }
            }
        }
        Column {
            visible: win.view === "list"
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - Theme.px(52)
            spacing: Theme.px(4)
            Row {
                spacing: Theme.px(4)
                anchors.horizontalCenter: parent.horizontalCenter
                McButton {
                    text: "Play Selected World"
                    enabled: win.currentRow !== null
                    onClicked: win.apply(win.selected)
                }
                McButton {
                    text: "Create New World"
                    onClicked: win.create()
                }
            }
            Row {
                spacing: Theme.px(4)
                anchors.horizontalCenter: parent.horizontalCenter
                McButton {
                    width: Theme.px(73)
                    text: "Delete"
                    enabled: win.currentRow !== null && !win.isCurrent(win.currentRow.path)
                    tooltip: win.currentRow !== null && win.isCurrent(win.currentRow.path) ? "In use" : ""
                    onClicked: win.view = "delete"
                }
                McButton {
                    width: Theme.px(73)
                    text: "Random"
                    enabled: win.rows.length > 1
                    onClicked: win.randomWorld()
                }
                McButton {
                    width: Theme.px(73)
                    text: "Refresh"
                    onClicked: { lister.running = true; indexFile.reload(); }
                }
                McButton {
                    width: Theme.px(73)
                    text: "Cancel"
                    onClicked: ShellState.close("wallpapers")
                }
            }
        }

        // ------------------------------------------------------------ the game's world-loading screen
        Column {
            visible: win.view === "create"
            anchors.centerIn: parent
            spacing: Theme.px(8)
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.hudText
                text: win.genError.length ? "Generation failed" : "Generating world..."
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                darkGround: true
                codes: win.genError.length ? "§c" + win.genError : "§7Building terrain: " + Math.round(win.genProgress * 100) + "%"
            }
            ChunkMap {
                anchors.horizontalCenter: parent.horizontalCenter
                progress: win.genProgress
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(4)
                McButton {
                    visible: !win.genError.length
                    text: "Keep in Background"
                    tooltip: "Close this screen"
                    tooltipDescription: "The new world is selected when it is ready"
                    onClicked: ShellState.close("wallpapers")
                }
                McButton {
                    text: win.genError.length ? "Back" : "Cancel"
                    onClicked: win.cancelCreate()
                }
            }
        }

        // ------------------------------------------------------------ delete confirm: the game's wording
        Column {
            visible: win.view === "delete"
            anchors.centerIn: parent
            spacing: Theme.px(10)
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.hudText
                text: "Are you sure you want to delete this world?"
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.tooltipDesc
                text: win.currentRow ? "'" + win.currentRow.title + "' will be lost forever! (A long time!)" : ""
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(8)
                McButton {
                    text: "Delete"
                    onClicked: {
                        const w = win.currentRow;
                        if (w && !win.isCurrent(w.path)) {
                            ShellState.run(["sh", "-c",
                                'rm -f "$1" "$2/thumbs/$(basename "$1")"; f="$2/index.json"; [ -f "$f" ] && out="$(jq --arg r "$3" \'map(select(.file != $r))\' "$f")" && printf "%s\\n" "$out" > "$f"',
                                "overworld-delete-world", w.path, win.wallDir, w.rel]);
                            lister.running = true;
                        }
                        win.view = "list";
                    }
                }
                McButton {
                    text: "Cancel"
                    onClicked: win.view = "list"
                }
            }
        }
    }
}
