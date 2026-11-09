"""bake — render one library clip to PNG frames at its true speed. Runs inside Blender.

    blender -b --factory-startup --python-exit-code 1 -P tools/bakery/bake.py -- \
        --char assets/Knight.glb --lib assets/Rig_Medium_General.glb --clip Hit_A \
        --out /tmp/bake/knight_hit --fps 15 [--loop true] [--locomotion true] [--amount 0]

Nothing here is authored. The character and the clip are CC0 library assets; the only human input is
a frame rate and a camera angle (plus the opt-in cartoon `amount`, 0 by default). The pose is driven frame by frame straight from
the filtered arrays — no keyframes are written, so there is no interpolation to argue with and the
same command always produces the same pixels.
"""
from __future__ import annotations

import json
import math
import os
import sys

import bpy  # type: ignore
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector  # type: ignore

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import cartoon_filter as cf  # noqa: E402
import props as P  # noqa: E402


def argv() -> dict:
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out: dict = {}
    i = 0
    while i < len(raw):
        if raw[i].startswith("--"):
            key = raw[i][2:]
            if i + 1 < len(raw) and not raw[i + 1].startswith("--"):
                out[key] = raw[i + 1]
                i += 2
            else:
                out[key] = "true"
                i += 1
        else:
            i += 1
    return out


def wipe() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path: str) -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def drop_unskinned(objs: list, arm) -> list:
    """Library assets ship junk: Rogue.glb contains a stray unskinned Icosphere that renders as a grey
    blob beside the head and wrecks the camera framing. Anything without an Armature modifier bound to
    this rig is not part of the character, so the bake removes it and says so. Noticing this by eye and
    fixing it by hand in Blender is exactly the asset-debugging this pipeline exists to avoid."""
    keep, dropped = [], []
    for o in list(objs):
        if o.type != "MESH":
            keep.append(o)
            continue
        skinned = any(m.type == "ARMATURE" and m.object == arm for m in o.modifiers)
        if skinned:
            keep.append(o)
        else:
            dropped.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    if dropped:
        print(f"[bake] dropped {len(dropped)} unskinned mesh(es) from the source asset: {', '.join(dropped)}")
    return keep


def find_armature(objs: list):
    for o in objs:
        if o.type == "ARMATURE":
            return o
    return None


def find_action(name: str):
    for a in bpy.data.actions:
        if a.name == name or a.name.endswith("|" + name) or a.name.split("|")[-1] == name:
            return a
    return None


def bind_slot(arm, action) -> None:
    arm.animation_data_create()
    arm.animation_data.action = action
    # Blender 4.4+ slotted actions: an action imported for one armature carries a slot bound to THAT
    # armature. Assign the action to another rig without picking the slot and it silently does
    # nothing — the clip plays, every bone stays at rest, and every frame renders identical.
    if hasattr(arm.animation_data, "action_slot") and len(getattr(action, "slots", [])):
        arm.animation_data.action_slot = action.slots[0]


def sample_times(action, fps: float, loop: bool) -> tuple[list[float], list[float], float]:
    """Source frame positions to sample, and how long each sampled frame is on screen (seconds).

    Sampling is in REAL TIME, at the clip's own speed: the library clips are 24 fps with fractional
    lengths (Running_A is 19.2 frames = 0.8 s), so picking N integer frames and playing them at a fixed
    rate made every clip run at an invented speed. A loop is divided into equal steps that do NOT
    include the end point — the last pose of a loop is its first pose again, and sampling both put a
    stutter on every cycle. A one-shot keeps both ends: where it lands is the point of it."""
    src_fps = float(bpy.context.scene.render.fps) / float(bpy.context.scene.render.fps_base)
    f0, f1 = (float(v) for v in action.frame_range)
    dur = max(1e-3, (f1 - f0) / src_fps)
    if loop:
        count = max(2, int(round(dur * fps)))
        step = dur / count
        times = [k * step for k in range(count)]
        durs = [step] * count
    else:
        count = max(2, int(round(dur * fps)) + 1)
        step = dur / (count - 1)
        times = [k * step for k in range(count)]
        durs = [step] * count
    return [f0 + t * src_fps for t in times], durs, dur


def sample(arm, frames: list[float], bones: list[str]) -> dict:
    """Play the clip and record every bone's local transform at each requested (fractional) frame."""
    n = len(frames)
    loc = np.zeros((n, len(bones), 3))
    rot = np.zeros((n, len(bones), 4))
    scl = np.ones((n, len(bones), 3))
    world_z = np.zeros(n)
    ref = "hips" if "hips" in bones else bones[0]
    scene = bpy.context.scene
    for i, fr in enumerate(frames):
        whole = int(math.floor(fr))
        scene.frame_set(whole, subframe=fr - whole)
        bpy.context.view_layer.update()
        for b, name in enumerate(bones):
            pb = arm.pose.bones[name]
            loc[i, b] = pb.location
            q = pb.rotation_quaternion if pb.rotation_mode == "QUATERNION" else pb.matrix_basis.to_quaternion()
            rot[i, b] = (q.w, q.x, q.y, q.z)
            scl[i, b] = pb.scale
        # glTF import is Z-up, so the body's HEIGHT is world Z of a reference bone. Bone-local axes
        # mean different things per bone, so they are useless for driving squash and stretch.
        world_z[i] = (arm.matrix_world @ arm.pose.bones[ref].head).z
    return {"loc": loc, "rot": rot, "scale": scl, "n": n, "world_z": world_z}


def film_axes(angle_deg: float) -> tuple["Vector", "Vector", "Vector"]:
    """(view, right, up) for a camera orbiting the character at `angle_deg` around world Z."""
    a = math.radians(angle_deg)
    view = Vector((-math.sin(a), math.cos(a), 0.0)).normalized()
    right = view.cross(Vector((0.0, 0.0, 1.0))).normalized()
    return view, right, Vector((0.0, 0.0, 1.0))


def mesh_points(meshes: list) -> list:
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in meshes:
        if o.hide_render:
            continue                      # an expression or prop not shown in this frame
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        pts.extend(mw @ v.co for v in me.vertices)
        ev.to_mesh_clear()
    return pts


def build_world(angle_deg: float, u0: float, u1: float, v0: float, v1: float, ppm: float) -> tuple[int, int]:
    """Lights and an orthographic camera at a FIXED pixels-per-metre.

    The film window is [u0,u1] x [v0,v1] in metres on the film plane, where (0,0) is the character's
    root on the floor. Every clip of a character is rendered at the same `ppm`, so switching from walk
    to throw never changes the character's size, and the root's pixel is recorded as the clip's anchor
    so the feet never slide when clips change. Returns the render size in pixels."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    try:
        scene.eevee.taa_render_samples = 16
    except AttributeError:
        pass
    w_px = max(8, int(math.ceil((u1 - u0) * ppm)))
    h_px = max(8, int(math.ceil((v1 - v0) * ppm)))
    scene.render.resolution_x = w_px
    scene.render.resolution_y = h_px
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    # "Standard", not Blender's default AgX/Filmic: those tone-map for photoreal range and wash a
    # flat palette out (cherry red came out salmon, navy came out grey). The cast's colours are
    # picked hex values (recolour.py) and must arrive on the sprite as picked.
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # flat, even light: the read comes from the shapes, not from shading
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.62
    scene.world = world
    key = bpy.data.lights.new("key", type="SUN")
    key.energy = 1.9
    key.angle = 0.6
    ko = bpy.data.objects.new("key", key)
    ko.rotation_euler = (math.radians(55), math.radians(8), math.radians(35))
    scene.collection.objects.link(ko)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.sensor_fit = "AUTO"
    # whole pixels both ways, then the window is grown to match, so ppm stays exact
    u1 = u0 + w_px / ppm
    v1 = v0 + h_px / ppm
    cam_data.ortho_scale = max(w_px, h_px) / ppm
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    view, right, up = film_axes(angle_deg)
    target = right * ((u0 + u1) * 0.5) + up * ((v0 + v1) * 0.5)
    cam.location = target - view * 20.0
    cam.rotation_euler = view.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    return w_px, h_px


def ground_speed(arm, frames: list[float], durs: list[float], right: "Vector") -> tuple[float, int]:
    """How fast the body would travel if its planted foot did not slide (metres/s along the film),
    and which way it faces on screen (+1 right, -1 left).

    Library locomotion is in place: the hips stay put and the feet sweep backwards. Measured off the
    LOWER foot of each step (the one carrying weight), the median backward sweep is exactly the speed
    to move the sprite at so the feet stick to the floor. Guessing this number by eye is how
    moonwalking happens."""
    feet = [b for b in ("foot.l", "foot.r") if b in arm.pose.bones]
    if len(feet) < 2:
        return 0.0, 1
    scene = bpy.context.scene
    pos = []
    for fr in frames:
        whole = int(math.floor(fr))
        scene.frame_set(whole, subframe=fr - whole)
        bpy.context.view_layer.update()
        pos.append([(arm.matrix_world @ arm.pose.bones[f].head) for f in feet])
    vel = []
    n = len(frames)
    for i in range(n - 1):
        a, b = pos[i], pos[i + 1]
        lo = 0 if a[0].z <= a[1].z else 1
        if abs(a[0].z - a[1].z) < 0.01:
            continue
        vel.append((b[lo] - a[lo]).dot(right) / max(1e-6, durs[i]))
    if not vel:
        return 0.0, 1
    v = float(np.median(vel))
    # the planted foot sweeps backwards: a negative sweep means the body faces (and walks) right
    return abs(v), (1 if v < 0 else -1)


# --- props in hand (round 6) ---------------------------------------------------------------------
# A recipe's `props`: [{"item", "bone", "from", "until", "off", "rot", "scale"}]. The item is built
# by props.py in PROP SPACE (origin = grip, +Z along the handle) and parented to the bone so the
# library motion carries it. KayKit's handslot.l/.r are its weapon sockets: the prop's origin sits on
# the bone's HEAD with +Z along the bone. `off` (metres) and `rot` (degrees XYZ) adjust it in the
# bone's own axes; `from` / `until` (seconds) show it only part of the clip (picked up, thrown).

_MATS: dict = {}


def flat_material(colour: str):
    if colour in _MATS:
        return _MATS[colour]
    h = P.PALETTE[colour].lstrip("#")

    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    m = bpy.data.materials.new(f"prop_{colour}")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*(lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    _MATS[colour] = m
    return m


def attach_prop(arm, spec: dict, char_scale: float) -> list:
    bone = spec.get("bone", "handslot.r")
    if bone not in arm.data.bones:
        raise SystemExit(f"[bake] prop bone '{bone}' not in the rig")
    length = arm.data.bones[bone].length
    s = float(spec.get("scale", 1.0)) * char_scale
    basis = (Matrix.Translation(Vector(spec.get("off", (0, 0, 0))))
             @ Euler([math.radians(v) for v in spec.get("rot", (0, 0, 0))], "XYZ").to_matrix().to_4x4()
             @ Matrix.Rotation(math.radians(-90), 4, "X")          # prop +Z -> bone +Y
             @ Matrix.Diagonal((s, s, s, 1.0)))
    objs = []
    for k, (bm, colour) in enumerate(P.build(spec["item"])):
        me = bpy.data.meshes.new(f"prop_{spec['item']}_{k}")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(flat_material(colour))
        ob = bpy.data.objects.new(me.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = arm
        ob.parent_type = "BONE"
        ob.parent_bone = bone
        # bone parenting starts the child at the bone's TAIL; move it back to the head
        ob.matrix_parent_inverse = Matrix.Translation((0.0, -length, 0.0))
        ob.matrix_basis = basis
        objs.append(ob)
    return objs


def show_props(props: list, t: float) -> None:
    for spec, objs in props:
        on = float(spec.get("from", -1e9)) - 1e-6 <= t < float(spec.get("until", 1e9)) - 1e-6
        for o in objs:
            o.hide_render = not on


# --- faces (round 6) -----------------------------------------------------------------------------
# A cast model may carry several expression sets as meshes named "<Who>_Face.<expr>.<part>"
# ("all" = shown in every expression). One set is shown per frame; `face` in a recipe is either one
# expression or timed switches [[secs, expr], ...] (startle goes neutral -> shock on the jolt).


def face_sets(meshes: list) -> dict:
    sets: dict = {}
    for o in meshes:
        bits = o.name.split("_Face.", 1)
        if len(bits) == 2 and "." in bits[1]:
            sets.setdefault(bits[1].split(".", 1)[0], []).append(o)
    return sets


def face_at(face, t: float) -> str:
    if isinstance(face, str):
        return face
    cur = face[0][1]
    for at, expr in sorted(face, key=lambda k: k[0]):
        if t + 1e-6 >= at:
            cur = expr
    return cur


def show_face(sets: dict, expr: str) -> None:
    for name, objs in sets.items():
        for o in objs:
            o.hide_render = not (name == "all" or name == expr)


# --- composed clips (`--recipe`) ----------------------------------------------------------------
# The library has no statue, no look-around and no angry stomp. Rather than hand-key new motion (or
# bring back the filter the owner found wobbly), a recipe COMPOSES library material:
#   pose   — ease from a stance into one frame of any clip and hold it dead still (FREEZE statues)
#   layer  — some bones (with their children) from a second clip, time-fitted to the base loop
#   tweak  — eased extra turns on a few bones, in BODY axes, keyed in seconds
# Everything stays a library pose or a smooth blend between library poses.

_ACTION_CACHE: dict = {}


def load_action(path: str, clip: str):
    """Import a clip library for one action. Libraries share action names (Idle_A is in both the
    Medium and Large sets), so the action is picked from what THIS import added, never by name alone."""
    key = (path, clip)
    if key in _ACTION_CACHE:
        return _ACTION_CACHE[key]
    before = set(bpy.data.actions)
    objs = import_glb(path)
    new = [x for x in bpy.data.actions if x not in before]
    for act in new:
        act.use_fake_user = True
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    hit = None
    for act in new:
        # a second import of the same library comes back as "Throw.001"
        base = act.name.split("|")[-1]
        if base == clip or (base.rsplit(".", 1)[0] == clip and base.rsplit(".", 1)[-1].isdigit()):
            hit = act
    if hit is None:
        raise SystemExit(f"[bake] clip '{clip}' not in {os.path.basename(path)}: {sorted(x.name for x in new)}")
    _ACTION_CACHE[key] = hit
    return hit


def src_fps() -> float:
    return float(bpy.context.scene.render.fps) / float(bpy.context.scene.render.fps_base)


def pose_at(arm, action, secs: float, bones: list[str]) -> dict:
    bind_slot(arm, action)
    f0, f1 = (float(v) for v in action.frame_range)
    return sample(arm, [min(f1, f0 + secs * src_fps())], bones)


def ease_out(s: float) -> float:
    """Fast start, soft landing: a mime SNAPS into a pose and settles — no overshoot, no wobble.
    Quadratic, not cubic: a cubic's last step is 1.6% of the move, a frame nobody can see at 48 px
    (the validator fails it as dead); quadratic's is 6% and still lands soft."""
    return 1.0 - (1.0 - s) ** 2


def slerp(q0: np.ndarray, q1: np.ndarray, t: float) -> np.ndarray:
    a = Quaternion(tuple(q0))
    b = Quaternion(tuple(q1))
    if a.dot(b) < 0.0:
        b.negate()
    q = a.slerp(b, t)
    return np.array((q.w, q.x, q.y, q.z))


def strike(arm, bones: list[str], rest: dict, pose: dict, secs: float, hold: float, fps: float) -> tuple[dict, list[float], list[float]]:
    """Frames from the stance into the target pose (eased), the last one held for `hold` seconds."""
    a = pose_at(arm, rest["action"], rest.get("at", 0.0), bones)
    b = pose_at(arm, pose["action"], pose["at"], bones)
    k = max(2, int(round(secs * fps)))
    n = k + 1
    loc = np.zeros((n, len(bones), 3))
    rot = np.zeros((n, len(bones), 4))
    scl = np.ones((n, len(bones), 3))
    for i in range(n):
        e = ease_out(i / k)
        loc[i] = a["loc"][0] * (1 - e) + b["loc"][0] * e
        scl[i] = a["scale"][0] * (1 - e) + b["scale"][0] * e
        for j in range(len(bones)):
            rot[i, j] = slerp(a["rot"][0, j], b["rot"][0, j], e)
    durs = [secs / k] * k + [hold]
    times = [i * secs / k for i in range(n)]
    return {"loc": loc, "rot": rot, "scale": scl, "n": n, "world_z": np.zeros(n)}, durs, times


def descendants(arm, roots: list[str]) -> set[str]:
    out = set()
    for r in roots:
        b = arm.data.bones.get(r)
        if b is None:
            raise SystemExit(f"[bake] layer bone '{r}' not in the rig")
        out.add(b.name)
        out.update(c.name for c in b.children_recursive)
    return out


def apply_layer(arm, data: dict, bones: list[str], layer: dict, times: list[float], dur: float, loop: bool) -> None:
    """Overwrite some bones with another clip. On a loop the layer is time-fitted to the base's
    period, so both cycles close on the same frame and the seam stays clean."""
    act = layer["action"]
    f0, f1 = (float(v) for v in act.frame_range)
    ldur = max(1e-3, (f1 - f0) / src_fps())
    frames = [f0 + ((t / dur) * ldur if loop else min(t, ldur)) * src_fps() for t in times]
    bind_slot(arm, act)
    lay = sample(arm, frames, bones)
    for j, name in enumerate(bones):
        if name in layer["bones"]:
            data["loc"][:, j] = lay["loc"][:, j]
            data["rot"][:, j] = lay["rot"][:, j]
            data["scale"][:, j] = lay["scale"][:, j]


def tweak_value(keys: list, t: float, dur: float, loop: bool) -> tuple[float, float, float]:
    """(pitch, roll, yaw) degrees at time t, cosine-eased between keys [[t, pitch, roll, yaw], ...]."""
    ks = sorted(keys, key=lambda k: k[0])
    if loop:
        ks = ks + [[ks[0][0] + dur] + list(ks[0][1:])]
        t = t % dur
        if t < ks[0][0]:
            t += dur
    if t <= ks[0][0]:
        return tuple(ks[0][1:4])
    for a, b in zip(ks, ks[1:]):
        if a[0] <= t <= b[0]:
            s = (t - a[0]) / max(1e-6, b[0] - a[0])
            s = 0.5 - 0.5 * math.cos(math.pi * s)
            return tuple(a[i] + (b[i] - a[i]) * s for i in (1, 2, 3))
    return tuple(ks[-1][1:4])


def apply_tweaks(arm, tweaks: dict, t: float, dur: float, loop: bool) -> None:
    """Turn bones in BODY axes about their own head, parents first. Bodies face -Y, so:
    pitch = world X (+ bows forward), roll = world Y (+ leans to its own left), yaw = world Z (+ turns
    to its own left, which is toward the camera). Children follow, like turning a real neck."""
    mw = arm.matrix_world.to_3x3().normalized()
    order = sorted(tweaks, key=lambda nm: len(arm.data.bones[nm].parent_recursive))
    for name in order:
        p, r, y = tweak_value(tweaks[name], t, dur, loop)
        if abs(p) + abs(r) + abs(y) < 1e-4:
            continue
        rw = Euler((math.radians(p), math.radians(r), math.radians(y)), "XYZ").to_matrix()
        ra = mw.inverted() @ rw @ mw
        pb = arm.pose.bones[name]
        m = pb.matrix.copy()
        new = (ra @ m.to_3x3()).to_4x4()
        new.translation = m.translation
        pb.matrix = new
        bpy.context.view_layer.update()


def main() -> int:
    a = argv()
    char_path = a["char"]
    lib_path = a["lib"]
    clip = a["clip"]
    out_dir = a["out"]
    amount = float(a.get("amount", 0.0))
    sigma = float(a.get("sigma", 2.5))
    fps = float(a.get("fps", 15.0))
    angle = float(a.get("angle", 70.0))
    res = int(a.get("res", 256))
    loop = a.get("loop", "false").lower() in ("1", "true", "yes")
    ss_amount = float(a.get("squash", amount))
    max_deg = float(a.get("max_deg", 30.0))
    locomotion = a.get("locomotion", "false").lower() in ("1", "true", "yes")
    plant = a.get("plant", "true").lower() in ("1", "true", "yes")

    wipe()
    char_objs = import_glb(char_path)
    arm = find_armature(char_objs)
    if arm is None:
        print("[bake] no armature in the character file")
        return 1
    char_objs = drop_unskinned(char_objs, arm)
    meshes = [o for o in char_objs if o.type == "MESH"]
    view, right, up = film_axes(angle)

    # ONE scale per character, from its bind pose: `res` is the pixel height of a cell that holds the
    # standing character with headroom. Every clip shares it, whatever the clip does.
    bpy.context.view_layer.update()
    rest = mesh_points(meshes)
    height = max(p.z for p in rest) - min(0.0, min(p.z for p in rest))
    ppm = res / (height * 1.3)
    if float(a.get("ppm", 0)) > 0:
        # cast-wide scale: every character at the same pixels-per-metre, so relative heights hold
        ppm = float(a["ppm"])

    # Import the clip library for its ACTIONS only. Its own mannequin comes along with it and would
    # otherwise stand in shot in every single frame — keep the actions alive with a fake user, then
    # delete every object the library brought in.
    lib_objs = import_glb(lib_path)
    for act in bpy.data.actions:
        act.use_fake_user = True
    for o in lib_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    action = find_action(clip)
    if action is None:
        print(f"[bake] clip '{clip}' not found; have: {sorted(x.name for x in bpy.data.actions)[:40]}")
        return 1
    _ACTION_CACHE[(lib_path, clip)] = action
    recipe = json.loads(a["recipe"]) if a.get("recipe") else {}
    for part in [recipe.get("pose"), recipe.get("layer")]:
        if part:
            part["action"] = load_action(part["lib"], part["clip"])

    bones = [pb.name for pb in arm.pose.bones]
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    if recipe.get("pose"):
        # a statue: `clip` is the stance it strikes FROM (time `from_at`), `pose` the frame it holds
        rest = {"action": action, "at": float(recipe.get("from_at", 0.0))}
        data, durs, times = strike(arm, bones, rest, recipe["pose"], float(recipe.get("secs", 0.2)),
                                   float(recipe.get("hold", 0.6)), fps)
        frames = [0.0] * data["n"]
        dur = float(sum(durs))
        loop = False
        speed, faces = 0.0, 1
    else:
        bind_slot(arm, action)
        frames, durs, dur = sample_times(action, fps, loop)
        reps = int(recipe.get("repeat", 1))
        if loop and reps > 1:
            frames, durs, dur = frames * reps, durs * reps, dur * reps
        speed, faces = ground_speed(arm, frames, durs, right) if locomotion else (0.0, 1)
        data = sample(arm, frames, bones)
        f_start = float(action.frame_range[0])
        times = [float(sum(durs[:i])) for i in range(len(frames))] if reps > 1 else \
            [(f - f_start) / src_fps() for f in frames]
    if recipe.get("layer"):
        recipe["layer"]["bones"] = sorted(descendants(arm, recipe["layer"]["bones"]))
        apply_layer(arm, data, bones, recipe["layer"], times, dur, loop)
    tweaks = recipe.get("tweak", {})
    for nm in tweaks:
        if nm not in arm.pose.bones:
            print(f"[bake] tweak bone '{nm}' not in the rig")
            return 1
    faces_by_expr = face_sets(meshes)
    face = recipe.get("face", "neutral")
    if faces_by_expr:
        wanted = {face} if isinstance(face, str) else {e for _, e in face}
        # "neutral" may have no set of its own: then neutral is the bare face (Hush's painted one)
        missing = sorted(wanted - set(faces_by_expr) - {"neutral"})
        if missing:
            print(f"[bake] no expression {missing}; this model has {sorted(k for k in faces_by_expr if k != 'all')}")
            return 1
    # props: sized per character so an apple is the same apple in either hand on stage
    char_scale = float(recipe.get("prop_scale", 1.0))
    props = [(sp, attach_prop(arm, sp, char_scale)) for sp in recipe.get("props", [])]
    prop_objs = [o for _, objs in props for o in objs]
    n = data["n"]

    # The cartoon filter is OPT-IN (amount 0 = the library motion exactly as captured). The owner
    # judged the filtered takes too wobbly and unnatural; the knob stays for the odd gag that wants it.
    floc = data["loc"].copy()
    frot = data["rot"].copy()
    ss = np.ones((n, 3))
    if amount > 0.0:
        sig = sigma * fps / 24.0   # sigma was tuned in 24 fps source frames
        for b in range(len(bones)):
            floc[:, b] = cf.exaggerate(data["loc"][:, b], amount, sig, loop)
            frot[:, b] = cf.exaggerate_quats(data["rot"][:, b], amount, sig, loop, max_deg)
        ss = cf.squash_stretch(data["world_z"], ss_amount, sig, loop)
    # The accent is the punchline of a one-shot — the frame sound and hit-stop hang off. It is where
    # the WHOLE pose changes hardest. A LOOP has no punchline.
    accent = 0 if loop else cf.accent_frame(data["rot"].reshape(n, -1), sigma=1.2, loop=loop)
    if recipe.get("pose"):
        accent = n - 1          # a statue's punchline is the moment it locks

    os.makedirs(out_dir, exist_ok=True)
    arm.animation_data.action = None          # we drive the pose ourselves, frame by frame

    lift = np.zeros(n)

    def apply_pose(i: int) -> None:
        arm.location.z = float(lift[i])
        for b, name in enumerate(bones):
            pb = arm.pose.bones[name]
            pb.location = Vector(floc[i, b])
            q = frot[i, b]
            pb.rotation_quaternion = Quaternion((q[0], q[1], q[2], q[3]))
            pb.scale = Vector(data["scale"][i, b])
        arm.scale = Vector((ss[i, 0], ss[i, 2], ss[i, 1]))
        bpy.context.view_layer.update()
        if tweaks:
            apply_tweaks(arm, tweaks, times[i], dur, loop)
        if faces_by_expr:
            show_face(faces_by_expr, face_at(face, times[i]))
        if props:
            show_props(props, times[i])

    # The film window covers every pose in the clip — measured ON THE FILM, so a body lying along the
    # view axis still fits — and always includes the root on the floor, which becomes the anchor.
    # Floor contact. Library clips were captured on another body, so on ours they sink INTO the
    # floor (a third of a lying body) or float above it (30 px mid get-up when a Medium-rig clip
    # drives the Large body's longer legs). A PLANTED clip (the default) puts its lowest point on
    # the floor in every frame. `--plant false` only lifts out of the floor, so a jump can leave it.
    u0 = v0 = 1e9
    u1 = v1 = -1e9
    for i in range(n):
        apply_pose(i)
        pts = mesh_points(meshes)
        # the BODY decides floor contact (a saw's tip must not lift her); props only widen the cell
        low = min(p.z for p in pts)
        lift[i] = -low if plant else max(0.0, -low)
        for p in pts + mesh_points(prop_objs):
            u, v = p.dot(right), p.dot(up) + lift[i]
            u0, u1, v0, v1 = min(u0, u), max(u1, u), min(v0, v), max(v1, v)
    if np.abs(lift).max() > 0.005:
        print(f"[bake] floor contact: moved {int((np.abs(lift) > 0.005).sum())}/{n} poses, "
              f"{lift.min() * 100:+.0f}..{lift.max() * 100:+.0f} cm")
    pad = float(a.get("pad_px", 8)) / ppm
    u0, u1 = min(u0, 0.0) - pad, max(u1, 0.0) + pad
    v0, v1 = min(v0, 0.0) - pad, max(v1, 0.0) + pad
    w_px, h_px = build_world(angle, u0, u1, v0, v1, ppm)
    anchor = [(0.0 - u0) * ppm, h_px - (0.0 - v0) * ppm]   # root on the floor, in pixels from top-left
    print(f"[bake] {clip}: {n} frames @ {fps:g} fps over {dur:.2f}s, cell {w_px}x{h_px}, "
          f"anchor ({anchor[0]:.1f}, {anchor[1]:.1f}), {ppm:.1f} px/m")

    for i in range(n):
        apply_pose(i)
        bpy.context.scene.render.filepath = os.path.join(out_dir, f"f{i:03d}.png")
        bpy.ops.render.render(write_still=True)

    meta = {
        "clip": (f"{recipe['pose']['clip']}@{recipe['pose']['at']:g}s" if recipe.get("pose") else clip), "character": os.path.basename(char_path), "amount": amount, "sigma": sigma,
        "loop": loop, "angle": angle, "fps": fps, "duration": round(float(sum(durs)), 4), "source_duration": round(dur, 4),
        "max_lift_cm": round(float(lift.max()) * 100, 1), "plant": plant, "ppm": round(ppm, 3),
        "anchor": [round(anchor[0], 2), round(anchor[1], 2)],
        "durations": [round(d, 4) for d in durs], "faces": faces,
        "ground_speed": round(speed, 4), "ground_speed_px": round(speed * ppm, 2),
        "source_frames": [round(f, 3) for f in frames], "frames": n, "accent": accent,
        "recipe": {k: ({kk: vv for kk, vv in v.items() if kk not in ("action", "lib")} if isinstance(v, dict) and k != "tweak" else v)
                   for k, v in recipe.items()} if recipe else None,
    }
    with open(os.path.join(out_dir, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=2)
    print(f"[bake] {clip} -> {n} frames (accent {accent}, speed {speed:.2f} m/s) in {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
