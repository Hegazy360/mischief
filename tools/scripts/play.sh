#!/usr/bin/env bash
# Open a scene in a window, from a fresh private copy of the repo — one command, so the sync step can
# never be forgotten. (Godot only ever runs on a sandbox copy; a sandbox that was not re-synced shows
# whatever the repo looked like the last time it was.)
#
# Usage: tools/scripts/play.sh <res://scene.tscn> [-- user args]
#   tools/scripts/play.sh res://proto/bakery/Bakery.tscn
#   tools/scripts/play.sh res://proto/toyhouse/TheKeep.tscn
#   tools/scripts/play.sh res://scenes/boot/Boot.tscn            # the real game's front end
# Env: SANDBOX (default "play").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCENE="${1:-res://proto/act1/Act1.tscn}"; shift || true   # no argument: the current showcase (Act I)
SB_NAME="${SANDBOX:-play}"
"$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null
SB="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}/$SB_NAME/game"
echo "[play] $SCENE  (synced into $SB)"
exec godot --path "$SB" "$SCENE" "$@"
