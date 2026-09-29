#!/usr/bin/env python3
"""Micro-gag table (owner: content): reads game/data/activities.json and writes
docs/review/s2-content/micro_gags.md — every timed micro-gag (id, activity, at_s, len_f, emote, one-line gag),
the walk beats, which slice Nights play each activity, and the per-activity cadence check.

Usage: python3 tools/content/micro_gags.py [--out=path.md] [--check]
  --check  exit 1 if a slice activity/detour breaks the cadence rules (first beat 2-3 s, spacing 5-8 s,
           no gap > 8 s over dur_s or the cycle, len_f 36-72, emote in the vocabulary, ids unique per activity).

The animators build `bellows/mg_<id>` for every id listed (s2-anim-bellows); ids are stable once published —
add, never rename.
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "game", "data")
EMOTES = ["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]
SLICE = ["g0_sneeze", "p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]
# fix-up detours the slice can reach (residues its pranks leave)
SLICE_DETOURS = ["fixup_dry", "fixup_sink", "fixup_honey", "fixup_mirror"]
MAX_GAP_S = 8.0
MIN_SPACING_S = 5.0
NOTES = [
    "**Changes from the Stage-1 id lists** (made before this first publication; every Phase-G id is kept):",
    "- `hum` moved from `tea` to `warmup` (4th beat of the gated warm-up cycle): the D1 tea is 8 s and fits two",
    "  beats (`admire_in_kettle` 2.0 s, `pinkie_up` 7.0 s = the sip); the Prologue's player-led warm-up needs",
    "  four different beats before it repeats. A face-and-notes overlay works standing at the gramophone.",
    "- `comb_flourish` moved from `mirror` to `fixup_mirror` (combing *is* the fix-up); `mirror` keeps",
    "  `kiss_reflection`.",
    "- `turn_page` retired (a page turn is not a joke at 50 px; the D1 paper is 8 s and fits two beats).",
    "- New: `hunt` `peer_under_piano` (2.5 s = the moment his hunt path passes the piano Hush hides behind);",
    "  one beat per fix-up detour (`steam_sideburns`, `scrub_nose`,",
    "  `honey_test_note`, `comb_flourish`); walk beats `walk_hum`, `cravat_tug`, `walk_scale`.",
    "- `emote` is null only where the gag has no face (`peer_under_piano`: his head is under the piano).",
    "- The `dur_s` column shows the file's current value; the D1 durations land with the retuned routes",
    "  (`d1_changes.md`). Every `at_s` already fits the D1 durations.",
]


def _read(p):
    with open(os.path.join(DATA, p), encoding="utf-8") as f:
        return json.load(f)


def slice_usage():
    use = {}
    for ep in SLICE:
        try:
            e = _read("episodes/%s.json" % ep)
        except OSError:
            continue
        for le in e.get("bellows", {}).get("loop", []):
            use.setdefault(le.get("a"), []).append(ep)
    return {k: sorted(set(v), key=SLICE.index) for k, v in use.items()}


def cadence_problems(aid, a):
    """Problems with one activity's micro-gags against the D1 cadence rules."""
    out = []
    mg = a.get("micro_gags", [])
    dur = float(a.get("dur_s", 0))
    if not mg:
        return ["%s: no micro-gags" % aid]
    ids = [g.get("id") if isinstance(g, dict) else g for g in mg]
    if len(set(ids)) != len(ids):
        out.append("%s: duplicate micro-gag id" % aid)
    ats = []
    for g in mg:
        if not isinstance(g, dict):
            out.append("%s: legacy string micro-gag '%s' (use the timed form)" % (aid, g))
            continue
        ats.append(float(g.get("at_s", 0)))
        if not 36 <= int(g.get("len_f", 0)) <= 72:
            out.append("%s.%s: len_f %s not 36-72" % (aid, g.get("id"), g.get("len_f")))
        if g.get("emote") is not None and g.get("emote") not in EMOTES:
            out.append("%s.%s: emote %s not in the vocabulary" % (aid, g.get("id"), g.get("emote")))
        if not str(g.get("gag", "")).strip():
            out.append("%s.%s: no one-line gag" % (aid, g.get("id")))
    if not ats:
        return out
    if not 2.0 <= ats[0] <= 3.0:
        out.append("%s: first beat at %.1f s (2-3 s)" % (aid, ats[0]))
    for x, y in zip(ats, ats[1:]):
        if not MIN_SPACING_S <= y - x <= MAX_GAP_S:
            out.append("%s: spacing %.1f s (5-8 s)" % (aid, y - x))
    played = [t for t in ats if t < dur] or ats[:1]
    if dur - played[-1] > MAX_GAP_S:
        out.append("%s: %.1f s from the last beat to the end of dur_s" % (aid, dur - played[-1]))
    cyc = a.get("mg_cycle_s")
    if cyc is not None:
        if float(cyc) - ats[-1] + ats[0] > MAX_GAP_S or float(cyc) - ats[-1] < MIN_SPACING_S - ats[0]:
            out.append("%s: mg_cycle_s %.1f leaves a wrap gap of %.1f s" % (aid, float(cyc), float(cyc) - ats[-1] + ats[0]))
    return out


def main(argv):
    out_path = os.path.join(ROOT, "docs", "review", "s2-content", "micro_gags.md")
    check = "--check" in argv
    for a in argv:
        if a.startswith("--out="):
            out_path = a.split("=", 1)[1]
    d = _read("activities.json")
    use = slice_usage()
    acts = d.get("activities", {})
    dets = d.get("detours", {})
    rows = []
    problems = []
    slice_ids = [k for k in acts if k in use] + [k for k in SLICE_DETOURS if k in dets]
    for aid in list(acts) + list(dets):
        a = acts.get(aid) or dets.get(aid)
        in_slice = aid in slice_ids
        if in_slice:
            problems += cadence_problems(aid, a)
        for g in a.get("micro_gags", []):
            if isinstance(g, dict):
                rows.append((in_slice, aid, a, g))
    lines = [
        "# Micro-gags (timed schema, D1) — generated by `tools/content/micro_gags.py`",
        "",
        "Source of truth: `game/data/activities.json` (`micro_gags: [{id, at_s, len_f, emote, gag}]`, `mg_cycle_s`,",
        "root `walk_beats`). `at_s` counts from the activity's start (the PERFORM clock); a gated or long activity",
        "repeats its list every `mg_cycle_s`. The sim emits `micro_gag {id, activity, room, x, len, emote, vis}`;",
        "the view plays clip `bellows/mg_<id>` (an overlay on the activity clip) and the HUD edge bubble draws",
        "`emote` when he is off-screen. **Ids are stable from this publication on: add, never rename.**",
        "Each gag is written as a one-second joke readable at 50 px; the animator builds from the line.",
        "",
    ] + NOTES + [
        "",
        "## Slice activities and detours (Gate 0, Prologue, Night 1, Night 2)",
        "",
        "| activity | dur_s | cycle | id | at_s | len_f | emote | the gag (one line) | Nights |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for in_slice, aid, a, g in rows:
        if not in_slice:
            continue
        nights = ", ".join(use.get(aid, ["(fix-up)"]))
        lines.append("| `%s` | %s | %s | `%s` | %.1f | %d | %s | %s | %s |" % (
            aid, a.get("dur_s"), a.get("mg_cycle_s", "—"), g["id"], float(g["at_s"]), int(g["len_f"]),
            g.get("emote") or "—", g.get("gag", ""), nights))
    wb = d.get("walk_beats", {})
    lines += ["", "## Walk beats (root `walk_beats`)", "",
              "During a non-chase walk longer than `min_leg_s` = %s s, one beat every `every_s` = %s s of walking,"
              " cycling the ids in order (clip `bellows/mg_<id>` over the strut)." % (wb.get("min_leg_s"), wb.get("every_s")),
              "", "| id | len_f | emote | the gag |", "|---|---|---|---|"]
    for g in wb.get("ids", []):
        lines.append("| `%s` | %d | %s | %s |" % (g["id"], int(g.get("len_f", 48)), g.get("emote") or "—", g.get("gag", "")))
    lines += ["", "## Other activities (Stage 3; timed form, not gated by the slice lint)", "",
              "| activity | dur_s | id | at_s | len_f | emote | the gag |", "|---|---|---|---|---|---|---|"]
    for in_slice, aid, a, g in rows:
        if in_slice:
            continue
        lines.append("| `%s` | %s | `%s` | %.1f | %d | %s | %s |" % (
            aid, a.get("dur_s"), g["id"], float(g["at_s"]), int(g["len_f"]), g.get("emote") or "—", g.get("gag", "")))
    lines += ["", "## Cadence check (slice)", ""]
    lines += ["- %s" % p for p in problems] if problems else ["All slice activities and detours pass: first beat 2–3 s,"
                                                             " spacing 5–8 s, no gap > 8 s over `dur_s` or the cycle,"
                                                             " `len_f` 36–72, emotes in the vocabulary."]
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("[micro_gags] %d gags, %d walk beats, %d problem(s) -> %s" % (
        len(rows), len(wb.get("ids", [])), len(problems), os.path.relpath(out_path, ROOT)))
    for p in problems:
        print("  - " + p)
    return 1 if (check and problems) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
