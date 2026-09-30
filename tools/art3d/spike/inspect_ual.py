import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
p = sys.argv[sys.argv.index("--") + 1]
bpy.ops.import_scene.gltf(filepath=p)
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, tuple(round(v, 3) for v in o.dimensions), o.parent.name if o.parent else None)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
print("ARM scale", arm.scale[:], "rot", arm.rotation_euler[:])
for b in arm.data.bones:
    if b.name in ("root", "pelvis", "spine_01", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l", "foot_l", "ball_l"):
        hl = arm.matrix_world @ b.head_local; tl = arm.matrix_world @ b.tail_local
        print("BONE %-11s head %s tail %s roll-axisX %s" % (b.name, tuple(round(v, 3) for v in hl), tuple(round(v, 3) for v in tl), tuple(round(v, 2) for v in (arm.matrix_world.to_3x3() @ b.matrix_local.to_3x3().col[0]))))
print("ACTIONS", len(bpy.data.actions), [a.name for a in bpy.data.actions][:8])
m = [o for o in bpy.data.objects if o.type == "MESH"]
for o in m:
    print("MESH", o.name, len(o.data.vertices), "verts; groups", len(o.vertex_groups), "mats", [s.material.name for s in o.material_slots if s.material])
