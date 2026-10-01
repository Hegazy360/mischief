#!/usr/bin/env bash
# End-to-end driver (s2-night §4.6): runs the REAL game from res://scenes/boot/Boot.tscn under xvfb with
# game/tools/e2e.gd attached (DevShot --e2e), replaying solver routes through the NightScene or driving
# a flow with synthetic input.
#
# Usage: tools/scripts/e2e.sh <scenario> [--report=/abs.json] [--perf-log] [--strict] [--headless] [--max-s=N]
#                             [--shot-seq=/abs/dir --every=N --count=K] [--realtime] [--fixed] [-- extra godot user args]
#   --fixed     a launch-clock scenario (prologue_*) at a fixed 60 fps as well (frame strips; its launch timings mean nothing)
#   --headless  no renderer (no draw-call numbers; slice_all always runs headless)
#   --max-s=N   stop a route replay after N sim seconds (a perf sample of a long Night)
#   route scenarios: g0_sneeze prologue_{ideal,required,slow} n01_{ideal,required,slow} n02_{…}
#                    n01_caught n01_chase n01_meltdown   (N02 face_to_face* are retired: r3d-content C2)
#   flows:           retry pause_back curtain_call touch_smoke tap_accuracy cold_<episode>
#   slice_all:       every route scenario above, one fresh game process each, at a fixed 60 fps as fast as
#                    the machine allows; one JSON report per route next to --report (…/<scenario>.json)
#                    plus the summary at --report.
# Route scenarios dump their commands first with `solve.sh <ep> --route=<r> --dump-cmds=<tmp>` (s2-sim)
# and pass the file with --e2e-cmds; launch-clock scenarios (prologue_*) and the flows run in real time,
# the other route replays at --fixed-fps 60 unless --realtime. --strict makes view fallbacks (puppets, missing clips, greybox props)
# fail (the pre-gate). Exit 1 when any scenario's thresholds fail.
# Env: E2E_SANDBOX (default e2e), SHOT_SIZE (default 1200x540), E2E_TIMEOUT (seconds per process; default: the
# scenario's row below), E2E_MSAA (default off: every run passes --msaa=off to NightScene — R11: timing runs on the
# CPU box run without MSAA; draw counts are unchanged, so the perf rows use the same runs; E2E_MSAA=2 to render
# with the device default).
# Every game process runs through tools/scripts/slot.sh (R3D ruling R11); E2E_TIMEOUT starts once a slot is free.
#
# E2E_TIMEOUT table (R3D, r3d-night; MEASURED 2026-09-30 on the 4-core CPU box under llvmpipe, 1200x540, MSAA off, one
# render thread per slot, 3D view: frame 99-106 ms p50 / 142-177 ms p95 real time; Godot clamps a frame at 66.7 ms of
# game time, so real-time runs take ~1.5-2x their game length; fixed-fps replays take frames x ~100 ms; `rows` marked
# "est." were not measured in this task (slice_all measures them headless):
#   scenario            mode        game length        measured wall                    timeout (E2E_TIMEOUT default)
#   g0_sneeze           fixed 60    1414 ticks ~24 s    210 s (373 s with --shot-seq/4)  600 s
#   prologue_ideal      real time   ~60 s               134-163 s                        600 s
#   prologue_required   real time   ~70 s               152 s                            600 s
#   prologue_slow       real time   ~90 s               147 s                            700 s
#   n01_* / n02_*       fixed 60    ~140 s (8400 ticks)  est. ~14 min rendered            1800 s
#   n01_caught/chase/meltdown fixed ~40-80 s            est. ~4-8 min rendered           1200 s
#   retry               real time   ~10 s               26 s                             400 s
#   pause_back          real time   ~10 s               30 s                             400 s
#   touch_smoke         real time   ~5 s                20 s                             400 s
#   curtain_call        real time   P00+N01x2+N02+g0    115 s                            900 s
#   tap_accuracy        real time   4 Nights x rooms    73 s                             1200 s
#   slice_all           headless    every route          see the r3d-night report         per row as above
# (wall = slot wait excluded, Godot start ~10 s and a sandbox re-import when assets changed included)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCEN="${1:?scenario}"; shift
REPORT=""; PERF=""; STRICT=""; REALTIME=""; FIXED=""; HEADLESS=""; MAXS=""; SEQ=(); EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
    --report=*) REPORT="$(realpath -m "${1#--report=}")" ;;
    --perf-log) PERF="--perf-log" ;;
    --strict) STRICT="--e2e-strict" ;;
    --realtime) REALTIME=1 ;;
    --fixed) FIXED=1 ;;
    --headless) HEADLESS=1 ;;
    --max-s=*) MAXS="${1#--max-s=}" ;;
    --shot-seq=*) SEQ+=("--shot-seq=$(realpath -m "${1#--shot-seq=}")") ;;
    --every=*|--count=*|--seq-from=*) SEQ+=("$1") ;;
    --) shift; EXTRA=("$@"); break ;;
    *) EXTRA+=("$1") ;;
  esac
  shift
done
SB_NAME="${E2E_SANDBOX:-e2e}"
MSAA_ARG="--msaa=${E2E_MSAA:-off}"
BASE="${MND_SANDBOX_ROOT:-/tmp/mnd_sandbox}"
SIZE="${SHOT_SIZE:-1200x540}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mnd_e2e.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

timeout_of() {  # scenario -> the default E2E_TIMEOUT (s) of the table above
  case "$1" in
    g0_sneeze|prologue_ideal|prologue_required) echo 600 ;;
    prologue_slow) echo 700 ;;
    n01_caught|n01_chase|n01_meltdown) echo 1200 ;;
    n01_*|n02_*) echo 1800 ;;
    curtain_call) echo 900 ;;
    tap_accuracy) echo 1200 ;;
    *) echo 400 ;;
  esac
}

route_of() {  # scenario -> "episode route" (empty for flows)
  case "$1" in
    g0_sneeze) echo "g0_sneeze ideal" ;;
    prologue_*) echo "p00_curtain_up ${1#prologue_}" ;;
    n01_*) echo "n01_throat_tea ${1#n01_}" ;;
    n02_*) echo "n02_something_fishy ${1#n02_}" ;;
    *) echo "" ;;
  esac
}

"$ROOT/tools/scripts/sandbox.sh" "$SB_NAME" >/dev/null
SB="$BASE/$SB_NAME/game"

# one game process: $1 scenario, $2 report path, $3 cmds file ("" = none)
run_one() {
  local scen="$1" rep="$2" cmds="$3" fps=()
  local args=("--e2e" "--e2e-scenario=$scen" "$MSAA_ARG")
  [ -n "$rep" ] && args+=("--e2e-report=$rep")
  [ -n "$cmds" ] && args+=("--e2e-cmds=$cmds")
  [ -n "$STRICT" ] && args+=("$STRICT")
  [ -n "$PERF" ] && args+=("$PERF")
  [ -n "$MAXS" ] && args+=("--e2e-max-s=$MAXS")
  # route replays run at a fixed 60 fps (as fast as the machine allows); the launch clock (prologue_*)
  # and the flows (their wall-clock budgets: retry ≤ 1.5 s, curtain-call lengths) run in real time
  if [ -z "$REALTIME" ] && [ -n "$(route_of "$scen")" ] && [[ "$scen" != prologue_* ]]; then fps=(--fixed-fps 60); fi
  # --fixed: a launch-clock scenario at a fixed 60 fps too (frame sequences / strips; its launch timings then mean nothing)
  if [ -n "$FIXED" ] && [ -z "$REALTIME" ]; then fps=(--fixed-fps 60); fi
  if [ "${#SEQ[@]}" -gt 0 ]; then args+=("${SEQ[@]}"); fi
  if [ "${#EXTRA[@]}" -gt 0 ]; then args+=("${EXTRA[@]}"); fi
  local runner=(xvfb-run -a -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --audio-driver Dummy --resolution "$SIZE")
  [ -n "$HEADLESS" ] && runner=(godot --headless --audio-driver Dummy)
  set +e
  "$ROOT/tools/scripts/slot.sh" timeout "${E2E_TIMEOUT:-$(timeout_of "$scen")}" "${runner[@]}" ${fps[@]+"${fps[@]}"} --path "$SB" res://scenes/boot/Boot.tscn -- "${args[@]}" 2>&1 \
    | grep -vE "ALSA|libpulse|audio_driver|All audio drivers|at: (init_output_device|initialize)|V-Sync|set_use_vsync" \
    | grep -E "^\[E2E\]|ERROR|SCRIPT ERROR|at: |WARNING: .*E2E" | head -200
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

dump_cmds() {  # $1 episode $2 route -> prints the cmds file path ("" when the dump failed)
  local out="$TMP/cmds"
  mkdir -p "$out"
  SANDBOX="${SB_NAME}-shot" "$ROOT/tools/scripts/solve.sh" "$1" "--route=$2" "--dump-cmds=$out" >"$TMP/solve_$1_$2.log" 2>&1 || true
  local f="$out/${1}_${2}.cmds.json"
  [ -f "$f" ] && echo "$f" || echo ""
}

if [ "$SCEN" = "slice_all" ]; then
  HEADLESS=1   # no rendering: the replays run as fast as the sim + view scripts allow (draw calls: n0x_ideal --perf-log)
  SUM="${REPORT:-$TMP/slice_all.json}"
  DIR="$(dirname "$SUM")/slice_all"
  mkdir -p "$DIR"
  mkdir -p "$TMP/cmds"
  SANDBOX="${SB_NAME}-shot" "$ROOT/tools/scripts/solve.sh" all --route=all "--dump-cmds=$TMP/cmds" >"$TMP/solve_all.log" 2>&1 || true
  # g0_sneeze is a draft episode: `all` covers final ones only
  [ -f "$TMP/cmds/g0_sneeze_ideal.cmds.json" ] || dump_cmds g0_sneeze ideal >/dev/null
  fail=0; rows=()
  for s in g0_sneeze prologue_ideal prologue_required prologue_slow n01_ideal n01_required n01_slow n02_ideal n02_required \
      n02_slow n01_caught n01_chase n01_meltdown; do
    read -r ep rt <<< "$(route_of "$s")"
    f="$TMP/cmds/${ep}_${rt}.cmds.json"
    if [ ! -f "$f" ]; then
      echo "[E2E] SKIP $s: no route '$rt' in $ep (solve.sh wrote no command log)"
      rows+=("{\"scenario\": \"$s\", \"skipped\": true}")
      continue
    fi
    echo "[E2E] --- $s"
    REALTIME_SAVE="$REALTIME"; REALTIME=""
    if run_one "$s" "$DIR/$s.json" "$f"; then rows+=("{\"scenario\": \"$s\", \"ok\": true, \"report\": \"$DIR/$s.json\"}")
    else fail=1; rows+=("{\"scenario\": \"$s\", \"ok\": false, \"report\": \"$DIR/$s.json\"}"); fi
    REALTIME="$REALTIME_SAVE"
  done
  printf '{"scenario": "slice_all", "ok": %s, "runs": [%s]}\n' "$([ $fail = 0 ] && echo true || echo false)" \
    "$(IFS=,; echo "${rows[*]}")" > "$SUM"
  python3 - "$SUM" <<'PY' || true
import json, sys, os
s = json.load(open(sys.argv[1]))
print("[E2E] slice_all summary (%s)" % sys.argv[1])
for r in s["runs"]:
    if r.get("skipped"):
        print("  %-22s SKIP" % r["scenario"]); continue
    p = r.get("report", "")
    d = json.load(open(p)) if os.path.exists(p) else {}
    fb = d.get("fallbacks", {}) or {}
    print("  %-22s %s  view=%s end=%s errors=%s fallbacks(clip=%s puppets=%s grey=%s) doubles=%d pip_on_share=%s" % (r["scenario"],
        "PASS" if r.get("ok") else "FAIL", d.get("view"), d.get("end_reason"), d.get("script_errors"), fb.get("clip_fallbacks"),
        fb.get("puppets"), fb.get("greybox_props"), len(d.get("doubles", [])), d.get("pip_on_share")))
PY
  echo "[E2E] slice_all $([ $fail = 0 ] && echo PASS || echo FAIL)"
  exit $fail
fi

CMDS=""
RT="$(route_of "$SCEN")"
if [ -n "$RT" ]; then
  read -r ep rt <<< "$RT"
  CMDS="$(dump_cmds "$ep" "$rt")"
  if [ -z "$CMDS" ]; then
    echo "[E2E] no command log from solve.sh for $ep/$rt (see below); the driver dumps the route in-process" >&2
    tail -5 "$TMP/solve_${ep}_${rt}.log" >&2 || true
  fi
fi
run_one "$SCEN" "$REPORT" "$CMDS"
