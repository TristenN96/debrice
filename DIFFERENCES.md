# DIFFERENCES.md — LARBS behaviors that could not be ported 1:1, and why

Every binding in Luke's dwm config.h (upstream ee3354d, vendored at
`static/dwm-config.h`) is either present in `static/sxwmrc` or listed below
with a reason. `scripts/check-binds.sh` verifies this mechanically: zero
unaccounted-for bindings is the pass condition. Combos are written in the
checker's normalized form (`mod` = super/Mod4).

## 1. Dropped keybindings (no sxwm analog)

sxwm has no promote/focus-master function — the nearest idiom is rotating the
stack with mod+shift+j/k until the focused window lands in master:

- `mod+v` — dwm focusstack(0): focus the master window.
- `mod+shift+v` — dwm pushstack(0): push focused window to master.
- `mod+space` — dwm zoom: promote focused window to master.

dwm tags are bitmasks; sxwm workspaces are exclusive. Multi-tag operations
have no equivalent:

- `ctrl+mod+1`, `ctrl+mod+2`, `ctrl+mod+3`, `ctrl+mod+4`, `ctrl+mod+5`,
  `ctrl+mod+6`, `ctrl+mod+7`, `ctrl+mod+8`, `ctrl+mod+9` — toggleview
  (view additional tag).
- `ctrl+mod+shift+1`, `ctrl+mod+shift+2`, `ctrl+mod+shift+3`,
  `ctrl+mod+shift+4`, `ctrl+mod+shift+5`, `ctrl+mod+shift+6`,
  `ctrl+mod+shift+7`, `ctrl+mod+shift+8`, `ctrl+mod+shift+9` — toggletag
  (pin window to extra tag).
- `mod+0` — view all tags at once.
- `mod+shift+0` — tag window to all tags (sticky via tag mask).
- `mod+s` — togglesticky (same all-tags mechanism).

sxwm has exactly one tiled layout (master-stack), plus a monocle toggle and a
global floating toggle. These dwm layouts do not exist:

- `mod+t` — tile (is sxwm's one and only layout; nothing to switch to).
- `mod+shift+t` — bstack.
- `mod+y` — fibonacci spiral.
- `mod+shift+y` — fibonacci dwindle.
- `mod+u` — deck.
- `mod+i` — centered master.
- `mod+shift+i` — centered floating master.

sxwm always has exactly one master window; there is no nmaster:

- `mod+o` — incnmaster +1.
- `mod+shift+o` — incnmaster -1.

sxwm gaps only step up/down (mod+z/x); there is no toggle/reset/smart mode:

- `mod+a` — togglegaps.
- `mod+shift+a` — defaultgaps (reloading sxwmrc with super+F5 resets gaps).
- `mod+shift+apostrophe` — togglesmartgaps.

shifttag (send window to next/prev tag) would need sxwm to honor
_NET_WM_DESKTOP client messages; its client-message handler only implements
_NET_CURRENT_DESKTOP and _NET_WM_STATE (verified in src/sxwm.c):

- `mod+shift+g` — shifttag -1.
- `mod+shift+semicolon` — shifttag +1.
- `mod+shift+page_up` — shifttag -1.
- `mod+shift+page_down` — shifttag +1.

## 2. Adapted keybindings (same key, adjusted action)

- `mod+F5` — dwm's xrdb (re-read Xresources into dwm) → sxwm `reload_config`.
  sxwm doesn't read Xresources; reloading sxwmrc is the true analog, and it
  keeps sxwm's hot-reload on a memorable key since sxwm's default super+r
  reload collides with Luke's `mod+r` = `st -e lfub` (Luke's bindings win).
- `mod+minus` / `mod+shift+minus` / `mod+equal` / `mod+shift+equal`,
  `mod+shift+m`, XF86AudioMute/RaiseVolume/LowerVolume, `mod+e`,
  `mod+shift+n`, `mod+F4`, XF86Mail — the `kill -44 $(pidof dwmblocks)` /
  `pkill -RTMIN+N dwmblocks` refresh suffixes are dropped. sxbar has no
  signal API; the affected bar modules poll on short intervals instead
  (sb-volume every 2 s, sb-news every 60 s, sb-mailbox every 180 s).
- `mod+shift+Return`, `mod+apostrophe` — dwm togglescratch (spawn-on-first-
  press, toggle afterwards) → sxwm `scratchpad … toggle`. sxwm scratchpads
  are created by marking the focused window (`ctrl` variants of both keys)
  and Luke's exact spawn commands (`st -n spterm -g 120x34`,
  `st -n spcalc -f monospace:size=16 -g 50x20 -e bc -lq`) moved to the `alt`
  variants. First-time workflow: super+alt+Return (spawn), super+ctrl+Return
  (register), then super+shift+Return toggles forever.
- `mod+g`, `mod+semicolon`, `mod+page_up`, `mod+page_down` — dwm shiftview →
  `sh -c 'wmctrl -s …'`, which works because sxwm honors
  _NET_CURRENT_DESKTOP client messages (verified in src/sxwm.c).
- XF86Sleep — `sudo -A zzz` (zzz is Void/Artix-only) → `systemctl suspend`,
  which needs no sudo under logind.
- `mod+b` — dwm togglebar → `sh -c 'pkill -x sxbar || sxbar &'`: sxbar is a
  separate process, so toggling the bar means killing/starting it.
- `mod+w`, XF86WWW — spawn `brave` instead of librewolf (browser change).
- `mod+F1` — renders the ported cheat sheet from
  /usr/local/share/debrice/larbs.mom instead of dwm's copy.

## 3. Status bar (dwmblocks → sxbar)

- dwmblocks' real-time-signal refresh (`kill -<34+N>`/`pkill -RTMIN+N`) has
  no sxbar equivalent: sxbar refreshes modules only on per-module intervals.
  Signal-only dwmblocks blocks became polled blocks (see static/sxbarc).
- Click actions ($BLOCK_BUTTON: left/middle/right-click and scroll on bar
  modules) are entirely lost — sxbar has no click support. All sb-* scripts
  keep working non-interactively (they still print their status text).
- sb-pacpackages is gone from the bar (pacman-only; see
  CHANGES-FROM-VOIDRICE.md), so there is no update-count module.
- sb-help-icon still renders the cheat sheet when clicked under dwm; under
  sxbar it is a static ❓ glyph. Its middle-click "restart WM" became the
  sxwm reload key for anyone running it by hand.

## 4. Mouse/button differences

- dwm's mod+Button1 drag = move, mod+Button3 drag = resize — sxwm does the
  same natively (plus mod+shift+Button1 = swap-drag with a highlight border).
- dwmblocks click regions, tag-bar clicks, and root-window middle-click
  togglebar have no equivalent (sxwm has no built-in bar).
- mod+scroll on a window changed gaps in dwm; sxwm has no mouse gap control.

## 5. LARBS behaviors intentionally not ported

- Librewolf + 4 extensions + arkenfox user.js: replaced by Brave from its
  official apt repo. The whole "start librewolf headless, build user.js from
  arkenfox + overrides, kill librewolf" phase is gone; Brave needs no such
  bootstrap. ~/.config/firefox/larbs.js still ships with voidrice but is
  unused unless Firefox is installed.
- AUR helper (yay) bootstrap and all AUR packages: gone; everything is apt,
  one external repo (Brave), or git+make. `-git` AUR auto-update flag: gone.
- pacman.conf cosmetics (ILoveCandy, ParallelDownloads) and makepkg.conf -j:
  apt needs no equivalent.
- artix/runit branches (runit keyrings, dbus-launch profile.d hook): Debian
  is systemd; dbus machine-id is ensured with `dbus-uuidgen --ensure`.
- ntpd one-shot time sync: Debian uses systemd-timesyncd out of the box.
- ueberzugpp: Debian ships the classic ueberzug instead (voidrice's lfub
  calls the `ueberzug` CLI directly, so functionality is identical).
- zathura-pdf-mupdf: not in Debian; zathura-pdf-poppler provides PDF support.
- fonts-libertinus: not in Debian; fonts-linuxlibertine installed instead.
- gtk-theme-arc-gruvbox-git (AUR): replaced by apt arc-theme; GTK configs
  point at Arc-Dark (nearest maintained equivalent).
- zsh-fast-syntax-highlighting-git (AUR): replaced by Debian's
  zsh-syntax-highlighting; the sourced path in .zshrc is updated.
- htop-vim (AUR): plain htop. simple-mtpfs (AUR): jmtpfs. sc-im: apt build.
- slock: built from git.suckless.org like LARBS's other suckless tools
  (Debian's suckless-tools exists but parity with st/dmenu builds won).
- sxwm's default super+r reload: moved to super+F5 (see §2). Mentioned in
  the README as required.

## 6. Testing limitations

- Docker was unusable on the development host (no docker group membership,
  no passwordless sudo, no rootless socket), so tests/docker-test.sh fell
  back to static verification: Trixie/Brave package indices for resolution,
  host-toolchain builds, fake-HOME idempotency, host Xephyr smoke test.
  With working docker, the same script runs everything in debian:trixie
  containers end-to-end.
- The Xephyr stage verifies sxwm launches, parses static/sxwmrc, and
  survives a super+F5 reload. It does not exercise real key grabs against
  every binding; that needs a live session.
