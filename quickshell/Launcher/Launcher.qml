import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "fuzzy.js" as Fuzzy
import "calc.js" as Calc

/*  Launcher — the medicine cabinet 药柜 (SUPER+Space · `ipc call launcher toggle`), namespace overworld-launcher.
 *  900×600 PaperPanel: search drawer on top · category labels (left column) · grid of wooden drawers · Maomao strip (right, if art exists)
 *  Prefixes: `=` calculator (safe parser, Enter copies the result) · `>` run a command (Quickshell.execDetached via sh)
 *  Keys: arrows move · Enter launches · Esc closes · Tab cycles categories
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-launcher"
        open: ShellState.launcherOpen
        onCloseRequested: ShellState.close("launcher")

        // ------------------------------------------------------------ data
        readonly property var categories: [
            { glyph: "全", name: "All",         match: [] },
            { glyph: "网", name: "Internet",    match: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "P2P", "FileTransfer"] },
            { glyph: "工", name: "Development", match: ["Development", "IDE", "Debugger", "Building"] },
            { glyph: "画", name: "Media",       match: ["AudioVideo", "Audio", "Video", "Graphics", "Photography", "Player", "Music", "Recorder"] },
            { glyph: "书", name: "Office",      match: ["Office", "TextEditor", "Documentation", "WordProcessor", "Spreadsheet", "Viewer", "Presentation", "Calendar"] },
            { glyph: "器", name: "System",      match: ["System", "TerminalEmulator", "FileManager", "Monitor", "Emulator", "Utility", "Archiving"] },
            { glyph: "设", name: "Settings",    match: ["Settings", "DesktopSettings", "HardwareSettings", "PackageManager", "Security"] }
        ]
        property int category: 0
        property string query: ""
        property int selected: 0
        property int tick: 0
        property var apps: []
        property var results: []
        readonly property string mode: query.indexOf("=") === 0 ? "calc" : (query.indexOf(">") === 0 ? "run" : "apps")
        readonly property var calc: mode === "calc" ? Calc.evaluate(query.substring(1)) : ({ ok: false, error: "" })
        readonly property string artPath: Theme.assetsDir + "/art/launcher-maomao.png"
        property bool artExists: false
        FileView { id: artProbe; path: win.artPath; printErrors: false; onLoaded: win.artExists = true; onLoadFailed: win.artExists = false }

        function buildApps() {
            const list = DesktopEntries.applications.values;
            const out = [];
            for (let i = 0; i < list.length; i++) {
                const e = list[i];
                if (!e || e.noDisplay) continue;
                out.push({ entry: e, name: e.name || e.id, generic: e.genericName || "", comment: e.comment || "",
                           keywords: (e.keywords || []).join(" "), categories: e.categories || [], icon: e.icon || "" });
            }
            out.sort((a, b) => a.name.localeCompare(b.name));
            win.apps = out;
            win.rebuild();
        }
        function inCategory(app, cat) {
            if (cat.match.length === 0) return true;
            for (let i = 0; i < app.categories.length; i++) if (cat.match.indexOf(app.categories[i]) >= 0) return true;
            return false;
        }
        function rebuild() {
            if (win.mode !== "apps") { win.results = []; win.selected = 0; return; }
            const cat = win.categories[win.category];
            const q = win.query.trim();
            const scored = [];
            for (let i = 0; i < win.apps.length; i++) {
                const a = win.apps[i];
                if (!q.length && !win.inCategory(a, cat)) continue;
                const s = Fuzzy.score(q, a.name, a.generic, a.keywords, a.comment);
                if (s > 0) scored.push({ app: a, s: s });
            }
            if (q.length) scored.sort((x, y) => (y.s - x.s) || x.app.name.localeCompare(y.app.name));
            win.results = scored.map(x => x.app);
            win.selected = 0;
        }
        onQueryChanged: rebuild()
        onCategoryChanged: { rebuild(); win.tick++; }
        Connections { target: ShellState; function onLauncherSearch(q) { win.setQuery(q); } }
        Connections { target: DesktopEntries; function onApplicationsChanged() { win.buildApps(); } }
        Component.onCompleted: buildApps()

        onShownChanged: {
            if (shown) {
                search.text = ""; win.category = 0; win.selected = 0; win.tick++;
                rebuild(); grid.contentY = 0; search.forceActiveFocus();
            }
        }

        function setQuery(q) { search.text = q; search.forceActiveFocus(); }
        function launch(i) {
            const app = win.results[i];
            if (!app) return;
            SoundService.play("seal");
            app.entry.execute();
            ShellState.close("launcher");
        }
        function accept() {
            if (win.mode === "calc") {
                if (win.calc.ok) { Quickshell.execDetached(["wl-copy", Calc.format(win.calc.value)]); ShellState.close("launcher"); }
                return;
            }
            if (win.mode === "run") {
                const cmd = win.query.substring(1).trim();
                if (cmd.length) { Quickshell.execDetached(["sh", "-c", cmd]); ShellState.close("launcher"); }
                return;
            }
            launch(win.selected);
        }
        function move(key) {
            const n = win.results.length;
            if (key === Qt.Key_Tab) { win.category = (win.category + 1) % win.categories.length; return; }
            if (n === 0) return;
            const cols = grid.columns;
            let s = win.selected;
            if (key === Qt.Key_Right) s = Math.min(n - 1, s + 1);
            else if (key === Qt.Key_Left) s = Math.max(0, s - 1);
            else if (key === Qt.Key_Down) s = Math.min(n - 1, s + cols);
            else if (key === Qt.Key_Up) s = Math.max(0, s - cols);
            else if (key === Qt.Key_PageDown) s = Math.min(n - 1, s + cols * 4);
            else if (key === Qt.Key_PageUp) s = Math.max(0, s - cols * 4);
            win.selected = s;
            grid.ensureVisible(s);
        }

        // ------------------------------------------------------------ panel
        PaperPanel {
            id: panel
            width: 900; height: 600
            anchors.centerIn: parent
            title: "药柜"
            subtitle: "Apps · Medicine cabinet"
            sealGlyph: "药"
            radius: Theme.radius.lg
            padding: Theme.space.lg
            opacity: win.progress
            transform: Translate { y: (1 - win.progress) * 12 }

            MouseArea { anchors.fill: parent; onClicked: search.forceActiveFocus() }   // swallow scrim clicks

            Column {
                anchors.fill: parent
                spacing: Theme.space.md

                // ---- search drawer: wood front, brass ring, caret
                Item {
                    width: parent.width; height: 48
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.sm
                        color: Theme.wood
                        border.width: 1; border.color: Theme.woodDark
                        Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
                    }
                    Rectangle {   // brass ring
                        width: 14; height: 14; radius: 7
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"; border.width: 2; border.color: Theme.gold
                    }
                    InkField {
                        id: search
                        anchors.fill: parent
                        anchors.leftMargin: 40; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8
                        fill: Theme.withAlpha(Theme.surface, 0.55)
                        icon: win.mode === "calc" ? "󰃬" : (win.mode === "run" ? "󰆍" : "󰍉")
                        placeholder: "找 · search apps…   = calculate   > run"
                        arrowsNavigate: true
                        onTextChanged: win.query = text
                        onAccepted: win.accept()
                        onEscaped: ShellState.close("launcher")
                        onNavigate: key => win.move(key)
                    }
                }

                // ---- body: categories | grid | art
                Row {
                    width: parent.width
                    height: parent.height - 48 - footer.height - parent.spacing * 2
                    spacing: Theme.space.md

                    Column {   // cabinet labels
                        id: catCol
                        width: 104
                        height: parent.height
                        spacing: 2
                        Repeater {
                            model: win.categories
                            Item {
                                id: catItem
                                required property var modelData
                                required property int index
                                readonly property bool current: win.category === index && win.query.trim().length === 0
                                width: catCol.width; height: 54
                                opacity: win.query.trim().length ? 0.5 : 1
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius.sm
                                    color: catItem.current ? Theme.surfaceAlt : Theme.inkWash
                                    opacity: catItem.current ? 1 : (catMouse.containsMouse ? 0.7 : 0)
                                    border.width: catItem.current ? 1 : 0
                                    border.color: Theme.hairline
                                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                                }
                                Rectangle {   // accent rule on the current label
                                    width: 2; height: parent.height - 12
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.accent
                                    visible: catItem.current
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left; anchors.leftMargin: Theme.space.md
                                    spacing: Theme.space.sm
                                    Text {
                                        text: catItem.modelData.glyph
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: 24
                                        color: catItem.current ? Theme.seal : Theme.text
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                    }
                                    Text {
                                        text: catItem.modelData.name
                                        font.family: Theme.fontSerif
                                        font.pixelSize: 12; font.weight: 600
                                        font.capitalization: Font.AllUppercase
                                        font.letterSpacing: 1
                                        color: catItem.current ? Theme.text : Theme.textMuted
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { search.text = ""; win.category = catItem.index; search.forceActiveFocus(); }
                                }
                            }
                        }
                    }
                    InkDivider { vertical: true; height: parent.height }

                    // ---- drawer grid
                    Item {
                        id: gridArea
                        width: parent.width - catCol.width - 1 - (art.visible ? art.width + parent.spacing : 0) - parent.spacing * 2
                        height: parent.height
                        clip: true

                        Flickable {
                            id: grid
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: flow.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            readonly property int gap: 12
                            readonly property int columns: Math.max(1, Math.floor((width + gap) / (112 + gap)))
                            readonly property int cell: Math.floor((width - (columns - 1) * gap) / columns)
                            function ensureVisible(i) {
                                const row = Math.floor(i / columns);
                                const y = row * (90 + gap);
                                if (y < contentY) contentY = y;
                                else if (y + 90 > contentY + height) contentY = y + 90 - height;
                            }
                            Flow {
                                id: flow
                                width: grid.width
                                spacing: grid.gap
                                Repeater {
                                    model: win.results
                                    Drawer {
                                        id: drawer
                                        required property var modelData
                                        required property int index
                                        width: grid.cell
                                        label: modelData.name
                                        icon: modelData.icon
                                        selected: win.selected === index
                                        staggerIndex: index
                                        tick: win.tick
                                        onActivated: win.launch(index)
                                        onHoveredChangedTo: h => { if (h) win.selected = index; }
                                    }
                                }
                            }
                        }

                        // ---- empty / calc / run states
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.space.sm
                            visible: win.mode !== "apps" || win.results.length === 0
                            width: parent.width - 48
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: win.mode === "calc" ? "算" : (win.mode === "run" ? "令" : "空")
                                font.family: Theme.fontDisplay
                                font.pixelSize: 48
                                color: win.mode === "apps" ? Theme.textMuted : Theme.seal
                                renderType: Text.NativeRendering
                            }
                            InkText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                role: win.mode === "calc" ? "display_sm" : "body"
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                font.family: win.mode === "calc" ? Theme.fontSerif : Theme.fontBody
                                text: win.mode === "calc" ? (win.calc.ok ? "= " + Calc.format(win.calc.value) : (win.calc.error.length ? win.calc.error : "…"))
                                    : win.mode === "run" ? (win.query.substring(1).trim().length ? "$ " + win.query.substring(1).trim() : "type a command")
                                    : "nothing found"
                                color: win.mode === "calc" && !win.calc.ok && win.calc.error.length ? Theme.error : Theme.text
                            }
                            InkText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                role: "small"; muted: true
                                text: win.mode === "calc" ? "Calculator · Enter copies the result" : (win.mode === "run" ? "Run command · Enter executes" : (win.query.trim().length ? "no drawer matches “" + win.query.trim() + "”" : "no apps in this column"))
                            }
                        }
                    }

                    // ---- Maomao strip (only if the art exists)
                    Item {
                        id: art
                        visible: win.artExists
                        width: 100
                        height: parent.height
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.sm
                            color: Theme.surfaceAlt
                            border.width: 1; border.color: Theme.hairline
                            clip: true
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: win.artExists ? "file://" + win.artPath : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 220
                                smooth: true
                                mipmap: true
                            }
                        }
                    }
                }

                // ---- footer
                Item {
                    id: footer
                    width: parent.width; height: 20
                    InkText {
                        role: "small"; muted: true
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "⏎ open · esc close · ↑↓←→ move · tab column · = calculator · > run"
                    }
                    InkText {
                        role: "small"; muted: true
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: win.mode === "apps" ? (win.results.length + " drawer" + (win.results.length === 1 ? "" : "s")) : ""
                    }
                }
            }
        }
    }
}
