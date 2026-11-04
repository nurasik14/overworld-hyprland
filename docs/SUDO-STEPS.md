# Steps that need sudo (user runs these)

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (the stock desktop returns in about 5 s, no logout); `overworld status` shows which state is active.
> The SDDM login theme below is installed separately and is not affected by on/off; it has its own `revert`. How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

```
sudo dnf install -y kvantum papirus-icon-theme google-noto-serif-cjk-fonts
```

## SDDM login theme (hyprland-engineer)

Preview first (no sudo):
`scripts/install-sddm.sh prepare light && sddm-greeter-qt6 --test-mode --theme ~/Projects/overworld-hyprland/sddm/overworld`

```
sudo ~/Projects/overworld-hyprland/scripts/install-sddm.sh light     # or: dark
```

Copies the theme (fonts + Maomao backgrounds baked in) to `/usr/share/sddm/themes/overworld`, backs up
`/etc/sddm.conf` to `/etc/sddm.conf.pre-overworld` and sets `[Theme] Current=overworld`.
Revert: `sudo ~/Projects/overworld-hyprland/scripts/install-sddm.sh revert` (the silent theme comes back).

## Screen brightness (Acer Nitro AN515-58, hybrid Intel + NVIDIA)

Symptom: the brightness keys show the OSD, but the screen does not change. In hybrid mode the panel (eDP-1) is
driven by the Intel iGPU, so the backlight that works is `intel_backlight`. Two things got in the way:

1. **Kernel parameter.** `acpi_backlight=vendor` makes i915 skip `intel_backlight` ("Skipping intel_backlight
   registration" in `journalctl -k`). With no parameter, the kernel may pick `nvidia_wmi_ec_backlight` instead: its
   value moves, but the screen does not. Fix (done on this machine):

   ```
   sudo grubby --update-kernel=ALL --remove-args="acpi_backlight=vendor" --args="acpi_backlight=native"
   # reboot, then check:  ls /sys/class/backlight   ->  intel_backlight  nvidia_0
   ```

2. **Two backlights after the reboot.** `nvidia_0` (the dGPU's unused output) sorts before `intel_backlight`, so plain
   `brightnessctl` drives the wrong one. No sudo needed: `scripts/backlight-dev.sh` prints the backlight whose display
   is connected, and every caller passes it with `-d`:
   - `hypr/hypridle.conf`: dim to 30 % after 5 min idle, restore on activity
   - `quickshell/Services/AudioService.qml`: the brightness OSD
   - JaKooLit's `~/.config/hypr/scripts/Brightness.sh`: the brightness keys. This file is outside the repo and was
     patched by hand; a `.bak` sits next to it.

   Check: `scripts/backlight-dev.sh` prints `intel_backlight`.

If you ever switch the MUX to discrete-only in the BIOS and brightness stops working again, use
`acpi_backlight=nvidia_wmi_ec` instead: `sudo grubby --update-kernel=ALL --args="acpi_backlight=nvidia_wmi_ec"`.
Undo: `sudo grubby --update-kernel=ALL --args="acpi_backlight=vendor"`.
