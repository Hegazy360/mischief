"""Saturday Cartoon character builder (Hush / Bellows) — geometry + rig + face bones + regions.

blender -b --python build_char.py -- --who hush|bellows --out <dir> [--preview 1]
Writes <dir>/<who>_geo.blend (armature 'Armature' + one skinned mesh with a per-face 'region' attribute,
the UAL clips as actions). paint.py then UV-maps, bakes and paints it; build_anim.py adds the clips.
"""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clib, heads, parts
from clib import *

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {argv[i].lstrip("-"): argv[i + 1] for i in range(0, len(argv) - 1, 2)}
WHO = opt.get("who", "hush")
OUT = opt.get("out", ".")
os.makedirs(OUT, exist_ok=True)

KEEP1 = ["Idle_Loop", "Walk_Loop", "Walk_Formal_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Crouch_Idle_Loop",
         "Crouch_Fwd_Loop", "Interact", "PickUp_Table", "Sitting_Enter", "Sitting_Idle_Loop", "Sitting_Exit",
         "Hit_Head", "Idle_Talking_Loop", "Jump_Start", "Jump_Loop", "Jump_Land", "Roll", "Dance_Loop", "Push_Loop",
         "Fixing_Kneeling"]
KEEP2 = ["Idle_FoldArms_Loop", "Idle_No_Loop", "Yes", "Chest_Open", "Consume", "Walk_Carry_Loop", "OverhandThrow",
         "Hit_Knockback", "LayToIdle", "Idle_TalkingPhone_Loop"]

# region ids (colour classes; paint.py maps them to colours / patterns)
R = dict(skin=1, facepaint=2, eyewhite=3, hair=4, hat=5, brow=6, shirt=7, trousers=8, shoes=9, glove=10,
         collar=11, chick=12, chick_red=13, chick_beak=14, lid=15, jacket=16, lapel=17, shirtw=18, cravat=19,
         gold=20, spats=21, specs=22, cuffw=23, hem=24, lowlid=25, sock=26)

reset()
bpy.context.scene.render.fps = 30
arm = load_rig(KEEP1, KEEP2)
names = [b.name for b in arm.data.bones]
body, joints = load_base("female" if WHO == "hush" else "male")
fit_rig(arm, joints)
bind(body, arm)
body.data.update()

# ---- 1. cut the base: head + neck, hands, feet go (replaced by cartoon parts) ---------------------
W = weights(body, names)
dom = np.array([names[i] for i in W.argmax(1)])
HANDS = {n for n in names if any(n.startswith(f) for f in ("hand_", "index", "middle", "ring", "pinky", "thumb"))}
cut = np.isin(dom, ["Head", "neck_01"]) | np.isin(dom, list(HANDS)) | np.isin(dom, ["foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"])
if WHO == "bellows":   # the torso is replaced by a clay barrel; keep arms from the upper arm, legs from the thigh
    cut |= np.isin(dom, ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"])
delete_verts(body, cut)
print("BASE kept verts", len(body.data.vertices), "tris", tris(body))

# ---- 2. proportions --------------------------------------------------------------------------
def sym(d):
    out = {}
    for k, v in d.items():
        if k.endswith("_*"):
            out[k[:-2] + "_l"] = v
            out[k[:-2] + "_r"] = v
        else:
            out[k] = v
    return out

if WHO == "hush":
    SC = sym({"pelvis": (0.92, 0.8, 0.92), "spine_01": (0.86, 0.74, 0.86), "spine_02": (0.86, 0.74, 0.86),
              "spine_03": (0.86, 0.74, 0.86), "neck_01": (0.9, 0.6, 0.9), "clavicle_*": (1.0, 0.8, 1.0),
              "upperarm_*": (0.66, 0.86, 0.66), "lowerarm_*": (0.62, 0.86, 0.62), "hand_*": (1.65, 1.65, 1.65),
              "thigh_*": (0.66, 0.84, 0.66), "calf_*": (0.6, 0.84, 0.6), "foot_*": (1.0, 1.0, 1.0)})
else:
    SC = sym({"thigh_*": (1.35, 0.44, 1.35), "calf_*": (1.3, 0.44, 1.3), "foot_*": (0.9, 0.9, 0.9),
              "upperarm_*": (1.4, 0.74, 1.4), "lowerarm_*": (1.35, 0.8, 1.35),
              "hand_*": (1.2, 1.2, 1.2), "spine_01": (1, 1.25, 1), "spine_02": (1, 1.25, 1), "spine_03": (1, 1.25, 1),
              "neck_01": (1, 0.5, 1), "pelvis": (1.4, 1.0, 1.4)})
OFF = {}
if WHO == "bellows":
    OFF = {"upperarm_l": (0.05, -0.06, -0.08), "upperarm_r": (-0.05, -0.06, -0.08)}
reshape(arm, [body], SC, OFF)
if WHO == "bellows":   # the arm mesh starts at the shoulder joint, inside the barrel
    Pb = coords(body)
    ux = bone_head(arm, "upperarm_l").x
    delete_verts(body, (np.abs(Pb[:, 0]) < ux - 0.005) & (Pb[:, 2] > bone_head(arm, "thigh_l").z + 0.2))
ANKLE_Z = 0.085 if WHO == "hush" else 0.08
dz = ANKLE_Z - bone_head(arm, "foot_l").z
reshape(arm, [body], offset={"pelvis": (0, 0, dz)})
bpy.context.view_layer.update()
J = {n: bone_head(arm, n) for n in names}
print("JOINTS", {n: tuple(round(c, 3) for c in J[n]) for n in ("pelvis", "spine_03", "neck_01", "Head", "upperarm_l", "hand_l", "thigh_l", "calf_l", "foot_l")})

# ---- 3. body sculpt --------------------------------------------------------------------------
nb = neighbours(body)
bnd = set()
for c, r, comp in parts.boundary_loops(body):
    bnd.update(comp)
free = np.ones(len(body.data.vertices))
free[list(bnd)] = 0.0
P = coords(body)
Wb = weights(body, names)
def gw(*bones):
    return Wb[:, [names.index(b) for b in bones]].sum(1)

if WHO == "hush":
    # flatten the chest (a loose Breton top), slim the hips a touch
    zc0, zc1 = J["spine_02"].z - 0.02, J["spine_03"].z + 0.12
    band = smoothstep(zc0, zc0 + 0.05, P[:, 2]) * (1 - smoothstep(zc1 - 0.05, zc1, P[:, 2]))
    front = smoothstep(0.0, 0.06, -(P[:, 1] - J["spine_03"].y))
    k = band * front * (np.abs(P[:, 0]) < 0.16)
    yc = J["spine_03"].y - 0.03
    P[:, 1] = P[:, 1] + (yc - P[:, 1]) * 0.55 * k * (P[:, 1] < yc)
    set_coords(body, P)
    smooth(body, 0.6, 14, mask=free * np.clip(0.25 + k, 0, 1), nb=nb)
    smooth(body, 0.5, 6, mask=free, nb=nb)
    # clothes: loose shirt, straight trousers widening a little toward the hem
    P = coords(body)
    N = vertex_normals(body)
    leg = gw("thigh_l", "thigh_r", "calf_l", "calf_r")
    calf = gw("calf_l", "calf_r")
    t = 1 - smoothstep(J["foot_l"].z + 0.02, J["calf_l"].z, P[:, 2])       # 1 at the hem
    infl = 0.011 + 0.004 * leg + 0.02 * calf * t
    P = P + N * (infl * free + 0.006 * (1 - free))[:, None]
    set_coords(body, P)
else:
    smooth(body, 0.5, 10, mask=free, nb=nb)
    P = coords(body)
    N = vertex_normals(body)
    P = P + N * (0.012 * free + 0.006 * (1 - free))[:, None]
    set_coords(body, P)

decimate(body, target_tris=2700 if WHO == "hush" else 1720)
body.data.update()
tag(body, R["shirt"] if WHO == "hush" else R["jacket"], 1)
WAIST_Z = J["pelvis"].z + (0.05 if WHO == "hush" else 0.0)
allparts = [body]

# ---- 4. head ---------------------------------------------------------------------------------
if WHO == "hush":
    hp, F = heads.hush_head()
    HEAD_C = Vector((0, J["neck_01"].y - 0.005, J["upperarm_l"].z + 0.235))
else:
    hp, F = heads.bellows_head()
    HEAD_C = Vector((0, J["spine_03"].y - 0.085, J["upperarm_l"].z + 0.03 + 0.25))
DEC = {"head": 1700 if WHO == "hush" else 1500, "hair": 800, "beret": 360, "bouffant": 1100, "chop_l": 220, "chop_r": 220,
       "brow_l": 80, "brow_r": 80, "eye_l": 240, "eye_r": 240, "lid_l": 190, "lid_r": 190, "lowlid_l": 100, "lowlid_r": 100}
role_region = {"skin": R["facepaint"] if WHO == "hush" else R["skin"], "eye": R["eyewhite"], "lid": R["lid"],
               "brow": R["brow"] if WHO == "hush" else R["hair"], "hair": R["hair"], "beret": R["hat"]}
face = {}
for k, (ob, role) in hp.items():
    decimate(ob, target_tris=DEC.get(k, 300))
    ob.data.transform(Matrix.Translation(HEAD_C))
    tag(ob, R["lowlid"] if k.startswith("lowlid") else role_region[role], 0,
        {"head": 1, "eye_l": 2, "eye_r": 3}.get(k, 0))
    face[k] = ob
eye_c = {s: HEAD_C + Vector((sg * F["eye_c"][0], F["eye_c"][1], F["eye_c"][2])) for s, sg in (("l", 1), ("r", -1))}
brow_c = {s: HEAD_C + Vector((sg * F["brow_c"][0], F["brow_c"][1], F["brow_c"][2])) for s, sg in (("l", 1), ("r", -1))}

# move neck/head bones to the new head, add face bones (children of Head)
set_mode(arm, "EDIT")
eb = arm.data.edit_bones
def move_bone(n, head):
    b = eb[n]
    d = (b.tail - b.head)
    roll = b.roll
    b.head = head
    b.tail = head + d
    b.roll = roll
neck_base = Vector((0, J["neck_01"].y, J["upperarm_l"].z - 0.02))
head_pivot = HEAD_C + Vector((0, 0.03, -0.13 if WHO == "hush" else -0.12))
move_bone("neck_01", neck_base)
move_bone("Head", head_pivot)
FACE_BONES = []
def add_bone(n, head, parent="Head", L=0.04):
    b = eb.new(n)
    b.head = head
    b.tail = head + Vector((0, 0, L))
    b.roll = 0.0
    b.parent = eb[parent]
    b.use_deform = True
    FACE_BONES.append(n)
for s in ("l", "r"):
    add_bone("eye_" + s, eye_c[s])
    add_bone("lid_" + s, eye_c[s] + Vector((0, 0.0005, 0)))
    add_bone("brow_" + s, brow_c[s])
if WHO == "bellows":
    add_bone("bouffant", HEAD_C + Vector((0, 0.03, 0.12)), L=0.1)
set_mode(arm, "OBJECT")
names = [b.name for b in arm.data.bones]
J = {n: bone_head(arm, n) for n in names}

# weights of the head parts
hd = face["head"]
Ph = coords(hd)
zj = HEAD_C.z - 0.13                       # jaw line: Head fully above
wh = smoothstep(neck_base.z + 0.02, zj, Ph[:, 2])
for n, w in (("Head", wh), ("neck_01", 1 - wh)):
    vg = hd.vertex_groups.new(name=n)
    for i in range(len(Ph)):
        if w[i] > 1e-4:
            vg.add([i], float(w[i]), "REPLACE")
for k, ob in face.items():
    if k == "head":
        continue
    if k.startswith(("eye_", "lid_", "brow_")):
        rigid(ob, k.replace("lowlid", "Head"))
    elif k == "bouffant":
        rigid(ob, "bouffant")
    else:
        rigid(ob, "Head")
allparts += list(face.values())

# ---- 5. hands, shoes, rings, costume pieces -------------------------------------------------------
for s in ("l", "r"):
    if WHO == "hush":
        g, cf = parts.glove(arm, s, k=1.5, cuff=True, fat=1.15)
        decimate(g, target_tris=600); decimate(cf, target_tris=120)
        tag(g, R["glove"], 2); tag(cf, R["glove"], 2)
        allparts += [g, cf]
        sh = parts.shoe(arm, s, length=0.95, width=0.82, height=0.8, pointy=0.5)
        decimate(sh, target_tris=280)
        tag(sh, R["shoes"], 2)
        allparts.append(sh)
    else:
        g, cf = parts.glove(arm, s, k=1.15, cuff=False, fat=1.25, name="hand")
        decimate(g, target_tris=400)
        tag(g, R["skin"], 2)
        allparts.append(g)
        la, hh = J["lowerarm_" + s], J["hand_" + s]
        d = (hh - la).normalized()
        cuff = parts.lathe("scuff_" + s, [(0.052, 0.0), (0.058, 0.01), (0.058, 0.045), (0.05, 0.055)], hh - d * 0.06, d, seg=14)
        clib.skin_segments(cuff, ["lowerarm_" + s, "hand_" + s], arm, keep=2)
        tag(cuff, R["cuffw"], 2)
        allparts.append(cuff)
        sh = parts.shoe(arm, s, length=0.95, width=1.1, height=0.95, pointy=0.0)
        decimate(sh, target_tris=260)
        tag(sh, R["shoes"], 2)
        allparts.append(sh)

# neckline collar / hems from the open boundary loops of the base body
loops = parts.boundary_loops(body)
for c, r, comp in loops:
    if WHO == "hush" and c.z > J["spine_03"].z and abs(c.x) < 0.05:        # neckline
        tor = parts.torus("collar", c + Vector((0, 0, 0.004)), (0, 0, 1), r * 1.0, 0.013, seg=20, rseg=5, squash=0.9)
        clib.skin_segments(tor, ["spine_03", "neck_01"], arm, keep=2)
        tag(tor, R["collar"], 2)
        allparts.append(tor)
    elif c.z < 0.35 and abs(c.x) > 0.03:                                    # trouser hems
        side = "l" if c.x > 0 else "r"
        tor = parts.torus("hem_" + side, c + Vector((0, 0, 0.004)), (0, 0, 1), r * 1.02, 0.011, seg=16, rseg=5, squash=0.8)
        clib.skin_segments(tor, ["calf_" + side], arm, keep=1)
        tag(tor, R["hem"], 2)
        allparts.append(tor)

if WHO == "hush":
    # Clarence the rubber chicken, tucked in the right brace
    cc = Vector((-0.072, J["spine_03"].y - 0.095, J["spine_03"].z + 0.035))
    ch = clib.metablob("clarence", [heads.ellip(tuple(cc), (0.03, 0.026, 0.045)),
                                    heads.ball(tuple(cc + Vector((0.004, -0.005, 0.06))), 0.024),
                                    heads.capsule(tuple(cc + Vector((0.0, -0.004, 0.03))), 0.012, 0.02, rot=(0, 90, 0))],
                       resolution=0.003)
    decimate(ch, target_tris=240)
    tag(ch, R["chick"], 2)
    comb = clib.metablob("comb", [heads.ball(tuple(cc + Vector((0.004 + dx, -0.002, 0.085 - abs(dx) * 0.4))), 0.009) for dx in (-0.012, 0.0, 0.012)], resolution=0.002)
    decimate(comb, target_tris=80)
    tag(comb, R["chick_red"], 2)
    beak = clib.metablob("beak", [heads.ellip(tuple(cc + Vector((0.004, -0.03, 0.058))), (0.009, 0.014, 0.006))], resolution=0.002)
    decimate(beak, target_tris=60)
    tag(beak, R["chick_beak"], 2)
    for o in (ch, comb, beak):
        rigid(o, "spine_03")
    allparts += [ch, comb, beak]
else:
    # the barrel: one clay egg from the hips to the shoulders, arms attach at its upper sides
    zb, zt = J["thigh_l"].z - 0.07, J["upperarm_l"].z + 0.03
    H = zt - zb
    yc = J["spine_02"].y
    el = [heads.ellip((0, yc - 0.02, zb + H * 0.40), (0.40, 0.35, H * 0.48)),      # belly
          heads.ellip((0, yc - 0.07, zb + H * 0.36), (0.32, 0.32, H * 0.38)),      # belly forward
          heads.ellip((0, yc + 0.02, zb + H * 0.72), (0.31, 0.25, H * 0.25)),      # chest
          heads.ellip((0, yc + 0.04, zt - 0.08), (0.36, 0.22, 0.12)),              # shoulders (hide the arm roots)
          heads.ellip((0, yc + 0.0, zb + 0.04), (0.28, 0.25, 0.1))]                # seat
    barrel = clib.metablob("barrel", el, resolution=0.012)
    decimate(barrel, target_tris=1200)
    clib.skin_segments(barrel, ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"], arm, power=3.0, keep=3)
    tag(barrel, R["jacket"], 1)
    allparts.append(barrel)
    # coat tails (two flaps behind), cravat puff, shirt front, lapels and buttons are painted/added
    for s, sg in (("l", 1), ("r", -1)):
        tail = clib.metablob("tail_" + s, [heads.ellip((sg * 0.12, yc + 0.3, zb + 0.02), (0.11, 0.05, 0.2), rot=(12, 0, sg * 10))], resolution=0.008)
        decimate(tail, target_tris=100)
        clib.skin_segments(tail, ["pelvis", "thigh_" + s], arm, keep=2)
        tag(tail, R["jacket"], 1)
        allparts.append(tail)
    cz = zt - 0.0
    cy = HEAD_C.y - 0.08
    crav = clib.metablob("cravat", [heads.ellip((0, cy, cz), (0.07, 0.045, 0.045)),
                                    heads.ellip((0, cy - 0.025, cz - 0.07), (0.048, 0.035, 0.06)),
                                    heads.ellip((0.05, cy + 0.01, cz + 0.008), (0.04, 0.03, 0.03)),
                                    heads.ellip((-0.05, cy + 0.01, cz + 0.008), (0.04, 0.03, 0.03))], resolution=0.004)
    decimate(crav, target_tris=220)
    rigid(crav, "spine_03")
    tag(crav, R["cravat"], 2)
    allparts.append(crav)
    # high white collar around the neck
    col = parts.lathe("collar", [(0.1, 0.0), (0.094, 0.045), (0.088, 0.062)], Vector((0, HEAD_C.y + 0.035, zt - 0.045)), Vector((0, 0, 1)), seg=24)
    clib.skin_segments(col, ["spine_03", "neck_01"], arm, keep=2)
    tag(col, R["shirtw"], 2)
    allparts.append(col)
    # specs on a chain resting on the belly
    sp = []
    for sx in (-0.045, 0.045):
        t = parts.torus("spec", Vector((0.06 + sx, yc - 0.37, zb + H * 0.62)), (0.25, -1, 0.15), 0.03, 0.005, seg=14, rseg=4)
        sp.append(t)
    br = parts.torus("specbr", Vector((0.06, yc - 0.37, zb + H * 0.62 + 0.012)), (0.25, -1, 0.15), 0.015, 0.004, seg=6, rseg=4)
    sp.append(br)
    for t in sp:
        rigid(t, "spine_02")
        tag(t, R["gold"], 2)
    allparts += sp
    # gold buttons down the jacket front
    for i, fz in enumerate((0.3, 0.45, 0.6)):
        b = heads.uv_sphere("btn%d" % i, 0.018, 8, 5, center=(0.0, yc - 0.43 + abs(0.5 - fz) * 0.08, zb + H * fz))
        rigid(b, "spine_01" if fz < 0.5 else "spine_02")
        tag(b, R["gold"], 2)
        allparts.append(b)

for o in allparts:
    for p in o.data.polygons:
        p.use_smooth = True
PART_TRIS = {}
for o in allparts:
    k = o.name.split(".")[0].rstrip("_lr").rstrip("_")
    PART_TRIS[k] = PART_TRIS.get(k, 0) + tris(o)
print("PARTS", sorted(PART_TRIS.items(), key=lambda kv: -kv[1]))
for o in allparts:
    if "custom_normal" in o.data.attributes:
        o.data.attributes.remove(o.data.attributes["custom_normal"])
char = join(allparts, "Hush" if WHO == "hush" else "Bellows")
if "custom_normal" in char.data.attributes:
    char.data.attributes.remove(char.data.attributes["custom_normal"])
for cn in [ca.name for ca in char.data.color_attributes]:
    char.data.color_attributes.remove(char.data.color_attributes[cn])
bind(char, arm)
# ---- 6. exact spec height (GDD / REDESIGN §5.5: Hush 1.60 m, Bellows 1.78 m to the top of the bouffant)
TARGET = 1.60 if WHO == "hush" else 1.78
zmax = coords(char)[:, 2].max()
SCALE = TARGET / zmax
set_coords(char, coords(char) * SCALE)
set_mode(arm, "EDIT")
for b in arm.data.edit_bones:
    roll = b.roll
    b.head = b.head * SCALE
    b.tail = b.tail * SCALE
    b.roll = roll
set_mode(arm, "OBJECT")
HEAD_C = HEAD_C * SCALE
eye_c = {k: v * SCALE for k, v in eye_c.items()}
brow_c = {k: v * SCALE for k, v in brow_c.items()}
F = dict(F)
F["eye_r"] *= SCALE
F["mouth_w"] *= SCALE
F["mouth_c"] = tuple(c * SCALE for c in F["mouth_c"])
WAIST_Z *= SCALE
print("SCALE", round(SCALE, 4), "height", TARGET)
print("TRIS", WHO, tris(char), "VERTS", len(char.data.vertices))
meta = {"who": WHO, "head_c": list(HEAD_C), "eye_c": {k: list(v) for k, v in eye_c.items()}, "eye_r": F["eye_r"],
        "brow_c": {k: list(v) for k, v in brow_c.items()}, "mouth_c": list(HEAD_C + Vector(F["mouth_c"])), "mouth_w": F["mouth_w"],
        "lid_rest": F["lid_rest"], "face_bones": FACE_BONES, "regions": R,
        "waist_z": WAIST_Z, "joints": {n: list(bone_head(arm, n)) for n in names}}
json.dump(meta, open(os.path.join(OUT, WHO + "_meta.json"), "w"), indent=1)
print("VALIDATE", char.data.validate(verbose=False))
for o in list(bpy.data.objects):
    if o not in (arm, char):
        bpy.data.objects.remove(o, do_unlink=True)
for coll in (bpy.data.metaballs, bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.images):
    for d in list(coll):
        if d.users == 0:
            coll.remove(d)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, WHO + "_geo.blend"))

if opt.get("preview"):
    COL = {1: (0.96, 0.78, 0.66), 2: (1.0, 0.96, 0.92), 3: (1, 1, 1), 4: (0.25, 0.16, 0.15) if WHO == "hush" else (0.85, 0.86, 0.9),
           5: (0.89, 0.23, 0.31), 6: (0.1, 0.08, 0.12), 7: (0.9, 0.9, 0.95), 8: (0.1, 0.1, 0.14), 9: (0.08, 0.08, 0.1),
           10: (1, 1, 1), 11: (0.17, 0.21, 0.4), 12: (1.0, 0.82, 0.25), 13: (0.89, 0.23, 0.31), 14: (1.0, 0.55, 0.2),
           15: (0.98, 0.92, 0.9), 16: (0.48, 0.25, 0.55), 17: (0.35, 0.16, 0.4), 18: (1, 1, 1), 19: (0.91, 0.7, 0.23),
           20: (0.91, 0.7, 0.23), 21: (1, 1, 1), 22: (0.8, 0.8, 0.8), 23: (1, 1, 1), 24: (0.1, 0.1, 0.14), 25: (0.98, 0.92, 0.9)}
    me = char.data
    ca = me.color_attributes.new("pv", "BYTE_COLOR", "CORNER")
    reg = region_array(char)
    for p in me.polygons:
        c = COL.get(int(reg[p.index]), (1, 0, 1))
        for li in p.loop_indices:
            ca.data[li].color = (*c, 1)
    me.color_attributes.active_color = ca
    bpy.context.scene.display.shading.color_type = "VERTEX"
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions["Idle_Loop"]
    if hasattr(arm.animation_data, "action_slot") and arm.animation_data.action_suitable_slots:
        arm.animation_data.action_slot = arm.animation_data.action_suitable_slots[0]
    bpy.context.scene.frame_set(20)
    preview(os.path.join(OUT, WHO + "_pv"), ("front", "q34", "side", "back"), center=(0, 0, 0.85), ortho=1.9, res=(520, 700), color="VERTEX")
