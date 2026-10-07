# AGENTS.md — keeping the rice consistent

This repo (`~/Programming/dotfiles`) is the **source of truth** for the New Wave
Sway rice on this machine. `setup.sh` recreates the whole setup on a new PC.

**Trigger phrases:** "make it consistent", "sync the rice", "rice check" —
when the user says any of these, run the consistency check below.

## Golden rules

1. Every rice config dir lives in this repo and is **symlinked** into
   `~/.config/<name>` (never a real directory).
2. Every asset used by the rice (fonts, icons, themes, wallpapers, binaries,
   scripts) lives in this repo and is **symlinked** to its destination;
   every one must be registered in `setup.sh` → `EXTRA_LINKS`.
3. Never commit secrets or runtime state. Known-ignored: `vdirsyncer/*-password`,
   `mpd/mpd.db`, `mpd/state`, `systemd/user/*.wants/`,
   `scripts/.venv/`. Check `git status` after each change; add new junk to
   `.gitignore` instead of committing it.
4. This repo is **private**. Never make it public without removing: SF Pro fonts
   (Apple licensing), the Genius token, emails/calendar IDs in `vdirsyncer/config`.
5. If unsure whether something is rice or a personal app → **ask the user**.

## Exclusions (never track these)

- Personal apps: `discord`, `zen`, `qBittorrent`, `opencode`, `nemo`,
  `matplotlib`, `github-copilot`, `Code`, `yay`, `zed`, `obsidian`,
  `inkscape`, `Recordly`
- Machine-local / junk: `dconf`, `go`, `pulse`, `procps`, `pavucontrol.ini`,
  `mimeapps.list`, `raffi` (not even installed)
- Data (not config): `~/.calendars`, `~/.contacts`, `~/Music`,
  `~/.local/share/lyrics`, `~/.local/share/vdirsyncer`
- Backups: `~/.newwave-backup`, `~/.rice-backup-*`

## Consistency check procedure

### 1. Repo hygiene
```bash
cd ~/Programming/dotfiles
git status                     # must be clean; fix or catalogue first
git pull
```

### 2. Config scan — find rice configs outside the repo
```bash
ls -la ~/.config               # entries that are NOT symlinks into the repo
```
Classify each non-symlink:
- in the exclusion list → leave it
- looks rice-related (new bar/widget/music/theme/etc.) → include it (step 4)
- unknown → ask the user

Also scan for newly created dotfiles the rice might use: `~/.config/*`, `~/.xkb`,
`~/.gtkrc-2.0`, anything referenced by existing configs (step 3).

### 3. Asset scan — find rice files outside `~/.config`
- Grep existing configs for external references:
  ```bash
  grep -rnE '/home/|~/|\$HOME' sway waybar rofi eww quickshell mpd mpd-lyricsd \
    rmpc systemd khal vdirsyncer gtk-3.0 scripts 2>/dev/null | grep -v '\.venv'
  ```
  Every referenced path outside the repo is a candidate asset.
- Known asset homes — check for new entries:
  `~/.local/share/fonts`, `~/.local/share/icons`, `~/.themes`,
  `~/Pictures/wallpapers`, `~/.local/bin`, `/home/scripts` (if it exists)
- Compare against `setup.sh`'s `EXTRA_LINKS` and repo dirs.

### 4. Include a new config dir
```bash
mv ~/.config/<name> ~/Programming/dotfiles/<name>
ln -s ~/Programming/dotfiles/<name> ~/.config/<name>
```
- Add `<name>` to `CONFIG_DIRS` in `setup.sh`.
- Check for runtime junk that appears inside (e.g. dbs, logs, caches):
  `git status` → add patterns to `.gitignore` for anything the app rewrites.
- If any files inside hardcode `/home/ashim` paths, add them to
  `PATH_FIX_FILES` in `setup.sh` (only needed for plain-text files).

### 5. Include a new asset
- Move/copy it into the right repo dir: `fonts/`, `icons/`, `themes/`,
  `wallpapers/`, `bin/`, `scripts/`.
- Register in `setup.sh` → `EXTRA_LINKS` as `"path/inside/repo|$HOME/destination"`.
- Symlink it into place (mirror what `setup.sh` would do):
  `ln -s ~/Programming/dotfiles/<path> <destination>`
- Fonts: run `fc-cache -f` and verify with `fc-list | grep -i <name>`.
- Scripts: `chmod +x`, and check what interpreter they need (venv → recreate
  under `scripts/.venv`, which is gitignored).

### 6. Verify
```bash
readlink -f ~/.config/<name> ~/.themes/<theme> ~/.local/share/fonts/<font>   # resolves into repo?
sway -C -c ~/.config/sway/config                                             # config still valid
git status                                                                   # only intended changes
```
Restart the affected app (waybar/quickshell) or `swaymsg reload`.

### 7. Ship
- `git add -A && git commit -m "rice: <what changed>" && git push`

## Asset map (source in repo → destination)

| Repo path | Destination |
|---|---|
| `bin/mpd-lyricsd` | `~/.local/bin/mpd-lyricsd` |
| `bin/power-mode` | `~/.local/bin/power-mode` |
| `bin/quickshell-watchdog` | `~/.local/bin/quickshell-watchdog` |
| `bin/waybar-output` | `~/.local/bin/waybar-output` |
| `bin/bluetooth-autoconnect` | `~/.local/bin/bluetooth-autoconnect` |
| `icons/vinyl.svg` | `~/.local/share/icons/vinyl.svg` |
| `icons/Flat-Remix-Blue-Dark` | `~/.local/share/icons/Flat-Remix-Blue-Dark` |
| `fonts/SFPro` | `~/.local/share/fonts/SFPro` |
| `fonts/newwave` | `~/.local/share/fonts/newwave` |
| `fonts/maple-mono` | `~/.local/share/fonts/maple-mono` |
| `gtkrc-2.0` | `~/.gtkrc-2.0` |
| `themes/Nightfox-*` | `~/.themes/Nightfox-*` |
| `wallpapers/newwave-1.png` | `~/Pictures/wallpapers/newwave-1.png` |
| `scripts/{fetch-lyrics,lyrics-view}` | used in place (eww + systemd units point at the repo) |

## New machine setup

```bash
git clone git@github.com:ashimparajuli04/dotfiles.git ~/Programming/dotfiles
cd ~/Programming/dotfiles && ./setup.sh        # add --skip-packages if already installed
```
- On a machine with a different username/home, `setup.sh` rewrites the hardcoded
  paths in `PATH_FIX_FILES` and re-targets the `gtk-4.0` symlinks. Those
  rewrites are **machine-local** — do not commit them.
- Still manual after setup: vdirsyncer passwords, Genius token, weather API key.

## setup.sh flags

| Flag | Effect |
|---|---|
| `--skip-packages` | skip pacman/AUR installs |
| `--copy-assets` | copy assets into place instead of symlinking |
| `--no-restart` | don't reload sway at the end |

`PACMAN_PKGS`, `AUR_PKGS`, `CONFIG_DIRS`, `EXTRA_LINKS`, `PATH_FIX_FILES` are the
single source of truth, and this file documents the procedure that keeps them
up to date.
