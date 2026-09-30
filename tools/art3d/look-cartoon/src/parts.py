"""Body parts built on the fitted rig (armature space): gloves/hands along the finger bones, shoes along
the foot, rings (collars, cuffs, hems), a lathe helper. Metaball clay like the heads."""
import bpy, bmesh, math
import numpy as np
from mathutils import Vector, Matrix
import clib
from heads import ball, ellip, capsule, uv_sphere


def V(v):
    return Vector(v)


def cap_between(a, b, r, stiff=2.0):
    """A metaball capsule from point a to point b (radius r)."""
    a, b = V(a), V(b)
    d = b - a
    L = d.length
    c = (a + b) / 2
    # CAPSULE is along local X; rotate X onto d
    q = Vector((1, 0, 0)).rotation_difference(d.normalized())
    e = capsule(tuple(c), r, L / 2, stiff=stiff)
    e["rot"] = tuple(math.degrees(a) for a in q.to_euler("XYZ"))
    return e


def ellip_along(a, b, semi_w, semi_t, up, pad=0.0):
    """An ellipsoid spanning a->b (semi-axis along = |ab|/2 + pad), width semi_w, thickness semi_t
    (thickness along `up`)."""
    a, b, up = V(a), V(b), V(up).normalized()
    d = (b - a)
    c = (a + b) / 2
    xa = d.normalized()
    za = (up - xa * up.dot(xa)).normalized()
    ya = za.cross(xa)
    M = Matrix((xa, ya, za)).transposed()
    e = ellip(tuple(c), (d.length / 2 + pad, semi_w, semi_t))
    e["rot"] = tuple(math.degrees(x) for x in M.to_euler("XYZ"))
    return e


def finger_chain(arm, f, side):
    names = ["%s_0%d_%s" % (f, i, side) for i in (1, 2, 3)]
    pts = [clib.bone_head(arm, n) for n in names] + [clib.bone_tail(arm, names[-1])]
    return names, pts


def glove(arm, side, k=1.0, cuff=True, fingers=("index", "middle", "ring"), fat=1.0, name="glove"):
    """A cartoon 4-digit hand (thumb + 3 fingers) as one clay blob along the hand + finger bones.
    k: overall radius scale. Returns (mesh, cuff mesh or None)."""
    h = clib.bone_head(arm, "hand_" + side)
    hx, hy, hz = clib.bone_axes(arm, "hand_" + side)   # y along the hand, z = palm normal-ish (front in T-pose)
    roots = {f: clib.bone_head(arm, "%s_01_%s" % (f, side)) for f in ("index", "middle", "ring", "pinky", "thumb")}
    mid = (roots["index"] + roots["ring"]) / 2
    el = []
    # palm: from the wrist to the knuckles; thickness along the hand's x axis (palm faces down in T-pose)
    el.append(ellip_along(h + (mid - h) * 0.12, mid, 0.036 * k * fat, 0.022 * k * fat, hx, pad=0.012 * k))
    radii = {"index": 0.0125, "middle": 0.0135, "ring": 0.0125, "pinky": 0.011}
    spread = {"index": -0.12, "middle": 0.0, "ring": 0.14}
    for f in fingers:
        names, pts = finger_chain(arm, f, side)
        r = radii[f] * k * fat
        for a, b in zip(pts[:-1], pts[1:]):
            el.append(cap_between(a, b, r))
        el.append(ball(tuple(pts[-1]), r * 1.08))   # round fingertip
    names, pts = finger_chain(arm, "thumb", side)
    for a, b in zip(pts[:-1], pts[1:]):
        el.append(cap_between(a, b, 0.0135 * k * fat))
    el.append(ball(tuple(pts[-1]), 0.0145 * k * fat))
    ob = clib.metablob(name + "_" + side, el, resolution=0.004 * k)
    bones = ["hand_" + side] + ["%s_0%d_%s" % (f, i, side) for f in list(fingers) + ["thumb"] for i in (1, 2, 3)]
    clib.skin_segments(ob, bones, arm, power=6.0, keep=2)
    cf = None
    if cuff:
        la = clib.bone_head(arm, "lowerarm_" + side)
        d = (h - la).normalized()
        a = h - d * 0.045 * k
        prof = [(0.032 * k, 0.0), (0.036 * k, 0.02 * k), (0.045 * k, 0.04 * k), (0.05 * k, 0.05 * k), (0.045 * k, 0.056 * k), (0.03 * k, 0.054 * k)]
        cf = lathe(name + "_cuff_" + side, prof, a, d, seg=14)
        clib.skin_segments(cf, ["lowerarm_" + side, "hand_" + side], arm, power=4.0, keep=2)
    return ob, cf


def lathe(name, prof, base, axis, seg=20, cap=False):
    """Revolve [(r, t)] about `axis` starting at point `base` (t = distance along the axis)."""
    axis = V(axis).normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized()
    w = axis.cross(u)
    bm = bmesh.new()
    rings = []
    for r, t in prof:
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            p = V(base) + axis * t + (u * math.cos(a) + w * math.sin(a)) * r
            ring.append(bm.verts.new(p))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return clib.new_mesh_obj(name, bm)


def torus(name, center, axis, R, r, seg=28, rseg=8, squash=1.0):
    axis = V(axis).normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized()
    w = axis.cross(u)
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        radial = u * math.cos(a) + w * math.sin(a)
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            p = V(center) + radial * (R + r * math.cos(b)) + axis * (r * squash * math.sin(b))
            ring.append(bm.verts.new(p))
        rings.append(ring)
    for i in range(seg):
        for j in range(rseg):
            a, b = rings[i][j], rings[(i + 1) % seg][j]
            c, d = rings[(i + 1) % seg][(j + 1) % rseg], rings[i][(j + 1) % rseg]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return clib.new_mesh_obj(name, bm)


def shoe(arm, side, length=1.0, width=1.0, height=1.0, toe_up=0.0, name="shoe", pointy=0.0):
    """A cartoon shoe: heel + instep + toe blobs along foot->ball, flat sole at z = 0."""
    an = clib.bone_head(arm, "foot_" + side)
    bl = clib.bone_head(arm, "ball_" + side)
    toe = clib.bone_tail(arm, "ball_" + side)
    fwd = (toe - an)
    fwd.z = 0
    fwd.normalize()
    x = an.x
    heel = Vector((x, an.y + 0.035 * length, 0.04 * height))
    inst = Vector((x, (an.y + bl.y) / 2, 0.05 * height))
    tip = Vector((x, bl.y - 0.06 * length - pointy * 0.03, 0.03 * height + toe_up))
    el = [ellip(tuple(heel), (0.042 * width, 0.05 * length, 0.042 * height)),
          ellip(tuple(inst), (0.047 * width, 0.08 * length, 0.047 * height)),
          ellip(tuple(tip), (0.048 * width * (1 - 0.3 * pointy), 0.075 * length, 0.033 * height)),
          ellip((x, an.y + 0.005, an.z + 0.01), (0.04 * width, 0.042, 0.05)),       # ankle collar
          ellip((x, (an.y + bl.y) / 2, -0.1), (0.3, 0.4, 0.1), neg=True)]            # flat sole
    ob = clib.metablob(name + "_" + side, el, resolution=0.005)
    clib.skin_segments(ob, ["calf_" + side, "foot_" + side, "ball_" + side], arm, power=6.0, keep=2)
    return ob


def boundary_loops(ob):
    """[(centre Vector, mean radius, [vertex indices])] of every open boundary loop of the mesh."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    edges = [e for e in bm.edges if e.is_boundary]
    adj = {}
    for e in edges:
        a, b = e.verts[0].index, e.verts[1].index
        adj.setdefault(a, []).append(b)
        adj.setdefault(b, []).append(a)
    seen = set()
    loops = []
    for s in adj:
        if s in seen:
            continue
        comp, stack = [], [s]
        while stack:
            v = stack.pop()
            if v in seen:
                continue
            seen.add(v)
            comp.append(v)
            stack += adj[v]
        pts = [ob.data.vertices[i].co.copy() for i in comp]
        c = sum(pts, Vector()) / len(pts)
        r = sum((p - c).length for p in pts) / len(pts)
        loops.append((c, r, comp))
    bm.free()
    return loops
