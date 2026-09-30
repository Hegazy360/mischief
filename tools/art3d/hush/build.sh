#!/usr/bin/env bash
# Build Hush for R3D (r3d-cast-hush): palette, face atlas, skeleton contract, the glb, rig descriptor + face presets,
# Hush's props (tag beret, plinth). Blender runs through tools/art3d/blender.sh (a CPU slot, one thread).
#   tools/art3d/hush/build.sh                          # B's head (head_scale 1.0): hush.glb + rig3d.json + faces.json
#   tools/art3d/hush/build.sh --head-scale 1.2 --variant head_b   # the R6 head variant: hush_head_b.glb + rig3d_head_b.json
#   tools/art3d/hush/build.sh --no-props               # skip tag_beret.glb / plinth.glb
# Intermediates go to build/art3d/hush/ (gitignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
H="$ROOT/tools/art3d/hush"
OUT="$ROOT/game/art3d/chars/hush"
RIG="$ROOT/game/data/rigs3d/hush"
B="$ROOT/build/art3d/hush"
HS=1.0; VAR=""; PROPS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --head-scale) HS="$2"; shift 2 ;;
    --variant) VAR="$2"; shift 2 ;;
    --no-props) PROPS=0; shift ;;
    *) echo "unknown arg $1" >&2; exit 64 ;;
  esac
done
mkdir -p "$OUT" "$RIG" "$B"
NAME=hush; [ -n "$VAR" ] && NAME="hush_$VAR"
python3 "$H/palette.py" "$OUT/palette_hush.png"
python3 "$H/face_atlas.py" "$OUT" --json-dir "$B"
SKEL_ARGS=()
[ -z "$VAR" ] && SKEL_ARGS=(--skeleton "$H/skeleton.json")
"$ROOT/tools/art3d/blender.sh" --python "$H/build.py" -- --out "$OUT" --name "$NAME" --head-scale "$HS" \
  --palette "$OUT/palette_hush.png" --face "$OUT/face_hush.png" --meta "$B/meta_$NAME.json" "${SKEL_ARGS[@]}" \
  2>&1 | grep -E "HUSH|Error|Traceback|line [0-9]+" || true
test -f "$OUT/$NAME.glb"
python3 "$H/glb_strip.py" "$OUT/$NAME.glb"
if [ -n "$VAR" ]; then
  python3 "$H/write_rig.py" --meta "$B/meta_$NAME.json" --face "$B/face_hush.json" --variant "$VAR" --out "$RIG"
else
  python3 "$H/write_rig.py" --meta "$B/meta_$NAME.json" --face "$B/face_hush.json" --out "$RIG"
  cp "$H/skeleton.json" "$RIG/skeleton.json"
fi
if [ "$PROPS" = 1 ] && [ -f "$H/props.py" ]; then
  "$ROOT/tools/art3d/blender.sh" --python "$H/props.py" -- --out "$OUT" --palette "$OUT/palette_hush.png" \
    2>&1 | grep -E "PROP|Error|Traceback|line [0-9]+" || true
  for g in "$OUT"/tag_beret.glb "$OUT"/plinth.glb; do [ -f "$g" ] && python3 "$H/glb_strip.py" "$g"; done
fi
echo "[hush] built $NAME (head_scale $HS)"
