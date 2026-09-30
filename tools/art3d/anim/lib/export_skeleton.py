"""Blender: export a rig's armature alone (no mesh, no animation) — the skeleton fixture of the lint tests.
  tools/art3d/blender.sh --python tools/art3d/anim/lib/export_skeleton.py -- --rig-glb /abs/hush.glb --out /abs/skel.glb"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from lib import export as X

a = sys.argv[sys.argv.index("--") + 1:]
opt = {a[i].lstrip("-"): a[i + 1] for i in range(0, len(a) - 1, 2)}
arm = X.import_rig(opt["rig-glb"])
os.makedirs(os.path.dirname(opt["out"]), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
kw = dict(filepath=opt["out"], use_selection=True, export_format="GLB", export_yup=True, export_animations=False,
          export_skins=True, export_materials="NONE", export_def_bones=False)
props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props or k == "filepath"})
print("SKELETON", opt["out"], len(arm.data.bones), "bones")
