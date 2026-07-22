# DECISIONS.md — running log of judgment calls

debrice is a port of Luke Smith's LARBS (Arch) to Debian 13 Trixie, with sxwm
replacing dwm and Brave replacing Librewolf. Every non-obvious
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

## D9 — sxwmrc look: gruvbox-dark, harmonized with Luke's st palette
Investigation note: voidrice's xresources ships every palette commented out
(only alpha and font are active), so Luke's dwm actually runs on config.h's
compiled-in #222222/#444444/#770000 defaults; the gruvbox look of a LARBS
desktop comes from st's config.h palette (#282828 bg, #ebdbb2 fg, #cc241d
red). sxwm has no Xresources support, so sxwmrc hardcodes: unfocused border
#282828 (st bg), focused border #cc241d (st red — same hue family as dwm's
#770000), swap border #ebdbb2, border_width 3, gaps 10 (dwm's mixed
20/10/10/30 vanity gaps collapse into sxwm's single `gaps` value; 10 matches
the dominant inner/outer horizontal gap). `new_win_master : true` reproduces
dwm's new-window-becomes-master semantics; `master_width : 55` matches
mfact 0.55; `resize_master_amount : 5` matches setmfact ±0.05 steps;
`snap_distance : 32` matches dwm's snap. Trailing `#` comments are only used
on atoi-parsed numeric options: sxwm's parser does not strip comments from
bind lines or strcmp-parsed booleans (caught by the parse harness).

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

## D20 — Docker-based verification with automatic local fallback
Docker is installed on the build host but unusable (user not in docker group,
sudo requires a password, no rootless socket). tests/docker-test.sh therefore
auto-detects: when `docker info` fails it degrades each stage to static local
verification and says so loudly —
- package resolution greps downloaded Trixie main + Brave stable Packages
  indices (in /tmp/debrice-test-cache) instead of apt-cache in a container;
- git builds compile on the host (Arch, gcc 15) into a throwaway PREFIX
  instead of a Trixie container — verifies the code and the dependency set,
  not the exact Trixie toolchain;
- idempotency runs in a fake HOME with overridable repo paths;
- Xephyr smoke test runs on the host's Xephyr if present.
On any machine with working docker the same script runs the real
debian:trixie container stages unchanged. shellcheck is fetched as a static
binary to /tmp since the host lacks it.

## D23 — Three package swaps after Trixie index verification
- fonts-libertinus: does not exist in Trixie (spec anticipated this). Using
  fonts-linuxlibertine (the Libertine family libertinus forked from); true
  libertinus also arrives with texlive-full, whose Debian packaging registers
  texmf fonts with fontconfig via 09-texlive.conf.
- ueberzugpp: not in Trixie. Spec says G-build if missing, but voidrice's
  lfub/scope call the classic `ueberzug` CLI (`ueberzug layer -p json`), which
  Trixie ships as the `ueberzug` package. Chose apt ueberzug over a heavy
  cmake/opencv-adjacent ueberzugpp source build: zero functional difference
  for the only consumer. Recorded in DIFFERENCES.md.
- zathura-pdf-mupdf: not in Trixie (Debian ships only the poppler plugin).
  Mapped to zathura-pdf-poppler; PDF support preserved.

All other `,` entries verified present in Trixie main (68,755-package index),
and brave-browser verified present in Brave's stable repo index (R tag).

## D21 — mutt-wizard G-build with Debian deps
`G,https://github.com/LukeSmithxyz/mutt-wizard` plus apt deps neomutt, isync,
msmtp, pass, abook (abook exists in Trixie — verified in Phase 2; if it had
not, it would become an S/G entry per spec).

## D22 — Xephyr smoke test attempted; parser harness used instead
xserver-xephyr is in progs.csv for testing and the docker stage does run the
full Xephyr launch + super+F5 reload check. The development host has no
Xephyr/Xvfb/Xnest and no packages may be installed host-side, so locally the
stage degrades to `parsecheck`: sxwm's and sxbar's own parser.c files are
compiled into small stub harnesses (symbols from extern.h stubbed) and run
against static/sxwmrc and static/sxbarc. That caught a real bug (trailing
comment after a `call` action; a `#` suffix breaking a strcmp-parsed bool),
which is exactly the class of error a launch test exists for. Recorded as a
limitation in DIFFERENCES.md §6.

## D24 — Repo URL placeholder and larbs.mom port
debrice.sh self-bootstraps by cloning `$repourl` when curl'd standalone;
both it and the README use the placeholder
https://github.com/debrice/debrice(.git) — whoever publishes the repo sets
that to its real location (one variable + the README curl line).
static/larbs.mom is a full port of dwm's larbs.mom: same mom structure and
voice, but the binding lists reflect sxwmrc reality (scratchpad workflow,
single layout + monocle/floating, Mod+F5 reload, Brave, sxbar without click
actions, no sticky/zoom/multi-tag) and the Configuration/FAQ sections point
at sxwmrc/sxbarc instead of dwm's config.h. Verified renderable with
groff -mom -Tpdf on the host.

## D25 — Real repo URL; libs sourced at top; error() reports the real failure
The placeholder from D24 is resolved: repourl and the README curl line now
point at https://github.com/TristenN96/debrice(.git).

Bare-metal run of the committed script died at the prereq loop with
`apt_install: command not found` — lib/packages.sh was only sourced by
bootstraprepo(), i.e. after first use. Fix: debrice.sh now sources lib/*.sh
near the top via SCRIPT_DIR (the script's own directory, never the cwd).
The sourcing is conditional (`[ -f lib/packages.sh ]`) specifically to
preserve the standalone-curl path: a curl'd script has no lib/ next to it
and still gets the libraries from bootstraprepo()'s clone. Sourcing twice
(checkout case) is idempotent — only function definitions and `: "${X:=...}"`
defaults.

error() used to let callers swap any failure for the guess "root? Debian 13?
internet?" — which masked the sourcing bug for days. It now headlines
`FATAL: debrice.sh:<line>: <message naming the failed command>`, and
error-guarded commands keep stderr unsuppressed so apt's own diagnosis sits
above the FATAL line; the generic hint survives only as a trailing sentence.

Lint never executes code paths, so this class of bug was invisible to every
existing stage. tests/docker-test.sh gained a `runtime` stage that runs
debrice.sh for real in debian:trixie (DEBRICE_ASSUME_YES=1,
DEBRICE_PREFLIGHT_ONLY=1) and fails on any "command not found" in the output
or any nonzero exit.

The same first real docker run also exposed that the X smoke stage could
never have worked in a container: Xephyr renders into a window on a host X
server ("Xephyr cannot open host display"), so it needs a mounted host
session. The docker stage now uses Xvfb (pure framebuffer, no host
requirements) for the same sxwm launch + super+F5 reload assertions; the
stage keeps its `xephyr` CLI name. D22's "full suite green" had come from
the local fallback, where the stage silently degraded to parsecheck.

## D26 — Silent git-build phase: missing sudo, misordered deps, swallowed errors
Bare-metal run #2 exited 0 with zero G builds in /usr/local/bin. Four
stacked causes, the first three each independently sufficient:
1. sudo was present neither on a root-password netinstall nor in progs.csv,
   and every gitmakeinstall step goes through `sudo -u $name` — the clone
   died (rc 127) before make was ever reached. Fixed: `,sudo` added to
   progs.csv ahead of the G block.
2. The build toolchain (build-essential, pkg-config, libx*-dev) sat AFTER
   the G block in progs.csv, so even with sudo every `make` failed. Fixed:
   deps moved ahead of the G entries — manifest ordering is load-bearing,
   and the e2e runtime stage now guards it (it also installs an apt entry
   placed after the G block, proving the loop keeps going).
3. progs_each declared `local name` and bash's DYNAMIC SCOPING made it
   visible down the call stack: inside gitmakeinstall, `$name` was the CSV
   name field (the git URL), not the username — `sudo -u https://...` died
   with "unknown user" for every G entry. Caught by the first e2e runtime
   run. Fixed: progs_each's locals are pe_-prefixed.
4. gitmakeinstall sent stdout+stderr to /dev/null and gitinstall ignored
   the return code, so all failure modes were invisible and the script
   exited 0. Fixed: build stderr stays visible, G/S install failures are
   FATAL, and every G/S install must produce its expected binary
   (mutt-wizard→mw, everything else=repo name) or die naming the package.

Also: installationloop now counts per-tag pass/fail (apt/repo failures
listed by name, non-fatal as in LARBS), print_install_summary runs before
finalize so a skipped phase shows as zeros on the last screen, and a
post-loop assertion aborts if fewer git builds landed than `^G,` lines in
the manifest. bootstraprepo respects a preset PROGS_FILE so the docker
runtime stage can drive debrice.sh end-to-end with a trimmed manifest
(texlive-full et al. dropped) and assert the binaries landed.
/etc/sudoers.d and /etc/modprobe.d are not guaranteed to exist (both absent
in the debian:trixie image, and sudoers.d absent on any sudo-less system) —
mkdir -p before writing to them.

## D27 — Bare-metal #3: dbus-x11, TeX Live dropped, sxwm docs audit
Three user-directed fixes after the third bare-metal run:
1. startx died at "dbus-launch: not found" — Debian splits dbus-launch (and
   dbus-update-activation-environment) out of dbus into dbus-x11. Added
   `,dbus-x11`; also `,openssh-client`, because the xinitrc execs the WM
   through `dbus-launch ssh-agent sxwm` and ssh-agent is not guaranteed
   either (both absent in the debian:trixie image). New guard:
   scripts/check-session-deps.sh extracts every external command the
   deployed xinitrc/xprofile invoke and asserts each resolves on PATH; it
   runs inside the e2e container against the installed user's deployed
   files, so a missing session binary fails the build, not the user's
   first startx.
2. texlive-full/latexmk/biber removed from progs.csv (user decision; groff
   stays for the cheat sheet). With the multi-GB packages gone, the docker
   runtime stage no longer trims the manifest — it runs the real progs.csv
   end-to-end, so the test installs exactly what a user gets, including the
   Brave R entry.
3. sxwm keybinding audit against docs/sxwm.md (re-read in full) and the
   parser source. Findings:
   - The workspace section ALREADY used the exact upstream dedicated
     syntax (`workspace : mod + N : move N` / `workspace : mod + shift + N
     : swap N`) — confirmed against docs and parser.c (TYPE_WS_CHANGE /
     TYPE_WS_MOVE). No change needed there.
   - The `call` directive used for all internal-function bindings is NOT in
     the docs; parser.c accepts it as an undocumented alias of `bind`, but
     docs are the contract — all 20 lines switched to `bind : … : func`
     (bare action = internal function; identical parse result).
   - Every function name used was verified against the docs' function
     table / parser call_table: focus_next/prev, master_next/prev,
     master_increase/decrease, close_window, toggle_monocle,
     global_floating, fullscreen, toggle_floating, increase/decrease_gaps,
     switch_previous_workspace, focus/move_next/prev_mon, reload_config.
     All exist with the exact names used.
   - The Xvfb stage gained a functional assertion: xdotool sends super+2
     and `_NET_CURRENT_DESKTOP` must move 0 → 1 (xprop -root), proving the
     workspace directives are grabbed and acted on, not merely parsed.

## D28 — Config-review hardening: dep coverage, PipeWire units, brave-browser, dead binds
Four user-directed items from the config review:
1. check-session-deps.sh now also parses the deployed sxwmrc: every quoted
   bind/exec action is unwrapped (sh -c bodies, st -e targets) and each
   command must resolve on PATH in the e2e container against the deployed
   user home (a voidrice script counts only if actually deployed).
   pulseaudio-utils (pactl, mic-mute bind) and xserver-xorg-input-synaptics
   (synclient, touchpad XF86 binds) were missing from the manifest and were
   added; wmctrl and wpctl were already covered (own entry, pipewire-bin).
   Caveat: the synaptics and libinput drivers both claim touchpads — the
   binds are XF86 corner keys and the check only enforces resolution.
2. PipeWire the Debian way: `pipewire` dropped from the xprofile autostart;
   debrice.sh runs `systemctl --global enable pipewire pipewire-pulse
   wireplumber`. `systemctl --user enable` as another user needs that
   user's session bus (absent pre-login); --global writes /etc/systemd/user
   symlinks offline and covers the single rice user. Units start at first
   graphical login; the runtime stage asserts the symlinks landed.
3. Brave's Debian package ships /usr/bin/brave-browser (plus
   brave-browser-stable) — no `brave` binary (verified in the e2e
   container). sxwmrc binds and BROWSER in .config/shell/profile fixed to
   brave-browser.
4. Dead upstream binds removed and recorded in DIFFERENCES.md: mod+c
   (profanity), mod+scroll_lock (screenkey), plus two more found by the
   audit — mod+shift+d (passmenu: dropped upstream at voidrice ad94491 and
   absent from Debian's pass package) and mod+f8 (mailsync: dropped
   upstream). LockMask: sxwm's grab guards mask LockMask, numlock (Mod2)
   and mode_switch in both key and button grabs (verified in src/sxwm.c),
   so NumLock does not break super+number — no README warning needed.

## D29 — apt fetch retries
Suite runs on the dev host's network kept dying on single-package download
hiccups (a local TLS-intercepting proxy failing individual fetches at
random). apt's default is zero retries, so one bad fetch failed the whole
package — and D26's per-package summary plus D28's FATAL pipewire-unit
check then (correctly) refused to let the partial install pass. apt_install
and the prereq loop now pass `-o Acquire::Retries=3`: a bootstrap is
nothing but downloads, and transient fetch failures should be absorbed,
not surfaced. Genuine resolution/availability failures still fail loudly.

## D30 — sxbar workspace-highlight audit (tracks correctly; hardened)
User report: workspaces switch fine but sxbar's active-workspace highlight
never updates on hardware. Full audit of sxbar.c + sxwm.c plus an Xvfb
reproduction with the shipped configs:
- sxbar reads _NET_CURRENT_DESKTOP and repaints on its PropertyNotify; the
  run loop also repaints every second unconditionally. sxwm sets every
  required atom at startup (SUPPORTED incl. desktop atoms,
  NUMBER_OF_DESKTOPS, DESKTOP_NAMES, CURRENT_DESKTOP, per-client
  WM_DESKTOP). No EWMH gap on either side; no patch needed.
- Our workspaces.* keys match the current parser exactly; sxbar.1 is an
  EMPTY file upstream — parser.c/default_sxbarc are the only authority.
- Xvfb reproduction: highlight at x=0 on ws1, moves to x=26 after super+2
  with the exec-started bar. The stage now asserts this permanently via a
  small XGetImage scanner compiled inline (finds the dock window by
  scanning the root tree — sxwm does not manage docks and excludes them
  from _NET_CLIENT_LIST, noted in DIFFERENCES.md §7).
- Real freeze candidates on hardware: a stale sxbar binary, a duplicate
  sxbar instance stacked over the good one, or a hung module — sxbar runs
  module commands with a blocking popen in its single event loop.
  Hardened our side: sb-forecast/sb-doppler curls get --max-time 20
  (documented in CHANGES-FROM-VOIDRICE.md); the design caveat is recorded
  in DIFFERENCES.md §7.
