"""bake — render one library clip, through the cartoon filter, to PNG frames. Runs inside Blender.

    blender -b --factory-startup --python-exit-code 1 -P tools/bakery/bake.py -- \
        --char assets/Knight.glb --lib assets/Rig_Medium_General.glb --clip Hit_A \
        --out /tmp/bake/knight_hit --amount 1.0 --sigma 2.5 --frames 14

Nothing here is authored. The character and the clip are CC0 library assets; the only human input is
two numbers (`amount`, `sigma`) and a camera angle. The pose is driven frame by frame straight from
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
from mathutils import Quaternion, Vector  # type: ignore

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import cartoon_filter as cf  # noqa: E402


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


def sample(arm, action, bones: list[str]) -> dict:
    """Play the clip and record every bone's local transform, frame by frame."""
    arm.animation_data_create()
    arm.animation_data.action = action
    # Blender 4.4+ slotted actions: an action imported for one armature carries a slot bound to THAT
    # armature. Assign the action to another rig without picking the slot and it silently does
    # nothing — the clip plays, every bone stays at rest, and every frame renders identical.
    if hasattr(arm.animation_data, "action_slot") and len(getattr(action, "slots", [])):
        arm.animation_data.action_slot = action.slots[0]
    f0, f1 = (int(round(v)) for v in action.frame_range)
    n = max(2, f1 - f0 + 1)
    loc = np.zeros((n, len(bones), 3))
    rot = np.zeros((n, len(bones), 4))
    scl = np.ones((n, len(bones), 3))
    world_z = np.zeros(n)
    ref = "hips" if "hips" in bones else bones[0]
    scene = bpy.context.scene
    for i in range(n):
        scene.frame_set(f0 + i)
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


def build_world(angle_deg: float, lo: "Vector", hi: "Vector", res: int, margin: float) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    try:
        scene.eevee.taa_render_samples = 16
    except AttributeError:
        pass
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # flat, even light: the cartoon read comes from the shapes, not from shading
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.15
    scene.world = world
    key = bpy.data.lights.new("key", type="SUN")
    key.energy = 2.6
    key.angle = 0.6
    ko = bpy.data.objects.new("key", key)
    ko.rotation_euler = (math.radians(55), math.radians(8), math.radians(35))
    scene.collection.objects.link(ko)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    a = math.radians(angle_deg)
    dist = 20.0
    view = Vector((-math.sin(a), math.cos(a), 0.0)).normalized()   # the way the camera looks
    right = view.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = Vector((0.0, 0.0, 1.0))
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    us = [c.dot(right) for c in corners]
    vs = [c.dot(up) for c in corners]
    # measure the silhouette ON THE FILM, not along world axes: a body lying along the view axis has a
    # tiny x-span and still fills the frame
    span = max(max(us) - min(us), max(vs) - min(vs), 0.5)
    cam_data.ortho_scale = span * margin
    centre = Vector((0.0, 0.0, 0.0))
    for c in corners:
        centre += c
    centre /= len(corners)
    target = right * ((max(us) + min(us)) * 0.5) + up * ((max(vs) + min(vs)) * 0.5) + view * centre.dot(view)
    cam.location = target - view * dist
    cam.rotation_euler = view.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam


def main() -> int:
    a = argv()
    char_path = a["char"]
    lib_path = a["lib"]
    clip = a["clip"]
    out_dir = a["out"]
    amount = float(a.get("amount", 1.0))
    sigma = float(a.get("sigma", 2.5))
    want = int(a.get("frames", 14))
    angle = float(a.get("angle", 25.0))
    res = int(a.get("res", 256))
    loop = a.get("loop", "false").lower() in ("1", "true", "yes")
    ss_amount = float(a.get("squash", amount))
    max_deg = float(a.get("max_deg", 30.0))

    wipe()
    char_objs = import_glb(char_path)
    arm = find_armature(char_objs)
    if arm is None:
        print("[bake] no armature in the character file")
        return 1
    char_objs = drop_unskinned(char_objs, arm)
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

    bones = [pb.name for pb in arm.pose.bones]
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    data = sample(arm, action, bones)
    n = data["n"]

    # the filter, per bone, on the library motion
    floc = np.zeros_like(data["loc"])
    frot = np.zeros_like(data["rot"])
    for b in range(len(bones)):
        floc[:, b] = cf.exaggerate(data["loc"][:, b], amount, sigma, loop)
        frot[:, b] = cf.exaggerate_quats(data["rot"][:, b], amount, sigma, loop, max_deg)

    # squash and stretch from how hard the body's height changes
    ss = cf.squash_stretch(data["world_z"], ss_amount, sigma, loop)
    # the accent is where the WHOLE pose changes hardest, not just where the hips move: KayKit clips
    # animate mostly in rotation, so a hips-only accent lands on frame 0 for nearly everything
    # An accent is the punchline of a one-shot — the frame sound and hit-stop hang off. A LOOP has no
    # punchline, and pretending it does protects a dull frame from being pruned.
    accent = 0 if loop else cf.accent_frame(data["rot"].reshape(n, -1), sigma=1.2, loop=loop)

    # choose which frames to keep: evenly spread, but never drop the accent
    if want <= 1:
        keep = [accent]
    elif want >= n:
        keep = list(range(n))
    else:
        keep = sorted(set(int(round(i * (n - 1) / (want - 1))) for i in range(want)) | {accent})
    out_accent = keep.index(accent) if accent in keep else 0

    # a frame that is visually the same as the one before it is wasted atlas space. Compare in pose
    # space (cheap, before any rendering) and drop it, but never drop the accent.
    def pose_vec(i: int) -> np.ndarray:
        return np.concatenate([floc[i].ravel(), frot[i].ravel() * 2.0])

    dedup_eps = float(a.get("dedup", 0.012))
    pruned = [keep[0]]
    for idx in keep[1:]:
        if idx == accent or float(np.abs(pose_vec(idx) - pose_vec(pruned[-1])).max()) >= dedup_eps:
            pruned.append(idx)
    if len(pruned) != len(keep):
        print(f"[bake] dropped {len(keep) - len(pruned)} near-duplicate frame(s)")
    keep = pruned
    out_accent = keep.index(accent) if accent in keep else 0

    os.makedirs(out_dir, exist_ok=True)
    arm.animation_data.action = None          # we drive the pose ourselves, frame by frame
    meshes = [o for o in char_objs if o.type == "MESH"]

    def apply_pose(src_i: int) -> None:
        for b, name in enumerate(bones):
            pb = arm.pose.bones[name]
            pb.location = Vector(floc[src_i, b])
            q = frot[src_i, b]
            pb.rotation_quaternion = Quaternion((q[0], q[1], q[2], q[3]))
            pb.scale = Vector(data["scale"][src_i, b])
        arm.scale = Vector((ss[src_i, 0], ss[src_i, 2], ss[src_i, 1]))
        bpy.context.view_layer.update()

    # ONE camera for the whole clip, framed on the bounds of every frame we will render: the
    # character must never swim in the cell or clip at the edge mid-animation
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for src_i in keep:
        apply_pose(src_i)
        dg = bpy.context.evaluated_depsgraph_get()
        for o in meshes:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            for v in me.vertices:
                w = ev.matrix_world @ v.co
                lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
                hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
            ev.to_mesh_clear()
    print(f"[bake] clip bounds x {lo.x:.2f}..{hi.x:.2f}  z {lo.z:.2f}..{hi.z:.2f}")
    build_world(angle, lo, hi, res, float(a.get("margin", 1.28)))

    for out_i, src_i in enumerate(keep):
        apply_pose(src_i)
        bpy.context.scene.render.filepath = os.path.join(out_dir, f"f{out_i:03d}.png")
        bpy.ops.render.render(write_still=True)

    meta = {
        "clip": clip, "character": os.path.basename(char_path), "amount": amount, "sigma": sigma,
        "loop": loop, "angle": angle, "res": res, "max_deg": max_deg, "source_frames": n, "frames": len(keep),
        "accent": out_accent, "kept": keep,
    }
    with open(os.path.join(out_dir, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=2)
    print(f"[bake] {clip} amount={amount} -> {len(keep)} frames (accent {out_accent}) in {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
