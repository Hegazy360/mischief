"""build -- Hush for R3D: look B's body dimensions built in look A's Toy Box vinyl construction.

    tools/art3d/blender.sh --python tools/art3d/hush/build.py -- --out game/art3d/chars/hush \
        [--head-scale 1.0] [--name hush] [--palette <png>] [--face <png>] [--meta <json>] [--poses <glb>] [--preview <dir>]

Writes <out>/<name>.glb (Armature + one skinned mesh `hush_body`, one material: palette on UV0, the face atlas on
FaceUV = TEXCOORD_1; vertex colours COLOR_0 = the §7.6 masks) and <meta> (tris, bones, heights, sockets, face frame)
for write_rig.py. `--poses <glb>` also writes a scratch glb with static board poses as actions (never shipped).

Forms (brief §4.2): superellipsoid / capsule vinyl blobs (toy_lib), masked shells for the bob, bisect-cut colour borders
for the stripes, soles and cuffs; B's dimensions: 1.60 m to the top of the beret, head chin 1.19 -> crown 1.55, B's neck,
narrow torso with a loose flattened Breton top, long thin arms (0.199 + 0.206 m) ending in 1.65x white 4-digit gloves
with rolled cuffs, long thin shaped legs (hip 0.787) in straight navy trousers widening a little to the hem, flat shoes.
"""
import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hush_dims as D      # noqa: E402
import palette as TP       # noqa: E402
import skeleton as SK      # noqa: E402
import toy_lib as T        # noqa: E402


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {}
    i = 0
    while i < len(argv):
        k = argv[i].lstrip("-")
        if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
            opt[k] = argv[i + 1]
            i += 2
        else:
            opt[k] = "1"
            i += 1
    return opt


opt = args()
HS = float(opt.get("head-scale", "1.0"))
NAME = opt.get("name", "hush")
OUT = opt.get("out", os.path.join(D.REPO, "game", "art3d", "chars", "hush"))
BUILD = opt.get("build", os.path.join(D.REPO, "build", "art3d", "hush"))
os.makedirs(OUT, exist_ok=True)
os.makedirs(BUILD, exist_ok=True)
PAL = opt.get("palette", os.path.join(OUT, "palette_hush.png"))
FACE = opt.get("face", os.path.join(OUT, "face_hush.png"))

T.reset()
arm, UAL_REST = SK.build_armature(HS)
rig = T.Rig(arm)
H = rig.head
TL = rig.tail
body = T.Body(rig, "hush_body")

PIVOT = H("Head")                         # head-scale pivot (R6: B's neck is kept)


def hs(p):
    """A head-space point (built at scale 1) -> its place at the head scale."""
    p = Vector(p)
    return PIVOT + (p - PIVOT) * HS


HC = Vector(D.HEAD_C)
HA, HBy, HCz, HP = D.HEAD_A, D.HEAD_B, D.HEAD_CZ, D.HEAD_P


# =====================================================================================================
# HEAD (face paint) + face card
# =====================================================================================================
def head_q(d):
    r = T.se_radius(d, HA, HBy, HCz, HP)
    q = d * r
    lo = T.smoothstep(-0.02, -0.18, q.z)          # jaw: narrower and rounder toward B's small chin
    q.x *= 1.0 - 0.24 * lo * lo - 0.04 * lo
    q.y *= 1.0 - 0.10 * lo * lo
    cheek = T.smoothstep(0.02, -0.07, q.z) * (1.0 - T.smoothstep(-0.07, -0.15, q.z))
    q.x *= 1.0 + 0.035 * cheek                    # full cheeks
    q.z *= 1.0 - 0.03 * T.smoothstep(0.1, 0.17, q.z)
    if q.y < 0.0:                                 # a flatter face front (room for the face card)
        q.y *= 1.0 - 0.10 * T.smoothstep(0.25, 0.9, abs(d.y)) * (1.0 - T.smoothstep(0.08, 0.16, abs(q.x)))
    return q


FRINGE_Z = 0.094        # fringe line above the head centre (brows sit just below it)
FACE_SIDE = 0.138       # half width of the face opening between the bob's sides (R6 step 1: as wide as B's head allows)


def face_amount(q):
    front = T.smoothstep(-0.01, -0.10, q.y)
    xn = q.x / HA
    fringe_z = FRINGE_Z - 0.028 * xn * xn - 0.010 * xn     # swept fringe, a touch higher on her right
    below = T.smoothstep(fringe_z + 0.012, fringe_z - 0.012, q.z)
    sides = T.smoothstep(FACE_SIDE + 0.012, FACE_SIDE - 0.018, abs(q.x))
    return front * below * sides


bm = T.blob(lambda d: hs(HC + head_q(d)), "paint", n=12)
T.delete_faces(bm, lambda c, n: face_amount((PIVOT + (c - PIVOT) / HS) - HC) < 0.002
               and ((PIVOT + (c - PIVOT) / HS) - HC).z > -0.11)
FACE_UV = {"center": (D.FACE_C[0], hs((0, 0, D.FACE_C[1])).z), "w": D.FACE_W * HS, "h": D.FACE_W * HS,
           "front": -0.25, "ymax": hs(HC).y - 0.03}
body.add(bm, "Head", face_uv=FACE_UV, name="head")

# button nose (tiny, a touch pink)
NOSE_C = HC + Vector((0.0, -HBy * 0.99, -0.034))
bm = T.se_blob(hs(NOSE_C), 0.016 * HS, 0.011 * HS, 0.013 * HS, 2.0, "nose_h", n=3)
body.add(bm, "Head", name="nose", outline=0.0)


# =====================================================================================================
# HAIR: the bob as a masked shell (head surface pushed out where there is hair, the face left open)
# =====================================================================================================
def hair_pos(d):
    q = head_q(d)
    face = face_amount(q)
    s = T.lerp(1.085 - 0.075 * T.smoothstep(0.07, 0.17, q.z), 0.93, face)   # the crown tucks under the beret
    p = q * s
    hang = T.smoothstep(0.0, -0.14, q.z) * (1.0 - face)
    p.x *= 1.0 + 0.10 * hang                     # the bob swings out a little at the jaw
    p.y *= 1.0 + 0.08 * hang * (1.0 if p.y > 0 else 0.25)
    return HC + p


bm = T.blob(lambda d: hs(hair_pos(d)), "hair", n=11)
CUT = -0.128                                     # bob cut at the jaw line, a little longer toward the face
T.bisect(bm, hs(HC + Vector((0, 0, CUT))), (0, 0.10, 1))
T.delete_faces(bm, lambda c, n: (0.10 * ((PIVOT + (c - PIVOT) / HS) - HC).y + ((PIVOT + (c - PIVOT) / HS) - HC).z - CUT) < 0)
# drop the part of the shell that sits inside the head over the face (hidden anyway: saves triangles)
T.delete_faces(bm, lambda c, n: face_amount(head_q(((PIVOT + (c - PIVOT) / HS) - HC).normalized())) > 0.995)


def hair_weights(co):
    q = (PIVOT + (Vector(co) - PIVOT) / HS) - HC
    tip = T.smoothstep(-0.03, -0.12, q.z) * T.smoothstep(0.06, 0.12, abs(q.x))
    w = {"Head": 1.0 - 0.8 * tip}
    w["hair_l" if q.x > 0 else "hair_r"] = 0.8 * tip
    return w


body.add(bm, None, name="hair", weight_fn=hair_weights)


# =====================================================================================================
# BERET (tilted cherry red, droopy rim, a stalk) -- its highest point exactly at 1.60 m (x head scale)
# =====================================================================================================
BC = HC + Vector(D.BERET_OFF)


def beret_warp(d, q):
    rr = (q.x * q.x + q.y * q.y) / (D.BERET_R[0] * D.BERET_R[0])
    q.z -= 0.044 * rr            # droop at the rim (wraps the bob)
    q.z += 0.012 * (1 - rr)
    return q


bm = T.se_blob(BC, D.BERET_R[0], D.BERET_R[1], D.BERET_R[2], 2.4, "beret", n=7, warp=beret_warp)
T.rot_about(bm, BC, D.BERET_TILT)
top_z = max(v.co.z for v in bm.verts)
dz_fit = D.HEIGHT_M - top_z                      # the fit: highest beret vertex at 1.60 (head scale 1)
T.transform(bm, __import__("mathutils").Matrix.Translation((0, 0, dz_fit)))
stalk_base = Vector(SK.extra_positions()["beret_stalk"][0])
bm2 = T.capsule_chain([stalk_base + Vector((0, 0, -0.012)), stalk_base + Vector((0.006, 0, 0.022))], [0.010, 0.008],
                      "beret_dk", seg=6, cap_rings=2, samples_per_m=60)
for b_ in (bm, bm2):
    for v in b_.verts:
        v.co = hs(v.co)
body.add(bm, "beret", name="beret")
body.add(bm2, "beret_stalk", name="beret_stalk", outline=0.6)

# =====================================================================================================
# NECK (B's: neck_01 1.108 -> Head 1.228; the collar may cover it, never shorten it)
# =====================================================================================================
nk0 = H("neck_01") + Vector((0, -0.004, -0.02))
nk1 = hs(H("Head") + Vector((0, -0.010, 0.05)))
bm = T.capsule_chain([nk0, nk1], [D.NECK_R, D.NECK_R * 0.96 * HS], "paint", seg=9, cap_rings=2, samples_per_m=40)
body.add(bm, ["spine_03", "neck_01", "Head"], power=4.0, keep=2, name="neck")

# =====================================================================================================
# TORSO: a loose Breton top (flattened chest) with >= 5 navy stripes, a navy boat collar; red braces with clips
# =====================================================================================================
TZ0, TZ1 = D.TORSO_Z0, D.TORSO_Z1
TC = Vector((0.0, D.TORSO_C_Y, (TZ0 + TZ1) / 2))
TA, TB, TCz, TPw = D.TORSO_A, D.TORSO_B, (TZ1 - TZ0) / 2, 2.9


def torso_scale(zn):
    """half-width / half-depth multipliers along the torso (zn -1 hem .. +1 shoulders)."""
    return 1.0 + 0.10 * zn - 0.10 * zn * zn + 0.04 * T.smoothstep(-0.6, -1.0, zn), 1.0 + 0.02 * zn


def torso_warp(d, q):
    zn = q.z / TCz
    kx, ky = torso_scale(zn)
    q.x *= kx
    q.y *= ky
    return q


bm = T.se_blob(TC, TA, TB, TCz, TPw, "stripe", n=7, warp=torso_warp)
# 10 cuts -> 5 navy bands (0.026 m) between wider cream bands (0.048 m) + the navy collar: cream-heavy stripes keep her
# light share >= 20 % under the 4.8 px outline (REDESIGN 3.7 value rule; value_check.png)
NAVY_W, CREAM_W = 0.026, 0.048
STRIPES = [TZ0 + 0.034 + (NAVY_W + CREAM_W) * (i // 2) + NAVY_W * (i % 2) for i in range(10)]
for z in STRIPES:
    T.bisect(bm, (0, 0, z), (0, 0, 1))


def stripe_col(z):
    k = sum(1 for s_ in STRIPES if z > s_)
    return "navy" if (k % 2 == 1 or z > STRIPES[-1]) else "stripe"


T.recolor(bm, lambda c, n, cur: stripe_col(c.z))
body.add(bm, ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"], power=3.0, keep=3, name="torso")


def torso_surface(x, z, side):
    zn = (z - TC.z) / TCz
    kx, ky = torso_scale(zn)
    a, b = TA * kx, TB * ky
    t = max(1.0 - abs(x / a) ** TPw - abs(zn) ** TPw, 1e-4)
    y = side * b * t ** (1.0 / TPw)
    p = Vector((x, TC.y + y, z))
    g = Vector((TPw * abs(x / a) ** (TPw - 1) / a * math.copysign(1, x),
                TPw * abs(y / b) ** (TPw - 1) / b * side,
                TPw * abs(zn) ** (TPw - 1) / TCz * math.copysign(1, zn)))
    return p, g.normalized()


BRACE_X0, BRACE_X1 = 0.060, 0.070


def brace_weights(sx):
    bone = "brace_l" if sx > 0 else "brace_r"

    def fn(co):
        z = Vector(co).z
        mid = T.smoothstep(0.84, 0.95, z) * (1.0 - T.smoothstep(1.02, 1.12, z))
        w = {"spine_02": 0.55 * (1 - mid) + 0.3, "spine_03": 0.35 * T.smoothstep(0.95, 1.12, z) + 0.05,
             "spine_01": 0.25 * (1 - T.smoothstep(0.82, 0.92, z)), bone: 0.45 * mid}
        return w
    return fn


for sx in (-1, 1):
    for side in (-1, 1):
        pts, nrm = [], []
        for i in range(12):
            z = TZ0 + 0.02 + (TZ1 - 0.012 - TZ0 - 0.02) * i / 11
            x = sx * (BRACE_X0 + (BRACE_X1 - BRACE_X0) * (TZ1 - z) / (TZ1 - TZ0))
            p, n = torso_surface(x, z, side)
            pts.append(p + n * 0.002)
            nrm.append(n)
        bm = T.ribbon(pts, nrm, 0.030, 0.008, "braces")
        body.add(bm, None, name="brace", weight_fn=brace_weights(sx))
        if side == -1:   # the clip at the front bottom
            p, n = torso_surface(sx * (BRACE_X1 - 0.002), TZ0 + 0.035, -1)
            bm = T.se_blob(p + n * 0.010, 0.019, 0.008, 0.013, 2.6, "clip", n=2)
            body.add(bm, ["spine_01", "pelvis"], power=3.0, keep=2, name="clip", outline=0.6)

# =====================================================================================================
# HIPS + LEGS: straight navy trousers widening a little to the hem; shaped (calf, knee, ankle taper); flat shoes
# =====================================================================================================
PCn = Vector((0.0, D.TORSO_C_Y + 0.004, 0.745))
bm = T.se_blob(PCn, 0.100, 0.060, 0.048, 2.3, "trouser", n=5)
body.add(bm, ["pelvis", "thigh_l", "thigh_r"], power=4.0, keep=2, name="hips")

R = D.LEG_R
for s, sx in (("l", 1), ("r", -1)):
    th, kn, an = H("thigh_" + s), H("calf_" + s), H("foot_" + s)
    pts = [th + Vector((0, 0, 0.015)), th.lerp(kn, 0.45), kn + Vector((0, -0.004, 0)), kn.lerp(an, 0.3),
           kn.lerp(an, 0.72), an + Vector((0, -0.006, 0.030))]
    rad = [R["hip"], R["thigh"], R["knee"], R["calf"], R["ankle"], R["hem"]]
    bm = T.capsule_chain(pts, rad, "trouser", seg=9, cap_rings=2, samples_per_m=26)

    def leg_w(co, s=s, th=th, kn=kn, an=an):
        z = Vector(co).z
        k = T.smoothstep(kn.z + 0.06, kn.z - 0.06, z)          # 0 thigh .. 1 calf
        return {"thigh_" + s: 1.0 - k, "calf_" + s: k}
    body.add(bm, None, name="leg", weight_fn=leg_w)

    # the flat shoe: a rounded toy shoe, sole cut with a bisect plane
    ft, bl = H("foot_" + s), H("ball_" + s)
    SCn = Vector((ft.x, (ft.y + bl.y) * 0.5 - 0.040, 0.040))

    def shoe_warp(d, q):
        if q.y < 0 and q.z > 0:
            q.z *= 1.0 + 0.16 * T.smoothstep(0, -0.08, q.y)    # a round toe cap
            q.x *= 1.0 + 0.06 * T.smoothstep(0, -0.1, q.y)
        return q
    bm = T.se_blob(SCn, 0.054, 0.132, 0.040, 2.5, "shoe", n=5, warp=shoe_warp)
    T.bisect(bm, (0, 0, 0.013), (0, 0, 1))
    T.recolor(bm, lambda c, n, cur: "sole" if c.z < 0.013 else None)

    def shoe_w(co, s=s, bl=bl):
        k = T.smoothstep(bl.y + 0.03, bl.y - 0.03, Vector(co).y)
        return {"foot_" + s: 1.0 - k, "ball_" + s: k}
    body.add(bm, None, name="shoe", weight_fn=shoe_w)

# =====================================================================================================
# ARMS: striped sleeves; the huge white 4-digit gloves (1.65 x hand), rolled cuffs
# =====================================================================================================
SR = D.SLEEVE_R
for s, sx in (("l", 1), ("r", -1)):
    sh, el, wr = H("upperarm_" + s), H("lowerarm_" + s), H("hand_" + s)
    a0 = sh + (sh - el).normalized() * 0.035 + Vector((0, 0, 0.004))
    bm = T.capsule_chain([a0, el, wr + (wr - el).normalized() * 0.012], [SR[0], SR[1], SR[2]], "stripe", seg=8,
                         cap_rings=2, samples_per_m=30)
    ax = (wr - sh).normalized()
    L = (wr - sh).length
    SN, SC_ = 0.024, 0.044                                       # navy / cream band widths along the sleeve
    cuts = [0.018 + (SN + SC_) * (i // 2) + SN * (i % 2) for i in range(int(2 * L / (SN + SC_)) + 1)]
    for c_ in cuts:
        T.bisect(bm, sh + ax * c_, ax)

    def sleeve_col(c, n, cur, sh=sh, ax=ax, cuts=cuts):
        t = (c - sh).dot(ax)
        k = sum(1 for c_ in cuts if t > c_)
        return "navy" if k % 2 == 0 else "stripe"
    T.recolor(bm, sleeve_col)
    body.add(bm, ["clavicle_" + s, "upperarm_" + s, "lowerarm_" + s], power=4.0, keep=2, name="sleeve")

    hx = (H("middle_01_" + s) - wr).normalized()               # along the hand
    # rolled cuff: a flared ring, the roll in the shade white
    cuff = T.capsule_chain([wr - hx * 0.022, wr + hx * 0.030], [0.036, 0.052], "glove", seg=8, cap_rings=2, samples_per_m=40)
    T.bisect(cuff, wr + hx * 0.012, hx)
    T.recolor(cuff, lambda c, n, cur, wr=wr, hx=hx: "glove_sh" if (c - wr).dot(hx) > 0.012 else None)
    body.add(cuff, ["lowerarm_" + s, "hand_" + s], power=4.0, keep=2, name="cuff")
    # puffy palm from the wrist to the knuckles
    PCg = wr + hx * 0.078 + Vector((0, 0.022, -0.004))
    bm = T.se_blob(PCg, 0.070, 0.058, 0.034, 2.3, "glove", n=4)
    rot = math.degrees(math.atan2(hx.y, hx.x))
    T.rot_about(bm, PCg, (0, 0, rot))
    body.add(bm, "hand_" + s, name="palm")
    # three fat fingers + a thumb along the UAL finger bones (01-02 weighted, never _03 / pinky)
    for f, rad in (("index", 0.0205), ("middle", 0.021), ("ring", 0.0195)):
        a, b = H(f + "_01_" + s), H(f + "_04_leaf_" + s)
        bm = T.capsule_chain([a - hx * 0.012, b - hx * 0.008], [rad, rad * 0.92], "glove", seg=6, cap_rings=2, samples_per_m=34)
        body.add(bm, [f + "_01_" + s, f + "_02_" + s], power=4.0, keep=2, name="finger",
                 seg_override={f + "_02_" + s: (H(f + "_02_" + s), b)})
    a, b = H("thumb_01_" + s), H("thumb_04_leaf_" + s)
    bm = T.capsule_chain([a + hx * 0.012, b], [0.021, 0.019], "glove", seg=6, cap_rings=2, samples_per_m=34)
    body.add(bm, ["thumb_01_" + s, "thumb_02_" + s], power=4.0, keep=2, name="thumb",
             seg_override={"thumb_02_" + s: (H("thumb_02_" + s), b)})

# =====================================================================================================
# CLARENCE the rubber chicken, riding in her right brace (yellow body, red comb, open beak; squashable)
# =====================================================================================================
EX = SK.extra_positions()
cb = Vector(EX["clarence_body"][0])
bm = T.se_blob(cb, 0.036, 0.029, 0.050, 2.1, "chicken", n=4)
body.add(bm, "clarence_body", name="clarence_body", outline=0.8)
head_c = Vector(EX["clarence_comb"][0]) + Vector((0.0, 0.004, -0.032))
neck_a = cb + Vector((0.002, -0.004, 0.034))
bm = T.capsule_chain([neck_a, head_c], [0.017, 0.019], "chicken", seg=6, cap_rings=2, samples_per_m=40)
bm = T.merge(bm, T.se_blob(head_c, 0.027, 0.026, 0.026, 2.0, "chicken", n=3))
eyes = [T.se_blob(head_c + Vector((dx, -0.022, 0.007)), 0.006, 0.004, 0.007, 2.0, "black", n=2) for dx in (-0.012, 0.012)]
beak_u = T.se_blob(head_c + Vector((0, -0.034, -0.004)), 0.013, 0.018, 0.007, 2.0, "beak", n=2)
beak_l = T.se_blob(head_c + Vector((0, -0.029, -0.018)), 0.011, 0.014, 0.006, 2.0, "beak", n=2)
T.rot_about(beak_l, head_c + Vector((0, -0.020, -0.013)), (24, 0, 0))
body.add(T.merge(bm, *eyes, beak_u, beak_l), "prop_clarence", name="clarence_head", outline=0.8)
comb_c = Vector(EX["clarence_comb"][0])
comb = T.merge(*[T.se_blob(comb_c + Vector((0, 0.011 * k, 0.004 - 0.004 * abs(k))), 0.007, 0.010, 0.013, 2.0, "comb", n=1)
                 for k in (-1, 0, 1)])
body.add(comb, "clarence_comb", name="clarence_comb", outline=0.7)

# =====================================================================================================
# THE PEPPER POT (ACHOO-RIA!): oversized x1.5, 0.35 m, red cap, on prop_r (hidden by default via rig3d.json)
# =====================================================================================================
gp = Vector(EX["prop_r"][0])
ax = Vector((0, -1, 0))            # prop_r's axis: out of the fist on the thumb side = the cap end
p0, p1 = gp - ax * 0.135, gp + ax * 0.215
bm = T.capsule_chain([p0, gp - ax * 0.02, p1 - ax * 0.04, p1], [0.050, 0.046, 0.052, 0.040], "pot", seg=9,
                     cap_rings=2, samples_per_m=16)
T.bisect(bm, gp + ax * 0.150, ax)
T.bisect(bm, p0 + ax * 0.045, ax)
T.recolor(bm, lambda c, n, cur: "pot_cap" if (c - gp).dot(ax) > 0.150 else ("pot_band" if (c - gp).dot(ax) < -0.090 else None))
holes = [T.se_blob(p1 + ax * 0.034 + Vector((dx, 0, dz)), 0.007, 0.004, 0.007, 2.0, "black", n=2)
         for dx, dz in ((-0.013, 0.0), (0.013, 0.0), (0.0, 0.013), (0.0, -0.013))]
body.add(T.merge(bm, *holes), "prop_r", name="pepper_pot", outline=0.8)

# =====================================================================================================
mat = T.toy_material("hush_toy", PAL, FACE if os.path.exists(FACE) else None)
bodyob = body.finish(mat)
bodyob.data.color_attributes.active_color = bodyob.data.color_attributes["Col"]
tris = sum(len(p.vertices) - 2 for p in bodyob.data.polygons)
deform_used = sorted({g.name for g in bodyob.vertex_groups if any(
    g.index in [ge.group for ge in v.groups if ge.weight > 1e-4] for v in bodyob.data.vertices)})
zs = [v.co.z for v in bodyob.data.vertices]
stalk_g = bodyob.vertex_groups["beret_stalk"].index
zs_ns = [v.co.z for v in bodyob.data.vertices if not any(ge.group == stalk_g and ge.weight > 0.5 for ge in v.groups)]
print("HUSH tris", tris, "verts", len(bodyob.data.vertices), "bones", len(arm.data.bones), "weighted", len(deform_used),
      "top", round(max(zs), 4), "top_no_stalk", round(max(zs_ns), 4), "min", round(min(zs), 4))

# un-weighted bones must not be flagged deform
bpy.context.view_layer.objects.active = arm
for b in arm.data.bones:
    b.use_deform = b.name in deform_used
skel = SK.contract(arm, UAL_REST, HS)


def sockets() -> dict:
    """Sockets in their bone's local rest frame (Blender bone axes = the glTF / Godot bone axes: Y along the bone) +
    the model-space point (Godot axes) the cast test checks them against."""
    B = arm.data.bones
    face_front_y = min(v.co.y for v in bodyob.data.vertices if abs(v.co.x) < 0.01 and abs(v.co.z - FACE_UV["center"][1]) < 0.02)
    table = {
        "grip_r": ("hand_r", Vector(EX["prop_r"][0])),
        "grip_l": ("hand_l", Vector(EX["prop_l"][0])),
        "head_top": ("Head", Vector((0.0, hs(HC).y, max(zs_ns)))),
        "brace_r": ("spine_02", Vector(EX["prop_clarence"][0])),
        "carry_1": ("spine_02", Vector(EX["carry_1"][0])),
        "carry_2": ("spine_02", Vector(EX["carry_2"][0])),
        "feet": ("root", Vector((0.0, 0.0, 0.0))),
        "face": ("Head", Vector((0.0, face_front_y, FACE_UV["center"][1]))),
    }
    out = {}
    for name, (bone, p) in table.items():
        loc = B[bone].matrix_local.inverted() @ p
        out[name] = {"bone": bone, "pos": [round(loc.x, 5), round(loc.y, 5), round(loc.z, 5)], "rot_deg": [0, 0, 0],
                     "model_pos": [round(p.x, 5), round(p.z, 5), round(-p.y, 5)]}
    return out


meta = {"character": "hush", "name": NAME, "head_scale": HS, "tris": tris, "verts": len(bodyob.data.vertices),
        "sockets": sockets(),
        "bones": len(arm.data.bones), "deform_bones": len(deform_used), "deform": deform_used,
        "height_m": round(max(zs_ns), 4), "height_with_stalk_m": round(max(zs), 4), "min_z": round(min(zs), 4),
        "face_uv": {"center": list(FACE_UV["center"]), "w": FACE_UV["w"], "h": FACE_UV["h"]},
        "head_center": list(hs(HC)), "grip_r": list(EX["prop_r"][0]), "grip_l": list(EX["prop_l"][0]),
        "beret_fit_dz": dz_fit, "tris_by_part": getattr(body, "tri_log", {})}
if "meta" in opt:
    json.dump(meta, open(opt["meta"], "w"), indent=1)
if "skeleton" in opt:
    SK.write_json(skel, opt["skeleton"])


def export(path, actions=False):
    for o in list(bpy.data.objects):
        if o not in (arm, bodyob):
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
    bodyob.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
              export_animations=actions, export_skins=True, export_materials="EXPORT", export_image_format="AUTO",
              export_animation_mode="ACTIONS", export_optimize_animation_size=False, export_def_bones=False,
              export_frame_range=False, export_texcoords=True, export_normals=True, export_vertex_color="ACTIVE",
              export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True,
              export_tangents=False, export_morph=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = {k: v for k, v in kw.items() if k in props or k == "filepath"}
    bpy.ops.export_scene.gltf(**kw)


if "poses" in opt:
    import board_poses
    board_poses.build(arm, rig)
    export(opt["poses"], actions=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
if "noexport" not in opt:
    path = os.path.join(OUT, NAME + ".glb")
    export(path)
    print("HUSH_OK", path)
