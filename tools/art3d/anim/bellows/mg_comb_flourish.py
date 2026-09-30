"""bellows/mg_comb_flourish — the mirror micro-gag (activities.json detour fixup_mirror `comb_flourish`, emote smug; 48 f,
OVERLAY `upper`, the view clock; no audio-table row): "Combs the bouffant back up with a flourish and tucks the comb
behind his ear." At the hall mirror (house.json st_hall_mirror stand_x 952 → 4.76 m, house3d yaw 55 → facing +1,
cheat 35: his RIGHT side — the comb hand — is the camera side), the comb (the fix-up's signature prop) in his right glove:

  0-6     the comb dips (the wind-up)
  6-20    ONE big sweep from his brow up and over the top of the bouffant (the stroke)
  20-28   the FLOURISH: the comb swung out wide, the chin up, a smug look to the house (D8)
  28-38   the comb tucked behind his right ear (a pat)
  38-48   the glove comes down, admiring the result in the mirror

The comb stays in his glove after the tuck (act_fixup_mirror owns the prop state)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 48
BROW = Vector((-0.16, -0.30, 1.40))      # the front of the bouffant, his right (Head-carried rest points)
CROWN = Vector((-0.20, -0.08, 1.54))
BACK = Vector((-0.18, 0.10, 1.48))
EAR = Vector((-0.30, 0.00, 1.26))


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def body(*parts):
    return merge(STAND, ARMS_POMPOUS, glove("l", 18, 10), grip("r", 66, 40), {"upperarm_l": [("y", 78), ("z", 14)]},
                 *parts)


def build(ctx):
    st = Stage(x=4.76, z=-1.4, facing=1, cheat=35.0)
    c = Clip(ctx, "bellows/mg_comb_flourish", length=L, layer="overlay", mask="upper", blend_in=6, blend_out=6,
             cheat_deg=35, stage=st, audio="own", tags=["micro_gag", "fixup_mirror"])
    hide_fx(c)
    COMBING = {"clavicle_r": [("y", 20), ("z", -6)], "upperarm_r": [("y", -20), ("z", 40)], "lowerarm_r": [("z", 120)]}
    c.key(0, body(pompous(1.0), head(x=-6)))
    c.key(5, body(COMBING, lean(fwd=2), head(x=6, y=-4)), "in_out_sine")                      # the dip
    c.key(12, body(COMBING, pompous(1.2), head(x=-4, y=-6, z=-6)), "in_out_sine")             # the stroke...
    c.key(19, body(COMBING, pompous(1.4), head(x=-12, y=-8, z=-8)), "in_out_sine")
    FLOURISH = body({"clavicle_r": [("y", 18)], "upperarm_r": [("y", -30), ("z", -20)], "lowerarm_r": [("z", 30)],
                     "hand_r": [("x", -40)]}, pompous(1.7), head(x=-18, y=6, z=12))
    c.key(23, FLOURISH, "out_back")                                                           # FLOURISH
    c.key(28, merge(FLOURISH, head(x=-20, y=8, z=14)), "in_out_sine")
    c.key(34, body(COMBING, pompous(1.4), head(x=-12, y=8, z=4)), "in_out_cubic")             # behind the ear
    c.key(38, body(COMBING, pompous(1.4), head(x=-14, y=8, z=4)), "in_out_sine")
    c.key(44, body(pompous(1.3), head(x=-10, y=-4, z=-10)), "in_out_cubic")                   # admires the result
    c.key(L, body(pompous(1.0), head(x=-6)), "in_out_sine")

    stroke = [(4, BROW), (8, BROW), (14, CROWN), (20, BACK)]
    tuck = [(29, EAR + Vector((0.0, -0.10, 0.10))), (34, EAR), (38, EAR)]

    def path(f):
        pts = stroke if f < 24 else tuck
        return track(f, pts)

    def comb_hand(pose, f):
        w = window(f, 2, 6, 19, 23) if f < 24 else window(f, 26, 30, 38, 43)
        if w <= 0.0:
            return
        tgt = pose.skel.carried(pose.world, "Head", Vector(path(f)))
        arm_ik(pose, "r", tgt, (-0.9, 0.4, -0.2), w=w)
    c.custom(comb_hand, 0, L)
    c.motion(lambda f: breath(f, 48.0, 1.0))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look(("camera",), 20, 32, weight=0.8, blend=(3, 4))
    c.look_camera(20, 32, weight=1.0, blend=6)
    c.beats(dip=(0, 6), stroke=(6, 20), flourish=(20, 28), tuck=(28, 38), admire=(38, L))
    c.event(0, "prop", op="show", prop="comb")
    c.event(6, "sfx", id="zip", vol_db=-6.0)
    c.event(20, "sfx", id="sparkle", vol_db=-4.0)
    c.event(22, "fx", id="sparkles")
    for f, p in ((0, "admiring"), (6, "pompous"), (20, "smug"), (30, "sly_smile"), (40, "admiring")):
        c.face(f, p)
    return c
