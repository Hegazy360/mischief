"""hush/freeze_2 — statue: THE THINKER (Rodin, crouched): down on her right knee, the left knee up, the right elbow
propped on it and her chin on the fist, the free hand on her hip — hunched in thought."""
from mathutils import Vector
from lib.pose import merge
from lib.hush_presets import lean, head, gloves, glove
from _freeze import build_freeze

STATUE = merge({"thigh_l": [("x", -88), ("z", 8)], "calf_l": [("x", 96)], "foot_l": [("x", -8)],
                "thigh_r": [("x", 6), ("z", -4)], "calf_r": [("x", 112)], "foot_r": [("x", 44)], "ball_r": [("x", -46)],
                "clavicle_r": [("y", -14)], "upperarm_r": [("y", 52), ("z", 56)], "lowerarm_r": [("y", 112), ("z", -10)],
                "hand_r": [("x", 30), ("z", 20)],
                "clavicle_l": [("y", 0)], "upperarm_l": [("y", 64), ("z", 20)], "lowerarm_l": [("z", -86)],
                "hand_l": [("x", -10), ("y", 30)]},
               lean(fwd=34, turn=-6), head(x=22, z=-4), glove("r", 80, 50), glove("l", 30, 20))


def build(ctx):
    # the right foot steps back (lifted at f 2) before the knee goes down
    c = build_freeze(ctx, "hush/freeze_2", STATUE, face="statue",
                     mid={"thigh_r": [("x", -30)], "calf_r": [("x", 58)], "foot_r": [("x", -14)],
                          "thigh_l": [("x", -30), ("z", 6)], "calf_l": [("x", 40)]})
    return c
