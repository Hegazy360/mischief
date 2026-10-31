#!/usr/bin/env bash
# Rebuild the 3D cast from the KayKit (CC0) source characters.
#
#   tools/art3d/cast/build.sh [--quick] [hush|bellows ...]      (default: both)
#
# Two stages, because Blender's bundled Python has no Pillow:
#   1. recolour.py (system python3) repaints the character's gradient atlas into our palette;
#   2. redress.py (Blender) drops the clashing meshes, swaps the atlas in, paints Hush's Breton
#      stripes onto the tunic's own faces, adds our accessories on new jiggle bones, and writes
#      the .glb plus the runtime rig descriptor.
#
# The body, skeleton and skinning are never rebuilt -- that is the point of using a finished
# open-source cast. Animation comes from the KayKit library in game/art3d/cast/anim/ via
# game/data/anim/clipmap3d.json; only the gags the library lacks stay as our own 2D clips.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
. "$ROOT/tools/scripts/lib.sh"

QUICK=""
WHO=()
for a in "$@"; do
	case "$a" in
		--quick) QUICK="--quick" ;;
		*) WHO+=("$a") ;;
	esac
done
[ "${#WHO[@]}" -gt 0 ] || WHO=(hush bellows)

SRC="$HERE/src"
OUT="${CAST_OUT:-$ROOT/game/art3d/cast}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_cast.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

command -v blender >/dev/null 2>&1 || { echo "[cast] 'blender' is not on PATH (docs/DEV_SETUP.md)" >&2; exit 127; }

# Which KayKit character each cast member is re-dressed from.
base_of() {
	case "$1" in
		hush) echo "Rogue rogue_texture.png" ;;
		bellows) echo "Mage mage_texture.png" ;;
		*) echo "" ;;
	esac
}

# Face decal atlases (used by the toon shader's face cards; needs librsvg + Pillow).
if command -v rsvg-convert >/dev/null 2>&1; then
	python3 "$ROOT/tools/art3d/look-toy/face_atlas.py" "$OUT" all >/dev/null
	mkdir -p "$ROOT/docs/review/cast3d"
	for f in "$OUT"/face_*_preview.png; do
		[ -e "$f" ] && mv "$f" "$ROOT/docs/review/cast3d/" || true
	done
else
	echo "[cast] rsvg-convert missing: skipping face atlases (brew install librsvg)" >&2
fi

for who in "${WHO[@]}"; do
	read -r model tex <<<"$(base_of "$who")"
	[ -n "$model" ] || { echo "[cast] unknown character '$who'" >&2; exit 2; }
	t0=$(date +%s)
	python3 "$HERE/recolour.py" "$who" "$SRC/$tex" "$TMP/${who}_atlas.png"
	blender -b --python "$HERE/redress.py" -- --who "$who" --src "$SRC/$model.glb" \
		--atlas "$TMP/${who}_atlas.png" --out "$OUT" $QUICK 2>&1 \
		| grep -E "^\[redress\]|Error|Traceback|rror:" || true
	echo "[cast] $who built in $(( $(date +%s) - t0 ))s"
done
