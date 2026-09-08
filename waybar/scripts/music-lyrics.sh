#!/usr/bin/env bash
# waybar custom module: MPD now-playing + current synced lyric line.
# Lyrics are timed .lrc files in ~/.local/share/lyrics, named
# "<Artist> - <Title>.lrc". Example output:
#    " Let Her Go: only know you love her when you let her go"

LYRICS_DIR="$HOME/.local/share/lyrics"
# The icon shows what pressing the pill will do:
#   bars while playing  -> press pauses
#   triangle while paused -> press plays
#   note when stopped / disconnected
ICON_WHILE_PLAYING=$'\uf04c'   # nf-fa-pause (press -> pause)
ICON_WHILE_PAUSED=$'\uf04b'    # nf-fa-play  (press -> play)
ICON_STOP=$'\uf001'            # nf-fa-music

# ---- MPD status ------------------------------------------------------------
if ! status=$(mpc status 2>/dev/null); then
    echo "$ICON_STOP Disconnected"
    exit 0
fi

# NOTE: line 1 of `mpc status` is the current song title; the [state]
# token is on line 2 — taking line 1 made the state never match.
state=$(printf '%s\n' "$status" | sed -n '2{s/^\[\([a-z]*\)\].*/\1/;p}')
case "$state" in
    playing) icon="$ICON_WHILE_PLAYING" ;;
    paused)  icon="$ICON_WHILE_PAUSED" ;;
    *)       icon="$ICON_STOP" ;;
esac

# Elapsed time (m:ss or h:mm:ss) -> seconds
elapsed=$(printf '%s\n' "$status" | grep -oE '([0-9]+:)?[0-9]+:[0-9]+/' | head -n1 | tr -d '/')
current_seconds=0
if [ -n "$elapsed" ]; then
    current_seconds=$(printf '%s' "$elapsed" | awk -F: '{ if (NF == 3) print $1 * 3600 + $2 * 60 + $3; else print $1 * 60 + $2 }')
fi

# ---- Current song ----------------------------------------------------------
artist=$(mpc current -f '%artist%' 2>/dev/null)
title=$(mpc current -f '%title%' 2>/dev/null)
if [ -z "$title" ]; then
    title=$(mpc current -f '%file%' 2>/dev/null)
fi
title=${title##*/}
title=${title%.*}

if [ -z "$title" ]; then
    echo "$icon Stopped"
    exit 0
fi

# ---- Locate lyrics: exact "Artist - Title.lrc", else title substring -------
lyrics_file=""
if [ -n "$artist" ] && [ -f "$LYRICS_DIR/$artist - $title.lrc" ]; then
    lyrics_file="$LYRICS_DIR/$artist - $title.lrc"
else
    lyrics_file=$(find "$LYRICS_DIR" -maxdepth 1 -type f -name '*.lrc' 2>/dev/null | grep -iF -- "$title" | head -n1)
fi

# ---- Latest lyric line whose timestamp has passed --------------------------
current_lyric=""
if [ -n "$lyrics_file" ] && [ -f "$lyrics_file" ]; then
    current_lyric=$(awk -v now="$current_seconds" '
        function tsecs(ts,   p, n, s) {
            n = split(ts, p, ":")
            s = p[n] + 0
            if (n == 1) return s
            if (n == 2) return p[1] * 60 + s
            return p[1] * 3600 + p[2] * 60 + s
        }
        /^\[[0-9]+:[0-9]+([.:][0-9]+)?\]/ {
            ts = $0
            sub(/^\[/, "", ts)
            sub(/\].*/, "", ts)
            if (tsecs(ts) <= now + 0) {
                text = $0
                gsub(/\r/, "", text)
                sub(/^(\[[0-9]+:[0-9]+([.:][0-9]+)?\])+/, "", text)
                sub(/^[ \t]+/, "", text)
                sub(/[ \t]+$/, "", text)
                if (text != "") best = text
            }
        }
        END { if (best != "") print best }
    ' "$lyrics_file")
fi

# ---- Output ----------------------------------------------------------------
if [ -n "$current_lyric" ]; then
    printf '%s %s: %s\n' "$icon" "$title" "$current_lyric"
else
    printf '%s %s\n' "$icon" "$title"
fi
