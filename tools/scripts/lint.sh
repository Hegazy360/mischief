#!/usr/bin/env bash
# Design lints (TECH §10.5): content + hotspot + IP (res://tools/lint/run_lints.gd -- --all), then the
# animation / rig lints (res://tools/anim/lint_anim.gd -- --all) when that module exists.
# Usage: tools/scripts/lint.sh [--strict] [--json=/abs/out.json]   Env: SANDBOX (default "lint").
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
if [ -f "$ROOT/game/tools/anim/lint_anim.gd" ]; then
  NO_IMPORT=1 "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/anim/lint_anim.gd -- --all || rc=1
else
  echo "[lint] anim: SKIPPED — game/tools/anim/lint_anim.gd not built yet"
fi
exit "$rc"
