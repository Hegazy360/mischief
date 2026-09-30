#!/usr/bin/env bash
# Shoot the diorama (this project) at 1200x540. Usage: tools/shot.sh <out.png> [frames=60] [-- DioramaShot args]
# e.g. tools/shot.sh /tmp/a.png 60 -- --char=/abs/path/my_char.glb@stool@Idle_Loop@20@1.7 --cam=kitchen
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?out png}"; FR="${2:-60}"; shift 2 2>/dev/null || shift $#
exec "$R/tools/shot3d.sh" "$R" res://diorama/DioramaShot.tscn "$OUT" "$FR" "$@"
