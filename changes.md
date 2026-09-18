# New Wave rice port — full change log

**Date:** 2026-10-08
**Source:** https://github.com/LoneWolf4713/new-wave (Sway "New Wave" rice, Fedora-based, adapted for this Arch system)
**Purpose of this file:** every change made during the port, so any part (or all) can be reverted.

---

## 0. TL;DR — how to revert everything

```bash
# 1. Restore original configs
cp ~/.newwave-backup/sway-config.bak ~/.config/sway/config
cp ~/.newwave-backup/kitty.conf.bak ~/.config/kitty/kitty.conf

# 2. Remove new config dirs/files (these did not exist before)
rm -rf ~/.config/waybar ~/.config/rofi ~/.config/eww ~/.config/mpd ~/.config/ncmpcpp \
       ~/.config/dunst ~/.config/battery-alert ~/.config/mpd-lyricsd ~/.config/kitty/theme.conf \
       ~/.local/bin/mpd-lyricsd ~/.local/share/icons/vinyl.svg \
       ~/.local/share/icons/Flat-Remix-Blue-Dark \
       ~/.local/share/fonts/SFPro ~/.local/share/fonts/newwave \
       ~/Pictures/wallpapers/newwave-1.png \
       ~/.themes/Nightfox-Dark-Duskfox ~/.themes/Nightfox-Dark-Duskfox-hdpi ~/.themes/Nightfox-Dark-Duskfox-xhdpi \
       ~/.themes/Nightfox-Dusk-B
rm -f ~/.config/gtk-4.0/assets ~/.config/gtk-4.0/gtk.css ~/.config/gtk-4.0/gtk-dark.css  # symlinks

# 3. Restore GTK settings (old values from ~/.newwave-backup/gsettings-before.txt)
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'

# 4. Remove installed packages (only if you don't need them — check with `pacman -Q`)
sudo pacman -Rns waybar rofi mpd mpc ncmpcpp playerctl jq ffmpeg dunst libnotify swaybg \
     brightnessctl pipewire-pulse ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-material-icons \
     ttf-material-design-icons-extended python-requests python-unidecode python-jinja grim \
     pavucontrol sassc papirus-icon-theme
yay -Rns eww-git bibata-cursor-theme-bin

# 5. Rebuild font cache and reload sway
fc-cache -f
swaymsg reload
```

> Note: removing `pipewire-pulse` breaks the volume keys again (that was the pre-existing state).
> Remove step 4 lines selectively if you want to keep some packages.

---

## 1. Backups made (before any change)

| Backup | Original file |
|---|---|
| `~/.newwave-backup/sway-config.bak` | `~/.config/sway/config` |
| `~/.newwave-backup/kitty.conf.bak` | `~/.config/kitty/kitty.conf` |
| `~/.newwave-backup/gsettings-before.txt` | GTK/icon/cursor/font settings |
| `~/.newwave-backup/packages-before.txt` | `pacman -Qq` list before installs |

---

## 2. Packages installed

**Official repos (`sudo pacman -S`):**

```
waybar rofi mpd mpc ncmpcpp playerctl jq ffmpeg dunst libnotify swaybg brightnessctl
pipewire-pulse ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-material-icons
python-requests python-unidecode python-jinja grim pavucontrol sassc papirus-icon-theme
```

- `pipewire-pulse` — fixes the pre-existing broken volume keys (`pactl` had no server).
- `grim` — your existing `Print` keybind was already pointing at it (it was not installed).
- `pavucontrol` — Waybar volume module's on-click target (his config).
- `sassc` (+ `libsass` dep) — needed to build the Nightfox GTK theme.
- `papirus-icon-theme` — rofi's configured icon theme.

**AUR (`yay -S`):** `eww-git`, `bibata-cursor-theme-bin`, `ttf-material-design-icons-extended`.

**NOT installed as a package:** `flat-remix` (icon theme). Its AUR package is a 2 GB build and
makepkg deadlocked on this machine during its debug-symbol step. Instead, the single variant we
need (`Flat-Remix-Blue-Dark`, 55 MB) was extracted manually from the downloaded source tarball
into `~/.local/share/icons/`. (The 3 GB build cache was deleted afterwards.)

**From GitHub:**
- Nightfox GTK theme — cloned and built with `sassc` (see section 3).
- SF Pro Display fonts (from the repo his README links).
- Wallpaper (`newwave-1.png` — the palm-tree synthwave one from his showcase).

---

## 3. Files/directories created (all new; only the two files in section 4 were overwritten)

### Sway
- `~/.config/sway/config` — **modified** (backup above). His "MY STUFF" block appended, `$menu` switched to rofi, wallpaper changed, built-in swaybar commented out, Waybar + dunst autostarts added, Fedora-isms removed. Details in section 5.

### Waybar
- `~/.config/waybar/config` — his file, one fix (launcher on-click path).
- `~/.config/waybar/style.css` — his file, verbatim.
- `~/.config/waybar/weather.py` — his file + guard that stays silent while unconfigured.
- `~/.config/waybar/weather-waybar-module.sh` — wrapper with placeholder coordinates.

### Rofi
- `~/.config/rofi/config.rasi` — his file, `@theme` path fixed (his home → this home, type-3 → type-7).
- `~/.config/rofi/colors/` — all his color schemes.
- `~/.config/rofi/launchers/type-7/` — launcher used by `$mod+d`.
- `~/.config/rofi/powermenu/type-6/` — power menu (XF86PowerOff key).
- `~/.config/rofi/applets/` — includes the MPD applet (`$mod+m`).
- `~/.config/rofi/scripts/` — `launcher_t7`, `powermenu_t6` entry scripts.
- `~/.config/rofi/images/` — only the images his styles reference (`k2.png`, `a.png`, `d.png`, `e.jpg`, `i.jpg`, `z.png`, `j.jpg`).
- `~/.config/rofi/rofi-wifi-menu.sh` — Waybar network module on-click.

### EWW (music widget, bottom-left)
- `~/.config/eww/eww.yuck` — his widget; `getSongDuration` (missing from his repo) replaced with `~/.config/eww/music length`.
- `~/.config/eww/eww.scss` — his style; font changed `JetBrains Mono NL Medium` → `JetBrainsMono Nerd Font` (the NL variant isn't installed).
- `~/.config/eww/music` — his script (executable); fallback cover path fixed.
- `~/.config/eww/assets/fallback.png` — copy of the wallpaper (his referenced file doesn't exist in the repo).

### MPD / ncmpcpp (music stack — library is empty for now)
- `~/.config/mpd/mpd.conf` — his config with fixes (section 5).
- `~/.config/mpd/mpd-notify` — his track-change notification script (executable).
- `~/.config/mpd-lyricsd/config.toml` — lyrics daemon config; path fixed to `/home/ashim/Music/.lyrics`. **Uses his public Genius API token** — get your own free token at https://genius.com/api-clients and replace `access_token`.
- `~/.local/bin/mpd-lyricsd` — his prebuilt binary from the repo (verified: needs glibc ≤2.34, system has 2.44; connects to MPD 0.24 successfully).
- `~/.config/ncmpcpp/config` — his config; removed three lyrics fetchers that no longer exist in ncmpcpp 0.10 (`azlyrics`, `sing365`, `metrolyrics`) to silence warnings.
- `~/.local/share/icons/vinyl.svg` — small vinyl icon (his referenced icon is not in the repo); used by ncmpcpp's song-change notification.
- `~/Music/.lyrics/lyrics.txt` — empty placeholder read by the EWW lyrics box.

### Notifications / bar support
- `~/.config/dunst/dunstrc` — his Catppuccin dunstrc, verbatim.
- `~/.config/battery-alert/battery-alert` — **written from scratch** (his file 404s). Notifies at 15% and 5%.

### Terminal (kitty)
- `~/.config/kitty/theme.conf` — his Floraverse theme.
- `~/.config/kitty/kitty.conf` — **modified** (backup above): theme include swapped to `theme.conf`, font switched to `JetBrainsMono Nerd Font` (auto bold/italic), `window_padding_width 4` added. Your symbol_map, cursor trail and other settings untouched.

### Fonts (installed to `~/.local/share/fonts/`)
- `SFPro/` — SF Pro Display family (from his README's GitHub link; **Apple font, personal use only**).
- `newwave/Icomoon-Feather.ttf`, `newwave/GrapeNuts-Regular.ttf` — from his `fonts.zip`.
- System fonts (packages): JetBrains Mono Nerd Font, Iosevka Nerd Font, Material Icons, Material Design Icons Extended.
- Ran `fc-cache -f`.

### Icons / cursor / GTK theme
- `~/.local/share/icons/Flat-Remix-Blue-Dark/` — extracted manually (see section 2).
- `~/.themes/Nightfox-Dark-Duskfox/` (+ `-hdpi`, `-xhdpi` variants) — built from https://github.com/Fausto-Korpsvart/Nightfox-GTK-Theme with the `duskfox` tweak.
- `~/.themes/Nightfox-Dusk-B` — symlink to `Nightfox-Dark-Duskfox` (the name his config expects).
- `~/.config/gtk-4.0/{assets,gtk.css,gtk-dark.css}` — **new symlinks** into the Nightfox theme (libadwaita/GTK4 apps); `settings.ini` untouched.
- Cursor: `Bibata-Modern-Ice` (AUR package).

### Wallpaper
- `~/Pictures/wallpapers/newwave-1.png` — the palm-tree synthwave wallpaper from his showcase (1920x1080). The second wallpaper link in his README is dead (imgur 404).
- Set via `output * bg` in the sway config. Swap the path there to change it.

---

## 4. Files modified (pre-existing files that changed)

| File | What changed | How to revert |
|---|---|---|
| `~/.config/sway/config` | rice block appended, `$menu` → rofi, wallpaper path, swaybar commented out | `cp ~/.newwave-backup/sway-config.bak ~/.config/sway/config` |
| `~/.config/kitty/kitty.conf` | theme include, font family/bold/italic, padding | `cp ~/.newwave-backup/kitty.conf.bak ~/.config/kitty/kitty.conf` |
| dconf (GTK settings) | gtk-theme/icon-theme/cursor-theme/font-name | see section 0 step 3 |

---

## 5. Deviations from his repo (adaptations for Arch / this machine)

| His config | Here | Why |
|---|---|---|
| `font pango:monospace 0` | `font pango:monospace 1` | Newer Sway rejects size 0 ("Invalid font size") |
| Fedora `layered-include` line | removed (kept your `include /etc/sway/config.d/*`) | Fedora-specific helper doesn't exist on Arch |
| `/home/prtyksh/...` paths | `/home/ashim/...` | his home directory |
| `light -U/-A` brightness (F2/F3) | `brightnessctl set 5%±` | `light` not used here; your Fn keys kept too |
| mpd `httpd` output (open HTTP stream, port 8000) | commented out | no need for a stream server |
| mpd `bind_to_address` (unset = any interface) | `127.0.0.1` | localhost only |
| mpd fifo output named `my_fifo` | renamed `Visualizer` | matches ncmpcpp `visualizer_output_name` |
| mpd `auto_update` (off in his config) | `auto_update "yes"` | new files in `~/Music` are picked up automatically |
| Waybar launcher on-click `~/.config/rofi/launchers/misc/launcher.sh` | `.../type-7/launcher.sh` | his path doesn't exist in his own repo |
| EWW `getSongDuration` | `~/.config/eww/music length` | file missing from his repo |
| EWW fallback cover `~/.config/eww/dashboard/assets/fallback.png` | `~/.config/eww/assets/fallback.png` | missing from his repo |
| powermenu.sh used `hostname` | `cat /proc/sys/kernel/hostname` | `hostname` isn't installed on Arch (part of inetutils) |
| mpdscrobble (Last.fm) autostart | not installed | needs a Last.fm account; can add later (`mpdscrobble-git` in AUR) |
| login sound (`paplay`) | not added | sound file not in his repo |
| SDDM/Catppuccin theme | not applied | this system has no display manager |
| Firefox `userChrome` CSS (PenguinFox) | not applied | Zen browser doesn't support it |
| ncmpcpp ueberzug cover art | not configured | ueberzug is X11-only; EWW shows covers instead |
| gaps `inner 10` / `outer 10` | `inner 6` / `outer 0` | on sway 1.12 outer gaps are *added* to inner (his 10+10 = 20px edges, while the top gap was only 10px -> unequal + chunky). 6px everywhere now, top gap matched. |
| Waybar `margin-top/left/right: 5/10/10` | `1/1/1` | makes every bar gap 6px: screen-top-to-pills, pills-to-window, and both screen edges (pill margins are 5px + 1px bar margin) |

---

## 6. What was verified working (2026-10-08)

- `sway -C` config validation: clean. `swaymsg reload` applied to the running session: success.
- Waybar: running, black pill modules visible (workspaces, MPD, clock, backlight, volume, network, battery, power).
- EWW: daemon + `example` window active, no errors in `~/.cache/eww/eww_*.log`; widget renders (pink card + controls + lyrics area) — screenshot-verified.
- Rofi: launcher theme loads, powermenu + MPD applet scripts run.
- MPD: running; `mpc` connects; `mpd-lyricsd` connects to MPD.
- Music library scanned: 187 songs / 118 artists / 159 albums (~12h). Playback verified end-to-end:
  audio through PipeWire, embedded cover extracted to `/tmp/cover.png`, dunst track notification fired,
  lyrics fetched and written to `~/Music/.lyrics/lyrics.txt` (verified with Selena Gomez - Back To You).
- ncmpcpp: opens in kitty and is assigned to workspace 3 (`assign [app_id="ncmpcpp"]` works).
- dunst: running; `dunstify` test notification sent.
- gsettings: all four values applied (Nightfox-Dusk-B, Flat-Remix-Blue-Dark, Bibata-Modern-Ice, SF Pro Display).
- Wallpaper, gaps (6px equal top/sides/bottom, verified by pixel-measuring screenshots), no borders, no titlebars: confirmed.

> These were also started manually in the current session (they autostart on next login via sway `exec`):
> waybar, dunst, eww, mpd-notify, mpd-lyricsd, battery-alert, ncmpcpp window on ws3.

### Quirks / notes

- **EWW widget stacking**: his config uses `:stacking "bottom"`, so the widget sits *below* normal
  windows — visible on empty workspaces / wallpaper, hidden when a tiled window covers that corner.
  To make it float above windows: change `:stacking "bottom"` to `:stacking "top"` in
  `~/.config/eww/eww.yuck`, then `eww reload`.
- **Gaps (sway 1.12 semantics)**: `gaps inner` spaces *each window* (including workspace edges) and
  `gaps outer` is *additional* workspace spacing — so edge gap = inner + outer. Current values:
  `inner 6`, `outer 0` → 6px edges/between windows; Waybar margins `1px` + its 5px pill margins →
  6px above pills, 6px from each screen edge to the first/last pill; pills end 6px above windows.
  - Gap values in the config are defaults for **new** workspaces only. To change live (all workspaces):
    `swaymsg gaps inner all set 6` and `swaymsg gaps outer all set 0` (note the `all set` — plain
    `swaymsg gaps outer 0` does nothing).
  - To tune: pick the edge value, set `inner` to it and `outer 0`; for the bar gaps set Waybar
    `margin-*` to (desired - 5).
- **Waybar height warning**: `height: 20` in his config is below what the module fonts require
  (39px); Waybar renders 39px tall. Same as his setup — kept as-is.
- **Rofi window-mode warnings**: harmless; this Arch rofi is Wayland-capable and only supports
  title/app-id matching.
- **ncmpcpp startup warnings** about old lyrics fetchers were silenced by trimming the list.
- **flat-remix AUR build** hung in makepkg's debug-symbol step on this machine (2 GB tree);
  its build cache was deleted. Icons were extracted manually instead.

---

## 7. Still to configure (optional)

1. **Weather module** — currently invisible. To enable: edit `~/.config/waybar/weather.py` line `appid = "<ENTER YOUR API KEY>"` (free key from https://openweathermap.org/api) and set your coordinates in `~/.config/waybar/weather-waybar-module.sh`. Then reload Waybar (`pkill -x waybar; waybar &`).
2. **Genius token for lyrics** — `~/.config/mpd-lyricsd/config.toml` currently uses his public token. Replace with your own free token.
3. **Music library** — already populated and scanned (187 songs in `~/Music`); `auto_update` is on, so new files appear automatically (no `mpc update` needed anymore).
4. **Spotify** — not installed; Waybar's `mpris` module will pick it up automatically if you install it. `assign [app_id="Spotify"] workspace number 4` is already in the sway config.
5. **Wallpaper** — swap the file or edit the `output * bg` line in `~/.config/sway/config`.
6. **Widget above windows** — see the EWW stacking note above.

---

## 8. Mod key addition: right Alt (2026-10-08)

Right Alt now acts as an extra `$mod` (Super/Mod4). Left Alt and both Win keys are
unchanged, and the Logo key still works as `$mod`.

- `~/.config/xkb/symbols/custom` — new file; `ralt_super` variant: `<RALT>` → `Super_R` (Mod4).
- `~/.config/xkb/rules/evdev` — new file; includes `%S/evdev` and registers the
  `custom:ralt_super` option.
- `~/.config/sway/config` — `input "type:keyboard" { xkb_options custom:ralt_super }`
  block added (plus a note near `set $mod Mod4`).

Apply live: `swaymsg input "type:keyboard" xkb_options custom:ralt_super`
(or `swaymsg reload` / re-login).

Revert: remove the `input "type:keyboard"` block from the sway config, then
`swaymsg input "type:keyboard" xkb_options ""` to clear it live (a re-login also
does), and optionally `rm -rf ~/.config/xkb`.

---

## 9. Bluetooth menu (2026-10-09)

The Bluetooth stack was not installed (hardware present: `hci0` / `ideapad_bluetooth`,
soft/hard block: no).

**Installed:** `bluez`, `bluez-utils` (`sudo pacman -S --needed`); `bluetooth.service`
enabled + started. Controller verified working (`bluetoothctl show`).

**New file:**
- `~/.config/rofi/rofi-bluetooth-menu.sh` — rofi picker: Bluetooth on/off, scan (8s),
  connect/disconnect, pair + trust. Same rofi styling as the Wi-Fi menu (global
  `config.rasi` theme); device MACs are hidden via rofi's `-display-columns`.

**Modified:**
- `~/.config/waybar/config` — `bluetooth` module added to `modules-right` (between
  volume and network); left-click opens the menu. Icons: 󰂯 on / 󰂱 connected / 󰂲 off.

**Revert:**
```bash
rm ~/.config/rofi/rofi-bluetooth-menu.sh
# remove "bluetooth" from modules-right and the "bluetooth" module block in
# ~/.config/waybar/config, then:
pkill -x waybar; setsid -f waybar >/dev/null 2>&1
sudo systemctl disable --now bluetooth
sudo pacman -Rns bluez bluez-utils   # optional
```

---

## 10. Quickshell Bluetooth popover (2026-10-09)

The Waybar bluetooth icon now opens a **Quickshell layer-shell popover** instead of the
rofi script (supersedes section 9's UI; the rofi script is kept on disk as a fallback).

**Installed:** `quickshell` (official `extra` repo, 0.3.1).

**New files (`~/.config/quickshell/`, flat):**
- `shell.qml` — entry point (`ShellRoot { BluetoothPanel {} }`)
- `BluetoothPanel.qml` — the popover: power switch, Scan button (auto-stops after 20 s),
  CONNECTED / SAVED / NEARBY sections, empty-state pairing-mode hint; transparent
  fullscreen click-catcher + Escape close it; anchored top-right, 6 px under the bar
  (the compositor adds Waybar's 30 px exclusive zone automatically)
- `DeviceRow.qml` — one device: icon, name, battery %, Connect/Disconnect/Pair;
  pair → auto trust + connect. (Note: delegate property is NOT `required` — Qt doesn't
  resolve `modelData` bindings on required properties for external component delegates.)
- `ToggleSwitch.qml` — pill switch
- `Theme.qml` — New Wave palette/font singleton (`#180F39` / `#FF00F1` / `#9878FF`)
- `qmldir` — registers the singleton + components

**Modified:**
- `~/.config/waybar/config` — bluetooth module `on-click` → `qs ipc call bluetooth toggle`
- `~/.config/sway/config` — `exec --no-startup-id quickshell --no-duplicate` autostart added

**Verified:** panel renders top-right (36 px from top, 6 px margin), XM4 shows as connected
with battery %, IPC toggle works, `--no-duplicate` prevents double start.
Battery reporting works natively (BlueZ `Battery Percentage`), no `main.conf` change needed.

**Note:** quickshell warns it was built against Qt 6.11.2 while the system now has
6.12.0 ("package must be rebuilt"). It runs fine here, but if it starts crashing,
reinstall/rebuild `quickshell` (`yay -S quickshell` or wait for the Arch rebuild).

**Revert:**
```bash
rm -rf ~/.config/quickshell
# waybar: bluetooth on-click back to: ~/.config/rofi/rofi-bluetooth-menu.sh &
# sway: remove the "exec --no-startup-id quickshell --no-duplicate" line
pkill -x quickshell
sudo pacman -Rns quickshell   # optional
```

---

## 11. Quickshell sound popover (2026-10-09)

The Waybar volume icon now opens a **Quickshell popover with Output / Input / Playback
tabs** instead of launching pavucontrol.

**New files (`~/.config/quickshell/`):**
- `SoundPanel.qml` — the popover: header (icon, default output name, master mute switch),
  tab bar (Output / Input / Playback), scrollable list capped at half the screen with a
  draggable scrollbar thumb; transparent click-catcher + Escape close; anchored top-right.
- `AudioRow.qml` — one row: icon (device glyph / app icon), name, `→ output` chip for
  playback streams (tap to pick another output), volume slider, %, mute button.
- `VolumeSlider.qml` — themed drag/click slider (doesn't fight live PipeWire updates).

**Behaviour:**
- Output / Input tabs: every sink/source; click a row to make it the default;
  per-device volume + mute.
- Playback tab: every app currently playing audio; per-app volume + mute; the chip shows
  which output the app is on and moves just that app (e.g. Discord on headphones while
  YouTube stays on speakers).
- Moves use `pactl move-sink-input <object.serial> <sink node name>` (Quickshell 0.3.1's
  link API is read-only). Verified mapping: PwNode.id == pactl `object.id`; pactl
  sink-input index == node `object.serial`.
- Quirks found and handled: all PwNodes report `ready=false` in 0.3.1, and nodes only
  receive live property updates while tracked — the panel uses a `PwObjectTracker` and
  ignores `ready`. PwNodeType flags are composite (`AudioSink = Audio|Sink`), so filters
  check the full flag and exclude `isStream` (otherwise streams show up as devices).

**Modified:**
- `~/.config/waybar/config` — `pulseaudio`: left-click → `qs ipc call sound toggle`,
  right-click → `pavucontrol`; Waybar reloaded.
- `BluetoothPanel.qml` / `WifiPanel.qml` / `SoundPanel.qml` — mutual exclusion: opening
  any popover closes the other two (each panel spawns `qs ipc call <other> hide`).
  Note: the WiFi popover's final rewrite dropped the `hideSound` hook once; it was
  re-added.
- `shell.qml` — `SoundPanel {}` added; `qmldir` — new components registered.

**Known quirk:** `qs ipc call <target> show` is broken in 0.3.1 for all panels (prints the
function list instead of calling; `toggle`/`hide` work). Waybar uses `toggle`, so it is
unaffected. `qs ipc call` also cannot pass arguments ("Function not found").

**Verified:** all three tabs render; volume changes from `pactl` update sliders live;
moving a stream between the analog sink and the WH-1000XM4 updates the output chip live
(tested both directions, stream restored afterwards); default input/output highlighting,
mute buttons, click-outside and Escape close.

**Revert:**
```bash
rm ~/.config/quickshell/SoundPanel.qml ~/.config/quickshell/AudioRow.qml ~/.config/quickshell/VolumeSlider.qml
# remove the three lines from ~/.config/quickshell/qmldir; remove SoundPanel {} from shell.qml
# waybar pulseaudio: on-click back to "pavucontrol", remove on-click-right
pkill -x quickshell; setsid -f quickshell --no-duplicate
```

---

## 12. Time-synced lyrics in the EWW widget + improved fetcher (2026-10-09)

The EWW music widget now shows **time-synced rolling lyrics** from the LRC files
in `~/.local/share/lyrics/` (Apple-Music-style window: 3 lines above, active line
marked `▶`, 4 lines below), with automatic fallback to the old Genius plain text
(`~/Music/.lyrics/lyrics.txt`, still fed by `mpd-lyricsd`) for songs without an
`.lrc`.

**New files:**
- `/home/scripts/fetch-lyrics` — rewritten fetcher (Python, replaces the old
  `~/.local/bin/fetch-lyrics` bash script + the broken `syncedlyrics` dependency).
  Uses the LRCLIB API directly, with romanized→native Japanese title mappings,
  fuzzy search, and duration-based selection. Auto-converts Japanese lyrics to
  romaji via `pykakasi`. Also supports `--force`, `--romaji-only`, `--current`,
  `--dry-run`.
- `/home/scripts/.venv/` — python venv holding `pykakasi` (the systemd service
  runs the script through this interpreter via its shebang).
- `/home/scripts/lyrics-view` — per-second lyrics renderer (Python stdlib only):
  reads current MPD track + position, parses the matching `.lrc`
  (`~/.local/share/lyrics/<file>.lrc`, same layout as `~/Music`), prints the
  rolling window with the active line; falls back to
  `~/Music/.lyrics/lyrics.txt` when no `.lrc` exists.

**Modified:**
- `~/.config/eww/eww.yuck` — lyrics `defpoll` changed from
  `:interval "5s" "cat ~/Music/.lyrics/lyrics.txt"` to
  `:interval "1s" "/home/scripts/lyrics-view"`.
- `~/.config/systemd/user/fetch-lyrics.service` — `ExecStart` now
  `/home/scripts/fetch-lyrics` (was `~/.ashim/.local/bin/fetch-lyrics`).

**Result:** 181/187 songs have synced lyrics (was 169/187). The remaining 6 are
instrumentals (2× Oogway Ascends) and Nepali tracks with no synced source
(4 songs) — left for the weekly timer to keep retrying. All Japanese lyrics are
now romaji.

**Verified:** widget follows playback live (bbno$ "Ticking Away", Bartika Eam Rai
"Khai"); fallback path renders Genius text for instrumental tracks; Japanese
romaji conversion spot-checked (Soutaiseiriron, Miku Itō, B Komachi).

**Revert:**
```bash
# widget: point the lyrics defpoll back to the Genius file (interval 5s):
#   ~/.config/eww/eww.yuck: (defpoll lyrics :interval "5s" "cat ~/Music/.lyrics/lyrics.txt")
eww reload
# restore old fetcher unit
sed -i 's|ExecStart=/home/scripts/fetch-lyrics|ExecStart=/home/ashim/.local/bin/fetch-lyrics|' \
  ~/.config/systemd/user/fetch-lyrics.service
systemctl --user daemon-reload
# keep ~/.local/share/lyrics — the .lrc files are plain data and work with any player
rm -rf /home/scripts   # only if you also drop the new fetcher
```



---

## 13. Hover-expanding brightness pill with slider (2026-10-09)

The Waybar `backlight` pill was replaced by a **Quickshell overlay pill** that expands
smoothly on hover and reveals a draggable slider. Waybar can't host a slider (no slider
widget, no hover actions, no width animation), so the pill is drawn by Quickshell on the
Overlay layer, exactly on top of a transparent Waybar spacer that reserves its slot —
the same pattern as the calendar chip (§11).

**New files (`~/.config/quickshell/`):**
- `BrightnessPill.qml` — the pill. Idle it looks like the old backlight pill: black
  rounded pill, Nerd Font brightness glyph (the circle fills as brightness rises) plus
  `NN%` in teal `#2aa198`. On hover it animates width 70→200px (220ms OutCubic) leftward
  into the empty bar gap and fades in the slider; on mouse-leave (or after a drag) it
  collapses back after a 260ms grace period. Wheel over the pill = ±5%. Drag = live
  `brightnessctl set N%` (coalesced to one call per 30ms). It polls `brightnessctl -m`
  every second, so F2/F3 and any other brightness change show up live. An input mask
  (`Region`) restricts pointer input to the pill itself, so the invisible remainder of
  the surface never blocks clicks around it.

**Modified:**
- `~/.config/quickshell/VolumeSlider.qml` — added optional `trackColor` / `fillColor` /
  `knobColor` (defaults unchanged), a `dragging` readonly property and a `dragged(v)`
  signal (fires continuously while dragging; `moved(v)` still fires on release).
  Existing SoundPanel usage is unaffected.
- `~/.config/quickshell/qmldir` + `shell.qml` — component registered:
  `BrightnessPill 1.0 BrightnessPill.qml`.
- `~/.config/waybar/config` — in `modules-right`, `"backlight"` → `"custom/brightness"`
  (new module block: `{ "format": " ", "tooltip": false }`), same position in the bar.
  The old `"backlight"` module block is still in the file (unused) for reference.
- `~/.config/waybar/style.css` — new `#custom-brightness` rule: transparent,
  `min-width: 70px`, same margins as the old backlight module, so the slot (and
  mpris/tray to the left of it) stays reserved.
- `~/.config/waybar/config` — two width-stabilizing format tweaks so the bar can never
  reflow the pill slot: `network` `format-disconnected` → `󰤮` (wifi-off glyph),
  `format-ethernet` → `󰈀` (ethernet glyph); tooltips still show the details.

**Geometry (measured against the real bar):**
- The Quickshell pill sits at x 1574–1643 — pixel-identical to where the old Waybar
  backlight pill was (`rightMargin: 276` from the screen's right edge). Expanded, it
  grows to x 1444 while its right edge stays pinned.
- The Waybar spacer slot is exactly 70px wide (verified with a temporary red
  background), same row (y 6–29) as all other pills.

**IPC:** `qs ipc call brightness up|down|refresh|expand|collapse|set <int>`
(handy for scripts/keybinds; `set` takes an int 1–100).

**Verified 2026-10-09:** pill aligned to the slot (screenshot measurement); smooth
expansion caught mid-animation (70→169→198→200px frames, right edge pinned); collapse
on leave; real drag changes brightness live (user-confirmed); keyboard/`brightnessctl`
changes sync into the pill via the 1s poll; `qs ipc call brightness set 100` works;
spacer measures 70px; the Waybar restart is visually clean (neighbours unmoved).

**Notes:**
- The Waybar restart also applied the pending music-lyrics module from §12 (the old
  `mpd` pill is now the `music-lyrics` pill) and the center clock is still the
  calendar chip (§11) — both unchanged by this work.
- Quickshell still logs the pre-existing Qt 6.11→6.12 rebuild warning from §10; the
  current quickshell instance runs fine.
- Note (see §14/§15): the sound, bluetooth and wifi pills expand leftward into this
  pill's gap when hovered and push it left via PillBus.qml; its resting position is
  unchanged.

**Revert:**
```bash
# Quickshell widget
rm ~/.config/quickshell/BrightnessPill.qml
# remove the "BrightnessPill 1.0 BrightnessPill.qml" line from ~/.config/quickshell/qmldir
# remove "BrightnessPill {}" from ~/.config/quickshell/shell.qml
# (the VolumeSlider.qml additions are backwards compatible; harmless to keep)

# Waybar: swap "custom/brightness" back to "backlight" in modules-right and remove
# the "custom/brightness" module block; optionally restore network
# format-disconnected ("Disconnected ⚠ ") and format-ethernet ("{ifname}");
# style.css: remove the #custom-brightness rule block
pkill -x waybar; setsid -f waybar >/dev/null 2>&1
```

---

## 14. Hover-expanding volume pill with slider (2026-10-09)

The Waybar `pulseaudio` pill was replaced by a **Quickshell overlay pill** that expands
on hover and reveals a draggable slider — same pattern as the brightness pill (§13).
The slider always controls the **PipeWire default sink**: the exact same device the
keyboard volume keys drive (`pactl ... @DEFAULT_SINK@`). When two devices play at once,
only the default sink is affected, just like the keys.

**New files (`~/.config/quickshell/`):**
- `SoundPill.qml` — idle it looks like the old pulseaudio pill: black rounded pill,
  glyph + `NN%` in mauve `#a55377` (mute → 󰝟 in `#fb958b`; headphones/bluez → the
  FA headphone glyph; otherwise 󰕿/󰖀/󰕾 by level). On hover it animates width 64→154px
  (220ms OutCubic) **leftward** (right edge pinned at x=1719) and fades in the slider;
  on mouse-leave (or after a drag) it collapses back after a 260ms grace period.
  Wheel = ±5% (matches the keyboard step), drag = live sink volume (coalesced to
  ~30ms). Drag never unmutes.
- `PillBus.qml` — singleton that coordinates the pill row (generalized to the full
  cascade in §15).

**Modified:**
- `VolumeSlider.qml` — added optional `trackColor`/`fillColor`/`knobColor` (defaults
  unchanged), a `dragging` readonly property and a `dragged(v)` signal; SoundPanel
  usage unaffected.
- `qmldir` + `shell.qml` — `SoundPill` registered.
- `~/.config/waybar/config` — `"pulseaudio"` → `"custom/sound"` spacer in
  `modules-right` (old block kept for rollback).
- `style.css` — `#custom-sound` reserves the slot (`min-width: 64px`, transparent).

**IPC:** `qs ipc call volume up|down|set <int>` (`set` takes 0–100).

**Geometry:** pill sits at x 1655–1718 collapsed (`rightMargin: 201`), pixel-identical
to the old pulseaudio pill; expanded it grows to 154px leftward. Since §15 the
bluetooth and wifi pills push this pill further left while they expand (PillBus).

**Verified 2026-10-09:** slot alignment before/after the swap; expansion frames
(64→154, right edge pinned, brightness pushed with a constant 11px gap); emulated
drag applied (72%→47%) and volume restored exactly (raw 47183); external
`pactl set-sink-volume 55%` reflected live; mute toggle reflected (glyph + color);
collapse restores the exact baseline; `qs ipc call volume set` works.

**Revert:**
```bash
rm ~/.config/quickshell/SoundPill.qml
# remove "SoundPill 1.0 SoundPill.qml" from ~/.config/quickshell/qmldir and
# "SoundPill {}" from shell.qml
# Waybar: swap "custom/sound" back to "pulseaudio" in modules-right and remove the
# "custom/sound" module block; style.css: remove the #custom-sound rule
pkill -x waybar; setsid -f waybar >/dev/null 2>&1
```

---

## 15. Hover-expanding Bluetooth & Wi-Fi pills with name-on-hover (2026-10-09)

The Waybar `bluetooth` and `network` pills were replaced by Quickshell overlay pills
that expand **leftward** on hover and reveal the connected device name(s) / the
connected SSID. Same interaction as §13/§14, now as a full cascade: every pill
publishes its live expansion delta to `PillBus.qml`, and every pill to its left binds
its position shift to the sum of the deltas of the pills on its right (brightness ·
sound · bluetooth · wifi) — the gaps stay constant while the row slides (push, never
overlap).

**New files (`~/.config/quickshell/`):**
- `BluetoothPill.qml` — idle: same glyphs/colour as the old module (󰂱 connected /
  󰂯 on / 󰂲 off, `#81a1c1`). Hover reveals the connected device name(s) joined with
  ", " (e.g. "WH-1000XM4"); fallbacks: "No device" / "Off". Left-click opens the
  BluetoothPanel (`qs ipc call bluetooth toggle` — exactly what the Waybar module's
  on-click did).
- `WifiPill.qml` — idle: the same 5 signal glyphs as the old module (F092F…F0928),
  `#268bd2`; disconnected 󰤮 in `#fb958b`; ethernet 󰈀. Hover reveals the SSID
  (e.g. "TinTin_5"); fallbacks "Ethernet" / "Disconnected". Left-click opens the
  WifiPanel (`qs ipc call wifi toggle`).

**Icon fidelity details:**
- The Wi-Fi icon is picked by replicating Waybar 0.15's own pipeline: `/proc/net/wireless`
  RSSI → `strength = 100 − |dBm + 45| / 45 · 100` → `floor(strength / 20)` → the same
  5 format-icons. (NetworkManager's percentage is only the startup fallback.) This
  matters because Waybar's "punish too-strong signals" formula disagrees with NM's
  percentage at bucket edges — a one-off "wrong glyph" observation during testing was
  traced to exactly this (the old bar had shown the strongest-signal icon), not to a
  rendering bug.
- Glyphs render in `Material Design Icons` — the first font in the old Waybar pill's
  CSS stack — so shapes match the pre-Quickshell bar; ink placement measured within
  0.5px. Name text stays JetBrainsMono Nerd Font.
- Long names cap at 140px and elide with "…". Multiple connected BT devices are joined
  with ", ".

**Modified:**
- `PillBus.qml` — generalized: live `soundPush`/`btPush`/`wifiPush`, max values and
  the derived per-pill sums.
- `SoundPill.qml` / `BrightnessPill.qml` — windows widened so they can slide left by
  the pushes coming from their right; nothing else changed (resting positions
  pixel-identical to before).
- `~/.config/waybar/config` — `"bluetooth"`/`"network"` → `"custom/bluetooth"` /
  `"custom/wifi"` spacers in `modules-right` (old module blocks kept for rollback).
- `style.css` — `#custom-bluetooth` (`min-width: 27px`) and `#custom-wifi`
  (`min-width: 42px`) reserve the exact slots.

**Geometry:** bt slot 1729–1756 (`rightMargin: 164`), wifi slot 1766–1808
(`rightMargin: 112`); both expand leftward with right edges pinned. Measured slots
before and after the swap: identical, no reflow.

**Verified 2026-10-09:** collapsed layout pixel-identical after the Waybar swap;
hover frames for both pills (bt 27→110px, wifi 42→109px, left edges travel, gaps
constant at 10–11px through the whole cascade); collapse restores the exact baseline;
Wi-Fi → Bluetooth hand-off; pill clicks open the Bluetooth/Wifi panels (screenshots
captured) and `qs ipc call ... hide` closes them; glyph shape/placement compared
against pre-swap bar crops.

**Notes:**
- The old hover tooltips are gone by design; the info they showed now lives in the
  pill expansion itself.
- The only non-pushable neighbours are Waybar's mpris/tray (left of the brightness
  pill, usually hidden): when the cluster slides they can be transiently covered.
  The battery/power pills to the right never move.
- No disruptive tests were run (no Wi-Fi/BT disconnect of the live connection): the
  disconnected/ethernet/"no device" branches are code-reviewed paths; the panels
  themselves are the place to connect/disconnect.

**Revert:**
```bash
rm ~/.config/quickshell/BluetoothPill.qml ~/.config/quickshell/WifiPill.qml
# remove "BluetoothPill 1.0 ..." / "WifiPill 1.0 ..." from qmldir and
# "BluetoothPill {}" / "WifiPill {}" from shell.qml
# SoundPill.qml / BrightnessPill.qml: restore their implicitWidth and pill x bindings
# to the §13/§14 versions; PillBus.qml can stay or be deleted (only the pills use it)
# Waybar: swap "custom/bluetooth"→"bluetooth", "custom/wifi"→"network" in
# modules-right and remove the two spacer blocks; style.css: remove the
# #custom-bluetooth / #custom-wifi rules
pkill -x waybar; setsid -f waybar >/dev/null 2>&1
```

---

## 16. Music pill tooltip removed, power button → 💢 (2026-10-09)

Two small bar tweaks:

- `custom/music-lyrics` (the 🎵 lyrics pill in the left cluster) no longer shows the
  GTK hover tooltip: added `"tooltip": false` (custom modules default to showing
  their output text as a tooltip).
- `custom/powermenu` glyph `⏻` → `💢` (rendered in colour via Noto Color Emoji).
  The emoji's larger advance made the pill ~8px wider and pushed the whole
  right-hand cluster (battery + the spacers under the §14/§15 pills) 8px left, so
  `#custom-powermenu` horizontal padding was reduced 12px → 8px to keep the pill's
  old width — this restores the battery position and the uniform 10px gaps.

**Verified 2026-10-09:** hovering the music pill shows no tooltip (screenshot);
battery+power run back at x 1818–1913 (battery ink 1827–1865, same as pre-emoji);
all §14/§15 pill slots unchanged; battery cluster gaps 10px again.

**Revert:**
```bash
# ~/.config/waybar/config: remove the "tooltip": false line from custom/music-lyrics;
# change custom/powermenu "format" back to "⏻ "
# ~/.config/waybar/style.css: #custom-powermenu padding-left/right back to 12px
pkill -x waybar; setsid -f waybar >/dev/null 2>&1
```

---

## 17. Music pill: real play/pause state icon (2026-10-09)

The lyrics pill now shows the actual MPD state instead of a static ♪. Two bugs in
`~/.config/waybar/scripts/music-lyrics.sh` were behind it:

- The state was parsed from **line 1** of `mpc status` — but line 1 is the current
  song title; the `[playing]`/`[paused]` token is on line 2. The case therefore never
  matched and every track (playing or paused) fell through to the ♪ "stop" glyph.
  Fixed with `sed -n '2{s/^\[\([a-z]*\)\].*/\1/;p}'`.
- The icon now shows the **action the click will perform**: **⏸ bars while playing
  (press → pause), ▶ triangle while paused (press → play)**, ♪ when
  stopped/disconnected. Variables renamed to `ICON_WHILE_PLAYING`/`ICON_WHILE_PAUSED`
  and written as explicit `$'\uf04b'`-style escapes so they can't be mangled by
  editors again.

**Verified 2026-10-09:** playing → ⏸, `mpc pause` → ▶, `mpc play` → ⏸ again (live
pill screenshots at each step); `bash -n` syntax check passes.

**Revert:**
```bash
# ~/.config/waybar/scripts/music-lyrics.sh:
#  - restore: state=$(printf '%s\n' "$status" | head -n1 | sed -E 's/^\[([a-z]+)\].*/\1/')
#  - restore the original icon lines (literal glyphs: ICON_PLAY=U+F04C,
#    ICON_PAUSE=U+F04B, ICON_STOP=U+F001) and the case labels back to
#    $ICON_PLAY / $ICON_PAUSE
```

---

## 18. All Waybar-opened Quickshell panels share the pill background (2026-10-09)

Every Quickshell popover that can be opened from the Waybar now uses the same
`#040404` frame background as the Waybar pills (`Theme.bg`):

- `CalendarPanel.qml`: hover card `cardBg` `#1C1C1E` → `Theme.bg`; full popup
  `monthBg` `#0B0B0D` → `Theme.bg`. The clock chip was already `#040404`.
- `PowermenuPanel.qml`: frame `bg` `#11092D` → `Theme.bg`. Metrics, tile
  (`#281657`) / selection (`#DF5296`) colours, the two side bars and `barText`
  still match the rofi theme — only the window background changed.
- Sound / Wi-Fi / Bluetooth panels already used `Theme.bg`; unchanged.

**Verified 2026-10-09:** opened every panel and pixel-sampled screenshots —
calendar popup and hover-card frames `#040404` (border, header and event chips
unchanged); powermenu frame found at (560,371), 800x369, margin samples
`#040404`; sound/wifi/bluetooth frames `#040404` dominant with their accents
intact. Heads-up found while testing: in Quickshell 0.3.1,
`qs ipc call <target> show` only prints the target's function list and does not
open the panel (the CLI swallows the trailing `show` as its own subcommand);
`toggle` — what the pills/Waybar call — works fine.

**Revert:**
```bash
# ~/.config/quickshell/CalendarPanel.qml:
#   cardBg:  Theme.bg → "#1C1C1E"
#   monthBg: Theme.bg → "#0B0B0D"
# ~/.config/quickshell/PowermenuPanel.qml:
#   bg: Theme.bg → "#11092D"  (restore the rofi wording of the comment)
# Save the files; Quickshell hot-reloads automatically.
```

---

## 19. Dotfiles repo — full rice backup, setup.sh and AGENTS.md (2026-10-09)

All rice configs now live in `~/Programming/dotfiles` and are symlinked into
`~/.config`; assets are copied into the repo and symlinked to their destinations.
The repo is source of truth — edit there, it is live immediately.

- Config dirs: battery-alert, cava, dunst, eww, gtk-3.0, gtk-4.0, khal, mpd,
  mpd-lyricsd, ncmpcpp, quickshell, rmpc, rofi, sway, systemd, vdirsyncer,
  waybar, xkb (plus kitty/nvim from before).
- Assets added to the repo: `fonts/{SFPro,newwave}`,
  `icons/{vinyl.svg,Flat-Remix-Blue-Dark}`, `themes/Nightfox-*`,
  `wallpapers/newwave-1.png`, `bin/mpd-lyricsd`, `scripts/{fetch-lyrics,lyrics-view}`,
  `changes.md` itself.
- Gitignored: `mpd/mpd.db`, `mpd/state`, `ncmpcpp/error.log`,
  `systemd/user/*.wants/`, `vdirsyncer/*-password`, `scripts/.venv`.
- Repointed: eww.yuck lyrics defpoll and `fetch-lyrics.service` ExecStart now
  use `~/Programming/dotfiles/scripts/...`; fetch-lyrics shebang uses the
  repo venv.
- `setup.sh` (new): idempotent one-shot install for a new machine — packages
  (pacman + AUR), path repair for different home/repo paths, symlinks with
  backup, assets, lyrics venv, gsettings, systemd user units. Flags:
  `--skip-packages`, `--copy-assets`, `--no-restart`.
- `AGENTS.md` (new): the "make it consistent" playbook for agents — triggers,
  exclusion lists, scan/register procedure. A pointer lives at
  `~/Programming/AGENTS.md` so the trigger works outside the repo dir.

**New machine:** `git clone <repo> ~/Programming/dotfiles && ./setup.sh`

**Notes:**
- eww had to be restarted after the move — it keys its IPC socket to the
  canonical config path, so moving `~/.config/eww` breaks client↔daemon until
  restart (`pkill -x eww; setsid -f eww daemon; eww open example`).
- `~/.local/bin/fetch-lyrics` is a stale pre-rewrite script, superseded by
  `scripts/fetch-lyrics` (left on disk, unused).
- Still manual on a new machine: vdirsyncer passwords, Genius token, weather
  API key.

**Revert:** `git revert` the repo commits, or replace the `~/.config` symlinks
with real copies of the repo dirs; config history is preserved in git.

---

## 20. Quickshell music widget — replaces the eww widget (2026-10-09)

**Goal:** retire eww while folding the useful rmpc bits (library browsing,
queue, shuffle, cava visualizer) into one Quickshell widget. waybar untouched.

**New files** (in `quickshell/`, registered in `quickshell/qmldir`):
- `MusicState.qml` (singleton) — event-driven MPD state: one long-lived
  `mpc idleloop player options playlist update` process, short `mpc` queries
  per event, wall-clock elapsed anchor (no per-second polling). mpc 0.35
  quirks: `status` takes a POSITIONAL format (`-f` is ignored for it) and `|`
  is an alternation operator, so formats separate fields with `\n`.
- `MusicWidget.qml` — floating panel with the eww footprint and stacking
  (bottom-left, 2%/3% margins, 20% x 20%, Bottom layer, never takes focus).
  Cover art, title/artist, click-to-seek progress, prev/playpause/next,
  shuffle + repeat (cycles off -> all -> single), rolling lyrics, visualizer.
- `MusicStyle.qml` (singleton) — the eww palette (pink `#df6bac`, dark
  `#1A182C`) so the widget looks like the old one.
- `MusicButton.qml` — square 2px-bordered button; `active` inverts it.
- `LyricsView.qml` — QML port of `scripts/lyrics-view` (.lrc rolling window +
  `~/Music/.lyrics/lyrics.txt` fallback). Kills the old 2 s Python spawn
  (~57 ms CPU per run).
- `Visualizer.qml` + `cava.conf` — single long-lived cava (pipewire input, raw
  ascii, 24 fps), neon bars as batched Rectangles; frames are dropped after 2 s
  of silence, so idle costs no repaints. Reacts to any sink audio, not only mpd.
- `MusicPanel.qml` — library/queue popover above the widget (click the cover;
  IPC target `music`: toggle/library/queue/hide). Library sorted + searchable;
  left-click queues & plays, middle appends, right-click (queue) removes, plus
  a shuffle-all button.

**Changed:** `shell.qml` adds `MusicWidget {}` + `MusicPanel {}`; the Wi-Fi,
Bluetooth, Sound and Powermenu panels now hide the music panel when they open
(and the music panel hides them).

**Notes:** mpd exposes no MPRIS, so everything stays `mpc`-based. eww is still
installed and its sway autostart is untouched for now; its window was closed
(`eww open example` brings it back) and can be removed once the new widget has
proven itself. Measured: idle ~1% of one core, playing ~5% (cava 2.2% + 24 fps
bar updates) — under 1% of the 8-thread CPU; quickshell PSS +~10 MB.

---

## 21. rmpc de-autostarted; `$mod+m` unbound (2026-10-09)

- `sway/config`: removed the rmpc autostart (`kitty --class rmpc rmpc`) and its
  workspace-3 assign — the Quickshell music widget's library/queue panel
  replaces that role. rmpc stays installed; run `rmpc` from a terminal if
  wanted.
- `sway/config`: removed `bindsym $mod+m exec ...rofi/applets/bin/mpd.sh` (the
  music panel opens by clicking the widget's cover art).
- Takes effect on the next sway reload/restart; no reload was forced so the
  currently running rmpc window is left alone.

---

## 22. Satty screenshots; Print capture mode (2026-10-09)

- `sway/config`: replaced the broken `bindsym Print exec grim` (grim with no
  filename just errors) with direct KDE-style binds: `Print` = region
  (`slurp -d`), `Shift+Print` = full desktop, `$mod+Print` = focused window.
- `sway/scripts/screenshot.sh` (new): capture wrapper; pipes grim into satty
  with the arrow tool, `wl-copy` clipboard, and
  `~/Pictures/Screenshots/Screenshot_%Y-%m-%d_%H-%M-%S.png` save target.
  Enter = copy + save, Ctrl+Shift+S = save as, Esc = exit.
- `setup.sh`: added `satty` and `wl-clipboard` to `PACMAN_PKGS`.
- Reloaded sway. No repo links added: the script lives inside the already
  symlinked `sway/` config dir.

---

## 23. Wi-Fi panel: Forget saved networks, auto-drop failed passwords, right-click copy (2026-10-09)

**Fixed:** entering a wrong password used to save a NetworkManager profile anyway
(`connectWithPsk` → `AddAndActivateConnection` saves even when activation fails),
and the panel offered no way to remove it — clicking the SAVED entry just retried
the bad PSK forever.

- `quickshell/WifiRow.qml` — new `Forget` text button on every known row (saved
  and connected), styled like the Bluetooth rows; calls `network.forget()` so the
  profile is deleted and the network returns to AVAILABLE (clicking it prompts for
  the password again).
- `quickshell/WifiPanel.qml` — when a password attempt started from the prompt
  fails, the profile it just created is auto-`forget()`ed, the input is cleared
  and refocused, and the error stays on screen for an immediate retry; nothing is
  left saved with a wrong password.
- Right-click any Wi-Fi entry copies its stored password to the clipboard —
  deliberately silent (no toast, no highlight). `quickshell/wifi-copy-password.sh`
  (new, executable, lives in the already symlinked config dir) matches the profile
  by SSID, reads the secret with `nmcli -s` and pipes it to `wl-copy` via stdin so
  it never appears in process arguments; on any failure the clipboard is not
  touched.

**Verified 2026-10-09:** `Forget` renders on CONNECTED and SAVED rows and not on
AVAILABLE rows (screenshot); copy and forget exercised end-to-end through the
panel with a throwaway profile (SSID matched to a visible AP, PSK `wrongpass`):
clipboard received exactly the dummy PSK, then the profile disappeared from
`nmcli connection show`; QML reloads clean. No real network or saved profile was
touched.

**Revert:**
```bash
rm ~/.config/quickshell/wifi-copy-password.sh
# WifiRow.qml: remove the right-click MouseArea and the passwordCopyRequested signal
# WifiPanel.qml: remove copySavedPassword(), the onPasswordCopyRequested lines and
# the forget()/clear lines in onConnectionFailed
pkill -x quickshell; setsid -f quickshell --no-duplicate
```

---

## 24. Music widget rebuilt to the original eww proportions (2026-10-09)

The first Quickshell card was sized from the literal `20% x 20%` eww geometry —
but eww grows its window to fit content, so the real widget was much bigger and
the first version looked tiny. Rebuilt against a screenshot of the original:

- Window: **466 px wide**, content-driven height (~520 px), **dark `#1A182C`
  rounded backdrop** with 30 px padding; same bottom-left 2 %/3 % anchor and
  Bottom layer (never takes focus).
- Card: ~405 px wide pink card; **150 px cover**; 13 px title/artist in 2 px
  bordered boxes (headings still omitted); full-width control row with five
  buttons (prev/play-pause/next/shuffle/repeat, 26 px glyphs); thin
  click-to-seek progress bar.
- Lyrics: below the card on the backdrop, 13 px, **lavender `#A79BC8`**
  (sampled from the original), active line pink with `▶`; ~9 visible lines.
- Visualizer: intentionally left out for now (files kept: `Visualizer.qml`,
  `cava.conf`). quickshell now idles at ~0 % CPU.
- Fixed: cover extraction was missing `-i` in the ffmpeg command, so every
  track showed the fallback art; real covers now extract on every track change.
- `MusicStyle.qml` holds the measured layout constants; `MusicPanel.qml` got
  the matching width (466) and sits directly above the widget.

---

## 25. Battery pill + Low Power Mode panel (2026-10-09)

**Goal:** the battery icon becomes a Quickshell pill like wifi/bluetooth/sound
(icon-only, percentage on hover) and clicking it opens a popover with a
working **Low Power Mode** switch.

**New files:**
- `quickshell/BatteryState.qml` (singleton) — UPower-backed battery state plus
  the old Waybar battery glyphs and `#battery` palette. Quickshell's UPower
  `percentage` is 0–1 (the service scales upower's 0–100 by 0.01), so it is
  multiplied by 100. Health/capacity are read from the real laptop battery in
  `UPower.devices` (`isLaptopBattery`), because `UPower.displayDevice` is a
  composite without `Capacity`/`EnergyFull`.
- `quickshell/BatteryPill.qml` — overlay on the new `custom/battery` spacer;
  expands LEFTWARD on hover (icon-only → `󰁹 71%`), snug **27 px** collapsed
  width like the bluetooth pill. The right edge reaches x=1883 (6 px into
  the powermenu's black padding, up to the 💢 ink) and the right corners are
  square (old module was `border-radius: 8px 0 0 8px`), so the icon sits
  optically centred between the wifi gap and the emoji. Publishes
  `batteryPush` / `batteryMaxPush` to PillBus.
- `quickshell/BatteryPanel.qml` — popover (IPC target `battery`:
  toggle/show/hide): status, time left/to full, power draw, health
  (`68% · 30.7 Wh`) and the **Low Power Mode** row with a `ToggleSwitch`.
  Joins the mutual-hide ring with wifi/bluetooth/sound/powermenu/music.
- `bin/power-mode` (→ `~/.local/bin/power-mode`, registered in setup.sh
  `EXTRA_LINKS`) — `on`: boost off + all cores capped to 1.4 GHz (this CPU's
  lowest P-state; `scaling_min_freq` is already 1.4 GHz); `off`: 2.1 GHz +
  boost back, governor `schedutil`; `status` reads sysfs. The panel drives it
  with `sudo -n`; setup.sh now installs a scoped
  `/etc/sudoers.d/rice-power-mode` rule (NOPASSWD for just this script) so a
  fresh machine works without prompts.

**Changed:**
- `waybar/config`: native `battery` module → invisible `custom/battery`
  spacer; clicks go through the pill (`qs ipc call battery toggle`).
- `waybar/style.css`: `#battery` rules (and the unused `blink` keyframes)
  removed, `#custom-battery` spacer added (`min-width: 27px`).
- `quickshell/PillBus.qml`: `batteryPush`/`batteryMaxPush` added; sound/
  brightness push sums include it. `WifiPill.qml`/`BluetoothPill.qml` now
  bind position + window slack to their cascaded sums so the battery pill
  pushes the row left into perfect gaps while expanding.
- The snug battery slot moves everything left of it right by 36 px, so the
  wifi/bluetooth/sound/brightness pills got matching `rightMargin` updates
  (112→76, 164→128, 201→165, 276→240) keeping them pixel-aligned with their
  Waybar spacers.
- `WifiPill.qml`: the signal glyphs no longer carry the old Waybar trailing
  space (the pill centres its content, so the space pushed the ink 4 px left);
  the wifi icon is now optically centred (15 px air on both sides).
- Each existing panel hides the battery panel and vice versa.
- `setup.sh` + `AGENTS.md`: script link, `BatteryPanel.qml` in
  `PATH_FIX_FILES`, asset-map row, sudoers step.

**Notes:** `power-profiles-daemon` would be a no-op on this CPU (acpi-cpufreq,
no amd-pstate/EPP/platform_profile), hence the direct cpufreq helper. Low
Power Mode lives in sysfs, so it resets on reboot and the panel always shows
the real state. Battery health (68 %) is UPower's `Capacity` = energy-full /
energy-full-design (30.68/45 Wh, 1516 cycles) — not a UI artifact.

**Verified:** pill and row positions re-measured with screenshots (all four
neighbouring pills shift exactly +36 px, gaps intact); pixel-peeped glyph
centring — wifi 15/15 px air, battery 9/10 px between its left edge, the
icon and the emoji; hover expands and cascades pushes (28 px); click opens
the panel; the toggle flips sysfs through sudo (journal +
`boost`/`scaling_max_freq` checks); health row reads the real battery;
panels hide each other; no QML errors in `qs log`.

**Revert:** `git show HEAD:waybar/config waybar/style.css` to restore the
battery module, remove the three QML files + `bin/power-mode`, revert the
PillBus/panel/shell/qmldir edits, and delete
`/etc/sudoers.d/rice-power-mode`.

---

## 26. Low Power Mode tier 2 — ryzenadj APU power caps (2026-10-09)

**Goal:** stack a second, stronger savings tier on the battery panel's Low
Power Mode switch.

- `bin/power-mode` grows modes: `max` (tier 1 + APU caps), `limit-on`,
  `limit-off`, `limit-status`. Tier 2 caps the whole APU (CPU + Vega iGPU)
  at 6/8/10 W (STAPM / PPT slow / PPT fast) via `ryzenadj`; the stock limits
  (15/20/25 W) are captured to `/run/power-mode/ryzenadj-defaults` on first
  enable and restored by `limit-off`/`off`. Everything is volatile — a
  reboot resets both the limits and the state file to firmware defaults.
- `BatteryPanel.qml`: the Low Power Mode card now has two stacked rows
  ("Low Power Mode" + "Power Limit") with a divider. Tier 2 implies tier 1;
  turning tier 1 off also drops tier 2. Same sudo'd helper, so the existing
  scoped sudoers rule covers the new modes.
- Packages: `ryzenadj-git` + `ryzen_smu-dkms-git` (AUR),
  `dkms`/`linux-headers` (repo). Without the SMU module ryzenadj can write
  limits but not read the PM table (no capture/verify), so
  `/etc/modules-load.d/rice-ryzen-smu.conf` autoloads it; `setup.sh` now
  installs both the packages and that file.

**Measured** (8-thread `yes` load, battery `power_now`): tier 1 only
~9.2–9.5 W (package ~8 W); tier 1+2 ~8.0–8.6 W (STAPM avg ~5.9 W). Tier 2
also bounds GPU-heavy loads. Frequency-bound python loop: 12.4 s with tier 1
vs 7.1 s uncapped — the caps do bite.

**Verified:** panel clicks flip both tiers end-to-end (journal + PM-table
checks); `limit-off` restores the captured stock limits exactly; final state
left at tier 1 on, tier 2 off.

**Revert:** drop the tier-2 code paths from `bin/power-mode`, the second
row in `BatteryPanel.qml`, and (if unwanted) the packages +
`/etc/modules-load.d/rice-ryzen-smu.conf`.


---

## 27. Sound pill glyphs were mangled by 5-digit `\u` escapes (2026-10-09)

**Bug:** the sound pill's four volume glyphs in `SoundPill.qml` were written as
five-hex-digit JS escapes (`"\uf075f"` etc.). JS `\uXXXX` consumes exactly 4 hex
digits, so each string silently became an old FontAwesome glyph plus a literal
character: mute → fa-comment + `f`, low → fa-times-circle + `f`, medium →
fa-check-circle + `0`, high → fa-times-circle + `e`. With the sink muted, the
Waybar slot showed a speech bubble + `f` instead of 󰝟.

**Fixed:**
- `quickshell/SoundPill.qml` — plane-15 codepoints now use surrogate pairs
  (same convention as `MusicWidget.qml`): `\udb81\udf5f` mute, `\udb81\udd7f`
  low, `\udb81\udd80` medium, `\udb81\udd7e` high; comment added to the glyph
  property warning about 5-digit escapes.
- `waybar/config` — same latent bug in the `custom/discord` and
  `custom/qbittorrent` exec icons (jsoncpp also truncates `\u` at 4 digits):
  `\udb81\ude6f` (md-discord), `\udb81\uddd2` (md-card-account-details).

**Verified:** quickshell hot-reload; screenshots of all four states (cycled
volume via `pactl`, raw volume 91701 / muted state restored exactly) match the
rendered reference glyphs; `waybar/config` re-parses as valid JSON.

**Revert:** `git revert <this commit>`.

---

## 27. Volume capped at 100% (no more runaway over-amplification) (2026-10-09)

**Bug:** nothing stopped volume from climbing past 100%: the Sway volume keys
ran `pactl set-sink-volume +5%` (which happily steps past 100% — the desktop
had drifted to 140%), and the sound pill's wheel / `qs ipc call volume` paths
had no ceiling either.

**Fixed:**
- `sway/config` — `XF86AudioRaiseVolume` now runs
  `wpctl set-volume -l 1.0 \@DEFAULT_AUDIO_SINK@ 5%+` (WirePlumber's limit);
  the lower key uses the same tool (`5%-`). wpctl reports/accepts the same
  1.0 = 100% scale as pactl.
- `quickshell/SoundPill.qml` — `applyVolume()` clamps to [0, 1], covering the
  wheel nudge, the slider drag and `qs ipc call volume up|down|set`; the
  displayed fraction/percent clamp to 100% too, so even an externally
  over-amplified sink shows 100% instead of an inflated number.

**Verified:** from 95% a `5%+` lands exactly at 100% and repeats stay at 100%;
`qs ipc call volume set 150` clamps to 100%; normal 30% → 40% stepping still
works; pill screenshot shows `100%`. The sink (previously at 140%) is reset
to 100%.

**Revert:** `git revert <this commit>`.

---

## 28. Brightness and sound pills are icon-only (drop the `%` readout) (2026-10-09)

**Change:** the last two pills that still printed a `%` value now show just
the level glyph, matching the snug bluetooth/battery chips and the native
Waybar `format: "{icon}"` + `format-icons` pattern (level → glyph, no text).
The glyph mapping itself was already in place (9 circle-fill brightness
glyphs, speaker low/med/high + mute) — only the trailing readout is gone.

- `quickshell/BrightnessPill.qml` — `pct` Text removed; `collapsedWidth`
  70→27, `expandedWidth` 200→172 (trimmed by the removed 23px text + 5px
  spacing so the expanded slider keeps its 25px padding), `rightMargin`
  240→203 (37px rightward shift from the sound slot below it).
- `quickshell/SoundPill.qml` — `pct` Text removed; `collapsedWidth` 64→27,
  `expandedWidth` 154→118 (keeps the expanded row's 8px padding);
  `rightMargin` 165 unchanged (right edge stays pinned at x=1755).
- `waybar/style.css` — `#custom-brightness` / `#custom-sound` `min-width`
  70px / 64px → 27px; the tray and mpris modules to their left shift right
  by 80px to close the gap (Waybar packs `modules-right` from the edge).
- `waybar/config` — the unused native `backlight` / `pulseaudio` blocks now
  use `"format": "{icon}"` (were `{icon} {percent}%` / `{icon}{volume}%`),
  keeping the dead config in sync with the design.

**Verified:** Waybar SIGUSR2 + Quickshell hot reload; screenshot-measured
pill runs: brightness 1690..1717 (w 27), sound 1728..1755 (w 27) — the 11px
gap to each other and to bluetooth is intact; everything right of brightness
unchanged (bt 1765..1792, wifi 1802..1844, battery+powermenu 1856..1913).
Expanded brightness (172px) has symmetric 27/27px air around glyph+slider;
expanded sound measured 118px wide with a 91px push and the same 11px gap.
Glyph ink sits 9/8px from the pill edges in both collapsed chips (1px
optical rounding). No QML errors in `qs log`.

**Revert:** `git revert <this commit>`.

---

## 29. Calendar hover card closes with no delay (2026-10-09)

**Change:** the quickshell clock chip's hover card (CalendarPanel.qml) used a
500 ms `closeTimer` grace period before hiding after the pointer left the chip
or the agenda card — that is what made the "time panel" linger after
un-hovering. `closeTimer.interval` is now `0`: the card hides on the next
event-loop tick (visually instant).

The zero-interval timer is still cancellable in the same tick, so moving the
pointer from the clock straight onto the agenda card still cancels the close
(the agenda stays scrollable) — only the visible linger is gone. The full
popup (opened by click) and all other panels are untouched.

**Verified:** quickshell hot reload (`Reloading configuration... Configuration
Loaded`); no QML errors in `qs log` (only the pre-existing textinput warnings).
Pointer-hover feel left for manual confirmation — no pointer-automation tool
(ydotool/wtype) on this machine.

**Revert:** set `closeTimer.interval` back to `500` in
`quickshell/CalendarPanel.qml` (or `git revert <this commit>`).

---

## 30. Pill row hover hold — quick switches keep the pill you left open (2026-10-09)

**Problem:** each pill collapsed on its own 260 ms timer even when the pointer
had already moved onto a neighbour. Collapsing a pill pushes the row (the
pills left of it slide right), so a quick wifi → bluetooth switch slid
bluetooth out from under the cursor — the hover was lost and the row
flickered/jumped.

**Change — one shared hover hold for the whole pill row:**
- `quickshell/PillBus.qml` — each pill publishes `hoverBrightness` /
  `hoverSound` / `hoverBt` / `hoverWifi` / `hoverBattery`; `hoverAny` gates a
  single shared **500 ms** idle timer that bumps `collapseTick` only after
  the *whole* row has been left.
- `quickshell/{BrightnessPill,SoundPill,BluetoothPill,WifiPill,BatteryPill}.qml`
  — per-pill `closeTimer`s removed. Hover only expands; collapse happens off
  `collapseTick`, and only if the pill isn't hovered. Sound/brightness count
  an active slider drag as engaged, so a drag can never be collapsed
  mid-drag, and releasing it outside the pill resumes the normal grace.
- Behaviour: switching quickly between pills (any pair, any direction —
  battery→wifi, wifi→bt, bt→sound, sound→brightness, …) keeps every
  already-expanded pill open while the pointer is on one of them; leaving the
  row collapses them all together in one synchronized animation, so the gaps
  stay exact. A pill that already fully collapsed stays collapsed
  (re-expanding would shift the row under the cursor — the same flicker this
  avoids).

**Verified:** `PillBus` exercised with a standalone `qs -p` test config using
the pills' exact patterns (`Binding` publishing hover, `Connections` on
`collapseTick`): quick switch → no collapse broadcast; no collapse at 200 ms
after leaving; collapse broadcast after the 500 ms grace; hover holds a
running timer; collapse resumes after the hold is released — 5/5 pass. Hot
reload clean ("Configuration Loaded", no QML errors); resting bar screenshot
unchanged. The pointer-level hover sweep itself is left for manual
confirmation (no pointer-automation tool on this machine, same as §29).

**Revert:** `git revert <this commit>`.
