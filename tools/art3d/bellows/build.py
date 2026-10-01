"""HORACE BELLOWS in 3D -- look A (Toy Box) with the board's fixes (r3d-cast-bellows).

    tools/art3d/blender.sh --python tools/art3d/bellows/build.py -- --out game/art3d/chars/bellows
        [--meta <json>] [--rig-out <dir>] [--no-descriptor] [--poses <scratch.glb>] [--no-atlas] [--no-attachments]

61, retired bass-baritone: a dandelion clock on a barrel. A styled three-lobe silver bouffant pushed up and back so the
painted face (a bigger card than look A's) reads inside it; mutton chops framing the jaw; a bulbous rosy nose; a plum
tail-coat open over a white shirt V with gold buttons and a gold spotted cravat; white opera gloves on arms that clear
the barrel (the pipeline's `arm_out` layer, never the rest pose); striped trousers on tiny legs with spats.
Held props (teacup + saucer x1.8, spoon, comb, baton), the worn / dangling specs and the FX (CHOO puff, dazed stars,
orbiting notes) are skinned into the ONE mesh on their own bones (scale 0 = hidden: no extra draw call).
Body-slot variants of the bouffant and the rarer props are attachment scenes (separate small .glb).

Outputs (in --out): bellows.glb, palette_bellows.png, face_bellows.png (+ face_bellows.json layout),
bouffant_{flipped,frazzled,wet,floured}.glb, and --meta (tris, bones, landmarks, sockets) for descriptor.py.
"""
import bpy, bmesh, sys, os, math, json, random, subprocess
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import blib as T
import bpalette as TP
import skeleton as SK
import parts as P

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
OUT = os.path.abspath(opt.get("out", os.path.join(SK.ROOT, "game", "art3d", "chars", "bellows")))
os.makedirs(OUT, exist_ok=True)

# ---- palette + face atlas (python3 + rsvg-convert, outside Blender's python) ---------------------------------------
PAL = os.path.join(OUT, "palette_bellows.png")
FACE = os.path.join(OUT, "face_bellows.png")
if "no-atlas" not in opt or not os.path.exists(FACE):
    subprocess.run(["python3", os.path.join(HERE, "bpalette.py"), PAL], check=True)
    subprocess.run(["python3", os.path.join(HERE, "face_atlas.py"), "--out", OUT], check=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
POSES = "poses" in opt
arm, hip_ratio = SK.build_armature(keep1=("Idle_Loop", "Walk_Formal_Loop") if POSES else ())
rig = T.Rig(arm)
body = T.Body(rig, "bellows_body")
L = P.landmarks(rig)
P.build_body(body, rig, L)
P.build_props(body, rig, L)
P.build_fx(body, rig, L)

mat = T.toy_material("bellows_toy", PAL, FACE)
bodyob = body.finish(mat)
tris = sum(len(p.vertices) - 2 for p in bodyob.data.polygons)
print("BELLOWS tris", tris, "verts", len(bodyob.data.vertices), "bones", len(arm.data.bones))

# rest pose, no clips (the clips are baked per file by tools/art3d/anim, index R2)
GLB = os.path.join(OUT, "bellows.glb")
attach = {}
if "no-attachments" not in opt:
    attach = P.build_attachments(rig, L, OUT, mat)

# sockets (armature space, Blender Z-up) -> bone-local (Blender bone space: +Y along the bone)
HC, TC, FC = L["HC"], L["TC"], L["FC"]
HB = P.HEAD_R[1]
def head_front_y(z):
    """The head surface's front y at height z (march the head shape along the mid-sagittal plane)."""
    best, err = HC.y - HB, 9.0
    for k in range(181):
        th = math.radians(-90 + k)
        q = P.head_q(Vector((0.0, -math.cos(th), math.sin(th))))
        if abs(HC.z + q.z - z) < err:
            err, best = abs(HC.z + q.z - z), HC.y + q.y
    return best


MOUTH_Z = FC.z + P.FACE_H * (0.5 - 0.748)
SOCK_W = {
    "mouth": ("Head", Vector((0.0, head_front_y(MOUTH_Z) - 0.005, MOUTH_Z))),
    "head_top": ("Head", Vector((0.0, HC.y + 0.085, SK.HEIGHT_M))),
    "nose_tip": ("nose", HC + Vector((0, -HB - 0.026 - 0.052, -0.044))),
    "face": ("Head", Vector((0.0, head_front_y(FC.z), FC.z))),
    "belly_front": ("spine_02", Vector((0.0, TC.y - P.BARREL_R[1] - 0.03, TC.z))),
    "seat": ("pelvis", Vector((0.0, TC.y, TC.z - P.BARREL_R[2] + 0.03))),
}


def to_local(bone, p):
    M = (arm.matrix_world @ arm.data.bones[bone].matrix_local).inverted()
    return [round(v, 4) for v in (M @ p)]


sockets = {k: to_local(b, p) for k, (b, p) in SOCK_W.items()}
# deform bones = the bones that carry skin weight (jiggle and prop / FX bones included), as RigPerf3D counts them
# (index row 17: <= 50). The skeleton keeps every bone (clips, sockets); a bone flagged deform without weight is free.
_gname = {g.index: g.name for g in bodyob.vertex_groups}
weighted = {_gname[g.group] for v in bodyob.data.vertices for g in v.groups if g.weight > 0.0}
sockets_world = {k: [round(v, 4) for v in p] for k, (b, p) in SOCK_W.items()}
meta = {"character": "bellows", "sockets": sockets, "sockets_world": sockets_world, "arm_out": SK.ARM_OUT, "tris": tris, "verts": len(bodyob.data.vertices), "bones": len(arm.data.bones),
        "deform_bones": len(weighted), "weighted_bones": sorted(weighted),
        "jiggle_bones": len(SK.JIGGLE), "hip_ratio": hip_ratio, "tri_log": body.tri_log, "landmarks": P.landmarks_json(L),
        "attachments": attach, "height_m": P.measure_height(bodyob)}
T.export_glb(arm, bodyob, GLB, animations=False)
if POSES:
    import poses as PO
    PO.setup(arm)
    TA, TB, TCz, _p = P.BARREL_R
    zn = (1.0 - TC.z) / TCz
    belly_y = TC.y - TB * max(0.0, 1 - abs(zn) ** 2.2) ** (1 / 2.2) - 0.02
    lm = {"HC": HC, "TC": TC, "mouth": SOCK_W["mouth"][1], "belly_y_at_1m": belly_y, "seat_z": SOCK_W["seat"][1].z,
          "bouffant_top": Vector((0.0, HC.y + 0.10, meta["height_m"]))}
    meta["reach"] = PO.build_proof_poses(lm)
    meta["reach"]["belly_y_at_1m"] = round(belly_y, 3)
    for act in list(bpy.data.actions):
        if act.name.startswith("UAL_"):
            bpy.data.actions.remove(act)
    T.export_glb(arm, bodyob, os.path.abspath(opt["poses"]), animations=True)
    print("POSES_OK", json.dumps(meta["reach"]))
META = opt.get("meta", os.path.join(OUT, ".build_meta.json"))
with open(META, "w") as f:
    json.dump(meta, f, indent=1)
# the rig descriptor + presets follow the build (game/data/rigs3d/bellows unless --rig-out)
RIG_OUT = opt.get("rig-out", os.path.join(SK.ROOT, "game", "data", "rigs3d", "bellows"))
if "no-descriptor" not in opt:
    subprocess.run(["python3", os.path.join(HERE, "descriptor.py"), "--meta", META, "--face",
                    os.path.join(OUT, "face_bellows.json"), "--out", RIG_OUT], check=True)
print("BELLOWS_META", json.dumps({k: meta[k] for k in ("tris", "bones", "deform_bones", "height_m")}))
print("BELLOWS_OK", GLB)
