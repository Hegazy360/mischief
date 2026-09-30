"""Pose language for 3D clips (look A's `toy_pose.py` + look B's `poses.py`, merged) — pure mathutils, no depsgraph.

A **pose** is a dict:
  * `"<bone>": [(axis, deg), ...]` — rotations about ARMATURE axes, applied in order, as if the parent were at rest
    (standard FK: the child inherits its parent's rotation). Or `{"r": [...], "s": 1.0 | (x, y, z), "t": (x, y, z)}`
    with a bone-space scale (extra / prop bones only survive the bake) and an armature-space offset.
  * `"_root": (x, y, z)` / `"_pelvis": (x, y, z)` — armature-space offsets of the root / the pelvis (metres).
Armature axes (Blender, the rig's own frame): **+x = the character's LEFT, -y = her FRONT, +z = up**.
Sign cheat-sheet (left side; `mirror()` gives the right side):
  spine / neck / Head  +x = bend forward     y = lean sideways (+ = to her LEFT)   z = turn (+ = to her LEFT)
  thigh                -x = knee up (hip flexion)      calf +x = bend the knee     foot +x = point the toes
  upperarm_l (T-pose)  +y = arm down from the T        -z = arm forward             lowerarm_l -z = elbow bend
Bones the pose does not name stay at rest. Helpers: `sym` (copy *_l to *_r mirrored), `mirror`, `swap` (sides, for
the second half of a cycle), `merge`, `curl` (fingers), `add` (compose two poses: b applied after a), `scaled` (scale
every angle).

`Skel` holds the armature's rest data and evaluates poses with its own forward kinematics (Blender pose-bone
semantics: `world = world(parent) @ rest_rel @ basis`), so IK, foot grounding and look-at run per frame without
touching the scene. `Pose` (below) is one evaluated frame: per-bone basis (loc, rot, scale) + world matrices.
"""
import math
from mathutils import Vector, Quaternion, Matrix

AX = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}
FRONT = Vector((0, -1, 0))          # the character's front in armature space
UP = Vector((0, 0, 1))

# ------------------------------------------------------------------------------------------------
# pose dict helpers
# ------------------------------------------------------------------------------------------------


def rot_q(rots):
    """Quaternion of a rotation list [(axis, deg), ...] about armature axes (first entry applied first)."""
    R = Quaternion()
    for ax, deg in rots or ():
        R = Quaternion(AX[ax], math.radians(deg)) @ R
    return R


def _spec(v):
    """(rots, scale, offset) of a pose entry."""
    if v is None:
        return [], None, None
    if isinstance(v, dict):
        return list(v.get("r", [])), v.get("s"), v.get("t")
    if isinstance(v, Quaternion):
        return v, None, None
    return list(v), None, None


def mirror(rots):
    """Left <-> right of a rotation list (about Y and Z flip sign, about X keep), or of a {"r", "s", "t"} entry."""
    if isinstance(rots, dict):
        out = dict(rots)
        out["r"] = mirror(rots.get("r", []))
        if rots.get("t") is not None:
            x, y, z = rots["t"]
            out["t"] = (-x, y, z)
        return out
    return [(ax, deg if ax == "x" else -deg) for ax, deg in rots]


def other_side(bone):
    if bone.endswith("_l"):
        return bone[:-2] + "_r"
    if bone.endswith("_r"):
        return bone[:-2] + "_l"
    return bone


def sym(pose):
    """Copy every *_l entry to *_r (mirrored) unless *_r is given."""
    out = dict(pose)
    for n, r in list(pose.items()):
        if n.endswith("_l") and (n[:-2] + "_r") not in pose:
            out[n[:-2] + "_r"] = mirror(r)
    return out


def swap(pose):
    """Swap sides (the second half of a walk cycle): *_l <-> *_r mirrored, centre bones and offsets mirrored."""
    q = {}
    for n, r in pose.items():
        if n.startswith("_"):
            q[n] = (-r[0], r[1], r[2]) if n in ("_root", "_pelvis") else r
        elif n.endswith("_l") or n.endswith("_r"):
            q[other_side(n)] = mirror(r)
        else:
            q[n] = mirror(r)
    return q


def merge(*poses):
    """Later poses win bone by bone."""
    out = {}
    for p in poses:
        if p:
            out.update(p)
    return out


def add(a, b):
    """Compose: every bone of b applied after a's rotation (lists concatenate); offsets add."""
    out = dict(a)
    for k, v in b.items():
        if k.startswith("_"):
            if k in ("_root", "_pelvis") and k in out:
                out[k] = tuple(x + y for x, y in zip(out[k], v))
            else:
                out[k] = v
            continue
        ra, sa, ta = _spec(out.get(k))
        rb, sb, tb = _spec(v)
        if isinstance(ra, Quaternion) or isinstance(rb, Quaternion):
            raise ValueError("add(): quaternion entries cannot be composed")
        e = {"r": list(ra) + list(rb)}
        if sb is not None or sa is not None:
            e["s"] = sb if sb is not None else sa
        if ta is not None or tb is not None:
            ta = ta or (0, 0, 0)
            tb = tb or (0, 0, 0)
            e["t"] = tuple(x + y for x, y in zip(ta, tb))
        out[k] = e if ("s" in e or "t" in e) else e["r"]
    return out


def scaled(pose, k, bones=None):
    """Every rotation angle (of `bones`, default all) multiplied by k; offsets too."""
    out = {}
    for n, v in pose.items():
        if bones is not None and n not in bones:
            out[n] = v
            continue
        if n in ("_root", "_pelvis"):
            out[n] = tuple(x * k for x in v)
        elif n.startswith("_"):
            out[n] = v
        elif isinstance(v, dict):
            e = dict(v)
            e["r"] = [(ax, d * k) for ax, d in v.get("r", [])]
            out[n] = e
        else:
            out[n] = [(ax, d * k) for ax, d in v]
    return out


def curl(side, a, thumb=None, fingers=("index", "middle", "ring", "pinky"), spread=0.0):
    """Finger curl (degrees per joint), +a = toward the palm; `spread` fans the fingers (deg, index out / pinky out)."""
    s = 1 if side == "l" else -1
    fan = {"index": -1.0, "middle": 0.0, "ring": 0.6, "pinky": 1.0}
    out = {}
    for f in fingers:
        for i in (1, 2, 3):
            r = [("y", s * a * (0.7 if i == 1 else 1.0))]
            if i == 1 and spread:
                r = [("z", s * spread * fan[f])] + r
            out["%s_%02d_%s" % (f, i, side)] = r
    if thumb is not None:
        for i in (1, 2, 3):
            out["thumb_%02d_%s" % (i, side)] = [("z", -s * thumb * 0.5), ("y", s * thumb * 0.5)]
    return out


# ------------------------------------------------------------------------------------------------
# quaternion helpers (extrapolating slerp so back / elastic eases overshoot)
# ------------------------------------------------------------------------------------------------


def qslerp(a, b, t):
    """Slerp a -> b at t (t may lie outside [0, 1]: extrapolates along the same great circle)."""
    if a.dot(b) < 0.0:
        b = -b
    d = a.inverted() @ b
    d.normalize()
    w = max(-1.0, min(1.0, d.w))
    ang = 2.0 * math.acos(w)
    if ang < 1e-9:
        return a.copy()
    axis = Vector((d.x, d.y, d.z))
    if axis.length < 1e-12:
        return a.copy()
    axis.normalize()
    return a @ Quaternion(axis, ang * t)


def qangle_deg(a, b):
    """Rotation angle between two quaternions (degrees, 0..180)."""
    d = a.rotation_difference(b)
    w = max(-1.0, min(1.0, abs(d.w)))
    return math.degrees(2.0 * math.acos(w))


def swing(u, v):
    """Minimal rotation taking direction u to direction v."""
    u = u.normalized()
    v = v.normalized()
    return u.rotation_difference(v)


# ------------------------------------------------------------------------------------------------
# the skeleton + FK
# ------------------------------------------------------------------------------------------------
UAL_BONES = [
    "root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
    "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
    "index_01_l", "index_02_l", "index_03_l", "index_04_leaf_l", "middle_01_l", "middle_02_l", "middle_03_l",
    "middle_04_leaf_l", "pinky_01_l", "pinky_02_l", "pinky_03_l", "pinky_04_leaf_l", "ring_01_l", "ring_02_l",
    "ring_03_l", "ring_04_leaf_l", "thumb_01_l", "thumb_02_l", "thumb_03_l", "thumb_04_leaf_l",
    "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
    "index_01_r", "index_02_r", "index_03_r", "index_04_leaf_r", "middle_01_r", "middle_02_r", "middle_03_r",
    "middle_04_leaf_r", "pinky_01_r", "pinky_02_r", "pinky_03_r", "pinky_04_leaf_r", "ring_01_r", "ring_02_r",
    "ring_03_r", "ring_04_leaf_r", "thumb_01_r", "thumb_02_r", "thumb_03_r", "thumb_04_leaf_r",
    "thigh_l", "calf_l", "foot_l", "ball_l", "ball_leaf_l", "thigh_r", "calf_r", "foot_r", "ball_r", "ball_leaf_r",
]
UAL_SET = set(UAL_BONES)


class Skel:
    """Rest skeleton (Blender armature space) + forward kinematics.

    bones: list of (name, parent or None, matrix_local 4x4, tail Vector) in parent-first order."""

    def __init__(self, bones):
        self.names = [b[0] for b in bones]
        self.parent = {b[0]: b[1] for b in bones}
        self.rest = {b[0]: b[2].copy() for b in bones}
        self.tail = {b[0]: Vector(b[3]) for b in bones}
        self.rest_q = {n: m.to_quaternion() for n, m in self.rest.items()}
        self.rest_rel = {}
        for n in self.names:
            p = self.parent[n]
            self.rest_rel[n] = self.rest[n].copy() if p is None else self.rest[p].inverted() @ self.rest[n]
        self.children = {n: [] for n in self.names}
        for n in self.names:
            if self.parent[n] is not None:
                self.children[self.parent[n]].append(n)
        self.index = {n: i for i, n in enumerate(self.names)}
        self._soles = None

    @classmethod
    def from_armature(cls, arm):
        order = []

        def visit(b):
            order.append(b)
            for c in b.children:
                visit(c)
        for b in arm.data.bones:
            if b.parent is None:
                visit(b)
        return cls([(b.name, b.parent.name if b.parent else None, b.matrix_local.copy(), b.tail_local.copy()) for b in order])

    def has(self, n):
        return n in self.rest

    def head(self, n):
        return self.rest[n].translation.copy()

    def extras(self):
        """Non-UAL bones (props, FX, jiggle, face)."""
        return [n for n in self.names if n not in UAL_SET]

    # --- pose dict -> basis -------------------------------------------------------------------
    def basis_rot(self, n, R):
        """Basis quaternion of a rotation R about armature axes (parent at rest)."""
        M = self.rest_q[n]
        return M.inverted() @ R @ M

    def basis_loc(self, n, off):
        return self.rest_q[n].inverted() @ Vector(off)

    # --- FK ------------------------------------------------------------------------------------
    def fk(self, basis):
        """basis: {bone: (loc Vector, rot Quaternion, scale Vector)} (missing = rest) -> {bone: Matrix 4x4}."""
        world = {}
        ident = Matrix.Identity(4)
        for n in self.names:
            b = basis.get(n)
            if b is None:
                B = ident
            else:
                loc, rot, sc = b
                B = Matrix.Translation(loc) @ rot.to_matrix().to_4x4() @ Matrix.Diagonal((sc[0], sc[1], sc[2], 1.0))
            p = self.parent[n]
            world[n] = (self.rest_rel[n] @ B) if p is None else (world[p] @ self.rest_rel[n] @ B)
        return world

    def fk_from(self, basis, world, start):
        """Recompute world matrices of `start` and its descendants in place."""
        stack = [start]
        ident = Matrix.Identity(4)
        while stack:
            n = stack.pop()
            b = basis.get(n)
            if b is None:
                B = ident
            else:
                loc, rot, sc = b
                B = Matrix.Translation(loc) @ rot.to_matrix().to_4x4() @ Matrix.Diagonal((sc[0], sc[1], sc[2], 1.0))
            p = self.parent[n]
            world[n] = (self.rest_rel[n] @ B) if p is None else (world[p] @ self.rest_rel[n] @ B)
            stack.extend(self.children[n])

    def carried(self, world, bone, p_rest):
        """Where a point given in REST armature space ends up when it rides on `bone`."""
        return world[bone] @ self.rest[bone].inverted() @ Vector(p_rest)

    def carried_dir(self, world, bone, d_rest):
        return (world[bone].to_3x3() @ self.rest[bone].to_3x3().inverted() @ Vector(d_rest)).normalized()

    # --- feet ------------------------------------------------------------------------------------
    def soles(self):
        """Per side: [(bone, rest point)] for heel, ball and toe — the floor points under the ankle, the ball joint
        and the toe tip at rest (z = 0); a sole point's height in a pose is its clearance above the support."""
        if self._soles is None:
            out = {}
            for s in ("l", "r"):
                foot, ball = "foot_" + s, "ball_" + s
                leaf = "ball_leaf_" + s
                toe = self.head(leaf) if self.has(leaf) else self.tail[ball]
                heel = self.head(foot)
                out[s] = [(foot, Vector((heel.x, heel.y + 0.02, 0.0))), (foot, Vector((self.head(ball).x, self.head(ball).y, 0.0))),
                          (ball, Vector((toe.x, toe.y, 0.0)))]
            self._soles = out
        return self._soles

    def sole_points(self, world, side):
        return [self.carried(world, b, p) for b, p in self.soles()[side]]

    def lowest_sole(self, world):
        return min(p.z for s in ("l", "r") for p in self.sole_points(world, s))


# ------------------------------------------------------------------------------------------------
# one evaluated frame
# ------------------------------------------------------------------------------------------------
class Pose:
    """Per-bone basis (loc, rot, scale) and the FK world matrices of one frame."""

    def __init__(self, skel):
        self.skel = skel
        self.basis = {}
        self.world = None

    @classmethod
    def from_dict(cls, skel, d):
        p = cls(skel)
        for n, v in d.items():
            if n.startswith("_"):
                continue
            if not skel.has(n):
                continue
            rots, s, t = _spec(v)
            R = rots if isinstance(rots, Quaternion) else rot_q(rots)
            loc = skel.basis_loc(n, t) if t is not None else Vector()
            sc = Vector((1, 1, 1)) if s is None else (Vector(s) if isinstance(s, (tuple, list)) else Vector((s, s, s)))
            p.basis[n] = (loc, skel.basis_rot(n, R), sc)
        for key, bone in (("_pelvis", "pelvis"), ("_root", "root")):
            if key in d and skel.has(bone):
                loc, rot, sc = p.basis.get(bone, (Vector(), Quaternion(), Vector((1, 1, 1))))
                p.basis[bone] = (loc + skel.basis_loc(bone, d[key]), rot, sc)
        return p

    def copy(self):
        q = Pose(self.skel)
        q.basis = {n: (l.copy(), r.copy(), s.copy()) for n, (l, r, s) in self.basis.items()}
        q.world = None if self.world is None else {n: m.copy() for n, m in self.world.items()}
        return q

    def get(self, n):
        return self.basis.get(n, (Vector(), Quaternion(), Vector((1, 1, 1))))

    def set_rot(self, n, q):
        loc, _, sc = self.get(n)
        self.basis[n] = (loc, q, sc)

    def set_loc(self, n, v):
        _, rot, sc = self.get(n)
        self.basis[n] = (Vector(v), rot, sc)

    def solve(self):
        self.world = self.skel.fk(self.basis)
        return self.world

    def update_from(self, bone):
        if self.world is None:
            self.solve()
        else:
            self.skel.fk_from(self.basis, self.world, bone)

    def pos(self, bone):
        return self.world[bone].translation.copy()

    def world_rot(self, bone):
        return self.world[bone].to_quaternion()

    def set_world_rot(self, bone, q_world):
        """Set a bone's basis so its world rotation becomes q_world (its head stays where FK puts it)."""
        sk = self.skel
        p = sk.parent[bone]
        parent_q = Quaternion() if p is None else self.world[p].to_quaternion()
        rel_q = sk.rest_rel[bone].to_quaternion()
        self.set_rot(bone, (parent_q @ rel_q).inverted() @ q_world)
        self.update_from(bone)

    def pelvis_offset(self):
        """The pelvis' armature-space offset from rest (its basis location mapped back)."""
        loc, _, _ = self.get("pelvis")
        return self.skel.rest_q["pelvis"] @ loc

    def add_pelvis_offset(self, d):
        loc, rot, sc = self.get("pelvis")
        self.basis["pelvis"] = (loc + self.skel.basis_loc("pelvis", d), rot, sc)
        self.update_from("pelvis")


def blend_pose(a, b, t):
    """Per-bone interpolation of two evaluated poses (extrapolates for t outside [0, 1]); world not solved."""
    out = Pose(a.skel)
    keys = set(a.basis) | set(b.basis)
    for n in keys:
        la, ra, sa = a.get(n)
        lb, rb, sb = b.get(n)
        out.basis[n] = (la.lerp(lb, t), qslerp(ra, rb, t), sa.lerp(sb, t))
    return out


# ------------------------------------------------------------------------------------------------
# IK
# ------------------------------------------------------------------------------------------------
_HINGE = {}


def arm_hinge_sign(skel, side):
    key = (id(skel), side)
    if key in _HINGE:
        return _HINGE[key]
    up = "upperarm_" + side
    u = (skel.head("lowerarm_" + side) - skel.head(up)).normalized()
    f = (u + FRONT).normalized()                # natural flexion: the forearm swings to the front
    hinge = u.cross(f).normalized()
    bx = skel.rest[up].to_3x3().col[0]
    _HINGE[key] = 1.0 if hinge.dot(bx) > 0 else -1.0
    return _HINGE[key]


def _frame(y, x):
    """Rotation whose local Y = y and local X ~ x (orthonormalised)."""
    y = y.normalized()
    z = x.cross(y).normalized()
    x = y.cross(z).normalized()
    return Matrix((x, y, z)).transposed().to_quaternion()


def solve_arm(pose, side, target, pole, hand_world=None, effector=None, iters=8):
    """Analytic 2-bone arm IK (look B's): the wrist (hand bone head) — or `effector`, a point in REST armature space
    riding on the hand (e.g. the palm centre) — to `target` (armature space); the elbow bends toward `pole` (a
    direction). `hand_world`: optional world rotation of the hand (a Quaternion about armature axes applied to its rest
    orientation) — else the hand keeps its basis relative to the forearm. Returns the remaining error (m)."""
    sk = pose.skel
    up, lo, hd = "upperarm_" + side, "lowerarm_" + side, "hand_" + side
    if pose.world is None:
        pose.solve()
    L1 = (sk.head(lo) - sk.head(up)).length
    L2 = (sk.head(hd) - sk.head(lo)).length
    goal = Vector(target)
    wrist_goal = goal.copy()
    err = 0.0
    for _ in range(max(1, iters)):
        S = pose.pos(up)
        D = wrist_goal - S
        d = max(1e-4, min(D.length, (L1 + L2) * 0.9995))
        dv = D.normalized()
        a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
        h = math.sqrt(max(L1 * L1 - a * a, 0.0))
        pv = Vector(pole)
        pp = pv - dv * pv.dot(dv)
        if pp.length < 1e-6:
            pp = Vector((0, 0, -1)) - dv * (-dv.z)
        pp.normalize()
        E = S + dv * a + pp * h
        T = S + dv * d
        u = (E - S).normalized()
        f = (T - E).normalized()
        hinge = u.cross(f)
        if hinge.length < 1e-6:
            hinge = u.cross(pp)
        hinge = hinge.normalized() * arm_hinge_sign(sk, side)
        pose.set_world_rot(up, _frame(u, hinge))
        pose.set_world_rot(lo, _frame(f, hinge))
        if hand_world is not None:
            pose.set_world_rot(hd, hand_world @ sk.rest_q[hd])
        if effector is None:
            err = (pose.pos(hd) - goal).length
            break
        eff = sk.carried(pose.world, hd, effector)
        err = (eff - goal).length
        if err < 1e-4:
            break
        wrist_goal = wrist_goal + (goal - eff)
    return err


def solve_leg(pose, side, ankle_target, foot_world=None, knee_dir=None):
    """2-bone leg IK keeping the FK knee plane: the ankle (foot bone head) to `ankle_target`; the thigh and calf
    swing minimally (twist kept); `foot_world` (Quaternion) sets the foot's world rotation (planted feet)."""
    sk = pose.skel
    th, ca, ft = "thigh_" + side, "calf_" + side, "foot_" + side
    if pose.world is None:
        pose.solve()
    L1 = (sk.head(ca) - sk.head(th)).length
    L2 = (sk.head(ft) - sk.head(ca)).length
    H = pose.pos(th)
    K0 = pose.pos(ca)
    A0 = pose.pos(ft)
    T = Vector(ankle_target)
    D = T - H
    d = max(1e-4, min(D.length, (L1 + L2) * 0.9995))
    dv = D.normalized()
    # the knee plane: the FK knee's offset from the hip-ankle line (or a given direction)
    kd = Vector(knee_dir) if knee_dir is not None else (K0 - (H + (A0 - H).normalized() * (K0 - H).dot((A0 - H).normalized())))
    pp = kd - dv * kd.dot(dv)
    if pp.length < 1e-6:
        pp = FRONT - dv * FRONT.dot(dv)
    pp.normalize()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    E = H + dv * a + pp * h
    q_th = swing(K0 - H, E - H) @ pose.world_rot(th)
    pose.set_world_rot(th, q_th)
    K1 = pose.pos(ca)
    A1 = pose.pos(ft)
    q_ca = swing(A1 - K1, (H + dv * d) - K1) @ pose.world_rot(ca)
    pose.set_world_rot(ca, q_ca)
    if foot_world is not None:
        pose.set_world_rot(ft, foot_world)
    return (pose.pos(ft) - T).length


# ------------------------------------------------------------------------------------------------
# look-at (head + neck toward a point)
# ------------------------------------------------------------------------------------------------
def face_dir(pose, bone="Head"):
    """The face's forward direction (armature space) for a head bone in `pose`."""
    return pose.skel.carried_dir(pose.world, bone, FRONT)


def look_at(pose, point, weight=1.0, bones=("spine_03", "neck_01", "Head"), share=(0.15, 0.3, 0.55), max_deg=80.0):
    """Turn the chain so the face points at `point` (armature space), `share` of the swing per bone."""
    if weight <= 0.0:
        return
    if pose.world is None:
        pose.solve()
    head = bones[-1]
    eye = pose.pos(head) + Vector((0, 0, 0.1))
    for b, k in zip(bones, share):
        if not pose.skel.has(b):
            continue
        fd = face_dir(pose, head)
        want = (Vector(point) - eye).normalized()
        q = swing(fd, want)
        ang = math.degrees(2 * math.acos(max(-1.0, min(1.0, abs(q.w)))))
        lim = min(ang, max_deg)
        frac = 0.0 if ang < 1e-6 else (lim / ang)
        rel_k = min(1.0, k / max(1e-6, sum(share[bones.index(b):]))) * frac * weight
        qp = Quaternion().slerp(q, rel_k)
        pose.set_world_rot(b, qp @ pose.world_rot(b))
