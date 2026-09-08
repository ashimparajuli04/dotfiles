#!/usr/bin/env bash
# Focus the window of a running app (matched by wayland app_id or X11 class,
# case-insensitive substring), or launch the app if no window exists.
#
# Usage: app-toggle.sh <name-pattern> <launch-command...>
# Example: app-toggle.sh discord discord

set -u

pattern="$1"
shift

cid=$(swaymsg -t get_tree | jq -r --arg p "$pattern" '
  [.. | objects
   | select(((.app_id? // "") | test($p; "i"))
            or ((.window_properties.class? // "") | test($p; "i")))]
  | .[0].id // empty')

if [ -n "$cid" ]; then
  swaymsg "[con_id=$cid] focus"
else
  exec "$@"
fi
