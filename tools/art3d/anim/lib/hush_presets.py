"""Hush's shared pose presets (look B's lanky body, the mime's vocabulary) for every Hush clip spec — `r3d-anim` and
`r3d-anim-hush-b` import them: `from lib.hush_presets import *`. Angles in degrees about ARMATURE axes (+x her
left, -y her front, +z up; see README). The right side is always the mirror (sym / mirror)."""
import math
from lib.pose import sym, merge, mirror, curl, swap, add, scaled

# --- gloves (4 digits: index, middle, ring + thumb; the pinky is unweighted) ---------------------------------------
DIGITS = ("index", "middle", "ring", "pinky")


def glove(side, c=18, thumb=12, spread=0.0):
    return curl(side, c, thumb=thumb, fingers=DIGITS, spread=spread)


def gloves(c=18, thumb=12, spread=0.0):
    return merge(glove("l", c, thumb, spread), glove("r", c, thumb, spread))


FIST = 85
OPEN = 4

# --- arms ------------------------------------------------------------------------------------------------------
ARMS_DOWN = sym({"clavicle_l": [], "upperarm_l": [("y", 74), ("z", -8)], "lowerarm_l": [("z", -18)], "hand_l": [("x", -6)]})
# the mime's paws (the sneak): elbows up and out, forearms folded, gloves drooping at the wrist
PAWS = sym({"clavicle_l": [("z", -8), ("y", -8)], "upperarm_l": [("y", 30), ("z", -58)],
            "lowerarm_l": [("z", -95), ("y", -30)], "hand_l": [("y", 60), ("x", 6)]})
# gloves at the chin (the snicker, the shush)
CHIN = sym({"clavicle_l": [("y", -10)], "upperarm_l": [("y", 34), ("z", -92)], "lowerarm_l": [("y", -104), ("z", -8)],
            "hand_l": [("x", -30), ("z", -22)]})
# fists pumping (the run), per phase k in -1..1 (left arm forward at +1)
def run_arms(k):
    l = {"upperarm_l": [("y", 62), ("z", -8 - 42 * k)], "lowerarm_l": [("z", -78 - 12 * max(0, k))], "hand_l": [("x", -10)]}
    r = mirror_side({"upperarm_l": [("y", 62), ("z", -8 + 42 * k)], "lowerarm_l": [("z", -78 - 12 * max(0, -k))], "hand_l": [("x", -10)]})
    return merge(l, r)


def mirror_side(pose):
    """Left-side entries -> the right side (mirrored)."""
    out = {}
    for n, v in pose.items():
        if n.endswith("_l"):
            out[n[:-2] + "_r"] = mirror(v)
        else:
            out[n] = v
    return out


# --- legs ------------------------------------------------------------------------------------------------------
STAND = {"thigh_l": [("x", -3), ("z", 4)], "calf_l": [("x", 6)], "foot_l": [("x", -3), ("z", -4)],
         "thigh_r": [("x", -2), ("z", -5)], "calf_r": [("x", 4)], "foot_r": [("x", -2), ("z", 5)]}
TIPTOE = {"foot_l": [("x", 38)], "ball_l": [("x", -34)], "foot_r": [("x", 38)], "ball_r": [("x", -34)]}
KNEEL = {"thigh_l": [("x", -95)], "calf_l": [("x", 100)], "foot_l": [("x", -5)],
         "thigh_r": [("x", 15)], "calf_r": [("x", 115)], "foot_r": [("x", 40)], "ball_r": [("x", -40)]}

# --- spine / head ---------------------------------------------------------------------------------------------------
def lean(fwd=0.0, side=0.0, turn=0.0):
    """Distribute a forward lean / side lean / turn over the spine (degrees in total)."""
    return {"spine_01": [("x", fwd * 0.4), ("y", side * 0.4), ("z", turn * 0.3)],
            "spine_02": [("x", fwd * 0.35), ("y", side * 0.35), ("z", turn * 0.35)],
            "spine_03": [("x", fwd * 0.25), ("y", side * 0.25), ("z", turn * 0.35)]}


def head(x=0.0, y=0.0, z=0.0, neck=0.35):
    """Head nod (+x down) / tilt (+y to her left) / turn (+z to her left), split with the neck."""
    return {"neck_01": [("x", x * neck), ("y", y * neck), ("z", z * neck)],
            "Head": [("x", x * (1 - neck)), ("y", y * (1 - neck)), ("z", z * (1 - neck))]}


# --- Clarence (the rubber chicken in her right brace; prop_clarence rides on spine_02) ------------------------------
def clarence(peek=0.0, bob=0.0):
    """peek 0..1 = he rises out of the brace and leans out to look at the audience; bob = a nod (deg)."""
    return {"prop_clarence": {"r": [("y", -40 * peek), ("x", -34 * peek + bob), ("z", -30 * peek)],
                              "t": (-0.02 * peek, -0.03 * peek, 0.07 * peek)}}


def breath(f, period=120.0, amp=1.0):
    """A breathing layer (spine / clavicles) for motion(): fn(frame) -> pose."""
    a = 2 * math.pi * f / period
    s = math.sin(a) * amp
    return {"spine_02": [("x", -1.2 * s)], "spine_03": [("x", -0.8 * s)],
            "clavicle_l": [("y", -1.5 * s)], "clavicle_r": [("y", 1.5 * s)]}


def finger_drum(f, side="l", period=24, amp=22):
    """Fingers tapping in turn (a mime's impatience) for motion()."""
    out = {}
    for i, fg in enumerate(("index", "middle", "ring")):
        ph = (f - i * 4) % period
        k = max(0.0, math.sin(math.pi * ph / 8.0)) if ph < 8 else 0.0
        s = 1 if side == "l" else -1
        out["%s_01_%s" % (fg, side)] = [("y", s * amp * k)]
        out["%s_02_%s" % (fg, side)] = [("y", s * amp * 0.6 * k)]
    return out
