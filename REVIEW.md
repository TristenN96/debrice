# debrice — configuration review

Review deliverable: the complete current text of the sxwm/sxbar configs, the
session files as shipped, and the dwm→sxwm action mapping. The sxwm config
lives at **`static/sxwmrc`** (repo root) and is tracked in git; it is
deployed verbatim to `~/.config/sxwmrc` by `deploy_dotfiles`
(`lib/dotfiles.sh`). Audit sources: `docs/sxwm.md`, `src/parser.c` and
`src/sxwm.c` in uint23/sxwm (master), `src/sxbar.c` + `src/parser.c` +
`default_sxbarc` in uint23/sxbar (main), and the vendored
`static/dwm-config.h` (upstream ee3354d).

## 1. `static/sxwmrc` — complete current text

```
# debrice sxwmrc — Luke Smith's dwm keybindings (LukeSmithxyz/dwm config.h,
# upstream ee3354d) ported to sxwm (https://github.com/uint23/sxwm).
#
# mod = super (Mod4), matching dwm's MODKEY. Per docs/sxwm.md there are three
# binding directives: `bind` (quoted action = external command, bare action =
# internal function from the docs' function table), and the dedicated
# `workspace`/`scratchpad` directives. Commands needing a shell
# (pipes, $(...), &&, ||) are wrapped in sh -c '...'.
#
# Reload this file with super+F5 (sxwm's default super+r reload was moved
# here because super+r is Luke's lfub binding).

# Look: dark gruvbox tones harmonized with Luke's st palette (#282828 bg).
mod_key                 : super
border_width            : 3
gaps                    : 10
focused_border_colour   : #cc241d
unfocused_border_colour : #282828
swap_border_colour      : #ebdbb2
master_width            : 55 # dwm mfact = 0.55
resize_master_amount    : 5  # dwm setmfact steps of 0.05
resize_stack_amount     : 20
snap_distance           : 32 # dwm snap = 32
move_window_amount      : 50
resize_window_amount    : 50
motion_throttle         : 60
new_win_focus           : true
warp_cursor             : true
floating_on_top         : true
# dwm semantics: new windows become master.
new_win_master          : true
should_float            : "floatterm", "spterm", "spcalc"
can_swallow             : "st"
can_be_swallowed        : "mpv", "nsxiv", "sxiv", "zathura"
start_fullscreen        : "mpv"

# Autostart the status bar (sxbar replaces dwmblocks).
exec : "sxbar"

####################### keybindings #######################

# Focus movement (dwm focusstack).
bind : mod + j : focus_next
bind : mod + k : focus_prev
# mod+v (focus master) has no sxwm equivalent — see DIFFERENCES.md.
# Stack movement (dwm pushstack; sxwm rotates the stack).
bind : mod + shift + j : master_next
bind : mod + shift + k : master_prev

# Emoji picker.
bind : mod + grave : "dmenuunicode"

# Workspaces 1-9 (dwm tags): view / send window.
workspace : mod + 1 : move 1
workspace : mod + shift + 1 : swap 1
workspace : mod + 2 : move 2
workspace : mod + shift + 2 : swap 2
workspace : mod + 3 : move 3
workspace : mod + shift + 3 : swap 3
workspace : mod + 4 : move 4
workspace : mod + shift + 4 : swap 4
workspace : mod + 5 : move 5
workspace : mod + shift + 5 : swap 5
workspace : mod + 6 : move 6
workspace : mod + shift + 6 : swap 6
workspace : mod + 7 : move 7
workspace : mod + shift + 7 : swap 7
workspace : mod + 8 : move 8
workspace : mod + shift + 8 : swap 8
workspace : mod + 9 : move 9
workspace : mod + shift + 9 : swap 9
# mod+ctrl+N (toggleview), mod+ctrl+shift+N (toggletag), mod+0 (view all)
# and mod+shift+0 (tag all/sticky) have no workspace analog — DIFFERENCES.md.

# Volume (dwmblocks refresh signals dropped; sxbar polls sb-volume).
bind : mod + minus : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
bind : mod + shift + minus : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 15%-"
bind : mod + equal : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
bind : mod + shift + equal : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 15%+"

# System menu and window close.
bind : mod + BackSpace : "sysact"
bind : mod + shift + BackSpace : "sysact"
bind : mod + shift + q : "sysact"
bind : mod + q : close_window

# Programs.
bind : mod + w : "brave-browser"
bind : mod + shift + w : "st -e nmtui"
bind : mod + e : "st -e neomutt"
bind : mod + shift + e : "st -e abook"
bind : mod + r : "st -e lfub"
bind : mod + shift + r : "st -e htop"

# Layouts: sxwm has a single master-stack layout plus monocle and global
# floating. The other six dwm layouts have no equivalent — DIFFERENCES.md.
bind : mod + shift + u : toggle_monocle
bind : mod + shift + f : global_floating
# mod+o / mod+shift+o (incnmaster): no equivalent — DIFFERENCES.md.

# Music player.
bind : mod + p : "mpc toggle"
bind : mod + shift + p : "sh -c 'mpc pause; pauseallmpv'"
bind : mod + bracketleft : "mpc seek -10"
bind : mod + shift + bracketleft : "mpc seek -60"
bind : mod + bracketright : "mpc seek +10"
bind : mod + shift + bracketright : "mpc seek +60"
bind : mod + comma : "mpc prev"
bind : mod + shift + comma : "mpc seek 0%"
bind : mod + period : "mpc next"
bind : mod + shift + period : "mpc repeat"

# Previous workspace (dwm's mod+Tab / mod+backslash "view").
bind : mod + Tab : switch_previous_workspace
bind : mod + backslash : switch_previous_workspace

# Gaps: only stepwise adjust exists in sxwm; togglegaps/defaultgaps/
# togglesmartgaps are dropped — DIFFERENCES.md.
bind : mod + z : increase_gaps
bind : mod + x : decrease_gaps

# mod+s (togglesticky): no sticky windows in sxwm — DIFFERENCES.md.

# Launchers.
bind : mod + d : "dmenu_run"

# Fullscreen / floating.
bind : mod + f : fullscreen
bind : mod + shift + space : toggle_floating

# Tag cycling (dwm shiftview) via wmctrl; sxwm honors _NET_CURRENT_DESKTOP.
# shifttag (send window along) has no analog — DIFFERENCES.md.
bind : mod + g : "sh -c 'wmctrl -s $(( ($(xdotool get_desktop) + 8) % 9 ))'"
bind : mod + semicolon : "sh -c 'wmctrl -s $(( ($(xdotool get_desktop) + 1) % 9 ))'"
bind : mod + Page_Up : "sh -c 'wmctrl -s $(( ($(xdotool get_desktop) + 8) % 9 ))'"
bind : mod + Page_Down : "sh -c 'wmctrl -s $(( ($(xdotool get_desktop) + 1) % 9 ))'"

# Master area resize (dwm setmfact).
bind : mod + h : master_decrease
bind : mod + l : master_increase

# Scratchpads. sxwm scratchpads are created from the focused window
# (create), then shown/hidden (toggle). Luke's original keys toggle;
# ctrl variants create; alt variants spawn Luke's exact dwm commands.
scratchpad : mod + shift + Return : toggle 1
scratchpad : mod + ctrl + Return : create 1
bind : mod + alt + Return : "st -n spterm -g 120x34"
scratchpad : mod + apostrophe : toggle 2
scratchpad : mod + ctrl + apostrophe : create 2
bind : mod + alt + apostrophe : "st -n spcalc -f monospace:size=16 -g 50x20 -e bc -lq"

# Terminal.
bind : mod + Return : "st"

# Other programs.
bind : mod + b : "sh -c 'pkill -x sxbar || sxbar &'"
bind : mod + n : "st -e nvim -c VimwikiIndex"
bind : mod + shift + n : "st -e newsboat"
bind : mod + m : "st -e ncmpcpp"
bind : mod + shift + m : "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

# Monitors (dwm focusmon/tagmon).
bind : mod + Left : focus_prev_mon
bind : mod + Right : focus_next_mon
bind : mod + shift + Left : move_prev_mon
bind : mod + shift + Right : move_next_mon

# Snippet typer.
bind : mod + Insert : "sh -c 's=$(grep -v ^# ~/.local/share/larbs/snippets | dmenu -i -l 50); xdotool type ${s%% *}'"

# Function keys.
bind : mod + F1 : "sh -c 'groff -mom /usr/local/share/debrice/larbs.mom -Tpdf | zathura -'"
bind : mod + F2 : "tutorialvids"
bind : mod + F3 : "displayselect"
bind : mod + F4 : "st -e pulsemixer"
# dwm's xrdb-refresh analog: reload sxwmrc.
bind : mod + F5 : reload_config
bind : mod + F6 : "torwrap"
bind : mod + F7 : "td-toggle"
bind : mod + F9 : "mounter"
bind : mod + F10 : "unmounter"
bind : mod + F11 : "sh -c 'mpv --untimed --no-cache --no-osc --no-input-default-bindings --profile=low-latency --input-conf=/dev/null --title=webcam $(ls /dev/video[0,2,4,6,8] | tail -n 1)'"
bind : mod + F12 : "remaps"

# mod+space (zoom) has no promote-to-master in sxwm — DIFFERENCES.md.

# Screenshots and recording.
bind : Print : "sh -c 'maim pic-full-$(date +%y%m%d-%H%M-%S).png'"
bind : shift + Print : "maimpick"
bind : mod + Print : "dmenurecord"
bind : mod + shift + Print : "dmenurecord kill"
bind : mod + Delete : "dmenurecord kill"

# Media and hardware keys.
bind : XF86AudioMute : "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
bind : XF86AudioRaiseVolume : "sh -c 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0%- && wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%+'"
bind : XF86AudioLowerVolume : "sh -c 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0%+ && wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-'"
bind : XF86AudioPrev : "mpc prev"
bind : XF86AudioNext : "mpc next"
bind : XF86AudioPause : "mpc pause"
bind : XF86AudioPlay : "mpc play"
bind : XF86AudioStop : "mpc stop"
bind : XF86AudioRewind : "mpc seek -10"
bind : XF86AudioForward : "mpc seek +10"
bind : XF86AudioMedia : "st -e ncmpcpp"
bind : XF86AudioMicMute : "pactl set-source-mute @DEFAULT_SOURCE@ toggle"
bind : XF86Calculator : "st -e bc -l"
bind : XF86Sleep : "systemctl suspend"
bind : XF86WWW : "brave-browser"
bind : XF86DOS : "st"
bind : XF86ScreenSaver : "sh -c 'slock & xset dpms force off; mpc pause; pauseallmpv'"
bind : XF86TaskPane : "st -e htop"
bind : XF86Mail : "st -e neomutt"
bind : XF86MyComputer : "st -e lfub /"
bind : XF86Launch1 : "xset dpms force off"
bind : XF86TouchpadToggle : "sh -c '(synclient | grep TouchpadOff.*1 && synclient TouchpadOff=0) || synclient TouchpadOff=1'"
bind : XF86TouchpadOff : "synclient TouchpadOff=1"
bind : XF86TouchpadOn : "synclient TouchpadOff=0"
bind : XF86MonBrightnessUp : "xbacklight -inc 15"
bind : XF86MonBrightnessDown : "xbacklight -dec 15"
```

## 2. `static/sxbarc` — complete current text

```
# debrice sxbarc — sxbar (dwmblocks replacement) wired to Luke's sb-* scripts.
#
# The module list ports LukeSmithxyz/dwmblocks' config.h, minus sb-pacpackages
# (pacman-only). dwmblocks' signal-only blocks (interval 0) become polled
# blocks here because sxbar refreshes purely on intervals; click actions
# ($BLOCK_BUTTON) are lost — see DIFFERENCES.md.
# Modules run through popen(), so ~/.local/bin/statusbar must be on PATH
# (it is, via ~/.local/bin in the shell profile).

# layout and style — dark gruvbox look matching sxwmrc; bar on top like dwm.
bottom_bar          : false
height              : 19
vertical_padding    : 0
horizontal_padding  : 0
text_padding        : 0
border              : false
border_width        : 0
background_colour   : #282828
foreground_colour   : #ebdbb2
border_colour       : #928374
font                : monospace
font_size           : 10

# modules (same order as Luke's dwmblocks config.h)
module.0.name       : recording
module.0.cmd        : cat /tmp/recordingicon 2>/dev/null
module.0.enabled    : true
module.0.interval   : 2

module.1.name       : tasks
module.1.cmd        : sb-tasks
module.1.enabled    : true
module.1.interval   : 10

module.2.name       : news
module.2.cmd        : sb-news
module.2.enabled    : true
module.2.interval   : 60

module.3.name       : torrent
module.3.cmd        : sb-torrent
module.3.enabled    : true
module.3.interval   : 20

module.4.name       : doppler
module.4.cmd        : sb-doppler
module.4.enabled    : true
module.4.interval   : 1800

module.5.name       : forecast
module.5.cmd        : sb-forecast
module.5.enabled    : true
module.5.interval   : 1800

module.6.name       : mailbox
module.6.cmd        : sb-mailbox
module.6.enabled    : true
module.6.interval   : 180

module.7.name       : nettraf
module.7.cmd        : sb-nettraf
module.7.enabled    : true
module.7.interval   : 1

module.8.name       : volume
module.8.cmd        : sb-volume
module.8.enabled    : true
module.8.interval   : 2

module.9.name       : battery
module.9.cmd        : sb-battery
module.9.enabled    : true
module.9.interval   : 5

module.10.name      : clock
module.10.cmd       : sb-clock
module.10.enabled   : true
module.10.interval  : 60

module.11.name      : internet
module.11.cmd       : sb-internet
module.11.enabled   : true
module.11.interval  : 5

module.12.name      : help
module.12.cmd       : sb-help-icon
module.12.enabled   : true
module.12.interval  : 3600

workspaces.labels              : 1 2 3 4 5 6 7 8 9
workspaces.active_background   : #cc241d
workspaces.active_foreground   : #ebdbb2
workspaces.inactive_background : #282828
workspaces.inactive_foreground : #ebdbb2
workspaces.padding_left        : 10
workspaces.padding_right       : 10
workspaces.spacing             : 0
workspaces.position            : left
```

## 3. Deployed session files (as shipped in `dotfiles/`)

### `dotfiles/.config/x11/xinitrc`

```
#!/bin/sh

# xinitrc runs automatically when you run startx.

# There are some small but important commands that need to be run when we start
# the graphical environment. There is a link to this file in ~/.xprofile
# because that file is run automatically if someone uses a display manager
# (login screen) and so they are needed there. To prevent doubling up commands,
# I source them here with the line below.

if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/x11/xprofile" ]; then
	. "${XDG_CONFIG_HOME:-$HOME/.config}/x11/xprofile"
else
	. "$HOME/.xprofile"
fi
# Activate dbus variables
dbus-update-activation-environment --all
dbus-launch ssh-agent sxwm
```

### `dotfiles/.config/x11/xprofile`

```
#!/bin/sh

# This file runs when a DM logs you into a graphical session.
# If you use startx/xinit like a Chad, this file will also be sourced.

xrandr --dpi 96		# Set DPI. User may want to use a larger number for larger screens.
setbg &			# set the background with the `setbg` script
#xrdb ${XDG_CONFIG_HOME:-$HOME/.config}/x11/xresources & xrdbpid=$!	# Uncomment to use Xresources colors/settings on startup

autostart="mpd picom dunst unclutter remapd"

for program in $autostart; do
	pidof -sx "$program" || "$program" &
done >/dev/null 2>&1

# Ensure that xrdb has finished running before moving on to start the WM/DE.
[ -n "$xrdbpid" ] && wait "$xrdbpid"
```

### `dotfiles/.xprofile`

```
#!/bin/sh

# This file runs when a DM logs you into a graphical session.
# If you use startx/xinit like a Chad, this file will also be sourced.

xrandr --dpi 96		# Set DPI. User may want to use a larger number for larger screens.
setbg &			# set the background with the `setbg` script
#xrdb ${XDG_CONFIG_HOME:-$HOME/.config}/x11/xresources & xrdbpid=$!	# Uncomment to use Xresources colors/settings on startup

autostart="mpd picom dunst unclutter remapd"

for program in $autostart; do
	pidof -sx "$program" || "$program" &
done >/dev/null 2>&1

# Ensure that xrdb has finished running before moving on to start the WM/DE.
[ -n "$xrdbpid" ] && wait "$xrdbpid"
```

`dotfiles/.xprofile` is a symlink to `.config/x11/xprofile`; the xinitrc sources the XDG copy first and falls back to `~/.xprofile`.

## 4. dwm internal function → sxwm directive mapping

Every dwm-internal function from Luke's `config.h` that needed translation,
and the directive now used in `static/sxwmrc`. "Dropped" entries point at
`DIFFERENCES.md` (§1 = dropped bindings, §2 = adapted bindings).

### Focus and stack

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `focusstack(+1)` (`mod+j`) | `bind : mod + j : focus_next` | ported |
| `focusstack(-1)` (`mod+k`) | `bind : mod + k : focus_prev` | ported |
| `focusstack(0)` (`mod+v`) | — | dropped → DIFFERENCES.md §1 |
| `pushstack(+1)` (`mod+shift+j`) | `bind : mod + shift + j : master_next` | ported |
| `pushstack(-1)` (`mod+shift+k`) | `bind : mod + shift + k : master_prev` | ported |
| `pushstack(0)` (`mod+shift+v`) | — | dropped → DIFFERENCES.md §1 |
| `zoom` (`mod+space`) | — | dropped → DIFFERENCES.md §1 |

### Layouts (`setlayout` ×9)

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| tile (`mod+t`) | — | dropped (sxwm's one tiled layout) → §1 |
| bstack (`mod+shift+t`) | — | dropped → §1 |
| spiral (`mod+y`) | — | dropped → §1 |
| dwindle (`mod+shift+y`) | — | dropped → §1 |
| deck (`mod+u`) | — | dropped → §1 |
| monocle (`mod+shift+u`) | `bind : mod + shift + u : toggle_monocle` | ported |
| centeredmaster (`mod+i`) | — | dropped → §1 |
| centeredfloatingmaster (`mod+shift+i`) | — | dropped → §1 |
| floating (`mod+shift+f`) | `bind : mod + shift + f : global_floating` | ported |

### Master count and width

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `incnmaster(+1)` (`mod+o`) | — | dropped → §1 |
| `incnmaster(-1)` (`mod+shift+o`) | — | dropped → §1 |
| `setmfact(-0.05)` (`mod+h`) | `bind : mod + h : master_decrease` | ported |
| `setmfact(+0.05)` (`mod+l`) | `bind : mod + l : master_increase` | ported |

### Gaps

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `togglegaps` (`mod+a`) | — | dropped → §1 |
| `defaultgaps` (`mod+shift+a`) | — | dropped → §1 |
| `incrgaps(+3)` (`mod+z`) | `bind : mod + z : increase_gaps` | ported |
| `incrgaps(-3)` (`mod+x`) | `bind : mod + x : decrease_gaps` | ported |
| `togglesmartgaps` (`mod+shift+apostrophe`) | — | dropped → §1 |

### Window state

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `togglesticky` (`mod+s`) | — | dropped → §1 |
| `togglefullscr` (`mod+f`) | `bind : mod + f : fullscreen` | ported |
| `togglefloating` (`mod+shift+space`) | `bind : mod + shift + space : toggle_floating` | ported |
| `killclient` (`mod+q`) | `bind : mod + q : close_window` | ported |
| `togglebar` (`mod+b`) | `bind : mod + b : "sh -c 'pkill -x sxbar \|\| sxbar &'"` | adapted (sxwm has no built-in bar) → §2 |

### Tags → workspaces

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `view N` (`mod+1`…`mod+9`) | `workspace : mod + N : move N` | ported (dedicated directive) |
| `tag N` (`mod+shift+1`…`mod+shift+9`) | `workspace : mod + shift + N : swap N` | ported (dedicated directive) |
| `toggleview N` (`mod+ctrl+1`…`9`) | — | dropped → §1 |
| `toggletag N` (`mod+ctrl+shift+1`…`9`) | — | dropped → §1 |
| `view ~0` (`mod+0`) | — | dropped → §1 |
| `tag ~0` (`mod+shift+0`) | — | dropped → §1 |
| `view {0}` previous tag (`mod+Tab`, `mod+backslash`) | `bind : mod + Tab : switch_previous_workspace` / `bind : mod + backslash : switch_previous_workspace` | ported |
| `shiftview(-1)` (`mod+g`, `mod+Page_Up`) | `bind : … : "sh -c 'wmctrl -s …'"` (prev desktop) | adapted → §2 |
| `shiftview(+1)` (`mod+semicolon`, `mod+Page_Down`) | `bind : … : "sh -c 'wmctrl -s …'"` (next desktop) | adapted → §2 |
| `shifttag(±1)` (`mod+shift+g`/`;`/`PgUp`/`PgDn`) | — | dropped → §1 |

### Scratchpads

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `togglescratch 0` — spterm (`mod+shift+Return`) | `scratchpad : mod + shift + Return : toggle 1` (`create 1` on ctrl, Luke's spawn on alt) | adapted → §2 |
| `togglescratch 1` — spcalc (`mod+apostrophe`) | `scratchpad : mod + apostrophe : toggle 2` (`create 2` on ctrl, Luke's spawn on alt) | adapted → §2 |

### Monitors

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `focusmon(-1)` (`mod+Left`) | `bind : mod + Left : focus_prev_mon` | ported |
| `focusmon(+1)` (`mod+Right`) | `bind : mod + Right : focus_next_mon` | ported |
| `tagmon(-1)` (`mod+shift+Left`) | `bind : mod + shift + Left : move_prev_mon` | ported |
| `tagmon(+1)` (`mod+shift+Right`) | `bind : mod + shift + Right : move_next_mon` | ported |

### Config reload

| dwm function (key) | sxwm directive | Status |
|---|---|---|
| `xrdb` (`mod+F5`) | `bind : mod + F5 : reload_config` | adapted → §2 |

## 5. Audit notes

- **Workspace directives:** the shipped sxwmrc uses the exact upstream
  dedicated syntax — `workspace : mod + N : move N` (switch) and
  `workspace : mod + shift + N : swap N` (send window) — verified against
  `docs/sxwm.md` and `src/parser.c` (`TYPE_WS_CHANGE`/`TYPE_WS_MOVE`). The
  Xvfb stage proves it functionally: it sends `super+2` via xdotool and
  asserts `_NET_CURRENT_DESKTOP` moves 0 → 1 via `xprop -root`.
- **`call` → `bind`:** `docs/sxwm.md` defines only `bind`, `workspace` and
  `scratchpad` (an internal function is a `bind` with a bare, unquoted
  action). The previously used `call` directive exists only as an
  undocumented alias in `parser.c`; all internal-function lines use the
  documented `bind` form. Parse result is identical.
- **Function names:** every internal function used above exists verbatim in
  the docs' function table / parser `call_table`: `focus_next`, `focus_prev`,
  `master_next`, `master_prev`, `master_increase`, `master_decrease`,
  `close_window`, `toggle_monocle`, `global_floating`, `fullscreen`,
  `toggle_floating`, `increase_gaps`, `decrease_gaps`,
  `switch_previous_workspace`, `focus_next_mon`, `focus_prev_mon`,
  `move_next_mon`, `move_prev_mon`, `reload_config`.
- **sxbar workspace tracking (audited end-to-end):** sxbar reads
  `_NET_CURRENT_DESKTOP` from the root window and repaints on the matching
  PropertyNotify, plus an unconditional 1-second repaint in its run loop.
  sxwm sets every atom it needs (`_NET_SUPPORTED` including the desktop
  atoms, `_NET_NUMBER_OF_DESKTOPS`, `_NET_DESKTOP_NAMES`, per-client
  `_NET_WM_DESKTOP`) — no EWMH patch required on either side. The
  `workspaces.*` keys in sxbarc match the current parser exactly
  (`sxbar.1` is an empty file upstream; `src/parser.c` + `default_sxbarc`
  are the only authority). The Xvfb stage asserts the highlight actually
  moves: a small XGetImage scanner locates the dock window via the root
  tree (sxwm does not manage docks — they are absent from
  `_NET_CLIENT_LIST`) and checks the active color moves on `super+2`.
  Upstream caveat: sxbar runs module commands with a blocking popen in
  its single loop, so a hung module freezes the whole bar — the two
  network modules (sb-forecast, sb-doppler) now use `curl --max-time 20`.
  A highlight that never moves on hardware means a stale sxbar binary, a
  duplicate instance stacked over the good one, or a hung module — see
  DIFFERENCES.md §7.
- **Brave binary:** Debian's `brave-browser` package ships
  `/usr/bin/brave-browser` (and `brave-browser-stable`) — no `brave`
  binary. Binds and the `BROWSER` env var (`.config/shell/profile`) use
  `brave-browser`. Verified in the e2e container.
- **Dead upstream binds removed:** `mod+c` (profanity), `mod+scroll_lock`
  (screenkey), `mod+shift+d` (passmenu — dropped upstream at voidrice
  ad94491, absent from Debian's `pass`), `mod+f8` (mailsync — dropped
  upstream). Each is recorded in DIFFERENCES.md §1.
- **NumLock/LockMask:** sxwm masks `LockMask`, NumLock (`Mod2`) and
  `mode_switch` in both key and button grabs (`guards[]` in
  `grabkeys`/`grabbuttons`, mirroring dwm), so `super+number` works with
  NumLock on. Verified in `src/sxwm.c`; no user action needed.
- **PipeWire:** the session no longer spawns `pipewire` from xprofile;
  `pipewire`, `pipewire-pulse` and `wireplumber` are enabled as systemd
  user units at install time (`systemctl --global enable`) and start at
  first graphical login. The `wpctl`/`pactl` binds are unchanged.
- **Dependency coverage:** `scripts/check-session-deps.sh` checks every
  command in the session files AND every quoted bind/exec action in the
  deployed sxwmrc against PATH in the e2e container (52 commands), so a
  dead key or dead autostart fails the build.
