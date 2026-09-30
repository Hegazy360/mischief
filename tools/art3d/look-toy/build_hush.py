"""HUSH -- Toy Box look-dev. blender -b --python build_hush.py -- --out hush_toy.glb [--preview dir] [--nolib]

Street mime ~25, lanky (2.5 heads), tilted cherry beret, Breton stripes, red braces, huge white gloves,
white face paint, big warm eyes (decals), rosy cheeks. Built on the CC0 Quaternius UAL skeleton with
chibi bone lengths (directions + rolls kept, so the UAL clips still apply) + a beret and a prop bone.
"""
import bpy, bmesh, sys, os, math, json
from mathutils import Vector, Matrix, Euler
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toy_lib as T
import toy_common as C
import toy_palette as TP

opt = C.args()
T.reset()
LIB1 = ["Walk_Loop", "Sprint_Loop", "Crouch_Fwd_Loop", "Interact", "Idle_Loop", "Jog_Fwd_Loop", "Sitting_Idle_Loop", "PickUp_Table"]
LIB2 = ["Yes", "Idle_No_Loop"]
if "nolib" in opt:
    LIB1, LIB2 = [], []
arm = T.import_ual(C.UAL1, C.UAL2 if LIB2 else None, LIB1, LIB2)

K = {"pelvis": 0.7, "spine_01": 0.7, "spine_02": 0.7, "spine_03": 0.7, "neck_01": 0.6, "Head": 3.0}
for s in ("l", "r"):
    K.update({f"clavicle_{s}": 0.73, f"upperarm_{s}": 0.55, f"lowerarm_{s}": 0.55, f"hand_{s}": 1.05,
              f"thigh_{s}": 0.42, f"calf_{s}": 0.42, f"foot_{s}": 0.95, f"ball_{s}": 0.95, f"ball_leaf_{s}": 0.95})
    for f in ("index", "middle", "ring", "pinky", "thumb"):
        for i in (1, 2, 3, 4):
            K[f"{f}_{i:02d}_{s}" if i < 4 else f"{f}_04_leaf_{s}"] = 0.95
KO = {"thigh_l": (0.95, 0.6, 1.0), "thigh_r": (0.95, 0.6, 1.0)}
for s in ("l", "r"):
    for f in ("index", "middle", "ring", "pinky"):
        KO[f"{f}_01_{s}"] = (1.0, 1.25, 1.0)   # spread the glove fingers a little
    KO[f"thumb_01_{s}"] = (1.0, 1.5, 1.0)
hip_ratio = T.retarget(arm, K, KO, foot_k=0.95)
rig = T.Rig(arm)
H = rig.head
HB = H("Head")
HC = Vector((0.0, HB.y - 0.005, 1.165))       # head centre
HA, HBy, HCz, HP = 0.285, 0.258, 0.300, 2.25  # head half-sizes + superellipse power

# extra bones
T.add_bones(arm, [
    ("beret", "Head", HC + Vector((-0.02, 0.03, 0.27)), HC + Vector((-0.02, 0.03, 0.40))),
    ("prop_r", "hand_r", H("hand_r") + Vector((-0.07, -0.02, -0.05)), H("hand_r") + Vector((-0.07, -0.02, 0.05))),
    ("fx_pepper", "prop_r", H("hand_r") + Vector((-0.07, -0.02, -0.25)), H("hand_r") + Vector((-0.07, -0.02, -0.15))),
])
rig = T.Rig(arm)
H = rig.head
body = T.Body(rig, "HushToy")


def head_q(d):
    r = T.se_radius(d, HA, HBy, HCz, HP)
    q = d * r
    # chibi cheeks: a touch wider in the lower half, a softer flatter crown
    lo = T.smoothstep(0.05, -0.2, q.z)
    q.x *= 1.0 + 0.045 * lo
    q.y *= 1.0 + 0.02 * lo
    q.z *= 1.0 - 0.04 * T.smoothstep(0.1, 0.3, q.z)
    return q


def face_amount(q):
    front = T.smoothstep(-0.02, -0.15, q.y)
    xn = q.x / 0.285
    fringe_z = 0.088 - 0.07 * xn * xn - 0.018 * xn     # swept fringe, a touch higher on her right
    below = T.smoothstep(fringe_z + 0.03, fringe_z - 0.03, q.z)
    sides = T.smoothstep(0.245, 0.19, abs(q.x))
    return front * below * sides


def hair_amount(q):
    return 1.0 - face_amount(q)


# ---- head (white face paint) + face decal UVs ----------------------------------------------------
bm = T.blob(lambda d: HC + head_q(d), "paint", n=14)
T.delete_faces(bm, lambda c, n: hair_amount(c - HC) > 0.995 and (c - HC).z > -0.1)
body.add(bm, "Head", face_uv={"center": (0.0, HC.z), "w": 0.58, "h": 0.58, "front": -0.2, "ymax": HC.y - 0.06}, name="head")
# tiny button nose
bm = T.se_blob(HC + Vector((0, -HBy + 0.006, -0.045)), 0.034, 0.02, 0.028, 2.0, "nose_h", n=5)
body.add(bm, "Head", name="nose")


# ---- hair: a bob shell = the head surface pushed out where there is hair, pulled in on the face -----
def hair_pos(d):
    q = head_q(d)
    face = face_amount(q)
    s = T.lerp(1.07 - 0.04 * T.smoothstep(0.12, 0.26, q.z), 0.9, face)
    p = q * s
    hang = T.smoothstep(0.02, -0.2, q.z) * (1.0 - face)
    p.x *= 1.0 + 0.11 * hang
    p.y *= 1.0 + 0.12 * hang * (1.0 if p.y > 0 else 0.3)
    return HC + p


bm = T.blob(hair_pos, "hair", n=16)
# bob cut: level at the jaw, a little longer toward the face
T.bisect(bm, HC + Vector((0, 0, -0.245)), (0, 0.12, 1))
T.delete_faces(bm, lambda c, n: (0.12 * (c - HC).y + (c - HC).z + 0.245) < 0)
body.add(bm, "Head", name="hair")

# ---- beret (tilted, droopy, with a nub) -------------------------------------------------------------
BC = HC + Vector((-0.02, 0.03, 0.285))


def beret_warp(d, q):
    rr = (q.x * q.x + q.y * q.y) / (0.27 * 0.27)
    q.z -= 0.05 * rr          # droop at the rim
    q.z += 0.02 * (1 - rr)
    return q


bm = T.se_blob(BC, 0.275, 0.265, 0.07, 2.4, "beret", n=9, warp=beret_warp)
bm2 = T.capsule_chain([BC + Vector((0, 0, 0.07)), BC + Vector((0.01, 0, 0.115))], [0.016, 0.012], "beret_dk", seg=6, cap_rings=2)
bm = T.merge(bm, bm2)
T.rot_about(bm, BC, (-7, -13, 0))
body.add(bm, "beret", name="beret")

# ---- neck ---------------------------------------------------------------------------------------------
bm = T.capsule_chain([H("neck_01") + Vector((0, 0, -0.05)), H("Head") + Vector((0, 0, 0.06))], [0.048, 0.046], "paint", seg=10, cap_rings=2)
body.add(bm, ["spine_03", "neck_01", "Head"], name="neck")

# ---- torso: a striped bean; red braces --------------------------------------------------------------
TC = Vector((0.0, H("spine_02").y + 0.01, 0.655))
TA, TB, TCz, TPw = 0.158, 0.13, 0.205, 2.3


def torso_warp(d, q):
    zn = q.z / TCz
    q.x *= 1.0 + 0.07 * zn - 0.05 * zn * zn
    q.y *= 1.0 + 0.03 * zn
    return q


bm = T.se_blob(TC, TA, TB, TCz, TPw, "stripe", n=10, warp=torso_warp)
stripes = [0.505 + 0.052 * i for i in range(7)]
for z in stripes:
    T.bisect(bm, (0, 0, z), (0, 0, 1))


def stripe_col(z, zs):
    k = sum(1 for s in zs if z > s)
    return "navy" if k % 2 == 1 else "stripe"


T.recolor(bm, lambda c, n, cur: stripe_col(c.z, stripes))
T.recolor(bm, lambda c, n, cur: "navy" if c.z > stripes[-1] else None)
body.add(bm, ["pelvis", "spine_01", "spine_02", "spine_03"], power=3.0, keep=3, name="torso")


def torso_surface(x, z, side):
    """Point + outward normal on the torso at (x, z), side -1 = front (y<0), +1 = back."""
    zn = (z - TC.z) / TCz
    a = TA * (1.0 + 0.07 * zn - 0.05 * zn * zn)
    b = TB * (1.0 + 0.03 * zn)
    t = 1.0 - abs(x / a) ** TPw - abs(zn) ** TPw
    t = max(t, 1e-4)
    y = side * b * t ** (1.0 / TPw)
    p = Vector((x, TC.y + y, z))
    # implicit gradient
    g = Vector((TPw * abs(x / a) ** (TPw - 1) / a * math.copysign(1, x),
                TPw * abs(y / b) ** (TPw - 1) / b * side,
                TPw * abs(zn) ** (TPw - 1) / TCz * math.copysign(1, zn)))
    return p, g.normalized()


for sx in (-1, 1):
    for side in (-1, 1):
        pts, nrm = [], []
        for i in range(14):
            z = 0.47 + (0.82 - 0.47) * i / 13
            x = sx * (0.072 + 0.012 * (z - 0.47) / 0.35)
            p, n = torso_surface(x, z, side)
            pts.append(p + n * 0.002)
            nrm.append(n)
        bm = T.ribbon(pts, nrm, 0.036, 0.011, "braces")
        body.add(bm, ["spine_01", "spine_02", "spine_03"], power=3.0, keep=2, name="brace")
        if side == -1:   # button
            p, n = torso_surface(sx * 0.072, 0.505, -1)
            bm = T.se_blob(p + n * 0.012, 0.014, 0.008, 0.014, 2.0, "shoe", n=3)
            body.add(bm, "spine_01", name="btn")

# ---- hips / trousers ---------------------------------------------------------------------------------
PC = Vector((0.0, TC.y + 0.005, 0.455))
bm = T.se_blob(PC, 0.148, 0.122, 0.085, 2.2, "trouser", n=7)
body.add(bm, ["pelvis", "thigh_l", "thigh_r"], power=4.0, keep=2, name="hips")

for s, sx in (("l", 1), ("r", -1)):
    # trouser leg
    th, kn, an = H("thigh_" + s), H("calf_" + s), H("foot_" + s)
    bm = T.capsule_chain([th + Vector((0, 0, 0.02)), kn, an + Vector((0, 0, 0.0))], [0.07, 0.062, 0.066], "trouser", seg=10, cap_rings=2, samples_per_m=35)
    body.add(bm, ["thigh_" + s, "calf_" + s], power=4.0, keep=2, name="leg")
    # shoe: chunky rounded toy shoe
    ft, bl = H("foot_" + s), H("ball_" + s)
    SC = Vector((ft.x, (ft.y + bl.y) * 0.5 - 0.03, 0.047))

    def shoe_warp(d, q):
        if q.y < 0:
            q.z *= 1.0 + 0.18 * T.smoothstep(0, -0.1, q.y)   # a round toe cap
        return q
    bm = T.se_blob(SC, 0.068, 0.13, 0.054, 2.5, "shoe", n=7, warp=shoe_warp)
    T.bisect(bm, (0, 0, 0.016), (0, 0, 1))
    T.recolor(bm, lambda c, n, cur: "sole" if c.z < 0.016 else None)
    body.add(bm, ["foot_" + s, "ball_" + s], power=4.0, keep=2, name="shoe")

    # sleeve (striped) from inside the shoulder to the wrist
    sh, el, wr = H("upperarm_" + s), H("lowerarm_" + s), H("hand_" + s)
    a0 = sh + (sh - wr).normalized() * 0.045
    bm = T.capsule_chain([a0, el, wr + (wr - el).normalized() * 0.02], [0.053, 0.047, 0.045], "stripe", seg=10, cap_rings=2, samples_per_m=45)
    ax = (wr - sh).normalized()
    L = (wr - sh).length
    cuts = [0.03 + 0.042 * i for i in range(int(L / 0.042) + 1)]
    for c_ in cuts:
        T.bisect(bm, sh + ax * c_, ax)

    def sleeve_col(c, n, cur, sh=sh, ax=ax, cuts=cuts):
        t = (c - sh).dot(ax)
        k = sum(1 for c_ in cuts if t > c_)
        return "navy" if k % 2 == 0 else "stripe"
    T.recolor(bm, sleeve_col)
    body.add(bm, ["upperarm_" + s, "lowerarm_" + s], power=4.0, keep=2, name="sleeve")

    # the huge white glove: flared cuff, puffy palm, three fat fingers + thumb (1.6x a hand)
    hx = (H("middle_01_" + s) - wr).normalized()
    cuff = T.capsule_chain([wr - hx * 0.02, wr + hx * 0.035], [0.058, 0.09], "glove", seg=12, cap_rings=2, samples_per_m=40)
    T.bisect(cuff, wr + hx * 0.028, hx)
    T.recolor(cuff, lambda c, n, cur, wr=wr, hx=hx: "glove_sh" if (c - wr).dot(hx) > 0.028 else None)
    body.add(cuff, "hand_" + s, name="cuff")
    PCn = wr + hx * 0.105 + Vector((0, 0.0, 0.0))
    bm = T.se_blob(PCn, 0.078, 0.09, 0.056, 2.3, "glove", n=6)
    body.add(bm, "hand_" + s, name="palm")
    for f, rad in (("index", 0.034), ("middle", 0.035), ("ring", 0.032)):
        a, b = H(f + "_01_" + s), rig.tail(f + "_03_" + s)
        bm = T.capsule_chain([a - hx * 0.01, b - hx * 0.012], [rad, rad * 0.95], "glove", seg=8, cap_rings=2, samples_per_m=40)
        body.add(bm, [f + "_01_" + s, f + "_02_" + s, f + "_03_" + s], power=4.0, keep=2, name="finger")
    a, b = H("thumb_01_" + s), rig.tail("thumb_03_" + s)
    bm = T.capsule_chain([a + hx * 0.02, b], [0.034, 0.03], "glove", seg=8, cap_rings=2, samples_per_m=40)
    body.add(bm, ["thumb_01_" + s, "thumb_02_" + s, "thumb_03_" + s], power=4.0, keep=2, name="thumb")

# ---- the pepper shaker (held prop on prop_r; scale 0 when not used): gripped at the base, cap pointing
#      along the fingers, so a wrist bend tips it into a pour ------------------------------------------------
PR = H("prop_r")
hxr = (H("middle_01_r") - H("hand_r")).normalized()
base = H("hand_r") + hxr * 0.11
ax = Vector((0, -1, 0))                     # through the fist (thumb side = cap end)
bm = T.capsule_chain([base - ax * 0.09, base + ax * 0.09], [0.044, 0.04], "pepper", seg=10, cap_rings=2, samples_per_m=30)
T.bisect(bm, base + ax * 0.065, ax)
T.recolor(bm, lambda c, n, cur: "shaker_cap" if (c - base).dot(ax) > 0.065 else None)
dots = [T.se_blob(base + ax * 0.132 + Vector((dx, 0, dz)), 0.008, 0.008, 0.008, 2.0, "pepper", n=1) for dx in (-0.015, 0.015) for dz in (-0.015, 0.015)]
body.add(T.merge(bm, *dots), "prop_r", name="shaker")

PAL = os.path.join(opt.get("build", "/tmp"), "toy_palette.png")
FACE = opt.get("face")
mat = T.toy_material("toy_hush", PAL, FACE)
bodyob = body.finish(mat)
tris = sum(len(p.vertices) - 2 for p in bodyob.data.polygons)
print("HUSH tris", tris, "verts", len(bodyob.data.vertices), "bones", len(arm.data.bones))

# ---- clips ---------------------------------------------------------------------------------------
anim = T.Animator(rig, C.MAIN + C.FINGERS + ["beret", "prop_r", "fx_pepper"])
if "noclips" not in opt:
    import clips_hush
    clips_hush.build(anim, rig)

T.key_library_extras(arm, ["prop_r", "fx_pepper"])
meta = {"character": "hush", "tris": tris, "bones": len(arm.data.bones), "hip_ratio": hip_ratio,
        "head_center": [HC.x, HC.z, -HC.y], "faces": anim.faces, "clips": anim.meta,
        "actions": sorted(a.name for a in bpy.data.actions)}
if "meta" in opt:
    json.dump(meta, open(opt["meta"], "w"), indent=1)
if "preview" in opt:
    shots = [(None, 1, v) for v in ("front", "side", "34", "back")]
    for a in opt.get("pv", "").split(","):
        if a:
            nm, fr, vw = a.split(":")
            shots.append((nm, int(fr), vw))
    C.preview(arm, opt["preview"], shots, size=(420, 560), ortho=1.9, center_z=0.85, tag="hush_")
if "out" in opt:
    T.export_glb(arm, bodyob, opt["out"])
    print("HUSH_OK", opt["out"])
