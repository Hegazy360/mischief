#!/usr/bin/env bash
# Render the 3D animation review sheets with the game's own RigPlayer3D (TECH §11 in 3D, r3d-rig §4.4).
# Usage: tools/scripts/anim_sheet3d.sh <rig> <clip> <out_dir> [--room=<room>] [--cam=side|game] [--tier=2] [--suppressed]
#        tools/scripts/anim_sheet3d.sh <rig> --turntable <out_dir> [--clip=<id> --frame=N]   (front / 3/4 / side / back)
#        tools/scripts/anim_sheet3d.sh <rig> --faces <out_dir>                                (every face preset at 3×)
#   <clip>: an id (bellows/rx_sneeze_blast_a) or a name (rx_sneeze_blast_a). Writes <clip>_contact.png,
#   <clip>_onion.png, <clip>_curves.json + <clip>_curves.png, <clip>_sil64.png, <clip>_phone.jpg (the 1200×540 game
#   framing every 3 f) and <clip>_lint.txt (r3d-anim's 3D lint, when it exists); --turntable → <rig>_turntable.png,
#   --faces → <rig>_faces.png. Tier / suppressed sheets get a _t2 / _sup suffix.
# Runs in a private sandbox copy (ANIM_SANDBOX, default anim3d_<rig>) under xvfb + opengl3; runs sharing a sandbox are
# serialised with a lock; Godot goes through tools/scripts/slot.sh (R3D ruling R11). Raw frames are deleted after.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RIG="${1:?rig id}"; WHAT="${2:?clip | --turntable | --faces}"; OUT="${3:?out dir}"
shift 3
OUT="$(realpath -m "$OUT")"
mkdir -p "$OUT"
SB_NAME="${ANIM_SANDBOX:-anim3d_${RIG}}"
BASE="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}"
mkdir -p "$BASE"
RAW="$(mktemp -d "${TMPDIR:-/tmp}/mnd_sheet3d.XXXXXX")"
trap 'rm -rf "$RAW"' EXIT
case "$WHAT" in
  --turntable) MODE=(--mode=turntable) ;;
  --faces) MODE=(--mode=faces) ;;
  *) MODE=(--mode=clip "--clip=$WHAT") ;;
esac
CLIP_ID="$WHAT"
[[ "$CLIP_ID" != */* ]] && CLIP_ID="$RIG/$CLIP_ID"
(
  flock 9
  "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null
  SB="$BASE/$SB_NAME/game"
  "$ROOT/tools/scripts/slot.sh" timeout "${SHEET_TIMEOUT:-600}" xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 \
    --audio-driver Dummy --resolution 640x360 --path "$SB" -s res://tools/anim3d/sheet3d.gd -- \
    "--rig=$RIG" "${MODE[@]}" "--out=$RAW" "$@" 2>&1 \
    | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)|V-Sync|set_use_vsync" | tail -30
  if [ "${MODE[0]}" = "--mode=clip" ] && [[ " $* " != *" --anim-glb="* ]] && grep -q 'format=3d' "$SB/tools/anim/lint_anim.gd" 2>/dev/null; then
    STEM="${CLIP_ID##*/}"
    # The same sandbox (already imported), no re-sync: the cast glbs' .import files live only in the sandbox.
    "$ROOT/tools/scripts/slot.sh" timeout 300 godot --headless --path "$SB" -s res://tools/anim/lint_anim.gd -- --format=3d \
      "--clip=$CLIP_ID" >"$OUT/${STEM}_lint.txt" 2>&1 || true
  fi
) 9>"$BASE/$SB_NAME.lock"
case "$WHAT" in
  --turntable) python3 "$ROOT/tools/anim/sheet3d.py" turntable "$RAW" "$OUT/${RIG}_turntable.png" "--title=$RIG — turntable" ;;
  --faces) python3 "$ROOT/tools/anim/sheet3d.py" faces "$RAW" "$OUT/${RIG}_faces.png" ;;
  *)
    python3 "$ROOT/tools/anim/sheet3d.py" clip "$RAW" "$OUT"
    for j in "$OUT"/*_curves.json; do
      png="${j%.json}.png"
      if [ ! -f "$png" ] || [ "$j" -nt "$png" ]; then
        python3 "$ROOT/tools/anim/curves.py" "$j" "$png" --top=14 || echo "[anim_sheet3d] curves.py failed for $j" >&2
      fi
    done ;;
esac
echo "[anim_sheet3d] $OUT"
ls -1 "$OUT" | sed 's/^/  /'
