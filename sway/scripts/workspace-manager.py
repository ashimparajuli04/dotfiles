#!/usr/bin/env python3
"""Keep sway workspace numbers contiguous and reserve workspace 1 for the
external (non-main) display.

Supersedes workspace-compact.py. It does two related jobs:

1. Compaction. Sway destroys an empty, unfocused workspace but never
   renumbers the survivors, so closing the window(s) on workspace 1 used to
   leave you stranded on "2". We rename numeric workspaces so they run 1..N.

2. External pinning. When a display other than the bar's main display is
   connected, that external display always shows workspace 1. Existing
   workspaces shift up by one (1->2, 2->3, ...) so an empty workspace 1 can be
   slid in at the front and pinned to the external. Unplugging it collapses the
   numbers back down (2,3,4 -> 1,2,3).

The main display can still focus workspace 1; because workspace 1 lives on the
external, doing so moves keyboard focus to the external (sway keeps one
workspace per output, so this is not a true mirror).

"Main" is the output Waybar is pinned to (".local/state/newwave/
waybar-display.json"), falling back to the internal panel. Headless/virtual
outputs are never chosen as the external, so a remote-session output does not
steal workspace 1.

Started from sway/config with `exec --no-startup-id`; the flock guard keeps
`swaymsg reload` from spawning a second instance. Run `--dry-run` to print the
plan without touching anything, `--once` to reconcile and exit.
"""

import fcntl
import json
import os
import re
import select
import subprocess
import sys
import time
import traceback

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
LOG = os.path.join(RUNTIME, "sway-workspace-manager.log")
LOCK = os.path.join(RUNTIME, "sway-workspace-manager.lock")
STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "newwave", "waybar-display.json",
)
INTERNAL = "eDP-1"
NUMERIC = re.compile(r"\d+$")
TMP_PREFIX = "nw-tmp-"
DEBOUNCE = 0.2  # seconds to coalesce a burst of events into one pass

VERBOSE = False
pinned_id = None  # sway id of the workspace we pinned to the external


def log(msg):
    line = "%s %s" % (time.strftime("%H:%M:%S"), msg)
    if VERBOSE:
        print(line)
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write(line + "\n")
    except OSError:
        pass


def swaymsg(*args):
    return subprocess.run(["swaymsg", *args], capture_output=True, text=True)


def _json(args):
    try:
        return json.loads(swaymsg(*args).stdout)
    except ValueError:
        return []


def get_workspaces():
    return _json(["-t", "get_workspaces"])


def active_outputs():
    outs = [o["name"] for o in _json(["-t", "get_outputs"])
            if o.get("active") and o.get("name")]
    return sorted(outs)


def is_headless(name):
    return name.startswith("HEADLESS")


def nonempty_workspaces():
    """Names of workspaces that currently hold at least one window. The
    workspace objects from `get_workspaces` carry no children, so emptiness has
    to be derived from the full tree."""
    tree = _json(["-t", "get_tree"])
    result = set()

    def walk(node, ws):
        t = node.get("type")
        if t == "workspace":
            ws = node.get("name")
        kids = node.get("nodes", []) + node.get("floating_nodes", [])
        if t == "con" and not kids and (node.get("app_id") or node.get("window")):
            if ws:
                result.add(ws)
        for c in kids:
            walk(c, ws)

    for c in tree.get("nodes", []) + tree.get("floating_nodes", []):
        walk(c, None)
    return result


def resolve_main(outs):
    host = None
    try:
        with open(STATE) as f:
            host = json.load(f).get("output")
    except (OSError, ValueError):
        pass
    if host in outs:
        return host
    if INTERNAL in outs:
        return INTERNAL
    return outs[0] if outs else INTERNAL


def pick_external(outs, main):
    # Debug/testing override: SWAY_WM_FORCE_EXT="" forces "no external",
    # SWAY_WM_FORCE_EXT=HDMI-A-1 forces that output. Unset for real behaviour.
    forced = os.environ.get("SWAY_WM_FORCE_EXT")
    if forced is not None:
        return forced if forced in outs else None
    for name in outs:
        if name != main and not is_headless(name):
            return name
    return None


def destroy_empty(w):
    """Remove an empty workspace by focusing it then focusing elsewhere (sway
    destroys empty workspaces once they lose focus)."""
    others = [x for x in get_workspaces() if x["id"] != w["id"]]
    if not others:
        return
    foc = next((x for x in others if x.get("focused")), others[0])
    swaymsg("workspace", w["name"])
    swaymsg("workspace", foc["name"])


def apply_targets(targets, dry):
    """Rename workspaces to their desired numbers. Two passes (via unique
    temporary names) so cyclic renames like 1->2 and 2->1 never collide."""
    to_change = [(n, t) for n, t in targets.items() if n != t]
    if not to_change:
        return False
    if dry:
        for n, t in to_change:
            log("[dry] rename %s -> %s" % (n, t))
        return True

    tmp = []
    for i, (n, t) in enumerate(to_change):
        tn = "%s%d-%d" % (TMP_PREFIX, os.getpid(), i)
        r = swaymsg("rename", "workspace", n, "to", tn)
        if r.returncode != 0:
            log("temp rename %s -> %s failed: %s" % (n, tn, r.stderr.strip()))
            continue
        tmp.append((tn, t))
    for tn, t in tmp:
        r = swaymsg("rename", "workspace", tn, "to", t)
        if r.returncode != 0:
            log("rename %s -> %s failed: %s" % (tn, t, r.stderr.strip()))
        else:
            log("renamed -> %s" % t)
    return True


def reconcile(dry=False):
    global pinned_id

    all_ws = get_workspaces()
    ws = sorted((w for w in all_ws if NUMERIC.match(w.get("name", ""))),
                key=lambda w: w["num"])
    refocus = next((w["name"] for w in all_ws if w.get("focused")), None)

    outs = active_outputs()
    main = resolve_main(outs)
    ext = pick_external(outs, main)

    # External went away: drop the empty pinned workspace it left behind so the
    # rest collapse back down (2,3,4 -> 1,2,3).
    if ext is None and pinned_id is not None:
        pin = next((w for w in all_ws if w["id"] == pinned_id), None)
        if pin is not None and pin["name"] not in nonempty_workspaces() and not dry:
            destroy_empty(pin)
            all_ws = get_workspaces()
            ws = sorted((w for w in all_ws if NUMERIC.match(w.get("name", ""))),
                        key=lambda w: w["num"])
        pinned_id = None

    targets = {}

    if ext is None:
        for i, w in enumerate(ws, start=1):
            targets[w["name"]] = str(i)
    else:
        on_ext = [w for w in ws if w["output"] == ext]
        off = [w for w in ws if w["output"] != ext]

        # Only one workspace may live on the external; focus each extra and
        # move it to main (sway has no "move workspace <name>" form — a named
        # move is silently parsed as junk and mangles the name).
        if len(on_ext) > 1:
            if not dry:
                for w in on_ext[1:]:
                    swaymsg("workspace", w["name"])
                    swaymsg("move", "workspace", "to", "output", main)
                if refocus:
                    swaymsg("workspace", refocus)
            return

        # Nothing on the external yet: create an empty workspace there and let
        # the next pass number it as 1.
        if not on_ext:
            if dry:
                log("[dry] would create workspace 1 on %s" % ext)
                return
            hi = max((w["num"] for w in ws), default=0) + 1
            swaymsg("focus", "output", ext)
            swaymsg("workspace", "number", str(hi))
            if refocus:
                swaymsg("workspace", refocus)
            all_ws = get_workspaces()
            ws = sorted((w for w in all_ws if NUMERIC.match(w.get("name", ""))),
                        key=lambda w: w["num"])
            on_ext = [w for w in ws if w["output"] == ext]
            off = [w for w in ws if w["output"] != ext]
            if not on_ext:
                log("could not create a workspace on %s" % ext)
                return

        pinned = on_ext[0]
        off.sort(key=lambda w: w["num"])
        targets[pinned["name"]] = "1"
        for i, w in enumerate(off, start=2):
            targets[w["name"]] = str(i)

    apply_targets(targets, dry)

    if not dry and ext is not None:
        for w in get_workspaces():
            if w["name"] == "1" and w["output"] == ext:
                pinned_id = w["id"]
                break


def main():
    os.makedirs(os.path.dirname(LOCK), exist_ok=True)
    lockf = open(LOCK, "w")
    try:
        fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return  # another instance is already running
    lockf.write(str(os.getpid()))
    lockf.flush()

    proc = subprocess.Popen(
        ["swaymsg", "-t", "subscribe", "-m", '["workspace","window","output"]'],
        stdout=subprocess.PIPE, text=True,
    )
    log("started (pid %d)" % os.getpid())
    try:
        reconcile()
    except Exception:
        log(traceback.format_exc())

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
            try:
                reconcile()
            except Exception:
                log(traceback.format_exc())
            deadline = None


if __name__ == "__main__":
    if "--dry-run" in sys.argv:
        VERBOSE = True
        try:
            reconcile(dry=True)
        except Exception:
            traceback.print_exc()
    elif "--once" in sys.argv:
        reconcile()
    else:
        try:
            main()
        except Exception:
            log(traceback.format_exc())
            raise
