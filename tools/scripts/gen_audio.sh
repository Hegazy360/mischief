#!/usr/bin/env bash
# Render every procedural sound (tools/audio, numpy only) into game/audio/, rewrite
# game/audio/sfx_map.json and verify the result (formats, levels, loops, budgets, ids).
# Usage:
#   tools/scripts/gen_audio.sh                 # render everything + --check (exit 1 on errors)
#   tools/scripts/gen_audio.sh --check         # verify only (CI)
#   tools/scripts/gen_audio.sh --only a,b      # re-render some recipes / music jobs, then check
#   tools/scripts/gen_audio.sh --pack          # ... and rebuild the docs/review/audio Gate-0 pack
# Deterministic: re-running produces byte-identical files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PACK=0
ARGS=()
for a in "$@"; do
  if [ "$a" = "--pack" ]; then PACK=1; else ARGS+=("$a"); fi
done
if [ "${ARGS[0]:-}" = "--check" ]; then
  exec python3 tools/audio/gen_audio.py "${ARGS[@]}"
fi
python3 tools/audio/gen_audio.py "${ARGS[@]+"${ARGS[@]}"}"
if [ "$PACK" = 1 ]; then
  python3 tools/audio/review.py --pack
fi
