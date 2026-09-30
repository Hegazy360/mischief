#!/usr/bin/env bash
# Render a 3D scene of a Godot project under a virtual display (Compatibility / opengl3) and save a PNG.
# Usage: shot3d.sh <project_dir> <res://scene.tscn> <out.png> [frames=60] [-- user args...]
# Env: SHOT_SIZE (default 1200x540 = 20:9 phone held sideways), NO_IMPORT=1 to skip the import pass.
set -euo pipefail
PROJ="$(realpath "${1:?project dir}")"; SCENE="${2:?scene}"; OUT="$(realpath -m "${3:?out png}")"; FRAMES="${4:-60}"
shift 4 2>/dev/null || shift $#
[ "${1:-}" = "--" ] && shift
SIZE="${SHOT_SIZE:-1200x540}"
if [ -z "${NO_IMPORT:-}" ]; then
  for i in 1 2 3; do timeout 600 godot --headless --path "$PROJ" --import >/tmp/shot3d_import.log 2>&1 && break; echo "[shot3d] import retry $i" >&2; done
fi
mkdir -p "$(dirname "$OUT")"
timeout "${SHOT_TIMEOUT:-180}" xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 \
  --audio-driver Dummy --resolution "$SIZE" --path "$PROJ" "$SCENE" -- --shot="$OUT" --frames="$FRAMES" "$@" 2>&1 \
  | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)" | tail -30
test -f "$OUT" && echo "[shot3d] $OUT"
