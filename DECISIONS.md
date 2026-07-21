# DECISIONS.md — running log of judgment calls

debrice is a port of Luke Smith's LARBS (Arch) to Debian 13 Trixie, with sxwm
replacing dwm, Brave replacing Librewolf, and full TeX Live. Every non-obvious
judgment call made while building this repo is logged here, newest last.

Reference sources were cloned to /tmp/debrice-ref/ and studied before any code
was written: LukeSmithxyz/LARBS (larbs.sh, progs.csv), LukeSmithxyz/voidrice,
LukeSmithxyz/dwm (config.h = keybinding source of truth, larbs.mom),
LukeSmithxyz/st, LukeSmithxyz/dmenu, LukeSmithxyz/dwmblocks (canonical status
bar module list), uint23/sxwm (README, docs/sxwm.md man page, src/parser.c and
src/sxwm.c for exact config semantics), uint23/sxbar (src/, default_sxbarc).

## D1 — sxwm config syntax, verified against src/parser.c
- `bind : mods + key : "cmd"` runs an external command via execvp (no shell;
  quotes of both kinds group arguments). `call : mods + key : fn` (or `bind`
  with an unquoted action) calls an internal function from the parser's
  call_table. We use `bind` for commands and `call` for functions, matching
  upstream default_sxwmrc.
- Commands needing shell features (pipes, `$(...)`, `;`, `||`) must be wrapped:
  `bind : ... : "sh -c '...'"`. Both quote styles are understood by sxwm's
  split_cmd, so single quotes inside the double-quoted action are safe.
- Modifier-less binds (Print, XF86 keys) are supported: `bind : Print : "..."`.
- XF86 keysyms are written e.g. `XF86AudioMute` (XStringToKeysym resolves them).
- Duplicate (mods, key) pairs are deduped keeping the first: one action per key.

## D2 — Scratchpads: dwm spawn-on-toggle cannot be reproduced
dwm's togglescratch spawns `st -n spterm …` on first press and toggles after.
sxwm scratchpads are created only by marking the *focused* window
(`scratchpad : … : create n`), then shown/hidden with `toggle n`. There is no
auto-spawn and no way to hide arbitrary windows from outside (sxwm handles no
iconify client message). Decision:
- `super+shift+Return` → `scratchpad … toggle 1`, `super+ctrl+Return` → create 1
- `super+'` → `scratchpad … toggle 2`, `super+ctrl+'` → create 2
Documented in DIFFERENCES.md; README explains the open-then-create workflow.

## D3 — super+r conflict: Luke's bindings win
sxwm's default reload is `mod+r`, but Luke's `super+r` is `st -e lfub` and ALL
of Luke's bindings are non-negotiable. `reload_config` moves to `super+F5`,
which is exactly dwm's old xrdb-refresh key ("refresh the WM"), so the mnemonic
survives. Documented in README + DIFFERENCES.md.

## D4 — zoom (super+space) dropped; pushstack mapped to stack rotation
sxwm has no promote-to-master. Its `master_next`/`master_prev` rotate the whole
client list (head→tail / tail→head), which is the nearest analog of dwm's
pushstack, so `super+shift+j/k` map there. Repeated presses do promote the
focused window to master, but nothing does it in one press: `super+space`
(zoom) is dropped and recorded in DIFFERENCES.md. `super+shift+space` keeps
dwm's togglefloating → sxwm `toggle_floating`.

## D5 — shiftview via wmctrl; shifttag dropped
sxwm's source shows it honors `_NET_CURRENT_DESKTOP` client messages, so
`wmctrl -s N` switches workspaces from outside. Luke's tag cycling
(super+g, super+;, super+PgUp/PgDn) is preserved with inline
`sh -c 'wmctrl -s $(( ($(xdotool get_desktop) + 1) % 9 ))'` (next) and
`+ 8` instead of `+ 1` (previous) binds.
shifttag (send window to next/prev tag) needs `_NET_WM_DESKTOP` client
messages, which sxwm does not handle: dropped, recorded in DIFFERENCES.md.
Adds `wmctrl` to progs.csv.

## D6 — Layouts: only monocle and floating survive
sxwm has exactly one tiled layout (master-stack), a monocle toggle, and a
global-floating toggle. Mapping of Luke's nine layout binds:
- `super+shift+u` (monocle) → `toggle_monocle`
- `super+shift+f` (floating layout) → `global_floating` (nearest)
- tile/bstack/spiral/dwindle/deck/centeredmaster/centeredfloatingmaster
  (super+(shift+)t/y/u/i) → no equivalent: dropped, recorded in DIFFERENCES.md.

## D7 — togglebar (super+b) restarts/kills sxbar
sxwm has no built-in bar; sxbar is a separate process. `super+b` →
`sh -c 'pkill -x sxbar || sxbar &'` — a kill/restart toggle equivalent to
dwm's togglebar. sxbar itself is autostarted via `exec : "sxbar"` in sxwmrc.

## D8 — No signal-based bar refresh anywhere
Neither sxwm nor sxbar installs signal handlers (verified in source; sxwm only
SIG_IGNs SIGCHLD). dwmblocks' `kill -44`/`pkill -RTMIN+N` refresh mechanism
therefore has no analog: it is stripped from ported bindings and neutered in
deployed voidrice scripts. sxbar refreshes modules purely by `interval`;
intervals are chosen per module (fast for volume/nettraf, slow for
forecast/clock). Lost dwmblocks click actions ($BLOCK_BUTTON) are recorded in
DIFFERENCES.md. sxbar module cmds run via popen() → sb-* scripts work as-is.

## D9 — sxwmrc look: gruvbox-dark from voidrice Xresources
Luke's dwm colors come from Xresources (ResourcePref: norm border←color0,
sel border←color8). sxwm has no Xresources support, so the resolved values are
hardcoded into sxwmrc: unfocused border = color0 (#282828 family), focused
border = Xresources color8 (gruvbox red), border_width 3, gaps 10 (dwm's mixed
20/10/10/30 vanity gaps collapse into sxwm's single `gaps` value; 10 matches
the dominant inner/outer horizontal gap). `new_win_master : true` reproduces
dwm's new-window-becomes-master semantics. `master_width : 55` matches dwm's
mfact 0.55; `resize_master_amount : 5` matches setmfact ±0.05 steps.

## D10 — pacman-only voidrice scripts are excluded, not rewritten
§2 forbids any pacman/AUR reference in the repo; §5 says deploy voidrice
verbatim except listed adaptations. Resolution: scripts whose *entire purpose*
is pacman/AUR are dropped from the vendored dotfiles (sb-pacpackages,
sb-popupgrade, cron/checkup), each recorded in CHANGES-FROM-VOIDRICE.md and
DIFFERENCES.md. Scripts merely *mentioning* pacman get surgical one-line fixes
(ifinstalled: `pacman -Qq` → `dpkg -s`; aliasrc: `p="pacman"` → `p="sudo apt"`,
`pacman` removed from the sudo-alias loop; tutorialvids: pacman video line
removed). ncmpcpp's `execute_on_song_change` bar-signal lines are removed
(sxbar polls sb-music on an interval instead).

## D11 — Debian user/sudo model replaces Arch's wheel
LARBS creates the user in group `wheel` with %wheel sudoers. Debian's sudo
group is `sudo`: useradd -G sudo, and sudoers.d files use %sudo. The
passwordless-command list is rewritten for Debian paths
(/usr/sbin/shutdown, /usr/sbin/reboot, systemctl suspend, mount/umount,
loadkeys, apt-get). `runcwd=*` default kept.

## D12 — Brave from official apt repo, idempotently
Keyring at /usr/share/keyrings/brave-browser-archive-keyring.gpg
(curl | gpg --dearmor, only if absent), source
/etc/apt/sources.list.d/brave-browser-release.list with signed-by, added only
if absent, then `apt-get update` once. brave-browser installed via the `R` tag
in progs.csv. All Librewolf packages + arkenfox removed from the manifest;
BROWSER=brave in the deployed profile; super+w and XF86WWW launch `brave`.

## D13 — TeX Live full + tooling
`,texlive-full`, `,latexmk`, `,biber` added. `,groff` added so super+F1 can
render the ported larbs.mom cheat sheet with groff -mom … | zathura -.

## D14 — bat is batcat on Debian
Debian's bat package ships /usr/bin/batcat. debrice.sh symlinks
/usr/local/bin/bat → batcat so voidrice scripts (lf scope previewer) and user
muscle memory keep working. Logged here rather than silently aliased.

## D15 — nmtui binding requires network-manager
Luke's super+shift+w runs `st -e nmtui`; LARBS assumes NetworkManager from the
base install. Debian netinstall doesn't guarantee it, so `,network-manager` is
in progs.csv. Safe on ifupdown systems: Debian's NM ships managed=false and
ignores interfaces declared in /etc/network/interfaces.

## D16 — larbs.mom ported and installed to /usr/local/share/debrice/larbs.mom
dwm's Makefile installs larbs.mom under /usr/local/share/dwm/. debrice ships a
rewritten mom file (sxwm bindings) installed to
/usr/local/share/debrice/larbs.mom; the super+F1 bind and sb-help-icon point
there. Filename kept as larbs.mom for LARBS lineage.

## D17 — xcompmgr → picom in xprofile autostart
progs mapping replaces dead xcompmgr with picom; the deployed
.config/x11/xprofile autostart line is updated accordingly (one word).

## D18 — slock from suckless.org git, not apt
Spec allows apt-if-present; Debian has suckless-tools (slock) but the G-build
from tools.suckless.org keeps parity with st/dmenu builds and Luke's setup.
Decision: `G,https://git.suckless.org/slock`. Verified buildable in the
container test with only declared deps (libx11-dev, libxrandr-dev).

## D19 — sxwm swallow config kept close to upstream default
can_swallow: "st"; can_be_swallowed: "mpv", "nsxiv", "sxiv", "zathura"
(upstream default plus nsxiv/zathura, matching what Luke's dwm swallowed).
should_float: "floatterm", "spterm", "spcalc" (dwm rule parity for the
floating terminal instances).

## D20 — Docker-based verification
Docker is available on the build host; tests/docker-test.sh runs everything in
debian:trixie containers (package resolution, git builds, lint, idempotency,
Xephyr smoke test where possible). shellcheck is not installed on the host, so
lint also runs inside the container. Nothing is installed host-side.

## D21 — mutt-wizard G-build with Debian deps
`G,https://github.com/LukeSmithxyz/mutt-wizard` plus apt deps neomutt, isync,
msmtp, pass, abook (abook exists in Trixie — verified in Phase 2; if it had
not, it would become an S/G entry per spec).

## D22 — Xephyr smoke test attempted, not guaranteed
xserver-xephyr is in progs.csv for testing. tests/docker-test.sh tries to
launch sxwm inside Xephyr and trigger a config reload via xdotool key super+F5;
if the environment forbids it, the test degrades to build+parser validation
and the limitation is recorded in DIFFERENCES.md.
