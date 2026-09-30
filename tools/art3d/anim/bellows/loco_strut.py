"""bellows/loco_strut — the pompous strut-waddle (loop, 32 f, 1.2 m/s, stride 0.64 m; the map's `walk`): chest out,
chin up, tiny fast legs with the toes turned out, the barrel rocking side to side over the planted foot, the arms
swinging stiffly out from the barrel; a step every 16 f (contacts on f 0 / 16 = the audio table's bellows_step). In
place: the planted foot slides back at exactly 1.2 m/s in clip space (still in lane space). Cheat 20."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 32
SPEED = 1.2
G = Gait(L, SPEED, stance=15, lift=0.075, toe_out=12.0, width=1.05)


def upper(k):
    """k = +1 while the left foot is planted, -1 the right: the barrel rocks over it, the arms swing opposite."""
    return merge(ARMS_POMPOUS, gloves(22, 12), pompous(1.2),
                 {"pelvis": [("y", 4 * k), ("z", 5 * k)], "_pelvis": (0.025 * k, 0.0, 0.0)},
                 lean(fwd=-2, side=-4 * k, turn=-6 * k), head(x=-4, y=3 * k, z=5 * k),
                 {"upperarm_l": [("y", 80), ("z", 6 + 22 * k)], "upperarm_r": [("y", -80), ("z", -6 + 22 * k)],
                  "lowerarm_l": [("z", -34)], "lowerarm_r": [("z", 34)]})


def build(ctx):
    c = Clip(ctx, "bellows/loco_strut", length=L, loop=True, cheat_deg=20, stride_m=SPEED * L / 60.0,
             speed_m_s=SPEED)
    c.key(0, upper(1.0))
    c.key(L // 2, upper(-1.0))
    c.key(L, upper(1.0))
    rest = ctx.skel.head("pelvis").z

    def pel(f):
        # down on each contact, up at mid-stance (a bouncy little waddle)
        return -0.030 + 0.012 * math.cos(4 * math.pi * (f - 7) / L)
    G.apply(c, pelvis_h=pel)
    c.motion(lambda f: {"Head": [("x", 2.5 * math.sin(4 * math.pi * f / L + 1.0))],
                        "belly": [("x", 3 * math.sin(4 * math.pi * f / L))],
                        "hand_l": [("y", 8 * math.sin(2 * math.pi * f / L + 0.8))],
                        "hand_r": [("y", 8 * math.sin(2 * math.pi * f / L + 0.8))]})
    c.face(0, "pompous")
    fx_off(c)                     # the FX bones it never shows reset to hidden (an overlay's notes / stars)
    return c
