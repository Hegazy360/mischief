#!/usr/bin/env bash
# Copy mischief/game into a private sandbox and run headless Godot there.
# Usage: tools/scripts/sandbox.sh <name> [godot args...]
# Prints the sandbox path on stderr. Env: NO_IMPORT=1 to skip the import step,
# MND_SANDBOX_ROOT (default /tmp/mnd_sandbox).
# Both Godot runs (the import and the headless run) go through tools/scripts/slot.sh (4 CPU slots,
# one render thread each; R3D ruling R11); MND_SLOT_HELD=1 (a caller already holds a slot) skips it.
#
# The source project carries Godot's committed import metadata (`*.import` next to every
# asset, `*.uid` next to every script/shader — see tools/ci/check_import_meta.sh), so the
# mirror below keeps them: `--delete` only removes files that are gone from the source.
# Only the import cache `.godot/` is sandbox-local (kept between runs of the same sandbox).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="${1:?sandbox name}"; shift || true
BASE="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}"
SB="$BASE/$NAME/game"
LOG="$BASE/$NAME.import.log"
mkdir -p "$SB"
rsync -a --delete --exclude '.godot/' "$ROOT/game/" "$SB/"
if [ -z "${NO_IMPORT:-}" ]; then
  # Godot 4.7.2's headless --import occasionally segfaults on a large first import; retry up to 3 times.
  ok=0
  for attempt in 1 2 3; do
    rc=0
    "$ROOT/tools/scripts/slot.sh" sh -c 'exec timeout 600 godot --headless --path "$1" --import >"$2" 2>&1' _ "$SB" "$LOG" \
      || rc=$?
    if [ "$rc" = 0 ]; then ok=1; break; fi
    [ "$rc" = 75 ] && { echo "[sandbox] no CPU slot free (slot.sh timed out)" >&2; exit 75; }
    echo "[sandbox] import attempt $attempt failed, retrying" >&2
  done
  [ "$ok" = 1 ] || { echo "[sandbox] import failed, see $LOG" >&2; tail -40 "$LOG" >&2; exit 3; }
fi
echo "[sandbox] $SB" >&2
if [ "$#" -gt 0 ]; then
  exec "$ROOT/tools/scripts/slot.sh" godot --headless --path "$SB" "$@"
fi
