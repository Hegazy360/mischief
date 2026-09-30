import bpy, sys, math
from mathutils import Vector
A="/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/3d/assets/quaternius/"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=A+"universal-base-characters/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf")
objs=list(bpy.data.objects)
for o in objs: print("OBJ",o.name,o.type,o.parent.name if o.parent else None, o.matrix_world.to_translation(), o.scale)
arm=[o for o in objs if o.type=="ARMATURE"][0]
sh={b.name:(b.head_local.copy(),b.tail_local.copy(),b.matrix_local.copy()) for b in arm.data.bones}
for o in objs:
    if o.type=="MESH":
        me=o.data
        bb=[o.matrix_world@Vector(c) for c in o.bound_box]
        print("MESH",o.name,len(me.vertices),len(me.polygons),"zmin",min(v.z for v in bb),"zmax",max(v.z for v in bb),"vg",len(o.vertex_groups), [m.name for m in me.materials], "uv",[u.name for u in me.uv_layers], "shapes", me.shape_keys and len(me.shape_keys.key_blocks))
print("ARM", arm.name, arm.matrix_world)
bpy.ops.import_scene.gltf(filepath=A+"universal-animation-library/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb")
arm2=[o for o in bpy.data.objects if o.type=="ARMATURE" and o!=arm][0]
print("ARM2", arm2.name, arm2.matrix_world)
mx=0
for b in arm2.data.bones:
    if b.name in sh:
        h,t,m=sh[b.name]
        q1=m.to_quaternion(); q2=b.matrix_local.to_quaternion()
        ang=math.degrees(q1.rotation_difference(q2).angle)
        print("BONE %-18s dHead %.3f  len %.3f/%.3f ang %.2f" % (b.name,(arm.matrix_world@h-arm2.matrix_world@b.head_local).length,(t-h).length,(b.tail_local-b.head_local).length,ang))
for o in bpy.data.objects:
    if o.type=="MESH" and o.parent==arm2: print("UALMESH",o.name,len(o.data.polygons))
print("NACT",len(bpy.data.actions))
