#!/bin/bash
# debrice — scripts/check-binds.sh
# Machine-checkable keybinding coverage test.
#
# Parses the keys[] array of Luke's dwm config.h (vendored at
# static/dwm-config.h, upstream ee3354d), expands the STACKKEYS/TAGKEYS
# macros, and asserts that every binding's mod+key combo is either
#   a) present in static/sxwmrc (bind/call/workspace/scratchpad line), or
#   b) listed in DIFFERENCES.md as intentionally dropped.
# For dwm spawn bindings that are present, it additionally asserts the
# spawned command's first token appears in the sxwmrc action (with a small
# exception table for deliberate adaptations). Zero unaccounted-for
# bindings is the pass condition.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGH="$REPO/static/dwm-config.h"
SXWMRC="$REPO/static/sxwmrc"
DIFFS="$REPO/DIFFERENCES.md"

for f in "$CONFIGH" "$SXWMRC" "$DIFFS"; do
	[ -f "$f" ] || { echo "MISSING: $f" >&2; exit 1; }
done

# norm_combo MODS KEY — normalize a dwm mod-mask + keysym to a canonical
# combo string (mods sorted, lowercase key, XF86XK_Foo -> xf86foo).
norm_combo() {
	local mods="$1" key="$2"
	key="${key#XK_}"
	case "$key" in
	XF86XK_*) key="XF86${key#XF86XK_}" ;;
	esac
	key="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')"
	[ "$mods" = "0" ] && mods=""
	local m part
	local -a conv=()
	IFS='|' read -ra parts <<<"$mods"
	for part in "${parts[@]}"; do
		case "$part" in
		MODKEY | Mod4Mask) m="mod" ;;
		ShiftMask) m="shift" ;;
		ControlMask) m="ctrl" ;;
		Mod1Mask) m="alt" ;;
		"") continue ;;
		*)
			echo "check-binds: unknown modifier '$part'" >&2
			exit 1
			;;
		esac
		conv+=("$m")
	done
	local sorted
	if [ "${#conv[@]}" -gt 0 ]; then
		sorted="$(printf '%s\n' "${conv[@]}" | sort -u | paste -sd+ -)"
	else
		sorted=""
	fi
	if [ -n "$sorted" ]; then
		printf '%s+%s\n' "$sorted" "$key"
	else
		printf '%s\n' "$key"
	fi
}

# spawn_token LINE — extract the first command token of a dwm spawn entry.
spawn_token() {
	local line="$1" tok
	case "$line" in
	*SHCMD*TERMINAL*) tok="st" ;;
	*SHCMD*) tok="$(printf '%s' "$line" | sed -n 's/.*SHCMD("\([^"]*\)".*/\1/p' | awk '{print $1}')" ;;
	*termcmd*) tok="st" ;;
	*BROWSER*) tok="librewolf" ;;
	*)
		tok="$(printf '%s' "$line" | sed -n 's/.*{\.v = (const char\*\[\]){ "\([^"]*\)".*/\1/p')"
		;;
	esac
	# Deliberate adaptations (documented in DIFFERENCES.md).
	case "$tok" in
	librewolf) tok="brave" ;;
	sudo) tok="systemctl" ;; # "sudo -A zzz" -> "systemctl suspend"
	esac
	printf '%s\n' "$tok"
}

# sxwmrc_combo LINE — normalize the combo of an sxwmrc bind line.
sxwmrc_combo() {
	local line="$1" combo key sorted
	combo="$(printf '%s' "$line" | cut -d: -f2)"
	key="$(printf '%s' "$combo" | awk -F+ '{print $NF}' | tr -d ' \t' | tr '[:upper:]' '[:lower:]')"
	sorted="$(printf '%s' "$combo" | tr '+' '\n' | head -n -1 |
		sed 's/[ \t]//g' | sed 's/^super$/mod/' | sort -u | paste -sd+ -)"
	if [ -n "$sorted" ]; then
		printf '%s+%s\n' "$sorted" "$key"
	else
		printf '%s\n' "$key"
	fi
}

# Build the sxwmrc lookup tables once: SXWM_SET[combo]=1 for presence tests,
# SXWM_ACT[combo]=action for spawn-token verification.
declare -A SXWM_SET SXWM_ACT
build_sxwm_tables() {
	local line combo
	while IFS= read -r line; do
		combo="$(sxwmrc_combo "$line")"
		SXWM_SET["$combo"]=1
		SXWM_ACT["$combo"]="$line"
	done < <(grep -E '^\s*(bind|call|workspace|scratchpad)\s*:' "$SXWMRC")
}

# Collect every dwm binding as "combo|first-token-or-empty".
collect_dwm_binds() {
	local inblock=0 line mods key tok
	while IFS= read -r line; do
		case "$line" in
		*'static const Key keys[]'*) inblock=1; continue ;;
		esac
		[ "$inblock" = 1 ] || continue
		case "$line" in
		'};'*) break ;;
		esac
		# Strip single-line /* ... */ comments; skip what is left blank.
		line="$(printf '%s' "$line" | sed 's|/\*[^*]*\*/||g')"
		line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		[ -z "$line" ] && continue
		case "$line" in
		STACKKEYS\(MODKEY,*)
			for key in XK_j XK_k XK_v; do
				printf '%s|\n' "$(norm_combo MODKEY "$key")"
			done
			;;
		STACKKEYS\(MODKEY\|ShiftMask,*)
			for key in XK_j XK_k XK_v; do
				printf '%s|\n' "$(norm_combo 'MODKEY|ShiftMask' "$key")"
			done
			;;
		TAGKEYS\(*)
			key="$(printf '%s' "$line" | sed -n 's/TAGKEYS([[:space:]]*\([^,)]*\).*/\1/p' | tr -d '[:space:]')"
			printf '%s|\n' "$(norm_combo MODKEY "$key")"
			printf '%s|\n' "$(norm_combo 'MODKEY|ControlMask' "$key")"
			printf '%s|\n' "$(norm_combo 'MODKEY|ShiftMask' "$key")"
			printf '%s|\n' "$(norm_combo 'MODKEY|ControlMask|ShiftMask' "$key")"
			;;
		\{*)
			mods="$(printf '%s' "$line" | sed -n 's/^{\s*\([^,]*\),.*/\1/p' | tr -d '[:space:]')"
			key="$(printf '%s' "$line" | sed -n 's/^\s*{[^,]*,\s*\([^,]*\),.*/\1/p' | tr -d '[:space:]')"
			if [ -z "$mods" ] || [ -z "$key" ]; then
				continue
			fi
			case "$line" in
			*spawn*)
				tok="$(spawn_token "$line")"
				printf '%s|%s\n' "$(norm_combo "$mods" "$key")" "$tok"
				;;
			*)
				printf '%s|\n' "$(norm_combo "$mods" "$key")"
				;;
			esac
			;;
		esac
	done <"$CONFIGH"
}

main() {
	local binds total=0 missing=0 wrongcmd=0 combo tok
	build_sxwm_tables
	binds="$(collect_dwm_binds)"
	total="$(printf '%s\n' "$binds" | wc -l)"
	while IFS='|' read -r combo tok; do
		[ -n "$combo" ] || continue
		if [ "${SXWM_SET[$combo]:-}" = 1 ]; then
			# Present: for spawns, the command token must survive the port.
			if [ -n "$tok" ] && ! printf '%s' "${SXWM_ACT[$combo]}" | grep -qF "$tok"; then
				printf 'WRONG CMD: %-28s expected token "%s" in action\n' "$combo" "$tok"
				wrongcmd=$((wrongcmd + 1))
			fi
		elif ! grep -qF "$combo" "$DIFFS"; then
			printf 'UNACCOUNTED: %s (not in sxwmrc, not in DIFFERENCES.md)\n' "$combo"
			missing=$((missing + 1))
		fi
	done <<<"$binds"
	printf 'check-binds: %d dwm bindings, %d unaccounted, %d wrong-command\n' \
		"$total" "$missing" "$wrongcmd"
	if [ "$missing" -eq 0 ] && [ "$wrongcmd" -eq 0 ]; then
		echo "KEYBINDING COVERAGE OK"
		return 0
	fi
	return 1
}

main "$@"
