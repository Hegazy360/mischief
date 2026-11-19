#!/usr/bin/env bash
# Reach review sheet (docs/research/animation.md, phase 2): one AnimViewer shot per container / rig point,
# Hush standing at the hotspot playing her work clip (rummage for containers, tinker for rig points) with the
# hotspot's grab crosshair (green = the gloves are on it, grey = skipped / not reaching), cropped and tiled.
# Usage: tools/scripts/reach_sheet.sh <out.png> [sandbox] [-- extra AnimViewer args, e.g. --no-reach]
#   REACH_IDS="kitchen_kettle hall_confiscated_box"  only these hotspots
#   REACH_FRAME=30                                   frames to run before the shot
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/tools/scripts/lib.sh"
OUT="$(mnd_abspath "${1:?out.png}")"; shift
SB="reach"
if [ $# -gt 0 ] && [ "$1" != "--" ]; then SB="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_reach.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
IDS="${REACH_IDS:-$(python3 -c "
import json
h = json.load(open('$ROOT/game/data/house/house.json'))
print(' '.join(x['id'] + ':' + x['kind'] for x in h['hotspots'] if x['kind'] in ('container', 'rig_point')))")}"
n=0
for entry in $IDS; do
	id="${entry%%:*}"; kind="${entry#*:}"
	if [ "$kind" = "$id" ]; then
		kind="$(python3 -c "import json;print(next(x['kind'] for x in json.load(open('$ROOT/game/data/house/house.json'))['hotspots'] if x['id']=='$id'))")"
	fi
	clip="act_tinker_q"; [ "$kind" = "container" ] && clip="act_rummage"
	"$ROOT/tools/scripts/shot.sh" res://scenes/dev/AnimViewer.tscn "$TMP/$(printf %02d $n)_$id.png" "${REACH_FRAME:-30}" "$SB" -- \
		--rig=hush --clip="$clip" --hotspot="$id" --zoom=1.6 --paused "$@" >/dev/null 2>&1 || echo "[reach_sheet] $id: shot failed" >&2
	n=$((n + 1))
done
python3 - "$TMP" "$OUT" <<'EOF'
import glob, os, sys
from PIL import Image, ImageDraw
tmp, out = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(tmp, "*.png")))
if not files:
    sys.exit("[reach_sheet] no shots")
cw, ch, cols = 420, 360, 6
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cw * cols, (ch + 26) * rows), (24, 20, 34))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    im = Image.open(f).convert("RGB")
    w, h = im.size
    # the AnimViewer frames the rig at 34 % of the width; crop around it
    cx = int(w * 0.34)
    box = (max(0, cx - cw // 2), max(0, h - 120 - ch), max(0, cx - cw // 2) + cw, max(0, h - 120 - ch) + ch)
    x, y = (i % cols) * cw, (i // cols) * (ch + 26)
    sheet.paste(im.crop(box), (x, y + 26))
    d.text((x + 6, y + 6), os.path.basename(f)[3:-4], fill=(240, 230, 200))
sheet.save(out)
print("[reach_sheet] %d hotspots -> %s" % (len(files), out))
EOF
