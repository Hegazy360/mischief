"""skeleton -- Hush's R3D armature (the skeleton contract, r3d-index §7.3; brief r3d-cast-hush §4.1).

    tools/art3d/blender.sh --python tools/art3d/hush/skeleton.py -- [--head-scale 1.0] [--json tools/art3d/hush/skeleton.json]

The CC0 Quaternius UAL1 65-bone UE5-mannequin skeleton, re-proportioned BY BONE LENGTH ONLY to look B's joint rest
positions (`look-cartoon/chars/hush_meta.json`): every UAL bone keeps its rest direction and roll (so UAL clips and the
bpy pose language mean the same motion), its head moves onto B's joint, its length becomes the distance to its chain
child along that direction (leaf bones: UAL length x B's per-bone scale). Feet stand on z = 0 (Godot y = 0), the
character faces -Y in Blender (+Z in Godot), the armature object is named `Armature`.

Extra (non-UAL) bones, parented as the brief lists: beret (Head) > beret_stalk; hair_l, hair_r (Head, bob tips);
brace_l, brace_r (spine_02, strap jiggle); prop_clarence (spine_02, at the right brace) > clarence_comb, clarence_body;
prop_r (hand_r) > fx_pepper; prop_l (hand_l); carry_1, carry_2 (spine_02, items tucked in her braces).

`head_scale` (ruling R6) scales everything above the Head joint about that joint (B's neck length is kept); it never
renames a bone or changes a roll, so clips never need a re-bake.

Also a module: build.py calls `build_armature(head_scale)` and `contract(arm)`.
"""
import bpy
import json
import math
import os
import sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hush_dims as D  # noqa: E402

FINGERS = ("thumb", "index", "middle", "ring", "pinky")
# UAL bones that carry weights (<= 50 deform bones with the extras; brief 4.2): per glove thumb/index/middle/ring
# 01-02, never the _03, the _04 leaves or the pinky; no root, no ball_leaf.
DEFORM_UAL = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"]
for _s in ("l", "r"):
    DEFORM_UAL += [f"clavicle_{_s}", f"upperarm_{_s}", f"lowerarm_{_s}", f"hand_{_s}",
                   f"thigh_{_s}", f"calf_{_s}", f"foot_{_s}", f"ball_{_s}"]
    for _f in ("thumb", "index", "middle", "ring"):
        DEFORM_UAL += [f"{_f}_01_{_s}", f"{_f}_02_{_s}"]

# extra bones: name -> (parent, deform, jiggle)
EXTRAS = {
    "beret": ("Head", True, True),
    "beret_stalk": ("beret", True, True),
    "hair_l": ("Head", True, True),
    "hair_r": ("Head", True, True),
    "brace_l": ("spine_02", True, True),
    "brace_r": ("spine_02", True, True),
    "prop_clarence": ("spine_02", True, False),
    "clarence_comb": ("prop_clarence", True, True),
    "clarence_body": ("prop_clarence", True, True),
    "prop_r": ("hand_r", True, False),
    "fx_pepper": ("prop_r", False, False),
    "prop_l": ("hand_l", False, False),
    "carry_1": ("spine_02", False, False),
    "carry_2": ("spine_02", False, False),
}
HEAD_DESC = {"beret", "beret_stalk", "hair_l", "hair_r"}   # scaled with the head (R6)


def V(t):
    return Vector(t)


def extra_positions() -> dict:
    """Rest head/tail of every extra bone (armature space, head_scale 1.0)."""
    J = {k: V(v) for k, v in D.b_joints().items()}
    HC = V(D.HEAD_C)
    BC = HC + V(D.BERET_OFF)
    top = BC + V((0.0, 0.0, D.BERET_R[2]))
    grip_r = J["hand_r"] + V((-0.090, -0.004, -0.030))   # palm centre: +0.09 along the hand, on the palm side
    grip_l = J["hand_l"] + V((0.090, -0.004, -0.030))
    return {
        "beret": (BC, BC + V((0.0, 0.0, 0.09))),
        "beret_stalk": (top + V((0.0, 0.0, -0.004)), top + V((0.004, 0.0, 0.034))),
        "hair_l": (HC + V((0.128, 0.004, -0.060)), HC + V((0.142, -0.012, -0.160))),
        "hair_r": (HC + V((-0.128, 0.004, -0.060)), HC + V((-0.142, -0.012, -0.160))),
        "brace_l": (V((0.064, -0.070, 1.130)), V((0.070, -0.100, 0.860))),
        "brace_r": (V((-0.064, -0.070, 1.130)), V((-0.070, -0.100, 0.860))),
        "prop_clarence": (V((-0.072, -0.088, 0.950)), V((-0.072, -0.088, 1.050))),
        "clarence_body": (V((-0.072, -0.092, 0.930)), V((-0.072, -0.092, 1.000))),
        "clarence_comb": (V((-0.070, -0.100, 1.106)), V((-0.070, -0.100, 1.146))),
        "prop_r": (grip_r, grip_r + V((0.0, -0.10, 0.0))),
        "fx_pepper": (grip_r + V((0.0, -0.215, 0.0)), grip_r + V((0.0, -0.315, 0.0))),
        "prop_l": (grip_l, grip_l + V((0.0, -0.10, 0.0))),
        "carry_1": (V((0.078, -0.118, 1.000)), V((0.078, -0.118, 1.080))),
        "carry_2": (V((0.080, -0.110, 0.880)), V((0.080, -0.110, 0.960))),
    }


def import_ual_armature():
    """A clean UAL1 armature (no meshes, no actions) named Armature; returns (arm, ual_rest)."""
    bpy.ops.import_scene.gltf(filepath=D.UAL1)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for o in list(bpy.data.objects):
        if o != arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    arm.name = "Armature"
    arm.data.name = "Armature"
    if arm.animation_data:
        arm.animation_data.action = None
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    rest = {b.name: (b.head.copy(), b.tail.copy(), b.roll, b.parent.name if b.parent else None) for b in arm.data.edit_bones}
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm, rest


def _chain_child(name, rest):
    """The UAL child whose head sits on this bone's tail (the chain continues), else None."""
    h, t, _, _ = rest[name]
    best, bd = None, 1e9
    for n, (ch, _ct, _r, p) in rest.items():
        if p == name:
            d = (ch - t).length
            if d < bd:
                best, bd = n, d
    return best if bd < 0.004 else None


def _leaf_scale(name):
    if name.startswith(FINGERS) or name.startswith("hand_"):
        return D.GLOVE_K
    if name == "Head":
        return 2.4
    return 1.0


def build_armature(head_scale: float = 1.0):
    """Import UAL1 and re-proportion it to look B (see the module doc). Returns (arm, ual_rest)."""
    arm, rest = import_ual_armature()
    J = {k: V(v) for k, v in D.b_joints().items()}
    missing = [n for n in rest if n not in J]
    if missing:
        raise RuntimeError("B joints missing for %s" % missing)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for b in eb:
        b.use_connect = False
    for n, (h, t, roll, _p) in rest.items():
        d = (t - h).normalized()
        c = _chain_child(n, rest)
        if c is not None:
            L = max((J[c] - J[n]).dot(d), 0.01)
        else:
            L = (t - h).length * _leaf_scale(n)
        b = eb[n]
        b.head = J[n]
        b.tail = J[n] + d * L
        b.roll = roll
    # extras
    for n, (hd, tl) in extra_positions().items():
        parent, deform, _jig = EXTRAS[n]
        b = eb.new(n)
        b.head = hd
        b.tail = tl
        b.roll = 0.0
        b.parent = eb[parent]
        b.use_connect = False
        b.use_deform = deform
    for n in rest:
        eb[n].use_deform = n in DEFORM_UAL
    # head scale about the Head joint (R6): the Head bone's own tail, every bone above it
    if abs(head_scale - 1.0) > 1e-6:
        pivot = eb["Head"].head.copy()
        for b in eb:
            if b.name == "Head" or b.name in HEAD_DESC:
                r = b.roll
                if b.name != "Head":
                    b.head = pivot + (b.head - pivot) * head_scale
                b.tail = pivot + (b.tail - pivot) * head_scale
                b.roll = r
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm, rest


def contract(arm, ual_rest, head_scale: float = 1.0) -> dict:
    """The skeleton.json contract: every bone (name, parent, head, tail, roll, deform, jiggle) + the references the
    cast test checks against (UAL rest directions, B's joints), in Blender and Godot axes."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bones = []

    def g(v):   # Blender -> glTF/Godot axes
        return [round(v[0], 6), round(v[2], 6), round(-v[1], 6)]

    J = D.b_joints()
    for b in arm.data.edit_bones:
        n = b.name
        is_ual = n in ual_rest
        row = {"name": n, "parent": b.parent.name if b.parent else None,
               "head": [round(x, 6) for x in b.head], "tail": [round(x, 6) for x in b.tail],
               "roll": round(b.roll, 6), "deform": bool(b.use_deform),
               "jiggle": bool(EXTRAS[n][2]) if n in EXTRAS else False, "ual": is_ual}
        if is_ual:
            h, t, roll, _p = ual_rest[n]
            d = (t - h).normalized()
            row["ual_dir"] = [round(x, 6) for x in d]
            row["ual_dir_godot"] = g(d)
            row["ual_roll"] = round(roll, 6)
            row["b_joint"] = [round(x, 6) for x in J[n]]
        bones.append(row)
    bpy.ops.object.mode_set(mode="OBJECT")
    deform = [r["name"] for r in bones if r["deform"]]
    jig = [r["name"] for r in bones if r["jiggle"]]
    out = {
        "version": 1, "rig": "hush", "head_scale": head_scale,
        "doc": ("Hush's skeleton contract (R3D): the UAL1 65-bone skeleton re-proportioned by bone length only to look B's "
                "joints (directions and rolls kept) + extra bones. Blender armature space (faces -Y, +X = her left, +Z up), "
                "metres; *_godot = the same vector in Godot axes (+Y up, faces +Z). Frozen at P1 (SKELETON FROZEN): names, "
                "rest heads and rolls never change after it (head_scale excepted, ruling R6)."),
        "armature": "Armature", "height_m": D.HEIGHT_M,
        "counts": {"bones": len(bones), "ual": sum(1 for r in bones if r["ual"]), "extras": sum(1 for r in bones if not r["ual"]),
                   "deform": len(deform), "deform_non_jiggle": len([n for n in deform if n not in jig]), "jiggle": len(jig)},
        "arms_b": {"upperarm_m": round((V(J["lowerarm_l"]) - V(J["upperarm_l"])).length, 6),
                   "forearm_m": round((V(J["hand_l"]) - V(J["lowerarm_l"])).length, 6),
                   "shoulder_z": round(J["upperarm_l"][2], 6)},
        "bones": bones,
    }
    return out


def write_json(data: dict, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {}
    for i in range(0, len(argv) - 1, 2):
        opt[argv[i].lstrip("-")] = argv[i + 1]
    hs = float(opt.get("head-scale", "1.0"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, rest = build_armature(hs)
    data = contract(arm, rest, hs)
    path = opt.get("json", os.path.join(HERE, "skeleton.json"))
    write_json(data, path)
    print("SKELETON_OK", path, data["counts"])
