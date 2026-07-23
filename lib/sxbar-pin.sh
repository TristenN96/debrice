#!/bin/bash
# debrice — lib/sxbar-pin.sh
# Build-time pin for sxbar's module reader (uint23/sxbar#19), shared by
# lib/builds.sh (install) and tests/docker-test.sh (Xvfb stage) so the
# tested build is byte-identical to the installed one.
#
# Upstream run_command() reads each module's popen pipe with a blocking
# fgets until EOF. sxbar's loop is single-threaded, so any of these
# freezes the WHOLE bar — workspace highlight included:
#   1. a backgrounded grandchild inherits the pipe and holds it open after
#      the module printed (sb-forecast's wttr.in retry loop — hardware
#      run #4): EOF never comes;
#   2. a module hangs before printing anything (sb-volume's wpctl against
#      a session-manager-less PipeWire — hardware run #5): the FIRST
#      fgets blocks;
#   3. a module hangs and never exits: pclose's waitpid blocks.
#
# The pin rewrites run_command() to bound all three:
#   - the module runs under `timeout -k 1 5` (coreutils, Essential): a
#     hung module is killed, which closes the pipe and unblocks fgets and
#     pclose;
#   - poll(2) with a 5s timeout precedes the read: a pipe held open by a
#     grandchild with no output pending no longer blocks;
#   - a single line is read (while->if), dwmblocks' semantics — every
#     sb-* script emits exactly one line.
# A bad module renders empty for one tick; the bar can never freeze
# indefinitely again.
#
# Usage: sxbar-pin.sh SXBAR_SOURCE_DIR   (run as the tree's owner)
set -eu

[ $# -eq 1 ] || { echo "usage: sxbar-pin.sh SXBAR_SOURCE_DIR" >&2; exit 2; }
target="$1/src/modules.c"
[ -f "$target" ] || { echo "sxbar-pin: not a file: $target" >&2; exit 1; }

# Anchor guard: fail loudly if upstream reshapes run_command() — the pin
# must move with it.
grep -q 'fgets(buffer, sizeof buffer, fp)' "$target" ||
	{
		echo "sxbar-pin: anchor 'fgets(buffer, sizeof buffer, fp)' missing — upstream reshaped run_command()" >&2
		exit 1
	}

newfunc="$(mktemp)"
trap 'rm -f "$newfunc"' EXIT
cat >"$newfunc" <<'PIN_EOF'
static char *run_command(const char *cmd)
{
	if (!cmd || !*cmd) {
		return strdup("");
	}

	/* Bound the module's lifetime: a module that hangs — before printing
	   or after — is killed by timeout(1) (coreutils, Essential), which
	   closes the pipe and keeps fgets and pclose bounded. Single-quote
	   the command, escaping embedded quotes. */
	size_t cap = strlen(cmd) * 4 + 64;
	char *wrapped = malloc(cap);
	if (!wrapped) {
		return strdup("N/A");
	}
	char *w = wrapped;
	w += sprintf(w, "exec timeout -k 1 5 sh -c '");
	for (const char *p = cmd; *p; p++) {
		if (*p == '\'') {
			memcpy(w, "'\\''", 4);
			w += 4;
		}
		else {
			*w++ = *p;
		}
	}
	*w++ = '\'';
	*w = '\0';

	FILE *fp = popen(wrapped, "r");
	free(wrapped);
	if (!fp) {
		return strdup("N/A");
	}

	char buffer[1024];
	char *res = NULL;

	/* Read one line (dwmblocks' semantics — every sb-* script emits
	   exactly one), and only when output arrives within 5s: a pipe held
	   open by a backgrounded grandchild with nothing printed must not
	   block the bar's single-threaded loop. On timeout or EOF the module
	   renders empty until its next tick. */
	struct pollfd pfd = { .fd = fileno(fp), .events = POLLIN };
	if (poll(&pfd, 1, 5000) > 0 && fgets(buffer, sizeof buffer, fp)) {
		size_t l = strlen(buffer);
		if (l > 0 && buffer[l - 1] == '\n') {
			buffer[--l] = '\0';
		}
		res = strdup(buffer);
	}
	pclose(fp);
	return res ? res : strdup("");
}
PIN_EOF

# poll(2) needs poll.h (insert once; the pin is idempotent).
grep -q '#include <poll.h>' "$target" ||
	sed -i 's/^#include <time\.h>$/#include <time.h>\n#include <poll.h>/' "$target"

# Splice the replacement in place of upstream's run_command(): print the
# new body at the function's start line, then skip up to and including its
# closing brace (the first line that is exactly `}`).
awk -v f="$newfunc" '
	BEGIN { while ((getline line < f) > 0) repl = repl line "\n" }
	/^static char \*run_command\(const char \*cmd\)$/ { printf "%s", repl; skip = 1; next }
	skip && /^\}$/ { skip = 0; next }
	skip { next }
	{ print }
' "$target" >"$target.pinned"
mv "$target.pinned" "$target"

# Verify the pin landed: both bounds must be present afterwards.
if ! { grep -q 'timeout -k 1 5' "$target" && grep -q 'poll(&pfd, 1, 5000)' "$target"; }; then
	echo "sxbar-pin: pin did not land in $target" >&2
	exit 1
fi
