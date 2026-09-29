#!/usr/bin/env bash
# Render animation review sheets with the game's own rig player (TECH §11).
# Usage: tools/scripts/anim_sheet.sh <rig> <clip|--poses|--rig|--all> <out_dir> [--scale=1.0] [--tier=2] [--suppressed]
#   <clip>   a clip name ("rx_take") or id ("_mannequin/rx_take"): <clip>_contact.png (+ _phone),
#            <clip>_onion.png, <clip>_curves.json + <clip>_curves.png, <clip>_lint.txt
#   --poses  poses.png (+ 50 px silhouettes) and poses_phone.png
#   --rig    rig.png (exploded parts with pivots, rest / min / max joint limits)
#   --residues residues.png (the stand pose with every residue look, combos included)
#   --all    everything above for every clip of the rig
# Runs in a private sandbox copy (ANIM_SANDBOX, default anim_<rig>) under xvfb + opengl3; runs
# sharing a sandbox are serialised with a lock. Tier / suppressed sheets get a _t2 / _sup suffix.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RIG="${1:?rig id}"; WHAT="${2:?clip | --poses | --rig | --all}"; OUT="${3:?out dir}"
shift 3
OUT="$(realpath -m "$OUT")"
mkdir -p "$OUT"
SB_NAME="${ANIM_SANDBOX:-anim_${RIG}}"
BASE="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}"
mkdir -p "$BASE"
case "$WHAT" in
  --poses) MODE=(--mode=poses) ;;
  --rig) MODE=(--mode=rig) ;;
  --all) MODE=(--mode=all) ;;
  --residues) MODE=(--mode=residues) ;;
  *) MODE=(--mode=clip "--clip=$WHAT") ;;
esac
(
  flock 9
  "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null
  SB="$BASE/$SB_NAME/game"
  timeout "${SHEET_TIMEOUT:-600}" xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 \
    --audio-driver Dummy --resolution 640x360 --path "$SB" -s res://tools/anim/sheet.gd -- \
    "--rig=$RIG" "${MODE[@]}" "--out=$OUT" "$@" 2>&1 \
    | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)" | tail -60
) 9>"$BASE/$SB_NAME.lock"
shopt -s nullglob
for j in "$OUT"/*_curves.json; do
  png="${j%.json}.png"
  if [ ! -f "$png" ] || [ "$j" -nt "$png" ]; then
    python3 "$ROOT/tools/anim/curves.py" "$j" "$png" || echo "[anim_sheet] curves.py failed for $j" >&2
  fi
done
echo "[anim_sheet] $OUT"
ls -1 "$OUT" | sed 's/^/  /'
