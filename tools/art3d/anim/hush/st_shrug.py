"""hush/st_shrug — "oh well" (clip_rules.json `flavour:shrug`: the struck-hotspot feedback `cmd_rejected` and a missed
lure; 20 f, an OVERLAY on the `upper` mask so it plays over whatever her legs are doing): a tiny dip, then the
shoulders pop up to her ears with both palms turned up and out, the head tilted, the mouth wavy — a beat — and down.
GDD §9.3 shape: anticipation 0–3, accent 3–6 (the pop), hold 6–14 (a moving hold), settle 14–20."""
import math
from lib.clip import Clip
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head

L = 20
LEGS = merge(STAND, {"thigh_r": [("x", -4), ("z", -7)], "calf_r": [("x", 8)]})
DOWN = merge(ARMS_DOWN, gloves(18, 12), glove("r", 22, 14), {"upperarm_r": [("y", -70), ("z", 10)]})
DIP = merge(DOWN, sym({"clavicle_l": [("y", 6)], "upperarm_l": [("y", 80), ("z", -4)], "lowerarm_l": [("z", -6), ("y", -14)]}),
            lean(fwd=4), head(x=6, y=2))                                     # sink, the forearms uncurl (against the pop)
SHRUG = merge(sym({"clavicle_l": [("y", -24), ("z", -4)], "upperarm_l": [("y", 36), ("z", -18)],
                   "lowerarm_l": [("z", -60), ("y", 80)], "hand_l": [("x", -30), ("y", 30)]}),
              {"upperarm_r": [("y", -40), ("z", 14)]},                                   # a touch lopsided; palms up, out wide
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
    c.beats(anticipation=(0, 3), accent=(3, 6), hold=(6, 14), settle=(14, L))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "neutral")
    c.face(3, "worried")
    c.face(15, "neutral")
    return c
