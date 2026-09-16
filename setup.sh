#!/usr/bin/env bash
#
# New Wave sway rice — one-shot setup (idempotent).
# On a new machine:  git clone <repo> ~/Programming/dotfiles && ./setup.sh
#
# Usage: ./setup.sh [--skip-packages] [--copy-assets] [--no-restart]
#   --skip-packages  don't install pacman/AUR packages
#   --copy-assets    copy assets into place instead of symlinking them
#   --no-restart     don't reload sway at the end
#
# Keep the lists below in sync with AGENTS.md ("make it consistent").
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OLD_HOME="/home/ashim"
OLD_REPO="/home/ashim/Programming/dotfiles"

SKIP_PACKAGES=0
COPY_ASSETS=0
NO_RESTART=0
for arg in "$@"; do
  case "$arg" in
    --skip-packages) SKIP_PACKAGES=1 ;;
    --copy-assets)   COPY_ASSETS=1 ;;
    --no-restart)    NO_RESTART=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown option: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

BACKUP="$HOME/.rice-backup-$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------
PACMAN_PKGS=(
  waybar rofi mpd mpc ncmpcpp playerctl jq ffmpeg dunst libnotify swaybg
  brightnessctl pipewire-pulse grim satty wl-clipboard pavucontrol sassc
  papirus-icon-theme
  bluez bluez-utils quickshell cava rmpc khal vdirsyncer uv
  ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-material-icons
  ttf-material-design-icons-extended
  python-requests python-unidecode python-jinja
  dkms linux-headers
)
AUR_PKGS=(eww-git bibata-cursor-theme-bin ryzenadj-git ryzen_smu-dkms-git)

# ---------------------------------------------------------------------------
# What gets placed where
# ---------------------------------------------------------------------------
CONFIG_DIRS=(
  kitty nvim battery-alert cava dunst eww gtk-3.0 gtk-4.0 khal mpd
  mpd-lyricsd ncmpcpp quickshell rmpc rofi sway systemd vdirsyncer
  waybar xkb
)

# "path-inside-repo|destination"
EXTRA_LINKS=(
  "changes.md|$HOME/changes.md"
  "bin/mpd-lyricsd|$HOME/.local/bin/mpd-lyricsd"
  "bin/power-mode|$HOME/.local/bin/power-mode"
  "icons/vinyl.svg|$HOME/.local/share/icons/vinyl.svg"
  "icons/Flat-Remix-Blue-Dark|$HOME/.local/share/icons/Flat-Remix-Blue-Dark"
  "fonts/SFPro|$HOME/.local/share/fonts/SFPro"
  "fonts/newwave|$HOME/.local/share/fonts/newwave"
  "wallpapers/newwave-1.png|$HOME/Pictures/wallpapers/newwave-1.png"
  "themes/Nightfox-Dark-Duskfox|$HOME/.themes/Nightfox-Dark-Duskfox"
  "themes/Nightfox-Dark-Duskfox-hdpi|$HOME/.themes/Nightfox-Dark-Duskfox-hdpi"
  "themes/Nightfox-Dark-Duskfox-xhdpi|$HOME/.themes/Nightfox-Dark-Duskfox-xhdpi"
  "themes/Nightfox-Dusk-B|$HOME/.themes/Nightfox-Dusk-B"
)

# Text files whose hardcoded /home/ashim paths are rewritten on a new machine
PATH_FIX_FILES=(
  sway/config waybar/config rofi/config.rasi eww/eww.yuck rmpc/config.ron
  vdirsyncer/config systemd/user/fetch-lyrics.service
  systemd/user/mpd-lyricsd.service scripts/fetch-lyrics
  mpd-lyricsd/config.toml gtk-3.0/bookmarks quickshell/BatteryPanel.qml
)

# ---------------------------------------------------------------------------
say()  { printf '   %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

backup_and_remove() {
  local dest="$1"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local rel="${dest#"$HOME"/}"
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$dest" "$BACKUP/$rel"
    say "backed up $dest -> $BACKUP/$rel"
  fi
}

link() {
  local src="$1" dest="$2" label="$3"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    say "ok       $label"
    return 0
  fi
  backup_and_remove "$dest"
  ln -s "$src" "$dest"
  say "linked   $label"
}

place() {
  local src="$REPO/$1" dest="$2" label="$3"
  if [ "$COPY_ASSETS" -eq 1 ]; then
    if [ -L "$dest" ]; then
      rm -f "$dest"
    elif [ -e "$dest" ]; then
      backup_and_remove "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    say "copied   $label"
  else
    link "$src" "$dest" "$label"
  fi
}

step "Repositories and paths"
say "repo: $REPO"
say "home: $HOME"

if [ "$OLD_REPO" != "$REPO" ] || [ "$OLD_HOME" != "$HOME" ]; then
  step "Path repair: $OLD_REPO -> $REPO, $OLD_HOME -> $HOME"
  for f in "${PATH_FIX_FILES[@]}"; do
    [ -f "$REPO/$f" ] || continue
    sed -i "s|$OLD_REPO|$REPO|g; s|$OLD_HOME|$HOME|g" "$REPO/$f"
    say "rewrote $f"
  done
  for n in assets gtk.css gtk-dark.css; do
    ln -sfn "$HOME/.themes/Nightfox-Dark-Duskfox/gtk-4.0/$n" "$REPO/gtk-4.0/$n"
  done
  say "re-targeted gtk-4.0 symlinks"
  say "NOTE: these rewrites are machine-local — do not commit them"
else
  say "paths already match this machine, nothing to rewrite"
fi

if [ "$SKIP_PACKAGES" -eq 0 ]; then
  step "Packages"
  if command -v pacman >/dev/null; then
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}" || say "some pacman packages failed — check output above"
    if command -v yay >/dev/null; then
      yay -S --needed --noconfirm "${AUR_PKGS[@]}" || say "some AUR packages failed — check output above"
    else
      say "yay not found; install AUR packages manually: ${AUR_PKGS[*]}"
    fi
    if [ -f /usr/lib/systemd/system/bluetooth.service ]; then
      sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 || true
      say "bluetooth.service enabled"
    fi
  else
    say "pacman not found — skipping package installs"
  fi
else
  step "Packages — skipped (--skip-packages)"
fi

step "Config dirs (~/.config)"
for d in "${CONFIG_DIRS[@]}"; do
  if [ -d "$REPO/$d" ]; then
    link "$REPO/$d" "$HOME/.config/$d" "~/.config/$d"
  else
    say "missing in repo: $d — skipped"
  fi
done

step "Assets"
for entry in "${EXTRA_LINKS[@]}"; do
  src="${entry%%|*}"
  dest="${entry#*|}"
  if [ -e "$REPO/$src" ] || [ -L "$REPO/$src" ]; then
    place "$src" "$dest" "${dest#"$HOME"/}"
  else
    say "missing in repo: $src — skipped"
  fi
done

if command -v fc-cache >/dev/null; then
  fc-cache -f >/dev/null 2>&1 || true
  say "font cache rebuilt"
fi

step "GTK settings"
if command -v gsettings >/dev/null && gsettings get org.gnome.desktop.interface gtk-theme >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme    "Nightfox-Dusk-B"
  gsettings set org.gnome.desktop.interface icon-theme   "Flat-Remix-Blue-Dark"
  gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
  gsettings set org.gnome.desktop.interface font-name    "SF Pro Display"
  say "theme / icons / cursor / font applied"
else
  say "no gsettings session found — apply manually (see changes.md)"
fi

step "Lyrics venv"
if [ -x "$REPO/scripts/.venv/bin/python3" ] && "$REPO/scripts/.venv/bin/python3" -c 'import pykakasi' >/dev/null 2>&1; then
  say "ok       scripts/.venv"
else
  if command -v uv >/dev/null; then
    uv venv --python "$(command -v python3)" "$REPO/scripts/.venv"
    uv pip install --python "$REPO/scripts/.venv/bin/python3" pykakasi
  else
    python3 -m venv "$REPO/scripts/.venv"
    "$REPO/scripts/.venv/bin/pip" install --quiet pykakasi
  fi
  say "created  scripts/.venv (pykakasi)"
fi

step "systemd user services"
systemctl --user daemon-reload >/dev/null 2>&1 || true
for unit in mpd.service mpd-lyricsd.service fetch-lyrics.timer vdirsyncer.timer; do
  if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
    say "enabled  $unit"
  else
    say "could not enable $unit — run manually"
  fi
done

step "Low Power Mode sudo rule"
# The Quickshell battery panel (BatteryPanel.qml) flips CPU boost/freq caps
# through bin/power-mode; allow just that script without a password prompt.
POWER_RULE="$(id -un) ALL=(root) NOPASSWD: $HOME/.local/bin/power-mode"
if command -v sudo >/dev/null && command -v visudo >/dev/null; then
  tmp="$(mktemp)"
  printf '%s\n' "$POWER_RULE" > "$tmp"
  if sudo visudo -c -f "$tmp" >/dev/null 2>&1; then
    sudo install -m 440 -o root -g root "$tmp" /etc/sudoers.d/rice-power-mode
    say "installed /etc/sudoers.d/rice-power-mode"
  else
    say "could not validate sudoers rule — Low Power Mode will ask for a password"
  fi
  rm -f "$tmp"
else
  say "no sudo/visudo — Low Power Mode will ask for a password"
fi

step "ryzen_smu module autoload"
# ryzenadj needs the SMU kernel module to read the PM table (power-mode
# tier 2 captures and verifies the APU limits through it).
if [ -d /etc/modules-load.d ]; then
  printf 'ryzen_smu\n' | sudo tee /etc/modules-load.d/rice-ryzen-smu.conf >/dev/null 2>&1 \
    && sudo modprobe ryzen_smu 2>/dev/null \
    && say "installed /etc/modules-load.d/rice-ryzen-smu.conf" \
    || say "could not set up ryzen_smu — the Power Limit tier will not work"
fi

for p in google-password icloud-password; do
  f="$REPO/vdirsyncer/$p"
  if [ ! -f "$f" ]; then
    : > "$f"
    chmod 600 "$f"
    say "created empty $f — fill in your password"
  fi
done

if [ "$NO_RESTART" -eq 0 ] && command -v swaymsg >/dev/null && swaymsg -t get_version >/dev/null 2>&1; then
  step "Reloading sway"
  swaymsg reload >/dev/null 2>&1 && say "sway config reloaded" || say "sway reload failed"
fi

cat <<'EOF'

Setup complete.

Manual steps still to do:
  * vdirsyncer:                app passwords in ~/.config/vdirsyncer/{google,icloud}-password
  * Genius lyrics token:       ~/.config/mpd-lyricsd/config.toml -> [genius] access_token
  * Weather module (optional): appid in ~/.config/waybar/weather.py + coords in weather-waybar-module.sh
  * Music:                     put songs in ~/Music (mpd auto_update is on)

EOF
