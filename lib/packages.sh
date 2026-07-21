#!/bin/bash
# debrice — lib/packages.sh
# progs.csv parsing, apt helpers and external (Brave) repository setup.
# Sourced by debrice.sh and by the container tests; expects to run as root.

BRAVE_KEYRING="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
BRAVE_KEYRING_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
BRAVE_SOURCES="/etc/apt/sources.list.d/brave-browser-release.list"
BRAVE_SOURCE_LINE="deb [signed-by=${BRAVE_KEYRING}] https://brave-browser-apt-release.s3.brave.com/ stable main"

# apt_install PKG [PKG...] — non-interactive apt install.
apt_install() {
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >/dev/null 2>&1
}

# add_brave_repo — add Brave's official apt repository and keyring.
# Idempotent: rewrites nothing and does not re-run apt-get update when the
# keyring and sources entry already exist with the expected content.
add_brave_repo() {
	local changed=0
	if [ ! -s "$BRAVE_KEYRING" ]; then
		curl -fsSLo "$BRAVE_KEYRING" "$BRAVE_KEYRING_URL" || return 1
		chmod 644 "$BRAVE_KEYRING"
		changed=1
	fi
	if [ ! -f "$BRAVE_SOURCES" ] || ! grep -qF "$BRAVE_SOURCE_LINE" "$BRAVE_SOURCES"; then
		echo "$BRAVE_SOURCE_LINE" >"$BRAVE_SOURCES"
		changed=1
	fi
	if [ "$changed" -eq 1 ] || [ "${DEBRICE_FORCE_APT_UPDATE:-0}" = 1 ]; then
		apt-get update >/dev/null 2>&1 || return 1
	fi
	return 0
}

# progs_each CALLBACK — read progs.csv and invoke CALLBACK TAG NAME COMMENT
# for every non-comment line. CSV format: TAG,NAME,"PURPOSE".
progs_each() {
	local callback="$1" tag name comment
	while IFS=, read -r tag name comment; do
		case "$tag" in \#*) continue ;; esac
		[ -z "$name" ] && continue
		# Strip surrounding double quotes from the comment.
		comment="${comment%\"}"
		comment="${comment#\"}"
		"$callback" "$tag" "$name" "$comment"
	done <"$PROGS_FILE"
}

# progs_count — number of installable entries (for progress display).
progs_count() {
	grep -cv '^\s*#\|^\s*$' "$PROGS_FILE"
}
