"""bellows/act_hunt — the hunt (loop, 180 f = 3 s; activities.json hunt: specs on, Prologue only; played while he
stands — the walk 2350 -> 1650 px is walk@tier3): livid, specs jammed on (the view's specs state; the face is
`magnified`), he creeps in place like an inspector who KNOWS the squeaker is here — crouched, nose first, fingers
curled ready to pounce — peering low under the furniture to one side, snapping upright to glare over his specs,
peering high, then low to the other side. A two-part loop matching the sim's search turns (every 1.5 s = 90 f):
each half is one "look this way" beat, so a facing flip on the half never catches him mid-glance.

Plays facing either way (the peering is forward and low, the glance a runtime gaze). Feet planted (IK), the knees
doing the creeping. Cheat 35. Audio "own" (no table row; a loop): a floorboard creak on each crouch."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 180


def rest_feet(sk):
    """The feet of the plain STAND pose with the soles on the floor: {side: (ankle location, foot rotation)}."""
    p = P.Pose.from_dict(sk, STAND)
    p.solve()
    p.add_pelvis_offset(Vector((0.0, 0.0, -sk.lowest_sole(p.world))))
    return {s: (p.world["foot_" + s].translation.copy(), p.world["foot_" + s].to_quaternion()) for s in ("l", "r")}


def hold_feet(c, f0, f1, anchors):
    """Both feet held exactly on `anchors` (rest_feet): the keyed pelvis height bends the knees on IK."""
    def fn(pose, f):
        for s in ("l", "r"):
            loc, q = anchors[s]
            P.solve_leg(pose, s, loc, foot_world=q)
    c.custom(fn, f0, f1)


# ready to pounce: elbows out, gloves forward and low, fingers curled like claws (the right a little higher)
CLAWS = merge({"clavicle_l": [("z", -6)], "upperarm_l": [("y", 62), ("z", -36)], "lowerarm_l": [("z", -54)],
               "hand_l": [("x", 20), ("y", 10)],
               "clavicle_r": [("z", 8)], "upperarm_r": [("y", -56), ("z", 42)], "lowerarm_r": [("z", 62)],
               "hand_r": [("x", 16), ("y", -8)]},
              curl("l", 46, thumb=30), curl("r", 40, thumb=26))


def crouch(depth=1.0, fwd=0.0, side=0.0, turn=0.0, hx=0.0, hy=0.0, hz=0.0):
    """The creep: knees bent by the pelvis drop (`depth` 0..1), the barrel pitched forward, the head searching."""
    return merge(STAND, CLAWS, lean(fwd=fwd, side=side, turn=turn), head(x=hx, y=hy, z=hz),
                 {"_pelvis": (0.0, 0.0, -0.075 * depth)})


# the glare over the specs: upright, chin down, fists
GLARE = merge(STAND, lean(fwd=-4), head(x=10, z=0), fist("l"), fist("r"),
              {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 78), ("z", 14)], "lowerarm_l": [("z", -40)],
               "clavicle_r": [("y", 10)], "upperarm_r": [("y", -68), ("z", -22)], "lowerarm_r": [("z", 56)],
               "_pelvis": (0.0, 0.0, -0.01)})



def hide_fx(c):
    """Key the FX bones (the dazed stars, the orbiting notes, the CHOO puff) at scale 0 on every key: a clip that
    never shows them must still say so, or a stray scale track (exporter float drift) leaves them visible."""
    for k in c._keys:
        for b, v in fx_hidden("fx_notes", "fx_stars", "fx_choo").items():
            k.pose.setdefault(b, v)
    c._key_poses = None

def build(ctx):
    c = Clip(ctx, "bellows/act_hunt", length=L, loop=True, cheat_deg=35, blend_in=8, audio="own",
             tags=["activity", "hunt", "specs"], notes="standing part of the hunt; the view plays walk@tier3 while he moves")
    # first half (0-90): peer low to his right, snap up to glare, peer high
    c.key(0, crouch(0.6, fwd=16, turn=-4, hx=14, hz=-10))
    c.key(14, crouch(1.0, fwd=30, side=-6, turn=-14, hx=24, hy=-8, hz=-26), "in_out_sine")       # low, to the right
    c.key(30, crouch(1.0, fwd=32, side=-8, turn=-16, hx=26, hy=-12, hz=-30), "in_out_sine")      # holds, sniffing
    c.key(38, merge(GLARE, head(x=6, z=4)), "out_back")                                              # snap up!
    c.key(56, merge(GLARE, head(x=2, y=4, z=8)), "in_out_sine")
    c.key(72, crouch(0.3, fwd=-8, turn=6, hx=-22, hz=12), "in_out_cubic")                          # peers high
    c.key(90, crouch(0.6, fwd=16, turn=4, hx=14, hz=10), "in_out_sine")
    # second half (90-180): the same search to his left
    c.key(104, crouch(1.0, fwd=30, side=6, turn=14, hx=24, hy=8, hz=26), "in_out_sine")
    c.key(120, crouch(1.0, fwd=32, side=8, turn=16, hx=26, hy=12, hz=30), "in_out_sine")
    c.key(128, merge(GLARE, head(x=6, z=-4)), "out_back")
    c.key(146, merge(GLARE, head(x=2, y=-4, z=-8)), "in_out_sine")
    c.key(162, crouch(0.3, fwd=-8, turn=-6, hx=-22, hz=-12), "in_out_cubic")
    # the sniffing twitch of the nose-first peer, the clawing fingers, the tremble of held fury
    c.motion(lambda f: {"Head": [("x", 1.5 * math.sin(2 * math.pi * f / 9.0)), ("z", 1.2 * math.sin(2 * math.pi * f / 13.0))],
                        "nose": [("x", 8 * math.sin(2 * math.pi * f / 6.0))]})
    c.motion(lambda f: {"index_01_l": [("y", 10 * math.sin(2 * math.pi * f / 15.0))],
                        "middle_01_r": [("y", -10 * math.sin(2 * math.pi * f / 12.0))],
                        "ring_01_l": [("y", 8 * math.sin(2 * math.pi * f / 18.0 + 1.0))]})
    c.motion(lambda f: breath(f, 45.0, 1.0))
    hold_feet(c, 0, L, rest_feet(ctx.skel))
    c.look_camera(38, 60, weight=0.8, blend=8)
    c.look_camera(128, 150, weight=0.8, blend=8)
    c.beats(peer_low=(0, 36), glare=(38, 60), peer_high=(60, 90), peer_low_b=(90, 126), glare_b=(128, 150),
            peer_high_b=(150, 180))
    c.sfx(0, "creak")
    c.sfx(90, "creak")
    for f, p in ((0, "magnified"), (38, "furious"), (60, "magnified"), (90, "magnified"), (128, "furious"),
                 (150, "magnified")):
        c.face(f, p)
    hide_fx(c)
    return c
