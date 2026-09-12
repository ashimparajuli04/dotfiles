#!/usr/bin/env bash
# Screenshot helper for the New Wave rice.
#
#   screenshot.sh region   drag a region (slurp), then annotate in satty
#   screenshot.sh full     whole desktop, then annotate in satty
#   screenshot.sh window   focused window, then annotate in satty
#
# In satty: Enter copies to the clipboard and saves a timestamped PNG,
# Ctrl+Shift+S saves as, Esc cancels. Bound to Print in sway/config.
set -euo pipefail

mode="${1:-region}"
shot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$shot_dir"

satty_args=(
    --filename -
    --initial-tool arrow
    --copy-command wl-copy
    --output-filename "$shot_dir/Screenshot_%Y-%m-%d_%H-%M-%S.png"
    --save-after-copy
    --actions-on-escape exit
    --disable-notifications
)

case "$mode" in
    region)
        geometry="$(slurp -d)" || exit 0 # cancelled with Esc
        grim -g "$geometry" - | satty "${satty_args[@]}"
        ;;
    full)
        grim - | satty "${satty_args[@]}"
        ;;
    window)
        geometry="$(
            swaymsg -t get_tree | jq -r '
                .. | objects
                | select(.focused? == true and (.type? == "con" or .type? == "floating_con"))
                | "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"' | head -n1
        )"
        [[ -n "$geometry" ]] || exit 0
        grim -g "$geometry" - | satty "${satty_args[@]}"
        ;;
    *)
        echo "usage: screenshot.sh region|full|window" >&2
        exit 2
        ;;
esac
