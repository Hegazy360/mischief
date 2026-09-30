#!/usr/bin/env bash
# Build the 3D sets (r3d-sets): palettes (system Python + Pillow), then the Blender builders (one slot, one thread).
# Usage: tools/art3d/set/build.sh [--only name1,name2] [--out game/art3d]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="$ROOT/game/art3d"
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$(realpath -m "$2")"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
python3 "$ROOT/tools/art3d/set/palettes.py" "$OUT"
"$ROOT/tools/art3d/blender.sh" --python "$ROOT/tools/art3d/set/build.py" -- --out "$OUT" "${ARGS[@]}" 2>&1 \
  | grep -E "^\[set\]|Error|Traceback|File \"|line [0-9]+" || true
test -f "$OUT/set/build_report.json"
