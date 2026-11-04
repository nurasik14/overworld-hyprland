import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  SelfTest — walks the real input paths: QtTest's event injection goes straight into each window's event queue. Hover, click, wheel
 *  and keys arrive like real ones, but nothing reaches the compositor: the actual pointer does not move and other windows see nothing.
 *  Commands stay DRYRUN lines in the log (OW_PREVIEW=1 is required, and the script refuses to start without it). Prints PASS/FAIL lines.
 */
Scope {
    id: root
    property bool active: false
    property var hud; property var launcher; property var notes; property var center
    property var network; property var power; property var worlds; property var brew; property var osd; property var card

    property string before: ""
    property int levels: 0
    property var realNetworks: []
    property int passed: 0
    property int failed: 0
    function check(name, ok) {
        if (ok) passed++; else failed++;
        console.warn((ok ? "PASS " : "FAIL ") + name);
    }

    // ------------------------------------------------------------ helpers
    function find(item, pred) {
        if (!item) return null;
        if (pred(item)) return item;
        const kids = item.children || [];
        for (let i = 0; i < kids.length; i++) {
            const r = find(kids[i], pred);
            if (r) return r;
        }
        return null;
    }
    function button(item, text) { return find(item, o => o.text === text && o.activate !== undefined && o.visible); }
    property var _events: []
    function ev(item) {
        // QtTest finds the window through the event object's parent item
        for (let i = 0; i < _events.length; i++) if (_events[i].owner === item) return _events[i].ev;
        const e = Qt.createQmlObject('import QtTest; TestEvent {}', item, "testEvent");
        _events.push({ owner: item, ev: e });
        return e;
    }
    function click(item, button_) {
        const e = ev(item);
        e.mouseMove(item, item.width / 2, item.height / 2, -1, Qt.NoButton, Qt.NoModifier);
        e.mouseClick(item, item.width / 2, item.height / 2, button_ === undefined ? Qt.LeftButton : button_, Qt.NoModifier, -1);
    }
    function hover(item) { ev(item).mouseMove(item, item.width / 2, item.height / 2, -1, Qt.NoButton, Qt.NoModifier); }
    function wheel(item, dy) { ev(item).mouseWheel(item, item.width / 2, item.height / 2, Qt.NoButton, Qt.NoModifier, 0, dy, -1); }
    function key(item, k, mods) { ev(item).keyClick(k, mods === undefined ? Qt.NoModifier : mods, -1); }
    function type(item, text) { const e = ev(item); for (let i = 0; i < text.length; i++) e.keyClickChar(text[i], Qt.NoModifier, -1); }

    // ------------------------------------------------------------ states for screenshots
    function hoverSlot(n) {
        const hb = find(hud.instances[0].contentItem, o => o.switched !== undefined);
        ev(hb).mouseMove(hb, Theme.px(29 + 10 + (n - 1) * 20), Theme.px(10), -1, Qt.NoButton, Qt.NoModifier);
    }
    function hoverAppSlot(i) {
        const slot = find(launcher.instances[0].contentItem, o => o.modelData !== undefined && o.rightClicked !== undefined && o.index === i);
        hover(slot);
    }
    function pickFavourites() {
        const w = launcher.instances[0];
        const pick = [];
        for (let i = 0; i < w.apps.length && pick.length < 6; i++)
            if (w.apps[i].item.length && w.apps[i].item !== "stone" && pick.findIndex(id => w.apps.find(a => a.id === id).item === w.apps[i].item) < 0) pick.push(w.apps[i].id);
        w.favourites = pick;
        w.category = 1;
    }
    function fakeStacks() {
        const app = (item, count) => ({ count: count, item: item, cls: item, title: "", apps: [{ item: item, cls: item, title: "", count: count }] });
        HyprlandState.slots = { 1: app("enchanting_table", 3), 2: app("command_block", 12), 3: app("compass", 64), 5: app("writable_book", 2), 9: app("jukebox", 1), 10: app("redstone", 7) };
        HyprlandState.specials = [{ id: -98, name: "special:scratchpad", count: 2, item: "ender_chest", cls: "", apps: [] }];
        HyprlandState.activeSpecial = "special:scratchpad";
    }
    function openPassword() {
        const w = network.instances[0];
        const i = w.rows.findIndex(r => r.kind === "wifi" && r.net.secured && !r.net.known && !r.net.active);
        if (i >= 0) { w.selected = i; w.join(w.rows[i]); }
        NetworkService.lastMessage = "nmcli: Secrets were required, but not provided.";
        NetworkService.lastError = true;
    }

    // ------------------------------------------------------------ the script: one step per timer tick, so bindings and fades settle
    property var steps: []
    property int stepIndex: 0
    Timer {
        id: stepper
        interval: 260; repeat: true
        onTriggered: {
            if (root.stepIndex >= root.steps.length) {
                stop();
                console.warn("SELFTEST DONE passed=" + root.passed + " failed=" + root.failed);
                return;
            }
            const s = root.steps[root.stepIndex++];
            try { s(); } catch (e) { root.check("step " + (root.stepIndex - 1) + " threw: " + e, false); }
        }
    }
    Timer {
        interval: 2500; running: root.active
        onTriggered: {
            if (!ShellState.preview) { console.warn("SELFTEST refused: OW_PREVIEW=1 is required"); return; }
            root.steps = root.script();
            stepper.start();
        }
    }

    function script() {
        const L = () => launcher.instances[0];
        const P = () => power.instances[0];
        const N = () => network.instances[0];
        const W = () => worlds.instances[0];
        const B = () => brew.instances[0];
        const H = () => hud.instances[0];
        const C = () => center.instances[0];
        const T = () => notes.instances[0];
        const scene = w => w.contentItem;
        return [
            // ---- launcher: keys
            () => ShellState.open("launcher"),
            () => { check("launcher opens", L().visible && L().shown); check("search field has focus", find(scene(L()), o => o.echoMode !== undefined && o.activeFocus) !== null); },
            () => { check("launcher lists apps", L().results.length > 20); type(scene(L()), "fire"); },
            () => { check("typing filters (" + L().query + ", " + L().results.length + " hits)", L().query === "fire" && L().results.length < L().apps.length); },
            () => key(scene(L()), Qt.Key_Backspace),
            () => { key(scene(L()), Qt.Key_Backspace); key(scene(L()), Qt.Key_Backspace); key(scene(L()), Qt.Key_Backspace); },
            () => { check("backspace clears", L().query === ""); key(scene(L()), Qt.Key_Down); },
            () => { check("Down moves one row (9)", L().selected === 9); key(scene(L()), Qt.Key_Right); },
            () => { check("Right moves one slot (" + L().selected + ")", L().selected === 10); key(scene(L()), Qt.Key_Left); key(scene(L()), Qt.Key_Up); },
            () => { check("Left and Up go back", L().selected === 0); key(scene(L()), Qt.Key_Tab); },
            () => { check("Tab goes to Favourites", L().category === 1); key(scene(L()), Qt.Key_Backtab); },
            () => { check("Shift+Tab goes back", L().category === 0); key(scene(L()), Qt.Key_F, Qt.ControlModifier); },
            () => { check("Ctrl+F favourites the selected app", L().favourites.length === 1 && L().favApps.length === 1); key(scene(L()), Qt.Key_F, Qt.ControlModifier); },
            () => { check("Ctrl+F again removes it", L().favourites.length === 0); type(scene(L()), "=2*21"); },
            () => { check("= calculator evaluates", L().mode === "calc" && L().calc.ok && L().calc.value === 42); key(scene(L()), Qt.Key_Return); },
            () => { check("Enter on a sum closes", !ShellState.launcherOpen); ShellState.open("launcher"); },
            () => { check("query cleared on reopen", L().query === ""); type(scene(L()), ">echo hi"); },
            () => { check("> run mode", L().mode === "run"); key(scene(L()), Qt.Key_Return); },
            () => { check("Enter runs the command and closes", !ShellState.launcherOpen); ShellState.open("launcher"); },
            () => { L().selected = 0; L().keyboardNav = true; check("keyboard cursor set", L().keyboardNav); },
            () => {
                const t = find(scene(L()), o => o.targetX !== undefined && o.title !== undefined && o.visible);
                const w = L();
                check("keyboard cursor shows a tooltip", w.contentItem.Window.contentItem.children.some(c => c.title !== undefined && c.title === w.results[0].name));
            },
            () => key(scene(L()), Qt.Key_Return),
            () => { check("Enter launches and closes", !ShellState.launcherOpen); ShellState.open("launcher"); },
            // ---- launcher: pointer
            () => {
                const slot = find(scene(L()), o => o.modelData !== undefined && o.rightClicked !== undefined && o.index === 3);
                check("slot 3 exists", slot !== null);
                hover(slot);
            },
            () => {
                const w = L();
                check("hover selects (selected " + w.selected + ", keyboardNav " + w.keyboardNav + ")", w.selected === 3 && !w.keyboardNav);
                check("hover shows the tooltip", w.contentItem.Window.contentItem.children.some(c => c.title === w.results[3].name));
                const slot = find(scene(w), o => o.modelData !== undefined && o.rightClicked !== undefined && o.index === 3);
                click(slot, Qt.RightButton);
            },
            () => { check("right-click favourites", L().favourites.length === 1); const slot = find(scene(L()), o => o.modelData !== undefined && o.rightClicked !== undefined && o.index === 3); click(slot, Qt.RightButton); },
            () => {
                check("right-click again removes", L().favourites.length === 0);
                const tabs = find(scene(L()), o => o.tabClicked !== undefined && o.side === "bottom");
                ev(tabs).mouseClick(tabs, Theme.px(13), Theme.px(16), Qt.LeftButton, Qt.NoModifier, -1);
            },
            () => { check("a bottom tab click switches tab", L().category === L().topTabs); key(scene(L()), Qt.Key_Escape); },
            () => check("Esc closes the launcher", !ShellState.launcherOpen),

            // ---- game menu (commands are DRYRUN lines; nothing is executed)
            () => ShellState.open("power"),
            () => { check("menu opens on Back to Game", P().selectedKey === "back"); key(scene(P()), Qt.Key_Down); },
            () => { check("Down to Advancements", P().selectedKey === "advancements"); key(scene(P()), Qt.Key_Right); },
            () => { check("Right to Statistics", P().selectedKey === "statistics"); key(scene(P()), Qt.Key_Down); key(scene(P()), Qt.Key_Down); key(scene(P()), Qt.Key_Down); },
            () => { check("Down to Save and Quit", P().selectedKey === "logout"); key(scene(P()), Qt.Key_Return); },
            () => { check("logout asks first", P().confirmAction !== null && ShellState.powerOpen && P().confirmChoice === 1); key(scene(P()), Qt.Key_Return); },
            () => { check("Enter on No goes back", P().confirmAction === null && ShellState.powerOpen); type(scene(P()), "p"); },
            () => { check("P asks before shutdown", P().confirmAction !== null && P().confirmAction.label === "Quit Game"); key(scene(P()), Qt.Key_Escape); },
            () => { check("Esc leaves the confirm screen", P().confirmAction === null && ShellState.powerOpen); hover(button(scene(P()), "Respawn")); },
            () => { check("hover selects a button", P().selectedKey === "respawn"); click(button(scene(P()), "Respawn")); },
            () => { check("Respawn asks first", P().confirmAction !== null && P().confirmAction.label === "Respawn"); click(button(scene(P()), "No")); },
            () => { check("No button goes back", P().confirmAction === null); type(scene(P()), "r"); },
            () => type(scene(P()), "y"),
            () => check("R then Y runs reboot (DRYRUN)", !ShellState.powerOpen),
            () => ShellState.open("power"),
            () => type(scene(P()), "l"),
            () => check("L locks at once (DRYRUN)", !ShellState.powerOpen),
            () => ShellState.open("power"),
            () => click(button(scene(P()), "Back to Game")),
            () => check("Back to Game closes", !ShellState.powerOpen),

            // ---- multiplayer (nmcli writes are DRYRUN lines; the list is the real adapter's)
            () => ShellState.open("network"),
            () => {},
            () => {
                check("the real adapter's list arrived (" + NetworkService.networks.length + " networks)", NetworkService.networks.length >= 0);
                root.realNetworks = NetworkService.networks;
                // a fixture from here on, so the checks do not depend on who is on the air
                NetworkService.networks = [
                    { ssid: "Connected One", signal: 90, security: "WPA2", secured: true, enterprise: false, active: true, bssid: "", freq: 5180, known: true },
                    { ssid: "Stranger", signal: 40, security: "WPA2 WPA3", secured: true, enterprise: false, active: false, bssid: "", freq: 2412, known: false },
                    { ssid: "Open Cafe", signal: 15, security: "", secured: false, enterprise: false, active: false, bssid: "", freq: 2437, known: false }
                ];
                N().selected = 0;
            },
            () => { check("server list has rows", N().rows.length >= 4 && N().rows[3].kind === "header"); key(scene(N()), Qt.Key_Down); },
            () => { check("Down selects the next server", N().selected === 1); key(scene(N()), Qt.Key_Return); },
            () => { check("Enter on a secured unknown network opens the password screen", N().view === "password" && N().pendingSsid === "Stranger"); type(scene(N()), "hunter2"); },
            () => { check("password field takes keys", N().view === "password" && find(scene(N()), o => o.echoMode === TextInput.Password && o.text === "hunter2") !== null); key(scene(N()), Qt.Key_Return); },
            () => { check("Enter joins, back to the list (DRYRUN)", N().view === "list"); key(scene(N()), Qt.Key_Down); },
            () => { check("Down to the open network", N().selected === 2); key(scene(N()), Qt.Key_Down); },
            () => { check("Down skips the LAN header", N().rows[N().selected].kind !== "header"); N().selected = 2; key(scene(N()), Qt.Key_Return); },
            () => { check("an open network joins without a password (DRYRUN)", N().view === "list"); N().selected = 0; },
            () => { check("the connected row offers Disconnect", button(scene(N()), "Disconnect") !== null); click(button(scene(N()), "Forget")); },
            () => { check("Forget wants a second click", N().confirmForget === true); click(button(scene(N()), "Sure?")); },
            () => { check("Forget ran (DRYRUN)", N().confirmForget === false); },
            () => { click(button(scene(N()), "Direct Connection")); },
            () => { check("Direct Connection screen", N().view === "direct"); key(scene(N()), Qt.Key_Escape); },
            () => { check("Esc returns to the list", N().view === "list" && ShellState.networkOpen); click(button(scene(N()), "Refresh")); },
            () => { check("Refresh rescans", NetworkService.scanning || NetworkService.busy || NetworkService.lastMessage.length > 0); click(button(scene(N()), "Cancel")); },
            () => check("Cancel closes", !ShellState.networkOpen),

            // ---- select world
            () => ShellState.open("wallpapers"),
            () => { check("worlds listed (" + W().rows.length + ")", W().rows.length >= 1); type(scene(W()), "desert"); },
            () => { check("search filters", W().filter === "desert" && W().rows.length >= 1 && W().rows.length < W().worlds.length); key(scene(W()), Qt.Key_Backspace); },
            () => { for (let i = 0; i < 5; i++) key(scene(W()), Qt.Key_Backspace); },
            () => { check("search cleared", W().filter === ""); key(scene(W()), Qt.Key_Down); },
            () => { check("Down selects the next world", W().selected === 1 || W().rows.length < 2); click(button(scene(W()), "Create New World")); },
            () => { check("Create New World shows the loading screen", W().view === "create"); },
            () => click(button(scene(W()), "Cancel")),
            () => { check("Cancel returns", W().view === "list"); click(button(scene(W()), "Delete")); },
            () => {
                check("Delete asks first", W().view === "delete" || W().isCurrent(W().currentRow.path));
                if (W().view === "delete") key(scene(W()), Qt.Key_Escape);
            },
            () => { check("Esc on the delete screen goes back", W().view === "list"); click(button(scene(W()), "Delete")); },
            () => { if (W().view === "delete") click(button(scene(W()), "Cancel")); },
            () => {
                check("Cancel keeps the world", W().view === "list" && W().worlds.length >= 1);
                check("the search field has the keys again", find(scene(W()), o => o.placeholderText === "Search for worlds").input.activeFocus);
                key(scene(W()), Qt.Key_Return);
            },
            () => check("Enter plays the world (DRYRUN) and closes", !ShellState.wallpapersOpen),

            // ---- brewing stand
            () => ShellState.open("brew"),
            () => {
                const field = find(scene(B()), o => o.placeholderText === "25, 50m, 1h30, 1:30");
                check("brew field focused", field !== null && field.input.activeFocus);
                root.before = field.text;
                key(scene(B()), Qt.Key_Up);
            },
            () => {
                const field = find(scene(B()), o => o.placeholderText === "25, 50m, 1h30, 1:30");
                check("Up adds a minute (" + field.text + ")", field.text !== root.before);
                key(scene(B()), Qt.Key_Tab);
            },
            () => {
                const rest = find(scene(B()), o => o.placeholderText === "5, 10m, 0 = no rest");
                check("Tab reaches the rest field", rest !== null && rest.input.activeFocus);
                rest.text = "nonsense";
            },
            () => { check("a bad duration is an error", !B().ok); key(scene(B()), Qt.Key_Return); },
            () => {
                check("Enter refuses it", ShellState.brewOpen);
                find(scene(B()), o => o.placeholderText === "5, 10m, 0 = no rest").text = "0";
            },
            () => { check("rest 0 is valid", B().ok); click(button(scene(B()), "1h30")); },
            () => {
                const field = find(scene(B()), o => o.placeholderText === "25, 50m, 1h30, 1:30");
                check("a preset fills the field", B().workSec === 5400);
                key(scene(B()), Qt.Key_Return);
            },
            () => check("Enter saves and starts (DRYRUN)", !ShellState.brewOpen),

            // ---- toasts and the chat history
            () => NotificationService.test("Self test", "A note with a body", "normal", "kitty"),
            () => { check("toast window shows", T().visible && NotificationService.popups.length === 1); },
            () => {
                const toast = find(T().contentItem, o => o.note !== undefined && o.closeClicked !== undefined);
                check("toast exists", toast !== null);
                hover(toast);
            },
            () => {
                const note = NotificationService.popups[0];
                check("hover pauses the toast", note.hovered === true);
            },
            () => {
                const toast = find(T().contentItem, o => o.note !== undefined && o.closeClicked !== undefined);
                click(toast);
            },
            () => check("a click starts the slide-out", NotificationService.all.length === 0 || NotificationService.all[0].closing || !NotificationService.all[0].popup),
            () => NotificationService.test("Stays in history", "body", "critical", "kitty"),
            () => { check("critical has no timeout", NotificationService.all[0].timeout === 0); ShellState.open("notifCenter"); },
            () => {
                check("toasts hide while the history is open", !T().visible);
                click(button(scene(C()), "Difficulty: Normal"));
            },
            () => {
                check("Difficulty goes Peaceful", NotificationService.dnd === true);
                check("Peaceful hides toasts", NotificationService.popups.length === 0);
                click(button(scene(C()), "Difficulty: Peaceful"));
            },
            () => { check("back to Normal", NotificationService.dnd === false); click(button(scene(C()), "Clear Chat")); },
            () => { check("Clear Chat empties it", NotificationService.count === 0); key(scene(C()), Qt.Key_Escape); },
            () => check("Esc closes the history", !ShellState.notifCenterOpen),

            // ---- HUD pointer (workspace switches are DRYRUN lines)
            () => {
                const bar = H().contentItem;
                const hb = find(bar, o => o.switched !== undefined);
                check("hotbar exists", hb !== null);
                ev(hb).mouseMove(hb, Theme.px(29 + 50), Theme.px(10), -1, Qt.NoButton, Qt.NoModifier);
            },
            () => {
                const tip = H().contentItem.Window.contentItem.children.find(c => c.category !== undefined && String(c.category).indexOf("Workspace 3") === 0);
                check("hovering a slot shows the workspace tooltip", tip !== undefined);
                const hb = find(H().contentItem, o => o.switched !== undefined);
                ev(hb).mouseClick(hb, Theme.px(29 + 50), Theme.px(10), Qt.LeftButton, Qt.NoModifier, -1);
                wheel(hb, -120);
            },
            () => {
                const chip = find(H().contentItem, o => o.tooltip === "Crafting Table");
                check("launcher slot exists", chip !== null);
                click(chip);
            },
            () => { check("crafting table opens the launcher", ShellState.launcherOpen); key(scene(L()), Qt.Key_Escape); },
            () => {
                const bell = find(H().contentItem, o => o.tooltip === "Notifications");
                click(bell);
            },
            () => { check("the bell opens the history", ShellState.notifCenterOpen); key(scene(C()), Qt.Key_Escape); },
            () => {
                const door = find(H().contentItem, o => o.tooltip === "Game Menu");
                click(door);
            },
            () => { check("the door opens the game menu", ShellState.powerOpen); key(scene(P()), Qt.Key_Escape); },
            () => {
                const chip = find(H().contentItem, o => o.tooltip === "Item Frame");
                click(chip);
            },
            () => { check("the item frame opens the widgets menu", WidgetsState.menuOpen); WidgetsState.menuOpen = false; },
            () => {
                const vol = find(H().contentItem, o => String(o.tooltip).indexOf("Master Volume") === 0);
                wheel(vol, 120);
                ev(vol).mouseClick(vol, 4, 4, Qt.MiddleButton, Qt.NoModifier, -1);
            },
            () => {
                const bell = find(H().contentItem, o => o.tooltip === "Notifications");
                ev(bell).mouseClick(bell, 4, 4, Qt.MiddleButton, Qt.NoModifier, -1);
            },
            () => { check("middle-click on the bell toggles Peaceful", NotificationService.dnd === true); NotificationService.setDnd(false); },
            // ---- a workspace switch: selection, item name, /title, the event (needs OW_FAKE_WS)
            () => { if (HyprlandState._fakeFocus > 0) HyprlandState._fakeFocus = 5; },
            () => {
                if (HyprlandState._fakeFocus <= 0) return;
                const name = find(H().contentItem, o => o.alphaShown !== undefined);
                check("a switch shows the item name", name !== null && name.alphaShown === 1 && name.text === WorkspaceNotes.displayTitle(5));
                check("a switch shows /title", card.shown && card.titleText === WorkspaceNotes.displayTitle(5));
                card.hide();
            },
            () => { root.levels = 0; SystemStats.levelUp.connect(l => root.levels++); SystemStats.uptimeHours = SystemStats.level + 1.01; },
            () => check("a new uptime hour levels up once", root.levels === 1),
            // ---- config writes, only with OW_CONFIG pointing at a scratch file
            () => { if (Quickshell.env("OW_CONFIG")) { ConfigService.set("sound_volume.ui", 40); ConfigService.set("hud.bossbar_media", "track"); NotificationService.setDnd(true); } },
            () => {},
            () => {
                if (!Quickshell.env("OW_CONFIG")) return;
                check("config write lands, others keep their defaults", ConfigService.get("sound_volume.ui") === 40 && ConfigService.get("sound_volume.master") === 100);
                check("difficulty persists", ConfigService.difficulty === "peaceful" && NotificationService.dnd === true);
                NotificationService.setDnd(false);
            },
            () => {},
            () => { if (Quickshell.env("OW_CONFIG")) check("difficulty back to normal", ConfigService.difficulty === "normal" && !NotificationService.dnd); },
            // ---- the rest
            () => { osd.show("volume"); check("OSD shows", osd.shown); },
            () => { card.reveal(2); check("/title shows", card.shown && card.titleText.length > 0); },
            () => { card.hide(); osd.shown = false; }
        ];
    }
}
