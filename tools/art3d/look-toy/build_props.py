"""Toy props for the look-dev shots: the honey jar (lid off, dipper). blender -b --python build_props.py -- --build dir"""
import bpy, sys, os, math
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toy_lib as T
import toy_common as C

opt = C.args()
T.reset()
S = 1.5   # toy scale
jar = T.capsule_chain([Vector((0, 0, 0.05 * S)), Vector((0, 0, 0.1 * S))], [0.06 * S, 0.062 * S], "honey_jar", seg=16, cap_rings=4, samples_per_m=30)
T.bisect(jar, (0, 0, 0.05 * S), (0, 0, 1)); T.bisect(jar, (0, 0, 0.09 * S), (0, 0, 1))
T.recolor(jar, lambda c, n, cur: "cup" if 0.05 * S < c.z < 0.09 * S and abs(n.z) < 0.8 else None)
T.delete_faces(jar, lambda c, n: c.z > 0.14 * S)
honey = T.se_blob(Vector((0, 0, 0.125 * S)), 0.055 * S, 0.055 * S, 0.012 * S, 2.0, "honey", n=5)
rim = T.torus(0.055 * S, 0.01 * S, Vector((0, 0, 0.14 * S)), "honey_jar", seg=16, rseg=5)
lid = T.se_blob(Vector((0.11 * S, 0.02, 0.012 * S)), 0.06 * S, 0.06 * S, 0.014 * S, 2.3, "jar_lid", n=5)
dip = T.capsule_chain([Vector((0.0, 0.0, 0.1 * S)), Vector((-0.05 * S, 0.02, 0.25 * S))], [0.008 * S, 0.008 * S], "wood", seg=6, cap_rings=1)
dhead = T.se_blob(Vector((0.0, 0.0, 0.11 * S)), 0.02 * S, 0.02 * S, 0.03 * S, 2.0, "honey", n=3)
import random
random.seed(5)
pep = [T.se_blob(Vector((random.uniform(-0.03, 0.03), random.uniform(-0.03, 0.03), 0.15 * S + random.uniform(0.0, 0.28))),
                 0.01, 0.01, 0.01, 2.0, "pepper", n=1) for _ in range(26)]
heap = T.se_blob(Vector((0.0, 0.0, 0.132 * S)), 0.03, 0.03, 0.012, 2.0, "pepper", n=3)
bm = T.merge(jar, honey, rim, lid, dip, dhead, *([heap] + pep if "pepper" in opt else []))
me = bpy.data.meshes.new("honey_jar")
ob = None
arm_dummy = None
body = T.Body(None, "honey_jar")
ob = body.add(bm, "prop", name="honey_jar")
ob.vertex_groups.clear()
mat = T.toy_material("toy_prop", os.path.join(opt["build"], "toy_palette.png"))
ob.data.materials.clear(); ob.data.materials.append(mat)
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=os.path.join(opt["build"], "honey_jar%s.glb" % ("_pepper" if "pepper" in opt else "")), use_selection=True, export_format="GLB",
                          export_yup=True, export_materials="EXPORT", export_texcoords=True, export_normals=True)
print("PROPS_OK tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
