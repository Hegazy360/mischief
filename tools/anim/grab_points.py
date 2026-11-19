#!/usr/bin/env python3
"""Propose reach grab points for every container / rig point (docs/research/animation.md, phase 2).

usage: tools/scripts/sandbox.sh <sb> -s res://tools/anim/prop_spans.gd -- --out=/abs/spans.json
       python3 tools/anim/grab_points.py --spans=/abs/spans.json [--check]

A grab point is where a hand goes on a prop, in world px (x, y; y up = negative from the floor line),
one for each way Hush can face at it (she faces whichever way she walked in): ((right), (left)).
Props are drawn centred over the stand point (use_x), so Hush's body hides most of each one, and a
canvas bounding box is no guide (the kettle's box reaches 95 px in front of her, but only its spout
does). prop_spans.gd measures the VISIBLE pixels per 8 px column; the rule picks

  x  = the opaque column (>= MIN_SPAN px tall) nearest FRONT_PX in front of her (just past her nose);
       when nothing solid sticks out in front (>= FRONT_MIN), the most forward solid column (flagged)
  y  = open boxes on the floor (top below RIM_MAX_TOP): RIM_DROP px under that column's top -- the hand
       goes INTO it; tall / wall-hung containers (fridge, cabinet): the middle, at the door
       rig points: the middle of that column's span

The proposals are pasted into tools/art/house/geo.py `GRAB` (the data; tune there by hand after the
review shots) and house_json.py writes them into house.json. `--check` lists geo.GRAB entries that
differ from the rule (the hand edits) and the flagged ones.
"""
import json
import os
import sys

FRONT_PX = 62
FRONT_MIN = 40
FRONT_MAX = 100
MIN_SPAN = 20
RIM_DROP = 18
RIM_FLOOR = 40      # px: a container whose column reaches this close to the floor stands on it
RIM_MAX_TOP = 260   # px: taller than this and it has a door, not an opening
KINDS = ("container", "rig_point")


def propose(d, f):
    """(grab [x, y], flag) for one prop_spans entry when Hush faces `f` (+1 right, -1 left): she arrives
    facing whichever way she walked in, so every prop gets a point on each side."""
    u = d["use_x"]
    cols = [(f * (c[0] - u), c) for c in d["cols"] if c[2] - c[1] >= MIN_SPAN]
    if not cols:
        cols = [(f * (c[0] - u), c) for c in d["cols"]]
    front = [fc for fc in cols if FRONT_MIN <= fc[0] <= FRONT_MAX]
    flag = ""
    if front:
        fwd, c = min(front, key=lambda fc: abs(fc[0] - FRONT_PX))
    else:
        fwd, c = max(cols, key=lambda fc: fc[0])
        flag = "nothing solid in front (most forward column at %+d)" % fwd
    # Only an open box on the floor is reached INTO (its rim); a tall or wall-hung container (a fridge, a
    # cabinet) is reached at its door, the middle of the column, like a rig point.
    rim = d["kind"] == "container" and c[2] > -RIM_FLOOR and c[1] > -RIM_MAX_TOP
    y = c[1] + RIM_DROP if rim else 0.5 * (c[1] + c[2])
    return [int(round(c[0])), int(round(min(y, -12)))], flag


def main():
    spans = ""
    check = False
    for a in sys.argv[1:]:
        if a.startswith("--spans="):
            spans = a.split("=", 1)[1]
        elif a == "--check":
            check = True
    if not spans:
        sys.exit("grab_points: --spans=<prop_spans.gd output> is required (see the usage)")
    data = json.load(open(spans))
    rows = []
    for hid, d in sorted(data.items()):
        if d["kind"] in KINDS:
            (r, fr), (l, fl) = propose(d, 1), propose(d, -1)
            rows.append((hid, (r, l), "; ".join(x for x in ("right: " + fr if fr else "", "left: " + fl if fl else "") if x)))
    if check:
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "house"))
        import geo
        for hid, p, flag in rows:
            g = geo.GRAB.get(hid)
            if g is None:
                print("MISSING %s (rule %s)" % (hid, p))
            elif [list(g[0]), list(g[1])] != [p[0], p[1]]:
                print("edited  %-28s %s (rule %s)" % (hid, [list(g[0]), list(g[1])], [p[0], p[1]]))
            if flag:
                print("flag    %-28s %s" % (hid, flag))
        return
    for hid, (r, l), flag in rows:
        print('    "%s": ((%d, %d), (%d, %d)),%s' % (hid, r[0], r[1], l[0], l[1], ("  # " + flag) if flag else ""))


if __name__ == "__main__":
    main()
