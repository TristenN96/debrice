# CHANGES-FROM-VOIDRICE.md

The `dotfiles/` directory is a vendored fork of LukeSmithxyz/voidrice
(upstream commit ad94491). Everything is deployed verbatim EXCEPT the changes
below, each with a one-line reason. sxwmrc/sxbarc are not voidrice files; they
are added at deploy time from `static/` and noted at the bottom.

## Adapted files

- `.config/x11/xinitrc` — `dbus-launch ssh-agent dwm` → `… sxwm`: window manager changed.
- `.config/shell/profile` — `BROWSER="librewolf"` → `"brave"`: default browser changed.
- `.config/x11/xprofile` — autostart `xcompmgr` → `picom`: xcompmgr is dead upstream; picom is the maintained replacement.
- `.config/shell/aliasrc` — dropped `pacman` from the sudo-alias loop and `p="pacman"` → `p="sudo apt"`: repo must contain zero pacman references (apt-only).
- `.config/shell/bm-files` — `cfb` bookmark now points to `~/.config/sxbarc`: bar config moved from dwmblocks' config.h to sxbarc.
- `.config/gtk-2.0/gtkrc-2.0` — theme `Arc-Gruvbox` → `Arc-Dark`: AUR theme unavailable; arc-theme (apt) is the nearest equivalent.
- `.config/gtk-3.0/settings.ini` — same theme change as above.
- `.config/zsh/.zshrc` — sources `/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh`: Debian's zsh-syntax-highlighting package path replaces Arch's fast-syntax-highlighting AUR path.
- `.config/nvim/init.vim` — dwmblocks-recompile autocmd now restarts sxbar on `~/.config/sxbarc` writes: bar program changed.
- `.config/ncmpcpp/config` — removed `execute_on_song_change`/`execute_on_player_state_change` dwmblocks-signal hooks: sxbar has no signal API and polls sb-music by interval.
- `.local/bin/sysact` — `WM="sxwm"`; "renew" sends `xdotool key super+F5` (sxwm reload_config) instead of SIGHUP, which would kill sxwm (it installs no SIGHUP handler); dropped the volume bar-signal in `lock()`.
- `.local/bin/setbg` — removed the `pidof dwm && xdotool key super+F5` line: sxwm does not theme from Xresources, so there is no WM color scheme to refresh.
- `.local/bin/statusbar/sb-help-icon` — checks `pidof sxwm`, serves `/usr/local/share/debrice/larbs.mom`, middle-click sends the sxwm reload key instead of `pkill -HUP dwm`.
- `.local/bin/statusbar/sb-volume` — removed `pkill -RTMIN+10 dwmblocks` from the click action: no signal API in sxbar.
- `.local/bin/statusbar/sb-mailbox` — removed `pkill -RTMIN+12 dwmblocks`: same reason.
- `.local/bin/statusbar/sb-internet` — removed `pkill -RTMIN+4 dwmblocks`: same reason.
- `.local/bin/statusbar/sb-kbselect` — removed `pkill -RTMIN+30 dwmblocks`: same reason.
- `.local/bin/statusbar/sb-price` — removed `pkill -RTMIN+"$4" dwmblocks`: same reason.
- `.local/bin/statusbar/sb-iplocate` — removed `pkill -RTMIN+"${1:-27}" dwmblocks` (and the `&&` it left dangling): same reason.
- `.local/bin/statusbar/sb-moonphase` — removed `pkill -RTMIN+"${1:-17}" dwmblocks`: same reason.
- `.local/bin/statusbar/sb-forecast` — removed `pkill -RTMIN+"${1:-5}" dwmblocks`: same reason.
- `.local/bin/transadd` — removed `pkill -RTMIN+7 dwmblocks`: same reason.
- `.local/bin/torwrap` — removed `pkill -RTMIN+7 dwmblocks`: same reason.
- `.local/bin/td-toggle` — removed the trailing torrent-module refresh line: same reason.
- `.local/bin/dmenurecord` — removed both `pkill -RTMIN+9 dwmblocks` refreshes: icon file still written to `/tmp/recordingicon`, sxbar polls it.
- `.local/bin/cron/newsup` — removed both `pkill -RTMIN+6 dwmblocks` refreshes: same reason.
- `.local/bin/ifinstalled` — `pacman -Qq` → `dpkg -s`: Debian package query.
- `.local/bin/tutorialvids` — removed the pacman episode line (apt-only policy) and the dwmblocks episode line (program not installed).

## Removed files

- `.local/bin/statusbar/sb-pacpackages` — pacman-only update counter; apt-only policy.
- `.local/bin/statusbar/sb-popupgrade` — yay-based upgrader; apt-only policy.
- `.local/bin/cron/checkup` — pacman-based update checker; apt-only policy.
- `.local/bin/statusbar/sb-mpdup` — sole purpose was signaling dwmblocks on mpd changes; useless with sxbar.

## Not deployed (upstream repo metadata, not user configs)

- `README.md`, `LICENSE`, `FUNDING.yml`, `.gitmodules` — metadata of the voidrice repo itself; the mpvSockets submodule content is vendored directly instead (see below).

## Vendored content

- `.config/mpv/script_modules/mpvSockets/` — content of the `wis/mpvSockets` submodule (commit 3b3f430) vendored in-tree: debrice deploys a directory tree rather than a recursive clone, and `pauseallmpv` depends on it.

## Added at deploy time (not voidrice files)

- `~/.config/sxwmrc` — copied from `static/sxwmrc`: Luke's dwm keybindings ported to sxwm (new file).
- `~/.config/sxbarc` — copied from `static/sxbarc`: sxbar modules wired to Luke's `sb-*` statusbar scripts (new file).
