#!/bin/sh
# Copy the stored Wi-Fi password for the SSID given as $1 to the clipboard.
# Used by the Wi-Fi panel's hidden right-click action; stays silent on failure
# and never touches the clipboard unless a password was actually found.

ssid=$1
[ -n "$ssid" ] || exit 0

# nmcli escapes ':' and '\' in terse output; escape the argument the same way
# so SSIDs containing those characters still match.
esc=$(printf %s "$ssid" | sed -e 's/\\/\\\\/g' -e 's/:/\\:/g')

for uuid in $(nmcli -t -f UUID,TYPE connection show | awk -F: '$2 == "802-11-wireless" {print $1}'); do
    if [ "$(nmcli -t -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null)" = "$esc" ]; then
        psk=$(nmcli -s -t -g 802-11-wireless-security.psk connection show "$uuid" 2>/dev/null)
        [ -n "$psk" ] && printf %s "$psk" | wl-copy
        break
    fi
done
