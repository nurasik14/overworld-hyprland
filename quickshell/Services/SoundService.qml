pragma Singleton
import QtQuick
import Quickshell
import qs.Common

/*  SoundService — plays assets/sounds/<name>.wav through pw-play, detached (never blocks the UI).
 *  Honours config.json → {"sounds": false}.  Names: login notify notify-urgent brew-done seal
 */
Singleton {
    id: root
    readonly property string dir: Theme.assetsDir + "/sounds"
    readonly property bool enabled: ConfigService.sounds

    function play(name) {
        if (!enabled) return false;
        const p = dir + "/" + name + ".wav";
        Quickshell.execDetached(["pw-play", p]);
        return true;
    }
}
