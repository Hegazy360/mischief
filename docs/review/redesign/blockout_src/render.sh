#!/usr/bin/env bash
# render.sh <mock> [size=1200x540] [out name]
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
M="${1:?mock}"; SIZE="${2:-1200x540}"; NAME="${3:-$M}"
mkdir -p "$D/out"
timeout 90 xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --audio-driver Dummy \
  --resolution "$SIZE" --path "$D/blockout" -- --mock="$M" --shot="$D/out/$NAME.png" --frames=10 2>&1 \
  | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)" | tail -25
