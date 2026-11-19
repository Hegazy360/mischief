#!/usr/bin/env bash
# Reach before / after on a REAL Night (docs/research/animation.md): replays a solver route in the ViewSandbox on
# the real sim and, at each moment Hush works at a prop, captures the same frames twice — clips as authored
# (`--no-reach`) and with reach + posture — and stacks them, BEFORE over AFTER, cropped around Hush.
# Usage: tools/scripts/reach_ab.sh <out_dir> [episode] [route] [sandbox]
#   defaults: n01_throat_tea ideal reach-ab. One PNG per moment: <out_dir>/<nn>_<hotspot>_t<tick>.png
#   REACH_AB_MAX=8   moments at most (the first N rig / rummage / pick moments of the route)
#   REACH_AB_FRAMES=8 frames per strip (every 6 frames from 6 ticks after the work starts)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/tools/scripts/lib.sh"
OUT="$(mnd_abspath "${1:?out_dir}")"; EP="${2:-n01_throat_tea}"; RT="${3:-ideal}"; SB="${4:-reach-ab}"
mkdir -p "$OUT"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_reach_ab.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SANDBOX="$SB-solve" "$ROOT/tools/scripts/solve.sh" "$EP" "--route=$RT" "--dump-cmds=$TMP" >"$TMP/solve.log" 2>&1 || true
CMDS="$TMP/${EP}_${RT}.cmds.json"
[ -f "$CMDS" ] || { echo "[reach_ab] no route '$RT' for $EP (see solve.sh)"; cat "$TMP/solve.log" | tail -5; exit 1; }
# Moments: a `rig on` or a `pick` right after a `go` to a hotspot (the work starts on arrival).
MOMENTS="$(python3 - "$CMDS" "${REACH_AB_MAX:-8}" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
cmds = d["cmds"] if isinstance(d, dict) else d
out, last_go = [], None
for t, c in cmds:
    if c.get("c") == "go":
        last_go = c.get("hotspot", "")
    elif c.get("c") in ("rig", "pick") and (c.get("c") == "pick" or c.get("on")) and last_go:
        out.append("%s:%d" % (last_go, t + (-10 if c.get("c") == "pick" else 6)))
        last_go = None
print(" ".join(out[: int(sys.argv[2])]))
EOF
)"
n=0
for m in $MOMENTS; do
	hs="${m%%:*}"; t="${m#*:}"
	for mode in off on; do
		d="$TMP/$n-$mode"; mkdir -p "$d"
		extra=(); [ "$mode" = off ] && extra=(--no-reach)
		"$ROOT/tools/scripts/shot.sh" res://view/sandbox/ViewSandbox.tscn "$d/last.png" 60 "$SB" -- --sim --episode="$EP" \
			--cmds="$CMDS" --seek="$t" ${extra[@]+"${extra[@]}"} --shot-seq="$d" --every=6 --count="${REACH_AB_FRAMES:-8}" \
			>/dev/null 2>&1 || echo "[reach_ab] $hs t$t ($mode): capture failed" >&2
	done
	python3 - "$TMP/$n-off" "$TMP/$n-on" "$OUT/$(printf %02d $n)_${hs}_t$t.png" "$hs" "$ROOT/game/data/house/house.json" <<'EOF'
import glob, json, sys
from PIL import Image, ImageDraw
off, on, out, hs, house = sys.argv[1:6]
fo, fn = sorted(glob.glob(off + "/frame_*.png")), sorted(glob.glob(on + "/frame_*.png"))
if not fo or not fn:
    sys.exit("[reach_ab] %s: no frames" % hs)
# Crop: the column where the two runs differ most (that is Hush), else the frame's middle.
a, b = Image.open(fo[len(fo) // 2]).convert("L"), Image.open(fn[len(fn) // 2]).convert("L")
w, h = a.size
diff = [sum(abs(a.getpixel((x, y)) - b.getpixel((x, y))) for y in range(0, h, 6)) for x in range(0, w, 6)]
cx = (max(range(len(diff)), key=lambda i: diff[i]) * 6) if max(diff) > 0 else w // 2
cw, ch = 340, 330
box = (max(0, min(w - cw, cx - cw // 2)), max(0, h - ch - 100), max(0, min(w - cw, cx - cw // 2)) + cw, h - 100)
rows = []
for label, fs in (("BEFORE (authored)", fo), ("AFTER (reach + posture)", fn)):
    cells = [Image.open(f).convert("RGB").crop(box) for f in fs]
    row = Image.new("RGB", (cw * len(cells), ch + 22), (20, 18, 30))
    ImageDraw.Draw(row).text((6, 4), "%s — %s" % (hs, label), fill=(240, 220, 160))
    for i, c in enumerate(cells):
        row.paste(c, (i * cw, 22))
    rows.append(row)
s = Image.new("RGB", (rows[0].size[0], sum(r.size[1] for r in rows) + 6), (10, 10, 16))
s.paste(rows[0], (0, 0)); s.paste(rows[1], (0, rows[0].size[1] + 6))
s.save(out)
print("[reach_ab] %s" % out)
EOF
	n=$((n + 1))
done
echo "[reach_ab] $n moments of $EP ($RT) -> $OUT"
