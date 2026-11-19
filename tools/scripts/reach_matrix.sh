#!/usr/bin/env bash
# Reach accuracy matrix (docs/research/animation.md phase 4): every container / rig point × facing through the real
# RigPlayer (clip reach + posture), headless; CSV + a summary; exit 1 on an elbow pop.
# Usage: tools/scripts/reach_matrix.sh <out.csv> [sandbox] [-- --rig=hush --only=id,id]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/tools/scripts/lib.sh"
OUT="$(mnd_abspath "${1:?out.csv}")"; shift
SB="reach-matrix"
if [ $# -gt 0 ] && [ "$1" != "--" ]; then SB="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
mkdir -p "$(dirname "$OUT")"
"$ROOT/tools/scripts/sandbox.sh" "$SB" -s res://tools/anim/reach_matrix_tool.gd -- "--out=$OUT" "$@" 2>&1 | grep -E '^\[reach_matrix\]|^  (short|pop)'
