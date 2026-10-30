"""The Mischief Next Door cast skeleton: one compact, self-contained armature for every character.

Why not the Quaternius UAL skeleton the look-devs used (tools/art3d/look-toy)? Three reasons:

1. **Budget.** UAL is the UE5 mannequin: 65 bones, 40 of them finger joints — on a cast whose hands
   are mitten gloves and a four-finger plush paw. REDESIGN_3D §5.6 allows ≤ 50 deform bones per
   character *including* jiggle. This skeleton spends 20 on the body and leaves 30 for secondary
   motion, where the comedy actually is.
2. **The clips we already own.** `game/data/rigs/{hush,bellows}` hold 236 authored poses and 34
   lint-checked clips whose timing the team has already reviewed. Their channels (`pelvis`, `torso`,
   `head`, `arm_upper_r`, …) are a plain humanoid hierarchy, so a skeleton shaped to match retargets
   all of them for free (see `game/view/char3d/pose_retarget.gd`). UAL's hierarchy does not line up,
   and its own library clips are generic locomotion — not what makes this game funny.
3. **No external fetch.** The CC0 packs are deliberately not committed (`tools/art3d/SOURCES.txt`),
   so every rebuild depended on re-downloading them.

**Axes.** Blender build space: +Z up, +X = the direction the character faces (the 2D art faces
right), +Y = the character's left. The sagittal plane is therefore XZ, and every retargeted 2D
rotation is a rotation about **−Y** here. `export_yup=True` maps Blender (x, y, z) → glTF
(x, z, −y), so in Godot the character faces +X, up is +Y, and the 2D rotations become rotations
about **+Z** — the same sense as the 2D rig. `FK_AXIS` below is exported in the rig descriptor so
the runtime never hardcodes it.
"""
import math

# The sagittal rotation axis, in each BONE'S OWN rest frame (the retarget post-multiplies it onto
# the bone's rest rotation). Blender bones run along their local +Y and this skeleton is built with
# no roll, so a knee or elbow bending in the character's side plane turns about local X. Verified by
# rendering hush/loco_walk with all three candidate axes: X gives a stride with one leg forward and
# one back, Y twists the legs together, Z lifts the knee sideways.
FK_AXIS = (1.0, 0.0, 0.0)

# Deform bones, in parent-before-child order. Each entry:
#   name, parent, head (x, y, z), tail (x, y, z)   -- Blender build space, metres.
# `fk` names the 2D rig channel this bone replays (None = 3D-only, driven procedurally).
#
# Finger joints are deliberately absent: both characters wear gloves/mittens, and the hand shape that
# sells a pose at 64 px is the silhouette of the whole mitt, not its knuckles.
CORE = [
    #  name           parent        fk channel
    ("root",          None,         None),
    ("pelvis",        "root",       "pelvis"),
    ("spine",         "pelvis",     "torso"),
    ("chest",         "spine",      None),      # shares the torso angle (see TORSO_SPLIT)
    ("neck",          "chest",      None),      # shares the head angle (see HEAD_SPLIT)
    ("head",          "neck",       "head"),
    ("arm_upper_l",   "chest",      "arm_upper_l"),
    ("arm_lower_l",   "arm_upper_l", "arm_lower_l"),
    ("hand_l",        "arm_lower_l", "hand_l"),
    ("arm_upper_r",   "chest",      "arm_upper_r"),
    ("arm_lower_r",   "arm_upper_r", "arm_lower_r"),
    ("hand_r",        "arm_lower_r", "hand_r"),
    ("leg_upper_l",   "pelvis",     "leg_upper_l"),
    ("leg_lower_l",   "leg_upper_l", "leg_lower_l"),
    ("foot_l",        "leg_lower_l", "foot_l"),
    ("toe_l",         "foot_l",     None),
    ("leg_upper_r",   "pelvis",     "leg_upper_r"),
    ("leg_lower_r",   "leg_upper_r", "leg_lower_r"),
    ("foot_r",        "leg_lower_r", "foot_r"),
    ("toe_r",         "foot_r",     None),
]

# A 2D "torso" / "head" rotation is one joint; in 3D the same angle spread over two bones reads as a
# spine rather than a hinge. The runtime splits the retargeted angle in these ratios.
TORSO_SPLIT = {"spine": 0.55, "chest": 0.45}
HEAD_SPLIT = {"neck": 0.35, "head": 0.65}


def hush_proportions():
    """Hush: 1.60 m, 3.4 heads (REDESIGN_3D §5.6). Lanky-for-a-toy, long shins, big mitts.

    The look-dev's note was "her legs are sticks": the fix is not length but *taper and knee* — the
    skeleton here gives the shin its own bone with a real knee offset so the leg can bend with a
    silhouette instead of scissoring as one line.
    """
    return _layout(
        height=1.60,
        pelvis_z=0.62, spine_z=0.80, chest_z=0.96, neck_z=1.09, head_z=1.16,
        head_top=1.60,
        shoulder_y=0.115, shoulder_z=0.93,
        upper_arm=0.21, lower_arm=0.20, hand=0.115,
        hip_y=0.070, thigh=0.30, shin=0.27, ankle_z=0.050,
        foot_len=0.155, toe_len=0.055,
    )


def bellows_proportions():
    """Horace Bellows: 1.72 m, a barrel on short legs, the head low and forward on a pouchy neck.

    The look-dev's note was "a purple blob": the fix is skeletal as well as surface — the shoulders
    sit *wider and lower* than Hush's and the arms start clear of the belly, so the arm silhouette
    separates from the torso instead of sinking into it.
    """
    return _layout(
        height=1.72,
        pelvis_z=0.56, spine_z=0.74, chest_z=0.96, neck_z=1.12, head_z=1.20,
        head_top=1.72,
        shoulder_y=0.195, shoulder_z=1.03,
        upper_arm=0.22, lower_arm=0.21, hand=0.125,
        hip_y=0.090, thigh=0.26, shin=0.23, ankle_z=0.055,
        foot_len=0.185, toe_len=0.060,
    )


def _layout(height, pelvis_z, spine_z, chest_z, neck_z, head_z, head_top,
            shoulder_y, shoulder_z, upper_arm, lower_arm, hand,
            hip_y, thigh, shin, ankle_z, foot_len, toe_len):
    """Turn the proportion numbers into (head, tail) pairs for every bone in CORE.

    Arms hang slightly forward and out, legs slightly apart: a rest pose with no two bones parallel,
    so the retargeted 2D angles never land on a degenerate straight line.
    """
    b = {}
    b["root"] = ((0, 0, 0), (0, 0, pelvis_z))
    b["pelvis"] = ((0, 0, pelvis_z), (0, 0, spine_z))
    b["spine"] = ((0, 0, spine_z), (0, 0, chest_z))
    b["chest"] = ((0, 0, chest_z), (0, 0, neck_z))
    b["neck"] = ((0, 0, neck_z), (0, 0, head_z))
    b["head"] = ((0, 0, head_z), (0, 0, head_top))

    for side, sy in (("l", 1.0), ("r", -1.0)):
        sh = (0.010, sy * shoulder_y, shoulder_z)
        # The arm drops and splays a little; `dx` carries it forward so the elbow never crosses the hip.
        el = (sh[0] + 0.030, sy * (shoulder_y + 0.030), sh[2] - upper_arm)
        wr = (el[0] + 0.020, sy * (shoulder_y + 0.045), el[2] - lower_arm)
        hd = (wr[0] + 0.010, sy * (shoulder_y + 0.050), wr[2] - hand)
        b[f"arm_upper_{side}"] = (sh, el)
        b[f"arm_lower_{side}"] = (el, wr)
        b[f"hand_{side}"] = (wr, hd)

        hip = (0.0, sy * hip_y, pelvis_z)
        kn = (0.006, sy * hip_y, pelvis_z - thigh)
        an = (0.0, sy * hip_y, ankle_z)
        b[f"leg_upper_{side}"] = (hip, kn)
        b[f"leg_lower_{side}"] = (kn, an)
        b[f"foot_{side}"] = (an, (foot_len * 0.72, sy * hip_y, ankle_z * 0.35))
        b[f"toe_{side}"] = ((foot_len * 0.72, sy * hip_y, ankle_z * 0.35),
                            (foot_len * 0.72 + toe_len, sy * hip_y, 0.004))
    # Knee and ankle are forced a hair off the thigh line above (kn[0] = 0.006) so the IK solver has
    # an unambiguous bend direction without a pole target.
    b["_height"] = height
    return b


# Secondary-motion ("jiggle") bones. These never appear in a clip: the runtime swings them from the
# motion of their parent (game/view/char3d/jiggle3d.gd). Each entry:
#   name, parent, head, tail, stiffness, damping, max_deg
# Stiffness is the spring constant in the jiggle solver; a floppier part uses a lower one.
#
# IMPORTANT: head/tail are offsets from the PARENT BONE'S HEAD, not from the part's visual centre.
# A head bone starts at the neck, so anything sitting on the crown needs most of the head's height
# in its `up` term — getting this wrong buries the beret and the bouffant inside the skull.
HUSH_JIGGLE = [
    # Hush's head bone spans z 1.16 -> 1.60; the skull centre is ~1.36 and the crown ~1.60.
    ("beret",      "head", (-0.020, 0.0, 0.410), (-0.040, 0.0, 0.530), 150.0, 0.62, 16.0),
    ("hair_back",  "head", (-0.090, 0.0, 0.215), (-0.130, 0.0, 0.055), 110.0, 0.58, 22.0),
    # Chest bone head is z 0.96; the braces run down the front of the torso.
    ("brace_l",    "chest", (0.080, 0.058, 0.020), (0.092, 0.062, -0.165), 220.0, 0.70, 9.0),
    ("brace_r",    "chest", (0.080, -0.058, 0.020), (0.092, -0.062, -0.165), 220.0, 0.70, 9.0),
    ("clarence",   "hand_l", (0.0, 0.0, -0.020), (0.0, 0.0, -0.110), 90.0, 0.50, 34.0),
]

BELLOWS_JIGGLE = [
    # Bellows' head bone spans z 1.20 -> 1.72; the skull centre is ~1.43 and the crown ~1.64.
    ("bouffant_c", "head", (-0.010, 0.0, 0.350), (-0.025, 0.0, 0.500), 130.0, 0.60, 15.0),
    ("bouffant_l", "head", (-0.030, 0.100, 0.300), (-0.055, 0.165, 0.420), 115.0, 0.56, 19.0),
    ("bouffant_r", "head", (-0.030, -0.100, 0.300), (-0.055, -0.165, 0.420), 115.0, 0.56, 19.0),
    ("sideburn_l", "head", (0.020, 0.145, 0.215), (0.012, 0.160, 0.090), 170.0, 0.64, 14.0),
    ("sideburn_r", "head", (0.020, -0.145, 0.215), (0.012, -0.160, 0.090), 170.0, 0.64, 14.0),
    ("nose",       "head", (0.150, 0.0, 0.215), (0.205, 0.0, 0.200), 300.0, 0.80, 7.0),
    # Spine bone head is z 0.74, chest 0.96, pelvis 0.56.
    ("belly",      "spine", (0.130, 0.0, 0.075), (0.195, 0.0, -0.020), 190.0, 0.74, 11.0),
    ("cravat",     "chest", (0.125, 0.0, 0.105), (0.150, 0.0, -0.045), 140.0, 0.58, 20.0),
    ("tail_l",     "pelvis", (-0.120, 0.080, 0.030), (-0.150, 0.095, -0.250), 100.0, 0.54, 26.0),
    ("tail_r",     "pelvis", (-0.120, -0.080, 0.030), (-0.150, -0.095, -0.250), 100.0, 0.54, 26.0),
]

# Prop sockets: empty bones a held item parents to. Kept out of the jiggle list so they stay rigid.
HUSH_SOCKETS = [
    ("socket_r", "hand_r", (0.03, 0.0, -0.055), (0.03, 0.0, 0.015)),
    ("socket_l", "hand_l", (0.03, 0.0, -0.055), (0.03, 0.0, 0.015)),
]
BELLOWS_SOCKETS = [
    ("socket_r", "hand_r", (0.03, 0.0, -0.060), (0.03, 0.0, 0.015)),
    ("socket_l", "hand_l", (0.03, 0.0, -0.060), (0.03, 0.0, 0.015)),
]


def bone_specs(prop, jiggle, sockets):
    """[(name, parent, head, tail)] for Blender, deform bones first."""
    out = []
    for name, parent, _fk in CORE:
        h, t = prop[name]
        out.append((name, parent, h, t))
    for name, parent, h, t, _s, _d, _m in jiggle:
        ph = prop[parent][0] if parent in prop else (0, 0, 0)
        out.append((name, parent, _add(ph, h), _add(ph, t)))
    for name, parent, h, t in sockets:
        ph = prop[parent][0] if parent in prop else (0, 0, 0)
        out.append((name, parent, _add(ph, h), _add(ph, t)))
    return out


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def descriptor(who, prop, jiggle, sockets, face_atlas):
    """The runtime rig descriptor written to game/data/rigs3d/<who>.json."""
    fk = {}
    for name, _parent, ch in CORE:
        if ch:
            fk[ch] = [name]
    fk["torso"] = list(TORSO_SPLIT.keys())
    fk["head"] = list(HEAD_SPLIT.keys())
    return {
        "version": 1,
        "rig": who,
        "doc": "3D cast rig built by tools/art3d/cast/build_%s.py. Angles come from the 2D clips in "
               "game/data/anim/%s; everything else is procedural (jiggle, IK, squash, overlap)." % (who, who),
        "height_m": prop["_height"],
        "fk_axis": list(FK_AXIS),
        "fk_map": fk,
        "splits": {"torso": TORSO_SPLIT, "head": HEAD_SPLIT},
        "jiggle": [
            {"bone": n, "parent": p, "stiffness": s, "damping": d, "max_deg": m}
            for n, p, _h, _t, s, d, m in jiggle
        ],
        "sockets": [n for n, _p, _h, _t in sockets],
        "ik": {
            "arm_l": {"upper": "arm_upper_l", "lower": "arm_lower_l", "tip": "hand_l", "bend": [0, -1, 0]},
            "arm_r": {"upper": "arm_upper_r", "lower": "arm_lower_r", "tip": "hand_r", "bend": [0, -1, 0]},
            "leg_l": {"upper": "leg_upper_l", "lower": "leg_lower_l", "tip": "foot_l", "bend": [1, 0, 0]},
            "leg_r": {"upper": "leg_upper_r", "lower": "leg_lower_r", "tip": "foot_r", "bend": [1, 0, 0]},
        },
        "feet": ["foot_l", "foot_r"],
        "toes": ["toe_l", "toe_r"],
        "face": face_atlas,
    }
