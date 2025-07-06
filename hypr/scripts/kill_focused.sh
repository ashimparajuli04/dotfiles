#!/bin/bash

pid=$(hyprctl activewindow -j | jq -r '.pid')

if [[ "$pid" =~ ^[0-9]+$ ]]; then
    kill -9 "$pid"
else
    notify-send "Hyprland" "Could not get PID of focused window"
fi
