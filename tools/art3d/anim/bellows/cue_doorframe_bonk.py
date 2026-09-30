"""bellows/cue_doorframe_bonk — the `laugh_doorframe` director cue (Prologue ≈ 30 s; 36 f, the 2D length and the audio
table's frames: woodblock_bonk f4, vo_bellows_oof f7): FRAZZLED, the bouffant flipped over his eyes, he gropes along
on the blind shuffle and walks face-first into the parlour|kitchen door frame — BONK: the head snaps back, the arms
fly up, he reels, rubs his forehead with his left glove (the camera side on the walk to the mirror) while the right keeps groping, and gropes on.

An OVERLAY (mask `upper`: spine_02 and everything above it) over `loco_blind_shuffle`, which keeps the legs going; it
starts and ends on the groping arms (straight out in front, fingers spread, the right a little higher), blending in
over 4 f and out over 6 f. No baked facing: it plays facing either way (the view stages the stars at the frame).
"""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 36

# groping: both arms straight out in front at chest height (after arm_out: y 42 is about horizontal), the right a
# touch higher and wider, fingers spread; the head poked forward under the flipped bouffant
GROPE = merge({"clavicle_l": [("z", -6)], "upperarm_l": [("y", 44), ("z", -70)], "lowerarm_l": [("z", -8)],
               "hand_l": [("x", -6), ("y", 6)],
               "clavicle_r": [("z", 8)], "upperarm_r": [("y", -38), ("z", 64)], "lowerarm_r": [("z", 12)],
               "hand_r": [("x", -10), ("y", -4)]},
              open_hand("l", 20), open_hand("r", 18), lean(fwd=4), head(x=10, z=2))
# the last step before the frame: leaning in, nose first, the arms reaching wide (they miss the frame; the nose doesn't)
LEAN_IN = merge(GROPE, {"upperarm_l": [("y", 50), ("z", -84)], "upperarm_r": [("y", -46), ("z", 80)],
                        "lowerarm_l": [("z", -2)], "lowerarm_r": [("z", 4)]},
                lean(fwd=22), head(x=22, z=-2))
# BONK: the head snapped back, the chest recoiled, both arms thrown up and back, fingers splayed
BONK = merge({"clavicle_l": [("y", -22)], "upperarm_l": [("y", -52), ("z", 14)], "lowerarm_l": [("z", -16)],
              "hand_l": [("x", -30)],
              "clavicle_r": [("y", 20)], "upperarm_r": [("y", 46), ("z", -8)], "lowerarm_r": [("z", 14)],
              "hand_r": [("x", -26)]},
             open_hand("l", 28), open_hand("r", 26), lean(fwd=-16, side=3), head(x=-30, y=6, z=-4, neck=0.4))
REEL = merge({"clavicle_l": [("y", -10)], "upperarm_l": [("y", -8), ("z", -20)], "lowerarm_l": [("z", -50)],
              "hand_l": [("x", -16)],
              "clavicle_r": [("y", 6)], "upperarm_r": [("y", 6), ("z", 10)], "lowerarm_r": [("z", 36)],
              "hand_r": [("x", -20)]},
             glove("l", 30, 16), open_hand("r", 24), lean(fwd=-12, side=4), head(x=-22, y=8, z=-6))
# rubbing the bonked forehead with his LEFT glove (on IK below: the camera side when he shuffles left, facing -1, the
# way the Prologue's blind walk from the sink to the hall mirror goes), the right arm groping again, a woozy tilt
RUB_L = {"clavicle_l": [("y", -8)], "upperarm_l": [("y", 18), ("z", -58)], "lowerarm_l": [("z", -118)], "hand_l": [("x", 10)]}
RUB_R = {"clavicle_r": [("z", 8)], "upperarm_r": [("y", -44), ("z", 60)], "lowerarm_r": [("z", 14)], "hand_r": [("x", -8)]}
RUB = merge(RUB_L, RUB_R, glove("l", 16, 10), open_hand("r", 18), lean(fwd=-4, side=-4), head(x=-6, y=-10, z=-4))
RUB_B = merge(RUB, lean(fwd=-2, side=-3), head(x=-2, y=-6, z=-4))



def hide_fx(c):
    """Key the FX bones (the dazed stars, the orbiting notes, the CHOO puff) at scale 0 on every key: a clip that
    never shows them must still say so, or a stray scale track (exporter float drift) leaves them visible."""
    for k in c._keys:
        for b, v in fx_hidden("fx_notes", "fx_stars", "fx_choo").items():
            k.pose.setdefault(b, v)
    c._key_poses = None

def build(ctx):
    c = Clip(ctx, "bellows/cue_doorframe_bonk", length=L, layer="overlay", mask="upper", blend_in=4, blend_out=6,
             cheat_deg=20, tags=["cue", "overlay", "blind"],
             notes="overlay (mask upper) over bellows/loco_blind_shuffle; the stars at the door frame are the view's")
    c.key(0, GROPE)
    c.key(3, LEAN_IN, "in_quad")
    c.key(4, BONK, "pop")
    c.key(7, merge(BONK, head(x=-34, y=8, z=-6, neck=0.4), lean(fwd=-18, side=4)), "out_quad")
    c.key(11, REEL, "in_out_sine")
    c.key(18, RUB, "in_out_cubic")
    c.key(24, RUB_B, "in_out_sine")
    c.key(30, RUB, "in_out_sine")
    c.key(L, GROPE, "in_out_sine")
    # the rub: the left palm on his forehead (it rides the Head bone, so it follows the wobble)
    face_b, face_p = ctx.socket("face")
    brow = face_p + Vector((0.0, -0.10, 0.10))

    def brow_pt(f, pose):
        wob = 0.025 * math.sin(2 * math.pi * (f - 16) / 7.0)
        return pose.skel.carried(pose.world, face_b, brow + Vector((wob, 0.0, 0.0)))
    c.ik("l", brow_pt, 12, 31, pole=POLE_L, hand=None, effector="palm", blend=(7, 4), world=False)
    # a woozy wobble through the rub, the reel's tremble
    c.motion(lambda f: tremble(f, 1.2, ("spine_03", "Head"), rate=2.6), 5, 14, weight=lambda f: window(f, 5, 7, 11, 14))
    c.motion(lambda f: {"Head": [("y", 5 * math.sin(2 * math.pi * (f - 14) / 18.0))],
                        "spine_03": [("y", 2 * math.sin(2 * math.pi * (f - 14) / 18.0 + 1.0))]}, 14, 34,
             weight=lambda f: window(f, 14, 18, 30, 34))
    # the accent beat opens on the lean-in frame (3) so the pop (4) and the recoil after it both sit inside it
    c.beats(anticipation=(0, 3), accent=(3, 7), hold=(7, 31), settle=(31, 36))
    c.mark(4, "accent")
    c.event(4, "jiggle", bones=["bouffant", "bouffant_l", "bouffant_r", "belly"], kick=0.8)
    c.event(4, "shake", trauma=0.2)
    for f, p in ((0, "huh"), (4, "shock"), (11, "dazed_open"), (18, "dazed"), (31, "huh")):
        c.face(f, p)
    hide_fx(c)
    return c
