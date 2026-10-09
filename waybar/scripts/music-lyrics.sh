#!/usr/bin/env bash
# waybar music pill, split across the group/music modules:
#   icon  -> just the play/pause state glyph (the always-visible button)
#   text  -> "Title: current lyric"
#   prev  -> skip-previous glyph (revealed on hover)
#   next  -> skip-next glyph     (revealed on hover)
#   full  -> legacy "<icon> Title: lyric" (no argument; kept for back-compat)
# Lyrics are timed .lrc files in ~/.local/share/lyrics, named
# "<Artist> - <Title>.lrc". That dir is NOT tracked in the rice repo: if it is
# missing or empty the pill just shows the title. Genius plain-text fallback:
# ~/Music/.lyrics/lyrics.txt (written by mpd-lyricsd).

LYRICS_DIR="$HOME/.local/share/lyrics"
# The icon shows what pressing the pill will do:
#   bars while playing  -> press pauses
#   triangle while paused -> press plays
#   note when stopped / disconnected
ICON_WHILE_PLAYING=$'\uf04c'   # nf-fa-pause (press -> pause)
ICON_WHILE_PAUSED=$'\uf04b'    # nf-fa-play  (press -> play)
ICON_STOP=$'\uf001'            # nf-fa-music
# Prev/next are Plane-15 (nf-md-skip_previous / _next) — 5 hex digits, so
# they need \U (8-digit) escapes, not \u.
ICON_PREV=$'\U000F04AE'        # nf-md-skip_previous
ICON_NEXT=$'\U000F04AD'        # nf-md-skip_next

mode=${1:-full}
# These never depend on MPD state, so they short-circuit before mpc runs.
case "$mode" in
    prev) printf '%s\n' "$ICON_PREV"; exit 0 ;;
    next) printf '%s\n' "$ICON_NEXT"; exit 0 ;;
esac

# ---- MPD status ------------------------------------------------------------
if ! status=$(mpc status 2>/dev/null); then
    case "$mode" in
        icon) printf '%s\n' "$ICON_STOP" ;;
        text) printf 'Disconnected\n' ;;
        *)    printf '%s Disconnected\n' "$ICON_STOP" ;;
    esac
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

# The icon module only needs the play/pause state. Stop here so this
# (once-per-second) invocation never touches `mpc current`, the lyrics dir, or
# awk — they only feed the text module. Output is unchanged.
if [ "$mode" = icon ]; then
    printf '%s\n' "$icon"
    exit 0
fi

# Elapsed time (m:ss or h:mm:ss) -> seconds
elapsed=$(printf '%s\n' "$status" | grep -oE '([0-9]+:)?[0-9]+:[0-9]+/' | head -n1 | tr -d '/')
current_seconds=0
if [ -n "$elapsed" ]; then
    current_seconds=$(printf '%s' "$elapsed" | awk -F: '{ if (NF == 3) print $1 * 3600 + $2 * 60 + $3; else print $1 * 60 + $2 }')
fi

# ---- Current song ----------------------------------------------------------
# All three tags from a single `mpc current` (saves two mpd round-trips per
# second); split in pure bash to avoid extra `sed`/`printf` subprocesses.
meta=$(mpc current -f '%artist%\n%title%\n%file%' 2>/dev/null)
artist=${meta%%$'\n'*}
meta=${meta#*$'\n'}
title=${meta%%$'\n'*}
file=${meta#*$'\n'}
if [ -z "$title" ]; then
    title=$file
fi
title=${title##*/}
title=${title%.*}

if [ -z "$title" ]; then
    case "$mode" in
        icon) printf '%s\n' "$icon" ;;
        text) printf 'Stopped\n' ;;
        *)    printf '%s Stopped\n' "$icon" ;;
    esac
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
case "$mode" in
    icon)
        printf '%s\n' "$icon"
        ;;
    text)
        if [ -n "$current_lyric" ]; then
            printf '%s: %s\n' "$title" "$current_lyric"
        else
            printf '%s\n' "$title"
        fi
        ;;
    *)
        if [ -n "$current_lyric" ]; then
            printf '%s %s: %s\n' "$icon" "$title" "$current_lyric"
        else
            printf '%s %s\n' "$icon" "$title"
        fi
        ;;
esac
