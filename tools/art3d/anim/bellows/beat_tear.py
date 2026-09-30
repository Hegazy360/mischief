"""bellows/beat_tear — a T3 last beat (60 f; reactions.json clip_timings: lip 0-24, tear 24, sniff 40-60; the audio
table: sad_violin 0, tear_plink 24, sniffle 42): the fight goes out of him — shoulders sag, gloves clasped at his
heart, the lower lip trembling at the Stalls (0-24); a single tear rolls down (24, the `teary` face); he holds it,
wobbling (24-40) … then an enormous SNIFF (42): chest out, chin up, a brave pompous "I am perfectly fine" (40-60).

Standing, feet planted (IK; the sag bends the knees), cheat 35; the face stays on the Stalls with a runtime gaze."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 60
HEART_L = ("spine_03", Vector((0.05, -0.43, 0.94)))
HEART_R = ("spine_03", Vector((-0.07, -0.44, 0.92)))


def hold_feet(c, f0, f1, at=None):
    """Both feet held exactly where they are at frame `at` (default f0) after the keys and vertical constraints."""
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


CLASP = merge({"clavicle_l": [("z", 8)], "upperarm_l": [("y", 70), ("z", -40)], "lowerarm_l": [("z", -96)],
               "clavicle_r": [("z", -4)], "upperarm_r": [("y", -64), ("z", 48)], "lowerarm_r": [("z", 88)]},
              glove("l", 40, 20), glove("r", 44, 22))


def sag(k=1.0, hx=0.0, hy=0.0, hz=0.0):
    """Deflated: shoulders dropped and rounded, the head bowed and tilted (k 0..1), the knees giving."""
    return merge(STAND, CLASP, lean(fwd=10 * k, side=2 * k), head(x=10 * k + hx, y=6 * k + hy, z=hz),
                 {"clavicle_l": [("y", 8 * k), ("z", 8)], "clavicle_r": [("y", -8 * k), ("z", -8)],
                  "_pelvis": (0.0, 0.0, -0.03 * k)})


# brave: chest out, chin up, the left fist on his hip, the right glove gripping his lapel
BRAVE = merge(STAND, ARMS_POMPOUS, fist("l"), grip("r", 50, 30), pompous(1.6),
              {"clavicle_l": [("y", -10)], "clavicle_r": [("y", 6)], "_pelvis": (0.0, 0.0, 0.0),
               "upperarm_r": [("y", -70), ("z", 30)], "lowerarm_r": [("z", 92)], "hand_r": [("x", 10)]})


def build(ctx):
    c = Clip(ctx, "bellows/beat_tear", length=L, cheat_deg=35, blend_in=8, blend_out=10, tags=["last_beat", "t3"])
    c.key(0, sag(0.3))
    c.key(10, sag(0.8, hz=6), "in_out_sine")
    c.key(22, sag(1.0, hx=2, hz=8), "in_out_sine")
    c.key(24, sag(1.05, hx=4, hy=2, hz=8), "out_quad")                       # the tear
    c.key(34, sag(1.0, hx=0, hy=-2, hz=8), "in_out_sine")
    c.key(40, sag(0.9, hx=-4, hz=6), "in_out_sine")
    c.key(42, merge(BRAVE, CLASP, head(x=-8), {"clavicle_l": [("y", -16)], "clavicle_r": [("y", 12)]}), "out_back")   # SNIFF
    c.key(50, merge(BRAVE, head(x=-14, z=6)), "in_out_sine")
    c.key(L, merge(BRAVE, head(x=-12, z=4)), "in_out_sine")
    # the gloves clasped at his heart (IK on the chest)
    c.ik("l", HEART_L, 0, 40, pole=POLE_L, effector="palm", blend=(0, 3), world=False)
    c.ik("r", HEART_R, 0, 40, pole=POLE_R, effector="palm", blend=(0, 3), world=False)
    # the trembling lower lip = the chin and head quiver; the sniff's shudder
    c.motion(lambda f: {"Head": [("x", 1.2 * math.sin(f * 2.4)), ("y", 0.8 * math.sin(f * 1.7))],
                        "spine_03": [("x", 0.8 * math.sin(f * 1.1))]}, 0, 42, weight=lambda f: window(f, 0, 4, 38, 42))
    c.motion(lambda f: breath(f, 30.0, 1.4), 42, L)
    c.ground(0, 0)
    hold_feet(c, 0, L)
    c.look_camera(0, L, weight=0.9, blend=4)
    c.beats(lip=(0, 24), tear=(24, 40), sniff=(40, 60), sniffle=(42, 50))
    for f, p in ((0, "sulk"), (12, "mortified"), (24, "teary"), (42, "sniff"), (48, "pompous")):
        c.face(f, p)
    return c
