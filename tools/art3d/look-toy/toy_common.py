"""Shared pieces of the two Toy Box builds: arg parsing, UAL paths, preview renders, rig bone list."""
import bpy, sys, os, math, json
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
W3D = os.path.abspath(os.path.join(HERE, "..", ".."))
ASSETS = os.path.join(W3D, "assets", "quaternius")
UAL1 = os.path.join(ASSETS, "universal-animation-library", "Universal Animation Library[Standard]", "Unreal-Godot", "UAL1_Standard.glb")
UAL2 = os.path.join(ASSETS, "universal-animation-library-2", "Universal Animation Library 2[Standard]", "Unreal-Godot", "UAL2_Standard.glb")

MAIN = ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "thigh_l", "thigh_r",
        "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]
FINGERS = [f"{f}_{i:02d}_{s}" for s in ("l", "r") for f in ("index", "middle", "ring", "pinky", "thumb") for i in (1, 2, 3)]


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


def preview(arm, out_dir, shots, size=(420, 560), ortho=2.0, center_z=0.85, tag=""):
    """Workbench renders. shots: [(action or None, frame, view)] view in front/side/34/back/top."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.show_object_outline = True
    sc.display.shading.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.film_transparent = False
    cam_d = bpy.data.cameras.new("pc")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = ortho
    cam = bpy.data.objects.new("pc", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    os.makedirs(out_dir, exist_ok=True)
    views = {"front": (0, -4, 0), "side": (4, 0, 90), "side_r": (-4, 0, -90), "34": (2.83, -2.83, 45),
             "back": (0, 4, 180), "34l": (-2.83, -2.83, -45)}
    outs = []
    arm.animation_data_create()
    for act, fr, view in shots:
        arm.animation_data.action = bpy.data.actions[act] if act else None
        if act and hasattr(arm.animation_data, "action_slot") and arm.animation_data.action_suitable_slots:
            arm.animation_data.action_slot = arm.animation_data.action_suitable_slots[0]
        if not act:
            for pb in arm.pose.bones:
                pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
        sc.frame_set(fr)
        x, y, rz = views[view]
        cam.location = (x, y, center_z)
        cam.rotation_euler = (math.radians(90), 0, math.radians(rz))
        p = os.path.join(out_dir, "%s%s_%03d_%s.png" % (tag, act or "rest", fr, view))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        outs.append(p)
    arm.animation_data.action = None
    bpy.data.objects.remove(cam, do_unlink=True)
    return outs
