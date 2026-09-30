"""props -- Hush's props for the view (brief 4.5): the red beret tag, the freeze plinth, the TOMATO splat, the carried
items (squeaker, magnifier, kipper, x1.5), all in look A's Toy Box construction on palette_hush.png.

    tools/art3d/blender.sh --python tools/art3d/hush/props.py -- --out game/art3d/chars/hush --palette <png>

* tag_beret.glb   -- Hush's calling card hung on armed props: a 0.28 m beret (cherry red, stalk) on a string; armature
                     `Armature` with bones `root` (the string's top = the origin), `string` (wiggle), `beret` (the hat
                     swings on the string's end). ~65 px across at the 1080 base framing.
* plinth.glb      -- the freeze plinth: stone white #E8E6E1, 0.50 m across, 0.12 m tall, chamfered; origin at its
                     bottom centre (the view scales it up under her feet in 0.1 s).
* tomato_splat.glb -- the TOMATO residue look: a squashed tomato over her face/beret side, origin = the Head bone's
                     head (attachment on bone Head, rig3d.json attachments.tomato_splat).
* carry_squeaker.glb, carry_magnifier.glb, carry_kipper.glb -- items tucked in her braces (sockets carry_1 / carry_2),
                     origin = the socket point, x1.5 of real size.
"""
import bmesh
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import palette as TP   # noqa: E402
import toy_lib as T    # noqa: E402


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return {argv[i].lstrip("-"): argv[i + 1] for i in range(0, len(argv) - 1, 2)}


opt = args()
OUT = opt.get("out", os.path.join(HERE, "..", "..", "..", "game", "art3d", "chars", "hush"))
PAL = opt.get("palette", os.path.join(OUT, "palette_hush.png"))


def to_object(bm, name, keep_g=0.0, outline=1.0):
    """bmesh (int face layer col) -> a mesh object with palette UVs + COLOR_0 masks (+ an unused FaceUV at -2 so the
    char_toon path sees 'no face')."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    layer = me.attributes.get("col")
    cols = [layer.data[i].value for i in range(len(me.polygons))] if layer is not None else [0] * len(me.polygons)
    if layer is not None:
        me.attributes.remove(layer)
    # the primitives' own UV maps (bmesh create_cube / create_cone) would export instead of the palette UVs
    # (r3d-rig: corner-only TEXCOORD_0 sampling the palette's unused magenta half): drop them first
    while len(me.uv_layers):
        me.uv_layers.remove(me.uv_layers[0])
    uv0 = me.uv_layers.new(name="UVMap")
    fuv = me.uv_layers.new(name="FaceUV")          # TEXCOORD_1 at -2: char_toon's "no face card here"
    me.uv_layers.active = uv0
    uv0.active_render = True
    vc = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    names = [c[0] for c in TP.COLORS]
    for i, p in enumerate(me.polygons):
        u = TP.cell_uv(cols[i])
        damp = 1.0 if names[cols[i]] in T.VC_DAMP else 0.0
        for li in p.loop_indices:
            uv0.data[li].uv = u
            fuv.data[li].uv = (-2.0, -2.0)
            vc.data[li].color = (0.0, keep_g, damp, outline)
        p.use_smooth = True
    me.color_attributes.active_color = vc
    return ob


def material():
    m = bpy.data.materials.new("hush_prop")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(PAL)
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


MAT = None


def export(objs, path, arm=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    if arm is not None:
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
    else:
        bpy.context.view_layer.objects.active = objs[0]
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
              export_animations=False, export_skins=True, export_materials="EXPORT", export_texcoords=True,
              export_normals=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False,
              export_active_vertex_color_when_no_material=True, export_def_bones=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props or k == "filepath"})
    print("PROP_OK", path)


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def beret_bm(center, r, h, tilt=(-8.0, -14.0, 0.0), n=7):
    def warp(d, q):
        rr = (q.x * q.x + q.y * q.y) / (r * r)
        q.z -= h * 0.9 * rr
        q.z += h * 0.25 * (1 - rr)
        return q
    bm = T.se_blob(center, r, r * 0.95, h, 2.4, "beret", n=n, warp=warp)
    top = Vector(center) + Vector((0, 0, h * 1.2))
    st = T.capsule_chain([top - Vector((0, 0, 0.02)), top + Vector((0.01, 0, 0.035))], [0.016, 0.012], "beret_dk", seg=6,
                         cap_rings=2, samples_per_m=50)
    bm = T.merge(bm, st)
    T.rot_about(bm, center, tilt)
    return bm


# ---- the red beret tag ---------------------------------------------------------------------------------------------
def build_tag():
    clear()
    L = 0.12                          # string length
    arm_d = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_d)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm_d.edit_bones.new("root")
    root.head, root.tail = (0, 0, 0), (0, 0, 0.04)
    sb = arm_d.edit_bones.new("string")
    sb.head, sb.tail, sb.parent = (0, 0, 0), (0, 0, -L), root
    bb = arm_d.edit_bones.new("beret")
    bb.head, bb.tail, bb.parent = (0, 0, -L), (0, 0, -L - 0.10), sb
    bpy.ops.object.mode_set(mode="OBJECT")
    string = T.capsule_chain([(0, 0, 0.0), (0, 0, -L - 0.01)], [0.005, 0.005], "string", seg=6, cap_rings=2, samples_per_m=40)
    knot = T.se_blob((0, 0, 0.0), 0.012, 0.012, 0.012, 2.0, "string", n=2)
    c = Vector((0.0, 0.0, -L - 0.035))
    hat = beret_bm(c, 0.14, 0.036, tilt=(-12.0, -16.0, 0.0), n=7)
    ob_s = to_object(T.merge(string, knot), "tag_string", outline=0.6)
    ob_b = to_object(hat, "tag_beret", outline=1.0)
    for o, bone in ((ob_s, "string"), (ob_b, "beret")):
        g = o.vertex_groups.new(name=bone)
        g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    ob_s.select_set(True)
    ob_b.select_set(True)
    bpy.context.view_layer.objects.active = ob_b
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "tag_beret"
    body.data.materials.append(MAT)
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("TAG tris", tris)
    export([body], os.path.join(OUT, "tag_beret.glb"), arm)


# ---- the freeze plinth -----------------------------------------------------------------------------------------------
def build_plinth():
    clear()
    R, Hh, ch = 0.25, 0.12, 0.022
    bm = T._new_bm()
    seg = 28
    rings = [(R - ch, 0.0), (R, ch), (R, Hh - ch), (R - ch, Hh)]
    vr = []
    for r, z in rings:
        vr.append([bm.verts.new((r * math.cos(2 * math.pi * j / seg), r * math.sin(2 * math.pi * j / seg), z)) for j in range(seg)])
    for k in range(len(vr) - 1):
        for j in range(seg):
            bm.faces.new((vr[k][j], vr[k][(j + 1) % seg], vr[k + 1][(j + 1) % seg], vr[k + 1][j]))
    top = bm.verts.new((0, 0, Hh))
    bot = bm.verts.new((0, 0, 0))
    for j in range(seg):
        bm.faces.new((top, vr[-1][j], vr[-1][(j + 1) % seg]))
        bm.faces.new((bot, vr[0][(j + 1) % seg], vr[0][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    T.paint_all(bm, "stone")
    T.recolor(bm, lambda c, n, cur: "stone_dk" if c.z < 0.03 else None)
    ob = to_object(bm, "plinth")
    # the plinth is flat-shaded at the chamfers only
    for p in ob.data.polygons:
        p.use_smooth = False
    ob.data.materials.append(MAT)
    print("PLINTH tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    export([ob], os.path.join(OUT, "plinth.glb"))


# ---- the TOMATO splat (attachment on bone Head) ------------------------------------------------------------------------
def build_tomato():
    clear()
    # Head bone head at (0, 0.066, 1.228) (Blender); the splat sits on her beret-side cheek and the fringe
    base = Vector((0.0, 0.066, 1.228))
    parts = []
    splat = T.se_blob((0.06, -0.125, 1.44), 0.075, 0.03, 0.06, 2.0, "red", n=5)
    parts.append(splat)
    for dx, dz, r in ((0.12, 1.40, 0.022), (-0.01, 1.49, 0.02), (0.1, 1.49, 0.018), (0.02, 1.37, 0.016)):
        parts.append(T.se_blob((dx, -0.132, dz), r, r * 0.6, r * 1.2, 2.0, "red", n=2))
    parts.append(T.se_blob((0.13, -0.115, 1.33), 0.012, 0.01, 0.03, 2.0, "red", n=2))    # a drip
    seeds = [T.se_blob((0.06 + dx, -0.158, 1.44 + dz), 0.006, 0.003, 0.009, 2.0, "pot", n=1)
             for dx, dz in ((-0.03, 0.01), (0.02, 0.02), (0.0, -0.02), (0.035, -0.01))]
    bm = T.merge(*parts, *seeds)
    T.transform(bm, Matrix.Translation(-base))
    ob = to_object(bm, "tomato_splat", outline=0.7)
    ob.data.materials.append(MAT)
    print("TOMATO tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    export([ob], os.path.join(OUT, "tomato_splat.glb"))


# ---- carried items (x1.5), origin = the carry socket ------------------------------------------------------------------
def build_carry():
    items = {}
    # squeaker: a rubber bulb + a brass reed
    bm = T.merge(T.se_blob((0, -0.02, 0.05), 0.035, 0.03, 0.04, 2.0, "red", n=4),
                 T.capsule_chain([(0, -0.02, 0.09), (0, -0.02, 0.14)], [0.012, 0.009], "clip", seg=6, cap_rings=2, samples_per_m=40))
    items["carry_squeaker"] = bm
    # magnifier: a brass ring, a pale lens, a wooden handle
    ring = T.torus(0.05, 0.009, (0, -0.02, 0.10), "clip", seg=18, rseg=6, rot=(90, 0, 0))
    lens = T.cylinder(0.045, 0.045, 0.006, (0, -0.017, 0.10), "white", seg=16, rot=(90, 0, 0))
    handle = T.capsule_chain([(0, -0.02, -0.02), (0, -0.02, 0.05)], [0.012, 0.014], "wood", seg=6, cap_rings=2, samples_per_m=40)
    items["carry_magnifier"] = T.merge(ring, lens, handle)
    # kipper: a flat smoked fish, tail up
    body = T.se_blob((0, -0.02, 0.06), 0.03, 0.012, 0.09, 2.0, "kipper", n=4)
    tail = T.se_blob((0, -0.02, 0.165), 0.035, 0.008, 0.02, 2.0, "kipper", n=2)
    eye = T.se_blob((0.0, -0.034, 0.0), 0.006, 0.003, 0.006, 2.0, "black", n=1)
    items["carry_kipper"] = T.merge(body, tail, eye)
    for name, bm in items.items():
        clear()
        ob = to_object(bm, name, outline=0.7)
        ob.data.materials.append(MAT)
        print("CARRY", name, "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
        export([ob], os.path.join(OUT, name + ".glb"))


T.reset()
MAT = material()
build_tag()
build_plinth()
build_tomato()
build_carry()
