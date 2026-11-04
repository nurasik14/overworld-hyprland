pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  Theme — the Overworld design-token singleton.
 *
 *  import qs.Common            (when the config root is <repo>/quickshell)
 *  import "../" as Common      (relative, used by Common/preview/shell.qml)
 *
 *  Theme.mode            "light" | "dark"   (watched from ~/.config/overworld/mode)
 *  Theme.c               raw colour object of the current mode (every role in tokens.json)
 *  Theme.bg0 … Theme.seal typed colours that cross-fade (500 ms OutCubic) on mode change
 *  Theme.radius / space / border / sizes / type / motion / opacity   shared tokens
 *  Theme.fontFor("title") -> { family, pixelSize, weight }
 *  Theme.texture("paper-tile") -> file:// url of a generated texture (mode-aware aliases: "ground-tile")
 *  Theme.setMode("dark")  writes the mode (via `overworld dark` when the CLI exists, else the file)
 */
Singleton {
    id: root

    // ------------------------------------------------------------ locations
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.config/overworld"
    readonly property string modePath: stateDir + "/mode"

    // Repo root candidates, tried in order until tokens.json loads:
    //   shellDir/..            config root is <repo>/quickshell (qs -c overworld with a real dir or a resolved symlink)
    //   shellDir/../../..      config root is <repo>/quickshell/Common/preview
    //   $OVERWORLD_DIR        explicit override
    //   ~/.config/overworld/repo   symlink that scripts/install.sh may create
    //   ~/Projects/overworld-hyprland   this machine's checkout
    readonly property var repoCandidates: [
        Quickshell.shellDir + "/..",
        Quickshell.shellDir + "/../../..",
        Quickshell.env("OVERWORLD_DIR") || "",
        stateDir + "/repo",
        home + "/Projects/overworld-hyprland"
    ].filter(p => p !== "")
    property int repoIndex: 0
    readonly property string repoDir: repoCandidates[Math.min(repoIndex, repoCandidates.length - 1)]
    readonly property string assetsDir: repoDir + "/assets"
    property bool ready: false

    // ------------------------------------------------------------ tokens.json
    property var tokens: ({})
    FileView {
        id: tokensFile
        path: root.repoDir + "/tokens/tokens.json"
        blockLoading: true          // first read is synchronous: palette is right before the first frame
        watchChanges: true          // live-edit tokens.json while developing
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseTokens(text())
    }
    function parseTokens(t) {
        if (!t || !t.length) return false;
        try {
            root.tokens = JSON.parse(t);
            root.ready = true;
            return true;
        } catch (e) {
            console.error("Theme: tokens.json parse error:", e);
            return false;
        }
    }
    Component.onCompleted: {
        // Resolve the repo synchronously by trying each candidate (blocking reads, ~µs each).
        for (let i = 0; i < repoCandidates.length; i++) {
            root.repoIndex = i;
            if (parseTokens(tokensFile.text())) break;
        }
        if (!root.ready) console.error("Theme: tokens.json not found; tried", JSON.stringify(repoCandidates));
        applyModeText(modeFile.text());
    }

    // ------------------------------------------------------------ mode file
    property string mode: "light"
    readonly property bool isDark: mode === "dark"
    FileView {
        id: modeFile
        path: root.modePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.applyModeText(text())
        onFileChanged: reload()
        onLoadFailed: error => { modePoll.running = true }   // file missing: poll until it appears
    }
    Timer {
        id: modePoll
        interval: 2000; repeat: true; running: false
        onTriggered: modeFile.reload()
    }
    function applyModeText(t) {
        const m = (t || "").trim();
        if (m === "dark" || m === "light") {
            root.mode = m;
            modePoll.running = false;
        }
    }
    Process {
        id: modeWriter
        property string wanted: "light"
        command: ["sh", "-c",
            "m=\"$1\"; if command -v overworld >/dev/null 2>&1; then overworld \"$m\"; " +
            "else mkdir -p \"$HOME/.config/overworld\" && printf '%s' \"$m\" > \"$HOME/.config/overworld/mode\"; fi",
            "overworld-mode", wanted]
    }
    function setMode(m) {
        if (m !== "light" && m !== "dark") return;
        root.mode = m;                 // optimistic: cross-fade immediately
        modeWriter.wanted = m;
        modeWriter.running = true;
    }
    function toggleMode() { setMode(isDark ? "light" : "dark") }

    // ------------------------------------------------------------ shared tokens
    readonly property var shared: tokens.shared || ({})
    readonly property var radius: shared.radius || ({ xs: 3, sm: 6, md: 8, lg: 12, pill: 999 })
    readonly property var space: shared.space || ({ xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, gutter: 16, margin: 24 })
    readonly property var border: shared.border || ({ hairline: 1, frame: 2, focus: 1 })
    readonly property var sizes: shared.sizes || ({})
    readonly property var type: shared.type || ({ families: {}, roles: {} })
    readonly property var motion: shared.motion || ({ duration: { fast: 160, base: 350, slow: 600, theme_fade: 500, stagger: 40 } })
    readonly property var opacity: shared.opacity || ({})
    readonly property var shadowSpec: shared.shadow || ({})

    readonly property int durFast: motion.duration ? motion.duration.fast : 160
    readonly property int durBase: motion.duration ? motion.duration.base : 350
    readonly property int durSlow: motion.duration ? motion.duration.slow : 600
    readonly property int durTheme: motion.duration ? motion.duration.theme_fade : 500
    readonly property int stagger: motion.duration ? motion.duration.stagger : 40
    // QML easing equivalents of the Hyprland beziers (see tokens.shared.motion.easing)
    readonly property int easeInk: Easing.OutQuint
    readonly property int easeBrush: Easing.InOutCubic
    readonly property int easeDrift: Easing.OutCubic

    // Font families (by role name in tokens.shared.type.families)
    readonly property var families: type.families || ({})
    readonly property string fontDisplay: families.display_cjk || "Ma Shan Zheng"
    readonly property string fontTitle: families.title || "ZCOOL XiaoWei"
    readonly property string fontBody: families.body_cjk || "LXGW WenKai"
    readonly property string fontSerif: families.serif_latin_display || "Cormorant Garamond"
    readonly property string fontSerifBody: families.serif_latin_body || "EB Garamond"
    readonly property string fontUi: families.ui || "Noto Sans"
    readonly property string fontMono: families.mono || "JetBrainsMono Nerd Font"
    readonly property string fontJp: families.jp_brush || "Yuji Syuku"

    function fontFor(role) {
        const r = (type.roles || {})[role] || { family: fontUi, size: 13, weight: 400 };
        return { family: r.family, pixelSize: r.size, weight: r.weight || 400, italic: !!r.italic, letterSpacing: r.letter_spacing || 0 };
    }
    // Ma Shan Zheng / ZCOOL XiaoWei cover Simplified Chinese only; Japanese-only glyphs (薬, kana) need the JP brush.
    function brushFamilyFor(text) {
        return /[\u3040-\u30ff\u85ac\u5bae]/.test(text) ? fontJp : fontDisplay;
    }

    // ------------------------------------------------------------ colours
    readonly property var modes: tokens.modes || ({})
    readonly property var c: modes[mode] || modes.light || ({})
    // tokens.json uses CSS-style #rrggbbaa; Qt parses 8-digit strings as #aarrggbb, so swap when needed.
    function qtColor(v) {
        if (typeof v === "string" && v.length === 9 && v[0] === "#") return "#" + v.substr(7, 2) + v.substr(1, 6);
        return v;
    }
    function col(role, fallback) { const v = c[role]; return qtColor(v !== undefined ? v : (fallback || "#ff00ff")); }
    function withAlpha(colour, a) { const q = Qt.color(colour); return Qt.rgba(q.r, q.g, q.b, a); }

    property color bg0:           col("bg0", "#e6dcc6")
    property color bg1:           col("bg1", "#efe6d2")
    property color bg2:           col("bg2", "#f3ecdc")
    property color surface:       col("surface", "#f3ecdc")
    property color surfaceAlt:    col("surfaceAlt", "#e9dfc9")
    property color frame:         col("frame", "#2a2622")
    property color hairline:      col("hairline", "#b8ab92")
    property color titlebar:      col("titlebar", "#2a2622")
    property color titlebarText:  col("titlebarText", "#f3ecdc")
    property color text:          col("text", "#2a2622")
    property color textMuted:     col("textMuted", "#5c554b")
    property color textOnAccent:  col("textOnAccent", "#f6f0e2")
    property color textOnSeal:    col("textOnSeal", "#fbf7ee")
    property color accent:        col("accent", "#376a4e")
    property color accentSoft:    col("accentSoft", "#7eba8f")
    property color accent2:       col("accent2", "#7a5c2b")
    property color gold:          col("gold", "#b08d57")
    property color seal:          col("seal", "#b02f2a")
    property color success:       col("success", "#4f6538")
    property color herb:          col("herb", "#7a8c5a")
    property color warning:       col("warning", "#80540e")
    property color error:         col("error", "#b02f2a")
    property color info:          col("info", "#8e4a5c")
    property color plum:          col("plum", "#8e4a5c")
    property color jade:          col("jade", "#2f6a5e")
    property color indigo:        col("indigo", "#3a6480")
    property color wood:          col("wood", "#d8c6a4")
    property color woodDark:      col("woodDark", "#8b6b45")
    property color shadow:        col("shadow", "#2a262238")
    property color shadowStrong:  col("shadowStrong", "#2a26224d")
    property color overlay:       col("overlay", "#2a262259")
    property color inkWash:       col("inkWash", "#2a262214")
    property color inkWashStrong: col("inkWashStrong", "#2a262229")
    property color sealWash:      col("sealWash", "#b02f2a1f")
    property color selection:     col("selection", "#376a4e33")
    property color cursor:        col("cursor", "#b02f2a")
    property color link:          col("link", "#3a6480")
    property color focusRing:     col("focusRing", "#b02f2a")
    readonly property var ansi:   c.ansi || []
    readonly property var ink:    c.ink || []
    readonly property var paper:  c.paper || []

    // Every typed colour cross-fades on mode change (brief: ≤ 600 ms, no bounce)
    Behavior on bg0 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on bg1 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on bg2 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on surface { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on surfaceAlt { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on frame { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on hairline { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on titlebar { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on titlebarText { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on text { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on textMuted { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on textOnAccent { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on textOnSeal { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on accentSoft { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on accent2 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on gold { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on seal { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on success { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on herb { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on warning { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on error { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on info { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on plum { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on jade { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on indigo { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on wood { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on woodDark { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on shadow { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on shadowStrong { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on overlay { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on inkWash { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on inkWashStrong { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on sealWash { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on selection { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on cursor { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on link { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on focusRing { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }

    // ------------------------------------------------------------ textures
    readonly property real textureOpacity: (opacity.texture_overlay || {})[mode] !== undefined ? opacity.texture_overlay[mode] : (isDark ? 0.5 : 0.6)
    // Fill alpha of every PaperPanel (cards, panels): slightly see-through paper/lacquer (user request).
    readonly property real surfaceOpacity: opacity.surface !== undefined ? opacity.surface : 0.88
    readonly property real cardTransparentOpacity: opacity.card_transparent !== undefined ? opacity.card_transparent : 0.82
    // name: paper | paper-tile | paper-grain | lacquer | lacquer-tile | lacquer-grain | ink-edge-mask | ink-divider | ink-divider-light | enso | enso-light
    //       ground | ground-tile | ground-grain  (mode aware: paper in light, lacquer in dark)
    //       divider | enso-ink                    (mode aware: black on paper, cream on lacquer)
    function texture(name) {
        const alias = {
            "ground": isDark ? "lacquer" : "paper",
            "ground-tile": isDark ? "lacquer-tile" : "paper-tile",
            "ground-grain": isDark ? "lacquer-grain" : "paper-grain",
            "divider": isDark ? "ink-divider-light" : "ink-divider",
            "enso-ink": isDark ? "enso-light" : "enso"
        };
        return "file://" + assetsDir + "/pd/textures/" + (alias[name] || name) + ".png";
    }
    function sealImage(glyph) { return "file://" + assetsDir + "/pd/seals/seal-" + glyph + ".png"; }
}
