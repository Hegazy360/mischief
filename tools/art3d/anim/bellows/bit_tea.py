"""bellows/bit_tea — the tea's squeak bit (activities.json squeak_bits.bit_tea, 100 f, lock "sim", base layer; the sim
plays it the tick he hears Hush's squeak at his tea): "Tea goes up his nose; a snort and a splutter."

  0-4     the squeak: a start — "huh?" — the cup on its saucer
  4-12    a hurried, pompous sip to cover it (the pinkie up), the cup at his lips
  12-16   anticipation: the tea goes the wrong way — the chin tips up, the eyes cross, the chest fills
  17      ACCENT (a pop): the SNORT — the head jerks down, the cup is yanked out at arm's length, tea spray (fx drops)
  19-58   a moving hold: the splutter — three coughs that shake the barrel, teary eyes, the saucer wobbling
  58-74   a sniff, and a suspicious glare at the house (the face on the camera, D8): "who did that?"
  74-100  composure: the cup back down onto the saucer on his belly (act_tea's rest), chin up

On his stool at st_tea (tea_stage(): x 15.0, z -1.4, facing -1, cheat 35); no hand-offs in flight (keeps none);
the spoon is hidden (the cup takes the right glove). Sounds: no audio-table row — its own (listed for r3d-integrate)."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 100


def sit(fwd=-4.0, turn=4.0, hx=-8.0, hz=10.0, hy=0.0, pel=-2.0, *extra):
    """act_tea's seated carriage (its REST = sit())."""
    return merge(SIT, lean(fwd=fwd, turn=turn), head(x=hx, y=hy, z=hz), glove("l", 16, 10), glove("r", 20, 12),
                 {"pelvis": [("x", pel)]}, *extra)



def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale; an overlay's
    unkeyed rest scale would show the CHOO puff and the stars)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c

def build(ctx):
    st = tea_stage()
    ts = TeaSet(ctx)
    c = Clip(ctx, "bellows/bit_tea", length=L, lock="sim", cheat_deg=TEA_CHEAT, stage=st, blend_in=6, blend_out=8,
             audio="own", keeps=[], tags=["bit", "squeak_bit"],
             notes="staged at the stool (st_tea); cup + saucer shown, spoon hidden; ends in act_tea's rest")
    hide_fx(c)
    c.key(0, sit())
    c.key(4, sit(-8, 6, -14, 14, 4, -3, pinkie_up("r", 0.4)), "out_quad")                     # huh? — a start
    c.key(10, merge(SIP_BODY, head(x=-14, z=10)), "in_out_sine")                            # the hurried sip
    c.key(13, merge(SIP_BODY, lean(fwd=-6, turn=4), head(x=-18, z=10)), "in_out_sine")
    # anticipation: the tea goes the wrong way — chin up, chest filling
    c.key(16, merge(SIP_BODY, lean(fwd=-14, turn=6), head(x=-30, y=4, z=10),
                    {"clavicle_l": [("y", -10)], "clavicle_r": [("y", 10)], "pelvis": [("x", -6)]}), "in_out_sine")
    # ACCENT (17): the SNORT — head whips down and forward, the whole barrel hunches
    KICK = {"thigh_l": [("x", -104), ("z", 12)], "calf_l": [("x", 8)], "foot_l": [("x", -24)],
            "thigh_r": [("x", -98), ("z", -12)], "calf_r": [("x", 14)], "foot_r": [("x", -20)]}     # the legs shoot out
    SNORT = sit(16, -2, 24, 4, -6, 6, pinkie_up("r", 1.3), {"clavicle_l": [("y", 8)], "clavicle_r": [("y", -8)]}, KICK)
    c.key(17, SNORT, "pop")
    c.overshoot(19, sit(12, -2, 18, 4, -6, 5, pinkie_up("r", 1.2), KICK), pct=0.25, frames=4)
    # the splutter: three coughs (a jerk down on each, recoil up between)
    c.key(22, sit(8, -2, 12, 4, -4, 3, pinkie_up("r", 1.1), KICK), "in_out_sine")
    for f0, amp in ((28, 1.0), (40, 0.8), (50, 0.6)):
        if f0 != 28:
            c.key(f0 - 4, sit(2 * amp, 0, 2, 6, 4, 1, pinkie_up("r", 1.0)), "in_out_sine")
        c.key(f0, sit(14 * amp, -2, 20 * amp, 6, -4, 4, pinkie_up("r", 1.2)), "out_quad")
    c.key(58, sit(-2, 3, -12, 10, 2, -2, pinkie_up("r", 0.8)), "in_out_sine")                  # sniff
    c.key(64, sit(-4, 6, -6, 16, -6, -2, pinkie_up("r", 0.6)), "in_out_cubic")                 # the glare
    c.key(74, sit(-5, 6, -8, 16, -8, -2, pinkie_up("r", 0.6)), "in_out_sine")
    c.key(86, sit(-6, 4, -12, 10, 0, -2), "in_out_cubic")                                       # chin up: composure
    c.key(L, sit(), "in_out_sine")
    c.motion(lambda f: dangle(f, 50.0, 6.0))
    c.motion(lambda f: breath(f, 100.0, 0.8))
    # the splutter shakes the barrel (a fast shiver, decaying)
    c.motion(lambda f: tremble(f, 1.6 * math.exp(-(f - 20) / 30.0), ("spine_02", "spine_03", "Head"), 2.9), 18, 60,
             weight=lambda f: window(f, 18, 20, 54, 60))

    # ---- constraints: the stool, the tea set in his gloves ------------------------------------------------------
    seat(c, 0, L)
    # the face on the house (D8): the start, the snort, the glare
    c.look(("camera",), 0, L, weight=0.5, blend=(0, 10))
    c.look_camera(0, 12, weight=1.0, blend=4)
    c.look_camera(18, 80, weight=1.0, blend=8)

    lift_keys = [(0, 0.0), (4, 0.15), (10, 1.0), (16, 1.0), (17, 0.35), (58, 0.3), (64, 0.25), (80, 0.25), (92, 0.0),
                 (L, 0.0)]
    low_keys = [(0, CUP_BELLY), (10, CUP_BELLY), (16, CUP_BELLY), (17, (-0.16, -0.74, 1.00)), (24, (-0.18, -0.72, 0.98)),
                (58, (-0.16, -0.66, 0.98)), (74, (-0.14, -0.58, 0.99)), (92, CUP_BELLY), (L, CUP_BELLY)]
    # the saucer (left glove, the camera side) is flung out behind him on the snort, then comes back under the cup
    sau_keys = [(0, SAUCER_BELLY), (10, SAUCER_CHIN), (16, SAUCER_CHIN), (17, (0.52, 0.22, 1.04)),
                (22, (0.50, 0.16, 1.02)), (29, (0.58, 0.02, 0.97)), (35, (0.46, -0.30, 0.94)), (43, (0.10, -0.50, 0.93)), (58, (0.04, -0.50, 0.92)), (92, SAUCER_BELLY),
                (L, SAUCER_BELLY)]
    tilt_keys = [(0, 0.0), (16, 0.0), (17, 30.0), (22, 26.0), (30, 20.0), (40, -12.0), (46, 10.0), (50, -8.0), (60, 4.0), (80, 0.0),
                 (L, 0.0)]

    def tea_hands(pose, f):
        lift = track(f, lift_keys)
        low = track(f, low_keys)
        sau = track(f, sau_keys)
        tilt = track(f, tilt_keys)
        sip_arms(ts, pose, lift=lift, cup_low=low, saucer_at=sau, saucer_R=qy(-tilt) @ SAUCER_L, w_l=0.0)
        # the saucer glove: the elbow DOWN (the preset's elbow-out pole is singular when the arm is flung out sideways)
        arm_ik(pose, "l", chest_point(pose, sau), (0.35, 0.3, -0.9), hand_R=qy(-tilt) @ SAUCER_L, effector=ts.saucer_c)
    c.custom(tea_hands, 0, L)

    # ---- events -------------------------------------------------------------------------------------------------
    c.beats(anticipation=(12, 16), accent=(16, 19), hold=(19, 58), settle=(74, L),
            huh=(0, 4), sip=(4, 12), splutter=(28, 58), sniff=(58, 64), glare=(64, 74))
    c.event(0, "prop", op="show", prop="teacup")
    c.event(0, "prop", op="show", prop="saucer")
    c.event(0, "prop", op="hide", prop="spoon")
    c.event(4, "sfx", id="tea_slurp")
    c.event(17, "voice", id="vo_bellows_pff")
    c.event(17, "fx", id="drops")
    c.event(17, "jiggle", bones=["bouffant", "belly", "cravat"], kick=0.5)
    c.event(28, "voice", id="vo_bellows_ugh")
    c.event(28, "fx", id="drops")
    c.event(58, "sfx", id="sniffle")
    for f, p in ((0, "huh"), (4, "sip"), (12, "sneeze_gasp"), (17, "wild_take"), (22, "teary"), (58, "sniff"),
                 (64, "suspicious"), (80, "disdain"), (88, "pompous")):
        c.face(f, p)
    return c
