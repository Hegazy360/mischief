"""hush/freeze_4 — statue: the FLAMINGO: on her right leg, the left foot tucked up against the right knee (the knee
out to the side), arms out like wings bent at the wrist, the head tilted, prim."""
from lib.pose import merge, sym
from lib.hush_presets import lean, head, gloves
from _freeze import build_freeze

STATUE = merge({"thigh_r": [("x", -2), ("z", 2)], "calf_r": [("x", 2)], "foot_r": [("x", -2)],
                "thigh_l": [("x", -58), ("z", 52)], "calf_l": [("x", 110)], "foot_l": [("x", 40)], "ball_l": [("x", -10)],
                "pelvis": [("y", 4)]},
               sym({"clavicle_l": [("y", -12)], "upperarm_l": [("y", -8), ("z", 10)], "lowerarm_l": [("y", 18), ("z", -10)],
                    "hand_l": [("y", 60), ("x", 10)]}),
               lean(side=-6), head(y=-14, x=-6), gloves(10, 6))


def build(ctx):
    return build_freeze(ctx, "hush/freeze_4", STATUE, face="statue",
                        mid={"thigh_l": [("x", -34), ("z", 14)], "calf_l": [("x", 48)], "foot_l": [("x", 6)]})
