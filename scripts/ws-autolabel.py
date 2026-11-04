#!/usr/bin/python3
"""ws-autolabel — let Claude (your Claude plan, via the `claude` CLI) keep the titles of workspaces 1–10 current.

    ws-autolabel.py                 daemon: watch Hyprland and act when needed (started by the shell
                                    while config.json → workspace_auto.enabled is true)
    ws-autolabel.py --once [N]      one pass now: label / check every workspace (or just N), no waiting
    ws-autolabel.py --once N --force   relabel N unconditionally (also a pinned one)

What it does (a pinned entry — `overworld ws N --pin` — is never touched):
  * label:  a workspace has windows but no title → Claude writes a title + note (your note is kept if it fits)
  * check:  a titled workspace's windows changed → Claude is shown the current title + note and the windows;
            if they no longer match, both are rewritten. Checked when the app set changes, or when only window
            titles changed and the last check is older than `recheck`. A title is left alone for `cooldown`
            seconds after it was set (by you or by Claude).
  * reset:  a workspace stayed empty for `reset_after` seconds → its title + note are removed (0 = never).
With manage_manual false, titles you set yourself are skipped by check and reset (the old behaviour).
Labels it writes are stored in ~/.config/overworld/workspaces.json with "auto": true.

config.json → "workspace_auto": { "enabled": false, "model": "haiku", "send_titles": true, "settle": 20,
                                   "cooldown": 600, "recheck": 600, "reset_after": 600,
                                   "manage_manual": true, "max_per_hour": 20 }
Window classes (and titles unless send_titles is false) are sent to Claude. Calls count against your plan:
ANTHROPIC_API_KEY is removed from the child environment so the CLI uses the logged-in subscription.
Log: ~/.cache/overworld/ws-auto.log   timers: ~/.cache/overworld/ws-auto-state.json
"""
import fcntl
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "overworld"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "overworld"
WS_FILE = STATE / "workspaces.json"
LOCK_FILE = STATE / "workspaces.json.lock"
CONFIG = STATE / "config.json"
LOG = CACHE / "ws-auto.log"
STATE_FILE = CACHE / "ws-auto-state.json"     # empty-since / last-check timers (survive shell reloads)
PID_FILE = CACHE / "ws-auto.pid"

SCHEMA = json.dumps({
    "type": "object",
    "properties": {"title": {"type": "string", "maxLength": 24}, "note": {"type": "string", "maxLength": 50}},
    "required": ["title", "note"], "additionalProperties": False,
})
CHECK_SCHEMA = json.dumps({
    "type": "object",
    "properties": {"fits": {"type": "boolean"},
                   "title": {"type": "string", "maxLength": 24}, "note": {"type": "string", "maxLength": 50}},
    "required": ["fits", "title", "note"], "additionalProperties": False,
})
STYLE = ("Title: 1-3 words, max 24 characters, Title Case, no emoji, no quotes. Note: one plain line, max 50 "
         "characters, saying what is going on there. Keep it distinct from the other workspaces' titles. Never "
         "include secrets, emails, or personal names that appear in window titles.")
SYSTEM = ("You name virtual desktop workspaces for a CS student's Linux desktop. From the open windows, infer what "
          "the workspace is FOR (the activity or project), not a list of apps. " + STYLE)
CHECK_SYSTEM = ("You keep the titles of virtual desktop workspaces on a CS student's Linux desktop accurate. You get "
                "a workspace's current title and note and the windows open on it now. Decide whether the title and "
                "note still describe what the workspace is used for NOW. Evidence: window titles, and for terminals "
                "the program running, its folder and a coding-agent session title (a Hermes session title says "
                "exactly what that terminal is working on). A bare terminal with no details and a music or video "
                "tab are neutral. Return fits=false when the evidence points to a different activity than the "
                "title or note, or when nothing on the workspace supports them any more. If it fits, return "
                "fits=true with the current title and note unchanged. If not, return fits=false and a new title "
                "and note for what the windows show. " + STYLE)

DEFAULTS = {"enabled": False, "model": "haiku", "send_titles": True, "settle": 20, "cooldown": 600,
            "recheck": 600, "reset_after": 600, "manage_manual": True, "max_per_hour": 20}


def log(msg):
    CACHE.mkdir(parents=True, exist_ok=True)
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + msg
    with open(LOG, "a") as f:
        f.write(line + "\n")
    if sys.stderr.isatty():
        print(line, file=sys.stderr)


def settings():
    try:
        cfg = json.loads(CONFIG.read_text() or "{}").get("workspace_auto", {})
    except Exception:
        cfg = {}
    return {**DEFAULTS, **(cfg if isinstance(cfg, dict) else {})}


# ------------------------------------------------------------------------------------------- workspaces.json
class Notes:
    """Locked read-modify-write; `overworld ws` takes the same flock."""

    def __enter__(self):
        STATE.mkdir(parents=True, exist_ok=True)
        self.lock = open(LOCK_FILE, "a")
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        try:
            self.data = json.loads(WS_FILE.read_text() or "{}")
            if not isinstance(self.data, dict):
                raise ValueError("not an object")
            self.ok = True
        except FileNotFoundError:
            self.data, self.ok = {}, True
        except Exception as e:           # malformed: never overwrite the user's file
            log(f"workspaces.json unreadable ({e}); skipping")
            self.data, self.ok = {}, False
        self.dirty = False
        return self

    def __exit__(self, *exc):
        if self.ok and self.dirty:
            # write in place (same inode) so the shell's file watch keeps working
            with open(WS_FILE, "r+" if WS_FILE.exists() else "w") as f:
                f.seek(0)
                f.write(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n")
                f.truncate()
        fcntl.flock(self.lock, fcntl.LOCK_UN)
        self.lock.close()


def read_notes():
    with Notes() as n:
        return dict(n.data)


def entry(notes, ws):
    e = notes.get(str(ws))
    if e is None:
        return None
    return {"title": e, "note": ""} if isinstance(e, str) else e


def has_text(e):
    return bool(e and (e.get("title") or e.get("note")))


def load_state():
    try:
        st = json.loads(STATE_FILE.read_text())
    except Exception:
        st = {}
    for k in ("empty_since", "seen", "checked"):
        if not isinstance(st.get(k), dict):
            st[k] = {}
    return st


def save_state(st):
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(st, indent=1))
    os.replace(tmp, STATE_FILE)        # nothing watches this file, a rename is fine


# ------------------------------------------------------------------------------------------- Hyprland
def hypr_env():
    env = dict(os.environ)
    rt = Path(env.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    sig = env.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not sig or not (rt / "hypr" / sig / ".socket2.sock").exists():
        dirs = sorted((p for p in (rt / "hypr").glob("*") if (p / ".socket2.sock").exists()),
                      key=lambda p: p.stat().st_mtime, reverse=True)
        if not dirs:
            raise SystemExit("ws-autolabel: no running Hyprland found")
        sig = dirs[0].name
    env["HYPRLAND_INSTANCE_SIGNATURE"] = sig
    env["XDG_RUNTIME_DIR"] = str(rt)
    return env, rt / "hypr" / sig / ".socket2.sock"


HENV, SOCK2 = hypr_env()


def hyprctl_json(what):
    out = subprocess.run(["hyprctl", what, "-j"], env=HENV, capture_output=True, text=True, timeout=5).stdout
    return json.loads(out or "[]")


# ------------------------------------------------------------------------------------------- what terminals run
# A terminal's window title is often just "hermes" or "zsh". Look at its process tree instead: the programs
# started from its shell, their working directory, and for Hermes the session title from ~/.hermes/state.db.
TERMINALS = {"kitty", "foot", "alacritty", "wezterm", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "ghostty",
             "konsole", "org.gnome.console", "gnome-terminal-server", "xterm", "st"}
SHELLS = {"zsh", "bash", "fish", "sh", "dash", "nu", "kitten", "login", "sudo", "tmux: client"}
HERMES_DB = HOME / ".hermes" / "state.db"


def _procs():
    """→ {pid: (ppid, comm, start_epoch)}"""
    try:
        btime = next(int(l.split()[1]) for l in open("/proc/stat") if l.startswith("btime"))
    except Exception:
        btime = 0
    hz = os.sysconf("SC_CLK_TCK")
    out = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            raw = open(f"/proc/{d}/stat").read()
        except OSError:
            continue
        comm = raw[raw.index("(") + 1:raw.rindex(")")]
        f = raw[raw.rindex(")") + 2:].split()
        out[int(d)] = (int(f[1]), comm, btime + int(f[19]) / hz)
    return out


def _cmdline(pid):
    try:
        return open(f"/proc/{pid}/cmdline", "rb").read().replace(b"\0", b" ").decode(errors="ignore")
    except OSError:
        return ""


def _cwd(pid):
    try:
        c = os.readlink(f"/proc/{pid}/cwd")
    except OSError:
        return ""
    return "~" + c[len(str(HOME)):] if c.startswith(str(HOME)) else c


def _is_hermes(pid, comm):
    return comm == "hermes" or "hermes_cli" in _cmdline(pid)[:4000]


def programs_in(pid, procs, kids):
    """the commands started from the terminal's shell(s): [(pid, name, start)]"""
    found, todo = [], [(pid, False)]
    while todo:
        p, under_shell = todo.pop()
        for c in kids.get(p, []):
            comm = procs[c][1]
            if comm in SHELLS or comm.startswith("kitty"):
                todo.append((c, True))
            elif under_shell:
                found.append((c, "hermes" if _is_hermes(c, comm) else comm, procs[c][2]))
    return found


def hermes_sessions(hermes_procs):
    """{pid: (title, ended)} — the latest top-level local session started by each running Hermes CLI.
    Hermes does not record the pid, so a session belongs to the newest Hermes CLI started before it."""
    if not hermes_procs or not HERMES_DB.exists():
        return {}
    import sqlite3
    starts = sorted((st, pid) for pid, st in hermes_procs.items())
    try:
        db = sqlite3.connect(f"file:{HERMES_DB}?mode=ro", uri=True, timeout=2)
        rows = db.execute("SELECT title, started_at, ended_at FROM sessions WHERE started_at >= ? "
                          "AND source = 'local' AND parent_session_id IS NULL AND COALESCE(hidden, 0) = 0 "
                          "ORDER BY started_at", (starts[0][0] - 5,)).fetchall()
        db.close()
    except Exception as ex:
        log(f"hermes sessions: {ex}")
        return {}
    out = {}
    for title, started, ended in rows:
        owner = None
        for st, pid in starts:
            if st - 5 <= started:
                owner = pid
        if owner is not None and title:
            out[owner] = (title, ended is not None)
    return out


def windows_by_ws():
    clients = hyprctl_json("clients")
    procs = _procs()
    kids = {}
    for pid, (ppid, _, _) in procs.items():
        kids.setdefault(ppid, []).append(pid)
    progs = {}
    for c in clients:
        if (c.get("class") or "").lower() in TERMINALS and c.get("pid", -1) in procs:
            progs[c["pid"]] = programs_in(c["pid"], procs, kids)
    sessions = hermes_sessions({p: st for lst in progs.values() for p, name, st in lst if name == "hermes"})
    by = {}
    for c in clients:
        wid = (c.get("workspace") or {}).get("id", -1)
        if not (1 <= wid <= 10 and c.get("mapped", True)):
            continue
        details = []
        for p, name, _ in progs.get(c.get("pid"), [])[:3]:
            d = f"running {name} in {_cwd(p) or '?'}"
            if p in sessions:
                title, ended = sessions[p]
                d += f'; Hermes session {"(finished) " if ended else ""}"{title[:70]}"'
            details.append(d)
        by.setdefault(wid, []).append({"class": c.get("class") or c.get("initialClass") or "?",
                                       "title": (c.get("title") or "")[:80], "detail": "; ".join(details)})
    return by


def focused_ws():
    try:
        return hyprctl_json("activeworkspace").get("id", -1)
    except Exception:
        return -1


def signature(wins):
    return sorted({w["class"].lower() for w in wins})


def fingerprint(wins, cfg):
    """what a check looked at: classes, plus window titles when they are sent"""
    if not cfg["send_titles"]:
        return signature(wins)
    return sorted(f'{w["class"].lower()}|{w["title"]}|{w.get("detail", "")}' for w in wins)


def jaccard(a, b):
    a, b = set(a), set(b)
    return 1.0 if not a and not b else len(a & b) / len(a | b)


# ------------------------------------------------------------------------------------------- Claude
def claude_bin():
    return shutil.which("claude") or str(HOME / ".local/bin/claude")


def _others(ws, notes):
    others = []
    for k in sorted(notes, key=lambda x: int(x) if x.isdigit() else 99):
        o = entry(notes, k)
        if k != str(ws) and o and o.get("title"):
            others.append(f'{k}: {o["title"]}')
    return ("\n\nOther workspaces are titled:\n" + "\n".join(others)) if others else ""


def _windows(wins, cfg):
    return "\n".join(f'- {w["class"]}' + (f' — "{w["title"]}"' if cfg["send_titles"] and w["title"] else "") +
                     (f' ({w["detail"]})' if cfg["send_titles"] and w.get("detail") else "")
                     for w in wins)


def _claude(prompt, system, schema, cfg):
    env = {k: v for k, v in os.environ.items() if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    cmd = [claude_bin(), "-p", "--model", str(cfg["model"]), "--tools", "", "--strict-mcp-config",
           "--setting-sources", "", "--no-session-persistence", "--output-format", "json",
           "--json-schema", schema, "--system-prompt", system, prompt]
    CACHE.mkdir(parents=True, exist_ok=True)
    p = subprocess.run(cmd, cwd=CACHE, env=env, capture_output=True, text=True, timeout=90)
    if p.returncode != 0:
        raise RuntimeError(f"claude exited {p.returncode}: {(p.stderr or p.stdout).strip()[:300]}")
    d = json.loads(p.stdout)
    out = d.get("structured_output") or json.loads(d.get("result") or "{}")
    title = " ".join(str(out.get("title", "")).split())[:24].strip()
    note = " ".join(str(out.get("note", "")).split())[:50].strip()
    return out, title, note, d


def ask_claude(ws, wins, notes, cfg):
    """→ (title, note) for an untitled workspace"""
    prompt = (f"Workspace {ws} has these windows:\n" + _windows(wins, cfg) + _others(ws, notes) +
              "\n\nGive this workspace a title and a one-line note.")
    _, title, note, d = _claude(prompt, SYSTEM, SCHEMA, cfg)
    if not title:
        raise RuntimeError(f"empty title in reply: {d.get('result')!r}")
    return title, note


def check_claude(ws, wins, e, notes, cfg):
    """→ (fits, title, note): do the current title + note still match the windows?"""
    prompt = (f'Workspace {ws} is titled "{e.get("title", "")}"' +
              (f' with the note "{e["note"]}"' if e.get("note") else " (no note)") +
              ".\nIts windows now:\n" + _windows(wins, cfg) + _others(ws, notes) +
              "\n\nDo the title and note still match? If not, give a new title and note.")
    out, title, note, d = _claude(prompt, CHECK_SYSTEM, CHECK_SCHEMA, cfg)
    fits = out.get("fits") is True
    if not fits and not title:
        raise RuntimeError(f"empty title in reply: {d.get('result')!r}")
    return fits, title, note


# ------------------------------------------------------------------------------------------- the decision
class Labeller:
    def __init__(self):
        self.calls = []                  # timestamps, for max_per_hour
        self.lock = threading.Lock()

    @staticmethod
    def need(ws, wins, e, cfg, st, now, eager=False):
        """→ None | "reset" | "label: <why>" | "check: <why>"   (pure: easy to test)
        eager = a manual `--once` pass: skip the cooldown / recheck waits."""
        k = str(ws)
        if e is not None and e.get("pinned"):
            return None                                          # pinned: hands off
        if e is not None and not e.get("auto") and not cfg["manage_manual"] and has_text(e):
            return None                                          # yours, and manage_manual is off
        if not wins:
            if not has_text(e) or float(cfg["reset_after"]) <= 0:
                return None
            since = st["empty_since"].get(k, now)
            return "reset" if now - since >= float(cfg["reset_after"]) else None
        if not e or not e.get("title"):
            return "label: untitled"
        seen = st["seen"].get(k, {})
        if not eager and now - seen.get("since", now) < float(cfg["cooldown"]):
            return None                                          # set recently: give it time
        chk = st["checked"].get(k)
        if chk is None:
            return "check: not checked yet"
        if chk.get("classes") != signature(wins):
            return "check: apps changed"
        if chk.get("fp") != fingerprint(wins, cfg) and (eager or now - chk.get("at", 0) >= float(cfg["recheck"])):
            return "check: windows changed"
        return None

    def _budget(self, ws, why, cfg):
        now = time.time()
        self.calls = [t for t in self.calls if now - t < 3600]
        if len(self.calls) >= int(cfg["max_per_hour"]):
            log(f"ws {ws}: {why} — skipped, max_per_hour={cfg['max_per_hour']} reached")
            return False
        self.calls.append(now)
        return True

    def run_pass(self, only=None, force=False, eager=False):
        # serialise with the daemon / another `--once` (else both ask Claude about the same change)
        CACHE.mkdir(parents=True, exist_ok=True)
        with self.lock, open(CACHE / "ws-auto.pass.lock", "a") as pl:
            fcntl.flock(pl, fcntl.LOCK_EX)
            return self._run_pass(only, force, eager)

    def _run_pass(self, only, force, eager):
        if True:
            cfg = settings()
            by = windows_by_ws()
            notes = read_notes()
            focus = focused_ws()
            st = load_state()
            now = time.time()
            done = 0
            for ws in range(1, 11):                              # timers: keep them for all ten
                k, e = str(ws), entry(notes, ws)
                if by.get(ws):
                    st["empty_since"].pop(k, None)
                else:
                    st["empty_since"].setdefault(k, now)
                val = [e.get("title", ""), e.get("note", "")] if has_text(e) else None
                if st["seen"].get(k, {}).get("val") != val:      # new / edited text: restart its clock
                    st["seen"][k] = {"val": val, "since": now}
                    st["checked"].pop(k, None)
            for ws in ([only] if only else range(1, 11)):
                k, wins, e = str(ws), by.get(ws, []), entry(notes, ws)
                if force:
                    if not wins:
                        log(f"ws {ws}: no windows, nothing to label")
                        continue
                    why = "label: forced"
                else:
                    why = self.need(ws, wins, e, cfg, st, now, eager=eager)
                if why is None:
                    continue
                if why == "reset":
                    with Notes() as n:
                        cur = entry(n.data, ws)
                        if n.ok and cur == e and k in n.data:    # unchanged since we looked
                            del n.data[k]; n.dirty = True
                    if n.ok and cur == e:
                        mins = int((now - st["empty_since"].get(k, now)) // 60)
                        log(f"ws {ws}: empty for {mins} min → reset (was {e.get('title', '')!r} / {e.get('note', '')!r})")
                        st["seen"].pop(k, None); st["checked"].pop(k, None)
                    continue
                if not self._budget(ws, why, cfg):
                    continue
                try:
                    if why.startswith("check"):
                        fits, title, note = check_claude(ws, wins, e, notes, cfg)
                    else:
                        fits = False
                        title, note = ask_claude(ws, wins, notes, cfg)
                        if e and e.get("note") and not force:    # untitled but you wrote a note: keep it
                            note = e["note"]
                except Exception as ex:
                    log(f"ws {ws}: claude failed: {ex}")
                    continue
                checked = {"classes": signature(wins), "fp": fingerprint(wins, cfg), "at": int(now)}
                if fits:
                    st["checked"][k] = checked
                    log(f"ws {ws}: {why} → still fits {e.get('title', '')!r}")
                    continue
                with Notes() as n:
                    cur = entry(n.data, ws)
                    if not n.ok or (cur != e and not force):
                        continue                                  # edited while Claude was thinking
                    n.data[k] = {"title": title, "note": note, "auto": True}
                    n.dirty = True
                if not n.ok or (cur != e and not force):
                    log(f"ws {ws}: changed while asking Claude — left as is")
                    continue
                notes[k] = {"title": title, "note": note}
                st["seen"][k] = {"val": [title, note], "since": now}
                st["checked"][k] = checked
                done += 1
                was = f" (was {e.get('title', '')!r} / {e.get('note', '')!r})" if has_text(e) else ""
                log(f"ws {ws}: {why} → {title!r} / {note!r}{was}")
                if ws == focus:   # show the new label right away on the workspace you are looking at
                    subprocess.run(["qs", "-c", "overworld", "ipc", "call", "workspace", "reveal", str(ws)],
                                   env=HENV, capture_output=True, timeout=5)
            save_state(st)
            return done


# ------------------------------------------------------------------------------------------- daemon
WATCH = {"openwindow", "closewindow", "movewindow", "movewindowv2", "createworkspace", "destroyworkspace"}


def single_instance():
    """one watcher at a time: take over from an older one (e.g. orphaned by a shell crash)"""
    CACHE.mkdir(parents=True, exist_ok=True)
    f = open(PID_FILE, "a+")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        f.seek(0)
        old = f.read().strip()
        if old.isdigit():
            log(f"another watcher (pid {old}) is running; replacing it")
            try:
                os.kill(int(old), signal.SIGTERM)
            except ProcessLookupError:
                pass
        fcntl.flock(f, fcntl.LOCK_EX)
    f.seek(0); f.truncate(); f.write(str(os.getpid())); f.flush()
    return f                                                     # keep it open = keep the lock


def die_with_parent():
    try:                                                         # PR_SET_PDEATHSIG: exit when the shell dies
        import ctypes
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)
    except Exception:
        pass
    if os.getppid() == 1:
        log("parent already gone; exiting")
        raise SystemExit(0)


TICK = 60          # seconds: empty-reset timers and title-drift checks need no window event


def daemon():
    die_with_parent()
    _lock = single_instance()                                    # noqa: F841 (held for the process lifetime)
    lab = Labeller()
    log(f"daemon start (socket {SOCK2})")
    timer = None
    first_pending = None      # debounce, but never wait more than 3 × settle while windows keep changing
    last_event = 0.0

    def schedule():
        nonlocal timer, first_pending
        settle = float(settings()["settle"])
        now = time.time()
        if first_pending is None:
            first_pending = now
        delay = max(0.0, min(settle, first_pending + 3 * settle - now))
        if timer:
            timer.cancel()
        timer = threading.Timer(delay, safe_pass)
        timer.daemon = True
        timer.start()

    def safe_pass():
        nonlocal first_pending
        first_pending = None
        try:
            lab.run_pass()
        except Exception as ex:
            log(f"pass failed: {ex}")

    def ticker():
        while True:
            time.sleep(TICK)
            if first_pending is not None:
                continue                                         # an event pass is already on its way
            try:
                if time.time() - last_event >= float(settings()["settle"]):
                    lab.run_pass()
            except Exception as ex:
                log(f"tick failed: {ex}")

    threading.Thread(target=ticker, daemon=True).start()
    schedule()                                                     # first look after the settle delay
    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(str(SOCK2))
            buf = b""
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    raise ConnectionError("socket closed")
                buf += chunk
                *lines, buf = buf.split(b"\n")
                if any(l.split(b">>", 1)[0].decode(errors="ignore") in WATCH for l in lines):
                    last_event = time.time()
                    schedule()
        except Exception as ex:
            log(f"event socket: {ex}; retrying in 5 s")
            time.sleep(5)


def main(argv):
    if "--once" in argv:
        nums = [int(a) for a in argv if a.isdigit()]
        only = nums[0] if nums else None
        if only is not None and not 1 <= only <= 10:
            raise SystemExit("workspace must be 1–10")
        n = Labeller().run_pass(only=only, force="--force" in argv, eager=True)
        print(f"(re)labelled {n} workspace(s) — see {LOG}" if n else f"nothing needed a new label (log: {LOG})")
        return
    daemon()


if __name__ == "__main__":
    main(sys.argv[1:])
