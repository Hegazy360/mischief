"""bellows/rx_dizzy_spin_a — ALLEGRO-GO-GO!'s payoff (the Prologue's second prank; 169 f, lock "sim"; reactions.json
dizzy_spin_a): at the gramophone, mid-warm-up with his baton, the record screeches to triple speed — a flinch (the
needle screech, 0-12); he babbles his scales as a chipmunk, conducting at ×3 with a jerky head bob and the mouth
flapping (12-40); winds up, springs onto ONE TOE and spins like a top, two full turns and a bit (fix round 2: slower, so every
quarter turn reads — he is spun BY the record), arms out, coat tails flying (40-70 — the 3D spin); the top wobbles round its toe as it slows (70-86, rising onto the point: the
anticipation); COLLAPSE (86, the pop: the legs shoot out and he lands on his bottom, hit-stop 5, punch-in 1.4); dizzy
on the floor with his legs in a V and the vinyl notes orbiting his bouffant, the torso and head lolling in circles
(89-149); then he shakes the notes off, spins back round on his bottom, springs to his feet and glares (149-169).

Staged at the gramophone (st_gramophone: stand_x 1730 px = 8.65 m, z -1.4, facing -1, cheat 35). The spin turns him
752 deg to his LEFT (2 turns + 32 deg), so the collapse and the dizzy hold face the audience (cheat 35 + 32 = 67 deg;
facing -1: his left side is the camera side) with the legs in a V seen three-quarter; he spins back 32 deg on his bottom before he gets up, so the clip ends on the station
yaw. The spin pivots on the tip of his left slipper: the toe is pinned to the root's origin (the pelvis moves over it,
the root turns about it), so the foot never slides and the root never travels. Face beats carry a runtime gaze to the
camera (lead note D8). Sounds: no audio-table row exists for this clip -> audio "own" (new rows for r3d-integrate).
"""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 169
GRAMO_X, GRAMO_Z, GRAMO_FACING, GRAMO_CHEAT = 8.65, -1.4, -1, 35.0

# the spin: the root yaw (deg, + = to his left) — takes off at 36, lands on the toe at 39, 2 turns + 32 by 80
SPIN_F0, SPIN_F1 = 36, 80
SPIN_UP, SPIN_DOWN = 5, 16
SPIN_TOTAL = 720.0 + 32.0           # fix round 2 (Q2-G2): TWO turns in the same 36-80 window (was 3: a blur at strip size)
BACK_F0, BACK_F1 = 150, 155          # spins back 48 deg on his bottom (the feet up in the air)


def _omega_shape(f):
    """Relative angular speed of the spin (trapezoid: ramp up, cruise, long spin-down)."""
    if f <= SPIN_F0 or f >= SPIN_F1:
        return 0.0
    if f < SPIN_F0 + SPIN_UP:
        return smooth((f - SPIN_F0) / float(SPIN_UP))
    if f > SPIN_F1 - SPIN_DOWN:
        return smooth((SPIN_F1 - f) / float(SPIN_DOWN))
    return 1.0


_AREA = sum(0.5 * (_omega_shape(f) + _omega_shape(f + 1)) for f in range(SPIN_F0, SPIN_F1))


def root_yaw(f):
    """Root yaw at frame f (deg): 0 until the take-off, SPIN_TOTAL after the spin-down, back to 1080 on his bottom."""
    if f <= SPIN_F0:
        return 0.0
    a = 0.0
    for g in range(SPIN_F0, min(int(f), SPIN_F1)):
        a += 0.5 * (_omega_shape(g) + _omega_shape(g + 1))
    th = SPIN_TOTAL * a / _AREA
    if f >= BACK_F0:
        th -= 32.0 * smooth((f - BACK_F0) / float(BACK_F1 - BACK_F0))
    return th


def set_root_yaw(pose, deg):
    sk = pose.skel
    loc, _, sc = pose.get("root")
    pose.basis["root"] = (loc, sk.basis_rot("root", P.rot_q([("z", deg)])), sc)
    pose.update_from("root")


def hold_feet(c, f0, f1, at=None):
    """Both feet held exactly (position + rotation, no blend) where they are at frame `at` (default f0) after the
    keys and the vertical constraints — the planted stance while the body above it jolts, squats and rises."""
    cache = {}

    def fn(pose, f):
        if "a" not in cache:
            ap = c._anchor_pose(f0 if at is None else at)
            cache["a"] = {s: (ap.world["foot_" + s].translation.copy(), ap.world["foot_" + s].to_quaternion())
                          for s in ("l", "r")}
        for s in ("l", "r"):
            loc, q = cache["a"][s]
            P.solve_leg(pose, s, loc, foot_world=q)
    c.custom(fn, f0, f1)


def warmup_trigger_pose(ctx):
    """act_warmup's frame 30 (ALLEGRO-GO-GO!'s trigger, mark_s 0.5) — the pose the reaction starts from, so the
    switch (blend_in 0) never pops. None when the warm-up spec is missing (then SING below stands in)."""
    try:
        import importlib.util, os
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "act_warmup.py")
        sp = importlib.util.spec_from_file_location("bellows_act_warmup_for_dizzy", path)
        mod = importlib.util.module_from_spec(sp)
        sp.loader.exec_module(mod)
        return mod.build(ctx).evaluate(30).copy()
    except Exception as e:          # noqa: BLE001 — a missing / broken warm-up must not break this clip
        print("[rx_dizzy_spin_a] act_warmup f30 unavailable (%s): starting from SING" % e)
        return None


def blend_from(c, src, f0, f1):
    """Every bone's final basis eased from `src` (an evaluated pose) at f0 to this clip's own at f1 (a custom
    constraint added LAST, so the feet, the root and the IK are blended too); scales are never blended (the FX and
    prop bones keep this clip's keyed scale)."""
    names = list(src.basis.keys())

    def fn(pose, f):
        w = 1.0 - smooth((f - f0) / float(max(1, f1 - f0)))
        if w <= 0.0:
            return
        for n in set(names) | set(pose.basis.keys()):
            la, ra, sa = src.get(n)
            lb, rb, sb = pose.get(n)
            pose.basis[n] = (lb.lerp(la, w), P.qslerp(rb, ra, w), sb)     # scales stay this clip's (FX hidden)
        pose.solve()
    c.custom(fn, f0, f1)


def toe(pose, side="l"):
    return pose.skel.sole_points(pose.world, side)[2]


# ------------------------------------------------------------------------------------------------------------------
# poses (armature axes: +x his LEFT, -y his FRONT, +z up; the pipeline adds arm_out: an arm keyed y 84 hangs 44 deg
# below the horizontal)
# ------------------------------------------------------------------------------------------------------------------
HIDE = fx_hidden("fx_notes", "fx_stars", "fx_choo")


def body(*parts, baton=1.0, notes=0.0):
    p = merge(HIDE, *parts)
    p["prop_baton"] = {"r": [], "s": baton}
    p["fx_notes"] = {"r": [], "s": notes}
    return p


# the warm-up at its trigger: chest out, chin up, mid-note, the baton raised in his right glove, the left on his chest
SING_ARMS = merge(
    {"clavicle_r": [("y", 8)], "upperarm_r": [("y", 6), ("z", 34)], "lowerarm_r": [("z", 58)], "hand_r": [("x", -30)]},
    {"clavicle_l": [("z", 4)], "upperarm_l": [("y", 70), ("z", -38)], "lowerarm_l": [("z", -92)], "hand_l": [("x", -8), ("y", 20)]},
    grip("r", 60, 36), glove("l", 16, 8))
SING = merge(STAND, pompous(1.3), SING_ARMS, head(x=-10, z=-6))

# the needle screech: a startled jolt — shoulders up, gloves up by the face, knees buckle, the head snapped back and
# turned away from the gramophone (toward the audience)
FLINCH_ARMS = merge(
    {"clavicle_r": [("y", 16)], "upperarm_r": [("y", -2), ("z", 52)], "lowerarm_r": [("z", 96)], "hand_r": [("x", -40)]},
    {"clavicle_l": [("y", -16)], "upperarm_l": [("y", 10), ("z", -46)], "lowerarm_l": [("z", -104)], "hand_l": [("x", -30), ("y", 10)]},
    grip("r", 64, 40), open_hand("l", 20))
FLINCH = merge(STAND, lean(fwd=-10, turn=14), head(x=-18, y=-4, z=16), FLINCH_ARMS,
               {"thigh_l": [("x", -12), ("z", 8)], "thigh_r": [("x", -10), ("z", -8)], "calf_l": [("x", 20)], "calf_r": [("x", 18)],
                "foot_l": [("x", -8)], "foot_r": [("x", -8)], "_pelvis": (0.0, 0.0, -0.035)})

# the chipmunk babble base: hunched forward over the triple-speed record, elbows out, conducting like mad
BABBLE_ARMS = merge(
    {"clavicle_r": [("y", 10)], "upperarm_r": [("y", 20), ("z", 30)], "lowerarm_r": [("z", 70)], "hand_r": [("x", -24)]},
    {"clavicle_l": [("y", -8)], "upperarm_l": [("y", 36), ("z", -20)], "lowerarm_l": [("z", -60)], "hand_l": [("x", -10)]},
    grip("r", 62, 38), open_hand("l", 12))
BABBLE = merge(STAND, lean(fwd=6, turn=18), head(x=4, z=16), BABBLE_ARMS,
               {"thigh_l": [("x", -8), ("z", 10)], "thigh_r": [("x", -6), ("z", -10)], "calf_l": [("x", 14)], "calf_r": [("x", 12)],
                "foot_l": [("x", -6)], "foot_r": [("x", -6)], "_pelvis": (0.0, 0.0, -0.02)})

# the wind-up: coiled to his right, arms wrapped across, crouched to spring
WIND_ARMS = merge(
    {"clavicle_r": [("y", 4)], "upperarm_r": [("y", -60), ("z", -24)], "lowerarm_r": [("z", 30)], "hand_r": [("x", -10)]},
    {"clavicle_l": [("z", 16)], "upperarm_l": [("y", 64), ("z", -64)], "lowerarm_l": [("z", -40)], "hand_l": [("x", -10)]},
    grip("r", 62, 38), open_hand("l", 14))
WIND = merge(STAND, lean(fwd=10, turn=-18), head(x=2, z=8), WIND_ARMS,
             {"thigh_l": [("x", -30), ("z", 10)], "thigh_r": [("x", -28), ("z", -10)], "calf_l": [("x", 48)], "calf_r": [("x", 46)],
              "foot_l": [("x", -18)], "foot_r": [("x", -18)], "_pelvis": (0.0, 0.0, -0.075)})

# ON THE TOE: the left leg straight and slanted in under the barrel, the slipper pointed; the right knee up and out
# (a pirouette in a barrel); arms flung out, the left higher than the right (never mirror-equal), head thrown back
TOE_LEGS = {"thigh_l": [("x", -4), ("y", 12), ("z", 4)], "calf_l": [("x", 4)], "foot_l": [("x", 62)],
            "thigh_r": [("x", -78), ("y", 30), ("z", -14)], "calf_r": [("x", 104)], "foot_r": [("x", 34)]}
SPIN_ARMS = merge(
    {"clavicle_l": [("y", -12)], "upperarm_l": [("y", 6), ("z", -8)], "lowerarm_l": [("z", -10)], "hand_l": [("x", -14)]},
    {"clavicle_r": [("y", 6)], "upperarm_r": [("y", -26), ("z", 2)], "lowerarm_r": [("z", 22)], "hand_r": [("x", -20)]},
    grip("r", 62, 38), open_hand("l", 22))
SPIN = merge(TOE_LEGS, lean(fwd=-6, side=4), head(x=-12, y=6), SPIN_ARMS)

# the top wobbling: arms windmilling for balance (two phases), up on the point at the end
WOB_A = merge(TOE_LEGS, lean(fwd=-4, side=-10), head(x=-6, y=-10),
              {"clavicle_l": [("y", -18)], "upperarm_l": [("y", -30), ("z", 24)], "lowerarm_l": [("z", -30)],
               "clavicle_r": [("y", 4)], "upperarm_r": [("y", -40), ("z", -20)], "lowerarm_r": [("z", 40)]},
              grip("r", 62, 38), open_hand("l", 24))
WOB_B = merge(TOE_LEGS, lean(fwd=-8, side=12), head(x=-10, y=10),
              {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 20), ("z", -30)], "lowerarm_l": [("z", -50)],
               "clavicle_r": [("y", 18)], "upperarm_r": [("y", 20), ("z", 34)], "lowerarm_r": [("z", 20)]},
              grip("r", 62, 38), open_hand("l", 24))
TEETER = merge(TOE_LEGS, {"foot_l": [("x", 70)], "thigh_r": [("x", -60), ("y", 20), ("z", -10)], "calf_r": [("x", 80)]},
               lean(fwd=-14, side=6), head(x=-16, y=8),
               {"clavicle_l": [("y", -22)], "upperarm_l": [("y", -40), ("z", 10)], "lowerarm_l": [("z", -20)],
                "clavicle_r": [("y", 16)], "upperarm_r": [("y", 6), ("z", -12)], "lowerarm_r": [("z", 28)]},
               grip("r", 62, 38), open_hand("l", 26))

# THE COLLAPSE (the pop): the legs shoot out from under him, arms thrown up, the barrel dropping onto its bottom
DROP_LEGS = {"thigh_l": [("x", -104), ("y", -30)], "calf_l": [("x", 6)], "foot_l": [("x", -30)],
             "thigh_r": [("x", -96), ("y", 26)], "calf_r": [("x", 12)], "foot_r": [("x", -26)]}
DROP = merge(DROP_LEGS, lean(fwd=-12), head(x=10, y=-6),
             {"clavicle_l": [("y", -20)], "upperarm_l": [("y", -44), ("z", -6)], "lowerarm_l": [("z", -12)],
              "clavicle_r": [("y", 16)], "upperarm_r": [("y", 36), ("z", 10)], "lowerarm_r": [("z", 18)]},
             grip("r", 62, 38), open_hand("l", 26))
# on his bottom: the legs in a V on the floor, slippers up; gloves limp on the floor beside him, the baton still held
FLOOR_LEGS = {"thigh_l": [("x", -92), ("y", -44), ("z", 14)], "calf_l": [("x", 6)], "foot_l": [("x", -58)],
              "thigh_r": [("x", -88), ("y", 38), ("z", -10)], "calf_r": [("x", 10)], "foot_r": [("x", -54)]}
FLOOR_ARMS = merge(
    {"clavicle_l": [("y", 6)], "upperarm_l": [("y", 76), ("z", 16)], "lowerarm_l": [("z", -16)], "hand_l": [("x", 20), ("y", 30)]},
    {"clavicle_r": [("y", -2)], "upperarm_r": [("y", -84), ("z", -2)], "lowerarm_r": [("z", 30)], "hand_r": [("x", 10)]},
    grip("r", 58, 34), glove("l", 30, 14))


# the arms still flying from the fall as he lands (they flop down by 97)
ARMS_FLAIL = {"clavicle_l": [("y", -10)], "upperarm_l": [("y", 16), ("z", 4)], "lowerarm_l": [("z", -20)],
              "clavicle_r": [("y", 8)], "upperarm_r": [("y", -24), ("z", -6)], "lowerarm_r": [("z", 26)]}


def floor_sit(sq=0.0, slump=0.0):
    """On his bottom: sq = the landing squash (+ = folded forward), slump = the lolling slump."""
    return merge(FLOOR_LEGS, FLOOR_ARMS, lean(fwd=-12 + 16 * sq + 6 * slump), head(x=8 + 10 * sq + 8 * slump))


# getting up: legs drawn in, a squat on his feet, then up
TUCK = merge({"thigh_l": [("x", -118), ("y", -18)], "calf_l": [("x", 112)], "foot_l": [("x", -10)],
              "thigh_r": [("x", -112), ("y", 16)], "calf_r": [("x", 108)], "foot_r": [("x", -12)]},
             lean(fwd=24), head(x=-6),
             {"clavicle_l": [("y", 4)], "upperarm_l": [("y", 70), ("z", -40)], "lowerarm_l": [("z", -30)],
              "clavicle_r": [("y", -4)], "upperarm_r": [("y", -66), ("z", 36)], "lowerarm_r": [("z", 40)]},
             grip("r", 62, 38), glove("l", 30, 14))
# on his bottom with the knees pulled up to the chest, the slippers in the air (he spins back round on it)
TUCK_UP = merge({"thigh_l": [("x", -102), ("y", -16)], "calf_l": [("x", 42)], "foot_l": [("x", -10)],
                 "thigh_r": [("x", -98), ("y", 14)], "calf_r": [("x", 38)], "foot_r": [("x", -12)]},
                lean(fwd=10), head(x=-4),
                {"clavicle_l": [("y", 4)], "upperarm_l": [("y", 64), ("z", -44)], "lowerarm_l": [("z", -40)],
                 "clavicle_r": [("y", -4)], "upperarm_r": [("y", -60), ("z", 40)], "lowerarm_r": [("z", 48)]},
                grip("r", 62, 38), glove("l", 30, 14))
# the squat on his feet (the legs are on IK to the standing feet: the pelvis height makes the squat)
SQUAT = merge({"thigh_l": [("x", -95), ("z", 8)], "calf_l": [("x", 150)], "foot_l": [("x", -55)],
               "thigh_r": [("x", -93), ("z", -8)], "calf_r": [("x", 148)], "foot_r": [("x", -55)],
               "_pelvis": (0.0, 0.0, -0.27)},
              lean(fwd=30), head(x=-20),
              {"clavicle_l": [("y", 4)], "upperarm_l": [("y", 76), ("z", -30)], "lowerarm_l": [("z", -40)],
               "clavicle_r": [("y", -4)], "upperarm_r": [("y", -72), ("z", 30)], "lowerarm_r": [("z", 44)]},
              grip("r", 62, 38), fist("l"))
# up and livid: fists, chest out, leaning in; the baton tucked away under his coat at 162
GLARE = merge(STAND, lean(fwd=6), head(x=-6, z=8), ARMS_POMPOUS, fist("l"), fist("r"),
              {"upperarm_l": [("y", 72), ("z", 10)], "upperarm_r": [("y", -72), ("z", -10)],
               "lowerarm_l": [("z", -44)], "lowerarm_r": [("z", 44)]})
TUCK_ARM = {"clavicle_r": [("y", 4)], "upperarm_r": [("y", -64), ("z", 50)], "lowerarm_r": [("z", 110)],
            "hand_r": [("x", 10), ("z", 20)]}


def build(ctx):
    st = Stage(x=GRAMO_X, z=GRAMO_Z, facing=GRAMO_FACING, cheat=GRAMO_CHEAT)
    c = Clip(ctx, "bellows/rx_dizzy_spin_a", length=L, lock="sim", cheat_deg=GRAMO_CHEAT, stage=st, blend_in=0,
             blend_out=10, audio="own", tags=["reaction", "take", "dizzy", "spin"],
             notes="staged at st_gramophone (x 8.65, z -1.4, facing -1); spins on the left toe pinned at the root origin")

    # ---- needle screech (0-12) -------------------------------------------------------------------------------------
    c.key(0, body(SING))
    c.key(3, body(FLINCH), "pop")
    c.key(8, body(merge(FLINCH, head(x=-14, y=-2, z=18))), "out_quad")
    c.key(12, body(merge(FLINCH, lean(fwd=-4, turn=16))), "in_out_sine")
    # ---- chipmunk babble (12-40): the base leans in over the record; the ×3 conducting is a motion layer -----------
    c.key(16, body(BABBLE), "out_cubic")
    c.key(28, body(merge(BABBLE, lean(fwd=8, turn=20))), "in_out_sine")
    # ---- wind-up (30-36) and the spring onto the toe (36-39) ----------------------------------------------------
    c.key(34, body(WIND), "in_out_cubic")
    c.key(36, body(merge(WIND, lean(fwd=6, turn=-16))), "in_out_sine")
    c.key(39, body(SPIN), "linear")
    # ---- spins like a top (40-70) ---------------------------------------------------------------------------------
    c.key(50, body(merge(SPIN, lean(fwd=-8, side=6))), "in_out_sine")
    c.key(62, body(merge(SPIN, lean(fwd=-6, side=2))), "in_out_sine")
    c.key(70, body(merge(SPIN, lean(fwd=-4, side=-2))), "in_out_sine")
    # ---- wobble (70-86): arms windmill, up on the point ----------------------------------------------------------
    c.key(74, body(WOB_A), "in_out_sine")
    c.key(78, body(WOB_B), "in_out_sine")
    c.key(81, body(WOB_A), "in_out_sine")
    c.key(84, body(TEETER), "out_quad")
    # ---- COLLAPSE (86, the pop) -----------------------------------------------------------------------------------
    c.key(86, body(DROP, notes=0.0), "pop")
    c.key(89, body(merge(floor_sit(sq=1.0), ARMS_FLAIL), notes=0.0), "out_quad")
    c.key(92, body(merge(floor_sit(sq=-0.4), scaled(ARMS_FLAIL, 0.5)), notes=1.25), "out_back")
    c.key(97, body(floor_sit(sq=0.1), notes=1.0), "in_out_sine")
    # ---- dizzy (89-149): the torso and head loll (motion layers), the notes orbit ---------------------------------
    c.key(120, body(floor_sit(slump=0.6), notes=1.0), "in_out_sine")
    c.key(147, body(floor_sit(slump=0.2), notes=1.0), "in_out_sine")
    # ---- sits up (149-169): shakes the notes off, spins back on his bottom, springs up, glares ---------------------
    c.key(150, body(merge(floor_sit(slump=-0.4), {"thigh_l": [("x", -86), ("y", -28)], "calf_l": [("x", 14)],
                                                   "thigh_r": [("x", -84), ("y", 22)], "calf_r": [("x", 16)]}), notes=0.9),
          "out_quad")
    c.key(154, body(TUCK_UP, notes=0.2), "in_out_sine")
    c.key(158, body(SQUAT), "in_out_sine")
    c.key(161, body(merge(SQUAT, STAND, lean(fwd=-10), head(x=-10), {"_pelvis": (0.0, 0.0, -0.13)})), "in_out_sine")
    c.key(164, body(merge(GLARE, TUCK_ARM, {"pelvis": [("x", -4)], "_pelvis": (0.0, 0.0, -0.02)}), baton=1.0), "in_out_sine")
    c.key(165, body(merge(GLARE, TUCK_ARM, {"_pelvis": (0.0, 0.0, -0.01)}), baton=0.0), "linear")
    c.key(L, body(merge(GLARE, lean(fwd=10), head(x=-2, z=10)), baton=0.0), "in_out_sine")

    # ---- motion layers ---------------------------------------------------------------------------------------------
    c.motion(lambda f: tremble(f, 1.4, ("spine_03", "Head", "neck_01"), rate=2.9), 3, 14, weight=lambda f: window(f, 3, 5, 10, 14))
    # the ×3 babble: a jerky head bob (a squared sine, 5 f), the baton conducting at 6 f, the left glove flapping at 8 f
    def jerk(x):
        return math.copysign(abs(x) ** 0.45, x)

    def babble(f):
        hb = jerk(math.sin(2 * math.pi * (f - 12) / 5.0))
        cb = math.sin(2 * math.pi * (f - 12) / 6.0)
        lb = math.sin(2 * math.pi * (f - 12) / 8.0 + 1.1)
        return {"Head": [("x", 9 * hb), ("z", 4 * jerk(math.sin(2 * math.pi * (f - 12) / 11.0)))],
                "neck_01": [("x", 4 * hb)],
                "upperarm_r": [("y", -16 * cb), ("z", 8 * cb)], "lowerarm_r": [("z", 22 * cb)], "hand_r": [("x", -20 * cb)],
                "upperarm_l": [("y", 14 * lb)], "lowerarm_l": [("z", -18 * lb)],
                "spine_03": [("y", 3 * math.sin(2 * math.pi * (f - 12) / 10.0))],
                "_pelvis": (0.0, 0.0, -0.012 * abs(math.sin(2 * math.pi * (f - 12) / 10.0)))}
    c.motion(babble, 12, 36, weight=lambda f: window(f, 12, 15, 31, 36))
    # coat-tail flutter + a small tremble while he spins; the top wobble's precession on the spine
    c.motion(lambda f: {"spine_03": [("y", 3 * math.sin(f * 0.9))], "Head": [("y", 3 * math.cos(f * 0.9))]}, 39, 72,
             weight=lambda f: window(f, 39, 42, 68, 72))
    # dizzy: the torso circles one way, the head the other (the woozy loll), slowing
    def loll(f):
        t = f - 92
        a = 2 * math.pi * t / 44.0
        b = 2 * math.pi * t / 30.0
        return {"spine_01": [("x", 3.0 * math.sin(a)), ("y", 4.0 * math.cos(a))],
                "spine_02": [("x", 3.0 * math.sin(a)), ("y", 5.0 * math.cos(a))],
                "spine_03": [("x", 2.0 * math.sin(a)), ("y", 3.0 * math.cos(a))],
                "Head": [("x", 7 * math.sin(-b)), ("y", 9 * math.cos(-b))],
                "hand_l": [("y", 6 * math.sin(a + 1.0))], "hand_r": [("x", 5 * math.sin(a + 2.0))]}
    c.motion(loll, 90, 152, weight=lambda f: window(f, 90, 96, 146, 152))
    # the slippers waggling up in the air (out of phase), the soles to the Stalls
    c.motion(lambda f: {"foot_l": [("x", 9 * math.sin(2 * math.pi * (f - 92) / 22.0))],
                        "foot_r": [("x", 9 * math.sin(2 * math.pi * (f - 92) / 22.0 + 2.2))],
                        "calf_l": [("x", 5 * math.sin(2 * math.pi * (f - 92) / 34.0))]}, 92, 150,
             weight=lambda f: window(f, 92, 98, 144, 150))
    # the notes orbit 2 turns between their pop-in (89) and their vanish (158): 0 mod 360 at both ends, because a
    # scale-0 bone exports as the rest rotation
    c.motion(lambda f: {"fx_notes": [("z", -720.0 * min(1.0, (f - 89) / 69.0))]}, 89, L)
    # brrr: the head shake that throws the notes off (149-155)
    c.motion(lambda f: {"Head": [("z", 16 * math.sin(2 * math.pi * (f - 149) / 6.0))],
                        "neck_01": [("z", 6 * math.sin(2 * math.pi * (f - 149) / 6.0))]}, 149, 156,
             weight=lambda f: window(f, 149, 150, 154, 156))
    c.motion(lambda f: breath(f, 50.0, 0.8), 150, L, weight=lambda f: ramp(f, 158, 164))

    # ---- constraints ------------------------------------------------------------------------------------------------
    sk = ctx.skel
    # standing 0-35: frame 0 grounded, both feet planted while the upper body jolts, babbles and winds up
    c.ground(0, 0)
    hold_feet(c, 0, 35)

    # the spring (36-38): up off the floor; from 39 the left toe is pinned at the root origin and the root spins
    def pivot(pose, f):
        """The left toe tip onto the root's origin (x/y eased in over the spring, z on the floor from 39)."""
        t = toe(pose, "l")
        w = {36: 0.25, 37: 0.55, 38: 0.85}.get(f, 1.0)
        if f >= 39:
            dz = -t.z
        else:      # airborne: the lowest sole clears the floor by the spring's height
            dz = {36: 0.04, 37: 0.035, 38: 0.016}[f] - sk.lowest_sole(pose.world)
        pose.add_pelvis_offset(Vector((-t.x * w, -t.y * w, dz)))
    c.custom(pivot, 36, 85)

    # on his bottom (86-157): the lowest of the barrel's underside and the soles sits on h(f) (the bounce)
    seat_b, seat_p = ctx.socket("seat")
    bounce = [(86, 0.10), (88, 0.0), (90, 0.035), (92, 0.0), (156, 0.0)]

    def floor(pose, f):
        if f >= 155:       # the hop onto his feet: the slippers clear the floor until they land at 158
            pose.add_pelvis_offset(Vector((0.0, 0.0, {155: 0.03, 156: 0.035, 157: 0.018}[f] - sk.lowest_sole(pose.world))))
            return
        s = sk.carried(pose.world, seat_b, seat_p).z
        low = min(s, sk.lowest_sole(pose.world))
        pose.add_pelvis_offset(Vector((0.0, 0.0, track(f, bounce) - low)))
    c.custom(floor, 86, 157)

    # up again (158-169): both feet planted where the final standing pose puts them; the keyed pelvis height makes the
    # squat and the spring up (the legs follow on IK)
    c.ground(L, L)
    hold_feet(c, 158, L, at=L)

    # the root yaw last: the spin about the pinned toe, the turn back on his bottom
    c.custom(lambda pose, f: set_root_yaw(pose, root_yaw(f)), SPIN_F0 + 1, L)

    # frame 0 = act_warmup's trigger frame (30): its pose eased into the flinch by f 2 (the flinch pops on 3)
    warm = warmup_trigger_pose(ctx)
    if warm is not None:
        blend_from(c, warm, 0, 2)

    # face beats: the face to the camera (the runtime gaze, facing-proof)
    c.look_camera(8, 36, weight=1.0, blend=6)
    c.look_camera(92, 147, weight=0.6, blend=8)
    c.look_camera(160, L, weight=0.8, blend=4)

    # ---- beats, events, face -----------------------------------------------------------------------------------
    c.beats(anticipation=(70, 86), accent=(86, 89), hold=(89, 149), settle=(149, 169),
            needle_screech=(0, 12), chipmunk_babble=(12, 40), spins_like_a_top=(40, 70), wobble=(70, 86),
            collapse=(86, 89), dizzy_orbiting_notes=(89, 149), sits_up=(149, 169))
    c.event(0, "prop", op="show", prop="baton")
    c.sfx(0, "record_scratch")
    c.event(3, "jiggle", bones=["bouffant", "belly"], kick=0.5)
    c.event(12, "voice", id="vo_bellows_dizzy_babble")
    c.sfx(40, "spin")
    c.event(40, "jiggle", bones=["tail_l", "tail_r", "bouffant"], kick=0.8)
    c.mark(86, "accent")
    c.event(86, "hitstop", frames=5)
    c.event(86, "cam", op="punch", zoom=1.4, **{"in": 11}, hold=70, out=21, yaw=4)
    c.event(86, "shake", trauma=0.45)
    c.event(86, "jiggle", bones=["bouffant", "belly", "tail_l", "tail_r"], kick=0.9)
    c.sfx(88, "thud")
    c.sfx(89, "dizzy_tweets")
    c.event(94, "laugh", tier="auto")
    c.event(149, "voice", id="vo_bellows_ugh")
    c.event(165, "prop", op="hide", prop="baton")
    c.mark(169, "release")
    for f, p in ((0, "inhale"), (3, "shock"), (12, "wild_take"), (15, "huh"), (18, "wild_take"), (21, "sing_big"),
                 (24, "wild_take"), (27, "huh"), (30, "wild_take"), (33, "antic"), (39, "wild_take"),
                 (56, "dazed_open"), (78, "terrified"), (86, "dazed_open"), (92, "dazed"), (108, "dazed_open"),
                 (122, "dazed"), (136, "dazed_open"), (146, "dazed"), (149, "antic"), (157, "irked"), (163, "furious")):
        c.face(f, p)
    return c
