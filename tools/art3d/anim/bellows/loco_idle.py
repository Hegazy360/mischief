"""bellows/loco_idle — the pompous idle (loop, 240 f = 4 s; REDESIGN §4.2): chest out, chin up, the belly breathing
under his gloves; the right glove lifts into a pinkie flourish (an imaginary teacup, "hm-hm"), a glance at the
Stalls with one eyebrow up, the weight shifting on his little feet, then a cravat tug (the audio table's cravat_tug
at f 170) and back. Cheat 35 (idle). Facing-proof: the audience glance is the sidecar gaze (runtime look-at)."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 240
# gloves resting on the barrel's sides (spine_02-carried rest points), palms to the body, fingers down
HIP_L = ("spine_02", Vector((0.425, -0.12, 0.74)))
HIP_R = ("spine_02", Vector((-0.425, -0.12, 0.74)))
PALM_IN_L = [("y", 80), ("z", -20)]
PALM_IN_R = [("y", -80), ("z", 20)]


def base(w=0.0):
    """Standing, chest out; w = weight toward his left (+1) / right (-1)."""
    return merge(STAND, pompous(1.0), ARMS_POMPOUS, gloves(18, 10),
                 {"pelvis": [("y", 3 * w)], "_pelvis": (0.02 * w, 0.0, 0.0)},
                 lean(side=-3 * w), head(y=2 * w))


FLOURISH_UP = {"clavicle_r": [("y", 10)], "upperarm_r": [("y", -34), ("z", 44)], "lowerarm_r": [("z", 96), ("y", 20)],
               "hand_r": [("x", -24), ("y", -10)]}
FLOURISH_TA = {"clavicle_r": [("y", 14)], "upperarm_r": [("y", -42), ("z", 38)], "lowerarm_r": [("z", 104), ("y", 36)],
               "hand_r": [("x", -44), ("y", 18)]}
CRAVAT = {"clavicle_r": [("y", 6)], "upperarm_r": [("y", -8), ("z", 58)], "lowerarm_r": [("z", 118), ("y", 10)],
          "hand_r": [("x", -10), ("z", 30)]}


def build(ctx):
    c = Clip(ctx, "bellows/loco_idle", length=L, loop=True, cheat_deg=35)
    A = base(+1)
    B = base(-1)
    c.key(0, A)
    c.key(36, merge(A, head(x=-10, y=3, z=4)))
    c.key(56, merge(A, {"upperarm_r": [("y", 70), ("z", 14)]}), "in_out_sine")                       # anticipation dip
    c.key(70, merge(A, FLOURISH_UP, pinkie_up("r", 0.8), head(x=-12, y=4, z=-6)), "out_cubic")
    c.key(80, merge(A, FLOURISH_TA, pinkie_up("r", 1.25), head(x=-14, y=6, z=-8)), "out_back")          # the pinkie!
    c.key(92, merge(A, FLOURISH_TA, pinkie_up("r", 1.0), head(x=-13, y=5, z=-8)))
    c.key(104, merge(B, FLOURISH_UP, pinkie_up("r", 0.6), head(x=-10, y=-2, z=10)), "in_out_sine")
    c.key(118, merge(B, head(x=-9, y=-4, z=14), lean(turn=6)), "in_out_cubic")                          # the glance
    c.key(146, merge(B, head(x=-8, y=-6, z=12), lean(turn=6)))
    c.key(162, merge(B, {"upperarm_r": [("y", 64), ("z", 20)]}, head(x=-6)), "in_out_sine")
    c.key(170, merge(B, CRAVAT, grip("r", 60, 36), head(x=-16, y=-2)), "out_quad")                        # tug
    c.key(176, merge(B, CRAVAT, grip("r", 64, 36), {"lowerarm_r": [("z", 112), ("y", 14)]}, head(x=-18, y=-3)))
    c.key(184, merge(B, CRAVAT, grip("r", 60, 36), head(x=-14, y=-2)), "in_out_sine")
    c.key(204, merge(B, head(x=-9)), "in_out_cubic")
    c.key(222, merge(base(0.0), head(x=-9, y=1)), "in_out_sine")
    c.key(L, A, "in_out_sine")
    # the gloves on the barrel (IK; the right one lets go for the flourish and the tug)
    c.ik("l", HIP_L, 0, L, pole=POLE_L, hand=PALM_IN_L, effector="palm", blend=0, world=False)
    c.ik("r", HIP_R, 0, 60, pole=POLE_R, hand=PALM_IN_R, effector="palm", blend=(0, 8), world=False)
    c.ik("r", HIP_R, 206, L, pole=POLE_R, hand=PALM_IN_R, effector="palm", blend=(10, 0), world=False)
    c.motion(lambda f: breath(f, 120.0, 1.2))
    c.motion(lambda f: finger_drum(f, "l", 24, 24.0))          # drumming on his belly
    c.motion(lambda f: {"Head": [("z", 1.5 * math.sin(2 * math.pi * f / 80.0))]})
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(116, 150, weight=1.0, blend=6)
    c.beats(flourish=(56, 80), glance=(118, 150), tug=(170, 184))
    for f, p in ((0, "pompous"), (70, "smug"), (104, "pompous"), (118, "sly_smile"), (150, "pompous"),
                 (170, "disdain"), (190, "pompous")):
        c.face(f, p)
    return c
