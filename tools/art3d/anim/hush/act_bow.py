"""hush/act_bow — the curtain-call bow (curtain:bow / state:bowing, loop 150 f = 2.5 s): she steps into it with a
flourish — the right glove sweeps across her middle, the left flung out wide — folds into a deep bow (held, the
beret nearly off), rises beaming with the left glove high to the gallery, blows a little kiss, and settles to take the
applause before bowing again (the roses are the view's). Cheat 40 (facing the house)."""
import math
from lib.clip import Clip
from lib.pose import merge, sym, mix
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head, breath, clarence

L = 150
SWEEP = {"clavicle_r": [("y", 6)], "upperarm_r": [("y", -50), ("z", 70)], "lowerarm_r": [("z", 70)],
         "hand_r": [("x", -20)],
         "clavicle_l": [("y", -14)], "upperarm_l": [("y", -10), ("z", 10)], "lowerarm_l": [("z", -10)],
         "hand_l": [("x", -30), ("y", -20)]}
BOW_LEGS = {"thigh_l": [("x", -10), ("z", 4)], "calf_l": [("x", 8)], "foot_l": [("x", -4)],
            "thigh_r": [("x", 18), ("z", -6)], "calf_r": [("x", 22)], "foot_r": [("x", 10)], "ball_r": [("x", -10)]}
HIGH_L = {"clavicle_l": [("y", -24)], "upperarm_l": [("y", -64), ("z", -14)], "lowerarm_l": [("z", -10)],
          "hand_l": [("x", -10), ("y", -24)]}
KISS_L = {"clavicle_l": [("y", -8)], "upperarm_l": [("y", 36), ("z", -84)], "lowerarm_l": [("y", -110)],
          "hand_l": [("x", -30), ("z", -20)]}


def build(ctx):
    c = Clip(ctx, "hush/act_bow", length=L, loop=True, cheat_deg=40, audio="own", blend_in=8)
    stand = merge(ARMS_DOWN, STAND, gloves(18, 12), head(x=-6))
    proud = merge(stand, lean(fwd=-4), head(x=-10, z=4), glove("l", 6, 4, spread=12))
    c.key(0, proud)
    c.key(12, merge(stand, SWEEP, BOW_LEGS, lean(fwd=12), head(x=-4)), "in_out_sine")              # the flourish
    c.key(28, merge(stand, SWEEP, BOW_LEGS, lean(fwd=62), head(x=30), {"pelvis": [("x", 14)]}), "in_out_cubic")  # BOW
    c.key(52, merge(stand, SWEEP, BOW_LEGS, lean(fwd=64), head(x=32), {"pelvis": [("x", 15)]}))
    c.key(66, merge(stand, HIGH_L, gloves(4, 2, spread=20), lean(fwd=-10), head(x=-18, z=-6)), "out_back")    # up!
    c.key(84, merge(stand, HIGH_L, gloves(4, 2, spread=20), lean(fwd=-8, side=-4), head(x=-16, z=-10)))
    c.key(94, merge(stand, KISS_L, glove("l", 40, 30), lean(fwd=2), head(x=-2, z=-4)), "in_out_sine")         # a kiss
    c.key(100, merge(stand, mix(KISS_L, HIGH_L, 0.6), gloves(0, 0, spread=24), lean(fwd=-6), head(x=-12)), "out_quad")
    c.key(120, proud, "in_out_sine")
    c.key(L, proud)
    c.motion(lambda f: breath(f, 75.0, 1.2))
    # the held bow is a living one: two little "thank you" dips of the head and shoulders, the glove circling
    def dips(f):
        if f < 26 or f > 56:
            return {}
        k = min(1.0, (f - 26) / 6.0) * min(1.0, (56 - f) / 6.0)
        s = math.sin(2 * math.pi * (f - 26) / 15.0) * k
        return {"spine_03": [("x", 4 * s)], "Head": [("x", 5 * s)], "hand_l": [("y", 12 * s)], "hand_r": [("z", 6 * s)]}
    c.motion(dips)
    # taking the applause: a little sway and nods, the left glove waving to the gallery
    def applause(f):
        if f < 116:
            return {}
        k = min(1.0, (f - 116) / 8.0) * min(1.0, (L + 2 - f) / 8.0)
        s = math.sin(2 * math.pi * (f - 116) / 17.0) * k
        return {"spine_01": [("y", 2.5 * s)], "Head": [("x", 3 * s), ("z", 2 * s)], "hand_l": [("y", 16 * s)],
                "lowerarm_l": [("z", -6 * s)]}
    c.motion(applause)
    # the beret flops forward in the bow (its stalk bone), Clarence nods too
    c.motion(lambda f: {"beret": [("x", 14 * max(0.0, math.sin(math.pi * min(1.0, max(0.0, (f - 16) / 50.0)))))]})
    c.motion(lambda f: clarence(0.0, bob=10 * max(0.0, math.sin(math.pi * min(1.0, max(0.0, (f - 20) / 40.0))))))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.sfx(28, "bow_creak")
    c.face(0, "proud")
    c.face(20, "happy")
    c.face(62, "laugh")
    c.face(92, "wink")
    c.face(104, "happy")
    c.face(122, "proud")
    c.mark(28, "accent")
    return c
