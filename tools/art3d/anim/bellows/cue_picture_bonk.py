"""bellows/cue_picture_bonk — the `laugh_picture` director cue (Prologue ≈ 58 s; 48 f): "Hmph!" — he stomps out,
chin in the air, and in the doorway the picture frame drops onto his head (the view drops `parlour_picture_frame`
onto his head socket over 12 f and hangs it round his neck): BONK (f12) — the head squashed down into the frame, the
arms flung out; he looks down at the frame round his neck, then raises a slow, framed glare to the Stalls (a portrait
of fury), and with a second "Hmph!" (f40) tosses his chin and stomps on.

An OVERLAY (mask `upper`) over the walk (`walk@tier3` = loco_stomp, or the strut), fists pumping at both ends so it
blends in (4 f) and out (6 f) on the stomp's arms. The falling picture and its crash sound are the cue's (the view's
CueStager3D + cues.json `picture_fall`); the clip adds the bonk on its landing frame and the second Hmph.
"""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 48

# the livid stomp's arms: fists, elbows bent and back, forearms pumping at his sides (the right forward, the left back)
STOMP_ARMS = merge({"clavicle_l": [("z", -4)], "upperarm_l": [("y", 74), ("z", 18)], "lowerarm_l": [("z", -64)],
                    "hand_l": [("x", -10)],
                    "clavicle_r": [("z", -4)], "upperarm_r": [("y", -70), ("z", 10)], "lowerarm_r": [("z", 70)],
                    "hand_r": [("x", -10)]},
                   fist("l"), fist("r"))
HAUGHTY = merge(STOMP_ARMS, lean(fwd=-6), head(x=-14, z=6))
CHIN_UP = merge(STOMP_ARMS, {"upperarm_l": [("y", 86), ("z", 12)], "upperarm_r": [("y", -86), ("z", -8)],
                             "lowerarm_l": [("z", -40)], "lowerarm_r": [("z", 44)]},
                lean(fwd=-10), head(x=-24, y=-4, z=10))
# BONK: the frame lands on his head — head squashed down and forward, shoulders up round his ears, arms flung out
BONK = merge({"clavicle_l": [("y", -22)], "upperarm_l": [("y", -8), ("z", -46)], "lowerarm_l": [("z", -12)],
              "hand_l": [("x", -30)],
              "clavicle_r": [("y", 20)], "upperarm_r": [("y", 14), ("z", 40)], "lowerarm_r": [("z", 16)],
              "hand_r": [("x", -26)]},
             fist("l"), fist("r"), lean(fwd=26), head(x=28, y=4, neck=0.5))
# looking down at the frame round his neck (arms hanging, the palms out: "...")
LOOK_DOWN = merge({"clavicle_l": [("y", 2)], "upperarm_l": [("y", 76), ("z", 14)], "lowerarm_l": [("z", -20)],
                   "hand_l": [("x", 10), ("y", 20)],
                   "clavicle_r": [("y", -2)], "upperarm_r": [("y", -80), ("z", -10)], "lowerarm_r": [("z", 16)],
                   "hand_r": [("x", 14), ("y", -18)]},
                  glove("l", 14, 8), glove("r", 12, 8), lean(fwd=4), head(x=19, y=-6))
# the framed slow burn at the Stalls: chin level, trembling fists
BURN = merge(STOMP_ARMS, {"upperarm_l": [("y", 78), ("z", 8)], "upperarm_r": [("y", -78), ("z", -6)],
                          "lowerarm_l": [("z", -48)], "lowerarm_r": [("z", 52)]},
             lean(fwd=-2), head(x=-4, y=6, z=8))
# Hmph!: the chin tossed up and away
TOSS = merge(STOMP_ARMS, lean(fwd=-10, turn=-4), head(x=-26, y=-8, z=-12))



def hide_fx(c):
    """Key the FX bones (the dazed stars, the orbiting notes, the CHOO puff) at scale 0 on every key: a clip that
    never shows them must still say so, or a stray scale track (exporter float drift) leaves them visible."""
    for k in c._keys:
        for b, v in fx_hidden("fx_notes", "fx_stars", "fx_choo").items():
            k.pose.setdefault(b, v)
    c._key_poses = None

def build(ctx):
    c = Clip(ctx, "bellows/cue_picture_bonk", length=L, layer="overlay", mask="upper", blend_in=4, blend_out=6,
             cheat_deg=20, audio="own", tags=["cue", "overlay"],
             notes="overlay (mask upper) over the walk; the picture frame is the view's (lent to his head socket)")
    c.key(0, HAUGHTY)
    c.key(6, merge(CHIN_UP, {"upperarm_l": [("y", 80), ("z", -6)], "upperarm_r": [("y", -80), ("z", 8)]}), "in_out_sine")
    # the arms swing back as the chin goes up (the wind-up against the frame's blow, which throws them forward)
    c.key(11, merge(CHIN_UP, head(x=-26, y=-4, z=12), {"upperarm_l": [("y", 86), ("z", 30)], "upperarm_r": [("y", -86), ("z", -30)]}),
          "in_out_sine")
    c.key(12, BONK, "pop")
    c.key(15, merge(BONK, head(x=32, y=6, neck=0.5), lean(fwd=32), glove("l", 40, 20), glove("r", 40, 20)), "out_quad")
    c.key(18, merge(BONK, head(x=30, y=5, neck=0.5), lean(fwd=26), open_hand("l", 26), open_hand("r", 24)), "in_out_sine")
    c.key(24, LOOK_DOWN, "in_out_sine")
    c.key(29, merge(LOOK_DOWN, head(x=16, y=4)), "in_out_sine")
    c.key(34, BURN, "in_out_cubic")
    c.key(39, merge(BURN, head(x=-6, y=4, z=6)), "in_out_sine")
    c.key(41, TOSS, "out_back")
    c.key(L, HAUGHTY, "in_out_sine")
    c.motion(lambda f: tremble(f, 1.0, ("spine_03", "Head"), rate=2.4), 13, 20, weight=lambda f: window(f, 13, 14, 17, 20))
    # the fists shaking with fury through the burn
    c.motion(lambda f: {"lowerarm_l": [("z", -3 * math.sin(f * 2.3))], "lowerarm_r": [("z", 3 * math.sin(f * 2.1 + 1.0))],
                        "Head": [("x", 0.8 * math.sin(f * 2.7))]}, 30, 41, weight=lambda f: window(f, 30, 33, 38, 41))
    c.look_camera(30, 40, weight=1.0, blend=6)
    # the accent beat opens on the last chin-up frame (11) so the pop (12) and the squash after it sit inside it
    c.beats(anticipation=(6, 11), accent=(11, 15), hold=(15, 40), settle=(40, 48))
    c.mark(12, "accent")
    c.sfx(12, "bonk")
    c.event(12, "jiggle", bones=["bouffant", "bouffant_l", "bouffant_r", "belly", "cravat"], kick=0.9)
    c.event(12, "shake", trauma=0.25)
    c.event(40, "voice", id="vo_bellows_hmph")
    for f, p in ((0, "disdain"), (6, "pompous"), (12, "dazed_open"), (24, "huh"), (30, "slow_burn"), (40, "irked"),
                 (44, "furious")):
        c.face(f, p)
    hide_fx(c)
    return c
