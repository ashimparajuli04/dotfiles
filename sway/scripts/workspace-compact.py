#!/usr/bin/env python3
"""Keep sway workspace numbers contiguous (1..N).

Sway destroys an empty workspace as soon as it loses focus, but it never
renumbers the survivors: close the window(s) on workspace 1, leave it, and
you are left on "2" — pressing Mod+1 then creates a brand-new workspace
instead of focusing the one you already have. This helper listens to sway
events and renames the remaining numeric workspaces to 1..N so Mod+<n>,
the 3-finger swipes (gesture-workspace.py) and the waybar dots all stay
contiguous.

Started from sway/config with `exec --no-startup-id`; the flock guard makes
re-running that exec line on `swaymsg reload` a no-op.
"""

import fcntl
import json
import os
import re
import select
import subprocess
import time

LOG = "/tmp/opencode/sway-workspace-compact.log"
LOCK = "/tmp/opencode/sway-workspace-compact.lock"
DEBOUNCE = 0.15  # seconds to coalesce a burst of events into one pass


def log(msg):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))
    except OSError:
        pass


def swaymsg(*args):
    return subprocess.run(["swaymsg", *args], capture_output=True, text=True)


def get_workspaces():
    try:
        return json.loads(swaymsg("-t", "get_workspaces").stdout)
    except ValueError:
        return []


def compact():
    """Rename numeric workspaces so their numbers run 1..N in order."""
    workspaces = [w for w in get_workspaces() if re.fullmatch(r"\d+", w.get("name", ""))]
    workspaces.sort(key=lambda w: w["num"])
    taken = {w["name"] for w in workspaces}
    for desired, w in enumerate(workspaces, start=1):
        target = str(desired)
        if w["name"] == target or target in taken:
            continue  # already in place, or target is a live workspace
        r = swaymsg("rename", "workspace", w["name"], "to", target)
        if r.returncode != 0:
            log("rename %s -> %s failed: %s" % (w["name"], target, r.stderr.strip()))
            continue
        log("renamed %s -> %s" % (w["name"], target))
        taken.discard(w["name"])
        taken.add(target)


def main():
    lockf = open(LOCK, "w")
    try:
        fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return  # another instance is already running
    lockf.write(str(os.getpid()))
    lockf.flush()

    compact()  # normalise any gap that already exists at startup

    proc = subprocess.Popen(
        ["swaymsg", "-t", "subscribe", "-m", '["workspace","window"]'],
        stdout=subprocess.PIPE, text=True,
    )
    log("started (pid %d)" % os.getpid())
    fd = proc.stdout.fileno()
    deadline = None
    while True:
        timeout = None if deadline is None else max(0.0, deadline - time.monotonic())
        ready, _, _ = select.select([fd], [], [], timeout)
        if ready:
            if proc.stdout.readline() == "":
                log("subscribe stream ended")
                break
            deadline = time.monotonic() + DEBOUNCE  # reset the quiet timer
        elif deadline is not None:
            compact()
            deadline = None


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        log(traceback.format_exc())
        raise
