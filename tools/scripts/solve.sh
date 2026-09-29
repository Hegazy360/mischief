#!/usr/bin/env bash
# Solver bot: plays every route of every `final` episode headless (TECH §8) and checks each route's
# `expect`, the fairness invariants and determinism. One summary line per run.
# Usage: tools/scripts/solve.sh [<episode>|all] [--route=ideal|required|slow|scenario-name,…|all] [--auto]
#                               [--write-auto] [--report=out.json] [--strict] [--auto-gate] [--budget-ms=N]
#                               [--timeline=dir] [--dump-cmds=dir] [--dump-events=dir] [--baseline=report.json]
#                               [--pregate]
#   --route=all   every route of the solution file (ideal, required, slow and the `scenario` routes)
#   --auto        planner proofs (line alone, whole Script, ★★★, soft-lock) — advisory unless --auto-gate
#   --write-auto  also writes game/data/solutions/_auto/<episode>.json in THIS repo (never authored files)
#   --report      JSON report (+ a .md table next to it)
#   --timeline    one SolverTimeline PNG per run (laughs, visible micro-gag beats, dead air, ⏩)
#   --dump-cmds   <episode>_<route>.cmds.json per run (sim_run --cmds format; replays to the same hash)
#   --baseline    compare with a saved --report (ruling L15): exit 1 only on a NEW failure (a route or an expect
#                 key that passed there fails now; new routes / keys are checked absolutely)
#   --pregate     also fail a run on its pre-gate checks (a warn_ expect key left; edge beats > 1/3 of the beat
#                 credit, ruling L1)
# `warn_<key>` expect keys are evaluated and reported, never failing. Exit 1 on any failed expect / invariant /
# missing route (with --baseline: on any new failure). Env: SANDBOX (default "solve").
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
    --baseline=*) args+=("--baseline=$(realpath -m "${a#--baseline=}")") ;;
    --timeline=*) args+=("--timeline=$(realpath -m "${a#--timeline=}")") ;;
    --dump-cmds=*) args+=("--dump-cmds=$(realpath -m "${a#--dump-cmds=}")") ;;
    --dump-events=*) args+=("--dump-events=$(realpath -m "${a#--dump-events=}")") ;;
    *) args+=("$a") ;;
  esac
done
import_sandbox "$SB_NAME" solve
NO_IMPORT=1 exec "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/solve.gd -- ${args[@]+"${args[@]}"}
