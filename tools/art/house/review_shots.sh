#!/usr/bin/env bash
# Regenerate every art-house review artefact into docs/review/art-house/ (Godot shots at 1200x540 = a
# 20:9 phone, plus Pillow sheets). Usage: tools/art/house/review_shots.sh [sandbox=art-house]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SB="${1:-art-house}"
OUT="$ROOT/docs/review/art-house"
mkdir -p "$OUT"
cd "$ROOT"
python3 tools/art/house/build_all.py --report
python3 tools/art/house/validate_svg.py
python3 tools/art/house/lint_rects.py
shot() {  # name, args...
  local name="$1"; shift
  tools/scripts/shot.sh res://scenes/dev/house_preview/HousePreview.tscn "$OUT/$name.png" 30 "$SB" -- "$@" 2>&1 | grep -E "ERROR|SCRIPT|\[shot\]" || true
}
for r in porch hall parlour kitchen; do
  shot "${r}_idle" --room=$r
  shot "${r}_rigged" --room=$r --state=rigged
  shot "${r}_rects" --room=$r --rects --badges
done
for r in hall parlour kitchen; do shot "${r}_occupied" --room=$r --state=occupied; done
shot hall_open --room=hall --state=open
shot kitchen_open --room=kitchen --state=open
shot kitchen_spent --room=kitchen --state=spent
shot parlour_spent --room=parlour --state=spent
shot overview --room=parlour --zoom=0.5
shot overview_east --room=garden --zoom=0.5
shot upper_west --room=bathroom
shot upper_east --room=dressing
shot upper_occupied --room=bedroom --state=occupied
shot upper_rigged --room=bedroom --state=rigged
shot conservatory_garden --room=garden
shot upper_rects --room=bedroom --rects
shot garden_rects --room=garden --rects
shot prologue_locked --room=parlour --x=2800 --locked=porch,hall,landing,bathroom,bedroom,dressing,conservatory,garden
shot kitchen_chars_outline --room=kitchen --chars --outline
shot parlour_chars --room=parlour --chars
rm -f "$OUT"/grey_*.png
python3 tools/art/house/sheets.py "$OUT"
rsvg-convert -z 0.5 game/art/house/stage/curtain.svg -o "$OUT/curtain.png"
echo "[review] $OUT"
