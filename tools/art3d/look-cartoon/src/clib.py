"""clib — "Saturday Cartoon" character library (bpy + numpy) for Mischief Next Door look-dev.

Pipeline pieces shared by build_char.py (mesh/rig/texture) and build_anim.py (clips/export):
  * load_rig()        the CC0 Quaternius UAL / UE5-mannequin 65-bone skeleton (+ its clips as actions)
  * load_base()       a CC0 Quaternius Universal Base Character body (Superhero male/female), weights kept
  * fit_rig()         move the UAL bone heads onto the base body's joints (UAL directions + rolls kept,
                      so UAL local-rotation keys still mean the same motion)
  * reshape()         cartoon proportions: per-bone local scale (bone space, y = along the bone), propagated
                      down the chain like a pose, applied to the mesh with its own skin weights (LBS), then
                      written back as the new rest skeleton (directions/rolls unchanged)
  * sculpt helpers    bulge / inflate / radial profile / smooth on vertex subsets (numpy)
  * part builders     metaball blobs -> mesh, lathes, capsules, rigid-weighted to a bone

Blender axes (armature at identity): +X = character's LEFT, -Y = character's FRONT, +Z up.
"""
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler

Q = "/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/3d/assets/quaternius/"
UAL1 = Q + "universal-animation-library/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"
UAL2 = Q + "universal-animation-library-2/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"
UBC = Q + "universal-base-characters/Universal Base Characters[Standard]/Base Characters/Godot - UE/"
BASE = {"male": UBC + "Superhero_Male_FullBody.gltf", "female": UBC + "Superhero_Female_FullBody.gltf"}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def action_fcurves(act):
    try:
        return list(act.fcurves)
    except Exception:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
        return out


# ------------------------------------------------------------------------------------------------
# rig + base body
# ------------------------------------------------------------------------------------------------
def load_rig(keep1=None, keep2=None):
    """UAL1 armature (named 'Armature', as UAL ships it) + the requested UAL1/UAL2 clips as actions."""
    bpy.ops.import_scene.gltf(filepath=UAL1)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    arm.name = "Armature"
    arm.data.name = "Armature"
    for o in list(bpy.data.objects):
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if keep1 is not None and a.name not in keep1:
            bpy.data.actions.remove(a)
    if keep2:
        before = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=UAL2)
        for o in list(bpy.data.objects):
            if o != arm:
                bpy.data.objects.remove(o, do_unlink=True)
        for a in list(set(bpy.data.actions) - before):
            base = a.name.split(".")[0]
            if base in keep2 and base not in bpy.data.actions:
                a.name = base
            elif base not in keep2 or a.name != base:
                bpy.data.actions.remove(a)
    for a in bpy.data.actions:
        a.use_fake_user = True
    return arm


def load_base(which):
    """Import a Universal Base Character; return (body mesh object, {bone: (head, tail)}). Its armature,
    eyes, brows and helper sphere are removed; the body keeps its 65 vertex groups."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BASE[which], merge_vertices=True)
    new = [o for o in bpy.data.objects if o not in before]
    barm = [o for o in new if o.type == "ARMATURE"][0]
    joints = {b.name: (barm.matrix_world @ b.head_local, barm.matrix_world @ b.tail_local) for b in barm.data.bones}
    body = max((o for o in new if o.type == "MESH"), key=lambda o: len(o.data.polygons))
    mw = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = mw
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    for o in new:
        if o != body:
            bpy.data.objects.remove(o, do_unlink=True)
    body.data.materials.clear()
    body.name = "Body"
    return body, joints


def fit_rig(arm, joints):
    """Move every UAL bone head onto the base body's joint; keep UAL direction + roll; take the base
    bone length."""
    set_mode(arm, "EDIT")
    eb = arm.data.edit_bones
    for b in eb:
        b.use_connect = False
    for b in eb:
        if b.name in joints and b.name != "root":
            h, t = joints[b.name]
            d = (b.tail - b.head).normalized()
            roll = b.roll
            L = (t - h).length
            b.head = h.copy()
            b.tail = h + d * L
            b.roll = roll
    set_mode(arm, "OBJECT")


def set_mode(ob, mode):
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    if mode != "OBJECT":
        bpy.ops.object.mode_set(mode=mode)


def bind(ob, arm):
    ob.parent = arm
    ob.matrix_parent_inverse = arm.matrix_world.inverted()
    for m in list(ob.modifiers):
        if m.type == "ARMATURE":
            ob.modifiers.remove(m)
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


# ------------------------------------------------------------------------------------------------
# weights as numpy
# ------------------------------------------------------------------------------------------------
def weights(ob, names):
    """(V, len(names)) float array of vertex group weights (0 where absent)."""
    idx = {vg.name: i for i, vg in enumerate(ob.vertex_groups)}
    col = {idx[n]: j for j, n in enumerate(names) if n in idx}
    W = np.zeros((len(ob.data.vertices), len(names)), np.float64)
    for v in ob.data.vertices:
        for g in v.groups:
            j = col.get(g.group)
            if j is not None:
                W[v.index, j] = g.weight
    return W


def coords(ob):
    a = np.empty(len(ob.data.vertices) * 3, np.float64)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_coords(ob, P):
    ob.data.vertices.foreach_set("co", P.astype(np.float64).ravel())
    ob.data.update()


def group_mask(ob, names, thresh=0.5):
    W = weights(ob, names)
    return W.sum(1) > thresh


# ------------------------------------------------------------------------------------------------
# reshape (proportions)
# ------------------------------------------------------------------------------------------------
def reshape(arm, meshes, scale=None, offset=None):
    """scale: {bone: (sx, sy, sz)} in bone space (y along the bone); offset: {bone: (dx, dy, dz)}
    armature-space translation of that bone (and, through the chain, its children).
    Every bone keeps its rest direction and roll; heads move like a posed chain; each mesh vertex moves
    by its skin weights (linear blend). Bone lengths scale by sy."""
    scale = scale or {}
    offset = offset or {}
    bones = list(arm.data.bones)
    names = [b.name for b in bones]
    R = {}
    for b in bones:
        R[b.name] = (np.array(b.matrix_local.to_3x3(), np.float64), np.array(b.head_local, np.float64),
                     b.length)
    D = {}   # bone -> (A 3x3, t) : p' = A p + t
    newhead = {}
    order = []

    def visit(b):
        order.append(b)
        for c in b.children:
            visit(c)
    for b in bones:
        if b.parent is None:
            visit(b)
    for b in order:
        rot, h, L = R[b.name]
        if b.parent is None:
            hn = h.copy()
        else:
            A, t = D[b.parent.name]
            hn = A @ h + t
        hn = hn + np.array(offset.get(b.name, (0, 0, 0)), np.float64)
        s = np.diag(np.array(scale.get(b.name, (1, 1, 1)), np.float64))
        A = rot @ s @ rot.T
        t = hn - A @ h
        D[b.name] = (A, t)
        newhead[b.name] = hn
    # children of an offset bone: offsets accumulate through D (t already includes it)
    for ob in meshes:
        P = coords(ob)
        W = weights(ob, names)
        tot = W.sum(1, keepdims=True)
        tot[tot < 1e-8] = 1.0
        W = W / tot
        out = np.zeros_like(P)
        for j, n in enumerate(names):
            w = W[:, j]
            if not np.any(w > 0):
                continue
            A, t = D[n]
            out += w[:, None] * (P @ A.T + t)
        none = W.sum(1) < 1e-6
        out[none] = P[none]
        set_coords(ob, out)
    set_mode(arm, "EDIT")
    eb = arm.data.edit_bones
    for b in eb:
        rot, h, L = R[b.name]
        d = (b.tail - b.head).normalized()
        roll = b.roll
        sy = scale.get(b.name, (1, 1, 1))[1]
        hn = Vector(newhead[b.name])
        b.head = hn
        b.tail = hn + d * L * sy
        b.roll = roll
    set_mode(arm, "OBJECT")
    return {n: Vector(newhead[n]) for n in names}


def bone_head(arm, n):
    return arm.matrix_world @ arm.data.bones[n].head_local


def bone_tail(arm, n):
    return arm.matrix_world @ arm.data.bones[n].tail_local


def bone_axes(arm, n):
    """(x, y, z) unit axes of bone n's rest frame in armature space."""
    m = arm.data.bones[n].matrix_local.to_3x3()
    return Vector(m.col[0]), Vector(m.col[1]), Vector(m.col[2])


# ------------------------------------------------------------------------------------------------
# sculpt helpers (numpy on object coords; armature at identity so object = armature space)
# ------------------------------------------------------------------------------------------------
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def falloff(P, c, r):
    d = np.linalg.norm(P - np.array(c), axis=1)
    return 1.0 - smoothstep(0.0, r, d)


def bulge(P, c, r, k, mask=None, axes=(1, 1, 1)):
    """Local magnify (k > 1) / shrink (k < 1) about centre c within radius r (smooth falloff)."""
    c = np.array(c, np.float64)
    f = falloff(P, c, r)
    if mask is not None:
        f = f * mask
    s = 1.0 + (k - 1.0) * f
    d = (P - c) * np.array(axes, np.float64)
    return P + d * (s[:, None] - 1.0)


def grab(P, c, r, delta, mask=None):
    f = falloff(P, c, r)
    if mask is not None:
        f = f * mask
    return P + f[:, None] * np.array(delta, np.float64)


def vertex_normals(ob):
    ob.data.update()
    n = np.empty(len(ob.data.vertices) * 3, np.float64)
    ob.data.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3)


def neighbours(ob):
    me = ob.data
    nb = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nb[a].append(b)
        nb[b].append(a)
    return nb


def smooth(ob, amount, iters, mask=None, nb=None):
    """Laplacian smoothing of the vertices (weighted by mask 0..1)."""
    P = coords(ob)
    nb = nb or neighbours(ob)
    m = np.ones(len(P)) if mask is None else mask
    # CSR adjacency
    idx = np.concatenate([np.array(n, np.int64) for n in nb]) if nb else np.zeros(0, np.int64)
    cnt = np.array([len(n) for n in nb], np.int64)
    start = np.concatenate([[0], np.cumsum(cnt)[:-1]])
    for _ in range(iters):
        s = np.add.reduceat(P[idx], start, axis=0) if len(idx) else P
        s[cnt == 0] = P[cnt == 0]
        avg = s / np.maximum(cnt, 1)[:, None]
        P = P + (avg - P) * (amount * m)[:, None]
    set_coords(ob, P)
    return P


# ------------------------------------------------------------------------------------------------
# parts
# ------------------------------------------------------------------------------------------------
def metablob(name, elems, resolution=0.012, threshold=0.6):
    """elems: [dict(type='BALL'|'ELLIPSOID'|'CAPSULE', co=(x,y,z), radius=r, size=(sx,sy,sz),
    rot=(deg x,y,z), neg=False, stiff=2.0)] -> a mesh object (triangulated, smooth)."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    for e in elems:
        el = mb.elements.new()
        el.type = e.get("type", "BALL")
        el.co = e["co"]
        el.radius = e.get("radius", 0.1)
        if "size" in e:
            el.size_x, el.size_y, el.size_z = e["size"]
        if "rot" in e:
            el.rotation = Euler([math.radians(a) for a in e["rot"]], "XYZ").to_quaternion()
        el.use_negative = e.get("neg", False)
        el.stiffness = e.get("stiff", 2.0)
    ob = bpy.data.objects.new(name + "_mb", mb)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    set_mode(ob, "OBJECT")
    bpy.ops.object.convert(target="MESH")
    me_ob = bpy.context.view_layer.objects.active
    me_ob.name = name
    for o in list(bpy.data.objects):   # the converted metaball family leaves the source behind sometimes
        if o.type == "META":
            bpy.data.objects.remove(o, do_unlink=True)
    for p in me_ob.data.polygons:
        p.use_smooth = True
    return me_ob


def decimate(ob, ratio=None, target_tris=None):
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if target_tris is not None:
        ratio = min(1.0, target_tris / max(1, tris))
    if ratio >= 0.999:
        return
    set_mode(ob, "OBJECT")
    m = ob.modifiers.new("dec", "DECIMATE")
    m.ratio = ratio
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)


def remesh(ob, voxel=0.01):
    set_mode(ob, "OBJECT")
    m = ob.modifiers.new("rm", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    m.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=m.name)


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def rigid(ob, bone, weight=1.0):
    vg = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), weight, "REPLACE")


def skin_segments(ob, bones, arm, power=4.0, keep=2):
    """Distance-to-bone-segment weights for a part (smooth joints)."""
    P = coords(ob)
    segs = [(np.array(bone_head(arm, n)), np.array(bone_tail(arm, n))) for n in bones]
    D = np.zeros((len(P), len(bones)))
    for j, (a, b) in enumerate(segs):
        ab = b - a
        t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
        D[:, j] = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
    Wt = 1.0 / (D ** power + 1e-9)
    if keep < len(bones):
        cut = -np.sort(-Wt, axis=1)[:, keep - 1:keep]
        Wt[Wt < cut] = 0.0
    Wt /= Wt.sum(1, keepdims=True)
    for j, n in enumerate(bones):
        vg = ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)
        for i in np.nonzero(Wt[:, j] > 1e-4)[0]:
            vg.add([int(i)], float(Wt[i, j]), "REPLACE")


def copy_weights_nearest(dst, src, maxdist=None):
    """Give every vertex of dst the weights of the nearest vertex of src (KD tree)."""
    from mathutils.kdtree import KDTree
    kd = KDTree(len(src.data.vertices))
    for v in src.data.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    gnames = {g.index: g.name for g in src.vertex_groups}
    for v in dst.data.vertices:
        co, i, d = kd.find(v.co)
        for g in src.data.vertices[i].groups:
            n = gnames[g.group]
            vg = dst.vertex_groups.get(n) or dst.vertex_groups.new(name=n)
            vg.add([v.index], g.weight, "REPLACE")


def join(objs, name):
    set_mode(objs[0], "OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


def new_mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def delete_verts(ob, mask):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(mask)[0]], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def set_region(ob, region_id):
    """Store a per-face integer 'region' (colour class) attribute on every face."""
    at = ob.data.attributes.get("region") or ob.data.attributes.new("region", "INT", "FACE")
    at.data.foreach_set("value", [int(region_id)] * len(ob.data.polygons))


def region_array(ob):
    at = ob.data.attributes.get("region")
    a = np.zeros(len(ob.data.polygons), np.int64)
    if at is not None:
        at.data.foreach_get("value", a)
    return a


def set_region_array(ob, arr):
    at = ob.data.attributes.get("region") or ob.data.attributes.new("region", "INT", "FACE")
    at.data.foreach_set("value", [int(x) for x in arr])


def face_centers(ob):
    c = np.empty(len(ob.data.polygons) * 3, np.float64)
    ob.data.polygons.foreach_get("center", c)
    return c.reshape(-1, 3)


# ------------------------------------------------------------------------------------------------
# quick Workbench previews (debug only; the look is judged in Godot)
# ------------------------------------------------------------------------------------------------
def preview(path_prefix, views=("front", "side"), center=(0, 0, 0.85), ortho=2.0, res=(700, 800), color="SINGLE"):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = color
    sc.display.shading.show_cavity = False
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    cam = bpy.data.objects.get("_pcam")
    if cam is None:
        cd = bpy.data.cameras.new("_pcam")
        cd.type = "ORTHO"
        cam = bpy.data.objects.new("_pcam", cd)
        sc.collection.objects.link(cam)
    cam.data.ortho_scale = ortho
    sc.camera = cam
    cx, cy, cz = center
    V = {"front": ((cx, cy - 5, cz), (90, 0, 0)), "side": ((cx + 5, cy, cz), (90, 0, 90)),
         "back": ((cx, cy + 5, cz), (90, 0, 180)), "q34": ((cx + 3.5, cy - 3.5, cz), (90, 0, 45)),
         "top": ((cx, cy, cz + 5), (0, 0, 0))}
    outs = []
    for v in views:
        loc, rot = V[v]
        cam.location = loc
        cam.rotation_euler = [math.radians(a) for a in rot]
        sc.render.filepath = "%s_%s.png" % (path_prefix, v)
        bpy.ops.render.render(write_still=True)
        outs.append(sc.render.filepath)
    return outs


def set_face_int(ob, name, value):
    at = ob.data.attributes.get(name) or ob.data.attributes.new(name, "INT", "FACE")
    at.data.foreach_set("value", [int(value)] * len(ob.data.polygons))


def face_int(ob, name):
    at = ob.data.attributes.get(name)
    a = np.zeros(len(ob.data.polygons), np.int64)
    if at is not None:
        at.data.foreach_get("value", a)
    return a


def tag(ob, region, group, part=0):
    """region = colour class, group = UV block (0 head, 1 body, 2 small parts), part = decal owner
    (1 head skin -> mouth decal, 2/3 eyeball l/r -> iris decal)."""
    set_region(ob, region)
    set_face_int(ob, "group", group)
    set_face_int(ob, "part", part)
