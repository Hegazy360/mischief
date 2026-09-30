"""hush/act_climb_in — the kitchen-window entry (oneshot:enter, 60 f = the 2D beats and sounds): crouched on the
sill (0.9 m), one glove on the frame, she swings her legs over and slips down (the creak at f 0), lands on her toes
in a crouch — "shh!" — a quick look round, then three tiptoe steps in place (f 18 / 28 / 38, soft pizzicato) and a
last, bolder one at f 50 that settles her into the sneak. Cheat 20; the player faces her right while entering."""
from lib.clip import Clip
from lib.pose import merge, sym, mix
from lib.hush_presets import ARMS_DOWN, PAWS, STAND, TIPTOE, gloves, glove, lean, head

L = 60
SILL = 0.9
PERCH = {"thigh_l": [("x", -96), ("z", 10)], "calf_l": [("x", 120)], "foot_l": [("x", -12)],
         "thigh_r": [("x", -88), ("z", -10)], "calf_r": [("x", 116)], "foot_r": [("x", -12)]}
REACH_DOWN = {"thigh_l": [("x", -40), ("z", 10)], "calf_l": [("x", 40)], "foot_l": [("x", 30)],
              "thigh_r": [("x", -96), ("z", -8)], "calf_r": [("x", 124)], "foot_r": [("x", -10)]}
DROP = {"thigh_l": [("x", -40), ("z", 6)], "calf_l": [("x", 62)], "foot_l": [("x", 36)], "ball_l": [("x", -10)],
        "thigh_r": [("x", -46), ("z", -6)], "calf_r": [("x", 70)], "foot_r": [("x", 36)], "ball_r": [("x", -10)]}
LAND = {"thigh_l": [("x", -52), ("z", 8)], "calf_l": [("x", 84)], "foot_l": [("x", 6)], "ball_l": [("x", -30)],
        "thigh_r": [("x", -48), ("z", -8)], "calf_r": [("x", 80)], "foot_r": [("x", 6)], "ball_r": [("x", -30)]}
HOLD_FRAME = merge({"clavicle_r": [("y", 20)], "upperarm_r": [("y", 70), ("z", 20)], "lowerarm_r": [("z", 30)]},
                   glove("r", 60, 40))
SHH = merge({"clavicle_l": [("y", -10)], "upperarm_l": [("y", 40), ("z", -80)], "lowerarm_l": [("y", -118)],
             "hand_l": [("x", -20), ("z", -20)]}, glove("l", 70, 30))


def lift(side, k=1.0):
    """A dainty tiptoe step: the knee up, the toe pointed."""
    return {"thigh_%s" % side: [("x", -48 * k)], "calf_%s" % side: [("x", 70 * k)], "foot_%s" % side: [("x", 30 * k)]}


def build(ctx):
    c = Clip(ctx, "hush/act_climb_in", length=L, cheat_deg=20, audio="table", blend_in=0, blend_out=10)
    sneak = merge(PAWS, STAND, TIPTOE, gloves(34, 12), lean(fwd=14), head(x=-14))
    arms0 = merge(ARMS_DOWN, gloves(20, 12))
    c.start_on("mime", SILL)
    c.key(0, merge(arms0, PERCH, HOLD_FRAME, lean(fwd=30), head(x=-20, z=10)))                       # on the sill
    c.key(4, merge(arms0, REACH_DOWN, HOLD_FRAME, lean(fwd=22), head(x=6, z=-10)), "in_out_sine")    # a leg feels down
    c.key(7, merge(arms0, PERCH, HOLD_FRAME, lean(fwd=34), head(x=-6)), "in_out_sine")                # gathers
    c.key(10, merge(arms0, DROP, sym({"upperarm_l": [("y", 20), ("z", -30)], "lowerarm_l": [("z", -40)]}),
                    {"upperarm_r": [("y", 46), ("z", 14)], "lowerarm_r": [("z", 36)]},
                    lean(fwd=6), head(x=-10)), "in_out_sine")                                        # slips down
    BAL = sym({"clavicle_l": [("y", -8)], "upperarm_l": [("y", 30), ("z", -24)], "lowerarm_l": [("z", -40)],
               "hand_l": [("x", -20)]})
    left_up = mix({k: v for k, v in arms0.items() if k.endswith("_l")}, SHH, 0.4)
    c.key(12, merge(arms0, LAND, BAL, left_up, {"upperarm_r": [("y", 10), ("z", -10)]}, lean(fwd=24),
                    head(x=-4, z=18)), "in_out_sine")                                                # lands
    c.key(15, merge(sneak, LAND, SHH, lift("l", 0.6), lean(fwd=20), head(x=-6, z=-22)), "in_out_sine")   # shh! looks
    c.key(18, merge(sneak, SHH, lean(fwd=16), head(x=-10, z=-8)), "in_quad")                        # toe down (1)
    c.key(23, merge(sneak, lift("r"), lean(fwd=16), head(x=-12, z=-6)), "in_out_sine")
    c.key(28, merge(sneak, lean(fwd=15), head(x=-14)), "in_quad")                                    # toe down (2)
    c.key(33, merge(sneak, lift("l"), lean(fwd=16), head(x=-12, z=6)), "in_out_sine")
    c.key(38, merge(sneak, lean(fwd=15), head(x=-14)), "in_quad")                                    # toe down (3)
    c.key(45, merge(sneak, lift("r", 1.3), lean(fwd=18), head(x=-10)), "in_out_sine")
    c.key(50, merge(sneak, lean(fwd=14), head(x=-14)), "in_quad")                                    # the bold one
    c.key(L, sneak, "in_out_sine")
    c.ground()
    c.step_down(7, 12, arc=0.16)
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "determined")
    c.face(8, "hold_breath")
    c.face(14, "shush")
    c.face(17, "curious")
    c.face(22, "sneak")
    c.face(50, "grin")
    c.mark(12, "contact")
    return c
