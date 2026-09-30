"""Test character for the 3D pipeline spike: a toon mime ("Hush proxy") modelled procedurally in bpy on
the CC0 Quaternius UAL skeleton, skinned by distance-to-bone weights, carrying a curated set of UAL1+UAL2
clips plus custom keyframed comedy clips (Tiptoe_Sneak_Loop, Freeze_Statue, Snicker) — one .glb.

blender -b --python build_char.py -- --ual1 <UAL1_Standard.glb> --ual2 <UAL2_Standard.glb> --out <hush_test.glb>
    [--preview <dir>]  (Workbench keyframe previews of the custom clips; needs xvfb-run)
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix, Quaternion
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mnd3d
from mnd3d import PB

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {argv[i].lstrip("-"): argv[i + 1] for i in range(0, len(argv) - 1, 2)}
FPS = 30

KEEP_UAL1 = ["Idle_Loop", "Walk_Loop", "Walk_Formal_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Crouch_Idle_Loop",
             "Crouch_Fwd_Loop", "Interact", "PickUp_Table", "Fixing_Kneeling", "Push_Loop", "Sitting_Enter",
             "Sitting_Idle_Loop", "Sitting_Exit", "Hit_Head", "Idle_Talking_Loop", "Jump_Start", "Jump_Loop",
             "Jump_Land", "Roll", "Dance_Loop"]
KEEP_UAL2 = ["Idle_FoldArms_Loop", "Idle_No_Loop", "Yes", "Chest_Open", "Consume", "Walk_Carry_Loop",
             "OverhandThrow", "Hit_Knockback", "LayToIdle", "Idle_TalkingPhone_Loop"]

mnd3d.reset()
bpy.context.scene.render.fps = FPS

# ---- skeleton + library clips ------------------------------------------------------------------
bpy.ops.import_scene.gltf(filepath=opt["ual1"])
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
arm.name = "Armature"   # keep the UAL node name: shared AnimationLibrary tracks are "Armature/Skeleton3D:<bone>"
arm.data.name = "Armature"
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a.name not in KEEP_UAL1:
        bpy.data.actions.remove(a)
if "ual2" in opt:
    before = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=opt["ual2"])
    for o in list(bpy.data.objects):
        if o != arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(set(bpy.data.actions) - before):
        base = a.name.split(".")[0]
        if base in KEEP_UAL2 and base not in bpy.data.actions:
            a.name = base
        elif base not in KEEP_UAL2 or a.name != base:
            bpy.data.actions.remove(a)
for o in list(bpy.data.objects):
    if o.type == "ARMATURE" and o != arm:
        bpy.data.objects.remove(o, do_unlink=True)
for a in bpy.data.actions:
    a.use_fake_user = True
print("LIB_ACTIONS", len(bpy.data.actions))

VARIANT = opt.get("variant", "hush")
K_LEG = float(opt.get("leg", "1.0"))
GIRTH = float(opt.get("girth", "1.0"))


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


def edit_proportions(k):
    """Shorter/longer legs WITHOUT breaking the library clips: bone directions and rolls are kept (so
    local-rotation keys still mean the same motion), the upper body drops by the leg-length change and
    pelvis translation keys are scaled by k (crouch/sit depth follows the new legs)."""
    if abs(k - 1.0) < 1e-3:
        return
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    leg = {n + s for s in ("_l", "_r") for n in ("thigh", "calf", "foot", "ball", "ball_leaf") if (n + s) in eb}
    drop = (1.0 - k) * (eb["thigh_l"].head.z - eb["foot_l"].head.z)
    for b in eb:
        b.use_connect = False
    for b in eb:
        if b.name not in leg and b.name != "root":
            b.head.z -= drop
            b.tail.z -= drop
    for s in ("_l", "_r"):
        t, c = eb["thigh" + s], eb["calf" + s]
        dt, dc = (t.tail - t.head), (c.tail - c.head)
        t.head.z -= drop
        t.tail = t.head + dt * k
        c.head = t.tail.copy()
        c.tail = c.head + dc * k
        delta = c.tail - eb["foot" + s].head
        for n in ("foot", "ball", "ball_leaf"):
            if (n + s) in eb:
                eb[n + s].head += delta
                eb[n + s].tail += delta
    bpy.ops.object.mode_set(mode="OBJECT")
    for act in bpy.data.actions:
        for fc in action_fcurves(act):
            if fc.data_path == 'pose.bones["pelvis"].location':
                for kp in fc.keyframe_points:
                    kp.co[1] *= k
                    kp.handle_left[1] *= k
                    kp.handle_right[1] *= k


edit_proportions(K_LEG)
B = {b.name: b for b in arm.data.bones}


def head(n):
    return arm.matrix_world @ B[n].head_local


def tail(n):
    return arm.matrix_world @ B[n].tail_local


# ---- weights --------------------------------------------------------------------------------------
def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (p - (a + ab * t)).length


def skin(ob, bones, power=4.0, keep=2):
    """Vertex groups from distances to the given bone segments (smooth joints, top-`keep` bones)."""
    groups = {n: ob.vertex_groups.new(name=n) for n in bones}
    segs = {n: (head(n), tail(n)) for n in bones}
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        ws = sorted(((1.0 / (seg_dist(p, *segs[n]) ** power + 1e-7), n) for n in bones), reverse=True)[:keep]
        tot = sum(w for w, _ in ws)
        for w, n in ws:
            groups[n].add([v.index], w / tot, "REPLACE")


parts = []


def part(pb, bones, **kw):
    ob = pb.finish()
    skin(ob, bones, **kw)
    parts.append(ob)
    return ob


def ring_profile(z0, z1, r0, r1, n=6, bulge=0.0):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append((r0 + (r1 - r0) * t + bulge * math.sin(math.pi * t), z0 + (z1 - z0) * t))
    return out


# ---- the body (armature space: +X = character's left, -Y = front, +Z up) -------------------------------
# VARIANT "hush": the mime (beret, Breton stripes, braces, huge gloves). "bellows": the neighbour proxy
# (barrel torso via --girth, tiny legs via --leg, silver bouffant + mutton chops, plum jacket, gold cravat).
BELL = VARIANT == "bellows"
SKIN = "peach" if BELL else "skin"
hz = head("Head").z
pb = PB("head")
HC = Vector((0.0, -0.01, hz + 0.13))
pb.sphere(0.15, HC, SKIN, scale=(1.0, 0.97, 1.12), seg=28, rings=18)
for s in (-1, 1):
    if BELL:   # small short-sighted eyes, bushy brows, mutton chops
        pb.sphere(0.016, HC + Vector((s * 0.055, -0.136, 0.03)), "pupil", scale=(1.0, 0.5, 1.0), seg=10, rings=8)
        pb.box((0.075, 0.03, 0.03), HC + Vector((s * 0.058, -0.13, 0.075)), "bouffant", bevel=0.012, rot=(0, -s * 12, 0))
        pb.sphere(0.07, HC + Vector((s * 0.125, -0.06, -0.06)), "bouffant", scale=(0.7, 0.9, 1.25), seg=14, rings=10)
    else:
        pb.sphere(0.03, HC + Vector((s * 0.056, -0.128, 0.03)), "pupil", scale=(0.85, 0.5, 1.35), seg=14, rings=10)
        pb.sphere(0.009, HC + Vector((s * 0.056 + 0.01, -0.146, 0.052)), "white", seg=8, rings=6)
        pb.sphere(0.026, HC + Vector((s * 0.095, -0.112, -0.035)), "cheek", scale=(1.0, 0.45, 0.8), seg=12, rings=8)
        pb.box((0.06, 0.012, 0.014), HC + Vector((s * 0.058, -0.138, 0.098)), "pupil", bevel=0.005, rot=(0, s * 14, 0))
if BELL:
    pb.sphere(0.042, HC + Vector((0, -0.15, -0.01)), "cheek", scale=(1.0, 0.9, 0.85), seg=14, rings=10)   # bulbous nose
    pb.sphere(0.03, HC + Vector((0, -0.128, -0.085)), "red", scale=(1.3, 0.45, 0.5), seg=12, rings=8)
    # the bouffant: a dandelion clock of silver puffs
    for (x, y, z, r) in ((0, 0.02, 0.17, 0.12), (-0.1, 0.03, 0.13, 0.1), (0.1, 0.03, 0.13, 0.1), (0, 0.1, 0.1, 0.11),
                         (-0.06, -0.05, 0.16, 0.08), (0.06, -0.05, 0.16, 0.08)):
        pb.sphere(r, HC + Vector((x, y, z)), "bouffant", seg=16, rings=10)
else:
    pb.sphere(0.018, HC + Vector((0, -0.15, -0.008)), "cheek", seg=10, rings=8)
    pb.sphere(0.034, HC + Vector((0, -0.128, -0.075)), "red", scale=(1.0, 0.45, 0.42), seg=14, rings=8)
    pb.sphere(0.165, HC + Vector((0.03, 0.01, 0.145)), "red", scale=(1.0, 0.95, 0.32), seg=24, rings=12, rot=(0, 14, 0))
    pb.cyl(0.012, 0.008, 0.04, HC + Vector((0.05, 0.01, 0.19)), "red", seg=8)
part(pb, ["Head"], keep=1)

pb = PB("neck")
pb.cyl(0.042 * (1.3 if BELL else 1.0), 0.045 * (1.3 if BELL else 1.0), 0.16, head("neck_01") + Vector((0, 0, -0.04)), SKIN, seg=14)
part(pb, ["spine_03", "neck_01", "Head"])

# torso: one continuous lathe (stripes for Hush, a plum barrel for Bellows)
pz = head("pelvis").z
top = head("neck_01").z
H = top - pz
prof = [(0.13, pz - 0.02), (0.145, pz + 0.05), (0.14, pz + 0.12)]
z = pz + 0.12
while z < pz + H * 0.88:
    z += 0.045
    t = (z - pz) / H
    r = 0.14 - 0.02 * math.sin(math.pi * min(t, 0.5)) + 0.04 * max(0.0, t - 0.4)
    if BELL:
        r = 0.15 + 0.11 * math.sin(math.pi * min(1.0, t * 1.05))   # barrel
    prof.append((r, z))
prof += [(0.15 if not BELL else 0.19, pz + H * 0.93), (0.12, pz + H * 0.98), (0.05, pz + H * 1.02)]
prof = [(r * (GIRTH if i > 1 else max(1.0, GIRTH * 0.8)), z) for i, (r, z) in enumerate(prof)]
if BELL:
    bands = ["plum_dk", "plum_dk"] + ["plum"] * (len(prof) - 5) + ["plum", "plum", "plum"]
else:
    bands = ["trouser", "trouser"] + ["white" if i % 2 == 0 else "navy" for i in range(len(prof) - 5)] + ["navy", "navy", "navy"]
pb = PB("torso")
pb.lathe(prof, Vector((0, 0.02, 0)), "navy", seg=28, scale=(1.0, 0.78, 1.0), bands=bands, cap_bottom=True, cap_top=True)
if BELL:
    front = max(r for r, _ in prof) * 0.78
    pb.sphere(0.07, Vector((0, -0.11 * GIRTH * 0.9, top - 0.02)), "cravat", scale=(1.1, 0.7, 0.9), seg=14, rings=10)
    pb.sphere(0.045, Vector((0, -0.12 * GIRTH * 0.9, top - 0.11)), "cravat", scale=(0.8, 0.6, 1.1), seg=12, rings=8)
    for zz in (0.35, 0.5):
        pb.sphere(0.022, Vector((0, 0.02 - front - 0.005, pz + H * zz)), "cravat", seg=10, rings=6)
    pb.torus(0.035, 0.006, Vector((0.05, 0.02 - front * 0.93, pz + H * 0.62)), "specs", seg=14, rseg=5, rot=(90, 0, 0))
    pb.torus(0.035, 0.006, Vector((0.13, 0.02 - front * 0.85, pz + H * 0.62)), "specs", seg=14, rseg=5, rot=(90, 0, 25))
else:
    for s in (-1, 1):
        pb.box((0.032, 0.02, 0.5), Vector((s * 0.07, -0.098, pz + 0.07)), "red", bevel=0.008, rot=(-4, 0, 0))
        pb.box((0.032, 0.02, 0.48), Vector((s * 0.07, 0.135, pz + 0.07)), "red", bevel=0.008, rot=(6, 0, 0))
part(pb, ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"], power=3.0, keep=3)

pb = PB("hips")
pb.sphere(0.15 * max(1.0, GIRTH * 0.85), Vector((0, 0.02, pz - 0.01)), "plum_dk" if BELL else "trouser", scale=(1.0, 0.8, 0.72), seg=22, rings=12)
part(pb, ["pelvis", "thigh_l", "thigh_r"], keep=2)

for side in ("l", "r"):
    sx = 1 if side == "l" else -1
    sh, el, wr = head("upperarm_" + side), head("lowerarm_" + side), head("hand_" + side)
    L = (wr - sh).length
    thick = 1.25 if BELL else 1.0
    prof = [(0.055 * thick, 0.0)]
    n = 9
    for i in range(1, n + 1):
        t = i / n
        prof.append(((0.055 - 0.012 * t) * thick, L * t))
    bands = ["plum"] * n if BELL else ["navy" if i % 2 == 0 else "white" for i in range(n)]
    pb = PB("sleeve_" + side)
    pb.lathe(prof, sh + Vector((-sx * 0.02, 0, 0)), "navy", seg=16, rot=(0, sx * 90, 0), bands=bands)
    pb.sphere(0.068 * thick, sh + Vector((-sx * 0.01, 0, 0.0)), "plum" if BELL else "navy", seg=16, rings=10)
    if BELL:
        pb.cyl(0.055 * thick, 0.06 * thick, 0.05, wr + Vector((-sx * 0.05, 0, 0)), "white", seg=14, rot=(0, sx * 90, 0))  # shirt cuff
    part(pb, ["clavicle_" + side, "upperarm_" + side, "lowerarm_" + side], power=4.0, keep=2)
    hp = head("hand_" + side)
    pb = PB("hand_" + side)
    if BELL:   # small pudgy hands (he is the straight man; Hush's gloves act)
        pb.sphere(0.05, hp + Vector((sx * 0.06, 0.0, -0.005)), "peach", scale=(1.2, 0.7, 0.9), seg=14, rings=10)
        pb.sphere(0.022, hp + Vector((sx * 0.04, -0.045, 0.01)), "peach", scale=(1.3, 0.9, 0.9), seg=8, rings=6)
    else:      # huge white glove (1.6x hand): cuff + mitten + fingers + thumb
        pb.cyl(0.05, 0.07, 0.06, hp + Vector((-sx * 0.035, 0, 0)), "glove", seg=16, rot=(0, sx * 90, 0))
        pb.sphere(0.07, hp + Vector((sx * 0.1, 0.0, -0.005)), "glove", scale=(1.25, 0.62, 0.95), seg=18, rings=12)
        for dy in (-0.035, 0.0, 0.035):
            pb.sphere(0.024, hp + Vector((sx * 0.185, dy, -0.01)), "glove", scale=(1.3, 1.0, 0.9), seg=10, rings=8)
        pb.sphere(0.03, hp + Vector((sx * 0.07, -0.06, 0.01)), "glove", scale=(1.3, 0.9, 0.9), seg=10, rings=8, rot=(0, 0, sx * 30))
    part(pb, ["hand_" + side], keep=1)
    th, kn, an = head("thigh_" + side), head("calf_" + side), head("foot_" + side)
    pb = PB("leg_" + side)
    lw = 1.25 if BELL else 1.0
    pb.lathe([(0.05 * lw, 0.0), (0.056 * lw, (kn - an).length * 0.5), (0.062 * lw, (kn - an).length), (0.074 * lw, (th - an).length + 0.02)],
             an + Vector((0, 0, -0.03)), "plum_dk" if BELL else "trouser", seg=16)
    part(pb, ["thigh_" + side, "calf_" + side, "pelvis"], power=4.0, keep=2)
    ft, bl = head("foot_" + side), head("ball_" + side)
    pb = PB("shoe_" + side)
    pb.box((0.1 * lw, 0.25, 0.075), Vector((ft.x, (ft.y + bl.y) / 2 - 0.02, 0.0)), "shoe", bevel=0.035, seg=3)
    pb.sphere(0.052 * lw, Vector((ft.x, bl.y - 0.07, 0.035)), "shoe", scale=(1.0, 1.25, 0.72), seg=14, rings=8)
    part(pb, ["foot_" + side, "ball_" + side], keep=2)

# join into one skinned mesh
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "Bellows" + "Body" if VARIANT == "bellows" else "HushBody"
body.parent = arm
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm
print("BODY verts", len(body.data.vertices), "tris", sum(len(p.vertices) - 2 for p in body.data.polygons))


# ---- custom comedy clips (keyframed in bpy) -----------------------------------------------------
def rest_q(n):
    return B[n].matrix_local.to_quaternion()


AX = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}


def local_q(n, rots):
    """rots: [(axis, deg), ...] about ARMATURE axes (as if the parent were at rest), applied in order."""
    R = Quaternion()
    for ax, deg in rots:
        R = Quaternion(AX[ax], math.radians(deg)) @ R
    M = rest_q(n)
    return M.inverted() @ R @ M


def mirror(rots):
    # left <-> right: rotations about Y and Z flip sign, about X keep
    return [(ax, deg if ax == "x" else -deg) for ax, deg in rots]


ALL = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r",
       "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "thigh_l", "thigh_r",
       "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]


def pose_key(action_name, frames_poses, loop_to=None):
    """frames_poses: [(frame, {bone: rots or ("L"/"R" mirrored), "_pelvis_z": metres}), ...]"""
    act = bpy.data.actions.new(action_name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    for f, pose in frames_poses:
        for n in ALL:
            pbn = arm.pose.bones[n]
            pbn.rotation_mode = "QUATERNION"
            pbn.rotation_quaternion = local_q(n, pose.get(n, []))
            pbn.keyframe_insert("rotation_quaternion", frame=f, group=n)
        pv = arm.pose.bones["pelvis"]
        off = Vector((0, pose.get("_pelvis_y", 0.0), pose.get("_pelvis_z", 0.0)))
        pv.location = rest_q("pelvis").inverted() @ off
        pv.keyframe_insert("location", frame=f, group="pelvis")
    for fc in act.fcurves if hasattr(act, "fcurves") else []:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
    arm.animation_data.action = None
    return act


def sym(pose_l):
    """Make the right-side entries from the left-side ones (mirrored)."""
    out = dict(pose_l)
    for n, r in list(pose_l.items()):
        if n.endswith("_l"):
            out[n[:-2] + "_r"] = mirror(r)
    return out


# arms: from T-pose down along the body (base), used by every custom clip
ARM_DOWN_L = [("y", 72)]
# Tiptoe sneak: exaggerated cartoon tiptoe — knee high, toes pointed, body leaning, "paws" up front.
paws_l = {"clavicle_l": [("z", -8)], "upperarm_l": [("y", 62), ("z", -58)], "lowerarm_l": [("z", -95), ("y", -20)],
          "hand_l": [("y", 55)]}
paws = sym(paws_l)
torso = {"spine_01": [("x", 12)], "spine_02": [("x", 8)], "spine_03": [("x", 4)], "neck_01": [("x", -10)],
         "Head": [("x", -8), ("z", 0)]}


def tiptoe(phase):
    """phase 0: left knee up; 1: passing; mirrored by swapping sides."""
    lift = {"thigh_l": [("x", -78)], "calf_l": [("x", 100)], "foot_l": [("x", 38)], "ball_l": [("x", -10)],
            "thigh_r": [("x", 14)], "calf_r": [("x", 22)], "foot_r": [("x", 32)], "ball_r": [("x", -38)]}
    passing = {"thigh_l": [("x", -30)], "calf_l": [("x", 55)], "foot_l": [("x", 40)], "ball_l": [("x", -20)],
               "thigh_r": [("x", -2)], "calf_r": [("x", 8)], "foot_r": [("x", 36)], "ball_r": [("x", -40)]}
    p = dict(torso)
    p.update(paws)
    p.update(lift if phase == 0 else passing)
    p["_pelvis_z"] = -0.05 if phase == 0 else 0.03
    return p


def swap(p):
    q = {}
    for n, r in p.items():
        if n.endswith("_l"):
            q[n[:-2] + "_r"] = mirror(r)
        elif n.endswith("_r"):
            q[n[:-2] + "_l"] = mirror(r)
        else:
            q[n] = r
    return q


A0 = tiptoe(0)
A0["Head"] = [("x", -8), ("z", 6)]
A1 = tiptoe(1)
A2 = swap(A0)
A2["Head"] = [("x", -8), ("z", -6)]
A3 = swap(A1)
pose_key("Tiptoe_Sneak_Loop", [(1, A0), (10, A1), (19, A2), (28, A3), (37, A0)])

# Freeze_Statue: the mime turns to stone mid-sneak (arabesque, arms in a V, chin up) — held.
statue = {"spine_01": [("x", -6)], "neck_01": [("x", -12)], "Head": [("x", -10), ("y", 10)],
          "upperarm_l": [("y", -38), ("z", -10)], "lowerarm_l": [("y", -15)], "hand_l": [("y", -25)],
          "upperarm_r": [("y", -38), ("z", 10)], "lowerarm_r": [("y", 15)], "hand_r": [("y", 25)],
          "thigh_l": [("x", 55)], "calf_l": [("x", 25)], "foot_l": [("x", 45)],
          "thigh_r": [("x", -4)], "calf_r": [("x", 4)], "foot_r": [("x", 0)], "_pelvis_z": -0.02}
pose_key("Freeze_Statue", [(1, statue), (31, statue)])

# Snicker: hand over mouth, shoulders shaking, glance to the audience (turns head toward camera side).
sn_base = {"spine_01": [("x", 10)], "spine_02": [("x", 6)], "neck_01": [("x", 6)],
           "upperarm_l": [("y", 55), ("z", -62)], "lowerarm_l": [("z", -120), ("y", -30)], "hand_l": [("y", 20)],
           "upperarm_r": [("y", -75), ("z", 15)], "lowerarm_r": [("z", 40)], "hand_r": [("y", -10)],
           "thigh_l": [("x", -8)], "calf_l": [("x", 14)], "foot_l": [("x", -4)], "thigh_r": [("x", 6)]}
frames = []
for i, f in enumerate(range(1, 38, 4)):
    p = dict(sn_base)
    up = (i % 2) * 1.0
    p["clavicle_l"] = [("y", -8 * up)]
    p["clavicle_r"] = [("y", 8 * up)]
    p["spine_03"] = [("x", 4 + 5 * up)]
    p["Head"] = [("z", 28), ("x", 6 - 6 * up)]
    p["_pelvis_z"] = -0.01 * up
    frames.append((f, p))
pose_key("Snicker", frames)

bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 37
print("ACTIONS", len(bpy.data.actions), sorted(a.name for a in bpy.data.actions))

# ---- previews (Workbench, side + front) ------------------------------------------------------------
if "preview" in opt:
    import time
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 360, 480
    cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"; cam_d.ortho_scale = 2.3
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    os.makedirs(opt["preview"], exist_ok=True)
    arm.animation_data_create()
    for act_name, fr_list in (("Tiptoe_Sneak_Loop", (1, 10, 19, 28)), ("Freeze_Statue", (1,)), ("Snicker", (1, 5)),
                              ("Walk_Loop", (1, 12)), ("Idle_Loop", (1,))):
        arm.animation_data.action = bpy.data.actions[act_name]
        if hasattr(arm.animation_data, "action_slot") and arm.animation_data.action_suitable_slots:
            arm.animation_data.action_slot = arm.animation_data.action_suitable_slots[0]
        for fr in fr_list:
            sc.frame_set(fr)
            for view, loc, rot in (("side", (3.0, 0, 1.0), (math.radians(90), 0, math.radians(90))),
                                   ("front", (0, -3.0, 1.0), (math.radians(90), 0, 0))):
                cam.location, cam.rotation_euler = loc, rot
                sc.render.filepath = os.path.join(opt["preview"], "%s_%02d_%s.png" % (act_name, fr, view))
                bpy.ops.render.render(write_still=True)
    arm.animation_data.action = None

# ---- export --------------------------------------------------------------------------------------
if "out" in opt:
    for o in bpy.data.objects:
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    arm.animation_data_create()
    arm.animation_data.action = None
    for pbn in arm.pose.bones:
        pbn.location = (0, 0, 0); pbn.rotation_quaternion = (1, 0, 0, 0); pbn.rotation_euler = (0, 0, 0); pbn.scale = (1, 1, 1)
    mnd3d.export_glb([arm], opt["out"], animations=True,
                     extra={"export_animation_mode": "ACTIONS", "export_optimize_animation_size": True,
                            "export_def_bones": False, "export_frame_range": False})
    print("CHAR_OK", opt["out"])
