"""bellows/mg_pinkie_up — tea micro-gag (activities.json tea `pinkie_up`, emote yum; 48 f, OVERLAY `upper`, the view
clock; the audio table: teacup_clink f 10, pinkie_wobble f 14, vo_bellows_bliss f 30): "A long sip with the pinkie
cocked so high it wobbles; eyes shut: 'Ahhh.'" On his stool (the base act_tea keeps the legs and the seat):

  0-10    the cup comes up off the saucer (clink on 10 as it leaves)
  10-14   the PINKIE shoots up — higher than ever — and wobbles (14-28) like a tuning fork
  14-30   the long sip, head tipping back, eyes shut
  30      "Ahhh." — the cup lowers, the head rolls back in bliss (the face to the house, D8)
  30-48   the cup settles back toward the saucer

The mg fires at 7.0 s of the tea = act_tea's THE SIP (f 420), so the cup path is _lib's sip_arms like act_tea's.
Staged at the stool (tea_stage(): facing -1, cheat 35)."""
import math
from lib.clip import Clip
from _lib.presets import *

L = 48


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def sit(fwd=-4.0, turn=4.0, hx=-8.0, hz=10.0, hy=0.0, *extra):
    return merge(SIT, lean(fwd=fwd, turn=turn), head(x=hx, y=hy, z=hz), glove("l", 16, 10), {"pelvis": [("x", -2)]},
                 *extra)


def build(ctx):
    st = tea_stage()
    ts = TeaSet(ctx)
    c = Clip(ctx, "bellows/mg_pinkie_up", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6,
             cheat_deg=TEA_CHEAT, stage=st, tags=["micro_gag", "tea"])
    hide_fx(c)
    c.key(0, sit(-4, 4, -8, 10, 0, pinkie_up("r", 0.6)))
    c.key(10, sit(-5, 4, -12, 10, 0, pinkie_up("r", 0.8)), "in_out_sine")
    c.key(14, merge(SIP_BODY, pinkie_up("r", 1.35), head(x=-16, z=10)), "out_back")          # the pinkie UP
    c.key(28, merge(SIP_BODY, pinkie_up("r", 1.3), lean(fwd=-8, turn=4), head(x=-24, z=10)), "in_out_sine")
    c.key(33, sit(-10, 5, -26, 12, 6, pinkie_up("r", 1.2)), "out_cubic")                      # Ahhh
    c.key(42, sit(-8, 5, -20, 12, 4, pinkie_up("r", 1.0)), "in_out_sine")
    c.key(L, sit(-5, 4, -10, 10, 0, pinkie_up("r", 0.7)), "in_out_sine")
    # the wobble: the cocked pinkie quivers like a tuning fork (decaying)
    c.motion(lambda f: {"pinky_01_r": [("z", 10 * math.exp(-(f - 14) / 10.0) * math.sin(2 * math.pi * (f - 14) / 4.0))]},
             14, 30)
    c.motion(lambda f: breath(f, 48.0, 0.8))
    lift_keys = [(0, 0.1), (10, 0.45), (14, 1.0), (30, 1.0), (40, 0.4), (L, 0.2)]
    sau_keys = [(0, SAUCER_BELLY), (12, SAUCER_CHIN), (30, SAUCER_CHIN), (44, SAUCER_BELLY), (L, SAUCER_BELLY)]

    def tea_hands(pose, f):
        sip_arms(ts, pose, lift=track(f, lift_keys), saucer_at=track(f, sau_keys))
    c.custom(tea_hands, 0, L)
    c.look(("camera",), 24, L, weight=0.6, blend=(6, 6))
    c.look_camera(28, 46, weight=1.0, blend=6)
    c.beats(lift=(0, 10), cock=(10, 14), sip=(14, 30), ahh=(30, 40))
    c.event(0, "prop", op="show", prop="teacup")
    c.event(0, "prop", op="show", prop="saucer")
    for f, p in ((0, "sip"), (14, "blissful"), (44, "blissful")):
        c.face(f, p)
    c.face(30, "blissful", slots={"mouth": "O_mid"})          # "Ahhh."
    c.face_tl.sort(key=lambda e: e["f"])
    return c
