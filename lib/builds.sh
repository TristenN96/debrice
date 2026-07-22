#!/bin/bash
# debrice — lib/builds.sh
# git clone + make install helpers, mirroring LARBS's gitmakeinstall.
# Requires: $repodir (clone destination) and $name (build user) to be set
# by the calling script (debrice.sh).
# shellcheck disable=SC2154

# Repos whose default make target installs (nothing to compile).
NOBUILD_REPOS="mutt-wizard"

# gitmakeinstall GITURL — clone (or update) a repo into $repodir as $name,
# build as $name where there is something to build, then make install as root.
gitmakeinstall() {
	local url="$1" prog dir
	prog="$(basename "$url" .git)"
	dir="$repodir/$prog"
	mkdir -p "$repodir"
	if [ -d "$dir/.git" ]; then
		sudo -u "$name" git -C "$dir" pull --force >/dev/null || return 1
	else
		sudo -u "$name" git clone --depth 1 --single-branch --no-tags -q \
			"$url" "$dir" || return 1
	fi
	case " $NOBUILD_REPOS " in
	*" $prog "*) : ;; # header-only/script repo: nothing to compile
	*)
		# Pinned build-time defaults, applied after clone/pull, before make.
		case "$prog" in
		st)
			# st alpha: compile 85% opacity in. Upstream's knob is a float
			# (0.0-1.0), not the old alpha patch's `static unsigned int
			# alpha`; 0xd9/0xff ≈ 0.85. Compile-time pinning keeps the
			# vendored xresources and xprofile stock. Run sed as $name so
			# the clone stays user-owned; fail loudly if upstream renames
			# the knob — the pin must move with it.
			grep -q '^float alpha = ' "$dir/config.h" || return 1
			sudo -u "$name" sed -i 's/^float alpha = .*;/float alpha = 0.85;/' \
				"$dir/config.h" || return 1
			;;
		sxbar)
			# sxbar freeze pin (hardware-confirmed, uint23/sxbar#19):
			# run_command() reads each module's popen pipe until EOF, but
			# sb-* scripts background retry jobs that inherit the pipe
			# (sb-forecast's wttr.in loop is unbounded when the fetch
			# keeps failing). EOF never comes, sxbar's single-threaded
			# loop blocks in fgets, and the whole bar freezes — workspace
			# highlight included. dwmblocks reads a single line per
			# module; pin sxbar to the same semantics: read one line
			# (while→if) and turn the loop body's two allocation-failure
			# `break;`s (the only ones in the file) into plain returns —
			# `break` is illegal once the loop is gone. Both seds are
			# no-ops on an already-pinned tree. Fail loudly if upstream
			# reshapes run_command() — the pin must move with it.
			grep -q 'fgets(buffer, sizeof buffer, fp)' \
				"$dir/src/modules.c" || return 1
			sudo -u "$name" sed -i \
				-e 's/while (fgets(buffer, sizeof buffer, fp)) {/if (fgets(buffer, sizeof buffer, fp)) {/' \
				-e 's|break;|pclose(fp); return res ? res : strdup("");|' \
				"$dir/src/modules.c" || return 1
			;;
		esac
		(cd "$dir" && sudo -u "$name" make >/dev/null) || return 1
		;;
	esac
	(cd "$dir" && make install >/dev/null) || return 1
	return 0
}

# scriptinstall NAME URL — drop a single-file script into /usr/local/bin.
scriptinstall() {
	local name="$1" url="$2"
	curl -fsSLo "/usr/local/bin/$name" "$url" &&
		chmod 755 "/usr/local/bin/$name"
}
