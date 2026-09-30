#!/usr/bin/env bash
# Capture a scene to review GIFs + a numbered frame strip with Movie Maker (TECH §11, s2-rig
# §4.1.6): PNG sequence + the game's own audio (WAV) at a fixed 60 fps, an event log of every
# RigPlayer clip event (movie frame numbers), then tools/anim/gif.py.
# Usage: tools/scripts/capture.sh <res://scene.tscn> <frames> <out.gif> [-- user args]
#   AnimViewer3D: tools/scripts/capture.sh res://scenes/dev/anim3d/AnimViewer3D.tscn 180 out/take.gif -- --rig=bellows --clip=<id> --play
#   AnimViewer (2D): tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 180 out/take.gif -- --clip=rx_take --blips
#   The game:   tools/scripts/capture.sh res://scenes/boot/Boot.tscn 2400 out/g0.gif -- --e2e --e2e-scenario=g0_sneeze
#   (the scene becomes the current scene, so Boot → Router → NightScene changes work; every
#   autoload runs; user args pass through to the scene and to DevShot's --e2e driver).
# Writes <out>.gif (picture + sound strip: loudness, onsets, event labels), <out>_mute.gif,
# <out>_strip.png (+ _strip_2.png …: a numbered cell every STRIP_EVERY frames), <out>.wav,
# (the hook is res://tools/anim3d/capture3d.gd: it logs every node with a `clip_event` signal — RigPlayer3D and the
# frozen 2D RigPlayer alike),
# <out>_events.json, <out>_sync.json (each sfx/voice event vs the nearest onset: ± 1 f = in sync).
# GIFs are kept ≤ GIF_MAX_MB (width first, then fps; each reduction is reported on stderr).
# Env: CAPTURE_SANDBOX (default capture), SHOT_SIZE (default 1200x540), GIF_WIDTH (720),
#      GIF_FPS (30), GIF_MAX_MB (4), STRIP_EVERY (3), STRIP_RANGE (F0-F1, default all),
#      STRIP_W (cell width px, 400), STRIP_COLS (6), STRIP_MAX (cells per sheet, 60),
#      CAPTURE_TIMEOUT (s, 600), KEEP_FRAMES=<dir> (keep the raw PNG frames there).
# Godot runs through tools/scripts/slot.sh (R3D ruling R11).
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
  "$ROOT/tools/scripts/slot.sh" timeout "${CAPTURE_TIMEOUT:-600}" xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 \
    --resolution "$SIZE" --path "$SB" --write-movie "$TMP/f.png" --fixed-fps 60 --quit-after "$((FRAMES + 2))" \
    -s res://tools/anim3d/capture3d.gd -- "--scene=$SCENE" "--frames=$FRAMES" "--log=$TMP/events.json" "$@" 2>&1 \
    | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)|V-Sync|set_use_vsync" | tail -20
) 9>"$BASE/$NAME.lock"
python3 "$ROOT/tools/anim/gif.py" "$TMP" "$OUT" --width="${GIF_WIDTH:-720}" --fps="${GIF_FPS:-30}" \
  --max-mb="${GIF_MAX_MB:-4}" --strip-every="${STRIP_EVERY:-3}" --strip-range="${STRIP_RANGE:-}" \
  --strip-w="${STRIP_W:-400}" --strip-cols="${STRIP_COLS:-6}" --strip-max="${STRIP_MAX:-60}"
if [ -n "${KEEP_FRAMES:-}" ]; then mkdir -p "$KEEP_FRAMES"; cp "$TMP"/f*.png "$KEEP_FRAMES"/; fi
