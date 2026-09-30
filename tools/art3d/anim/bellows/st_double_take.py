"""bellows/st_double_take — the double take (clip_rules.json `state:spotted` in N1/N2 — the "!" 0.3 s double take — and
`curtain:double_take` — he sees the audience; 18 f, base, the view clock). It is ALSO the view's readable fallback for
an N1/N2 reaction not made yet (held to the sim's length + the caption), so it must read on its own and END on a
strong held take: eyes popped, jaw dropped, both gloves up and out, bouffant bristling.

  0-3    a casual glance at the thing (a small, bored nod)
  3-8    anticipation: he looks AWAY (it didn't register), chin down, the knees soften, the gloves drop
  8      ACCENT (a pop): he SNAPS back — the head whips round, the barrel jerks up on straightened legs, both
         gloves fly up and out (the "WHAT?!")
  8-18   the take settles through one overshoot into the held pose (a trembling hold, so a view that holds the
         last frame still reads it)

Facing-proof: the face is turned to the camera through the sidecar gaze from the snap on (D8); the look-away is a nod
down + a small turn, so it reads either way."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 18
LEGS_SOFT = {"thigh_l": [("x", -14), ("z", 8)], "calf_l": [("x", 26)], "foot_l": [("x", -10), ("z", -3)],
             "thigh_r": [("x", -12), ("z", -9)], "calf_r": [("x", 24)], "foot_r": [("x", -10), ("z", 3)]}
# both gloves thrown out in front of him, low and wide, palms out at the thing he saw ("WHOA!") — below the face,
# so the take reads in both facings
TAKE_ARMS = {"clavicle_l": [("y", -16), ("z", -6)], "upperarm_l": [("y", 58), ("z", -52)], "lowerarm_l": [("z", -18)],
             "hand_l": [("x", -62), ("y", -10)],
             "clavicle_r": [("y", 16), ("z", -6)], "upperarm_r": [("y", -44), ("z", -24)], "lowerarm_r": [("z", 16)],
             "hand_r": [("x", -56), ("y", 12)]}
# the pompous look-away: gloves clasped behind his back
BEHIND = sym({"clavicle_l": [("z", 10)], "upperarm_l": [("y", 76), ("z", 46)], "lowerarm_l": [("z", -64)],
              "hand_l": [("x", 10), ("y", 30)]})



def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale; an overlay's
    unkeyed rest scale would show the CHOO puff and the stars)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c

def build(ctx):
    c = Clip(ctx, "bellows/st_double_take", length=L, blend_in=4, blend_out=6, cheat_deg=35, audio="own",
             tags=["oneshot", "take", "fallback"])
    hide_fx(c)
    c.key(0, merge(STAND, ARMS_POMPOUS, gloves(18, 10), pompous(1.0), head(x=-6, z=4),
                   {"upperarm_r": [("y", -76), ("z", 12)]}))
    c.key(3, merge(STAND, ARMS_POMPOUS, gloves(18, 10), pompous(0.8), head(x=2, z=10),
                   {"upperarm_r": [("y", -76), ("z", 12)]}), "in_out_sine")                 # a bored glance
    TUCK = merge(ARMS_POMPOUS, {"upperarm_l": [("y", 86), ("z", 12)], "upperarm_r": [("y", -86), ("z", -12)],
                                "lowerarm_l": [("z", -40)], "lowerarm_r": [("z", 38)]})     # gloves tucked in
    c.key(7, merge(LEGS_SOFT, TUCK, gloves(30, 20), lean(fwd=6, turn=-8), head(x=12, y=-4, z=-22),
                   {"pelvis": [("x", 4)]}), "in_out_sine")   # looks away
    c.key(8, merge(LEGS_SOFT, TUCK, gloves(30, 20), lean(fwd=7, turn=-9), head(x=13, y=-4, z=-24),
                   {"pelvis": [("x", 4)]}), "in_out_sine")
    TAKE = merge(STAND, TAKE_ARMS, open_hand("l", 26), open_hand("r", 22), lean(fwd=-16, turn=6),
                 head(x=-22, y=6, z=10), {"pelvis": [("x", -8)]})
    c.key(9, TAKE, "pop")                                                                       # SNAP back!
    c.overshoot(11, merge(TAKE, lean(fwd=-12, turn=5), head(x=-18, y=5, z=8)), pct=0.3, frames=4)
    c.key(L, merge(TAKE, lean(fwd=-13, turn=5), head(x=-19, y=5, z=8),
                   {"upperarm_l": [("y", 56), ("z", -55)], "upperarm_r": [("y", -42), ("z", -26)]}), "in_out_sine")
    c.motion(lambda f: tremble(f, 1.0, ("spine_03", "Head", "hand_l", "hand_r"), 3.1), 9, L,
             weight=lambda f: ramp(f, 9, 12))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(8, L, weight=1.0, blend=2)
    c.beats(anticipation=(3, 8), accent=(8, 11), hold=(11, L))
    c.event(9, "jiggle", bones=["bouffant", "bouffant_l", "bouffant_r", "belly", "tail_l", "tail_r"], kick=0.8)
    for f, p in ((0, "pompous"), (3, "neutral"), (8, "shock"), (11, "wild_take")):
        c.face(f, p)
    return c
