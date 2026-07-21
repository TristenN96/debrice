#!/bin/bash
# debrice — lib/dotfiles.sh
# Deployment of the vendored voidrice fork plus the sxwm/sxbar configs.
# Every overwritten file is first backed up to
# ~/.config/debrice-backup-<timestamp>/ so the script is safe to re-run.

# deploy_dotfiles USER HOME — copy $DEBRICE_DOTFILES_SRC into HOME, then
# overlay $DEBRICE_STATIC_SRC/sxwmrc and sxbarc into ~/.config.
# USER may be empty (tests); then no chown/sudo -u is attempted.
deploy_dotfiles() {
	local name="$1" home="$2" src static ts backup rel
	src="${DEBRICE_DOTFILES_SRC:?DEBRICE_DOTFILES_SRC not set}"
	static="${DEBRICE_STATIC_SRC:?DEBRICE_STATIC_SRC not set}"
	[ -d "$src" ] || return 1
	[ -d "$home" ] || return 1
	ts="$(date +%Y%m%d-%H%M%S.%N)"
	backup="$home/.config/debrice-backup-$ts"

	# Back up anything that would be overwritten (dotfiles tree + overlays).
	{
		(cd "$src" && find . -mindepth 1 \( -type f -o -type l \) -print)
		printf './.config/sxwmrc\n./.config/sxbarc\n'
	} | while read -r rel; do
		rel="${rel#./}"
		if [ -e "$home/$rel" ] || [ -L "$home/$rel" ]; then
			mkdir -p "$backup/$(dirname "$rel")"
			cp -a "$home/$rel" "$backup/$rel" 2>/dev/null || true
		fi
	done

	# Deploy: -rdT merges the tree and keeps symlinks as symlinks.
	cp -rdT "$src" "$home" || return 1

	# Overlay the sxwm/sxbar configs from static/.
	mkdir -p "$home/.config"
	[ -f "$static/sxwmrc" ] && cp -f "$static/sxwmrc" "$home/.config/sxwmrc"
	[ -f "$static/sxbarc" ] && cp -f "$static/sxbarc" "$home/.config/sxbarc"

	# Hand everything to the user.
	if [ -n "$name" ]; then
		local top
		(cd "$src" && find . -mindepth 1 -maxdepth 1 -printf '%P\n') | while read -r top; do
			[ -e "$home/$top" ] || [ -L "$home/$top" ] || continue
			chown -R "$name:$name" "$home/$top" 2>/dev/null || true
		done
		[ -e "$home/.config/sxwmrc" ] && chown "$name:$name" "$home/.config/sxwmrc"
		[ -e "$home/.config/sxbarc" ] && chown "$name:$name" "$home/.config/sxbarc"
		[ -d "$backup" ] && chown -R "$name:$name" "$backup"
	fi
	return 0
}

# install_cheatsheet STATIC_DIR — install the ported larbs.mom where the
# super+F1 binding and sb-help-icon expect it.
install_cheatsheet() {
	local static="${1:-$DEBRICE_STATIC_SRC}"
	[ -f "$static/larbs.mom" ] || return 0
	mkdir -p /usr/local/share/debrice
	cp -f "$static/larbs.mom" /usr/local/share/debrice/larbs.mom
}
