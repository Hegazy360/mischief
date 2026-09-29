#!/usr/bin/env bash
# Regenerate the Stage-2 house-art review artefacts (s2-art) into docs/review/s2-art/: the slice rooms with the
# REAL Hush and Bellows rigs at game framing (1200x540 = a 20:9 phone) in every state, the overviews, the Gate-0
# kitchen (stool, sink lip, open window, honey tell), both cold-open sets in every state, the title card at full
# and at phone scale, and the icon sheet. Usage: tools/art/house/review_s2.sh [sandbox=s2-art]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SB="${1:-s2-art}"
OUT="$ROOT/docs/review/s2-art"
mkdir -p "$OUT"
cd "$ROOT"
python3 tools/art/house/build_all.py --report
python3 tools/art/house/validate_svg.py
python3 tools/art/house/lint_rects.py
shot() {  # name, args...
  local name="$1"; shift
  tools/scripts/shot.sh res://scenes/dev/house_preview/HousePreview.tscn "$OUT/$name.png" 30 "$SB" -- "$@" 2>&1 | grep -E "\[shot\]|HousePreview" || true
}
for r in porch hall parlour kitchen; do
  shot "${r}_chars" --room=$r --chars
  shot "${r}_chars_rigged" --room=$r --chars --state=rigged
done
for r in hall parlour kitchen; do shot "${r}_occupied" --room=$r --state=occupied --nobellows --nohush --chars; done
shot hall_open --room=hall --chars --state=open --nobellows
shot kitchen_open --room=kitchen --chars --state=open --nobellows
shot parlour_spent --room=parlour --chars --state=spent
shot kitchen_spent --room=kitchen --chars --state=spent
shot hall_glow --room=hall --chars --show=hall_front_door_glow
shot parlour_gags --room=parlour --chars --nobellows --show=parlour_vase_smashed --decor=parlour_picture_frame:falling
shot g0_stool --room=kitchen --chars --bpose=b_stool_sit --nohush --state=rigged --x=3300
shot g0_sink --room=kitchen --chars --bx=3788 --bpose=b_sink_sit --bface=-1 --show=kitchen_sink_lip --nohush --x=3400 --state=open
shot overview_chars --zoom=0.5 --chars
shot overview_n01 --zoom=0.5 --chars --slice=n01
shot kitchen_n01_locked --room=kitchen --chars --slice=n01
shot prologue_locked --room=parlour --x=2800 --chars --slice=p00
shot cold_n01 --cold=n01_throat_tea --chars
shot cold_n01_cracked --cold=n01_throat_tea --chars --cold_state=window_no9:cracked,birds:flown
shot cold_n01_rects --cold=n01_throat_tea --rects
shot cold_n02 --cold=n02_something_fishy --chars
shot cold_n02_popped --cold=n02_something_fishy --chars --cold_state=balloon:popped
shot cold_n02_confiscated --cold=n02_something_fishy --chars --cold_state=balloon:none,box:string --bface=-1
shot title --title
shot title_phone --title --title_scale=0.5
python3 - "$OUT" <<'PY'
import os, subprocess, sys
from PIL import Image
out = sys.argv[1]
# the upper-floor band + conservatory edge from the kitchen shot, 2x (what every ground-floor frame shows)
k = Image.open(os.path.join(out, "kitchen_chars.png"))
k.crop((0, 0, 1200, 100)).resize((2400, 200), Image.LANCZOS).save(os.path.join(out, "kitchen_band_2x.png"))
k.crop((860, 60, 1200, 440)).resize((680, 760), Image.LANCZOS).save(os.path.join(out, "kitchen_conservatory_2x.png"))
PY
python3 - "$OUT" <<'PY'
import json, os, sys
sys.path.insert(0, "tools/art/house")
import sheets
out = sys.argv[1]
sheets.icon_sheet(os.path.join(sheets.ART, "icons", "activities"), os.path.join(out, "activities_sheet.png"), 88, (1.0, 0.5), cols=9, bubble=True)
house = json.load(open(os.path.join(sheets.REPO, "game", "data", "house", "house.json")))
for room in ("landing", "bathroom", "bedroom", "dressing", "conservatory"):
    sheets.prop_sheet(house, room, os.path.join(out, "props_%s_states.png" % room))
PY
echo "[review] $OUT"
