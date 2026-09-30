"""hush/loco_arrive — the arrival settle at a spot (REDESIGN §4.2 "Move — tiptoe", AFTER): the sneak's last step
lands, she dips, pops up in ONE small hop with her gloves flung out for balance, lands soft on her toes and settles
into her stance with a glance down at the spot she came for. 8 f (`flavour:arrive`, clip_rules.json), played between
the walk and the idle; cheat 35° (she arrives and gives her front to the audience)."""
import math
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import PAWS, ARMS_DOWN, STAND, gloves, glove, lean, head

# the sneak's contact pose (loco_walk: paws, lean 12°, knees soft) — what the 3-f blend-in lands on
WALK_END = merge(PAWS, gloves(34, 12), lean(fwd=12, side=-2, turn=-6), head(x=-10, y=2, z=4),
                 {"thigh_l": [("x", -26)], "calf_l": [("x", 44)], "foot_l": [("x", 18)],
                  "thigh_r": [("x", -8)], "calf_r": [("x", 30)], "foot_r": [("x", 22)], "pelvis": [("x", 6)]})
# anticipation: sink into both knees, paws tucked in
DIP = merge(PAWS, gloves(40, 14), lean(fwd=14, side=-1, turn=-3), head(x=-6, y=2, z=2),
            {"upperarm_l": [("y", 36), ("z", -60)], "upperarm_r": [("y", -36), ("z", 62)],
             "lowerarm_l": [("z", -78), ("y", -18)], "lowerarm_r": [("z", 80), ("y", 18)],
             "thigh_l": [("x", -40), ("z", 3)], "calf_l": [("x", 66)], "foot_l": [("x", -18)],
             "thigh_r": [("x", -36), ("z", -3)], "calf_r": [("x", 62)], "foot_r": [("x", -20)], "pelvis": [("x", 8)]})
# the hop: legs long, toes pointed, gloves flung out to the sides (balance), head up
HOP = merge(sym({"clavicle_l": [("y", -6)], "upperarm_l": [("y", -2), ("z", -36)], "lowerarm_l": [("z", -46)],
                 "hand_l": [("y", 10), ("x", -6)]}),
            glove("l", 2, 0, spread=20), glove("r", 4, 2, spread=16), lean(fwd=2, side=0, turn=4), head(x=-8, y=-2, z=6),
            {"upperarm_r": [("y", -32), ("z", 10)],
             "thigh_l": [("x", -6), ("z", 2)], "calf_l": [("x", 10)], "foot_l": [("x", 34)],
             "thigh_r": [("x", 2), ("z", -2)], "calf_r": [("x", 16)], "foot_r": [("x", 38)]})
# landing squash: knees give, gloves still out, head already turning down to the spot
LAND = merge(sym({"clavicle_l": [("y", -4)], "upperarm_l": [("y", 22), ("z", -26)], "lowerarm_l": [("z", -34)],
                  "hand_l": [("y", -14), ("x", -4)]}),
             glove("l", 6, 4, spread=16), glove("r", 8, 4, spread=12), lean(fwd=8, side=1, turn=2), head(x=14, y=4, z=-8),
             {"upperarm_r": [("y", -44), ("z", 16)],
              "thigh_l": [("x", -30), ("z", 3)], "calf_l": [("x", 50)], "foot_l": [("x", -12)],
              "thigh_r": [("x", -26), ("z", -3)], "calf_r": [("x", 46)], "foot_r": [("x", -12)], "pelvis": [("x", 5)]})
# the settle: her stance (idle-like), gloves drifting down, the glance at the spot held
SETTLE = merge(ARMS_DOWN, STAND, gloves(16, 12), glove("r", 20, 14),
               {"upperarm_l": [("y", 50), ("z", -16)], "upperarm_r": [("y", -54), ("z", 18)],
                "lowerarm_l": [("z", -22)], "lowerarm_r": [("z", 26)]},
               lean(fwd=3, side=-2, turn=0), head(x=12, y=3, z=-6), {"pelvis": [("y", 2)]})


def build(ctx):
    c = Clip(ctx, "hush/loco_arrive", length=8, cheat_deg=35, blend_in=3, blend_out=6, audio="own")
    c.key(0, WALK_END)
    c.key(2, DIP, "out_quad")
    c.key(4, HOP, "in_out_sine")
    c.key(6, LAND, "in_quad")
    c.key(8, SETTLE, "in_out_sine")
    # the hop: the body rises 5 cm between the take-off (f 2) and the landing (f 6)
    hop = lambda f: 0.05 * math.sin(math.pi * (f - 2) / 4.0) if 2 < f < 6 else 0.0
    c.ground(lift=hop)
    c.auto_plant(speed_m_s=0.0, release=2)
    c.pop_frames.append(6)          # the landing squash is an impact frame (the knees give at once)
    c.sfx(6, "land_soft")
    c.face(0, "sneak")
    c.face(4, "grin")
    c.face(6, "curious")
    return c
