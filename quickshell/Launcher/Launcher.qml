import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "fuzzy.js" as Fuzzy
import "calc.js" as Calc

/*  Launcher — the creative inventory (SUPER+Space · `ipc call launcher toggle`), namespace overworld-launcher.
 *  The game's metrics: 195 wide, 9-column grid of 18 px slots from (9,18), creative scroller at x 175, a hotbar row 4 px under
 *  the grid (here: your first nine favourites), tabs above and below.
 *  Tabs: Search (every app until you type), Favourites, then the freedesktop categories.
 *  Prefixes in the search field: `=` calculator (safe parser, Enter copies the result) · `>` run a command.
 *  Keys: arrows move · PageUp/PageDown · Enter launches · Esc closes · Tab/Shift+Tab next tab · Ctrl+F favourite.
 *  Mouse: click launches, right-click favourites, hover shows the tooltip. Favourites wear a star, and persist in
 *  ~/.config/overworld/launcher.json. Plays chest.open/chest.close, emits launcher.launch {app}.
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
        readonly property var tabs: [
            { key: "search",  item: "compass",        label: "Search Items", match: [] },
            { key: "fav",     item: "nether_star",    label: "Favourites",   match: [] },
            { key: "net",     item: "filled_map",     label: "Internet",     match: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "P2P", "FileTransfer"] },
            { key: "dev",     item: "command_block",  label: "Development",  match: ["Development", "IDE", "Debugger", "Building"] },
            { key: "media",   item: "jukebox",        label: "Media",        match: ["AudioVideo", "Audio", "Video", "Graphics", "Photography", "Player", "Music", "Recorder"] },
            { key: "office",  item: "writable_book",  label: "Office",       match: ["Office", "TextEditor", "Documentation", "WordProcessor", "Spreadsheet", "Viewer", "Presentation", "Calendar"] },
            { key: "system",  item: "redstone",       label: "System",       match: ["System", "TerminalEmulator", "FileManager", "Monitor", "Emulator", "Utility", "Archiving"] },
            { key: "settings",item: "comparator",     label: "Settings",     match: ["Settings", "DesktopSettings", "HardwareSettings", "PackageManager", "Security"] },
            { key: "games",   item: "diamond_sword",  label: "Games",        match: ["Game"] }
        ]
        readonly property int topTabs: 7
        property int category: 0
        property string query: ""
        property int selected: 0
        property bool keyboardNav: false
        property var apps: []
        property var results: []
        property var favourites: []
        readonly property string mode: query.indexOf("=") === 0 ? "calc" : (query.indexOf(">") === 0 ? "run" : "apps")
        readonly property var calc: mode === "calc" ? Calc.evaluate(query.substring(1)) : ({ ok: false, error: "" })
        readonly property var favApps: favourites.map(id => apps.find(a => a.id === id)).filter(a => a !== undefined)

        // ------------------------------------------------------------ favourites, persisted
        readonly property string favPath: Theme.stateDir + "/launcher.json"
        FileView {
            id: favFile
            path: win.favPath
            blockLoading: true
            printErrors: false
            atomicWrites: false
        }
        function saveFavourites() {
            if (!ShellState.preview) favFile.setText(JSON.stringify({ favourites: win.favourites }, null, 1) + "\n");
        }
        function isFav(id) { return win.favourites.indexOf(id) >= 0; }
        function toggleFav(app) {
            if (!app) return;
            const i = win.favourites.indexOf(app.id);
            const copy = win.favourites.slice();
            if (i >= 0) copy.splice(i, 1); else copy.push(app.id);
            win.favourites = copy;
            SoundService.play("item.pickup");
            win.saveFavourites();
            if (win.tabs[win.category].key === "fav") win.rebuild();
        }

        function iconFor(e) {          // items.json by desktop id, class or icon name; else the app's own icon; else the default item
            const keys = [e.id, e.startupClass, e.icon, e.name];
            for (let i = 0; i < keys.length; i++) {
                const k = String(keys[i] || "").toLowerCase();
                if (k.length && typeof Theme.items[k] === "string") return { item: Theme.items[k], url: "" };
            }
            const p = e.icon ? Quickshell.iconPath(e.icon, true) : "";
            return p ? { item: "", url: p } : { item: Theme.items._default || "stone", url: "" };
        }
        function categoryName(a) {
            for (let i = 2; i < win.tabs.length; i++) if (win.inTab(a, win.tabs[i])) return win.tabs[i].label;
            return "Application";
        }
        function buildApps() {
            const list = DesktopEntries.applications.values;
            const out = [];
            for (let i = 0; i < list.length; i++) {
                const e = list[i];
                if (!e || e.noDisplay) continue;
                const ic = win.iconFor(e);
                out.push({ entry: e, id: e.id, name: e.name || e.id, generic: e.genericName || "", comment: e.comment || "",
                           keywords: (e.keywords || []).join(" "), categories: e.categories || [], item: ic.item, url: ic.url });
            }
            out.sort((a, b) => a.name.localeCompare(b.name));
            win.apps = out;
            win.rebuild();
        }
        function inTab(app, tab) {
            for (let i = 0; i < app.categories.length; i++) if (tab.match.indexOf(app.categories[i]) >= 0) return true;
            return false;
        }
        function rebuild() {
            if (win.mode !== "apps") { win.results = []; win.selected = 0; return; }
            const tab = win.tabs[win.category];
            const q = win.query.trim();
            let pool = win.apps;
            if (tab.key === "fav") pool = win.favApps;
            else if (tab.key !== "search") pool = pool.filter(a => win.inTab(a, tab));
            if (!q.length) {
                win.results = pool;
            } else {
                const scored = [];
                for (let i = 0; i < pool.length; i++) {
                    const a = pool[i];
                    const s = Fuzzy.score(q, a.name, a.generic, a.keywords, a.comment);
                    if (s > 0) scored.push({ app: a, s: s });
                }
                scored.sort((x, y) => (y.s - x.s) || x.app.name.localeCompare(y.app.name));
                win.results = scored.map(x => x.app);
            }
            win.selected = 0;
            grid.contentY = 0;
        }
        onQueryChanged: {
            if (query.length && win.tabs[win.category].key !== "search") win.category = 0;   // typing jumps to Search, like the game
            rebuild();
        }
        onCategoryChanged: rebuild()
        Connections { target: ShellState; function onLauncherSearch(q) { win.setQuery(q); } }
        Connections { target: DesktopEntries; function onApplicationsChanged() { win.buildApps(); } }
        Component.onCompleted: {
            try { win.favourites = (JSON.parse(favFile.text() || "{}").favourites) || []; } catch (e) { win.favourites = []; }
            buildApps();
        }

        property bool wasShown: false
        onShownChanged: {
            if (shown) {
                search.text = ""; win.category = 0; win.selected = 0; win.keyboardNav = false;
                rebuild(); grid.contentY = 0; search.input.forceActiveFocus();
                SoundService.play("chest.open");
                wasShown = true;
            } else if (wasShown) {
                SoundService.play("chest.close");
                wasShown = false;
            }
        }

        function setQuery(q) { search.text = q; search.input.forceActiveFocus(); }
        function launchApp(app) {
            if (!app) return;
            GameEvents.emit("launcher.launch", { app: app.id });
            if (ShellState.preview) console.warn("DRYRUN launch", app.id);
            else app.entry.execute();
            ShellState.close("launcher");
        }
        function accept() {
            if (win.mode === "calc") {
                if (win.calc.ok) { ShellState.run(["wl-copy", Calc.format(win.calc.value)]); ShellState.close("launcher"); }
                return;
            }
            if (win.mode === "run") {
                const cmd = win.query.substring(1).trim();
                if (cmd.length) { ShellState.run(["sh", "-c", cmd]); ShellState.close("launcher"); }
                return;
            }
            launchApp(win.results[win.selected]);
        }
        function nextTab(d) { win.category = (win.category + d + win.tabs.length) % win.tabs.length; Theme.playSound("ui.click"); }
        function move(key) {
            win.keyboardNav = true;
            const n = win.results.length;
            if (n === 0) return;
            const cols = 9;
            let s = win.selected;
            if (key === Qt.Key_Right) s = Math.min(n - 1, s + 1);
            else if (key === Qt.Key_Left) s = Math.max(0, s - 1);
            else if (key === Qt.Key_Down) s = Math.min(n - 1, s + cols);
            else if (key === Qt.Key_Up) s = Math.max(0, s - cols);
            else if (key === Qt.Key_PageDown) s = Math.min(n - 1, s + cols * win.rows);
            else if (key === Qt.Key_PageUp) s = Math.max(0, s - cols * win.rows);
            win.selected = s;
            grid.positionViewAtIndex(s, GridView.Contain);
        }
        // The grid keeps working while the search field has the keyboard, so these run before the field sees them.
        function handleKey(event) {
            const k = event.key;
            if (k === Qt.Key_Tab) { win.nextTab(1); event.accepted = true; }
            else if (k === Qt.Key_Backtab) { win.nextTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_PageUp || k === Qt.Key_PageDown) { win.move(k); event.accepted = true; }
            else if ((k === Qt.Key_Left || k === Qt.Key_Right) && win.mode === "apps") { win.move(k); event.accepted = true; }
            else if (k === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) { win.toggleFav(win.results[win.selected]); event.accepted = true; }
        }

        // ------------------------------------------------------------ geometry (GUI px)
        readonly property int rows: 8
        readonly property int panelW: 195
        readonly property int panelH: 18 + rows * 18 + 4 + 18 + 6

        // ------------------------------------------------------------ the panel
        Item {
            id: stage
            width: Theme.px(win.panelW)
            height: Theme.px(win.panelH)
            x: Math.round((parent.width - width) / 2 / Theme.gui) * Theme.gui
            y: Math.round((parent.height - height) / 2 / Theme.gui) * Theme.gui

            McPanel {
                id: panel
                anchors.fill: parent
                title: win.tabs[win.category].key === "search" ? "" : win.tabs[win.category].label
                padding: 0
                MouseArea { anchors.fill: parent; onClicked: search.input.forceActiveFocus() }   // swallow clicks
            }

            McTabs {
                id: topTabs
                z: 2
                tabs: win.tabs.slice(0, win.topTabs)
                currentIndex: win.category < win.topTabs ? win.category : -1
                anchors { left: parent.left; bottom: parent.top; bottomMargin: -overlap }
                onTabClicked: i => { search.text = ""; win.category = i; search.input.forceActiveFocus(); }
            }
            McTabs {
                id: bottomTabs
                z: 2
                side: "bottom"
                tabs: win.tabs.slice(win.topTabs)
                currentIndex: win.category >= win.topTabs ? win.category - win.topTabs : -1
                anchors { left: parent.left; top: parent.bottom; topMargin: -overlap }
                onTabClicked: i => { search.text = ""; win.category = win.topTabs + i; search.input.forceActiveFocus(); }
            }

            // ---- search field. Stays focused on every tab (typing jumps to Search), only drawn there, like the game.
            McTextField {
                id: search
                x: Theme.px(62); y: Theme.px(4)
                width: Theme.px(127); height: Theme.px(12)
                opacity: win.tabs[win.category].key === "search" ? 1 : 0
                placeholderText: "Search..."
                onTextChanged: win.query = text
                onAccepted: win.accept()
                Component.onCompleted: search.input.Keys.pressed.connect(win.handleKey)
            }
            McText {
                visible: win.tabs[win.category].key === "search"
                x: Theme.px(8); y: Theme.px(5)
                text: "Search"
                guiTitle: true
            }

            // ---- grid: the empty slots, then the apps on top of them
            Grid {
                x: Theme.px(9); y: Theme.px(18)
                columns: 9
                Repeater {
                    model: win.rows * 9
                    McSlot { enabled: false }
                }
            }
            GridView {
                id: grid
                x: Theme.px(9); y: Theme.px(18)
                width: Theme.px(9 * 18)
                height: Theme.px(win.rows * 18)
                cellWidth: Theme.px(18)
                cellHeight: Theme.px(18)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                visible: win.mode === "apps"
                interactive: false
                model: win.results
                delegate: McSlot {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property string desc: modelData.comment.length ? modelData.comment : modelData.generic
                    item: modelData.item
                    iconSource: modelData.url
                    highlighted: win.selected === index && win.keyboardNav
                    tooltip: modelData.name
                    tooltipDescription: desc
                    tooltipCategory: win.categoryName(modelData)
                    onHoveredChanged: if (hovered) { win.keyboardNav = false; win.selected = index; }
                    onClicked: win.launchApp(modelData)
                    onRightClicked: win.toggleFav(modelData)
                    McItemIcon {   // favourites wear a small star
                        visible: win.isFav(slot.modelData.id)
                        x: Theme.px(10); y: Theme.px(1)
                        size: 7
                        name: "nether_star"
                    }
                    Loader {   // the keyboard cursor has a tooltip too
                        active: win.keyboardNav && win.selected === slot.index
                        sourceComponent: McTooltip {
                            title: slot.modelData.name
                            description: slot.desc
                            category: win.categoryName(slot.modelData)
                            target: slot
                            targetX: slot.width
                            targetY: 0
                        }
                    }
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => grid.contentY = Math.max(0, Math.min(Math.max(0, grid.contentHeight - grid.height),
                        grid.contentY - Math.sign(event.angleDelta.y) * Theme.px(18)))
                }
            }
            McScrollbar {
                x: Theme.px(174); y: Theme.px(17)
                height: Theme.px(win.rows * 18 + 2)
                variant: "creative"
                flickable: grid
                visible: win.mode === "apps"
            }

            // ---- nothing found / calculator / command
            Item {
                id: resultBox
                x: Theme.px(9); y: Theme.px(18)
                width: Theme.px(9 * 18); height: Theme.px(win.rows * 18)
                visible: win.mode !== "apps" || win.results.length === 0
                Rectangle { anchors.fill: parent; visible: win.mode !== "apps"; color: Theme.slot }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.px(12)
                    spacing: Theme.px(4)
                    McItemIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: win.mode === "calc" ? "comparator" : win.mode === "run" ? "command_block" : "barrier"
                    }
                    McText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere
                        text: win.mode === "calc" ? (win.calc.ok ? "= " + Calc.format(win.calc.value) : (win.calc.error.length ? win.calc.error : "..."))
                            : win.mode === "run" ? (win.query.substring(1).trim().length ? "/" + win.query.substring(1).trim() : "Type a command")
                            : (win.tabs[win.category].key === "fav" && !win.query.trim().length ? "Nothing here yet" : "Nothing found")
                        color: win.mode === "calc" && !win.calc.ok && win.calc.error.length ? Theme.chatReadable("c") : Theme.guiText
                        font.pixelSize: win.mode === "calc" && win.calc.ok ? Theme.fontPx(2) : Theme.fontPx(1)
                    }
                    McText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: Theme.textMuted
                        text: win.mode === "calc" ? "Calculator. Enter copies the result."
                            : win.mode === "run" ? "Command block. Enter runs it."
                            : (win.tabs[win.category].key === "fav" && !win.query.trim().length ? "Right-click an app to add it." : "")
                    }
                }
            }

            // ---- hotbar row: the first nine favourites
            Row {
                x: Theme.px(9); y: Theme.px(18 + win.rows * 18 + 4)
                Repeater {
                    model: 9
                    McSlot {
                        required property int index
                        readonly property var app: win.favApps[index] || null
                        item: app ? app.item : ""
                        iconSource: app ? app.url : ""
                        tooltip: app ? app.name : ""
                        tooltipDescription: app ? (app.comment.length ? app.comment : app.generic) : ""
                        tooltipCategory: app ? win.categoryName(app) : ""
                        onClicked: if (app) win.launchApp(app)
                        onRightClicked: if (app) win.toggleFav(app)
                    }
                }
            }
        }
        McText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.y + stage.height + Theme.px(32)
            color: Theme.tooltipDesc
            text: win.mode !== "apps" ? "Enter: accept   Esc: close"
                : win.results.length + (win.results.length === 1 ? " app" : " apps") + "   Enter: open   Tab: next tab   Right-click, Ctrl+F: favourite   = sum   > run"
        }
    }
}
