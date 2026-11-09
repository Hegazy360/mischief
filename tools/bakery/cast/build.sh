#!/usr/bin/env bash
# Build the game's cast from KayKit (CC0) bodies, for the Bakery to bake.
#
#   tools/bakery/cast/build.sh [hush|gus ...]      (default: both)
#
# hush: recolour.py repaints the KayKit Rogue's palette atlas, redress.py (Blender) paints her
#       Breton stripes and adds beret + braces on new bones inside KayKit's rig.
# gus:  neighbour.py (Blender) dresses KayKit's blank Large mannequin from scratch, painting every
#       face by the bone that carries it (singlet, shorts, wristbands, sneakers) + a flat-top.
#
# The body, skeleton and skinning are KayKit's and are never rebuilt, so every KayKit library clip
# drives the cast unchanged. Output goes to tools/bakery/cast/out/ — NOT game/: the game only ever
# sees the baked sprite sheets.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
SRC="$ROOT/game/proto/toyhouse/assets/kaykit"
OUT="${CAST_OUT:-$HERE/out}"
WHO=("$@")
[ "${#WHO[@]}" -gt 0 ] || WHO=(hush gus)
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_cast.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
command -v blender >/dev/null 2>&1 || { echo "[cast] 'blender' is not on PATH (docs/DEV_SETUP.md)" >&2; exit 127; }

base_of() {
	case "$1" in
		hush) echo "Rogue Rogue_rogue_texture.png" ;;
		*) echo "" ;;
	esac
}

for who in "${WHO[@]}"; do
	if [ "$who" = gus ]; then
		t0=$(date +%s)
		rm -f "$OUT/gus.glb"     # a failed build must not pass on the previous model
		blender -b --factory-startup --python-exit-code 1 --python "$HERE/neighbour.py" -- \
			--src "$HERE/src/Mannequin_Large.glb" --out "$OUT" 2>&1 | grep -E "^\[neighbour\]|Error|Traceback" || true
		[ -s "$OUT/gus.glb" ] || { echo "[cast] gus: no .glb written" >&2; exit 1; }
		echo "[cast] gus built in $(( $(date +%s) - t0 ))s -> ${OUT#$ROOT/}/gus.glb"
		continue
	fi
	read -r model tex <<<"$(base_of "$who")"
	[ -n "$model" ] || { echo "[cast] unknown character '$who'" >&2; exit 2; }
	t0=$(date +%s)
	rm -f "$OUT/$who.glb"
	python3 "$HERE/recolour.py" "$who" "$SRC/$tex" "$TMP/${who}_atlas.png"
	blender -b --factory-startup --python-exit-code 1 --python "$HERE/redress.py" -- --who "$who" \
		--src "$SRC/$model.glb" --atlas "$TMP/${who}_atlas.png" --out "$OUT" 2>&1 \
		| grep -E "^\[redress\]|Error|Traceback|rror:" || true
	[ -s "$OUT/$who.glb" ] || { echo "[cast] $who: no .glb written" >&2; exit 1; }
	echo "[cast] $who built in $(( $(date +%s) - t0 ))s -> ${OUT#$ROOT/}/$who.glb"
done
