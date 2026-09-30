"""hush/freeze_3 — statue: ARMS-UP SURPRISE ("eek!"): up on her toes, both arms flung up and out in a wide V (the left
higher), gloves spread wide, one knee jerked up, the back arched, the head thrown back, mouth an O."""
from lib.pose import merge
from lib.hush_presets import lean, head, gloves, TIPTOE
from _freeze import build_freeze

STATUE = merge(TIPTOE, {"ball_l": [("x", -38)], "ball_r": [("x", -38)],
                        "thigh_l": [("x", -2), ("z", 6)], "thigh_r": [("x", -30), ("z", -10)], "calf_r": [("x", 44)],
                        "foot_r": [("x", 30)]},
               {"clavicle_l": [("y", -14)], "upperarm_l": [("y", -30), ("z", -12)], "lowerarm_l": [("z", -6)],
                "hand_l": [("x", -6), ("y", -16)],
                "clavicle_r": [("y", 12)], "upperarm_r": [("y", 22), ("z", 16)], "lowerarm_r": [("z", 14), ("y", 8)],
                "hand_r": [("x", 10), ("y", 18)]},
               lean(fwd=-16, side=-8), head(x=-16, y=-12), gloves(0, 0, spread=28))


def build(ctx):
    return build_freeze(ctx, "hush/freeze_3", STATUE, face="shock", ball_feet=("l",))
