// Test driver: runs the wrapper inside the real sddm-greeter-qt6 (offscreen), with the real `config` but a fake session list and a fake
// `sddm` that records logins instead of performing them, sends real key and mouse events, and saves PNGs. See run-harness.sh.
import QtQuick
import QtQuick.Window
import QtTest

Item {
    id: harness
    width: 1920
    height: 1080

    readonly property string scenario: String(config["HyprTest/Scenario"] || "walk")
    readonly property string outDir: String(config["HyprTest/OutDir"] || "/tmp")
    readonly property int fakeLastIndex: parseInt(config["HyprTest/LastIndex"] || "0")
    readonly property string sessionSet: String(config["HyprTest/FakeSessions"] || "full")

    function say(text) { console.warn("TEST " + text); }

    // ---- shadows the greeter's objects for everything below this item ---------------------------------------------------------
    property QtObject sddm: QtObject {
        property string currentUser: ""
        property bool canPowerOff: true
        property bool canReboot: true
        property bool canSuspend: true
        property bool canHibernate: false
        property bool canHybridSleep: false
        property string hostName: "test"
        signal loginFailed()
        signal loginSucceeded()
        signal informationMessage(string message)
        function login(user, password, session) { harness.say("LOGIN user=" + user + " password=" + password + " session=" + session + " file=" + harness.fileAt(session)); }
        function powerOff() {} function reboot() {} function suspend() {} function hibernate() {} function hybridSleep() {}
    }
    function fileAt(i) { return sessionModel.get(i) ? sessionModel.get(i).file : "?"; }

    property ListModel sessionModel: ListModel {
        property int lastIndex: harness.fakeLastIndex
        function data(modelIndex, role) {
            const row = get(modelIndex.row);
            return role === 258 ? row.file : role === 260 ? row.name : "";
        }
    }

    Loader {
        id: wrapper
        anchors.fill: parent
        focus: true
        active: false
        source: "Main.qml"
    }
    TestEvent { id: ev }

    function key(k, mods) { ev.keyClick(k, mods || Qt.NoModifier, 10); }
    function typeText(t) { for (const c of t) ev.keyClickChar(c, Qt.NoModifier, 10); }
    function click(item, x, y) {
        ev.mouseClick(item, x === undefined ? item.width / 2 : x, y === undefined ? item.height / 2 : y, Qt.LeftButton, Qt.NoModifier, 10);
    }
    function shot(name) {
        wrapper.grabToImage(r => { const p = outDir + "/" + name + ".png"; r.saveToFile(p); say("SHOT " + p); });
    }
    function status(tag) {
        const w = wrapper.item;
        say("STATE " + tag + " look=" + (w.currentLook ? w.currentLook.id : "none") + " session=" + w.sessionIndex + " file=" + fileAt(w.sessionIndex)
            + " menu=" + find(w, "themeMenu").open + " focus=" + harness.Window.window.activeFocusItem + " active=" + harness.Window.window.active);
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const c of item.children) { const r = find(c, name); if (r) return r; }
        return null;
    }

    // ---- scenarios: each entry is [ms to wait first, what to do] -----------------------------------------------------------------
    readonly property var scenarios: ({
        walk: [
            [1500, () => {}],
            [1000, () => { status("start"); shot("overworld"); }],
            [100, () => key(Qt.Key_F10)],
            [200, () => status("esc-before")],
            [100, () => key(Qt.Key_Escape)],
            [200, () => status("esc-closed")],              // focus must be back on the password field
            [100, () => key(Qt.Key_T, Qt.AltModifier)],
            [200, () => click(find(wrapper.item, "themeMenu"), 400, 500)],
            [200, () => status("click-outside-closed")],
            [300, () => key(Qt.Key_T, Qt.AltModifier)],
            [300, () => { status("menu-open"); shot("menu"); }],
            [100, () => key(Qt.Key_Down)],
            [100, () => key(Qt.Key_Return)],
            [150, () => shot("crossfade")],
            [1500, () => { status("after-keyboard-pick"); shot("apothecary"); }],
            [100, () => typeText("secret")],
            [100, () => key(Qt.Key_Return)],
            [300, () => sddm.loginFailed()],
            [300, () => { status("after-failed-login"); shot("apothecary-failed"); }],
            [100, () => key(Qt.Key_F10)],
            [200, () => key(Qt.Key_1)],
            [3000, () => { status("waguri-lock"); shot("waguri-lock"); }],
            [100, () => key(Qt.Key_F10)],
            [200, () => key(Qt.Key_Escape)],
            [300, () => status("waguri-lock-after-menu")],  // the lock screen keeps the focus, and is still the lock screen
            [100, () => key(Qt.Key_Space)],
            [1500, () => { status("waguri-login"); shot("waguri-login"); }],
            [100, () => typeText("pw")],
            [100, () => key(Qt.Key_Return)],
            [500, () => sddm.loginFailed()],
            [500, () => click(find(wrapper.item, "themeButton"))],
            [300, () => { status("menu-mouse"); shot("menu-waguri"); }],
            [100, () => click(find(wrapper.item, "themeMenu"), 1920 - 150, 16 + 32 + 6 + 6 + 50 + 24)],
            [2000, () => { status("after-mouse-pick"); shot("overworld-2"); }],
            [100, () => key(Qt.Key_Tab)],                   // password -> Singleplayer
            [100, () => key(Qt.Key_Tab)],                   // Singleplayer -> Session
            [100, () => key(Qt.Key_Return)],                // next session, by hand
            [300, () => { status("manual-session"); shot("overworld-manual-session"); }],
            [100, () => key(Qt.Key_Tab)],                   // Session -> Sleep
            [100, () => key(Qt.Key_Tab)],                   // -> Respawn
            [100, () => key(Qt.Key_Tab)],                   // -> Quit
            [100, () => key(Qt.Key_Tab)],                   // -> password
            [100, () => typeText("x")],
            [100, () => key(Qt.Key_Return)],
            [300, () => sddm.loginSucceeded()],
            [500, () => status("logged-in")]
        ],
        snapshot: [
            [1500, () => {}],
            [2000, () => { status("snapshot"); shot(String(config["HyprTest/Shot"] || "snapshot")); }],
            [300, () => key(Qt.Key_T, Qt.AltModifier)],
            [300, () => shot(String(config["HyprTest/Shot"] || "snapshot") + "-menu")]
        ]
    })

    property int stepIndex: 0
    // SDDM activates its window itself; on the offscreen platform something has to ask, and an inactive window gets no key events.
    Timer {
        id: stepper
        repeat: false
        onTriggered: { harness.Window.window.requestActivate(); action.start(); }
    }
    Timer {
        id: action
        interval: 60
        onTriggered: {
            const steps = harness.scenarios[harness.scenario];
            steps[harness.stepIndex][1]();
            harness.stepIndex++;
            if (harness.stepIndex >= steps.length) { harness.say("DONE"); quitter.start(); return; }
            stepper.interval = steps[harness.stepIndex][0];
            stepper.start();
        }
    }
    Timer { id: quitter; interval: 500; onTriggered: Qt.quit() }

    Component.onCompleted: {
        const all = [
            { name: "Hyprland", file: "hyprland.desktop" },
            { name: "Hyprland (uwsm-managed)", file: "hyprland-uwsm.desktop" },
            { name: "Hyprland · Apothecary", file: "hyprland-apothecary.desktop" },
            { name: "Hyprland · Overworld", file: "hyprland-overworld.desktop" },
            { name: "Hyprland · Stock", file: "hyprland-stock.desktop" },
            { name: "Plasma", file: "plasma.desktop" }
        ];
        for (const s of all) if (sessionSet !== "stock" || !/overworld|apothecary|stock/.test(s.file)) sessionModel.append(s);
        wrapper.active = true;
        stepper.interval = harness.scenarios[harness.scenario][0][0];
        stepper.start();
    }
}
