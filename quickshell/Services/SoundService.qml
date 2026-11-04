pragma Singleton
import QtQuick
import Quickshell
import qs.Common

/*  SoundService — the one QML entry for sounds; every id goes through scripts/ow-sound (BRIEF §4.5, tokens/sounds.json).
 *    SoundService.play("ui.click")     honours config.json sounds + sound_volume.*, and OW_SOUND_DRYRUN=1
 *  Apothecary's names still work: login, notify, notify-urgent, brew-done, seal, click.
 */
Singleton {
    id: root
    readonly property bool enabled: ConfigService.sounds
    readonly property var legacy: ({
        "login": "door.open",
        "notify": "notify",
        "notify-urgent": "notify.urgent",
        "brew-done": "brew.done",
        "seal": "ui.click",
        "click": "ui.click"
    })

    function resolve(name) { return legacy[name] || name; }
    function play(name) {
        if (!name) return false;
        Theme.playSound(resolve(name));
        return enabled;
    }
}
