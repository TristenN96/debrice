#!/bin/bash

# debrice — Debian ricing bootstrap.
# A port of Luke Smith's LARBS to Debian 13 Trixie, with sxwm (and sxbar)
# replacing dwm (and dwmblocks), Brave replacing Librewolf, and full TeX Live.
# License: GNU GPLv3 (like LARBS itself)

# Harden invocation: if executed via `sh` (dash on Debian), re-exec with bash.
if [ -z "${BASH_VERSION:-}" ]; then
	if [ -f "$0" ]; then
		exec bash "$0" "$@"
	fi
	printf '%s\n' "debrice.sh requires bash. Re-run it as: bash debrice.sh" >&2
	exit 1
fi

set -u

# Resolve the script's own location — never the caller's cwd — and load the
# function libraries from it when running from a full checkout. When
# debrice.sh was curl'd standalone there is no lib/ next to it; in that case
# bootstraprepo() clones the repo below and sources the libraries from the
# clone instead. Either way every helper (apt_install, add_brave_repo,
# gitmakeinstall, scriptinstall, progs_each, deploy_dotfiles,
# install_cheatsheet) is defined before its first call.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/packages.sh" ]; then
	# shellcheck source=lib/packages.sh
	. "$SCRIPT_DIR/lib/packages.sh"
	# shellcheck source=lib/builds.sh
	. "$SCRIPT_DIR/lib/builds.sh"
	# shellcheck source=lib/dotfiles.sh
	. "$SCRIPT_DIR/lib/dotfiles.sh"
fi

### OPTIONS AND VARIABLES ###

repourl="https://github.com/TristenN96/debrice.git"
repobranch="master"

# Non-interactive mode: skip every prompt. Enabled by --yes/-y or by setting
# DEBRICE_ASSUME_YES=1 in the environment. Credentials may then be supplied
# via DEBRICE_USER and DEBRICE_PASSWORD.
: "${DEBRICE_ASSUME_YES:=0}"

rssurls="https://lukesmith.xyz/rss.xml
https://videos.lukesmith.xyz/feeds/videos.xml?videoChannelId=2 \"~Luke Smith (Videos)\"
https://www.youtube.com/feeds/videos.xml?channel_id=UC2eYFnH61tmytImy1mTYvhA \"~Luke Smith (YouTube)\"
https://lindypress.net/rss
https://notrelated.xyz/rss
https://landchad.net/rss.xml
https://based.cooking/index.xml
https://artixlinux.org/feed.php \"tech\"
https://www.archlinux.org/feeds/news/ \"tech\"
https://github.com/LukeSmithxyz/voidrice/commits/master.atom \"~LARBS dotfiles\""

### FUNCTIONS ###

error() {
	# Report the actual failure, then exit. Headline: the call-site line and
	# a message naming the command that failed. Commands that can call
	# error() leave their stderr unsuppressed, so the real error text sits
	# directly above this line; any generic hint trails the specifics.
	printf 'FATAL: debrice.sh:%s: %s\n' "${BASH_LINENO[0]:-?}" "$1" >&2
	exit 1
}

assume_yes() {
	[ "$DEBRICE_ASSUME_YES" = 1 ]
}

say() {
	# Progress/status message (replaces the old whiptail infoboxes).
	printf '==> %s\n' "$*"
}

confirm() {
	# confirm QUESTION — plain, always-visible y/N prompt that works on a raw
	# Linux console TTY. Returns 0 on y/yes (case-insensitive), 1 on anything
	# else. Auto-accepts in assume-yes mode.
	assume_yes && return 0
	local ans
	printf '%s [y/N] ' "$1"
	read -r ans || return 1
	case "$ans" in
	[yY] | [yY][eE][sS]) return 0 ;;
	*) return 1 ;;
	esac
}

welcomemsg() {
	printf '\n%s\n\n' "Welcome to debrice!"
	printf '%s\n' \
		"This script will automatically install a fully-featured Linux desktop:" \
		"the LARBS setup by Luke Smith, ported to Debian 13 (Trixie), with the" \
		"sxwm window manager, the Brave browser and a complete TeX Live installation." \
		""
	confirm "Be sure this computer has a working internet connection and is running Debian 13 (Trixie). Continue?"
}

getuserandpass() {
	# Prompts user for new username and password. Non-interactive runs may
	# supply both via DEBRICE_USER and DEBRICE_PASSWORD.
	if [ -n "${DEBRICE_USER:-}" ] && [ -n "${DEBRICE_PASSWORD:-}" ]; then
		name="$DEBRICE_USER"
		pass1="$DEBRICE_PASSWORD"
	else
		[ -t 0 ] ||
			error "Cannot prompt for a username: stdin is not a TTY. Set DEBRICE_USER and DEBRICE_PASSWORD (together with DEBRICE_ASSUME_YES=1) or run interactively."
		printf 'First, please enter a name for the user account: '
		read -r name || exit 1
		while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
			printf 'Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _: '
			read -r name || exit 1
		done
		printf 'Enter a password for that user: '
		read -rs pass1 || exit 1
		printf '\nRetype password: '
		read -rs pass2 || exit 1
		printf '\n'
		while ! [ "$pass1" = "$pass2" ]; do
			unset pass2
			printf 'Passwords do not match. Enter password again: '
			read -rs pass1 || exit 1
			printf '\nRetype password: '
			read -rs pass2 || exit 1
			printf '\n'
		done
	fi
	echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$" ||
		error "Invalid username: $name"
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		confirm "WARNING: the user \`$name\` already exists. Conflicting settings/dotfiles will be OVERWRITTEN (they are backed up to ~/.config/debrice-backup-<timestamp> first) and $name's password will be changed. Continue?"
}

preinstallmsg() {
	confirm "The rest of the installation will now be totally automated (TeX Live alone is large, so it will take some time). Begin installation now?" ||
		exit 1
}

distrocheck() {
	. /etc/os-release
	[ "${ID:-}" = "debian" ] ||
		error "debrice targets Debian 13 (Trixie). This system reports ID=${ID:-unknown}. Aborting."
	[ "${VERSION_ID:-}" = "13" ] ||
		confirm "This system reports Debian ${VERSION_ID:-unknown}; debrice is tested on Debian 13 (Trixie) only. Continue anyway?" ||
		error "Aborted: not Debian 13."
}

bootstraprepo() {
	# When debrice.sh is run from a full checkout, use it; otherwise clone
	# the debrice repository to obtain progs.csv, lib/, dotfiles/ and static/.
	local scriptdir
	scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if [ -f "$scriptdir/progs.csv" ] && [ -d "$scriptdir/lib" ]; then
		DEBRICE_DIR="$scriptdir"
	elif [ -d /tmp/debrice-repo/.git ]; then
		DEBRICE_DIR="/tmp/debrice-repo"
		git -C "$DEBRICE_DIR" pull --force >/dev/null 2>&1 || true
	else
		say "Downloading the debrice repository..."
		git clone --depth 1 --single-branch --no-tags -q \
			-b "$repobranch" "$repourl" /tmp/debrice-repo ||
			error "Could not clone $repourl — check your internet connection."
		DEBRICE_DIR="/tmp/debrice-repo"
	fi
	export DEBRICE_DIR
	# Tests may point PROGS_FILE at a trimmed manifest; default to the repo's.
	export PROGS_FILE="${PROGS_FILE:-$DEBRICE_DIR/progs.csv}"
	export DEBRICE_DOTFILES_SRC="$DEBRICE_DIR/dotfiles"
	export DEBRICE_STATIC_SRC="$DEBRICE_DIR/static"
	# shellcheck source=lib/packages.sh
	. "$DEBRICE_DIR/lib/packages.sh"
	# shellcheck source=lib/builds.sh
	. "$DEBRICE_DIR/lib/builds.sh"
	# shellcheck source=lib/dotfiles.sh
	. "$DEBRICE_DIR/lib/dotfiles.sh"
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	say "Adding user \"$name\"..."
	useradd -m -G sudo -s /bin/zsh "$name" >/dev/null 2>&1 || {
		usermod -a -G sudo "$name"
		mkdir -p "/home/$name"
		chown "$name:$name" "/home/$name"
	}
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name:$name" "/home/$name/.local"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

maininstall() {
	# Installs all needed programs from the main repos.
	say "Installing \`$1\` ($n of $total). $2"
	apt_install "$1"
}

repoinstall() {
	# Installs a program from an external apt repository (added beforehand).
	say "Installing \`$1\` ($n of $total) from an external repository. $2"
	apt_install "$1"
}

gitinstall() {
	local prog bin
	prog="$(basename "$1" .git)"
	say "Installing \`$prog\` ($n of $total) via \`git\` and \`make\`. $2"
	gitmakeinstall "$1" ||
		error "git build failed: $prog (from $1). The failing step's output is above."
	# A build phase that installs nothing must be impossible to miss: verify
	# the binary actually landed. mutt-wizard installs `mw`; every other repo
	# ships a binary named after the repo.
	case "$prog" in
	mutt-wizard) bin=mw ;;
	*) bin="$prog" ;;
	esac
	command -v "$bin" >/dev/null 2>&1 ||
		error "git build of $prog completed but '$bin' is not on PATH."
}

installationloop() {
	total="$(progs_count)"
	n=0
	apt_ok=0 apt_fail=0 repo_ok=0 repo_fail=0 git_ok=0 script_ok=0
	failed_apt="" failed_repo=""
	progs_dispatch() {
		local tag="$1" program="$2" comment="$3"
		n=$((n + 1))
		case "$tag" in
		R)
			if repoinstall "$program" "$comment"; then
				repo_ok=$((repo_ok + 1))
			else
				repo_fail=$((repo_fail + 1))
				failed_repo="$failed_repo $program"
			fi
			;;
		G)
			gitinstall "$program" "$comment"
			git_ok=$((git_ok + 1))
			;;
		S)
			say "Installing \`$(basename "$program")\` ($n of $total) as a script. $comment"
			scriptinstall "$(basename "$program")" "$program" ||
				error "script install failed: $(basename "$program") (from $program)."
			[ -x "/usr/local/bin/$(basename "$program")" ] ||
				error "script install of $(basename "$program") finished but /usr/local/bin/$(basename "$program") is missing or not executable."
			script_ok=$((script_ok + 1))
			;;
		*)
			if maininstall "$program" "$comment"; then
				apt_ok=$((apt_ok + 1))
			else
				apt_fail=$((apt_fail + 1))
				failed_apt="$failed_apt $program"
			fi
			;;
		esac
	}
	progs_each progs_dispatch
	# The manifest ships G entries by design; if fewer builds landed than the
	# file declares, dispatch/parsing broke — fail loudly, never skip a whole
	# phase silently again.
	local g_expected
	g_expected="$(grep -c '^G,' "$PROGS_FILE")"
	[ "$git_ok" -eq "$g_expected" ] ||
		error "git build phase incomplete: $git_ok of $g_expected manifest git builds installed."
}

print_install_summary() {
	# Last-screen scoreboard: a silently skipped phase shows up as zeros here.
	say "Installation summary:"
	printf '    apt packages:   %d installed, %d failed%s\n' \
		"$apt_ok" "$apt_fail" "${failed_apt:+ — FAILED:${failed_apt}}"
	printf '    repo packages:  %d installed, %d failed%s\n' \
		"$repo_ok" "$repo_fail" "${failed_repo:+ — FAILED:${failed_repo}}"
	printf '    git builds:     %d installed (failures are FATAL, see above)\n' "$git_ok"
	printf '    scripts:        %d installed (failures are FATAL, see above)\n' "$script_ok"
	if [ "$apt_fail" -ne 0 ] || [ "$repo_fail" -ne 0 ]; then
		say "WARNING: some packages failed to install — re-run debrice.sh after fixing the entries named above."
	fi
}

vimplugininstall() {
	# Installs vim plugins.
	say "Installing neovim plugins..."
	mkdir -p "/home/$name/.config/nvim/autoload"
	curl -fsSLo "/home/$name/.config/nvim/autoload/plug.vim" \
		"https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
	chown -R "$name:$name" "/home/$name/.config/nvim"
	sudo -u "$name" nvim -c "PlugInstall|q|q" >/dev/null 2>&1 || true
}

finalize() {
	printf '\n%s\n\n' "All done!"
	printf '%s\n' \
		"Congrats! Provided there were no hidden errors, the script completed" \
		"successfully and all the programs and configuration files should be in place." \
		"" \
		"To run the new graphical environment, log out and log back in as your new" \
		"user, then run the command \"startx\" to start the graphical environment" \
		"(it will start automatically in tty1)." \
		"" \
		".t Luke (and the sxwm port by debrice)"
}

### THE ACTUAL SCRIPT ###

# Parse options.
for arg in "$@"; do
	case "$arg" in
	-y | --yes) DEBRICE_ASSUME_YES=1 ;;
	*) error "Unknown option: $arg (supported: --yes)" ;;
	esac
done

# Check if user is root.
[ "$(id -u)" = 0 ] || error "Please run debrice.sh as the root user."

# Never hang waiting for input that cannot arrive: without --yes, the script
# is interactive and needs a TTY on stdin.
if ! assume_yes && [ ! -t 0 ]; then
	error "debrice.sh is interactive but stdin is not a TTY. Re-run with DEBRICE_ASSUME_YES=1 or 'bash debrice.sh --yes' to skip all prompts (set DEBRICE_USER and DEBRICE_PASSWORD as well)."
fi

# stderr stays visible so a failure shows apt's own diagnosis above the
# FATAL line — never silently swap it for a generic guess.
apt-get update >/dev/null ||
	error "command failed: apt-get update (see apt output above). Check your internet connection and apt sources."

# Install the script prerequisites. Plain apt-get on purpose: this phase must
# also work on a standalone curl run, where the function libraries only exist
# after bootstraprepo() clones the repo.
say "Installing script prerequisites..."
for x in curl ca-certificates git gnupg zsh; do
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$x" >/dev/null ||
		error "command failed: apt-get install -y --no-install-recommends $x (see apt output above). Generic hint: run as root, on Debian 13, with a working internet connection."
done

distrocheck

# Welcome user.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

# Test/CI hook: stop after the interactive preflight phase.
if [ "${DEBRICE_PREFLIGHT_ONLY:-0}" = 1 ]; then
	say "Preflight checks passed; stopping before installation (DEBRICE_PREFLIGHT_ONLY=1)."
	exit 0
fi

### The rest of the script requires no user input.

# Obtain progs.csv, lib/, dotfiles/ and static/ (clone if curl'd standalone).
bootstraprepo

# Add external apt repositories (Brave). Idempotent.
say "Adding the Brave browser repository..."
add_brave_repo || error "Could not add the Brave repository."

adduserandpass || error "Error adding username and/or password."

# Allow user to run sudo without password for the duration of the install.
# /etc/sudoers.d only exists once the sudo package is installed (or not at
# all on a sudo-less system) — create it.
mkdir -p /etc/sudoers.d
trap 'rm -f /etc/sudoers.d/debrice-temp' HUP INT QUIT TERM PWR EXIT
echo "%sudo ALL=(ALL) NOPASSWD: ALL
Defaults:%sudo,root runcwd=*" >/etc/sudoers.d/debrice-temp

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required.
installationloop

# Install the dotfiles into the user's home directory, backing up any
# existing configs they overwrite.
deploy_dotfiles "$name" "/home/$name"

# Install the ported keybinding cheat sheet (super+F1).
install_cheatsheet "$DEBRICE_STATIC_SRC"

# Write urls for newsboat if it doesn't already exist
[ -s "/home/$name/.config/newsboat/urls" ] ||
	echo "$rssurls" | sudo -u "$name" tee "/home/$name/.config/newsboat/urls" >/dev/null

# Install vim plugins if not already present.
[ ! -f "/home/$name/.config/nvim/autoload/plug.vim" ] && vimplugininstall

# Most important command! Get rid of the beep!
rmmod pcspkr 2>/dev/null || true
mkdir -p /etc/modprobe.d
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1 || true
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# Keep dash as the default #!/bin/sh interpreter (Debian default; guard anyway).
[ "$(readlink -f /bin/sh)" = /bin/dash ] || ln -sfT /bin/dash /bin/sh

# Ensure a dbus machine id exists.
command -v dbus-uuidgen >/dev/null 2>&1 && dbus-uuidgen --ensure >/dev/null 2>&1

# Enable tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && {
	mkdir -p /etc/X11/xorg.conf.d
	printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf
}

# Debian's bat package ships the binary as batcat; voidrice scripts expect bat.
if [ ! -x /usr/local/bin/bat ] && command -v batcat >/dev/null 2>&1; then
	ln -sf "$(command -v batcat)" /usr/local/bin/bat
fi

# Allow sudo users to sudo with password and allow several system commands
# (like `shutdown`) to run without password.
echo "%sudo ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-debrice-sudo-can-sudo
echo "%sudo ALL=(ALL:ALL) NOPASSWD: /usr/sbin/shutdown,/usr/sbin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/loadkeys,/usr/bin/apt-get update,/usr/bin/apt-get upgrade" >/etc/sudoers.d/01-debrice-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-debrice-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" >/etc/sysctl.d/dmesg.conf

# Cleanup
rm -f /etc/sudoers.d/debrice-temp

# Last message! Install complete! Print the per-phase scoreboard first, so a
# silently skipped phase is visible in the final screen of output.
print_install_summary
finalize
