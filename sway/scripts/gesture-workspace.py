#!/usr/bin/env python3
"""3-finger swipe handler for sway: switch to the adjacent workspace,
creating the numbered workspace on demand (like pressing Mod+N).

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


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in DIRECTIONS:
        sys.exit("usage: gesture-workspace.py left|right")
    direction = sys.argv[1]
    prev = direction == "left"  # swipe left = previous, swipe right = next

    ws_name = ""
    for w in get_json("get_workspaces"):
        if w.get("focused"):
            ws_name = w["name"]
            break

    m = re.fullmatch(r"(\d+)", ws_name)
    if m:
        target = int(m.group(1)) + (-1 if prev else 1)
        if target < 1:
            log("ws-%s: on %s, no previous workspace, ignored" % (direction, ws_name))
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
