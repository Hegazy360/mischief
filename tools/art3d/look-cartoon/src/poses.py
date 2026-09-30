"""FK posing toolkit + the custom comedy clips for the Saturday Cartoon look-dev.

Poses are dicts {bone: [(axis, deg), ...]} with rotations about ARMATURE axes (x = character's left,
y = back, z = up) applied in order, as if the parent were at rest (standard FK: the child inherits its
parent's rotation). Special keys: "_pelvis" = (dx, dy, dz) armature-space offset of the pelvis,
"_root" = (dx, dy, dz) offset of the whole character (root motion, e.g. the CHOO launch).
Sign cheat-sheet (left side; the right side mirrors y/z rotations with mirror()):
  spine/neck/head  +x = bend forward        z = turn (+ = turn to her left)   y = lean sideways (+ = to her LEFT)
  thigh            -x = knee up (hip flex)  calf +x = bend the knee           foot +x = point the toes
  upperarm_l       +y = arm down from T     -z = arm forward                  lowerarm_l -z = elbow bend (forward)
"""
import bpy, math, os, json
from mathutils import Vector, Quaternion, Matrix
import clib

ARM = None
REST = {}
META = {}
FPS = 30
AX = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}
BODY = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "thigh_l", "thigh_r",
        "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]
FINGERS = ["%s_0%d_%s" % (f, i, s) for f in ("index", "middle", "ring", "pinky", "thumb") for i in (1, 2, 3) for s in ("l", "r")]


GROUND = {}


def setup(arm, meta):
    global ARM, META
    ARM = arm
    META = meta
    for b in arm.data.bones:
        REST[b.name] = b.matrix_local.to_quaternion()
    bb = arm.data.bones
    # rest heights of the foot landmarks above the floor (heel under the ankle, ball, toe tip)
    GROUND["ankle"] = bb["foot_l"].head_local.z - 0.0
    GROUND["ball"] = bb["ball_l"].head_local.z - 0.0
    GROUND["toe"] = bb["ball_l"].tail_local.z - 0.0
    GROUND["ankle"] = bb["foot_l"].head_local.z
    # heel bottom is ~at the floor under the ankle: treat the ankle's rest height as the heel clearance
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"


def rot_q(rots):
    R = Quaternion()
    for ax, deg in rots:
        R = Quaternion(AX[ax], math.radians(deg)) @ R
    return R


def local_q(n, rots):
    M = REST[n]
    return M.inverted() @ rot_q(rots) @ M


def mirror(rots):
    return [(ax, deg if ax == "x" else -deg) for ax, deg in rots]


def sym(pose):
    """Fill *_r from *_l (mirrored) where *_r is missing."""
    out = dict(pose)
    for n, r in pose.items():
        if n.endswith("_l") and (n[:-2] + "_r") not in pose:
            out[n[:-2] + "_r"] = mirror(r)
    return out


def _mirror_bone(b):
    return b[:-2] + "_r" if b.endswith("_l") else (b[:-2] + "_l" if b.endswith("_r") else b)


def swap(pose):
    out = {}
    for n, r in pose.items():
        if n.startswith("ik_"):
            bone, p, pole = r
            out["ik_" + ("r" if n == "ik_l" else "l")] = (_mirror_bone(bone), Vector((-p[0], p[1], p[2])), Vector((-pole[0], pole[1], pole[2])))
            continue
        if n.startswith("_") and n not in ("_pelvis", "_root"):
            out[n] = r
            continue
        if n.endswith("_l"):
            out[n[:-2] + "_r"] = mirror(r)
        elif n.endswith("_r"):
            out[n[:-2] + "_l"] = mirror(r)
        elif n in ("_pelvis", "_root"):
            out[n] = (-r[0], r[1], r[2])
        elif isinstance(r, list):
            out[n] = mirror(r)
        else:
            out[n] = r
    return out


def blend(a, b, t):
    """Pose interpolation (per bone slerp of the composed rotations; offsets lerp)."""
    out = {}
    keys = set(a) | set(b)
    for k in keys:
        if k.startswith("_"):
            va, vb = Vector(a.get(k, (0, 0, 0))), Vector(b.get(k, (0, 0, 0)))
            out[k] = tuple(va.lerp(vb, t))
        else:
            qa = rot_q(a.get(k, [])) if isinstance(a.get(k, []), list) else a[k]
            qb = rot_q(b.get(k, [])) if isinstance(b.get(k, []), list) else b[k]
            out[k] = qa.slerp(qb, t)
    return out


def _q(n, v):
    if isinstance(v, Quaternion):
        M = REST[n]
        return M.inverted() @ v @ M
    return local_q(n, v)


def new_action(name):
    act = bpy.data.actions.get(name)
    if act is not None:
        bpy.data.actions.remove(act)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ARM.animation_data_create()
    ARM.animation_data.action = act
    if hasattr(ARM.animation_data, "action_slot"):
        try:
            if ARM.animation_data.action_slot is None:
                slot = act.slots.new(id_type="OBJECT", name=ARM.name)
                ARM.animation_data.action_slot = slot
        except Exception:
            pass
    return act


def key(frame, pose, bones=None, fingers=None):
    """Key every body bone (rest where the pose says nothing), pelvis offset, root offset.
    fingers: {"l": curl_deg, "r": curl_deg} or None (fingers keyed straight-ish)."""
    extra = [n for n in pose if not n.startswith("_") and n not in BODY and n in ARM.pose.bones and n != "root"]
    for n in list(bones or BODY) + extra:
        pb = ARM.pose.bones[n]
        pb.rotation_quaternion = _q(n, pose.get(n, []))
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=n)
    pv = ARM.pose.bones["pelvis"]
    off = Vector(pose.get("_pelvis", (0, 0, 0)))
    pv.location = REST["pelvis"].inverted() @ off
    rt = ARM.pose.bones["root"]
    rt.location = REST["root"].inverted() @ Vector(pose.get("_root", (0, 0, 0)))
    rt.rotation_quaternion = _q("root", pose.get("root", []))
    if pose.get("_ground", False):
        # plant the lowest foot point (heel / ball / toe) on the floor by moving the pelvis
        rt.location = (0, 0, 0)
        bpy.context.view_layer.update()
        low = 1e9
        for s_ in ("l", "r"):
            an = ARM.pose.bones["foot_" + s_].head
            bl = ARM.pose.bones["ball_" + s_].head
            tp = ARM.pose.bones["ball_" + s_].tail
            low = min(low, an.z - GROUND["ankle"], bl.z - GROUND["ball"], tp.z - GROUND["toe"])
        off = off + Vector((0, 0, -low + pose.get("_lift", 0.0)))
        pv.location = REST["pelvis"].inverted() @ off
        rt.location = REST["root"].inverted() @ Vector(pose.get("_root", (0, 0, 0)))
    for s_ in ("l", "r"):
        spec = pose.get("ik_" + s_)
        if spec is not None:
            solve_arm(s_, *spec)
            for n in ("upperarm_" + s_, "lowerarm_" + s_):
                ARM.pose.bones[n].keyframe_insert("rotation_quaternion", frame=frame, group=n)
    pv.keyframe_insert("location", frame=frame, group="pelvis")
    rt.keyframe_insert("location", frame=frame, group="root")
    rt.keyframe_insert("rotation_quaternion", frame=frame, group="root")
    fg = fingers or {}
    for s in ("l", "r"):
        c = fg.get(s, 12.0)
        spread = {"index": -6, "middle": 0, "ring": 6, "pinky": 10}
        for f in ("index", "middle", "ring", "pinky"):
            for i in (1, 2, 3):
                n = "%s_0%d_%s" % (f, i, s)
                # curl about the finger's own bend axis (armature y for T-pose fingers pointing +-x)
                rots = [("y", c * (1.0 if s == "l" else -1.0))]
                if i == 1:
                    rots = [("z", spread[f] * (1 if s == "l" else -1))] + rots
                pb = ARM.pose.bones[n]
                pb.rotation_quaternion = _q(n, rots)
                pb.keyframe_insert("rotation_quaternion", frame=frame, group=n)
        for i in (1, 2, 3):
            n = "thumb_0%d_%s" % (i, s)
            pb = ARM.pose.bones[n]
            pb.rotation_quaternion = _q(n, [("y", c * 0.4 * (1 if s == "l" else -1))])
            pb.keyframe_insert("rotation_quaternion", frame=frame, group=n)


def finish(act, loop=False, interp="BEZIER"):
    for fc in clib.action_fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = interp
            kp.easing = "AUTO"
    ARM.animation_data.action = None


def clip(name, keys, loop=False, fingers=None):
    """keys: [(frame, pose[, fingers])]"""
    act = new_action(name)
    for k in keys:
        f, p = k[0], k[1]
        key(f, p, fingers=k[2] if len(k) > 2 else fingers)
    finish(act, loop)
    return act


# ------------------------------------------------------------------------------------------------
# library adaptation
# ------------------------------------------------------------------------------------------------
def leg_ratio():
    b = ARM.data.bones
    new = b["thigh_l"].length + b["calf_l"].length
    return new / (0.400 + 0.429)


def adapt_library(arm, who, meta):
    """Pelvis translation keys scaled by the leg ratio; Bellows: arm-out layer (clears the barrel)."""
    k = leg_ratio()
    print("LEG_RATIO", round(k, 3))
    for act in list(bpy.data.actions):
        for fc in clib.action_fcurves(act):
            if fc.data_path == 'pose.bones["pelvis"].location':
                for kp in fc.keyframe_points:
                    kp.co[1] *= k
                    kp.handle_left[1] *= k
                    kp.handle_right[1] *= k
        if who == "bellows":
            layer_rotation(act, {"upperarm_l": [("y", -40)], "upperarm_r": [("y", 40)]})


def layer_rotation(act, extra):
    """Pre-multiply keyed local rotations by an armature-axis offset (per keyframe time)."""
    fcs = {}
    for fc in clib.action_fcurves(act):
        for n in extra:
            if fc.data_path == 'pose.bones["%s"].rotation_quaternion' % n:
                fcs.setdefault(n, {})[fc.array_index] = fc
    for n, comps in fcs.items():
        if len(comps) < 4:
            continue
        frames = sorted({round(kp.co[0], 3) for c in comps.values() for kp in c.keyframe_points})
        off = local_q(n, extra[n])
        vals = []
        for f in frames:
            q = Quaternion([comps[i].evaluate(f) for i in range(4)])
            vals.append(off @ q)
        for i in range(4):
            c = comps[i]
            c.keyframe_points.clear()
            c.keyframe_points.add(len(frames))
            for j, f in enumerate(frames):
                c.keyframe_points[j].co = (f, vals[j][i])
                c.keyframe_points[j].interpolation = "LINEAR"
            c.update()


# ------------------------------------------------------------------------------------------------
# custom clips (filled in by author())
# ------------------------------------------------------------------------------------------------
def author(arm, who, meta):
    import clips_custom
    clips_custom.make(who)


def preview(arm, char, who, out, which=""):
    import clips_custom
    clips_custom.preview(arm, char, who, out, which)


# ------------------------------------------------------------------------------------------------
# 2-bone arm IK (analytic): target given relative to a bone's deformation
# ------------------------------------------------------------------------------------------------
_HINGE_SIGN = {}


def deform_point(bone, p_rest):
    """Where a point defined in REST armature space ends up if it rides on `bone` (current pose)."""
    pb = ARM.pose.bones[bone]
    return pb.matrix @ pb.bone.matrix_local.inverted() @ Vector(p_rest)


def deform_dir(bone, d_rest):
    pb = ARM.pose.bones[bone]
    return (pb.matrix.to_3x3() @ pb.bone.matrix_local.to_3x3().inverted() @ Vector(d_rest)).normalized()


def hinge_sign(side):
    if side in _HINGE_SIGN:
        return _HINGE_SIGN[side]
    b_up = ARM.data.bones["upperarm_" + side]
    u = (b_up.tail_local - b_up.head_local).normalized()
    # natural flexion: forearm swings to the front (-Y)
    f = (u + Vector((0, -1.0, 0))).normalized()
    hinge = u.cross(f).normalized()
    bx = b_up.matrix_local.to_3x3().col[0]
    _HINGE_SIGN[side] = 1.0 if hinge.dot(bx) > 0 else -1.0
    return _HINGE_SIGN[side]


def solve_arm(side, bone, p_rest, pole_rest, rel_pole=True):
    """Place the wrist (hand bone head) at p_rest carried by `bone`; the elbow bends toward pole_rest
    (a direction in rest armature axes, carried by the root)."""
    bpy.context.view_layer.update()
    up = ARM.pose.bones["upperarm_" + side]
    lo = ARM.pose.bones["lowerarm_" + side]
    hd = ARM.pose.bones["hand_" + side]
    T = deform_point(bone, p_rest)
    pole = deform_dir("root", pole_rest)
    S = up.head.copy()
    L1 = (lo.bone.head_local - up.bone.head_local).length
    L2 = (hd.bone.head_local - lo.bone.head_local).length
    D = T - S
    d = max(1e-4, min(D.length, (L1 + L2) * 0.995))
    dv = D.normalized()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    pp = pole - dv * pole.dot(dv)
    if pp.length < 1e-5:
        pp = Vector((0, 0, -1)) - dv * (-dv.z)
    pp.normalize()
    E = S + dv * a + pp * h
    Tt = S + dv * d
    u = (E - S).normalized()
    f = (Tt - E).normalized()
    hinge = u.cross(f)
    if hinge.length < 1e-5:
        hinge = u.cross(pp)
    hinge = hinge.normalized() * hinge_sign(side)
    def mat(y, x, t):
        z = x.cross(y).normalized()
        x = y.cross(z).normalized()
        M = Matrix((x, y, z)).transposed().to_4x4()
        M.translation = t
        return M
    up.matrix = mat(u, hinge, S)
    up.location = (0, 0, 0)
    bpy.context.view_layer.update()
    lo.matrix = mat(f, hinge, lo.head.copy())
    lo.location = (0, 0, 0)
    bpy.context.view_layer.update()
