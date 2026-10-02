"""bellows/st_double_take — the double take (clip_rules.json `state:spotted` in N1/N2 — the "!" 0.3 s double take — and
`curtain:double_take` — he sees the audience; 18 f, base, the view clock). The Prologue's near miss holds it to the
relief cue (`cue_stager_3d.gd` stage_hold, ~48 f) and the curtain call holds it until the slow burn, so the LAST frame is
a held pose that must read on its own. It is ALSO the view's readable fallback for an N1/N2 reaction not made yet.

  0-3    the glance: a casual, bored look at the thing (a small nod toward it)
  3-8    the look AWAY (it didn't register): chin down and turned off, the knees soften, the shoulders drop, the
         gloves sink to his belly (the anticipation goes DOWN so the snap can go UP)
  8-9    ACCENT (a pop on 9): the SNAP back — the head whips round to the thing, the shoulders jerk up to the ears,
         the barrel pulls back on straightened legs, both gloves fly up and TUCK against his chest either side of the
         jabot, fingers splayed, palms out (the "EEK!")
  9-13   one overshoot (shoulders highest, the gloves a touch higher), then the settle
  13-18  the held take: shoulders up, elbows tucked to his sides, gloves at the chest below the chin, eyes popped
         (wild_take), the gloves trembling

QA round 3 (Q3-G1, r3d-polish-take): the old take threw both arms straight out at shoulder height, which read as a
T-pose (the relief and the curtain call f360). The arms never leave the chest zone now: the gloves are IK'd to points
carried by the chest (below the chin, inside the barrel's silhouette width), the elbows down at his sides.

Facing-proof: the face is turned to the camera through the sidecar gaze from the snap on (D8); the look-away is a nod
down + a small turn, and the take is symmetric, so it reads either way."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 18
LEGS_SOFT = {"thigh_l": [("x", -14), ("z", 8)], "calf_l": [("x", 26)], "foot_l": [("x", -10), ("z", -3)],
             "thigh_r": [("x", -12), ("z", -9)], "calf_r": [("x", 24)], "foot_r": [("x", -10), ("z", 3)]}
# the look-away: shoulders slumped, gloves sunk to the belly front (the FK the IK starts from)
SLUMP_ARMS = sym({"clavicle_l": [("y", 6), ("z", 4)], "upperarm_l": [("y", 86), ("z", -14)],
                  "lowerarm_l": [("z", -46)], "hand_l": [("x", -8), ("y", 14)]})
# the take's FK seed (the IK below places the gloves exactly): elbows bent, forearms up toward the chest
TUCK_ARMS = sym({"clavicle_l": [("y", -18), ("z", -5)], "upperarm_l": [("y", 78), ("z", -34)],
                 "lowerarm_l": [("z", -112)], "hand_l": [("x", -20), ("y", 6)]})
SHRUG_UP = {"clavicle_l": [("y", -22), ("z", -6)], "clavicle_r": [("y", 22), ("z", -6)]}
# the gloves' targets, carried by the chest (spine_03; armature rest space): either side of the jabot, a hand's width
# in front of it and below the chin (head centre 1.26 m, chin ~1.12) — never past the barrel's 0.405 m half-width
GLOVE_L = Vector((0.25, -0.34, 0.74))
GLOVE_R = Vector((-0.24, -0.34, 0.73))
SINK_L = Vector((0.17, -0.36, 0.76))     # the look-away: gloves sunk to the belly front
SINK_R = Vector((-0.17, -0.36, 0.76))
POLE_TUCK_L = (0.6, 0.2, -0.8)         # elbows down and out, clear of the barrel
POLE_TUCK_R = (-0.6, 0.2, -0.8)
# palms out at the thing, fingers up and splayed OUTWARD (hand rest = along the T-pose arm, palm down): the outward
# tilt keeps a held prop (the warm-up baton rides grip_r through the hunt) leaning away from his face, not across it
HAND_EEK_L = qy(32) @ qz(-80) @ qy(-75)
HAND_EEK_R = qy(-32) @ qz(80) @ qy(75)


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale; an overlay's
    unkeyed rest scale would show the CHOO puff and the stars)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


BATON_OUT = Vector((-0.72, -0.25, -0.65)).normalized()   # out to his right, a little forward, down


def baton_out(pose):
    """The warm-up baton (prop_baton under hand_r's grip, its stick along the bone's +Y) can still be in his right
    glove in the near miss: turn the glove about the wrist so the stick points out and down, never across his face."""
    sk = pose.skel
    v = pose.world["prop_baton"].col[1].xyz.normalized()
    R = v.rotation_difference(BATON_OUT)
    pose.set_world_rot("hand_r", R @ pose.world["hand_r"].to_quaternion())
    pose.solve()


def glove_at(f):
    """(left, right) chest-space glove targets per frame: sunk before the snap, tucked up from 9, an overshoot lift on
    9-11, then a fast small tremble on the hold (two incommensurate sines, a few mm)."""
    if f <= 8:
        return SINK_L, SINK_R
    lift = 0.03 * window(f, 9, 10, 11, 14)
    k = ramp(f, 11, 13)
    tl = Vector((0.004 * math.sin(3.1 * f), 0.0, 0.006 * math.sin(4.3 * f + 1.0))) * k
    tr = Vector((0.004 * math.sin(3.4 * f + 2.0), 0.0, 0.006 * math.sin(4.0 * f + 0.4))) * k
    up = Vector((0.0, 0.0, lift))
    return GLOVE_L + up + tl, GLOVE_R + up + tr


def build(ctx):
    c = Clip(ctx, "bellows/st_double_take", length=L, blend_in=4, blend_out=6, cheat_deg=35, audio="own",
             tags=["oneshot", "take", "fallback"])
    hide_fx(c)
    c.key(0, merge(STAND, ARMS_POMPOUS, gloves(18, 10), pompous(1.0), head(x=-6, z=4),
                   {"upperarm_r": [("y", -76), ("z", 12)]}))
    c.key(3, merge(STAND, ARMS_POMPOUS, gloves(18, 10), pompous(0.8), head(x=4, z=8),
                   {"upperarm_r": [("y", -76), ("z", 12)]}), "in_out_sine")                 # a bored glance
    LOOK_AWAY = merge(LEGS_SOFT, SLUMP_ARMS, gloves(24, 14), lean(fwd=7, turn=-10), head(x=14, y=-4, z=-26),
                      {"pelvis": [("x", 4)]})
    c.key(7, LOOK_AWAY, "in_out_sine")                                                          # looks away
    c.key(8, merge(LOOK_AWAY, lean(fwd=8, turn=-11), head(x=15, y=-4, z=-28)), "in_out_sine")
    TAKE = merge(STAND, TUCK_ARMS, SHRUG_UP, open_hand("l", 30), open_hand("r", 26), lean(fwd=-14, turn=6),
                 head(x=-20, y=5, z=8), {"pelvis": [("x", -6)]})
    c.key(9, TAKE, "pop")                                                                       # SNAP back!
    c.overshoot(11, merge(TAKE, {"clavicle_l": [("y", -27), ("z", -7)], "clavicle_r": [("y", 27), ("z", -7)]},
                          lean(fwd=-17, turn=7), head(x=-24, y=6, z=9)), pct=0.3, frames=4)
    c.key(L, merge(TAKE, {"clavicle_l": [("y", -20), ("z", -6)], "clavicle_r": [("y", 20), ("z", -6)]},
                   lean(fwd=-13, turn=5), head(x=-19, y=5, z=7)), "in_out_sine")
    c.motion(lambda f: tremble(f, 1.0, ("spine_03", "Head"), 3.1), 9, L, weight=lambda f: ramp(f, 9, 12))
    c.ground()
    c.auto_plant(speed_m_s=0.0)

    def hands(pose, f):
        # the gloves: sunk to the belly through the look-away (weight eases in on 3-7), then snapped to the chest on
        # the pop (9) with the palms out
        tl, tr = glove_at(f)
        if f <= 8:
            w = ramp(f, 3, 7)
            arm_ik(pose, "l", chest_point(pose, tl), POLE_L, w=w)
            arm_ik(pose, "r", chest_point(pose, tr), POLE_R, w=w)
        else:
            arm_ik(pose, "l", chest_point(pose, tl), POLE_TUCK_L, hand_R=HAND_EEK_L)
            arm_ik(pose, "r", chest_point(pose, tr), POLE_TUCK_R, hand_R=HAND_EEK_R)
            baton_out(pose)
    c.custom(hands, 0, L)
    # the face to the camera from the snap on and THROUGH the held last frame (a window's blend-out ends at its f1,
    # so one window to L would leave the held take with no gaze): a blended window brings it in on 7-9, a second
    # unblended one keeps it at full weight 9..L inclusive
    c.look_camera(7, 11, weight=1.0, blend=2)
    c.look_camera(9, L, weight=1.0, blend=0)
    c.beats(anticipation=(3, 8), accent=(8, 11), hold=(11, L))
    c.event(9, "jiggle", bones=["bouffant", "bouffant_l", "bouffant_r", "belly", "tail_l", "tail_r"], kick=0.8)
    for f, p in ((0, "pompous"), (3, "neutral"), (8, "shock"), (11, "wild_take")):
        c.face(f, p)
    return c
