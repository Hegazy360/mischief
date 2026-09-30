"""Horace Bellows' parts (Blender bmesh): body, held props, FX, attachment variants. Called by build.py.

Construction follows look A (superellipsoid blobs on quad spheres, swept capsules, exact bisect colour borders,
masked shells) with the board's modeller fixes: a *styled* three-lobe dandelion bouffant (parametric scalloped lobes
instead of a metaball cloud), a bigger face card pushed clear of the hair, chops on the jaw, white opera gloves, a
barrel that the arms clear, readable x1.8 tea things. Coordinates: armature space, +X = his left, -Y = his front, Z up.
"""
import bpy, bmesh, math, os, json, random
from mathutils import Vector, Matrix, Euler, Quaternion
import blib as T
import bpalette as TP
import skeleton as SK

# face card: the planar FaceUV square on the head front (face_atlas.py draws in the same 1000 x 1000 face space)
FACE_W = 0.56
FACE_H = 0.56
FACE_DZ = -0.012          # face square centre relative to the head centre
HEAD_R = (0.255, 0.232, 0.238, 2.1)       # half width, half depth, half height, superellipse power
BARREL_R = (0.405, 0.355, 0.43, 2.2)
CUP_SCALE = 1.8           # R5: Bellows' teacup + saucer x1.8


def landmarks(rig):
    H = rig.head
    L = {}
    L["HC"] = Vector((0.0, H("Head").y - 0.020, SK.HC_Z))
    L["TC"] = Vector((0.0, H("spine_02").y + 0.005, SK.TC_Z))
    L["FC"] = L["HC"] + Vector((0, 0, FACE_DZ))
    L["H"] = H
    return L


def landmarks_json(L):
    out = {k: [round(x, 4) for x in v] for k, v in L.items() if isinstance(v, Vector)}
    out["face_card"] = {"centre": [0.0, round(L["FC"].z, 4)], "w": FACE_W, "h": FACE_H}
    out["head_r"] = HEAD_R
    out["barrel_r"] = BARREL_R
    return out


# ------------------------------------------------------------------------------------------------------------------
# shape helpers
# ------------------------------------------------------------------------------------------------------------------
def head_q(d):
    HA, HB, HCz, HP = HEAD_R
    q = d * T.se_radius(d, HA, HB, HCz, HP)
    lo = T.smoothstep(0.05, -0.22, q.z)          # jowls: a pompous heavy jaw
    q.x *= 1.0 + 0.10 * lo
    q.y *= 1.0 + 0.05 * lo
    return q


def torso_q(d):
    TA, TB, TCz, TPw = BARREL_R
    q = d * T.se_radius(d, TA, TB, TCz, TPw)
    zn = q.z / TCz
    k = 1.0 + 0.05 * (0.4 - zn) - 0.07 * max(0.0, zn - 0.5)
    q.x *= k
    q.y *= k
    return q


def lobe(center, radii, pole, color, groove_color, n_ridges=12, amp=0.07, rings=9, segs=36, flat_back=0.0):
    """A scalloped dandelion lobe: a UV sphere whose pole points along `pole`; the radius is modulated by ridges that
    run pole-to-pole (a scalloped silhouette seen from the pole side); groove faces take groove_color."""
    C = Vector(center)
    pz = Vector(pole).normalized()
    ref = Vector((0, 0, 1)) if abs(pz.z) < 0.9 else Vector((1, 0, 0))
    px = ref.cross(pz).normalized()
    py = pz.cross(px).normalized()
    bm = T._new_bm()
    col = T._col_layer(bm)
    grid = []
    for i in range(1, rings):
        th = math.pi * i / rings
        row = []
        for j in range(segs):
            ph = 2 * math.pi * j / segs
            d = pz * math.cos(th) + (px * math.cos(ph) + py * math.sin(ph)) * math.sin(th)
            r = T.se_radius(d, radii[0], radii[1], radii[2], 2.0)
            rid = 0.5 + 0.5 * math.cos(n_ridges * ph)
            r *= 1.0 + amp * (rid ** 1.5 - 0.45) * math.sin(th) ** 1.2
            if flat_back and d.dot(pz) < 0:
                r *= 1.0 - flat_back * (-d.dot(pz))
            row.append(bm.verts.new(C + d * r))
        grid.append(row)
    top = bm.verts.new(C + pz * T.se_radius(pz, *radii[:3], 2.0) * (1.0 - amp * 0.3))
    bot = bm.verts.new(C - pz * T.se_radius(-pz, *radii[:3], 2.0) * (1.0 - flat_back))
    for i in range(len(grid) - 1):
        for j in range(segs):
            f = bm.faces.new((grid[i][j], grid[i][(j + 1) % segs], grid[i + 1][(j + 1) % segs], grid[i + 1][j]))
            ph = 2 * math.pi * (j + 0.5) / segs
            groove = (0.5 + 0.5 * math.cos(n_ridges * ph)) < 0.07 and i > 0
            f[col] = TP.IDX[groove_color if groove else color]
    for j in range(segs):
        f = bm.faces.new((top, grid[0][(j + 1) % segs], grid[0][j]))
        f[col] = TP.IDX[color]
        f = bm.faces.new((bot, grid[-1][j], grid[-1][(j + 1) % segs]))
        f[col] = TP.IDX[color]
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def inside_lobe(p, c, radii, shrink=0.93):
    d = p - Vector(c)
    if d.length < 1e-6:
        return True
    return d.length < T.se_radius(d.normalized(), radii[0], radii[1], radii[2], 2.0) * shrink


def star_prism(center, r_out, r_in, thick, color, rot=(0, 0, 0), points=5):
    """A chunky 5-point vinyl star, extruded (front faces -Y before rot)."""
    bm = T._new_bm()
    col = T._col_layer(bm)
    C = Vector(center)
    M = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
    ring_f, ring_b = [], []
    for k in range(points * 2):
        a = math.pi / 2 + math.pi * k / points
        r = r_out if k % 2 == 0 else r_in
        p = Vector((math.cos(a) * r, 0.0, math.sin(a) * r))
        ring_f.append(bm.verts.new(C + M @ (p + Vector((0, -thick / 2, 0)))))
        ring_b.append(bm.verts.new(C + M @ (p + Vector((0, thick / 2, 0)))))
    cf = bm.verts.new(C + M @ Vector((0, -thick * 0.9, 0)))
    cb = bm.verts.new(C + M @ Vector((0, thick * 0.9, 0)))
    n = len(ring_f)
    for k in range(n):
        a, b = k, (k + 1) % n
        bm.faces.new((cf, ring_f[b], ring_f[a]))
        bm.faces.new((cb, ring_b[a], ring_b[b]))
        bm.faces.new((ring_f[a], ring_f[b], ring_b[b], ring_b[a]))
    for f in bm.faces:
        f[col] = TP.IDX[color]
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def box(center, size, color, rot=(0, 0, 0)):
    bm = T._new_bm()
    bmesh.ops.create_cube(bm, size=1.0)
    M = Matrix.Translation(Vector(center)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1.0))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts[:])
    T.paint_all(bm, color)
    return bm


# ------------------------------------------------------------------------------------------------------------------
# the body
# ------------------------------------------------------------------------------------------------------------------
BOUFFANT_LOBES = {
    # bone: (centre offset from HC, radii, pole, ridges)
    "bouffant": ((0.0, 0.100, 0.268), (0.300, 0.262, 0.248), (0.0, -0.40, 1.0), 12),
    "bouffant_l": ((0.222, 0.095, 0.185), (0.180, 0.180, 0.176), (1.0, -0.35, 0.35), 9),
    "bouffant_r": ((-0.222, 0.095, 0.185), (0.180, 0.180, 0.176), (-1.0, -0.35, 0.35), 9),
}


def bouffant_neat(HC, color="bouffant", groove="bouffant_dk", scale=1.0, rings=(9, 7), segs=(36, 24)):
    """The styled dandelion clock: crown + two side lobes; faces hidden inside a neighbour lobe or the head removed."""
    out = {}
    for bone, (off, radii, pole, nr) in BOUFFANT_LOBES.items():
        c = HC + Vector(off) * scale
        rr = tuple(r * scale for r in radii)
        crown = bone == "bouffant"
        bm = lobe(c, rr, pole, color, groove, n_ridges=nr, amp=0.075,
                  rings=rings[0] if crown else rings[1], segs=segs[0] if crown else segs[1])
        others = [(HC + Vector(o) * scale, tuple(r * scale for r in rd)) for b2, (o, rd, _p, _n) in BOUFFANT_LOBES.items() if b2 != bone]
        T.delete_faces(bm, lambda p, n: any(inside_lobe(p, oc, orr, 0.90) for oc, orr in others)
                       or inside_lobe(p, HC, HEAD_R[:3], 0.88))
        out[bone] = bm
    return out


def build_body(body, rig, L):
    H, HC, TC, FC = L["H"], L["HC"], L["TC"], L["FC"]
    HA, HB, HCz, HP = HEAD_R
    # ---- head (the face card lives on its front) ----
    lobes = [(HC + Vector(o), r) for o, r, _p, _n in BOUFFANT_LOBES.values()]
    bm = T.blob(lambda d: HC + head_q(d), "peach", n=10)
    T.delete_faces(bm, lambda c, n: any(inside_lobe(c, lc, lr, 0.84) for lc, lr in lobes))
    body.add(bm, "Head", face_uv={"center": (0.0, FC.z), "w": FACE_W, "h": FACE_H, "front": -0.22, "ymax": HC.y - 0.06},
             name="head")
    # ---- the bulbous rosy nose ----
    NC = HC + Vector((0, -HB - 0.034, -0.048))
    body.add(T.se_blob(NC, 0.072, 0.064, 0.062, 2.0, "nose", n=4), "nose", name="nose")
    # ---- ears (peek out between the side lobes and the chops) ----
    for sx in (-1, 1):
        bm = T.se_blob(HC + Vector((sx * 0.252, 0.035, 0.005)), 0.034, 0.048, 0.062, 2.0, "peach", n=2)
        body.add(bm, "Head", name="ear")
    # ---- mutton chops: smooth silver teardrops on the jaw sides, clear of the cheeks ----
    for s, sx in (("l", 1), ("r", -1)):
        c = HC + Vector((sx * 0.236, -0.030, -0.125))

        def chop(d, q, sx=sx):
            # fuller at the bottom-front, tapering up toward the ear
            up = T.smoothstep(-0.2, 1.0, d.z)
            q.x *= 1.0 - 0.25 * up
            q.y *= 1.0 - 0.35 * up
            if d.y < 0:
                q.y *= 1.12
            return q
        bm = T.se_blob(c, 0.058, 0.085, 0.120, 2.3, "bouffant", n=4, warp=chop)
        T.rot_about(bm, c, (12, 0, sx * -18))
        T.recolor(bm, lambda cc, nn, cur: "bouffant_dk" if (cc - c).z < -0.085 and nn.z < -0.3 else None)
        body.add(bm, "sideburn_" + s, name="sideburn")
    # ---- the styled bouffant (three lobes, one jiggle bone each) ----
    for bone, bm in bouffant_neat(HC).items():
        body.add(bm, bone, name="bouffant")
    # ---- neck stub (hidden under the collar unless he stretches) ----
    bm = T.capsule_chain([H("neck_01") + Vector((0, 0, -0.03)), H("Head") + Vector((0, 0, 0.06))], [0.09, 0.085], "peach",
                         seg=8, cap_rings=1, samples_per_m=12)
    body.add(bm, ["spine_03", "neck_01", "Head"], name="neck")

    # ---- the barrel: white shirt V core + plum tail-coat shell open at the front ----
    W_TOP, Z_TOP, SLOPE = 0.062, TC.z + BARREL_R[2] * 0.70, 0.30

    def lapel_w(z):
        return W_TOP + (Z_TOP - z) * SLOPE
    Z_WAIST = TC.z - 0.22
    bm = T.blob(lambda d: TC + torso_q(d), "shirt", n=8)
    T.bisect(bm, (0, 0, Z_WAIST), (0, 0, 1))
    T.recolor(bm, lambda c, n, cur: "trouser" if c.z < Z_WAIST else None)
    T.delete_faces(bm, lambda c, n: (c - TC).y > 0.10 and c.z > Z_WAIST)      # hidden under the coat
    body.add(bm, ["pelvis", "spine_01", "spine_02", "spine_03"], power=3.0, keep=3, name="barrel")
    COAT_OFF = 0.020

    def coat_pos(d):
        q = torso_q(d)
        hem = T.smoothstep(-0.25, -0.42, q.z)
        return TC + q + q.normalized() * COAT_OFF + Vector((q.x, q.y, 0)) * 0.06 * hem
    bm = T.blob(coat_pos, "plum", n=10)
    for sx in (-1, 1):
        T.bisect(bm, (sx * (W_TOP + SLOPE * Z_TOP), 0, 0), (sx, 0, SLOPE))
    T.bisect(bm, (0, TC.y, Z_WAIST - 0.02), (0, 0.35, 1))
    T.delete_faces(bm, lambda c, n: (c - TC).y < -0.02 and abs(c.x) < lapel_w(c.z) - 1e-4)
    T.delete_faces(bm, lambda c, n: c.z - (Z_WAIST - 0.02) + 0.35 * (c.y - TC.y) < 0)   # tail-coat hem, lower at the back
    body.add(bm, ["pelvis", "spine_01", "spine_02", "spine_03"], power=3.0, keep=3, name="coat")
    # lapel rolls along the cut edges
    for sx in (-1, 1):
        pts = []
        for k in range(12):
            z = Z_TOP - 0.02 - (Z_TOP - 0.02 - (Z_WAIST + 0.04)) * k / 11
            x = sx * lapel_w(z)
            for j in range(220):
                y = TC.y - 0.02 - j * 0.004
                dd = Vector((x, y, z)) - TC
                if dd.length < 1e-6:
                    continue
                r = coat_pos(dd.normalized()) - TC
                if dd.length >= r.length:
                    pts.append(TC + r)
                    break
        if len(pts) > 2:
            bm = T.capsule_chain(pts, [0.019] * len(pts), "plum_lt", seg=5, cap_rings=1, samples_per_m=12)
            body.add(bm, ["spine_01", "spine_02", "spine_03"], power=3.0, keep=2, name="lapel")
    # coat tails: two flaps hanging at the back below the hem (jiggle)
    for s, sx in (("l", 1), ("r", -1)):
        h0, t0 = rig.head("tail_" + s), rig.tail("tail_" + s)
        c = (h0 + t0) * 0.5
        bm = T.se_blob(c, 0.085, 0.030, 0.140, 2.2, "plum", n=3)
        T.rot_about(bm, c, (-12, 0, sx * -8))
        T.recolor(bm, lambda cc, nn, cur: "plum_dk" if nn.y < -0.5 else None)
        body.add(bm, "tail_" + s, name="tail")
    # gold buttons down the shirt V
    for z in (TC.z - 0.14, TC.z - 0.02, TC.z + 0.10):
        zn = (z - TC.z) / BARREL_R[2]
        q = torso_q(Vector((0, -math.sqrt(max(0, 1 - zn * zn)), zn)).normalized())
        bm = T.se_blob(TC + q + Vector((0, -0.008, 0)), 0.026, 0.015, 0.026, 2.0, "button", n=1)
        body.add(bm, "spine_02", name="button")
    # the gold spotted cravat: a knot, two wings and a cascade
    cz, cy = rig.head("cravat").z, rig.head("cravat").y
    parts = [T.se_blob(Vector((0, cy - 0.012, cz - 0.005)), 0.060, 0.045, 0.052, 2.0, "cravat", n=3)]
    for sx in (-1, 1):
        w = T.se_blob(Vector((sx * 0.085, cy + 0.012, cz + 0.004)), 0.062, 0.030, 0.040, 2.0, "cravat", n=2)
        T.rot_about(w, Vector((sx * 0.085, cy, cz)), (0, sx * 14, 0))
        parts.append(w)
    parts.append(T.se_blob(Vector((0, cy - 0.030, cz - 0.110)), 0.058, 0.032, 0.085, 2.2, "cravat", n=3))
    bm = T.merge(*parts)
    L_ = T._col_layer(bm)
    for f in bm.faces:
        cc = f.calc_center_median()
        if f.normal.y < -0.3 and (int((cc.x + 1) * 40) + int((cc.z + 1) * 40)) % 4 == 0:
            f[L_] = TP.IDX["cravat_dot"]
    body.add(bm, "cravat", name="cravat")
    # the specs chain: a gold loop draped across the waistcoat (always on; the specs themselves are a prop)
    a, b = Vector((0.13, TC.y - 0.30, TC.z + 0.24)), Vector((-0.11, TC.y - 0.36, TC.z + 0.06))
    mid = (a + b) * 0.5 + Vector((0.02, -0.06, -0.10))
    bm = T.capsule_chain([a, mid, b], [0.006, 0.006, 0.006], "specs", seg=4, cap_rings=1, samples_per_m=24)
    body.add(bm, "spine_02", name="chain")

    # ---- arms: plum sleeves, white cuffs, white opera gloves ----
    for s, sx in (("l", 1), ("r", -1)):
        sh, el, wr = H("upperarm_" + s), H("lowerarm_" + s), H("hand_" + s)
        a0 = sh - (el - sh).normalized() * 0.05
        bm = T.capsule_chain([a0, el, wr], [0.080, 0.070, 0.062], "plum", seg=8, cap_rings=2, samples_per_m=18)
        body.add(bm, ["upperarm_" + s, "lowerarm_" + s], power=4.0, keep=2, name="sleeve")
        ax = (wr - el).normalized()
        bm = T.capsule_chain([wr - ax * 0.045, wr + ax * 0.005], [0.074, 0.072], "cuff", seg=8, cap_rings=1, samples_per_m=12)
        body.add(bm, "lowerarm_" + s, name="cuff")
        hx = (H("middle_01_" + s) - wr).normalized()
        bm = T.se_blob(wr + hx * 0.070, 0.066, 0.060, 0.040, 2.3, "glove", n=4)
        body.add(bm, "hand_" + s, name="palm")
        for f in ("index", "middle", "ring", "pinky"):
            a, b = H(f + "_01_" + s), rig.tail(f + "_03_" + s)
            r = 0.024 if f != "pinky" else 0.020
            bm = T.capsule_chain([a - hx * 0.02, b], [r, r * 0.92], "glove", seg=5, cap_rings=1, samples_per_m=20)
            bones = [f + "_01_" + s, f + "_02_" + s] if f != "pinky" else "pinky_01_" + s
            body.add(bm, bones, power=4.0, keep=2, name="finger")
        a, b = H("thumb_01_" + s), rig.tail("thumb_03_" + s)
        bm = T.capsule_chain([a + hx * 0.01, b], [0.026, 0.023], "glove", seg=5, cap_rings=1, samples_per_m=20)
        body.add(bm, ["thumb_01_" + s, "thumb_02_" + s], power=4.0, keep=2, name="thumb")
    # ---- legs: striped trousers, spats, tiny shoes ----
    for s, sx in (("l", 1), ("r", -1)):
        th, kn, an = H("thigh_" + s), H("calf_" + s), H("foot_" + s)
        bm = T.capsule_chain([th + Vector((0, 0, 0.02)), kn, an + Vector((0, 0, 0.02))], [0.062, 0.058, 0.052], "trouser",
                             seg=8, cap_rings=1, samples_per_m=16)
        L_ = T._col_layer(bm)
        for f in bm.faces:
            cc = f.calc_center_median() - th
            if int((math.atan2(cc.y, cc.x) + math.pi) / (2 * math.pi) * 8 + 0.5) % 2 == 0:
                f[L_] = TP.IDX["trouser_st"]
        body.add(bm, ["thigh_" + s, "calf_" + s], power=4.0, keep=2, name="leg")
        ft, bl = H("foot_" + s), H("ball_" + s)
        SC = Vector((ft.x, (ft.y + bl.y) * 0.5 - 0.030, 0.040))

        def shoe_warp(d, q):
            if q.y < 0:
                q.z *= 1.0 + 0.10 * T.smoothstep(0, -0.1, q.y)
            return q
        bm = T.se_blob(SC, 0.062, 0.110, 0.042, 2.4, "shoe", n=4, warp=shoe_warp)
        T.recolor(bm, lambda c, n, cur: "shoe_hi" if n.z > 0.7 and c.y < SC.y - 0.04 else None)
        body.add(bm, ["foot_" + s, "ball_" + s], power=4.0, keep=2, name="shoe")
        bm = T.capsule_chain([ft + Vector((0, 0.005, -0.020)), ft + Vector((0, -0.035, 0.035))], [0.060, 0.056], "spat",
                             seg=8, cap_rings=1, samples_per_m=10)
        body.add(bm, "foot_" + s, name="spat")


# ------------------------------------------------------------------------------------------------------------------
# held props (x1.5-1.8, R5) + specs: rigid on their own bones, hidden at scale 0 by the rig / clips
# ------------------------------------------------------------------------------------------------------------------
def build_props(body, rig, L):
    HC = L["HC"]
    HB = HEAD_R[1]
    CS = CUP_SCALE
    # teacup (prop_teacup, right hand grip): white, gold band, a curly handle toward the palm, tea inside
    PR = rig.head("prop_teacup") + Vector((-0.045 * CS, -0.010, 0.0))
    cup = T.capsule_chain([PR + Vector((0, 0, -0.030 * CS)), PR + Vector((0, 0, 0.030 * CS))], [0.030 * CS, 0.042 * CS], "cup",
                          seg=11, cap_rings=2, samples_per_m=8)
    T.bisect(cup, PR + Vector((0, 0, 0.000 * CS)), (0, 0, 1))
    T.bisect(cup, PR + Vector((0, 0, 0.016 * CS)), (0, 0, 1))
    T.bisect(cup, PR + Vector((0, 0, 0.026 * CS)), (0, 0, 1))
    T.recolor(cup, lambda c, n, cur: "cup_band" if (PR.z < c.z < PR.z + 0.016 * CS or c.z > PR.z + 0.026 * CS) and abs(n.z) < 0.85 else None)
    T.delete_faces(cup, lambda c, n: c.z > PR.z + 0.033 * CS)
    tea = T.se_blob(PR + Vector((0, 0, 0.028 * CS)), 0.038 * CS, 0.038 * CS, 0.004, 2.0, "tea", n=3)
    handle = T.torus(0.017 * CS, 0.006 * CS, PR + Vector((0.046 * CS, 0, 0.004)), "cup", seg=10, rseg=4, rot=(90, 0, 0))
    body.add(T.merge(cup, tea, handle), "prop_teacup", name="teacup")
    # saucer (prop_saucer, left hand): a flat white dish with the gold rim
    PL = rig.head("prop_saucer") + Vector((0.035, -0.010, 0.012))
    sau = T.se_blob(PL, 0.080 * CS * 0.62, 0.080 * CS * 0.62, 0.012, 2.0, "cup", n=4)
    T.recolor(sau, lambda c, n, cur: "cup_band" if (Vector((c.x, c.y, 0)) - Vector((PL.x, PL.y, 0))).length > 0.080 * CS * 0.50 else None)
    body.add(sau, "prop_saucer", name="saucer")
    # the honey spoon (prop_spoon): a long silver spoon, the bowl dripping gold
    PS = rig.head("prop_spoon")
    sp = T.capsule_chain([PS + Vector((0.0, 0.0, -0.05)), PS + Vector((0.0, -0.02, 0.17))], [0.010, 0.008], "spoon", seg=5, cap_rings=1, samples_per_m=8)
    bowl = T.se_blob(PS + Vector((0.0, -0.028, 0.20)), 0.030, 0.012, 0.040, 2.0, "honey", n=2)
    body.add(T.merge(sp, bowl), "prop_spoon", name="spoon")
    # the comb (prop_comb): a chunky red comb with four teeth
    # it sticks out of the fist along the fingers (right hand: -X at rest), teeth down, 0.20 m to the tip
    PC = rig.head("prop_comb")
    parts = [box(PC + Vector((-0.10, -0.005, 0.012)), (0.19, 0.020, 0.034), "comb")]
    for k in range(5):
        parts.append(box(PC + Vector((-0.045 - k * 0.034, -0.005, -0.018)), (0.013, 0.016, 0.040), "comb"))
    body.add(T.merge(*parts), "prop_comb", name="comb")
    # the conductor's baton (prop_baton): white wand, brown grip, pointing up/out
    PB = rig.head("prop_baton")     # along the fingers (right hand: -X at rest), 0.34 m, a white wand on a brown grip
    bt = T.capsule_chain([PB + Vector((0.02, 0, 0)), PB + Vector((-0.34, -0.01, 0.02))], [0.011, 0.006], "baton", seg=5, cap_rings=1, samples_per_m=8)
    gr = T.capsule_chain([PB + Vector((0.035, 0, 0)), PB + Vector((-0.035, 0, 0.002))], [0.020, 0.018], "baton_grip", seg=6, cap_rings=1, samples_per_m=20)
    body.add(T.merge(bt, gr), "prop_baton", name="baton")
    # specs worn on the nose (specs_face): big round gold rims so they read on the face card
    EY = SK.HC_Z + FACE_DZ + (0.5 - 0.423) * FACE_H
    parts = []
    for sx in (-1, 1):
        ex = sx * (0.667 - 0.5) * FACE_W
        parts.append(T.torus(0.058, 0.008, Vector((ex, HC.y - HB - 0.030, EY)), "specs", seg=12, rseg=3, rot=(90, 0, 0)))
        parts.append(T.capsule_chain([Vector((sx * 0.150, HC.y - HB - 0.012, EY + 0.006)), Vector((sx * 0.235, HC.y - 0.10, EY + 0.012))],
                                     [0.006, 0.006], "specs", seg=4, cap_rings=1, samples_per_m=10))
    parts.append(T.capsule_chain([Vector((-0.036, HC.y - HB - 0.058, EY + 0.012)), Vector((0.036, HC.y - HB - 0.058, EY + 0.012))],
                                 [0.007, 0.007], "specs", seg=4, cap_rings=1, samples_per_m=10))
    body.add(T.merge(*parts), "specs_face", name="specs_face")
    # the same specs dangling on the belly (specs_chest): folded, hanging from the chain
    SPC = rig.head("specs_chest")
    parts = []
    for sx in (-1, 1):
        parts.append(T.torus(0.042, 0.008, SPC + Vector((sx * 0.050, 0, 0)), "specs", seg=9, rseg=3, rot=(90, 0, 0)))
        parts.append(T.se_blob(SPC + Vector((sx * 0.050, 0.004, 0)), 0.038, 0.004, 0.038, 2.0, "lens", n=2))
    parts.append(T.capsule_chain([SPC + Vector((-0.012, 0, 0.004)), SPC + Vector((0.012, 0, 0.004))], [0.006, 0.006], "specs", seg=4, cap_rings=1, samples_per_m=10))
    bm = T.merge(*parts)
    T.rot_about(bm, SPC, (-14, 0, 10))
    body.add(bm, "specs_chest", name="specs_chest")


# ------------------------------------------------------------------------------------------------------------------
# FX (vinyl, skinned in; scale 0 until the clip scales them): the CHOO puff, five dazed stars, four orbiting notes
# ------------------------------------------------------------------------------------------------------------------
def build_fx(body, rig, L):
    random.seed(11)
    FX = rig.head("fx_choo")
    # the puff: one big scalloped cotton-wool cloud ~0.9 m across in front of the nose (+ two small puffs, droplets)
    cc = FX + Vector((0, -0.34, 0.02))
    parts = [lobe(cc, (0.44, 0.22, 0.34), (0, -1, 0), "puff", "puff_sh", n_ridges=9, amp=0.16, rings=6, segs=27)]
    for off, r in (((0.30, -0.10, 0.26), 0.12), ((-0.33, -0.06, -0.20), 0.10)):
        parts.append(lobe(cc + Vector(off), (r, r * 0.8, r), (0, -1, 0), "puff", "puff_sh", n_ridges=6, amp=0.18, rings=4, segs=12))
    for _ in range(6):
        p = cc + Vector((random.uniform(-0.52, 0.52), random.uniform(-0.25, -0.05), random.uniform(-0.40, 0.40)))
        parts.append(T.se_blob(p, 0.024, 0.024, 0.030, 2.0, "drop", n=1))
    body.add(T.merge(*parts), "fx_choo", name="fx_choo", outline=1.3)
    # dazed stars: five chunky yellow vinyl stars on a 0.28 m ring (the clip spins the ring bone)
    FS = rig.head("fx_stars")
    parts = []
    for k in range(5):
        a = 2 * math.pi * k / 5
        p = FS + Vector((math.cos(a) * 0.28, math.sin(a) * 0.28, 0.02 * math.sin(3 * a)))
        parts.append(star_prism(p, 0.062, 0.028, 0.030, "star", rot=(0, math.degrees(a) * 0.3, math.degrees(a))))
    body.add(T.merge(*parts), "fx_stars", name="fx_stars")
    # orbiting notes: four navy vinyl music notes on a 0.32 m ring
    FN = rig.head("fx_notes")
    parts = []
    for k in range(4):
        a = 2 * math.pi * (k + 0.5) / 4
        p = FN + Vector((math.cos(a) * 0.32, math.sin(a) * 0.32, 0.03 * (k % 2)))
        parts.append(T.se_blob(p, 0.040, 0.022, 0.030, 2.0, "note", n=2))
        parts.append(box(p + Vector((0.034, 0, 0.075)), (0.012, 0.012, 0.15), "note"))
        parts.append(box(p + Vector((0.052, 0, 0.135)), (0.040, 0.012, 0.022), "note", rot=(0, -25, 0)))
    body.add(T.merge(*parts), "fx_notes", name="fx_notes")


# ------------------------------------------------------------------------------------------------------------------
# attachment scenes (separate small glbs on a bone; the body-slot variants of the bouffant)
# ------------------------------------------------------------------------------------------------------------------
def _export_attachment(rig, bone, bms, path, mat):
    """One rigid mesh in the bone's local frame (Blender bone space; the glTF exporter converts to Y-up, and a
    BoneAttachment3D on that bone places it back at rest)."""
    M = (rig.arm.matrix_world @ rig.B[bone].matrix_local).inverted()
    tmp = T.Body(rig, "att")
    for i, bm in enumerate(bms):
        bmesh.ops.transform(bm, matrix=M, verts=bm.verts[:])
        tmp.add(bm, bone, name="att%d" % i)
    for o in tmp.parts:
        o.vertex_groups.clear()
    bpy.ops.object.select_all(action="DESELECT")
    for o in tmp.parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = tmp.parts[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    name = os.path.splitext(os.path.basename(path))[0]
    ob.name = name
    ob.data.name = name
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    ob.data.color_attributes.active_color = ob.data.color_attributes["Col"]
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    hidden = []
    for o in bpy.data.objects:
        if o != ob:
            hidden.append((o, o.hide_get()))
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
              export_animations=False, export_skins=False, export_materials="EXPORT", export_texcoords=True,
              export_normals=True, export_image_format="NONE")
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if "export_vertex_color" in props:
        kw["export_vertex_color"] = "ACTIVE"
    kw = {k: v for k, v in kw.items() if k in props or k == "filepath"}
    bpy.ops.export_scene.gltf(**kw)
    bpy.data.objects.remove(ob, do_unlink=True)
    return tris


def bouffant_flipped(HC):
    """ACHOO-RIA! / BLINDED: the whole dandelion tipped forward over his eyes (a silver fringe down to the nose)."""
    bms = []
    piv = HC + Vector((0, 0.02, 0.10))
    for bone, bm in bouffant_neat(HC, rings=(8, 7), segs=(30, 24)).items():
        T.rot_about(bm, piv, (-58, 0, 0))
        bmesh.ops.translate(bm, vec=Vector((0, -0.05, -0.02)), verts=bm.verts[:])
        bms.append(bm)
    return bms


def bouffant_frazzled(HC):
    """FRAZZLED: blown up into a frizz -- bigger, spikier ridges, singed grey tips."""
    bms = []
    for bone, (off, radii, pole, nr) in BOUFFANT_LOBES.items():
        c = HC + Vector(off) * 1.12 + Vector((0, 0, 0.02))
        rr = tuple(r * 1.18 for r in radii)
        bm = lobe(c, rr, pole, "frazzle", "frazzle_dk", n_ridges=nr + 6, amp=0.22, rings=8, segs=36 if bone == "bouffant" else 26)
        bms.append(bm)
    return bms


def bouffant_wet(HC):
    """SOAKED: the puff flattened into dripping spaniel ears (crown slicked flat, side lobes drooping)."""
    bms = []
    for bone, (off, radii, pole, nr) in BOUFFANT_LOBES.items():
        if bone == "bouffant":
            c = HC + Vector((0.0, 0.05, 0.19))
            rr = (0.275, 0.25, 0.13)
        else:
            sx = 1 if bone.endswith("_l") else -1
            c = HC + Vector((sx * 0.25, 0.04, -0.06))
            rr = (0.11, 0.13, 0.22)
        bm = lobe(c, rr, (0, -1, 0.2), "wet", "wet_dk", n_ridges=6, amp=0.05, rings=7, segs=22)
        bms.append(bm)
    return bms


def bouffant_floured(HC):
    """FLOURY: the same styled puff caked white (a lumpier, brighter version)."""
    return list(bouffant_neat(HC, color="flour", groove="flour", scale=1.04, rings=(8, 7), segs=(30, 24)).values())


def build_attachments(rig, L, out_dir, mat):
    HC = L["HC"]
    res = {}
    for name, fn in (("bouffant_flipped", bouffant_flipped), ("bouffant_frazzled", bouffant_frazzled),
                     ("bouffant_wet", bouffant_wet), ("bouffant_floured", bouffant_floured)):
        path = os.path.join(out_dir, name + ".glb")
        res[name] = {"bone": "Head", "tris": _export_attachment(rig, "Head", fn(HC), path, mat)}
    return res


def measure_height(ob):
    return round(max((ob.matrix_world @ v.co).z for v in ob.data.vertices
                     if not any(ob.vertex_groups[g.group].name.startswith(("fx_", "prop_")) for g in v.groups if g.weight > 0.5)), 4)


def preview(arm, out_dir):
    import blib
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.show_object_outline = True
    sc.render.resolution_x, sc.render.resolution_y = 520, 620
    cam_d = bpy.data.cameras.new("pc")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 2.2
    cam = bpy.data.objects.new("pc", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for view, (x, y, rz) in {"front": (0, -4, 0), "side": (4, 0, 90), "34": (2.83, -2.83, 45)}.items():
        cam.location = (x, y, 0.95)
        cam.rotation_euler = (math.radians(90), 0, math.radians(rz))
        sc.render.filepath = os.path.join(out_dir, "wb_%s.png" % view)
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
