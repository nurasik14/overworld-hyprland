// Overworld Hyprland — SDDM login theme (Qt 6, Theme-API 2.0): the Minecraft title screen.
// A slowly turning panorama (a seamless strip, scrolled), the OVERWORLD wordmark, a pulsing yellow splash, and the game's
// buttons at its own metrics: 200×20 GUI px, rows 24 GUI px apart from height/4 + 48, GUI scale 3 at 1080p.
//   password = Minecraft text field · Singleplayer = log in · Session: <name> cycles · Sleep in Bed / Respawn / Quit Game = power
// Login logic: sddm.login(user, password, sessionIndex), userModel/sessionModel roles, sddm.loginFailed/loginSucceeded,
// keyboard.capsLock/layouts, sddm.canPowerOff/canReboot/canSuspend. The greeter runs as its own user and cannot read ~/…, so
// fonts, sprites, strips, splashes and quotes are copied into this directory by scripts/install-sddm.sh prepare.
import QtQuick
import "splashes.js" as Splashes
import "quotes.js" as Quotes

Item {
    id: root
    width: 1920
    height: 1080

    // ---- GUI scale: every size below is in GUI px × gs --------------------------------------------------------
    readonly property int gs: Math.max(2, Math.floor(height / 360))
    function px(n) { return n * gs; }
    readonly property int guiHeight: Math.floor(height / gs)
    function rowY(i) { return px(Math.floor(guiHeight / 4) + 48 + 24 * i); }

    // ---- Day or Night: theme.conf Mode=auto|light|dark; auto = by the clock, 06:00–18:59 is Day ------------------
    readonly property string modeSetting: config.stringValue("Mode") || "auto"
    readonly property bool night: modeSetting === "dark" || (modeSetting !== "light" && (new Date().getHours() < 6 || new Date().getHours() >= 19))

    FontLoader { id: mojangles; source: "fonts/OverworldMojangles-Regular.ttf" }
    readonly property string fontUi: mojangles.status === FontLoader.Ready ? mojangles.name : "Noto Sans"

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function dayOfYear(d) { return Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 0)) / 86400000); }

    readonly property string splash: {
        const d = new Date();
        const today = pad(d.getMonth() + 1) + "-" + pad(d.getDate());
        const inSeason = s => !s.from || (s.from <= s.to ? (today >= s.from && today <= s.to) : (today >= s.from || today <= s.to));
        const pool = Splashes.splashes.filter(inSeason);
        return pool.length ? pool[Math.floor(Math.random() * pool.length)].text : "Press Enter!";
    }
    readonly property var quote: {
        const q = Quotes.quotes && Quotes.quotes.length ? Quotes.quotes : [{ text: "The world is still here when you get back.", by: "" }];
        return q[Math.floor(Math.random() * q.length)];
    }

    // ---- login state ------------------------------------------------------------------------------------------
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    readonly property bool haveUsers: typeof userModel !== "undefined" && userModel.count > 0
    property bool busy: false
    property string message: ""

    function userRole(i, role) { return haveUsers ? userModel.data(userModel.index(i, 0), role) : ""; }
    function currentUserName() { return haveUsers ? userRole(userIndex, 257) : userField.text; }
    function sessionName(i) {
        if (typeof sessionModel === "undefined" || sessionModel.count === 0) return "";
        return sessionModel.data(sessionModel.index(i, 0), 260) || "";
    }
    function login() {
        if (busy) return;
        const user = currentUserName();
        if (!user || user.length === 0) { message = "Enter your username"; userField.forceActiveFocus(); return; }
        busy = true; message = "";
        sddm.login(user, passwordField.text, sessionIndex);
    }
    Connections {
        target: sddm
        function onLoginSucceeded() { root.busy = false; stage.opacity = 0.0; }
        function onLoginFailed() { root.busy = false; passwordField.text = ""; root.message = "Failed to log in: wrong password"; passwordField.forceActiveFocus(); }
        function onInformationMessage(msg) { root.busy = false; root.message = msg; }
    }
    readonly property bool capsOn: typeof keyboard !== "undefined" && keyboard.capsLock
    readonly property string layoutName: (typeof keyboard !== "undefined" && keyboard.layouts && keyboard.layouts.length > 0)
                                         ? keyboard.layouts[keyboard.currentLayout].shortName : ""

    Component.onCompleted: { if (haveUsers) passwordField.forceActiveFocus(); else userField.forceActiveFocus(); }

    // ---- inline components ------------------------------------------------------------------------------------
    component McText: Item {                          // hard drop shadow 1 GUI px, colour × 0.25, as in the game
        id: mcText
        property alias text: main.text
        property alias color: main.color
        property color shadowColor: "#3f3f3f"
        implicitWidth: main.implicitWidth
        implicitHeight: main.implicitHeight
        width: implicitWidth; height: implicitHeight
        Text { x: root.gs; y: root.gs; text: main.text; color: mcText.shadowColor; font: main.font; renderType: main.renderType; antialiasing: false }
        Text { id: main; color: "white"; font.family: root.fontUi; font.pixelSize: 8 * root.gs; font.hintingPreference: Font.PreferNoHinting; renderType: Text.NativeRendering; antialiasing: false }
    }
    component NineSlice: Item {                       // an upscaled nine-slice sprite, nearest neighbour
        id: slice
        property string sprite: ""
        property int border: 3
        BorderImage {
            width: parent.width / root.gs; height: parent.height / root.gs
            scale: root.gs; transformOrigin: Item.TopLeft
            source: slice.sprite; smooth: false
            border { left: slice.border; right: slice.border; top: slice.border; bottom: slice.border }
        }
    }
    component McButton: FocusScope {                  // hover and keyboard focus = white border at once, like the game
        id: btn
        property string text: ""
        property bool active: true
        signal clicked()
        width: root.px(200); height: root.px(20)
        activeFocusOnTab: active
        readonly property bool lit: active && (ma.containsMouse || activeFocus)
        NineSlice { anchors.fill: parent; sprite: !btn.active ? "gui/button_disabled.png" : (btn.lit ? "gui/button_highlighted.png" : "gui/button.png") }
        McText { anchors.centerIn: parent; text: btn.text; color: btn.active ? "white" : "#a0a0a0" }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (btn.active) btn.clicked(); } }
        Keys.onReturnPressed: if (active) clicked()
        Keys.onEnterPressed: if (active) clicked()
        Keys.onSpacePressed: if (active) clicked()
    }
    component McField: FocusScope {                   // the game's text field: black fill, grey frame, white when focused
        id: field
        property alias text: input.text
        property alias echoMode: input.echoMode
        property string hint: ""
        signal accepted()
        width: root.px(200); height: root.px(20)
        NineSlice { anchors.fill: parent; border: 1; sprite: input.activeFocus ? "gui/text_field_highlighted.png" : "gui/text_field.png" }
        Text {
            anchors.left: parent.left; anchors.leftMargin: root.px(4); anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0; text: field.hint; color: "#707070"
            font: input.font; renderType: Text.NativeRendering; antialiasing: false
        }
        TextInput {
            id: input
            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: root.px(4); anchors.rightMargin: root.px(4); anchors.verticalCenter: parent.verticalCenter
            focus: true; clip: true; passwordCharacter: "*"; passwordMaskDelay: 0
            color: "#e0e0e0"; selectionColor: "#0000ff"; selectedTextColor: "white"
            font.family: root.fontUi; font.pixelSize: 8 * root.gs; font.hintingPreference: Font.PreferNoHinting
            renderType: TextInput.NativeRendering; antialiasing: false
            enabled: !root.busy
            onAccepted: field.accepted()
            Keys.onEscapePressed: text = ""
        }
    }

    // ---- the panorama: two copies of the seamless strip side by side, turning once in 3 minutes ------------------
    Rectangle { anchors.fill: parent; color: root.night ? "#0b1020" : "#78a7ff" }
    Item {
        id: panorama
        anchors.fill: parent
        clip: true
        readonly property real stripW: strip1.status === Image.Ready ? strip1.sourceSize.width * root.height / strip1.sourceSize.height : root.width
        property real offset: 0
        NumberAnimation on offset { from: 0; to: 1; duration: 180000; loops: Animation.Infinite; running: strip1.status === Image.Ready }
        Image {
            id: strip1
            x: -panorama.offset * panorama.stripW; y: 0
            width: panorama.stripW; height: root.height
            source: root.night ? "backgrounds/strip-night.png" : "backgrounds/strip-day.png"
            fillMode: Image.Stretch; cache: true; asynchronous: true; smooth: true
        }
        Image {
            x: strip1.x + panorama.stripW; y: 0
            width: panorama.stripW; height: root.height
            source: strip1.source
            fillMode: Image.Stretch; cache: true; asynchronous: true; smooth: true
        }
        // the title screen's soft dim over the world, darker at the top and bottom edges
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#70000000" }
                GradientStop { position: 0.35; color: "#20000000" }
                GradientStop { position: 0.75; color: "#20000000" }
                GradientStop { position: 1.0; color: "#80000000" }
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // ---- wordmark ----------------------------------------------------------------------------------------
        Image {
            id: wordmark
            source: "wordmark.png"
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.px(30)
            width: sourceSize.width * root.gs / 3; height: sourceSize.height * root.gs / 3
            smooth: root.gs % 3 !== 0
        }
        // ---- splash: tilted 20°, pulsing, scaled down when long -------------------------------------------------
        Item {
            x: wordmark.x + wordmark.width * 0.83; y: wordmark.y + wordmark.height * 0.88
            rotation: -20
            McText {
                id: splashText
                anchors.centerIn: parent
                text: root.splash; color: "#ffff00"; shadowColor: "#3f3f00"
                readonly property real fit: Math.min(1.8, 1.8 * root.px(100) / (implicitWidth + root.px(32)))
                property real pulse: 0
                scale: fit * (1 - pulse * 0.055)
                SequentialAnimation on pulse { loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 1; duration: 250; easing.type: Easing.OutSine }
                    NumberAnimation { from: 1; to: 0; duration: 250; easing.type: Easing.InSine } }
            }
        }

        // ---- the column --------------------------------------------------------------------------------------
        McText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: wordmark.y + wordmark.height + root.px(14)
            text: "Day " + root.dayOfYear(root.now) + " · " + root.pad(root.now.getHours()) + ":" + root.pad(root.now.getMinutes())
        }
        McText {                                      // who is logging in, or why not
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.haveUsers || root.message.length > 0
            y: root.rowY(0) - root.px(12)
            text: root.message.length ? root.message : "Player: " + (root.userRole(root.userIndex, 258) || root.userRole(root.userIndex, 257))
            color: root.message.length ? "#ff5555" : "white"
        }
        McButton {                                    // several users: a cycling button above the label
            visible: root.haveUsers && userModel.count > 1
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.rowY(0) - root.px(36)
            text: "Switch Player (" + (root.userIndex + 1) + "/" + (root.haveUsers ? userModel.count : 0) + ")"
            onClicked: root.userIndex = (root.userIndex + 1) % userModel.count
        }
        McField {                                     // no user list: type a name
            id: userField
            visible: !root.haveUsers
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.rowY(0) - root.px(24)
            hint: "Username"
            KeyNavigation.tab: passwordField
            onAccepted: passwordField.forceActiveFocus()
        }
        McField {
            id: passwordField
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.rowY(0)
            echoMode: TextInput.Password
            hint: "Enter password"
            focus: true
            KeyNavigation.tab: playButton
            onAccepted: root.login()
        }
        McButton {
            id: playButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.rowY(1)
            text: root.busy ? "Joining world..." : "Singleplayer"
            active: !root.busy
            KeyNavigation.tab: sessionButton
            onClicked: root.login()
        }
        McButton {
            id: sessionButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.rowY(2)
            text: "Session: " + (root.sessionName(root.sessionIndex) || "default")
            KeyNavigation.tab: sleepButton
            onClicked: if (typeof sessionModel !== "undefined" && sessionModel.count > 0) root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
        }
        Row {                                         // half-width pair, 12 GUI px below the column, like Options… / Quit Game
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.rowY(3) + root.px(12)
            spacing: root.px(4)
            McButton { id: sleepButton; width: root.px(98); text: "Sleep in Bed"; active: sddm.canSuspend; KeyNavigation.tab: respawnButton; onClicked: sddm.suspend() }
            McButton { id: respawnButton; width: root.px(98); text: "Respawn"; active: sddm.canReboot; KeyNavigation.tab: quitButton; onClicked: sddm.reboot() }
        }
        McButton {
            id: quitButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.rowY(4) + root.px(12)
            text: "Quit Game"
            active: sddm.canPowerOff
            KeyNavigation.tab: root.haveUsers ? passwordField : userField
            onClicked: sddm.powerOff()
        }

        // ---- bottom left, where the game prints its version; bottom right, where it prints its copyright line --------
        Column {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: root.px(2)
            spacing: root.px(1)
            McText { text: Qt.formatDate(root.now, "dddd d MMMM") }
            McText {
                visible: text.length > 0
                text: (root.layoutName.length ? "Keyboard: " + root.layoutName : "") + (root.capsOn ? "   Caps Lock is on" : "")
                color: root.capsOn ? "#ffff55" : "white"
            }
        }
        McText {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: root.px(2)
            text: "“" + root.quote.text + "”"
        }
    }
}
