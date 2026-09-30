"""hush/act_glance — the quick look round (REDESIGN §4.2 Rig DURING "she glances left and right"; clip_rules.json
`flavour:glance` after the snicker and `flavour:glance_rig`): a snap of the head to her right — the audience, when she
faces +1 as every band rig clip does — with the chin up (a "did you see that?"), a moving hold, a snap over her left
shoulder (is he coming?), and back. 30 f.

An OVERLAY on the `head` mask (neck_01 and below: head, beret, hair): the view fires it over the rig clips at
rig_actions.json's glance ‰ (index §7.10) and after the snicker, so it only ever drives the neck and head; the body is
keyed to a plain asymmetric stance only so the clip is sane (and lint-clean) if something plays it on the base layer."""
import math
from lib.clip import Clip
from lib.pose import merge
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, head

L = 30
BODY = merge(ARMS_DOWN, STAND, gloves(18, 12), glove("r", 24, 14),
             {"upperarm_r": [("y", -70), ("z", 12)], "lowerarm_r": [("z", 26)]})


def build(ctx):
    c = Clip(ctx, "hush/act_glance", length=L, layer="overlay", mask="head", blend_in=4, blend_out=6, cheat_deg=35,
             audio="own")
    c.key(0, merge(BODY, head(x=-2, z=0)))
    c.key(2, merge(BODY, head(x=2, z=6)), "in_out_sine")                  # a flick the other way first
    c.key(6, merge(BODY, head(x=-12, y=-6, z=-58, neck=0.4)), "out_back")  # SNAP right: the audience
    c.key(13, merge(BODY, head(x=-14, y=-8, z=-54, neck=0.4)))
    c.key(15, merge(BODY, head(x=-10, y=-4, z=-50, neck=0.4)), "in_out_sine")
    c.key(20, merge(BODY, head(x=-2, y=8, z=48, neck=0.45)), "out_back")   # SNAP over her left shoulder
    c.key(25, merge(BODY, head(x=-4, y=10, z=44, neck=0.45)))
    c.key(L, merge(BODY, head(x=-2, z=0)), "in_out_cubic")
    c.motion(lambda f: {"Head": [("x", 1.2 * math.sin(2 * math.pi * f / 15.0))]})
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.face(0, "glance")
    c.face(6, "sneak")
    c.face(20, "worried")
    c.face(26, "sneak")
    return c
