"""Re-dress a KayKit character as a Mischief Next Door cast member.

    blender -b --python redress.py -- --who hush --src <Rogue.glb> --atlas <hush_atlas.png>
                                      --out <dir> [--quick]

The body, skeleton and skinning are KayKit's (CC0) and are never rebuilt -- that was the lesson of
the procedural pipeline this replaces. What happens here is only what makes the character ours:

  1. delete the meshes whose palette cells clash with the re-dress (Rogue cape, Barbarian bear hat);
  2. swap the gradient atlas for the recoloured one (tools/art3d/cast/recolour.py);
  3. add accessories -- beret, Breton bands, bouffant, nose, specs -- as new meshes on new bones
     parented into KayKit's rig, so the 132 library clips still drive everything, and the jiggle
     bones the runtime expects (game/view/char3d/jiggle3d.gd) exist;
  4. write the rig3d descriptor the runtime loads, mapping our 2D clip channels onto KayKit's
     bone names so the authored gag poses still replay as an overlay.

Accessory geometry reuses the look-dev's blob/capsule helpers (tools/art3d/look-toy/toy_lib.py),
which never depended on the discarded skeleton.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "look-toy"))
import toy_lib as T  # noqa: E402

# KayKit Rig_Medium bone names -> the 2D clip channels in game/data/rigs/<rig>/rig.json.
# KayKit has no neck bone (chest parents head directly), so the 2D "head" channel is not split.
FK_MAP = {
    "pelvis": ["hips"],
    "torso": ["spine", "chest"],
    "head": ["head"],
    "arm_upper_l": ["upperarm.l"], "arm_lower_l": ["lowerarm.l"], "hand_l": ["hand.l"],
    "arm_upper_r": ["upperarm.r"], "arm_lower_r": ["lowerarm.r"], "hand_r": ["hand.r"],
    "leg_upper_l": ["upperleg.l"], "leg_lower_l": ["lowerleg.l"], "foot_l": ["foot.l"],
    "leg_upper_r": ["upperleg.r"], "leg_lower_r": ["lowerleg.r"], "foot_r": ["foot.r"],
}
SPLITS = {"torso": {"spine": 0.55, "chest": 0.45}}
# Verified by rendering hush/loco_walk on this rig with each candidate axis (see mnd_rig.py).
FK_AXIS = (1.0, 0.0, 0.0)

# Atlas sample points for flat-coloured accessories: the centre of the 8x8 cell that
# tools/art3d/cast/recolour.py repaints. Keep in step with the maps there.
def _cell(cx, cy):
    return ((cx + 0.5) / 8.0, (cy + 0.5) / 8.0)


CELL = {
    # Hush (Rogue atlas)
    "red": _cell(3, 0), "cream": _cell(1, 2), "navy": _cell(0, 3),
    # Bellows (Mage atlas)
    "silver": _cell(1, 0), "peach": _cell(0, 1), "gold": _cell(4, 0),
    "plum": _cell(0, 2), "vest": _cell(3, 0),
}

# Atlas cells of the Rogue tunic, which paint_stripes turns into Breton bands.
TUNIC_CELLS = {(0, 3), (1, 2)}

DROP = {"hush": ["Cape"], "bellows": ["Hat", "Cape"]}
# KayKit .glb files carry a stray unskinned "Icosphere" helper (a -1..1 ball). It is not part of
# the character, and leaving it in doubles the measured height and ships a hidden mesh.
JUNK = ("Icosphere",)


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"who": "hush", "src": "", "atlas": "", "out": os.path.join(HERE, "build"), "quick": False}
    i = 0
    while i < len(a):
        if a[i] in ("--who", "--src", "--atlas", "--out"):
            o[a[i][2:]] = a[i + 1]
            i += 2
        elif a[i] == "--quick":
            o["quick"] = True
            i += 1
        else:
            i += 1
    return o


def import_character(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    return arm, meshes


def drop_meshes(meshes, suffixes):
    kept = []
    for o in meshes:
        if any(s in o.name for s in tuple(suffixes) + JUNK):
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            kept.append(o)
    return kept


def world_box(ob):
    """(min, max) of a mesh in world space."""
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def part_box(meshes, suffix):
    """(centre, size) of the mesh whose name ends with `suffix`, or None.

    Accessories are placed off MESH bounds, never off bone positions. A KayKit head is extremely
    chibi -- the skull reaches z 2.18 while the head BONE tail is at 1.49 -- so anything sized from
    the bone ends up buried inside the skull.
    """
    for o in meshes:
        if o.name.endswith(suffix):
            lo, hi = world_box(o)
            return (lo + hi) * 0.5, (hi - lo)
    return None


def swap_atlas(meshes, atlas_png):
    """Point every material's base-colour image at the recoloured atlas."""
    img = bpy.data.images.load(atlas_png)
    img.name = "cast_atlas"
    done = set()
    for o in meshes:
        for slot in o.material_slots:
            m = slot.material
            if m is None or m.name in done or not m.use_nodes:
                continue
            done.add(m.name)
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE":
                    n.image = img
                    n.interpolation = "Closest"
    return len(done)


def bone_world(arm, name):
    return arm.matrix_world @ arm.data.bones[name].head_local


def bone_tail(arm, name):
    return arm.matrix_world @ arm.data.bones[name].tail_local


def add_bones(arm, specs):
    """specs: [(name, parent, head Vector, tail Vector)] in armature space."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for name, parent, h, t in specs:
        if name in eb:
            continue
        b = eb.new(name)
        b.head, b.tail, b.roll = Vector(h), Vector(t), 0.0
        b.parent = eb[parent]
        b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")


def attach(bm, arm, bone, name, material):
    """Turn a bmesh into a mesh rigidly skinned to one bone, parented under the armature."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.uv_layers.new(name="UVMap")
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    if material is not None:
        me.materials.append(material)
    g = ob.vertex_groups.new(name=bone)
    g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def face_cell(ob, poly, grid=8):
    """Which atlas cell a face currently samples (glTF cell coords)."""
    uv = ob.data.uv_layers[0]
    u = sum(uv.data[li].uv[0] for li in poly.loop_indices) / len(poly.loop_indices)
    v = sum(uv.data[li].uv[1] for li in poly.loop_indices) / len(poly.loop_indices)
    v = 1.0 - v     # Blender bottom-left -> glTF top-left
    return min(grid - 1, max(0, int(u * grid))), min(grid - 1, max(0, int(v * grid)))


def paint_stripes(ob, cells, z0, z1, bands, cell_a, cell_b):
    """Repaint the faces of `ob` that currently sample any cell in `cells` as horizontal stripes.

    Hush's Breton stripes cannot come from the atlas: a KayKit face samples one flat palette cell,
    so the whole tunic is one colour whatever is painted in that cell. Adding hoops of geometry
    round the torso was the first attempt and read as barrel bands, not cloth. Instead the tunic's
    OWN faces are re-assigned, cell A or cell B by height band -- real stripes that follow the body
    exactly, skin with it for free, and cost no extra triangles.
    """
    uv = ob.data.uv_layers[0]
    painted = 0
    for poly in ob.data.polygons:
        if face_cell(ob, poly) not in cells:
            continue
        z = sum((ob.matrix_world @ ob.data.vertices[vi].co).z for vi in poly.vertices) / len(poly.vertices)
        band = int((z - z0) / max(1e-6, (z1 - z0)) * bands)
        u, v = cell_a if band % 2 == 0 else cell_b
        for li in poly.loop_indices:
            uv.data[li].uv = (u, 1.0 - v)
        painted += 1
    return painted


def palette_uv(ob, u, v):
    """Flat-colour an accessory by pinning every loop to one point of the atlas.

    `v` is given in glTF space (origin top-left), which is what recolour.py's cell grid uses.
    Blender's UV origin is bottom-left and its glTF exporter flips v on the way out, so the value
    stored here must be flipped first -- otherwise every accessory samples the mirrored row and
    comes out the wrong colour (the beret arrives blue instead of cherry red).
    """
    uv = ob.data.uv_layers[0]
    for lp in uv.data:
        lp.uv = (u, 1.0 - v)


# --------------------------------------------------------------------------------------------
# accessories
# --------------------------------------------------------------------------------------------
def build_hush(arm, meshes, mat, n):
    """Cherry beret on a jiggle bone, Breton bands round the chest, red braces."""
    head_c, head_s = part_box(meshes, "Head")
    body_c, body_s = part_box(meshes, "Body")
    chest = bone_world(arm, "chest")
    spine = bone_world(arm, "spine")
    crown = head_c.z + head_s.z * 0.5

    add_bones(arm, [
        ("beret", "head", Vector((head_c.x, head_c.y, crown - head_s.z * 0.07)),
         Vector((head_c.x, head_c.y, crown + head_s.z * 0.14))),
        ("brace_l", "chest", chest + Vector((body_s.x * 0.22, -body_s.y * 0.30, 0.06)),
         chest + Vector((body_s.x * 0.20, -body_s.y * 0.34, -0.22))),
        ("brace_r", "chest", chest + Vector((-body_s.x * 0.22, -body_s.y * 0.30, 0.06)),
         chest + Vector((-body_s.x * 0.20, -body_s.y * 0.34, -0.22))),
    ])
    out = []
    # Beret: a tilted disc sitting ON the crown. `crown` is the top of the HEAD MESH, which on the
    # Rogue includes her swept hair -- putting the beret at the skull's height buries it in the bob.
    # Sit it ON the hair, not above it: a floating beret shows the camera only its shadowed
    # underside, which reads as a dark disc rather than a cherry-red hat.
    r = head_s.x * 0.46
    c = Vector((head_c.x, head_c.y + head_s.y * 0.06, crown - head_s.z * 0.055))
    bm = T.se_blob(c, r, r * 0.95, head_s.z * 0.105, 2.4, "beret", n=n)
    T.rot_about(bm, c, (-11, 0, 5))
    ob = attach(bm, arm, "beret", "Hush_Beret", mat)
    palette_uv(ob, *CELL["red"])
    out.append(ob)
    bm = T.se_blob(c + Vector((0, 0, head_s.z * 0.11)), r * 0.11, r * 0.11, head_s.z * 0.06, 2.0, "beret", n=5)
    ob = attach(bm, arm, "beret", "Hush_BeretStalk", mat)
    palette_uv(ob, *CELL["red"])
    out.append(ob)
    # Breton stripes, painted onto the tunic's own faces (see paint_stripes).
    body = next(o for o in meshes if o.name.endswith("Body"))
    n_painted = paint_stripes(body, TUNIC_CELLS, spine.z - 0.05, chest.z + 0.26, 7,
                              CELL["navy"], CELL["cream"])
    print("[redress]   striped %d tunic faces" % n_painted)
    # Braces over the shoulders.
    for side in ("l", "r"):
        a = bone_world(arm, "brace_%s" % side)
        b = bone_tail(arm, "brace_%s" % side)
        bm = T.capsule_chain([a, b], [body_s.x * 0.048, body_s.x * 0.042], "braces", seg=8)
        ob = attach(bm, arm, "brace_%s" % side, "Hush_Brace%s" % side.upper(), mat)
        palette_uv(ob, *CELL["red"])
        out.append(ob)
    return out


def build_bellows(arm, meshes, mat, n):
    """Silver bouffant in three lobes, a bulbous nose, gold specs and a cravat."""
    head_c, head_s = part_box(meshes, "Head")
    body_c, body_s = part_box(meshes, "Body")
    chest = bone_world(arm, "chest")
    crown = head_c.z + head_s.z * 0.5
    fwd = -head_s.y * 0.5          # KayKit characters face -Y in Blender after the glTF import

    add_bones(arm, [
        ("bouffant_c", "head", Vector((head_c.x, head_c.y, crown - head_s.z * 0.06)),
         Vector((head_c.x, head_c.y, crown + head_s.z * 0.16))),
        ("bouffant_l", "head", Vector((head_c.x + head_s.x * 0.30, head_c.y, crown - head_s.z * 0.14)),
         Vector((head_c.x + head_s.x * 0.48, head_c.y, crown + head_s.z * 0.02))),
        ("bouffant_r", "head", Vector((head_c.x - head_s.x * 0.30, head_c.y, crown - head_s.z * 0.14)),
         Vector((head_c.x - head_s.x * 0.48, head_c.y, crown + head_s.z * 0.02))),
        ("nose", "head", Vector((head_c.x, head_c.y + fwd * 0.72, head_c.z)),
         Vector((head_c.x, head_c.y + fwd * 1.05, head_c.z))),
        ("cravat", "chest", chest + Vector((0, fwd * 0.55, 0.02)),
         chest + Vector((0, fwd * 0.65, -0.14))),
    ])
    out = []
    for bone, k, off in (("bouffant_c", 0.46, Vector((0, 0, head_s.z * 0.06))),
                         ("bouffant_l", 0.32, Vector((head_s.x * 0.06, 0, 0))),
                         ("bouffant_r", 0.32, Vector((-head_s.x * 0.06, 0, 0)))):
        c = bone_world(arm, bone) + off
        bm = T.se_blob(c, head_s.x * k, head_s.y * k * 0.92, head_s.z * k * 0.70, 2.3, "bouffant", n=n)
        ob = attach(bm, arm, bone, "Bellows_%s" % bone, mat)
        palette_uv(ob, *CELL["silver"])
        out.append(ob)
    # Nose.
    c = bone_world(arm, "nose")
    bm = T.se_blob(c, head_s.x * 0.13, head_s.y * 0.15, head_s.z * 0.11, 2.1, "nose", n=max(5, n - 3))
    ob = attach(bm, arm, "nose", "Bellows_Nose", mat)
    palette_uv(ob, *CELL["peach"])
    out.append(ob)
    # Gold half-moon specs.
    for sx in (1.0, -1.0):
        c = Vector((head_c.x + head_s.x * 0.16 * sx, head_c.y + fwd * 0.70, head_c.z + head_s.z * 0.07))
        bm = T.torus(head_s.x * 0.13, head_s.x * 0.022, c, "specs", seg=18, rseg=5, rot=(90, 0, 0))
        ob = attach(bm, arm, "head", "Bellows_Spec%s" % ("L" if sx > 0 else "R"), mat)
        palette_uv(ob, *CELL["gold"])
        out.append(ob)
    # Cravat at the throat.
    c = bone_world(arm, "cravat")
    bm = T.se_blob(c, body_s.x * 0.20, body_s.y * 0.22, body_s.z * 0.11, 2.2, "cravat", n=max(6, n - 2))
    ob = attach(bm, arm, "cravat", "Bellows_Cravat", mat)
    palette_uv(ob, *CELL["cream"])
    out.append(ob)
    return out


BUILD = {"hush": build_hush, "bellows": build_bellows}
JIGGLE = {
    "hush": [
        ("beret", "head", 150.0, 0.62, 15.0),
        ("brace_l", "chest", 220.0, 0.70, 8.0),
        ("brace_r", "chest", 220.0, 0.70, 8.0),
    ],
    "bellows": [
        ("bouffant_c", "head", 130.0, 0.60, 14.0),
        ("bouffant_l", "head", 115.0, 0.56, 18.0),
        ("bouffant_r", "head", 115.0, 0.56, 18.0),
        ("nose", "head", 300.0, 0.80, 6.0),
        ("cravat", "chest", 140.0, 0.58, 18.0),
    ],
}


# Design heights on stage (REDESIGN_3D §5.6). KayKit models are authored in their own units, so
# the runtime scales each character by height_m / model_height_u.
DESIGN_HEIGHT = {"hush": 1.60, "bellows": 1.78}


def descriptor(who, arm, tris, model_height):
    return {
        "version": 1,
        "rig": who,
        "doc": "KayKit %s re-dressed by tools/art3d/cast/redress.py. Body, skeleton and skinning "
               "are KayKit (CC0); the palette and accessories are ours. Base animation comes from "
               "the KayKit library clips; the 2D clips in game/data/anim/%s replay as overlays "
               "through fk_map." % (who, who),
        "source": "KayKit Adventurers 2.0 / Character Animations 1.1 (CC0, Kay Lousberg)",
        "height_m": DESIGN_HEIGHT[who],
        "model_height_u": model_height,
        "fk_axis": list(FK_AXIS),
        "fk_map": FK_MAP,
        "splits": SPLITS,
        "jiggle": [{"bone": b, "parent": p, "stiffness": s, "damping": d, "max_deg": m}
                   for b, p, s, d, m in JIGGLE[who]],
        "sockets": ["handslot.l", "handslot.r"],
        "ik": {
            "arm_l": {"upper": "upperarm.l", "lower": "lowerarm.l", "tip": "hand.l", "bend": [0, -1, 0]},
            "arm_r": {"upper": "upperarm.r", "lower": "lowerarm.r", "tip": "hand.r", "bend": [0, -1, 0]},
            "leg_l": {"upper": "upperleg.l", "lower": "lowerleg.l", "tip": "foot.l", "bend": [0, 0, 1]},
            "leg_r": {"upper": "upperleg.r", "lower": "lowerleg.r", "tip": "foot.r", "bend": [0, 0, 1]},
        },
        "feet": ["foot.l", "foot.r"],
        "toes": ["toes.l", "toes.r"],
        "face": {"atlas": "face_%s.png" % who, "uv": "FaceUV"},
        "tris": tris,
        "bones": len(arm.data.bones),
    }


def export(arm, path):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False,
              export_yup=True, export_animations=False, export_skins=True,
              export_materials="EXPORT", export_image_format="AUTO", export_texcoords=True,
              export_normals=True, export_frame_range=False, export_def_bones=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props or k == "filepath"})


def main():
    o = args()
    who = o["who"]
    n = 7 if o["quick"] else 11
    arm, meshes = import_character(o["src"])
    meshes = drop_meshes(meshes, DROP.get(who, []))
    swap_atlas(meshes, o["atlas"])
    mat = meshes[0].data.materials[0] if meshes[0].data.materials else None
    BUILD[who](arm, meshes, mat, n)

    tris = 0
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.data.calc_loop_triangles()
            tris += len(ob.data.loop_triangles)
    zs = [(ob.matrix_world @ v.co).z for ob in bpy.data.objects if ob.type == "MESH"
          for v in ob.data.vertices]
    model_height = round(max(zs) - min(zs), 3) if zs else 1.0

    os.makedirs(o["out"], exist_ok=True)
    glb = os.path.join(o["out"], "%s.glb" % who)
    export(arm, glb)
    with open(os.path.join(o["out"], "%s.rig3d.json" % who), "w") as f:
        json.dump(descriptor(who, arm, tris, model_height), f, indent=1)
    print("[redress] %s: %d tris, %d bones, model %.2f u -> %.2f m -> %s" % (
        who, tris, len(arm.data.bones), model_height, DESIGN_HEIGHT[who], glb))


main()
