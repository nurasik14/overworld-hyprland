pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets.Services
import "ChatCommands.js" as Cmd

/*  ChatService — the chat log, the command interpreter, completion, history and reminders.
 *    lines            [{id, t, text (§-codes), color, hover: {title, description, label, prefix} | null}] newest last, ≤ 120
 *    post(text, color)        a plain line; `color` "#rrggbb" or "" (§-codes inside text work too)
 *    system(text) / error(text)       grey info line / red error line
 *    submit(text)             a typed line: "/command args" or a chat message
 *    completions(text) → {start, prefix, items[]};   tab(text, backwards) → new text (cycles through candidates)
 *    historyPrev()/historyNext(current) · history
 *  Other modules post with GameEvents.emit("chat.say", {text, color}) — see docs/GAMEPLAY.md.
 */
Singleton {
    id: root
    property var lines: []
    property int nextId: 1
    property var history: []
    property int histPos: -1
    property string histDraft: ""
    property var reminders: []
    signal linePosted(var line)
    signal cleared()

    // ---------------------------------------------------------------- commands (chat.json + what lore-writer did not list)
    readonly property var extraCommands: ({
        say:   { usage: "/say <message>", description: "Sends a chat message.", args: [{ name: "message", type: "text" }] },
        me:    { usage: "/me <action>", description: "Describes an action in chat.", args: [{ name: "action", type: "text" }] },
        msg:   { usage: "/msg <text> in <duration>", description: "Reminds you later with a notification, e.g. /msg stretch in 20m. /msg list shows pending ones.",
                 args: [{ name: "text", type: "text" }] },
        options: { usage: "/options", description: "Opens the options screen.", args: [] },
        advancement: { usage: "/advancement [open|list|grant|revoke|reset] [id|tab|all]", description: "Opens the advancements screen, lists progress, grants/revokes one (testing aid), or resets everything (/advancement reset confirm).",
                       args: [{ name: "action", type: "choice", choices: ["open", "list", "grant", "revoke", "reset"] }, { name: "target", type: "advancement" }] },
        kill:  { usage: "/kill [class]", description: "Mines the focused window, or the first window of that class.", args: [{ name: "class", type: "window" }] },
        seed:  { usage: "/seed [current]", description: "Rolls a new random wallpaper world and shows its seed; /seed current only shows it.", args: [{ name: "which", type: "choice", choices: ["current"] }] },
        project: { usage: "/project [add <title>|done <n|title>|undone|remove|undo|list|open]", description: "Your to-do card: /project add Hyprland rice, /project done 2 (number from /project list, or the start of the title), /project remove …, /project undo (5 s). Bare /project opens the add dialog.",
                   args: [{ name: "action", type: "choice", choices: ["add", "done", "undone", "toggle", "remove", "undo", "list", "edit", "open"] }, { name: "project", type: "project" }] },
        note: { usage: "/note [<text>|list]", description: "Sticky notes: /note <text> pins a sheet to the Notes card, /note list shows them. Bare /note opens the sheet to write on.",
                args: [{ name: "text", type: "choice", choices: ["list"] }] },
        clear: { usage: "/clear", description: "Clears the chat and the notification history.", args: [] }
    })
    readonly property var commandSpecs: {
        const base = (GameCore.chatTexts.help || {}).commands || [];
        const map = {};
        base.forEach(c => { map[c.name] = c; });
        for (const k in extraCommands) map[k] = Object.assign({ name: k }, map[k] || {}, extraCommands[k]);
        return map;
    }
    readonly property var commandNames: Object.keys(commandSpecs).sort()

    // ---------------------------------------------------------------- posting
    function post(text, color, hover) {
        const line = { id: nextId++, t: Date.now(), text: String(text), color: color || "", hover: hover || null };
        const list = root.lines.concat([line]);
        root.lines = list.length > 120 ? list.slice(list.length - 120) : list;
        root.linePosted(line);
        return line;
    }
    function system(text) { return post(text, "#aaaaaa"); }
    function error(text) { return post(text, "#ff5555"); }
    function ok(text) { return post(text, ""); }
    function clearLog() { root.lines = []; root.cleared(); }

    Connections {
        target: GameCore
        function onDryRunLogged(line) { root.system("[dry-run] " + line); }
    }

    // ---------------------------------------------------------------- history
    JsonStore {
        id: histStore
        path: GameCore.statePath("chat-history.json")
        array: true
        onLoadedFile: root.history = Array.isArray(histStore.data) ? histStore.data.slice(-100) : []
    }
    function remember(text) {
        const h = root.history.slice();
        if (h.length && h[h.length - 1] === text) { root.histPos = -1; return; }
        h.push(text);
        root.history = h.slice(-100);
        histStore.data = root.history;
        histStore.save();
        root.histPos = -1;
    }
    function historyPrev(current) {
        if (history.length === 0) return current;
        if (histPos < 0) { histDraft = current; histPos = history.length; }
        histPos = Math.max(0, histPos - 1);
        return history[histPos];
    }
    function historyNext(current) {
        if (histPos < 0) return current;
        histPos++;
        if (histPos >= history.length) { histPos = -1; return histDraft; }
        return history[histPos];
    }

    // ---------------------------------------------------------------- lookups
    function windows() {
        const out = [];
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            const t = list[i], o = t.lastIpcObject || {};
            let addr = String(t.address || o.address || "");
            if (addr && addr.indexOf("0x") !== 0) addr = "0x" + addr;
            out.push({ address: addr, cls: o["class"] || "", title: t.title || o.title || "",
                       ws: o.workspace ? o.workspace.id : (t.workspace ? t.workspace.id : 0) });
        }
        return out;
    }
    function apps() {
        const out = [], list = DesktopEntries.applications.values;
        for (let i = 0; i < list.length; i++) if (!list[i].noDisplay) out.push(list[i]);
        return out;
    }
    function findApp(word) {
        let best = null, score = 0;
        apps().forEach(e => {
            const s = Cmd.matchScore(word, [e.id.replace(/\.desktop$/, ""), e.name, e.startupClass, e.genericName]);
            if (s > score) { score = s; best = e; }
        });
        return best;
    }
    function currentWs() { return HyprlandState.focusedId; }
    function findWindow(word) {
        let best = null, bestScore = 0, bestDist = 1e9;
        windows().forEach(w => {
            const s = Cmd.matchScore(word, [w.cls, w.title]);
            const dist = Math.abs(w.ws - currentWs());
            if (s > bestScore || (s === bestScore && s > 0 && dist < bestDist)) { best = w; bestScore = s; bestDist = dist; }
        });
        return best;
    }

    // ---------------------------------------------------------------- completion
    function candidatesFor(spec, w, argIndex) {
        if (!spec) return [];
        const typ = spec.type;
        if (typ === "choice" || typ === "duration") return spec.choices || [];
        if (typ === "workspace") return ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"];
        if (typ === "command") return commandNames;
        if (typ === "app") {
            const out = [];
            apps().forEach(e => out.push(Cmd.slug(e.name) || e.id.replace(/\.desktop$/, "")));
            windows().forEach(x => { if (x.cls) out.push(x.cls.toLowerCase()); });
            return out;
        }
        if (typ === "window") return windows().filter(x => x.cls).map(x => x.cls.toLowerCase());
        if (typ === "advancement") {
            const out = ["all"];
            Advancements.tabs.forEach(t => out.push(t.id));
            Advancements.defs.forEach(d => out.push(d.id));
            return out;
        }
        return [];
    }
    function completions(text) {
        const none = { start: text.length, prefix: "", items: [] };
        if (text.charAt(0) !== "/") return none;
        const body = text.slice(1);
        const endsSpace = /\s$/.test(body);
        const w = Cmd.words(body);
        const argIndex = endsSpace ? w.length : Math.max(0, w.length - 1);
        const prefix = endsSpace ? "" : (w[w.length - 1] || "");
        const start = text.length - prefix.length;
        let items = [];
        if (argIndex === 0) items = commandNames;
        else {
            const spec = commandSpecs[(w[0] || "").toLowerCase()];
            if (!spec) return none;
            const args = spec.args || [];
            let a = args[argIndex - 1];
            const first = (w[1] || "").toLowerCase();
            if (spec.name === "time") a = argIndex === 1 ? { type: "choice", choices: ["set", "query"] }
                                      : (first === "set" && argIndex === 2 ? { type: "choice", choices: ["day", "night", "auto"] } : null);
            else if (spec.name === "advancement" && argIndex === 2) {
                if (first === "list") a = { type: "choice", choices: ["unlocked", "locked"].concat(Advancements.tabs.map(t => t.id)) };
                else if (first === "reset") a = { type: "choice", choices: ["confirm"] };
                else if (first !== "grant" && first !== "revoke") a = null;
            }
            if (a && a.type === "text") a = null;
            items = candidatesFor(a, w, argIndex);
            if (spec.name === "project" && argIndex >= 2) {            // titles contain spaces: complete the whole rest of the line
                const act = first === "rm" || first === "delete" ? "remove" : first;
                const pool = act === "done" ? ProjectsService.inProgress : act === "undone" ? ProjectsService.built
                           : (act === "remove" || act === "toggle" || act === "edit") ? ProjectsService.ordered : [];
                const typed = Cmd.restAfter(body, 2);
                return { start: text.length - typed.length, prefix: typed, items: Cmd.filterCandidates(pool.map(i => i.title), typed) };
            }
        }
        return { start: start, prefix: prefix, items: Cmd.filterCandidates(items, prefix) };
    }

    property var cycle: ({ base: "", items: [], index: -1, start: 0 })
    function tab(text, backwards) {
        const c = root.cycle;
        if (c.items.length > 0 && c.last === text) {
            const n = c.items.length;
            const i = (c.index + (backwards ? -1 : 1) + n) % n;
            const out = text.slice(0, c.start) + c.items[i];
            root.cycle = { items: c.items, index: i, start: c.start, last: out };
            return out;
        }
        const r = completions(text);
        if (r.items.length === 0) return text;
        if (r.items.length === 1) { root.cycle = { items: [], index: -1, start: 0, last: "" }; return text.slice(0, r.start) + r.items[0] + " "; }
        const cp = Cmd.commonPrefix(r.items);
        if (cp.length > r.prefix.length) { root.cycle = { items: [], index: -1, start: 0, last: "" }; return text.slice(0, r.start) + cp; }
        const i = backwards ? r.items.length - 1 : 0;
        const out = text.slice(0, r.start) + r.items[i];
        root.cycle = { items: r.items, index: i, start: r.start, last: out };
        return out;
    }
    function resetCycle() { root.cycle = { items: [], index: -1, start: 0, last: "" }; }

    // ---------------------------------------------------------------- submit / interpreter
    function submit(raw) {
        const text = String(raw || "").trim();
        if (!text.length) return;
        remember(text);
        if (text.charAt(0) === "/") {
            GameEvents.emit("chat.command", { cmd: text });
            run(text.slice(1));
        } else say(text);
    }
    function say(text) {
        if (!text.length) { error(GameCore.t("errors.empty_message")); return; }
        post(GameCore.t("system.message", { text: text }) || ("<" + GameCore.player + "> " + text));
    }
    function usageError(spec) {
        error(GameCore.t("errors.unknown_command"));
        if (spec) post("§7" + GameCore.t("help.usage", { usage: spec.usage }));
    }
    function run(body) {
        const w = Cmd.words(body);
        if (!w.length) return;
        const name = w[0].toLowerCase();
        const spec = commandSpecs[name];
        if (!spec) { error(GameCore.t("errors.unknown_command_hint")); return; }
        const a = w.slice(1);
        const rest = Cmd.restAfter(body, 1);
        switch (name) {
        case "help": return cmdHelp(a);
        case "time": return cmdTime(a, spec);
        case "weather": return cmdWeather(a, spec);
        case "gamemode": return cmdGamemode(a, spec);
        case "tp": return cmdTp(a, spec);
        case "give": return cmdGive(a, spec);
        case "kill": return cmdKill(a);
        case "locate": return cmdLocate(a, spec);
        case "seed": return cmdSeed(a);
        case "brew": return cmdBrew(a, rest, spec);
        case "title": return cmdTitle(a, body, spec);
        case "clear": NotificationService.dismissAll(); clearLog(); ok(GameCore.t("ok.clear")); return;
        case "advancement": return cmdAdvancement(a, spec);
        case "stats": GameUi.open("stats"); return;
        case "options": GameUi.open("options"); return;
        case "f3": return cmdF3(a, spec);
        case "reload": ok(GameCore.t("ok.reload")); system(GameCore.t("ok.reload_warn")); reloadTimer.start(); return;
        case "say": return say(rest);
        case "me": if (!rest.length) { error(GameCore.t("errors.empty_message")); return; } post("§f* " + GameCore.player + " " + rest); return;
        case "msg": return cmdMsg(rest, spec);
        case "project": return cmdProject(a, rest, spec);
        case "note": return cmdNote(rest);
        }
    }
    Timer { id: reloadTimer; interval: 600; onTriggered: { if (GameCore.dryRun) root.system("[dry-run] Quickshell.reload()"); else Quickshell.reload(false); } }

    function cmdHelp(a) {
        const per = (GameCore.chatTexts.help || {}).per_page || 7;
        const names = commandNames;
        if (a.length && !/^\d+$/.test(a[0])) {
            const spec = commandSpecs[a[0].replace(/^\//, "").toLowerCase()];
            if (!spec) { error(GameCore.t("errors.unknown_option", { value: a[0] })); return; }
            post("§e" + spec.usage);
            post("§f" + spec.description);
            return;
        }
        const pages = Math.max(1, Math.ceil(names.length / per));
        const page = Math.min(pages, Math.max(1, parseInt(a[0] || "1")));
        post("§2" + GameCore.t("help.header", { page: page, pages: pages }));
        names.slice((page - 1) * per, page * per).forEach(n => post("§e" + commandSpecs[n].usage + "§7 - " + commandSpecs[n].description));
        if (page === pages) system(GameCore.t("help.footer"));
    }
    function cmdTime(a, spec) {
        let v = (a[0] || "").toLowerCase();
        if (v === "set") v = (a[1] || "").toLowerCase();
        if (v === "query") { ok(GameCore.t("ok.time_query", { time: Qt.formatDateTime(new Date(), "HH:mm") + " (" + (Theme.isDark ? "Night" : "Day") + ")" })); return; }
        if (v !== "day" && v !== "night" && v !== "auto") { post("§c" + GameCore.t("errors.incorrect_argument")); post("§7" + spec.usage); return; }
        setTime(v);
        ok(GameCore.t("ok.time_" + v));
    }
    // day → `overworld light`, night → `overworld dark`, auto → the sun decides (fx-world); the choice is kept in config.json "daycycle"
    function setTime(v) {
        if (v === "day") GameCore.cli(["light"]);
        if (v === "night") GameCore.cli(["dark"]);
        Options.set("daycycle", v);
        GameCore.ipc("world", "daycycle", [v]);
    }
    function cmdWeather(a, spec) {
        const v = (a[0] || "").toLowerCase();
        if (["clear", "rain", "thunder", "snow", "auto"].indexOf(v) < 0) { post("§c" + GameCore.t("errors.incorrect_argument")); post("§7" + spec.usage); return; }
        GameCore.ipc("world", "weather", [v]);
        ok(GameCore.t("ok.weather_" + v));
    }
    function cmdGamemode(a, spec) {
        if (!a.length) { GameUi.open("switcher"); return; }
        const m = a[0].toLowerCase();
        if (!GameMode.valid(m)) { error(GameCore.t("errors.unknown_option", { value: a[0] })); post("§7" + spec.usage); return; }
        GameMode.set(m);      // the "gamemode" event posts the chat line
    }
    function cmdTp(a, spec) {
        const n = parseInt(a[0]);
        if (!(n >= 1 && n <= 10)) { error(GameCore.t("errors.invalid_workspace")); return; }
        GameCore.run(["hyprctl", "dispatch", "workspace", String(n)]);
        ok(GameCore.t("ok.tp", { ws: n }));
    }
    function cmdGive(a, spec) {
        if (!a.length) { usageError(spec); return; }
        const word = a.join(" ");
        const e = findApp(word);
        if (!e) { error(GameCore.t("errors.no_such_app", { value: word })); return; }
        if (GameCore.dryRun) system("[dry-run] launch " + e.id); else e.execute();
        GameEvents.emit("launcher.launch", { app: e.id.replace(/\.desktop$/, "") });
        ok(GameCore.t("ok.give", { app: e.name }));
    }
    function cmdKill(a) {
        let target = null;
        if (a.length) {
            target = findWindow(a.join(" "));
            if (!target) { error(GameCore.t("errors.not_running", { value: a.join(" ") })); return; }
            GameCore.run(["hyprctl", "dispatch", "focuswindow", "address:" + target.address]);
        } else {
            if (!HyprlandState.title && !HyprlandState.appClass) { error(GameCore.t("errors.no_window")); return; }
            target = { title: HyprlandState.title || HyprlandState.appClass };
        }
        GameCore.ipc("interact", "kill");
        ok(GameCore.t("ok.kill", { title: target.title || target.cls }));
    }
    function cmdLocate(a, spec) {
        if (!a.length) { usageError(spec); return; }
        const word = a.join(" ");
        const w = findWindow(word);
        if (!w) { error(GameCore.t("errors.not_running", { value: word })); return; }
        GameCore.run(["hyprctl", "dispatch", "focuswindow", "address:" + w.address]);
        ok(GameCore.t("ok.locate", { app: w.cls || word, ws: w.ws, title: w.title }));
    }
    function cmdSeed(a) {
        if (a[0] !== "current") GameCore.cli(["wallpaper", "random"]);
        seedProc.wait = a[0] === "current" ? 100 : 1800;
        seedDelay.interval = seedProc.wait;
        seedDelay.restart();
    }
    Timer { id: seedDelay; onTriggered: seedProc.running = true }
    Process {
        id: seedProc
        property int wait: 0
        command: [GameCore.gameScripts + "/wallpaper-seed.sh"]
        environment: ({ OW_STATE_DIR: GameCore.stateDir, OW_REPO: GameCore.repoDir })
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim();
                if (s.length) root.ok(GameCore.t("ok.seed", { seed: s }));
                else root.error("Could not read the wallpaper seed");
            }
        }
    }
    function cmdBrew(a, rest, spec) {
        if (!a.length) { usageError(spec); return; }
        if (a[0].toLowerCase() === "stop") { GameCore.ipc("brew", "reset"); ok(GameCore.t("ok.brew_stop")); return; }
        const sec = Cmd.parseDuration(a[0]);
        if (sec < 0) { error(GameCore.t("errors.invalid_duration", { value: a[0] })); return; }
        if (sec > 12 * 3600 || sec < 1) { error(GameCore.t("errors.duration_too_long")); return; }
        GameCore.ipc("brew", "start", [sec + "s"]);
        const task = Cmd.restAfter(rest, 1);
        ok(GameCore.t("ok.brew_start", { task: task.length ? task : "a potion", duration: Cmd.durationLabel(sec) }));
    }
    // /project add <title> · done|undone|toggle|remove|edit <n|title> · undo · list · open   (the list is Widgets/Services/ProjectsService)
    function cmdProject(a, rest, spec) {
        const P = ProjectsService;
        const sub = (a[0] || "open").toLowerCase();
        const arg = Cmd.restAfter(rest, 1);
        const T = GameCore.t;
        if (sub === "open") { GameUi.closeAll(); P.openDialog(""); return; }
        if (sub === "add") {
            if (!P.add(arg, "", false)) { usageError(spec); return; }
            ok(T("ok.project_add", { title: P.clean(arg) }));
            return;
        }
        if (sub === "list") {
            if (P.count === 0) { system(T("ok.project_none")); return; }
            post("§2" + T("ok.project_list_head", { progress: P.inProgress.length, built: P.built.length }));
            P.ordered.forEach(it => post((it.status === "built" ? "§a" : "§f") + " " + P.numberOf(it) + ". [" + (it.status === "built" ? "x" : " ") + "] " + it.title,
                                         "", it.note ? { title: it.title, description: it.note, frame: "task", prefix: "", label: it.title } : null));
            return;
        }
        if (sub === "undo") {
            if (P.undoRemove()) ok(T("ok.project_undo")); else error("Nothing to undo");
            return;
        }
        const verbs = { done: "done", built: "done", check: "done", undone: "undone", uncheck: "undone", toggle: "toggle",
                        remove: "remove", rm: "remove", delete: "remove", edit: "edit" };
        const verb = verbs[sub];
        if (!verb) { usageError(spec); return; }
        const r = P.find(arg);
        if (r.error) { error(r.error); return; }
        const it = r.item;
        if (verb === "edit") { GameUi.closeAll(); P.openDialog(it.id); return; }
        if (verb === "remove") { P.remove(it.id); ok(T("ok.project_remove", { title: it.title })); return; }
        const wantBuilt = verb === "done" ? true : verb === "undone" ? false : it.status !== "built";
        if ((it.status === "built") === wantBuilt) { system("[" + it.title + "] is already " + (wantBuilt ? "built" : "in progress")); return; }
        P.setBuilt(it.id, wantBuilt);
        if (!wantBuilt) ok(T("ok.project_undone", { title: it.title }));      // building one says its own line (project.built below)
    }
    // /note <text> pins a sheet · /note list · bare /note opens the editor   (the pad is Widgets/Services/NotesService)
    function cmdNote(rest) {
        const N = NotesService;
        if (!rest.length) { GameUi.closeAll(); N.openEditor("current"); return; }
        if (rest.toLowerCase() === "list") {
            if (N.count === 0) { system(GameCore.t("ok.note_none")); return; }
            post("§2" + GameCore.t("ok.note_list_head", { count: N.count }));
            N.sheets.forEach((s, k) => {
                const line = N.firstLine(s.text);
                post("§f " + (k + 1) + (s.id === N.currentId ? "* " : ". ") + line, "", s.text.trim() !== line ? { title: line, description: s.text, frame: "task", prefix: "", label: line } : null);
            });
            return;
        }
        if (N.add(rest)) ok(GameCore.t("ok.note_pinned"));
    }
    function cmdTitle(a, body, spec) {
        const n = parseInt(a[0]);
        if (!(n >= 1 && n <= 10)) { error(GameCore.t("errors.invalid_workspace")); return; }
        const text = Cmd.restAfter(body, 2);
        if (!text.length) {
            GameCore.cli(["ws", String(n), "--clear"]);
            ok(GameCore.t("ok.title_cleared", { ws: n }));
        } else {
            GameCore.cli(["ws", String(n), text]);
            ok(GameCore.t("ok.title_set", { ws: n, text: text }));
        }
        revealWs.ws = n; revealWs.restart();
    }
    Timer { id: revealWs; property int ws: 1; interval: 700; onTriggered: GameCore.ipc("workspace", "reveal", [String(ws)]) }
    function cmdF3(a, spec) {
        const v = (a[0] || "toggle").toLowerCase();
        if (["on", "off", "toggle"].indexOf(v) < 0) { error(GameCore.t("errors.unknown_option", { value: a[0] })); return; }
        GameCore.ipc("world", "f3", [v]);
        ok(GameCore.t(v === "off" ? "ok.f3_off" : "ok.f3_on"));
    }
    function cmdAdvancement(a, spec) {
        const sub = (a[0] || "open").toLowerCase();
        if (sub === "open") { GameUi.open("advancements"); return; }
        if (sub === "list") {
            const filter = (a[1] || "").toLowerCase();
            const total = Advancements.total, have = Advancements.unlockedCount;
            post("§e" + GameCore.player + " has " + have + " of " + total + " advancements");
            Advancements.tabs.forEach(t => {
                if (filter && filter !== "unlocked" && filter !== "locked" && filter !== t.id) return;
                const c = Advancements.tabCounts(t.id);
                post("§7" + t.title + ": §f" + c.done + "/" + c.total);
                if (filter) t.items.forEach(d => {
                    const u = Advancements.isUnlocked(d.id);
                    if (filter === "unlocked" && !u) return;
                    if (filter === "locked" && u) return;
                    post((u ? "§a [x] " : "§8 [ ] ") + d.title + " §7(" + d.id + ")");
                });
            });
            return;
        }
        if (sub === "reset") {
            if ((a[1] || "").toLowerCase() !== "confirm") {
                post("§eThis forgets all " + Advancements.unlockedCount + " of your advancements and cannot be undone.");
                post("§eTo go ahead, type §f/advancement reset confirm");
            } else Advancements.reset();
            return;
        }
        if (sub !== "grant" && sub !== "revoke") { error(GameCore.t("errors.unknown_option", { value: a[0] })); post("§7" + spec.usage); return; }
        if (a.length < 2) { post("§c" + GameCore.t("errors.expected", { what: "an advancement, tab or 'all'" })); return; }
        const r = sub === "grant" ? Advancements.grant(a[1]) : Advancements.revoke(a[1]);
        if (r.matched === 0) error(GameCore.t("errors.unknown_option", { value: a[1] }));
        else ok((sub === "grant" ? "Granted " : "Revoked ") + r.changed + " advancement" + (r.changed === 1 ? "" : "s") + (r.matched !== r.changed ? " (" + (r.matched - r.changed) + " already " + (sub === "grant" ? "granted" : "locked") + ")" : ""));
    }

    // ---------------------------------------------------------------- /msg reminders
    JsonStore {
        id: remStore
        path: GameCore.statePath("reminders.json")
        array: true
        onLoadedFile: root.reminders = Array.isArray(remStore.data) ? remStore.data : []
    }
    function saveReminders() { remStore.data = root.reminders; remStore.saveNow(); }
    function cmdMsg(rest, spec) {
        if (rest.toLowerCase() === "list") {
            if (!reminders.length) { system("No reminders are pending"); return; }
            reminders.forEach(r => post("§7" + Qt.formatDateTime(new Date(r.due), "HH:mm:ss") + " §f" + r.text));
            return;
        }
        const i = rest.toLowerCase().lastIndexOf(" in ");
        if (i < 1) { usageError(spec); return; }
        const text = rest.slice(0, i).trim(), durText = rest.slice(i + 4).trim();
        const sec = Cmd.parseDuration(durText);
        if (!text.length) { error(GameCore.t("errors.empty_message")); return; }
        if (sec < 1) { error(GameCore.t("errors.invalid_duration", { value: durText })); return; }
        if (sec > 7 * 24 * 3600) { error("Duration must be at most 7 days"); return; }
        root.reminders = root.reminders.concat([{ due: Date.now() + sec * 1000, text: text }]);
        saveReminders();
        ok("Reminder set: \"" + text + "\" in " + Cmd.durationLabel(sec));
    }
    function fireReminder(r) {
        post("§e[Reminder] §f" + r.text, "");
        GameCore.run(["notify-send", "-a", "Overworld", "-u", "normal", "Reminder", r.text]);
        Theme.playSound("bell");
    }
    Timer {
        interval: 1000; running: root.reminders.length > 0; repeat: true
        onTriggered: {
            const now = Date.now();
            const due = root.reminders.filter(r => r.due <= now);
            if (!due.length) return;
            root.reminders = root.reminders.filter(r => r.due > now);
            root.saveReminders();
            due.forEach(r => root.fireReminder(r));
        }
    }

    // ---------------------------------------------------------------- system lines from events
    function baseName(p) { return String(p || "").replace(/^.*\//, ""); }
    property int lastBatteryPercent: -1
    property bool lastCharging: false
    Connections {
        target: GameEvents
        function onEvent(name, d) {
            d = d || {};
            const T = GameCore.t;
            switch (name) {
            case "chat.say": root.post(String(d.text || ""), d.color || ""); break;
            case "chat.open": GameUi.openChat(d.prefill || ""); break;
            case "ui.open": GameUi.open(String(d.screen || "")); break;
            case "screenshot": root.post(T("system.saved_screenshot", { file: root.baseName(d.path) || "screenshot.png" })); break;
            case "xp.levelup": if (!d.catchup) root.post("§a" + T("system.level_up", { level: d.level })); break;
            case "brew.done": root.post(T("system.brew_done", { task: d.task || "a potion" })); break;
            case "rest.done": root.post(T("system.rest_done")); break;
            case "mode": root.post(T(d.mode === "dark" ? "system.mode_night" : "system.mode_day")); break;
            case "wallpaper.set": root.post(T("system.wallpaper", { name: root.baseName(d.path).replace(/\.[a-z0-9]+$/i, "") })); break;
            case "world.created": root.post(T("system.world_created", { name: root.baseName(d.path).replace(/\.[a-z0-9]+$/i, "") })); break;
            case "net.connect": root.post(T("system.wifi_joined", { ssid: d.ssid })); break;
            case "net.disconnect": root.post(T("system.wifi_left", { ssid: d.ssid })); break;
            case "gamemode": root.post(T("system.gamemode", { mode: GameMode.info(d.mode).name.replace(" Mode", "") })); break;
            case "window.kill": if (!d.synth) root.post(T("system.kill", { title: d.title || d.cls || "window" })); break;
            case "battery": root.battery(d); break;
            }
        }
    }
    function battery(d) {
        const pct = d.percent, ch = d.charging === true;
        if (ch !== lastCharging && lastBatteryPercent >= 0) post(GameCore.t(ch ? "system.charging" : "system.unplugged"));
        else if (!ch && pct <= 20 && (lastBatteryPercent < 0 || lastBatteryPercent > 20)) post("§c" + GameCore.t("system.low_battery", { percent: pct }));
        lastBatteryPercent = pct; lastCharging = ch;
    }
    property bool dndSeen: NotificationService.dnd
    Connections {
        target: NotificationService
        function onDndChanged() {
            if (NotificationService.dnd === root.dndSeen) return;
            root.dndSeen = NotificationService.dnd;
            root.post(GameCore.t(NotificationService.dnd ? "system.peaceful_on" : "system.peaceful_off"));
        }
    }
    Connections {
        target: ProjectsService
        function onProjectBuilt(item) {              // from the file diff: a click on the card, /project, the CLI, a text editor
            const text = GameCore.t("system.project_built", { title: "\u0001" });
            const mark = text.indexOf("[\u0001]");
            const i = mark >= 0 ? mark : text.indexOf("\u0001");
            if (i < 0) return;
            const prefix = text.slice(0, i), suffix = mark >= 0 ? text.slice(i + 3) : text.slice(i + 1);
            root.post("§f" + prefix + "§a[" + item.title + "]§f" + suffix, "", { title: item.title, description: item.note || "Project built", frame: "task", prefix: prefix, label: "[" + item.title + "]" });
        }
    }
    Connections {
        target: Advancements
        function onWasReset() { root.post("§e[Overworld] Advancements have been reset"); }
        function onAdvancementUnlocked(adv, silent) {
            if (silent) return;
            const key = adv.frame === "challenge" ? "advancement_challenge" : adv.frame === "goal" ? "advancement_goal" : "advancement_task";
            const text = GameCore.t("system." + key, { title: "\u0001" });          // the template reads "... [{title}]"; \u0001 marks the title
            const mark = text.indexOf("[\u0001]");
            const i = mark >= 0 ? mark : text.indexOf("\u0001");
            const prefix = text.slice(0, i), suffix = mark >= 0 ? text.slice(i + 3) : text.slice(i + 1);
            const colour = adv.frame === "challenge" ? "§5" : "§a";
            root.post("§f" + prefix + colour + "[" + adv.title + "]§f" + suffix, "", { title: adv.title, description: adv.description, frame: adv.frame, prefix: prefix, label: "[" + adv.title + "]" });
        }
    }
    // "joined the game" on every shell start, like the game; chat.json may still be loading at onCompleted
    property bool _greeted: false
    function _greet() {
        if (_greeted || !GameCore.t("system.join").length) return;
        _greeted = true;
        post(GameCore.t("system.join"), "#ffff55");
        post(GameCore.t("system.motd"), "#ffffff");
    }
    Connections { target: GameCore; function onChatTextsChanged() { root._greet(); } }
    Component.onCompleted: _greet()
}
