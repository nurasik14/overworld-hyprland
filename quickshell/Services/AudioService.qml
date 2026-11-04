pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/*  AudioService — default Pipewire sink volume/mute + brightness via brightnessctl.
 *  AudioService.volume (0..1) · muted · setVolume(v) · change(±0.05) · toggleMute()
 *  AudioService.brightness (0..1) · setBrightness(v) · changeBrightness(±0.05) · refreshBrightness()
 *  signal volumeShown() / brightnessShown() fire when the OSD should appear (user-driven changes only).
 */
Singleton {
    id: root

    // ---------------------------------------------------------------- volume
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    readonly property bool ready: sink !== null && sink !== undefined && sink.ready
    readonly property real volume: (sink && sink.audio) ? Math.max(0, Math.min(1.5, sink.audio.volume)) : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    readonly property int percent: Math.round(volume * 100)

    signal volumeShown()
    signal brightnessShown()

    property bool armed: false      // ignore the initial values reported at startup
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }
    onVolumeChanged: if (armed) volumeShown()
    onMutedChanged: if (armed) volumeShown()

    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        if (sink.audio.muted && v > 0) sink.audio.muted = false;
    }
    function change(delta) { setVolume(volume + delta); }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }

    function volumeGlyph() {
        if (muted || volume <= 0.001) return "󰝟";
        if (volume < 0.34) return "󰕿";
        if (volume < 0.67) return "󰖀";
        return "󰕾";
    }

    // ---------------------------------------------------------------- brightness
    property real brightness: 0
    property bool brightnessAvailable: false
    // Use the backlight attached to a *connected* display: hybrid laptops expose several
    // (intel_backlight for eDP-1, nvidia_0 for the unused dGPU output); brightnessctl's default picks the wrong one.
    readonly property string pickBacklight: "dev=$(\"$HOME/Projects/overworld-hyprland/scripts/backlight-dev.sh\"); "
    Process {
        id: brGet
        command: ["sh", "-c", root.pickBacklight + "brightnessctl -m -d \"$dev\""]
        stdout: StdioCollector {
            onStreamFinished: {
                // intel_backlight,backlight,12345,50%,24242
                const line = (text || "").trim().split("\n")[0] || "";
                const parts = line.split(",");
                if (parts.length >= 4 && parts[1] === "backlight") {
                    const pct = parseInt(parts[3].replace("%", ""));
                    if (!isNaN(pct)) { root.brightness = pct / 100; root.brightnessAvailable = true; }
                } else {
                    root.brightnessAvailable = false;
                }
            }
        }
    }
    Process {
        id: brSet
        property string value: "50%"
        command: ["sh", "-c", root.pickBacklight + "brightnessctl -m -d \"$dev\" set \"$1\"", "sh", value]
        onExited: brGet.running = true
    }
    function refreshBrightness() { brGet.running = true; }
    function setBrightness(v) {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        root.brightness = pct / 100;
        brSet.value = pct + "%";
        brSet.running = true;
        brightnessShown();
    }
    function changeBrightness(delta) { setBrightness(brightness + delta); }
    Component.onCompleted: refreshBrightness()
}
