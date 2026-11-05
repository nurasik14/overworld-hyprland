pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  GameEvents — the shell-wide event bus (contract: BRIEF.md §4.4). Owner after phase 0: qs-features.
 *
 *  Emit:    GameEvents.emit("window.kill", { cls: "kitty" })
 *  Listen:  Connections { target: GameEvents; function onEvent(name, data) { ... } }
 *  Outside QML: `overworld event <name> ['<json>']` appends the same line format.
 *
 *  Every event (from QML or the CLI) is appended as one JSON line {"t":<ms>,"name":..,"data":{..}} to
 *  $XDG_RUNTIME_DIR/overworld/events.jsonl and delivered to listeners ONLY through the tail below, so an
 *  event is seen exactly once whatever its origin.
 */
Singleton {
    id: root
    signal event(string name, var data)

    // OW_EVENTS_DIR gives a test process a private bus: previews that fake events (`overworld event …` with XDG_RUNTIME_DIR pointing
    // there too) then cannot leak into another running shell's advancements / statistics.
    readonly property string runtimeDir: Quickshell.env("OW_EVENTS_DIR") || ((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/overworld")
    readonly property string logPath: runtimeDir + "/events.jsonl"

    function emit(name, data) {
        const line = JSON.stringify({ t: Date.now(), name: String(name), data: data || {} });
        writer.queue.push(line);
        if (!writer.busy) writer.next();
    }

    Process {
        id: writer
        property var queue: []
        property bool busy: false
        function next() {
            if (queue.length === 0) { busy = false; return; }
            busy = true;
            const line = queue.shift();
            command = ["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" >> "$3"', "sh", root.runtimeDir, line, root.logPath];
            running = true;
        }
        onExited: next()
    }

    Process {
        id: tail
        running: true
        command: ["sh", "-c", 'mkdir -p "$1" && touch "$2" && exec tail -n0 -F "$2" 2>/dev/null', "sh", root.runtimeDir, root.logPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                try { const e = JSON.parse(line); root.event(e.name, e.data || {}); }
                catch (err) { console.warn("GameEvents: bad line", line); }
            }
        }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 2000; onTriggered: tail.running = true }
}
