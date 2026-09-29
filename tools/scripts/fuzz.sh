#!/usr/bin/env bash
# Fairness fuzz (TECH §8.6): seeded random / reckless / hider / bait bots on every `final` episode,
# invariants + soft-lock probe per run, determinism replay every 5th run.
# Usage: tools/scripts/fuzz.sh [<episode>|all] [--runs=20] [--seed=1] [--bot=all|random,reckless,hider,bait]
#                              [--ticks=10800] [--report=/abs/out.json] [--verbose] [--no-probe] [--strict]
#                              [--dump-cmds=/abs/dir]  (first run per episode × bot with a caught / face_to_face /
#                              meltdown_start / chase_start → <episode>_<bot>_<event>.cmds.json, sim_run --cmds format)
# Exit 1 on any violation. Env: SANDBOX (default "fuzz").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_NAME="${SANDBOX:-fuzz}"
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
    --report=*) args+=("--report=$(realpath -m "${a#--report=}")") ;;
    --dump-cmds=*) args+=("--dump-cmds=$(realpath -m "${a#--dump-cmds=}")") ;;
    *) args+=("$a") ;;
  esac
done
import_sandbox "$SB_NAME" fuzz
NO_IMPORT=1 exec "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/fuzz.gd -- ${args[@]+"${args[@]}"}
