"""hush/loco_idle — the mime at rest (loop, 240 f = 4 s; REDESIGN §4.2): a contrapposto that shifts its weight left
then right, the left glove on her hip drumming its fingers, Clarence peeking out of her brace at the audience (she
glances down at him), a glove flourish ("ta-da") with the right hand. Cheat 35° (performing)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge, mirror, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head, clarence, breath, finger_drum

L = 240


def stance(w):
    """Weight on her left (w = +1) or right (w = -1): hip shifted over the standing leg, the free knee soft."""
    free = "r" if w > 0 else "l"
    stand = "l" if w > 0 else "r"
    s = 1 if w > 0 else -1
    legs = merge(STAND, {"thigh_%s" % free: [("x", -10), ("z", -4 * s)], "calf_%s" % free: [("x", 20)],
                         "foot_%s" % free: [("x", -8)],
                         "thigh_%s" % stand: [("x", -1), ("z", 3 * s)], "calf_%s" % stand: [("x", 2)]})
    return merge(legs, {"pelvis": [("y", 4 * s)], "_pelvis": (0.03 * s, 0.0, 0.0)},
                 lean(fwd=2.0, side=-6 * s), head(x=-3, y=5 * s))


RIGHT_ARM = mirror  # (for readability below)


def base(w, arm_r=None):
    arm = arm_r or {"upperarm_r": [("y", -76), ("z", 10)], "lowerarm_r": [("z", 22)], "hand_r": [("x", -8)]}
    return merge(ARMS_DOWN, stance(w), arm, gloves(20, 14), glove("r", 24, 16))


FLOURISH_UP = {"clavicle_r": [("y", 8)], "upperarm_r": [("y", -18), ("z", 30)], "lowerarm_r": [("z", 30), ("y", 20)],
               "hand_r": [("x", -20), ("y", -30)]}
FLOURISH_TA = {"clavicle_r": [("y", 12)], "upperarm_r": [("y", 6), ("z", 12)], "lowerarm_r": [("z", 8), ("y", 10)],
               "hand_r": [("x", -45), ("y", 25)]}


def build(ctx):
    c = Clip(ctx, "hush/loco_idle", length=L, loop=True, cheat_deg=35, audio="own")
    A = base(+1)
    B = base(-1)
    c.key(0, A)
    c.key(40, merge(A, head(x=-2, y=3, z=-4)))
    c.key(64, merge(A, head(x=16, y=-8, z=-34), lean(fwd=5, side=-6, turn=-10)))          # glances down at Clarence
    c.key(92, merge(A, head(x=20, y=-12, z=-38), lean(fwd=6, side=-6, turn=-12)))
    c.key(112, merge(A, head(x=-2, y=4, z=0)), "in_out_cubic")
    c.key(136, B, "in_out_sine")                                                           # the weight shift
    c.key(150, merge(B, {"upperarm_r": [("y", -60), ("z", 18)], "lowerarm_r": [("z", 34)]}), "in_out_sine")   # anticipation
    c.key(160, merge(B, FLOURISH_UP, head(x=-4, y=-6, z=-10)), "out_cubic")
    c.key(170, merge(B, FLOURISH_TA, head(x=-6, y=-8, z=-14), glove("r", 2, 0, spread=18)), "out_back")   # "ta-da"
    c.key(186, merge(B, FLOURISH_TA, head(x=-5, y=-7, z=-12), glove("r", 4, 2, spread=14)))
    c.key(204, merge(B, head(x=-2, y=-4)), "in_out_cubic")
    c.key(222, B)
    c.key(L, A, "in_out_sine")
    # the left glove on her hip, fingers drumming (IK: the palm on the hip, the elbow out)
    hip_l = ("pelvis", Vector((0.155, 0.03, 0.905)))
    c.ik("l", hip_l, 0, L, pole=(1.0, 0.7, 0.05), hand=[("x", -8), ("y", 58), ("z", 22)], blend=0)
    c.motion(lambda f: breath(f, 120.0, 1.0))
    c.motion(lambda f: finger_drum(f, "l", 24, 26), 0, L)
    c.motion(lambda f: {"Head": [("y", 1.2 * math.sin(2 * math.pi * f / 80.0))]})
    # Clarence peeks out, bobs at the audience, tucks back in
    def peek(f):
        if f < 44 or f > 118:
            return clarence(0.0)
        k = min(1.0, (f - 44) / 16.0) if f < 96 else max(0.0, (118 - f) / 22.0)
        k = k * k * (3 - 2 * k)
        return clarence(k, bob=9 * math.sin(2 * math.pi * (f - 44) / 26.0) * k)
    c.motion(peek)
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    # the face to the audience (R6: ~25 deg of head turn on top of the 35 deg cheat) — a runtime look ("gaze"), so it
    # works facing either way; off while she glances down at Clarence
    c.look_camera(0, 50, weight=0.7, blend=8)
    c.look_camera(112, L, weight=0.7, blend=8)
    c.face(0, "neutral")
    c.face(62, "curious")
    c.face(100, "happy")
    c.face(122, "neutral")
    c.face(160, "proud")
    c.face(196, "smug")
    c.face(222, "neutral")
    return c
