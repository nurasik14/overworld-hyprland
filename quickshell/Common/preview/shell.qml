//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common

/*  Design-system preview.  Run from the repo root:
 *      source scripts/dev-env.sh && qs -p quickshell/Common/preview
 *  `Common` inside this directory is a symlink to `..` so `import qs.Common` resolves exactly as it does in the
 *  real shell (config root = quickshell/).  A relative `import "../" as Common` does NOT work: Quickshell only
 *  registers `pragma Singleton` types for directories inside the config root (see docs/DESIGN.md §12).
 */
ShellRoot {
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === "eDP-1") || Quickshell.screens[0]
        implicitWidth: 1200
        implicitHeight: 760
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "overworld-preview"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore

        PaperBackground {
            anchors.fill: parent
            ground: "bg0"
            radius: Theme.radius.lg
        }

        // ---------------------------------------------------------------- header
        Item {
            id: header
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: Theme.space.xl
            height: 40
            Row {
                spacing: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                Seal { size: 24; glyph: "薬"; label: "Overworld" ; anchors.verticalCenter: parent.verticalCenter }
                InkText { role: "display_sm"; text: Theme.isDark ? "后宫" : "薬屋"; anchors.verticalCenter: parent.verticalCenter }
                InkText { role: "subtitle"; text: Theme.isDark ? "INNER PALACE · DARK" : "OVERWORLD · LIGHT"; muted: true; anchors.verticalCenter: parent.verticalCenter }
                InkText { role: "small"; text: "mode ← " + Theme.modePath.replace(Theme.home, "~"); muted: true; anchors.verticalCenter: parent.verticalCenter }
            }
            InkButton {
                id: modeToggle
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                icon: Theme.isDark ? "󰖨" : "󰖔"
                text: Theme.isDark ? "Light · 薬屋" : "Dark · 后宫"
                tooltip: "Toggle light/dark"
                onClicked: Theme.toggleMode()
            }
        }

        // ---------------------------------------------------------------- body
        RowLayout {
            anchors.top: header.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: Theme.space.xl
            anchors.topMargin: Theme.space.lg
            spacing: Theme.space.lg

            // ---- components column
            ColumnLayout {
                Layout.preferredWidth: 420
                Layout.fillHeight: true
                spacing: Theme.space.lg

                PaperPanel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 196
                    title: "天气"; subtitle: "Weather"
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.space.xs
                        RowLayout {
                            spacing: Theme.space.md
                            InkText { text: "󰖕"; font.family: Theme.fontMono; font.pixelSize: 34; color: Theme.accent }
                            InkText { role: "weather_temp"; text: "26°"; }
                            ColumnLayout {
                                spacing: 0
                                InkText { role: "title"; text: "九龍 · Kowloon" }
                                InkText { role: "small"; text: "Cloudy · 午 11–13"; muted: true }
                            }
                        }
                        InkDivider { Layout.fillWidth: true; brush: true; Layout.preferredHeight: 12 }
                        InkText { role: "mono"; text: "precip 0%   humidity 85%   wind 3 km/h"; muted: true }
                        Row {
                            spacing: 3
                            Repeater {
                                model: 24
                                Rectangle {
                                    width: 11; height: 6 + ((index * 7) % 23)
                                    anchors.bottom: parent.bottom
                                    color: index === 11 ? Theme.seal : Theme.text
                                    opacity: index === 11 ? 1 : 0.85
                                    radius: 1
                                }
                            }
                        }
                    }
                }

                PaperPanel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 108
                    title: "音乐"; subtitle: "Spotify"; transparent: true; sealGlyph: "猫"
                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.space.md
                        Rectangle { width: 48; height: 48; radius: Theme.radius.xs; color: Theme.surfaceAlt; border.width: 1; border.color: Theme.hairline
                            InkText { anchors.centerIn: parent; text: "󰝚"; font.family: Theme.fontMono; font.pixelSize: 22; muted: true } }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            InkText { role: "body"; text: "幾億光年"; Layout.fillWidth: true }
                            InkText { role: "small"; text: "Omoinotake  ·  transparent card @ 0.82"; muted: true; Layout.fillWidth: true }
                            Rectangle { Layout.fillWidth: true; height: 3; radius: 1; color: Theme.surfaceAlt
                                Rectangle { width: parent.width * 0.42; height: parent.height; radius: 1; color: Theme.accent } }
                        }
                        Row { spacing: 4
                            InkButton { icon: "󰒮"; quiet: true; tooltip: "Previous" }
                            InkButton { icon: "󰏤"; quiet: true; tooltip: "Pause" }
                            InkButton { icon: "󰒭"; quiet: true; tooltip: "Next" } }
                    }
                }

                PaperPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "印"; subtitle: "Controls"; sealGlyph: "印"
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.space.md
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.space.sm
                            InkButton { text: "Default" }
                            InkButton { text: "Connect"; icon: "󰤨"; accentFill: true }
                            InkButton { text: "Confirm 印"; primary: true }
                            InkButton { text: "Checked"; checked: true }
                            InkButton { text: "Disabled"; enabled: false }
                            InkButton { icon: "󰂯"; quiet: true; tooltip: "Bluetooth" }
                            InkButton { text: "Focus ring"; focusRingVisible: true }
                        }
                        InkDivider { Layout.fillWidth: true }
                        RowLayout {
                            spacing: Theme.space.lg
                            Repeater {
                                model: [["印", 14, false], ["猫", 24, false], ["薬", 48, true], ["药", 48, true], ["猫", 48, true]]
                                ColumnLayout {
                                    spacing: 4
                                    Seal { glyph: modelData[0]; size: modelData[1]; rough: modelData[2]; Layout.alignment: Qt.AlignHCenter; label: "seal " + modelData[0] }
                                    InkText { role: "small"; text: modelData[1] + (modelData[2] ? " png" : " drawn"); muted: true; Layout.alignment: Qt.AlignHCenter }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Image { source: Theme.texture("enso-ink"); width: 64; height: 64; sourceSize: Qt.size(128, 128); smooth: true; mipmap: true }
                        }
                        RowLayout {
                            spacing: Theme.space.md
                            Repeater {
                                model: [["hover", 0.6], ["pressed", 1.0], ["selection", -1]]
                                Rectangle {
                                    width: 96; height: 28; radius: Theme.radius.sm
                                    color: modelData[1] < 0 ? Theme.selection : Theme.inkWash
                                    opacity: modelData[1] < 0 ? 1 : modelData[1]
                                    border.width: 1; border.color: Theme.hairline
                                    InkText { anchors.centerIn: parent; role: "small"; text: modelData[0] }
                                }
                            }
                            Rectangle { width: 96; height: 28; radius: Theme.radius.sm; color: Theme.sealWash; border.width: 1; border.color: Theme.seal
                                InkText { anchors.centerIn: parent; role: "small"; text: "urgent"; color: Theme.seal } }
                        }
                    }
                }
            }

            // ---- type + palette column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.space.lg

                PaperPanel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 318
                    title: "字"; subtitle: "Type roles"; sealGlyph: "印"
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        Repeater {
                            model: ["display", "display_sm", "title", "subtitle", "body", "body_latin", "ui", "small", "mono", "clock_bar"]
                            RowLayout {
                                spacing: Theme.space.sm
                                Layout.fillWidth: true
                                InkText { role: "small"; text: modelData; muted: true; Layout.preferredWidth: 76 }
                                InkText {
                                    role: modelData
                                    Layout.fillWidth: true
                                    text: {
                                        switch (modelData) {
                                        case "display": return "薬屋 · 后宫 · 32px 马善政";
                                        case "display_sm": return "药 猫 印 · 28 px";
                                        case "title": return "天气 · 日历 · 系统 · 18 px ZCOOL XiaoWei";
                                        case "subtitle": return "WEATHER · CALENDAR · 13 PX CORMORANT";
                                        case "body": return "猫猫在后宫当试毒官。14 px LXGW WenKai";
                                        case "body_latin": return "Do things out of love, not for love. — 15 px EB Garamond";
                                        case "ui": return "Connect · Disconnect · Rescan · 13 px Noto Sans";
                                        case "small": return "12 px captions · 2026-10-29 · Noto Sans";
                                        case "mono": return "kernel 7.2.13 · 󰍛 42% · 󰘚 6.1G · 13 px JetBrainsMono NF";
                                        case "clock_bar": return "11:42 · 午 · 16 px Cormorant 600";
                                        default: return modelData;
                                        }
                                    }
                                }
                                InkText { role: "small"; text: Theme.fontFor(modelData).pixelSize + "px"; muted: true }
                            }
                        }
                    }
                }

                PaperPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "色"; subtitle: "Palette · " + Theme.mode; sealGlyph: "印"; padding: 12
                    GridLayout {
                        anchors.fill: parent
                        columns: 5
                        columnSpacing: 6
                        rowSpacing: 6
                        Repeater {
                            model: ["bg0", "bg1", "bg2", "surface", "surfaceAlt",
                                    "frame", "hairline", "titlebar", "text", "textMuted",
                                    "accent", "accentSoft", "accent2", "gold", "seal",
                                    "success", "herb", "warning", "error", "info",
                                    "plum", "jade", "indigo", "wood", "woodDark",
                                    "shadow", "overlay", "inkWash", "sealWash", "selection"]
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radius.xs
                                color: Theme.col(modelData)
                                border.width: 1
                                border.color: Theme.hairline
                                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
                                readonly property bool onDark: {
                                    const q = Qt.color(Theme.col(modelData));
                                    const lum = 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b;
                                    return q.a < 0.5 ? Theme.isDark : lum < 0.45;
                                }
                                Column {
                                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 5
                                    InkText { role: "small"; text: modelData; color: parent.parent.onDark ? "#f3ecdc" : "#2a2622"; font.weight: 600 }
                                    InkText { role: "small"; text: Theme.c[modelData]; color: parent.parent.onDark ? "#f3ecdc" : "#2a2622"; font.family: Theme.fontMono; font.pixelSize: 10; opacity: 0.85 }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: 16
                        Rectangle {
                            Layout.fillWidth: true; height: 22; radius: 3
                            color: Theme.ansi[index] || "magenta"
                            border.width: 1; border.color: Theme.hairline
                            readonly property bool onDark: { const q = Qt.color(Theme.ansi[index] || "#000"); return (0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b) < 0.45 }
                            InkText { anchors.centerIn: parent; role: "small"; text: index; font.family: Theme.fontMono; font.pixelSize: 10
                                color: parent.onDark ? "#f3ecdc" : "#2a2622"; opacity: 0.9 }
                        }
                    }
                }
            }
        }
    }
}
