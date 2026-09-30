#!/usr/bin/env bash
# Design lints (TECH §10.5): content + hotspot + IP (res://tools/lint/run_lints.gd -- --all), then the
# animation / rig lints (res://tools/anim/lint_anim.gd -- --all) when that module exists, then (R3D) the 3D clip
# lint on the g0 + p00 scope (lint_anim.gd -- --format=3d --scope=g0,p00) when game/data/anim/hush3d/ exists.
# Usage: tools/scripts/lint.sh [--strict] [--json=/abs/out.json]   Env: SANDBOX (default "lint").
# Both flags reach both runners: --strict makes content clip-coverage warnings and every anim WARNING errors (the
# pre-gate); --json writes out.json (content/hotspot/ip), out_anim.json (lint_anim, when it supports --json) and
# out_anim3d.json (the 3D clip lint).
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
# lint_anim takes --strict (every WARNING an error; the pre-gate) and --json=… as well
anim_args=()
anim3d_args=()
for a in "$@"; do
  case "$a" in
    --strict) anim_args+=("--strict"); anim3d_args+=("--strict") ;;
    --json=*) j="${a#--json=}"; anim_args+=("--json=${j%.json}_anim.json"); anim3d_args+=("--json=${j%.json}_anim3d.json") ;;
  esac
done
if [ -f "$ROOT/game/tools/anim/lint_anim.gd" ]; then
  NO_IMPORT=1 "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/anim/lint_anim.gd -- --all \
    ${anim_args[@]+"${anim_args[@]}"} || rc=1
  # R3D (ruling R9): the 3D clip lint on the Gate-0 + Prologue scope, once the 3D sidecars and the --format=3d
  # runner exist (r3d-anim); N01/N02 3D clips are reported by it as info, never failing.
  if [ -d "$ROOT/game/data/anim/hush3d" ] && grep -q -- '--format=3d' "$ROOT/game/tools/anim/lint_anim.gd"; then
    NO_IMPORT=1 "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/anim/lint_anim.gd -- --format=3d --scope=g0,p00 \
      ${anim3d_args[@]+"${anim3d_args[@]}"} || rc=1
  else
    echo "[lint] anim3d: SKIPPED — no game/data/anim/hush3d/ or lint_anim.gd --format=3d yet (r3d-anim)"
  fi
else
  echo "[lint] anim: SKIPPED — game/tools/anim/lint_anim.gd not built yet"
fi
exit "$rc"
