"""bellows/st_specs_on — specs ON (clip_rules.json `oneshot:specs_on`, 12 f = SimConst.SPECS_ON_TICKS, an OVERLAY on the
`upper` mask, frame-locked; plays out): the sim's `specs {on: true}` (Curious, Searching, the hunt, Livid) — "specs on
= danger" (GDD §4.2: a loud "tink" and a glint; the tink is the event's, cues.json). A 12 f snap: the right glove
whips the dangling specs up off his chest (f 0-3), SLAPS them onto his nose (f 4: the `specs` prop shows, which hides
`specs_dangling`), the index finger pushes them up the bridge with the chin tucked (4-8), a glint, the glove drops
away (8-12). The face narrows to the specs squint on the slap.

Facing-proof (no baked turn; the face beat is the sidecar gaze, D8). The body below spine_02 is a plain stance."""
import math
from mathutils import Vector
from lib.clip import Clip
from _lib.presets import *

L = 12
LEGS = merge(STAND, {"calf_l": [("x", 5)]})
BASE_ARMS = merge(ARMS_POMPOUS, gloves(18, 10), {"upperarm_l": [("y", 76), ("z", 10)]})
# the right glove at the bridge of his nose, index finger out (pushing the specs up)
POINT_R = merge(curl("r", 70, thumb=40, fingers=("middle", "ring", "pinky")), curl("r", 6, thumb=0, fingers=("index",)))
BRIDGE = ("Head", Vector((-0.02, -0.29, 1.27)))          # the specs' bridge (specs_face rides Head at y -0.27, z 1.29)
CHEST = ("spine_03", Vector((-0.02, -0.42, 0.84)))       # where the dangling specs hang



def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale; an overlay's
    unkeyed rest scale would show the CHOO puff and the stars)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c

def build(ctx):
    c = Clip(ctx, "bellows/st_specs_on", length=L, layer="overlay", mask="upper", lock="sim", blend_in=4, blend_out=4,
             cheat_deg=35, audio="own", tags=["oneshot", "specs"])
    hide_fx(c)
    c.key(0, merge(LEGS, BASE_ARMS, pompous(1.0), head(x=-6)))
    c.key(2, merge(LEGS, BASE_ARMS, grip("r", 50, 30), pompous(1.0), head(x=-2),
                   {"upperarm_r": [("y", -40), ("z", 60)], "lowerarm_r": [("z", 110)]}), "in_out_sine")
    c.key(4, merge(LEGS, BASE_ARMS, POINT_R, lean(fwd=2), head(x=6),
                   {"upperarm_r": [("y", -30), ("z", 50)], "lowerarm_r": [("z", 130)]}), "pop")     # SLAP: on!
    c.key(7, merge(LEGS, BASE_ARMS, POINT_R, lean(fwd=0), head(x=10, y=-3),
                   {"upperarm_r": [("y", -34), ("z", 50)], "lowerarm_r": [("z", 128)]}), "out_quad")   # push up the bridge
    c.key(9, merge(LEGS, BASE_ARMS, grip("r", 30, 20), pompous(0.8), head(x=-2, y=-2),
                   {"upperarm_r": [("y", -50), ("z", 40)], "lowerarm_r": [("z", 90)]}), "in_out_sine")
    c.key(L, merge(LEGS, BASE_ARMS, pompous(1.0), head(x=-6)), "in_out_cubic")
    # the glove path: chest (grab the dangling specs) -> the bridge -> away (IK over the FK arcs)
    c.ik("r", CHEST, 0, 3, pole=(-0.9, 0.3, -0.3), effector="palm", blend=(1, 1), world=False)
    c.ik("r", BRIDGE, 3, 9, pole=(-0.9, 0.2, -0.4), effector="tip", blend=(1, 2), world=False)
    c.pop_frames.append(3)          # the snap spans f 3-4: the glove leaves the chest for the bridge
    c.motion(lambda f: breath(f, 120.0, 0.8))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    c.look_camera(3, L, weight=1.0, blend=3)
    c.beats(grab=(0, 4), on=(4, 7), push_up=(7, 9))
    c.event(4, "prop", op="show", prop="specs")
    c.event(5, "fx", id="sparkles")
    for f, p in ((0, "huh"), (4, "magnified"), (9, "suspicious")):
        c.face(f, p)
    return c
