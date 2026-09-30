#!/usr/bin/env bash
# still.sh <out.png> <t> <ToyShot args...> : exact-time still (all characters seeked to t, paused)
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; OUT=$1; T=$2; shift 2
NO_IMPORT=1 "$R/proj/tools/shot3d.sh" "$R/proj" res://toy/ToyShot.tscn "$OUT" ${FRAMES:-12} -- --seek=$T --pause=1 "$@" 2>&1 | grep -E "ERROR|SCRIPT" || true
