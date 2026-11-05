// Hyprland themes — SDDM wrapper theme (Qt 6, Theme-API 2.0): one login screen, three looks, a theme button.
// The button (top right, Alt+T or F10) switches the look AND selects the session that logs into the matching desktop theme.
// Each look is an unmodified login theme under looks/<dir>/, except for the scripted transform in scripts/install-sddm.sh.
// How the looks get their own config and session: LookHost.qml. How it all fits together: docs/LOGIN.md.
//
// Remembered in a small ini file (the greeter runs as the sddm user, whose home is writable):
//   look           the look picked last
//   sessionChoice  the session that pick selected, until a login uses it. After a login SDDM's own "last session" is the truth,
//                  which is how a session chosen by hand (Plasma, …) survives a reboot and keeps the look.
import QtQuick
import QtCore
import "looks.js" as Looks

Item {
    id: root
    width: 1920
    height: 1080

    // Taken here on purpose: below LookHost the name `config` means the look's own shim.
    readonly property var sddmConfig: config

    function cfg(key, fallback) {
        const v = sddmConfig["HyprThemes/" + key];
        return (v === undefined || v === null || v === "") ? fallback : v;
    }

    readonly property var availableLooks: {
        const wanted = String(cfg("Looks", "")).split(",").map(s => s.trim()).filter(s => s.length > 0);
        return Looks.all.filter(l => wanted.length === 0 || wanted.indexOf(l.id) >= 0);
    }
    function lookById(id) {
        for (const l of availableLooks) if (l.id === id) return l;
        return null;
    }

    Settings {
        id: store
        // A file url, or QSettings falls back to the application's identifiers, which the greeter does not set.
        location: {
            const path = root.cfg("StateFile", "");
            return path ? "file://" + path : StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/hyprthemes/greeter.conf";
        }
    }
    // setValue + sync, not a Settings property: those are written on a timer, and the greeter is killed right after a login.
    function remember(key, value) {
        store.setValue(key, value);
        store.sync();
    }

    // ---- sessions ---------------------------------------------------------------------------------------------
    readonly property int sessionFileRole: 258      // SessionModel: Directory 257, File 258, Type 259, Name 260
    function sessionFile(i) {
        if (typeof sessionModel === "undefined" || i < 0 || i >= sessionModel.count) return "";
        const f = sessionModel.data(sessionModel.index(i, 0), sessionFileRole);
        return f ? String(f).split("/").pop() : "";
    }
    function sessionIndexOf(file) {
        if (typeof sessionModel === "undefined" || !file) return -1;
        for (let i = 0; i < sessionModel.count; ++i) if (sessionFile(i) === file) return i;
        return -1;
    }
    function lastSessionIndex() {
        return (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0;
    }
    property int sessionIndex: 0

    // ---- looks ------------------------------------------------------------------------------------------------
    property var currentLook: null
    property var currentHost: null
    property var tried: []
    property bool loggedIn: false

    // A look the user picked: the matching session comes with it, and the pick survives a reboot.
    function selectLook(id) {
        const look = lookById(id);
        if (!look) return;
        const i = sessionIndexOf(look.session);
        if (i >= 0) sessionIndex = i;
        else console.warn("hyprthemes: session " + look.session + " is not installed, keeping the current one");
        remember("look", id);
        remember("sessionChoice", i >= 0 ? look.session : "");
        tried = [];
        showLook(look);
    }

    function showLook(look) {
        tried = tried.concat([look.id]);
        const host = hostComponent.createObject(stage, {
            lookInfo: look,
            realConfig: sddmConfig,
            hyprthemesSessionIndex: sessionIndex,
            opacity: currentHost ? 0 : 1
        });
        host.anchors.fill = stage;
        host.loaded.connect(() => lookReady(look, host));
        host.failed.connect(() => lookFailed(look, host));
        host.start();
    }
    function lookReady(look, host) {
        const previous = currentHost;
        currentLook = look;
        currentHost = host;
        host.forceActiveFocus();
        if (previous) {
            previous.enabled = false;
            fade.finish(previous, host);
        }
        console.log("hyprthemes: look " + look.id + ", session " + sessionIndex + " (" + sessionFile(sessionIndex) + ")");
    }
    function lookFailed(look, host) {
        console.warn("hyprthemes: look " + look.id + " failed to load");
        host.destroy();
        for (const l of availableLooks) {
            if (tried.indexOf(l.id) < 0) { showLook(l); return; }
        }
        if (!currentHost) fallback.active = true;      // nothing loads: still a way in
    }
    Component { id: hostComponent; LookHost {} }

    QtObject {
        id: fade
        property var outgoing: null
        function finish(oldHost, newHost) {
            if (outgoing && outgoing !== oldHost) outgoing.destroy();
            outgoing = oldHost;
            fadeIn.target = newHost;
            fadeIn.restart();
        }
    }
    NumberAnimation {
        id: fadeIn
        property: "opacity"
        to: 1
        duration: 400
        easing.type: Easing.InOutQuad
        // The old look goes once it is covered: this also stops its video and its share of the sddm signals.
        onFinished: { if (fade.outgoing) { fade.outgoing.destroy(); fade.outgoing = null; } }
    }

    Rectangle { anchors.fill: parent; color: "black" }
    Item { id: stage; anchors.fill: parent }
    Loader {
        id: fallback
        anchors.fill: parent
        active: false
        focus: active
        source: "Fallback.qml"
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.loggedIn = true;
            if (root.currentLook) root.remember("look", root.currentLook.id);
            root.remember("sessionChoice", "");
        }
    }

    Component.onCompleted: {
        const stored = String(store.value("look", ""));
        const firstRun = !lookById(stored);
        const look = lookById(stored) || lookById(cfg("DefaultLook", "")) || availableLooks[0];

        let index = sessionIndexOf(String(store.value("sessionChoice", "")));
        if (index < 0) index = lastSessionIndex();
        // First boot after the install: move the plain Hyprland session onto the theme session of the same desktop, nothing else.
        if (firstRun && look && (sessionFile(index) === "" || sessionFile(index) === "hyprland.desktop")) {
            const matching = sessionIndexOf(look.session);
            if (matching >= 0) index = matching;
        }
        sessionIndex = index;
        if (look) showLook(look); else fallback.active = true;
    }

    // ---- the theme button ---------------------------------------------------------------------------------------
    Shortcut {
        sequences: ["Alt+T", "F10"]
        context: Qt.ApplicationShortcut
        enabled: themeButton.visible
        onActivated: menu.toggle()
    }

    Rectangle {
        id: themeButton
        objectName: "themeButton"
        visible: !root.loggedIn && !fallback.active && root.availableLooks.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        width: buttonLabel.implicitWidth + 28
        height: 32
        radius: 6
        color: buttonMouse.containsMouse || menu.open ? "#d0202028" : "#a0101014"
        border.width: 1
        border.color: buttonMouse.containsMouse || menu.open ? "#c0ffffff" : "#50ffffff"
        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: "Theme: " + (root.currentLook ? root.currentLook.label : "…") + "  ▾"
            color: "white"
            font.family: "Noto Sans"
            font.pixelSize: 14
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.toggle()
        }
    }

    FocusScope {
        id: menu
        objectName: "themeMenu"
        anchors.fill: parent
        visible: open
        property bool open: false
        property int highlighted: 0

        function toggle() { if (open) close(); else show(); }
        function show() {
            highlighted = Math.max(0, root.availableLooks.indexOf(root.currentLook));
            open = true;
            forceActiveFocus();
        }
        function close() {
            open = false;
            if (root.currentHost) root.currentHost.forceActiveFocus();
        }
        function pick(i) {
            const look = root.availableLooks[i];
            open = false;
            if (look) root.selectLook(look.id);
        }

        Keys.onPressed: event => {
            const n = root.availableLooks.length;
            if (event.key === Qt.Key_Escape) close();
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) highlighted = (highlighted + 1) % n;
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) highlighted = (highlighted + n - 1) % n;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) pick(highlighted);
            else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + n) pick(event.key - Qt.Key_1);
            else return;
            event.accepted = true;
        }

        MouseArea { anchors.fill: parent; onClicked: menu.close() }      // a click outside closes, and goes no further
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 16 + themeButton.height + 6
            anchors.rightMargin: 16
            width: 280
            height: menuColumn.implicitHeight + 12
            radius: 6
            color: "#e8101014"
            border.width: 1
            border.color: "#50ffffff"
            MouseArea { anchors.fill: parent }                           // clicks between the rows stay in the panel
            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2
                Repeater {
                    model: root.availableLooks
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool lit: menu.highlighted === index
                        readonly property bool installed: root.sessionIndexOf(modelData.session) >= 0
                        width: menuColumn.width
                        height: 48
                        radius: 4
                        color: lit ? "#40ffffff" : "transparent"
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 5
                            text: (root.currentLook === modelData ? "● " : "") + modelData.label
                            color: "white"
                            font.family: "Noto Sans"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            text: parent.installed ? "logs into: " + modelData.desktop : "look only (session not installed)"
                            color: "#c0ffffff"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.index + 1
                            color: "#80ffffff"
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: menu.highlighted = parent.index
                            onClicked: menu.pick(parent.index)
                        }
                    }
                }
                Text {
                    leftPadding: 10
                    topPadding: 2
                    bottomPadding: 2
                    text: "Alt+T · ↑ ↓ · Enter · Esc"
                    color: "#80ffffff"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                }
            }
        }
    }
}
