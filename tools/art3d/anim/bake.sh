#!/usr/bin/env bash
# Bake 3D clips: clip specs (tools/art3d/anim/<rig>/<clip>.py) -> Blender (one process) -> glTF actions
# (build/art3d/anim/<rig>/<clip>.glb, gitignored) + sidecars (game/data/anim/<rig>3d/<clip>.json) -> Godot (one
# converter run in your sandbox) -> game/art3d/anim/<rig>/<clip>.res, each linted (the 3D animation lint).
#
#   SANDBOX=<your task key> tools/art3d/anim/bake.sh <rig> [clip ...|--all] [--changed] [--strict]
#   SANDBOX=<key> tools/art3d/anim/bake.sh <rig> --ual <UAL clip> --as <rig>/<clip id> [--layers mime,damp_head]
#   tools/art3d/anim/bake.sh <rig> --done <clip>        # print the DONE line for your LANDED.md (R16)
#   tools/art3d/anim/bake.sh --audio-rows               # docs/review/r3d-anim/audio_rows.md (r3d-anim)
#
# --changed: only specs newer than their .res (or older than the pipeline library / the rig's glb / the rig's
# shared _lib) — the resume after a restart. --strict: the lint's warnings count as errors in the table.
# Env: SANDBOX (required: your task key, never someone else's), RIG_GLB=/abs/rig.glb (a stand-in skeleton until
# the cast task's game/art3d/chars/<rig>/<rig>.glb exists), NO_LINT=1, MND_SANDBOX_ROOT; fixtures / experiments:
# BAKE_SIDECAR_DIR=/abs, BAKE_RES_DIR=/abs, BAKE_RES_PREFIX=res://… (where the sidecars and .res go instead of game/).
# Prints a table (clip, frames, max°/f, bake ms, KB, OK / errors); exit 1 when any clip failed or has lint errors.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CLI="$ROOT/tools/art3d/anim/lib/bake_cli.py"
if [ "${1:-}" = "--audio-rows" ]; then
  exec python3 "$CLI" audio-rows "$ROOT/docs/review/r3d-anim/audio_rows.md"
fi
RIG="${1:?usage: bake.sh <rig> [clip ...|--all] [--changed] [--strict] | <rig> --ual <clip> --as <id>}"; shift
if [ "${1:-}" = "--done" ]; then
  exec python3 "$CLI" done "$RIG" "${2:?clip}"
fi
: "${SANDBOX:?set SANDBOX=<your task key> (the Godot converter runs in that sandbox)}"
NAMES=(); FLAGS=(); UAL=""; AS=""; LAYERS=""; STRICT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ual) UAL="$2"; shift 2 ;;
    --as) AS="$2"; shift 2 ;;
    --layers) LAYERS="$2"; shift 2 ;;
    --strict) STRICT="--strict"; shift ;;
    --all|--changed) FLAGS+=("$1"); shift ;;
    -*) echo "bake: unknown flag $1" >&2; exit 64 ;;
    *) NAMES+=("$1"); shift ;;
  esac
done
RIG_GLB="${RIG_GLB:-$ROOT/game/art3d/chars/$RIG/$RIG.glb}"
[ -f "$RIG_GLB" ] || { echo "bake: rig skeleton $RIG_GLB not found (set RIG_GLB=/abs/stand_in.glb)" >&2; exit 66; }
BUILD="$ROOT/build/art3d/anim/$RIG"
mkdir -p "$BUILD"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/bake_${RIG}_XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SPECS=()
if [ -z "$UAL" ] || [ "${#NAMES[@]}" -gt 0 ] || [ "${#FLAGS[@]}" -gt 0 ]; then
  if [ "${#NAMES[@]}" -eq 0 ] && [ "${#FLAGS[@]}" -eq 0 ] && [ -z "$UAL" ]; then
    echo "bake: name clips, or --all / --changed" >&2; exit 64
  fi
  if [ "${#NAMES[@]}" -gt 0 ] || [ "${#FLAGS[@]}" -gt 0 ]; then
    mapfile -t SPECS < <(python3 "$CLI" specs "$RIG" "${NAMES[@]}" "${FLAGS[@]}")
  fi
fi
if [ "${#SPECS[@]}" -eq 0 ] && [ -z "$UAL" ]; then
  echo "bake: nothing to bake (${FLAGS[*]:-})"; exit 0
fi
ARGS=(--rig "$RIG" --rig-glb "$RIG_GLB" --out "$BUILD" --results "$TMP/results.json")
[ -n "${BAKE_SIDECAR_DIR:-}" ] && ARGS+=(--sidecars "$BAKE_SIDECAR_DIR")
[ -n "${BAKE_RES_PREFIX:-}" ] && ARGS+=(--res-prefix "$BAKE_RES_PREFIX")
for s in "${SPECS[@]}"; do ARGS+=(--spec "$s"); done
if [ -n "$UAL" ]; then
  ARGS+=(--ual "$UAL" --as "${AS:-$RIG/ual_${UAL,,}}"); [ -n "$LAYERS" ] && ARGS+=(--layers "$LAYERS")
fi
echo "[bake] blender: ${#SPECS[@]} spec(s)${UAL:+ + UAL $UAL}"
"$ROOT/tools/art3d/blender.sh" --python "$ROOT/tools/art3d/anim/lib/bake_main.py" -- "${ARGS[@]}" >"$TMP/blender.log" 2>&1 || true
grep -E '^\[bake\]|Error|Traceback|  File "' "$TMP/blender.log" | grep -v '^\[bake\] blender' || true
[ -f "$TMP/results.json" ] || { echo "bake: Blender produced no results (log: $TMP/blender.log)" >&2; tail -30 "$TMP/blender.log" >&2; exit 70; }
N="$(python3 "$CLI" jobs "$TMP/results.json" "$TMP/jobs.json")"
if [ "$N" -gt 0 ]; then
  SB="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}/$SANDBOX/game"
  if [ -f "$SB/.godot/global_script_class_cache.cfg" ]; then export NO_IMPORT=1; fi
  LINT=(--lint); [ -n "${NO_LINT:-}" ] && LINT=()
  echo "[bake] godot ($SANDBOX): converting $N clip(s)"
  "$ROOT/tools/scripts/sandbox.sh" "$SANDBOX" -s res://tools/anim/glb_to_res.gd -- --batch="$TMP/jobs.json" "${LINT[@]}" $STRICT \
    >"$TMP/convert.log" 2>&1 || true
  grep -E '^(ERROR|WARNING|INFO) L[0-9]' "$TMP/convert.log" || true
  grep -E 'SCRIPT ERROR|Parse Error' "$TMP/convert.log" | head -20 || true
fi
python3 "$CLI" table "$TMP/results.json" "$TMP/convert.log"
