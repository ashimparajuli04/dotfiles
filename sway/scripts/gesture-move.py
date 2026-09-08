#!/usr/bin/env python3
"""4-finger swipe handler for sway.

Moves the focused container in the given direction. If it cannot move
(already at the edge of the layout), the container is carried to the
adjacent workspace instead and the view follows it.

Usage: gesture-move.py left|right|up|down   (bound via bindgesture)
"""

import json
import re
import subprocess
import sys
import traceback

LOG = "/tmp/opencode/sway-gesture-move.log"
DIRECTIONS = ("left", "right", "up", "down")


def log(msg):
    try:
        with open(LOG, "a") as f:
            f.write(msg + "\n")
    except OSError:
        pass


def swaymsg(*args):
    return subprocess.run(["swaymsg", *args], capture_output=True, text=True).stdout


def get_json(*args):
    return json.loads(swaymsg("-t", *args))


def find_focused(node, chain=()):
    """Return (container, ancestor_chain) of the focused window, or None."""
    if node.get("focused") and node.get("type") == "con":
        return node, chain
    for key in ("nodes", "floating_nodes"):
        for i, child in enumerate(node.get(key) or []):
            found = find_focused(child, chain + ((node.get("id"), key, i),))
            if found is not None:
                return found
    return None


def signature(con, chain):
    r = con["rect"]
    return (con["id"], r["x"], r["y"], r["width"], r["height"], chain)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in DIRECTIONS:
        sys.exit("usage: gesture-move.py left|right|up|down")
    direction = sys.argv[1]
    prev = direction in ("left", "up")

    result = find_focused(get_json("get_tree"))
    con, chain = result if result else (None, None)

    moved = False
    if con is not None:
        before = signature(con, chain)
        swaymsg("move " + direction)
        result2 = find_focused(get_json("get_tree"))
        if result2:
            moved = signature(*result2) != before

    if moved:
        log("%s: moved within the layout" % direction)
        return

    ws_name = ""
    for w in get_json("get_workspaces"):
        if w.get("focused"):
            ws_name = w["name"]
            break

    log("%s: fallback (workspace %r, window=%s)" % (direction, ws_name, con is not None))

    m = re.fullmatch(r"(\d+)", ws_name)
    if m:
        target = int(m.group(1)) + (-1 if prev else 1)
        if target < 1:
            log("  no previous workspace, doing nothing")
            return
        if con is not None:
            swaymsg("move container to workspace number %d" % target)
        swaymsg("workspace number %d" % target)
    else:
        rel = "prev" if prev else "next"
        if con is not None:
            swaymsg("move container to workspace " + rel)
        swaymsg("workspace " + rel)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log(traceback.format_exc())
