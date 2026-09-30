#!/usr/bin/env bash
# Rebuild the set from the Blender sources: src/*.py -> diorama/props/*.glb + diorama/layout.json -> diorama/diorama.tscn.
# Usage: tools/rebuild.sh        (needs `blender` 4.5 on PATH; palette edits: src/palette.json -> src/make_palette.py)
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
B="$(mktemp -d)"
python3 "$R/src/make_palette.py" "$R/src/palette.png"
blender -b --python "$R/src/build_diorama.py" -- "$B" 2>&1 | grep -E "DIORAMA_OK|Error|Traceback" || true
cp "$B"/props/*.glb "$R/diorama/props/"
cp "$B/layout.json" "$R/diorama/layout.json"
cp "$R/src/palette.png" "$R/diorama/palette.png"
python3 "$R/src/gen_tscn.py" "$R/diorama"
rm -rf "$B"
