#!/usr/bin/env bash
# The REDESIGN §6.3 lints on the 3D game (owner r3d-tools-b; index §6 rows 9–12; TECH §10.5).
#
# Usage: tools/scripts/lint3d.sh <mode>… [options]
#   --set          counts, geometry, silhouette families, stacks (headless) + colour / value and 64 px silhouettes on
#                  LintShot3D renders (beauty / id / mask passes under xvfb → tools/art3d/review lab.py + sil64.py)
#   --screen       projected hit boxes at every framing, per aspect (headless) + a rects board per room per aspect
#   --hud          the e2e reports' HUD pieces, overlays and Bellows-window share (needs --from=<dir of e2e reports>)
#   --visibility   C8 on every frame of every solver route (solve.sh --dump-cmds, then a headless replay through the
#                  view stack), both window modes; a 1200×540 shot of the first violation per route
#   --self-test    the Python half on its fixtures (render_measure.py: a C* 40 dressing fails, IoU 0.9 masks fail)
# Options: --night=<id>,… | --all-nights (default all: g0_sneeze p00_curtain_up n01_throat_tea n02_something_fishy)
#          --aspects=20x9,16x9,4x3 (screen; visibility default 20x9)  --routes=all|ideal,…  --mode=sim|lean
#          --from=<dir> (hud)  --strict (a SKIP fails)  --json=/abs/out.json  --no-render (headless rules only)
#          --boards=<dir> (default $OUT/boards; docs/review/r3d-tools-b/boards for the review set)  --verbose
# Env: SANDBOX (default lint3d), LINT3D_OUT (default <repo>/build/lint3d: shots, cmds, measures), SHOT_TIMEOUT for the
# render batch (default 1200 s once a slot is free). Every Godot process runs through tools/scripts/slot.sh (R11), one
# at a time. Exit 1 when any mode fails (an error; with --strict also a SKIP); warnings never fail.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_NAME="${SANDBOX:-lint3d}"
OUT="${LINT3D_OUT:-$ROOT/build/lint3d}"
MODES=(); PASS=(); JSON=""; RENDER=1; BOARDS=""; FROM=""; STRICT=""; NIGHTS="all"; ASPECTS=""; SELFTEST=""
for a in "$@"; do
  case "$a" in
    --set|--screen|--hud|--visibility) MODES+=("${a#--}") ;;
    --self-test) SELFTEST=1 ;;
    --json=*) JSON="$(realpath -m "${a#--json=}")" ;;
    --no-render) RENDER="" ;;
    --boards=*) BOARDS="$(realpath -m "${a#--boards=}")" ;;
    --from=*) FROM="$(realpath -m "${a#--from=}")"; PASS+=("--from=$FROM") ;;
    --strict) STRICT=1; PASS+=("--strict") ;;
    --all-nights) NIGHTS="all" ;;
    --night=*) NIGHTS="${a#--night=}"; PASS+=("$a") ;;
    --aspects=*) ASPECTS="${a#--aspects=}" ;;
    *) PASS+=("$a") ;;
  esac
done
BOARDS="${BOARDS:-$OUT/boards}"
mkdir -p "$OUT" "$BOARDS"
rc=0

if [ -n "$SELFTEST" ]; then
  python3 "$ROOT/game/tools/lint3d/render_measure.py" "$ROOT/game/tests/lint3d/fixtures/shots" \
    --review="$ROOT/tools/art3d/review" --boards="$OUT/selftest_boards" --out="$OUT/selftest_measure.json" || rc=1
  python3 - "$OUT/selftest_measure.json" <<'EOF' || rc=1
import json, sys
m = json.load(open(sys.argv[1]))
r = m["rooms"][0]
fails = [x["name"] for x in r["rules"]["results"] if x["status"] == "FAIL"]
pairs = [(p["a"], p["b"]) for p in r["sil"]["pairs_over"]]
ok = fails == ["fx_rug_c40"] and pairs == [("fx_jar", "fx_jar_twin")]
print("[lint3d] self-test %s: colour FAIL %s, IoU >= 0.80 %s" % ("OK" if ok else "FAIL", fails, pairs))
sys.exit(0 if ok else 1)
EOF
  [ "${#MODES[@]}" -eq 0 ] && exit "$rc"
fi
[ "${#MODES[@]}" -eq 0 ] && { echo "usage: lint3d.sh --set|--screen|--hud|--visibility|--self-test [options]" >&2; exit 2; }

has_mode() { local m; for m in "${MODES[@]}"; do [ "$m" = "$1" ] && return 0; done; return 1; }

# One import (new class_name scripts register only on import), retried like lint.sh does.
import_ok=""
for n in 1 2 3; do
  if "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null 2>&1; then import_ok=1; break; fi
  echo "[lint3d] sandbox import failed (attempt $n), retrying" >&2
done
[ -n "$import_ok" ] || "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null || exit 3
SB="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}/$SB_NAME/game"
godot_lint() { NO_IMPORT=1 "$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" -s res://tools/lint3d/run_lint3d.gd -- "$@"; }
parts=()

# --- renders (one xvfb process for every pass the requested modes need) ---
if [ -n "$RENDER" ] && { has_mode set || has_mode screen; }; then
  passes=()
  has_mode set && passes+=("beauty,id,mask")
  has_mode screen && passes+=("rects")
  pj="$(IFS=,; echo "${passes[*]}")"
  rm -rf "$OUT/shots"; mkdir -p "$OUT/shots"
  NO_IMPORT=1 SHOT_TIMEOUT="${SHOT_TIMEOUT:-1200}" "$ROOT/tools/scripts/shot.sh" res://scenes/dev/review3d/LintShot3D.tscn \
    "$OUT/shots/last.png" 999999 "$SB_NAME" -- --batch=all "--night=$NIGHTS" "--out-dir=$OUT/shots" "--passes=$pj" \
    "--aspects=${ASPECTS:-20x9,16x9,4x3}" | grep -E '^\[LintShot3D\]|ERROR|SCRIPT' | tail -200
  python3 "$ROOT/game/tools/lint3d/render_measure.py" "$OUT/shots" --review="$ROOT/tools/art3d/review" \
    --boards="$BOARDS" --out="$OUT/measure.json" || rc=1
fi

if has_mode set; then
  margs=()
  [ -n "$RENDER" ] && [ -f "$OUT/measure.json" ] && margs+=("--measure=$OUT/measure.json")
  godot_lint --set ${margs[@]+"${margs[@]}"} "--json=$OUT/set.json" ${PASS[@]+"${PASS[@]}"} || rc=1
  parts+=("$OUT/set.json")
fi
if has_mode screen; then
  godot_lint --screen "--aspects=${ASPECTS:-20x9,16x9,4x3}" "--json=$OUT/screen.json" ${PASS[@]+"${PASS[@]}"} || rc=1
  parts+=("$OUT/screen.json")
fi
if has_mode hud; then
  godot_lint --hud "--json=$OUT/hud.json" ${PASS[@]+"${PASS[@]}"} || rc=1
  parts+=("$OUT/hud.json")
fi
if has_mode visibility; then
  rm -rf "$OUT/cmds"; mkdir -p "$OUT/cmds"
  SANDBOX="$SB_NAME" "$ROOT/tools/scripts/solve.sh" all --route=all "--dump-cmds=$OUT/cmds" | tail -3 || true
  # `solve.sh all` plays the final Nights; Gate 0 (a draft episode) is dumped on its own
  case ",$NIGHTS," in
    *,all,*|*,g0_sneeze,*)
      SANDBOX="$SB_NAME" "$ROOT/tools/scripts/solve.sh" g0_sneeze --route=all "--dump-cmds=$OUT/cmds" | tail -1 || true ;;
  esac
  godot_lint --visibility "--cmds-dir=$OUT/cmds" "--aspects=${ASPECTS:-20x9}" "--json=$OUT/visibility.json" \
    ${PASS[@]+"${PASS[@]}"} || rc=1
  parts+=("$OUT/visibility.json")
  if [ -n "$RENDER" ] && [ -f "$OUT/visibility.json" ]; then
    # the first violation of each route in the shipped mode, at 1200×540 (ViewSandbox3D on the real sim, seeked)
    python3 - "$OUT/visibility.json" <<'EOF' > "$OUT/c8_shots.txt" || true
import json, sys
for s in json.load(open(sys.argv[1]))["visibility"]["results"].get("shots", []):
    print("\t".join([s["episode"], s["route"], s["mode"], str(s["tick"]), s["cmds"], s["aspect"]]))
EOF
    while IFS=$'\t' read -r ep route mode tick cmds aspect; do
      [ -n "$ep" ] || continue
      size="1200x540"; [ "$aspect" = "16x9" ] && size="960x540"; [ "$aspect" = "4x3" ] && size="720x540"
      NO_IMPORT=1 SHOT_SIZE="$size" "$ROOT/tools/scripts/shot.sh" res://view3d/sandbox/ViewSandbox3D.tscn \
        "$BOARDS/c8_${ep}_${route}_${mode}_${aspect}.png" 30 "$SB_NAME" -- --sim "--episode=$ep" "--cmds=$cmds" \
        "--seek=$tick" "--window=$mode" | grep -E '^\[shot\]' || true
    done < "$OUT/c8_shots.txt"
  fi
fi

if [ -n "$JSON" ] && [ "${#parts[@]}" -gt 0 ]; then
  python3 - "$JSON" "${parts[@]}" <<'EOF'
import json, sys
out = {}
for p in sys.argv[2:]:
    try:
        out.update(json.load(open(p)))
    except (OSError, ValueError) as e:
        out[p] = {"error": str(e)}
json.dump(out, open(sys.argv[1], "w"), indent=2)
print("[lint3d] json %s" % sys.argv[1])
EOF
fi
exit "$rc"
