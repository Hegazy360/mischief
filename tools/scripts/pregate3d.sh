#!/usr/bin/env bash
# R3D pre-gate (r3d-index.md §6, owner r3d-qa): runs exit rows 1–18, 19 (the readability verdicts) and 20a on the
# commit that becomes the owner APK, in sandbox `r3d-qa`, ONE Godot process at a time, with nothing else running.
# Writes build/r3d/pregate.json (one entry per row: command, pass/fail, the numbers, the wall time, the tree it ran on)
# and prints the row table. Row 20b (the CI APK after the push) is NOT here (r3d-qa brief §3.5).
#
# Usage: tools/scripts/pregate3d.sh [--rows=1,2,5-7,20a] [--no-render] [--force] [--fresh]
#   --rows=…     a subset (numbers, ranges, "20a"); default: every row. Rows not run keep their entry from an earlier
#                run in pregate.json — the table marks them "(earlier)" and a row whose input tree changed since then
#                (by content: game/** + tools/scripts, tools/ci, tools/art3d/review, tools/audio; rows 5–8 only the sim,
#                solver, data and autoload files) as STALE (= FAIL).
#   --no-render  skip the rendering rows (11, 13, 14, 16, 17, 18) and run the lint3d rows headless (--no-render) — CI.
#   --force      start although another Godot / Blender process is running (timing rows are noisy on a shared box).
#   --fresh      drop the earlier entries of pregate.json first.
# Exit 0 when every requested row passes (row 19 counts), 1 otherwise; 2 on bad usage; 3 when refused (busy box).
#
# Expected durations (measured on the 4-core CPU box, llvmpipe, 1200×540, MSAA off, one render thread per slot:
# r3d-night's e2e timing table in tools/scripts/e2e.sh, r3d-view3d P0b's real-time frame 99–106 ms p50 / 142–177 ms
# p95 — index R11 — and r3d-integrate's 2026-10-01 gate chain, frame 66–89 ms p95 after the perf passes; slot waits
# excluded). Real-time rows get E2E_TIMEOUT = 3 × the expected wall (≥ 300 s):
#   row  what                                   expected wall      E2E_TIMEOUT
#    1   import metadata                        ~5 s               —
#    2   full suite (incl. tests/slice)         ~6 min             —
#    3   lint.sh --strict                       ~40 s              —
#    4   lint_all.sh --no-godot                 ~60 s              —
#    5   solve all --route=all (+ g0)           ~2 min             —
#    6   dead-air gate (row 5's report)         0 s                —
#    7   solve --auto + g0 ideal                ~2.5 min           —
#    8   fuzz all --runs=200 (2400 runs), one process per final episode in parallel   ~1.5–2 h (N01 / N02 ~25 min a bot)
#    9   lint3d --set --all-nights              ~1 min             —
#   10   lint3d --screen (3 aspects)            ~30 s              —
#   11   lint3d --hud (rows 13–14 reports)      ~10 s              —
#   12   lint3d --visibility --routes=all       ~3 min             —
#   13   e2e g0_sneeze --strict --perf-log      ~2.5 min (fixed 60, 1414 frames × ~100 ms)    600 s
#   14   e2e prologue ideal / required / slow   ~1.5 min each (real time, ~60–90 s game)       450 / 450 / 450 s
#   15   e2e slice_all (headless, 13 routes)    ~10 min (r3d-night: 576 s)                      1800 s per route
#   16   e2e n01_ideal --perf-log (rendered) + 5 × prologue_ideal --perf-log --view3d-prof (3 rendered + 2
#        --headless, the D18.2 spike rule) + perf3d   ~15 + 5 × 1.6 min (r3d-fix-hud2: 83–102 s a run)  2700 / 450 s
#   17   RigPerf3D 5 × 2 rigs                   ~3 min (18 s each)                              SHOT_TIMEOUT 300 s
#   18   flows retry/pause_back/touch_smoke/tap_accuracy/curtain_call  ~15/20/15/50/80 s     300/300/300/400/600 s
#   19   readability verdicts (docs/review/r3d-qa/readability.md)   0 s
#   20a  export_android.sh --sandbox r3d-qa + unzip -l + the exported pack loaded headless   ~2 min
# Frame-quantised timing checks (retry, tap feedback, cue → crowd, hit-stop, the sneeze accent frame) compare against
# max(threshold, one measured frame of that run: the report's frame_ms / frame_ms_p95) and print both.
#
# Row 19 reads `verdict` lines from docs/review/r3d-qa/readability.md (one per test; medians when several reviewers):
#   verdict verb 7/8                     (≥ 7/8 named)
#   verdict spot 6/8                     (≥ 6/8 the gist of the joke)
#   verdict crowded_yes 1/8              (≤ 1/8 answered "yes, crowded")
#   verdict prefer_3d 6/8                (≥ 6/8 pairs where the 3D frame was preferred)
#   verdict gag <id> funny=4 readable=4 fresh=3   (g0 sneeze + the dizzy spin [ids containing "sneeze" / "dizzy"]:
#                                         funny and readable ≥ 4; every other gag ≥ 3; fresh ≥ 3 for all)
set -uo pipefail
# bash reads a script as it runs: run a private copy so the file can be edited while a long pre-gate is in flight
if [ -z "${PREGATE3D_COPY:-}" ]; then
  _root="$(cd "$(dirname "$0")/../.." && pwd)"
  _copy="$(mktemp "${TMPDIR:-/tmp}/pregate3d.XXXXXX")"
  cp "$0" "$_copy"
  PREGATE3D_COPY="$_copy" PREGATE3D_ROOT="$_root" exec bash "$_copy" "$@"
fi
ROOT="$PREGATE3D_ROOT"
cd "$ROOT"
# slot waits: the long rows hold a slot for a long time (fuzz) — wait up to 2 h instead of giving up after 30 min
export MND_SLOT_WAIT="${MND_SLOT_WAIT:-7200}"
SB=r3d-qa
OUT="$ROOT/build/r3d"
LOGS="$OUT/logs"
ROWS_ALL="1 2 3 4 5 6 7 9 10 12 13 14 11 15 16 17 18 20a 19 8"
ROWS_ARG=""; NO_RENDER=""; FORCE=""; FRESH=""
for a in "$@"; do
  case "$a" in
    --rows=*) ROWS_ARG="${a#--rows=}" ;;
    --no-render) NO_RENDER=1 ;;
    --force) FORCE=1 ;;
    --fresh) FRESH=1 ;;
    -h|--help) sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "pregate3d: unknown argument $a" >&2; exit 2 ;;
  esac
done

# --- the rows to run, in the dependency order of ROWS_ALL ---------------------------------------------------------
want=()
if [ -n "$ROWS_ARG" ]; then
  IFS=',' read -r -a parts <<< "$ROWS_ARG"
  for p in "${parts[@]}"; do
    if [[ "$p" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      for ((i = BASH_REMATCH[1]; i <= BASH_REMATCH[2]; i++)); do want+=("$i"); done
    elif [[ "$p" =~ ^([0-9]+|20a)$ ]]; then want+=("$p")
    else echo "pregate3d: bad --rows item '$p'" >&2; exit 2; fi
  done
fi
ROWS=()
for r in $ROWS_ALL; do
  if [ "${#want[@]}" -eq 0 ]; then ROWS+=("$r"); continue; fi
  for w in "${want[@]}"; do [ "$w" = "$r" ] && { ROWS+=("$r"); break; }; done
done
[ "${#ROWS[@]}" -gt 0 ] || { echo "pregate3d: no row selected" >&2; exit 2; }

# --- refuse a busy box (timing rows) --------------------------------------------------------------------------------
busy="$(pgrep -a -x 'godot|blender|Godot' 2>/dev/null; pgrep -a -f '^(/usr/local/bin/)?(godot|blender)( |$)' 2>/dev/null)"
if [ -n "$busy" ] && [ -z "$FORCE" ]; then
  echo "pregate3d: another Godot / Blender process is running — the timing rows would be noisy (--force to run anyway):" >&2
  echo "$busy" | sort -u | head -10 >&2
  exit 3
fi

mkdir -p "$OUT" "$LOGS" "$OUT/e2e" "$OUT/flows"
[ -n "$FRESH" ] && rm -f "$OUT/pregate.json"
export SANDBOX="$SB" E2E_SANDBOX="$SB" E2E_MSAA=off
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
# The inputs a row's verdict depends on, by content (blob ids of HEAD + the working-tree diff + untracked files), so a
# commit that only adds docs keeps every row valid: SIM_TREE for the sim-only rows (5–8), TREE for every other row.
SIM_PATHS=(game/sim game/solver game/data game/tools/fuzz.gd game/tools/solve.gd game/tools/sim_run.gd game/autoload)
FULL_PATHS=(game tools/scripts tools/ci tools/art3d/review tools/audio)
tree_hash() {
  { git ls-tree -r HEAD -- "$@" 2>/dev/null
    git diff HEAD -- "$@" 2>/dev/null
    git ls-files --others --exclude-standard -- "$@" 2>/dev/null | sort | while read -r f; do sha256sum "$f"; done
  } | sha256sum | cut -c1-16
}
SIM_TREE="$(tree_hash "${SIM_PATHS[@]}")"
TREE="$(tree_hash "${FULL_PATHS[@]}")"

EVAL="$(mktemp "${TMPDIR:-/tmp}/pregate3d_eval.XXXXXX.py")"
trap 'rm -f "$EVAL" "$PREGATE3D_COPY"' EXIT
cat > "$EVAL" <<'PY'
"""pregate3d.sh evaluator: one row's verdict from its logs / reports, merged into build/r3d/pregate.json."""
import glob, json, os, re, statistics, sys, time

ROOT, OUT, LOGS = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4]
row, rc, wall, command, head, tree, norender = sys.argv[5], int(sys.argv[6]), float(sys.argv[7]), sys.argv[8], sys.argv[9], sys.argv[10], sys.argv[11] == "1"
PJ = os.path.join(OUT, "pregate.json")
FRAME_S = 1.0 / 60.0


def load(p, default=None):
    try:
        with open(p) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def log(n):
    try:
        return open(os.path.join(LOGS, n), errors="replace").read()
    except OSError:
        return ""


fails, nums, notes = [], {}, []


def need(cond, msg):
    if not cond:
        fails.append(msg)
    return cond


def quant(value_s, thr_s, frame_s):
    return value_s <= max(thr_s, frame_s) + 0.0005


def e2e(name):
    return load(os.path.join(OUT, "e2e", name + ".json"), None)


def e2e_common(rep, label, strict_fallbacks=True):
    if not need(rep is not None, "%s: no report" % label):
        return False
    need(bool(rep.get("ok")), "%s: e2e FAIL %s" % (label, (rep.get("failures") or [])[:4]))
    need(int(rep.get("script_errors", 0)) == 0, "%s: %s script errors" % (label, rep.get("script_errors")))
    need(int(rep.get("engine_errors", 0)) == 0, "%s: %s engine errors %s" % (label, rep.get("engine_errors"), (rep.get("error_messages") or [])[:3]))
    fb = rep.get("fallbacks", {}) or {}
    nfb = int(fb.get("clip_fallbacks", 0)) + int(fb.get("puppets", 0)) + int(fb.get("greybox_props", 0))
    if strict_fallbacks:
        need(nfb == 0 and not (fb.get("by_clip") or {}), "%s: %d view fallbacks %s" % (label, nfb, fb.get("by_clip")))
    return True


if row == "1":
    need(rc == 0, "check_import_meta.sh exit %d" % rc)
    imp = uid = 0
    for d, _, fs in os.walk(os.path.join(ROOT, "game")):
        if "/.godot" in d:
            continue
        imp += sum(1 for f in fs if f.endswith(".import"))
        uid += sum(1 for f in fs if f.endswith(".uid"))
    nums.update({"import_files": imp, "uid_files": uid})

elif row == "2":
    t = log("row2.log")
    m = re.findall(r"== (OK|FAILED): (\d+) passed, (\d+) failed, (\d+) skipped, (\d+) tests in (\d+) files", t)
    need(rc == 0, "test_game.sh exit %d" % rc)
    if need(bool(m), "no suite summary line"):
        _, p, f, s, n, files = m[-1]
        nums.update({"passed": int(p), "failed": int(f), "skipped": int(s), "tests": int(n), "files": int(files)})
        need(int(f) == 0, "%s failed" % f)
    skips = re.findall(r"^\s+skip (\S+) — (.*)$", t, re.M)
    allowed = open(os.path.join(ROOT, "docs/review/r3d-qa/allowed_skips.md")).read() if os.path.exists(
        os.path.join(ROOT, "docs/review/r3d-qa/allowed_skips.md")) else None
    need(allowed is not None, "docs/review/r3d-qa/allowed_skips.md missing")
    listed = set(re.findall(r"^\|\s*`?([^|`]+?)`?\s*\|", allowed or "", re.M))
    unlisted = [s for s, _ in skips if s not in listed]
    need(not unlisted, "skips not in allowed_skips.md: %s" % unlisted[:5])
    nums["skips"] = [s for s, _ in skips]
    # the runner prints "<dir>/<file>.gd: ok (N tests, T ms)" per file; the 3D slice tests must be among them
    slice_ = re.findall(r"^(slice/test_\S+?\.gd): ok", t, re.M)
    nums["slice_files_seen"] = len(set(slice_))
    need(len(set(slice_)) >= 2, "the tests/slice files did not run (%d seen)" % len(set(slice_)))

elif row == "3":
    t = log("row3.log")
    need(rc == 0, "lint.sh --strict exit %d" % rc)
    m = re.findall(r"lint_anim 3d: (\d+) clip\(s\), (\d+) error\(s\), (\d+) warning\(s\), (\d+) missing \[strict\]", t)
    if need(bool(m), "no strict 3D anim lint line"):
        c, e, w, mi = map(int, m[-1])
        nums.update({"anim3d_strict_clips": c, "anim3d_errors": e, "anim3d_warnings": w, "anim3d_missing": mi})
        need(e == 0 and mi == 0, "3D anim lint: %d errors, %d missing" % (e, mi))
        need(c >= 72, "3D anim lint scope has %d clips (< 70 + rig_high/mid/low)" % c)
    m2 = re.findall(r"content coverage 3d: OK \((\d+) clips", t)
    need(bool(m2), "no 3D content coverage OK line")
    if m2:
        nums["coverage3d_clips"] = int(m2[-1])
    for k in ("content", "hotspot", "ip"):
        need(re.search(r"\[lint\] %s: OK" % k, t) is not None, "lint %s not OK" % k)
    m3 = re.findall(r"\[lint\] (OK|FAIL): (\d+) lint\(s\) failed, (\d+) skipped", t)
    if m3:
        nums["lints_failed"], nums["lints_skipped"] = int(m3[-1][1]), int(m3[-1][2])
        need(int(m3[-1][2]) == 0, "%s lints skipped" % m3[-1][2])

elif row == "4":
    t = log("row4.log")
    need(rc == 0 and "[lint_all] OK" in t, "lint_all.sh --no-godot exit %d" % rc)
    nums["validators"] = len(re.findall(r"^\[lint_all\] python3 ", t, re.M))

elif row in ("5", "6"):
    rep = load(os.path.join(OUT, "solve.json"), {}) or {}
    g0 = load(os.path.join(OUT, "solve_g0.json"), {}) or {}
    runs = list(rep.get("runs", [])) + list(g0.get("runs", []))
    need(bool(runs), "no solver runs (build/r3d/solve.json)")
    if row == "5":
        need(rc == 0, "solve.sh exit %d" % rc)
        per = {}
        for r in runs:
            key = "%s/%s" % (r["episode"], r["route"])
            st = sum(1 for s in r.get("stars", []) if s)
            per[key] = {"ok": r.get("ok"), "stars": st, "applause": r.get("applause"), "catches": len(r.get("catches", [])),
                        "invariants": len(r.get("invariants", []))}
            need(bool(r.get("ok")), "%s: expect FAIL %s" % (key, (r.get("fail") or [])[:3]))
            need(not r.get("invariants"), "%s: invariant violations %s" % (key, r.get("invariants")[:2] if r.get("invariants") else ""))
            if r["route"] == "ideal":
                need(len(r.get("catches", [])) == 0, "%s: %d catches on the ideal route" % (key, len(r.get("catches", []))))
            if r["episode"] in ("n01_throat_tea", "n02_something_fishy"):
                a = float(r.get("applause", 0))
                if r["route"] == "ideal":
                    need(st == 3 and 100 <= a <= 140, "%s: %d★ %.1f applause (★★★ 100–140)" % (key, st, a))
                if r["route"] == "required":
                    need(st >= 1 and 35 <= a <= 60, "%s: %d★ %.1f applause (★ 35–60)" % (key, st, a))
            if r["episode"] == "p00_curtain_up":
                need(st == 0, "%s: P00 stars %s (expected none)" % (key, r.get("stars")))
            if r["episode"] == "n02_something_fishy":
                need(not r["route"].startswith("face_to_face"), "%s: a retired face_to_face route is back" % key)
        need("g0_sneeze/ideal" in per, "no g0_sneeze ideal run")
        nums["routes"] = per
        nums["n_routes"] = len(per)
    else:
        lim = {"ideal": 20.0, "required": 25.0, "slow": 30.0}
        per = {}
        for r in runs:
            if r["route"] not in lim:
                continue
            key = "%s/%s" % (r["episode"], r["route"])
            ff = float(r.get("dead_air_ff_pct", 999))
            gap = float(r.get("max_gap_ff_s", 999))
            edge = float((r.get("beats") or {}).get("edge_share", 0.0))
            per[key] = {"dead_air_ff_pct": ff, "max_gap_ff_s": gap, "edge_share": edge,
                        "first_prank_launch_s": r.get("first_prank_launch_s")}
            need(ff <= lim[r["route"]], "%s: dead air ⏩ %.1f %% > %.0f %%" % (key, ff, lim[r["route"]]))
            need(gap <= 12.0, "%s: worst gap ⏩ %.1f s > 12 s" % (key, gap))
            need(edge <= 1.0 / 3.0 + 1e-6, "%s: edge-beat share %.2f > 1/3" % (key, edge))
            if r["episode"] == "n02_something_fishy":
                fp = r.get("first_prank_launch_s")
                need(fp is not None and float(fp) <= 25.0, "%s: first prank %s s > 25 s" % (key, fp))
        nums["routes"] = per
        nums["worst"] = {"ideal_ff": max([v["dead_air_ff_pct"] for k, v in per.items() if k.endswith("/ideal")] or [0]),
                         "required_ff": max([v["dead_air_ff_pct"] for k, v in per.items() if k.endswith("/required")] or [0]),
                         "slow_ff": max([v["dead_air_ff_pct"] for k, v in per.items() if k.endswith("/slow")] or [0]),
                         "gap_s": max([v["max_gap_ff_s"] for v in per.values()] or [0]),
                         "edge_share": max([v["edge_share"] for v in per.values()] or [0])}

elif row == "7":
    t = log("row7.log")
    need(rc == 0, "solve --auto / g0 exit %d" % rc)
    autos = re.findall(r"\[solve\] (\S+) auto (OK|FAIL): (.*)", t)
    need(len(autos) >= 3, "%d planner proofs (expected 3 episodes)" % len(autos))
    for ep, ok, rest in autos:
        need(ok == "OK", "%s planner proof FAIL: %s" % (ep, rest[:120]))
        need("soft-lock OK" in rest and "lines alone OK" in rest and "script OK" in rest,
             "%s: a planner proof missing (%s)" % (ep, rest[:120]))
    nums["auto"] = {ep: rest.split(",")[0] for ep, ok, rest in autos}
    g0 = load(os.path.join(OUT, "solve_g0_ideal.json"), {}) or {}
    gr = (g0.get("runs") or [{}])[0]
    ends = (gr.get("event_counts") or {})
    need(bool(gr.get("ok")), "g0_sneeze ideal not OK")
    end_ok = any("g0_done" in json.dumps(v) for v in (gr.get("steps") or [])) or "g0_done" in json.dumps(gr)
    need(end_ok, "g0_sneeze ideal does not end by g0_done")
    nums["g0_ideal"] = {"ok": gr.get("ok"), "duration_s": gr.get("duration_s"), "end_g0_done": end_ok}

elif row == "8":
    rep = load(os.path.join(OUT, "fuzz.json"), {}) or {}
    runs = rep.get("runs", [])
    need(rc == 0, "fuzz.sh exit %d" % rc)
    by = {}
    for r in runs:
        k = "%s/%s" % (r.get("episode"), r.get("bot"))
        d = by.setdefault(k, {"runs": 0, "ok": 0, "softlocks": 0, "invariants": 0, "catches": 0})
        d["runs"] += 1
        d["ok"] += 1 if r.get("ok") else 0
        d["softlocks"] += 0 if (r.get("softlock") or {}).get("ok", True) else 1
        d["invariants"] += len(r.get("invariants") or [])
        d["catches"] += int(r.get("catches", 0))
    nums["by_episode_bot"] = by
    nums["runs"] = len(runs)
    need(len(by) >= 12, "%d episode×bot groups (expected 3 × 4)" % len(by))
    for k, d in by.items():
        need(d["runs"] >= 200, "%s: %d runs < 200" % (k, d["runs"]))
        need(d["ok"] == d["runs"] and d["invariants"] == 0 and d["softlocks"] == 0,
             "%s: %d/%d ok, %d invariant hits, %d soft-locks" % (k, d["ok"], d["runs"], d["invariants"], d["softlocks"]))
    struck = [r for r in runs if any("struck" in json.dumps(i) for i in (r.get("invariants") or []))]
    need(not struck, "%d runs accepted a command on a struck hotspot" % len(struck))

elif row in ("9", "10", "11", "12"):
    mode = {"9": "set", "10": "screen", "11": "hud", "12": "visibility"}[row]
    rep = load(os.path.join(OUT, "lint3d_%s.json" % mode), {}) or {}
    blk = rep.get(mode, {})
    need(rc == 0, "lint3d.sh --%s exit %d" % (mode, rc))
    if need(bool(blk), "no %s block in the lint3d json" % mode):
        c = blk.get("counts", {})
        nums.update({"errors": c.get("error"), "warnings": c.get("warning"), "skips": c.get("skip"), "info": c.get("info")})
        need(int(c.get("error", 1)) == 0 and bool(blk.get("pass")), "%s lint: %s errors" % (mode, c.get("error")))
        nums["warning_list"] = ["%s %s %s %s: %s" % (i.get("night"), i.get("room"), i.get("rule"), i.get("subject"), i.get("value"))
                                for i in blk.get("issues", []) if i.get("level") == "warning"]
        if row == "12":
            res = blk.get("results", {})
            nums["shipped_mode"] = res.get("shipped_mode")
            rr = res.get("routes", [])
            nums["routes"] = len(rr)
            nums["violations_shipped"] = sum(int(r.get("violations", 0)) for r in rr if r.get("mode") == res.get("shipped_mode"))
            nums["violations_other"] = sum(int(r.get("violations", 0)) for r in rr if r.get("mode") != res.get("shipped_mode"))
            nums["window_share"] = {"%s/%s" % (r["episode"], r["route"]): r.get("window_share") for r in rr if r.get("mode") == res.get("shipped_mode")}
            need(nums["violations_shipped"] == 0, "C8: %d violations in the shipped mode" % nums["violations_shipped"])
            need(len(rr) >= 26, "C8 covered %d route×mode runs (13 routes × sim + lean)" % len(rr))
        if row == "11":
            nums["window_share_warnings"] = [w for w in nums["warning_list"] if "window_share" in w]

elif row == "13":
    rep = e2e("g0")
    if e2e_common(rep, "g0_sneeze"):
        sn = rep.get("sneeze", {}) or {}
        fr_ms = float(rep.get("frame_ms_p95", 0.0))
        nums.update({"end_reason": rep.get("end_reason"), "frame_ms_p95": fr_ms, "accent_frame": sn.get("accent_frame"),
                     "zoom_at_accent": sn.get("zoom_at_accent"), "zoom_max": sn.get("zoom_max"),
                     "hitstop_ms": int(sn.get("hitstop_us", 0)) / 1000.0, "captions": sn.get("captions"),
                     "bouffant_after": sn.get("bouffant_after"), "land_in_box": sn.get("land_in_box"),
                     "tag_flights": rep.get("tag_flights"), "c8_violations": (rep.get("c8") or {}).get("violations"),
                     "pip_on_share": rep.get("pip_on_share"), "pip_longest_s": rep.get("pip_longest_s")})
        need(rep.get("end_reason") == "g0_done", "g0 ended by %s" % rep.get("end_reason"))
        tol = max(2.0, -(-fr_ms // (1000.0 / 60.0)) + 1.0)
        need(sn.get("accent_frame") is not None and abs(float(sn["accent_frame"]) - 94) <= tol,
             "CHOO accent on clip frame %s (94 ± max(2, one frame %.0f ms) = ± %.0f)" % (sn.get("accent_frame"), fr_ms, tol))
        need(float(sn.get("zoom_max", 0)) >= 1.35, "punch-in zoom %.2f < 1.4" % float(sn.get("zoom_max", 0)))
        hs = int(sn.get("hitstop_us", 0)) / 1e6
        # 5 f = 83 ms of game time, frame-quantised: ≥ 4 f (66 ms) passes (the e2e probe's own bar)
        need(hs * 1000.0 >= 66.0, "hit-stop %.0f ms < 5 f (83 ms, quantised ≥ 66 ms; measured frame %.0f ms)" % (hs * 1000, fr_ms))
        nums["hitstop_check"] = "%.0f ms vs 5 f = 83 ms (quantised ≥ 66 ms; one measured frame %.0f ms)" % (hs * 1000, fr_ms)
        need(bool(sn.get("captions")), "no caption on the CHOO")
        need(sn.get("bouffant_after") == "flipped", "bouffant after the CHOO: %s" % sn.get("bouffant_after"))
        tf = rep.get("tag_flights") or {}
        need(int(tf.get("arrived", 0)) >= 1, "the tag never reached the Script pip (%s)" % tf)
        st = rep.get("stalls_rise") if "stalls_rise" in rep else None
        if st is not None:
            nums["stalls_rise"] = st
        cc = e2e("g0_curtain") or None
        pf = rep.get("perf3d") or {}
        nums["perf3d"] = {k: pf.get(k) for k in ("draw_calls_p95", "draw_calls_max", "tris_max", "emitters_max", "tex_mb_max",
                                                 "shader_compiles_play", "view_ms_p50", "view_ms_p95", "frame_ms_p95")}
        fl = load(os.path.join(OUT, "flows", "curtain_call.json"), None)
        if fl is not None:
            g = (fl.get("flow") or {})
            nums["g0_again_ms"] = g.get("g0_again_ms")
            need(bool(g.get("g0_buttons_live", False)), "g0 curtain call: Again ▶ not live")
        else:
            notes.append("curtain call with Again ▶ is checked by row 18 (flows/curtain_call.json) — run row 18 too")

elif row == "14":
    lim_fr = []
    for name in ("p00_ideal", "p00_required", "p00_slow"):
        rep = e2e(name)
        if name == "p00_required" and rep is None:
            notes.append("p00_required not run (info only)")
            continue
        if not e2e_common(rep, name):
            continue
        fr_s = float(rep.get("frame_ms_p95", 0.0)) / 1000.0
        cues = rep.get("laugh_cues", []) or []
        bad = [c for c in cues if not c.get("staged") or not quant(float(c.get("crowd_s", 99)), 0.3, fr_s)]
        d = {"end_reason": rep.get("end_reason"), "laughs_by_60": rep.get("laughs_by_60"), "laughs": rep.get("laughs"),
             "cues": len(cues), "cue_crowd_s_max": max([float(c.get("crowd_s", 0)) for c in cues] or [0]),
             "frame_ms_p95": rep.get("frame_ms_p95"), "doubles": len(rep.get("doubles", []) or []),
             "first_player_laugh_s": rep.get("first_player_laugh_s"), "first_prank_s": rep.get("first_prank_s"),
             "first_player_laugh_ms_proxy_launch": rep.get("first_player_laugh_ms"), "first_prank_ms_proxy_launch": rep.get("first_prank_ms"),
             "pip_on_share": rep.get("pip_on_share"), "pip_longest_s": rep.get("pip_longest_s"),
             "c8_violations": (rep.get("c8") or {}).get("violations")}
        nums[name] = d
        need(rep.get("end_reason") == "prologue_done", "%s ended by %s" % (name, rep.get("end_reason")))
        need(len(rep.get("doubles", []) or []) == 0, "%s: %d sound ids twice within 100 ms" % (name, len(rep.get("doubles", []))))
        if name in ("p00_ideal",):
            need(int(rep.get("laughs_by_60", 0)) >= 6, "%s: %s laughs by 60 s < 6" % (name, rep.get("laughs_by_60")))
            need(len(cues) >= 1, "%s: no laugh_* director cue recorded" % name)
            need(not bad, "%s: cues unstaged / crowd late (> max(0.3 s, frame %.0f ms)): %s" % (name, fr_s * 1000, [c.get("id") for c in bad]))
            d["cue_check"] = "crowd ≤ max(0.30 s, one frame %.3f s): worst %.3f s" % (fr_s, d["cue_crowd_s_max"])
        if name == "p00_slow":
            # launch-relative = from tick 0 + the device launch budget (2.3 s: the e2e thresholds 7.7 / 27.7 s from tick 0);
            # the proxy's own launch (boot + curtain on llvmpipe) is printed as info
            fl = float(rep.get("first_player_laugh_s", 99)) + 2.3
            fp = float(rep.get("first_prank_s", 99)) + 2.3
            d["first_laugh_launch_s"], d["first_prank_launch_s"] = round(fl, 2), round(fp, 2)
            need(fl <= 10.0 + 0.0005, "p00_slow: first player laugh %.2f s launch-relative > 10 s" % fl)
            need(fp <= 30.0 + 0.0005, "p00_slow: first prank %.2f s launch-relative > 30 s" % fp)
    nums["prologue_ideal_strict"] = bool((e2e("p00_ideal") or {}).get("strict"))

elif row == "15":
    s = load(os.path.join(OUT, "e2e", "slice_all.json"), None)
    need(rc == 0, "slice_all exit %d" % rc)
    if need(s is not None, "no slice_all summary"):
        per = {}
        for r in s.get("runs", []):
            sc = r.get("scenario")
            if r.get("skipped"):
                per[sc] = "SKIP"
                fails.append("%s skipped" % sc)
                continue
            d = load(r.get("report", ""), {}) or {}
            fb = d.get("fallbacks", {}) or {}
            nfb = int(fb.get("clip_fallbacks", 0)) + int(fb.get("puppets", 0)) + int(fb.get("greybox_props", 0))
            per[sc] = {"ok": r.get("ok"), "end": d.get("end_reason"), "errors": d.get("script_errors"), "engine_errors": d.get("engine_errors"),
                       "fallbacks": nfb, "doubles": len(d.get("doubles", []) or []), "pip_on_share": d.get("pip_on_share")}
            need(bool(r.get("ok")), "%s FAIL %s" % (sc, (d.get("failures") or [])[:3]))
            need(int(d.get("script_errors", 0)) == 0 and int(d.get("engine_errors", 0)) == 0, "%s: errors" % sc)
            if sc.startswith("g0") or sc.startswith("prologue"):
                need(nfb == 0, "%s: %d fallbacks" % (sc, nfb))
        nums["runs"] = per
        need(len(per) >= 13, "%d of 13 slice routes" % len(per))

elif row == "16":
    p = load(os.path.join(OUT, "perf3d.json"), {}) or {}
    t = log("row16_perf3d.log")
    rows_ = re.findall(r"^\| (\S+) \| (PASS|FAIL|SKIP) \| ([^\n]*)\|$", t, re.M)
    nums["table"] = {r[0]: r[1] + " | " + r[2].strip() for r in rows_ if r[0] != "report"}
    reps = {}
    for f in sorted(glob.glob(os.path.join(OUT, "e2e", "*.json"))):
        d = load(f, {}) or {}
        pf = d.get("perf3d")
        if isinstance(pf, dict) and pf.get("frames"):
            reps[os.path.basename(f)[:-5]] = pf
    need({"g0", "p00_ideal"} <= set(reps), "perf-log reports missing (have %s)" % sorted(reps))
    need(any(k.startswith("n01") for k in reps), "no N01 perf-log report (§3.4)")
    per = {}
    for k, pf in reps.items():
        v = {x: pf.get(x) for x in ("draw_calls_p95", "draw_calls_max", "tris_max", "emitters_max", "tex_mb_max",
                                    "shader_compiles_play", "view_ms_p50", "view_ms_p95", "frame_ms_p95", "hitches")}
        per[k] = v
        need(float(v["draw_calls_p95"] or 999) <= 150 and float(v["draw_calls_max"] or 999) <= 250,
             "%s: draw calls p95 %s / max %s" % (k, v["draw_calls_p95"], v["draw_calls_max"]))
        need(float(v["tris_max"] or 1e9) <= 150000, "%s: triangles %s > 150k" % (k, v["tris_max"]))
        need(int(v["emitters_max"] or 99) <= 8, "%s: emitters %s > 8" % (k, v["emitters_max"]))
        need(float(v["tex_mb_max"] or 999) <= 250, "%s: texture %s MB > 250" % (k, v["tex_mb_max"]))
        need(int(v["shader_compiles_play"] if v["shader_compiles_play"] is not None else 99) == 0,
             "%s: %s shader compiles during PLAY" % (k, v["shader_compiles_play"]))
        # D14 (lead ruling): on the CPU proxy the view + HUD row is p50 ≤ 3.5 ms AND p95 ≤ 8.0 ms; ≤ 4.0 p95 is judged on device
        need(float(v["view_ms_p50"] or 99) <= 3.5 and float(v["view_ms_p95"] or 99) <= 8.0,
             "%s: view + HUD p50 %s / p95 %s ms (D14: ≤ 3.5 / ≤ 8.0)" % (k, v["view_ms_p50"], v["view_ms_p95"]))
        v["device_target_4ms_p95"] = "met" if float(v["view_ms_p95"] or 99) <= 4.0 else "device-judged (D14)"
    nums["reports"] = per
    # D18.2 (lead 17:15Z, refines D17, which replaced D14's spike sentence): a spike counts against us only if
    # DETERMINISTIC — the same call site > 1 ms at the same tick (±2 f) in 3 of 3 rendered runs, OR in both headless runs
    # (dummy renderer), OR in a rendered AND a headless run. Others are noise (listed). D17's "≥ 2 of 3 rendered runs"
    # matched at chance level on this box, so it is kept as info only (info_d17_rendered_2of3).
    # Call sites = the profiler leaves row 16 always read (our nodes; WorldView3D's phases; "other" excluded).
    # "Same tick (±2 f)": a profiler frame simulated ticks (t[f-1], t[f]] (e2e prof_frame_ticks); two frames match when
    # those spans, widened by 2 ticks, overlap. A headless hit counts when the same site repeats at the same tick in
    # another run (the other headless run or a rendered one); headless one-offs are listed (box preemption also hits
    # headless runs: r3d-fix-hud) with the evidence. Info for the lead: the fixers' looser window (±2 PROFILER frames),
    # a chance baseline (the same matching with the other runs shifted ±120 ticks) and NightScene's own phase split.
    THR_MS, SLACK = 1.0, 2

    def _leaves(split):
        out = {}
        for k, v in split.items():
            if k == "wv" and isinstance(v, dict):
                for kk, vv in v.items():
                    out["WorldView3D." + kk] = float(vv)
            elif k not in ("WorldView3D", "other"):
                out[k] = float(v)
        return out

    def _events(pr, rp):
        ticks = (rp or {}).get("prof_frame_ticks") or []
        n = len(ticks)
        ev = []
        for sp in (pr or {}).get("spikes") or []:
            if not (isinstance(sp, list) and len(sp) >= 3 and isinstance(sp[2], dict)):
                continue
            f = int(sp[1])
            if not (0 <= f < n) or ticks[f] < 0:
                continue
            t = int(ticks[f])
            prev = int(ticks[f - 1]) if f > 0 and ticks[f - 1] >= 0 else t - 1
            lo2 = int(ticks[max(0, f - 2)]) if ticks[max(0, f - 2)] >= 0 else t
            lv = _leaves(sp[2])
            over = [c for c, ms in lv.items() if ms > THR_MS]
            for c in over:
                ev.append({"site": c, "ms": round(lv[c], 2), "tick": t, "span": (prev + 1 - SLACK, t + SLACK),
                           "win2": (lo2, int(ticks[min(n - 1, f + 2)])), "frame_ms": round(float(sp[0]), 2),
                           "sites_over_in_frame": len(over)})
        return ev

    def _near(a, b, mode="span", shift=0):
        if mode == "span":
            return a["span"][0] <= b["span"][1] + shift and b["span"][0] + shift <= a["span"][1]
        bt = b["tick"] + shift
        return (a["win2"][0] <= bt <= a["win2"][1]) or (b["win2"][0] + shift <= a["tick"] <= b["win2"][1] + shift)

    def _clusters(R, mode="span", shift=0, min_runs=2):
        out, first = [], (R[0][0] if R else None)
        for site in sorted({e["site"] for _, ev in R for e in ev}):
            evs = [(t, e) for t, ev in R for e in ev if e["site"] == site]
            used = set()
            for i, (ta, ea) in enumerate(evs):
                if i in used:
                    continue
                grp = [(ta, ea)]
                used.add(i)
                for j, (tb, eb) in enumerate(evs):
                    if j in used or tb in [g[0] for g in grp]:
                        continue
                    shf = lambda tx: 0 if tx == first else shift
                    if any(_near(g[1], eb, mode, shf(tb) - shf(g[0])) for g in grp):
                        grp.append((tb, eb))
                        used.add(j)
                if len({g[0] for g in grp}) >= min_runs:
                    out.append({"site": site, "ticks": sorted(g[1]["tick"] for g in grp), "runs": {g[0]: g[1]["ms"] for g in grp}})
        return out

    runs = []
    for tag in ("r1", "r2", "r3", "h1", "h2"):
        pr = load(os.path.join(OUT, "prof", "p00_%s.prof.json" % tag), None)
        rp = load(os.path.join(OUT, "prof", "p00_%s.e2e.json" % tag), None)
        if pr is not None and rp is not None:
            runs.append((tag, tag.startswith("h"), pr, rp))
    R = [(tg, _events(pr, rp)) for tg, h, pr, rp in runs if not h]
    H = [(tg, _events(pr, rp)) for tg, h, pr, rp in runs if h]
    need(len(R) == 3, "D18.2 needs 3 rendered --view3d-prof runs of prologue_ideal (have %d)" % len(R))
    need(len(H) == 2, "D18.2 needs 2 headless --view3d-prof runs of prologue_ideal (have %d)" % len(H))
    for tg, h, pr, rp in runs:
        need(bool((rp or {}).get("prof_frame_ticks")), "p00_%s: no prof_frame_ticks in the e2e report" % tg)
        need(bool((pr or {}).get("spikes")), "p00_%s: the profiler JSON has no 'spikes'" % tg)
    det = _clusters(R, "span", 0, 3)          # D18.2: 3 of 3 rendered runs
    d17_2of3 = _clusters(R, "span")           # info: D17's ≥ 2 of 3 (chance level on this box)
    hl_lit, hl_det = [], []
    for th, ev in H:
        for e in ev:
            rep_ = [(t2, e2["tick"], e2["ms"]) for t2, ev2 in R + H if t2 != th for e2 in ev2
                    if e2["site"] == e["site"] and _near(e, e2, "span")]
            row_ = {"run": th, "site": e["site"], "tick": e["tick"], "ms": e["ms"], "frame_ms": e["frame_ms"],
                    "sites_over_in_frame": e["sites_over_in_frame"]}
            hl_lit.append(row_)
            if rep_:
                hl_det.append(dict(row_, repeats=rep_[:4]))
    np_ev = {}
    for c in d17_2of3:  # NightScene phase evidence for every 2-of-3 cluster (a superset of the 3-of-3 set)
        if c["site"] != "NightScene":
            continue
        ph = []
        for tg, h, pr, rp in runs:
            if tg not in c["runs"]:
                continue
            for fr in (rp or {}).get("night_phase_frames") or []:
                if isinstance(fr, list) and len(fr) >= 3 and fr[2] and min(c["ticks"]) - 6 <= int(fr[1]) <= max(c["ticks"]) + 6:
                    k = max(fr[2], key=lambda x: fr[2][x])
                    ph.append("%s@t%s %s %.2f" % (tg, fr[1], k, fr[2][k]))
        np_ev["t%d-%d" % (min(c["ticks"]), max(c["ticks"]))] = ph[:6]
    per_run = {}
    for tg, h, pr, rp in runs:
        mx = {}
        for e in _events(pr, rp):
            mx[e["site"]] = max(mx.get(e["site"], 0.0), e["ms"])
        pf = (rp or {}).get("perf3d") or {}
        per_run[tg] = {"headless": h, "ok": (rp or {}).get("ok"), "frames": pr.get("frames"), "total": pr.get("total"),
                      "view_ms_p50": pf.get("view_ms_p50"), "view_ms_p95": pf.get("view_ms_p95"),
                      "sites_over_1ms": dict(sorted(((k, round(v, 2)) for k, v in mx.items()), key=lambda x: -x[1])[:8])}
        if pf.get("view_ms_p50") is not None:
            need(float(pf["view_ms_p50"]) <= 3.5 and float(pf["view_ms_p95"]) <= 8.0,
                 "p00_%s: view + HUD p50 %s / p95 %s ms (≤ 3.5 / ≤ 8.0)" % (tg, pf["view_ms_p50"], pf["view_ms_p95"]))
    def _hl_repeats(shift):  # info: the headless rule's chance baseline (the other runs shifted by `shift` ticks)
        n = 0
        for th, ev in H:
            for e in ev:
                if any(e2["site"] == e["site"] and _near(e, e2, "span", shift) for t2, ev2 in R + H if t2 != th for e2 in ev2):
                    n += 1
        return n

    hl_det_both = [c for c in hl_det if any(r[0].startswith("h") for r in c["repeats"])]
    hl_det_rend = [c for c in hl_det if any(not r[0].startswith("h") for r in c["repeats"])]
    nums["d18"] = {"rule": "D18.2: > 1 ms at the same tick (±2 f) in 3/3 rendered runs, or in both headless runs, "
                           "or in a rendered and a headless run",
                   "deterministic_rendered_3of3": det, "deterministic_headless": hl_det,
                   "deterministic_headless_both": len(hl_det_both), "deterministic_headless_and_rendered": len(hl_det_rend),
                   "headless_literal_count": len(hl_lit), "headless_literal": hl_lit[:40],
                   "info_d17_rendered_2of3": len(d17_2of3),
                   "info_d17_rendered_2of3_sites": ["%s t%s %s" % (c["site"], c["ticks"][0], c["runs"]) for c in d17_2of3[:20]],
                   "info_clusters_pm2_profiler_frames": len(_clusters(R, "win2")),
                   "info_chance_baseline_3of3_shift_m120_p120": [len(_clusters(R, "span", -120, 3)), len(_clusters(R, "span", 120, 3))],
                   "info_chance_baseline_2of3_shift_m120_p120": [len(_clusters(R, "span", -120)), len(_clusters(R, "span", 120))],
                   "info_chance_baseline_headless_shift_m120_p120": [_hl_repeats(-120), _hl_repeats(120)],
                   "nightscene_phase_evidence": np_ev, "runs": per_run}
    nums["d18_deterministic"] = len(det) + len(hl_det)
    nums["d18_chance_baseline"] = "3/3: %s at ±120 ticks vs %d at 0; headless repeats: %s at ±120 vs %d at 0; info D17 2/3: %s at ±120 vs %d at 0" % (
        nums["d18"]["info_chance_baseline_3of3_shift_m120_p120"], len(det),
        nums["d18"]["info_chance_baseline_headless_shift_m120_p120"], len(hl_det),
        nums["d18"]["info_chance_baseline_2of3_shift_m120_p120"], len(d17_2of3))
    need(not det, "D18.2: %d call sites > 1 ms at the same tick in 3 of 3 rendered runs: %s"
         % (len(det), ["%s t%s %s" % (c["site"], c["ticks"][0], c["runs"]) for c in det[:6]]))
    need(not hl_det, "D18.2: %d headless hits > 1 ms repeated at the same tick in the other headless run or a rendered run: %s"
         % (len(hl_det), ["%s %s t%s %.2f %s" % (c["run"], c["site"], c["tick"], c["ms"], c["repeats"][:2]) for c in hl_det[:6]]))
    pj_rc = re.search(r"\[lint3d\] perf: (OK|FAIL) — (\d+) error", t)
    nums["perf3d_tool"] = pj_rc.group(0) if pj_rc else "?"

elif row == "17":
    out = {}
    for rig in ("hush", "bellows"):
        vals = []
        for n in range(1, 6):
            t = log("row17_%s_%d.log" % (rig, n))
            m = re.findall(r"^\[rigperf3d\] (\{.*\})$", t, re.M)
            if m:
                vals.append(json.loads(m[-1]))
        if not need(len(vals) == 5, "%s: %d of 5 RigPerf3D runs" % (rig, len(vals))):
            continue
        cpu = statistics.median(float(v.get("cpu_us_with_skin_median", v.get("cpu_us_median", 9e9))) for v in vals) / 1000.0
        d = {"cpu_ms_median": round(cpu, 3), "cpu_runs_us": [v.get("cpu_us_with_skin_median") for v in vals],
             "draw_calls": statistics.median(int(v.get("draw_calls", 99)) for v in vals),
             "tris": statistics.median(int(v.get("tris", 1e9)) for v in vals),
             "deform_bones": statistics.median(int(v.get("deform_bones", 99)) for v in vals),
             "set_piece_draw_calls": max(int(v.get("set_piece_draw_calls", 0)) for v in vals),
             "set_piece_tris": max(int(v.get("set_piece_tris", 0)) for v in vals), "clip": vals[0].get("clip")}
        out[rig] = d
        need(cpu <= 0.25, "%s: CPU %.3f ms > 0.25" % (rig, cpu))
        need(d["draw_calls"] <= 4, "%s: %s draw calls > 4" % (rig, d["draw_calls"]))
        need(d["tris"] <= 10000, "%s: %s triangles > 10k" % (rig, d["tris"]))
        need(d["deform_bones"] <= 50, "%s: %s deform bones > 50" % (rig, d["deform_bones"]))
    nums.update(out)

elif row == "18":
    fl = {n: load(os.path.join(OUT, "flows", n + ".json"), None) for n in ("retry", "pause_back", "touch_smoke", "tap_accuracy", "curtain_call")}
    for n, d in fl.items():
        if need(d is not None, "%s: no report" % n):
            need(bool(d.get("ok")), "%s: FAIL %s" % (n, (d.get("failures") or [])[:3]))
            need(int(d.get("script_errors", 0)) == 0, "%s: script errors" % n)
    r = (fl["retry"] or {}).get("flow", {})
    if r:
        fr = float(r.get("frame_ms", 0))
        need(float(r.get("retry_ms", 99999)) <= max(1500.0, fr) + 0.5, "retry %s ms > max(1500, frame %.0f ms)" % (r.get("retry_ms"), fr))
        nums["retry"] = "%s ms (wall %s ms) vs max(1500, one frame %.0f ms)" % (r.get("retry_ms"), r.get("retry_wall_ms"), fr)
    t = (fl["touch_smoke"] or {}).get("flow", {})
    if t:
        need(int(t.get("tap_feedback", 99)) <= 1, "tap feedback %s frames > 1" % t.get("tap_feedback"))
        nums["tap_feedback_frames"] = t.get("tap_feedback")
        nums["touch_commands"] = t.get("commands")
    p = (fl["pause_back"] or {}).get("flow", {})
    if p:
        nums["pause_back"] = p
        need(all(bool(v) for v in p.values()), "pause_back: %s" % [k for k, v in p.items() if not v])
    ta = (fl["tap_accuracy"] or {}).get("flow", {})
    if ta:
        tb = ta.get("table", [])
        sl = [x for x in tb if x.get("episode") in ("p00_curtain_up", "g0_sneeze")]
        low = [x["id"] for x in sl if int(x.get("hits", 0)) < 19 or int(x.get("neighbour", 0)) > 0]
        nums["tap_accuracy"] = {"hotspots": len(tb), "slice_hotspots": len(sl), "min_hits": min([int(x.get("hits", 0)) for x in sl] or [0]),
                                "neighbour_hits": sum(int(x.get("neighbour", 0)) for x in sl), "frame_ms": ta.get("frame_ms")}
        need(bool(sl) and not low, "tap_accuracy below 19/20 or a neighbour hit: %s" % low)
    c = (fl["curtain_call"] or {}).get("flow", {})
    if c:
        nums["curtain_call"] = {k: c.get(k) for k in ("g0_again_ms", "g0_buttons_live", "next_to_n02", "frame_ms")}
        nums["curtain_call"]["p00"] = c.get("p00")
        need(bool(c.get("g0_buttons_live")), "g0 → Again ▶ not live")
        need(bool((c.get("p00") or {}).get("done")), "P00 curtain call not done")
        need(bool((c.get("p00") or {}).get("next_live_frame1")), "P00 → Next ▶ not live on frame 1")

elif row == "19":
    p = os.path.join(ROOT, "docs/review/r3d-qa/readability.md")
    if need(os.path.exists(p), "docs/review/r3d-qa/readability.md missing (the reviewer run is pending)"):
        t = open(p).read()
        v = {}
        for m in re.finditer(r"^verdict (verb|spot|crowded_yes|prefer_3d) (\d+)/(\d+)\s*$", t, re.M):
            v[m.group(1)] = (int(m.group(2)), int(m.group(3)))
        gags = {}
        for m in re.finditer(r"^verdict gag (\S+) funny=([\d.]+) readable=([\d.]+) fresh=([\d.]+)\s*$", t, re.M):
            gags[m.group(1)] = (float(m.group(2)), float(m.group(3)), float(m.group(4)))
        nums["tests"] = {k: "%d/%d" % x for k, x in v.items()}
        nums["gags"] = {k: "funny %g readable %g fresh %g" % x for k, x in gags.items()}
        for k, (lo, need_n) in {"verb": (">=", 7), "spot": (">=", 6), "crowded_yes": ("<=", 1), "prefer_3d": (">=", 6)}.items():
            if need(k in v, "no '%s' verdict" % k):
                a, n = v[k]
                need(n == 8, "%s: %d items (expected 8)" % (k, n))
                need(a >= need_n if lo == ">=" else a <= need_n, "%s %d/8 (bar %s %d)" % (k, a, lo, need_n))
        need(any("sneeze" in g for g in gags) and any("dizzy" in g for g in gags), "the sneeze / dizzy-spin gag verdicts are missing")
        need(len(gags) >= 3, "%d gag verdicts" % len(gags))
        for g, (fu, rd, fr) in gags.items():
            bar = 4 if ("sneeze" in g or "dizzy" in g) else 3
            need(fu >= bar and rd >= bar, "gag %s: funny %g readable %g (bar %d)" % (g, fu, rd, bar))
            need(fr >= 3, "gag %s: fresh %g < 3" % (g, fr))

elif row == "20a":
    apk = os.path.join(OUT, "mischief-debug.apk")
    lst = log("row20a_unzip.log")
    need(rc == 0, "export_android.sh exit %d" % rc)
    if need(os.path.exists(apk), "no APK at build/r3d/mischief-debug.apk"):
        size = os.path.getsize(apk)
        nums["size_bytes"] = size
        nums["size_mb"] = round(size / 1e6, 2)
        nums["sha256"] = open(os.path.join(LOGS, "row20a_sha256.txt")).read().split()[0] if os.path.exists(os.path.join(LOGS, "row20a_sha256.txt")) else "?"
        need(size <= 150 * 1000 * 1000, "APK %.1f MB > 150 MB" % (size / 1e6))
        names = [l.split()[-1] for l in lst.splitlines() if re.match(r"^\s*\d+\s+\d{4}-\d\d-\d\d", l)]
        nums["entries"] = len(names)
        a = [n[7:] for n in names if n.startswith("assets/")]
        for pre in ("art3d/", "data/rigs3d/", "data/anim/hush3d/", "data/anim/bellows3d/", "art3d/anim/hush/", "art3d/anim/bellows/"):
            need(any(x.startswith(pre) for x in a), "APK: nothing under %s" % pre)
        res = [x for x in a if x.startswith("art3d/anim/") and (x.endswith(".res") or x.endswith(".res.remap") or x.endswith(".import"))]
        imported_res = [n for n in names if "/.godot/" in n and n.endswith(".res")]
        nums["clip_res_entries"] = len(res)
        need(len(res) >= 70, "APK: %d art3d/anim .res entries (< 70 slice clips)" % len(res))
        sidecars = [x for x in a if re.match(r"data/anim/(hush|bellows)3d/.*\.json$", x)]
        nums["clip_sidecars"] = len(sidecars)
        need(len(sidecars) >= 70, "APK: %d 3D clip sidecars (< 70)" % len(sidecars))
        bad = {}
        for pre in ("tests/", "tools/", "scenes/dev/", "view3d/sandbox/", "view3d/probe/", "ui/demo/"):
            hits = [x for x in a if x.startswith(pre)]
            if hits:
                bad[pre] = hits[:3]
        src = [x for x in a if "/_src/" in "/" + x]
        if src:
            bad["_src/"] = src[:3]
        need(not bad, "APK carries excluded paths: %s" % bad)
        bc = load(os.path.join(LOGS, "row20a_boot_config.json"), None)
        if need(isinstance(bc, dict), "APK: boot_config.json unreadable"):
            nums["boot_config"] = bc
            need(bc.get("start") == "stage_door" and bc.get("view") == "3d" and bc.get("show_previews") is False,
                 "boot_config start/view/show_previews = %s/%s/%s" % (bc.get("start"), bc.get("view"), bc.get("show_previews")))
            need(bc.get("bellows_window") == "sim", "bellows_window %s (K3 decision: sim)" % bc.get("bellows_window"))
            need(bc.get("render") == {"msaa_3d": True, "render_scale": 1.0, "outline": True},
                 "render %s (K3: BootConfig.DEFAULTS unchanged, no O2 answer)" % bc.get("render"))
        v = log("row20a.log")
        m = re.search(r"permissions\s+(.*)", v)
        nums["permissions"] = m.group(1).strip() if m else "?"
        need(m is not None and m.group(1).split() == ["android.permission.VIBRATE"], "permissions: %s" % nums["permissions"])
        need("verify_android: OK" in v, "verify_android not OK")
        m = re.search(r"sdk\s+min=(\d+)", v)
        nums["min_sdk"] = int(m.group(1)) if m else None
        need(m is not None and int(m.group(1)) == 24, "minSdk %s (Android 7 = 24)" % nums["min_sdk"])
        m = re.search(r"orientation\s+(\d+)", v)
        nums["orientation"] = m.group(1) if m else None
        pr = log("row20a_probe.log")
        ms = re.search(r"\[apkprobe\] scripts (\d+), failed to load (\d+) (.*)", pr)
        mn = re.search(r"\[apkprobe\] night (OK|FAIL)(.*)", pr)
        perr = [l.strip() for l in pr.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Could not (find|resolve)", l)]
        nums["exported_scripts"] = int(ms.group(1)) if ms else None
        nums["exported_script_failures"] = (int(ms.group(2)), ms.group(3)) if ms else None
        nums["exported_night"] = (mn.group(1) + mn.group(2)).strip() if mn else None
        nums["exported_script_errors"] = perr[:8]
        need(ms is not None and int(ms.group(2)) == 0, "the exported pack: scripts that fail to load %s" % (ms.group(3) if ms else "(no probe output)"))
        need(not perr, "the exported pack: %d script / parse errors, first %s" % (len(perr), perr[:3]))
        need(mn is not None and mn.group(1) == "OK", "the exported pack does not build a 3D Night: %s" % (mn.group(0) if mn else "(no probe output)"))

else:
    fails.append("unknown row %s" % row)

entry = {"row": row, "command": command, "pass": not fails, "rc": rc, "wall_s": round(wall, 1), "numbers": nums,
         "failures": fails, "notes": notes, "head": head, "tree": tree, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
         "no_render": norender}
pj = load(PJ, {}) or {}
pj.setdefault("rows", {})[row] = entry
pj["generated_by"] = "tools/scripts/pregate3d.sh"
json.dump(pj, open(PJ, "w"), indent=1, sort_keys=False, ensure_ascii=False)
print("[pregate3d] row %-3s %s  (%.0f s)%s" % (row, "PASS" if not fails else "FAIL", wall, "" if not fails else "  " + "; ".join(fails[:4])))
for n in notes:
    print("[pregate3d]   note: %s" % n)
PY

# --- row runner ------------------------------------------------------------------------------------------------------
declare -A CMD_OF
tree_of() { case "$1" in 5|6|7|8) echo "$SIM_TREE" ;; *) echo "$TREE" ;; esac; }
evaluate() {  # row rc wall
  python3 "$EVAL" "$ROOT" "$OUT" "$LOGS" eval "$1" "$2" "$3" "${CMD_OF[$1]:-}" "$HEAD_SHA" "$(tree_of "$1")" "${NO_RENDER:-0}"
}
run() {  # row log cmd… — appends to the row's log, returns the command's rc
  local row="$1" lg="$2"; shift 2
  echo "\$ $*" >> "$LOGS/$lg"
  "$@" >> "$LOGS/$lg" 2>&1
}
skip_row() {  # row why
  python3 - "$OUT/pregate.json" "$1" "$2" "$HEAD_SHA" "$(tree_of "$1")" <<'PY'
import json, os, sys, time
pj_path, row, why, head, tree = sys.argv[1:6]
pj = json.load(open(pj_path)) if os.path.exists(pj_path) else {}
pj.setdefault("rows", {})[row] = {"row": row, "pass": None, "skipped": why, "head": head, "tree": tree,
                                  "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
pj["generated_by"] = "tools/scripts/pregate3d.sh"
json.dump(pj, open(pj_path, "w"), indent=1, ensure_ascii=False)
print("[pregate3d] row %-3s SKIP  (%s)" % (row, why))
PY
}

do_row() {
  local row="$1" t0 rc=0
  t0=$(date +%s)
  rm -f "$LOGS/row${row}"*.log
  case "$row" in
    1) CMD_OF[1]="tools/ci/check_import_meta.sh"
       run 1 row1.log tools/ci/check_import_meta.sh || rc=$? ;;
    2) CMD_OF[2]="tools/scripts/test_game.sh r3d-qa"
       run 2 row2.log tools/scripts/test_game.sh "$SB" || rc=$? ;;
    3) CMD_OF[3]="SANDBOX=r3d-qa tools/scripts/lint.sh --strict"
       run 3 row3.log tools/scripts/lint.sh --strict || rc=$? ;;
    4) CMD_OF[4]="tools/ci/lint_all.sh --no-godot"
       run 4 row4.log tools/ci/lint_all.sh --no-godot || rc=$? ;;
    5) CMD_OF[5]="SANDBOX=r3d-qa tools/scripts/solve.sh all --route=all --report=\$PWD/build/r3d/solve.json --timeline=\$PWD/build/r3d/tl (+ g0_sneeze --route=all --report=build/r3d/solve_g0.json)"
       rm -rf "$OUT/tl"
       run 5 row5.log tools/scripts/solve.sh all --route=all "--report=$OUT/solve.json" "--timeline=$OUT/tl" || rc=$?
       run 5 row5.log tools/scripts/solve.sh g0_sneeze --route=all "--report=$OUT/solve_g0.json" || rc=$? ;;
    6) CMD_OF[6]="(row 5's build/r3d/solve.json)"
       [ -f "$OUT/solve.json" ] || { echo "row 6 needs row 5's report: running row 5"; do_row 5; } ;;
    7) CMD_OF[7]="SANDBOX=r3d-qa tools/scripts/solve.sh all --auto && SANDBOX=r3d-qa tools/scripts/solve.sh g0_sneeze --route=ideal"
       run 7 row7.log tools/scripts/solve.sh all --auto || rc=$?
       run 7 row7.log tools/scripts/solve.sh g0_sneeze --route=ideal "--report=$OUT/solve_g0_ideal.json" || rc=$? ;;
    8) # = `fuzz.sh all --runs=200`, split per final episode (the same seeds 1–200 per bot) and run as parallel
       # processes after one sandbox import — the row is sim-only and seeded (no timing), and `all` takes 3–4 h serially
       CMD_OF[8]="SANDBOX=r3d-qa tools/scripts/fuzz.sh all --runs=200 --report=\$PWD/build/r3d/fuzz.json (as fuzz.sh <final episode> --runs=200 in parallel, merged)"
       local eps ep pids=() prc
       eps="$(python3 -c 'import json,glob,os
print(" ".join(sorted(os.path.basename(f)[:-5] for f in glob.glob("game/data/episodes/*.json") if json.load(open(f)).get("status")=="final")))')"
       run 8 row8.log tools/scripts/sandbox.sh "$SB" || rc=$?
       rm -f "$OUT"/fuzz_*.json "$OUT/fuzz.json"
       for ep in $eps; do
         echo "\$ NO_IMPORT=1 sandbox.sh $SB -s res://tools/fuzz.gd -- $ep --runs=200 --report=$OUT/fuzz_$ep.json" >> "$LOGS/row8.log"
         NO_IMPORT=1 tools/scripts/sandbox.sh "$SB" -s res://tools/fuzz.gd -- "$ep" --runs=200 "--report=$OUT/fuzz_$ep.json" \
           > "$LOGS/row8_$ep.log" 2>&1 &
         pids+=($!)
         sleep 5
       done
       for p in "${pids[@]}"; do wait "$p" || { prc=$?; rc=$prc; }; done
       cat "$LOGS"/row8_*.log >> "$LOGS/row8.log"
       python3 - "$OUT/fuzz.json" $(for ep in $eps; do echo "$OUT/fuzz_$ep.json"; done) <<'MERGE' >> "$LOGS/row8.log" 2>&1 || rc=1
import json, sys
runs = []
for p in sys.argv[2:]:
    try:
        runs += json.load(open(p)).get("runs", [])
    except (OSError, ValueError) as e:
        print("[fuzz-merge] missing %s: %s" % (p, e)); sys.exit(1)
json.dump({"generated_by": "tools/fuzz.gd (pregate3d row 8: per final episode, merged)", "runs": runs}, open(sys.argv[1], "w"))
print("[fuzz-merge] %d runs from %d episode reports" % (len(runs), len(sys.argv) - 2))
MERGE
       ;;
    9) local nr=(); [ -n "$NO_RENDER" ] && nr=(--no-render)
       CMD_OF[9]="SANDBOX=r3d-qa tools/scripts/lint3d.sh --set --all-nights ${nr[*]}"
       run 9 row9.log tools/scripts/lint3d.sh --set --all-nights ${nr[@]+"${nr[@]}"} "--json=$OUT/lint3d_set.json" || rc=$? ;;
    10) local nr=(); [ -n "$NO_RENDER" ] && nr=(--no-render)
       CMD_OF[10]="SANDBOX=r3d-qa tools/scripts/lint3d.sh --screen --aspects=20x9,16x9,4x3 ${nr[*]}"
       run 10 row10.log tools/scripts/lint3d.sh --screen --aspects=20x9,16x9,4x3 ${nr[@]+"${nr[@]}"} "--json=$OUT/lint3d_screen.json" || rc=$? ;;
    11) CMD_OF[11]="SANDBOX=r3d-qa tools/scripts/lint3d.sh --hud --from=\$PWD/build/r3d/e2e"
       if [ -n "$NO_RENDER" ]; then skip_row 11 "--no-render (needs the rendered e2e reports of rows 13–14)"; return 0; fi
       if ! ls "$OUT/e2e/g0.json" "$OUT/e2e/p00_ideal.json" >/dev/null 2>&1; then
         echo "row 11 needs the e2e reports of rows 13–14"; fi
       run 11 row11.log tools/scripts/lint3d.sh --hud "--from=$OUT/e2e" "--json=$OUT/lint3d_hud.json" || rc=$? ;;
    12) local nr=(); [ -n "$NO_RENDER" ] && nr=(--no-render)
       CMD_OF[12]="SANDBOX=r3d-qa tools/scripts/lint3d.sh --visibility --routes=all ${nr[*]}"
       run 12 row12.log tools/scripts/lint3d.sh --visibility --routes=all ${nr[@]+"${nr[@]}"} "--json=$OUT/lint3d_visibility.json" || rc=$? ;;
    13) CMD_OF[13]="E2E_SANDBOX=r3d-qa E2E_TIMEOUT=600 tools/scripts/e2e.sh g0_sneeze --strict --perf-log --report=\$PWD/build/r3d/e2e/g0.json"
       if [ -n "$NO_RENDER" ]; then skip_row 13 "--no-render"; return 0; fi
       E2E_TIMEOUT=600 run 13 row13.log tools/scripts/e2e.sh g0_sneeze --strict --perf-log "--report=$OUT/e2e/g0.json" || rc=$? ;;
    14) CMD_OF[14]="E2E_TIMEOUT=450 e2e.sh prologue_ideal --strict --perf-log --report=…/p00_ideal.json; prologue_slow --strict --report=…/p00_slow.json (+ prologue_required --strict, info: the window share)"
       if [ -n "$NO_RENDER" ]; then skip_row 14 "--no-render"; return 0; fi
       E2E_TIMEOUT=450 run 14 row14.log tools/scripts/e2e.sh prologue_ideal --strict --perf-log "--report=$OUT/e2e/p00_ideal.json" || rc=$?
       E2E_TIMEOUT=450 run 14 row14.log tools/scripts/e2e.sh prologue_slow --strict "--report=$OUT/e2e/p00_slow.json" || rc=$?
       E2E_TIMEOUT=450 run 14 row14.log tools/scripts/e2e.sh prologue_required --strict "--report=$OUT/e2e/p00_required.json" || true ;;
    15) CMD_OF[15]="E2E_SANDBOX=r3d-qa tools/scripts/e2e.sh slice_all --report=\$PWD/build/r3d/e2e/slice_all.json"
       rm -rf "$OUT/e2e/slice_all"
       run 15 row15.log tools/scripts/e2e.sh slice_all "--report=$OUT/e2e/slice_all.json" || rc=$? ;;
    16) CMD_OF[16]="E2E_TIMEOUT=2700 e2e.sh n01_ideal --perf-log --report=…/e2e/n01_ideal_perf.json; 3 × E2E_TIMEOUT=450 e2e.sh prologue_ideal --perf-log --report=…/prof/p00_r<n>.e2e.json -- --view3d-prof=…/prof/p00_r<n>.prof.json and 2 × the same --headless (p00_h<n>; D18.2); perf3d.sh build/r3d/e2e/{g0,p00_ideal,n01_ideal_perf}.json"
       if [ -n "$NO_RENDER" ]; then skip_row 16 "--no-render"; return 0; fi
       E2E_TIMEOUT=2700 run 16 row16.log tools/scripts/e2e.sh n01_ideal --perf-log "--report=$OUT/e2e/n01_ideal_perf.json" || true
       rm -rf "$OUT/prof"; mkdir -p "$OUT/prof"; rm -f "$OUT/view3d_prof.json" "$OUT/prof_p00_ideal.json"
       local pt hl
       for pt in r1 r2 r3 h1 h2; do
         hl=(); [[ "$pt" == h* ]] && hl=(--headless)
         E2E_TIMEOUT=450 run 16 row16.log tools/scripts/e2e.sh prologue_ideal --perf-log ${hl[@]+"${hl[@]}"} \
           "--report=$OUT/prof/p00_$pt.e2e.json" -- "--view3d-prof=$OUT/prof/p00_$pt.prof.json" || true
       done
       [ -f "$OUT/prof/p00_r1.prof.json" ] && cp "$OUT/prof/p00_r1.prof.json" "$OUT/view3d_prof.json"
       run 16 row16_perf3d.log tools/scripts/perf3d.sh "$OUT/e2e/g0.json" "$OUT/e2e/p00_ideal.json" "$OUT/e2e/n01_ideal_perf.json" "--json=$OUT/perf3d.json" || true
       rc=0 ;;  # perf3d's own 4.0 ms p95 line is judged by D14/D18.2 in the evaluator
    17) CMD_OF[17]="tools/scripts/shot.sh res://scenes/dev/anim3d/RigPerf3D.tscn build/r3d/perf_<rig>_<n>.png 600 r3d-qa -- --rig=<rig> --clip=<clip> --perf-log (5 × hush/loco_run, 5 × bellows/rx_sneeze_blast_a; medians)"
       if [ -n "$NO_RENDER" ]; then skip_row 17 "--no-render"; return 0; fi
       local rig clip n
       for rig in hush bellows; do
         clip=hush/loco_run; [ "$rig" = bellows ] && clip=bellows/rx_sneeze_blast_a
         for n in 1 2 3 4 5; do
           SHOT_TIMEOUT=300 run 17 "row17_${rig}_${n}.log" tools/scripts/shot.sh res://scenes/dev/anim3d/RigPerf3D.tscn \
             "$OUT/perf_${rig}_${n}.png" 600 "$SB" -- "--rig=$rig" "--clip=$clip" --perf-log || rc=$?
         done
       done ;;
    18) CMD_OF[18]="E2E_SANDBOX=r3d-qa tools/scripts/e2e.sh retry | pause_back | touch_smoke | tap_accuracy | curtain_call --report=build/r3d/flows/<flow>.json"
       if [ -n "$NO_RENDER" ]; then skip_row 18 "--no-render"; return 0; fi
       local f to
       for f in retry pause_back touch_smoke tap_accuracy curtain_call; do
         to=300; [ "$f" = tap_accuracy ] && to=400; [ "$f" = curtain_call ] && to=600
         E2E_TIMEOUT=$to run 18 row18.log tools/scripts/e2e.sh "$f" "--report=$OUT/flows/$f.json" || rc=$?
       done ;;
    19) CMD_OF[19]="(docs/review/r3d-qa/readability.md verdict lines)" ;;
    20a) CMD_OF[20a]="tools/scripts/export_android.sh --sandbox r3d-qa --out build/r3d/mischief-debug.apk + unzip -l + sha256sum"
       rm -f "$OUT/mischief-debug.apk" "$LOGS/row20a_boot_config.json"
       run 20a row20a.log tools/scripts/export_android.sh --sandbox "$SB" --out "$OUT/mischief-debug.apk" || rc=$?
       if [ -f "$OUT/mischief-debug.apk" ]; then
         unzip -l "$OUT/mischief-debug.apk" > "$LOGS/row20a_unzip.log" 2>&1
         sha256sum "$OUT/mischief-debug.apk" > "$LOGS/row20a_sha256.txt"
         unzip -p "$OUT/mischief-debug.apk" assets/scenes/boot/boot_config.json > "$LOGS/row20a_boot_config.json" 2>/dev/null || true
         # the exported pack's own scripts: every script the APK ships compiles and a 3D Night builds from it
         # (catches a shipped script that names a class the export filter left out); headless, one slot
         rm -rf "$OUT/apk_assets"; mkdir -p "$OUT/apk_assets"
         unzip -q "$OUT/mischief-debug.apk" 'assets/*' -d "$OUT/apk_x" && mv "$OUT/apk_x/assets/"* "$OUT/apk_x/assets/".[!.]* "$OUT/apk_assets/" 2>/dev/null
         rm -rf "$OUT/apk_x"
         cat > "$OUT/apk_assets/_pregate_probe.gd" <<'GD'
extends SceneTree
## pregate3d row 20a: load every script of the exported pack, then build g0 in 3D and play 120 frames headless.
func _initialize() -> void:
	_run.call_deferred()


func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd.remap"):
			out.append(dir.path_join(f.trim_suffix(".remap")))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan(dir.path_join(sub), out)


func _run() -> void:
	await process_frame
	var paths: Array = []
	_scan("res://", paths)
	var bad: Array = []
	for p in paths:
		var s: Variant = ResourceLoader.load(p)
		if s == null:
			bad.append(p)
	print("[apkprobe] scripts %d, failed to load %d %s" % [paths.size(), bad.size(), str(bad.slice(0, 8))])
	var ps := load("res://scenes/night/NightScene.tscn") as PackedScene
	if ps == null:
		print("[apkprobe] night FAIL: NightScene.tscn did not load")
		quit(1)
		return
	var n: Node = ps.instantiate()
	n.call("setup", {"episode": "g0_sneeze", "from": "test", "skip_intro": true})
	root.add_child(n)
	for i in 120:
		await process_frame
	var wv: Variant = n.get("world_view")
	var w: Variant = n.get("world")
	print("[apkprobe] night %s view=%s world_view=%s tick=%s" % ["OK" if wv != null and w != null else "FAIL",
		str(n.get("view_mode")), wv.get_class() if wv is Object else "null", str(w.get("tick")) if w is Object else "-"])
	quit(0 if bad.is_empty() and wv != null else 1)
GD
         "$ROOT/tools/scripts/slot.sh" timeout 300 godot --headless --audio-driver Dummy --path "$OUT/apk_assets" \
           -s res://_pregate_probe.gd > "$LOGS/row20a_probe.log" 2>&1 || true
       fi ;;
  esac
  evaluate "$row" "$rc" "$(( $(date +%s) - t0 ))"
}

echo "[pregate3d] head $HEAD_SHA tree $TREE sim-tree $SIM_TREE rows: ${ROWS[*]}${NO_RENDER:+ (no-render)} — logs in build/r3d/logs/"
for r in "${ROWS[@]}"; do do_row "$r"; done

# --- the table (every row of pregate.json; rows from an earlier run are marked, stale ones fail) ----------------------
python3 - "$OUT/pregate.json" "$TREE" "${ROWS[*]}" "$SIM_TREE" <<'PY'
import json, sys
pj = json.load(open(sys.argv[1]))
tree, ran, sim_tree = sys.argv[2], set(sys.argv[3].split()), sys.argv[4]
order = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20a"]
rows = pj.get("rows", {})
ok_all = True
print("\n| # | result | wall | key numbers |\n|---|---|---|---|")
for r in order:
    e = rows.get(r)
    if e is None:
        print("| %s | not run | | |" % r)
        if r in ran:
            ok_all = False
        continue
    if e.get("skipped"):
        print("| %s | SKIP | | %s |" % (r, e["skipped"]))
        continue
    stale = r not in ran and e.get("tree") != (sim_tree if r in ("5", "6", "7", "8") else tree) and r not in ("19",)
    res = "STALE" if stale else ("PASS" if e.get("pass") else "FAIL")
    if r not in ran:
        res += " (earlier, %s)" % e.get("at", "?")
    n = e.get("numbers", {})
    flat = []
    for k, v in n.items():
        if isinstance(v, (dict, list)):
            continue
        flat.append("%s %s" % (k, v))
    fl = ("; FAIL: " + "; ".join(e.get("failures", [])[:3])) if e.get("failures") else ""
    print("| %s | %s | %ss | %s%s |" % (r, res, e.get("wall_s", ""), ", ".join(flat)[:300], fl[:300]))
    if not e.get("pass"):
        ok_all = False  # a failing row fails the summary whether it ran now or earlier (row 19 included)
    if stale:
        ok_all = False
pj["summary"] = {"tree": tree, "sim_tree": sim_tree, "rows_run": sorted(ran), "pass": ok_all}
json.dump(pj, open(sys.argv[1], "w"), indent=1, ensure_ascii=False)
print("\n[pregate3d] %s — build/r3d/pregate.json" % ("PASS" if ok_all else "FAIL"))
sys.exit(0 if ok_all else 1)
PY
