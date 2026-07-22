#!/bin/bash
# debrice — scripts/check-session-deps.sh
# Session dependency check.
#
# Extracts every external command the deployed xinitrc and xprofile invoke
# and asserts each one resolves on PATH. A session file that references a
# missing binary must fail the build here, not the user's first startx —
# bare metal died at "dbus-launch: not found" because Debian splits
# dbus-launch into dbus-x11.
#
# Usage: check-session-deps.sh [--extra-path DIR] [FILE ...]
#   --extra-path DIR  append DIR to PATH for the resolution check
#                     (repeatable; use it for the user's ~/.local/bin)
#   FILE              session files to check; defaults to the deployed
#                     ~/.config/x11/xinitrc, ~/.config/x11/xprofile and
#                     ~/.xprofile (whichever exist)
set -u
set -f # no globbing: tokens are expanded unquoted below

EXTRA_PATHS=()
FILES=()
while [ $# -gt 0 ]; do
	case "$1" in
	--extra-path)
		shift
		[ $# -gt 0 ] || { echo "check-session-deps: --extra-path needs a DIR" >&2; exit 2; }
		EXTRA_PATHS+=("$1")
		;;
	*) FILES+=("$1") ;;
	esac
	shift
done

if [ "${#FILES[@]}" -eq 0 ]; then
	cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
	[ -f "$cfg/x11/xinitrc" ] && FILES+=("$cfg/x11/xinitrc")
	[ -f "$cfg/x11/xprofile" ] && FILES+=("$cfg/x11/xprofile")
	[ -f "$HOME/.xprofile" ] && FILES+=("$HOME/.xprofile")
fi
[ "${#FILES[@]}" -gt 0 ] ||
	{ echo "check-session-deps: no session files found" >&2; exit 1; }
for f in "${FILES[@]}"; do
	[ -f "$f" ] || { echo "check-session-deps: not a file: $f" >&2; exit 1; }
done

for d in ${EXTRA_PATHS[@]+"${EXTRA_PATHS[@]}"}; do
	PATH="$PATH:$d"
done
export PATH

# Shell keywords and builtins are not external commands. The list lives in a
# variable rather than a case pattern because bash rejects a pattern list
# that starts with a reserved word.
SHELL_WORDS="if then else elif fi for while until do done case esac select in time function coproc ! . : [ ] alias bg bind break builtin cd command compgen complete compopt continue declare dirs disown echo enable eval exec exit export false fc fg getopts hash help history jobs kill let local logout mapfile popd printf pushd pwd read readarray readonly return set shift shopt source suspend test times trap true type typeset ulimit umask unalias unset wait"

# is_shell_word WORD — true if WORD is a shell keyword or builtin.
is_shell_word() {
	case " $SHELL_WORDS " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

# extract_commands FILE — print candidate command names, one per line.
# Tokenizes each non-comment line on whitespace and shell metacharacters and
# keeps bare lowercase words that are not keywords, builtins, loop variables,
# flags, numbers, assignments, paths or expansions. Arguments survive too:
# `dbus-launch ssh-agent sxwm` runs its arguments as the session command.
extract_commands() {
	local file="$1" line tok var
	local -A loopvar=()
	while IFS= read -r line; do
		line="${line%%#*}"
		# `for x in ...` declares a loop variable, not a command.
		case "$line" in
		*for\ *\ in*)
			var="$(printf '%s' "$line" | sed -n 's/.*for \([a-zA-Z_][a-zA-Z0-9_]*\) in.*/\1/p')"
			[ -n "$var" ] && loopvar["$var"]=1
			;;
		esac
		# shellcheck disable=SC2086
		for tok in $(printf '%s' "$line" | tr ' \t;&|()<>"'\''\\*?[]!' ' '); do
			case "$tok" in
			"" | -* | [0-9]* | *[=/{}$\`]* | *=* | [A-Z]*) continue ;;
			esac
			is_shell_word "$tok" && continue
			[ "${loopvar[$tok]:-}" = 1 ] && continue
			printf '%s\n' "$tok"
		done
	done <"$file"
}

cmds="$(for f in "${FILES[@]}"; do extract_commands "$f"; done | sort -u)"
count="$(printf '%s\n' "$cmds" | grep -c .)"

# Sanity guard: an extraction that finds debrice's session files must find
# the WM itself and a plausible command set — otherwise the parser above
# broke and the check would pass vacuously.
printf '%s\n' "$cmds" | grep -qx sxwm ||
	{ echo "check-session-deps: extraction broken (sxwm not found in session files)" >&2; exit 1; }
[ "$count" -ge 8 ] ||
	{ echo "check-session-deps: extraction broken (only $count commands found)" >&2; exit 1; }

fail=0
while IFS= read -r c; do
	[ -n "$c" ] || continue
	if command -v "$c" >/dev/null 2>&1; then
		printf 'ok:      %s\n' "$c"
	else
		printf 'MISSING: %s\n' "$c"
		fail=1
	fi
done <<<"$cmds"

if [ "$fail" -ne 0 ]; then
	echo "check-session-deps: session files reference commands not on PATH" >&2
	exit 1
fi
echo "SESSION DEPS OK ($count commands checked: ${FILES[*]})"
