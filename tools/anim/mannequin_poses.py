#!/usr/bin/env python3
"""Authoring helper: writes game/data/rigs/_mannequin/poses.json.

The `_mannequin` poses are specified here as FK channels plus FOOT TARGETS that a 2-bone
leg IK turns into leg_upper / leg_lower / foot rotations, so planted feet stay exactly on
the floor line (y = 0) at the same spot across poses (the animation lint allows 2 px of
planted drift), even under whole-body squash (root sx/sy scale about the feet origin: the
IK solves in the unscaled root space so the soles land where asked in world space).

The walk half-cycle (8 keys, every 3 f of a 48 f loop) is generated from a stance/swing
schedule; the other half is `mirror_of` (the rig swaps every _l/_r partner).

Run:  python3 tools/anim/mannequin_poses.py        (then lint + sheets, see docs/review/rig)
Angles: degrees, clockwise-positive (Godot, y down). A hanging limb swings FORWARD with a
negative rot; an upright part (torso, head) leans FORWARD with a positive rot.
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "rigs", "_mannequin", "poses.json")

L1 = L2 = 64.0
ROOT_OFF = (0.0, -162.0)
HIP = {"r": (0.0, 8.0), "l": (0.0, 8.0)}
# Foot canvas: pivot (24, 10) = ankle; sole points relative to the ankle (flat foot).
SOLE_C = (15.0, 27.0)
HEEL = (-16.0, 27.0)
TOE = (46.0, 27.0)
STANCE = {"r": 23.0, "l": 7.0}     # standing sole-centre x of each foot (world px)


def rot(v, deg):
    t = math.radians(deg)
    return (v[0] * math.cos(t) - v[1] * math.sin(t), v[0] * math.sin(t) + v[1] * math.cos(t))


def hip_pos(side, hips):
    h = rot(HIP[side], hips.get("rot", 0.0))
    return (ROOT_OFF[0] + hips.get("x", 0.0) + h[0], ROOT_OFF[1] + hips.get("y", 0.0) + h[1])


def ik(hip, ankle):
    """(upper world rot, lower rel rot) with the knee bending forward."""
    dx, dy = ankle[0] - hip[0], ankle[1] - hip[1]
    d = min(math.hypot(dx, dy), L1 + L2 - 0.001)
    base = math.degrees(math.atan2(-dx, dy))
    a = math.degrees(math.acos(max(-1.0, min(1.0, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)))))
    g = math.degrees(math.acos(max(-1.0, min(1.0, (L1 * L1 + L2 * L2 - d * d) / (2 * L1 * L2)))))
    return base - a, 180.0 - g


def ankle_for(point, target, foot_rot, sx=1.0, sy=1.0):
    """Ankle (root space) so that foot-local `point` lands on world `target` (root scaled)."""
    p = rot(point, foot_rot)
    return (target[0] / sx - p[0], target[1] / sy - p[1])


def r1(v):
    return round(v, 2)


def build(spec):
    """spec: {root, hips, feet: {side: {...}}, bones, face, tags, silhouette, base}"""
    out = {}
    if "base" in spec:
        out["base"] = spec["base"]
    root = dict(spec.get("root", {}))
    if root:
        out["root"] = {k: r1(v) for k, v in root.items()}
    bones = {k: dict(v) for k, v in spec.get("bones", {}).items()}
    hips = spec.get("hips", {})
    if hips:
        bones.setdefault("hips", {}).update({k: v for k, v in hips.items()})
    sx = root.get("sx", 1.0)
    sy = root.get("sy", 1.0)
    for side, ft in spec.get("feet", {}).items():
        frot = ft.get("rot", 0.0)
        if "ankle" in ft:
            ankle = ft["ankle"]
        elif "toe" in ft:
            ankle = ankle_for(TOE, (ft["toe"], 0.0), frot, sx, sy)
        elif "heel" in ft:
            ankle = ankle_for(HEEL, (ft["heel"], 0.0), frot, sx, sy)
        else:
            ankle = ankle_for(SOLE_C, (ft.get("sole", STANCE[side]), 0.0), frot, sx, sy)
        up_w, low = ik(hip_pos(side, hips), ankle)
        hr = hips.get("rot", 0.0)
        bones["leg_upper_" + side] = {"rot": up_w - hr}
        bones["leg_lower_" + side] = {"rot": low}
        bones["foot_" + side] = dict(bones.get("foot_" + side, {}), rot=frot - up_w - low)
    if bones:
        out["bones"] = {k: {c: (r1(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else v)
                            for c, v in ch.items()} for k, ch in bones.items()}
    for k in ("face", "tags", "silhouette"):
        if k in spec:
            out[k] = spec[k]
    return out


def stand_feet(**kw):
    return {"r": dict({"sole": STANCE["r"]}, **kw.get("r", {})), "l": dict({"sole": STANCE["l"]}, **kw.get("l", {}))}


ARMS_REST = {"arm_upper_r": {"rot": -8}, "arm_lower_r": {"rot": -16}, "hand_r": {"rot": -6, "tex": "open"},
             "arm_upper_l": {"rot": 10}, "arm_lower_l": {"rot": -8}, "hand_l": {"rot": 4, "tex": "open"}}


def arms(**over):
    b = {k: dict(v) for k, v in ARMS_REST.items()}
    for k, v in over.items():
        b.setdefault(k, {}).update(v)
    return b


POSES = {}


def P(name, **spec):
    POSES[name] = build(spec)


# --- idle ------------------------------------------------------------------------------------
P("m_stand", hips={"rot": 0}, feet=stand_feet(),
  bones=dict(arms(), torso={"rot": 2}, head={"rot": -3}), face="neutral", tags=["idle", "stand"],
  silhouette="upright, arms loose, weight even")
P("m_stand_b", hips={"rot": 0.5, "y": 1}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -10}, arm_upper_l={"rot": 12}), torso={"rot": 3}, head={"rot": -1}),
  face="neutral", tags=["idle", "drift"])
P("m_idle_shift", hips={"x": 4, "rot": -3, "y": 2}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -2}, arm_lower_r={"rot": -24}, arm_upper_l={"rot": 16}, arm_lower_l={"rot": -14}),
             torso={"rot": 5}, head={"rot": 4}), face="neutral", tags=["idle", "fidget"],
  silhouette="weight on the front foot, hip cocked")
P("m_idle_look", hips={"rot": 1, "y": 1}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": 6}, arm_lower_r={"rot": -34}, hand_r={"rot": -10, "tex": "fist"},
                  arm_upper_l={"rot": 18}, arm_lower_l={"rot": -40}, hand_l={"tex": "fist"}),
             torso={"rot": -4}, head={"rot": -15}, face_pupils={"y": -3, "x": 2}),
  face="smug", tags=["idle", "fidget", "look"], silhouette="leaning back, chin up, fists on hips")
P("m_idle_look_b", base="m_idle_look", bones={"head": {"rot": -17}, "torso": {"rot": -5}}, tags=["idle", "drift"])

# --- walk (generated below) ----------------------------------------------------------------------

# --- take ------------------------------------------------------------------------------------
P("m_notice", hips={"rot": 0, "y": 1}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -12}, arm_lower_r={"rot": -22}), torso={"rot": -1}, head={"rot": -7},
             face_pupils={"x": 3}), face="blank", tags=["take", "notice"], silhouette="stops, a small glance")
P("m_notice_b", base="m_notice", bones={"head": {"rot": -8}, "torso": {"rot": -1.5}}, tags=["take", "notice", "drift"])
P("m_take_antic", root={"sx": 1.136, "sy": 0.88}, hips={"y": 14, "rot": 4}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": 22}, arm_lower_r={"rot": -78}, hand_r={"rot": -20, "tex": "fist"},
                  arm_upper_l={"rot": 30}, arm_lower_l={"rot": -82}, hand_l={"rot": -20, "tex": "fist"}),
             torso={"rot": 14}, head={"rot": 18, "y": 6}, hat={"y": 5}),
  face="squint", tags=["take", "antic"], silhouette="crouched small, arms tucked, head down, eyes shut")
P("m_take_antic_b", base="m_take_antic", root={"sx": 1.15, "sy": 0.87}, bones={"head": {"rot": 19, "y": 7}},
  tags=["take", "antic", "drift"])
P("m_take_accent", root={"sx": 0.8, "sy": 1.25, "y": -28},
  bones={"hips": {"rot": -4}, "torso": {"rot": -12}, "head": {"rot": -18, "sy": 1.12},
         "leg_upper_r": {"rot": -8}, "leg_lower_r": {"rot": 6}, "foot_r": {"rot": 34},
         "leg_upper_l": {"rot": 10}, "leg_lower_l": {"rot": 8}, "foot_l": {"rot": 26},
         "arm_upper_r": {"rot": -126}, "arm_lower_r": {"rot": -34}, "hand_r": {"rot": -10, "tex": "open"},
         "arm_upper_l": {"rot": 150}, "arm_lower_l": {"rot": -22}, "hand_l": {"rot": 10, "tex": "open"},
         "hat": {"y": -52, "x": -6, "rot": -26},
         "face_eyes": {"sx": 1.45, "sy": 1.45, "y": -4}, "face_pupils": {"sx": 0.8, "sy": 0.8, "y": -4},
         "face_mouth": {"sx": 1.2, "sy": 1.3, "y": 6}, "face_brows": {"y": -8}},
  face="shock", tags=["take", "accent"], silhouette="tall V: arms flung up, feet off the floor, hat popped off")
P("m_take_accent_b", base="m_take_accent", root={"sx": 0.78, "sy": 1.28, "y": -32},
  bones={"hat": {"y": -60, "x": -8, "rot": -30}, "face_eyes": {"sx": 1.6, "sy": 1.6, "y": -5},
         "arm_upper_r": {"rot": -130}, "arm_upper_l": {"rot": 156}},
  tags=["take", "accent"])
P("m_take_hold", base="m_take_accent", root={"sx": 0.82, "sy": 1.22, "y": -26},
  bones={"arm_upper_r": {"rot": -118}, "arm_lower_r": {"rot": -30}, "arm_upper_l": {"rot": 142}, "head": {"rot": -15, "sy": 1.1},
         "foot_r": {"rot": 18}, "foot_l": {"rot": 14},
         "hat": {"y": -44, "x": -5, "rot": -18}, "face_eyes": {"sx": 1.25, "sy": 1.25, "y": -3}},
  tags=["take", "hold"], silhouette="hangs in the air, eyes still popped")
P("m_take_drop", root={"sx": 0.94, "sy": 1.06, "y": -12},
  bones=dict(arms(arm_upper_r={"rot": -80}, arm_lower_r={"rot": -40}, arm_upper_l={"rot": 70}, arm_lower_l={"rot": -40}),
             hips={"y": 2}, torso={"rot": 0}, head={"rot": -8}, hat={"y": -20, "rot": -12},
             leg_upper_r={"rot": -4}, leg_lower_r={"rot": 6}, foot_r={"rot": -2},
             leg_upper_l={"rot": 4}, leg_lower_l={"rot": 5}, foot_l={"rot": -9}),
  face="aghast", tags=["take", "settle", "air"], silhouette="dropping back, feet flat just above the floor")
P("m_take_land", root={"sx": 1.12, "sy": 0.9}, hips={"y": 8, "rot": 2}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -60}, arm_lower_r={"rot": -50}, arm_upper_l={"rot": 50}, arm_lower_l={"rot": -50}),
             torso={"rot": 6}, head={"rot": 4}, hat={"y": -6, "rot": -8}),
  face="aghast", tags=["take", "settle"], silhouette="drops back down, knees soft")
P("m_take_settle", hips={"y": 2}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -42}, arm_lower_r={"rot": -96}, hand_r={"rot": -16, "tex": "open"},
                  arm_upper_l={"rot": -28}, arm_lower_l={"rot": -100}, hand_l={"rot": -10, "tex": "open"}),
             torso={"rot": -6}, head={"rot": -6}), face="aghast", tags=["take", "settle"],
  silhouette="hands up by the cheeks, aghast")
P("m_take_settle_b", base="m_take_settle", bones={"head": {"rot": -4}, "torso": {"rot": -5}, "arm_upper_r": {"rot": -40}},
  tags=["take", "settle", "drift"])

# --- crouch / reach ----------------------------------------------------------------------------
P("m_crouch", hips={"y": 46, "rot": 10}, feet=stand_feet(r={"sole": 30}, l={"sole": -6}),
  bones=dict(arms(arm_upper_r={"rot": -46}, arm_lower_r={"rot": -34}, arm_upper_l={"rot": -24}, arm_lower_l={"rot": -44}),
             torso={"rot": 30}, head={"rot": -20}), face="blank", tags=["crouch", "sneak"],
  silhouette="low, knees bent, leaning in")
P("m_reach", hips={"y": -6, "rot": 4},
  feet={"r": {"toe": 44, "rot": 28}, "l": {"toe": 22, "rot": 30}},
  bones=dict(arms(arm_upper_r={"rot": -128}, arm_lower_r={"rot": -10}, hand_r={"rot": -10, "tex": "open"},
                  arm_upper_l={"rot": 34}, arm_lower_l={"rot": -20}),
             torso={"rot": 16}, head={"rot": -12}, face_pupils={"x": 3, "y": -2}),
  face="blank", tags=["reach"], silhouette="on tiptoe, one arm stretched forward and up")

# --- land ------------------------------------------------------------------------------------
P("m_fall", root={"y": -130, "sx": 0.92, "sy": 1.09},
  bones={"torso": {"rot": -6}, "head": {"rot": -12},
         "arm_upper_r": {"rot": -166}, "arm_lower_r": {"rot": -20}, "hand_r": {"tex": "open"},
         "arm_upper_l": {"rot": 152}, "arm_lower_l": {"rot": -26}, "hand_l": {"tex": "open"},
         "leg_upper_r": {"rot": -24}, "leg_lower_r": {"rot": 34}, "foot_r": {"rot": 16},
         "leg_upper_l": {"rot": 12}, "leg_lower_l": {"rot": 26}, "foot_l": {"rot": 8},
         "hat": {"y": -26, "rot": -10}},
  face="aghast", tags=["fall", "air"], silhouette="dropping, arms up, legs dangling")
P("m_fall_b", base="m_fall", root={"y": -16, "sx": 0.87, "sy": 1.15},
  bones={"arm_upper_r": {"rot": -172}, "arm_upper_l": {"rot": 157}, "hat": {"y": -40, "rot": -14},
         "leg_upper_r": {"rot": -12}, "leg_lower_r": {"rot": 14}, "leg_upper_l": {"rot": 8}, "leg_lower_l": {"rot": 12}},
  tags=["fall", "air", "stretch"])
P("m_land_squash", root={"sx": 1.3, "sy": 0.7}, hips={"y": 20, "rot": 6}, feet=stand_feet(),
  bones={"torso": {"rot": 12}, "head": {"rot": 12, "y": 4},
         "arm_upper_r": {"rot": -84}, "arm_lower_r": {"rot": -18}, "hand_r": {"rot": 20, "tex": "open"},
         "arm_upper_l": {"rot": 78}, "arm_lower_l": {"rot": -24}, "hand_l": {"rot": 10, "tex": "open"},
         "hat": {"y": 10, "sy": 0.8}},
  face="wince", tags=["land", "squash"], silhouette="flattened wide, arms flung out")
P("m_land_squash_b", base="m_land_squash", root={"sx": 1.28, "sy": 0.72}, bones={"arm_upper_r": {"rot": -80}},
  tags=["land", "squash"])
P("m_land_stretch", root={"sx": 0.87, "sy": 1.15}, hips={"y": 3}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -42}, arm_lower_r={"rot": -22}, arm_upper_l={"rot": 40}, arm_lower_l={"rot": -20}),
             torso={"rot": -4}, head={"rot": -8}, hat={"y": -16, "rot": 6}),
  face="shock", tags=["land", "stretch"], silhouette="rebounds tall and thin")
P("m_dazed", hips={"y": 12, "rot": 6}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": 4}, arm_lower_r={"rot": -4}, hand_r={"rot": 12}, arm_upper_l={"rot": 12}, arm_lower_l={"rot": -2}),
             torso={"rot": 18}, head={"rot": 26, "x": 2}, hat={"rot": 22, "x": 8, "y": 4},
             face_pupils={"x": -2, "y": 2}),
  face="dazed", tags=["dazed", "hold"], silhouette="slumped, head lolling, hat askew")
P("m_dazed_b", base="m_dazed", hips={"y": 13, "rot": 4}, feet=stand_feet(),
  bones={"torso": {"rot": 15}, "head": {"rot": 20}, "hat": {"rot": 16, "x": 7, "y": 3}}, tags=["dazed", "hold", "drift"])
P("m_stand_up", hips={"y": 1}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -20}, arm_lower_r={"rot": -30}), torso={"rot": -3}, head={"rot": -6},
             hat={"rot": 10, "x": 5, "y": 2}), face="cross", tags=["settle"], silhouette="back upright, cross")
P("m_stand_up_b", base="m_stand_up", bones={"head": {"rot": -4}, "torso": {"rot": -2}}, tags=["settle", "drift"])

# --- look back / launch --------------------------------------------------------------------------
P("m_look_back", hips={"rot": -2}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": 22}, arm_lower_r={"rot": -20}, arm_upper_l={"rot": 30}),
             torso={"rot": -10}, head={"rot": -10},
             face_eyes={"x": -30}, face_pupils={"x": -35}, face_brows={"x": -30}, face_mouth={"x": -36}),
  face="blank", tags=["look"], silhouette="leans back, face turned over the shoulder")
P("m_sip", hips={"rot": 0}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -42}, arm_lower_r={"rot": -128}, hand_r={"rot": -34, "tex": "fist"},
                  arm_upper_l={"rot": 14}, arm_lower_l={"rot": -12}),
             torso={"rot": -2}, head={"rot": -8}), face="sip", tags=["act", "sip"],
  silhouette="mug at the mouth, elbow out")
P("m_sip_b", base="m_sip", bones={"head": {"rot": -12}, "torso": {"rot": -4}, "arm_lower_r": {"rot": -132}},
  tags=["act", "sip", "drift"])
P("m_launch_antic", root={"sx": 1.09, "sy": 0.92}, hips={"y": 8, "rot": 3}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -30}, arm_lower_r={"rot": -122}, hand_r={"rot": -30, "tex": "fist"},
                  arm_upper_l={"rot": 22}, arm_lower_l={"rot": -60}, hand_l={"tex": "fist"}),
             torso={"rot": 16}, head={"rot": 16, "y": 4}), face="suppress", tags=["antic"],
  silhouette="hunched over the mug, cheeks full")
P("m_launch_antic_b", base="m_launch_antic", root={"sx": 1.1, "sy": 0.91}, bones={"head": {"rot": 17}}, tags=["antic", "drift"])
P("m_jolt", root={"sx": 0.88, "sy": 1.14, "y": -22},
  bones={"hips": {"rot": -6}, "torso": {"rot": -20}, "head": {"rot": -24},
         "leg_upper_r": {"rot": -16}, "leg_lower_r": {"rot": 12}, "foot_r": {"rot": 16},
         "leg_upper_l": {"rot": 12}, "leg_lower_l": {"rot": 10}, "foot_l": {"rot": 10},
         "arm_upper_r": {"rot": -138}, "arm_lower_r": {"rot": -24}, "hand_r": {"rot": -10, "tex": "open"},
         "arm_upper_l": {"rot": 124}, "arm_lower_l": {"rot": -22}, "hand_l": {"tex": "open"},
         "hat": {"y": -40, "rot": -30},
         "face_eyes": {"sx": 1.35, "sy": 1.35, "y": -3}, "face_mouth": {"sy": 1.2}},
  face="shock", tags=["take", "accent"], silhouette="arched back, arm flung up, the mug gone")
P("m_jolt_b", base="m_jolt", root={"sx": 0.86, "sy": 1.16, "y": -26}, bones={"hat": {"y": -48, "rot": -34}}, tags=["take", "accent"])
P("m_watch_up", hips={"rot": -2}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -118}, arm_lower_r={"rot": -36}, hand_r={"tex": "open"},
                  arm_upper_l={"rot": 42}, arm_lower_l={"rot": -64}),
             torso={"rot": -10}, head={"rot": -30}, hat={"rot": -12, "y": -6}, face_pupils={"y": -4, "x": 2}),
  face="aghast", tags=["hold", "look"], silhouette="gaping up, one hand reaching after it")
P("m_watch_up_b", base="m_watch_up", bones={"head": {"rot": -22}, "arm_upper_r": {"rot": -106}, "face_pupils": {"y": 0, "x": 3}},
  tags=["hold", "look", "drift"])
P("m_flinch", root={"sx": 1.06, "sy": 0.94}, hips={"y": 6}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -30}, arm_lower_r={"rot": -110}, hand_r={"tex": "fist"},
                  arm_upper_l={"rot": -10}, arm_lower_l={"rot": -110}, hand_l={"tex": "fist"}),
             torso={"rot": 8}, head={"rot": 12, "y": 4}), face="wince", tags=["flinch"],
  silhouette="shoulders up, fists by the face")
P("m_look_down", hips={"y": 4, "rot": 2}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": -6}, arm_lower_r={"rot": -10}, arm_upper_l={"rot": 12}),
             torso={"rot": 10}, head={"rot": 24}, face_pupils={"y": 3, "x": 3}), face="dazed", tags=["look"],
  silhouette="stares at the mess on the floor")
P("m_look_down_b", base="m_look_down", bones={"head": {"rot": 21}, "torso": {"rot": 8}}, tags=["look", "drift"])

# --- beats (suppressed, slow burn) ---------------------------------------------------------------
P("m_suppress", root={"sx": 1.03, "sy": 0.97}, hips={"y": 3}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": 4}, arm_lower_r={"rot": -8}, hand_r={"tex": "fist"},
                  arm_upper_l={"rot": 6}, arm_lower_l={"rot": -4}, hand_l={"tex": "fist"}),
             torso={"rot": 1, "sy": 0.95}, head={"rot": 4, "y": 8}), face="suppress", tags=["suppressed"],
  silhouette="shoulders up to the ears, fists clenched, lips pressed")
P("m_suppress_b", base="m_suppress", bones={"head": {"rot": -2, "y": 7}, "torso": {"rot": 2, "sy": 0.94}, "hat": {"rot": 5}},
  tags=["suppressed", "drift"])
P("m_slow_burn", hips={"rot": 0}, feet=stand_feet(),
  bones=dict(arms(arm_upper_r={"rot": 34}, arm_lower_r={"rot": -96}, hand_r={"rot": -20, "tex": "fist"},
                  arm_upper_l={"rot": 40}, arm_lower_l={"rot": -102}, hand_l={"tex": "fist"}),
             torso={"rot": 0}, head={"rot": 0}, face_pupils={"x": -1}), face="cross", tags=["slow_burn"],
  silhouette="square to the audience, fists on hips, flat stare")
P("m_slow_burn_b", base="m_slow_burn", bones={"head": {"rot": 1}, "torso": {"rot": 0.5}}, tags=["slow_burn", "drift"])


# --- walk: 48 f loop, keys every 3 f; right foot contact at f0, left at f24 ---------------------
STEP = 72.0            # sole travel per step (px); stride_px = 2 × STEP per 48 f cycle
V = STEP / 24.0        # px per frame
SOLE0 = 48.0           # sole-centre x at heel strike


def foot_state(f):
    """(ankle x, ankle y, foot world rot) of a foot whose heel strikes at f = 0 (48 f cycle)."""
    f = f % 48
    if f <= 24:
        x = SOLE0 - V * f          # sole centre, planted, moving back
        if f < 3:
            r = -8.0 * (1.0 - f / 3.0)       # heel strike rolls flat
            a = ankle_for(HEEL, (x + HEEL[0] - SOLE_C[0], 0.0), r)
            return a[0], a[1], r
        return x - SOLE_C[0], -SOLE_C[1], 0.0
    if f <= 28:
        toe0 = SOLE0 - V * 24 + (TOE[0] - SOLE_C[0])
        toe = toe0 - V * (f - 24)
        r = 22.0 * (f - 24) / 4.0
        a = ankle_for(TOE, (toe, 0.0), r)
        return a[0], a[1], r
    # swing 28 → 48: from the toe-off ankle to the heel-strike ankle.
    s0 = foot_state(28)
    s1 = foot_state(0)
    t = (f - 28) / 20.0
    e = t * t * (3 - 2 * t)
    x = s0[0] + (s1[0] - s0[0]) * e
    y = s0[1] + (s1[1] - s0[1]) * t - 20.0 * math.sin(math.pi * t)
    r = 22.0 + (-8.0 - 22.0) * e
    return x, y, r


def walk_pose(f):
    bob = 3.2 + 2.0 * math.cos(2 * math.pi * f / 24.0)
    hips = {"y": bob, "rot": 0.0}
    feet = {}
    for side, ph in (("r", f), ("l", f + 24)):
        ax, ay, fr = foot_state(ph)
        feet[side] = {"ankle": (ax, ay), "rot": fr}
    sw = math.cos(2 * math.pi * f / 48.0)
    bones = {
        "torso": {"rot": 5 + 1.2 * math.cos(2 * math.pi * f / 24.0)},
        "head": {"rot": -4 - 1.2 * math.cos(2 * math.pi * f / 24.0)},
        "arm_upper_r": {"rot": 18 * sw}, "arm_lower_r": {"rot": -18 + 8 * sw}, "hand_r": {"rot": -4, "tex": "open"},
        "arm_upper_l": {"rot": -18 * sw}, "arm_lower_l": {"rot": -18 - 8 * sw}, "hand_l": {"rot": -4, "tex": "open"},
    }
    return build({"hips": hips, "feet": feet, "bones": bones})


for k in range(8):
    f = k * 3
    name = "m_walk_r%d" % k
    pose = walk_pose(f)
    pose["face"] = "neutral"
    pose["tags"] = ["loco", "walk"] + (["contact"] if k == 0 else ["pass"] if k == 4 else [])
    if k == 0:
        pose["silhouette"] = "contact: right heel strikes, arms opposite"
    if k == 4:
        pose["silhouette"] = "passing: right leg planted under the body, left swinging through"
    POSES[name] = pose

MIRROR = {"m_walk_l%d" % k: "m_walk_r%d" % k for k in range(8)}


def main():
    doc = {"version": 1, "poses": POSES, "mirror_of": MIRROR}
    with open(OUT, "w") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")
    print("wrote %s: %d poses + %d mirrored" % (OUT, len(POSES), len(MIRROR)))


if __name__ == "__main__":
    main()
