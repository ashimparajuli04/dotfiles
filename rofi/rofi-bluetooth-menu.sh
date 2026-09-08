#!/usr/bin/env bash

## Bluetooth device picker for rofi.
## Same styling as rofi-wifi-menu.sh: plain `rofi -dmenu`, so the global
## ~/.config/rofi/config.rasi theme applies.
##
## The MAC address travels in a hidden second column (tab-separated):
## rofi displays only column 1, but outputs the whole selected line.

if ! command -v bluetoothctl >/dev/null 2>&1; then
	notify-send "Bluetooth unavailable" "Install the stack: sudo pacman -S bluez bluez-utils"
	exit 1
fi

notify-send "Getting list of available Bluetooth devices..."

powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}')

if [ "$powered" = "yes" ]; then
	toggle="󰂲  Disable Bluetooth"
else
	toggle="󰂯  Enable Bluetooth"
fi

list="$toggle"
if [ "$powered" = "yes" ]; then
	# All known devices: connected first, then paired, then the rest.
	for mac in \
		$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}') \
		$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}') \
		$(bluetoothctl devices 2>/dev/null | awk '{print $2}')
	do
		[ -z "$mac" ] && continue
		[ "${seen[$mac]}" = 1 ] && continue
		seen[$mac]=1

		name=$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/^\tName:/ {print $2; exit}')
		if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
			label="󰂱  ${name:-$mac} (connected)"
		elif bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
			label="󰂯  ${name:-$mac}"
		else
			label="󰂰  ${name:-$mac} (new)"
		fi
		list+=$'\n'"$label"$'\t'"$mac"
	done
	list+=$'\n'"󰂰  Scan for devices"$'\t'"__scan__"
fi

# Show only column 1; the selection still returns the full line (label TAB mac).
chosen=$(printf '%s' "$list" | rofi -dmenu -i -display-columns 1 -selected-row 1 -p "Bluetooth: ")

[ -z "$chosen" ] && exit 0

case "$chosen" in
	*"Disable Bluetooth")
		bluetoothctl power off >/dev/null && notify-send "Bluetooth" "Disabled"
		exit 0
		;;
	*"Enable Bluetooth")
		bluetoothctl power on >/dev/null && notify-send "Bluetooth" "Enabled"
		exec "$HOME/.config/rofi/rofi-bluetooth-menu.sh"
		;;
esac

mac="${chosen##*$'\t'}"
name="${chosen%%$'\t'*}"
name="${name:3}"
name="${name% (connected)}"
name="${name% (new)}"

if [ "$mac" = "__scan__" ]; then
	notify-send "Bluetooth" "Scanning for 8 seconds..."
	bluetoothctl --timeout 8 scan on >/dev/null 2>&1
	exec "$HOME/.config/rofi/rofi-bluetooth-menu.sh"
fi

# Ignore anything that is not a valid MAC (custom typed input).
[[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || exit 0

if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
	bluetoothctl disconnect "$mac" >/dev/null \
		&& notify-send "Bluetooth" "Disconnected: $name"
else
	if ! bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
		if ! bluetoothctl pair "$mac" >/dev/null; then
			notify-send "Bluetooth" "Could not pair: $name"
			exit 1
		fi
	fi
	bluetoothctl trust "$mac" >/dev/null
	bluetoothctl connect "$mac" >/dev/null \
		&& notify-send "Bluetooth" "Connected: $name" \
		|| notify-send "Bluetooth" "Could not connect: $name"
fi
