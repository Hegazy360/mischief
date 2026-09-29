#!/usr/bin/env bash
# Capture a scene to a GIF with Movie Maker (TECH §11): PNG sequence + WAV at a fixed 60 fps,
# an event log, then tools/anim/gif.py → a 30 fps GIF (≤ 4 MB) with the sound drawn as a
# waveform strip (onsets + event labels, so a reviewer can SEE sync) and a mute copy.
# Usage: tools/scripts/capture.sh <res://scene.tscn> <frames> <out.gif> [-- user args]
#   e.g. tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 180 out/take.gif -- --clip=rx_take --blips
# Writes <out>.gif, <out>_mute.gif, <out>.wav, <out>_events.json, <out>_sync.json.
# Env: CAPTURE_SANDBOX (default capture), SHOT_SIZE (default 1200x540), GIF_WIDTH (default 720).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCENE="${1:?res://scene.tscn}"; FRAMES="${2:?frames}"; OUT="${3:?out.gif}"
shift 3
[ "${1:-}" = "--" ] && shift
OUT="$(realpath -m "$OUT")"
BASE="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}"
NAME="${CAPTURE_SANDBOX:-capture}"
mkdir -p "$BASE" "$(dirname "$OUT")"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_capture.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SIZE="${SHOT_SIZE:-1200x540}"
(
  flock 9
  "$ROOT/tools/scripts/sandbox.sh" "$NAME" >/dev/null
  SB="$BASE/$NAME/game"
  timeout "${CAPTURE_TIMEOUT:-600}" xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 \
    --resolution "$SIZE" --path "$SB" --write-movie "$TMP/f.png" --fixed-fps 60 --quit-after "$((FRAMES + 2))" \
    -s res://tools/anim/capture.gd -- "--scene=$SCENE" "--frames=$FRAMES" "--log=$TMP/events.json" "$@" 2>&1 \
    | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)|V-Sync|set_use_vsync" | tail -20
) 9>"$BASE/$NAME.lock"
python3 "$ROOT/tools/anim/gif.py" "$TMP" "$OUT" --width="${GIF_WIDTH:-720}"
