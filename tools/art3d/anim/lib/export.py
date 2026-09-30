"""Blender side of the bake: import the rig's armature, key one action from evaluated frames, export the glb, write
the sidecar and the bake log."""
import json, os, time
import bpy
from mathutils import Vector, Quaternion

from . import pose as P
from . import clip as C


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 60
    bpy.context.scene.render.fps_base = 1.0


def import_rig(path):
    """The rig's armature (object 'Armature') from its glb; meshes and actions removed, the pose reset to rest."""
    if not os.path.exists(path):
        raise FileNotFoundError("rig glb not found: %s (the cast task's game/art3d/chars/<rig>/<rig>.glb, or pass "
                                "RIG_GLB=/abs/stand_in.glb to bake.sh)" % path)
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=path)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not arms:
        raise RuntimeError("%s has no armature" % path)
    arm = arms[0]
    for o in list(bpy.data.objects):
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    arm.name = "Armature"
    arm.data.name = "Armature"
    arm.data.pose_position = "POSE"
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    return arm


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


_LINEAR = None


def _linear_index():
    global _LINEAR
    if _LINEAR is None:
        items = bpy.types.Keyframe.bl_rna.properties["interpolation"].enum_items
        _LINEAR = [i for i, it in enumerate(items) if it.identifier == "LINEAR"][0]
    return _LINEAR


def write_action(arm, skel, clip, frames):
    """One action named after the clip: every bone keyed on every frame (linear), quaternion signs continuous;
    scale channels only on bones whose scale leaves 1."""
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    act = bpy.data.actions.new(clip.short)
    arm.animation_data_create()
    arm.animation_data.action = act
    n_f = len(frames)
    scaled = set()
    for n in skel.names:
        for fr in frames:
            s = fr.get(n)[2]
            if abs(s.x - 1) > 1e-6 or abs(s.y - 1) > 1e-6 or abs(s.z - 1) > 1e-6:
                scaled.add(n)
                break
    for n in skel.names:
        pb = arm.pose.bones[n]
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=0, group=n)
        pb.keyframe_insert("rotation_quaternion", frame=0, group=n)
        if n in scaled:
            pb.keyframe_insert("scale", frame=0, group=n)
    fcs = {(fc.data_path, fc.array_index): fc for fc in _fcurves(act)}
    lin = _linear_index()
    for n in skel.names:
        locs, rots, scs = [], [], []
        prev = None
        for fr in frames:
            l, r, s = fr.get(n)
            r = r.normalized()
            if prev is not None and prev.dot(r) < 0:
                r = -r
            prev = r
            locs.append(l)
            rots.append(r)
            scs.append(s)
        chans = [("location", 3, lambda i, k: locs[i][k]), ("rotation_quaternion", 4, lambda i, k: rots[i][k])]
        if n in scaled:
            chans.append(("scale", 3, lambda i, k: scs[i][k]))
        for prop, dim, get in chans:
            for k in range(dim):
                fc = fcs.get(('pose.bones["%s"].%s' % (n, prop), k))
                if fc is None:
                    raise RuntimeError("no fcurve for %s.%s[%d]" % (n, prop, k))
                kp = fc.keyframe_points
                kp.clear()
                kp.add(n_f)
                co = []
                for i in range(n_f):
                    co += [float(i), float(get(i, k))]
                kp.foreach_set("co", co)
                kp.foreach_set("interpolation", [lin] * n_f)
                fc.update()
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = n_f - 1
    return act


def export(arm, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
              export_animations=True, export_skins=True, export_materials="NONE",
              export_animation_mode="ACTIVE_ACTIONS", export_optimize_animation_size=False, export_def_bones=False,
              export_frame_range=False, export_force_sampling=True, export_frame_step=1, export_reset_pose_bones=True,
              export_anim_single_armature=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = {k: v for k, v in kw.items() if k in props or k == "filepath"}
    bpy.ops.export_scene.gltf(**kw)
    if arm.animation_data:
        arm.animation_data.action = None


def _clean(v):
    if isinstance(v, float):
        return round(v, 4)
    if isinstance(v, dict):
        return {k: _clean(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [_clean(x) for x in v]
    return v


def write_sidecar(path, data):
    txt = json.dumps(_clean(data), indent=2, ensure_ascii=False)
    with open(path, "w") as f:
        f.write(txt + "\n")


def log_line(out_dir, text):
    with open(os.path.join(out_dir, "bake.log"), "a") as f:
        f.write("%s %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), text))


def ual_clip(ctx, ual_name, clip_id, layers, lib_hint=""):
    """A Clip from a UAL action (bake.sh --ual <clip> --as <id> [--layers a,b]): ground + auto-planted feet at the
    motion's own stance speed on locomotion loops; face / events empty (write a spec with Clip.from_ual for more)."""
    lay = [l for l in layers if l != "damp_head"]
    c = C.Clip.from_ual(ctx, clip_id, ual_name, lib=lib_hint or None, layers=lay,
                        cheat_deg=20.0 if ("Walk" in ual_name or "Jog" in ual_name or "Sprint" in ual_name) else 35.0)
    if "damp_head" in layers:
        c.custom(_damp_head(c.ual_basis, ctx.skel), 0, c.length)
        c.source["layers"] = list(layers)
    flight = any(w in ual_name for w in ("Jog", "Sprint", "Run", "Jump"))
    c.ground(per_frame=not flight)
    if c.loop and any(w in ual_name for w in ("Walk", "Jog", "Sprint", "Crouch_Fwd", "Run")):
        c.auto_plant()
    return c


def _damp_head(frames, skel, k=0.5, bones=("neck_01", "Head")):
    """×k head bob: neck/head rotations pulled toward their clip mean."""
    mean = {}
    for b in bones:
        if not skel.has(b):
            continue
        qs = [fr.get(b, (None, Quaternion(), None))[1] for fr in frames]
        m = qs[0].copy()
        for i, q in enumerate(qs[1:], 2):
            m = P.qslerp(m, q, 1.0 / i)
        mean[b] = m

    def fn(pose, f):
        for b, m in mean.items():
            pose.set_rot(b, P.qslerp(m, pose.get(b)[1], k))
    return fn
