"""Clips + export: <who>_uv.blend + <who>_albedo.png -> <out>/<who>.glb

blender -b --python build_anim.py -- --who hush --dir <dir> --out <glb> [--clips all|none] [--preview <dir>]
  * material: one Principled BSDF with the painted albedo (Godot swaps it for cartoon_char.gdshader)
  * COLOR_0: R = skin mask (Bellows' temper tint), G = 1 on eyeballs (no rim), B unused
  * UAL clips: pelvis translation keys scaled to the new leg length; Bellows gets an arm-out layer so
    his arms clear the barrel
  * custom comedy clips from poses.py (keyframed FK, 30 fps)
"""
import bpy, sys, os, math, json
import numpy as np
from mathutils import Vector, Quaternion, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clib

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {argv[i].lstrip("-"): argv[i + 1] for i in range(0, len(argv) - 1, 2)}
WHO = opt["who"]
D = opt["dir"]
bpy.ops.wm.open_mainfile(filepath=os.path.join(D, WHO + "_uv.blend"))
meta = json.load(open(os.path.join(D, WHO + "_meta.json")))
arm = bpy.data.objects["Armature"]
char = [o for o in bpy.data.objects if o.type == "MESH"][0]
arm.data.pose_position = "POSE"
me = char.data
bpy.context.scene.render.fps = 30

# ---- material --------------------------------------------------------------------------------
img = bpy.data.images.load(os.path.join(D, WHO + "_albedo.png"))
img.alpha_mode = "NONE"
img.name = WHO + "_albedo"
mat = bpy.data.materials.new(WHO + "_mat")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.7
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
uvn = nt.nodes.new("ShaderNodeUVMap")
uvn.uv_map = "UVMap"
nt.links.new(uvn.outputs[0], tex.inputs[0])
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
# reference the decal UV map so the exporter writes TEXCOORD_1 (occlusion slot, same image)
tex2 = nt.nodes.new("ShaderNodeTexImage")
tex2.image = img
uv2n = nt.nodes.new("ShaderNodeUVMap")
uv2n.uv_map = "UVDecal"
nt.links.new(uv2n.outputs[0], tex2.inputs[0])
grp_nt = bpy.data.node_groups.get("glTF Material Output") or bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
if not grp_nt.interface.items_tree:
    grp_nt.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
gnode = nt.nodes.new("ShaderNodeGroup")
gnode.node_tree = grp_nt
sep = nt.nodes.new("ShaderNodeSeparateColor")
nt.links.new(tex2.outputs["Color"], sep.inputs[0])
nt.links.new(sep.outputs[0], gnode.inputs["Occlusion"])
me.materials.clear()
me.materials.append(mat)

# ---- vertex colour masks -----------------------------------------------------------------------
R = meta["regions"]
reg = clib.region_array(char)
grp = clib.face_int(char, "group")
part = clib.face_int(char, "part")
for cn in [ca.name for ca in me.color_attributes if ca.data_type in ("BYTE_COLOR", "FLOAT_COLOR")]:
    me.color_attributes.remove(me.color_attributes[cn])
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
skin_regs = {R["skin"], R["lid"], R["lowlid"]} if WHO == "bellows" else set()
for p in me.polygons:
    r = int(reg[p.index])
    c = (1.0 if (r in skin_regs and grp[p.index] == 0) else 0.0, 1.0 if part[p.index] in (2, 3) else 0.0, 0.0, 1.0)
    for li in p.loop_indices:
        col.data[li].color = c
me.color_attributes.active_color = col
me.color_attributes.render_color_index = 0

# ---- clips ------------------------------------------------------------------------------------
import poses
LEG_K = meta.get("leg_k")
if LEG_K is None:
    LEG_K = (meta["joints"]["pelvis"][2]) / 0.917 if False else None
meta["_dir"] = D
poses.setup(arm, meta)
if opt.get("clips", "all") != "none":
    poses.adapt_library(arm, WHO, meta)
    poses.author(arm, WHO, meta)
print("ACTIONS", len(bpy.data.actions), sorted(a.name for a in bpy.data.actions))

if "preview" in opt:
    poses.preview(arm, char, WHO, opt["preview"], opt.get("preview_clips", ""))

# ---- export ------------------------------------------------------------------------------------
for o in list(bpy.data.objects):
    if o not in (arm, char):
        bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create()
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
out = opt.get("out", os.path.join(D, WHO + ".glb"))
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
char.select_set(True)
bpy.context.view_layer.objects.active = arm
kw = dict(filepath=out, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
          export_animations=True, export_skins=True, export_materials="EXPORT", export_image_format="AUTO",
          export_animation_mode="ACTIONS", export_optimize_animation_size=True, export_def_bones=False,
          export_frame_range=False, export_texcoords=True, export_normals=True)
props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
if "export_vertex_color" in props:
    kw["export_vertex_color"] = "ACTIVE"
if "export_all_vertex_colors" in props:
    kw["export_all_vertex_colors"] = False
if "export_active_vertex_color_when_no_material" in props:
    kw["export_active_vertex_color_when_no_material"] = True
kw = {k: v for k, v in kw.items() if k in props}
bpy.ops.export_scene.gltf(**kw)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D, WHO + "_final.blend"))
print("EXPORT_OK", out)
