// Overworld Hyprland — SDDM login theme (Qt 6, Theme-API 2.0).
// Grammar per docs/DESIGN.md §7.6: wallpaper per mode, a paper card 420×320 at (120,380) titled 后宫 · SIGN IN with
// the user list, a 320×48 paper password field with the 印 seal, a session selector, the clock top-right
// (Cormorant 64 + 時辰 glyph 48 in the seal colour), a quote, and three mini hanging scrolls bottom-right for power.
// Login logic follows /usr/share/sddm/themes/silent: sddm.login(user, password, sessionIndex), userModel/sessionModel
// roles, sddm.loginFailed/loginSucceeded, keyboard.capsLock/layouts, sddm.canPowerOff/canReboot/canSuspend.
// Mode (light|dark), background and colours come from theme.conf + Palette.js (baked by scripts/install-sddm.sh).
import QtQuick
import QtQuick.Controls
import "Palette.js" as Palette
import "quotes.js" as Quotes

Item {
    id: root
    width: 1920
    height: 1080

    // ---- mode & palette --------------------------------------------------------------------------------------
    readonly property string mode: (config.stringValue("Mode") || "light") === "dark" ? "dark" : "light"
    readonly property bool dark: mode === "dark"
    readonly property var pal: Palette.get(mode)
    function c(role, fallback) { return (pal && pal[role]) ? pal[role] : (fallback || "#ff00ff"); }

    // ---- fonts bundled in fonts/ (the sddm user cannot see ~/.local/share/fonts) ------------------------------
    FontLoader { id: fBrush; source: "fonts/MaShanZheng-Regular.ttf" }
    FontLoader { id: fTitle; source: "fonts/ZCOOLXiaoWei-Regular.ttf" }
    FontLoader { id: fClock; source: "fonts/CormorantGaramond[wght].ttf" }
    FontLoader { id: fQuote; source: "fonts/EBGaramond[wght].ttf" }
    readonly property string brushFamily: fBrush.status === FontLoader.Ready ? fBrush.name : "Noto Sans CJK SC"
    readonly property string titleFamily: fTitle.status === FontLoader.Ready ? fTitle.name : "Noto Serif CJK SC"
    readonly property string clockFamily: fClock.status === FontLoader.Ready ? fClock.name : "serif"
    readonly property string quoteFamily: fQuote.status === FontLoader.Ready ? fQuote.name : "serif"
    readonly property string uiFamily: "Noto Sans"
    readonly property string bodyFamily: "Noto Sans CJK SC"

    // ---- time: 時辰 period, Chinese numerals for the date --------------------------------------------------------
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    readonly property var shichenGlyphs: ["子","丑","寅","卯","辰","巳","午","未","申","酉","戌","亥"]
    readonly property var shichenSpans: ["23–1","1–3","3–5","5–7","7–9","9–11","11–13","13–15","15–17","17–19","19–21","21–23"]
    readonly property var shichenNames: ["Rat · midnight","Ox","Tiger","Rabbit","Dragon","Snake","Horse · noon","Goat","Monkey","Rooster","Dog","Pig"]
    function shichenIndex(d) { return Math.floor(((d.getHours() + 1) % 24) / 2); }
    function cnNum(n) {
        const d = ["零","一","二","三","四","五","六","七","八","九","十"];
        if (n <= 10) return d[n];
        if (n < 20) return "十" + d[n - 10];
        if (n === 20) return "二十";
        if (n < 30) return "廿" + d[n - 20];
        if (n === 30) return "三十";
        return "三十" + d[n - 30];
    }
    function cnDate(d) { return cnNum(d.getMonth() + 1) + "月" + cnNum(d.getDate()); }

    // ---- quote (one per greeter start) ------------------------------------------------------------------------
    readonly property var quote: {
        const q = Quotes.quotes && Quotes.quotes.length ? Quotes.quotes : [{ text: "Do things out of love, not for love.", by: "" }];
        return q[Math.floor(Math.random() * q.length)];
    }

    // ---- login state ------------------------------------------------------------------------------------------
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    readonly property bool haveUsers: typeof userModel !== "undefined" && userModel.count > 0
    property bool busy: false
    property string message: ""
    property bool messageIsError: false

    function userRole(i, role) { return haveUsers ? userModel.data(userModel.index(i, 0), role) : ""; }
    function currentUserName() { return haveUsers ? userRole(userIndex, 257) : userField.text; }
    function sessionName(i) {
        if (typeof sessionModel === "undefined" || sessionModel.count === 0) return "";
        return sessionModel.data(sessionModel.index(i, 0), 260) || "";
    }
    function warn(text, isError) { message = text; messageIsError = isError; }
    function login() {
        const user = currentUserName();
        if (!user || user.length === 0) { warn("Enter your user name", true); return; }
        busy = true; warn("", false);
        sddm.login(user, passwordField.text, sessionIndex);
    }
    Connections {
        target: sddm
        function onLoginSucceeded() { root.busy = false; stage.opacity = 0.0; }
        function onLoginFailed() { root.busy = false; passwordField.text = ""; root.warn("Login failed · 印 not accepted", true); shake.restart(); passwordField.forceActiveFocus(); }
        function onInformationMessage(msg) { root.busy = false; root.warn(msg, true); }
    }
    readonly property bool capsOn: typeof keyboard !== "undefined" && keyboard.capsLock
    readonly property string layoutName: (typeof keyboard !== "undefined" && keyboard.layouts && keyboard.layouts.length > 0)
                                         ? keyboard.layouts[keyboard.currentLayout].shortName : ""

    Component.onCompleted: { if (haveUsers) passwordField.forceActiveFocus(); else userField.forceActiveFocus(); }

    // ---- inline components ------------------------------------------------------------------------------------
    component Seal: Rectangle {                       // the red seal 印 — DESIGN §6.3
        property string glyph: "印"
        property int sz: 24
        width: sz; height: sz; radius: 3
        color: root.c("seal")
        Text { anchors.centerIn: parent; text: parent.glyph; color: root.c("textOnSeal"); font.family: root.brushFamily; font.pixelSize: Math.round(parent.sz * 0.68) }
    }
    component InkButton: Rectangle {                  // quiet paper button; filled = accent
        property string text: ""
        property bool filled: false
        property bool enabledLook: true
        signal clicked()
        implicitWidth: lbl.implicitWidth + 28; implicitHeight: 32; radius: 6
        color: filled ? root.c("accent") : (mouse.pressed ? root.c("inkWashStrong") : (mouse.containsMouse ? root.c("inkWash") : "transparent"))
        border.width: filled ? 0 : 1; border.color: root.c("hairline")
        opacity: enabledLook ? 1.0 : 0.45
        Text { id: lbl; anchors.centerIn: parent; text: parent.text; color: parent.filled ? root.c("textOnAccent") : root.c("text"); font.family: root.uiFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (parent.enabledLook) parent.clicked() }
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    component Scroll: Item {                          // a mini hanging scroll (power action) — DESIGN §7.4, 64×120
        property string glyph: "关"
        property string label: "Shutdown"
        property bool can: true
        signal activated()
        width: 64; height: 120
        opacity: can ? 1.0 : 0.4
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: 72; height: 8; radius: 4; color: root.c("woodDark") }
        Rectangle {
            id: sheet
            anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 100
            y: sm.containsMouse ? 12 : 8
            color: root.c("surface"); border.width: 1; border.color: root.c("hairline")
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 14; text: parent.parent.glyph; color: root.c("text"); font.family: root.brushFamily; font.pixelSize: 34 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 60; text: parent.parent.label; color: root.c("textMuted"); font.family: root.clockFamily; font.pixelSize: 11; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 }
            Seal { visible: sm.containsMouse; sz: 14; anchors.horizontalCenter: parent.horizontalCenter; y: 80 }
            Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 108; width: 72; height: 8; radius: 4; color: root.c("woodDark") }
        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (parent.can) parent.activated() }
    }

    // ---- background ---------------------------------------------------------------------------------------------
    Rectangle { anchors.fill: parent; color: root.c("bg0") }
    Image {
        id: bg
        anchors.fill: parent
        source: config.stringValue("Background") || ("backgrounds/sddm-" + root.mode + ".png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        onStatusChanged: if (status === Image.Error) { bgFallback.visible = true; }
    }
    Item {                                            // fallback: plain sheet + wordmark when no art is installed
        id: bgFallback; visible: false; anchors.fill: parent
        Text { anchors.right: parent.right; anchors.rightMargin: 160; anchors.verticalCenter: parent.verticalCenter
               text: "薬屋のひとりごと"; color: root.c("textMuted"); opacity: 0.6; font.family: "Noto Serif CJK JP"; font.pixelSize: 72 }
    }

    Item {
        id: stage
        anchors.fill: parent
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

        // ---- clock, top-right ------------------------------------------------------------------------------------
        Item {
            id: clockBlock
            anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 72; anchors.rightMargin: 120
            width: 420; height: 160
            Text {
                id: clockText
                anchors.right: shichenGlyph.left; anchors.rightMargin: 24; anchors.top: parent.top
                text: root.pad(root.now.getHours()) + ":" + root.pad(root.now.getMinutes())
                color: root.c("text"); font.family: root.clockFamily; font.pixelSize: 64; font.weight: Font.Light
            }
            Text {
                id: shichenGlyph
                anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 6
                text: root.shichenGlyphs[root.shichenIndex(root.now)]
                color: root.c("seal"); font.family: root.brushFamily; font.pixelSize: 48
            }
            Text {
                anchors.right: parent.right; anchors.top: shichenGlyph.bottom; anchors.topMargin: 2
                text: root.shichenSpans[root.shichenIndex(root.now)] + " · hour of the " + root.shichenNames[root.shichenIndex(root.now)]
                color: root.c("textMuted"); font.family: root.quoteFamily; font.pixelSize: 13
            }
            Text {
                anchors.right: parent.right; anchors.top: clockText.bottom; anchors.topMargin: 26
                text: Qt.formatDate(root.now, "dddd d MMMM") + "  ·  " + root.cnDate(root.now)
                color: root.c("text"); font.family: root.quoteFamily; font.pixelSize: 18; font.italic: true
            }
        }

        // ---- the paper card 420×320 at (120,380): 后宫 · SIGN IN -----------------------------------------------
        Item {
            id: card
            x: 120; y: 380; width: 420; height: 320
            transform: Translate { id: shakeT; x: 0 }
            SequentialAnimation {                     // fail = 160 ms shake (DESIGN §8 password field)
                id: shake
                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 40 }
                NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 40 }
                NumberAnimation { target: shakeT; property: "x"; to: -4; duration: 40 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 40 }
            }
            Rectangle { anchors.fill: parent; anchors.topMargin: 6; anchors.leftMargin: 2; anchors.rightMargin: -2; radius: 10; color: root.c("shadowStrong") } // soft shadow stand-in
            Rectangle {                               // frame + paper
                id: paper
                anchors.fill: parent; radius: 8
                color: root.c("surface"); border.width: 2; border.color: root.c("frame")
                clip: true
                Rectangle {                           // lacquer title strip 28 px
                    id: strip
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 2
                    height: 28; color: root.c("titlebar")
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: "后宫"; color: root.c("titlebarText"); font.family: root.titleFamily; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 1; height: 14; color: root.c("titlebarText"); opacity: 0.35; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "SIGN IN"; color: root.c("titlebarText"); opacity: 0.9; font.family: root.clockFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Rectangle { width: 9; height: 9; color: root.c("titlebarText"); opacity: 0.4; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 9; height: 9; color: root.c("titlebarText"); opacity: 0.4; anchors.verticalCenter: parent.verticalCenter }
                        Seal { sz: 14; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Rectangle {                           // 1 px inner hairline, inset 4
                    anchors.fill: parent; anchors.topMargin: 30 + 4; anchors.leftMargin: 6; anchors.rightMargin: 6; anchors.bottomMargin: 6
                    radius: 5; color: "transparent"; border.width: 1; border.color: root.c("hairline")
                }

                // content
                Item {
                    anchors.fill: parent; anchors.topMargin: 30 + 16; anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.bottomMargin: 16

                    // user row: avatar + name list (click to select; ← → cycle)
                    Row {
                        id: userRow
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 56; spacing: 12
                        Rectangle {
                            width: 48; height: 48; radius: 24; anchors.verticalCenter: parent.verticalCenter
                            color: root.c("surfaceAlt"); border.width: 2; border.color: root.c("seal"); clip: true
                            Image {
                                anchors.fill: parent; anchors.margins: 2
                                source: root.haveUsers && config.boolValue("ShowUserAvatar") ? (root.userRole(root.userIndex, 260) || "") : ""
                                fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready
                            }
                            Text { anchors.centerIn: parent; text: "猫"; color: root.c("textMuted"); font.family: root.brushFamily; font.pixelSize: 22 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            visible: root.haveUsers
                            Text { text: root.userRole(root.userIndex, 258) || root.userRole(root.userIndex, 257); color: root.c("text"); font.family: root.bodyFamily; font.pixelSize: 16 }
                            Row {
                                spacing: 8
                                Text { text: root.userRole(root.userIndex, 257); color: root.c("textMuted"); font.family: root.uiFamily; font.pixelSize: 12 }
                                Text {
                                    visible: root.haveUsers && userModel.count > 1
                                    text: "‹ " + (root.userIndex + 1) + "/" + userModel.count + " ›"
                                    color: root.c("accent2"); font.family: root.uiFamily; font.pixelSize: 12
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.userIndex = (root.userIndex + 1) % userModel.count }
                                }
                            }
                        }
                        TextField {                   // no users listed → type a name
                            id: userField
                            visible: !root.haveUsers; width: 300; height: 40; anchors.verticalCenter: parent.verticalCenter
                            placeholderText: "user name"; font.family: root.uiFamily; font.pixelSize: 14; color: root.c("text")
                            background: Rectangle { color: root.c("surface"); radius: 6; border.width: 2; border.color: userField.activeFocus ? root.c("accent") : root.c("frame") }
                            onAccepted: passwordField.forceActiveFocus()
                        }
                    }

                    // password field 320×48 with the seal
                    Item {
                        id: fieldRow
                        anchors.top: userRow.bottom; anchors.topMargin: 18; anchors.left: parent.left; width: 320; height: 48
                        Rectangle {
                            anchors.fill: parent; radius: 6
                            color: root.c("surface"); border.width: 2
                            border.color: root.messageIsError && root.message.length ? root.c("seal") : (passwordField.activeFocus ? root.c("accent") : root.c("frame"))
                            Behavior on border.color { ColorAnimation { duration: 160 } }
                        }
                        Seal { sz: 24; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter }
                        TextField {
                            id: passwordField
                            anchors.fill: parent; anchors.leftMargin: 46; anchors.rightMargin: 10
                            echoMode: TextInput.Password; passwordCharacter: "•"; passwordMaskDelay: 0
                            placeholderText: "印 · password"; placeholderTextColor: root.c("textMuted")
                            font.family: root.uiFamily; font.pixelSize: 15; color: root.c("text")
                            selectionColor: root.c("selection"); selectedTextColor: root.c("text")
                            background: null
                            enabled: !root.busy
                            onAccepted: root.login()
                            Keys.onEscapePressed: text = ""
                            KeyNavigation.tab: loginBtn
                        }
                    }
                    Text {                            // caps lock / layout / message
                        id: msg
                        anchors.top: fieldRow.bottom; anchors.topMargin: 8; anchors.left: parent.left; anchors.right: parent.right
                        text: root.message.length ? root.message : (root.capsOn ? "Caps Lock is on" : (root.layoutName.length ? "layout · " + root.layoutName : ""))
                        color: root.message.length && root.messageIsError ? root.c("error") : (root.capsOn ? root.c("warning") : root.c("textMuted"))
                        font.family: root.uiFamily; font.pixelSize: 12; elide: Text.ElideRight
                    }

                    // bottom row: session selector (small) + Sign in button
                    Item {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 36
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Text { text: "session"; color: root.c("textMuted"); font.family: root.uiFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                height: 26; width: sessLbl.implicitWidth + 24; radius: 6
                                color: sessMa.containsMouse ? root.c("inkWash") : "transparent"; border.width: 1; border.color: root.c("hairline")
                                anchors.verticalCenter: parent.verticalCenter
                                Text { id: sessLbl; anchors.centerIn: parent; text: (root.sessionName(root.sessionIndex) || "default") + " ▸"; color: root.c("accent2"); font.family: root.uiFamily; font.pixelSize: 12 }
                                MouseArea {
                                    id: sessMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (typeof sessionModel !== "undefined" && sessionModel.count > 0) root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
                                }
                            }
                        }
                        InkButton {
                            id: loginBtn
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: root.busy ? "signing in …" : "Sign in  印"; filled: true; enabledLook: !root.busy
                            onClicked: root.login()
                            Keys.onReturnPressed: root.login()
                            Keys.onEnterPressed: root.login()
                            activeFocusOnTab: true
                        }
                    }
                }
            }
        }

        // ---- quote under the card ----------------------------------------------------------------------------------
        Column {
            x: 120; anchors.top: card.bottom; anchors.topMargin: 36; width: 560; spacing: 4
            Text { width: parent.width; wrapMode: Text.WordWrap; text: "“" + root.quote.text + "”"; color: root.c("textMuted"); font.family: root.quoteFamily; font.pixelSize: 18; font.italic: true }
            Text { visible: root.quote.by && root.quote.by.length > 0; text: "— " + root.quote.by; color: root.c("textMuted"); opacity: 0.8; font.family: root.quoteFamily; font.pixelSize: 13 }
        }

        // ---- power: three mini scrolls bottom-right ------------------------------------------------------------------
        Row {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.rightMargin: 120; anchors.bottomMargin: 64; spacing: 20
            Scroll { glyph: "眠"; label: "Suspend";  can: typeof sddm !== "undefined" && sddm.canSuspend;  onActivated: sddm.suspend() }
            Scroll { glyph: "启"; label: "Reboot";   can: typeof sddm !== "undefined" && sddm.canReboot;   onActivated: sddm.reboot() }
            Scroll { glyph: "关"; label: "Shutdown"; can: typeof sddm !== "undefined" && sddm.canPowerOff; onActivated: sddm.powerOff() }
        }

        // ---- wordmark, bottom-left, small ----------------------------------------------------------------------------
        Row {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: 120; anchors.bottomMargin: 72; spacing: 10
            Seal { sz: 20; glyph: "猫"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Overworld"; color: root.c("textMuted"); font.family: root.clockFamily; font.pixelSize: 16; font.weight: Font.DemiBold; font.letterSpacing: 2; font.capitalization: Font.AllUppercase; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.dark ? "后宫 · Inner Palace" : "药屋 · Overworld"; color: root.c("textMuted"); opacity: 0.8; font.family: root.bodyFamily; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
