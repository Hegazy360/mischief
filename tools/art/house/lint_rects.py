#!/usr/bin/env python3
"""lint_rects - hotspot / geometry lint for game/data/house/house.json (TECH §4.1, §10.5; GDD §3.5).

Checks
* ids: every TECH §14 room, link, station and hotspot id is present (and canon.py matches TECH.md);
* hit boxes >= 144 x 144; any two targets on the same floor (hotspots, doors, stairs) are separated by
  >= 24 px in x OR in y (so no overlaps, 24 px dead space) - checked across room boundaries too,
  because door boxes may straddle a partition;
* shared objects (TECH §14 + this layout's extra stacks) sit in one column: every member overlaps
  another member in x and x-overlapping members are separated vertically by >= 24 px;
* use_x inside the hotspot's room; the use point lies within 90 px of its own box (tap-assist);
* stations: x within 80 px of the GDD §7.1 guide, stand_x inside the room, kinds as TECH §14;
* links reference real rooms, doorway/door x on the shared wall, stairs ends inside their rooms;
* landings, entries and quake props inside their rooms; every art path exists on disk.
Exit code 1 on any error. Usage: python3 tools/art/house/lint_rects.py [house.json]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import canon  # noqa: E402
import geo  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GAME = os.path.join(REPO, "game")
DEFAULT = os.path.join(GAME, "data", "house", "house.json")
MIN = 144
GAP = 24


def res_to_path(p):
    return os.path.join(GAME, p[len("res://"):]) if p.startswith("res://") else p


def sep(a, b):
    """(x gap, y gap) between rects [x, y, w, h] (negative = overlap)."""
    gx = max(b[0] - (a[0] + a[2]), a[0] - (b[0] + b[2]))
    gy = max(b[1] - (a[1] + a[3]), a[1] - (b[1] + b[3]))
    return gx, gy


def lint(house):
    errs = []
    errs += canon.check_against_tech()
    rooms = {r["id"]: r for r in house["rooms"]}
    links = {l["id"]: l for l in house["links"]}
    stations = {s["id"]: s for s in house["stations"]}
    hs = house["hotspots"]
    hot = {h["id"]: h for h in hs}
    for rid in canon.ROOMS:
        if rid not in rooms:
            errs.append("room %s missing" % rid)
    for lid in canon.LINKS:
        if lid not in links:
            errs.append("link %s missing" % lid)
    for sid, kinds in canon.STATIONS.items():
        if sid not in stations:
            errs.append("station %s missing" % sid)
        elif sorted(stations[sid].get("kinds", [])) != sorted(kinds):
            errs.append("station %s kinds %s != TECH %s" % (sid, stations[sid].get("kinds"), kinds))
    for hid in canon.HOTSPOTS:
        if hid not in hot:
            errs.append("hotspot %s missing" % hid)
    if len(hot) != len(hs):
        errs.append("duplicate hotspot ids")

    def inside(room, x):
        r = rooms.get(room)
        return r is not None and r["x0"] <= x <= r["x1"]

    # rooms
    for r in house["rooms"]:
        if r["x1"] <= r["x0"]:
            errs.append("room %s empty range" % r["id"])
        for k in ("bg", "fg"):
            p = r.get("art", {}).get(k)
            if not p or not os.path.exists(res_to_path(p)):
                errs.append("room %s art.%s missing: %s" % (r["id"], k, p))
    # links
    for l in house["links"]:
        a, b = rooms.get(l["a"]), rooms.get(l["b"])
        if a is None or b is None:
            errs.append("link %s references unknown rooms" % l["id"])
            continue
        if l["kind"] in ("doorway", "door"):
            if not (a["floor"] == b["floor"] and l["x"] in (a["x0"], a["x1"]) and l["x"] in (b["x0"], b["x1"])):
                errs.append("link %s x %s is not on the wall shared by %s and %s" % (l["id"], l["x"], l["a"], l["b"]))
        elif l["kind"] == "stairs":
            if not inside(l["a"], l["ax"]) or not inside(l["b"], l["bx"]):
                errs.append("stairs ends outside their rooms")
            if a["floor"] == b["floor"]:
                errs.append("stairs join one floor")
        else:
            errs.append("link %s unknown kind %s" % (l["id"], l["kind"]))
    # stations
    for s in house["stations"]:
        if not inside(s["room"], s["x"]) or not inside(s["room"], s["stand_x"]):
            errs.append("station %s x/stand_x outside %s" % (s["id"], s["room"]))
        g = geo.GDD_X.get(s["id"])
        if g is not None and abs(s["x"] - g) > 80:
            errs.append("station %s x %d is %d px from the GDD guide %d (> 80)" % (s["id"], s["x"], s["x"] - g, g))
        if s["facing"] not in (1, -1):
            errs.append("station %s facing" % s["id"])
        if "frame_x" in s and not inside(s["room"], s["frame_x"]):
            errs.append("station %s frame_x outside the room" % s["id"])
    # hotspots
    kinds = ("container", "hiding", "rig_point", "exit", "stairs", "door")
    for h in hs:
        hid = h["id"]
        if h["kind"] not in kinds:
            errs.append("%s kind %s" % (hid, h["kind"]))
        if not inside(h["room"], h["use_x"]):
            errs.append("%s use_x %s outside %s" % (hid, h["use_x"], h["room"]))
        x, y, w, hh = h["rect"]
        if w < MIN or hh < MIN:
            errs.append("%s hit box %dx%d < %d" % (hid, w, hh, MIN))
        if not (x - 90 <= h["use_x"] <= x + w + 90):
            errs.append("%s use_x %d is > 90 px from its box" % (hid, h["use_x"]))
        if h["facing"] not in (1, -1):
            errs.append("%s facing" % hid)
        if "station" in h and h["station"] not in stations:
            errs.append("%s station %s unknown" % (hid, h["station"]))
        if "link" in h and h["link"] not in links:
            errs.append("%s link %s unknown" % (hid, h["link"]))
        exp = canon.HIDING.get(hid, "__none__")
        if h["kind"] == "hiding" and exp != "__none__" and h.get("in_use_by") != exp:
            errs.append("%s in_use_by %s != %s" % (hid, h.get("in_use_by"), exp))
        want = {"container": canon.CONTAINERS, "hiding": list(canon.HIDING), "rig_point": list(canon.RIG_POINTS)}
        for k, ids in want.items():
            if hid in ids and h["kind"] != k:
                errs.append("%s should be kind %s" % (hid, k))
        for state, p in (h.get("art") or {}).items():
            if not os.path.exists(res_to_path(p)):
                errs.append("%s art.%s missing: %s" % (hid, state, p))
        if h.get("art") and "outline" not in h["art"] and h.get("tappable", True):
            errs.append("%s has art but no outline sprite" % hid)
    # pairwise gaps per floor
    floor_of = {rid: r["floor"] for rid, r in rooms.items()}
    for i in range(len(hs)):
        for j in range(i + 1, len(hs)):
            a, b = hs[i], hs[j]
            if floor_of.get(a["room"]) != floor_of.get(b["room"]):
                continue
            gx, gy = sep(a["rect"], b["rect"])
            if gx < GAP and gy < GAP:
                what = "overlap" if gx < 0 and gy < 0 else "gap %d/%d px" % (gx, gy)
                errs.append("%s and %s: %s (need >= %d px dead space)" % (a["id"], b["id"], what, GAP))
    # stacks
    for grp in canon.SHARED + [tuple(s) for s in house.get("stacks", [])]:
        mem = [hot[g] for g in grp if g in hot]
        if len(mem) != len(grp):
            errs.append("stack %s has unknown members" % (grp,))
            continue
        for m in mem:
            others = [o for o in mem if o is not m]
            if not any(sep(m["rect"], o["rect"])[0] < 0 for o in others):
                errs.append("stack %s: %s is not in the same column as the others" % (grp, m["id"]))
        for p in range(len(mem)):
            for q in range(p + 1, len(mem)):
                gx, gy = sep(mem[p]["rect"], mem[q]["rect"])
                if gx < 0 and gy < GAP:
                    errs.append("stack %s: %s / %s not stacked with a %d px gap" % (grp, mem[p]["id"], mem[q]["id"], GAP))
    # landings, entries, quake props, decor
    for room, tbl in house.get("landings", {}).items():
        for k, x in tbl.items():
            if not inside(room, x):
                errs.append("landing %s.%s x %s outside the room" % (room, k, x))
    for k, e in house.get("entries", {}).items():
        if not inside(e["room"], e["x"]):
            errs.append("entry %s outside %s" % (k, e["room"]))
    decor = {d["id"]: d for d in house.get("decor", [])}
    for room, lst in house.get("quake_props", {}).items():
        for q in lst:
            if not inside(room, q["x"]):
                errs.append("quake prop %s outside %s" % (q["prop"], room))
            if q.get("decor") and q["decor"] not in decor:
                errs.append("quake prop %s decor %s unknown" % (q["prop"], q["decor"]))
    for d in decor.values():
        if d["room"] not in rooms:
            errs.append("decor %s room unknown" % d["id"])
        for state, p in d.get("art", {}).items():
            if not os.path.exists(res_to_path(p)):
                errs.append("decor %s art.%s missing: %s" % (d["id"], state, p))
    stage = house.get("stage", {})
    for k, v in stage.items():
        p = v.get("art") if isinstance(v, dict) else (v if isinstance(v, str) else None)
        if p and p.startswith("res://") and not os.path.exists(res_to_path(p)):
            errs.append("stage %s art missing: %s" % (k, p))
    for piece in stage.get("pieces", []):
        if not os.path.exists(res_to_path(piece["art"])):
            errs.append("set piece %s art missing" % piece["id"])
    return errs


def main(argv):
    path = argv[1] if len(argv) > 1 else DEFAULT
    house = json.load(open(path))
    errs = lint(house)
    n = len(house["hotspots"])
    if errs:
        for e in errs:
            print("FAIL", e)
        print("lint_rects: %d errors (%d hotspots)" % (len(errs), n))
        return 1
    print("lint_rects: OK (%d rooms, %d links, %d stations, %d hotspots)" % (
        len(house["rooms"]), len(house["links"]), len(house["stations"]), n))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
