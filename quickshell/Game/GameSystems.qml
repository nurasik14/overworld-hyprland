import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  GameSystems — entry of the Game module (shell.qml instantiates it): chat console, game modes, advancements, statistics, options.
 *  Surfaces: overworld-chat · overworld-gamemode · overworld-advancements · overworld-stats · overworld-options · overworld-advtoast.
 *  IPC: chat open|command <text>|say <text>|close|toggle · gamemode set <m>|get|switcher|cycle · advancements open|close|toggle|grant|revoke|list
 *       stats open|close|toggle|summary · options open|close|toggle|page <name>|get <key>|set <key> <json>
 *  Docs: docs/GAMEPLAY.md.
 */
Scope {
    id: root

    // singletons are created on first use: touch the ones that must run from the start
    readonly property var _engine: [Advancements.total, Stats.revision, GameMode.mode, ChatService.lines.length, Options.revision]

    EventBridge {}
    ChatOverlay {}
    GameModeSwitcher {}
    AdvancementsScreen {}
    StatsScreen {}
    OptionsScreen {}
    AdvancementToasts {}

    IpcHandler {
        target: "chat"
        function open(): void { GameUi.openChat(""); }
        function command(text: string): void { GameUi.openChat(text.length ? text : "/"); }
        function say(text: string): void { ChatService.post(text, ""); }
        function close(): void { GameUi.closeChat(); }
        function toggle(): void { GameUi.chatOpen ? GameUi.closeChat() : GameUi.openChat(""); }
        function run(text: string): void { ChatService.submit(text); }   // execute a line without opening the console
        function log(n: int): string { return ChatService.lines.slice(-Math.max(1, n)).map(l => l.text.replace(/§./g, "")).join("\n"); }   // last n lines as plain text (tests)
    }
    IpcHandler {
        target: "gamemode"
        function set(mode: string): void { GameMode.set(mode); }
        function get(): string { return GameMode.mode; }
        function switcher(): void { GameUi.toggle("switcher"); }
        function cycle(): void { GameMode.cycle(1); }
    }
    IpcHandler {
        target: "advancements"
        function open(): void { GameUi.open("advancements"); }
        function close(): void { GameUi.close("advancements"); }
        function toggle(): void { GameUi.toggle("advancements"); }
        function grant(spec: string): string { const r = Advancements.grant(spec); return "granted " + r.changed + " of " + r.matched; }
        function revoke(spec: string): string { const r = Advancements.revoke(spec); return "revoked " + r.changed + " of " + r.matched; }
        function list(): string { return Advancements.unlockedCount + "/" + Advancements.total; }
        function tab(id: string): void { GameUi.open("advancements"); AdvancementsState.requestTab(id); }
        function inspect(id: string): void { GameUi.open("advancements"); Qt.callLater(() => AdvancementsState.requestInspect(id)); }   // opens the hover box of one advancement
    }
    IpcHandler {
        target: "stats"
        function open(): void { GameUi.open("stats"); }
        function close(): void { GameUi.close("stats"); }
        function toggle(): void { GameUi.toggle("stats"); }
        function summary(): string {
            return "played " + GameCore.durationText(Stats.playSeconds) + " · windows " + Stats.total("windowsOpened") + "/" + Stats.total("windowsClosed")
                 + " · mined " + Stats.total("windowsMined") + " · workspaces " + Stats.total("workspaceSwitches") + " · notifications " + Stats.total("notifications");
        }
        function tab(name: string): void { GameUi.open("stats"); StatsState.requestTab(name); }
    }
    IpcHandler {
        target: "options"
        function open(): void { GameUi.optionsPage = "main"; GameUi.open("options"); }
        function close(): void { GameUi.close("options"); }
        function toggle(): void { GameUi.optionsPage = "main"; GameUi.toggle("options"); }
        function page(name: string): void { GameUi.optionsPage = name; GameUi.open("options"); }
        function get(key: string): string { return JSON.stringify(Options.get(key, null)); }
        function set(key: string, json: string): void { try { Options.set(key, JSON.parse(json)); } catch (e) { console.warn("options set: bad JSON", json); } }
    }
}
