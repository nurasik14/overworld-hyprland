pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

/*  WidgetsState — visibility of the desktop widget layer.
 *    visible   persisted in ~/.config/overworld/widgets-visible ("true" / "false"), default true
 *    demo      show mocked music data (env OW_WIDGETS_DEMO=1 or `widgets demo on`)
 *    positions persisted in ~/.config/overworld/widget-positions.json  {cardId: [x, y]} (dragged cards)
 *    hiddenCards  cards switched off individually (bar chip 󰕮 menu), ~/.config/overworld/widgets-hidden.json
 *    cardOpacity  card fill alpha = Theme.widgetOpacity (config.json → {"widgets":{"opacity":0.72}}), clamped 0.2–1
 *    dragging  true while a card is dragged (the layer then takes input everywhere so a fast drag can't escape)
 *  IPC:  qs -c overworld ipc call widgets toggle | show | hide | demo on|off | status | layout (reset positions)
 *        | menu | card <id> (toggle one: weather music calendar sysinfo cava quote block brew projects notes; `herb` is an alias of
 *        `block`) | cards (list)
 */
Singleton {
    id: root
    property bool visible: true
    property bool demo: (Quickshell.env("OW_WIDGETS_DEMO") || Quickshell.env("APO_WIDGETS_DEMO")) === "1"
    readonly property string statePath: Quickshell.env("HOME") + "/.config/overworld/widgets-visible"

    FileView {
        id: file
        path: root.statePath
        blockLoading: true
        printErrors: false
        onLoaded: root.applyText(text())
    }
    function applyText(t) {
        const s = (t || "").trim().toLowerCase();
        root.visible = !(s === "false" || s === "0" || s === "hidden" || s === "no");
    }

    Process {
        id: writer
        property string value: "true"
        command: ["sh", "-c", "mkdir -p \"$HOME/.config/overworld\" && printf '%s\\n' \"$1\" > \"$HOME/.config/overworld/widgets-visible\"", "overworld-widgets", value]
    }
    function persist() { writer.value = root.visible ? "true" : "false"; writer.running = true }

    // ---- card positions (drag a card by its title bar; double-click the title bar = back to its slot)
    property var positions: ({})
    signal layoutReset()
    readonly property string posPath: Quickshell.env("HOME") + "/.config/overworld/widget-positions.json"
    FileView {
        id: posFile
        path: root.posPath
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        applyText(file.text());
        try { root.positions = JSON.parse(posFile.text() || "{}") || {} } catch (e) { root.positions = {} }
        try { const h = JSON.parse(hiddenFile.text() || "[]"); root.hiddenCards = Array.isArray(h) ? h : [] } catch (e) { root.hiddenCards = [] }
    }
    Process {
        id: posWriter
        property string value: "{}"
        command: ["sh", "-c", "mkdir -p \"$HOME/.config/overworld\" && printf '%s\\n' \"$1\" > \"$HOME/.config/overworld/widget-positions.json\"", "overworld-widgets", value]
    }
    function posX(id, d) { const p = root.positions[id]; return p ? p[0] : d }
    function hasPos(id) { return !!root.positions[id] }
    function posY(id, d) { const p = root.positions[id]; return p ? p[1] : d }
    function savePositions() { posWriter.value = JSON.stringify(root.positions); posWriter.running = true }
    function setPos(id, x, y) {
        if (!id) return;
        const n = Object.assign({}, root.positions); n[id] = [Math.round(x), Math.round(y)];
        root.positions = n; savePositions();
    }
    function resetPos(id) {
        const n = Object.assign({}, root.positions); delete n[id];
        root.positions = n; savePositions(); root.layoutReset();
    }
    function resetAll() { root.positions = {}; savePositions(); root.layoutReset() }

    // ---- per-card on/off
    // `item` = the Minecraft item that stands for the card (bar menu icon); `cjk` is a legacy one-letter badge kept for the
    // bar's menu rows until qs-core switches them to `item`.
    readonly property var cardList: [
        { id: "weather",  cjk: "W", item: "water_bucket",   name: "Weather" },
        { id: "music",    cjk: "J", item: "jukebox",        name: "Jukebox" },
        { id: "calendar", cjk: "C", item: "clock",          name: "Clock & Calendar" },
        { id: "sysinfo",  cjk: "F", item: "grass_block",    name: "System (F3)" },
        { id: "cava",     cjk: "N", item: "note_block",     name: "Note block" },
        { id: "quote",    cjk: "S", item: "oak_sign",       name: "Sign" },
        { id: "block",    cjk: "B", item: "item_frame",     name: "Block of the day" },
        { id: "brew",     cjk: "P", item: "brewing_stand",  name: "Brewing stand" },
        { id: "projects", cjk: "R", item: "writable_book",  name: "Projects" },
        { id: "notes",    cjk: "T", item: "paper",          name: "Notes" }
    ]
    property var hiddenCards: []
    property bool dragging: false
    property bool menuOpen: false          // the bar's widgets menu (IPC `widgets menu`)
    readonly property string hiddenPath: Quickshell.env("HOME") + "/.config/overworld/widgets-hidden.json"
    FileView { id: hiddenFile; path: root.hiddenPath; blockLoading: true; printErrors: false }
    Process {
        id: hiddenWriter
        property string value: "[]"
        command: ["sh", "-c", "mkdir -p \"$HOME/.config/overworld\" && printf '%s\\n' \"$1\" > \"$HOME/.config/overworld/widgets-hidden.json\"", "overworld-widgets", value]
    }
    function cardOn(id) { return root.hiddenCards.indexOf(id) < 0 && !(id === "block" && root.hiddenCards.indexOf("herb") >= 0) }
    function setCard(id, on) {
        const n = root.hiddenCards.filter(x => x !== id);
        if (!on) n.push(id);
        root.hiddenCards = n;
        hiddenWriter.value = JSON.stringify(n); hiddenWriter.running = true;
        if (on && !root.visible) show();          // switching a card on also brings the layer back
    }
    function toggleCard(id) { setCard(id, !cardOn(id)) }

    // ---- card transparency (fill alpha); text stays fully opaque
    // OW_WIDGETS_OPACITY pins the fill for preview screenshots (the live desktop's own cards would shine through otherwise)
    readonly property real cardOpacity: Quickshell.env("OW_WIDGETS_OPACITY") ? parseFloat(Quickshell.env("OW_WIDGETS_OPACITY")) : Math.max(0.2, Math.min(1, Theme.widgetOpacity))

    function show() { root.visible = true; persist() }
    function hide() { root.visible = false; persist() }
    function toggle() { root.visible ? hide() : show() }

    IpcHandler {
        target: "widgets"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        // `qs ipc call widgets show` is swallowed by the qs CLI (`show` is also the `qs ipc show` subcommand and
        // prints the target listing instead of calling) -> use `reveal` from scripts/keybinds.
        function reveal(): void { root.show() }
        function hide(): void { root.hide() }
        function demo(on: string): void { root.demo = (on === "on" || on === "1" || on === "true") }
        function layout(): void { root.resetAll() }
        function card(id: string): void { root.toggleCard(id === "herb" ? "block" : id) }
        function menu(): void { root.menuOpen = !root.menuOpen }
        function cards(): string { return root.cardList.map(c => c.id + (root.cardOn(c.id) ? " on" : " off")).join(", ") }
        function status(): string { return (root.visible ? "visible" : "hidden") + (root.demo ? " (demo)" : "") }
    }
}
