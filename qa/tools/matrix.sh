#!/usr/bin/env bash
# qa/tools/matrix.sh <night|day> [surface…] — open each surface through IPC, capture via dev-shot, close it.
# Requires the theme ON. Never touches power, Wi-Fi or media.
cd "$(dirname "$(realpath "$0")")/../.." || exit 1
source scripts/dev-env.sh
mode="${1:?night|day}"; shift
ipc() { timeout 5 qs -c overworld ipc call "$@"; }
shot() { DEVSHOT_SETTLE="${SETTLE:-0.7}" scripts/dev-shot.sh "qa/screenshots/qa-$1-$mode.png" >/dev/null || echo "SHOT FAILED $1"; }
want() { [[ ${#only[@]} -eq 0 ]] && return 0; local x; for x in "${only[@]}"; do [[ $x == "$1" ]] && return 0; done; return 1; }
only=("$@")
want launcher && { ipc launcher open; sleep .5; shot 02-launcher; ipc launcher search kit; sleep .4; shot 03-launcher-search; ipc launcher search '=2+3*7'; sleep .4; shot 03b-launcher-calc; ipc launcher search '>echo hi'; sleep .4; shot 03c-launcher-run; ipc launcher close; sleep .3; }
want network && { ipc network open; sleep 1.5; shot 04-network; ipc network close; sleep .3; }
want power && { ipc power open; sleep .5; shot 05-power; ipc power close; sleep .3; }
want wallpapers && { ipc wallpapers open; sleep 1; shot 06-wallpapers; ipc wallpapers close; sleep .3; }
want notif && { ipc notifications test "Advancement style" "A normal notification body that is long enough to wrap onto a second line." normal; sleep .1; ipc notifications test "Urgent thing" "Critical body text" critical; sleep .1; ipc notifications test "Low thing" "Low urgency" low; sleep 1.2; SETTLE=0.1 shot 07-toasts; ipc notifications open; sleep .5; shot 08-notifcenter; ipc notifications close; sleep .3; }
want osd && { ipc osd volume; sleep .3; SETTLE=0.2 shot 09-osd-volume; sleep 2.5; ipc osd brightness; sleep .3; SETTLE=0.2 shot 10-osd-brightness; sleep 2; }
want title && { ipc workspace reveal 3; sleep .9; SETTLE=0.1 shot 11-title; ipc workspace hide; sleep .3; }
want brew && { ipc brew open; sleep .5; shot 12-brew; ipc shell closeAll; sleep .3; }
want widgetsmenu && { ipc widgets menu; sleep .5; shot 13-widgetsmenu; ipc widgets menu; sleep .3; }
want chat && { ipc chat say "§eQA line one: system message"; ipc chat open; sleep .5; shot 14-chat; ipc chat close; sleep .3; }
want adv && { ipc advancements open; sleep .8; shot 15-advancements; ipc advancements close; sleep .3; }
want stats && { ipc stats open; sleep .6; shot 16-stats; ipc stats tab items 2>/dev/null; sleep .3; shot 16b-stats-tab2; ipc stats close; sleep .3; }
want options && { ipc options open; sleep .6; shot 17-options; for p in video sounds controls; do ipc options page $p; sleep .4; shot 17-options-$p; done; ipc options close; sleep .3; }
want switcher && { ipc gamemode switcher; sleep .5; SETTLE=0.1 shot 18-gamemode-switcher; ipc gamemode switcher; sleep .5; ipc shell closeAll; sleep .3; }
want f3 && { ipc world f3 on; sleep 4; shot 19-f3; ipc world f3graph on; sleep 2; shot 19b-f3graph; ipc world f3graph off; ipc world f3 off; sleep .3; }
want weather && { ipc world weather rain; sleep 2; shot 20-rain; ipc world weather snow; sleep 2; shot 21-snow; ipc world weather thunder; sleep 1; ipc world strike hold; sleep .3; SETTLE=0.1 shot 22-thunder-flash; ipc world strike release; ipc world weather auto; sleep .5; }
want death && { ipc interact death; sleep 1.5; shot 23-death; ipc interact respawn; sleep .6; }
exit 0
