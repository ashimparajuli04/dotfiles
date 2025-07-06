#!/bin/bash
eval $(/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh)
echo "SSH_AUTH_SOCK is $SSH_AUTH_SOCK" > /tmp/keyring_debug.txt
export SSH_AUTH_SOCK
exec Hyprland
