"""hush_dims -- the numbers of the R3D Hush: look B's body dimensions, look A's construction.

Blender armature space, metres: the character faces -Y, +X = the character's LEFT, +Z up, feet on z = 0.
(glTF / Godot: +Y up, the character faces +Z.)

Every body number here comes from look B (`tools/art3d/look-cartoon/chars/hush_meta.json` joints and
`src/heads.py` HUSH head: cranium 0.146 x 0.142 x 0.152 about head_c, chin ~1.195 m, beret top 1.60 m); the forms
that are built on them (superellipsoid blobs, swept capsules, masked shells, bisect-cut colour borders) are look A's.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
UAL1 = os.path.join(REPO, "tools", "art3d", "vendor", "ual", "UAL1_Standard.glb")
B_META = os.path.join(REPO, "tools", "art3d", "look-cartoon", "chars", "hush_meta.json")

HEIGHT_M = 1.60          # to the top of the beret (stalk excluded) -- the owner's pick (look B)


def b_joints() -> dict:
    """Look B's joint rest positions (bone heads), {bone: (x, y, z)} for the 65 UAL bones."""
    meta = json.load(open(B_META))
    return {k: tuple(v) for k, v in meta["joints"].items() if not k.startswith(("eye_", "lid_", "brow_"))}


# ---- head (B's head: skull 0.29-0.30 m wide, chin 1.195 -> crown 1.55, beret to 1.60) ----------------------
HEAD_C = (0.0, 0.028, 1.372)      # superellipsoid centre (B head_c (0, 0.037, 1.353) + the cranium's +0.045 lift, averaged)
HEAD_A = 0.147                    # half width  (B cranium 0.146)
HEAD_B = 0.138                    # half depth  (B cranium 0.142)
HEAD_CZ = 0.180                   # half height (chin 1.192 .. crown 1.552)
HEAD_P = 2.45                     # superellipse power: a flatter vinyl face front than B's sphere (room for the face card)

# the face card: planar FaceUV square on the head's front faces (u right as seen from the front, v up)
FACE_C = (0.0, 1.352)             # (x, z) centre of the face square
FACE_W = 0.300                    # width = height of the face square (m); the painted face fills ~0.26 of it

# beret (cherry red, tilted to her left, a stalk): its highest point is placed at HEIGHT_M exactly
BERET_R = (0.172, 0.164, 0.040)   # semi-axes (B: 0.168 x 0.158 x 0.036)
BERET_TILT = (-6.0, -14.0, 0.0)   # degrees about X, Y (tips down on her left, a little back)
BERET_OFF = (0.018, 0.012, 0.168)  # centre offset from HEAD_C before the height fit

# neck: B's neck bone 1.108 -> 1.228 (the Breton collar may cover it, never shorten it)
NECK_R = 0.036

# torso: a loose Breton top, chest flattened (B: narrow, shoulders at x +-0.118, waist 0.825)
TORSO_C_Y = 0.028
TORSO_Z0 = 0.765                  # hem (the loose top hangs over the trousers)
TORSO_Z1 = 1.190                  # shoulder top (wide enough at the shoulder joints: no puffed sleeves)
TORSO_A = 0.132                   # half width at the chest
TORSO_B = 0.092                   # half depth (flattened chest)

# arms: B's (shoulder 1.127 at x +-0.118, upper arm 0.199, forearm 0.206; glove 1.65 x hand)
SLEEVE_R = (0.040, 0.034, 0.031)  # shoulder, elbow, wrist
GLOVE_K = 1.65

# legs: B's (hip 0.787, knee 0.456, ankle 0.082), straight navy trousers widening a little at the hem
LEG_R = {"hip": 0.074, "thigh": 0.066, "knee": 0.050, "calf": 0.057, "ankle": 0.047, "hem": 0.061}

# stone white of the freeze plinth / marble (REDESIGN 4.2)
STONE = "#E8E6E1"
