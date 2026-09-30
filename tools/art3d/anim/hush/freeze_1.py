"""hush/freeze_1 — statue: the ARABESQUE (a dancer frozen mid-pose): on the ball of her left foot, the right leg
stretched out behind and up, the body tipped forward, one arm reaching ahead and up, the other back."""
from lib.pose import merge
from lib.hush_presets import lean, head, gloves
from _freeze import build_freeze

STATUE = merge({"thigh_l": [("x", -4), ("z", 2)], "calf_l": [("x", 4)], "foot_l": [("x", 34)], "ball_l": [("x", -38)],
                "thigh_r": [("x", 62), ("z", -6)], "calf_r": [("x", 6)], "foot_r": [("x", 40)],
                "pelvis": [("x", 18)],
                "clavicle_l": [("y", -10)], "upperarm_l": [("y", -30), ("z", -62)], "lowerarm_l": [("z", -8)],
                "hand_l": [("x", -10)],
                "clavicle_r": [("y", 4)], "upperarm_r": [("y", -4), ("z", -50)], "lowerarm_r": [("z", 10)],
                "hand_r": [("x", 20)]},
               lean(fwd=6), head(x=-22, z=6), gloves(4, 2, spread=14))


def build(ctx):
    return build_freeze(ctx, "hush/freeze_1", STATUE, ball_feet=("l",))
