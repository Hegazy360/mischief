"""hush/freeze_4 — statue: the FLAMINGO: on her right leg, the left knee drawn high in front, its foot tucked against the right knee, arms up and back like folded wings, the head tilted, prim."""
from lib.pose import merge, sym
from lib.hush_presets import lean, head, gloves
from _freeze import build_freeze

STATUE = merge({"thigh_r": [("x", -2), ("z", 2)], "calf_r": [("x", 2)], "foot_r": [("x", -2)],
                "thigh_l": [("x", -84), ("z", 18)], "calf_l": [("x", 118)], "foot_l": [("x", 44)], "ball_l": [("x", -10)],
                "pelvis": [("y", 4)]},
               sym({"clavicle_l": [("y", -16)], "upperarm_l": [("y", -24), ("z", 34)], "lowerarm_l": [("y", 46), ("z", 10)],
                    "hand_l": [("y", 50), ("x", 10)]}),
               lean(fwd=-4, side=-6), head(y=-14, x=-10), gloves(10, 6))


def build(ctx):
    return build_freeze(ctx, "hush/freeze_4", STATUE, face="statue",
                        mid={"thigh_l": [("x", -40), ("z", 8)], "calf_l": [("x", 56)], "foot_l": [("x", 10)]})
