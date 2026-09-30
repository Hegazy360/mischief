"""HORACE BELLOWS -- Toy Box look-dev. blender -b --python build_bellows.py -- --out bellows_toy.glb [--preview dir]

61, retired opera baritone: a dandelion clock on a barrel -- barrel torso on tiny legs, silver bouffant
(metaball cloud), springy mutton-chop sideburns, big nose, specs on a chain (worn = specs_face bone),
plum coat open over a cream waistcoat, gold cravat, slippers. UAL skeleton with chibi bone lengths.
"""
import bpy, bmesh, sys, os, math, json, random
from mathutils import Vector, Matrix, Euler
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toy_lib as T
import toy_common as C
import toy_palette as TP

opt = C.args()
T.reset()
LIB1 = ["Walk_Formal_Loop", "Idle_Loop", "Sitting_Idle_Loop", "Interact", "Idle_Talking_Loop", "Hit_Head"]
LIB2 = ["Idle_FoldArms_Loop", "Consume"]
if "nolib" in opt:
    LIB1, LIB2 = [], []
arm = T.import_ual(C.UAL1, C.UAL2 if LIB2 else None, LIB1, LIB2)

KS = 1.17
K = {"pelvis": KS, "spine_01": KS, "spine_02": KS, "spine_03": KS, "neck_01": 0.6, "Head": 3.0}
for s in ("l", "r"):
    K.update({f"clavicle_{s}": 1.67, f"upperarm_{s}": 0.74, f"lowerarm_{s}": 0.74, f"hand_{s}": 0.8,
              f"thigh_{s}": 0.24, f"calf_{s}": 0.24, f"foot_{s}": 0.78, f"ball_{s}": 0.78, f"ball_leaf_{s}": 0.78})
    for f in ("index", "middle", "ring", "pinky", "thumb"):
        for i in (1, 2, 3, 4):
            K[f"{f}_{i:02d}_{s}" if i < 4 else f"{f}_04_leaf_{s}"] = 0.72
KO = {"thigh_l": (1.3, 0.8, 1.0), "thigh_r": (1.3, 0.8, 1.0), "upperarm_l": (1.62, 0.3, 1.05), "upperarm_r": (1.62, 0.3, 1.05)}
hip_ratio = T.retarget(arm, K, KO, foot_k=0.78)
rig = T.Rig(arm)
H = rig.head
HB = H("Head")
HC = Vector((0.0, HB.y - 0.02, 1.205))
HA, HBy, HCz, HP = 0.25, 0.236, 0.245, 2.1
TC = Vector((0.0, H("spine_02").y + 0.005, 0.605))
TA, TB, TCz, TPw = 0.36, 0.325, 0.40, 2.2

T.add_bones(arm, [
    ("bouffant", "Head", HC + Vector((0, 0.03, 0.2)), HC + Vector((0, 0.03, 0.36))),
    ("sideburn_l", "Head", HC + Vector((0.2, -0.06, -0.02)), HC + Vector((0.3, -0.08, -0.08))),
    ("sideburn_r", "Head", HC + Vector((-0.2, -0.06, -0.02)), HC + Vector((-0.3, -0.08, -0.08))),
    ("nose", "Head", HC + Vector((0, -0.2, -0.03)), HC + Vector((0, -0.3, -0.03))),
    ("specs_face", "Head", HC + Vector((0, -0.2, 0.02)), HC + Vector((0, -0.2, 0.1))),
    ("specs_chest", "spine_03", Vector((0.0, -0.22, 0.76)), Vector((0.0, -0.22, 0.86))),
    ("cravat", "spine_03", Vector((0.0, -0.2, 0.93)), Vector((0.0, -0.2, 0.83))),
    ("fx_choo", "Head", HC + Vector((0, -0.34, -0.06)), HC + Vector((0, -0.5, -0.1))),
    ("prop_r", "hand_r", H("hand_r") + Vector((-0.06, -0.035, 0.0)), H("hand_r") + Vector((-0.06, -0.035, 0.1))),
    ("prop_l", "hand_l", H("hand_l") + Vector((0.06, 0.0, -0.045)), H("hand_l") + Vector((0.06, 0.0, 0.055))),
])
rig = T.Rig(arm)
H = rig.head
body = T.Body(rig, "BellowsToy")
# the bouffant: a dandelion clock of silver puffs
random.seed(7)
# a round puffball (dandelion clock): a core + scalloped puffs on an ellipsoid shell around it
BC_ = (0.0, 0.07, 0.19)            # centre, relative to HC
puffs = [(0.0, 0.07, 0.2, 0.25), (0.0, 0.12, 0.1, 0.2), (0.17, 0.06, 0.13, 0.17), (-0.17, 0.06, 0.13, 0.17)]
import math as _m
N = 46
for i in range(N):
    zz = 1 - 2 * (i + 0.5) / N
    rr = _m.sqrt(max(0.0, 1 - zz * zz))
    ph = i * 2.39996
    dx, dy, dz = _m.cos(ph) * rr, _m.sin(ph) * rr, zz
    if dz < -0.45:
        continue
    if dy < -0.35 and dz < 0.3:      # keep the face open (forehead line above the brows)
        continue
    if dz < -0.1 and dy < 0.1 and abs(dx) < 0.75:
        continue
    r = 0.088 + 0.03 * random.random()
    puffs.append((BC_[0] + dx * 0.31, BC_[1] + dy * 0.27, BC_[2] + dz * 0.25, r))
PUFFS = puffs


def head_q(d):
    q = d * T.se_radius(d, HA, HBy, HCz, HP)
    lo = T.smoothstep(0.05, -0.22, q.z)          # jowls
    q.x *= 1.0 + 0.10 * lo
    q.y *= 1.0 + 0.04 * lo
    return q


bm = T.blob(lambda d: HC + head_q(d), "peach", n=12)
T.delete_faces(bm, lambda c, n: any((c - Vector((x, HC.y + y, HC.z + z))).length < r * 0.8 for x, y, z, r in PUFFS) and (c - HC).z > 0.12)
body.add(bm, "Head", face_uv={"center": (0.0, HC.z), "w": 0.52, "h": 0.52, "front": -0.2, "ymax": HC.y - 0.05}, name="head")

# big bulbous nose
NC = HC + Vector((0, -HBy - 0.035, -0.035))
bm = T.se_blob(NC, 0.074, 0.066, 0.064, 2.0, "nose", n=6)
body.add(bm, "nose", name="nose")

# ears peek between the sideburns and the bouffant
for sx in (-1, 1):
    bm = T.se_blob(HC + Vector((sx * 0.245, 0.03, 0.0)), 0.035, 0.05, 0.065, 2.0, "peach", n=3)
    body.add(bm, "Head", name="ear")

# mutton-chop sideburns: soft silver puffs down the cheeks (springs that bristle with temper)
for s, sx in (("l", 1), ("r", -1)):
    els = [("BALL", (sx * 0.24, -0.02, 1.215), 0.06), ("BALL", (sx * 0.25, -0.07, 1.15), 0.066),
           ("BALL", (sx * 0.232, -0.12, 1.08), 0.062), ("BALL", (sx * 0.19, -0.16, 1.03), 0.052),
           ("BALL", (sx * 0.275, -0.02, 1.1), 0.055), ("BALL", (sx * 0.265, 0.02, 1.17), 0.05),
           ("BALL", (sx * 0.215, -0.19, 1.07), 0.04), ("BALL", (sx * 0.285, -0.08, 1.05), 0.045)]
    els = [(t, (x, HC.y + y + 0.02, z - 1.205 + HC.z), r) for t, (x, y, z), r in els]
    bm = T.metaballs("sb" + s, els, "bouffant", resolution=0.02, decimate=0.22, smooth=3)
    body.add(bm, "sideburn_" + s, name="sideburn")

els = [("BALL", (x, HC.y + y, HC.z + z), r) for x, y, z, r in puffs]
bm = T.metaballs("bouf", els, "bouffant", resolution=0.02, decimate=0.15, smooth=2)
body.add(bm, "bouffant", name="bouffant")

# neck (mostly hidden by the cravat)
bm = T.capsule_chain([H("neck_01") + Vector((0, 0, -0.04)), H("Head") + Vector((0, 0, 0.05))], [0.08, 0.075], "peach", seg=10, cap_rings=2)
body.add(bm, ["spine_03", "neck_01", "Head"], name="neck")


# ---- the barrel: cream waistcoat core + plum coat shell open at the front ----------------------------
def torso_q(d):
    q = d * T.se_radius(d, TA, TB, TCz, TPw)
    zn = q.z / TCz
    k = 1.0 + 0.05 * (0.4 - zn) - 0.06 * max(0.0, zn - 0.5)
    q.x *= k
    q.y *= k
    return q


W_TOP, Z_TOP, SLOPE = 0.055, 0.985, 0.27     # lapel line: |x| = W_TOP + (Z_TOP - z) * SLOPE


def lapel_w(z):
    return W_TOP + (Z_TOP - z) * SLOPE


bm = T.blob(lambda d: TC + torso_q(d), "vest", n=9)
T.bisect(bm, (0, 0, 0.3), (0, 0, 1))
T.recolor(bm, lambda c, n, cur: "trouser_b" if c.z < 0.3 else None)
T.delete_faces(bm, lambda c, n: (c - TC).y > 0.12 and c.z > 0.3)     # hidden under the coat
body.add(bm, ["pelvis", "spine_01", "spine_02", "spine_03"], power=3.0, keep=3, name="barrel")

COAT_OFF = 0.018


def coat_pos(d):
    q = torso_q(d)
    hem = T.smoothstep(-0.2, -0.38, q.z)
    return TC + q + q.normalized() * COAT_OFF + Vector((q.x, q.y, 0)) * 0.06 * hem


bm = T.blob(coat_pos, "plum", n=12)
for sx in (-1, 1):   # the two lapel planes: sx*x + SLOPE*z = W_TOP + SLOPE*Z_TOP
    T.bisect(bm, (sx * (W_TOP + SLOPE * Z_TOP), 0, 0), (sx, 0, SLOPE))
T.bisect(bm, (0, TC.y, 0.2), (0, 0.35, 1))
T.delete_faces(bm, lambda c, n: (c - TC).y < -0.02 and abs(c.x) < lapel_w(c.z) - 1e-4)
T.delete_faces(bm, lambda c, n: c.z - 0.2 + 0.35 * (c.y - TC.y) < 0)   # tail-coat hem, lower at the back
body.add(bm, ["pelvis", "spine_01", "spine_02", "spine_03"], power=3.0, keep=3, name="coat")


# lapel rolls: a soft piping along each cut edge (hides the shell edge, reads as a lapel)
for sx in (-1, 1):
    pts = []
    for i in range(18):
        z = Z_TOP - 0.02 - (Z_TOP - 0.02 - 0.24) * i / 17
        x = sx * lapel_w(z)
        # march along -Y from inside until outside the coat shell
        best = None
        for j in range(200):
            y = TC.y - 0.02 - j * 0.004
            d = Vector((x, y, z)) - TC
            if d.length < 1e-6:
                continue
            r = coat_pos(d.normalized()) - TC
            if d.length >= r.length:
                best = TC + r
                break
        if best is not None:
            pts.append(best)
    if len(pts) > 2:
        bm = T.capsule_chain(pts, [0.017] * len(pts), "plum_lt", seg=5, cap_rings=1, samples_per_m=16)
        body.add(bm, ["spine_01", "spine_02", "spine_03"], power=3.0, keep=2, name="lapel")

# gold buttons down the waistcoat
for z in (0.43, 0.56, 0.69):
    q = torso_q(Vector((0, -math.sqrt(max(0, 1 - ((z - TC.z) / TCz) ** 2)), (z - TC.z) / TCz)).normalized())
    p = TC + q
    bm = T.se_blob(p + Vector((0, -0.006, 0)), 0.024, 0.014, 0.024, 2.0, "button", n=2)
    body.add(bm, "spine_02", name="button")

# the gold cravat: knot, two lobes, a cascade
cy = TC.y - 0.2
els = [("BALL", (0, cy - 0.02, 0.95), 0.06), ("ELLIPSOID", (0.075, cy + 0.0, 0.955), 0.05, (1.4, 0.8, 0.9)),
       ("ELLIPSOID", (-0.075, cy + 0.0, 0.955), 0.05, (1.4, 0.8, 0.9)), ("ELLIPSOID", (0, cy - 0.06, 0.87), 0.05, (0.9, 0.55, 1.4)),
       ("BALL", (0, cy - 0.075, 0.8), 0.04)]
bm = T.metaballs("crav", els, "cravat", resolution=0.016, decimate=0.28, smooth=3)
body.add(bm, "cravat", name="cravat")

# specs on a chain, dangling on the belly (specs_chest) ...
SPC = Vector((0.1, TC.y - 0.345, 0.73))
parts = []
for sx in (-1, 1):
    parts.append(T.torus(0.04, 0.0075, SPC + Vector((sx * 0.047, 0, 0)), "specs", seg=12, rseg=4, rot=(90, 0, 0)))
    parts.append(T.se_blob(SPC + Vector((sx * 0.047, 0.004, 0)), 0.036, 0.004, 0.036, 2.0, "lens", n=3))
parts.append(T.capsule_chain([SPC + Vector((-0.012, 0, 0.004)), SPC + Vector((0.012, 0, 0.004))], [0.006, 0.006], "specs", seg=6, cap_rings=1))
bm = T.merge(*parts)
T.rot_about(bm, SPC, (-18, 0, 12))
body.add(bm, "specs_chest", name="specs_chest")
chain = []
for sx in (-1, 1):
    a = Vector((sx * 0.14, TC.y - 0.14, 0.95))
    b = SPC + Vector((sx * 0.085, 0.01, 0.01))
    mid = (a + b) * 0.5 + Vector((0, -0.06, -0.03))
    chain.append(T.capsule_chain([a, mid, b], [0.005, 0.005, 0.005], "specs", seg=4, cap_rings=1, samples_per_m=30))
body.add(T.merge(*chain), "specs_chest", name="chain")
# ... and the same specs worn on the nose (specs_face; scale 0 unless suspicious / furious)
EY = HC.z + (0.5 - 0.442) * 0.52
parts = []
for sx in (-1, 1):
    ex = sx * (0.666 - 0.5) * 0.52
    parts.append(T.torus(0.058, 0.008, Vector((ex, HC.y - HBy - 0.02, EY)), "specs", seg=12, rseg=4, rot=(90, 0, 0)))
    parts.append(T.capsule_chain([Vector((sx * 0.145, HC.y - HBy + 0.0, EY + 0.005)), Vector((sx * 0.225, HC.y - 0.1, EY + 0.01))], [0.006, 0.006], "specs", seg=6, cap_rings=1))
parts.append(T.capsule_chain([Vector((-0.03, HC.y - HBy - 0.045, EY + 0.012)), Vector((0.03, HC.y - HBy - 0.045, EY + 0.012))], [0.007, 0.007], "specs", seg=6, cap_rings=1))
body.add(T.merge(*parts), "specs_face", name="specs_face")

# ---- arms, hands, legs, slippers -------------------------------------------------------------------------
for s, sx in (("l", 1), ("r", -1)):
    sh, el, wr = H("upperarm_" + s), H("lowerarm_" + s), H("hand_" + s)
    a0 = sh + (sh - wr).normalized() * 0.06
    bm = T.capsule_chain([a0, el, wr], [0.078, 0.07, 0.064], "plum", seg=9, cap_rings=2, samples_per_m=28)
    body.add(bm, ["upperarm_" + s, "lowerarm_" + s], power=4.0, keep=2, name="sleeve")
    ax = (wr - el).normalized()
    bm = T.capsule_chain([wr - ax * 0.035, wr + ax * 0.01], [0.07, 0.068], "cuff", seg=10, cap_rings=2, samples_per_m=30)
    body.add(bm, "lowerarm_" + s, name="cuff")
    hx = (H("middle_01_" + s) - wr).normalized()
    bm = T.se_blob(wr + hx * 0.055, 0.05, 0.055, 0.036, 2.2, "peach", n=4)
    body.add(bm, "hand_" + s, name="palm")
    for f in ("index", "middle", "ring", "pinky"):
        a, b = H(f + "_01_" + s), rig.tail(f + "_03_" + s)
        r = 0.018 if f != "pinky" else 0.015
        bm = T.capsule_chain([a - hx * 0.012, b], [r, r * 0.9], "peach", seg=5, cap_rings=2, samples_per_m=30)
        body.add(bm, [f + "_01_" + s, f + "_02_" + s, f + "_03_" + s], power=4.0, keep=2, name="finger")
    a, b = H("thumb_01_" + s), rig.tail("thumb_03_" + s)
    bm = T.capsule_chain([a + hx * 0.015, b], [0.02, 0.018], "peach", seg=6, cap_rings=2, samples_per_m=40)
    body.add(bm, ["thumb_01_" + s, "thumb_02_" + s, "thumb_03_" + s], power=4.0, keep=2, name="thumb")
    th, kn, an = H("thigh_" + s), H("calf_" + s), H("foot_" + s)
    bm = T.capsule_chain([th + Vector((0, 0, -0.01)), kn, an], [0.056, 0.06, 0.058], "trouser_b", seg=8, cap_rings=2, samples_per_m=35)
    body.add(bm, ["thigh_" + s, "calf_" + s], power=4.0, keep=2, name="leg")
    ft, bl = H("foot_" + s), H("ball_" + s)
    SC = Vector((ft.x, (ft.y + bl.y) * 0.5 - 0.035, 0.042))

    def slip_warp(d, q):
        if q.y < 0:
            q.z *= 1.0 + 0.12 * T.smoothstep(0, -0.1, q.y)
        return q
    bm = T.se_blob(SC, 0.07, 0.118, 0.048, 2.4, "slipper", n=5, warp=slip_warp)
    T.bisect(bm, (0, 0, 0.012), (0, 0, 1))
    T.recolor(bm, lambda c, n, cur: "sole" if c.z < 0.012 else None)
    bm2 = T.se_blob(SC + Vector((0, -0.055, 0.045)), 0.03, 0.012, 0.018, 2.5, "buckle", n=3)
    body.add(T.merge(bm, bm2), ["foot_" + s, "ball_" + s], power=4.0, keep=2, name="slipper")

# ---- tea things: cup on prop_r (pinkie up!), saucer on prop_l -----------------------------------------
PR = H("prop_r")
CS = 1.6   # toy-scaled tea things (read at phone size)
cup = T.capsule_chain([PR + Vector((0, 0, -0.035 * CS)), PR + Vector((0, 0, 0.03 * CS))], [0.034 * CS, 0.044 * CS], "cup", seg=10, cap_rings=2, samples_per_m=16)
T.bisect(cup, PR + Vector((0, 0, 0.004 * CS)), (0, 0, 1))
T.bisect(cup, PR + Vector((0, 0, 0.018 * CS)), (0, 0, 1))
T.recolor(cup, lambda c, n, cur: "cup_band" if PR.z + 0.004 * CS < c.z < PR.z + 0.018 * CS and abs(n.z) < 0.8 else None)
tea = T.se_blob(PR + Vector((0, 0, 0.037 * CS)), 0.038 * CS, 0.038 * CS, 0.006, 2.0, "tea", n=4)
handle = T.torus(0.018 * CS, 0.006 * CS, PR + Vector((0.048 * CS, 0, 0.0)), "cup", seg=10, rseg=5, rot=(90, 0, 0))
body.add(T.merge(cup, tea, handle), "prop_r", name="cup")
PL = H("prop_l")
saucer = T.se_blob(PL, 0.075 * CS, 0.075 * CS, 0.012, 2.0, "cup", n=5)
T.bisect(saucer, PL, (0, 0, 1))
T.recolor(saucer, lambda c, n, cur: "cup_band" if c.z < PL.z else None)
body.add(saucer, "prop_l", name="saucer")

# sneeze spray: a fan of white puffs + droplets shooting out of the nose (fx_choo; scale 0 unless CHOO)
FX = H("fx_choo")
blobs = []
for i, (ang, dist, r) in enumerate([(-34, 0.16, 0.06), (0, 0.14, 0.07), (34, 0.16, 0.06), (-20, 0.3, 0.085), (18, 0.31, 0.09),
                                    (-44, 0.36, 0.07), (46, 0.35, 0.07), (0, 0.46, 0.1), (-26, 0.52, 0.075), (28, 0.52, 0.08)]):
    d = Vector((math.sin(math.radians(ang)), -math.cos(math.radians(ang)), -0.12 + 0.05 * (i % 3))).normalized()
    blobs.append(T.se_blob(FX + d * dist, r, r * 0.9, r * 0.85, 2.0, "white", n=3))
drops = [T.se_blob(FX + Vector((random.uniform(-0.3, 0.3), -random.uniform(0.3, 0.62), random.uniform(-0.16, 0.14))), 0.02, 0.02, 0.02, 2.0, "lens", n=1) for _ in range(12)]
body.add(T.merge(*blobs, *drops), "fx_choo", name="fx_choo")

PAL = os.path.join(opt.get("build", "/tmp"), "toy_palette.png")
mat = T.toy_material("toy_bellows", PAL, opt.get("face"))
bodyob = body.finish(mat)
tris = sum(len(p.vertices) - 2 for p in bodyob.data.polygons)
print("BELLOWS tris", tris, "verts", len(bodyob.data.vertices), "bones", len(arm.data.bones))

EXTRA = ["bouffant", "sideburn_l", "sideburn_r", "nose", "specs_face", "specs_chest", "cravat", "prop_r", "prop_l", "fx_choo"]
anim = T.Animator(rig, C.MAIN + C.FINGERS + EXTRA)
if "noclips" not in opt:
    import clips_bellows
    clips_bellows.build(anim, rig)
T.key_library_extras(arm, ["prop_r", "prop_l", "specs_face", "fx_choo"])
meta = {"character": "bellows", "tris": tris, "bones": len(arm.data.bones), "hip_ratio": hip_ratio,
        "faces": anim.faces, "clips": anim.meta, "actions": sorted(a.name for a in bpy.data.actions)}
if "meta" in opt:
    json.dump(meta, open(opt["meta"], "w"), indent=1)
if "preview" in opt:
    shots = [(None, 1, v) for v in ("front", "side", "34", "back")]
    for a in opt.get("pv", "").split(","):
        if a:
            nm, fr, vw = a.split(":")
            shots.append((nm, int(fr), vw))
    C.preview(arm, opt["preview"], shots, size=(420, 560), ortho=2.4, center_z=0.9, tag="bellows_")
if "out" in opt:
    T.export_glb(arm, bodyob, opt["out"])
    print("BELLOWS_OK", opt["out"])
