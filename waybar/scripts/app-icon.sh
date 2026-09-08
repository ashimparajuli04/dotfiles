#!/usr/bin/env bash
# Prints the given glyph while a process with the exact name is running,
# otherwise prints nothing (the waybar module hides itself).
#
# Usage: app-icon.sh <process-name> <glyph>

set -u

if pgrep -x "$1" > /dev/null 2>&1; then
    printf '%s\n' "$2"
fi
