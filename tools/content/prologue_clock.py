#!/usr/bin/env python3
"""Prologue clock (owner: content): the GDD §2.3 timeline against the sim, launch-relative.

Reads solver event dumps of `p00_curtain_up` (`SANDBOX=… tools/scripts/solve.sh p00_curtain_up --route=all
--dump-events=/abs/dir [--report=/abs/solve.json]`) and prints / writes a markdown table: each GDD §2.3 beat, its
target, and when it happens on each route (launch time = sim time + `director.launch_offset_s`, ruling L13: sim
tick 0 is the curtain starting to rise). With `--report`, the dead-air numbers of each route (the ⏩-latched gate
metric next to the naive Stage-1 one) are appended.

Usage: python3 tools/content/prologue_clock.py <dump dir> [--report=/abs/solve.json] [--out=path.md] [--check]
  --check  exit 1 when a hard target misses on the slow route (first player laugh <= 10 s, first prank <= 30 s,
           >= 4 laughs by 75 s) or on the ideal route (>= 6 laughs by 60 s)
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TPS = 60.0
EP = "p00_curtain_up"
ROUTES = ["slow", "ideal", "required"]
LAUGH_EVENTS = {"reaction_accent", "squeak_bit", "panto_round", "panto_bit", "near_miss", "combo", "meltdown_start",
                "door_slam"}

# (beat, GDD §2.3 target text, matcher) — the matcher picks the first matching event
BEATS = [
    ("Curtain up, input live", "2.3–3.1", ("tick0", None)),
    ("Vase smashes behind him (titter)", "≈ 4.6", ("director_cue", {"id": "laugh_vase"})),
    ("Figgis psst + ghost finger on Clarence", "≈ 6.0", ("director_cue", {"id": "ghost_squeak"})),
    ("SQUEAK → yodel (first player laugh)", "≈ 7–9, ≤ 10", ("squeak_bit", {})),
    ("Honey jar glows, ghost finger", "squeak + 1.0 (≤ 15)", ("director_cue", {"id": "ghost_honey"})),
    ("Rig the honey (hold 0.8 s)", "≈ 12", ("rigged", {"prank": "achoo_ria"})),
    ("Entry warning + BEHIND YOU!", "rig + 2.0 (≈ 16)", ("entry_warning", {"room": "kitchen"})),
    ("Hide in the pantry", "—", ("hide", {"spot": "kitchen_pantry_curtain"})),
    ("CHOO! (first prank)", "≈ 26, ≤ 30", ("reaction_accent", {"prank": "achoo_ria"})),
    ("Blind shuffle bonks the door frame", "≈ 29", ("director_cue", {"id": "laugh_doorframe"})),
    ("⏩ lesson (ghost_ff, Hush hidden)", "(new)", ("director_cue", {"id": "ghost_ff"})),
    ("Mirror fix-up (off-stage, hall)", "—", ("b_activity", {"id": "fixup_mirror"})),
    ("Gramophone lever sparkles (unguided)", "mirror detour + 8", ("director_cue", {"id": "sparkle_lever"})),
    ("ALLEGRO-GO-GO! (roar)", "≈ 38 (≈ 46 accepted)", ("reaction_accent", {"prank": "allegro_go_go"})),
    ("Specs on, the hunt", "≈ 46", ("b_activity", {"id": "hunt"})),
    ("Relief laugh (found nothing)", "hunt + 6", ("director_cue", {"id": "laugh_relief"})),
    ("Picture falls on his head", "≈ 54", ("director_cue", {"id": "laugh_picture"})),
    ("Curtain falls; title card", "≈ 58–70", ("director_cue", {"id": "title_card"})),
    ("Prologue ends", "title + 1.0", ("night_end", {})),
]


def read(path):
    evs = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("{"):
                try:
                    ev = json.loads(line)
                except ValueError:
                    continue
                if "e" in ev:
                    evs.append(ev)
    return evs


def launch_offset():
    try:
        with open(os.path.join(ROOT, "game", "data", "episodes", EP + ".json"), encoding="utf-8") as f:
            return float(json.load(f).get("director", {}).get("launch_offset_s", 0.0))
    except (OSError, ValueError):
        return 0.0


def first(evs, name, match):
    for ev in evs:
        if ev["e"] == name and all(ev.get(k) == v for k, v in (match or {}).items()):
            return ev["t"]
    return None


def is_laugh(ev):
    if ev["e"] in LAUGH_EVENTS:
        return True
    if ev["e"] == "bump":
        return bool(ev.get("first"))
    return ev["e"] == "director_cue" and str(ev.get("id", "")).startswith("laugh_")


def laughs_by(evs, s, off):
    return sum(1 for ev in evs if is_laugh(ev) and ev["t"] / TPS + off <= s)


def main(argv):
    dirs = [a for a in argv if not a.startswith("--")]
    if not dirs:
        print(__doc__)
        return 2
    rep_path = ""
    out_path = ""
    check = "--check" in argv
    for a in argv:
        if a.startswith("--report="):
            rep_path = a.split("=", 1)[1]
        elif a.startswith("--out="):
            out_path = a.split("=", 1)[1]
    off = launch_offset()
    runs = {}
    for r in ROUTES:
        p = os.path.join(dirs[0], "%s_%s.events.jsonl" % (EP, r))
        if os.path.exists(p):
            runs[r] = read(p)
    if not runs:
        print("[prologue_clock] no %s_*.events.jsonl in %s" % (EP, dirs[0]))
        return 2
    have = [r for r in ROUTES if r in runs]
    lines = ["| beat (GDD §2.3) | GDD target (launch s) | " + " | ".join("%s (launch s)" % r for r in have) + " |",
             "|---|---|" + "---|" * len(have)]
    for beat, want, (name, match) in BEATS:
        cells = []
        for r in have:
            if name == "tick0":
                cells.append("%.1f" % off)
                continue
            t = first(runs[r], name, match)
            cells.append("—" if t is None else "%.1f" % (t / TPS + off))
        lines.append("| %s | %s | %s |" % (beat, want, " | ".join(cells)))
    lines += ["", "| laugh clock | target | " + " | ".join(have) + " |", "|---|---|" + "---|" * len(have)]
    for s, want in ((10, "slow ≥ 1 player laugh"), (60, "ideal ≥ 6"), (75, "slow ≥ 4")):
        lines.append("| laughs by %d s | %s | %s |" % (s, want, " | ".join(str(laughs_by(runs[r], s, off)) for r in have)))
    fails = []
    if "slow" in runs:
        ev = runs["slow"]
        fl = next((e["t"] for e in ev if e["e"] == "squeak_bit"), None)
        fp = first(ev, "reaction_accent", {"prank": "achoo_ria"})
        if fl is None or fl / TPS + off > 10.0:
            fails.append("slow: first player laugh after 10 s")
        if fp is None or fp / TPS + off > 30.0:
            fails.append("slow: first prank after 30 s")
        if laughs_by(ev, 75, off) < 4:
            fails.append("slow: fewer than 4 laughs by 75 s")
    if "ideal" in runs and laughs_by(runs["ideal"], 60, off) < 6:
        fails.append("ideal: fewer than 6 laughs by 60 s")
    if rep_path and os.path.exists(rep_path):
        with open(rep_path, encoding="utf-8") as f:
            rep = json.load(f)
        lines += ["", "| dead air (%s) | ⏩ latched (gate) | naive ⏩ (info) | sim time (info) | worst gap ⏩ | edge share |" % EP,
                  "|---|---|---|---|---|---|"]
        for run in rep.get("runs", []):
            if run.get("episode") != EP:
                continue
            lines.append("| %s | %.1f %% | %.1f %% | %.1f %% | %.1f s | %.2f |" % (
                run.get("route"), float(run.get("dead_air_ff_pct", 0)), float(run.get("dead_air_ff_naive_pct", 0)),
                float(run.get("dead_air_sim_pct", 0)), float(run.get("max_gap_ff_s", 0)),
                float(run.get("beats", {}).get("edge_share", 0))))
    text = "\n".join(lines) + "\n"
    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(text)
    print(text)
    for x in fails:
        print("[prologue_clock] MISS " + x)
    return 1 if (check and fails) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
