# debrice

**debrice** is a port of [Luke Smith's LARBS](https://larbs.xyz) to
**Debian 13 (Trixie)**, with [sxwm](https://github.com/uint23/sxwm) replacing
dwm, [sxbar](https://github.com/uint23/sxbar) replacing dwmblocks,
**Brave** replacing Librewolf, and a **complete TeX Live** installed by
default. Luke's dotfiles (voidrice), Luke's keybindings, Luke's st/dmenu
builds and Luke's `~/.local/bin` scripts are all here.

## Installation

On a fresh Debian 13 netinstall (as root, with internet):

```sh
curl -LO https://raw.githubusercontent.com/TristenN96/debrice/master/debrice.sh && bash debrice.sh
```

The script asks for a username and password, creates the user (sudo group),
and installs everything unattended. When it finishes, log in as that user on
tty1 and the graphical session starts via `startx` automatically. Re-running
the script is safe: apt sources/keys are never duplicated, and any config it
would overwrite is first backed up to `~/.config/debrice-backup-<timestamp>/`.

Always invoke it with `bash` (never `sh`; if launched via `sh` it re-execs
itself with bash). For unattended runs, skip all prompts with:

```sh
DEBRICE_ASSUME_YES=1 DEBRICE_USER=myname DEBRICE_PASSWORD=mypass bash debrice.sh --yes
```

If stdin is not a TTY and `--yes` was not given, the script refuses to run
instead of hanging on an invisible prompt.

## What you get

- X11 + sxwm (built from source) with all of Luke's dwm keybindings ported
  (see the cheat sheet below; `super` is the mod key)
- sxbar status bar running Luke's `sb-*` statusbar scripts
- st and dmenu built from Luke's own repos, slock from suckless.org
- Luke's voidrice dotfiles deployed verbatim except the documented
  adaptations in [CHANGES-FROM-VOIDRICE.md](CHANGES-FROM-VOIDRICE.md)
- Brave (stable) from Brave's official apt repository
- Full TeX Live + latexmk + biber; groff for the `super+F1` cheat sheet
- mutt-wizard + neomutt/isync/msmtp/pass for terminal email
- Everything else from LARBS's manifest: lf, neovim, mpv, mpd/ncmpcpp,
  newsboat, zathura, nsxiv, maim, yt-dlp, fzf, picom, dunst, and more

## Keybindings (cheat sheet)

All bindings live in [static/sxwmrc](static/sxwmrc). **Mod = Super (the
Windows key).** Capital letters mean Shift is held (`Mod+T` = super+shift+t).
Press `super+F1` on an installed system to see this as a PDF.

### Basics

| Binding | Action |
|---|---|
| `Mod+Enter` | Spawn terminal (st) |
| `Mod+q` | Close window |
| `Mod+d` | dmenu (run commands/programs) |
| `Mod+j` / `Mod+k` | Cycle focus through the stack |
| `Mod+J` / `Mod+K` | Rotate windows down/up the stack (into master) |
| `Mod+h` / `Mod+l` | Shrink/grow master width |
| `Mod+z` / `Mod+x` | Increase/decrease gaps |
| `Mod+Shift+Space` | Toggle window floating (Mod+drag to move, Mod+right-drag to resize, Mod+Shift+drag to swap) |
| `Mod+b` | Toggle the status bar |
| `Mod+F5` | **Reload sxwmrc** (see note below) |

### Layouts

sxwm has a single master-stack tiled layout, plus:

| Binding | Action |
|---|---|
| `Mod+f` | Fullscreen the focused window |
| `Mod+F` | Global floating mode |
| `Mod+U` | Monocle (all windows stacked fullscreen) |

dwm's other layouts (bstack, spiral, dwindle, deck, centered master…) do not
exist in sxwm — see [DIFFERENCES.md](DIFFERENCES.md).

### Workspaces (dwm "tags")

| Binding | Action |
|---|---|
| `Mod+1` … `Mod+9` | Go to workspace N |
| `Mod+Shift+1` … `Mod+Shift+9` | Send window to workspace N |
| `Mod+Tab` or `Mod+\` | Previous workspace |
| `Mod+g` / `Mod+;` | Cycle to left/right workspace (also `Mod+PgUp`/`Mod+PgDn`) |
| `Mod+Left` / `Mod+Right` | Focus other monitor |
| `Mod+Shift+Left` / `Mod+Shift+Right` | Move window to other monitor |

### Scratchpads (dropdown terminal/calculator)

sxwm scratchpads are registered from the focused window, then toggled:

| Binding | Action |
|---|---|
| `Mod+Shift+Enter` | Show/hide dropdown terminal |
| `Mod+Ctrl+Enter` | Register focused window as dropdown terminal |
| `Mod+Alt+Enter` | Spawn a fresh dropdown terminal (`st -n spterm -g 120x34`) |
| `Mod+'` | Show/hide dropdown calculator |
| `Mod+Ctrl+'` | Register focused window as dropdown calculator |
| `Mod+Alt+'` | Spawn a fresh calculator (`st -n spcalc … -e bc -lq`) |

First time: `Mod+Alt+Enter` (spawn), `Mod+Ctrl+Enter` (register), then
`Mod+Shift+Enter` toggles forever.

### Programs

| Binding | Action |
|---|---|
| `Mod+w` | Web browser (**Brave**) |
| `Mod+W` | nmtui (networking) |
| `Mod+e` / `Mod+E` | neomutt (email) / abook (contacts) |
| `Mod+r` / `Mod+R` | lf (files) / htop (processes) |
| `Mod+n` / `Mod+N` | vimwiki (notes) / newsboat (RSS) |
| `Mod+m` | ncmpcpp (music) |
| `Mod+c` | profanity (XMPP chat) |
| `Mod+D` | passmenu (passwords) |
| `Mod+grave` | dmenuunicode (emoji picker) |
| `Mod+Insert` | Type a saved snippet |

### System

| Binding | Action |
|---|---|
| `Mod+BackSpace` or `Mod+Q` | sysact: lock/leave/reload/hibernate/sleep/reboot/shutdown |
| `Mod+F1` | This document, as a PDF |
| `Mod+F2` | Tutorial videos menu |
| `Mod+F3` | Display selection |
| `Mod+F4` | pulsemixer (audio control) |
| `Mod+F6` | torrent client / `Mod+F7` toggle daemon |
| `Mod+F8` | mailsync |
| `Mod+F9` / `Mod+F10` | Mount / unmount drives |
| `Mod+F11` | Webcam view |
| `Mod+F12` | Re-run keyboard remaps |

### Audio

| Binding | Action |
|---|---|
| `Mod+-` / `Mod+=` | Volume down/up (Shift for bigger steps) |
| `Mod+M` | Mute toggle |
| `Mod+p` / `Mod+P` | Play-pause / force-pause everything |
| `Mod+.` / `Mod+,` | Next / previous track |
| `Mod+>` / `Mod+<` | Toggle repeat / restart track |
| `Mod+]` / `Mod+[` | Seek +10s / −10s (Shift: ±60s) |

### Recording & screenshots

| Binding | Action |
|---|---|
| `Print` | Screenshot (full screen) |
| `Shift+Print` | Screenshot menu (maimpick) |
| `Mod+Print` | Recording menu (dmenurecord) |
| `Mod+Delete` or `Mod+Shift+Print` | Kill recording |
| `Mod+ScrollLock` | Toggle screenkey |

### Hardware (XF86) keys

Volume mute/up/down, mic mute, media play/pause/stop/prev/next/rewind/
forward, brightness up/down, calculator, sleep (suspend), WWW (Brave),
terminal, screensaver (slock + display off), task pane (htop), mail
(neomutt), "my computer" (lfub), display-off and touchpad toggle/on/off all
do what you'd expect.

### The super+r note

Upstream sxwm hot-reloads its config with `super+r`. In debrice that key is
Luke's `st -e lfub`, and Luke's bindings win, so **hot-reload lives on
`super+F5`** — the same key dwm used for its xrdb refresh. The "renew sxwm"
option in the sysact menu (`Mod+BackSpace`) sends it too.

## Differences from LARBS

- **sxwm replaces dwm** — one tiled layout (plus monocle and global
  floating), workspaces instead of bitmask tags, no zoom/sticky/multi-tag,
  native scratchpads with a create-then-toggle model. Every one of the 161
  bindings in Luke's config.h is either ported or accounted for in
  [DIFFERENCES.md](DIFFERENCES.md), and `scripts/check-binds.sh` proves it.
- **sxbar replaces dwmblocks** — same `sb-*` scripts, refreshed by intervals
  instead of signals; bar click actions are gone (sxbar has none).
- **Brave replaces Librewolf** — installed from Brave's official apt repo
  (signed keyring in `/usr/share/keyrings/`, sources list in
  `/etc/apt/sources.list.d/`). No arkenfox/user.js dance; Brave needs none.
- **apt replaces pacman/AUR** — zero pacman/yay/paru references anywhere;
  packages come from Debian's repos, Brave's repo, or git+make.
- **TeX Live is installed by default** — `texlive-full` plus `latexmk` and
  `biber`. It's several gigabytes; remove those three lines from
  [progs.csv](progs.csv) before running if you don't want it.
- User is created in the **sudo** group (Debian) instead of wheel.
- `bat` is symlinked to Debian's `batcat`; `picom` replaces the dead
  xcompmgr; `ueberzug` (not ueberzugpp) drives lf previews;
  `zathura-pdf-poppler` provides PDF support.

See [DIFFERENCES.md](DIFFERENCES.md) for the complete list with reasons and
[DECISIONS.md](DECISIONS.md) for the judgment calls made while porting.

## Repository layout

```
debrice.sh              entry point, mirrors larbs.sh flow
lib/packages.sh         progs.csv parser + apt/Brave-repo installers
lib/dotfiles.sh         voidrice deployment + backups + sxwm overlays
lib/builds.sh           git clone + make install helpers
progs.csv               Debian package manifest (, apt / R repo / G git / S script)
static/sxwmrc           Luke's keybindings ported to sxwm
static/sxbarc           sxbar modules (Luke's sb-* scripts)
static/larbs.mom        the super+F1 cheat sheet, ported
static/dwm-config.h     Luke's config.h (vendored) — checker source of truth
dotfiles/               vendored voidrice fork (adapted files only)
scripts/check-binds.sh  keybinding coverage test
tests/docker-test.sh    debian:trixie container tests (static local fallback)
```

## Testing

```sh
tests/docker-test.sh all        # or: lint preflight runtime packages builds binds idempotency xephyr parsecheck
scripts/check-binds.sh          # keybinding coverage alone
```

With working docker, every stage runs in a `debian:trixie` container:
shellcheck lint, non-interactive preflight, an end-to-end runtime stage that
executes `debrice.sh` with a trimmed manifest and asserts the git-built
binaries (`sxwm`, `sxbar`, `st`, `dmenu`, `slock`, `mw`) actually landed,
package resolution via apt-cache for every `,`/`R` entry, compilation of
st/dmenu/slock/sxwm/sxbar with only the declared build deps, an idempotency
run, and an Xvfb smoke test of sxwm + config reload.
Without docker the script degrades to static local verification (Trixie and
Brave package indices, host builds, a fake-HOME deploy, and config
validation with sxwm's/sxbar's own parsers) and says so loudly.

## Credits

- [Luke Smith](https://lukesmith.xyz) for LARBS, voidrice, dwm/st/dmenu builds
  and the whole workflow this preserves
- [uint23](https://github.com/uint23) for sxwm and sxbar
- License: GPLv3 (like LARBS itself)
