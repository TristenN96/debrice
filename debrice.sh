#!/bin/bash

# debrice — Debian ricing bootstrap.
# A port of Luke Smith's LARBS to Debian 13 Trixie, with sxwm (and sxbar)
# replacing dwm (and dwmblocks), Brave replacing Librewolf, and full TeX Live.
# License: GNU GPLv3 (like LARBS itself)

set -u

### OPTIONS AND VARIABLES ###

repourl="https://github.com/debrice/debrice.git"
repobranch="master"
export TERM=ansi

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
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Welcome!" \
		--msgbox "Welcome to debrice!\\n\\nThis script will automatically install a fully-featured Linux desktop: the LARBS setup by Luke Smith, ported to Debian 13 (Trixie), with the sxwm window manager, the Brave browser and a complete TeX Live installation.\\n\\nEnjoy!" 12 70

	whiptail --title "Important Note!" --yes-button "All ready!" \
		--no-button "Return..." \
		--yesno "Be sure the computer you are using has a working internet connection and is running Debian 13 (Trixie).\\n\\nIf it does not, the installation of some programs might fail." 9 70
}

getuserandpass() {
	# Prompts user for new username and password.
	name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNING" --yes-button "CONTINUE" \
			--no-button "No wait..." \
			--yesno "The user \`$name\` already exists on this system. debrice can install for a user already existing, but it will OVERWRITE any conflicting settings/dotfiles on the user account (they are backed up to ~/.config/debrice-backup-<timestamp> first).\\n\\ndebrice will NOT overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that debrice will change $name's password to the one you just gave." 15 75
}

preinstallmsg() {
	whiptail --title "Let's get this party started!" --yes-button "Let's go!" \
		--no-button "No, nevermind!" \
		--yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time (TeX Live alone is large), but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || {
		clear
		exit 1
	}
}

distrocheck() {
	. /etc/os-release
	[ "${ID:-}" = "debian" ] ||
		error "debrice targets Debian 13 (Trixie). This system reports ID=${ID:-unknown}. Aborting."
	[ "${VERSION_ID:-}" = "13" ] ||
		whiptail --title "Untested Debian version" --yes-button "Continue anyway" \
			--no-button "Abort" \
			--yesno "This system reports Debian ${VERSION_ID:-unknown}; debrice is tested on Debian 13 (Trixie) only." 9 65 ||
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
		whiptail --infobox "Downloading the debrice repository..." 7 50
		git clone --depth 1 --single-branch --no-tags -q \
			-b "$repobranch" "$repourl" /tmp/debrice-repo ||
			error "Could not clone $repourl — check your internet connection."
		DEBRICE_DIR="/tmp/debrice-repo"
	fi
	export DEBRICE_DIR
	export PROGS_FILE="$DEBRICE_DIR/progs.csv"
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
	whiptail --infobox "Adding user \"$name\"..." 7 50
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
	whiptail --title "debrice Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
	apt_install "$1"
}

repoinstall() {
	# Installs a program from an external apt repository (added beforehand).
	whiptail --title "debrice Installation" --infobox "Installing \`$1\` ($n of $total) from an external repository. $1 $2" 9 70
	apt_install "$1"
}

gitinstall() {
	local prog
	prog="$(basename "$1" .git)"
	whiptail --title "debrice Installation" \
		--infobox "Installing \`$prog\` ($n of $total) via \`git\` and \`make\`. $prog $2" 8 70
	gitmakeinstall "$1"
}

installationloop() {
	total="$(progs_count)"
	n=0
	progs_dispatch() {
		local tag="$1" program="$2" comment="$3"
		n=$((n + 1))
		case "$tag" in
		R) repoinstall "$program" "$comment" ;;
		G) gitinstall "$program" "$comment" ;;
		S) scriptinstall "$program" "$comment" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	}
	progs_each progs_dispatch
}

vimplugininstall() {
	# Installs vim plugins.
	whiptail --infobox "Installing neovim plugins..." 7 60
	mkdir -p "/home/$name/.config/nvim/autoload"
	curl -fsSLo "/home/$name/.config/nvim/autoload/plug.vim" \
		"https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
	chown -R "$name:$name" "/home/$name/.config/nvim"
	sudo -u "$name" nvim -c "PlugInstall|q|q" >/dev/null 2>&1 || true
}

finalize() {
	whiptail --title "All done!" \
		--msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Luke (and the sxwm port by debrice)" 13 80
}

### THE ACTUAL SCRIPT ###

# Check if user is root on Debian. Install the dialog prerequisites.
[ "$(id -u)" = 0 ] || error "Please run debrice.sh as the root user."
distrocheck

apt-get update >/dev/null 2>&1 ||
	error "Could not refresh apt. Check your internet connection and sources."

for x in whiptail curl ca-certificates git gnupg zsh; do
	apt_install "$x" ||
		error "Are you sure you're running this as the root user, are on Debian 13 and have an internet connection?"
done

# Welcome user.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

# Obtain progs.csv, lib/, dotfiles/ and static/ (clone if curl'd standalone).
bootstraprepo

# Add external apt repositories (Brave). Idempotent.
whiptail --infobox "Adding the Brave browser repository..." 7 50
add_brave_repo || error "Could not add the Brave repository."

adduserandpass || error "Error adding username and/or password."

# Allow user to run sudo without password for the duration of the install.
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

# Last message! Install complete!
finalize
