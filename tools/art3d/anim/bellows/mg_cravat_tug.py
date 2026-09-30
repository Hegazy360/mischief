"""bellows/mg_cravat_tug — walking micro-gag (activities.json walk_beats `cravat_tug`, emote smug; 48 f, OVERLAY `upper`
over the strut, the view clock; no audio-table row): "Tugs his cravat and puffs his chest out mid-stride." Both gloves
come up to the cravat, a sharp TUG (the chin jerks up), the chest swells enormous (the barrel leans back), a second
flick of the knot (cravat_ping), and the arms go back to the strut's stiff swing. Facing-proof (he walks either way);
the smug face beat is the sidecar gaze (D8). The legs are the strut's (the mask); the clip's own legs stand."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 48
KNOT_L = ("spine_03", Vector((0.05, -0.38, 0.99)))
KNOT_R = ("spine_03", Vector((-0.06, -0.38, 0.98)))
STRUT_ARMS = merge(ARMS_POMPOUS, gloves(22, 12), {"upperarm_l": [("y", 80), ("z", 6)], "upperarm_r": [("y", -74), ("z", 12)],
                                                  "lowerarm_l": [("z", -34)], "lowerarm_r": [("z", 34)]})


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def build(ctx):
    c = Clip(ctx, "bellows/mg_cravat_tug", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6,
             cheat_deg=20, audio="own", tags=["micro_gag", "walk"])
    hide_fx(c)
    W = lambda *p: merge(STAND, *p)
    c.key(0, W(STRUT_ARMS, pompous(1.2), head(x=-4)))
    c.key(7, W(STRUT_ARMS, grip("l", 56, 34), grip("r", 56, 34), pompous(1.0), head(x=4)), "in_out_sine")
    c.key(10, W(STRUT_ARMS, grip("l", 70, 40), grip("r", 70, 40), pompous(1.9), head(x=-20, y=-3)), "out_back")    # TUG
    PUFF = W(STRUT_ARMS, grip("l", 66, 38), grip("r", 66, 38), pompous(2.4), head(x=-24, y=4, z=6),
             {"clavicle_l": [("y", -10)], "clavicle_r": [("y", 10)]})
    c.key(18, PUFF, "in_out_sine")                                                                      # chest OUT
    c.key(24, merge(PUFF, head(x=-22, y=6, z=8)), "in_out_sine")
    c.key(27, merge(PUFF, pompous(2.6), head(x=-28, y=4, z=6)), "out_quad")                             # ping!
    c.key(36, W(STRUT_ARMS, gloves(24, 14), pompous(1.8), head(x=-14, y=3)), "in_out_cubic")
    c.key(L, W(STRUT_ARMS, pompous(1.2), head(x=-4)), "in_out_sine")

    def hands(pose, f):
        w = window(f, 2, 8, 28, 36)
        if w > 0.0:
            arm_ik(pose, "l", pose.skel.carried(pose.world, KNOT_L[0], KNOT_L[1]), POLE_L, w=w)
            arm_ik(pose, "r", pose.skel.carried(pose.world, KNOT_R[0], KNOT_R[1]), POLE_R, w=w)
    c.custom(hands, 0, L)
    c.motion(lambda f: breath(f, 48.0, 1.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(10, 40, weight=1.0, blend=6)
    c.beats(reach=(0, 10), puff=(10, 27), ping=(27, 36))
    c.event(10, "sfx", id="cravat_tug", vol_db=-3.0)
    c.event(10, "jiggle", bones=["cravat", "belly"], kick=0.6)
    c.event(27, "sfx", id="cravat_ping", vol_db=-4.0)
    for f, p in ((0, "pompous"), (10, "strained_grin"), (18, "smug"), (36, "pompous")):
        c.face(f, p)
    return c
