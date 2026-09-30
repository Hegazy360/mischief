"""hush/rig_step_down — the hop down from a step (flavour:step_down, 8 f): a stepped rig (Bellows' stool, 0.55 m) was
released mid-way and she moves off — a quick dip, a hop forward-down, a springy two-foot landing, up and ready to go
(the player faces her travel; the view moves her). Starts on the stool, ends standing on the floor (L28)."""
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, TIPTOE, gloves, lean, head

L = 8
DIP = {"thigh_l": [("x", -30), ("z", 5)], "calf_l": [("x", 52)], "foot_l": [("x", -20)],
       "thigh_r": [("x", -28), ("z", -5)], "calf_r": [("x", 50)], "foot_r": [("x", -20)]}
TUCK = {"thigh_l": [("x", -62), ("z", 6)], "calf_l": [("x", 70)], "foot_l": [("x", 26)], "ball_l": [("x", -10)],
        "thigh_r": [("x", -56), ("z", -6)], "calf_r": [("x", 66)], "foot_r": [("x", 26)], "ball_r": [("x", -10)]}
LAND = {"thigh_l": [("x", -40), ("z", 6)], "calf_l": [("x", 66)], "foot_l": [("x", -26)],
        "thigh_r": [("x", -38), ("z", -6)], "calf_r": [("x", 64)], "foot_r": [("x", -26)]}
ARMS_OUT = sym({"clavicle_l": [("y", -8)], "upperarm_l": [("y", 10), ("z", -10)], "lowerarm_l": [("z", -20)],
                "hand_l": [("x", -20)]})


def build(ctx):
    c = Clip(ctx, "hush/rig_step_down", length=L, cheat_deg=20, audio="own", blend_in=3, blend_out=8)
    stand = merge(ARMS_DOWN, STAND, gloves(22, 12), head(x=-6))
    c.start_on("stool", 0.55, "kitchen_stool")
    c.key(0, merge(stand, TIPTOE, lean(fwd=4)))
    c.key(2, merge(stand, DIP, sym({"upperarm_l": [("y", 50), ("z", 30)]}), lean(fwd=16), head(x=-16)), "in_out_quad")
    c.key(4, merge(stand, TUCK, ARMS_OUT, lean(fwd=8), head(x=-10)), "out_quad")          # airborne, arms up
    c.key(6, merge(stand, LAND, sym({"upperarm_l": [("y", 30), ("z", -16)]}), lean(fwd=18), head(x=-4)), "in_quad")
    c.key(8, merge(stand, {"thigh_l": [("x", -14), ("z", 5)], "calf_l": [("x", 26)], "foot_l": [("x", -12)],
                           "thigh_r": [("x", -12), ("z", -5)], "calf_r": [("x", 24)], "foot_r": [("x", -12)]},
                    lean(fwd=8), head(x=-8)), "out_quad")                                         # up and off
    c.ground()
    c.step_down(2, 6)
    c.auto_plant(speed_m_s=0.0)
    c.sfx(6, "step_pizz_up")
    c.face(0, "determined")
    c.face(4, "sneak")
    return c
