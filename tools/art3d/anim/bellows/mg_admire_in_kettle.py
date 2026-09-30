"""bellows/mg_admire_in_kettle — tea micro-gag (activities.json tea `admire_in_kettle`, emote smug; 48 f, OVERLAY, the
view clock; the audio table: glint f 6, vo_bellows_smug f 14): "Catches his reflection in the kettle, pats his
bouffant, winks at it."

The staging problem (brief §4.1 b-16): the mg fires at 2.0 s of the tea = act_tea f 120, the HONEY beat (the jar lent
to his left palm, the spoon in his right glove, the lid flip on f 126). An upper-body overlay would drag the lent jar
and the spoon with its own hands, so this clip is authored for the HEAD mask (sidecar `mask: "head"`): the head turns
down to the kettle on the dresser at his right (house3d kitchen_kettle's home, the world point (14.40, 0.95, -1.82)),
a glint, the chin lifts and tilts in vanity, one eyebrow waggles, a WINK at the reflection (6-26), and a smug look
back to the house (26-40, D8). The bouffant gets a preening jiggle kick instead of the pat (the hands are busy with the
honey). The body keys copy act_tea's seated honey pose so the clip stays sane under the `upper` mask that
clip_rules.json gives mg:* today (request to r3d-view3d: honour the sidecar mask). Staged at the stool (tea_stage())."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 48
KETTLE = (14.40, 0.95, -1.82)
JAR_HOLD = Vector((0.24, -0.50, 0.83))     # act_tea's honey beat: the left palm under the jar (chest-carried)


def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c


def sit(hx=-4.0, hy=0.0, hz=16.0, fwd=-10.0, turn=6.0):
    return merge(SIT, lean(fwd=fwd, turn=turn), head(x=hx, y=hy, z=hz), glove("l", 16, 10), grip("r", 60, 40),
                 {"pelvis": [("x", -2)]})


def build(ctx):
    st = tea_stage()
    ts = TeaSet(ctx)
    c = Clip(ctx, "bellows/mg_admire_in_kettle", length=L, layer="overlay", mask="head", blend_in=6, blend_out=6,
             cheat_deg=TEA_CHEAT, stage=st, tags=["micro_gag", "tea"])
    hide_fx(c)
    c.key(0, sit())
    c.key(5, sit(hx=4, hy=-6, hz=-6), "out_cubic")                  # glint: he catches himself in the kettle
    c.key(11, sit(hx=-2, hy=-12, hz=-10), "in_out_sine")            # a vain tilt at the reflection
    c.key(15, sit(hx=-14, hy=8, hz=14), "out_back")                 # SNAP to the house, chin up
    c.key(20, sit(hx=-12, hy=10, hz=14), "in_out_sine")             # the WINK (face slots 18-24) + a nod
    c.key(26, sit(hx=-16, hy=12, hz=12), "in_out_sine")             # preening: the head tilts, the chin rolls
    c.key(34, sit(hx=-12, hy=-6, hz=14), "in_out_sine")
    c.key(40, sit(hx=-12, hy=6, hz=12), "in_out_sine")
    c.key(L, sit(), "in_out_sine")
    c.motion(lambda f: {"Head": [("x", 1.0 * math.sin(2 * math.pi * f / 16.0))]})
    c.motion(lambda f: dangle(f, 48.0, 5.0))

    # keep the gloves where act_tea's honey beat has them (only matters under an `upper` mask)
    def honey_hands(pose, f):
        pl = chest_point(pose, JAR_HOLD)
        arm_ik(pose, "l", pl, POLE_L, hand_R=JAR_L)
        arm_ik(pose, "r", pl + Vector((-0.12, -0.08, 0.12)), POLE_R, hand_R=qz(-60) @ qx(20))
    c.custom(honey_hands, 0, L)
    c.look(KETTLE, 2, 13, weight=0.8, blend=(3, 3), bones=("neck_01", "Head"), share=(0.35, 0.65))
    c.look(("camera",), 13, L, weight=0.8, blend=(3, 6), bones=("neck_01", "Head"), share=(0.35, 0.65))
    c.look_camera(13, 44, weight=1.0, blend=6)
    c.beats(glint=(0, 6), vain=(6, 14), wink=(14, 26), smug=(26, 40))
    c.event(14, "jiggle", bones=["bouffant", "bouffant_l", "bouffant_r"], kick=0.5)
    for f, p in ((0, "pompous"), (5, "admiring"), (14, "sly_smile"), (26, "smug"), (40, "pompous")):
        c.face(f, p)
    # the WINK at the reflection: eyes shut under one cocked brow, a smug mouth, no auto-blink (18-24)
    c.face(18, "smug", slots={"eyes": "closed", "brows": "one_up", "pupils": "none", "lids": "none"}, blink=False)
    c.face(24, "sly_smile")
    c.face_tl.sort(key=lambda e: e["f"])
    return c
