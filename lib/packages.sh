#!/bin/bash
# debrice — lib/packages.sh
# progs.csv parsing, apt helpers and external (Brave) repository setup.
# Sourced by debrice.sh and by the container tests; expects to run as root.

# Paths and repo metadata. Assignments are defaults only: the container tests
# override them via the environment to run without root.
: "${BRAVE_KEYRING:=/usr/share/keyrings/brave-browser-archive-keyring.gpg}"
: "${BRAVE_SOURCES:=/etc/apt/sources.list.d/brave-browser-release.list}"
: "${BRAVE_KEYRING_URL:=https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg}"
: "${BRAVE_SOURCE_LINE:=deb [signed-by=${BRAVE_KEYRING}] https://brave-browser-apt-release.s3.brave.com/ stable main}"

# apt_install PKG [PKG...] — non-interactive apt install. stderr stays
# visible: a failed install must show apt's own diagnosis.
apt_install() {
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >/dev/null
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
	if [ "${DEBRICE_SKIP_APT_UPDATE:-0}" != 1 ] &&
		{ [ "$changed" -eq 1 ] || [ "${DEBRICE_FORCE_APT_UPDATE:-0}" = 1 ]; }; then
		apt-get update >/dev/null 2>&1 || return 1
	fi
	return 0
}

# progs_each CALLBACK — read progs.csv and invoke CALLBACK TAG NAME COMMENT
# for every non-comment line. CSV format: TAG,NAME,"PURPOSE".
# Locals are pe_-prefixed on purpose: bash's dynamic scoping would make a
# plain `local name` here visible to every callback invoked below, clobbering
# debrice.sh's global $name (the username) inside gitmakeinstall's sudo -u.
progs_each() {
	local pe_callback="$1" pe_tag pe_name pe_comment
	while IFS=, read -r pe_tag pe_name pe_comment; do
		case "$pe_tag" in \#*) continue ;; esac
		[ -z "$pe_name" ] && continue
		# Strip surrounding double quotes from the comment.
		pe_comment="${pe_comment%\"}"
		pe_comment="${pe_comment#\"}"
		"$pe_callback" "$pe_tag" "$pe_name" "$pe_comment"
	done <"$PROGS_FILE"
}

# progs_count — number of installable entries (for progress display).
progs_count() {
	grep -cv '^\s*#\|^\s*$' "$PROGS_FILE"
}
