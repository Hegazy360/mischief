#!/usr/bin/env bash
# Render a scene under a virtual display and save a screenshot.
# Usage: tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames=90] [sandbox=shots] [extra user args...]
# LANDSCAPE window, default 1200x540 (20:9, like a real phone held sideways: logical viewport
# 2400x1080 at the 1920x1080 base with aspect "expand"). SHOT_SIZE=960x540 for 16:9,
# SHOT_SIZE=1080x810 for a 4:3 tablet. Godot runs through tools/scripts/slot.sh (R3D ruling R11); SHOT_TIMEOUT
# (default 180 s) starts once a slot is free.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCENE="${1:?scene}"; OUT="${2:?out png}"; FRAMES="${3:-90}"; NAME="${4:-shots}"
shift 4 2>/dev/null || shift $#
OUT="$(realpath -m "$OUT")"
"$ROOT/tools/scripts/sandbox.sh" "$NAME" >/dev/null
SB="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}/$NAME/game"
SIZE="${SHOT_SIZE:-1200x540}"
"$ROOT/tools/scripts/slot.sh" timeout "${SHOT_TIMEOUT:-180}" xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 \
  --audio-driver Dummy --resolution "$SIZE" --path "$SB" "$SCENE" -- --shot="$OUT" --frames="$FRAMES" "$@" 2>&1 \
  | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)" | tail -40
test -f "$OUT" && echo "[shot] $OUT"
