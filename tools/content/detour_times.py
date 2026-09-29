#!/usr/bin/env python3
"""Fix-up detour durations from solver event dumps (owner: content; D1 budget "N01 detours <= 12 s").

A detour runs from its `b_detour {kind, station, why}` (the tick it is queued and shown in the bubble) to the
`b_activity_end {id: kind}` that closes it (the fix-up done). Several residues queue several detours: they
are closed in queue order, so each detour's time includes any queue ahead of it — what the player waits.
A detour a prank interrupts (the residue stays) is closed by the later visit that clears that residue; one whose
residue a prank clears first (N01: TAP DANCE washes out ACHOO-RIA!'s frizz, `clears: ["FRAZZLED"]`) closes at
that `residue_clear` and is flagged "cleared by a prank" (he never walks it).

Usage: python3 tools/content/detour_times.py <events.jsonl|dir> [...] [--max=12] [--json]
  (dumps from `SANDBOX=… tools/scripts/solve.sh … --dump-events=/abs/dir`)
  --max=S  exit 1 when any detour takes longer than S seconds (default: report only)
  --json   print one JSON object per file instead of the table
"""
import glob
import json
import os
import sys

TPS = 60.0
FIXUPS = ("fixup_dry", "fixup_sink", "fixup_honey", "fixup_mirror")


def read_events(path):
    evs = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            if isinstance(ev, dict) and "e" in ev:
                evs.append(ev)
    return evs


def detours(evs):
    """[{kind, station, why, t0, t1, dur_s, interrupted, cleared, ended}] in queue order (t1 = None when never closed;
    `ended` = the Night ended with it still open, which is not a slow detour)."""
    open_q = []
    out = []
    started = None
    for ev in evs:
        e = ev.get("e")
        t = int(ev.get("t", 0))
        if e == "b_detour" and ev.get("kind") in FIXUPS:
            d = {"kind": ev["kind"], "station": ev.get("station", ""), "why": ev.get("why", ""), "t0": t,
                 "t1": None, "dur_s": None, "interrupted": False, "cleared": False, "ended": False}
            open_q.append(d)
            out.append(d)
        elif e == "b_activity" and ev.get("id") in FIXUPS:
            started = ev["id"]
        elif e == "b_activity_end" and ev.get("id") in FIXUPS:
            started = None
            for d in open_q:
                if d["kind"] == ev["id"]:
                    d["t1"] = t
                    open_q.remove(d)
                    break
        elif e == "residue_clear":
            for d in list(open_q):
                if d["why"] == ev.get("kind"):
                    d["t1"] = t
                    d["cleared"] = started != d["kind"]
                    open_q.remove(d)
        elif e == "prank_fire" and started is not None:
            for d in open_q:
                if d["kind"] == started:
                    d["interrupted"] = True
                    break
            started = None
        elif e == "night_end":
            for d in open_q:
                d["ended"] = True
    for d in out:
        if d["t1"] is not None:
            d["dur_s"] = round((d["t1"] - d["t0"]) / TPS, 2)
    return out


def files_from(args):
    out = []
    for a in args:
        if os.path.isdir(a):
            out += sorted(glob.glob(os.path.join(a, "*.events.jsonl")))
        else:
            out.append(a)
    return out


def main(argv):
    limit = None
    as_json = "--json" in argv
    for a in argv:
        if a.startswith("--max="):
            limit = float(a.split("=", 1)[1])
    paths = files_from([a for a in argv if not a.startswith("--")])
    if not paths:
        print(__doc__)
        return 2
    over = 0
    for p in paths:
        ds = detours(read_events(p))
        name = os.path.basename(p).replace(".events.jsonl", "")
        worst = max([d["dur_s"] for d in ds if d["dur_s"] is not None] or [0.0])
        bad = [d for d in ds if limit is not None and not d["ended"] and (d["dur_s"] is None or d["dur_s"] > limit)]
        over += len(bad)
        if as_json:
            print(json.dumps({"run": name, "detours": ds, "worst_s": worst, "over": len(bad)}))
            continue
        print("%s: %d fix-up detour(s), worst %.1f s%s" % (name, len(ds), worst, " — %d over %.0f s" % (len(bad), limit) if bad else ""))
        for d in ds:
            dur = ("open at the curtain" if d["ended"] else "never closed") if d["dur_s"] is None else "%.1f s" % d["dur_s"]
            print("  %-13s %-15s %-9s t %6.1f -> %s%s" % (d["kind"], d["station"], d["why"], d["t0"] / TPS, dur,
                                                     (" (interrupted)" if d["interrupted"] else "") + (" (cleared by a prank)" if d["cleared"] else "")))
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
