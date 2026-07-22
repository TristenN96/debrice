#!/bin/bash
# debrice — lib/dotfiles.sh
# Deployment of the vendored voidrice fork plus the sxwm/sxbar configs.
# Every overwritten file is first backed up to
# ~/.config/debrice-backup-<timestamp>/ so the script is safe to re-run.

# deploy_dotfiles USER HOME — copy $DEBRICE_DOTFILES_SRC into HOME, then
# overlay $DEBRICE_STATIC_SRC/sxwmrc into ~/.config, sxbarc into
# ~/.config/sxbar/ (sxbar's preferred config path), picom.conf into
# ~/.config/picom/, and install $DEBRICE_STATIC_SRC/ship.jpg as the
# default ~/.local/share/bg wallpaper.
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
		printf './.config/sxwmrc\n./.config/sxbarc\n./.config/sxbar/sxbarc\n./.config/picom/picom.conf\n'
	} | while read -r rel; do
		rel="${rel#./}"
		if [ -e "$home/$rel" ] || [ -L "$home/$rel" ]; then
			mkdir -p "$backup/$(dirname "$rel")"
			cp -a "$home/$rel" "$backup/$rel" 2>/dev/null || true
		fi
	done

	# Deploy: -rdT merges the tree and keeps symlinks as symlinks.
	cp -rdT "$src" "$home" || return 1

	# Overlay the sxwm/sxbar configs from static/. sxbarc goes to
	# ~/.config/sxbar/sxbarc — upstream's preferred path (src/parser.c
	# get_config_path: $XDG_CONFIG_HOME/sxbar/sxbarc, then
	# ~/.config/sxbar/sxbarc, then the LEGACY ~/.config/sxbarc, then
	# /usr/local/share/sxbarc, which `make install` populates with the
	# upstream default). Deploying to the legacy path would silently lose
	# to any preferred-path file, and a missing config silently falls
	# through to the upstream default.
	mkdir -p "$home/.config" "$home/.config/sxbar"
	[ -f "$static/sxwmrc" ] && cp -f "$static/sxwmrc" "$home/.config/sxwmrc"
	if [ -f "$static/sxbarc" ]; then
		cp -f "$static/sxbarc" "$home/.config/sxbar/sxbarc"
		# Remove a stale legacy-path sxbarc (already backed up above):
		# sxbar only reads it when the preferred path is absent, and a
		# leftover copy invites edits to a file the bar ignores.
		rm -f "$home/.config/sxbarc"
	fi

	# Overlay the picom config (Debian 13's picom FATALs without an
	# explicit backend — see static/picom.conf).
	if [ -f "$static/picom.conf" ]; then
		mkdir -p "$home/.config/picom"
		cp -f "$static/picom.conf" "$home/.config/picom/picom.conf"
	fi

	# Default wallpaper: static/ship.jpg replaces voidrice's default bg
	# (a symlink to thiemeyer_road_to_samarkand.jpg). bg stays a symlink
	# next to the image, so the stock setbg mechanism works unchanged.
	if [ -f "$static/ship.jpg" ]; then
		mkdir -p "$home/.local/share"
		cp -f "$static/ship.jpg" "$home/.local/share/ship.jpg"
		ln -sf "ship.jpg" "$home/.local/share/bg"
	fi

	# Hand everything to the user.
	if [ -n "$name" ]; then
		local top
		(cd "$src" && find . -mindepth 1 -maxdepth 1 -printf '%P\n') | while read -r top; do
			[ -e "$home/$top" ] || [ -L "$home/$top" ] || continue
			chown -R "$name:$name" "$home/$top" 2>/dev/null || true
		done
		[ -e "$home/.config/sxwmrc" ] && chown "$name:$name" "$home/.config/sxwmrc"
		[ -d "$home/.config/sxbar" ] && chown -R "$name:$name" "$home/.config/sxbar"
		[ -d "$home/.config/picom" ] && chown -R "$name:$name" "$home/.config/picom"
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
