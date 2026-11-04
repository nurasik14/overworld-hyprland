import QtQuick
import Quickshell.Io

/*  BindsModel — the Controls page's keybind table. Source: `hyprctl binds -j` (what is really bound right now).
 *    rows: [{keys: "SUPER + SHIFT + W", action: "Wallpapers: next", mine: true}] sorted with the Overworld binds first
 *    load()   (re)read; empty rows + `error` when hyprctl cannot be reached
 *  Docs fallback: docs/KEYBINDS.md is what the table was written from; this reads the live truth instead.
 */
Item {
    id: root
    property var rows: []
    property string error: ""
    readonly property var modNames: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]

    function keysText(mask, key, keycode) {
        const m = [];
        modNames.forEach(p => { if (mask & p[0]) m.push(p[1]); });
        let k = String(key || "");
        if (!k.length && keycode > 0) k = keycode >= 10 && keycode <= 18 ? String(keycode - 9) : keycode === 19 ? "0" : "Key " + keycode;   // X keycodes 10–19 are 1…0
        if (k.length === 1) k = k.toUpperCase();
        else if (/^code:/.test(k)) k = k.replace("code:", "Key ");
        else k = k.replace(/^(\w)/, c => c.toUpperCase());
        m.push(k);
        return m.join(" + ");
    }
    function cap(s) { return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
    function actionText(b) {
        if (b.has_description && b.description) return b.description;
        const arg = String(b.arg || "");
        if (b.dispatcher === "exec") {
            let m = /ipc call (\w+) (\w+)/.exec(arg);
            if (m) return cap(m[1]) + ": " + m[2];
            m = /\boverworld\s+(.+)$/.exec(arg);
            if (m) return "overworld " + m[1];
            return arg.length > 52 ? arg.slice(0, 51) + "…" : arg;
        }
        return b.dispatcher + (arg.length ? " " + arg : "");
    }
    function parse(text) {
        try {
            const list = JSON.parse(text);
            const out = list.filter(b => !b.mouse).map(b => ({
                keys: keysText(b.modmask, b.key, b.keycode), action: actionText(b),
                mine: /overworld|ipc call/.test(String(b.arg || "")) }));
            out.sort((a, b) => (b.mine - a.mine) || (a.keys < b.keys ? -1 : 1));
            root.rows = out; root.error = "";
        } catch (e) { root.rows = []; root.error = "Could not read the keybinds (hyprctl binds -j)"; }
    }
    function load() { proc.running = true; }
    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        onExited: code => { if (code !== 0) docs.running = true; }
    }
    // hyprctl unreachable: fall back to the tables of docs/KEYBINDS.md (`| `SUPER + Space` | Launcher | … |`)
    Process {
        id: docs
        command: ["cat", GameCore.repoDir + "/docs/KEYBINDS.md"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                text.split("\n").forEach(l => {
                    const m = /^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|/.exec(l);
                    if (m) out.push({ keys: m[1].replace(/\s*\+\s*/g, " + "), action: m[2], mine: true });
                });
                root.rows = out;
                root.error = out.length ? "hyprctl unreachable: showing docs/KEYBINDS.md" : "Could not read the keybinds";
            }
        }
    }
}
