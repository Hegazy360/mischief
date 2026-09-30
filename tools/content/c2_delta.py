#!/usr/bin/env python3
"""C2 timing deltas (REDESIGN_3D §6.2 C2): per-hide tiptoe time and per-route totals, before vs after.

Reads two solver reports (`solve.sh --report`) and two `--dump-events` dirs (<episode>_<route>.events.jsonl) and prints
a markdown section: for every hide of the route (in order) the ticks from the `hush_go` that targets the spot to its
`hide` event, before and after, and the route's duration / dead air (gate ⏩) / stars / applause before and after.

  python3 tools/content/c2_delta.py --before-report=a.json --after-report=b.json \
      --before-events=dirA --after-events=dirB [--episode=n01_throat_tea] > c2_delta.md
"""
import argparse
import json
import os


def hides(path):
    """[(spot, go_tick, hide_tick)] in order from an events.jsonl dump."""
    out = []
    pending = {}
    if not os.path.exists(path):
        return out
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if not isinstance(e, dict) or "e" not in e:
                continue
            if e["e"] == "hush_go":
                pending[e.get("target", "")] = e["t"]
            elif e["e"] == "hide":
                spot = e.get("spot", "")
                out.append((spot, pending.get(spot, e["t"]), e["t"]))
    return out


def runs(path):
    d = json.load(open(path))
    return {(r["episode"], r["route"]): r for r in d.get("runs", [])}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before-report", required=True)
    ap.add_argument("--after-report", required=True)
    ap.add_argument("--before-events", required=True)
    ap.add_argument("--after-events", required=True)
    ap.add_argument("--episode", default="n01_throat_tea")
    a = ap.parse_args()
    b, n = runs(a.before_report), runs(a.after_report)
    keys = sorted(k for k in set(b) | set(n) if k[0] == a.episode)
    print("## %s — routes before / after C2\n" % a.episode)
    print("| route | duration s | dead air ⏩ % | max gap ⏩ s | stars | applause | hides moved | Δ tiptoe per moved hide |")
    print("|---|---|---|---|---|---|---|---|")
    detail = []
    for k in keys:
        rb, ra = b.get(k), n.get(k)
        def g(r, key, fmt="%s"):
            return fmt % r[key] if r and key in r else "—"
        hb = hides(os.path.join(a.before_events, "%s_%s.events.jsonl" % k))
        ha = hides(os.path.join(a.after_events, "%s_%s.events.jsonl" % k))
        moved = []
        for i in range(min(len(hb), len(ha))):
            if hb[i][0] != ha[i][0]:
                moved.append((i, hb[i], ha[i]))
        deltas = [((x[2][2] - x[2][1]) - (x[1][2] - x[1][1])) / 60.0 for x in moved]
        stars = lambda r: "".join("★" if s else "☆" for s in r.get("stars", [])) if r else "—"
        print("| %s | %s → %s | %s → %s | %s → %s | %s → %s | %s → %s | %d | %s |" % (
            k[1], g(rb, "duration_s", "%.1f"), g(ra, "duration_s", "%.1f"), g(rb, "dead_air_ff_pct", "%.1f"),
            g(ra, "dead_air_ff_pct", "%.1f"), g(rb, "max_gap_ff_s", "%.1f"), g(ra, "max_gap_ff_s", "%.1f"),
            stars(rb), stars(ra), g(rb, "applause", "%.0f"), g(ra, "applause", "%.0f"), len(moved),
            ("%+.2f s mean (%s)" % (sum(deltas) / len(deltas), ", ".join("%+.2f" % d for d in deltas))) if deltas else "—"))
        for i, x, y in moved:
            detail.append("- %s hide %d: %s %.2f s → %s %.2f s (go→hide)" % (
                k[1], i + 1, x[0], (x[2] - x[1]) / 60.0, y[0], (y[2] - y[1]) / 60.0))
    if detail:
        print("\nPer moved hide (tiptoe + dive, from the tap to the curtain closing):\n")
        print("\n".join(detail))


if __name__ == "__main__":
    main()
