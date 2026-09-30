"""bellows/loco_blind_shuffle — the blind shuffle (loop, 24 f, 1.2 m/s, stride 0.48 m; the map's `walk@blind`): the
bouffant flipped over his eyes (the residue's slot, not the clip's), both gloves out in front groping the air with
the fingers spread, the head poking forward and turning to listen, the slippers barely leaving the floor (a scuff
on each step: the audio table's slipper_scuff on f 0 / 12). The Gate-0 aftermath the owner watches all the way to
the mirror. In place (the planted foot slides back at exactly 1.2 m/s in clip space). Cheat 20."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 24
SPEED = 1.2
G = Gait(L, SPEED, stance=14, lift=0.03, toe_out=6.0, width=1.1, pitch_sw=-8.0, rise=0.35)


def upper(k):
    """k = +1 on the left step, -1 on the right: the gloves reach alternately, the barrel rolls over the foot."""
    arms = {"clavicle_l": [("z", -8 - 4 * k)], "clavicle_r": [("z", 8 - 4 * k)],
            "upperarm_l": [("y", 18 - 4 * k), ("z", -72 - 10 * k)], "upperarm_r": [("y", -18 - 4 * k), ("z", 72 - 10 * k)],
            "lowerarm_l": [("z", -14 + 6 * k)], "lowerarm_r": [("z", 14 + 6 * k)],
            "hand_l": [("x", 12), ("y", -6 * k)], "hand_r": [("x", 12), ("y", -6 * k)]}
    return merge(arms, open_hand("l", 22), open_hand("r", 22), lean(fwd=10, side=-3 * k, turn=-5 * k),
                 head(x=12, y=4 * k, z=-10 * k), {"pelvis": [("y", 3 * k), ("z", 4 * k)], "_pelvis": (0.02 * k, 0.0, 0.0)})


def build(ctx):
    c = Clip(ctx, "bellows/loco_blind_shuffle", length=L, loop=True, cheat_deg=20, stride_m=SPEED * L / 60.0,
             speed_m_s=SPEED)
    c.key(0, upper(1.0))
    c.key(L // 2, upper(-1.0))
    c.key(L, upper(1.0))
    G.apply(c, pelvis_h=lambda f: -0.034 + 0.006 * math.cos(4 * math.pi * (f - 5) / L))
    # fingers feeling the air (a slow wiggle), the head listening
    c.motion(lambda f: {"index_01_l": [("y", 10 * math.sin(2 * math.pi * f / 12.0))],
                        "middle_01_l": [("y", 10 * math.sin(2 * math.pi * f / 12.0 + 1.0))],
                        "index_01_r": [("y", -10 * math.sin(2 * math.pi * f / 12.0 + 2.0))],
                        "middle_01_r": [("y", -10 * math.sin(2 * math.pi * f / 12.0 + 3.0))]})
    c.face(0, "huh")
    return c
