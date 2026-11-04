//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Interact

/*  Interactions preview — the real Interactions module on its own, on top of the running desktop:
 *      source scripts/dev-env.sh
 *      OW_PREVIEW=1 OW_CONFIG=/tmp/ow-fxi/config.json OW_EVENTS_DIR=/tmp/ow-fxi/overworld OW_SOUND_DRYRUN=1 OW_INTERACT_DRYRUN=1 \
 *          qs -p quickshell/Interact/preview
 *  IPC: qs -p quickshell/Interact/preview ipc call interact <fn>   (see docs/INTERACTIONS.md for the test recipes)
 *  OW_FAKE_STATS='{"battery":4,"charging":false,"uptime":3.5}' drives the death screen; OW_PREVIEW=1 stops the config writes and
 *  the keyboard grab; OW_EVENTS_DIR keeps the fake events off the real bus.
 */
ShellRoot {
    Interactions {}
}
