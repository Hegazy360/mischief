"""Cartoon heads (metaball clay -> mesh) for Hush and Bellows, in HEAD space: origin = head centre,
-Y = the face's front, +Z up, +X = the character's left. Every part is returned as a mesh object plus a
'role' (skin / eye / lid / brow / hair / hat ...), the face frame (eye centres, mouth window) and the
bone anchors, so build_char.py can place, weight and paint them.
"""
import bpy, bmesh, math
import numpy as np
from mathutils import Vector, Matrix, Euler
import clib


K_MB = 0.574   # visible radius / metaball radius (threshold 0.6, stiffness 2; calibrated)


def ellip(co, size, neg=False, stiff=2.0, rot=(0, 0, 0)):
    """size = visible semi-axes (m) of the element alone."""
    return dict(type="ELLIPSOID", co=co, radius=1.0 / K_MB, size=size, neg=neg, stiff=stiff, rot=rot)


def ball(co, r, neg=False, stiff=2.0):
    return dict(type="BALL", co=co, radius=r / K_MB, neg=neg, stiff=stiff)


def capsule(co, r, half, rot=(0, 0, 0), stiff=2.0, neg=False):
    return dict(type="CAPSULE", co=co, radius=r / K_MB, size=(half, 0, 0), rot=rot, stiff=stiff, neg=neg)


def uv_sphere(name, r, seg=24, rings=16, scale=(1, 1, 1), center=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bmesh.ops.transform(bm, matrix=Matrix.Diagonal(Vector((*scale, 1))), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return clib.new_mesh_obj(name, bm)


def hemi_shell(name, r, rest_deg, center, seg=28, rings=10, lower=False, thick=0.12):
    """Eyelid: a hemispherical shell (outer radius r, pole +Z for an upper lid, -Z for a lower lid),
    rotated about the eye's X axis by rest_deg (negative = rim lifted at the front = open), placed at
    the eye centre. Its bone (at the same centre) rotates it further about X: + closes an upper lid."""
    bm = bmesh.new()
    rows_o, rows_i = [], []
    for i in range(rings + 1):
        th = (math.pi / 2) * i / rings
        ro, ri = [], []
        for j in range(seg):
            ph = 2 * math.pi * j / seg
            d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
            if lower:
                d.z = -d.z
            ro.append(bm.verts.new(d * r))
            ri.append(bm.verts.new(d * r * (1.0 - thick)))
        rows_o.append(ro)
        rows_i.append(ri)
    for i in range(rings):
        for j in range(seg):
            j2 = (j + 1) % seg
            f = [rows_o[i][j], rows_o[i][j2], rows_o[i + 1][j2], rows_o[i + 1][j]]
            g = [rows_i[i][j], rows_i[i + 1][j], rows_i[i + 1][j2], rows_i[i][j2]]
            if lower:
                f.reverse(); g.reverse()
            bm.faces.new(f)
            bm.faces.new(g)
    for j in range(seg):
        j2 = (j + 1) % seg
        f = [rows_o[-1][j], rows_o[-1][j2], rows_i[-1][j2], rows_i[-1][j]]
        if not lower:
            f.reverse()
        bm.faces.new(f)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ang = math.radians(rest_deg) * (-1 if lower else 1)
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(ang, 4, "X"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return clib.new_mesh_obj(name, bm)


def colour(ob, rgb):
    ob.color = (*rgb, 1.0)
    return ob


def arc_pts(c, w, h, n, z_bulge=0.0, y=0.0):
    """n points along an arch of width w and height h centred at c (in XZ, at depth c.y + y)."""
    out = []
    for i in range(n):
        t = -1 + 2 * i / (n - 1)
        out.append((c[0] + t * w / 2, c[1] + y + z_bulge * (t * t), c[2] + h * (1 - t * t)))
    return out


def blob_chain(pts, rads, stiff=2.0):
    return [ball(p, r, stiff=stiff) for p, r in zip(pts, rads)]


HUSH = dict(
    eye_r=0.044, eye_c=(0.058, -0.094, 0.004), lid_rest=-50.0, lowlid_rest=-64.0,
    mouth_c=(0.0, -0.134, -0.08), mouth_w=0.125, brow_c=(0.06, -0.13, 0.07),
)


def hush_head(P=HUSH):
    """Returns ({name: (obj, role)}, face frame) in head space."""
    er, (ex, ey, ez) = P["eye_r"], P["eye_c"]
    el = [
        ellip((0, 0.02, 0.045), (0.146, 0.142, 0.152)),            # cranium
        ellip((0, -0.035, -0.052), (0.108, 0.098, 0.092)),         # lower face
        ball((0.058, -0.078, -0.058), 0.046),                       # full cheeks
        ball((-0.058, -0.078, -0.058), 0.046),
        ball((0, -0.066, -0.118), 0.04),                            # small chin
        ball((0, -0.138, -0.036), 0.016),                           # button nose
        ellip((0, -0.122, -0.012), (0.01, 0.014, 0.018)),
        ellip((0.137, 0.018, -0.022), (0.014, 0.024, 0.032)),       # ears (under the bob)
        ellip((-0.137, 0.018, -0.022), (0.014, 0.024, 0.032)),
        ellip((ex, ey - 0.02, ez), (0.047, 0.03, 0.045), neg=True),  # eye sockets
        ellip((-ex, ey - 0.02, ez), (0.047, 0.03, 0.045), neg=True),
        capsule((0, 0.03, -0.19), 0.05, 0.08, rot=(0, 90, 0)),      # neck
    ]
    head = clib.metablob("head", el, resolution=0.006)
    parts = {"head": (head, "skin")}
    for s, nm in ((1, "l"), (-1, "r")):
        c = (s * ex, ey, ez)
        parts["eye_" + nm] = (uv_sphere("eye_" + nm, er, 28, 18, center=c), "eye")
        parts["lid_" + nm] = (hemi_shell("lid_" + nm, er * 1.07, P["lid_rest"], c), "lid")
        parts["lowlid_" + nm] = (hemi_shell("lowlid_" + nm, er * 1.05, P["lowlid_rest"], c, lower=True), "lid")
        bc = (s * P["brow_c"][0], P["brow_c"][1], P["brow_c"][2])
        pts = arc_pts(bc, 0.07, 0.012, 5, z_bulge=0.012)
        parts["brow_" + nm] = (clib.metablob("brow_" + nm, blob_chain(pts, [0.0075, 0.0098, 0.0105, 0.0098, 0.0072]), resolution=0.002), "brow")
    # the bob: a helmet around the cranium, face cut out, fringe, chin-length sides
    hair = [
        ellip((0, 0.028, 0.05), (0.162, 0.162, 0.168)),
        ball((0.12, 0.0, -0.06), 0.06), ball((-0.12, 0.0, -0.06), 0.06),       # side volume
        ball((0.1, -0.06, -0.085), 0.04), ball((-0.1, -0.06, -0.085), 0.04),   # curls toward the cheeks
        ellip((0, 0.09, -0.06), (0.13, 0.08, 0.08)),                            # back
        ellip((0.03, -0.108, 0.14), (0.125, 0.036, 0.036), rot=(0, -8, 0)),   # fringe
        ellip((0, -0.13, -0.02), (0.108, 0.1, 0.1), neg=True),                  # face opening
        ellip((0, -0.03, -0.24), (0.3, 0.3, 0.12), neg=True),                  # cut at the jaw line
    ]
    parts["hair"] = (clib.metablob("hair", hair, resolution=0.006), "hair")
    beret = [
        ellip((0.02, 0.02, 0.185), (0.168, 0.158, 0.036), rot=(0, 16, 0)),
        ellip((0.035, 0.02, 0.215), (0.12, 0.11, 0.02), rot=(0, 16, 0)),
        capsule((0.06, 0.02, 0.238), 0.008, 0.012, rot=(0, 70, 0)),
    ]
    parts["beret"] = (clib.metablob("beret", beret, resolution=0.004), "beret")
    return parts, dict(P)


BELL = dict(
    eye_r=0.038, eye_c=(0.057, -0.098, 0.04), lid_rest=-24.0, lowlid_rest=-58.0,
    mouth_c=(0.0, -0.14, -0.082), mouth_w=0.19, brow_c=(0.062, -0.125, 0.095),
)


def bellows_head(P=BELL):
    er, (ex, ey, ez) = P["eye_r"], P["eye_c"]
    el = [
        ellip((0, 0.025, 0.05), (0.138, 0.14, 0.14)),              # cranium
        ellip((0, -0.03, -0.045), (0.128, 0.112, 0.105)),          # face
        ball((0.08, -0.055, -0.09), 0.062), ball((-0.08, -0.055, -0.09), 0.062),  # jowls
        ellip((0, -0.055, -0.15), (0.085, 0.07, 0.045)),           # double chin
        ball((0, -0.152, -0.018), 0.043),                           # bulbous nose
        ellip((0, -0.128, 0.025), (0.02, 0.03, 0.04)),              # bridge
        ellip((0.14, 0.02, 0.0), (0.02, 0.035, 0.05)), ellip((-0.14, 0.02, 0.0), (0.02, 0.035, 0.05)),
        ellip((ex, ey - 0.018, ez), (0.042, 0.028, 0.04), neg=True),
        ellip((-ex, ey - 0.018, ez), (0.042, 0.028, 0.04), neg=True),
        capsule((0, 0.03, -0.17), 0.075, 0.06, rot=(0, 90, 0)),
    ]
    head = clib.metablob("head", el, resolution=0.006)
    parts = {"head": (head, "skin")}
    for s, nm in ((1, "l"), (-1, "r")):
        c = (s * ex, ey, ez)
        parts["eye_" + nm] = (uv_sphere("eye_" + nm, er, 24, 16, center=c), "eye")
        parts["lid_" + nm] = (hemi_shell("lid_" + nm, er * 1.08, P["lid_rest"], c), "lid")
        parts["lowlid_" + nm] = (hemi_shell("lowlid_" + nm, er * 1.06, P["lowlid_rest"], c, lower=True), "lid")
        bc = (s * P["brow_c"][0], P["brow_c"][1], P["brow_c"][2])
        pts = arc_pts(bc, 0.085, 0.01, 5, z_bulge=0.012)
        parts["brow_" + nm] = (clib.metablob("brow_" + nm, blob_chain(pts, [0.014, 0.019, 0.02, 0.018, 0.013]), resolution=0.003), "brow")
        # mutton chops: from the temple down the cheek to the jaw, bristly puffs
        chop = [ball((s * 0.128, -0.02, 0.035), 0.028), ball((s * 0.138, -0.035, -0.015), 0.036),
                ball((s * 0.136, -0.055, -0.06), 0.042), ball((s * 0.152, -0.04, -0.075), 0.034),
                ball((s * 0.125, -0.075, -0.095), 0.034), ball((s * 0.158, -0.02, -0.04), 0.026)]
        parts["chop_" + nm] = (clib.metablob("chop_" + nm, chop, resolution=0.005), "hair")
    # the bouffant: a dandelion clock of silver puffs
    import random
    rnd = random.Random(7)
    puffs = []
    # a dandelion clock: a wide round puff of silver curls, a rolled wave over the forehead
    for i in range(34):
        th = rnd.uniform(0, 2 * math.pi)
        ph = rnd.uniform(0.0, 1.5)
        x = 0.2 * math.sin(ph) * math.cos(th)
        y = 0.18 * math.sin(ph) * math.sin(th)
        z = 0.14 * math.cos(ph)
        puffs.append(ball((x, 0.035 + y, 0.2 + z), rnd.uniform(0.05, 0.065)))
    puffs.append(ellip((0, 0.035, 0.2), (0.2, 0.18, 0.14)))
    puffs.append(ellip((0, 0.03, 0.09), (0.16, 0.15, 0.08)))
    puffs.append(ellip((0, -0.12, 0.15), (0.15, 0.06, 0.06)))                 # front wave
    puffs.append(ellip((0, -0.15, 0.03), (0.12, 0.08, 0.1), neg=True))        # keep the forehead clear
    parts["bouffant"] = (clib.metablob("bouffant", puffs, resolution=0.007), "hair")
    return parts, dict(P)
