"""bellows/cue_doorframe_windup — the anticipation of the door-frame bonk (fix round 2, Q2-G6: "an anticipation the
other way"; 40 f, view staging only — CueStager3D plays it as the staged overlay over his walk in the last ~40 f
before he reaches the parlour|kitchen door frame, then the `laugh_doorframe` cue's overlay replaces it on the hit).

  0-8     still groping ahead (cue_doorframe_bonk's GROPE: the walk's own arms, so the overlay blends in clean)
  0-8     a little hunch forward (the dip before the draw-up)
  9-22    the opposite move (a pop at 10): "I know my own house" — he draws himself UP and BACK, chest out, chin in the air, nose
          high, the groping arms pulled back to his lapels (elbows winged behind him), a pompous lean back
  22-34   a smug little sniff held up there (the face to the Stalls: D8 runtime gaze)
  34-40   and he tips forward into the stride, nose first — into the frame (the bonk overlay takes it from here)

An OVERLAY (mask `upper`: spine_02 and everything above it) over his walk, which keeps the legs going; no baked facing.
No sounds (audio "own": the hit's woodblock is the bonk cue's)."""
from lib.clip import Clip
from _lib.presets import *

L = 40

# groping: the bonk cue's first pose (the walk's arms), so this overlay starts and the bonk cue starts on the same arms
GROPE = merge({"clavicle_l": [("z", -6)], "upperarm_l": [("y", 44), ("z", -70)], "lowerarm_l": [("z", -8)],
               "hand_l": [("x", -6), ("y", 6)],
               "clavicle_r": [("z", 8)], "upperarm_r": [("y", -38), ("z", 64)], "lowerarm_r": [("z", 12)],
               "hand_r": [("x", -10), ("y", -4)]},
              open_hand("l", 20), open_hand("r", 18), lean(fwd=4), head(x=10, z=2))
# drawn up and back: the chest out, the chin up, the gloves at his lapels with the elbows winged back
# (never mirror-equal: the left glove grips his lapel, the right fist sits on his hip behind him)
PROUD = merge({"clavicle_l": [("y", 8), ("z", 6)], "upperarm_l": [("y", 70), ("z", 34)], "lowerarm_l": [("z", -112)],
               "hand_l": [("x", 20), ("y", 10)],
               "clavicle_r": [("y", -2), ("z", -10)], "upperarm_r": [("y", -80), ("z", -22)], "lowerarm_r": [("z", 72)],
               "hand_r": [("x", 30), ("y", -20)]},
              glove("l", 40, 20), fist("r"), lean(fwd=-14, side=-3), head(x=-18, y=4, z=6))
# the dip before he draws up (the anticipation against the accent): a little hunch forward, the arms groping lower
DIP = merge(GROPE, {"upperarm_l": [("y", 52), ("z", -76)], "upperarm_r": [("y", -48), ("z", 70)]}, lean(fwd=10), head(x=16, z=2))
PROUD_UP = merge(PROUD, lean(fwd=-17), head(x=-22, z=6))
# tipping forward into the stride: the head leads, the arms start forward again
TIP = merge(GROPE, lean(fwd=12), head(x=16))


def hide_fx(c):
    for k in c._keys:
        for b, v in fx_hidden("fx_notes", "fx_stars", "fx_choo").items():
            k.pose.setdefault(b, v)
    c._key_poses = None


def build(ctx):
    c = Clip(ctx, "bellows/cue_doorframe_windup", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=4,
             cheat_deg=20, audio="own", tags=["cue", "overlay", "anticipation"],
             notes="view staging: the opposite move before the laugh_doorframe bonk (CueStager3D)")
    c.key(0, GROPE)
    c.key(8, DIP, "in_out_sine")
    c.key(10, PROUD, "pop")
    c.key(16, merge(PROUD, lean(fwd=-16, side=-3)), "out_quad")
    c.key(22, PROUD_UP, "in_out_sine")
    c.key(30, merge(PROUD_UP, head(x=-24, z=8)), "in_out_sine")
    c.key(34, PROUD, "in_out_sine")
    c.key(L, TIP, "in_cubic")
    c.motion(lambda f: breath(f, 24.0, 0.8), 14, 34, weight=lambda f: window(f, 14, 18, 30, 34))
    c.look_camera(14, 34, weight=0.8, blend=5)      # D8: the smug sniff to the Stalls
    c.beats(anticipation=(0, 9), accent=(9, 12), hold=(12, 34), settle=(34, 40), draw_up=(9, 22), sniff=(22, 34),
            tip=(34, 40))
    for f, p in ((0, "huh"), (9, "smug"), (34, "huh")):
        c.face(f, p)
    hide_fx(c)
    return c
