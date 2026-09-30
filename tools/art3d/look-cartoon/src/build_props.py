"""Small hand props for the look-dev poses (original, procedural; plain colour materials -> the diorama's
toonify() turns them into the set's toon look). Toon-oversized x1.3 like the set's kettle.

blender -b --python build_props.py -- <out_dir>
  honey_jar.glb (on the worktop), pepper_pot.glb (held: origin = grip centre, holes up +Z),
  teacup.glb (held: origin = handle), saucer.glb (held: origin = centre), pepper_puff.glb (falling pepper)
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
K = 1.3


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, rough=0.6):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*[c ** 2.2 for c in rgb], 1)
        b.inputs["Roughness"].default_value = rough
    return m


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lathe(name, prof, m, seg=28, z0=0.0):
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        rings.append([bm.verts.new((r * K * math.cos(2 * math.pi * i / seg), r * K * math.sin(2 * math.pi * i / seg), (z + z0) * K)) for i in range(seg)])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if prof[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if prof[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def prim(kind, name, m, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("seg", 20), ring_count=kw.get("rings", 12), radius=1)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("seg", 20), radius=1, depth=1)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=kw.get("R", 1), minor_radius=kw.get("r", 0.2), major_segments=kw.get("seg", 24), minor_segments=8)
    ob = bpy.context.active_object
    ob.name = name
    ob.location = Vector(loc) * K
    ob.scale = Vector(scale) * K
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return ob


def export(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True, export_format="GLB", export_yup=True, export_apply=True)


# honey jar: amber pot, gingham cloth cap tied with string, a wooden dipper poking out
reset()
amber, cloth, wood, string = mat("amber", hexrgb("F2A93B"), 0.25), mat("cloth", hexrgb("E23B4E")), mat("wood", hexrgb("B07A45")), mat("string", hexrgb("F4EBD8"))
lab = mat("label", hexrgb("FFF3D6"))
j = lathe("jar", [(0.0, 0.0), (0.04, 0.0), (0.05, 0.01), (0.055, 0.04), (0.053, 0.08), (0.043, 0.1), (0.038, 0.105), (0.0, 0.106)], amber)
l = lathe("label", [(0.0561, 0.035), (0.0561, 0.07)], lab)
cap = lathe("cap", [(0.0, 0.13), (0.03, 0.128), (0.05, 0.112), (0.058, 0.096), (0.05, 0.1), (0.0, 0.1)], cloth)
tie = prim("torus", "tie", string, (0, 0, 0.103), (0.043, 0.043, 0.2), R=1.0, r=0.12)
stick = prim("cyl", "stick", wood, (0.015, 0.0, 0.14), (0.005, 0.005, 0.08), (0, 12, 0))
knob = prim("sphere", "knob", wood, (0.024, 0.0, 0.178), (0.012, 0.012, 0.012))
export("honey_jar", [j, l, cap, tie, stick, knob])

# pepper pot: a fat black shaker with a steel dome top (holes up)
reset()
blk, steel, white = mat("blk", hexrgb("2A2530"), 0.4), mat("steel", hexrgb("C9CCD6"), 0.2), mat("white", hexrgb("FFFFFF"))
body = lathe("pp", [(0.0, -0.04), (0.026, -0.04), (0.03, -0.03), (0.028, 0.02), (0.024, 0.035), (0.0, 0.036)], blk)
top = lathe("pt", [(0.0, 0.03), (0.025, 0.03), (0.024, 0.045), (0.015, 0.055), (0.0, 0.058)], steel)
p_lab = lathe("pl", [(0.0302, -0.018), (0.0302, 0.004)], white)
export("pepper_pot", [body, top, p_lab])

# teacup (origin at the handle) + saucer
reset()
china, gold, rose = mat("china", hexrgb("FFFBF4"), 0.3), mat("gold", hexrgb("E8B33A"), 0.3), mat("rose", hexrgb("F28AA0"))
cup = lathe("cup", [(0.0, 0.0), (0.02, 0.0), (0.032, 0.012), (0.04, 0.04), (0.042, 0.052), (0.038, 0.052), (0.034, 0.02), (0.0, 0.012)], china)
rim = prim("torus", "rim", gold, (0, 0, 0.052), (0.041, 0.041, 0.1), R=1.0, r=0.06)
tea = lathe("tea", [(0.0, 0.043), (0.037, 0.043)], mat("tea", hexrgb("9A5A2A")))
hnd = prim("torus", "handle", china, (0.046, 0, 0.03), (0.013, 0.013, 0.013), (90, 0, 0), R=1.0, r=0.3)
dot = prim("sphere", "rose", rose, (0.0, -0.039, 0.03), (0.008, 0.003, 0.008))
for o in (cup, rim, tea, hnd, dot):
    o.location.x -= 0.052 * K
export("teacup", [cup, rim, tea, hnd, dot])
reset()
china, gold = mat("china", hexrgb("FFFBF4"), 0.3), mat("gold", hexrgb("E8B33A"), 0.3)
s = lathe("saucer", [(0.0, 0.0), (0.03, 0.0), (0.055, 0.008), (0.07, 0.014), (0.068, 0.016), (0.052, 0.011), (0.0, 0.006)], china)
sr = prim("torus", "srim", gold, (0, 0, 0.014), (0.069, 0.069, 0.05), R=1.0, r=0.04)
export("saucer", [s, sr])

# pepper puff: falling specks + a little cloud (placed under the pot while rigging)
reset()
pep = mat("pepper", hexrgb("3A3038"))
import random
rnd = random.Random(3)
obs = []
for i in range(26):
    z = -rnd.uniform(0.0, 0.14)
    r = 0.012 + 0.018 * (-z / 0.14)
    obs.append(prim("sphere", "s%d" % i, pep, (rnd.uniform(-r, r), rnd.uniform(-r, r), z), (0.0045, 0.0045, 0.0045), seg=6, rings=4))
export("pepper_puff", obs)
# CHOO cloud: a burst of white puffs + spray dots (placed in front of his face for the blast frames)
reset()
wh = mat("puff", hexrgb("FFFFFF"), 0.9)
sp = mat("spray", hexrgb("CFE6F2"), 0.5)
obs = []
for i in range(9):
    a = rnd.uniform(-0.7, 0.7)
    r = rnd.uniform(0.05, 0.09)
    d = rnd.uniform(0.05, 0.22)
    obs.append(prim("sphere", "c%d" % i, wh, (d, math.sin(a) * d * 0.8, math.cos(a) * d * 0.5), (r, r * 0.9, r * 0.85), seg=14, rings=8))
for i in range(14):
    d = rnd.uniform(0.18, 0.42)
    a = rnd.uniform(-0.8, 0.8)
    obs.append(prim("sphere", "d%d" % i, sp, (d, math.sin(a) * d * 0.7, math.cos(a) * d * 0.45), (0.012, 0.012, 0.012), seg=6, rings=4))
export("choo_cloud", obs)
print("PROPS_OK")
