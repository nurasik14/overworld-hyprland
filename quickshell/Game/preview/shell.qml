//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Game

/*  Game module preview (runs on top of the live desktop; never grabs the keyboard when OW_NOFOCUS=1):
 *      source scripts/dev-env.sh
 *      OW_STATE_DIR=/tmp/ow-feat-state OW_GAME_DRYRUN=1 OW_NOFOCUS=1 OW_BRIDGE=0 OW_SOUND_DRYRUN=1 OW_QS_ARGS="-p …/Game/preview" \
 *          qs -p quickshell/Game/preview
 *      qs -p quickshell/Game/preview ipc call chat open        (and `advancements open`, `stats open`, `options open`, `gamemode switcher`)
 *  OW_SELFTEST=1 (with OW_STATE_DIR) runs the logic checks in SelfTest.qml and prints SELFTEST PASS/FAIL lines.
 */
ShellRoot {
    GameSystems {}
    Loader { active: Quickshell.env("OW_SELFTEST") === "1"; source: "SelfTest.qml" }
}
