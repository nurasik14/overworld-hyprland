#!/usr/bin/env bash
# apps/test/sandbox.sh — build a throw-away copy of the user's app configs under /tmp/ow-apps-sandbox so that
# apps/install.sh / apply-mode.sh / uninstall.sh can be exercised WITHOUT touching the live desktop.
#   source it:   source apps/test/sandbox.sh     (sets HOME, XDG_CONFIG_HOME, PATH shims; prints the sandbox dir)
# gsettings / hyprctl / pkill / kitty / spicetify are shimmed (gsettings keeps its values in $SB/gsettings.db and is
# seeded from the real values; the others only log to $SB/shim.log), so nothing leaves the sandbox.
SB=/tmp/ow-apps-sandbox
REAL_HOME="${OW_REAL_HOME:-$HOME}"; REAL_CFG="$REAL_HOME/.config"
# OW_SANDBOX_KEEP=1 re-enters an existing sandbox (every shell call is a new process, so env must be re-exported)
if [[ "${OW_SANDBOX_KEEP:-0}" == 1 && -d "$SB/home" ]]; then
  export HOME="$SB/home" XDG_CONFIG_HOME="$SB/home/.config" PATH="$SB/bin:$PATH" OW_SANDBOX=1
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"; echo "sandbox (kept): $SB"; return 0 2>/dev/null || exit 0
fi
rm -rf "$SB"; mkdir -p "$SB/home/.config" "$SB/home/.local/share" "$SB/bin"
for d in kitty fastfetch rofi gtk-3.0 gtk-4.0 xsettingsd qt6ct Kvantum superfile cava btop starship swappy wlogout apothecary; do
  [[ -e "$REAL_CFG/$d" ]] && cp -a "$REAL_CFG/$d" "$SB/home/.config/$d"
done
cp -a "$REAL_CFG/starship.toml" "$SB/home/.config/starship.toml" 2>/dev/null || true
# zen: only the profile's chrome dir + user.js
for p in "$REAL_CFG"/zen/*Default*; do
  [[ -d "$p" ]] || continue; b="$(basename "$p")"; mkdir -p "$SB/home/.config/zen/$b"
  cp -a "$p/chrome" "$SB/home/.config/zen/$b/" 2>/dev/null || true; cp -a "$p/user.js" "$SB/home/.config/zen/$b/" 2>/dev/null || true
done
mkdir -p "$SB/home/.local/share/icons" && ln -s "$REAL_HOME/.local/share/icons/Overworld" "$SB/home/.local/share/icons/Overworld" 2>/dev/null || true
mkdir -p "$SB/home/.themes"; ln -s "$REAL_HOME/.themes/"* "$SB/home/.themes/" 2>/dev/null || true
# retarget absolute symlinks that point into the real ~/.config to the sandbox copy
while IFS= read -r l; do
  t="$(readlink "$l")"
  [[ "$t" == "$REAL_CFG"/* ]] && ln -sfn "$SB/home/.config/${t#"$REAL_CFG"/}" "$l"
done < <(find "$SB/home/.config" -type l)
# shims
for k in org.gnome.desktop.interface:gtk-theme org.gnome.desktop.interface:icon-theme org.gnome.desktop.interface:cursor-theme \
         org.gnome.desktop.interface:font-name org.gnome.desktop.interface:color-scheme; do
  printf '%s=%s\n' "$k" "$(/usr/bin/gsettings get "${k%%:*}" "${k##*:}")"
done > "$SB/gsettings.db"
cat > "$SB/bin/gsettings" <<'SH'
#!/usr/bin/env bash
db=/tmp/ow-apps-sandbox/gsettings.db
case "$1" in
  get) grep -m1 "^$2:$3=" "$db" | cut -d= -f2- ;;
  set) grep -v "^$2:$3=" "$db" > "$db.n" || true; printf '%s:%s=%s\n' "$2" "$3" "$4" >> "$db.n"; mv "$db.n" "$db" ;;
esac
SH
for c in hyprctl pkill kitty spicetify; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> /tmp/ow-apps-sandbox/shim.log\n' "$c" > "$SB/bin/$c"
done
rm -f "$SB/bin/spicetify"   # spicetify is not installed on the real machine either
chmod +x "$SB/bin/"*
export HOME="$SB/home" XDG_CONFIG_HOME="$SB/home/.config" PATH="$SB/bin:$PATH" OW_SANDBOX=1
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
echo "sandbox: $SB (HOME=$HOME)"
