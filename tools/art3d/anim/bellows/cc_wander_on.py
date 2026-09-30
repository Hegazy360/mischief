"""bellows/cc_wander_on — the curtain call's walk-on (144 f; clip_rules.json curtain:wander_on — the curtain call
slides him across the band while it plays): he ambles on in his strut, gloves on his belly, humming, gazing up at
the flies and round the "room" as if it were his own parlour — not knowing he's on stage (st_double_take follows
when he sees the Stalls). In place at 1.2 m/s (the strut's gait), cheat 20."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 144
SPEED = 1.2
G = Gait(32, SPEED, stance=15, lift=0.07, toe_out=12.0, width=1.05)
HIP_L = ("spine_02", Vector((0.425, -0.12, 0.74)))
HIP_R = ("spine_02", Vector((-0.425, -0.12, 0.74)))


def amble(k, hx=-10.0, hy=0.0, hz=0.0):
    return merge(ARMS_POMPOUS, gloves(18, 10), pompous(1.1),
                 {"pelvis": [("y", 4 * k), ("z", 5 * k)], "_pelvis": (0.025 * k, 0.0, 0.0)},
                 lean(fwd=-2, side=-4 * k, turn=-6 * k), head(x=hx, y=hy + 3 * k, z=hz))


def build(ctx):
    c = Clip(ctx, "bellows/cc_wander_on", length=L, cheat_deg=20, stride_m=None, speed_m_s=SPEED, audio="own")
    # the gaze wanders: up to the flies, round to his right, up again, then a satisfied nod
    look = [(0, (-10, 0, 0)), (32, (-24, 4, 10)), (64, (-18, -4, -22)), (96, (-28, 6, 6)), (128, (-8, 0, 12)),
            (144, (-10, 0, 8))]
    for i, (f, (hx, hy, hz)) in enumerate(look):
        c.key(f, amble(1.0 if (f // 16) % 2 == 0 else -1.0, hx, hy, hz), "in_out_sine")
    c.motion(lambda f: {"spine_01": [("y", -3 * math.cos(2 * math.pi * f / 32.0))],
                        "pelvis": [("z", 4 * math.cos(2 * math.pi * f / 32.0))],
                        "Head": [("x", 2 * math.sin(4 * math.pi * f / 32.0 + 1.0))]})
    G.apply(c, pelvis_h=lambda f: -0.030 + 0.012 * math.cos(4 * math.pi * (f - 7) / 32.0), f1=L)
    c.ik("l", HIP_L, 0, L, pole=POLE_L, hand=[("y", 80), ("z", -20)], effector="palm", blend=0, world=False)
    c.ik("r", HIP_R, 0, L, pole=POLE_R, hand=[("y", -80), ("z", 20)], effector="palm", blend=0, world=False)
    for f in range(0, L + 1, 16):
        c.sfx(f, "bellows_step", vol_db=-4.0)
    c.look_camera(48, 128, weight=0.6, blend=8)   # D8: the blissful face turned 3/4 to the Stalls, still gazing up
    c.face(0, "hum")
    c.face(64, "blissful")
    c.face(112, "hum")
    fx_off(c)                     # the FX bones it never shows reset to hidden (an overlay's notes / stars)
    return c
