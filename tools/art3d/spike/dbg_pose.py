import bpy, sys, math
from mathutils import Quaternion, Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1])
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
act = bpy.data.actions["Tiptoe_Sneak_Loop"]
arm.animation_data.action = act
if arm.animation_data.action_suitable_slots:
    arm.animation_data.action_slot = arm.animation_data.action_suitable_slots[0]
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()
for n in ("thigh_l", "calf_l", "foot_l", "upperarm_l", "lowerarm_l", "spine_01"):
    pb = arm.pose.bones[n]
    d = (pb.tail - pb.head).normalized()
    r = (arm.data.bones[n].tail_local - arm.data.bones[n].head_local).normalized()
    print("%-10s rest %s -> pose %s   q %s" % (n, tuple(round(v, 2) for v in r), tuple(round(v, 2) for v in d), tuple(round(v, 3) for v in pb.rotation_quaternion)))
