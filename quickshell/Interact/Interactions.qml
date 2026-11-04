import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  Interactions — what the desktop does when you touch windows (fx-interactions). Instantiated by shell.qml.
 *    Miner     block-break window close            IPC interact kill / killAddress / killClass
 *    Placer    block-place window open             IPC interact place / placeAddress
 *    Death     low-battery hurt warning + "You died!"   IPC interact death / respawn / hurt
 *    XpFlourish "+1" orbs on xp.levelup, item-pickup pop on screenshot   IPC interact levelup / pickup
 *  Effects are drawn by FxLayer (one overlay per output, namespace overworld-break). Documentation: docs/INTERACTIONS.md.
 *  IPC target `interact` (exact interface agreed with hyprland-engineer; never named `show`):
 *    kill()                 mine the focused window; aborts if focus moves
 *    killAddress(a: string) mine the window with Hyprland address a ("0x…")
 *    killClass(c: string)   mine the focused window only if its class is c (used by /kill <class> and the tests)
 *    place() / placeAddress(a)   run the place effect (dust + sound) for the focused window / a window
 *    death() / respawn() / hurt()   show / dismiss the death screen, play the low-battery warning
 *    levelup(n: int) / pickup()     the XP flourish / the pickup pop
 *    status(): string       "idle" or what is running, plus the last result
 */
Scope {
    id: root

    Variants {
        model: Quickshell.screens
        FxLayer {}
    }

    Miner { id: minerFx }
    Placer { id: placerFx }
    Death { id: deathFx }

    // ---------------------------------------------------------------- XP level-up, screenshot pickup
    function _hudRect() {
        const m = Hyprland.focusedMonitor;
        const list = Quickshell.screens;
        let s = list.length ? list[0] : null;
        for (let i = 0; i < list.length; i++) if (m && list[i].name === m.name) s = list[i];
        return s ? { screen: s, x: s.x + Math.round(s.width / 2 / Theme.gui) * Theme.gui - Theme.px(91), y: s.y + s.height - Theme.px(29) } : null;
    }
    function levelUp(level) {
        const hud = _hudRect();
        if (!hud || ConfigService.reducedMotion || ConfigService.isSpectator || ShellState.hudHidden) return;
        const n = Math.round(14 * InteractFx.particleFactor);
        InteractFx.add("orbs", { x: hud.x, y: hud.y, w: Theme.px(182), h: Theme.px(5) }, { level: level, count: n }, 4000);
    }
    function pickup(item) {
        const hud = _hudRect();
        if (!hud || ConfigService.reducedMotion || ConfigService.isSpectator || ShellState.hudHidden) return;
        InteractFx.add("pickup", { x: hud.screen.x, y: hud.screen.y, w: hud.screen.width, h: hud.screen.height }, { item: item || "filled_map" }, 3000);
    }
    Connections {
        target: GameEvents
        function onEvent(name, data) {
            if (name === "xp.levelup") root.levelUp(data && data.level ? data.level : 0);
            else if (name === "screenshot") root.pickup("filled_map");
        }
    }

    // ---------------------------------------------------------------- IPC
    IpcHandler {
        target: "interact"
        function kill(): void { minerFx.kill("", ""); }
        function killAddress(address: string): void { minerFx.kill(address, ""); }
        function killClass(cls: string): void { minerFx.kill("", cls); }
        function place(): void { const a = Hyprland.activeToplevel; if (a) placerFx.place(a.address); }
        function placeAddress(address: string): void { placerFx.place(address); }
        function death(): void { deathFx.show(); }
        function respawn(): void { deathFx.respawn(); }
        function hurt(): void {
            InteractFx.sound("player.hurt");
            GameEvents.emit("battery", { percent: SystemStats.percent, charging: false, flash: true });
        }
        function levelup(level: int): void { root.levelUp(level); }
        function pickup(): void { root.pickup("filled_map"); }
        function status(): string {
            return (minerFx.busy ? "mining(" + minerFx.phase + ") " : "idle ") + "fx=" + InteractFx.count
                 + " death=" + deathFx.open + " kill:[" + minerFx.lastResult + "] place:[" + placerFx.lastResult + "]";
        }
    }
}
