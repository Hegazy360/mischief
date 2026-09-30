"""Build the simplified 3D sets of the slice in look A (Toy Box) from game/data/house/house3d.json.

  tools/art3d/set/build.sh                      (palettes with system Python, then this under Blender)
  tools/art3d/blender.sh --python tools/art3d/set/build.py -- --out game/art3d [--only kitchen_arch,honey_jar]

Writes (paths relative to --out):
  set/<room>_arch.glb        one mesh per room (+ the front door leaf): back wall field, wainscot band, picture rail,
                             two-tone boards to the lip, the room's unconditional built-ins (counters, sink unit,
                             fireplace + mantel, stairs, the door flat) on the room palette = one material per room
  set/<builtin>.glb          conditional built-ins (a prop's own shelf, built only with that prop)
  set/<piece>.glb            furniture / dressing / decor (stool, windows, lamp, pans, portrait, vase, picture …)
  props/<prop>.glb           live props on the props palette, ONE skinned mesh each: parts (lid, lever, pepper pot,
                             door, armed marks …) are bones, so a prop is one draw (+ ink + halo shells)
  set/build_report.json      per piece: triangles, parts, bounds
Palettes (set/palette_<room>.png, props/palette_props.png) come from palettes.py (build.sh writes them first).
Coordinates are Godot metres (setlib converts); pieces are modelled around their local origin = bottom centre, the
values of house3d.json (bounds / box) decide their size.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import setlib as L  # noqa: E402
from setlib import PB  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    for i, a in enumerate(ARGV):
        if a == "--" + name and i + 1 < len(ARGV):
            return ARGV[i + 1]
        if a.startswith("--" + name + "="):
            return a.split("=", 1)[1]
    return default


REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.abspath(arg("out", os.path.join(REPO, "game", "art3d")))
ONLY = set(filter(None, (arg("only", "") or "").split(",")))
H3 = json.load(open(os.path.join(REPO, "game", "data", "house", "house3d.json")))
HOUSE = json.load(open(os.path.join(REPO, "game", "data", "house", "house.json")))
L.set_palette_root(OUT)
REPORT = {}
ROOM_X = {r["id"]: (r["x0"] / 200.0, r["x1"] / 200.0) for r in HOUSE["rooms"]}
BACK = -2.4
LIP = float(H3["stage"]["lip_z"])
ROOM_H = 3.2


def want(name):
    return not ONLY or name in ONLY


def save(root, rel, pb_parts=None):
    path = os.path.join(OUT, rel)
    L.export_glb(root, path)
    REPORT[rel] = {"tris": L.tri_count(root), "parts": pb_parts or []}
    print("[set] %s  %d tris" % (rel, REPORT[rel]["tris"]))
    L.clear_scene()


# =================================================================================================
# architecture
# =================================================================================================

def arch_room(room):
    d = H3["rooms"][room]
    x0, x1 = ROOM_X[room]
    pb = PB(room + "_arch", room)
    outdoor = bool(d.get("outdoor", False))
    # back wall: one flat field (+ the porch's sky with two soft cloud bands)
    pb.box((x0, 0.0, BACK - 0.1), (x1, ROOM_H, BACK), "wall")
    wh = float(d.get("wainscot_h_m", 0.9))
    if wh > 0:
        pb.box((x0, 0.0, BACK), (x1, wh, BACK + 0.03), "wainscot")
        pb.box((x0, wh - 0.02, BACK), (x1, wh + 0.02, BACK + 0.045), "rail", bevel=0.008)
    rh = float(d.get("rail_h_m", 2.2))
    if rh > 0:
        pb.box((x0, rh - 0.025, BACK), (x1, rh + 0.025, BACK + 0.045), "rail", bevel=0.01)
    if outdoor:
        pb.box((x0, 0.0, BACK + 0.001), (x1, 0.95, BACK + 0.02), "wainscot")
        for (cx, cy, w) in ((x0 + 0.6, 2.55, 0.9), (x0 + 1.8, 2.25, 0.7)):
            pb.sphere(0.2, (cx, cy, BACK + 0.03), "cloud", scale=(w / 0.4, 0.55, 0.15), seg=14, rings=7)
    # skirting + floor boards (plain, two tones, running along x) from the back wall to the lip
    if not outdoor:
        pb.box((x0, 0.0, BACK), (x1, 0.1, BACK + 0.04), "skirt", bevel=0.008)
    rows = 6
    depth = LIP - BACK
    for i in range(rows):
        za = BACK + depth * i / rows
        zb = BACK + depth * (i + 1) / rows
        pb.box((x0, -0.04, za), (x1, 0.0, zb - 0.004), "floor_a" if i % 2 == 0 else "floor_b")
    # built-ins
    for bid, bd in d.get("built_ins", {}).items():
        if bd.get("with"):
            continue
        builtin(pb, room, bid, bd)
    root = pb.finish()
    extra = []
    # the front door's leaf is its own object (it swings open for the exit)
    for bid, bd in d.get("built_ins", {}).items():
        if "leaf" in bd:
            lp = PB(room + "_leaf", room)
            lf = bd["leaf"]
            lp.box((lf[0], lf[1], lf[2]), (lf[3], lf[4], lf[5]), "door", bevel=0.015)
            lp.box((lf[0] - 0.012, 1.0, (lf[2] + lf[5]) * 0.5 - 0.3), (lf[3] + 0.012, 1.08, (lf[2] + lf[5]) * 0.5 - 0.22), "knocker", bevel=0.01)
            lo = lp.finish()
            lo.name = "leaf"
            lo.parent = root
            extra.append("leaf")
    save(root, "set/%s_arch.glb" % room, extra)


def builtin(pb, room, bid, bd):
    b = bd["box"]
    lo, hi = (b[0], b[1], b[2]), (b[3], b[4], b[5])
    if bid == "kitchen_dresser_base":
        pb.box(lo, (hi[0], hi[1] - 0.05, hi[2]), "counter", bevel=0.02)
        pb.box((lo[0] - 0.02, hi[1] - 0.05, lo[2]), (hi[0] + 0.02, hi[1], hi[2] + 0.03), "worktop", bevel=0.015)
        # two plain doors (one line each)
        mid = (lo[0] + hi[0]) * 0.5
        pb.box((mid - 0.006, 0.08, hi[2]), (mid + 0.006, hi[1] - 0.1, hi[2] + 0.006), "counter_dk")
        for kx in (mid - 0.07, mid + 0.07):
            pb.sphere(0.018, (kx, 0.5, hi[2] + 0.015), "handle", seg=10, rings=6)
        pb.box((lo[0], 0.0, hi[2] - 0.04), (hi[0], 0.08, hi[2] + 0.004), "counter_dk")
    elif bid == "kitchen_dresser_rack":
        pb.box(lo, hi, "rack", bevel=0.02)
        pb.box((lo[0] + 0.05, lo[1] + 0.08, hi[2]), (hi[0] - 0.05, hi[1] - 0.08, hi[2] + 0.004), "shelf")
        pb.box((lo[0] - 0.03, hi[1] - 0.05, lo[2]), (hi[0] + 0.03, hi[1], hi[2] + 0.04), "shelf", bevel=0.012)
    elif bid in ("kitchen_honey_shelf", "kitchen_pickle_shelf"):
        pb.box(lo, hi, "shelf", bevel=0.008)
        for bx in (lo[0] + 0.08, hi[0] - 0.08):
            pb.box((bx - 0.02, lo[1] - 0.14, BACK), (bx + 0.02, lo[1], BACK + 0.14), "shelf", bevel=0.006)
    elif bid == "kitchen_sink_unit":
        bs = bd["basin"]
        top = hi[1]
        pb.box(lo, (hi[0], bs[1], hi[2]), "counter", bevel=0.02)
        pb.box((lo[0], bs[1], lo[2]), (bs[0], top - 0.05, hi[2]), "counter", bevel=0.0)
        pb.box((bs[3], bs[1], lo[2]), (hi[0], top - 0.05, hi[2]), "counter", bevel=0.0)
        pb.box((bs[0], bs[1], lo[2]), (bs[3], top - 0.05, bs[2]), "counter", bevel=0.0)
        # the Belfast basin: white walls around the hollow + its floor, a thick front lip that hides his seat
        pb.box((bs[0], bs[1], bs[5]), (bs[3], top + 0.02, hi[2] + 0.02), "basin", bevel=0.02)
        pb.box((bs[0], bs[1] - 0.02, bs[2]), (bs[3], bs[1] + 0.02, bs[5]), "basin_in")
        pb.box((bs[0] - 0.03, bs[1], bs[2] - 0.03), (bs[0], top + 0.02, bs[5] + 0.02), "basin", bevel=0.01)
        pb.box((bs[3], bs[1], bs[2] - 0.03), (bs[3] + 0.03, top + 0.02, bs[5] + 0.02), "basin", bevel=0.01)
        # worktop either side of the basin
        pb.box((lo[0] - 0.02, top - 0.05, lo[2]), (bs[0] - 0.03, top, hi[2] + 0.03), "worktop", bevel=0.012)
        pb.box((bs[3] + 0.03, top - 0.05, lo[2]), (hi[0] + 0.02, top, hi[2] + 0.03), "worktop", bevel=0.012)
        pb.box((lo[0], 0.0, hi[2] - 0.04), (hi[0], 0.08, hi[2] + 0.004), "counter_dk")
    elif bid == "parlour_fireplace":
        fb = bd["firebox"]
        pb.box(lo, (fb[0], hi[1], hi[2]), "stone", bevel=0.02)
        pb.box((fb[3], lo[1], lo[2]), hi, "stone", bevel=0.02)
        pb.box((fb[0], fb[4], lo[2]), (fb[3], hi[1], hi[2]), "stone", bevel=0.015)
        pb.box((fb[0], 0.0, lo[2]), (fb[3], fb[4], fb[2]), "firebox")
        pb.box((fb[0] + 0.03, 0.0, fb[2]), (fb[3] - 0.03, 0.03, hi[2] + 0.06), "stone_dk", bevel=0.01)
        pb.box((lo[0] - 0.04, 0.0, hi[2]), (hi[0] + 0.04, 0.06, hi[2] + 0.12), "stone_dk", bevel=0.015)
    elif bid == "parlour_mantel":
        pb.box(lo, hi, "mantel", bevel=0.02)
    elif bid == "hall_stairs":
        n = int(bd.get("steps", 3))
        for i in range(n):
            zf = hi[2] - (hi[2] - lo[2]) * i / n
            pb.box((lo[0], 0.0, lo[2]), (hi[0], (hi[1]) * (i + 1) / n, zf), "stair", bevel=0.012)
            pb.box((lo[0] - 0.01, (hi[1]) * (i + 1) / n - 0.025, zf - 0.03), (hi[0] + 0.01, (hi[1]) * (i + 1) / n, zf + 0.012), "stair_dk", bevel=0.006)
        pb.box((lo[0] - 0.05, 0.0, BACK - 0.02), (hi[0] + 0.05, 2.25, BACK + 0.002), "stair_void")
        pb.box((lo[0] - 0.09, 0.0, BACK), (lo[0] - 0.03, 2.3, BACK + 0.06), "stair_dk", bevel=0.01)
        pb.box((hi[0] + 0.03, 0.0, BACK), (hi[0] + 0.09, 2.3, BACK + 0.06), "stair_dk", bevel=0.01)
    elif bid == "hall_front_door_flat":
        lf = bd["leaf"]
        pb.box(lo, (hi[0], hi[1], lf[2]), "door_frame")
        pb.box((lo[0], lo[1], lf[5]), hi, "door_frame")
        pb.box((lo[0], lf[4], lf[2]), (hi[0], hi[1], lf[5]), "door_frame")
    elif bid == "porch_step":
        pb.box(lo, hi, "step", bevel=0.015)
    elif bid == "porch_hedge":
        for i in range(4):
            cx = lo[0] + (hi[0] - lo[0]) * (i + 0.5) / 4
            pb.sphere(0.32, (cx, 0.62 + 0.08 * (i % 2), (lo[2] + hi[2]) * 0.5), "hedge" if i % 2 else "hedge_dk", scale=(1.1, 1.0, 0.7), seg=14, rings=8)
        pb.box((lo[0], 0.0, lo[2]), (hi[0], 0.55, hi[2]), "hedge_dk", bevel=0.05)
    elif bid == "porch_no9_door":
        pb.box((lo[0] - 0.08, 0.0, lo[2]), (hi[0] + 0.08, hi[1] + 0.1, hi[2] + 0.02), "no9_frame")
        pb.box(lo, (hi[0], hi[1], hi[2] + 0.04), "no9_door", bevel=0.01)
    else:
        pb.box(lo, hi, "wainscot" if "wainscot" in L.P.PALETTES[room] else "wall", bevel=0.01)


def conditional_builtins():
    for room, d in H3["rooms"].items():
        for bid, bd in d.get("built_ins", {}).items():
            if not bd.get("with") or not want(bid):
                continue
            pb = PB(bid, room)
            builtin(pb, room, bid, bd)
            save(pb.finish(), "set/%s.glb" % bid)


# =================================================================================================
# furniture, dressing, decor (room palettes; local origin = bottom centre)
# =================================================================================================

def piece(pid, d, kind):
    room = d["room"]
    b = d.get("box", [-0.2, 0.0, -0.2, 0.2, 0.4, 0.2])
    lo, hi = (b[0], b[1], b[2]), (b[3], b[4], b[5])
    w, h, dz = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    prim = d.get("primitive", "box")
    pb = PB(pid, room)
    C = L.P.PALETTES[room]

    def c(name, alt):
        return name if name in C else alt
    if prim == "stool":
        r = w * 0.5
        pb.cyl(r, r, 0.06, (0, h - 0.06, 0), c("stool", "wall"), seg=24)
        pb.cyl(r * 0.96, r, 0.015, (0, h - 0.075, 0), c("stool_dk", "wall"), seg=24)
        for i in range(3):
            a = 2 * math.pi * i / 3 + 0.5
            pb.cyl(0.032, 0.026, h - 0.06, (math.cos(a) * r * 0.6, 0, math.sin(a) * r * 0.6), c("stool_dk", "wall"), seg=10,
                   rot=(math.degrees(math.sin(a)) * 0.25, 0, -math.degrees(math.cos(a)) * 0.25))
        pb.torus(r * 0.55, 0.012, (0, h * 0.35, 0), c("stool_dk", "wall"), seg=18, rseg=5)
    elif prim == "table":
        pb.box((lo[0], h - 0.05, lo[2]), (hi[0], h, hi[2]), c("table", "wall"), bevel=0.015)
        pb.box((lo[0] + 0.04, h - 0.18, lo[2] + 0.04), (hi[0] - 0.04, h - 0.05, hi[2] - 0.04), c("table_dk", "wall"), bevel=0.01)
        for sx in (lo[0] + 0.06, hi[0] - 0.06):
            for sz in (lo[2] + 0.06, hi[2] - 0.06):
                pb.cyl(0.022, 0.016, h - 0.05, (sx, 0, sz), c("table_dk", "wall"), seg=8)
    elif prim == "window":
        pb.box((lo[0], 0.0, lo[2]), (hi[0], h, hi[2]), "window_frame", bevel=0.015)
        pb.box((lo[0] + 0.07, 0.07, hi[2] - 0.005), (hi[0] - 0.07, h - 0.07, hi[2] + 0.004), "pane")
        mx = (lo[0] + hi[0]) * 0.5
        pb.box((mx - 0.02, 0.07, hi[2]), (mx + 0.02, h - 0.07, hi[2] + 0.015), "window_frame")
        pb.box((lo[0] + 0.07, h * 0.5 - 0.02, hi[2]), (hi[0] - 0.07, h * 0.5 + 0.02, hi[2] + 0.015), "window_frame")
        pb.box((lo[0] - 0.04, -0.03, hi[2] - 0.01), (hi[0] + 0.04, 0.02, hi[2] + 0.06), "window_frame", bevel=0.01)
    elif prim == "lamp":
        pb.cyl(0.006, 0.006, 3.2 - (2.4 + 0.2) + 0.2, (0, 0.2, 0), "cord", seg=6)
        pb.lathe([(0.06, 0.2), (0.07, 0.17), (w * 0.5, 0.02), (w * 0.5, 0.0)], (0, 0, 0), "lamp_shade", seg=24, cap_bottom=False)
        pb.sphere(0.045, (0, 0.03, 0), "lamp_glow", seg=10, rings=6)
    elif prim == "pan_rail":
        pb.box((lo[0], h - 0.03, -0.015), (hi[0], h, 0.015), "pan_rail", bevel=0.006)
        for i, (r, dy) in enumerate(((0.12, 0.2), (0.1, 0.18), (0.085, 0.16))):
            x = lo[0] + 0.15 + i * (w - 0.3) / 2
            pb.cyl(0.006, 0.006, 0.06, (x, h - 0.09, 0), "pan_rail", seg=5)
            pb.cyl(r, r, 0.03, (x, h - 0.1 - r, -0.02), "pan" if i % 2 == 0 else "pan_dk", seg=20, rot=(90, 0, 0))
            pb.box((x - 0.012, h - 0.1 - 2 * r - 0.14, -0.02), (x + 0.012, h - 0.1 - 2 * r + 0.01, 0.0), "pan_dk")
    elif prim == "frame":
        col = c("frame_gold", "window_frame")
        pb.box((lo[0], 0.0, lo[2]), (hi[0], h, hi[2]), col, bevel=0.015)
        pb.box((lo[0] + 0.06, 0.06, hi[2] - 0.004), (hi[0] - 0.06, h - 0.06, hi[2] + 0.004), c("canvas", col))
        if pid == "parlour_portrait":
            # a calm portrait: an oval head-and-shoulders silhouette in the canvas's own family (low contrast)
            pb.sphere(0.12, (0.0, h * 0.6, hi[2] + 0.006), c("canvas_face", col), scale=(1.0, 1.25, 0.08), seg=16, rings=8)
            pb.sphere(0.2, (0.0, h * 0.2, hi[2] + 0.006), c("canvas_face", col), scale=(1.2, 0.55, 0.06), seg=16, rings=8)
    elif prim == "basket":
        pb.lathe([(w * 0.42, 0.0), (w * 0.47, 0.05), (w * 0.5, h)], (0, 0, 0), "basket", seg=20, cap_top=False)
        pb.torus(w * 0.5, 0.02, (0, h, 0), "basket", seg=20, rseg=5)
        for i in range(3):
            pb.cyl(0.05, 0.05, w * 0.8, (-w * 0.4, h * 0.75 + 0.02 * i, -0.08 + 0.08 * i), "log", seg=8, rot=(0, 0, -90))
    elif prim == "coat_stand":
        pb.cyl(0.028, 0.024, h, (0, 0, 0), "coat_stand", seg=10)
        for i in range(3):
            a = 2 * math.pi * i / 3 + 0.3
            pb.cyl(0.02, 0.016, 0.24, (0, 0.02, 0), "coat_stand", seg=6, rot=(math.degrees(math.sin(a)) * 1.2, 0, -math.degrees(math.cos(a)) * 1.2))
            pb.cyl(0.012, 0.01, 0.16, (0, h - 0.12, 0), "coat_stand", seg=6, rot=(math.degrees(math.sin(a + 1)) * 0.9, 0, -math.degrees(math.cos(a + 1)) * 0.9))
        pb.sphere(0.045, (0, h, 0), "coat_stand", seg=10, rings=6)
    elif prim == "hats":
        pb.cyl(0.17, 0.17, 0.02, (-0.12, 0.0, 0), "hat_a", seg=20)
        pb.cyl(0.095, 0.1, 0.13, (-0.12, 0.02, 0), "hat_a", seg=20)
        pb.sphere(0.12, (0.15, 0.08, 0), "hat_b", scale=(1.2, 0.75, 1.2), seg=16, rings=8)
        pb.cyl(0.15, 0.15, 0.015, (0.15, 0.03, 0), "hat_b", seg=18)
    elif prim == "vase":
        pb.lathe([(0.06, 0.0), (0.1, 0.04), (0.14, 0.2), (0.12, 0.34), (0.07, 0.44), (0.09, 0.54)], (0, 0, 0), "vase",
                 seg=20, bands=["vase", "vase", "vase_band", "vase", "vase"], cap_top=False)
    elif prim == "shards":
        for i, (x, zz, s) in enumerate(((-0.2, 0.0, 0.07), (-0.05, 0.05, 0.09), (0.1, -0.03, 0.06), (0.22, 0.04, 0.05))):
            pb.box((x - s, 0.0, zz - s * 0.7), (x + s, 0.05, zz + s * 0.7), "vase" if i % 2 else "vase_band", bevel=0.01, rot=(0, i * 37, 8 * i))
    elif prim == "fire":
        pb.box((-0.26, 0.0, -0.06), (0.26, 0.08, 0.06), "log", bevel=0.02, rot=(0, 8, 0))
        pb.box((-0.24, 0.05, -0.05), (0.24, 0.12, 0.05), "log", bevel=0.02, rot=(0, -12, 0))
        for i, (x, hh) in enumerate(((-0.12, 0.3), (0.0, 0.42), (0.13, 0.28))):
            pb.cyl(0.07, 0.0, hh, (x, 0.08, 0.0), "flame" if i != 1 else "ember", seg=10)
    else:
        pb.box(lo, hi, c("wainscot", "wall"), bevel=0.01)
    save(pb.finish(), "set/" + os.path.basename(d["model"]).replace("res://art3d/set/", ""))


def pieces():
    for kind in ("furniture", "dressing", "decor"):
        for pid, d in H3.get(kind, {}).items():
            m = d.get("model")
            if not m or not str(m).startswith("res://art3d/set/") or not want(pid):
                continue
            piece(pid, d, kind)


# =================================================================================================
# live props (the props palette; one skinned mesh each; local prop frame = house3d.json bounds, before scale)
# =================================================================================================

def prop_honey_jar():
    pb = PB("honey_jar", "props")
    # a big squat pot of honey with a cream label, the red lid (a part), the tall pepper pot beside it (a part)
    pb.lathe([(0.075, 0.0), (0.095, 0.012), (0.105, 0.04), (0.105, 0.11), (0.095, 0.13), (0.083, 0.14), (0.083, 0.15)],
             (0, 0, 0), "honey", seg=26, bands=["honey_dk", "honey", "honey", "honey", "honey_dk", "honey_dk"])
    pb.lathe([(0.1065, 0.058), (0.1065, 0.098)], (0, 0, 0), "honey_label", seg=26, cap_bottom=False, cap_top=False)
    pb.part("lid", pivot=(0.09, 0.15, 0.0))
    pb.lathe([(0.0, 0.15), (0.093, 0.15), (0.096, 0.162), (0.08, 0.171), (0.0, 0.173)], (0, 0, 0), "honey_lid", seg=26)
    pb.sphere(0.021, (0.0, 0.18, 0.0), "honey_lid", seg=10, rings=6)
    pb.part("pepper_pot", pivot=(-0.2, 0.0, 0.0))
    pb.lathe([(0.036, 0.0), (0.05, 0.024), (0.054, 0.16), (0.043, 0.215), (0.036, 0.235)], (-0.2, 0, 0), "pepper", seg=18)
    pb.lathe([(0.038, 0.235), (0.043, 0.253), (0.027, 0.29), (0.0, 0.296)], (-0.2, 0, 0), "pepper_cap", seg=18)
    for i in range(5):
        a = 2 * math.pi * i / 5
        pb.sphere(0.006, (-0.2 + 0.015 * math.cos(a), 0.288, 0.015 * math.sin(a)), "pepper", seg=6, rings=4)
    pb.part("armed", pivot=(0.0, 0.15, 0.0))
    for i in range(10):
        a = 2 * math.pi * i / 10 + 0.3
        pb.sphere(0.011, (0.088 * math.cos(a), 0.151, 0.088 * math.sin(a)), "pepper_grain", seg=6, rings=4)
    for (x, y, z) in ((-0.035, 0.2, 0.02), (0.025, 0.225, -0.01), (0.0, 0.25, 0.035)):
        pb.sphere(0.015, (x, y, z), "pepper_grain", seg=6, rings=4)
    return pb


def prop_kettle():
    pb = PB("kettle", "props")
    pb.lathe([(0.07, 0.0), (0.1, 0.02), (0.112, 0.07), (0.1, 0.13), (0.06, 0.16), (0.03, 0.165)], (0, 0, 0), "copper",
             seg=24, bands=["copper_dk", "copper", "copper", "copper", "copper"])
    # the spout (toward -x) and the arched handle
    pb.cyl(0.028, 0.014, 0.13, (-0.08, 0.05, 0.0), "copper", seg=10, rot=(0, 0, 58))
    pb.torus(0.07, 0.012, (0.0, 0.17, 0.0), "copper_dk", seg=18, rseg=6, rot=(90, 0, 0), scale=(1.0, 1.0, 0.9))
    pb.part("lid", pivot=(0.03, 0.165, 0.0))
    pb.lathe([(0.0, 0.165), (0.045, 0.165), (0.04, 0.18), (0.0, 0.185)], (0, 0, 0), "copper_dk", seg=18)
    pb.sphere(0.014, (0.0, 0.195, 0.0), "kettle_knob", seg=8, rings=5)
    pb.part("armed", pivot=(-0.14, 0.12, 0.0))
    pb.sphere(0.022, (-0.148, 0.13, 0.0), "squeaker", seg=10, rings=6)
    pb.cyl(0.009, 0.004, 0.04, (-0.148, 0.145, 0.0), "squeaker", seg=6, rot=(0, 0, 40))
    return pb


def prop_pickle_jar():
    pb = PB("pickle_jar", "props")
    # a pot-bellied jar with a narrow neck and a small gold lid (a waisted top at 64 px: not the piano's box)
    pb.lathe([(0.05, 0.0), (0.068, 0.012), (0.08, 0.07), (0.078, 0.11), (0.062, 0.145), (0.042, 0.165), (0.04, 0.19)],
             (0, 0, 0), "pickle", seg=22, bands=["pickle_dk", "pickle", "pickle", "pickle", "pickle_dk", "pickle_dk"])
    for i, (x, y, z) in enumerate(((-0.03, 0.04, 0.052), (0.03, 0.07, 0.056), (-0.012, 0.1, 0.062), (0.028, 0.125, 0.046))):
        pb.sphere(0.022, (x, y, z), "onion", seg=10, rings=6)
    pb.part("lid", pivot=(0.0, 0.19, 0.0))
    pb.lathe([(0.0, 0.19), (0.05, 0.19), (0.052, 0.2), (0.05, 0.222), (0.0, 0.225)], (0, 0, 0), "gold_lid", seg=22)
    pb.part("armed", pivot=(0.05, 0.205, 0.0))
    pb.box((0.05, 0.19, -0.008), (0.078, 0.215, 0.008), "spanner")
    pb.box((0.066, 0.06, -0.006), (0.078, 0.2, 0.006), "spanner", rot=(0, 0, -8), pivot=(0.072, 0.2, 0))
    return pb


def prop_sink_tap():
    pb = PB("sink_tap", "props")
    # a tall chrome gooseneck standing right of the basin, arching left over it
    pb.cyl(0.03, 0.03, 0.02, (0.0, 0.0, 0.0), "chrome_dk", seg=16)
    pb.cyl(0.018, 0.016, 0.2, (0.0, 0.02, 0.0), "chrome", seg=12)
    pb.torus(0.07, 0.016, (-0.07, 0.22, 0.0), "chrome", seg=20, rseg=6, rot=(90, 0, 0), arc=0.5)
    pb.part("head", pivot=(-0.14, 0.2, 0.0))
    pb.cyl(0.022, 0.016, 0.05, (-0.14, 0.17, 0.0), "chrome_dk", seg=10)
    pb.part("knob", pivot=(0.0, 0.08, 0.05))
    pb.cyl(0.012, 0.012, 0.04, (0.0, 0.08, 0.0), "chrome", seg=8, rot=(90, 0, 0))
    pb.sphere(0.026, (0.0, 0.08, 0.055), "tap_knob", seg=12, rings=7)
    pb.part("armed", pivot=(-0.14, 0.16, 0.0))
    pb.lathe([(0.012, 0.0), (0.045, -0.035), (0.05, -0.045), (0.0, -0.05)], (-0.14, 0.17, 0.0), "spray", seg=14)
    for i in range(3):
        pb.sphere(0.009, (-0.15 + 0.012 * i, 0.09 - 0.02 * i, 0.01), "spray", seg=6, rings=4)
    return pb


def prop_fridge():
    pb = PB("fridge", "props")
    # a SQUAT retro fridge (1.52 m: its 64 px silhouette must not read as the pantry alcove or the wardrobe):
    # a domed top, four stubby legs, two doors split at 0.81 m, a chrome bar handle per door
    for (x, z) in ((-0.3, -0.2), (0.3, -0.2), (-0.3, 0.17), (0.3, 0.17)):
        pb.box((x - 0.035, 0.0, z - 0.035), (x + 0.035, 0.13, z + 0.035), "fridge_dk", bevel=0.01)
    pb.box((-0.38, 0.12, -0.27), (0.38, 1.3, 0.25), "fridge", bevel=0.07)
    pb.sphere(0.38, (0.0, 1.26, -0.01), "fridge", scale=(1.0, 0.68, 0.69), seg=24, rings=12)
    pb.box((-0.37, 0.79, 0.24), (0.37, 0.83, 0.262), "fridge_dk", bevel=0.01)
    pb.part("door_upper", pivot=(-0.37, 1.08, 0.26))
    pb.box((-0.35, 0.85, 0.25), (0.35, 1.3, 0.27), "fridge", bevel=0.03)
    pb.box((0.23, 0.9, 0.27), (0.27, 1.16, 0.3), "fridge_bar", bevel=0.012)
    pb.part("door_lower", pivot=(-0.37, 0.45, 0.26))
    pb.box((-0.35, 0.16, 0.25), (0.35, 0.77, 0.27), "fridge", bevel=0.03)
    pb.box((0.23, 0.5, 0.27), (0.27, 0.72, 0.3), "fridge_bar", bevel=0.012)
    pb.part("armed", pivot=(0.3, 0.82, 0.27))
    pb.cyl(0.035, 0.035, 0.1, (0.2, 0.815, 0.24), "sausage", seg=10, rot=(90, 0, 0))
    pb.sphere(0.036, (0.2, 0.815, 0.335), "sausage", seg=10, rings=6)
    return pb


def prop_pantry():
    pb = PB("pantry", "props")
    # the dark arched alcove (jambs, arch, a shelf of tins high up) and the gathered curtain (a part)
    pb.box((-0.42, 0.0, -0.25), (0.42, 2.45, -0.2), "alcove")
    pb.box((-0.42, 0.0, -0.25), (-0.34, 2.2, 0.2), "jamb", bevel=0.02)
    pb.box((0.34, 0.0, -0.25), (0.42, 2.2, 0.2), "jamb", bevel=0.02)
    pb.box((-0.42, 2.2, -0.25), (0.42, 2.45, 0.2), "jamb", bevel=0.02)
    pb.torus(0.34, 0.04, (0.0, 2.2, 0.17), "jamb", seg=24, rseg=6, rot=(90, 0, 0), scale=(1.0, 1.0, 0.45))
    pb.box((-0.34, 1.8, -0.2), (0.34, 1.83, 0.05), "shelf_dark")
    pb.box((-0.34, 2.05, -0.2), (0.34, 2.08, 0.05), "shelf_dark")
    for i, col in enumerate(("tin_a", "tin_b", "tin_a", "tin_b")):
        pb.cyl(0.045, 0.045, 0.12, (-0.24 + 0.16 * i, 1.83, -0.08), col, seg=12)
    pb.cyl(0.012, 0.012, 0.72, (-0.36, 1.72, 0.15), "jamb", seg=8, rot=(0, 0, -90))
    pb.part("curtain", pivot=(0.0, 1.72, 0.15))
    pb.curtain(0.68, 1.66, (0.0, 1.72, 0.15), "curtain", folds=5, amp=0.035, thick=0.03)
    for i in range(6):
        pb.sphere(0.018, (-0.3 + 0.12 * i, 1.715, 0.15), "curtain_dk", seg=8, rings=5)
    return pb


def prop_gramophone():
    pb = PB("gramophone", "props")
    # cabinet + box + record + a big horn; the lever with a big red knob on the left side (in the reach row)
    pb.box((-0.17, 0.0, -0.15), (0.17, 0.47, 0.15), "cabinet", bevel=0.025)
    pb.box((-0.15, 0.05, 0.145), (0.15, 0.4, 0.155), "cabinet_dk", bevel=0.01)
    pb.box((-0.16, 0.47, -0.14), (0.16, 0.6, 0.14), "cabinet_dk", bevel=0.02)
    pb.cyl(0.12, 0.12, 0.012, (0.0, 0.6, 0.0), "record", seg=24)
    pb.cyl(0.035, 0.035, 0.014, (0.0, 0.606, 0.0), "label", seg=12)
    pb.part("horn", pivot=(0.06, 0.62, -0.03))
    pb.cyl(0.012, 0.012, 0.12, (0.06, 0.6, -0.03), "horn_dk", seg=8)
    # a closed, double-walled horn (an open shell would show its ink hull from inside)
    pb.lathe([(0.015, 0.0), (0.025, 0.1), (0.05, 0.28), (0.1, 0.4), (0.16, 0.46), (0.175, 0.475), (0.165, 0.48),
              (0.15, 0.462), (0.09, 0.405), (0.042, 0.29), (0.017, 0.11), (0.008, 0.02)], (0.06, 0.72, -0.03), "horn",
             seg=24, rot=(0, 0, 8), bands=["horn_dk", "horn", "horn", "horn", "horn", "horn_dk", "horn_dk", "horn_dk", "horn_dk", "horn_dk", "horn_dk"],
             cap_top=False, cap_bottom=True)
    pb.part("lever", pivot=(-0.133, 0.54, 0.15))
    pb.box((-0.14, 0.53, 0.14), (-0.126, 0.55, 0.2), "lever")
    pb.cyl(0.009, 0.009, 0.13, (-0.133, 0.54, 0.2), "lever", seg=8)
    pb.sphere(0.034, (-0.133, 0.667, 0.217), "knob_red", seg=12, rings=7)
    pb.part("armed", pivot=(0.0, 0.53, 0.145))
    pb.box((-0.06, 0.505, 0.14), (0.06, 0.565, 0.152), "sticker", bevel=0.004)
    return pb


def prop_piano():
    pb = PB("piano", "props")
    # the black upright block, ivory keys, a music desk; Hush hides in the gap behind it
    pb.box((-0.38, 0.0, -0.24), (0.38, 1.05, 0.24), "piano", bevel=0.03)
    pb.box((-0.36, 0.62, 0.24), (0.36, 0.7, 0.34), "piano", bevel=0.015)
    pb.box((-0.34, 0.7, 0.26), (0.34, 0.73, 0.34), "keys")
    for i in range(12):
        x = -0.31 + 0.055 * i
        if i % 7 in (2, 6):
            continue
        pb.box((x, 0.73, 0.26), (x + 0.02, 0.745, 0.31), "keys_blk")
    pb.box((-0.2, 1.05, -0.02), (0.2, 1.2, 0.02), "piano_hi", bevel=0.01)
    pb.box((-0.36, 0.0, 0.2), (-0.3, 0.62, 0.34), "piano", bevel=0.01)
    pb.box((0.3, 0.0, 0.2), (0.36, 0.62, 0.34), "piano", bevel=0.01)
    return pb


def prop_recliner():
    pb = PB("recliner", "props")
    pb.box((-0.38, 0.1, -0.31), (0.38, 0.42, 0.31), "recliner", bevel=0.07)
    pb.box((-0.38, 0.4, -0.31), (0.38, 0.95, -0.1), "recliner", bevel=0.08, rot=(-14, 0, 0), pivot=(0, 0.42, -0.2))
    pb.box((-0.38, 0.2, -0.3), (-0.24, 0.6, 0.31), "recliner_dk", bevel=0.06)
    pb.box((0.24, 0.2, -0.3), (0.38, 0.6, 0.31), "recliner_dk", bevel=0.06)
    for sx in (-0.32, 0.32):
        for sz in (-0.24, 0.24):
            pb.cyl(0.025, 0.02, 0.1, (sx, 0.0, sz), "brass", seg=8)
    pb.part("key", pivot=(0.1, 0.28, 0.3))
    pb.cyl(0.012, 0.012, 0.06, (0.1, 0.28, 0.28), "brass", seg=8, rot=(90, 0, 0))
    pb.box((0.06, 0.26, 0.33), (0.14, 0.3, 0.345), "brass", bevel=0.008)
    pb.part("armed", pivot=(0.0, 0.1, 0.3))
    for i in range(4):
        pb.torus(0.07, 0.012, (0.0, 0.03 + 0.025 * i, 0.26), "spring", seg=14, rseg=5)
    return pb


def prop_newspaper():
    pb = PB("newspaper", "props")
    pb.box((-0.1, 0.0, -0.05), (0.1, 0.12, -0.03), "paper", bevel=0.004, rot=(-18, 0, 0), pivot=(0, 0, -0.04))
    pb.box((-0.1, 0.0, 0.02), (0.1, 0.11, 0.04), "paper", bevel=0.004, rot=(14, 0, 0), pivot=(0, 0, 0.03))
    pb.box((-0.08, 0.08, 0.04), (0.08, 0.1, 0.046), "print", rot=(14, 0, 0), pivot=(0, 0, 0.03))
    pb.box((-0.08, 0.03, 0.04), (0.02, 0.06, 0.046), "print", rot=(14, 0, 0), pivot=(0, 0, 0.03))
    pb.part("armed", pivot=(0.1, 0.06, 0.0))
    pb.cyl(0.01, 0.01, 0.1, (0.1, 0.06, 0.0), "magnifier", seg=8, rot=(0, 0, -75))
    return pb


def prop_chandelier():
    pb = PB("chandelier", "props")
    pb.torus(0.32, 0.03, (0.0, 0.2, 0.0), "chandelier", seg=24, rseg=6)
    pb.cyl(0.01, 0.01, 0.6, (0.0, 0.2, 0.0), "chandelier", seg=6)
    for i in range(6):
        a = 2 * math.pi * i / 6
        pb.cyl(0.02, 0.02, 0.1, (math.cos(a) * 0.32, 0.22, math.sin(a) * 0.32), "candle", seg=8)
        pb.cyl(0.004, 0.004, 0.2, (0.0, 0.2, 0.0), "chandelier", seg=4, rot=(math.degrees(math.sin(a)) * 1.2, 0, -math.degrees(math.cos(a)) * 1.2))
    return pb


def prop_wardrobe():
    pb = PB("wardrobe", "props")
    # a narrow tall wardrobe on bun feet with a broken-pediment crown (its silhouette: feet + a peaked top)
    for x in (-0.28, 0.28):
        for z in (-0.2, 0.18):
            pb.sphere(0.05, (x, 0.05, z), "wardrobe_dk", seg=10, rings=6)
    pb.box((-0.32, 0.1, -0.26), (0.32, 1.9, 0.24), "wardrobe", bevel=0.03)
    pb.box((-0.36, 1.88, -0.27), (0.36, 1.96, 0.27), "wardrobe_dk", bevel=0.02)
    pb.panel([(-0.34, 1.96), (0.34, 1.96), (0.0, 2.2)], -0.25, 0.5, "wardrobe_dk")
    pb.part("door", pivot=(-0.31, 1.0, 0.25))
    pb.box((-0.3, 0.16, 0.23), (0.0, 1.84, 0.26), "wardrobe", bevel=0.015)
    pb.box((0.0, 0.16, 0.244), (0.02, 1.84, 0.262), "gap_dark")
    pb.sphere(0.022, (-0.04, 1.0, 0.27), "brass", seg=8, rings=5)
    pb.box((0.02, 0.16, 0.23), (0.3, 1.84, 0.25), "wardrobe", bevel=0.015)
    return pb


def prop_crate():
    pb = PB("crate", "props")
    pb.box((-0.23, 0.0, -0.17), (0.23, 0.38, 0.17), "crate", bevel=0.02)
    for x in (-0.23, 0.2):
        pb.box((x, 0.0, -0.172), (x + 0.03, 0.38, 0.172), "crate_dk")
    pb.box((-0.235, 0.14, -0.175), (0.235, 0.24, 0.175), "band", bevel=0.005)
    pb.box((-0.16, 0.165, 0.175), (0.16, 0.215, 0.18), "stencil")
    pb.part("lid", pivot=(0.0, 0.38, -0.17))
    pb.box((-0.235, 0.38, -0.175), (0.235, 0.41, 0.175), "crate_dk", bevel=0.01)
    return pb


def prop_phone():
    pb = PB("phone", "props")
    pb.lathe([(0.06, 0.0), (0.07, 0.01), (0.065, 0.025), (0.03, 0.035)], (0, 0, 0), "phone", seg=20)
    pb.cyl(0.013, 0.016, 0.2, (0.0, 0.035, 0.0), "phone", seg=10)
    pb.lathe([(0.012, 0.0), (0.035, 0.02), (0.04, 0.045)], (0.0, 0.225, 0.015), "phone_hi", seg=16, rot=(-55, 0, 0), cap_top=True)
    pb.part("handset", pivot=(0.07, 0.24, 0.02))
    pb.cyl(0.016, 0.016, 0.1, (0.07, 0.14, 0.03), "phone", seg=10)
    pb.lathe([(0.016, 0.0), (0.028, 0.02), (0.03, 0.03)], (0.07, 0.24, 0.03), "phone_hi", seg=12)
    pb.box((0.05, 0.2, 0.02), (0.09, 0.21, 0.04), "phone_hi")
    pb.part("armed", pivot=(0.04, 0.2, 0.04))
    pb.sphere(0.04, (0.02, 0.2, 0.05), "kipper", scale=(1.6, 0.6, 0.5), seg=12, rings=6)
    pb.cyl(0.02, 0.0, 0.05, (-0.05, 0.2, 0.05), "kipper", seg=6, rot=(0, 0, 90))
    return pb


def prop_mirror():
    pb = PB("mirror", "props")
    # an oval cheval mirror on a stand (the glass is a part: the armed look lifts it out)
    pb.torus(0.28, 0.035, (0.0, 1.3, 0.0), "mirror_gold", seg=28, rseg=6, rot=(90, 0, 0), scale=(1.0, 1.0, 1.55))
    pb.cyl(0.02, 0.02, 1.0, (-0.31, 0.05, 0.0), "mirror_dk", seg=8)
    pb.cyl(0.02, 0.02, 1.0, (0.31, 0.05, 0.0), "mirror_dk", seg=8)
    pb.box((-0.33, 0.0, -0.18), (-0.27, 0.05, 0.18), "mirror_dk", bevel=0.01)
    pb.box((0.27, 0.0, -0.18), (0.33, 0.05, 0.18), "mirror_dk", bevel=0.01)
    pb.sphere(0.03, (0.0, 2.02, 0.0), "mirror_gold", seg=10, rings=6)
    pb.part("pane", pivot=(0.0, 1.3, 0.0))
    pb.sphere(0.28, (0.0, 1.3, 0.0), "glass", scale=(1.0, 1.55, 0.03), seg=24, rings=10)
    pb.part("armed", pivot=(0.0, 0.8, 0.0))
    for sx in (-0.07, 0.07):
        pb.sphere(0.04, (sx, 0.95, 0.012), "footprint", scale=(0.8, 1.6, 0.1), seg=10, rings=6)
    return pb


def prop_clock():
    pb = PB("clock", "props")
    pb.box((-0.26, 0.0, -0.18), (0.26, 0.12, 0.18), "clock_dk", bevel=0.02)
    pb.box((-0.2, 0.12, -0.15), (0.2, 1.72, 0.15), "clock", bevel=0.025)
    pb.box((-0.12, 0.35, 0.15), (0.12, 1.4, 0.16), "clock_dk", bevel=0.01)
    pb.box((-0.28, 1.72, -0.18), (0.28, 2.34, 0.18), "clock", bevel=0.04)
    pb.box((-0.3, 2.32, -0.19), (0.3, 2.4, 0.19), "clock_dk", bevel=0.02)
    pb.cyl(0.21, 0.21, 0.03, (0.0, 2.05, 0.18), "clock_face", seg=28, rot=(90, 0, 0))
    pb.torus(0.21, 0.018, (0.0, 2.05, 0.2), "clock_dk", seg=28, rseg=5, rot=(90, 0, 0))
    pb.part("hands", pivot=(0.0, 2.05, 0.215))
    pb.box((-0.008, 2.05, 0.21), (0.008, 2.19, 0.218), "clock_hand")
    pb.box((-0.006, 1.95, 0.21), (0.006, 2.05, 0.218), "clock_hand")
    pb.part("pendulum", pivot=(0.0, 1.35, 0.17))
    pb.cyl(0.006, 0.006, 0.7, (0.0, 0.65, 0.162), "brass", seg=6)
    pb.cyl(0.07, 0.07, 0.015, (0.0, 0.6, 0.162), "brass", seg=16, rot=(90, 0, 0))
    pb.part("armed", pivot=(0.24, 1.6, 0.1))
    for i in range(4):
        pb.torus(0.035, 0.008, (0.24 + 0.012 * i, 1.6, 0.12), "spring", seg=10, rseg=4, rot=(0, 0, 90))
    return pb


PROP_BUILDERS = {
    "squat_jar": ("honey_jar", prop_honey_jar), "round_kettle": ("kettle", prop_kettle), "tall_jar": ("pickle_jar", prop_pickle_jar),
    "gooseneck_tap": ("sink_tap", prop_sink_tap), "tall_rounded_box": ("fridge", prop_fridge), "arched_alcove": ("pantry", prop_pantry),
    "big_horn": ("gramophone", prop_gramophone), "upright_block": ("piano", prop_piano), "fat_armchair": ("recliner", prop_recliner),
    "folded_broadsheet": ("newspaper", prop_newspaper), "chandelier": ("chandelier", prop_chandelier),
    "tall_wardrobe": ("wardrobe", prop_wardrobe), "banded_crate": ("crate", prop_crate), "candlestick_phone": ("phone", prop_phone),
    "oval_on_stand": ("mirror", prop_mirror), "tall_case_clock": ("clock", prop_clock),
}


def props():
    for fam, (name, fn) in PROP_BUILDERS.items():
        if not want(name):
            continue
        pb = fn()
        root = pb.finish_skinned()
        save(root, "props/%s.glb" % name, pb.parts)


if __name__ == "__main__":
    L.reset()
    if not ONLY or any(k.endswith("_arch") for k in ONLY):
        for room in H3["rooms"]:
            if want(room + "_arch"):
                arch_room(room)
    conditional_builtins()
    pieces()
    props()
    rp = os.path.join(OUT, "set", "build_report.json")
    old = {}
    if os.path.exists(rp):
        try:
            old = json.load(open(rp))
        except Exception:
            old = {}
    old.update(REPORT)
    json.dump(old, open(rp, "w"), indent=2, sort_keys=True)
    print("[set] BUILD_OK %d pieces" % len(REPORT))
