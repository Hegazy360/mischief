import bpy, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clib
from clib import *
OUT = sys.argv[sys.argv.index("--") + 1]
for who in ("bellows", "hush"):
    reset()
    arm = load_rig(keep1=["Idle_Loop"])
    body, joints = load_base("male" if who == "bellows" else "female")
    fit_rig(arm, joints)
    bind(body, arm)
    if who == "bellows":
        sc = {"thigh_l": (1.25, 0.5, 1.25), "thigh_r": (1.25, 0.5, 1.25), "calf_l": (1.2, 0.5, 1.2), "calf_r": (1.2, 0.5, 1.2),
              "clavicle_l": (1, 1.6, 1), "clavicle_r": (1, 1.6, 1), "upperarm_l": (1.3, 0.8, 1.3), "upperarm_r": (1.3, 0.8, 1.3),
              "lowerarm_l": (1.25, 0.8, 1.25), "lowerarm_r": (1.25, 0.8, 1.25)}
    else:
        sc = {"thigh_l": (0.75, 0.8, 0.75), "thigh_r": (0.75, 0.8, 0.75), "calf_l": (0.7, 0.8, 0.7), "calf_r": (0.7, 0.8, 0.7),
              "spine_01": (0.9, 0.75, 0.9), "spine_02": (0.9, 0.75, 0.9), "spine_03": (0.9, 0.75, 0.9), "pelvis": (0.9, 0.8, 0.9),
              "upperarm_l": (0.7, 0.85, 0.7), "upperarm_r": (0.7, 0.85, 0.7), "lowerarm_l": (0.7, 0.85, 0.7), "lowerarm_r": (0.7, 0.85, 0.7),
              "hand_l": (1.6, 1.6, 1.6), "hand_r": (1.6, 1.6, 1.6), "clavicle_l": (1, 0.8, 1), "clavicle_r": (1, 0.8, 1)}
    reshape(arm, [body], sc)
    bpy.context.view_layer.update()
    zs = [v.co.z for v in body.data.vertices]
    print("H", who, min(zs), max(zs), "head", bone_head(arm, "Head"), "neck", bone_head(arm, "neck_01"), "thigh", bone_head(arm, "thigh_l"), "upperarm", bone_head(arm, "upperarm_l"))
    # pose check: play Idle frame 30
    arm.animation_data_create(); arm.animation_data.action = bpy.data.actions["Idle_Loop"]
    if hasattr(arm.animation_data, "action_slot") and arm.animation_data.action_suitable_slots:
        arm.animation_data.action_slot = arm.animation_data.action_suitable_slots[0]
    bpy.context.scene.frame_set(30)
    preview(OUT + "/p_" + who, ("front", "side"), center=(0, 0, 0.8), ortho=2.0)
