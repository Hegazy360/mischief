#!/usr/bin/env bash
# Every lint in one go: tools/scripts/lint.sh (content, hotspot, IP, anim/rig) + every
# tools/art/*/validate*.py (and lint_*.py) + the 3D review toolset tests (tools/art3d/review/test_review.py) +
# `python3 tools/audio/gen_audio.py --check`, each only
# when it exists. Usage: tools/ci/lint_all.sh [--no-godot]   (--no-godot: only the Python checks)
# Needs Python 3 + numpy + Pillow, and `rsvg-convert` (apt librsvg2-bin) for the art validators.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
rc=0
if [ "${1:-}" != "--no-godot" ]; then
  tools/scripts/lint.sh || rc=1
fi
shopt -s nullglob
py=(tools/art/*/validate*.py tools/art/*/lint_*.py)
if [ ${#py[@]} -eq 0 ]; then
  echo "[lint_all] art: SKIPPED — no tools/art/*/validate*.py yet"
elif ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "[lint_all] art: rsvg-convert not found — install librsvg2-bin (apt) to run the art validators" >&2
  rc=1
fi
for s in "${py[@]}"; do
  echo "[lint_all] python3 $s"
  python3 "$s" || rc=1
done
if [ -f tools/art3d/review/test_review.py ]; then
  # the R14 review toolset every 3D art lint measures with (r3d-tools-a): numpy + Pillow, ~10 s
  echo "[lint_all] python3 -m unittest tools/art3d/review/test_review.py"
  python3 -m unittest tools/art3d/review/test_review.py || rc=1
fi
if [ -f tools/audio/gen_audio.py ]; then
  echo "[lint_all] python3 tools/audio/gen_audio.py --check"
  python3 tools/audio/gen_audio.py --check || rc=1
else
  echo "[lint_all] audio: SKIPPED — tools/audio/gen_audio.py not built yet"
fi
[ "$rc" -eq 0 ] && echo "[lint_all] OK" || echo "[lint_all] FAIL"
exit "$rc"
