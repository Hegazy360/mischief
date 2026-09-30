"""hush/act_dive — the big cartoon leap into a hiding spot (state:diving, 15 f): a 2-frame crouch, a stretched launch,
the body flat out like a swimmer off the blocks, arms first, then tucked into a ball as she drops in (the view carries
her along the arc to the spot's z). Whoosh (table: `dive` at f 0)."""
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, lean, head

L = 15
CROUCH = {"thigh_l": [("x", -58), ("z", 6)], "calf_l": [("x", 90)], "foot_l": [("x", -26)],
          "thigh_r": [("x", -54), ("z", -6)], "calf_r": [("x", 86)], "foot_r": [("x", -26)]}
ARMS_FWD = sym({"clavicle_l": [("y", -14)], "upperarm_l": [("y", -60), ("z", -70)], "lowerarm_l": [("z", -6)],
                "hand_l": [("x", -8)]})
ARMS_BACK = sym({"upperarm_l": [("y", 50), ("z", 40)], "lowerarm_l": [("z", -12)], "hand_l": [("x", 20)]})
FLAT = {"pelvis": [("x", 62)], "thigh_l": [("x", 20)], "calf_l": [("x", 10)], "foot_l": [("x", 40)],
        "thigh_r": [("x", 26)], "calf_r": [("x", 24)], "foot_r": [("x", 40)]}
BALL = {"pelvis": [("x", 40)], "thigh_l": [("x", -110)], "calf_l": [("x", 130)], "foot_l": [("x", 30)],
        "thigh_r": [("x", -104)], "calf_r": [("x", 126)], "foot_r": [("x", 30)]}
ARMS_HUG = sym({"upperarm_l": [("y", 40), ("z", -80)], "lowerarm_l": [("z", -120)], "hand_l": [("x", -20)]})


def build(ctx):
    c = Clip(ctx, "hush/act_dive", length=L, cheat_deg=20, audio="table", blend_in=2, blend_out=6)
    stand = merge(ARMS_DOWN, STAND, gloves(16, 10), head())
    c.key(0, merge(stand, CROUCH, ARMS_BACK, lean(fwd=26), head(x=-20)))                      # coiled
    c.key(2, merge(stand, CROUCH, ARMS_BACK, lean(fwd=30), head(x=-24)), "in_quad")
    c.key(5, merge(stand, FLAT, ARMS_FWD, gloves(4, 4, spread=10), lean(fwd=6), head(x=-40)), "out_quad")   # launch
    c.key(9, merge(stand, FLAT, ARMS_FWD, gloves(4, 4, spread=10), lean(fwd=10), head(x=-36)))           # flying
    c.key(13, merge(stand, BALL, ARMS_HUG, gloves(60, 30), lean(fwd=40), head(x=30)), "in_out_quad")    # tuck in
    c.key(L, merge(stand, BALL, ARMS_HUG, gloves(60, 30), lean(fwd=44), head(x=34)))
    c.ground(0, 3)
    c.jump(3, 14, arc=0.45)
    c.ground(14, L)
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "determined")
    c.face(4, "frantic")
    c.face(12, "hold_breath")
    c.mark(5, "release")
    return c
