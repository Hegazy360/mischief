"""hush/freeze_6 — statue 6 of 8, THE BALLERINA EN POINTE (see freeze_5 for the shared timing): up on the toes of her
left foot, the right foot drawn up to the left knee (a passé), both arms flung up into a high V over the beret, chin up,
chest lifted — tall and narrow with a V on top (no other statue is that shape)."""
from lib.pose import merge, sym
from lib.hush_presets import glove, lean, head
from freeze_5 import statue

# both arms raised, the forearms curving in over the beret (the elbow bends toward her midline: y on a raised forearm)
# both arms flung up into a high V over the beret, the gloves flared (the ring would hide behind her big head)
ARMS = merge(sym({"clavicle_l": [("y", -20)], "upperarm_l": [("y", -58), ("z", 6)], "lowerarm_l": [("y", -14), ("z", -8)],
                  "hand_l": [("y", -20)]}),
             {"upperarm_r": [("y", 62), ("z", -2)]}, glove("l", 14, 8, spread=8), glove("r", 16, 8, spread=8))
LEGS = {"thigh_l": [("x", 2), ("z", 2)], "calf_l": [("x", 2)], "foot_l": [("x", 62)], "ball_l": [("x", -20)],
        "thigh_r": [("x", -66), ("y", 20), ("z", -40)], "calf_r": [("x", 118)], "foot_r": [("x", 50)]}
POSE = merge(ARMS, LEGS, lean(fwd=-6, side=3), head(x=-12, y=4, z=-6), {"pelvis": [("y", 3)]})


def build(ctx):
    return statue(ctx, "hush/freeze_6", POSE, face="proud")
