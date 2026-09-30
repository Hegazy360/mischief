"""bellows/st_look — the look (clip_rules.json `oneshot:curious_look` = the `curious` detour's clip, SimConst.
CURIOUS_LOOK_TICKS 180, loop ok; also N1/N2 `oneshot:bump_look`): at the noise's spot, specs ON (the view shows them
from the sim's specs state), he LOOKS both ways and shrugs (GDD §4.2: "walks to the source, specs on, looks both ways
3 s, shrugs"). A 180 f loop, so a longer look (bump_look, a held Curious) keeps cycling seamlessly.

  0-20     crouched a little, gloves on his knees-ish, peering ahead through the specs
  20-60    a slow peer to his LEFT: the torso and the head swing round, the barrel leaning after them
  60-100   ...and to his RIGHT (a quicker swing, then a creep)
  100-128  down: peering at the floor, the rump out
  128-160  the SHRUG: shoulders up, both gloves out palm-up, the chin tucked ("nothing")
  160-180  back to the peer (= frame 0)

Facing-proof: the two peers are symmetric, so one of them gives his face to the camera either way; the shrug (a face
beat) is the sidecar gaze (D8)."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 180
CROUCH = {"thigh_l": [("x", -18), ("z", 9)], "calf_l": [("x", 32)], "foot_l": [("x", -14), ("z", -3)],
          "thigh_r": [("x", -16), ("z", -10)], "calf_r": [("x", 30)], "foot_r": [("x", -14), ("z", 3)]}
KNEES = merge(sym({"clavicle_l": [("y", 4)], "upperarm_l": [("y", 76), ("z", -34)], "lowerarm_l": [("z", -30)],
                   "hand_l": [("x", 18), ("y", 10)]}), {"upperarm_r": [("y", -80), ("z", 28)]})
SHRUG = {"clavicle_l": [("y", -22), ("z", -4)], "upperarm_l": [("y", 62), ("z", -24)], "lowerarm_l": [("z", -64), ("y", 70)],
         "hand_l": [("x", -30), ("y", 30)],
         "clavicle_r": [("y", 20), ("z", 4)], "upperarm_r": [("y", -66), ("z", 22)], "lowerarm_r": [("z", 60), ("y", -74)],
         "hand_r": [("x", -28), ("y", -30)]}


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def peer(turn=0.0, fwd=10.0, hx=8.0, hz=0.0, hy=0.0, legs=CROUCH):
    return merge(legs, KNEES, gloves(24, 14), lean(fwd=fwd, turn=turn), head(x=hx, y=hy, z=hz),
                 {"pelvis": [("x", 6), ("z", turn * 0.25)]})


def build(ctx):
    c = Clip(ctx, "bellows/st_look", length=L, loop=True, lock="sim", blend_in=8, blend_out=8, cheat_deg=35,
             audio="own", tags=["oneshot", "curious", "look"])
    hide_fx(c)
    P0 = peer()
    c.key(0, P0)
    c.key(16, peer(4, 13, 12, 8), "in_out_sine")
    c.key(44, peer(22, 10, 6, 30, 4), "in_out_cubic")                     # peer to his left
    c.key(58, peer(24, 11, 8, 34, 6), "in_out_sine")
    c.key(72, peer(-20, 10, 6, -30, -4), "in_out_cubic")                  # ...snap to his right
    c.key(96, peer(-24, 11, 8, -34, -6), "in_out_sine")
    c.key(112, peer(0, 24, 8, 0, 0), "in_out_cubic")                    # down at the floor, rump out
    c.key(124, peer(3, 26, 10, 4, 3), "in_out_sine")
    UP = merge(STAND, SHRUG, open_hand("l", 14), open_hand("r", 12), lean(fwd=-2), head(x=6, y=10, z=2))
    c.key(136, UP, "out_back")                                             # the SHRUG
    c.key(152, merge(UP, head(x=8, y=12, z=4), {"clavicle_l": [("y", -24), ("z", -4)], "clavicle_r": [("y", 23), ("z", 4)]}),
          "in_out_sine")
    c.key(166, peer(-2, 8, 6, -2), "in_out_cubic")
    c.key(L, P0, "in_out_sine")
    c.motion(lambda f: breath(f, 90.0, 1.0))                             # 90 divides 180: a clean seam
    # the peering never stops: the head searches (nods) and the barrel sways, out of phase (periods divide 180)
    c.motion(lambda f: {"Head": [("x", 3.0 * math.sin(2 * math.pi * f / 36.0)), ("z", 2.5 * math.sin(2 * math.pi * f / 45.0))],
                        "spine_03": [("z", 2.0 * math.sin(2 * math.pi * f / 60.0 + 1.3))]})
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(128, 164, weight=1.0, blend=8)
    c.beats(peer_left=(20, 58), peer_right=(58, 100), floor=(100, 128), shrug=(128, 160))
    for f, p in ((0, "magnified"), (58, "suspicious"), (100, "magnified"), (128, "pardon"), (156, "irked"),
                 (166, "magnified")):
        c.face(f, p)
    return c
