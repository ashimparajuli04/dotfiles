#!/usr/bin/env python3
"""3-finger swipe handler for sway: switch to the adjacent workspace,
creating the numbered workspace on demand (like pressing Mod+N).

Left stops at workspace 1. Right only creates a new workspace when the
current one has a window — from an empty rightmost workspace it is a no-op,
so you don't shuffle one empty workspace for another (see changes.md §34).

Usage: gesture-workspace.py left|right   (bound via bindgesture)
"""

import json
import re
import subprocess
import sys
import traceback

LOG = "/tmp/opencode/sway-gesture-workspace.log"
DIRECTIONS = ("left", "right")


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


def has_windows(node):
    """True if the container subtree holds at least one real window.

    On this sway the tree's leaf views report `window == null`, so a leaf
    container (type "con") is what identifies a window; the workspace itself
    must not count.
    """
    if node.get("window") is not None:
        return True
    children = node.get("nodes", []) + node.get("floating_nodes", [])
    if not children:
        return node.get("type") == "con"
    return any(has_windows(c) for c in children)


def focused_has_windows(name):
    """True if the workspace called `name` currently contains a window."""
    def find(node):
        if node.get("type") == "workspace" and node.get("name") == name:
            return node
        for c in node.get("nodes", []) + node.get("floating_nodes", []):
            hit = find(c)
            if hit is not None:
                return hit
        return None

    ws = find(get_json("get_tree"))
    return ws is not None and has_windows(ws)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in DIRECTIONS:
        sys.exit("usage: gesture-workspace.py left|right")
    direction = sys.argv[1]
    prev = direction == "left"  # swipe left = previous, swipe right = next

    workspaces = get_json("get_workspaces")
    ws_name = ""
    for w in workspaces:
        if w.get("focused"):
            ws_name = w["name"]
            break

    m = re.fullmatch(r"(\d+)", ws_name)
    if m:
        target = int(m.group(1)) + (-1 if prev else 1)
        if target < 1:
            log("ws-%s: on %s, no previous workspace, ignored" % (direction, ws_name))
            return
        # Never spawn a new workspace to the right from an empty one: sway would
        # create it and then destroy the empty workspace we left, so it looks
        # like a no-op with a flicker. Only create when there is a window to
        # leave behind. See changes.md §34.
        if (not prev and target not in {w["num"] for w in workspaces}
                and not focused_has_windows(ws_name)):
            log("ws-%s: on empty %s at the right edge, ignored" % (direction, ws_name))
            return
        swaymsg("workspace number %d" % target)
        log("ws-%s: workspace %s -> %d" % (direction, ws_name, target))
    else:
        rel = "prev" if prev else "next"
        swaymsg("workspace %s" % rel)
        log("ws-%s: non-numeric workspace %r, using %s" % (direction, ws_name, rel))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log(traceback.format_exc())
