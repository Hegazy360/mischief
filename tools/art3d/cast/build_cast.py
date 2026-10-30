"""Build the MND cast as skinned glTF on the self-contained skeleton (tools/art3d/cast/mnd_rig.py).

    blender -b --python build_cast.py -- --who hush --out <dir> [--quick]

Writes <dir>/<who>.glb and <dir>/<who>.rig3d.json. `--quick` drops the surface subdivision for a
fast silhouette check.

Geometry comes from the Toy Box look-dev's helpers (tools/art3d/look-toy/toy_lib.py): superellipsoid
blobs, swept capsules and exact bisect colour cuts, every face carrying a palette index that becomes
UV0. That part of the look-dev had no Quaternius dependency and is the genuinely good half of it.
What changed is the skeleton underneath (20 body bones instead of 65) and the three silhouette
problems the look-dev board flagged: Hush's stick legs, Bellows reading as a featureless blob, and
both faces sitting too small inside the hair.
"""
import bpy, bmesh, sys, os, math, json
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "look-toy"))
import toy_lib as T
import toy_palette as TP
import mnd_rig as R


# ------------------------------------------------------------------------------------------------
# args
# ------------------------------------------------------------------------------------------------
def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"who": "hush", "out": os.path.join(HERE, "build"), "quick": False, "budget": 10000}
    i = 0
    while i < len(a):
        if a[i] == "--who":
            out["who"] = a[i + 1]; i += 2
        elif a[i] == "--out":
            out["out"] = a[i + 1]; i += 2
        elif a[i] == "--budget":
            out["budget"] = int(a[i + 1]); i += 2
        elif a[i] == "--quick":
            out["quick"] = True; i += 1
        else:
            i += 1
    return out


# ------------------------------------------------------------------------------------------------
# skeleton
# ------------------------------------------------------------------------------------------------
def build_armature(name, specs):
    """Create an armature from [(bone, parent, head, tail)] with parents already present."""
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for bone, parent, head, tail in specs:
        b = eb.new(bone)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
        b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


# ------------------------------------------------------------------------------------------------
# shared body pieces
# ------------------------------------------------------------------------------------------------
def limb(rig, bones, r0, r1, color, seg=14):
    """A swept capsule down a bone chain: radius r0 at the first head, r1 at the last tail.

    Taper is what stops a leg reading as a stick — the look-dev board's note on Hush. The radius
    runs over the *whole chain*, so thigh→shin→ankle narrows continuously instead of stepping.
    """
    pts, radii = [], []
    n = len(bones)
    for i, b in enumerate(bones):
        t = i / float(n)
        pts.append(rig.head(b))
        radii.append(r0 + (r1 - r0) * t)
    pts.append(rig.tail(bones[-1]))
    radii.append(r1)
    return T.capsule_chain(pts, radii, color, seg=seg)


def face_uv_plane(ob, center_up, w, h, front=0.2, xmin=None):
    """Write the planar face-decal square (UV1 "FaceUV") on a head's front faces.

    toy_lib's own `face_uv=` hardcodes the look-dev's "character faces -Y" convention; this cast is
    modelled facing +X (see mnd_rig), so the projection is along +X instead: lateral runs on Y, up
    on Z. Faces outside the square, and every face that is not front-facing, get (-2, -2), which the
    toy shader reads as "no decal here".
    """
    me = ob.data
    uv1 = me.uv_layers.get("FaceUV") or me.uv_layers.new(name="FaceUV")
    for p in me.polygons:
        on_face = p.normal.x > front and (xmin is None or p.center.x > xmin)
        for li in p.loop_indices:
            if not on_face:
                uv1.data[li].uv = (-2.0, -2.0)
                continue
            co = me.vertices[me.loops[li].vertex_index].co
            # Lateral is +Y; the face square's u grows to the character's right as the audience
            # sees it, so u is -y.
            uv1.data[li].uv = (-co.y / w + 0.5, (co.z - center_up) / h + 0.5)
    return ob


def face_camera(arm):
    """Turn the finished rig so it faces -Y in Blender, which is +Z (toward the audience) in Godot.

    The cast is modelled facing +X because that is the direction the 2D art faces and it keeps the
    retarget's sagittal plane obvious. On a side-on stage, though, a character whose nose points
    along the walk direction shows the camera nothing but an ear, and a flat face card seen at 90°
    collapses. REDESIGN_3D §5.1 answers that with the "cheat out": the body is turned toward the
    audience and the walk direction is read from a partial yaw. Baking the base turn here means the
    runtime's facing is a plain yaw either side of straight-to-camera.
    """
    arm.rotation_euler = (0.0, 0.0, -math.pi / 2.0)


def export_glb(arm, body, path):
    """Export the rig and its skinned mesh, with the textures left OUT of the .glb.

    toy_lib's exporter embeds every image. That made the look-dev .glb self-contained, but here the
    palette and the face atlas are shared, versioned PNGs that the toy shader loads straight from
    `res://art3d/cast/`; embedding them a second time per character made Godot extract a duplicate
    pair on import (`hush_cast_palette.png` and friends) that nothing ever sampled. `export_image_
    format="NONE"` drops the images while keeping both UV layers, which is all the mesh needs.
    """
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    arm.animation_data_create()
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False,
              export_yup=True, export_animations=False, export_skins=True,
              export_materials="EXPORT", export_image_format="NONE", export_frame_range=False,
              export_texcoords=True, export_normals=True, export_def_bones=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = {k: v for k, v in kw.items() if k in props or k == "filepath"}
    bpy.ops.export_scene.gltf(**kw)


def count_tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimate_to_budget(obj, budget):
    """Collapse the joined body down to `budget` triangles (REDESIGN_3D §5.6: ≤ 10k per character).

    Collapse rather than un-subdivide: the palette colours live in UV0 and the face decal square in
    UV1, and only the collapse mode is UV-aware enough to keep the stripe boundaries and the face
    square from sliding. Below the budget the mesh is left exactly as built.
    """
    tris = count_tris(obj)
    if budget <= 0 or tris <= budget:
        return tris
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Budget", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = float(budget) / float(tris)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    out = count_tris(obj)
    print("[cast]   decimated %d -> %d tris (budget %d)" % (tris, out, budget))
    return out


def mitt(rig, bone, radius, color, squash=0.78, forward=0.012):
    """A glove/mitten: a flattened superellipsoid at the hand bone, long axis down the bone."""
    h, t = rig.head(bone), rig.tail(bone)
    c = h.lerp(t, 0.55) + Vector((forward, 0, 0))
    return T.se_blob(c, radius * 1.18, radius * squash, radius * 1.30, 2.6, color, n=9)


# ------------------------------------------------------------------------------------------------
# Hush
# ------------------------------------------------------------------------------------------------
def build_hush(quick):
    prop = R.hush_proportions()
    specs = R.bone_specs(prop, R.HUSH_JIGGLE, R.HUSH_SOCKETS)
    arm = build_armature("Hush", specs)
    rig = T.Rig(arm)
    body = T.Body(rig, "Hush")
    n = 7 if quick else 12

    head_c = rig.head("head").lerp(rig.tail("head"), 0.46)
    HA, HB, HC_, HP = 0.215, 0.200, 0.235, 2.3

    def head_q(d):
        q = d * T.se_radius(d, HA, HB, HC_, HP)
        lo = T.smoothstep(0.04, -0.18, q.z)
        q.y *= 1.0 + 0.05 * lo          # chibi cheeks
        q.z *= 1.0 - 0.05 * T.smoothstep(0.08, 0.26, q.z)
        return q

    def face_amount(q):
        """How much of the head surface at q is bare face rather than hair.

        The look-dev's "face too small inside the hair" is fixed here: the fringe line sits higher
        (`fringe_z` base 0.105 against the old 0.088) and the side cut is wider, so the brow and the
        eyes both clear the hair at 64 px.
        """
        front = T.smoothstep(-0.02, -0.13, -q.x)
        yn = q.y / HB
        fringe_z = 0.105 - 0.065 * yn * yn - 0.016 * yn
        below = T.smoothstep(fringe_z + 0.028, fringe_z - 0.028, q.z)
        sides = T.smoothstep(0.195, 0.150, abs(q.y))
        return front * below * sides

    # head (white face paint) + the planar face-decal square
    bm = T.blob(lambda d: head_c + head_q(d), "paint", n=n + 2)
    face_uv_plane(body.add(bm, "head", name="head"),
                  center_up=head_c.z, w=0.46, h=0.46, xmin=head_c.x - 0.02)
    # hair bob: the head surface pushed out where there is hair, pulled flat across the face
    def hair_pos(d):
        q = head_q(d)
        f = face_amount(q)
        s = T.lerp(1.075 - 0.035 * T.smoothstep(0.10, 0.24, q.z), 0.90, f)
        return head_c + q * s
    bm = T.blob(hair_pos, "hair", n=n + 2)
    T.delete_faces(bm, lambda c, nn: face_amount(c - head_c) > 0.985)
    body.add(bm, "head", name="hair")

    # beret: a tilted disc with a stalk, on its own jiggle bone
    bc = rig.head("beret")
    bm = T.se_blob(bc + Vector((-0.012, 0, 0.004)), 0.196, 0.190, 0.058, 2.6, "beret", n=n)
    T.rot_about(bm, bc, (0, -13, 0))
    body.add(bm, "beret", name="beret")
    bm = T.se_blob(bc + Vector((-0.030, 0, 0.062)), 0.020, 0.020, 0.028, 2.0, "beret_dk", n=5)
    body.add(bm, "beret", name="beret_stalk")

    # torso: Breton stripes cut in with bisect planes so they stay crisp on any topology
    tc = rig.head("spine").lerp(rig.tail("chest"), 0.5)
    bm = T.se_blob(tc, 0.125, 0.140, 0.195, 2.5, "navy", n=n)
    z0, z1 = rig.head("spine").z - 0.02, rig.tail("chest").z
    for i in range(7):
        zc = T.lerp(z0, z1, i / 6.0)
        T.bisect(bm, Vector((0, 0, zc)), Vector((0, 0, 1)))
    T.recolor(bm, lambda c, nn, cur: "stripe" if int((c.z - z0) / max(1e-6, (z1 - z0)) * 7.0) % 2 == 0 else "navy")
    body.add(bm, ["spine", "chest"], name="torso")

    # red braces, each on its own jiggle bone
    for side, sy in (("l", 1.0), ("r", -1.0)):
        a = rig.head(f"brace_{side}")
        b = rig.tail(f"brace_{side}")
        bm = T.capsule_chain([a + Vector((0.055, 0, 0.0)), b + Vector((0.075, 0, 0.0))],
                             [0.022, 0.020], "braces", seg=8)
        body.add(bm, f"brace_{side}", name=f"brace_{side}")

    # pelvis / trousers
    pc = rig.head("pelvis") + Vector((0, 0, -0.045))
    bm = T.se_blob(pc, 0.115, 0.130, 0.105, 2.6, "trouser", n=n)
    body.add(bm, "pelvis", name="hips")

    # arms + legs: tapered sweeps (no sticks)
    for side in ("l", "r"):
        bm = limb(rig, [f"arm_upper_{side}", f"arm_lower_{side}"], 0.058, 0.040, "navy")
        body.add(bm, [f"arm_upper_{side}", f"arm_lower_{side}"], name=f"arm_{side}")
        bm = mitt(rig, f"hand_{side}", 0.072, "glove")
        body.add(bm, f"hand_{side}", name=f"glove_{side}")
        bm = limb(rig, [f"leg_upper_{side}", f"leg_lower_{side}"], 0.078, 0.046, "trouser")
        body.add(bm, [f"leg_upper_{side}", f"leg_lower_{side}"], name=f"leg_{side}")
        # shoe: a wedge along the foot bone, with a visible sole
        fh, ft = rig.head(f"foot_{side}"), rig.tail(f"toe_{side}")
        c = fh.lerp(ft, 0.52) + Vector((0, 0, -0.004))
        bm = T.se_blob(c, 0.105, 0.058, 0.044, 2.7, "shoe", n=n - 2)
        T.bisect(bm, Vector((0, 0, c.z - 0.022)), Vector((0, 0, 1)))
        T.recolor(bm, lambda p, nn, cur, zc=c.z - 0.022: "sole" if p.z < zc else "shoe")
        body.add(bm, [f"foot_{side}", f"toe_{side}"], name=f"shoe_{side}")

    return arm, body, prop, R.HUSH_JIGGLE, R.HUSH_SOCKETS


# ------------------------------------------------------------------------------------------------
# Bellows
# ------------------------------------------------------------------------------------------------
def build_bellows(quick):
    prop = R.bellows_proportions()
    specs = R.bone_specs(prop, R.BELLOWS_JIGGLE, R.BELLOWS_SOCKETS)
    arm = build_armature("Bellows", specs)
    rig = T.Rig(arm)
    body = T.Body(rig, "Bellows")
    n = 7 if quick else 12

    head_c = rig.head("head").lerp(rig.tail("head"), 0.44)
    HA, HB, HC_, HP = 0.200, 0.190, 0.215, 2.4

    def head_q(d):
        q = d * T.se_radius(d, HA, HB, HC_, HP)
        jowl = T.smoothstep(0.02, -0.20, q.z)
        q.y *= 1.0 + 0.10 * jowl        # jowls
        q.x *= 1.0 + 0.04 * jowl
        return q

    bm = T.blob(lambda d: head_c + head_q(d), "peach", n=n + 2)
    face_uv_plane(body.add(bm, "head", name="head"),
                  center_up=head_c.z, w=0.42, h=0.42, xmin=head_c.x - 0.02)

    # The bouffant is three separate lobes on three jiggle bones, not one cloud: the look-dev's
    # "lumpy cloud" note. Three lobes give a readable silhouette and let the hair wobble off-phase.
    for bone, rx, ry, rz in (("bouffant_c", 0.150, 0.135, 0.120),
                             ("bouffant_l", 0.115, 0.105, 0.098),
                             ("bouffant_r", 0.115, 0.105, 0.098)):
        c = rig.head(bone).lerp(rig.tail(bone), 0.5)
        bm = T.se_blob(c, rx, ry, rz, 2.3, "bouffant", n=n)
        body.add(bm, bone, name=bone)

    for side in ("l", "r"):
        c = rig.head(f"sideburn_{side}").lerp(rig.tail(f"sideburn_{side}"), 0.5)
        bm = T.se_blob(c, 0.048, 0.040, 0.075, 2.4, "bouffant_dk", n=n - 3)
        body.add(bm, f"sideburn_{side}", name=f"sideburn_{side}")

    c = rig.head("nose").lerp(rig.tail("nose"), 0.55)
    bm = T.se_blob(c, 0.052, 0.040, 0.042, 2.1, "nose", n=6)
    body.add(bm, "nose", name="nose")

    # Barrel torso + a separate belly lobe on its own bone, so the gut leads and lags the body.
    tc = rig.head("spine").lerp(rig.tail("chest"), 0.52)
    bm = T.se_blob(tc, 0.175, 0.205, 0.245, 2.6, "plum", n=n)
    body.add(bm, ["spine", "chest"], name="torso")
    bc = rig.head("belly").lerp(rig.tail("belly"), 0.5)
    bm = T.se_blob(bc, 0.120, 0.150, 0.140, 2.5, "vest", n=n)
    body.add(bm, "belly", name="belly")

    c = rig.head("cravat").lerp(rig.tail("cravat"), 0.45)
    bm = T.se_blob(c, 0.070, 0.090, 0.072, 2.2, "cravat", n=n - 2)
    body.add(bm, "cravat", name="cravat")

    for side in ("l", "r"):
        a = rig.head(f"tail_{side}")
        b = rig.tail(f"tail_{side}")
        bm = T.capsule_chain([a, b], [0.075, 0.055], "plum_dk", seg=10)
        body.add(bm, f"tail_{side}", name=f"tail_{side}")

    pc = rig.head("pelvis") + Vector((0, 0, -0.040))
    bm = T.se_blob(pc, 0.140, 0.165, 0.110, 2.6, "trouser_b", n=n)
    body.add(bm, "pelvis", name="hips")

    for side in ("l", "r"):
        bm = limb(rig, [f"arm_upper_{side}", f"arm_lower_{side}"], 0.080, 0.052, "plum")
        body.add(bm, [f"arm_upper_{side}", f"arm_lower_{side}"], name=f"arm_{side}")
        bm = mitt(rig, f"hand_{side}", 0.078, "cuff", squash=0.86)
        body.add(bm, f"hand_{side}", name=f"hand_{side}")
        bm = limb(rig, [f"leg_upper_{side}", f"leg_lower_{side}"], 0.095, 0.058, "trouser_b")
        body.add(bm, [f"leg_upper_{side}", f"leg_lower_{side}"], name=f"leg_{side}")
        fh, ft = rig.head(f"foot_{side}"), rig.tail(f"toe_{side}")
        c = fh.lerp(ft, 0.52)
        bm = T.se_blob(c, 0.118, 0.068, 0.050, 2.6, "slipper", n=n - 2)
        body.add(bm, [f"foot_{side}", f"toe_{side}"], name=f"slipper_{side}")

    return arm, body, prop, R.BELLOWS_JIGGLE, R.BELLOWS_SOCKETS


# ------------------------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------------------------
def main():
    opt = args()
    who = opt["who"]
    out_dir = opt["out"]
    os.makedirs(out_dir, exist_ok=True)
    T.reset()

    # Blender's bundled Python has no Pillow, so the palette and face atlases are rasterised by the
    # system interpreter in build.sh before this script runs.
    palette = os.path.join(out_dir, "cast_palette.png")
    if not os.path.exists(palette):
        raise SystemExit("[cast] missing %s — run tools/art3d/cast/build.sh, not blender directly" % palette)
    face_png = os.path.join(out_dir, "face_%s.png" % who)

    builder = {"hush": build_hush, "bellows": build_bellows}[who]
    arm, body, prop, jiggle, sockets = builder(opt["quick"])

    mat = T.toy_material("toy_%s" % who, palette, face_png if os.path.exists(face_png) else None)
    obj = body.finish(mat)
    tris = decimate_to_budget(obj, opt["budget"])
    face_camera(arm)
    glb = os.path.join(out_dir, "%s.glb" % who)
    export_glb(arm, obj, glb)

    face_atlas = {"atlas": "face_%s.png" % who, "uv": "FaceUV"}
    desc = R.descriptor(who, prop, jiggle, sockets, face_atlas)
    desc["tris"] = tris
    desc["bones"] = len(arm.data.bones)
    with open(os.path.join(out_dir, "%s.rig3d.json" % who), "w") as f:
        json.dump(desc, f, indent=1)
    print("[cast] %s: %d tris, %d bones -> %s" % (who, tris, len(arm.data.bones), glb))


main()
