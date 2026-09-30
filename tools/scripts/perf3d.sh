#!/usr/bin/env bash
# The 3D frame budget on e2e reports (index §6 row 16; owner r3d-tools-b): reads each report's `perf3d` block
# (r3d-night's Perf3D.summary) — draw calls p95 ≤ 150 and max ≤ 250, triangles max ≤ 150k, emitters max ≤ 8,
# texture ≤ 250 MB, shader_compiles_play == 0, script ms p95 ≤ 4 — prints one table row per report and exits 1 on
# any breach (a report without a perf3d block is a SKIP; --strict fails on it).
# Usage: tools/scripts/perf3d.sh <e2e report.json>… [--strict] [--json=/abs/out.json]
# Env: SANDBOX (default perf3d). One headless Godot process through tools/scripts/slot.sh (R11).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_NAME="${SANDBOX:-perf3d}"
args=()
files=0
for a in "$@"; do
  case "$a" in
    --json=*) args+=("--json=$(realpath -m "${a#--json=}")") ;;
    --strict|--verbose) args+=("$a") ;;
    *) args+=("$(realpath -m "$a")"); files=$((files + 1)) ;;
  esac
done
[ "$files" -gt 0 ] || { echo "usage: perf3d.sh <e2e report.json>… [--strict] [--json=/abs.json]" >&2; exit 2; }
ok=""
for n in 1 2 3; do
  if "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null 2>&1; then ok=1; break; fi
  echo "[perf3d] sandbox import failed (attempt $n), retrying" >&2
done
[ -n "$ok" ] || "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null || exit 3
NO_IMPORT=1 exec "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/lint3d/run_lint3d.gd -- --perf "${args[@]}"
