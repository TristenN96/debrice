#!/bin/bash
# debrice — scripts/check-session-deps.sh
# Session and keybinding dependency check.
#
# Two sources of truth, one guarantee: no command the session or the
# keybindings invoke may be missing on PATH.
#
# 1. Session files (xinitrc/xprofile): every external command they invoke
#    must resolve — bare metal died at "dbus-launch: not found" because
#    Debian splits dbus-launch into dbus-x11.
# 2. sxwmrc (--sxwmrc): the command inside every quoted bind/exec action
#    must resolve (wpctl, wmctrl, sysact, st -e <cmd>, sh -c '...' bodies,
#    ...). A bind whose command is missing is a dead key on real hardware.
#    voidrice scripts count as present only when actually deployed — pass
#    the user's deployed ~/.local/bin via --extra-path.
#
# Usage: check-session-deps.sh [--extra-path DIR] [--sxwmrc FILE] [FILE ...]
#   --extra-path DIR  append DIR to PATH for the resolution check
#                     (repeatable; use it for the user's ~/.local/bin)
#   --sxwmrc FILE     also extract and check quoted bind/exec actions
#   FILE              session files to check; with no FILE and no --sxwmrc,
#                     defaults to the deployed ~/.config/x11/xinitrc,
#                     ~/.config/x11/xprofile, ~/.xprofile and ~/.config/sxwmrc
set -u
set -f # no globbing: tokens are expanded unquoted below

EXTRA_PATHS=()
FILES=()
SXWMRC=""
while [ $# -gt 0 ]; do
	case "$1" in
	--extra-path)
		shift
		[ $# -gt 0 ] || { echo "check-session-deps: --extra-path needs a DIR" >&2; exit 2; }
		EXTRA_PATHS+=("$1")
		;;
	--sxwmrc)
		shift
		[ $# -gt 0 ] || { echo "check-session-deps: --sxwmrc needs a FILE" >&2; exit 2; }
		SXWMRC="$1"
		;;
	*) FILES+=("$1") ;;
	esac
	shift
done

if [ "${#FILES[@]}" -eq 0 ] && [ -z "$SXWMRC" ]; then
	cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
	[ -f "$cfg/x11/xinitrc" ] && FILES+=("$cfg/x11/xinitrc")
	[ -f "$cfg/x11/xprofile" ] && FILES+=("$cfg/x11/xprofile")
	[ -f "$HOME/.xprofile" ] && FILES+=("$HOME/.xprofile")
	[ -f "$cfg/sxwmrc" ] && SXWMRC="$cfg/sxwmrc"
fi
[ "${#FILES[@]}" -gt 0 ] || [ -n "$SXWMRC" ] ||
	{ echo "check-session-deps: no session files found" >&2; exit 1; }
for f in ${FILES[@]+"${FILES[@]}"} ${SXWMRC:+"$SXWMRC"}; do
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

# not_a_command TOKEN — true for flags, numbers, assignments, paths,
# expansions, env vars and other tokens that cannot be command names.
not_a_command() {
	case "$1" in
	*[!a-zA-Z]*) return 0 ;; # no letters at all: %, +, numbers, punctuation
	"" | -* | .* | @* | *[=/{}$\`]* | *=* | [A-Z]*) return 0 ;;
	esac
	return 1
}

# extract_commands FILE — session-file extractor. Tokenizes each non-comment
# line on whitespace and shell metacharacters and keeps bare lowercase words
# that are not keywords, builtins, loop variables, flags, numbers,
# assignments, paths or expansions. Arguments survive too:
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
			not_a_command "$tok" && continue
			is_shell_word "$tok" && continue
			[ "${loopvar[$tok]:-}" = 1 ] && continue
			printf '%s\n' "$tok"
		done
	done <"$file"
}

# words_from_action ACTION — sxwmrc helper: print the command words an
# action runs. Command position = start of the action or right after a
# separator (; & | && || $( ` ( ). Arguments (subcommands like set-volume,
# flags, numbers, paths) are not commands — except `st -e CMD`, where CMD
# is a command. Known limitation: file redirections inside an action could
# yield false positives; no shipped action uses any.
words_from_action() {
	local tok expect=1 pending_e=0 prev_cmd=""
	# Separators become standalone `;` tokens; quotes are dropped. Word
	# splitting of the token stream is intended (set -f kills globbing).
	# shellcheck disable=SC2046
	set -- $(
		printf '%s' "$1" |
			sed "s/&&/ ; /g; s/||/ ; /g; s/\\\$(/ ; /g; s/[;|&()<>]/ ; /g; s/\`/ ; /g; s/[\"']/ /g"
	)
	for tok in "$@"; do
		if [ "$tok" = ";" ]; then
			expect=1
			continue
		fi
		# st -e CMD: the token after -e runs as a command.
		if [ "$tok" = "-e" ] && [ "$prev_cmd" = "st" ]; then
			pending_e=1
			continue
		fi
		if not_a_command "$tok" || is_shell_word "$tok"; then
			pending_e=0
			continue
		fi
		if [ "$pending_e" = 1 ]; then
			pending_e=0
			printf '%s\n' "$tok"
			prev_cmd="$tok"
			continue
		fi
		if [ "$expect" = 1 ]; then
			expect=0
			prev_cmd="$tok"
			printf '%s\n' "$tok"
		fi
	done
}

# extract_action_commands FILE — sxwmrc extractor: pull the quoted action
# out of every bind/exec line and print the commands it runs. `sh -c '...'`
# wrappers are unwrapped first.
extract_action_commands() {
	local file="$1" line action
	while IFS= read -r line; do
		case "$line" in
		\#*) continue ;;
		esac
		case "$line" in
		*bind*:*\"* | *exec*:*\"*) ;; # quoted bind/exec action: handled below
		*) continue ;;
		esac
		action="${line#*\"}"
		action="${action%%\"*}"
		case "$action" in
		"sh -c '"*)
			action="${action#sh -c \'}"
			action="${action%\'}"
			;;
		'sh -c "'*)
			action="${action#sh -c \"}"
			action="${action%\"}"
			;;
		esac
		words_from_action "$action"
	done <"$file"
}

session_cmds=""
if [ "${#FILES[@]}" -gt 0 ]; then
	session_cmds="$(for f in "${FILES[@]}"; do extract_commands "$f"; done | sort -u)"
	# Sanity guard: an extraction over debrice's session files must find the
	# WM itself and a plausible command set — otherwise the parser broke and
	# the check would pass vacuously.
	printf '%s\n' "$session_cmds" | grep -qx sxwm ||
		{ echo "check-session-deps: extraction broken (sxwm not found in session files)" >&2; exit 1; }
	[ "$(printf '%s\n' "$session_cmds" | grep -c .)" -ge 8 ] ||
		{ echo "check-session-deps: extraction broken (too few session commands)" >&2; exit 1; }
fi

sxwmrc_cmds=""
if [ -n "$SXWMRC" ]; then
	sxwmrc_cmds="$(extract_action_commands "$SXWMRC" | sort -u)"
	# Same guard for the sxwmrc extraction: the terminal and the bar must be
	# among the commands found.
	printf '%s\n' "$sxwmrc_cmds" | grep -qx st ||
		{ echo "check-session-deps: extraction broken (st not found in sxwmrc actions)" >&2; exit 1; }
	printf '%s\n' "$sxwmrc_cmds" | grep -qx sxbar ||
		{ echo "check-session-deps: extraction broken (sxbar not found in sxwmrc actions)" >&2; exit 1; }
	[ "$(printf '%s\n' "$sxwmrc_cmds" | grep -c .)" -ge 20 ] ||
		{ echo "check-session-deps: extraction broken (too few sxwmrc commands)" >&2; exit 1; }
fi

cmds="$(printf '%s\n%s\n' "$session_cmds" "$sxwmrc_cmds" | sed '/^$/d' | sort -u)"
count="$(printf '%s\n' "$cmds" | grep -c .)"

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
	echo "check-session-deps: session files or sxwmrc actions reference commands not on PATH" >&2
	exit 1
fi
echo "SESSION DEPS OK ($count commands checked${SXWMRC:+, sxwmrc: $SXWMRC})"
