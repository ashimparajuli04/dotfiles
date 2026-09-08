#!/usr/bin/env bash
# Focus an app's window when it raises its urgency hint, e.g. when clicking
# the app's tray icon in waybar (Discord sets urgency instead of focusing).
# APPS is a case-insensitive regex matched against wayland app_id / X11 class.
set -u

APPS="discord|qbittorrent"

# Single-instance guard (sway re-runs exec lines on config reload)
exec 9>"/tmp/urgent-focus.lock"
flock -n 9 || exit 0

swaymsg -t subscribe -m '["window"]' | jq --unbuffered -r --arg apps "$APPS" '
  select(.change == "urgent" and .container.urgent == true)
  | select(((.container.app_id? // "") | test($apps; "i"))
           or ((.container.window_properties.class? // "") | test($apps; "i")))
  | .container.id' | while read -r id; do
    swaymsg "[con_id=$id] focus"
done
