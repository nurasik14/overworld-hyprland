pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  Advancements — the engine. Loads quotes/advancements.json (trigger vocabulary: quotes/README.md), consumes every
 *  GameEvents event plus the derived $resume / $time / $day pseudo-events, persists progress to advancements.json.
 *
 *  Read:   defs · byId · tabs[{id, root, title, icon, background, items[], width, height}] · isUnlocked(id) · unlockedAt(id)
 *          progress(id) → {have, need, fraction, text} · tabCounts(tabId) → {done, total} · unlockedCount · total
 *  Write:  feed(name, data)            (called for every bus event; also for the derived events)
 *          grant(spec) / revoke(spec)  spec = id | tab id | "all"   (testing aids, used by /advancement)
 *          reset()                     forgets everything (screen button, IPC, CLI, /advancement reset confirm): unlocked + progress cleared,
 *                                      advancements.json rewritten at once, bus `advancement.reset {}`; uptime catch-up is off until the next shell start
 *  Signal: advancementUnlocked(var adv, bool silent)   → toast + chat line; the bus gets `advancement {id}` (silent unlocks: neither)
 *          wasReset()                  after reset() (the chat prints "[Overworld] Advancements have been reset")
 *  Node positions (GUI px, inside a tab): adv.x, adv.y = depth*dx, row*dy ;  adv.depth, adv.children[]
 *  The state file is only written when something changes (debounced) so a fresh install has none.
 */
Singleton {
    id: root
    readonly property string statePath: GameCore.statePath("advancements.json")
    readonly property int nodeDx: 34
    readonly property int nodeDy: 28
    property var defs: []
    property var byId: ({})
    property var tabs: []
    property var unlocked: ({})
    property var counters: ({})
    property int revision: 0
    readonly property int total: defs.length
    readonly property int unlockedCount: { const r = revision; return Object.keys(unlocked).length; }
    signal advancementUnlocked(var adv, bool silent)
    signal wasReset()
    property double resetAt: 0
    property bool catchupBlocked: false      // set by reset(): the uptime catch-up feed must not hand the levels straight back this session

    readonly property var tabBackgrounds: ({
        overworld: "gui/advancements/backgrounds/stone", adventure: "gui/advancements/backgrounds/adventure",
        husbandry: "gui/advancements/backgrounds/husbandry", nether: "gui/advancements/backgrounds/nether",
        end: "gui/advancements/backgrounds/end"
    })

    // ------------------------------------------------------------ definitions
    function build(list) {
        const idx = {};
        list.forEach(a => { a.children = []; idx[a.id] = a; });
        list.forEach(a => { if (a.parent && idx[a.parent]) idx[a.parent].children.push(a.id); });
        const order = [], map = {};
        list.forEach(a => {
            if (!map[a.tab]) { map[a.tab] = { id: a.tab, root: "", items: [] }; order.push(a.tab); }
            map[a.tab].items.push(a);
            if (!a.parent) map[a.tab].root = a.id;
        });
        const out = [];
        order.forEach(tid => {
            const tab = map[tid];
            let row = 0, maxDepth = 0;
            const place = (id, depth) => {
                const a = idx[id];
                a.depth = depth; maxDepth = Math.max(maxDepth, depth);
                if (a.children.length === 0) a.row = row++;
                else {
                    a.children.forEach(c => place(c, depth + 1));
                    a.row = (idx[a.children[0]].row + idx[a.children[a.children.length - 1]].row) / 2;
                }
                a.x = depth * root.nodeDx; a.y = a.row * root.nodeDy;
            };
            if (tab.root) place(tab.root, 0);
            const r = idx[tab.root] || {};
            tab.title = r.title || tid; tab.icon = r.icon || "grass_block";
            tab.background = root.tabBackgrounds[tid] || "gui/advancements/backgrounds/stone";
            tab.width = (maxDepth + 1) * root.nodeDx; tab.height = Math.max(1, row) * root.nodeDy;
            out.push(tab);
        });
        root.byId = idx; root.defs = list; root.tabs = out;
    }

    FileView {
        path: GameCore.quotesDir + "/advancements.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.build(JSON.parse(text()).advancements || []); } catch (e) { console.warn("Advancements: advancements.json:", e); } }
    }
    JsonStore {
        id: store
        path: root.statePath
        onLoadedFile: {
            root.unlocked = store.data.unlocked || ({});
            root.counters = store.data.progress || ({});
            root.revision++;
        }
    }
    function persist() {
        store.data = { version: 1, unlocked: root.unlocked, progress: root.counters };
        store.save();
    }
    function reset() {
        const had = Object.keys(unlocked).length;
        root.catchupBlocked = true; root.resetAt = Date.now();
        root.unlocked = ({}); root.counters = ({}); root.revision++;
        store.data = { version: 1, unlocked: {}, progress: {} };
        store.saveNow();
        GameEvents.emit("advancement.reset", {});
        root.wasReset();
        return had;
    }

    // ------------------------------------------------------------ icons
    // icon names in advancements.json are item/block names; blocks without an item sprite use their _front/_side/_top texture
    property var iconCache: ({})
    function iconUrl(name) {
        if (!Theme.ready || !name) return Theme.missingTexture;
        const hit = iconCache[name];
        if (hit !== undefined) return hit;
        let url = Theme.iconUrl(name);
        if (url === Theme.missingTexture) {
            const tries = ["block/" + name + "_front", "block/" + name + "_side", "block/" + name + "_top", "item/" + name + "_00"];
            for (let i = 0; i < tries.length && url === Theme.missingTexture; i++) url = Theme.tex(tries[i]);
        }
        iconCache[name] = url;
        return url;
    }

    // ------------------------------------------------------------ queries
    function isUnlocked(id) { return revision >= 0 && unlocked[id] !== undefined; }
    function unlockedAt(id) { return unlocked[id] || 0; }
    function partsOf(a) { const t = a.trigger || {}; return t.all ? t.all : [t]; }
    function partNeed(p) { return Math.max(1, p.count || 1); }
    function partHave(id, i) {
        const c = counters[id]; const e = c && c[i];
        return e ? e.n : 0;
    }
    function progress(id) {
        const r = revision;
        const a = byId[id];
        if (!a) return { have: 0, need: 1, fraction: 0, text: "" };
        if (isUnlocked(id)) return { have: 1, need: 1, fraction: 1, text: "" };
        const parts = partsOf(a);
        if (parts.length === 1) {
            const p = parts[0];
            if ((p.condition || {}).unlocked_at_least) {
                const others = defs.filter(d => d.id !== id);
                const have = others.filter(d => isUnlocked(d.id)).length;
                return { have, need: others.length, fraction: have / Math.max(1, others.length), text: have + "/" + others.length };
            }
            const need = partNeed(p), have = Math.min(need, partHave(id, 0));
            return { have, need, fraction: have / need, text: need > 1 ? have + "/" + need : "" };
        }
        let done = 0;
        parts.forEach((p, i) => { if (partHave(id, i) >= partNeed(p)) done++; });
        return { have: done, need: parts.length, fraction: done / parts.length, text: done + "/" + parts.length + " requirements" };
    }
    function tabCounts(tabId) {
        const r = revision;
        const tab = tabs.find(t => t.id === tabId);
        if (!tab) return { done: 0, total: 0 };
        let done = 0;
        tab.items.forEach(a => { if (unlocked[a.id] !== undefined) done++; });
        return { done, total: tab.items.length };
    }

    // ------------------------------------------------------------ matching
    function norm(v) { return typeof v === "string" ? v.toLowerCase() : v; }
    function fieldOk(expect, actual) {
        if (expect !== null && typeof expect === "object") {
            if (Array.isArray(expect.in) && !expect.in.some(x => norm(x) === norm(actual))) return false;
            if ("gte" in expect && !(Number(actual) >= expect.gte)) return false;
            if ("lte" in expect && !(Number(actual) <= expect.lte)) return false;
            if ("startswith" in expect && !(typeof actual === "string" && norm(actual).startsWith(norm(expect.startswith)))) return false;
            return true;
        }
        return norm(expect) === norm(actual);
    }
    function hm(s) { const m = /^(\d{1,2}):(\d{2})/.exec(s || ""); return m ? parseInt(m[1]) * 60 + parseInt(m[2]) : -1; }
    function timeOk(range, data) {
        const now = new Date();
        let at = hm(data.at);
        if (at < 0) at = now.getHours() * 60 + now.getMinutes();
        const a = hm(range.from), b = hm(range.to);
        if (a < 0 || b < 0) return false;
        return a <= b ? (at >= a && at < b) : (at >= a || at < b);
    }
    function conditionOk(cond, data) {
        if (!cond) return true;
        if (cond.where) for (const k in cond.where) if (!fieldOk(cond.where[k], data[k])) return false;
        if (cond.time && !timeOk(cond.time, data)) return false;
        return true;
    }

    // ------------------------------------------------------------ feeding
    function feed(name, data) {
        data = data || {};
        if (data.catchup === true && catchupBlocked) return;
        // the "/advancement reset confirm" that caused a reset reaches the bus a moment after the reset (file tail): it must not earn "First Words" on a clean slate
        if (name === "chat.command" && Date.now() - resetAt < 5000 && /^\/advancement\s+reset/i.test(String(data.cmd || ""))) return;
        const toUnlock = [];
        let dirty = false;
        const prog = Object.assign({}, counters);
        defs.forEach(a => {
            if (unlocked[a.id] !== undefined) return;
            const parts = partsOf(a);
            let touched = false;
            const entry = (prog[a.id] || []).map(e => e ? { n: e.n, seen: (e.seen || []).slice() } : { n: 0, seen: [] });
            while (entry.length < parts.length) entry.push({ n: 0, seen: [] });
            parts.forEach((p, i) => {
                if (p.event !== name) return;
                const cond = p.condition || {};
                if (cond.unlocked_at_least) {
                    if (defs.every(d => d.id === a.id || unlocked[d.id] !== undefined)) { entry[i].n = partNeed(p); touched = true; }
                    return;
                }
                if (!conditionOk(cond, data)) return;
                if (cond.distinct) {
                    const v = String(data[cond.distinct]);
                    if (data[cond.distinct] === undefined || entry[i].seen.indexOf(v) >= 0) return;
                    entry[i].seen.push(v);
                    entry[i].n = entry[i].seen.length;
                } else entry[i].n++;
                touched = true;
            });
            if (!touched) return;
            prog[a.id] = entry; dirty = true;
            if (parts.every((p, i) => entry[i].n >= partNeed(p))) toUnlock.push(a.id);
        });
        if (dirty) { root.counters = prog; }
        toUnlock.forEach(id => unlock(id, data.catchup === true));     // catch-up feeds (uptime at shell start) unlock without toast or chat line
        if (dirty && toUnlock.length === 0) persist();
    }

    function unlock(id, silent) {
        const a = byId[id];
        if (!a || unlocked[id] !== undefined) return false;
        const u = Object.assign({}, unlocked); u[id] = Date.now();
        root.unlocked = u; root.revision++;
        persist();
        root.advancementUnlocked(a, silent);
        if (!silent) GameEvents.emit("advancement", { id });
        return true;
    }
    function resolveSpec(spec) {
        if (spec === "all" || spec === "*") return defs.map(d => d.id);
        if (byId[spec]) return [spec];
        const tab = tabs.find(t => t.id === spec);
        if (tab) return tab.items.map(d => d.id);
        // unique suffix / title match: "terminal" → overworld/terminal
        const s = String(spec).toLowerCase();
        const hit = defs.filter(d => d.id.toLowerCase().endsWith("/" + s) || d.title.toLowerCase() === s);
        return hit.map(d => d.id);
    }
    function grant(spec) {
        const ids = resolveSpec(spec);
        let n = 0;
        ids.forEach(id => { if (unlock(id, false)) n++; });
        return { matched: ids.length, changed: n };
    }
    function revoke(spec) {
        const ids = resolveSpec(spec);
        const u = Object.assign({}, unlocked), p = Object.assign({}, counters);
        let n = 0;
        ids.forEach(id => { if (u[id] !== undefined) { delete u[id]; n++; } delete p[id]; });
        root.unlocked = u; root.counters = p; root.revision++;
        persist();
        return { matched: ids.length, changed: n };
    }

    // ------------------------------------------------------------ the bus + derived events
    Connections {
        target: GameEvents
        function onEvent(name, data) { root.feed(name, data); }
    }
    property double lastBeat: Date.now()
    property string lastDay: ""
    Timer {   // $resume: the wall clock jumped far past this timer's interval = the machine slept
        interval: 5000; running: true; repeat: true
        onTriggered: {
            const now = Date.now();
            if (now - root.lastBeat > 120000) root.feed("$resume", { gap: Math.round((now - root.lastBeat) / 1000) });
            root.lastBeat = now;
        }
    }
    Timer {   // $time once a minute, $day once per local calendar day
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            root.feed("$time", { at: GameCore.pad2(d.getHours()) + ":" + GameCore.pad2(d.getMinutes()) });
            const key = GameCore.dateKey(d);
            if (key !== root.lastDay) { root.lastDay = key; root.feed("$day", { date: key }); }
        }
    }
}
