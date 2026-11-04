#!/usr/bin/env bash
# apps/test/snapshot.sh <outfile> — fingerprint everything apps/*.sh may touch under $XDG_CONFIG_HOME (sandbox or live):
# symlink targets, file hashes, key lines, gsettings. Diff two snapshots to prove a round trip restored everything.
out="${1:?usage: snapshot.sh <outfile>}"; CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
{
  for f in kitty/kitty.conf rofi/config.rasi gtk-3.0/gtk.css gtk-4.0/gtk.css xsettingsd/xsettingsd.conf qt6ct/qt6ct.conf Kvantum/kvantum.kvconfig \
           superfile/config.toml cava/config btop/btop.conf starship.toml swappy/config wlogout/style.css wlogout/layout fastfetch/config.jsonc; do
    p="$CFG/$f"
    if [[ -L "$p" ]]; then echo "LINK $f -> $(readlink "$p")  [$(readlink -f "$p" | sed "s|$CFG||")] $(sha1sum < "$p" 2>/dev/null | cut -c1-12)"
    elif [[ -f "$p" ]]; then echo "FILE $f $(sha1sum < "$p" | cut -c1-12)"
    else echo "NONE $f"; fi
  done
  for p in "$CFG"/zen/*Default*/chrome/user*.css "$CFG"/zen/*Default*/user.js; do [[ -e "$p" ]] && echo "ZEN ${p#"$CFG"/} $(sha1sum < "$p" | cut -c1-12)"; done
  for k in gtk-theme icon-theme cursor-theme font-name color-scheme; do echo "GS $k $(gsettings get org.gnome.desktop.interface $k)"; done
  ls "$CFG/apothecary/" 2>/dev/null | head -0
} > "$out"
