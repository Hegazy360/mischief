#!/usr/bin/env bash
# Shared helpers so every tools/scripts/* runs the same on the Linux CI runners and on a
# developer's macOS machine. macOS ships none of coreutils `timeout`, `flock`, GNU
# `realpath -m` or an X server, so each helper below picks the native tool when it exists
# and falls back to a portable shell equivalent otherwise.
#
# Source it, never execute it:   . "$ROOT/tools/scripts/lib.sh"
#
#   mnd_timeout SECS cmd...   run cmd, kill it after SECS (exit 124, like coreutils)
#   mnd_gui cmd...            run a GUI Godot: xvfb-run on Linux, straight through on macOS
#   mnd_abspath PATH          absolute path, the target need not exist (GNU `realpath -m`)
#   mnd_lock NAME             take a whole-script lock named NAME, released when the shell exits
#   mnd_require_godot         fail with a useful message when `godot` is not on PATH

# ---------------------------------------------------------------- timeout
if command -v timeout >/dev/null 2>&1; then
	mnd_timeout() { timeout "$@"; }
elif command -v gtimeout >/dev/null 2>&1; then
	mnd_timeout() { gtimeout "$@"; }
else
	## Portable `timeout`: run the command in the background with a watchdog that TERMs it.
	## Returns the command's status, or 124 when the watchdog fired (coreutils' convention).
	mnd_timeout() {
		local secs="$1"; shift
		"$@" &
		local pid=$!
		( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
		local watchdog=$!
		local rc=0
		wait "$pid" 2>/dev/null || rc=$?
		# The watchdog is still asleep iff the command finished on its own.
		if kill -0 "$watchdog" 2>/dev/null; then
			kill -TERM "$watchdog" 2>/dev/null
		else
			rc=124
		fi
		wait "$watchdog" 2>/dev/null || true
		return "$rc"
	}
fi

# ---------------------------------------------------------------- virtual display
# Godot cannot render under `--headless` (the driver is a stub), so screenshot, sheet and
# capture runs need a real GL context. Linux CI has no display, hence Xvfb; macOS always has
# a window server, so the command runs as-is and a window appears for the length of the run.
#
# MND_GUI is a command PREFIX array, not a function, for two reasons: coreutils `timeout`
# execs its argument, so it cannot call a shell function, and bash 3.2 (macOS' /bin/bash)
# errors on an empty array under `set -u`. The no-display branch therefore uses `env`, a
# real no-op binary, which keeps every call site a plain `"${MND_GUI[@]}" godot …`.
if command -v xvfb-run >/dev/null 2>&1; then
	MND_GUI=(xvfb-run -a -s "-screen 0 2560x1440x24")
else
	MND_GUI=(env)
fi

# ---------------------------------------------------------------- abspath
## Absolute path of PATH without requiring it to exist (BSD `realpath` resolves only
## existing paths, so resolve the deepest existing ancestor and re-append the rest).
mnd_abspath() {
	local p="$1"
	case "$p" in
		/*) ;;
		*) p="$PWD/$p" ;;
	esac
	local head="$p" tail=""
	while [ ! -e "$head" ] && [ "$head" != "/" ]; do
		tail="$(basename "$head")${tail:+/$tail}"
		head="$(dirname "$head")"
	done
	local resolved
	resolved="$(cd "$head" 2>/dev/null && pwd -P)" || resolved="$head"
	if [ -n "$tail" ]; then
		printf '%s\n' "$resolved/$tail"
	else
		printf '%s\n' "$resolved"
	fi
}

# ---------------------------------------------------------------- lock
## Whole-script mutex named NAME (shared sandboxes must not be rendered into concurrently).
## Uses flock where it exists; elsewhere an atomic `mkdir` spin with a stale-lock break.
mnd_lock() {
	local name="$1"
	local base="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}"
	mkdir -p "$base"
	if command -v flock >/dev/null 2>&1; then
		exec 9>"$base/$name.lock"
		flock 9
		return 0
	fi
	local dir="$base/$name.lockd"
	local waited=0
	while ! mkdir "$dir" 2>/dev/null; do
		# Break a lock whose owner died (the pid file is written right after mkdir wins).
		local owner
		owner="$(cat "$dir/pid" 2>/dev/null || echo "")"
		if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
			rm -rf "$dir"
			continue
		fi
		sleep 1
		waited=$((waited + 1))
		if [ "$waited" -ge "${MND_LOCK_TIMEOUT:-900}" ]; then
			echo "[lib] gave up waiting for the $name lock after ${waited}s ($dir)" >&2
			return 1
		fi
	done
	echo $$ >"$dir/pid"
	# shellcheck disable=SC2064  # $dir must expand now, not when the trap fires.
	trap "rm -rf '$dir'" EXIT
}

# ---------------------------------------------------------------- godot
## Fail early, and with the fix, when the engine is missing (see docs/DEV_SETUP.md).
mnd_require_godot() {
	if ! command -v godot >/dev/null 2>&1; then
		echo "[lib] 'godot' is not on PATH. Install Godot 4.7.2 and add a shim:" >&2
		echo "        tools/scripts/setup_dev.sh" >&2
		echo "      (see docs/DEV_SETUP.md)" >&2
		return 127
	fi
}
