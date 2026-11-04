import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Game
import "Game/ChatCommands.js" as Cmd

/*  SelfTest — logic checks for the Game module, PASS/FAIL lines in the log (grep SELFTEST). Needs OW_STATE_DIR (a temp dir):
 *  it grants, revokes and rewrites state files. Run:  OW_SELFTEST=1 OW_STATE_DIR=/tmp/ow-feat-test OW_GAME_DRYRUN=1 OW_BRIDGE=0 qs -p …/Game/preview
 */
Scope {
    id: root
    property int pass: 0
    property int fail: 0
    function check(name, cond, extra) {
        if (cond) { pass++; console.warn("SELFTEST PASS", name); }
        else { fail++; console.warn("SELFTEST FAIL", name, extra === undefined ? "" : JSON.stringify(extra)); }
    }
    function lastLines(n) { return ChatService.lines.slice(-n).map(l => l.text.replace(/§./g, "")); }
    function hasLine(sub) { return ChatService.lines.some(l => l.text.indexOf(sub) >= 0); }

    function syncTests() {
        // ---- durations
        check("duration 25m", Cmd.parseDuration("25m") === 1500);
        check("duration 1h30m", Cmd.parseDuration("1h30m") === 5400);
        check("duration 90s", Cmd.parseDuration("90s") === 90);
        check("duration bare minutes", Cmd.parseDuration("45") === 2700);
        check("duration 1h30", Cmd.parseDuration("1h30") === 5400);
        check("duration 1.5h", Cmd.parseDuration("1.5h") === 5400);
        check("duration junk", Cmd.parseDuration("xx") === -1 && Cmd.parseDuration("") === -1 && Cmd.parseDuration("5x") === -1);

        // ---- advancements engine (state is reset first)
        Advancements.revoke("all");
        check("60 advancements loaded", Advancements.total === 60, Advancements.total);
        check("5 tabs", Advancements.tabs.length === 5, Advancements.tabs.length);
        check("tab layout has positions", Advancements.byId["overworld/terminal"].x > 0 && Advancements.tabs[0].width > 0);
        Advancements.feed("window.open", { cls: "Kitty", title: "x" });
        check("window.open kitty → root + terminal (case-insensitive)", Advancements.isUnlocked("overworld/root") && Advancements.isUnlocked("overworld/terminal"));
        check("browser not yet", !Advancements.isUnlocked("overworld/browser"));
        Advancements.feed("window.open", { cls: "zen" });
        check("window.open zen → browser", Advancements.isUnlocked("overworld/browser"));
        for (let i = 1; i <= 9; i++) Advancements.feed("workspace", { id: i });
        Advancements.feed("workspace", { id: 3 });
        check("9 distinct workspaces → no travel yet", !Advancements.isUnlocked("adventure/travel"));
        check("travel progress 9/10", Advancements.progress("adventure/travel").text === "9/10", Advancements.progress("adventure/travel"));
        Advancements.feed("workspace", { id: 10 });
        check("10 distinct workspaces → Adventuring Time", Advancements.isUnlocked("adventure/travel"));
        check("workspace ×50 progress counts every switch", Advancements.progress("adventure/hotbar5").have === 11, Advancements.progress("adventure/hotbar5"));
        for (let i = 0; i < 99; i++) Advancements.feed("window.kill", { cls: "x" });
        check("99 kills: hunter yes, hunted no", Advancements.isUnlocked("adventure/hunter") && !Advancements.isUnlocked("adventure/hunted"));
        Advancements.feed("window.kill", { cls: "x" });
        check("100th kill → Monsters Hunted", Advancements.isUnlocked("adventure/hunted"));
        Advancements.feed("xp.levelup", { level: 2 });
        check("level 2 → no uptime3", !Advancements.isUnlocked("overworld/uptime3"));
        Advancements.feed("xp.levelup", { level: 3 });
        check("level 3 → uptime3", Advancements.isUnlocked("overworld/uptime3"));
        Advancements.feed("$time", { at: "12:00" });
        check("noon → no night owl / early bird", !Advancements.isUnlocked("husbandry/night_owl") && !Advancements.isUnlocked("husbandry/early_bird"));
        Advancements.feed("$time", { at: "03:10" });
        check("03:10 → Night Owl", Advancements.isUnlocked("husbandry/night_owl"));
        Advancements.feed("$time", { at: "06:30" });
        check("06:30 → Early Bird", Advancements.isUnlocked("husbandry/early_bird"));
        Advancements.feed("battery", { percent: 15, charging: true });
        check("charging at 15 % is not Withering Hearts", !Advancements.isUnlocked("nether/low"));
        Advancements.feed("battery", { percent: 15, charging: false });
        check("15 % discharging → Withering Hearts", Advancements.isUnlocked("nether/low") && !Advancements.isUnlocked("nether/critical"));
        Advancements.feed("battery", { percent: 4, charging: false });
        check("4 % → Hardcore", Advancements.isUnlocked("nether/critical"));
        Advancements.feed("battery", { percent: 100, charging: true });
        check("100 % charging → Respawn Point", Advancements.isUnlocked("adventure/plugged"));
        Advancements.feed("chat.command", { cmd: "/locate kitty" });
        check("chat startswith /locate", Advancements.isUnlocked("overworld/locate") && Advancements.isUnlocked("overworld/chat") && !Advancements.isUnlocked("adventure/tp"));
        Advancements.feed("gamemode", { mode: "creative" }); Advancements.feed("gamemode", { mode: "creative" }); Advancements.feed("gamemode", { mode: "adventure" }); Advancements.feed("gamemode", { mode: "survival" });
        check("gamemode distinct 3/4", Advancements.progress("adventure/all_modes").have === 3 && !Advancements.isUnlocked("adventure/all_modes"), Advancements.progress("adventure/all_modes"));
        Advancements.feed("gamemode", { mode: "spectator" });
        check("gamemode distinct 4 → Gamemode Collector", Advancements.isUnlocked("adventure/all_modes"));
        // all-of: How Did We Get Here?
        for (let i = 0; i < 10; i++) Advancements.feed("brew.done", {});
        Advancements.feed("screenshot", { path: "/x.png" });
        Advancements.feed("world.created", { path: "/w" });
        check("everything: 6/7 requirements (no dark mode yet)", !Advancements.isUnlocked("end/everything"), Advancements.progress("end/everything"));
        Advancements.feed("mode", { mode: "dark" });
        check("everything unlocked once all 7 parts hold", Advancements.isUnlocked("end/everything"));
        check("mode dark → Moonrise + Hot Tourist", Advancements.isUnlocked("overworld/mode_night") && Advancements.isUnlocked("nether/hot"));
        // all others → Advancing Time
        Advancements.defs.forEach(d => { if (d.id !== "end/all_adv") Advancements.unlock(d.id, true); });
        check("not before the event", !Advancements.isUnlocked("end/all_adv"));
        Advancements.feed("advancement", { id: "x" });
        check("Advancing Time when every other is unlocked", Advancements.isUnlocked("end/all_adv"));
        check("tabCounts", Advancements.tabCounts("end").done === Advancements.tabCounts("end").total);
        const r = Advancements.revoke("end/free");
        check("revoke one", r.changed === 1 && !Advancements.isUnlocked("end/free"));
        check("grant by suffix 'free'", Advancements.grant("free").changed === 1 && Advancements.isUnlocked("end/free"));
        check("spec by tab", Advancements.revoke("nether").changed === 8 && Advancements.tabCounts("nether").done === 0);
        check("iconUrl resolves hay_block via _side", Advancements.iconUrl("hay_block").toString().indexOf("missing") < 0, Advancements.iconUrl("hay_block"));

        // ---- completion
        const c1 = ChatService.completions("/ti");
        check("complete /ti", c1.items[0] === "time" && c1.items.indexOf("title") >= 0 && c1.start === 1, c1);
        check("complete /tp ", ChatService.completions("/tp ").items.length === 10);
        check("complete /time set ", JSON.stringify(ChatService.completions("/time set ").items) === '["day","night","auto"]', ChatService.completions("/time set "));
        check("complete /time (action)", JSON.stringify(ChatService.completions("/time ").items) === '["set","query"]');
        check("complete /gamemode c", JSON.stringify(ChatService.completions("/gamemode c").items) === '["creative"]');
        check("complete /weather r", JSON.stringify(ChatService.completions("/weather r").items) === '["rain"]');
        check("complete advancement ids", ChatService.completions("/advancement grant overworld/t").items.indexOf("overworld/terminal") >= 0);
        check("complete /advancement subcommands", ChatService.completions("/advancement ").items.length === 4);
        check("no completion for free text", ChatService.completions("/say hel").items.length === 0);
        check("no completion without slash", ChatService.completions("hello").items.length === 0);
        check("tab single → completes + space", ChatService.tab("/gam", false) === "/gamemode ", ChatService.tab("/gam", false));
        ChatService.resetCycle();
        const t1 = ChatService.tab("/t", false), t2 = ChatService.tab(t1, false), t3 = ChatService.tab(t2, false);
        check("tab cycles through candidates", t1 !== t2 && t2 !== t3 && t1.indexOf("/t") === 0, [t1, t2, t3]);
        ChatService.resetCycle();
        const adTab = ChatService.tab("/ad", false);
        check("tab unique prefix completes", adTab === "/advancement ", adTab);
        ChatService.resetCycle();
        const sTab = ChatService.tab("/s", false);
        check("tab common prefix or first candidate for /s", sTab.indexOf("/s") === 0 && sTab !== "/s", sTab);
        check("completes running window classes / apps", ChatService.completions("/give ").items.length > 0 || ChatService.apps().length === 0);

        // ---- stats
        const before = Stats.total("windowsOpened");
        Stats.record("window.open", { cls: "testapp" });
        Stats.record("workspace", { id: 4 }); Stats.record("workspace", { id: 7 });
        check("stats count window.open", Stats.total("windowsOpened") === before + 1 && Stats.apps["testapp"].opened === 1);
        check("stats distance walked", Stats.total("distance") >= 3);
    }

    // ---- chat commands through the interpreter (dry-run), then file checks after a moment
    function chatTests() {
        ChatService.clearLog();
        ChatService.submit("/tp 3");
        check("/tp dry-run", hasLine("hyprctl dispatch workspace 3") && hasLine("Teleported"));
        ChatService.submit("/tp 11");
        check("/tp range error", hasLine("Workspace must be between 1 and 10"));
        ChatService.submit("/nonsense");
        check("unknown command", hasLine("Unknown command"));
        ChatService.submit("/brew 25m essay");
        check("/brew → ipc brew start 1500s", hasLine("ipc call brew start 1500s") && hasLine("Started brewing essay for 25 minutes"), lastLines(3));
        ChatService.submit("/brew 13h");
        check("/brew too long", hasLine("at most 12 hours"));
        ChatService.submit("/brew stop");
        check("/brew stop", hasLine("ipc call brew reset"));
        ChatService.submit("/weather thunder");
        check("/weather → world IPC", hasLine("ipc call world weather thunder"));
        ChatService.submit("/time set day");
        check("/time set day → overworld light + daycycle", hasLine("scripts/overworld light") && hasLine("daycycle day"));
        ChatService.submit("/title 4 Library");
        check("/title → overworld ws 4 Library", hasLine("overworld ws 4 Library"));
        ChatService.submit("/f3 on");
        check("/f3 on", hasLine("ipc call world f3 on"));
        ChatService.submit("hello world");
        check("plain message", hasLine("<Nurasik> hello world"));
        ChatService.submit("/me waves");
        check("/me", hasLine("* Nurasik waves"));
        ChatService.submit("/help brew");
        check("/help brew", hasLine("/brew <duration|stop>"));
        ChatService.submit("/help");
        check("/help page 1", hasLine("Showing help page 1 of 3"));
        ChatService.submit("/advancement grant overworld/launch");
        check("/advancement grant", Advancements.isUnlocked("overworld/launch") && hasLine("Granted"));
        ChatService.submit("/advancement revoke overworld/launch");
        check("/advancement revoke", !Advancements.isUnlocked("overworld/launch") && hasLine("Revoked 1 advancement"));
        ChatService.submit("/advancement grant doesnotexist");
        check("/advancement grant unknown", hasLine("Unknown option"));
        check("history keeps the last submit", ChatService.historyPrev("") === "/advancement grant doesnotexist");
        check("history prev prev", ChatService.historyPrev("") === "/advancement revoke overworld/launch");
        check("history next", ChatService.historyNext("") === "/advancement grant doesnotexist");
        // game modes
        ChatService.submit("/gamemode spectator");
        check("spectator mode set", GameMode.mode === "spectator" && GameMode.spectator, GameMode.mode);
        check("spectator → apply script called", hasLine("apply-gamemode.sh spectator survival"), lastLines(4));
        check("spectator → DND on", NotificationService.dnd === true);
        ChatService.submit("/gamemode adventure");
        check("adventure ← spectator", GameMode.mode === "adventure" && hasLine("apply-gamemode.sh adventure spectator") && NotificationService.dnd === false);
        ChatService.submit("/gamemode survival");
        check("back to survival", GameMode.mode === "survival" && hasLine("apply-gamemode.sh survival adventure"));
        check("invalid gamemode rejected", !GameMode.set("nonsense") && GameMode.mode === "survival");
        // reminder (fires after 2 s)
        ChatService.submit("/msg stretch in 2s");
        check("/msg schedules", ChatService.reminders.length === 1 && hasLine("Reminder set"));
        // config write through the Options store
        Options.set("gui_scale", 3);
        Options.set("sound_volume.master", 55);
        check("Options local copy", Options.get("gui_scale", 0) === 3 && Options.get("sound_volume.master", 0) === 55);
        GameEvents.emit("chat.say", { text: "§bHello from another module", color: "" });
        GameEvents.emit("screenshot", { path: "/home/x/shots/2026-11-05_10.00.00.png" });
        GameEvents.emit("brew.done", {});
        GameEvents.emit("net.connect", { ssid: "CityU_Hall" });
        Stats.persist();
        verify.start();
    }
    Timer {
        id: verify
        interval: 2800
        onTriggered: {
            check("chat.say event line", hasLine("Hello from another module"));
            check("screenshot event line", hasLine("Saved screenshot as 2026-11-05_10.00.00.png"));
            check("brew.done event line", hasLine("finished brewing"));
            check("net.connect event line", hasLine("joined CityU_Hall"));
            check("reminder fired", ChatService.reminders.length === 0 && hasLine("[Reminder] §fstretch") && hasLine("notify-send"), lastLines(5));
            files.running = true;
        }
    }
    Process {
        id: files
        command: ["sh", "-c", 'd="$OW_STATE_DIR"; echo "gamemode=$(cat $d/gamemode)"; echo "adv=$(jq ".unlocked|length" $d/advancements.json)"; echo "stats=$(jq ".totals.windowsOpened" $d/stats.json)"; echo "hist=$(jq "length" $d/chat-history.json)"; echo "cfg=$(jq -c "[.gui_scale,.sound_volume.master]" $d/config.json)"; echo "rem=$(jq length $d/reminders.json)"']
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                text.trim().split("\n").forEach(l => { const i = l.indexOf("="); kv[l.slice(0, i)] = l.slice(i + 1); });
                root.check("gamemode file", kv.gamemode === "survival", kv);
                root.check("advancements.json persisted", parseInt(kv.adv) === Advancements.unlockedCount, kv);
                root.check("stats.json persisted", parseInt(kv.stats) === Stats.total("windowsOpened"), kv);
                root.check("chat-history.json persisted", parseInt(kv.hist) >= 15, kv);
                root.check("config.json written in place", kv.cfg === "[3,55]", kv);
                root.check("reminders.json empty after firing", parseInt(kv.rem) === 0, kv);
                console.warn("SELFTEST DONE pass=" + root.pass + " fail=" + root.fail);
            }
        }
    }
    Component.onCompleted: {
        if (!Quickshell.env("OW_STATE_DIR")) { console.warn("SELFTEST refused: set OW_STATE_DIR to a temp dir"); return; }
        start.start();
    }
    Timer { id: start; interval: 1500; onTriggered: { root.syncTests(); root.chatTests(); } }
}
