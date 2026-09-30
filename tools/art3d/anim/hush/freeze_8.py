"""hush/freeze_8 — statue 8 of 8, THE SCARECROW (see freeze_5 for the shared timing): arms stuck straight out to the
sides with the gloves drooping, the head flopped onto one shoulder, knees knocked in and one foot turned in, the whole
figure a little lopsided — the wide floppy T no other statue makes."""
from lib.pose import merge
from lib.hush_presets import glove, lean, head
from freeze_5 import statue

POSE = merge({"clavicle_l": [("y", -4)], "upperarm_l": [("y", 4), ("z", -6)], "lowerarm_l": [("z", -4), ("y", 6)],
              "hand_l": [("y", 50)]},
             {"clavicle_r": [("y", 8)], "upperarm_r": [("y", -12), ("z", 4)], "lowerarm_r": [("z", 8), ("y", -10)],
              "hand_r": [("y", -46)]},                                                            # gloves drooping
             glove("l", 20, 10), glove("r", 26, 12), lean(fwd=4, side=6), head(x=8, y=28, z=6, neck=0.45),
             {"thigh_l": [("x", -14), ("y", 10), ("z", 16)], "calf_l": [("x", 26)], "foot_l": [("x", -8), ("z", 22)],
              "thigh_r": [("x", -10), ("y", -8), ("z", -10)], "calf_r": [("x", 18)], "foot_r": [("x", -6), ("z", -6)],
              "pelvis": [("y", 5)]})


def build(ctx):
    return statue(ctx, "hush/freeze_8", POSE, face="dazed")
