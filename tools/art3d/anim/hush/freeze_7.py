"""hush/freeze_7 — statue 7 of 8, THE LAMP POST (see freeze_5 for the shared timing): bolt upright and stiff as a pole,
heels together, the left arm clamped to her side, the right arm raised straight up with the forearm bent over at the
top and the glove hanging down like the lamp — a tall thin line with a hook on top."""
from lib.pose import merge
from lib.hush_presets import glove, gloves, lean, head

from freeze_5 import statue

POSE = merge({"clavicle_r": [("y", 26)], "upperarm_r": [("y", 88), ("z", 4)], "lowerarm_r": [("z", 62)],
              "hand_r": [("x", 70)]},                                                             # the arm up, the lamp head
             {"upperarm_l": [("y", 84), ("z", 2)], "lowerarm_l": [("z", -4)], "hand_l": [("x", 4)]},   # clamped to her side
             glove("r", 12, 6), glove("l", 2, 2), lean(fwd=-2), head(x=-2, y=-6),
             {"thigh_l": [("x", 0), ("z", -2)], "calf_l": [("x", 0)], "foot_l": [("x", 0), ("z", -8)],
              "thigh_r": [("x", 0), ("z", 3)], "calf_r": [("x", 1)], "foot_r": [("x", 0), ("z", 8)]})


def build(ctx):
    return statue(ctx, "hush/freeze_7", POSE, face="statue")
