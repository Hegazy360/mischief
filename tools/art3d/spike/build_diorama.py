"""Build the shared simplified diorama (parlour + kitchen, one floor, dollhouse cutaway) and export
one .glb per piece + layout.json (Godot coordinates) for the scene generator.

Run: blender -b --python build_diorama.py -- <out_dir>
Blender axes: +X along the house, +Y into the screen, +Z up. Props are modelled with their BACK at
local y = 0 extending toward the camera (-Y), origin at floor level, centred in X.
"""
import bpy, sys, os, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mnd3d
from mnd3d import PB

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(os.path.join(OUT, "props"), exist_ok=True)

# ---- house dimensions (metres) --------------------------------------------------------------
H = 3.0            # room height
D = 2.6            # room depth (front edge y=0 .. back wall inner face y=D)
BW = 0.2           # back wall thickness
END = 0.35         # end wall thickness
PX0, PX1 = 0.0, 6.0        # parlour
PT = 0.3                   # partition thickness
KX0, KX1 = PX1 + PT, PX1 + PT + 5.0   # kitchen 6.3 .. 11.3
SLAB = 0.32
CEIL = 0.3
DOOR_H = 2.3
DOOR_Y0, DOOR_Y1 = 0.0, 1.95   # doorway opening in the partition (depth range)
PAR_WIN = (0.8, 2.0, 1.0, 2.45)   # x0 x1 z0 z1
KIT_WIN = (8.75, 9.85, 1.3, 2.35)
PANTRY = (10.05, 11.05, 0.0, 2.3)

pieces = {}   # name -> {"pos": godot xyz, "rot_y": deg, "group": str}


def place(name, x, y, z=0.0, rot=0.0, group="props"):
    # Blender (x, y, z) -> Godot (x, z, -y)
    pieces[name] = {"pos": [round(x, 4), round(z, 4), round(-y, 4)], "rot_y": rot, "group": group}


def wall_with_holes(pb, x0, x1, holes, color, y0=D, y1=D + BW, z0=0.0, z1=H):
    """Back wall slab from x0..x1 with rectangular holes [(hx0, hx1, hz0, hz1)]."""
    xs = sorted({x0, x1, *[h[0] for h in holes], *[h[1] for h in holes]})
    for a, b in zip(xs[:-1], xs[1:]):
        inside = [h for h in holes if h[0] <= a and b <= h[1]]
        if not inside:
            pb.box_min((a, y0, z0), (b, y1, z1), color, bevel=0.0)
        else:
            h = inside[0]
            if h[2] > z0:
                pb.box_min((a, y0, z0), (b, y1, h[2]), color, bevel=0.0)
            if h[3] < z1:
                pb.box_min((a, y0, h[3]), (b, y1, z1), color, bevel=0.0)


def side_walls(pb, x0, x1, wall, skirt, left_partition=False):
    """Room-coloured panels on the inner faces of the end walls / partition (2 cm proud)."""
    T = 0.02
    for side in ("L", "R"):
        is_part = (side == "R" and not left_partition) or (side == "L" and left_partition)
        xa, xb = (x0, x0 + T) if side == "L" else (x1 - T, x1)
        if not is_part:
            pb.box_min((xa, 0.0, 0.0), (xb, D, H), wall, bevel=0.0)
            pb.box_min((xa - (0 if side == "L" else 0.02), 0.0, 0.0), (xb + (0.02 if side == "L" else 0), D, 0.13), skirt, bevel=0.0)
        else:
            pb.box_min((xa, DOOR_Y1, 0.0), (xb, D, H), wall, bevel=0.0)
            pb.box_min((xa, 0.0, DOOR_H), (xb, DOOR_Y1, H), wall, bevel=0.0)
            pb.box_min((xa - (0 if side == "L" else 0.02), DOOR_Y1, 0.0), (xb + (0.02 if side == "L" else 0), D, 0.13), skirt, bevel=0.0)


# ============================================================================================
# SHELL
# ============================================================================================
def build_frame():
    pb = PB("shell_frame")
    X0, X1 = PX0 - END, KX1 + END
    # floor slab (section cut on the front face)
    pb.box_min((X0, -0.28, -SLAB), (X1, D + BW, -0.02), "cut", bevel=0.0)
    pb.box_min((X0, -0.28, -0.02), (PX0, D + BW, 0.0), "cut", bevel=0.0)
    pb.box_min((KX1, -0.28, -0.02), (X1, D + BW, 0.0), "cut", bevel=0.0)
    pb.box_min((X0, -0.28, -0.02), (X1, 0.0, 0.0), "cut", bevel=0.0)
    pb.box_min((PX1, 0.0, -0.02), (KX0, D + BW, 0.0), "cut", bevel=0.0)
    # stage-lip trim along the front edge
    pb.box_min((X0, -0.30, -0.06), (X1, -0.26, 0.0), "trim", bevel=0.005)
    # ceiling band
    pb.box_min((X0, 0.0, H), (X1, D + BW, H + CEIL), "cut", bevel=0.0)
    # end walls
    pb.box_min((X0, 0.0, 0.0), (PX0, D + BW, H), "cut", bevel=0.0)
    pb.box_min((KX1, 0.0, 0.0), (X1, D + BW, H), "cut", bevel=0.0)
    # partition: lintel + back pier + thin front pier (the section edge)
    pb.box_min((PX1, 0.0, DOOR_H), (KX0, D, H), "cut", bevel=0.0)
    pb.box_min((PX1, DOOR_Y1, 0.0), (KX0, D, DOOR_H), "cut", bevel=0.0)
    # door-frame trim on the partition's room-facing sides (reads in perspective)
    # wooden door frame: jamb face on the back pier, lintel soffit, architraves on both room sides
    pb.box_min((PX1 - 0.05, DOOR_Y1 - 0.03, 0.0), (KX0 + 0.05, DOOR_Y1, DOOR_H), "door", bevel=0.008)
    pb.box_min((PX1 - 0.05, DOOR_Y0, DOOR_H - 0.03), (KX0 + 0.05, DOOR_Y1, DOOR_H), "door", bevel=0.008)
    for x, sgn in ((PX1, -1), (KX0, 1)):
        xa, xb = (x - 0.05, x) if sgn < 0 else (x, x + 0.05)
        pb.box_min((xa, DOOR_Y1 - 0.1, 0.0), (xb, DOOR_Y1, DOOR_H + 0.1), "door", bevel=0.01)
        pb.box_min((xa, DOOR_Y0, DOOR_H - 0.03), (xb, DOOR_Y1, DOOR_H + 0.1), "door", bevel=0.01)
    ob = pb.finish()
    place("shell_frame", 0, 0, 0, group="shell")
    return ob


def build_parlour_room():
    pb = PB("room_parlour")
    pb.box_min((PX0, 0.0, -0.02), (PX1, D, 0.0), "par_floor", bevel=0.0)  # sits in the slab recess (no coplanar faces)
    # a few wide floorboards: subtle seams via thin darker strips (only 3, calm)
    wall_with_holes(pb, PX0, PX1, [PAR_WIN[:4]], "par_wall")
    # dado panel + rail + skirting (protrude from the wall)
    pb.box_min((PX0, D - 0.025, 0.0), (PAR_WIN[0], D, 0.95), "par_dado", bevel=0.0)
    pb.box_min((PAR_WIN[1], D - 0.025, 0.0), (PX1, D, 0.95), "par_dado", bevel=0.0)
    pb.box_min((PAR_WIN[0], D - 0.025, 0.0), (PAR_WIN[1], D, 0.95), "par_dado", bevel=0.0)
    pb.box_min((PX0, D - 0.05, 0.93), (PX1, D, 0.99), "frame", bevel=0.01)
    pb.box_min((PX0, D - 0.05, 0.0), (PX1, D, 0.13), "par_skirt", bevel=0.01)
    # cornice
    side_walls(pb, PX0, PX1, "par_wall", "par_skirt")
    ob = pb.finish()
    place("room_parlour", 0, 0, 0, group="shell")
    return ob


def build_kitchen_room():
    pb = PB("room_kitchen")
    pb.box_min((KX0, 0.0, -0.02), (KX1, D, 0.0), "kit_floor", bevel=0.0)
    wall_with_holes(pb, KX0, KX1, [KIT_WIN, PANTRY], "kit_wall")
    # tiled lower band (one flat colour + a rail), skirting
    for a, b in ((KX0, PANTRY[0]), (PANTRY[1], KX1)):
        pb.box_min((a, D - 0.02, 0.0), (b, D, 1.25), "kit_dado", bevel=0.0)
        pb.box_min((a, D - 0.045, 1.23), (b, D, 1.28), "kit_skirt", bevel=0.01)
        pb.box_min((a, D - 0.045, 0.0), (b, D, 0.12), "kit_skirt", bevel=0.01)
    side_walls(pb, KX0, KX1, "kit_wall", "kit_skirt", left_partition=True)
    ob = pb.finish()
    place("room_kitchen", 0, 0, 0, group="shell")
    return ob


# ============================================================================================
# PARLOUR PROPS (back at local y=0, facing -Y)
# ============================================================================================
def build_window(name, w, z0, z1, curtains, cafe=False):
    pb = PB(name)
    hw = w / 2
    fr = 0.08
    pb.box_min((-hw - fr, -0.07, z0), (-hw, BW, z1), "frame", bevel=0.01)
    pb.box_min((hw, -0.07, z0), (hw + fr, BW, z1), "frame", bevel=0.01)
    pb.box_min((-hw - fr, -0.07, z1), (hw + fr, BW, z1 + fr), "frame", bevel=0.01)
    pb.box_min((-hw - fr - 0.04, -0.16, z0 - 0.07), (hw + fr + 0.04, BW, z0), "frame", bevel=0.015)
    # glazing bars
    pb.box_min((-0.022, 0.07, z0), (0.022, 0.11, z1), "frame", bevel=0.0)
    zm = z0 + (z1 - z0) * 0.55
    pb.box_min((-hw, 0.07, zm - 0.022), (hw, 0.11, zm + 0.022), "frame", bevel=0.0)
    # outside: sky + low horizon + one tree blob
    pb.box_min((-hw - 0.3, BW + 0.35, z0 - 0.3), (hw + 0.3, BW + 0.38, z1 + 0.3), "sky", bevel=0.0)
    pb.box_min((-hw - 0.3, BW + 0.33, z0 - 0.3), (hw + 0.3, BW + 0.35, z0 + (z1 - z0) * 0.28), "sky_lo", bevel=0.0)
    pb.sphere(0.42, (hw * 0.45, BW + 0.3, z0 + 0.25), "tree", scale=(1.0, 0.15, 0.8), seg=16, rings=8)
    if curtains:
        cw = 0.42
        for s in (-1, 1):
            pb.curtain(cw, (z1 - z0) + 0.55, (s * (hw + 0.14), -0.2, z0 - 0.35), "curtain", folds=3, amp=0.035, thick=0.03)
            pb.box((cw + 0.04, 0.05, 0.06), (s * (hw + 0.14), -0.24, z0 + 0.35), "curtain_dk", bevel=0.02)  # tie-back
        pb.cyl(0.022, 0.022, w + 1.1, (-(w + 1.1) / 2, -0.22, z1 + 0.2), "gold", seg=12, rot=(0, 90, 0))
        for s in (-1, 1):
            pb.sphere(0.045, (s * (w + 1.1) / 2, -0.22, z1 + 0.2), "gold", seg=12, rings=8)
    if cafe:
        pb.curtain(w, (z1 - z0) * 0.42, (0, -0.02, z0), "curtain", folds=5, amp=0.02, thick=0.02)
        pb.cyl(0.014, 0.014, w, (-w / 2, -0.02, z0 + (z1 - z0) * 0.42), "steel", seg=10, rot=(0, 90, 0))
    return pb.finish()


def build_fireplace():
    pb = PB("fireplace")
    # chimney breast (wall colour, full height)
    pb.box_min((-0.95, -0.28, 0.0), (0.95, 0.0, H), "par_wall", bevel=0.0)
    pb.box_min((-0.95, -0.31, 0.0), (0.95, -0.28, 0.13), "par_skirt", bevel=0.01)
    # stone surround: two piers + lintel, recessed firebox
    pb.box_min((-0.78, -0.52, 0.0), (-0.42, -0.28, 1.12), "stone", bevel=0.025)
    pb.box_min((0.42, -0.52, 0.0), (0.78, -0.28, 1.12), "stone", bevel=0.025)
    pb.box_min((-0.78, -0.52, 0.78), (0.78, -0.28, 1.12), "stone", bevel=0.025)
    pb.box_min((-0.42, -0.4, 0.0), (0.42, -0.28, 0.78), "soot", bevel=0.0)
    # mantel shelf + hearth
    pb.box_min((-0.9, -0.62, 1.12), (0.9, -0.28, 1.21), "stone_dk", bevel=0.02)
    pb.box_min((-0.92, -0.9, 0.0), (0.92, -0.28, 0.05), "stone_dk", bevel=0.015)
    # logs + flames
    pb.cyl(0.07, 0.07, 0.62, (-0.31, -0.45, 0.1), "log", seg=10, rot=(0, 90, 0))
    pb.cyl(0.06, 0.06, 0.5, (-0.25, -0.5, 0.2), "log", seg=10, rot=(0, 90, 12))
    for x, s, c in ((-0.14, 0.95, "fire"), (0.12, 0.8, "fire"), (0.0, 1.2, "fire"), (0.0, 0.7, "fire_hot"), (-0.12, 0.5, "fire_hot")):
        pb.lathe([(0.0, 0.0), (0.09 * s, 0.05 * s), (0.1 * s, 0.13 * s), (0.06 * s, 0.24 * s), (0.0, 0.34 * s)],
                 (x, -0.44 + (0.02 if c == "fire_hot" else 0), 0.14), c, seg=12, cap_top=False, cap_bottom=False)
    # portrait of Horace above the mantel: oval gold frame + bust
    zc = 1.95
    pb.torus(0.34, 0.045, (0, -0.33, zc), "gold", seg=28, rseg=8, rot=(90, 0, 0), scale=(0.82, 1.0, 1.0))
    pb.cyl(0.33, 0.33, 0.03, (0, -0.3, zc), "portrait", seg=28, rot=(90, 0, 0), scale=(0.82, 1.0, 1.0))
    pb.sphere(0.1, (0, -0.335, zc + 0.05), "stone", scale=(0.9, 0.3, 1.0), seg=14, rings=8)
    pb.sphere(0.13, (0, -0.33, zc + 0.14), "white", scale=(1.25, 0.3, 0.7), seg=14, rings=8)
    pb.sphere(0.2, (0, -0.325, zc - 0.2), "rug_dk", scale=(1.0, 0.25, 0.55), seg=14, rings=8)
    # a mantel clock (one small object on the shelf)
    pb.box((0.22, 0.12, 0.2), (0.5, -0.47, 1.21), "wood", bevel=0.03)
    pb.cyl(0.07, 0.07, 0.02, (0.5, -0.535, 1.31), "frame", seg=16, rot=(90, 0, 0))
    return pb.finish()


def build_armchair():
    pb = PB("armchair")
    for x in (-0.36, 0.36):
        for y in (-0.72, -0.12):
            pb.cyl(0.035, 0.025, 0.12, (x, y, 0.0), "wood_dk", seg=10)
    pb.box((0.96, 0.82, 0.3), (0, -0.42, 0.11), "teal", bevel=0.06, seg=3)
    pb.box((0.66, 0.66, 0.14), (0, -0.47, 0.39), "teal", bevel=0.06, seg=3)
    pb.box((0.96, 0.24, 0.9), (0, -0.14, 0.38), "teal", bevel=0.08, seg=3, rot=(-6, 0, 0))
    for s in (-1, 1):
        pb.box((0.17, 0.78, 0.3), (s * 0.4, -0.43, 0.38), "teal_dk", bevel=0.075, seg=3)
        pb.box((0.12, 0.42, 0.52), (s * 0.43, -0.24, 0.74), "teal", bevel=0.05, seg=3)
    return pb.finish()


def build_gramophone():
    pb = PB("gramophone")
    for x in (-0.22, 0.22):
        for y in (-0.44, -0.08):
            pb.cyl(0.03, 0.022, 0.16, (x, y, 0.0), "wood_dk", seg=10)
    pb.box((0.58, 0.5, 0.6), (0, -0.26, 0.15), "wood", bevel=0.03)
    pb.box((0.46, 0.02, 0.4), (0, -0.515, 0.25), "wood_dk", bevel=0.01)
    pb.box((0.62, 0.54, 0.05), (0, -0.26, 0.75), "wood_dk", bevel=0.015)
    pb.cyl(0.21, 0.21, 0.025, (0, -0.28, 0.8), "black", seg=28)
    pb.cyl(0.02, 0.02, 0.05, (0, -0.28, 0.8), "gold", seg=8)
    # neck + horn (flaring bell, pointing up-left toward the camera)
    pb.cyl(0.028, 0.028, 0.28, (0.2, -0.1, 0.8), "gold", seg=10)
    prof_out = [(0.03, 0.0), (0.035, 0.12), (0.05, 0.26), (0.085, 0.38), (0.15, 0.48), (0.25, 0.55), (0.34, 0.58)]
    prof_in = [(r - 0.012, z - 0.004) for (r, z) in reversed(prof_out)]
    pb.lathe(prof_out + prof_in, (0.2, -0.1, 1.06), "gold", seg=28, rot=(38, 0, -32), cap_top=False, cap_bottom=False)
    return pb.finish()


def build_rug():
    pb = PB("rug")
    pb.cyl(1.0, 1.0, 0.012, (0, 0, 0.0), "rug_dk", seg=40, scale=(1.0, 0.5, 1.0), smooth=False)
    pb.cyl(0.9, 0.9, 0.018, (0, 0, 0.0), "rug", seg=40, scale=(1.0, 0.44, 1.0), smooth=False)
    return pb.finish()


# ============================================================================================
# KITCHEN PROPS
# ============================================================================================
def build_counter():
    pb = PB("counter")
    L = 1.7
    pb.box_min((-L / 2 + 0.03, -0.52, 0.0), (L / 2 - 0.03, 0.0, 0.1), "cab_dk", bevel=0.0)
    pb.box_min((-L / 2, -0.58, 0.1), (L / 2, 0.0, 0.88), "cab", bevel=0.02)
    for x0 in (-L / 2 + 0.06, 0.03):
        pb.box_min((x0, -0.6, 0.16), (x0 + L / 2 - 0.09, -0.57, 0.8), "cab_dk", bevel=0.012)
        pb.sphere(0.025, (x0 + (0.06 if x0 > 0 else L / 2 - 0.15), -0.615, 0.7), "gold", seg=10, rings=6)
    pb.box_min((-L / 2 - 0.04, -0.64, 0.88), (L / 2 + 0.04, 0.0, 0.95), "worktop", bevel=0.02)
    # hob: two burner plates
    for x in (-0.4, 0.05):
        pb.cyl(0.14, 0.14, 0.02, (x, -0.33, 0.95), "hob", seg=24, smooth=False)
    # splashback shelf with 3 plates (the only wall decor in the kitchen)
    pb.box_min((-0.7, -0.24, 1.72), (0.7, 0.0, 1.77), "wood", bevel=0.01)
    for x in (-0.42, 0.0, 0.42):
        pb.cyl(0.16, 0.16, 0.025, (x, -0.1, 1.94), "ceramic", seg=24, rot=(80, 0, 0), smooth=False)
        pb.cyl(0.1, 0.1, 0.03, (x, -0.1, 1.94), "cab_dk", seg=20, rot=(80, 0, 0), smooth=False)
    return pb.finish()


def build_kettle():
    pb = PB("kettle")
    s = 1.35  # toon-oversized
    prof = [(0.0, 0.0), (0.12, 0.0), (0.15, 0.03), (0.16, 0.1), (0.15, 0.17), (0.11, 0.22), (0.06, 0.245), (0.0, 0.25)]
    pb.lathe([(r * s, z * s) for r, z in prof], (0, 0, 0), "copper", seg=24)
    pb.sphere(0.03 * s, (0, 0, 0.26 * s), "copper_dk", seg=12, rings=8)
    pb.torus(0.11 * s, 0.018 * s, (0, 0, 0.25 * s), "copper_dk", seg=20, rseg=8, rot=(90, 0, 0), scale=(1.0, 0.8, 1.0))
    pb.cyl(0.035 * s, 0.018 * s, 0.17 * s, (0.13 * s, 0, 0.07 * s), "copper", seg=12, rot=(0, 55, 0))
    return pb.finish()


def build_sink():
    pb = PB("sink")
    W = 1.0
    pb.box_min((-W / 2 + 0.03, -0.52, 0.0), (W / 2 - 0.03, 0.0, 0.1), "cab_dk", bevel=0.0)
    pb.box_min((-W / 2, -0.56, 0.1), (W / 2, 0.0, 0.66), "cab", bevel=0.02)
    pb.box_min((-W / 2 + 0.07, -0.58, 0.16), (W / 2 - 0.07, -0.55, 0.6), "cab_dk", bevel=0.012)
    # belfast basin (protrudes) + worktop shoulders
    pb.box_min((-0.4, -0.64, 0.66), (0.4, -0.06, 0.92), "ceramic", bevel=0.03)
    pb.box_min((-0.33, -0.57, 0.8), (0.33, -0.13, 0.925), "steel", bevel=0.0)
    for x0, x1 in ((-W / 2 - 0.02, -0.4), (0.4, W / 2 + 0.02)):
        pb.box_min((x0, -0.6, 0.86), (x1, 0.0, 0.93), "worktop", bevel=0.015)
    # gooseneck tap
    pb.cyl(0.022, 0.022, 0.32, (0, -0.07, 0.92), "steel", seg=10)
    pb.torus(0.08, 0.02, (0, -0.15, 1.24), "steel", seg=16, rseg=6, rot=(90, 0, 90), scale=(1.0, 1.0, 1.0))
    for s in (-1, 1):
        pb.sphere(0.035, (s * 0.1, -0.07, 1.02), "steel", seg=10, rings=6)
    return pb.finish()


def build_stool():
    pb = PB("stool")
    hgt = 0.66
    for i in range(4):
        a = math.radians(45 + 90 * i)
        tilt = 7
        x, y = 0.15 * math.cos(a), 0.15 * math.sin(a)
        # tilt outward: rotate about the axis perpendicular to the radial direction
        pb.cyl(0.024, 0.02, hgt - 0.02, (x, y, 0.0), "stool_dk", seg=10,
               rot=(tilt * math.sin(a), -tilt * math.cos(a), 0))
    pb.torus(0.165, 0.014, (0, 0, 0.24), "stool_dk", seg=24, rseg=6)
    pb.cyl(0.21, 0.21, 0.07, (0, 0, hgt - 0.02), "stool", seg=28, bevel=0.02)
    ob = pb.finish()
    return ob


def build_pantry():
    pb = PB("pantry")
    x0, x1 = -0.5, 0.5
    z1 = PANTRY[3]
    # dark alcove behind the wall + two shelves with jar silhouettes
    pb.box_min((x0, BW, 0.0), (x1, BW + 0.5, z1), "soot", bevel=0.0)
    pb.box_min((x0 - 0.02, 0.0, -0.001), (x0, BW + 0.5, z1), "soot", bevel=0.0)
    pb.box_min((x1, 0.0, -0.001), (x1 + 0.02, BW + 0.5, z1), "soot", bevel=0.0)
    for z in (1.2, 1.75):
        pb.box_min((x0, BW, z), (x1, BW + 0.45, z + 0.04), "wood_dk", bevel=0.0)
        for i, x in enumerate((-0.3, -0.05, 0.22)):
            pb.cyl(0.07, 0.07, 0.16 + 0.04 * (i % 2), (x, BW + 0.2, z + 0.04), "log", seg=10, smooth=False)
    # door frame trim around the opening
    fr = 0.08
    pb.box_min((x0 - fr, -0.05, 0.0), (x0, 0.02, z1), "door", bevel=0.01)
    pb.box_min((x1, -0.05, 0.0), (x1 + fr, 0.02, z1), "door", bevel=0.01)
    pb.box_min((x0 - fr, -0.05, z1), (x1 + fr, 0.02, z1 + fr), "door", bevel=0.01)
    # curtain rail + two drapes (left one wide, right one gathered: a gap shows the dark inside)
    pb.cyl(0.02, 0.02, 1.08, (x0 - 0.04, -0.1, z1 - 0.06), "gold", seg=10, rot=(0, 90, 0))
    pb.curtain(0.66, z1 - 0.1, (x0 + 0.33, -0.1, 0.02), "pantry", folds=4, amp=0.045, thick=0.03)
    pb.curtain(0.26, z1 - 0.1, (x1 - 0.13, -0.1, 0.02), "pantry_dk", folds=2, amp=0.05, thick=0.03)
    return pb.finish()


# ============================================================================================
builders = []
build_frame(); build_parlour_room(); build_kitchen_room()

ob = build_window("par_window", PAR_WIN[1] - PAR_WIN[0], PAR_WIN[2], PAR_WIN[3], curtains=True)
place("par_window", (PAR_WIN[0] + PAR_WIN[1]) / 2, D)
build_fireplace(); place("fireplace", 3.45, D)
build_armchair(); place("armchair", 1.45, D - 0.25, rot=-18)
build_gramophone(); place("gramophone", 5.15, D - 0.05, rot=8)
build_rug(); place("rug", 3.45, 1.3)

ob = build_window("kit_window", KIT_WIN[1] - KIT_WIN[0], KIT_WIN[2], KIT_WIN[3], curtains=False, cafe=True)
place("kit_window", (KIT_WIN[0] + KIT_WIN[1]) / 2, D)
build_counter(); place("counter", 7.55, D)
build_kettle(); place("kettle", 7.15, D - 0.33, 0.95, rot=-30)
build_sink(); place("sink", 9.3, D)
build_stool(); place("stool", 8.15, 1.35)
build_pantry(); place("pantry", (PANTRY[0] + PANTRY[1]) / 2, D)

# export every piece
for name in pieces:
    ob = bpy.data.objects[name]
    mnd3d.export_glb([ob], os.path.join(OUT, "props", name + ".glb"))

LANE = 1.05
marks = {
    # name: (blender x, blender y, blender z, facing yaw deg in Godot: 0 = facing camera (+Z), 90 = facing +X)
    "hush_start": (0.7, LANE, 0.0, 90),
    "bellows_start": (1.5, 1.35, 0.0, 0),
    "armchair_sit": (1.45, D - 0.72, 0.0, -18),
    "armchair_front": (1.7, LANE, 0.0, 0),
    "fireplace": (3.45, LANE + 0.1, 0.0, 180),
    "gramophone": (4.75, LANE + 0.15, 0.0, 150),
    "doorway": ((PX1 + KX0) / 2, LANE, 0.0, 90),
    "kettle": (7.2, LANE + 0.25, 0.0, 180),
    "stool": (8.15, 1.35, 0.0, 0),
    "stool_top": (8.15, 1.35, 0.66, 0),
    "sink": (9.3, LANE + 0.35, 0.0, 180),
    "pantry": ((PANTRY[0] + PANTRY[1]) / 2, D + 0.3, 0.0, 0),
    "pantry_front": ((PANTRY[0] + PANTRY[1]) / 2, LANE, 0.0, 0),
}
layout = {
    "units": "metres; Godot axes (X right along the house, Y up, +Z toward the camera)",
    "house": {"x0": PX0 - END, "x1": KX1 + END, "height": H, "depth": D, "lane_z": -LANE,
              "rooms": {"parlour": [PX0, PX1], "kitchen": [KX0, KX1]}, "doorway_x": [PX1, KX0], "door_h": DOOR_H},
    "pieces": pieces,
    "marks": {k: {"pos": [v[0], v[2], -v[1]], "yaw": v[3]} for k, v in marks.items()},
}
json.dump(layout, open(os.path.join(OUT, "layout.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "diorama_src.blend"))
print("DIORAMA_OK", len(pieces), "pieces")
