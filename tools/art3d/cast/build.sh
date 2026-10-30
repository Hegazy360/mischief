#!/usr/bin/env bash
# Rebuild the 3D cast: palette + face atlases (system python3 + Pillow), then the skinned .glb and
# the runtime rig descriptor for each character (Blender headless — its bundled Python has no PIL,
# which is why the two stages are split).
#
#   tools/art3d/cast/build.sh [--quick] [who ...]      (default: hush bellows)
#
# Output goes to game/art3d/cast/ so the game imports it directly.
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

OUT="${CAST_OUT:-$ROOT/game/art3d/cast}"
mkdir -p "$OUT"

command -v blender >/dev/null 2>&1 || { echo "[cast] 'blender' is not on PATH (see docs/DEV_SETUP.md)" >&2; exit 127; }

# Stage 1 — palette (the 8x8 colour atlas every character samples through UV0).
python3 -c "
import sys; sys.path.insert(0, '$ROOT/tools/art3d/look-toy')
import toy_palette as T; T.write_png('$OUT/cast_palette.png')"
echo "[cast] palette -> $OUT/cast_palette.png"

# Stage 2 — face atlases (SVG -> rsvg-convert -> one atlas per character; needs librsvg + Pillow).
if command -v rsvg-convert >/dev/null 2>&1; then
	python3 "$ROOT/tools/art3d/look-toy/face_atlas.py" "$OUT" all >/dev/null
	# The *_preview.png sheets are a review aid, not runtime art: keep them out of the project so
	# they are neither imported nor exported into the APK.
	mkdir -p "$ROOT/docs/review/cast3d"
	for f in "$OUT"/face_*_preview.png; do
		[ -e "$f" ] && mv "$f" "$ROOT/docs/review/cast3d/" || true
	done
	echo "[cast] face atlases -> $OUT/face_*.png (previews -> docs/review/cast3d/)"
else
	echo "[cast] rsvg-convert missing: building without face decals (brew install librsvg)" >&2
fi

# Stage 3 — the characters.
for who in "${WHO[@]}"; do
	t0=$(date +%s)
	blender -b --python "$HERE/build_cast.py" -- --who "$who" --out "$OUT" $QUICK 2>&1 \
		| grep -E "^\[cast\]|Error|Traceback|rror:" || true
	echo "[cast] $who built in $(( $(date +%s) - t0 ))s"
done
