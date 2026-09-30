"""UAL retarget: the CC0 Quaternius Universal Animation Library clips (tools/art3d/vendor/ual/UAL{1,2}_Standard.glb,
86 clips on the 65-bone skeleton) onto a rig with the same bone names (UAL rest directions and rolls kept, lengths
re-proportioned — index §7.3).

Per frame (resampled to 60 fps) every UAL bone's world rotation offset from its rest (armature axes) is carried onto
the rig bone's rest (identical to copying bone-space rotations when the rests match; robust when an importer
re-orients a bone); the pelvis (and root) translation offsets are scaled by the leg ratio (rig thigh + calf / UAL
thigh + calf). Extra bones (props, FX, jiggle, face) stay at rest. The rig's default layers (`anim.layers`) and the
clip's own layers (`mime`, `damp_head`) are applied by the Clip afterwards, like on every custom clip.
"""
import os
import bpy
from mathutils import Vector, Quaternion, Matrix

from . import pose as P
from .paths import repo_root

LIBS = {"UAL1": "tools/art3d/vendor/ual/UAL1_Standard.glb", "UAL2": "tools/art3d/vendor/ual/UAL2_Standard.glb"}


def _fcurves(act):
    try:
        return list(act.fcurves)
    except Exception:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
        return out


class Library:
    """One imported UAL glb: its armature (renamed UAL1/UAL2, never exported), rest skeleton and actions."""

    def __init__(self, name):
        self.name = name
        path = os.path.join(repo_root(), LIBS[name])
        if not os.path.exists(path):
            raise FileNotFoundError(path)
        before_o = set(bpy.data.objects)
        before_a = set(bpy.data.actions)
        bpy.context.scene.render.fps = 60
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before_o]
        arm = [o for o in new if o.type == "ARMATURE"][0]
        for o in new:
            if o is not arm:
                bpy.data.objects.remove(o, do_unlink=True)
        arm.name = "UAL_" + name
        self.arm = arm
        self.skel = P.Skel.from_armature(arm)
        self.actions = {}
        for a in set(bpy.data.actions) - before_a:
            base = a.name.split(".")[0]
            a.use_fake_user = True
            if base not in self.actions:
                self.actions[base] = a
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"

    def names(self):
        return sorted(self.actions)

    def frames(self, clip):
        a = self.actions[clip]
        f0, f1 = a.frame_range
        return int(round(f0)), int(round(f1))

    def sample(self, clip):
        """[{bone: (loc, rot, scale)}] basis per integer frame from the action's first to last frame."""
        a = self.actions.get(clip)
        if a is None:
            raise KeyError("UAL %s has no clip '%s' (have: %s)" % (self.name, clip, ", ".join(self.names())))
        chans = {}
        for fc in _fcurves(a):
            dp = fc.data_path
            if not dp.startswith('pose.bones["'):
                continue
            bone = dp[len('pose.bones["'):dp.index('"]')]
            prop = dp.rsplit(".", 1)[1]
            chans.setdefault(bone, {}).setdefault(prop, {})[fc.array_index] = fc
        f0, f1 = self.frames(clip)
        out = []
        for f in range(f0, f1 + 1):
            fr = {}
            for bone, props in chans.items():
                loc = Vector([props["location"][i].evaluate(f) if "location" in props and i in props["location"] else 0.0 for i in range(3)])
                if "rotation_quaternion" in props:
                    rq = props["rotation_quaternion"]
                    rot = Quaternion([rq[i].evaluate(f) if i in rq else (1.0 if i == 0 else 0.0) for i in range(4)])
                    rot.normalize()
                else:
                    rot = Quaternion()
                sc = Vector([props["scale"][i].evaluate(f) if "scale" in props and i in props["scale"] else 1.0 for i in range(3)])
                fr[bone] = (loc, rot, sc)
            out.append(fr)
        return out


def leg_ratio(src, dst):
    def leg(sk):
        return (sk.head("calf_l") - sk.head("thigh_l")).length + (sk.head("foot_l") - sk.head("calf_l")).length
    return leg(dst) / leg(src)


def retarget(lib, clip, dst):
    """UAL clip -> per-frame basis on skeleton `dst` (dict per frame). Returns (frames, leg_ratio)."""
    src = lib.skel
    k = leg_ratio(src, dst)
    samples = lib.sample(clip)
    out = []
    for s in samples:
        ws = src.fk({n: s.get(n, (Vector(), Quaternion(), Vector((1, 1, 1)))) for n in src.names})
        wd = {}
        basis = {}
        for n in dst.names:
            p = dst.parent[n]
            parent_w = Matrix.Identity(4) if p is None else wd[p]
            rest_rel = dst.rest_rel[n]
            if n in P.UAL_SET and src.has(n):
                D = ws[n].to_quaternion() @ src.rest_q[n].inverted()      # world rotation offset from rest
                want = D @ dst.rest_q[n]
                q = (parent_w.to_quaternion() @ rest_rel.to_quaternion()).inverted() @ want
                loc = Vector()
                if n in ("pelvis", "root") and n in s:
                    # the offset in armature axes (parent at rest), scaled by the leg ratio, back into bone space
                    v = src.rest_q[n] @ s[n][0]
                    loc = dst.rest_q[n].inverted() @ (v * k)
                basis[n] = (loc, q, Vector((1, 1, 1)))
            else:
                basis[n] = (Vector(), Quaternion(), Vector((1, 1, 1)))
            l, r, sc = basis[n]
            B = Matrix.Translation(l) @ r.to_matrix().to_4x4()
            wd[n] = parent_w @ rest_rel @ B
        out.append(basis)
    return out, k
