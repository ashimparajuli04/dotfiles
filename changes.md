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
