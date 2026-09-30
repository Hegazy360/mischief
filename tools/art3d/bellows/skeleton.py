"""Horace Bellows -- the contract skeleton (r3d-cast-bellows P0/P1; index §7.3, brief §4.1).

The Quaternius UAL 65-bone skeleton (CC0, tools/art3d/vendor/ual/UAL1_Standard.glb) re-proportioned by bone length and
joint offset only: every UAL bone keeps its rest DIRECTION and ROLL (the arm-out is a pipeline pose layer, `anim.layers`
= ["arm_out"], never built into the rest pose), + the extra bones of the brief (jiggle, props, FX, the ride-along stool).
Armature object `Armature`, facing -Y in Blender (+X = his LEFT, +Z up, metres).

Run standalone (writes skeleton.json):
    tools/art3d/blender.sh --python tools/art3d/bellows/skeleton.py -- --json tools/art3d/bellows/skeleton.json
Used as a module by build.py (`build_armature()`).
"""
import bpy, sys, os, math, json
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
UAL1 = os.path.join(ROOT, "tools", "art3d", "vendor", "ual", "UAL1_Standard.glb")
UAL2 = os.path.join(ROOT, "tools", "art3d", "vendor", "ual", "UAL2_Standard.glb")

HEIGHT_M = 1.78          # to the top of the bouffant (REDESIGN §5.5)
HIP_M = 0.45             # thigh head height = the legs (REDESIGN §5.5)

# ---- bone-length scales (own length) ------------------------------------------------------------------------------
K_SPINE = 1.02
K_ARM = 0.92             # upper + lower arm vs UAL (reach proof, brief §4.2): shoulder->wrist 0.503 m
K_HAND = 1.18            # hand bone + finger roots: big white opera gloves (palm centre ~ +0.09 m)
K_FINGER = 0.80
K_FOOT = 0.80
K_LEG = 0.443            # thigh + calf: hip at 0.45 m with the foot at K_FOOT
K = {"pelvis": K_SPINE, "spine_01": K_SPINE, "spine_02": K_SPINE, "spine_03": K_SPINE, "neck_01": 0.70, "Head": 3.0}
for _s in ("l", "r"):
    K.update({f"clavicle_{_s}": 1.0, f"upperarm_{_s}": K_ARM, f"lowerarm_{_s}": K_ARM, f"hand_{_s}": K_HAND,
              f"thigh_{_s}": K_LEG, f"calf_{_s}": K_LEG, f"foot_{_s}": K_FOOT, f"ball_{_s}": K_FOOT, f"ball_leaf_{_s}": K_FOOT})
    for _f in ("index", "middle", "ring", "pinky", "thumb"):
        for _i in (1, 2, 3):
            K[f"{_f}_{_i:02d}_{_s}"] = K_FINGER
        K[f"{_f}_04_leaf_{_s}"] = K_FINGER
# ---- joint-offset scales (parent head -> this head; default = the parent's own length scale) ---------------------
KO = {"thigh_l": (1.60, 0.8, 1.0), "thigh_r": (1.60, 0.8, 1.0)}
# explicit joint positions (armature space; descendants follow by their offsets): the shoulders at the barrel's sides
SHOULDER = (0.270, -0.020, 1.040)
HEAD_POS = {"upperarm_l": SHOULDER, "upperarm_r": (-SHOULDER[0], SHOULDER[1], SHOULDER[2])}

# ---- landmarks the builders share (armature space) --------------------------------------------------------------
HC_Z = 1.262             # head centre height
TC_Z = 0.700             # barrel centre height

# UAL bones that carry no weights (merged finger joints, leaves, root, clavicles) -> use_deform False
NON_DEFORM = {"root", "clavicle_l", "clavicle_r"}
for _s in ("l", "r"):
    NON_DEFORM |= {f"{f}_03_{_s}" for f in ("index", "middle", "ring", "thumb")}
    NON_DEFORM |= {f"pinky_{i:02d}_{_s}" for i in (2, 3)}      # pinky_01 stays weighted: the pinkie-up gag
    NON_DEFORM |= {f"{f}_04_leaf_{_s}" for f in ("index", "middle", "ring", "pinky", "thumb")}
    NON_DEFORM |= {f"ball_leaf_{_s}"}

# the arm-out pose layer (anim.layers = ["arm_out"], applied by the bake pipeline to every clip; look B's layer):
# rotations about the ARMATURE axes (Blender: X = his left, Y = his back, Z = up), degrees; y- raises the left arm
ARM_OUT = {"upperarm_l": [["y", -40.0]], "upperarm_r": [["y", 40.0]]}

JIGGLE = ["belly", "bouffant", "bouffant_l", "bouffant_r", "sideburn_l", "sideburn_r", "cravat", "tail_l", "tail_r"]


def extra_bones(H):
    """(name, parent, head, tail, deform) of every extra bone, from the retargeted joint heads H(name)."""
    hc = Vector((0.0, H("Head").y - 0.020, HC_Z))
    tc = Vector((0.0, H("spine_02").y + 0.005, TC_Z))
    gr = lambda s: H("hand_" + s) + (H("middle_01_" + s) - H("hand_" + s)).normalized() * 0.075 + Vector((0, -0.030, -0.035))
    sx = {"l": 1.0, "r": -1.0}
    out = [
        # jiggle: the three dandelion lobes (crown + two side lobes), the chops, the cravat, the coat tails, the belly
        ("bouffant", "Head", hc + Vector((0, 0.10, 0.22)), hc + Vector((0, 0.10, 0.40)), True),
        ("bouffant_l", "bouffant", hc + Vector((0.20, 0.09, 0.19)), hc + Vector((0.34, 0.09, 0.26)), True),
        ("bouffant_r", "bouffant", hc + Vector((-0.20, 0.09, 0.19)), hc + Vector((-0.34, 0.09, 0.26)), True),
        ("sideburn_l", "Head", hc + Vector((0.225, -0.02, -0.04)), hc + Vector((0.25, -0.05, -0.18)), True),
        ("sideburn_r", "Head", hc + Vector((-0.225, -0.02, -0.04)), hc + Vector((-0.25, -0.05, -0.18)), True),
        ("cravat", "spine_03", Vector((0.0, tc.y - 0.30, 1.02)), Vector((0.0, tc.y - 0.33, 0.88)), True),
        ("tail_l", "pelvis", Vector((0.11, tc.y + 0.33, 0.42)), Vector((0.12, tc.y + 0.38, 0.20)), True),
        ("tail_r", "pelvis", Vector((-0.11, tc.y + 0.33, 0.42)), Vector((-0.12, tc.y + 0.38, 0.20)), True),
        ("belly", "spine_01", tc + Vector((0, -0.10, -0.04)), tc + Vector((0, -0.30, -0.04)), True),
        # face: the nose twitch; brow lifts (decal offset only, no weights)
        ("nose", "Head", hc + Vector((0, -0.22, -0.048)), hc + Vector((0, -0.32, -0.048)), True),
        ("brow_l", "Head", hc + Vector((0.085, -0.24, 0.085)), hc + Vector((0.085, -0.24, 0.135)), False),
        ("brow_r", "Head", hc + Vector((-0.085, -0.24, 0.085)), hc + Vector((-0.085, -0.24, 0.135)), False),
        # specs: worn on the nose (scale 0 unless on) / dangling on the belly
        ("specs_face", "Head", hc + Vector((0, -0.25, 0.03)), hc + Vector((0, -0.25, 0.11)), True),
        ("specs_chest", "spine_03", Vector((0.10, tc.y - 0.40, 0.80)), Vector((0.10, tc.y - 0.40, 0.90)), True),
        # held props: grip frames on the hands; one bone per skinned-in prop (scale 0 when hidden)
        ("prop_r", "hand_r", gr("r"), gr("r") + Vector((0, 0, 0.10)), False),
        ("prop_l", "hand_l", gr("l"), gr("l") + Vector((0, 0, 0.10)), False),
        ("prop_teacup", "prop_r", gr("r"), gr("r") + Vector((0, 0, 0.10)), True),
        ("prop_spoon", "prop_r", gr("r"), gr("r") + Vector((0, 0, 0.10)), True),
        ("prop_comb", "prop_r", gr("r"), gr("r") + Vector((0, 0, 0.10)), True),
        ("prop_baton", "prop_r", gr("r"), gr("r") + Vector((0, 0, 0.10)), True),
        ("prop_saucer", "prop_l", gr("l"), gr("l") + Vector((0, 0, 0.10)), True),
        # FX rings: the CHOO puff (nose), the dazed stars and the orbiting notes (above the bouffant)
        ("fx_choo", "Head", hc + Vector((0, -0.34, -0.05)), hc + Vector((0, -0.50, -0.07)), True),
        ("fx_stars", "Head", hc + Vector((0, 0.03, 0.40)), hc + Vector((0, 0.03, 0.50)), True),
        ("fx_notes", "Head", hc + Vector((0, 0.03, 0.46)), hc + Vector((0, 0.03, 0.56)), True),
        # the ride-along stool (an attachment scene on this bone; pelvis child, seat under the barrel)
        ("ride", "pelvis", Vector((0.0, H("pelvis").y, 0.30)), Vector((0.0, H("pelvis").y, 0.40)), False),
    ]
    return out


def retarget(arm):
    """Rescale lengths + offsets (directions and rolls kept), place the shoulders, put the feet on the floor."""
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    old = {b.name: (b.head.copy(), b.tail.copy(), b.roll) for b in eb}
    order = []

    def visit(b):
        order.append(b.name)
        for c in b.children:
            visit(c)
    for b in eb:
        if b.parent is None:
            visit(b)
    nh, nt = {}, {}
    for n in order:
        b = eb[n]
        oh, ot, _ = old[n]
        if b.parent is None:
            nh[n] = oh.copy()
        else:
            p = b.parent.name
            ko = KO.get(n, K.get(p, 1.0))
            if not isinstance(ko, (tuple, list)):
                ko = (ko, ko, ko)
            d = oh - old[p][0]
            nh[n] = nh[p] + Vector((d.x * ko[0], d.y * ko[1], d.z * ko[2]))
        nt[n] = nh[n] + (ot - oh) * K.get(n, 1.0)
    # the floor: ball_l head at the UAL ball height x foot scale; then the hip exactly at HIP_M by the leg lengths
    dz = old["ball_l"][0].z * K_FOOT - nh["ball_l"].z
    for n in order:
        if n != "root":
            nh[n].z += dz
            nt[n].z += dz
    # explicit shoulder heads (the subtree follows)
    for n, pos in HEAD_POS.items():
        delta = Vector(pos) - nh[n]
        stack = [n]
        while stack:
            m = stack.pop()
            nh[m] += delta
            nt[m] += delta
            stack += [c.name for c in eb[m].children]
    for b in eb:
        b.use_connect = False
    for n in order:
        b = eb[n]
        b.head = nh[n]
        b.tail = nt[n]
        b.roll = old[n][2]
    bpy.ops.object.mode_set(mode="OBJECT")
    return old["pelvis"][0].z, nh["pelvis"].z


def add_bones(arm, specs):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for name, parent, h, t, deform in specs:
        b = eb.new(name)
        b.head = Vector(h)
        b.tail = Vector(t)
        b.roll = 0.0
        b.parent = eb[parent]
        b.use_connect = False
        b.use_deform = bool(deform)
    for n in NON_DEFORM:
        eb[n].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")


def import_ual(keep1=(), keep2=()):
    """Import UAL1 (armature + optional clips), drop its meshes; returns the armature object named `Armature`."""
    bpy.ops.import_scene.gltf(filepath=UAL1)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    arm.name = "Armature"
    arm.data.name = "Armature"
    for o in list(bpy.data.objects):
        if o != arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.name in keep1:
            a.name = "UAL_" + a.name
            a.use_fake_user = True
        else:
            bpy.data.actions.remove(a)
    if keep2:
        before = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=UAL2)
        for o in list(bpy.data.objects):
            if o != arm:
                bpy.data.objects.remove(o, do_unlink=True)
        for a in list(set(bpy.data.actions) - before):
            base = a.name.split(".")[0]
            if base in keep2 and ("UAL_" + base) not in bpy.data.actions:
                a.name = "UAL_" + base
                a.use_fake_user = True
            else:
                bpy.data.actions.remove(a)
    if arm.animation_data:
        arm.animation_data.action = None
    return arm


def build_armature(keep1=(), keep2=()):
    """The contract armature (+ optional UAL clips for proofs; their pelvis keys scaled to the new hip)."""
    arm = import_ual(keep1, keep2)
    ual_pel, new_pel = retarget(arm)
    ratio = new_pel / ual_pel
    import blib
    for act in bpy.data.actions:
        for fc in blib.action_fcurves(act):
            if fc.data_path == 'pose.bones["pelvis"].location':
                for kp in fc.keyframe_points:
                    kp.co[1] *= ratio
                    kp.handle_left[1] *= ratio
                    kp.handle_right[1] *= ratio
    B = {b.name: b for b in arm.data.bones}
    H = lambda n: arm.matrix_world @ B[n].head_local
    add_bones(arm, extra_bones(H))
    return arm, ratio


def describe(arm):
    """Every bone: name, parent, head, tail (armature space, Blender Z-up), roll (rad), deform, jiggle."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    rolls = {b.name: b.roll for b in arm.data.edit_bones}
    bpy.ops.object.mode_set(mode="OBJECT")
    bones = []
    for b in arm.data.bones:
        bones.append({"name": b.name, "parent": b.parent.name if b.parent else None,
                      "head": [round(v, 5) for v in b.head_local], "tail": [round(v, 5) for v in b.tail_local],
                      "roll": round(rolls[b.name], 5), "deform": bool(b.use_deform), "jiggle": b.name in JIGGLE})
    return bones


def write_json(arm, path, extra=None):
    bones = describe(arm)
    deform = [b["name"] for b in bones if b["deform"] and not b["jiggle"]]
    doc = {"version": 1, "rig": "bellows", "armature": "Armature",
           "doc": "Contract skeleton: UAL 65 (lengths/offsets re-proportioned, rest directions + rolls kept) + extras. "
                  "Coordinates: Blender armature space (Z up, the character faces -Y, +X = his left), metres. "
                  "glTF/Godot: x = x, y = z, z = -y.",
           "height_m": HEIGHT_M, "hip_m": HIP_M,
           "scales": {"spine": K_SPINE, "arm": K_ARM, "hand": K_HAND, "finger": K_FINGER, "leg": K_LEG, "foot": K_FOOT,
                      "neck": K["neck_01"], "head_bone": K["Head"], "hip_width": KO["thigh_l"][0]},
           "shoulder": list(SHOULDER), "head_centre_z": HC_Z, "barrel_centre_z": TC_Z,
           "counts": {"bones": len(bones), "ual": 65, "extra": len(bones) - 65, "deform": len(deform),
                      "jiggle": len(JIGGLE)},
           "jiggle": JIGGLE, "bones": bones}
    if extra:
        doc.update(extra)
    with open(path, "w") as f:
        json.dump(doc, f, indent=1)
    return doc


def write_ual_ref(path):
    """UAL's own rest frames (no retarget), converted to Godot axes (x, z, -y): the reference for the cast test
    'every UAL bone keeps its rest direction and roll within 0.5 deg'."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm = import_ual()
    g = lambda v: [round(v.x, 6), round(v.z, 6), round(-v.y, 6)]
    ref = {}
    for b in arm.data.bones:
        M = (arm.matrix_world @ b.matrix_local).to_3x3()
        ref[b.name] = {"x": g(M.col[0].normalized()), "y": g(M.col[1].normalized()), "z": g(M.col[2].normalized())}
    with open(path, "w") as f:
        json.dump({"version": 1, "source": "tools/art3d/vendor/ual/UAL1_Standard.glb",
                   "doc": "UAL rest bone axes (global, Godot axes); x = roll reference, y = bone direction.",
                   "bones": ref}, f, indent=1)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--ual-ref" in argv:
        write_ual_ref(argv[argv.index("--ual-ref") + 1])
        print("UAL_REF_OK")
        sys.exit(0)
    out = argv[argv.index("--json") + 1] if "--json" in argv else os.path.join(HERE, "skeleton.json")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, ratio = build_armature()
    doc = write_json(arm, out)
    B = {b.name: b for b in arm.data.bones}
    for n in ("pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
              "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "middle_01_l", "middle_04_leaf_l"):
        print("J", n, [round(v, 3) for v in B[n].head_local], "tail", [round(v, 3) for v in B[n].tail_local])
    print("SKELETON_OK", out, doc["counts"])
