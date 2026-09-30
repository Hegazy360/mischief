"""hush/st_shrug — "oh well" (clip_rules.json `flavour:shrug`: the struck-hotspot feedback `cmd_rejected` and a missed
lure; 20 f, an OVERLAY on the `upper` mask so it plays over whatever her legs are doing): a tiny dip, then the
shoulders pop up to her ears with both palms turned up and out, the head tilted, the mouth wavy — a beat — and down.
GDD §9.3 shape: anticipation 0–3, accent 3–6 (the pop), hold 6–14 (a moving hold), settle 14–20."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head

L = 20
LEGS = merge(STAND, {"thigh_r": [("x", -4), ("z", -7)], "calf_r": [("x", 8)]})
DOWN = merge(ARMS_DOWN, gloves(18, 12), glove("r", 22, 14), {"upperarm_r": [("y", -70), ("z", 10)]})
DIP = merge(DOWN, sym({"clavicle_l": [("y", 6)], "upperarm_l": [("y", 80), ("z", -4)], "lowerarm_l": [("z", -6), ("y", -14)], "hand_l": [("x", -20)]}),
            lean(fwd=4), head(x=6, y=2))                                     # sink, the forearms uncurl (against the pop)
# FK close to the IK below: elbows at her sides, forearms out; the IK puts the palms up and out at her waist
SHRUG = merge(sym({"clavicle_l": [("y", -24), ("z", -4)], "upperarm_l": [("y", 66), ("z", 10)], "lowerarm_l": [("z", -70)]}),
              glove("l", 6, 4, spread=16), glove("r", 8, 4, spread=14), lean(fwd=-3, side=3), head(x=-6, y=14, z=6))


def build(ctx):
    c = Clip(ctx, "hush/st_shrug", length=L, layer="overlay", mask="upper", blend_in=4, blend_out=4, cheat_deg=35,
             audio="own")
    c.key(0, merge(LEGS, DOWN))
    c.key(3, merge(LEGS, DIP), "in_out_sine")
    c.key(6, merge(LEGS, SHRUG), "pop")
    c.key(10, merge(LEGS, SHRUG, {"clavicle_l": [("y", -24), ("z", -4)], "clavicle_r": [("y", 25), ("z", 4)]},
                    head(x=-5, y=16, z=6)))
    c.key(14, merge(LEGS, SHRUG, head(x=-4, y=12, z=4)), "in_out_sine")
    c.key(L, merge(LEGS, DOWN), "in_out_cubic")
    # palms up, out wide at her waist (a touch lopsided): rest points riding on the chest, so the shrug lifts them
    c.ik("l", ("spine_03", Vector((0.34, -0.10, 0.99))), 3, 20, pole=(0.3, 0.8, -0.5), hand=[("x", 180), ("z", -25)],
         effector="palm", blend=4)
    c.ik("r", ("spine_03", Vector((-0.31, -0.13, 1.03))), 3, 20, pole=(-0.3, 0.8, -0.5), hand=[("x", 180), ("z", 25)],
         effector="palm", blend=4)
    c.pop_frames.extend([4, 5, 6])               # the palms flip up with the pop
    c.beats(anticipation=(0, 3), accent=(3, 6), hold=(6, 14), settle=(14, L))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "neutral")
    c.face(3, "worried")
    c.face(15, "neutral")
    return c
