"""hush/rig_allegro_go_go — ALLEGRO-GO-GO! (rig:allegro_go_go, tier Q = 48 f, lock rig_pm; REDESIGN §4.3, index R5):
the gramophone's big red-knobbed speed lever sits at her left in the reach row (≈ 1.0 m, no step). She eyes it,
wiggles her fingers, turns in and wraps both gloves round it (the right on the red knob, the left on the stick),
leans in (anticipation f 0–16) and YANKS it back to ×3 (f 16–22: the pop — she throws her weight away from it, knees
bent, the lever arcing 40° toward her under her gloves), holds it there straining with her face to the audience
(f 22–40), lets go and dusts off her gloves (f 40–48). Cheat 10°.

Staging from house3d.json (reach_geometry = the knob, prop_point for the lever pivot): re-bake when r3d-sets moves the
gramophone. The prop's own `rig` anim should move the lever over the same progress (16/48 → 22/48, 40° about its
pivot's x axis, toward the front)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage, reach_geometry, prop_point
from lib.pose import merge, sym, mix
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head, breath

L = 48
YANK0, YANK1, LET_GO = 16, 22, 40
PIVOT = (-0.133, 0.54, 0.15)          # the lever's part pivot in the gramophone prop (tools/art3d/set/build.py)
KNOB = (-0.133, 0.667, 0.217)         # = house3d reach_target
STICK = 0.55                          # the left glove this far from the pivot to the knob (on the stick)
SWING = 40.0                          # degrees the lever travels to x3
FALLBACK = {"target": (8.0, 1.0, -1.72), "pos": {"x": 7.6, "z": -1.3, "step": None, "step_h": 0.0}, "facing": 1,
            "band": "mid"}

BRACE = {"thigh_l": [("x", -20), ("z", 10)], "calf_l": [("x", 30)], "foot_l": [("x", -8), ("z", -8)],
         "thigh_r": [("x", -14), ("z", -12)], "calf_r": [("x", 24)], "foot_r": [("x", -8), ("z", 8)]}
HAUL = {"thigh_l": [("x", -40), ("z", 12)], "calf_l": [("x", 58)], "foot_l": [("x", -16), ("z", -8)],
        "thigh_r": [("x", -8), ("z", -18)], "calf_r": [("x", 30)], "foot_r": [("x", -20), ("z", 10)],
        "_pelvis": (0.10, 0.04, -0.05)}
TOWARD = {"_pelvis": (0.12, -0.04, -0.02)}          # the hips over toward the lever (her left), within L27's 0.15 m


def lever_point(g, frac, alpha):
    """World point `frac` of the way from the lever pivot to the knob with the lever swung `alpha` degrees."""
    if g.get("source") == "fallback":
        t = g["target"]
        return (t[0], t[1] - 0.1 * (1 - frac), t[2] + 0.1 * math.sin(math.radians(alpha)))
    v = [k - p for k, p in zip(KNOB, PIVOT)]
    a = math.radians(alpha)
    y = v[1] * math.cos(a) - v[2] * math.sin(a)
    z = v[1] * math.sin(a) + v[2] * math.cos(a)
    return prop_point("parlour_gramophone", (PIVOT[0], PIVOT[1] + y * frac, PIVOT[2] + z * frac))


def build(ctx):
    g = reach_geometry("parlour_gramophone", fallback=FALLBACK)
    pos = g["pos"]
    st = Stage(x=pos["x"], z=pos["z"], facing=g["facing"], cheat=10.0)
    c = Clip(ctx, "hush/rig_allegro_go_go", length=L, lock="rig_pm", cheat_deg=10.0, stage=st, audio="own",
             blend_in=6, notes="staged at %s from %s" % (st.as_json(), g.get("source")))
    stand = merge(ARMS_DOWN, STAND, gloves(18, 12), head(x=-4))

    def alpha(f):
        if f <= YANK0:
            return 0.0
        if f >= YANK1:
            return SWING
        u = (f - YANK0) / float(YANK1 - YANK0)
        return SWING * (1.0 - (1.0 - u) ** 3)                  # the yank: fast off the mark, easing into the stop

    def grip(side):
        frac = 1.0 if side == "r" else STICK
        return lambda f: st.to_char(lever_point(g, frac, alpha(f)))

    WIGGLE = merge(glove("l", 8, 6, spread=16), glove("r", 8, 6, spread=16))
    EYE = sym({"upperarm_l": [("y", 50), ("z", -30)], "lowerarm_l": [("z", -70)], "hand_l": [("x", -30)]})
    TURN_IN = lean(fwd=10, side=12, turn=62)                     # the chest round to the lever (her left)
    c.key(0, stand)
    c.key(5, merge(stand, EYE, WIGGLE, lean(fwd=4, turn=20), head(x=6, z=36)), "in_out_sine")        # eyes it
    c.key(9, merge(stand, EYE, glove("l", 30, 20), glove("r", 30, 20), BRACE, TOWARD, TURN_IN, head(z=30)),
          "in_out_sine")
    c.key(13, merge(stand, BRACE, TOWARD, gloves(70, 40), lean(fwd=16, side=16, turn=64), head(x=10, z=20)),
          "in_out_sine")                                                                             # grips, leans in
    c.key(YANK0, merge(stand, BRACE, TOWARD, gloves(80, 50), lean(fwd=20, side=18, turn=64), head(x=14, z=16)),
          "in_quad")
    c.key(YANK1, merge(stand, HAUL, gloves(85, 55), lean(fwd=0, side=10, turn=62), head(x=-18, z=-10)), "pop")   # YANK
    c.key(26, merge(stand, HAUL, gloves(85, 55), lean(fwd=2, side=11, turn=62), head(x=-14, z=-14)), "out_back")
    c.key(LET_GO - 2, merge(stand, HAUL, gloves(85, 55), lean(fwd=2, side=11, turn=62), head(x=-12, z=-14)))
    c.key(LET_GO + 2, merge(stand, BRACE, gloves(10, 6, spread=18), lean(fwd=-4, turn=20), head(x=-6)), "out_quad")
    DUST = sym({"clavicle_l": [("y", -6)], "upperarm_l": [("y", 62), ("z", -46)], "lowerarm_l": [("z", -84)],
                "hand_l": [("x", -10)]})
    c.key(45, merge(stand, DUST, gloves(4, 4), lean(fwd=4), head(x=4, z=10)), "in_out_sine")         # dusts off
    c.key(L, merge(stand, lean(fwd=2), head(x=-2, z=6)), "out_quad")
    # the strain: a tremble through the hold
    def strain(f):
        if f < YANK1 + 2 or f > LET_GO:
            return {}
        k = min(1.0, (f - YANK1 - 2) / 4.0) * min(1.0, (LET_GO - f) / 3.0)
        s = math.sin(2 * math.pi * f / 5.0) * k
        return {"spine_02": [("y", 1.4 * s)], "Head": [("x", 1.2 * s)], "clavicle_l": [("y", 1.5 * s)]}
    c.motion(strain)
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look(("camera",), YANK1, LET_GO, weight=0.8, blend=4)
    # both gloves on the lever (the IK takes over from the keyed arms as she reaches, gives them back at the let-go)
    c.ik_handoff("r", grip("r"), 6, LET_GO + 4, pole=(-0.6, 0.5, -0.8), hand=[("z", 70), ("x", -30)],
                 effector="grip_r", ramp=7, ramp_out=6, soft=0.03)
    c.ik_handoff("l", grip("l"), 6, LET_GO + 4, pole=(0.9, 0.4, -0.5), hand=[("z", 40), ("x", -40), ("y", 30)],
                 effector="grip_l", ramp=7, ramp_out=6, soft=0.03)
    c.pop_frames.extend([YANK0 + 1, YANK0 + 2])
    c.sfx(13, "creak")
    c.sfx(YANK1, "clack")
    c.face(0, "curious")
    c.face(5, "sneak")
    c.face(13, "determined")
    c.face(YANK0 + 1, "frantic")
    c.face(YANK1 + 4, "grin")
    c.face(LET_GO, "smug")
    c.mark(YANK1, "accent")
    c.mark(13, "contact")                                  # the gloves close on the lever
    return c
