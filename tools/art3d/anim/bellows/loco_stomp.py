"""bellows/loco_stomp — the livid stomp (loop, 26 f, 1.38 m/s = the map's walk@tier3 276 px/s, +15 % on the strut;
stride 0.598 m): head down like a bull, the barrel pitched forward, fists pumping hard, each slipper hauled up high
and SLAMMED down (a stamp on f 0 / 13 — the contact sounds), the whole body jolting on every stamp, a puff of ear
steam once a cycle. In place (lane space: the planted foot slides back at exactly the walk speed). Cheat 20.
Audio "own" (a loop: its contact sounds are new rows for r3d-integrate)."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 26
SPEED = 1.38


class Stomp(Gait):
    """The Gait with a stamping swing: the slipper is hauled up fast and high (knee up), hangs, then drops hard onto
    its contact (the last third of the swing is the slam)."""

    def foot(self, f, side):
        s = self.stance / float(self.L)
        ph = self.phase(f, side)
        if ph < s:
            return Gait.foot(self, f, side)
        v = (ph - s) / (1.0 - s)
        e = 0.5 - 0.5 * math.cos(math.pi * min(1.0, v * 1.15))
        y = self.front + self.D - self.D * e
        up = math.sin(math.pi * min(1.0, v / 0.62) * 0.5) if v < 0.62 else math.cos(math.pi * 0.5 * (v - 0.62) / 0.38) ** 1.6
        z = self.lift * up
        return y, z, -26.0 * math.sin(math.pi * v), False


G = Stomp(L, SPEED, stance=12, lift=0.15, toe_out=6.0, width=1.05, pitch_sw=-26.0)


def upper(k):
    """k = +1 while the left foot is planted (the right arm forward), -1 the right."""
    arms = {"clavicle_l": [("z", -6)], "clavicle_r": [("z", -6)],
            "upperarm_l": [("y", 76), ("z", -10 - 40 * k)], "upperarm_r": [("y", -76), ("z", 10 - 40 * k)],
            "lowerarm_l": [("z", -62 - 16 * k)], "lowerarm_r": [("z", 62 - 16 * k)],
            "hand_l": [("x", -12)], "hand_r": [("x", -12)]}
    return merge(arms, fist("l"), fist("r"), lean(fwd=14, side=-4 * k, turn=-10 * k), head(x=10, y=3 * k, z=5 * k),
                 {"pelvis": [("y", 4 * k), ("z", 8 * k)], "_pelvis": (0.022 * k, 0.0, 0.0)})


def build(ctx):
    c = Clip(ctx, "bellows/loco_stomp", length=L, loop=True, cheat_deg=20, stride_m=round(SPEED * L / 60.0, 4),
             speed_m_s=SPEED, audio="own", tags=["walk", "tier3", "livid"])
    c.key(0, upper(1.0))
    c.key(L // 2, upper(-1.0))
    c.key(L, upper(1.0))

    def pel(f):
        # jolted down on each stamp (f 0 / 13), up while the slipper is hauled high
        ph = (f % (L / 2.0)) / (L / 2.0)
        return -0.045 + 0.018 * math.sin(math.pi * ph) - 0.012 * math.exp(-((ph - 0.04) / 0.08) ** 2)
    G.apply(c, pelvis_h=pel)
    # the stamp's jolt through the barrel and the head (a sharp nod on each contact)
    c.motion(lambda f: {"spine_03": [("x", 3.0 * math.exp(-((f % 13) / 3.0)))],
                        "Head": [("x", 5.0 * math.exp(-((f % 13) / 3.0)) - 2.0)],
                        "belly": [("x", 2.0 * math.sin(4 * math.pi * f / L))]})
    c.sfx(0, "stomp")
    c.sfx(L // 2, "stomp")
    c.event(0, "fx", id="steam")
    c.event(0, "jiggle", bones=["belly", "sideburn_l", "sideburn_r"], kick=0.3)
    c.face(0, "furious")
    return c
