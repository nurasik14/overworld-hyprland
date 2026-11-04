import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  Miner — the block-break window close ("mining the block").
 *
 *    Miner.kill(address, onlyClass)
 *        address   "" = the focused window (aborts if focus moves to another window while mining), else a Hyprland address
 *                  ("0x55d0…") that is mined whether focused or not
 *        onlyClass non-empty = refuse unless the window's class equals it (case-insensitive)
 *
 *  Sequence (config `interact.break_ms`, default 450 ms ≈ 9 ticks of the 20 TPS clock):
 *    1  read the window (hyprctl -j activewindow | clients): address, class, title, rect, workspace
 *    2  sample its colours (scripts/interact/capture-palette.sh → grim, in memory) — only while its workspace is the one on screen
 *    3  an overlay layer (overworld-break) tiles block/destroy_stage_N over the exact window rect, one frame per tick,
 *       block.hit.<material> every `interact.hit_every` ticks
 *    4  last frame: emit window.kill {cls,title}; next tick: block.break.<material>, `closewindow address:<addr>`, and the break
 *       particles (30–60 fragments of the sampled colours, gravity, ~0.6 s)
 *  Instant close (no overlay, no particles; the sound still plays): reduced motion, config interact.break=false,
 *  adventure/spectator game mode, or a window that is not on the visible workspace.
 *  Aborts, closing nothing: the focused window changed (focus-mode kill), the window closed by itself, another kill is running.
 *  Only `closewindow address:<that window>` is ever dispatched — never a class or "active" dispatch.
 */
Scope {
    id: root

    property string phase: "idle"          // idle | query | capture | mine
    readonly property bool busy: phase !== "idle"
    property var target: null              // { address, bare, cls, title, rect:{x,y,w,h}, ws, viaActive }
    property string onlyClass: ""
    property string pendingAddress: ""
    property string material: "stone"
    property var palette: []
    property int frame: 0
    property int frames: 9
    property int effectId: 0
    property int mismatch: 0
    property string lastResult: ""         // for `ipc call interact status` and the tests

    readonly property string captureScript: Theme.repoDir + "/scripts/interact/capture-palette.sh"
    readonly property string mode: ConfigService.gamemode
    readonly property int breakMs: Math.max(100, Number(ConfigService.get("interact.break_ms", 450)))
    readonly property int hitEvery: Math.max(1, Number(ConfigService.get("interact.hit_every", 2)))
    readonly property bool enabled: ConfigService.get("interact.break", true) !== false
    readonly property string activeAddr: bare(Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "")

    signal finished(string result)

    function bare(a) { return String(a || "").toLowerCase().replace(/^0x/, ""); }

    function kill(address, cls) {
        if (busy) { lastResult = "busy"; return false; }
        pendingAddress = address || "";
        onlyClass = cls || "";
        phase = "query";
        watchdog.interval = breakMs + 3500;
        watchdog.restart();
        queryProc.command = pendingAddress ? ["hyprctl", "-j", "clients"] : ["hyprctl", "-j", "activewindow"];
        queryProc.running = true;
        return true;
    }

    Timer { id: watchdog; onTriggered: if (root.busy) root._abort("timeout") }   // nothing may keep the overlay or the lock forever

    function _abort(why) {
        watchdog.stop();
        lastResult = "abort: " + why;
        if (effectId) { InteractFx.remove(effectId); effectId = 0; }
        capTimeout.stop();
        if (capProc.running) capProc.running = false;
        phase = "idle";
        target = null;
        root.finished(lastResult);
    }

    // ---------------------------------------------------------------- 1: which window
    Process {
        id: queryProc
        stdout: StdioCollector {
            onStreamFinished: root._queried(text)
        }
        onExited: code => { if (code !== 0 && root.phase === "query") root._abort("hyprctl failed"); }
    }
    function _queried(text) {
        if (phase !== "query") return;
        let w = null;
        try {
            const j = JSON.parse(text);
            if (pendingAddress) {
                const want = bare(pendingAddress);
                w = (Array.isArray(j) ? j : []).find(c => bare(c.address) === want) || null;
            } else w = j && j.address ? j : null;
        } catch (e) { return _abort("bad hyprctl output"); }
        if (!w || !w.address || w.mapped === false) return _abort("no such window");
        const cls = String(w["class"] || "");
        if (onlyClass.length && cls.toLowerCase() !== onlyClass.toLowerCase()) return _abort("class is " + cls + ", not " + onlyClass);
        target = {
            address: w.address, bare: bare(w.address), cls: cls, title: String(w.title || ""),
            rect: { x: w.at[0], y: w.at[1], w: w.size[0], h: w.size[1] },
            ws: w.workspace ? w.workspace.id : 0,
            viaActive: pendingAddress === ""
        };
        material = InteractFx.materialFor(cls, target.title);
        const visible = target.ws === HyprlandState.focusedId || (target.ws < 0 && HyprlandState.activeSpecial.length > 0);
        const calm = ConfigService.reducedMotion || !enabled || mode === "adventure" || mode === "spectator";
        if (calm || !visible || target.rect.w < 8 || target.rect.h < 8) return _instant();
        phase = "capture";
        capProc.command = [captureScript, String(target.rect.x), String(target.rect.y), String(target.rect.w), String(target.rect.h), "12", "8"];
        capTimeout.restart();
        capProc.running = true;
    }

    // ---------------------------------------------------------------- 2: colours of the window
    property var _capLines: []
    Process {
        id: capProc
        stdout: SplitParser { onRead: line => { if (/^[0-9a-f]{6}$/.test(line)) root._capLines.push(line); } }
        onStarted: root._capLines = []
        onExited: if (root.phase === "capture") { capTimeout.stop(); root._startMining(); }
    }
    Timer { id: capTimeout; interval: 400; onTriggered: if (root.phase === "capture") { capProc.running = false; root._startMining(); } }

    // ---------------------------------------------------------------- 3: the cracks
    function _fallbackPalette() {
        return [Theme.col("panel"), Theme.col("slot"), Theme.col("text")].map(c => Qt.color(c).toString().replace("#", "").slice(-6));
    }
    function _startMining() {
        palette = _capLines.length >= 6 ? _capLines.slice() : _fallbackPalette();
        frames = Math.max(2, Math.round(breakMs / 50));
        frame = 0;
        mismatch = 0;
        effectId = InteractFx.add("mine", target.rect, {}, breakMs + 4000);
        InteractFx.setStage(effectId, 0);
        InteractFx.sound("block.hit." + material);
        phase = "mine";
    }
    function _stageOf(f) { return Math.round(f * 9 / (frames - 1)); }

    McTicker {
        active: root.phase === "mine"
        onTicked: n => Qt.callLater(root._step)      // not inside the tick binding: _step may stop this very ticker
    }
    function _step() {
        if (phase !== "mine") return;
        if (target.viaActive) {      // focus moved on: leave the window alone
            mismatch = activeAddr === target.bare ? 0 : mismatch + 1;
            if (mismatch >= 3) return _abort("active window changed");
        }
        frame++;
        if (frame >= frames) return _finish();
        InteractFx.setStage(effectId, _stageOf(frame));
        if (frame % hitEvery === 0) InteractFx.sound("block.hit." + material);
        if (frame === frames - 1) GameEvents.emit("window.kill", { cls: target.cls, title: target.title });   // before the window closes
    }

    // ---------------------------------------------------------------- 4: break
    function _finish() {
        watchdog.stop();
        const t = target;
        InteractFx.remove(effectId);
        effectId = 0;
        InteractFx.sound("block.break." + material);
        Hyprland.dispatch("closewindow address:" + t.address);
        const n = Math.round(Math.max(30, Math.min(60, 30 + t.rect.w * t.rect.h / 70000)) * InteractFx.particleFactor);
        if (n > 0) InteractFx.add("burst", t.rect, { palette: palette, count: n }, 3000);
        lastResult = "mined " + t.cls + " " + t.address;
        phase = "idle";
        target = null;
        root.finished(lastResult);
    }
    function _instant() {
        const t = target;
        GameEvents.emit("window.kill", { cls: t.cls, title: t.title });
        instantTimer.start();
    }
    Timer {      // lets window.kill reach the bus before Hyprland reports the close (the bridge looks back 6 s, not forward)
        id: instantTimer
        interval: 60
        onTriggered: {
            const t = root.target;
            if (!t) return;
            InteractFx.sound("block.break." + root.material);
            Hyprland.dispatch("closewindow address:" + t.address);
            watchdog.stop();
            root.lastResult = "closed " + t.cls + " " + t.address + " (instant)";
            root.phase = "idle";
            root.target = null;
            root.finished(root.lastResult);
        }
    }

    // ---------------------------------------------------------------- the window closed by itself while we were mining it
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "closewindow" && root.phase === "mine" && root.target && root.bare(ev.data) === root.target.bare)
                root._abort("window closed first");
        }
    }
}
