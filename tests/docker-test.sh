#!/bin/bash
# debrice — tests/docker-test.sh
# Runs the debrice test stages. Primary mode: debian:trixie containers.
# Fallback mode: if docker is unusable in this environment, stages degrade to
# static verification (Trixie package indices, host-side builds, local
# idempotency in a throwaway HOME) and say so loudly.
# Usage: tests/docker-test.sh [all|lint|packages|builds|binds|idempotency|xephyr]
set -u

IMAGE="debian:trixie"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="${1:-all}"
CACHE="/tmp/debrice-test-cache"
BUILDROOT="/tmp/debrice-build-root"
MODE="docker"

note() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	MODE="docker"
else
	MODE="local"
	warn "docker unusable here — falling back to static local verification"
fi

# run_container: pipe a bash script into a debian:trixie container with the
# repo mounted read-only at /debrice.
run_container() {
	docker run --rm -v "$REPO:/debrice:ro" "$IMAGE" bash -s
}

###############################################################################
# lint
###############################################################################
lint_cmd() {
	if command -v shellcheck >/dev/null 2>&1; then
		echo shellcheck
	elif [ -x "$CACHE/shellcheck-v0.10.0/shellcheck" ]; then
		echo "$CACHE/shellcheck-v0.10.0/shellcheck"
	else
		mkdir -p "$CACHE"
		if curl -fsSLo "$CACHE/sc.tar.xz" \
			https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz; then
			tar -xJf "$CACHE/sc.tar.xz" -C "$CACHE" || die "cannot extract shellcheck"
		else
			die "cannot obtain shellcheck"
		fi
		echo "$CACHE/shellcheck-v0.10.0/shellcheck"
	fi
}

stage_lint() {
	note "Stage: shellcheck lint [$MODE]"
	if [ "$MODE" = docker ]; then
		run_container <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq shellcheck >/dev/null
cd /debrice
shellcheck -x debrice.sh lib/*.sh scripts/*.sh tests/*.sh
echo "LINT OK"
EOF
		return
	fi
	local sc
	sc="$(lint_cmd)" || die "no shellcheck available"
	cd "$REPO" || die "no repo"
	shopt -s nullglob
	local files=(debrice.sh lib/*.sh scripts/*.sh tests/*.sh)
	[ "${#files[@]}" -gt 0 ] || die "no scripts to lint yet"
	"$sc" -x "${files[@]}" || die "shellcheck failed"
	echo "LINT OK (local, ${#files[@]} files)"
}

###############################################################################
# packages
###############################################################################
trixie_packages() {
	mkdir -p "$CACHE"
	[ -f "$CACHE/Packages-trixie-main" ] || {
		note "downloading Trixie main package index"
		if curl -fsSLo "$CACHE/Packages-trixie-main.xz" \
			http://deb.debian.org/debian/dists/trixie/main/binary-amd64/Packages.xz; then
			xz -dk "$CACHE/Packages-trixie-main.xz" || die "cannot decompress Trixie index"
		else
			die "cannot fetch Trixie index"
		fi
	}
	echo "$CACHE/Packages-trixie-main"
}

brave_packages() {
	mkdir -p "$CACHE"
	[ -f "$CACHE/brave-Packages" ] || {
		note "downloading Brave repo package index"
		if curl -fsSLo "$CACHE/brave-Packages.xz" \
			https://brave-browser-apt-release.s3.brave.com/dists/stable/main/binary-amd64/Packages.xz 2>/dev/null; then
			xz -dk "$CACHE/brave-Packages.xz" || die "cannot decompress Brave index"
		else
			curl -fsSLo "$CACHE/brave-Packages" \
				https://brave-browser-apt-release.s3.brave.com/dists/stable/main/binary-amd64/Packages \
				|| die "cannot fetch Brave index"
		fi
	}
	echo "$CACHE/brave-Packages"
}

stage_packages() {
	note "Stage: package resolution [$MODE]"
	if [ "$MODE" = docker ]; then
		run_container <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
export PROGS_FILE=/debrice/progs.csv
. /debrice/lib/packages.sh
apt-get update -qq
grep -q '^R,' "$PROGS_FILE" && {
	apt-get install -y -qq curl ca-certificates gnupg >/dev/null
	add_brave_repo
}
fail=0
check_resolvable() {
	local tag="$1" name="$2"
	case "$tag" in
		""|R)
			apt-cache policy "$name" 2>/dev/null | grep -qE 'Candidate: [0-9]' \
				|| { echo "UNRESOLVABLE: tag='$tag' name='$name'"; fail=1; }
			;;
	esac
}
progs_each check_resolvable
[ "$fail" -eq 0 ] || { echo "PACKAGE RESOLUTION FAILED"; exit 1; }
echo "PACKAGE RESOLUTION OK"
EOF
		return
	fi
	# Local static fallback: grep the Trixie (and Brave) package indices.
	local trixie brave fail=0 tag name
	trixie="$(trixie_packages)"
	brave="$(brave_packages)"
	while IFS=, read -r tag name _; do
		case "$tag" in \#*) continue ;; esac
		[ -z "$name" ] && continue
		case "$tag" in
		"")
			grep -qx "Package: $name" "$trixie" \
				|| { echo "NOT IN TRIXIE MAIN: $name"; fail=1; }
			;;
		R)
			grep -qx "Package: $name" "$brave" \
				|| { echo "NOT IN BRAVE REPO: $name"; fail=1; }
			;;
		esac
	done <"$REPO/progs.csv"
	[ "$fail" -eq 0 ] || die "package resolution failed (static check)"
	echo "PACKAGE RESOLUTION OK (static, Trixie main + Brave stable indices)"
}

###############################################################################
# builds
###############################################################################
stage_builds() {
	note "Stage: git builds (st, dmenu, slock, sxwm, sxbar) [$MODE]"
	if [ "$MODE" = docker ]; then
		run_container <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git build-essential pkg-config \
	libx11-dev libxft-dev libxinerama-dev libxcursor-dev \
	libfontconfig1-dev libxext-dev libxrandr-dev libharfbuzz-dev >/dev/null
cd /tmp
build_one() {
	local url="$1" name
	name="$(basename "$url" .git)"
	echo "--- building $name"
	git clone --depth 1 -q "$url" "$name"
	make -C "$name" >/dev/null
	make -C "$name" install PREFIX=/usr/local >/dev/null
}
build_one https://github.com/LukeSmithxyz/st.git
build_one https://github.com/LukeSmithxyz/dmenu.git
build_one https://git.suckless.org/slock
build_one https://github.com/uint23/sxwm.git
build_one https://github.com/uint23/sxbar.git
for b in st dmenu slock sxwm sxbar; do
	[ -x "/usr/local/bin/$b" ] || { echo "MISSING BINARY: $b"; exit 1; }
done
echo "BUILDS OK"
EOF
		return
	fi
	# Local fallback: build on the host into a throwaway PREFIX.
	note "building on host into $BUILDROOT (toolchain differs from Trixie)"
	rm -rf "$BUILDROOT"
	mkdir -p "$BUILDROOT"
	local url name
	for url in \
		https://github.com/LukeSmithxyz/st.git \
		https://github.com/LukeSmithxyz/dmenu.git \
		https://git.suckless.org/slock \
		https://github.com/uint23/sxwm.git \
		https://github.com/uint23/sxbar.git; do
		name="$(basename "$url" .git)"
		note "building $name"
		rm -rf "/tmp/debrice-build-$name"
		git clone --depth 1 -q "$url" "/tmp/debrice-build-$name" \
			|| die "clone failed: $url"
		make -C "/tmp/debrice-build-$name" >/dev/null \
			|| die "build failed: $name"
		make -C "/tmp/debrice-build-$name" install PREFIX="$BUILDROOT/usr/local" >/dev/null \
			|| die "install failed: $name"
	done
	local b
	for b in st dmenu slock sxwm sxbar; do
		[ -x "$BUILDROOT/usr/local/bin/$b" ] || die "missing binary after install: $b"
	done
	echo "BUILDS OK (host toolchain)"
}

###############################################################################
# binds
###############################################################################
stage_binds() {
	note "Stage: keybinding coverage"
	if [ ! -x "$REPO/scripts/check-binds.sh" ]; then
		note "scripts/check-binds.sh not present yet — skipping"
		return 0
	fi
	"$REPO/scripts/check-binds.sh"
}

###############################################################################
# idempotency
###############################################################################
stage_idempotency() {
	note "Stage: idempotency (repo add + dotfiles deploy run twice) [$MODE]"
	if [ ! -f "$REPO/lib/dotfiles.sh" ]; then
		note "lib/dotfiles.sh not present yet — skipping"
		return 0
	fi
	if [ "$MODE" = docker ]; then
		run_container <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg git >/dev/null
export PROGS_FILE=/debrice/progs.csv
export DEBRICE_DOTFILES_SRC=/debrice/dotfiles
export DEBRICE_STATIC_SRC=/debrice/static
. /debrice/lib/packages.sh
. /debrice/lib/dotfiles.sh
add_brave_repo
add_brave_repo
[ "$(wc -l < /etc/apt/sources.list.d/brave-browser-release.list)" = 1 ] \
	|| { echo "DUPLICATE/UNEXPECTED sources content"; exit 1; }
name=debricetest
useradd -m -s /bin/zsh "$name" 2>/dev/null || true
deploy_dotfiles "$name" /home/"$name"
before="$(find /home/$name -name 'debrice-backup-*' | wc -l)"
deploy_dotfiles "$name" /home/"$name"
after="$(find /home/$name -name 'debrice-backup-*' | wc -l)"
[ "$after" -gt "$before" ] \
	|| { echo "NO BACKUP DIRECTORY CREATED ON SECOND DEPLOY"; exit 1; }
echo "IDEMPOTENCY OK"
EOF
		return
	fi
	# Local fallback: fake HOME in /tmp, overridable repo paths, no useradd.
	local fake="$BUILDROOT/fakehome"
	rm -rf "$fake"
	mkdir -p "$fake"
	export PROGS_FILE="$REPO/progs.csv"
	export DEBRICE_DOTFILES_SRC="$REPO/dotfiles"
	export DEBRICE_STATIC_SRC="$REPO/static"
	export BRAVE_KEYRING="$BUILDROOT/brave-keyring.gpg"
	export BRAVE_SOURCES="$BUILDROOT/brave-browser-release.list"
	export DEBRICE_SKIP_APT_UPDATE=1
	# shellcheck source=/dev/null
	. "$REPO/lib/packages.sh"
	# shellcheck source=/dev/null
	. "$REPO/lib/dotfiles.sh"
	add_brave_repo || die "add_brave_repo run 1 failed"
	add_brave_repo || die "add_brave_repo run 2 failed"
	[ "$(wc -l <"$BRAVE_SOURCES")" = 1 ] || die "duplicate brave sources entry"
	deploy_dotfiles "" "$fake" || die "deploy run 1 failed"
	local before after
	before="$(find "$fake" -name 'debrice-backup-*' | wc -l)"
	deploy_dotfiles "" "$fake" || die "deploy run 2 failed"
	after="$(find "$fake" -name 'debrice-backup-*' | wc -l)"
	[ "$after" -gt "$before" ] || die "no backup directory created on second deploy"
	echo "IDEMPOTENCY OK (local, fake HOME)"
}

###############################################################################
# xephyr
###############################################################################
stage_xephyr() {
	note "Stage: Xephyr smoke test of sxwm [$MODE]"
	if [ ! -f "$REPO/static/sxwmrc" ]; then
		note "static/sxwmrc not present yet — skipping"
		return 0
	fi
	if [ "$MODE" = docker ]; then
		run_container <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git build-essential pkg-config xserver-xephyr x11-utils \
	xdotool libx11-dev libxinerama-dev libxcursor-dev >/dev/null
git clone --depth 1 -q https://github.com/uint23/sxwm.git /tmp/sxwm
make -C /tmp/sxwm >/dev/null
make -C /tmp/sxwm install PREFIX=/usr/local >/dev/null
mkdir -p /root/.config
cp /debrice/static/sxwmrc /root/.config/sxwmrc
export DISPLAY=:99
Xephyr :99 -screen 1280x720 >/dev/null 2>&1 &
sleep 2
sxwm >/tmp/sxwm.log 2>&1 &
sleep 3
xdotool key super+F5
sleep 1
pidof sxwm >/dev/null || { echo "sxwm NOT RUNNING"; cat /tmp/sxwm.log; exit 1; }
grep -q "using configuration file" /tmp/sxwm.log \
	|| { echo "sxwm DID NOT PARSE CONFIG"; cat /tmp/sxwm.log; exit 1; }
kill %2 %1 2>/dev/null || true
echo "XEPHYR SMOKE OK"
EOF
		return
	fi
	command -v Xephyr >/dev/null 2>&1 || { warn "no Xephyr on host — skipping smoke test"; return 0; }
	command -v xdotool >/dev/null 2>&1 || { warn "no xdotool on host — skipping smoke test"; return 0; }
	local sxwmbin="$BUILDROOT/usr/local/bin/sxwm" fake="$BUILDROOT/xephyr-home"
	[ -x "$sxwmbin" ] || {
		stage_builds >/dev/null || die "cannot build sxwm for smoke test"
	}
	rm -rf "$fake"
	mkdir -p "$fake/.config"
	cp "$REPO/static/sxwmrc" "$fake/.config/sxwmrc"
	Xephyr :99 -screen 1280x720 >/dev/null 2>&1 &
	local xepid=$!
	sleep 2
	HOME="$fake" DISPLAY=:99 "$sxwmbin" >"$BUILDROOT/sxwm.log" 2>&1 &
	local sxwmpid=$!
	sleep 3
	DISPLAY=:99 xdotool key super+F5
	sleep 1
	local ok=0
	kill -0 "$sxwmpid" 2>/dev/null && grep -q "using configuration file" "$BUILDROOT/sxwm.log" && ok=1
	kill "$sxwmpid" "$xepid" 2>/dev/null
	[ "$ok" = 1 ] || { echo "XEPHYR SMOKE FAILED"; cat "$BUILDROOT/sxwm.log"; return 1; }
	echo "XEPHYR SMOKE OK (host)"
}

case "$STAGE" in
lint) stage_lint ;;
packages) stage_packages ;;
builds) stage_builds ;;
binds) stage_binds ;;
idempotency) stage_idempotency ;;
xephyr) stage_xephyr ;;
all)
	stage_lint && stage_packages && stage_builds && stage_binds && stage_idempotency && stage_xephyr
	;;
*) die "unknown stage: $STAGE (want: all|lint|packages|builds|binds|idempotency|xephyr)" ;;
esac
