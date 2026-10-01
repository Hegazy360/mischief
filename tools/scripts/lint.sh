#!/usr/bin/env bash
# Design lints (TECH §10.5): content + hotspot + IP (res://tools/lint/run_lints.gd -- --all, incl. the 3D clip
# coverage of ruling R9), then the 3D clip lint (res://tools/anim/lint_anim.gd -- --format=3d: every 3D clip, then the
# g0 + p00 scope with --strict / --json). The 2D anim / rig lints and the 2D coverage went with the 2D path.
# Usage: tools/scripts/lint.sh [--strict] [--json=/abs/out.json]   Env: SANDBOX (default "lint").
# --strict makes content coverage warnings and every 3D-anim WARNING of the scope errors (the pre-gate); --json writes
# out.json (content/hotspot/ip) and out_anim3d.json (the 3D clip lint of the scope).
# Exit 1 if any lint fails.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_NAME="${SANDBOX:-lint}"
# The sandbox import can crash intermittently on a busy asset tree: retry it, then run without it.
import_sandbox() {
  local n
  for n in 1 2 3; do
    if "$ROOT/tools/scripts/sandbox.sh" "$1" >/dev/null 2>&1; then return 0; fi
    echo "[$2] sandbox import failed (attempt $n), retrying" >&2
  done
  "$ROOT/tools/scripts/sandbox.sh" "$1" >/dev/null
}
rc=0
import_sandbox "$SB_NAME" lint || rc=1
NO_IMPORT=1 "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/lint/run_lints.gd -- --all \
  "--gdd=$ROOT/docs/GDD.md" "$@" || rc=1
# the scoped 3D lint takes --strict (every WARNING an error; the pre-gate) and --json=… as well
anim3d_args=()
for a in "$@"; do
  case "$a" in
    --strict) anim3d_args+=("--strict") ;;
    --json=*) j="${a#--json=}"; anim3d_args+=("--json=${j%.json}_anim3d.json") ;;
  esac
done
if [ -f "$ROOT/game/tools/anim/lint_anim.gd" ] && [ -d "$ROOT/game/data/anim/hush3d" ]; then
  # R3D: every 3D clip (errors only; the 2D clip lint went with the 2D path, r3d-integrate), then the ruling-R9 scope
  # (Gate 0 + the Prologue + the band fallbacks) with --strict / --json when given; N01/N02 clips are info there.
  NO_IMPORT=1 "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/anim/lint_anim.gd -- --format=3d || rc=1
  NO_IMPORT=1 "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/anim/lint_anim.gd -- --format=3d --scope=g0,p00 \
    ${anim3d_args[@]+"${anim3d_args[@]}"} || rc=1
else
  echo "[lint] anim3d: SKIPPED — no game/tools/anim/lint_anim.gd or game/data/anim/hush3d/"
fi
exit "$rc"
