"""hush/act_pop — bursts out of the hiding spot (state:popping, 15 f): out of the tucked ball (act_dive's end), a
squash, then a star jump up and out — arms and legs flung wide, the cloth flapping off her (the spot's anim) — landing
on her toes, "ta-da". `pop_out` at f 0 (table)."""
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, TIPTOE, gloves, lean, head

L = 15
BALL = {"pelvis": [("x", 40)], "thigh_l": [("x", -110)], "calf_l": [("x", 130)], "foot_l": [("x", 30)],
        "thigh_r": [("x", -104)], "calf_r": [("x", 126)], "foot_r": [("x", 30)]}
ARMS_HUG = sym({"upperarm_l": [("y", 40), ("z", -80)], "lowerarm_l": [("z", -120)], "hand_l": [("x", -20)]})
STAR_ARMS = sym({"clavicle_l": [("y", -22)], "upperarm_l": [("y", -52), ("z", -6)], "lowerarm_l": [("z", -6)],
                 "hand_l": [("x", -10), ("y", -20)]})
STAR_LEGS = {"thigh_l": [("z", 24), ("x", -6)], "calf_l": [("x", 10)], "foot_l": [("x", 30)],
             "thigh_r": [("z", -24), ("x", -6)], "calf_r": [("x", 10)], "foot_r": [("x", 30)]}
LAND = {"thigh_l": [("x", -24), ("z", 8)], "calf_l": [("x", 40)], "foot_l": [("x", 10)], "ball_l": [("x", -20)],
        "thigh_r": [("x", -22), ("z", -8)], "calf_r": [("x", 38)], "foot_r": [("x", 10)], "ball_r": [("x", -20)]}


def build(ctx):
    c = Clip(ctx, "hush/act_pop", length=L, cheat_deg=35, audio="table", blend_in=0, blend_out=8)
    stand = merge(ARMS_DOWN, STAND, gloves(16, 10), head())
    c.key(0, merge(stand, BALL, ARMS_HUG, gloves(60, 30), lean(fwd=44), head(x=34)))
    c.key(2, merge(stand, BALL, ARMS_HUG, gloves(70, 36), lean(fwd=48), head(x=38)), "in_quad")        # squash
    c.key(6, merge(stand, STAR_LEGS, STAR_ARMS, gloves(0, 0, spread=22), lean(fwd=-10), head(x=-16)), "out_back")
    c.key(9, merge(stand, STAR_LEGS, STAR_ARMS, gloves(0, 0, spread=24), lean(fwd=-8), head(x=-14)))
    c.key(12, merge(stand, LAND, STAR_ARMS, gloves(2, 0, spread=20), lean(fwd=4), head(x=-8)), "in_quad")
    c.key(L, merge(stand, TIPTOE, STAR_ARMS, gloves(2, 0, spread=20), lean(fwd=-2), head(x=-10)), "out_quad")
    c.ground(0, 3)
    c.jump(3, 12, arc=0.35)
    c.ground(12, L)
    c.auto_plant(speed_m_s=0.0)
    c.pop_frames.extend([3, 4])                            # the launch: the arms fling (a 2-frame smear)
    c.face(0, "hold_breath")
    c.face(3, "grin")
    c.face(8, "happy")
    c.mark(3, "release")
    return c
