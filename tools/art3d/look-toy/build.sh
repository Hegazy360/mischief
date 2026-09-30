#!/usr/bin/env bash
# Rebuild the Toy Box look-dev characters: palette + face atlases + both .glb (+ meta json).
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"
python3 -c "import sys; sys.path.insert(0,'$R/src'); import toy_palette as T; T.write_png('$R/build/toy_palette.png')"
python3 "$R/src/face_atlas.py" "$R/build" all >/dev/null
for who in ${WHO:-hush bellows}; do
  t0=$(date +%s.%N)
  blender -b --python "$R/src/build_$who.py" -- --build "$R/build" --face "$R/build/face_$who.png" --out "$R/build/${who}_toy.glb" --meta "$R/build/${who}_toy.json" ${EXTRA:-} 2>&1 | grep -E "TRIS_BY|_OK|tris|Error|Traceback|rror" | grep -v "^$" || true
  echo "[build] $who $(python3 -c "print(round($(date +%s.%N)-$t0,1))") s"
done
