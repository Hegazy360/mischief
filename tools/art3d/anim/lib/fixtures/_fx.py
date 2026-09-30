"""Shared poses for the lint fixtures (game/tests/anim3d/fixtures, test_lint3d.gd). Each fixture breaks exactly one
rule of the 3D animation lint (or none: the clean ones)."""
import math
from lib.clip import Clip
from lib.pose import sym, merge, mirror

ARMS = {"upperarm_l": [("y", 70), ("z", -4)], "lowerarm_l": [("z", -12)],
        "upperarm_r": [("y", -62), ("z", 8)], "lowerarm_r": [("z", 18)]}
LEGS = {"thigh_l": [("x", -4), ("z", 3)], "calf_l": [("x", 8)], "foot_l": [("x", -4)],
        "thigh_r": [("x", -2), ("z", -4)], "calf_r": [("x", 4)], "foot_r": [("x", -2)]}


def sway(t, amp=1.0):
    """A standing pose with a gentle two-bone sway (never a dead hold)."""
    a = 2 * math.pi * t
    return merge(ARMS, LEGS, {"spine_02": [("y", 4 * amp * math.sin(a))], "Head": [("z", 5 * amp * math.cos(a)), ("x", -2)],
                              "spine_01": [("x", 2 + 1.5 * amp * math.cos(a))]})


def arm_up(k=1.0):
    return {"upperarm_r": [("y", -62 + 150 * k), ("z", 8)], "lowerarm_r": [("z", 18 - 10 * k)]}


def arm_back(k=1.0):
    return {"upperarm_r": [("y", -62 - 25 * k), ("z", 8 - 20 * k)], "lowerarm_r": [("z", 30)]}


def take(ctx, cid, length=60, acc=(24, 27), antic=(12, 24), hold_end=54, oppose=True, **kw):
    """A small take: sway, an anticipation, an arm POP up on the accent, a moving hold, a settle."""
    c = Clip(ctx, cid, length=length, cheat_deg=kw.pop("cheat_deg", 35), audio="own", **kw)
    fr = 0
    for f in range(0, antic[0] + 1, 6):
        c.key(f, sway(f / 40.0))
        fr = f
    wind = arm_back(1.0) if oppose else arm_up(0.5)
    c.key(antic[1], merge(sway(antic[1] / 40.0), wind, {"spine_01": [("x", 8)]}), "in_out_cubic")
    c.key(acc[1], merge(sway(acc[1] / 40.0), arm_up(1.0), {"spine_01": [("x", -6)]}), "pop")
    c.key(acc[1] + 14, merge(sway((acc[1] + 14) / 40.0), arm_up(0.9), {"spine_01": [("x", -5)]}), "out_back")
    c.key(hold_end, merge(sway(hold_end / 40.0), arm_up(0.85), {"spine_01": [("x", -4)]}))
    c.key(length, sway(length / 40.0))
    c.ground()
    c.beats(anticipation=antic, accent=acc, hold=(acc[1], hold_end), settle=(hold_end, length))
    c.face(0, "neutral")
    c.face(acc[0], "shock")
    return c
