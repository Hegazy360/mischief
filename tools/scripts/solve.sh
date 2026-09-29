#!/usr/bin/env bash
# Solver bot: plays every route of every `final` episode headless (TECH §8) and checks each route's
# `expect`, the fairness invariants and determinism. One summary line per run.
# Usage: tools/scripts/solve.sh [<episode>|all] [--route=ideal|required|slow|all] [--auto] [--write-auto]
#                               [--report=/abs/out.json] [--strict] [--auto-gate] [--budget-ms=N]
#   --auto        planner proofs (line alone, whole Script, ★★★, soft-lock) — advisory unless --auto-gate
#   --write-auto  also writes game/data/solutions/_auto/<episode>.json in THIS repo (never authored files)
#   --report      JSON report (+ a .md table next to it)
# Exit 1 on any failed expect / invariant / missing route. Env: SANDBOX (default "solve").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_NAME="${SANDBOX:-solve}"
# The sandbox import can crash intermittently on a busy asset tree: retry it, then run without it.
import_sandbox() {
  local n
  for n in 1 2 3; do
    if "$ROOT/tools/scripts/sandbox.sh" "$1" >/dev/null 2>&1; then return 0; fi
    echo "[$2] sandbox import failed (attempt $n), retrying" >&2
  done
  "$ROOT/tools/scripts/sandbox.sh" "$1" >/dev/null
}
args=()
for a in "$@"; do
  case "$a" in
    --write-auto) args+=("--write-auto" "--auto-dir=$ROOT/game/data/solutions/_auto") ;;
    --report=*) args+=("--report=$(realpath -m "${a#--report=}")") ;;
    *) args+=("$a") ;;
  esac
done
import_sandbox "$SB_NAME" solve
NO_IMPORT=1 exec "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/solve.gd -- ${args[@]+"${args[@]}"}
