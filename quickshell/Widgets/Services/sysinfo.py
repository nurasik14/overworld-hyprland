#!/usr/bin/env python3
"""sysinfo.py — fastfetch-style facts for the SysInfo card.  Prints one JSON object.

  sysinfo.py static    → os, kernel, shell, wm, terminal, packages   (packages cached 10 min in ~/.cache/overworld/packages)
  sysinfo.py dynamic   → cpu (%), ram (%), ramUsed/ramTotal (GiB), disk (%), diskMount, uptime ("3h 12m")
"""
import json
import os
import shutil
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
CACHE_DIR = os.path.join(HOME, ".cache", "overworld")
PKG_CACHE = os.path.join(CACHE_DIR, "packages")


def run(cmd, timeout=8):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def os_name():
    try:
        with open("/etc/os-release", encoding="utf-8") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return os.uname().sysname


def packages():
    try:
        if time.time() - os.path.getmtime(PKG_CACHE) < 600:
            with open(PKG_CACHE, encoding="utf-8") as f:
                return f.read().strip()
    except OSError:
        pass
    parts = []
    if shutil.which("rpm"):
        n = run(["sh", "-c", "rpm -qa | wc -l"])
        if n.isdigit():
            parts.append(n + " (rpm)")
    elif shutil.which("pacman"):
        n = run(["sh", "-c", "pacman -Qq | wc -l"])
        if n.isdigit():
            parts.append(n + " (pacman)")
    elif shutil.which("dpkg-query"):
        n = run(["sh", "-c", "dpkg-query -f '.\\n' -W | wc -l"])
        if n.isdigit():
            parts.append(n + " (dpkg)")
    if shutil.which("flatpak"):
        n = run(["sh", "-c", "flatpak list --app 2>/dev/null | wc -l"])
        if n.isdigit() and n != "0":
            parts.append(n + " (flatpak)")
    text = ", ".join(parts) or "—"
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(PKG_CACHE, "w", encoding="utf-8") as f:
            f.write(text)
    except OSError:
        pass
    return text


def static():
    wm = "Hyprland"
    v = run(["hyprctl", "version", "-j"])
    try:
        ver = json.loads(v).get("version") or json.loads(v).get("tag") or ""
        if ver:
            wm = "Hyprland " + ver.lstrip("v")
    except ValueError:
        pass
    return {
        "os": os_name(),
        "kernel": os.uname().release,
        "shell": os.path.basename(os.environ.get("SHELL") or "sh"),
        "wm": wm,
        "terminal": "kitty",
        "packages": packages(),
        "host": os.uname().nodename,
        "user": os.environ.get("USER") or "",
    }


def cpu_times():
    with open("/proc/stat") as f:
        parts = f.readline().split()[1:]
    vals = list(map(int, parts))
    idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
    return idle, sum(vals)


def dynamic():
    i1, t1 = cpu_times()
    time.sleep(0.35)
    i2, t2 = cpu_times()
    dt = max(1, t2 - t1)
    cpu = round(100.0 * (1.0 - (i2 - i1) / dt), 1)

    mem = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, v = line.split(":", 1)
            mem[k] = int(v.strip().split()[0])
    total = mem.get("MemTotal", 1)
    avail = mem.get("MemAvailable", 0)
    used = total - avail

    mount = "/home" if os.path.ismount("/home") else "/"
    du = shutil.disk_usage(mount)

    with open("/proc/uptime") as f:
        up = float(f.read().split()[0])
    d, rem = divmod(int(up), 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    uptime = (f"{d}d " if d else "") + (f"{h}h " if (h or d) else "") + f"{m}m"

    return {
        "cpu": cpu,
        "ram": round(100.0 * used / total, 1),
        "ramUsed": round(used / 1048576, 1),
        "ramTotal": round(total / 1048576, 1),
        "disk": round(100.0 * du.used / du.total, 1),
        "diskUsed": round(du.used / 1073741824),
        "diskTotal": round(du.total / 1073741824),
        "diskMount": mount,
        "uptime": uptime.strip(),
    }


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "dynamic"
    print(json.dumps(static() if mode == "static" else dynamic()))
