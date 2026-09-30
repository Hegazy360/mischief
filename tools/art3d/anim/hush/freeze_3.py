"""hush/freeze_3 — statue: ARMS-UP SURPRISE ("eek!"): up on her toes, both arms flung straight up, gloves spread wide,
the back arched, the head thrown back a little, mouth an O."""
from lib.pose import merge
from lib.hush_presets import lean, head, gloves, TIPTOE
from _freeze import build_freeze

STATUE = merge(TIPTOE, {"ball_l": [("x", -38)], "ball_r": [("x", -38)], "thigh_l": [("x", -2), ("z", 6)], "thigh_r": [("x", -18), ("z", -8)], "calf_r": [("x", 30)]},
               {"clavicle_l": [("y", -26)], "upperarm_l": [("y", -80), ("z", -4)], "lowerarm_l": [("z", -2)],
                "hand_l": [("x", -6), ("y", -10)],
                "clavicle_r": [("y", 18)], "upperarm_r": [("y", 58), ("z", 20)], "lowerarm_r": [("z", 26), ("y", 20)],
                "hand_r": [("x", 10), ("y", 14)]},
               lean(fwd=-12, side=-6), head(x=-14, y=-10), gloves(0, 0, spread=26))


def build(ctx):
    return build_freeze(ctx, "hush/freeze_3", STATUE, face="shock", ball_feet=("l", "r"))
