"""bellows/loco_irked — the irked strut (loop, 28 f, 1.32 m/s = the map's walk@tier2 264 px/s, stride 0.616 m): the
same pompous strut, shorter and sharper — fists clenched and pumping stiffly, the head pushed forward, the chin
jutting, heavier heel strikes (a step on f 0 / 14). In place (lane space). Cheat 20."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 28
SPEED = 1.32
G = Gait(L, SPEED, stance=13, lift=0.08, toe_out=8.0, width=1.0)


def upper(k):
    arms = {"upperarm_l": [("y", 78), ("z", -6 - 30 * k)], "upperarm_r": [("y", -78), ("z", 6 - 30 * k)],
            "lowerarm_l": [("z", -58 - 10 * k)], "lowerarm_r": [("z", 58 - 10 * k)],
            "hand_l": [("x", -10)], "hand_r": [("x", -10)]}
    return merge(arms, fist("l"), fist("r"), lean(fwd=8, side=-3 * k, turn=-8 * k), head(x=6, y=2 * k, z=4 * k),
                 {"pelvis": [("y", 3 * k), ("z", 6 * k)], "_pelvis": (0.018 * k, 0.0, 0.0)})


def build(ctx):
    c = Clip(ctx, "bellows/loco_irked", length=L, loop=True, cheat_deg=20, stride_m=SPEED * L / 60.0,
             speed_m_s=SPEED, audio="own")
    c.key(0, upper(1.0))
    c.key(L // 2, upper(-1.0))
    c.key(L, upper(1.0))
    G.apply(c, pelvis_h=lambda f: -0.034 + 0.014 * math.cos(4 * math.pi * (f - 6) / L))
    c.motion(lambda f: {"Head": [("x", 3 * math.sin(4 * math.pi * f / L + 1.2))]})
    c.sfx(0, "bellows_step")
    c.sfx(L // 2, "bellows_step")
    c.face(0, "irked")
    return c
