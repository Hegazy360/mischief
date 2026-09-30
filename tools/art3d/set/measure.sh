#!/usr/bin/env bash
# Measure a set render against REDESIGN §3.7 with the shared toolset (tools/art3d/review/lab.py):
# a beauty shot + an ID pass of SetPreview3D (same framing), then lab.py regions / rules / falsecolor.
# Usage: tools/art3d/set/measure.sh <episode> <room> <out_dir> [sandbox] [-- extra SetPreview3D args]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
EP="${1:?episode}"; ROOM="${2:?room}"; OUT="$(realpath -m "${3:?out dir}")"; SB="${4:-r3d-sets}"
shift 4 2>/dev/null || shift $#
[ "${1:-}" = "--" ] && shift
mkdir -p "$OUT"
TAG="${EP}_${ROOM}"
SCENE=res://scenes/dev/set3d/SetPreview3D.tscn
"$ROOT/tools/scripts/shot.sh" "$SCENE" "$OUT/${TAG}_beauty.png" 30 "$SB" -- --episode="$EP" --room="$ROOM" "$@" >/dev/null
# (no NO_IMPORT: sandbox.sh's rsync drops the .import sidecars of assets not yet committed, R13)
"$ROOT/tools/scripts/shot.sh" "$SCENE" "$OUT/${TAG}_id.png" 30 "$SB" -- --episode="$EP" --room="$ROOM" --pass=id \
  --legend="$OUT/${TAG}_legend.json" "$@" >/dev/null
python3 "$ROOT/tools/art3d/review/lab.py" regions "$OUT/${TAG}_beauty.png" --id="$OUT/${TAG}_id.png" \
  --legend="$OUT/${TAG}_legend.json" --json="$OUT/${TAG}_regions.json" >/dev/null
python3 "$ROOT/tools/art3d/review/lab.py" rules "$OUT/${TAG}_regions.json" --rules=set --json="$OUT/${TAG}_rules.json" || true
python3 "$ROOT/tools/art3d/review/lab.py" falsecolor "$OUT/${TAG}_beauty.png" --out="$OUT/${TAG}_value_map.png" \
  --id="$OUT/${TAG}_id.png" --legend="$OUT/${TAG}_legend.json" >/dev/null || true
echo "[measure] $OUT/${TAG}_rules.json"
